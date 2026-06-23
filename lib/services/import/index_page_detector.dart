import 'package:butlery/services/import/cache/url_normalizer.dart';

/// BUT-1273: detects recipe-index / listing pages and harvests the individual
/// recipe links from them, so a single pasted "collection" URL can be expanded
/// into a multi-URL import batch.
///
/// Pure-compute (no async, no Firebase) — a documented `BaseService` non-adopter
/// like [HtmlUtilities]. HTML scanning is regex-based to match the rest of the
/// import pipeline (no `html` package dependency); URL host comparison and
/// dedup reuse [UrlNormalizer] so `www.`/non-`www.` canonicals and tracking-param
/// variants of the same recipe collapse to one entry.
class IndexPageDetector {
  IndexPageDetector._();

  /// Maximum links returned from a single index page. Mirrors the batch
  /// fetcher's sequential, one-at-a-time cost/rate-limit posture (BUT-947) — an
  /// accidental harvest of a huge nav tree never fans out into hundreds of
  /// fetches.
  static const int maxLinks = 50;

  /// Default minimum recipe-like links before a page is treated as an index.
  /// Conservative on purpose: detection only ever *offers* expansion (opt-in
  /// banner), so the cost of a missed index page is low while a false positive
  /// on every ordinary recipe page would be noisy.
  static const int defaultMinLinks = 5;

  static final RegExp _anchorHref = RegExp(
    '''<a\\s[^>]*?href\\s*=\\s*["']([^"']+)["']''',
    caseSensitive: false,
  );

  /// Path segments that are navigation/utility, never an individual recipe.
  /// Bilingual (English + Swedish) to match the app's audience.
  static const Set<String> _utilitySegments = {
    'login',
    'signin',
    'sign-in',
    'signup',
    'sign-up',
    'register',
    'account',
    'konto',
    'cart',
    'varukorg',
    'checkout',
    'kassa',
    'about',
    'om-oss',
    'om',
    'contact',
    'kontakt',
    'privacy',
    'integritet',
    'terms',
    'villkor',
    'search',
    'sok',
    'sök',
    'tag',
    'tags',
    'taggar',
    'category',
    'categories',
    'kategori',
    'kategorier',
    'author',
    'forfattare',
    'newsletter',
    'nyhetsbrev',
    'subscribe',
    'prenumerera',
    'faq',
    'cookies',
  };

  /// Harvests candidate individual-recipe links from a listing page's [html].
  ///
  /// Keeps only same-host http(s) links whose final path segment looks like a
  /// content slug (long, hyphenated, or digit-bearing), drops navigation/utility
  /// paths and the listing URL itself, de-duplicates while preserving order, and
  /// caps the result at [maxLinks]. Relative hrefs are resolved against
  /// [baseUrl].
  static List<String> extractRecipeLinks(
    String html, {
    required String baseUrl,
  }) {
    final base = Uri.tryParse(baseUrl);
    if (base == null || !base.hasAuthority) return const [];

    final normalizer = UrlNormalizer();
    final baseDomain = normalizer.extractDomain(baseUrl);
    if (baseDomain == null) return const [];
    final baseKey = normalizer.normalize(baseUrl);

    final seen = <String>{};
    final links = <String>[];

    for (final match in _anchorHref.allMatches(html)) {
      final rawHref = match.group(1)!.trim();
      if (rawHref.isEmpty || rawHref.startsWith('#')) continue;

      final resolved = _resolve(base, rawHref);
      if (resolved == null) continue;
      if (resolved.scheme != 'http' && resolved.scheme != 'https') continue;

      final resolvedStr = resolved.toString();
      // Compare registrable host with www. stripped so a www. base still
      // matches the page's non-www. canonical links (and vice versa).
      if (normalizer.extractDomain(resolvedStr) != baseDomain) continue;
      if (!_looksLikeRecipeSlug(resolved)) continue;

      // Normalized key collapses www./tracking-param/fragment/trailing-slash
      // variants of the same recipe to one entry.
      final key = normalizer.normalize(resolvedStr);
      if (key == null || key == baseKey) continue;

      if (seen.add(key)) {
        links.add(key);
        if (links.length >= maxLinks) break;
      }
    }

    return links;
  }

  static Uri? _resolve(Uri base, String href) {
    try {
      return base.resolve(href);
    } catch (_) {
      return null;
    }
  }

  /// Heuristic: an individual recipe URL has a descriptive final path segment
  /// (a slug) rather than a short top-level nav target. Filters most header/
  /// footer chrome without a brittle site-specific allowlist.
  static bool _looksLikeRecipeSlug(Uri uri) {
    final segments = uri.pathSegments
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) return false;

    for (final segment in segments) {
      if (_utilitySegments.contains(segment.toLowerCase())) return false;
    }

    final last = segments.last.toLowerCase();
    final hasHyphen = last.contains('-');
    final hasDigit = last.contains(RegExp(r'\d'));
    final isLong = last.length >= 8;

    // A slug is long, or hyphenated, or carries an id-like digit — plain short
    // nav segments ("recept", "om") satisfy none of these.
    return hasHyphen || hasDigit || isLong;
  }
}
