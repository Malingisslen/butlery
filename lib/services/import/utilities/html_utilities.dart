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

  /// The page's og:image as an absolute https URL, or null. Relative paths
  /// resolve against [pageUrl]; plain http is refused because the image is
  /// shown under the page's name as a borrowed photo.
  static String? extractOgImage(String html, String pageUrl) {
    final attr = RegExp(
      '([a-zA-Z:_-]+)\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\')',
    );
    final base = Uri.tryParse(pageUrl);
    if (base == null) return null;
    for (final tag in RegExp(
      r'<meta\b[^>]*>',
      caseSensitive: false,
    ).allMatches(html)) {
      final attrs = <String, String>{
        for (final m in attr.allMatches(tag.group(0)!))
          m.group(1)!.toLowerCase(): m.group(2) ?? m.group(3) ?? '',
      };
      final key = (attrs['property'] ?? attrs['name'])?.toLowerCase();
      if (key != 'og:image' && key != 'og:image:secure_url') continue;
      final raw = attrs['content']?.replaceAll('&amp;', '&').trim();
      if (raw == null || raw.isEmpty) continue;
      final parsed = Uri.tryParse(raw);
      if (parsed == null) continue;
      final resolved = base.resolveUri(parsed);
      if (resolved.scheme == 'https' && resolved.host.isNotEmpty) {
        return resolved.toString();
      }
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
