/// Unit tests for `UrlImportStrategy` — the recipe-import orchestrator.
///
/// Two layers covered:
///
/// 1) **canHandle / validateInput / SSRF gating** — pure logic. Pins:
///    - Only http/https schemes accepted; file://, javascript:, data:, mailto:,
///      ftp:// all rejected (SSRF / XSS surface).
///    - Empty / whitespace / missing-host / non-URL inputs rejected.
///    - Internal hosts (localhost, 127/8, 10/8, 172.16/12, 192.168/16,
///      169.254/16, 0.0.0.0, IPv6 ::1 / fc00::/7 / fe80::/10) rejected even
///      when wrapped in a valid HTTPS URL.
///
/// 2) **`import(url)` multi-tier orchestration** — uses the real
///    `UrlImportStrategy(httpClient: ...)` constructor with `MockClient`.
///    URLs use public-IP hosts (`http://8.8.8.8/...`) so that
///    `InternetAddress.lookup` short-circuits without touching DNS.
///
///    The production `ServiceLocator` is intentionally left uninitialized,
///    which makes `_recipeParser` (Tier 1) and `_llmEnhancement` (Tier 6)
///    return `null` cleanly. We then drive Tiers 2 / 5 / 7 / hard-failure
///    through the HTTP response body.
///
///    Pins:
///    - JSON-LD recipe HTML → Tier 2 (schema.org) success with the right
///      `extraction_method` and recipe content carried through.
///    - Long unstructured HTML (no detectable ingredients/instructions) →
///      Tier 7 (user-assistance) result with `tier: 7` in metadata (BUT-1077:
///      quality gate added so prose-only pages fall through to user-assist
///      rather than becoming a low-quality Tier 5 success). NOT a hard failure.
///    - HTML with detectable recipe structure (ingredients OR instructions) →
///      Tier 5 success with `extraction_method=html_text_parse`.
///    - Tiny HTML body → hard failure carrying `html_fetched=true,
///      html_length=<N>` so the UI can explain "we fetched but found nothing."
///    - HTTP 4xx / 5xx → fetcher returns null → hard failure with
///      `html_fetched=false`.
///    - Non-http(s) scheme reaching `import()` (caller bypassed canHandle):
///      handled gracefully — failure result, no throw, no HTTP send.
///    - Whitespace around the URL is trimmed before fetching.
///    - JSON-LD with missing `recipeIngredient` still succeeds with empty
///      ingredients (extractor degrades; strategy must not crash).
///    - Exception during fetch is swallowed — failure result, no rethrow.
///
/// DNS-rebinding gate (BUT-1078):
///   - `UrlImportStrategy` now accepts a `dnsLookup` ctor seam forwarded to
///     `HttpContentFetcher`, so a hostname that passes the literal-IP SSRF
///     gate but RESOLVES to a private/loopback address can be driven
///     end-to-end. Pinned below: such a host is blocked pre-send.
///
/// Out of scope (no production seam to test cleanly):
///   - Tier 3/4 web-scraper paths (WebScraper requires `flutter_inappwebview`
///     platform code; the existing
///     `test/unit/services/extraction/web_scraper_test.dart` covers it).
///   - ParseEventLogger side effects (Firebase Functions — covered by its
///     own unit test).
///   - ParsedRecipeCache.store (requires production DI registration).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:get_it/get_it.dart';

import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/url_import_strategy.dart';
import 'package:butlery/services/import/fetchers/http_content_fetcher.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';
import 'package:butlery/services/parsing/feedback/import_correction_snapshot.dart';

/// Helper to make ImportValidationMixin testable in isolation.
class _ValidationHelper with ImportValidationMixin {}

/// JSON-LD recipe HTML that the schema.org tier parses cleanly.
String _jsonLdRecipeHtml({
  String title = 'Pannkakor',
  List<String> ingredients = const [
    '3 ägg',
    '5 dl mjölk',
    '3 dl vetemjöl',
    '1 krm salt',
  ],
  List<String> instructions = const [
    'Vispa ihop ägg och mjölk.',
    'Tillsätt mjölet i en stråle.',
    'Stek pannkakor i smör.',
  ],
}) {
  final ingredientsJson = ingredients.map((e) => '"$e"').join(',');
  final instructionsJson = instructions.map((e) => '"$e"').join(',');
  return '''
<!doctype html>
<html lang="sv">
<head>
  <meta charset="utf-8">
  <title>$title</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "$title",
    "recipeIngredient": [$ingredientsJson],
    "recipeInstructions": [$instructionsJson],
    "recipeYield": "4"
  }
  </script>
</head>
<body><h1>$title</h1></body>
</html>
''';
}

/// Long, recipe-free prose — must reach Tier 7 (user assistance).
String _unstructuredHtml() {
  return '''
<!doctype html>
<html><head><title>Random blog</title></head>
<body>
<article>
  <h1>An afternoon at the park</h1>
  <p>The leaves were turning amber and the children laughed under the
  oak tree while their parents watched from a bench, sipping coffee
  out of paper cups and discussing nothing in particular.</p>
  <p>It was the sort of afternoon that one remembers without quite
  knowing why, the kind of afternoon that lives in the corners of
  memory long after the trees have gone bare.</p>
</article>
</body>
</html>
''';
}

http.Response _htmlResponse(String body, {int status = 200}) {
  return http.Response(
    body,
    status,
    headers: {'content-type': 'text/html; charset=utf-8'},
  );
}

/// Build a strategy whose HTTP fetcher is driven by [responder]. URLs in the
/// tests use IP hosts (e.g. `http://8.8.8.8/recipe`) so `InternetAddress.lookup`
/// short-circuits without going to real DNS.
UrlImportStrategy _strategyWith(
  Future<http.Response> Function(http.Request req) responder,
) {
  final client = MockClient((req) async => responder(req));
  return UrlImportStrategy(httpClient: client);
}

void main() {
  // -----------------------------------------------------------------------
  // canHandle / validateInput / SSRF gating
  // -----------------------------------------------------------------------
  group('UrlImportStrategy.canHandle (URL validation + SSRF gate)', () {
    late UrlImportStrategy strategy;

    setUp(() {
      strategy = UrlImportStrategy();
    });

    /// canHandle is the public gate the ImportManager uses to route inputs.
    /// It must accept plain http/https URLs with a real host.
    test('accepts http and https URLs with hosts', () {
      expect(strategy.canHandle('http://example.com/recipe'), isTrue);
      expect(strategy.canHandle('https://www.ica.se/recept/pannkakor'), isTrue);
      expect(
        strategy.canHandle('https://sub.domain.example.com:8080/x?y=z#a'),
        isTrue,
      );
    });

    /// validateInput must be a strict alias of canHandle — they're the same
    /// gate from the caller's perspective. A future refactor that splits
    /// them is the bug this test catches.
    test('validateInput is the same gate as canHandle', () {
      const cases = [
        'https://example.com',
        'file:///etc/passwd',
        '   ',
        'http://localhost/admin',
        'not-a-url',
      ];
      for (final input in cases) {
        expect(
          strategy.validateInput(input),
          strategy.canHandle(input),
          reason: 'validateInput and canHandle must agree for "$input"',
        );
      }
    });

    /// SSRF guard at the routing layer. canHandle must reject internal
    /// hosts so the ImportManager never even dispatches the import.
    /// Defence in depth — `HttpContentFetcher.fetchHtmlWithTimeout` also
    /// blocks.
    test('rejects URLs pointing at internal / private networks', () {
      const blockedUrls = [
        'http://localhost/x',
        'http://127.0.0.1/admin',
        'http://10.0.0.1/internal',
        'http://192.168.1.1/router',
        'http://172.16.5.5/svc',
        'http://169.254.169.254/latest/meta-data', // EC2 metadata
        'http://0.0.0.0/x',
        'http://[::1]/x',
      ];
      for (final url in blockedUrls) {
        expect(
          strategy.canHandle(url),
          isFalse,
          reason: 'SSRF gate must block $url at the canHandle layer',
        );
      }
    });

    /// Non-HTTP schemes must be rejected — `file://` would read local files,
    /// `data:` would inline content, `javascript:` would be XSS. Only
    /// http(s) is safe.
    test(
      'rejects non-http(s) schemes (file/data/javascript/ftp/mailto/ws)',
      () {
        const rejected = [
          'file:///etc/passwd',
          'file:///C:/Windows/System32/drivers/etc/hosts',
          'data:text/html,<script>alert(1)</script>',
          'javascript:alert(1)',
          'ftp://files.example.com/recipe.txt',
          'mailto:chef@example.com',
          'ws://example.com/socket',
        ];
        for (final url in rejected) {
          expect(
            strategy.canHandle(url),
            isFalse,
            reason: 'non-http scheme must be rejected: $url',
          );
        }
      },
    );

    /// Empty / whitespace / no-host inputs are not URLs and must be
    /// rejected before we spend any cycles on them.
    test('rejects empty, whitespace, and host-less inputs', () {
      expect(strategy.canHandle(''), isFalse);
      expect(strategy.canHandle('   '), isFalse);
      expect(strategy.canHandle('http://'), isFalse);
      expect(strategy.canHandle('https://'), isFalse);
      expect(strategy.canHandle('not-a-url'), isFalse);
    });

    /// canHandle must trim before parsing — URLs pasted from chat apps
    /// arrive with surrounding whitespace all the time.
    test('trims whitespace before parsing', () {
      expect(strategy.canHandle('  https://example.com/recipe  '), isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // import(url) — multi-tier orchestration
  // -----------------------------------------------------------------------
  group('UrlImportStrategy.import (orchestration over real HTTP fetcher)', () {
    /// Happy path: Tier 2 fires because Tier 1 (`_recipeParser`) is null
    /// (no prod ServiceLocator) and the body has parseable JSON-LD.
    test('JSON-LD page → success with extraction_method=schema.org and recipe '
        'content carried through', () async {
      final strategy = _strategyWith((req) async {
        expect(req.url.toString(), 'http://8.8.8.8/recipe');
        return _htmlResponse(
          _jsonLdRecipeHtml(
            title: 'Köttbullar',
            ingredients: ['500 g köttfärs', '1 dl mjölk', '1 ägg'],
            instructions: ['Blanda.', 'Forma.', 'Stek.'],
          ),
        );
      });

      final result = await strategy.import('http://8.8.8.8/recipe');

      expect(
        result.isSuccess,
        isTrue,
        reason: 'JSON-LD recipe must yield a success result',
      );
      expect(result.recipe, isNotNull);
      expect(
        result.recipe!.core.title,
        'Köttbullar',
        reason: 'title must round-trip from the JSON-LD `name` field',
      );
      expect(
        result.recipe!.core.ingredients,
        containsAll(['500 g köttfärs', '1 dl mjölk', '1 ägg']),
      );
      expect(result.recipe!.core.instructions, hasLength(3));
      expect(result.recipe!.core.sourceUrl, 'http://8.8.8.8/recipe');
      expect(result.metadata?['strategy'], 'URL Import');
      expect(
        result.metadata?['extraction_method'],
        'schema.org',
        reason:
            'Tier 2 uses the schema.org extractor when Tier 1 is unavailable',
      );
    });

    /// BUT-1077: pure prose (no ingredients, no instructions detectable) must
    /// NOT produce a Tier 5 success — that would present a garbage recipe to
    /// the user. The quality gate in `_tryHtmlTextParse` checks that
    /// `TextImportStrategy` found at least one ingredient OR instruction;
    /// pure blog prose has neither, so Tier 5 returns null and we fall
    /// through to Tier 7 (user-assisted import).
    ///
    /// This pins the chosen product-intent contract: prose-only pages →
    /// user-assistance, NOT a low-quality success-with-warnings.
    test('unstructured prose HTML (no recipe structure) → Tier 7 '
        'user-assistance, NOT a Tier 5 low-quality success', () async {
      final strategy = _strategyWith(
        (req) async => _htmlResponse(_unstructuredHtml()),
      );

      final result = await strategy.import('http://8.8.8.8/blog');

      expect(
        result.needsAssistance,
        isTrue,
        reason:
            'BUT-1077: prose with no ingredients/instructions must fall '
            'through to Tier 7 (user-assisted), not be presented as a recipe',
      );
      expect(result.isSuccess, isFalse);
      expect(result.extractedText, isNotNull);
      expect(result.metadata?['tier'], 7);
    });

    /// BUT-1077: Tier 5 quality gate passes when there IS actual recipe
    /// structure. A page with detectable ingredients or instructions must
    /// still succeed at Tier 5 with `extraction_method=html_text_parse`.
    test('HTML with detectable recipe structure reaches Tier 5 → success with '
        'html_text_parse + quality warning + sourceUrl set', () async {
      // This page has no JSON-LD but has clear ingredient lines with
      // Swedish measurement units that RecipeSectionDetector recognises.
      const recipeHtml = '''
<!doctype html>
<html><head><title>Pannkakor</title></head>
<body>
<h1>Pannkakor</h1>
<h2>Ingredienser</h2>
<ul>
  <li>3 ägg</li>
  <li>5 dl mjölk</li>
  <li>3 dl vetemjöl</li>
  <li>1 krm salt</li>
  <li>2 msk smör</li>
</ul>
<h2>Gör så här</h2>
<ol>
  <li>Vispa ihop ägg och mjölk i en bunke.</li>
  <li>Tillsätt vetemjöl och salt under omrörning tills smeten är slät.</li>
  <li>Hetta upp smör i en stekpanna och stek pannkakor på medelvärme.</li>
</ol>
</body>
</html>
''';

      final strategy = _strategyWith(
        (req) async => _htmlResponse(recipeHtml),
      );

      final result = await strategy.import('http://8.8.8.8/pannkakor');

      expect(
        result.isSuccess,
        isTrue,
        reason: 'page with ingredient/instruction structure must succeed',
      );
      expect(result.recipe, isNotNull);
      expect(
        result.recipe!.core.sourceUrl,
        'http://8.8.8.8/pannkakor',
        reason: 'Tier 5 must stamp the source URL onto the recipe',
      );
      expect(
        result.metadata?['extraction_method'],
        'html_text_parse',
      );
      expect(result.metadata?['tier'], 5);
      expect(
        result.warnings,
        contains('Extracted from HTML text - quality may vary'),
        reason:
            'Tier 5 must warn the user that this is a low-quality extraction',
      );
    });

    /// BUT-1077 boundary: the quality gate is
    /// `ingredients.isEmpty && instructions.isEmpty` — an AND, not an OR.
    /// A page with detectable INSTRUCTIONS but ZERO ingredients must STILL
    /// pass the gate and reach Tier 5. This pins the asymmetric branch the
    /// other Tier 5 tests miss (they all supply both axes): tightening the
    /// gate to `||` (require BOTH) would silently demote instructions-only
    /// pages to Tier 7, and only this test would go red.
    test('BUT-1077: instructions-only page (zero ingredients) still passes the '
        'AND gate → Tier 5 success, NOT Tier 7', () async {
      // Numbered method steps with Swedish cooking verbs that
      // TextImportStrategy recognises as instructions, and no ingredient
      // list at all — so the parsed recipe has empty ingredients.
      const instructionsOnlyHtml = '''
<!doctype html>
<html><head><title>Tillagning</title></head>
<body>
<h1>Hur man gör</h1>
<h2>Gör så här</h2>
<ol>
  <li>Vispa ihop ägg och mjölk i en stor bunke tills det är slätt.</li>
  <li>Tillsätt vetemjöl under omrörning och låt smeten vila i tio minuter.</li>
  <li>Hetta upp smör i en stekpanna och stek pannkakorna på medelvärme.</li>
</ol>
</body>
</html>
''';

      final strategy = _strategyWith(
        (req) async => _htmlResponse(instructionsOnlyHtml),
      );

      final result = await strategy.import('http://8.8.8.8/instructions');

      expect(
        result.isSuccess,
        isTrue,
        reason:
            'instructions present → the AND gate must NOT fall through; '
            'an instructions-only page is a usable (if partial) recipe',
      );
      expect(result.needsAssistance, isFalse);
      expect(result.metadata?['extraction_method'], 'html_text_parse');
      expect(result.metadata?['tier'], 5);
      expect(
        result.recipe!.core.ingredients,
        isEmpty,
        reason:
            'this page has no ingredient list — the gate passed on '
            'instructions alone, proving the AND (not OR) semantics',
      );
      expect(result.recipe!.core.instructions, isNotEmpty);
    });

    /// Body too small for the >100-char bestHtml guard → none of Tiers 5-7
    /// run. The strategy must surface a hard failure with diagnostic
    /// metadata (`html_fetched`, `html_length`) so the UI can explain
    /// "we fetched but found nothing."
    test('tiny HTML body (<100 chars) → hard failure carrying html_length '
        'metadata', () async {
      // 19 chars — under the > 100 guard. Note: passes the
      // "if (httpHtml != null)" Tier 2 check (which has no length guard)
      // but extractRecipeFromHtml returns null on this body, so Tier 2
      // misses too. Then Tiers 5/6/7 are gated by `bestHtml.length > 100`.
      const body = '<html><b>x</b></html>';
      final strategy = _strategyWith((req) async => _htmlResponse(body));

      final result = await strategy.import('http://8.8.8.8/empty');

      expect(result.isSuccess, isFalse);
      expect(
        result.needsAssistance,
        isFalse,
        reason: 'body too small for the assistance threshold',
      );
      expect(result.errorMessage, isNotNull);
      expect(
        result.metadata?['html_fetched'],
        isTrue,
        reason: 'we DID fetch (status 200) — the page was just empty',
      );
      expect(result.metadata?['html_length'], body.length);
      expect(result.metadata?['strategy'], 'URL Import');
    });

    /// HTTP 5xx: `fetchHtmlWithTimeout` only returns the body on 200, so
    /// it returns null. All HTML-dependent tiers are then skipped and the
    /// strategy must record `html_fetched=false`.
    test('HTTP 500 → failure with html_fetched=false metadata', () async {
      final strategy = _strategyWith(
        (req) async => http.Response('upstream boom', 500),
      );

      final result = await strategy.import('http://8.8.8.8/down');

      expect(result.isSuccess, isFalse);
      expect(result.needsAssistance, isFalse);
      expect(
        result.metadata?['html_fetched'],
        isFalse,
        reason: 'a non-200 response must NOT be reported as html_fetched=true',
      );
      expect(result.metadata?['html_length'], 0);
    });

    /// HTTP 404: same contract as 500. Pin both so a future refactor that
    /// special-cases 404 has to update the test.
    test('HTTP 404 → failure with html_fetched=false metadata', () async {
      final strategy = _strategyWith(
        (req) async => http.Response('not found', 404),
      );

      final result = await strategy.import('http://8.8.8.8/missing');

      expect(result.isSuccess, isFalse);
      expect(result.metadata?['html_fetched'], isFalse);
    });

    /// HTTP 429 (rate limited): documented as no-special-case — same
    /// failure path as any other non-200. Pinning this explicitly because
    /// a "smart retry on 429" patch would silently change behaviour.
    test(
      'HTTP 429 is treated the same as any other non-200 (no retry logic)',
      () async {
        var requestCount = 0;
        final strategy = _strategyWith((req) async {
          requestCount++;
          return http.Response('rate limited', 429);
        });

        final result = await strategy.import('http://8.8.8.8/throttle');

        expect(result.isSuccess, isFalse);
        expect(result.metadata?['html_fetched'], isFalse);
        // The strategy makes at most 2 HTTP attempts (Tier 2 fetch + Tier 3
        // headless scraper). The scraper would normally also call out, but
        // it's not exercised here — we only assert that no SILENT retry
        // happens on 429. A "smart retry" patch would push this >= 3.
        expect(
          requestCount,
          lessThanOrEqualTo(2),
          reason: '429 must not trigger an in-strategy retry loop',
        );
      },
    );

    /// A non-http(s) scheme that somehow reaches `import` (e.g. caller
    /// bypassed `canHandle`) must be handled gracefully: the inner
    /// `HttpContentFetcher` blocks the request, all tiers fail, we get a
    /// failure result. NOT a thrown exception.
    test('file:// scheme reaching import is rejected pre-send', () async {
      var sendCount = 0;
      final strategy = _strategyWith((req) async {
        sendCount++;
        return _htmlResponse('should never be called');
      });

      final result = await strategy.import('file:///etc/passwd');

      expect(
        result.isSuccess,
        isFalse,
        reason: 'non-http schemes must never succeed an import',
      );
      expect(sendCount, 0, reason: 'scheme rejection must happen pre-send');
    });

    /// `javascript:` URL reaching `import` — same contract as file://.
    /// Belt-and-braces because XSS payloads in shared text are common.
    test('javascript: scheme reaching import is rejected pre-send', () async {
      var sendCount = 0;
      final strategy = _strategyWith((req) async {
        sendCount++;
        return _htmlResponse('nope');
      });

      final result = await strategy.import('javascript:alert(1)');

      expect(result.isSuccess, isFalse);
      expect(sendCount, 0);
    });

    /// Whitespace around the URL must be trimmed by `import()` — otherwise
    /// `Uri.parse` would carry the spaces into the path. End-to-end pin
    /// on the trim.
    test('trims leading/trailing whitespace before fetching', () async {
      Uri? capturedUri;
      final strategy = _strategyWith((req) async {
        capturedUri = req.url;
        return _htmlResponse(_jsonLdRecipeHtml());
      });

      final result = await strategy.import('  http://8.8.8.8/recipe   ');

      expect(result.isSuccess, isTrue);
      expect(
        capturedUri.toString(),
        'http://8.8.8.8/recipe',
        reason: 'whitespace must be stripped before constructing the URI',
      );
    });

    /// If the JSON-LD has @type=Recipe but no `recipeIngredient`, the
    /// schema.org extractor produces a Recipe with empty ingredients.
    /// The strategy must trust that — NOT crash trying to validate.
    test('JSON-LD with missing recipeIngredient still succeeds with empty '
        'ingredients list', () async {
      const html = '''
<!doctype html>
<html><head><script type="application/ld+json">
{"@context":"https://schema.org","@type":"Recipe","name":"Sparse"}
</script></head><body></body></html>
''';

      final strategy = _strategyWith((req) async => _htmlResponse(html));

      final result = await strategy.import('http://8.8.8.8/sparse');

      expect(
        result.isSuccess,
        isTrue,
        reason:
            'schema.org tier accepts any object whose @type is Recipe — '
            'the strategy must trust that and not second-guess content',
      );
      expect(result.recipe!.core.title, 'Sparse');
      expect(
        result.recipe!.core.ingredients,
        isEmpty,
        reason: 'empty list is the documented degradation',
      );
    });

    /// JSON-LD that ISN'T a Recipe (e.g. @type=Article) must NOT trigger
    /// the schema.org tier — the extractor returns null and we fall
    /// through. The body has only prose (no ingredients/instructions), so
    /// BUT-1077's quality gate in Tier 5 kicks in and falls through to
    /// Tier 7 (user-assisted import).
    ///
    /// This is the key invariant: a non-Recipe JSON-LD type must not be
    /// claimed as a structured-data extraction. Otherwise we'd present
    /// news articles as recipes with high confidence. Tier 7 (user-
    /// assistance) is the correct result — better than a low-quality
    /// success-with-warnings.
    test('JSON-LD @type=Article does NOT trigger Tier 2; pure prose page '
        'reaches Tier 7 (user-assisted) — never claims schema.org', () async {
      const html = '''
<!doctype html>
<html><head><script type="application/ld+json">
{"@context":"https://schema.org","@type":"Article","headline":"Not a recipe"}
</script></head><body>
<p>This is a long news article about cooking but it does not contain
any recipe structured data. The body is long enough to reach the
fallback tier but not the structured extractor.</p>
<p>Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod
tempor incididunt ut labore et dolore magna aliqua.</p>
</body></html>
''';

      final strategy = _strategyWith((req) async => _htmlResponse(html));

      final result = await strategy.import('http://8.8.8.8/article');

      // Core invariant: schema.org tier must never claim a non-Recipe type.
      expect(
        result.metadata?['extraction_method'],
        isNot(equals('schema.org')),
        reason:
            '@type=Article must not be claimed as a schema.org Recipe — '
            'doing so would mark news articles as high-confidence recipes',
      );

      // BUT-1077: pure prose → Tier 5 quality gate fails (no ingredients,
      // no instructions) → falls through to Tier 7 (user-assistance).
      // Tier 7 is a clearer signal to the user than a low-quality success.
      expect(
        result.needsAssistance,
        isTrue,
        reason:
            'BUT-1077: article page with no recipe structure must reach '
            'Tier 7 (user-assistance), not be presented as a recipe',
      );
      expect(result.isSuccess, isFalse);
      expect(result.extractedText, isNotNull);
      expect(result.metadata?['tier'], 7);
    });

    /// BUT-1070 companion: when Tier 5 DOES fire on a page with non-Recipe
    /// JSON-LD (because there ARE detectable ingredients), the warning
    /// must mention "nyhetsartikel" to flag the suspicious context.
    test('BUT-1070: Tier 5 with non-Recipe JSON-LD fires nyhetsartikel warning '
        'when ingredients ARE present', () async {
      // This page has @type=Article JSON-LD (non-Recipe) but also contains
      // Swedish ingredient lines that will pass Tier 5's quality gate.
      const html = '''
<!doctype html>
<html><head><script type="application/ld+json">
{"@context":"https://schema.org","@type":"Article","headline":"Cooking tips"}
</script></head><body>
<h1>Cooking tips</h1>
<h2>Ingredienser</h2>
<ul>
  <li>3 dl vetemjöl</li>
  <li>2 msk smör</li>
  <li>1 tsk bakpulver</li>
  <li>5 dl mjölk</li>
</ul>
<h2>Gör så här</h2>
<ol>
  <li>Blanda vetemjöl och bakpulver i en bunke.</li>
  <li>Tillsätt smält smör och mjölk under omrörning.</li>
</ol>
</body></html>
''';

      final strategy = _strategyWith((req) async => _htmlResponse(html));

      final result = await strategy.import('http://8.8.8.8/cooking-article');

      // Schema.org tier must still not fire for @type=Article.
      expect(
        result.metadata?['extraction_method'],
        isNot(equals('schema.org')),
      );

      // Tier 5 fires because ingredients were found (quality gate passes).
      expect(result.isSuccess, isTrue);
      expect(result.metadata?['extraction_method'], 'html_text_parse');

      // BUT-1070 warning must be present when non-Recipe JSON-LD was found.
      expect(
        result.warnings?.any((w) => w.contains('nyhetsartikel')),
        isTrue,
        reason:
            'BUT-1070: Tier 5 on a non-Recipe JSON-LD page must warn '
            '"nyhetsartikel" so the user knows the context is suspect',
      );
    });

    /// Verifies that the inner try/catch in `import()` swallows unexpected
    /// exceptions. We make the http.Client throw synchronously — the
    /// strategy must NOT rethrow.
    test(
      'http.Client throws during send → returns failure, never rethrows',
      () async {
        final boomClient = MockClient((req) async {
          throw StateError('synthetic boom');
        });
        final strategy = UrlImportStrategy(httpClient: boomClient);

        // No expect(throwsA(...)) — the contract is "swallow and return failure."
        final result = await strategy.import('http://8.8.8.8/x');

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, isNotNull);
        expect(result.metadata?['strategy'], 'URL Import');
        // HttpContentFetcher catches client-side exceptions and returns null,
        // so we land in the "no html, no assist" failure path — html_fetched
        // is false there.
        expect(result.metadata?['html_fetched'], isFalse);
      },
    );
  });

  // -----------------------------------------------------------------------
  // Correction-capture wiring (BUT-1469 / BUT-1614)
  //
  // The URL strategy's text-fallback tiers (Tier 4 web-scraper, Tier 5
  // html-text-parse) delegate to a REAL inner TextImportStrategy, which stores
  // its own `text`-tagged snapshot; the URL tier then re-captures the same
  // recipe id as `url` + domain (last write wins) so URL corrections never
  // pollute the pasted-text bucket and keep their domain attribution. These
  // tests wire a real ParsedRecipeCache into the production ServiceLocator
  // (the other groups leave it uninitialized, so Tier 1 stays null) and read
  // the final snapshot back through the whole import.
  // -----------------------------------------------------------------------
  group('UrlImportStrategy correction-capture (BUT-1469 / BUT-1614)', () {
    late ParsedRecipeCache cache;

    setUp(() {
      cache = ParsedRecipeCache();
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(DIContainer());
      final getIt = GetIt.instance;
      if (getIt.isRegistered<ParsedRecipeCache>()) {
        getIt.unregister<ParsedRecipeCache>();
      }
      getIt.registerSingleton<ParsedRecipeCache>(cache);
    });

    tearDown(() {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<ParsedRecipeCache>()) {
        getIt.unregister<ParsedRecipeCache>();
      }
      app_provider.ServiceLocator.reset();
    });

    /// Registering only ParsedRecipeCache (not RecipeParserService) must not
    /// accidentally enable Tier 1 — the html-text page must still land on
    /// Tier 5 exactly as it does with an uninitialized ServiceLocator.
    const recipeHtml = '''
<!doctype html>
<html><head><title>Pannkakor</title></head>
<body>
<h1>Pannkakor</h1>
<h2>Ingredienser</h2>
<ul>
  <li>3 ägg</li>
  <li>5 dl mjölk</li>
  <li>3 dl vetemjöl</li>
  <li>1 krm salt</li>
  <li>2 msk smör</li>
</ul>
<h2>Gör så här</h2>
<ol>
  <li>Vispa ihop ägg och mjölk i en bunke.</li>
  <li>Tillsätt vetemjöl och salt under omrörning tills smeten är slät.</li>
  <li>Hetta upp smör i en stekpanna och stek pannkakor på medelvärme.</li>
</ol>
</body>
</html>
''';

    test(
      'Tier 5 html-text-parse stores a snapshot tagged ImportSource.url with '
      'the source domain, overriding the inner text snapshot (last write wins)',
      () async {
        final strategy = _strategyWith(
          (req) async => _htmlResponse(recipeHtml),
        );

        final result = await strategy.import('http://8.8.8.8/pannkakor');

        expect(result.isSuccess, isTrue);
        expect(result.metadata?['extraction_method'], 'html_text_parse');

        final snapshot = cache.retrieve(result.recipe!.id);
        expect(
          snapshot,
          isNotNull,
          reason: 'a URL text-fallback import must anchor the feedback loop',
        );
        expect(
          snapshot!.metadata.source,
          ImportSource.url,
          reason:
              'the inner TextImportStrategy stored `text` first; the URL tier '
              're-captures the same id as `url` and must win',
        );
        expect(
          snapshot.metadata.domain,
          '8.8.8.8',
          reason: 'URL captures keep domain attribution for alias-learning',
        );
        expect(
          snapshot.metadata.parserVersion,
          ImportCorrectionSnapshot.snapshotParserVersion,
        );
      },
    );

    /// Positive/negative pairing: a prose page falls through to Tier 7
    /// (user-assistance) with no produced recipe, so there is no `url`-tagged
    /// anchor to retrieve. Pins that the capture rides on a produced recipe,
    /// not on every import attempt.
    test(
      'prose page reaching Tier 7 produces no url-tagged snapshot',
      () async {
        final strategy = _strategyWith(
          (req) async => _htmlResponse(_unstructuredHtml()),
        );

        final result = await strategy.import('http://8.8.8.8/blog');

        expect(result.needsAssistance, isTrue);
        expect(result.recipe, isNull);
      },
    );
  });

  // -----------------------------------------------------------------------
  // DNS-rebinding gate, driven end-to-end via the injected dnsLookup seam
  // (BUT-1078). A hostname that passes the literal-IP SSRF check at
  // canHandle() but RESOLVES to a private/loopback IP must be blocked before
  // any HTTP send.
  // -----------------------------------------------------------------------
  group('UrlImportStrategy DNS-rebinding gate (dnsLookup seam — BUT-1078)', () {
    /// A public-looking host that DNS-resolves to 127.0.0.1 is the classic
    /// DNS-rebinding SSRF. canHandle() can't catch it (the host is not a
    /// literal private IP), so the only defence is the post-resolution check
    /// in HttpContentFetcher. This pins that the resolved-IP block fires and
    /// no HTTP request is ever sent.
    test('host resolving to 127.0.0.1 is blocked pre-send → failure', () async {
      var sendCount = 0;
      final client = MockClient((req) async {
        sendCount++;
        return _htmlResponse(_jsonLdRecipeHtml());
      });
      final strategy = UrlImportStrategy(
        httpClient: client,
        dnsLookup: (host) async => [InternetAddress('127.0.0.1')],
      );

      final result = await strategy.import('http://rebind.example.com/recipe');

      expect(
        result.isSuccess,
        isFalse,
        reason: 'a host resolving to loopback must never import',
      );
      expect(
        sendCount,
        0,
        reason: 'the DNS-rebinding block must fire before any HTTP send',
      );
      expect(result.metadata?['html_fetched'], isFalse);
    });

    /// Mirror case: a host resolving to a cloud-metadata link-local address
    /// (169.254.169.254) — the highest-value SSRF target — must also be
    /// blocked through the same seam.
    test(
      'host resolving to 169.254.169.254 (cloud metadata) is blocked',
      () async {
        var sendCount = 0;
        final client = MockClient((req) async {
          sendCount++;
          return _htmlResponse(_jsonLdRecipeHtml());
        });
        final strategy = UrlImportStrategy(
          httpClient: client,
          dnsLookup: (host) async => [InternetAddress('169.254.169.254')],
        );

        final result = await strategy.import('http://metadata.example.com/x');

        expect(result.isSuccess, isFalse);
        expect(sendCount, 0);
      },
    );

    /// Positive control: when the same host resolves to a PUBLIC IP, the
    /// gate must let it through and the import succeeds. This proves the
    /// block above is the resolution check firing, not the seam swallowing
    /// every request.
    test('host resolving to a public IP passes the gate and imports', () async {
      final client = MockClient(
        (req) async => _htmlResponse(
          _jsonLdRecipeHtml(
            title: 'Våfflor',
          ),
        ),
      );
      final strategy = UrlImportStrategy(
        httpClient: client,
        dnsLookup: (host) async => [InternetAddress('93.184.216.34')],
      );

      final result = await strategy.import('http://good.example.com/recipe');

      expect(
        result.isSuccess,
        isTrue,
        reason: 'a public-resolving host must import normally',
      );
      expect(result.recipe!.core.title, 'Våfflor');
    });
  });

  // -----------------------------------------------------------------------
  // Strategy metadata (contract of the ImportStrategy interface)
  // -----------------------------------------------------------------------
  group('UrlImportStrategy strategy metadata', () {
    late UrlImportStrategy strategy;

    setUp(() {
      strategy = UrlImportStrategy();
    });

    /// strategyName is referenced verbatim in every ImportResult.metadata —
    /// renaming it breaks any code that filters by strategy.
    test('strategyName is stable ("URL Import")', () {
      expect(strategy.strategyName, 'URL Import');
    });

    /// inputExample must itself pass `canHandle` — otherwise the UI hint
    /// is showing the user a URL the strategy would reject.
    test('inputExample is itself a URL that canHandle accepts', () {
      expect(
        strategy.canHandle(strategy.inputExample),
        isTrue,
        reason: "the example URL must pass the strategy's own gate",
      );
    });

    /// description is shown in the importer chooser — pin "non-empty"
    /// so a future blank string fails CI.
    test('description is non-empty', () {
      expect(strategy.description.trim(), isNotEmpty);
    });
  });

  // -----------------------------------------------------------------------
  // HttpContentFetcher.isBlockedHost — the SSRF gate UrlImportStrategy
  // delegates to. If this breaks, every UrlImportStrategy protection breaks.
  // -----------------------------------------------------------------------
  group('HttpContentFetcher.isBlockedHost (delegated SSRF gate)', () {
    test('blocks loopback variations', () {
      expect(HttpContentFetcher.isBlockedHost('localhost'), isTrue);
      expect(HttpContentFetcher.isBlockedHost('127.0.0.1'), isTrue);
      expect(HttpContentFetcher.isBlockedHost('127.0.0.2'), isTrue);
    });

    test('blocks RFC1918 private ranges', () {
      expect(HttpContentFetcher.isBlockedHost('10.0.0.1'), isTrue);
      expect(HttpContentFetcher.isBlockedHost('10.255.255.255'), isTrue);
      expect(HttpContentFetcher.isBlockedHost('172.16.0.1'), isTrue);
      expect(HttpContentFetcher.isBlockedHost('172.31.255.255'), isTrue);
      expect(HttpContentFetcher.isBlockedHost('192.168.0.1'), isTrue);
    });

    /// 172.15.x.x and 172.32.x.x are PUBLIC — only 172.16-31 is private.
    /// A naive `bytes[0] == 172 && bytes[1] >= 16` (missing the `<= 31`
    /// upper bound) would block legitimate hosts.
    test('does NOT over-block 172.x outside the 16-31 private range', () {
      expect(
        HttpContentFetcher.isBlockedHost('172.15.0.1'),
        isFalse,
        reason: '172.15 is public, must not be blocked',
      );
      expect(
        HttpContentFetcher.isBlockedHost('172.32.0.1'),
        isFalse,
        reason: '172.32 is public, must not be blocked',
      );
    });

    test('blocks link-local 169.254.x.x and 0.0.0.0', () {
      expect(
        HttpContentFetcher.isBlockedHost('169.254.169.254'),
        isTrue,
        reason: 'cloud metadata endpoint — must always be blocked',
      );
      expect(HttpContentFetcher.isBlockedHost('0.0.0.0'), isTrue);
    });

    /// IPv6 SSRF surface — pin loopback, link-local, ULA, and the
    /// IPv4-mapped-IPv6 trick (::ffff:127.0.0.1) which is the classic
    /// bypass.
    test('blocks IPv6 loopback / link-local / ULA / IPv4-mapped-loopback', () {
      expect(HttpContentFetcher.isBlockedHost('::1'), isTrue);
      expect(
        HttpContentFetcher.isBlockedHost('fe80::1'),
        isTrue,
        reason: 'link-local must be blocked',
      );
      expect(
        HttpContentFetcher.isBlockedHost('fc00::1'),
        isTrue,
        reason: 'unique-local must be blocked',
      );
      expect(
        HttpContentFetcher.isBlockedHost('::ffff:127.0.0.1'),
        isTrue,
        reason:
            'IPv4-mapped IPv6 wrapping loopback must be unwrapped + blocked',
      );
    });

    /// Allow-list anchors so we don't accidentally block the whole internet.
    test('allows public hostnames and public IPs', () {
      expect(HttpContentFetcher.isBlockedHost('example.com'), isFalse);
      expect(HttpContentFetcher.isBlockedHost('www.ica.se'), isFalse);
      expect(HttpContentFetcher.isBlockedHost('8.8.8.8'), isFalse);
      expect(HttpContentFetcher.isBlockedHost('1.1.1.1'), isFalse);
    });
  });

  // -----------------------------------------------------------------------
  // ImportValidationMixin — used by UrlImportStrategy and siblings.
  // -----------------------------------------------------------------------
  group('ImportValidationMixin', () {
    late _ValidationHelper v;

    setUp(() {
      v = _ValidationHelper();
    });

    test('isValidRecipeName: requires 2+ trimmed chars', () {
      expect(v.isValidRecipeName('AB'), isTrue);
      expect(v.isValidRecipeName('Pannkakor'), isTrue);
      expect(v.isValidRecipeName(''), isFalse);
      expect(v.isValidRecipeName(' '), isFalse);
      expect(v.isValidRecipeName('A'), isFalse);
    });

    test('isValidIngredients: rejects empty and all-blank lists', () {
      expect(v.isValidIngredients(['2 dl mjöl']), isTrue);
      expect(v.isValidIngredients([]), isFalse);
      expect(v.isValidIngredients(['', '  ']), isFalse);
    });

    test('isValidInstructions: rejects empty and all-blank lists', () {
      expect(v.isValidInstructions(['Blanda allt']), isTrue);
      expect(v.isValidInstructions([]), isFalse);
      expect(v.isValidInstructions(['', '  ']), isFalse);
    });

    test('normalizeText: collapses spaces, trims, preserves newlines', () {
      expect(v.normalizeText('hello   world'), 'hello world');
      expect(v.normalizeText('  hello  '), 'hello');
      expect(v.normalizeText('line1  x\n  line2  y'), 'line1 x\nline2 y');
    });

    /// Emoji-stripping is documented behaviour (lots of social-media
    /// recipes arrive saturated with emojis). Pin one to catch regression.
    test('normalizeText: strips emojis from social-media copy', () {
      expect(v.normalizeText('Pannkakor 🥞 är goda'), 'Pannkakor är goda');
    });

    test('extractNumber: first integer wins', () {
      expect(v.extractNumber('4 portioner'), 4);
      expect(v.extractNumber('ca 6 bitar'), 6);
      expect(v.extractNumber('no numbers'), isNull);
    });

    test('extractRating: 1-5 range gate, multiple formats', () {
      expect(v.extractRating('4.5 av 5'), 4.5);
      expect(v.extractRating('3/5'), 3.0);
      expect(
        v.extractRating('0.5 av 5'),
        isNull,
        reason: 'ratings under 1.0 must be rejected',
      );
      expect(
        v.extractRating('6 av 5'),
        isNull,
        reason: 'ratings over 5.0 must be rejected',
      );
      expect(v.extractRating('no rating'), isNull);
    });
  });

  // -----------------------------------------------------------------------
  // ImportResult factory contract — used by every tier's return value.
  // -----------------------------------------------------------------------
  group('ImportResult factories', () {
    Recipe makeRecipe() => Recipe(
      core: RecipeCore(
        id: 'test-id',
        title: 'T',
        description: '',
        ingredients: ['a'],
        instructions: ['b'],
        mealType: 'Middag',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        createdBy: 'u1',
      ),
      type: RecipeType.personal,
    );

    test(
      'success: isSuccess=true, recipe set, no error, not needing assist',
      () {
        final r = ImportResult.success(makeRecipe(), metadata: {'k': 'v'});

        expect(r.isSuccess, isTrue);
        expect(r.recipe, isNotNull);
        expect(r.errorMessage, isNull);
        expect(r.needsAssistance, isFalse);
        expect(r.hasMetadata, isTrue);
        expect(r.metadata?['k'], 'v');
      },
    );

    test('failure: isSuccess=false, no recipe, errorMessage carried', () {
      final r = ImportResult.failure('something went wrong');

      expect(r.isSuccess, isFalse);
      expect(r.recipe, isNull);
      expect(r.errorMessage, 'something went wrong');
      expect(r.needsAssistance, isFalse);
    });

    test('assistance: needsAssistance=true, extractedText carried', () {
      final r = ImportResult.assistance(
        extractedText: 'some text',
        suggestedTitle: 'Maybe Pancakes',
        likelyIngredientLines: [0, 2, 4],
      );

      expect(r.isSuccess, isFalse);
      expect(r.needsAssistance, isTrue);
      expect(r.extractedText, 'some text');
      expect(r.suggestedTitle, 'Maybe Pancakes');
      expect(r.likelyIngredientLines, [0, 2, 4]);
    });

    test('hasWarnings reflects presence of non-empty warnings list', () {
      expect(ImportResult.failure('e').hasWarnings, isFalse);
      expect(ImportResult.failure('e', warnings: []).hasWarnings, isFalse);
      expect(
        ImportResult.failure('e', warnings: ['quality may vary']).hasWarnings,
        isTrue,
      );
    });
  });
}
