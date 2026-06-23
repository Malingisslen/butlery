import 'package:butlery/services/import/fetchers/http_content_fetcher.dart';
import 'package:butlery/services/import/index_page_detector.dart';

/// BUT-1273: fetches a candidate listing page and, if it looks like a recipe
/// index, returns the individual recipe links to feed into the multi-URL batch.
///
/// Kept out of [UrlImportViewModel] so the VM stays under the 500-line limit and
/// the network path is independently testable with a stubbed fetcher. The fetch
/// goes through [HttpContentFetcher.fetchHtmlWithTimeout] so it inherits the
/// SSRF host-guard + DNS-rebinding protection — never a raw HTTP call.
class IndexPageExpander {
  IndexPageExpander({HttpContentFetcher? fetcher})
    : _fetcher = fetcher ?? HttpContentFetcher();

  final HttpContentFetcher _fetcher;

  /// Returns the harvested recipe links if [url] resolves to a listing page,
  /// otherwise an empty list (single recipe page, fetch failure, or too few
  /// links). Empty means "don't offer expansion".
  Future<List<String>> harvest(String url) async {
    final html = await _fetcher.fetchHtmlWithTimeout(url);
    if (html == null || html.isEmpty) return const [];
    // Single parse: harvest once, then apply the index threshold. (Calling
    // looksLikeIndexPage would re-scan a 5 MB page's anchors a second time.)
    final links = IndexPageDetector.extractRecipeLinks(html, baseUrl: url);
    if (links.length < IndexPageDetector.defaultMinLinks) return const [];
    return links;
  }
}
