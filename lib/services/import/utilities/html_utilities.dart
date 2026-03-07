/// Utility functions for processing HTML content during recipe import.
class HtmlUtilities {
  HtmlUtilities._();

  /// Extracts page title from HTML using og:title, <title>, or <h1>.
  static String? extractTitleFromHtml(String html) {
    final ogTitleMatch = RegExp(
      r'<meta[^>]+property="og:title"[^>]+content="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (ogTitleMatch != null) {
      return cleanTitle(ogTitleMatch.group(1)!);
    }

    final ogTitleMatchSingle = RegExp(
      "<meta[^>]+property='og:title'[^>]+content='([^']+)'",
      caseSensitive: false,
    ).firstMatch(html);
    if (ogTitleMatchSingle != null) {
      return cleanTitle(ogTitleMatchSingle.group(1)!);
    }

    final titleMatch = RegExp(
      r'<title[^>]*>([^<]+)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    if (titleMatch != null) {
      return cleanTitle(titleMatch.group(1)!);
    }

    final h1Match = RegExp(
      r'<h1[^>]*>([^<]+)</h1>',
      caseSensitive: false,
    ).firstMatch(html);
    if (h1Match != null) {
      return cleanTitle(h1Match.group(1)!);
    }

    return null;
  }

  /// Cleans title by removing site name suffixes and normalizing whitespace.
  static String cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'\s*[-|]\s*.*$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
