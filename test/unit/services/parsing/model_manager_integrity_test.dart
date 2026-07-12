/// BUT-823: Integration tests for `_verifyModelIntegrity` short-circuit.
///
/// Pure-function coverage of `verifyModelBytes` already lives in
/// `expected_model_hashes_test.dart`. This file proves the **wiring** — that
/// `NerModelManager._downloadModel` and `LineClassifierModelManager._downloadModel`
/// abort BEFORE any disk write when the SHA-256 of the downloaded bytes does
/// not match the registered hash for the requested version.
///
/// Test strategy: a thin test subclass overrides `getCacheDir` to a temp dir,
/// `firebase_storage_mocks` returns bytes whose hash will not match
/// `kExpectedNerModelHashes[1]` / `kExpectedLineClassifierModelHashes[1]`.
/// We then assert `ensureModelAvailable()` returns null AND no `.tmp` files
/// remain in the cache directory.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/parsing/line_classifier/line_classifier_model_manager.dart';
import 'package:butlery/services/parsing/ner/ner_model_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NerModelManager integrity short-circuit (BUT-823)', () {
    late Directory tempDir;
    late MockFirebaseStorage mockStorage;
    late _TestNerModelManager manager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('but823_ner_');
      mockStorage = MockFirebaseStorage();
      manager = _TestNerModelManager(storage: mockStorage, cacheDir: tempDir);
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test(
      'mismatched bytes leave no .tmp file in cache dir and return null',
      () async {
        // Pre-stage Storage with bytes that will NOT hash to
        // kExpectedNerModelHashes[1]. The registered hash is for a 20-MB ONNX
        // blob; arbitrary placeholder bytes can never collide.
        final tamperedModel = Uint8List.fromList(
          utf8.encode('tampered-ner-bytes'),
        );
        await mockStorage
            .ref('models/ingredient_ner/latest_version.txt')
            .putData(Uint8List.fromList(utf8.encode('1')));
        await mockStorage
            .ref('models/ingredient_ner/v1/model.onnx')
            .putData(tamperedModel);
        await mockStorage
            .ref('models/ingredient_ner/v1/vocab.txt')
            .putData(Uint8List.fromList(utf8.encode('vocab')));

        final result = await manager.ensureModelAvailable();

        expect(
          result,
          isNull,
          reason:
              'Mismatched SHA-256 must short-circuit ensureModelAvailable() '
              'so the caller treats the model as unavailable for this session.',
        );

        final tmpArtifacts = tempDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.tmp'))
            .toList();
        expect(
          tmpArtifacts,
          isEmpty,
          reason:
              'BUT-792 security claim: tampered bytes never touch disk — no '
              '.tmp files should be produced by the aborted download.',
        );

        // And no committed files either (the .tmp → rename happens later in
        // _downloadModel; verifying the cache stays empty doubles as a
        // regression test on the order of operations).
        final committed = tempDir
            .listSync(recursive: true)
            .whereType<File>()
            .toList();
        expect(
          committed,
          isEmpty,
          reason:
              'No model artifacts should be committed on integrity '
              'failure.',
        );
      },
    );
  });

  group('NerModelManager error-envelope coverage (BUT-870)', () {
    late Directory tempDir;
    late MockFirebaseStorage mockStorage;
    late _TestNerModelManager manager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('but870_ner_');
      mockStorage = MockFirebaseStorage();
      manager = _TestNerModelManager(storage: mockStorage, cacheDir: tempDir);
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('latest version absent from hash registry refuses the load '
        '(fail-close, BUT-877)', () async {
      // Version 999 is not in `kExpectedNerModelHashes`. Per the fail-close
      // contract in `lib/services/parsing/_expected_model_hashes.dart`, an
      // unregistered version logs a Crashlytics non-fatal and REFUSES the
      // load — identical to a hash mismatch. Publishing a new version
      // requires adding its registry entry in the same PR as the upload.
      // (Supersedes the BUT-876 transitional soft-allow.)
      await mockStorage
          .ref('models/ingredient_ner/latest_version.txt')
          .putData(Uint8List.fromList(utf8.encode('999')));
      await mockStorage
          .ref('models/ingredient_ner/v999/model.onnx')
          .putData(Uint8List.fromList(utf8.encode('arbitrary-bytes')));
      await mockStorage
          .ref('models/ingredient_ner/v999/vocab.txt')
          .putData(Uint8List.fromList(utf8.encode('vocab')));

      final result = await manager.ensureModelAvailable();

      expect(
        result,
        isNull,
        reason:
            'Unregistered version must be refused (verifyModelDownload '
            'returns false on unverified) so the parser falls back to the '
            'rule-based / LLM path instead of running unvetted bytes.',
      );

      final committed = tempDir
          .listSync(recursive: true)
          .whereType<File>()
          .toList();
      expect(
        committed,
        isEmpty,
        reason:
            'Refused unverified bytes never touch disk — no .tmp or '
            'committed artifacts.',
      );
    });

    test(
      'cached load deletes leftover .tmp from prior interrupted write',
      () async {
        // Stage a valid-looking cache + a leftover `.tmp` file from a previous
        // interrupted write. `_tryLoadCached` should return the cached files
        // and clean up the stale `.tmp` (see ner_model_manager.dart:82-83).
        final modelPath = '${tempDir.path}/model.onnx';
        await File(modelPath).writeAsBytes(
          Uint8List.fromList(List<int>.generate(1024, (i) => i & 0xff)),
        );
        await File('${tempDir.path}/vocab.txt').writeAsString('vocab');
        await File('${tempDir.path}/version.txt').writeAsString('1');
        final staleTmp = File('$modelPath.tmp');
        await staleTmp.writeAsBytes(Uint8List.fromList([0xde, 0xad]));
        expect(
          staleTmp.existsSync(),
          isTrue,
          reason: 'Pre-condition: stale .tmp exists before cache load.',
        );

        final result = await manager.ensureModelAvailable();

        expect(
          result,
          isNotNull,
          reason:
              'Valid cache should be returned even with stale .tmp '
              'present.',
        );
        expect(
          staleTmp.existsSync(),
          isFalse,
          reason:
              'Stale .tmp from interrupted prior write must be deleted '
              'as part of cache load.',
        );
      },
    );
  });

  group(
    'NerModelManager transient FirebaseException mid-download (BUT-872)',
    () {
      late Directory tempDir;
      late MockFirebaseStorage mockStorage;
      late _TestNerModelManager manager;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('but872_ner_');
        mockStorage = MockFirebaseStorage();
      });

      tearDown(() async {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      });

      test('transient FirebaseException on model.onnx getData() leaves no '
          '.tmp file and no committed cache files', () async {
        // Stage version metadata + vocab so latestVersion resolves. The
        // throwing-storage wrapper intercepts only model.onnx.
        await mockStorage
            .ref('models/ingredient_ner/latest_version.txt')
            .putData(Uint8List.fromList(utf8.encode('1')));
        await mockStorage
            .ref('models/ingredient_ner/v1/vocab.txt')
            .putData(Uint8List.fromList(utf8.encode('vocab')));

        final throwingStorage = _ThrowingPathStorage(
          delegate: mockStorage,
          throwingPath: 'models/ingredient_ner/v1/model.onnx',
          error: FirebaseException(
            plugin: 'firebase_storage',
            code: 'unavailable',
            message: 'transient backend error',
          ),
        );
        manager = _TestNerModelManager(
          storage: throwingStorage,
          cacheDir: tempDir,
        );

        final result = await manager.ensureModelAvailable();

        expect(
          result,
          isNull,
          reason:
              'Mid-download FirebaseException must short-circuit the '
              'download — the `on FirebaseException catch` block in '
              'ner_model_manager.dart:186 returns null.',
        );

        final committed = tempDir
            .listSync(recursive: true)
            .whereType<File>()
            .toList();
        expect(
          committed,
          isEmpty,
          reason:
              'No files (including .tmp) should land when getData() '
              'throws — the hash + write phase never runs.',
        );
      });
    },
  );

  group('LineClassifierModelManager integrity short-circuit (BUT-823)', () {
    late Directory tempDir;
    late MockFirebaseStorage mockStorage;
    late _TestLineClassifierModelManager manager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('but823_lc_');
      mockStorage = MockFirebaseStorage();
      manager = _TestLineClassifierModelManager(
        storage: mockStorage,
        cacheDir: tempDir,
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test(
      'mismatched bytes leave no .tmp file in cache dir and return null',
      () async {
        final tamperedModel = Uint8List.fromList(
          utf8.encode('tampered-line-classifier-bytes'),
        );
        await mockStorage
            .ref('models/line_classifier/latest_version.txt')
            .putData(Uint8List.fromList(utf8.encode('1')));
        await mockStorage
            .ref('models/line_classifier/v1/model.onnx')
            .putData(tamperedModel);
        await mockStorage
            .ref('models/line_classifier/v1/vocab.txt')
            .putData(Uint8List.fromList(utf8.encode('vocab')));

        final result = await manager.ensureModelAvailable();

        expect(result, isNull);

        final tmpArtifacts = tempDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.tmp'))
            .toList();
        expect(tmpArtifacts, isEmpty);

        final committed = tempDir
            .listSync(recursive: true)
            .whereType<File>()
            .toList();
        expect(committed, isEmpty);
      },
    );
  });

  group('LineClassifierModelManager transient FirebaseException mid-download '
      '(BUT-872)', () {
    late Directory tempDir;
    late MockFirebaseStorage mockStorage;
    late _TestLineClassifierModelManager manager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('but872_lc_');
      mockStorage = MockFirebaseStorage();
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('transient FirebaseException on model.onnx getData() leaves no '
        '.tmp file and no committed cache files', () async {
      await mockStorage
          .ref('models/line_classifier/latest_version.txt')
          .putData(Uint8List.fromList(utf8.encode('1')));
      await mockStorage
          .ref('models/line_classifier/v1/vocab.txt')
          .putData(Uint8List.fromList(utf8.encode('vocab')));

      final throwingStorage = _ThrowingPathStorage(
        delegate: mockStorage,
        throwingPath: 'models/line_classifier/v1/model.onnx',
        error: FirebaseException(
          plugin: 'firebase_storage',
          code: 'unavailable',
          message: 'transient backend error',
        ),
      );
      manager = _TestLineClassifierModelManager(
        storage: throwingStorage,
        cacheDir: tempDir,
      );

      final result = await manager.ensureModelAvailable();

      expect(
        result,
        isNull,
        reason:
            'Mid-download FirebaseException must short-circuit the '
            'download (line_classifier_model_manager.dart:174).',
      );

      final committed = tempDir
          .listSync(recursive: true)
          .whereType<File>()
          .toList();
      expect(
        committed,
        isEmpty,
        reason:
            'No files (including .tmp) should land when getData() '
            'throws.',
      );
    });
  });
}

class _TestNerModelManager extends NerModelManager {
  final Directory _testCacheDir;

  _TestNerModelManager({
    required FirebaseStorage storage,
    required Directory cacheDir,
  }) : _testCacheDir = cacheDir,
       super(storage: storage);

  @override
  Future<Directory> getCacheDir() async => _testCacheDir;
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

/// BUT-872: a Reference that throws on `getData()` — used to simulate a
/// transient Storage failure mid-download. `firebase_storage_mocks` doesn't
/// expose a throw hook, so we wrap one ref in a Fake that delegates nothing
/// and just throws.
class _ThrowingReference extends Fake implements Reference {
  final FirebaseException _error;

  _ThrowingReference(this._error);

  @override
  Future<Uint8List?> getData([int maxSize = 10485760]) async {
    throw _error;
  }
}

/// BUT-872: wraps a `MockFirebaseStorage` and routes ALL calls to it EXCEPT
/// `.ref(throwingPath)`, which returns a [_ThrowingReference]. Lets the test
/// stage `latest_version.txt` + `vocab.txt` normally while triggering the
/// `on FirebaseException catch` branch in `_downloadModel`.
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
