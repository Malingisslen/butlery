/// Direct unit tests for [SiteParserRegistry] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Static registry that routes a recipe URL to its site-specific parser.
/// Covers register (domain lowercased), getParser (exact match → www-stripped
/// fallback → null for unknown/invalid), hasParser, registeredDomains, count,
/// and clear. clear() runs in setUp/tearDown to isolate the static state.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/extraction/site_parsers/recipe_site_parser.dart';
import 'package:butlery/services/extraction/site_parsers/site_parser_registry.dart';

class _FakeParser extends RecipeSiteParser {
  _FakeParser(this.domain);
  @override
  final String domain;
  @override
  String get siteName => 'Fake($domain)';
}

void main() {
  setUp(SiteParserRegistry.clear);
  tearDown(SiteParserRegistry.clear);

  test('register stores under the lowercased domain', () {
    SiteParserRegistry.register(_FakeParser('ICA.se'));
    expect(SiteParserRegistry.registeredDomains, ['ica.se']);
    expect(SiteParserRegistry.count, 1);
  });

  test('getParser matches the exact host', () {
    final p = _FakeParser('ica.se');
    SiteParserRegistry.register(p);
    expect(SiteParserRegistry.getParser('https://ica.se/recept/x'), same(p));
  });

  test('getParser strips a www. prefix', () {
    final p = _FakeParser('ica.se');
    SiteParserRegistry.register(p);
    expect(
      SiteParserRegistry.getParser('https://www.ica.se/recept/x'),
      same(p),
    );
  });

  test('getParser returns null for an unregistered domain', () {
    SiteParserRegistry.register(_FakeParser('ica.se'));
    expect(SiteParserRegistry.getParser('https://arla.se/x'), isNull);
  });

  test('getParser returns null for a URL with no matching host', () {
    SiteParserRegistry.register(_FakeParser('ica.se'));
    expect(SiteParserRegistry.getParser('not even a url'), isNull);
  });

  test('hasParser reflects whether a parser is registered', () {
    SiteParserRegistry.register(_FakeParser('ica.se'));
    expect(SiteParserRegistry.hasParser('https://ica.se/x'), isTrue);
    expect(SiteParserRegistry.hasParser('https://arla.se/x'), isFalse);
  });

  test('clear empties the registry', () {
    SiteParserRegistry.register(_FakeParser('ica.se'));
    SiteParserRegistry.clear();
    expect(SiteParserRegistry.count, 0);
    expect(SiteParserRegistry.registeredDomains, isEmpty);
  });
}
