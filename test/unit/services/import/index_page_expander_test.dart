import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/fetchers/http_content_fetcher.dart';
import 'package:butlery/services/import/index_page_expander.dart';

/// BUT-1273: the expander glues the SSRF-guarded HTML fetch to the pure
/// link-harvester. Intent: it returns links only for pages that actually look
/// like a recipe index, and empty for everything else (single page, fetch miss).
class _FakeFetcher extends HttpContentFetcher {
  _FakeFetcher(this._html);
  final String? _html;

  @override
  Future<String?> fetchHtmlWithTimeout(String url) async => _html;
}

void main() {
  const base = 'https://recept.example.se/recept';

  String listingHtml(int count) => List.generate(
    count,
    (i) => '<a href="/recept/ratt-nummer-med-namn-$i">x</a>',
  ).join('\n');

  test('harvests links when the page looks like an index', () async {
    final expander = IndexPageExpander(fetcher: _FakeFetcher(listingHtml(6)));

    final links = await expander.harvest(base);

    expect(links.length, 6);
    expect(links.first, startsWith('https://recept.example.se/recept/'));
  });

  test('returns empty when too few links to be an index', () async {
    final expander = IndexPageExpander(fetcher: _FakeFetcher(listingHtml(2)));

    expect(await expander.harvest(base), isEmpty);
  });

  test('returns empty when the fetch yields no HTML', () async {
    final expander = IndexPageExpander(fetcher: _FakeFetcher(null));

    expect(await expander.harvest(base), isEmpty);
  });

  test('returns empty for an ordinary recipe page (only nav chrome)', () async {
    final expander = IndexPageExpander(
      fetcher: _FakeFetcher('<a href="/om-oss">Om</a><a href="/kontakt">K</a>'),
    );

    expect(await expander.harvest(base), isEmpty);
  });
}
