/// Crawls Swedish recipe site sitemaps to collect recipe URLs for CRF training.
///
/// Fetches known recipe sitemaps, extracts URLs, and outputs one per line.
/// The scraper (scrape_ingredients.dart) handles JSON-LD filtering, so
/// non-recipe URLs that slip through are harmless.
///
/// Usage: dart run scripts/crf/crawl_sitemaps.dart > data/urls.txt
library;

import 'dart:convert';
import 'dart:io';

/// Known recipe sitemaps (discovered from robots.txt + sitemap indexes).
const _sitemaps = [
  // ICA — 3 recipe-specific sub-sitemaps
  'https://www.ica.se/recept/sitemaps/recipes/1',
  'https://www.ica.se/recept/sitemaps/recipes/2',
  'https://www.ica.se/recept/sitemaps/recipes/3',
  // Arla — recipe-specific sitemap
  'https://www.arla.se/sitemap.xml?type=Modules.Recipes.Business.SitemapUrlWriter.RecipeSitemapUrlWriter',
  // Tasteline — 12 recipe post sitemaps
  'https://www.tasteline.com/wp-sitemap-posts-recipe-1.xml',
  'https://www.tasteline.com/wp-sitemap-posts-recipe-2.xml',
  'https://www.tasteline.com/wp-sitemap-posts-recipe-3.xml',
  'https://www.tasteline.com/wp-sitemap-posts-recipe-4.xml',
  'https://www.tasteline.com/wp-sitemap-posts-recipe-5.xml',
  'https://www.tasteline.com/wp-sitemap-posts-recipe-6.xml',
  'https://www.tasteline.com/wp-sitemap-posts-recipe-7.xml',
  'https://www.tasteline.com/wp-sitemap-posts-recipe-8.xml',
  'https://www.tasteline.com/wp-sitemap-posts-recipe-9.xml',
  'https://www.tasteline.com/wp-sitemap-posts-recipe-10.xml',
  'https://www.tasteline.com/wp-sitemap-posts-recipe-11.xml',
  'https://www.tasteline.com/wp-sitemap-posts-recipe-12.xml',
  // Recepten.se — recipe-specific sitemap
  'https://www.recepten.se/sitemap/sitemap-recipe.xml',
  // Köket — flat sitemap (mixed content, scraper filters via JSON-LD)
  'https://www.koket.se/sitemap.xml',
];

final _locPattern = RegExp(r'<loc>\s*(.*?)\s*</loc>');

Future<void> main() async {
  final client = HttpClient();
  final allUrls = <String>{};

  for (final sitemapUrl in _sitemaps) {
    try {
      final urls = await _fetchSitemap(client, sitemapUrl);
      final before = allUrls.length;
      allUrls.addAll(urls);
      stderr.writeln(
        '${urls.length} URLs from $sitemapUrl '
        '(${allUrls.length - before} new)',
      );
    } catch (e) {
      stderr.writeln('Error fetching $sitemapUrl: $e');
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  // Output deduplicated URLs
  final sorted = allUrls.toList()..sort();
  for (final url in sorted) {
    stdout.writeln(url);
  }

  stderr.writeln('\nTotal: ${sorted.length} unique recipe URLs');
  client.close();
}

Future<List<String>> _fetchSitemap(HttpClient client, String url) async {
  final uri = Uri.parse(url);
  final request = await client.getUrl(uri);
  request.headers.set('User-Agent', 'ButleryCRFScraper/1.0');
  request.headers.set('Accept', 'application/xml, text/xml, text/html');

  final response = await request.close().timeout(
        const Duration(seconds: 15),
      );

  if (response.statusCode != 200) {
    stderr.writeln('HTTP ${response.statusCode} for $url');
    await response.drain<void>();
    return [];
  }

  final body = await response.transform(utf8.decoder).join();
  return _locPattern
      .allMatches(body)
      .map((m) => m.group(1)!)
      .where((u) => u.startsWith('http'))
      .toList();
}
