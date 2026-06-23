// lib/repositories/interfaces/deeplink_repository.dart

/// Repository interface for deep link operations
abstract class DeepLinkRepository {
  /// Create a short URL mapping
  Future<String> createShortUrl(String longUrl, Map<String, dynamic> metadata);

  /// Get the long URL from a short URL
  Future<String?> getLongUrl(String shortUrl);

  /// Track URL click/usage
  Future<void> trackUrlClick(String shortUrl);

  /// Store deep link metadata
  Future<void> storeDeepLinkMetadata(
    String linkId,
    Map<String, dynamic> metadata,
  );

  /// Retrieve deep link metadata
  Future<Map<String, dynamic>?> getDeepLinkMetadata(String linkId);

  /// Delete expired links
  Future<void> deleteExpiredLinks(DateTime before);
}
