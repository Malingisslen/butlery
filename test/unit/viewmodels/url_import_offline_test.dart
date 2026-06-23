import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/url_import_viewmodel.dart';
import 'package:butlery/core/l10n/app_locale.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

/// BUT-610: tracks whether the WebScraper leaf was reached. The offline
/// pre-check must short-circuit BEFORE any scrape, so an offline fetch must
/// leave [fetchContentCalls] at zero — proving the ~15s headless-WebView
/// timeout is never entered.
class _ScraperTrackingUrlImportViewModel extends UrlImportViewModel {
  _ScraperTrackingUrlImportViewModel({
    required super.importManager,
    required super.connectivity,
  });

  int fetchContentCalls = 0;

  @override
  Future<String> fetchContentFromUrl(String url) async {
    fetchContentCalls++;
    return 'recipe content for $url long enough to count as a body';
  }
}

void main() {
  group('UrlImportViewModel offline pre-check (BUT-610)', () {
    late MockImportManager mockImportManager;
    late MockConnectivityMonitoringService mockConnectivity;
    late _ScraperTrackingUrlImportViewModel viewModel;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      mockImportManager = MockImportManager();
      mockConnectivity = MockConnectivityMonitoringService();
      // Offline: every entry point must fail fast.
      when(() => mockConnectivity.isConnectedToInternet).thenReturn(false);

      viewModel = _ScraperTrackingUrlImportViewModel(
        importManager: mockImportManager,
        connectivity: mockConnectivity,
      );
    });

    tearDown(() async {
      viewModel.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    test('single-URL fetchFromUrl sets the offline message and never calls the '
        'scraper', () async {
      viewModel.updateUrl('https://example.com/recipe');

      await viewModel.fetchFromUrl();

      expect(viewModel.error, AppLocale.current.importOfflineMessage);
      expect(viewModel.hasExtractedText, isFalse);
      expect(
        viewModel.fetchContentCalls,
        0,
        reason: 'scraper must not run while offline',
      );
    });

    test('fetchAndParse stops at the offline pre-check without scraping or '
        'parsing', () async {
      viewModel.updateUrl('https://example.com/recipe');

      await viewModel.fetchAndParse();

      expect(viewModel.error, AppLocale.current.importOfflineMessage);
      expect(viewModel.fetchContentCalls, 0);
      expect(viewModel.hasParsedRecipe, isFalse);
    });

    test('multi-URL fetchMultipleUrls sets the offline message and never calls '
        'the scraper', () async {
      viewModel.updateUrl(
        'https://example.com/one\nhttps://example.com/two',
      );

      await viewModel.fetchMultipleUrls();

      expect(viewModel.error, AppLocale.current.importOfflineMessage);
      expect(
        viewModel.fetchContentCalls,
        0,
        reason: 'no URL in the batch should be scraped while offline',
      );
      expect(viewModel.hasAnyUrlSuccess, isFalse);
    });

    test(
      'online path is preserved — fetchFromUrl reaches the scraper',
      () async {
        when(() => mockConnectivity.isConnectedToInternet).thenReturn(true);
        viewModel.updateUrl('https://example.com/recipe');

        await viewModel.fetchFromUrl();

        expect(viewModel.fetchContentCalls, 1);
        expect(viewModel.error, isNull);
        expect(viewModel.hasExtractedText, isTrue);
      },
    );
  });
}
