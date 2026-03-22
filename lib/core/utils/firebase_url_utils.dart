/// Utilities for normalizing Firebase Storage URLs.
class FirebaseUrlUtils {
  FirebaseUrlUtils._();

  /// Returns a stable cache key by stripping query parameters from a Firebase
  /// Storage signed URL. The auth tokens (`GoogleAccessId`, `Expires`,
  /// `Signature`) rotate hourly, so using the raw URL as a disk-cache key
  /// causes the same image to be re-downloaded every hour.
  static String stableCacheKey(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    // Firebase Storage URLs only use query params for auth tokens.
    // Stripping them gives us a deterministic, rotation-proof key.
    return uri.replace(queryParameters: {}).toString();
  }
}
