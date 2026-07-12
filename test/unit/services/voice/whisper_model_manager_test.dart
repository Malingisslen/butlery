/// WhisperModelManager delivery-contract tests (kb-whisper voice plan).
///
/// Intention: the KB-Whisper GGML speech model inherits the EXACT fail-close
/// delivery contract of the parsing models (BUT-792/BUT-877) — tampered or
/// unregistered bytes never touch disk, a valid cache is reused (with stale
/// .tmp cleanup), and a transient Storage error degrades to "model
/// unavailable" instead of throwing into the voice feature.
///
/// Pure-function hash coverage lives in `expected_model_hashes_test.dart`;
/// this file proves the manager wiring, mirroring
/// `model_manager_integrity_test.dart` for the ONNX managers.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/voice/whisper_model_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MockFirebaseStorage mockStorage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('whisper_mgr_');
    mockStorage = MockFirebaseStorage();
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('integrity short-circuit (fail-close contract)', () {
    test('mismatched bytes return null and leave no files on disk', () async {
      // Registered v1 hash is the real 55.3 MB kb-whisper-base blob;
      // placeholder bytes can never collide with it.
      await mockStorage
          .ref('models/whisper_sv/latest_version.txt')
          .putData(Uint8List.fromList(utf8.encode('1')));
      await mockStorage
          .ref('models/whisper_sv/v1/ggml-model.bin')
          .putData(Uint8List.fromList(utf8.encode('tampered-whisper-bytes')));

      final manager = _TestWhisperModelManager(
        storage: mockStorage,
        cacheDir: tempDir,
      );
      final result = await manager.ensureModelAvailable();

      expect(
        result,
        isNull,
        reason:
            'Mismatched SHA-256 must make the model unavailable — the mic '
            'button then falls back to typed input, never runs unvetted '
            'bytes.',
      );
      expect(
        tempDir.listSync(recursive: true).whereType<File>(),
        isEmpty,
        reason: 'Tampered bytes must never touch disk (BUT-792).',
      );
      expect(manager.isModelAvailable, isFalse);
    });

    test('a version absent from the registry is refused (BUT-877)', () async {
      await mockStorage
          .ref('models/whisper_sv/latest_version.txt')
          .putData(Uint8List.fromList(utf8.encode('999')));
      await mockStorage
          .ref('models/whisper_sv/v999/ggml-model.bin')
          .putData(Uint8List.fromList(utf8.encode('arbitrary-bytes')));

      final manager = _TestWhisperModelManager(
        storage: mockStorage,
        cacheDir: tempDir,
      );
      final result = await manager.ensureModelAvailable();

      expect(
        result,
        isNull,
        reason:
            'Publishing a new whisper version requires its hash in '
            'kExpectedWhisperModelHashes in the same PR as the upload — '
            'an unregistered version must fail-close.',
      );
      expect(
        tempDir.listSync(recursive: true).whereType<File>(),
        isEmpty,
      );
    });
  });

  group('cache behavior', () {
    test('valid cache is returned and stale .tmp is cleaned up', () async {
      final modelPath = '${tempDir.path}/ggml-model.bin';
      await File(modelPath).writeAsBytes(
        Uint8List.fromList(List<int>.generate(2048, (i) => i & 0xff)),
      );
      await File('${tempDir.path}/version.txt').writeAsString('1');
      final staleTmp = File('$modelPath.tmp');
      await staleTmp.writeAsBytes(Uint8List.fromList([0xde, 0xad]));

      final manager = _TestWhisperModelManager(
        storage: mockStorage,
        cacheDir: tempDir,
      );
      final result = await manager.ensureModelAvailable();

      expect(result, isNotNull);
      expect(result!.modelPath, modelPath);
      expect(result.version, 1);
      expect(manager.isModelAvailable, isTrue);
      expect(
        staleTmp.existsSync(),
        isFalse,
        reason:
            'A .tmp left by an interrupted prior write must be deleted '
            'during cache load.',
      );
    });

    test('cache without a version.txt commit marker is ignored', () async {
      // A model file without the version marker means an interrupted
      // install — must be treated as absent, not trusted.
      await File('${tempDir.path}/ggml-model.bin').writeAsBytes(
        Uint8List.fromList(List<int>.generate(2048, (i) => i & 0xff)),
      );

      final manager = _TestWhisperModelManager(
        storage: mockStorage,
        cacheDir: tempDir,
      );
      // No Storage objects staged either → download path also yields null.
      final result = await manager.ensureModelAvailable();

      expect(
        result,
        isNull,
        reason:
            'version.txt is the atomic commit marker; a model file '
            'without it is an incomplete install and must not be used.',
      );
    });
  });

  group('user-initiated retry after failure', () {
    test('a failed download does NOT arm the 12h throttle — the next mic '
        'tap retries against Storage', () async {
      // Unregistered version → fail-closed refusal on every attempt.
      await mockStorage
          .ref('models/whisper_sv/latest_version.txt')
          .putData(Uint8List.fromList(utf8.encode('999')));
      await mockStorage
          .ref('models/whisper_sv/v999/ggml-model.bin')
          .putData(Uint8List.fromList(utf8.encode('arbitrary-bytes')));

      final counting = _CountingStorage(delegate: mockStorage);
      final manager = _TestWhisperModelManager(
        storage: counting,
        cacheDir: tempDir,
      );

      expect(await manager.ensureModelAvailable(), isNull);
      final refsAfterFirst = counting.refCalls;
      expect(refsAfterFirst, greaterThan(0));

      expect(await manager.ensureModelAvailable(), isNull);
      expect(
        counting.refCalls,
        greaterThan(refsAfterFirst),
        reason:
            'the second attempt must reach Storage again — a failed '
            'user-initiated download must not throttle-lock the voice '
            'feature for 12 hours (only SUCCESS arms the throttle)',
      );
    });
  });

  group('transient Storage failure', () {
    test('FirebaseException mid-download degrades to null, no files', () async {
      await mockStorage
          .ref('models/whisper_sv/latest_version.txt')
          .putData(Uint8List.fromList(utf8.encode('1')));

      final throwingStorage = _ThrowingPathStorage(
        delegate: mockStorage,
        throwingPath: 'models/whisper_sv/v1/ggml-model.bin',
        error: FirebaseException(
          plugin: 'firebase_storage',
          code: 'unavailable',
          message: 'transient backend error',
        ),
      );
      final manager = _TestWhisperModelManager(
        storage: throwingStorage,
        cacheDir: tempDir,
      );

      final result = await manager.ensureModelAvailable();

      expect(
        result,
        isNull,
        reason:
            'A transient Storage error must surface as "model unavailable" '
            '(typed input keeps working), never as a thrown exception.',
      );
      expect(
        tempDir.listSync(recursive: true).whereType<File>(),
        isEmpty,
      );
    });
  });
}

class _TestWhisperModelManager extends WhisperModelManager {
  final Directory _testCacheDir;

  _TestWhisperModelManager({
    required FirebaseStorage storage,
    required Directory cacheDir,
  }) : _testCacheDir = cacheDir,
       super(storage: storage);

  @override
  Future<Directory> getCacheDir() async => _testCacheDir;
}

/// Counts ref() lookups so tests can prove whether an attempt actually
/// reached Storage (throttled attempts short-circuit before any ref()).
class _CountingStorage extends Fake implements FirebaseStorage {
  _CountingStorage({required FirebaseStorage delegate}) : _delegate = delegate;

  final FirebaseStorage _delegate;
  int refCalls = 0;

  @override
  Reference ref([String? path]) {
    refCalls++;
    return _delegate.ref(path);
  }
}

class _ThrowingReference extends Fake implements Reference {
  final FirebaseException _error;

  _ThrowingReference(this._error);

  @override
  Future<Uint8List?> getData([int maxSize = 10485760]) async {
    throw _error;
  }
}

class _ThrowingPathStorage extends Fake implements FirebaseStorage {
  final FirebaseStorage _delegate;
  final String _throwingPath;
  final FirebaseException _error;

  _ThrowingPathStorage({
    required FirebaseStorage delegate,
    required String throwingPath,
    required FirebaseException error,
  }) : _delegate = delegate,
       _throwingPath = throwingPath,
       _error = error;

  @override
  Reference ref([String? path]) {
    if (path == _throwingPath) return _ThrowingReference(_error);
    return _delegate.ref(path);
  }
}
