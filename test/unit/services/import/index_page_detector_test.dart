import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/index_page_detector.dart';

/// BUT-1273: pure-unit coverage for recipe-index detection + link harvesting.
/// Intent: prove the detector turns a listing page's HTML into the set of
/// individual same-site recipe URLs a batch import should fetch — and that it
/// does NOT misfire on an ordinary recipe page's navigation chrome.
void main() {
  const base = 'https://recept.example.se/recept';

  String anchors(Iterable<String> hrefs) =>
      hrefs.map((h) => '<a href="$h">link</a>').join('\n');

  group('extractRecipeLinks', () {
    test('harvests same-host slug links from a listing page', () {
      final html = anchors([
        '/recept/kycklinggryta-med-curry',
        '/recept/vegetarisk-lasagne',
        'https://recept.example.se/recept/pannkakor-grundrecept',
      ]);

      final links = IndexPageDetector.extractRecipeLinks(html, baseUrl: base);

      expect(links, [
        'https://recept.example.se/recept/kycklinggryta-med-curry',
        'https://recept.example.se/recept/vegetarisk-lasagne',
        'https://recept.example.se/recept/pannkakor-grundrecept',
      ]);
    });

    test('resolves relative hrefs against the base URL (RFC 3986)', () {
      // Base has no trailing slash, so per RFC 3986 a bare relative segment
      // replaces the last path segment ("recept") — identical to browser
      // resolution. A directory-style base (".../recept/") would keep it nested.
      final html = anchors(['kycklinggryta-med-curry', 'recept/lax-i-ugn']);

      final links = IndexPageDetector.extractRecipeLinks(html, baseUrl: base);

      expect(links, [
        'https://recept.example.se/kycklinggryta-med-curry',
        'https://recept.example.se/recept/lax-i-ugn',
      ]);
    });

    test('drops off-site links (ads, social, other domains)', () {
      final html = anchors([
        '/recept/kycklinggryta-med-curry',
        'https://facebook.com/some-long-share-link',
        'https://evil.example.com/recept/stulet-recept',
      ]);

      final links = IndexPageDetector.extractRecipeLinks(html, baseUrl: base);

      expect(links, [
        'https://recept.example.se/recept/kycklinggryta-med-curry',
      ]);
    });

    test('drops navigation/utility paths even when same-host', () {
      final html = anchors([
        '/recept/kycklinggryta-med-curry',
        '/om-oss',
        '/kategori/middag',
        '/login',
        '/sok?q=kyckling',
      ]);

      final links = IndexPageDetector.extractRecipeLinks(html, baseUrl: base);

      expect(links, [
        'https://recept.example.se/recept/kycklinggryta-med-curry',
      ]);
    });

    test('drops short top-level nav segments that are not slugs', () {
      // "recept" and "om" satisfy none of slug/hyphen/digit/long → excluded.
      final html = anchors(['/recept', '/om', '/recept/lax-i-ugn']);

      final links = IndexPageDetector.extractRecipeLinks(html, baseUrl: base);

      expect(links, ['https://recept.example.se/recept/lax-i-ugn']);
    });

    test(
      'de-duplicates links differing only by trailing slash or fragment',
      () {
        final html = anchors([
          '/recept/lax-i-ugn',
          '/recept/lax-i-ugn/',
          '/recept/lax-i-ugn#tips',
        ]);

        final links = IndexPageDetector.extractRecipeLinks(html, baseUrl: base);

        expect(links, ['https://recept.example.se/recept/lax-i-ugn']);
      },
    );

    test('excludes the listing URL itself', () {
      final html = anchors(['/recept', '/recept/lax-i-ugn-med-citron']);

      final links = IndexPageDetector.extractRecipeLinks(html, baseUrl: base);

      expect(links, ['https://recept.example.se/recept/lax-i-ugn-med-citron']);
    });

    test('caps the harvest at maxLinks for cost safety', () {
      final many = List.generate(80, (i) => '/recept/ratt-nummer-$i');
      final html = anchors(many);

      final links = IndexPageDetector.extractRecipeLinks(html, baseUrl: base);

      expect(links.length, IndexPageDetector.maxLinks);
    });

    test('returns empty for a malformed base URL', () {
      final links = IndexPageDetector.extractRecipeLinks(
        anchors(['/recept/lax-i-ugn']),
        baseUrl: 'not a url',
      );

      expect(links, isEmpty);
    });

    test('matches non-www canonical links against a www base host', () {
      // Swedish sites often emit www-less canonical hrefs while the user pastes
      // the www. form. Both must be treated as the same host (UrlNormalizer).
      const wwwBase = 'https://www.ica.se/recept';
      final html = anchors([
        'https://ica.se/recept/kyckling-med-ris',
        '/recept/lax-i-ugn-med-citron',
      ]);

      final links = IndexPageDetector.extractRecipeLinks(
        html,
        baseUrl: wwwBase,
      );

      expect(links, contains('https://ica.se/recept/kyckling-med-ris'));
      expect(links, contains('https://ica.se/recept/lax-i-ugn-med-citron'));
    });

    test('collapses tracking-param variants of the same recipe', () {
      final html = anchors([
        '/recept/lax-i-ugn-med-citron',
        '/recept/lax-i-ugn-med-citron?utm_source=newsletter',
      ]);

      final links = IndexPageDetector.extractRecipeLinks(html, baseUrl: base);

      expect(links, [
        'https://recept.example.se/recept/lax-i-ugn-med-citron',
      ], reason: 'a utm_* variant is the same recipe — dedup to one entry');
    });
  });
}
