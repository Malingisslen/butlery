/// BUT-1238: integrity wiring for `RemoteWeightLoader`.
///
/// Pure-function coverage of `verifyOnnxBytes` lives in
/// `expected_model_hashes_test.dart`; the manager equivalents live in
/// `model_manager_integrity_test.dart`. This file proves the CRF loader
/// honours the same fail-close contract: downloaded weight JSON whose
/// SHA-256 is absent from / mismatches `kExpectedCrfWeightHashes` is
/// refused BEFORE `CrfWeights.fromJson` runs or anything is cached — the
/// bundled weights (rule-based fallback path) keep parsing.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/parsing/crf/remote_weight_loader.dart';

/// Minimal JSON that `CrfWeights.fromJson` accepts — proves the happy path
/// reaches parsing only after verification.
const _validWeightsJson =
    '{"features":{"B-NAME":{"w":1.0}},"transitions":{"B-NAME":{"O":0.5}}}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('but1238_crf_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('RemoteWeightLoader fail-close integrity (BUT-1238)', () {
    test('production registry is empty → any published weights are refused '
        'and nothing is cached', () async {
      // No registry override: exercises the real (committed, currently
      // empty) kExpectedCrfWeightHashes. If this test starts failing
      // because the registry gained an entry, stage a version NOT in the
      // registry instead — the refusal contract is what is pinned.
      final loader = _TestRemoteWeightLoader(
        storage: _FakeWeightsStorage(
          _FakeWeightsReference(
            version: 2,
            bytes: Uint8List.fromList(utf8.encode(_validWeightsJson)),
          ),
        ),
        cacheDir: tempDir,
      );

      final parser = await loader.tryLoadRemoteWeights(bundledVersion: 1);

      expect(
        parser,
        isNull,
        reason:
            'Empty registry must refuse every download (fail-close) — '
            'the bundled CRF weights keep parsing.',
      );
      expect(
        tempDir.listSync(recursive: true).whereType<File>(),
        isEmpty,
        reason: 'Refused bytes never touch disk.',
      );
    });

    test('version absent from a non-empty registry is refused', () async {
      final loader = _TestRemoteWeightLoader(
        storage: _FakeWeightsStorage(
          _FakeWeightsReference(
            version: 3,
            bytes: Uint8List.fromList(utf8.encode(_validWeightsJson)),
          ),
        ),
        cacheDir: tempDir,
        registry: {2: sha256.convert(utf8.encode('other')).toString()},
      );

      final parser = await loader.tryLoadRemoteWeights(bundledVersion: 1);

      expect(
        parser,
        isNull,
        reason:
            'Unregistered version must be refused — publishing new '
            'weights requires a registry entry in the same PR.',
      );
      expect(tempDir.listSync(recursive: true).whereType<File>(), isEmpty);
    });

    test('hash mismatch is refused and nothing is cached', () async {
      final tampered = Uint8List.fromList(
        utf8.encode('{"features":{},"transitions":{}}'),
      );
      final loader = _TestRemoteWeightLoader(
        storage: _FakeWeightsStorage(
          _FakeWeightsReference(version: 2, bytes: tampered),
        ),
        cacheDir: tempDir,
        registry: {
          2: sha256.convert(utf8.encode(_validWeightsJson)).toString(),
        },
      );

      final parser = await loader.tryLoadRemoteWeights(bundledVersion: 1);

      expect(
        parser,
        isNull,
        reason:
            'Tampered bytes (hash mismatch) must be refused before '
            'CrfWeights.fromJson or any disk write.',
      );
      expect(
        tempDir.listSync(recursive: true).whereType<File>(),
        isEmpty,
        reason: 'Mismatched bytes never touch disk.',
      );
    });

    test(
      'matching hash loads the parser and caches weights + version',
      () async {
        final bytes = Uint8List.fromList(utf8.encode(_validWeightsJson));
        final loader = _TestRemoteWeightLoader(
          storage: _FakeWeightsStorage(
            _FakeWeightsReference(version: 2, bytes: bytes),
          ),
          cacheDir: tempDir,
          registry: {2: sha256.convert(bytes).toString()},
        );

        final parser = await loader.tryLoadRemoteWeights(bundledVersion: 1);

        expect(
          parser,
          isNotNull,
          reason: 'Registered + matching hash is the only path that loads.',
        );
        final cached = tempDir
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .toSet();
        expect(
          cached,
          contains('crf_remote_weights.json'),
          reason: 'Verified weights are cached for offline use.',
        );
        expect(cached, contains('crf_remote_version.txt'));
      },
    );
  });
}

class _TestRemoteWeightLoader extends RemoteWeightLoader {
  final Directory _testCacheDir;
  final Map<int, String>? _registry;

  _TestRemoteWeightLoader({
    required FirebaseStorage storage,
    required Directory cacheDir,
    Map<int, String>? registry,
  }) : _testCacheDir = cacheDir,
       _registry = registry,
       super(storage: storage);

  @override
  Future<Directory> getCacheDir() async => _testCacheDir;

  @override
  Map<int, String> get weightHashRegistry =>
      _registry ?? super.weightHashRegistry;
}

/// Serves controlled metadata + bytes for `models/crf_ingredient_weights.json`
/// — `firebase_storage_mocks` doesn't surface customMetadata through
/// `getMetadata()`, so the loader's version gate needs a hand-rolled Fake
/// (same approach as `_ThrowingPathStorage` in
/// `model_manager_integrity_test.dart`).
class _FakeWeightsReference extends Fake implements Reference {
  final int version;
  final Uint8List? bytes;

  _FakeWeightsReference({required this.version, required this.bytes});

  @override
  Future<FullMetadata> getMetadata() async => FullMetadata({
    'customMetadata': {'version': '$version'},
  });

  @override
  Future<Uint8List?> getData([int maxSize = 10485760]) async => bytes;
}

class _FakeWeightsStorage extends Fake implements FirebaseStorage {
  final Reference _ref;

  _FakeWeightsStorage(this._ref);

  @override
  Reference ref([String? path]) => _ref;
}
