// lib/repositories/interfaces/deeplink_repository.dart

/// Repository interface for deep link operations
abstract class DeepLinkRepository {
  /// Create a short URL mapping
  Future<String> createShortUrl(String longUrl, Map<String, dynamic> metadata);

  /// Get the long URL from a short URL
  Future<String?> getLongUrl(String shortUrl);
}
