/// Typed exception for Firebase Storage upload failures so the UI can
/// surface targeted error copy (quota full, unauthorized, canceled) instead
/// of a generic "Upload failed."
///
/// Filed by BUT-971. Repositories that wrap Firebase Storage SDK calls
/// throw this on `FirebaseException`s with storage-domain codes; the
/// upload-service classifier maps the [code] to [ImageUploadErrorType].
class StorageUploadException implements Exception {
  /// The original Firebase Storage error code, e.g. `quota-exceeded`,
  /// `unauthorized`, `canceled`. Stripped of the `storage/` prefix the
  /// underlying SDK adds — callers should match on the bare code.
  final String code;

  /// Human-readable detail copied from the wrapped FirebaseException.
  /// Logged for observability; NOT user-facing on its own (the upload
  /// service maps [code] to localized copy).
  final String message;

  const StorageUploadException(this.code, this.message);

  /// Quota / storage limit hit on the Firebase project or per-user limit.
  bool get isQuotaExceeded => code == 'quota-exceeded';

  /// Permission failure — typically a storage rules deny or auth gap.
  bool get isUnauthorized =>
      code == 'unauthorized' || code == 'unauthenticated';

  /// User-initiated or system-initiated cancellation mid-upload.
  bool get isCanceled => code == 'canceled' || code == 'cancelled';

  /// Network-domain failure surfaced by the SDK — either no connectivity,
  /// the retry budget was exhausted, or the request hit a server-side
  /// failure category that's user-retryable. UX treats all three the same:
  /// "check your connection and tap retry."
  bool get isNetworkError =>
      code == 'retry-limit-exceeded' ||
      code == 'server-file-wrong-size' ||
      code == 'network-request-failed';

  @override
  String toString() => 'StorageUploadException($code): $message';
}
