/// Presentation-layer ViewModel for importing recipes from web URLs.
/// Handles single-URL fetch/parse plus BUT-947 multi-URL ("batch") import;
/// delegates the actual scraping/persistence to WebScraper and ImportManager.

import 'package:flutter/foundation.dart';

import 'package:butlery/viewmodels/import_base_viewmodel.dart';
import 'package:butlery/services/extraction/web_scraper.dart';
import 'package:butlery/services/extraction/platform_detector.dart' as pd;
import 'package:butlery/services/import/fetchers/http_content_fetcher.dart';
import 'package:butlery/services/social_media_extractor.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Per-URL lifecycle state for batch ("multiple URLs") imports.
enum UrlFetchStatus { pending, loading, success, failure }

/// BUT-947: immutable per-URL result for a multi-URL import batch.
/// One of these exists per URL the user pasted; the view renders a progress
/// row per entry and offers per-URL retry on [UrlFetchStatus.failure].
@immutable
class UrlImportResult {
  const UrlImportResult({
    required this.url,
    this.status = UrlFetchStatus.pending,
    this.extractedText,
    this.error,
  });

  final String url;
  final UrlFetchStatus status;
  final String? extractedText;
  final String? error;

  bool get isSuccess => status == UrlFetchStatus.success;
  bool get isFailure => status == UrlFetchStatus.failure;
  bool get isLoading => status == UrlFetchStatus.loading;
}

class UrlImportViewModel extends ImportBaseViewModel with UrlImportMixin {
  UrlImportViewModel({required super.importManager});

  // ---- BUT-947: multiple-URL ("batch") import -----------------------------

  List<UrlImportResult> _urlResults = const [];

  /// Editing the URL field invalidates any prior batch results. The mixin's
  /// [updateUrl] already resets single-URL extracted text; extend it to also
  /// drop the per-URL batch rows so a re-edit starts clean.
  @override
  void updateUrl(String url) {
    super.updateUrl(url);
    if (_urlResults.isNotEmpty) {
      _urlResults = const [];
      notifyListeners();
    }
  }

  /// Per-URL results for the most recent multi-URL fetch. Empty when the
  /// current input is a single URL (the legacy single-URL path is used then).
  List<UrlImportResult> get urlResults => List.unmodifiable(_urlResults);

  /// True when the current [url] input parses to more than one URL, i.e. the
  /// user pasted a list. Drives the view's per-URL progress list vs. the
  /// single-field flow.
  bool get isMultiUrl => parseUrls(url).length > 1;

  /// True once at least one URL in the batch succeeded — partial success still
  /// gives the user something to import.
  bool get hasAnyUrlSuccess => _urlResults.any((r) => r.isSuccess);

  /// Number of URLs in the batch that fetched successfully — drives the
  /// "Importera N recept" CTA count once the batch settles.
  int get successfulUrlCount => _urlResults.where((r) => r.isSuccess).length;

  /// BUT-947: the extracted text of every successfully-fetched URL, joined with
  /// the same blank-line separator the multi-recipe splitter treats as a recipe
  /// boundary. Feeding this into the paste step turns a successful batch fetch
  /// into N recipes via the shared multi-recipe picker — without this getter a
  /// batch that fetched fine had no path forward (the success state dead-ended).
  String get successfulBatchText => _urlResults
      .where((r) => r.isSuccess && (r.extractedText?.isNotEmpty ?? false))
      .map((r) => r.extractedText!)
      .join('\n\n');

  /// True when every URL in the batch failed (used to surface a batch-level
  /// error instead of leaving the user staring at all-red rows with no banner).
  bool get allUrlsFailed =>
      _urlResults.isNotEmpty && _urlResults.every((r) => r.isFailure);

  /// Splits a free-text input into candidate URLs. Accepts newline-, comma-,
  /// space-, semicolon- and tab-separated lists (the natural ways a user pastes
  /// several browser-tab URLs) and keeps only well-formed http(s) URLs so a
  /// trailing word or stray token doesn't become a phantom import row.
  /// De-duplicates while preserving order.
  static List<String> parseUrls(String input) {
    final tokens = input
        .split(RegExp(r'[\s,;]+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty);

    final seen = <String>{};
    final urls = <String>[];
    for (final token in tokens) {
      if (!_isFetchableUrl(token)) continue;
      if (seen.add(token)) urls.add(token);
    }
    return urls;
  }

  static bool _isFetchableUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    if (!uri.hasAuthority) return false;
    return !_isPrivateOrReservedHost(uri.host);
  }

  /// Fetches every URL in the current multi-URL input sequentially — one at a
  /// time, never N concurrent fetches — for cost/rate-limit safety (BUT-947),
  /// exposing per-URL progress via [urlResults] and tolerating partial failure
  /// so one dead link doesn't abort the whole batch. Mirrors the per-page
  /// failure handling of multi-page photo import. Returns without setting a
  /// global error unless *every* URL failed, so the view can render successful
  /// rows alongside failed ones.
  Future<void> fetchMultipleUrls() async {
    if (isDisposed) return;

    final urls = parseUrls(url);
    if (urls.isEmpty) {
      setError(AppLocale.current.errorPleaseEnterValidUrl);
      return;
    }

    clearError();
    _urlResults = [
      for (final u in urls)
        UrlImportResult(url: u, status: UrlFetchStatus.loading),
    ];
    setLoading(true);

    // Sequential, not Future.wait: fetch one URL at a time so a pasted list
    // never fans out into N concurrent network/LLM calls (BUT-947 cost/
    // rate-limit safety). Each fetch updates its own row, so progress still
    // streams in per-URL.
    for (var i = 0; i < urls.length; i++) {
      if (isDisposed) return;
      await _fetchOneInto(i, urls[i]);
    }

    if (isDisposed) return;
    setLoading(false);

    if (allUrlsFailed) {
      setError(AppLocale.current.importUrlBatchAllFailed);
    }
  }

  /// Retries a single failed URL in the batch without disturbing the others.
  Future<void> retryUrl(int index) async {
    if (isDisposed) return;
    if (index < 0 || index >= _urlResults.length) return;

    final target = _urlResults[index];
    // Fresh result (not copyWith) so the prior error string is dropped while
    // the row shows the loading state.
    _updateUrlResult(
      index,
      UrlImportResult(url: target.url, status: UrlFetchStatus.loading),
    );

    await _fetchOneInto(index, target.url);

    if (isDisposed) return;
    // A retry can clear an all-failed batch error.
    if (hasAnyUrlSuccess &&
        error == AppLocale.current.importUrlBatchAllFailed) {
      clearError();
    } else if (allUrlsFailed) {
      setError(AppLocale.current.importUrlBatchAllFailed);
    }
  }

  Future<void> _fetchOneInto(int index, String singleUrl) async {
    try {
      final text = await fetchContentFromUrl(singleUrl);
      if (isDisposed) return;
      _updateUrlResult(
        index,
        UrlImportResult(
          url: singleUrl,
          status: UrlFetchStatus.success,
          extractedText: text,
        ),
      );
    } catch (e) {
      if (isDisposed) return;
      _updateUrlResult(
        index,
        UrlImportResult(
          url: singleUrl,
          status: UrlFetchStatus.failure,
          error: e.toString(),
        ),
      );
    }
  }

  void _updateUrlResult(int index, UrlImportResult result) {
    if (isDisposed) return;
    if (index < 0 || index >= _urlResults.length) return;
    final next = List<UrlImportResult>.from(_urlResults);
    next[index] = result;
    _urlResults = next;
    notifyListeners();
  }

  void clearUrlResults() {
    if (isDisposed) return;
    if (_urlResults.isEmpty) return;
    _urlResults = const [];
    notifyListeners();
  }

  /// Single-URL flow: fetch content, then parse it only if the fetch yielded
  /// text and didn't error.
  Future<void> fetchAndParse() async {
    if (!canFetch) {
      setError(AppLocale.current.errorPleaseEnterValidUrl);
      return;
    }

    // First fetch content from URL
    await fetchFromUrl();

    // If successful, perform import
    if (hasExtractedText && !hasError) {
      await performImport();
    }
  }

  Future<bool> importAndSave() async {
    return await completeImport();
  }

  /// Overrides the mixin's basic HTTP fetch with the full WebScraper path
  /// (platform detection + headless extraction). Always disposes the scraper.
  @override
  Future<String> fetchContentFromUrl(String url) async {
    // Detect platform for optimized extraction
    final platformDetector = pd.PlatformDetector();
    final platform = platformDetector.detectPlatform(url);

    // Convert mobile URLs to web versions if needed
    final webUrl = platformDetector.convertToWebUrl(url);

    // Use WebScraper service for advanced content extraction
    final webScraper = WebScraper();

    try {
      final extractionResult =
          await webScraper.performExtraction(webUrl, platform);

      if (extractionResult.success && extractionResult.extractedText != null) {
        return extractionResult.extractedText!;
      } else {
        throw Exception(
            extractionResult.error ?? AppLocale.current.errorGeneric);
      }
    } finally {
      // Always dispose WebScraper to prevent memory leaks
      webScraper.dispose();
    }
  }

  /// Swedish-localized validation errors for the current URL (empty scheme,
  /// non-http(s), missing domain, private/reserved host, malformed).
  List<String> getUrlValidationErrors() {
    if (url.trim().isEmpty) {
      return [AppLocale.current.validationUrlRequired];
    }

    final errors = <String>[];
    final trimmedUrl = url.trim();

    try {
      final uri = Uri.parse(trimmedUrl);

      final l = AppLocale.current;
      if (!uri.hasScheme) {
        errors.add(l.errorUrlMissingScheme);
      } else if (uri.scheme != 'http' && uri.scheme != 'https') {
        errors.add(l.errorUrlUnsupportedScheme);
      }

      if (!uri.hasAuthority) {
        errors.add(l.errorUrlMissingDomain);
      } else if (_isPrivateOrReservedHost(uri.host)) {
        errors.add(l.errorUrlPrivateAddress);
      }
    } catch (e) {
      errors.add(AppLocale.current.errorInvalidUrlFormat);
    }

    return errors;
  }

  /// Returns true if the host is a private, loopback, or reserved address.
  ///
  /// BUT-1303: delegates to the single tested SSRF guard in
  /// [HttpContentFetcher.isBlockedHost] rather than carrying a second,
  /// string-prefix-based copy. The fetcher's guard parses the host as an
  /// [InternetAddress], so it also catches cases this VM's old string match
  /// missed — full `127.0.0.0/8` (not just `127.0.0.1`), IPv4-mapped IPv6
  /// (`::ffff:10.0.0.1`), and `uri.host`'s bracket-stripped IPv6 form (`::1`,
  /// which never equalled the old `[::1]` literal). One guard, one test surface.
  static bool _isPrivateOrReservedHost(String host) =>
      HttpContentFetcher.isBlockedHost(host);

  /// True when the URL's domain is a curated recipe site — drives the
  /// higher-success-probability suggestion shown to the user.
  bool isKnownRecipeSite() {
    if (!canFetch) return false;

    final domain = Uri.parse(url.trim()).host.toLowerCase();
    final knownSites = [
      // International recipe sites
      'allrecipes.com',
      'food.com',
      'epicurious.com',
      'foodnetwork.com',
      'delish.com',
      'tasty.co',
      'recipetineats.com',
      'simplyrecipes.com',

      // Swedish recipe sites
      'ica.se',
      'arla.se',
      'koket.se',
      'recepten.se',
      'tasteline.com',
      'mittkok.expressen.se',
    ];

    return knownSites.any((site) => domain.contains(site));
  }

  /// Swedish-localized hints shown before fetching (known/unknown site,
  /// recipe keyword present, over-long URL, social-media source).
  List<String> getUrlSuggestions() {
    if (!canFetch) {
      return getUrlValidationErrors();
    }

    final suggestions = <String>[];

    final l = AppLocale.current;
    if (isKnownRecipeSite()) {
      suggestions.add(l.urlSuggestionKnownSite);
    } else {
      suggestions.add(l.urlSuggestionUnknownSite);
    }

    if (url.contains('recipe') || url.contains('recept')) {
      suggestions.add(l.urlSuggestionContainsRecipeKeyword);
    }

    if (url.length > 200) {
      suggestions.add(l.urlSuggestionTooLong);
    }

    if (url.contains('instagram.com') ||
        url.contains('facebook.com') ||
        url.contains('tiktok.com')) {
      suggestions.add(l.urlSuggestionSocialMedia);
    }

    if (suggestions.length == 1 && isKnownRecipeSite()) {
      suggestions.add(l.urlSuggestionOptimal);
    }

    return suggestions;
  }

  /// Heuristically scores the extracted text (0-100) by recipe indicators
  /// and length, returning {quality, score, issues, positives} for UI feedback.
  Map<String, dynamic> analyzeExtractedContent() {
    if (!hasExtractedText) {
      return {
        'quality': 'none',
        'score': 0,
        'issues': [AppLocale.current.analysisNoContentExtracted],
      };
    }

    final text = extractedText.toLowerCase();
    int score = 0;
    final issues = <String>[];
    final positives = <String>[];

    // Check for recipe indicators (Swedish and English)
    if (text.contains('ingrediens') || text.contains('ingredient')) {
      score += 25;
      positives.add(AppLocale.current.analysisContainsIngredients);
    } else {
      issues.add(AppLocale.current.analysisNoIngredientsFound);
    }

    if (text.contains('instruktion') ||
        text.contains('instruction') ||
        text.contains('steg') ||
        text.contains('step') ||
        text.contains('gör så här') ||
        text.contains('method')) {
      score += 25;
      positives.add(AppLocale.current.analysisContainsInstructions);
    } else {
      issues.add(AppLocale.current.analysisNoInstructionsFound);
    }

    if (text.contains('minut') ||
        text.contains('minute') ||
        text.contains('timme') ||
        text.contains('hour') ||
        text.contains('tid') ||
        text.contains('time')) {
      score += 15;
      positives.add(AppLocale.current.analysisContainsTimeInfo);
    }

    if (text.contains('portion') ||
        text.contains('serve') ||
        text.contains('servering') ||
        text.contains('yield')) {
      score += 10;
      positives.add(AppLocale.current.analysisContainsPortionInfo);
    }

    // Check content length
    if (extractedText.length > 500) {
      score += 15;
      positives.add(AppLocale.current.analysisGoodContentLength);
    } else if (extractedText.length < 200) {
      issues.add(AppLocale.current.analysisContentTooShort);
    }

    // Check for recipe title patterns
    if (text.contains('recipe') || text.contains('recept')) {
      score += 10;
      positives.add(AppLocale.current.analysisContainsRecipeKeywords);
    }

    String quality;
    if (score >= 75) {
      quality = 'excellent';
    } else if (score >= 50) {
      quality = 'good';
    } else if (score >= 25) {
      quality = 'fair';
    } else {
      quality = 'poor';
    }

    return {
      'quality': quality,
      'score': score,
      'issues': issues,
      'positives': positives,
    };
  }

  @override
  Map<String, dynamic> get debugState => {
        ...super.debugState,
        'urlValidationErrors': getUrlValidationErrors(),
        'isKnownRecipeSite': isKnownRecipeSite(),
        'urlSuggestions': getUrlSuggestions(),
        'contentAnalysis': analyzeExtractedContent(),
        'urlLength': url.length,
        'hasExtractedContent': hasExtractedText,
        'extractedContentLength': hasExtractedText ? extractedText.length : 0,
      };
}
