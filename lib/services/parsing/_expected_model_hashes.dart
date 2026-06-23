import 'package:crypto/crypto.dart';

// BUT-792: integrity hashes for ONNX models downloaded from Firebase Storage.
//
// Each model version below maps to the SHA-256 of the exact `model.onnx`
// bytes shipped to production. The hash is verified after download in the
// model manager — a mismatch means either an attacker swapped the file at
// rest, a TLS MITM corrupted the bytes during transport, or someone
// replaced a published version (which is itself a process violation).
//
// **When publishing a new model version (every step MANDATORY):**
// 1. Build the .onnx, then compute its hash:
//    ```bash
//    shasum -a 256 model.onnx
//    # OR (Windows): certutil -hashfile model.onnx SHA256
//    ```
// 2. Add the version → SHA-256 entry to the matching map below — in the
//    SAME PR as the Storage upload. CI does not have model-bytes access so
//    this is a manual gate; a forgotten entry bricks the new version (see
//    fail-close contract below), it does not silently ship unverified.
// 3. Upload `model.onnx` to Firebase Storage at the new
//    `models/<family>/v<N>/` path.
// 4. Ship the client release containing the new registry entry.
// 5. Bump `latest_version.txt` in Storage so clients pull the new version
//    (only after the client with the entry is out — older clients refuse
//    versions they have no hash for).
//
// **Fail-close contract (BUT-877, supersedes the BUT-876 transitional
// soft-allow):**
// A downloaded version with no matching entry below is REFUSED — the
// manager logs a Crashlytics non-fatal and aborts before any disk write,
// exactly like a hash mismatch. An empty registry refuses everything.
// The parser then falls back gracefully (rule-based classifier / LLM
// tier); it is never stranded without a parsing path.
//
// SCOPE: the contract covers all three Storage→parser inputs — the two
// ONNX loaders and the CRF weight JSON (RemoteWeightLoader, BUT-1238).

/// SHA-256 hashes of the BERT NER ONNX model, keyed by Firebase Storage
/// version directory (`models/ingredient_ner/v{N}/model.onnx`).
const Map<int, String> kExpectedNerModelHashes = <int, String>{
  // BUT-822: hash captured 2026-05-19 from the production
  // `models/ingredient_ner/v1/model.onnx` bytes via Firebase Storage
  // signed-URL download (size: 20,654,344 B).
  1: 'f4f81738b25278c77c2aa9ba0a40128dcb67700da2685ea0e5fe510a33a1fe1c',
};

/// SHA-256 hashes of the line-classifier ONNX model, keyed by Firebase
/// Storage version directory (`models/line_classifier/v{N}/model.onnx`).
const Map<int, String> kExpectedLineClassifierModelHashes = <int, String>{
  // BUT-822: hash captured 2026-05-19 from the production
  // `models/line_classifier/v1/model.onnx` bytes via Firebase Storage
  // signed-URL download (size: 20,754,122 B). Matches local
  // `scripts/line_classifier/output/onnx/model.onnx` exactly.
  1: 'd155becda1cf586d9e1ee86fac6e81c5f999404aa8741d0f1a9223ec5f57f085',
  // BUT-1355: hash captured 2026-06-22 from the production
  // `models/line_classifier/v2/model.onnx` bytes (size: 20,754,122 B).
  // v2 is the "expand golden dataset and retrain" model (commit f0a769027,
  // 2026-03-05) that was deliberately set as latest_version.txt=2. The app
  // had been accidentally pinned to v1 (BUT-822 hashed v1 without noticing
  // latest already pointed at v2), so clients were fail-closing on v2 and
  // falling back to the slower rule-based classifier. Adopting v2 as the
  // trusted live model per Malin's decision (2026-06-22).
  2: 'c38c95211632f93dd548fd742fcb71a56acbeda53220cc7394a6a3920bfd53b5',
};

/// SHA-256 hashes of the CRF ingredient-weight JSON, keyed by the `version`
/// custom-metadata integer on `models/crf_ingredient_weights.json`.
///
/// BUT-1238: empty because no remote weights have ever been published —
/// verified 2026-06-11 via Firebase Storage (404 on the object path). The
/// retraining Cloud Function publishing a first version MUST land its hash
/// here in the same PR as the upload, or every client refuses the download
/// (empty/absent registry fail-closes; the bundled weights keep parsing).
const Map<int, String> kExpectedCrfWeightHashes = <int, String>{};

/// Thrown when a downloaded ONNX model fails its SHA-256 integrity check.
/// Caller is expected to delete the cached file and treat the model as
/// unavailable for this session.
class ModelIntegrityCheckFailure implements Exception {
  final String modelName;
  final int version;
  final String expected;
  final String actual;

  const ModelIntegrityCheckFailure({
    required this.modelName,
    required this.version,
    required this.expected,
    required this.actual,
  });

  @override
  String toString() =>
      'ModelIntegrityCheckFailure: $modelName v$version hash mismatch '
      '(expected $expected, got $actual)';
}

/// Result of a SHA-256 integrity check on downloaded ONNX bytes.
/// Pure data — easy to unit-test without touching Firebase Storage.
class ModelIntegrityResult {
  /// True when the computed hash matched a registry entry, OR when no
  /// entry existed ([unverified] = true). NOTE: since BUT-877 the loader
  /// treats unverified as a refusal — check [unverified] before [ok].
  final bool ok;

  /// Computed SHA-256 of the bytes (hex). Always populated.
  final String actualHash;

  /// Set when [ok] is false — the registered hash that didn't match.
  final String? expectedHash;

  /// Set when no hash was registered for the version. Fail-close
  /// (BUT-877): callers must refuse the load and emit a non-fatal
  /// Crashlytics event so the missing registry entry is visible.
  final bool unverified;

  const ModelIntegrityResult._({
    required this.ok,
    required this.actualHash,
    this.expectedHash,
    this.unverified = false,
  });

  factory ModelIntegrityResult.match(String hash) =>
      ModelIntegrityResult._(ok: true, actualHash: hash);

  factory ModelIntegrityResult.mismatch({
    required String actual,
    required String expected,
  }) => ModelIntegrityResult._(
    ok: false,
    actualHash: actual,
    expectedHash: expected,
  );

  factory ModelIntegrityResult.unverified(String hash) =>
      ModelIntegrityResult._(
        ok: true,
        actualHash: hash,
        unverified: true,
      );
}

/// Verify [modelBytes] against the registered SHA-256 for [version] in
/// [hashRegistry]. Pure function — model managers and unit tests both call it.
ModelIntegrityResult verifyOnnxBytes({
  required List<int> modelBytes,
  required int version,
  required Map<int, String> hashRegistry,
}) {
  final actual = sha256.convert(modelBytes).toString();
  final expected = hashRegistry[version];

  if (expected == null) {
    return ModelIntegrityResult.unverified(actual);
  }
  if (actual == expected) {
    return ModelIntegrityResult.match(actual);
  }
  return ModelIntegrityResult.mismatch(actual: actual, expected: expected);
}
