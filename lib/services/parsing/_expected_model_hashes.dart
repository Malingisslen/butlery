import 'package:crypto/crypto.dart';

// BUT-792: integrity hashes for ONNX models downloaded from Firebase Storage.
//
// Each model version below maps to the SHA-256 of the exact `model.onnx`
// bytes shipped to production. The hash is verified after download in the
// model manager — a mismatch means either an attacker swapped the file at
// rest, a TLS MITM corrupted the bytes during transport, or someone
// replaced a published version (which is itself a process violation).
//
// **When publishing a new model version:**
// 1. Build the .onnx, then compute its hash:
//    ```bash
//    shasum -a 256 model.onnx
//    # OR (Windows): certutil -hashfile model.onnx SHA256
//    ```
// 2. Upload `model.onnx` to Firebase Storage at the new
//    `models/<family>/v<N>/` path.
// 3. Add the version → SHA-256 entry to the matching map below in the
//    same PR. CI does not have model-bytes access so this is a manual gate.
// 4. Bump `latest_version.txt` in Storage so clients pull the new version.
//
// **Transitional rollout:**
// If the version downloaded has no matching entry below, the manager logs a
// warning + emits a Crashlytics non-fatal but allows the load to proceed.
// This avoids locking out existing users on the first deploy of this guard.
// Once a hash is added, mismatch becomes a hard failure for that version.

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
};

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
  /// True when the bytes are safe to write to disk (either matched or no
  /// hash registered for this version yet).
  final bool ok;

  /// Computed SHA-256 of the bytes (hex). Always populated.
  final String actualHash;

  /// Set when [ok] is false — the registered hash that didn't match.
  final String? expectedHash;

  /// Set when [ok] is true and no hash was registered for the version.
  /// Callers should emit a non-fatal Crashlytics event so the gap is
  /// visible in the field.
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
  }) =>
      ModelIntegrityResult._(
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
