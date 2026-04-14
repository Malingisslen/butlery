/// Shared HTTP constants for web scraping and content fetching.
abstract final class HttpConstants {
  /// Desktop Chrome UA — used by headless WebView extraction.
  static const desktopUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.0.0 Safari/537.36';

  /// Mobile Safari UA — used by HTTP fetcher; some recipe sites
  /// serve simpler HTML to mobile clients.
  static const mobileUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_6_1 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1';

  /// Swedish-preferred Accept-Language for recipe content.
  static const acceptLanguage = 'sv-SE,sv;q=0.9,en-US;q=0.8,en;q=0.7';
}
