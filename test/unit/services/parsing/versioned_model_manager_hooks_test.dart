/// VersionedModelManager per-family hook coverage (voice-consolidation
/// plan, Data/ML review condition 4).
///
/// Intention: the de-triplication refactor expressed each family's
/// specializations as overridable hooks on the shared base — these tests
/// prove each hook actually FIRES for its family, so a future base change
/// can't silently default a family to another family's behavior.
///
/// - NER/LC: the vocab sidecar hook — a cache missing vocab.txt is invalid.
/// - NER + whisper: the per-family size cap hook (25 MB vs 80 MB).
/// - LC: a FAILED download ARMS the 12h throttle (background family
///   default) — the deliberate contrast to whisper's success-only throttle,
///   which is pinned in whisper_model_manager_test.dart.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/parsing/line_classifier/line_classifier_model_manager.dart';
import 'package:butlery/services/parsing/ner/ner_model_manager.dart';
import 'package:butlery/services/voice/whisper_model_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MockFirebaseStorage mockStorage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vmm_hooks_');
    mockStorage = MockFirebaseStorage();
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// Creates a file of [length] bytes without writing them (sparse-friendly
  /// truncate) — lets the size-cap tests stage an "81 MB" file instantly.
  Future<void> createFileOfLength(String path, int length) async {
    final raf = await File(path).open(mode: FileMode.write);
    await raf.truncate(length);
    await raf.close();
  }

  group('vocab sidecar hook (NER family)', () {
    test('a cache missing vocab.txt is treated as absent', () async {
      // Model + version.txt commit marker present, vocab sidecar missing —
      // the sidecar hook must invalidate the install (the tokenizer cannot
      // run without its vocab).
      await File('${tempDir.path}/model.onnx').writeAsBytes(
        Uint8List.fromList(List<int>.generate(2048, (i) => i & 0xff)),
      );
      await File('${tempDir.path}/version.txt').writeAsString('1');

      final manager = _TestNerModelManager(
        storage: mockStorage,
        cacheDir: tempDir,
      );
      // No Storage objects staged → the download path also yields null, so
      // a non-null result could only come from (wrongly) trusting the cache.
      final result = await manager.ensureModelAvailable();

      expect(
        result,
        isNull,
        reason:
            'The NER family declares vocab.txt as a required sidecar — a '
            'cache without it must be ignored, not returned vocab-less.',
      );
    });
  });

  group('per-family size cap hook', () {
    test('NER: a cached model over the 25 MB family cap is ignored', () async {
      await createFileOfLength(
        '${tempDir.path}/model.onnx',
        26 * 1024 * 1024,
      );
      await File('${tempDir.path}/vocab.txt').writeAsString('vocab');
      await File('${tempDir.path}/version.txt').writeAsString('1');

      final manager = _TestNerModelManager(
        storage: mockStorage,
        cacheDir: tempDir,
      );

      expect(
        await manager.ensureModelAvailable(),
        isNull,
        reason: 'The NER cap is 25 MB — an oversize cache must be refused.',
      );
    });

    test('whisper: 26 MB is fine (80 MB cap) but 81 MB is refused', () async {
      // Same 26 MB that the NER family refuses is comfortably inside the
      // whisper cap — proving the cap is per-family, not a shared constant.
      await createFileOfLength(
        '${tempDir.path}/ggml-model.bin',
        26 * 1024 * 1024,
      );
      await File('${tempDir.path}/version.txt').writeAsString('1');

      final manager = _TestWhisperModelManager(
        storage: mockStorage,
        cacheDir: tempDir,
      );
      final within = await manager.ensureModelAvailable();
      expect(
        within,
        isNotNull,
        reason: '26 MB is within the whisper family\'s 80 MB cap.',
      );

      await createFileOfLength(
        '${tempDir.path}/ggml-model.bin',
        81 * 1024 * 1024,
      );
      final oversize = await _TestWhisperModelManager(
        storage: mockStorage,
        cacheDir: tempDir,
      ).ensureModelAvailable();
      expect(
        oversize,
        isNull,
        reason: '81 MB exceeds the whisper family\'s 80 MB cap.',
      );
    });
  });

  group('successful install (the base\'s happy download path)', () {
    test(
      'NER: registered matching hash installs verified bytes + sidecar '
      'with the version marker, and a fresh manager trusts the cache',
      () async {
        // The fail-close suites pin every REFUSAL branch; this pins the one
        // branch they can't reach (production registries hold real-model
        // hashes): a registered, hash-matching download must land on disk
        // byte-identical to what was staged (the bytes WRITTEN are the bytes
        // HASHED — the TransferableTypedData round-trip's integrity half),
        // with the vocab sidecar installed and version.txt committed, and the
        // resulting cache must be accepted by a fresh manager instance.
        final modelBytes = Uint8List.fromList(
          List<int>.generate(4096, (i) => (i * 7) & 0xff),
        );
        await mockStorage
            .ref('models/ingredient_ner/latest_version.txt')
            .putData(Uint8List.fromList(utf8.encode('3')));
        await mockStorage
            .ref('models/ingredient_ner/v3/model.onnx')
            .putData(modelBytes);
        await mockStorage
            .ref('models/ingredient_ner/v3/vocab.txt')
            .putData(Uint8List.fromList(utf8.encode('[PAD]\n[UNK]\nsmör')));

        final registry = {3: sha256.convert(modelBytes).toString()};
        final manager = _TestNerModelManager(
          storage: mockStorage,
          cacheDir: tempDir,
          registry: registry,
        );

        final result = await manager.ensureModelAvailable();

        expect(
          result,
          isNotNull,
          reason:
              'A registered, hash-matching version is the ONE path that '
              'may install — if even this returns null, every model download '
              'in the app is broken.',
        );
        expect(result!.version, 3);
        expect(
          result.vocabContent,
          contains('smör'),
          reason:
              'The vocab sidecar content must reach the family result — '
              'the tokenizer cannot run without it.',
        );
        expect(
          await File('${tempDir.path}/model.onnx').readAsBytes(),
          modelBytes,
          reason:
              'The cached bytes must be byte-identical to the verified '
              'download (bytes written == bytes hashed).',
        );
        expect(
          (await File('${tempDir.path}/version.txt').readAsString()).trim(),
          '3',
          reason: 'version.txt is the commit marker for a complete install.',
        );
        expect(
          tempDir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.tmp')),
          isEmpty,
          reason: 'No .tmp staging files may survive a committed install.',
        );

        // Round trip: a FRESH manager must accept the install from cache
        // alone (proves the download wrote everything the cache path needs).
        final second = _TestNerModelManager(
          storage: mockStorage,
          cacheDir: tempDir,
          registry: registry,
        );
        final cached = await second.ensureModelAvailable();
        expect(
          cached,
          isNotNull,
          reason:
              'A completed install must validate as a cache hit on the '
              'next launch — otherwise every launch re-downloads 25-55 MB.',
        );
        expect(cached!.version, 3);
        expect(cached.vocabContent, contains('smör'));
      },
    );
  });

  group('throttle-on-failure hook (background-family default)', () {
    test('LC: a FAILED download arms the 12h throttle — the second attempt '
        'never reaches Storage', () async {
      // Unregistered version → fail-closed refusal. Unlike whisper (whose
      // user-initiated downloads must stay retryable — pinned in
      // whisper_model_manager_test.dart), the parsing families back off.
      await mockStorage
          .ref('models/line_classifier/latest_version.txt')
          .putData(Uint8List.fromList(utf8.encode('999')));
      await mockStorage
          .ref('models/line_classifier/v999/model.onnx')
          .putData(Uint8List.fromList(utf8.encode('arbitrary-bytes')));
      await mockStorage
          .ref('models/line_classifier/v999/vocab.txt')
          .putData(Uint8List.fromList(utf8.encode('vocab')));

      final counting = _CountingStorage(delegate: mockStorage);
      final manager = _TestLineClassifierModelManager(
        storage: counting,
        cacheDir: tempDir,
      );

      expect(await manager.ensureModelAvailable(), isNull);
      final refsAfterFirst = counting.refCalls;
      expect(refsAfterFirst, greaterThan(0));

      expect(await manager.ensureModelAvailable(), isNull);
      expect(
        counting.refCalls,
        refsAfterFirst,
        reason:
            'Parsing-model downloads are background-initiated: a failure '
            'must arm the check throttle so a Storage outage is not '
            'hammered on every parse.',
      );
    });
  });
}

class _TestNerModelManager extends NerModelManager {
  final Directory _testCacheDir;
  final Map<int, String>? _registry;

  _TestNerModelManager({
    required FirebaseStorage storage,
    required Directory cacheDir,
    Map<int, String>? registry,
  }) : _testCacheDir = cacheDir,
       _registry = registry,
       super(storage: storage);

  @override
  Future<Directory> getCacheDir() async => _testCacheDir;

  /// The production registry holds real-model hashes, so the happy path is
  /// unreachable with staged bytes unless the test provides its own entry.
  @override
  Map<int, String> get hashRegistry => _registry ?? super.hashRegistry;
}

class _TestLineClassifierModelManager extends LineClassifierModelManager {
  final Directory _testCacheDir;

  _TestLineClassifierModelManager({
    required FirebaseStorage storage,
    required Directory cacheDir,
  }) : _testCacheDir = cacheDir,
       super(storage: storage);

  @override
  Future<Directory> getCacheDir() async => _testCacheDir;
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
