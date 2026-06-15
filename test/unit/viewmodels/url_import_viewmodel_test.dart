import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:butlery/viewmodels/url_import_viewmodel.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/index_page_expander.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;

// Using centralized mocks from production_mocks.dart:
// - MockImportManager with setImportManagerState() method
// - MockTextImportStrategy with stubbing support

// Using local mock patterns that follow centralized architecture
class MockHttpClient extends Mock implements http.Client {}

// Test HTTP Response
class TestHttpResponse extends http.Response {
  TestHttpResponse(super.body, super.statusCode);
}

// Testable version that overrides ONLY the leaf network call.
//
// Production's [UrlImportViewModel.fetchContentFromUrl] delegates to the
// headless-browser WebScraper, which we can't drive in a unit test. We stub
// just that leaf so the REAL inherited orchestration runs unchanged:
// fetchFromUrl() stores the returned text into extractedText via executeAsync
// (incl. its error/loading lifecycle), fetchAndParse() feeds it to the import
// strategy, analyzeExtractedContent() scores it, and the BUT-947 multi-URL
// batch logic sequences the fetches. The stub mirrors WebScraper's only real
// content contract — return the extracted text, or throw on failure — and adds
// no HTTP-status / fallback-retry / length policy that production does not have
// (asserting such fixture-only logic would prove nothing about production).
class TestableUrlImportViewModel extends UrlImportViewModel {
  final http.Client? testHttpClient;

  TestableUrlImportViewModel({
    required super.importManager,
    this.testHttpClient,
    super.indexExpander,
  });

  @override
  Future<String> fetchContentFromUrl(String url) async {
    if (testHttpClient != null) {
      // A single fetch, like WebScraper.performExtraction: success returns the
      // body, any failure (network throw or non-200) propagates so the real
      // executeAsync error path in fetchFromUrl is exercised.
      final response = await testHttpClient!.get(
        Uri.parse(url),
        headers: _stubHeaders,
      );
      if (response.statusCode != 200) {
        throw Exception(
            'Kunde inte hämta innehåll från URL: HTTP ${response.statusCode}');
      }
      return response.body;
    }
    return super.fetchContentFromUrl(url);
  }

  static const Map<String, String> _stubHeaders = {
    'User-Agent': 'butlery-test',
  };
}

/// Records how many [fetchContentFromUrl] calls are in flight at once so a test
/// can prove the batch fetch is sequential (BUT-947). Each call holds for a
/// real delay; if the batch fired concurrently every call would overlap and
/// [maxInFlight] would climb above 1.
class ConcurrencyTrackingUrlImportViewModel extends UrlImportViewModel {
  ConcurrencyTrackingUrlImportViewModel({required super.importManager});

  int _inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<String> fetchContentFromUrl(String url) async {
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    _inFlight--;
    return 'recipe content for $url long enough to count as a body';
  }
}

/// Invokes [onMidFetch] during the FIRST per-URL fetch, before that fetch
/// resolves, so a test can observe the in-flight [urlResults] (rows still
/// seeded [UrlFetchStatus.loading]) and prove `UrlImportResult.isLoading`
/// reflects the loading status. Only fires once to keep the snapshot
/// unambiguous.
class _LoadingObservingUrlImportViewModel extends UrlImportViewModel {
  _LoadingObservingUrlImportViewModel({
    required super.importManager,
    required this.onMidFetch,
  });

  final void Function(_LoadingObservingUrlImportViewModel vm) onMidFetch;
  bool _fired = false;

  @override
  Future<String> fetchContentFromUrl(String url) async {
    if (!_fired) {
      _fired = true;
      onMidFetch(this);
    }
    return 'recipe content for $url long enough to count as a body';
  }
}

/// BUT-1273: returns canned harvested links so the VM's detect/expand flow can
/// be tested without a real network fetch. The link-harvest logic itself is
/// covered in index_page_detector_test.dart.
class _FakeIndexExpander extends IndexPageExpander {
  _FakeIndexExpander(this._links);
  final List<String> _links;

  @override
  Future<List<String>> harvest(String url) async => _links;
}

void main() {
  group('UrlImportViewModel', () {
    late TestableUrlImportViewModel viewModel;
    late MockImportManager mockImportManager;
    late MockTextImportStrategy mockTextStrategy; // Centralized mock
    late MockHttpClient mockHttpClient;

    // Test HTML content
    const testHtmlContent = '''
      <!DOCTYPE html>
      <html>
      <head><title>Pannkakor - Klassiskt recept</title></head>
      <body>
        <h1>Svenska Pannkakor</h1>
        <section class="ingredients">
          <h2>Ingredienser</h2>
          <ul>
            <li>3 ägg</li>
            <li>3 dl mjölk</li>
            <li>2 dl vetemjöl</li>
            <li>1 tsk salt</li>
            <li>2 msk smält smör</li>
          </ul>
        </section>
        <section class="instructions">
          <h2>Instruktioner</h2>
          <ol>
            <li>Vispa ihop ägg och hälften av mjölken</li>
            <li>Tillsätt mjöl och salt, vispa till en slät smet</li>
            <li>Rör i resten av mjölken och det smälta smöret</li>
            <li>Låt smeten svälla 10 minuter</li>
            <li>Stek tunna pannkakor i smör</li>
          </ol>
        </section>
        <p>Tid: 20 minuter | Portioner: 4</p>
      </body>
      </html>
    ''';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      // BUT-1181: bridge the production ServiceLocator so saveImportedRecipe()'s
      // ServiceLocator.get<HeirloomBridge>() resolves (DIContainer wraps the
      // shared GetIt where TestServiceLocator registers HeirloomBridge).
      prod_locator.ServiceLocator.initialize(DIContainer());
      registerFallbackValue(Uri.parse('https://example.com'));
      registerFallbackValue(RecipeFactory.build());
      registerFallbackValue(<String, String>{});
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks
      mockImportManager = MockImportManager();
      mockHttpClient = MockHttpClient();

      // Configure ImportManager mock using centralized setImportManagerState()
      mockTextStrategy = MockTextImportStrategy();
      when(() => mockTextStrategy.import(any(), options: any(named: 'options')))
          .thenAnswer((_) async => ImportResult.success(
                RecipeFactory.build(
                  title: 'Svenska Pannkakor',
                  description: 'Klassiska tunna pannkakor',
                  ingredients: [
                    '3 ägg',
                    '3 dl mjölk',
                    '2 dl vetemjöl',
                    '1 tsk salt',
                    '2 msk smält smör'
                  ],
                  instructions: [
                    'Vispa ihop',
                    'Tillsätt mjöl',
                    'Rör i smör',
                    'Låt svälla',
                    'Stek i panna'
                  ],
                  timeMinutes: 20,
                  portions: 4,
                ),
              ));

      mockImportManager.setImportManagerState(
        textImportStrategy: mockTextStrategy,
      );

      // Configure ImportManager save
      when(() => mockImportManager.saveImportedRecipe(any()))
          .thenAnswer((_) async => ImportManagerResult.success(
                RecipeFactory.build(),
                strategy: 'url',
              ));

      // Configure default HTTP responses
      when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => TestHttpResponse(testHtmlContent, 200));

      // Create viewModel
      viewModel = TestableUrlImportViewModel(
        importManager: mockImportManager,
        testHttpClient: mockHttpClient,
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

    group('Initialization', () {
      test('should initialize with default state', () {
        // Arrange - viewModel created in setUp

        // Act - no action needed, checking initial state

        // Assert
        expect(viewModel.url, isEmpty);
        expect(viewModel.extractedText, isEmpty);
        expect(viewModel.hasExtractedText, isFalse);
        expect(viewModel.canFetch, isFalse);
        expect(viewModel.canImport, isFalse);
        expect(viewModel.hasParsedRecipe, isFalse);
        expect(viewModel.parsedRecipe, isNull);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
      });

      test('should have correct import type', () {
        // Assert
        expect(viewModel.importType, equals('url'));
      });
    });

    group('URL Input Management', () {
      test('should update URL', () {
        // Arrange
        const testUrl = 'https://www.ica.se/recept/pannkakor-grundrecept';
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.updateUrl(testUrl);

        // Assert
        expect(viewModel.url, equals(testUrl));
        expect(viewModel.canFetch, isTrue);
        expect(notificationCount, greaterThan(0));
      });

      test('should validate URL format', () {
        // Arrange
        viewModel.updateUrl('not-a-url');

        // Act
        final canFetch = viewModel.canFetch;

        // Assert
        expect(canFetch, isFalse);
      });

      test('should accept HTTP URLs', () {
        // Act
        viewModel.updateUrl('http://example.com/recipe');

        // Assert
        expect(viewModel.canFetch, isTrue);
      });

      test('should accept HTTPS URLs', () {
        // Act
        viewModel.updateUrl('https://example.com/recipe');

        // Assert
        expect(viewModel.canFetch, isTrue);
      });

      test('should reject invalid URL schemes', () {
        // Act
        viewModel.updateUrl('ftp://example.com/recipe');

        // Assert
        expect(viewModel.canFetch, isFalse);
      });

      test('should clear previous data when URL changes', () {
        // Arrange
        viewModel.updateUrl('https://example.com/recipe1');

        // Act
        viewModel.updateUrl('https://example.com/recipe2');

        // Assert
        expect(viewModel.extractedText, isEmpty);
        expect(viewModel.parsedRecipe, isNull);
      });
    });

    group('URL Validation', () {
      test('should provide validation errors for empty URL', () {
        // Arrange
        viewModel.updateUrl('');

        // Act
        final errors = viewModel.getUrlValidationErrors();

        // Assert
        expect(errors, isNotEmpty);
        expect(errors.first, equals('URL krävs'));
      });

      test('should validate URL without scheme', () {
        // Arrange
        viewModel.updateUrl('example.com/recipe');

        // Act
        final errors = viewModel.getUrlValidationErrors();

        // Assert
        expect(errors, contains('URL måste inkludera http:// eller https://'));
      });

      test('should validate invalid URL format', () {
        // Arrange
        viewModel.updateUrl('https://[invalid');

        // Act
        final errors = viewModel.getUrlValidationErrors();

        // Assert
        expect(errors, contains('Ogiltigt URL-format'));
      });

      test('should validate non-HTTP schemes', () {
        // Arrange
        viewModel.updateUrl('ftp://example.com/file');

        // Act
        final errors = viewModel.getUrlValidationErrors();

        // Assert
        expect(errors, contains('Endast HTTP- och HTTPS-URL:er stöds'));
      });

      test('should pass validation for valid URL', () {
        // Arrange
        viewModel.updateUrl('https://www.example.com/recipe');

        // Act
        final errors = viewModel.getUrlValidationErrors();

        // Assert
        expect(errors, isEmpty);
      });
    });

    // BUT-1303: the single-URL SSRF guard. getUrlValidationErrors() rejects
    // private/loopback/reserved hosts with errorUrlPrivateAddress, and canFetch
    // goes false. Since the guard now delegates to the parsed-address
    // HttpContentFetcher.isBlockedHost (not the old string-prefix copy), these
    // assert every block branch through the public validation surface — and
    // pin the cases the old copy missed (full 127/8, IPv4-mapped IPv6, the
    // bracket-stripped uri.host IPv6 form). Each blocked host is paired with a
    // public sibling so the test also proves the guard isn't over-broad.
    group('SSRF host guard — getUrlValidationErrors (BUT-1303)', () {
      const privateAddressError =
          'URL:en pekar på en privat eller reserverad adress och kan inte användas';

      void expectBlocked(String url) {
        viewModel.updateUrl(url);
        expect(
            viewModel.getUrlValidationErrors(), contains(privateAddressError),
            reason: '$url should be flagged as a private/reserved host');
        // NOTE: canFetch only checks the scheme (ImportBaseViewModel._isValidUrl),
        // so it stays true here — the SSRF block surfaces through the validation
        // errors and the batch parseUrls() drop, which is what this guard governs.
      }

      void expectAllowed(String url) {
        viewModel.updateUrl(url);
        expect(viewModel.getUrlValidationErrors(),
            isNot(contains(privateAddressError)),
            reason: '$url is public and must not be flagged private');
      }

      test('blocks localhost', () => expectBlocked('http://localhost/recipe'));

      test('blocks loopback 127.0.0.1',
          () => expectBlocked('http://127.0.0.1/recipe'));

      test('blocks the wider 127.0.0.0/8 loopback range (old copy missed this)',
          () => expectBlocked('http://127.1.2.3/recipe'));

      test('blocks 0.0.0.0', () => expectBlocked('http://0.0.0.0/recipe'));

      test('blocks 10.0.0.0/8 private range',
          () => expectBlocked('http://10.0.0.5/recipe'));

      test('blocks 172.16.0.0/12 private range',
          () => expectBlocked('http://172.16.0.1/recipe'));

      test('blocks 172.31.x (upper bound of 172.16.0.0/12)',
          () => expectBlocked('http://172.31.255.254/recipe'));

      test('does NOT block 172.32.x (just outside 172.16.0.0/12)',
          () => expectAllowed('http://172.32.0.1/recipe'));

      test('blocks 192.168.0.0/16 private range',
          () => expectBlocked('http://192.168.1.10/recipe'));

      test('blocks 169.254.0.0/16 link-local',
          () => expectBlocked('http://169.254.1.1/recipe'));

      test('blocks IPv6 loopback ::1 (bracket-stripped uri.host form)',
          () => expectBlocked('http://[::1]/recipe'));

      test('blocks IPv6 unique-local fc00::/7',
          () => expectBlocked('http://[fc00::1]/recipe'));

      test('blocks IPv6 link-local fe80::/10',
          () => expectBlocked('http://[fe80::1]/recipe'));

      test('blocks IPv4-mapped IPv6 ::ffff:10.0.0.1 (old copy missed this)',
          () => expectBlocked('http://[::ffff:10.0.0.1]/recipe'));

      test('allows a public IPv4 host',
          () => expectAllowed('http://93.184.216.34/recipe'));

      test('allows a public hostname',
          () => expectAllowed('https://www.example.com/recipe'));

      test('allows a public IPv6 host',
          () => expectAllowed('http://[2606:2800:220:1:248:1893:25c8:1946]/r'));
    });

    group('Recipe Site Recognition', () {
      test('should recognize ICA recipe site', () {
        // Arrange
        viewModel.updateUrl('https://www.ica.se/recept/pannkakor');

        // Act
        final isKnown = viewModel.isKnownRecipeSite();

        // Assert
        expect(isKnown, isTrue);
      });

      test('should recognize Arla recipe site', () {
        // Arrange
        viewModel.updateUrl('https://www.arla.se/recept/pasta');

        // Act
        final isKnown = viewModel.isKnownRecipeSite();

        // Assert
        expect(isKnown, isTrue);
      });

      test('should recognize international recipe sites', () {
        // Test various international sites
        final sites = [
          'https://www.allrecipes.com/recipe/123',
          'https://www.food.com/recipe/456',
          'https://www.epicurious.com/recipe',
          'https://www.foodnetwork.com/recipes',
          'https://www.delish.com/cooking',
          'https://tasty.co/recipe/789',
        ];

        for (final site in sites) {
          viewModel.updateUrl(site);
          expect(viewModel.isKnownRecipeSite(), isTrue,
              reason: 'Should recognize $site');
        }
      });

      test('should not recognize unknown sites', () {
        // Arrange
        viewModel.updateUrl('https://www.example.com/page');

        // Act
        final isKnown = viewModel.isKnownRecipeSite();

        // Assert
        expect(isKnown, isFalse);
      });

      test('should handle subdomains correctly', () {
        // Arrange
        viewModel.updateUrl('https://recept.ica.se/pannkakor');

        // Act
        final isKnown = viewModel.isKnownRecipeSite();

        // Assert
        expect(isKnown, isTrue);
      });
    });

    group('URL Suggestions', () {
      test('should suggest for known recipe site', () {
        // Arrange
        viewModel.updateUrl('https://www.ica.se/recept/pannkakor');

        // Act
        final suggestions = viewModel.getUrlSuggestions();

        // Assert
        expect(suggestions,
            contains('Känd receptsida — bra chans att importera!'));
      });

      test('should warn for unknown site', () {
        // Arrange
        viewModel.updateUrl('https://www.example.com/page');

        // Act
        final suggestions = viewModel.getUrlSuggestions();

        // Assert
        expect(suggestions, contains('Okänd sida — import kan vara begränsad'));
      });

      test('should identify recipe keywords in URL', () {
        // Arrange
        viewModel.updateUrl('https://www.example.com/recipe/pasta');

        // Act
        final suggestions = viewModel.getUrlSuggestions();

        // Assert
        expect(suggestions, contains('URL:en innehåller receptnyckelord'));
      });

      test('should warn about long URLs', () {
        // Arrange
        final longUrl = 'https://www.example.com/${'a' * 200}';
        viewModel.updateUrl(longUrl);

        // Act
        final suggestions = viewModel.getUrlSuggestions();

        // Assert
        expect(
            suggestions,
            contains(
                'URL:en är ovanligt lång — kontrollera att den är korrekt'));
      });

      test('should identify social media links', () {
        // Test various social media platforms
        final socialUrls = [
          'https://www.instagram.com/p/abc123',
          'https://www.facebook.com/recipe/123',
          'https://www.tiktok.com/@user/video',
        ];

        for (final url in socialUrls) {
          viewModel.updateUrl(url);
          final suggestions = viewModel.getUrlSuggestions();
          expect(suggestions,
              contains('Sociala medier — import kräver ibland extra steg'));
        }
      });

      test('should provide optimal suggestion for perfect URL', () {
        // Arrange
        viewModel.updateUrl(
            'https://www.ica.se/pannkakor'); // URL without 'recept' keyword

        // Act
        final suggestions = viewModel.getUrlSuggestions();

        // Assert
        // When it's a known site but no recipe keyword, should still get known site message
        expect(suggestions,
            contains('Känd receptsida — bra chans att importera!'));
        // When only one positive suggestion and is known site, should show optimal
        expect(suggestions.any((s) => s.contains('Perfekt')), isTrue);
      });

      test('should return validation errors when URL invalid', () {
        // Arrange
        viewModel.updateUrl('not-a-url');

        // Act
        final suggestions = viewModel.getUrlSuggestions();

        // Assert
        expect(suggestions, isNotEmpty);
        expect(suggestions.first, contains('URL måste inkludera'));
      });
    });

    group('Content Fetching', () {
      test('should fetch content from URL successfully', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/recipe');

        // Act
        await viewModel.fetchFromUrl();

        // Assert
        expect(viewModel.hasExtractedText, isTrue);
        expect(viewModel.extractedText, isNotEmpty);
        expect(viewModel.error, isNull);
        verify(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .called(1);
      });

      // A failing fetch (here a non-200 surfaced as a throw, but the same path
      // covers any WebScraper failure) must propagate through the REAL
      // fetchFromUrl/executeAsync error lifecycle: no extracted text, error
      // flag set. This exercises production's actual error handling — the only
      // fetch-failure contract the production fetchContentFromUrl has.
      test('failed fetch sets the error state and extracts no text', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/notfound');
        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => TestHttpResponse('Not Found', 404));

        // Act — executeAsync rethrows, so catch the propagated exception
        try {
          await viewModel.fetchFromUrl();
        } catch (_) {
          // Expected: executeAsync sets error then rethrows
        }

        // Assert
        expect(viewModel.hasExtractedText, isFalse);
        expect(viewModel.hasError, isTrue);
      });

      test('network error during fetch propagates to the error state',
          () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/error');
        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenThrow(Exception('Network error'));

        // Act — executeAsync rethrows, so catch the propagated exception
        try {
          await viewModel.fetchFromUrl();
        } catch (_) {
          // Expected: executeAsync sets error then rethrows
        }

        // Assert
        expect(viewModel.hasExtractedText, isFalse);
        expect(viewModel.hasError, isTrue);
      });

      test('should set source URL when fetching', () async {
        // Arrange
        const testUrl = 'https://www.example.com/recipe';
        viewModel.updateUrl(testUrl);

        // Act
        await viewModel.fetchFromUrl();

        // Assert
        expect(viewModel.sourceUrl, equals(testUrl));
      });
    });

    group('Fetch and Parse Workflow', () {
      test('should fetch and parse successfully', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/recipe');

        // Act
        await viewModel.fetchAndParse();

        // Assert
        expect(viewModel.hasExtractedText, isTrue);
        expect(viewModel.hasParsedRecipe, isTrue);
        expect(viewModel.parsedRecipe, isNotNull);
        expect(viewModel.parsedRecipe!.title, equals('Svenska Pannkakor'));
        expect(viewModel.error, isNull);
      });

      test('should not parse without valid URL', () async {
        // Arrange
        viewModel.updateUrl('');

        // Act
        await viewModel.fetchAndParse();

        // Assert
        expect(viewModel.hasParsedRecipe, isFalse);
        expect(viewModel.error, equals('Vänligen ange en giltig URL'));
      });

      test('should not parse if fetch fails', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/error');
        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenThrow(Exception('Network error'));

        // Act — executeAsync rethrows, so catch the propagated exception
        try {
          await viewModel.fetchAndParse();
        } catch (_) {
          // Expected: executeAsync sets error then rethrows
        }

        // Assert
        expect(viewModel.hasParsedRecipe, isFalse);
        expect(viewModel.hasError, isTrue);
      });

      test('should parse after successful fetch', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/recipe');

        // Act
        await viewModel.fetchAndParse();

        // Assert
        expect(viewModel.hasParsedRecipe, isTrue);
        verify(() =>
                mockTextStrategy.import(any(), options: any(named: 'options')))
            .called(1);
      });
    });

    group('Import and Save', () {
      test('should complete full import workflow', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/recipe');
        // Need to fetch first to have extracted text
        await viewModel.fetchFromUrl();
        expect(viewModel.hasExtractedText, isTrue);

        // Act
        final result = await viewModel.importAndSave();

        // Assert
        expect(result, isTrue);
        expect(viewModel.hasParsedRecipe, isTrue);
        expect(viewModel.error, isNull);
        verify(() => mockImportManager.saveImportedRecipe(any())).called(1);
      });

      test('should not save without valid URL', () async {
        // Arrange
        viewModel.updateUrl('');

        // Act
        final result = await viewModel.importAndSave();

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockImportManager.saveImportedRecipe(any()));
      });

      test('should handle save failure', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/recipe');
        await viewModel.fetchFromUrl(); // Need to fetch first
        when(() => mockImportManager.saveImportedRecipe(any()))
            .thenAnswer((_) async => ImportManagerResult.failure(
                  'Failed to save',
                  strategy: 'url',
                ));

        // Act
        final result = await viewModel.importAndSave();

        // Assert
        expect(result, isFalse);
      });

      test('should track loading state during import', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/recipe');
        await viewModel.fetchFromUrl(); // Need to fetch first
        bool wasLoading = false;

        viewModel.addListener(() {
          if (viewModel.isLoading) wasLoading = true;
        });

        // Act
        await viewModel.importAndSave();

        // Assert
        expect(wasLoading, isTrue);
        expect(
            viewModel.isLoading, isFalse); // Should be false after completion
      });
    });

    group('Content Analysis', () {
      test('should analyze empty content', () {
        // Arrange - no extracted text

        // Act
        final analysis = viewModel.analyzeExtractedContent();

        // Assert
        expect(analysis['quality'], equals('none'));
        expect(analysis['score'], equals(0));
        expect(analysis['issues'], contains('Inget innehåll extraherat'));
      });

      test('should identify excellent content', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/recipe');
        await viewModel.fetchFromUrl();

        // Act
        final analysis = viewModel.analyzeExtractedContent();

        // Assert
        expect(analysis['quality'], equals('excellent'));
        expect(analysis['score'], greaterThanOrEqualTo(75));
        expect(analysis['positives'], contains('Innehåller ingredienser'));
        expect(analysis['positives'], contains('Innehåller instruktioner'));
      });

      test('should detect missing ingredients', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/recipe');
        when(() => mockHttpClient.get(any(),
            headers: any(
                named: 'headers'))).thenAnswer((_) async => TestHttpResponse(
            '<html><body>Recipe instructions only: Stek i panna. Servera varmt. Tid: 20 minuter.</body></html>',
            200));
        await viewModel.fetchFromUrl();

        // Act
        final analysis = viewModel.analyzeExtractedContent();

        // Assert
        expect(
            analysis['issues'], contains('Ingen ingredienssektion hittades'));
      });

      test('should detect missing instructions', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/recipe');
        when(() => mockHttpClient.get(any(),
            headers: any(
                named: 'headers'))).thenAnswer((_) async => TestHttpResponse(
            '<html><body>Ingredienser: 3 ägg, 2 dl mjölk, 1 dl mjöl. Portioner: 4.</body></html>',
            200));
        await viewModel.fetchFromUrl();

        // Act
        final analysis = viewModel.analyzeExtractedContent();

        // Assert
        expect(analysis['issues'], contains('Inga instruktioner hittades'));
      });

      test('should identify time information', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/recipe');
        await viewModel.fetchFromUrl();

        // Act
        final analysis = viewModel.analyzeExtractedContent();

        // Assert
        expect(analysis['positives'], contains('Innehåller tidsinformation'));
      });

      test('should identify portion information', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/recipe');
        await viewModel.fetchFromUrl();

        // Act
        final analysis = viewModel.analyzeExtractedContent();

        // Assert
        expect(
            analysis['positives'], contains('Innehåller portionsinformation'));
      });

      test('should score content appropriately', () async {
        // Test different quality levels
        final testCases = [
          {
            'content': testHtmlContent,
            'expectedQuality': 'excellent',
            'minScore': 75,
          },
          {
            'content': '<html><body>${'x' * 200}</body></html>',
            'expectedQuality': 'poor',
            'maxScore': 25,
          },
        ];

        for (final testCase in testCases) {
          viewModel.updateUrl('https://www.example.com/recipe');
          when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
              .thenAnswer((_) async =>
                  TestHttpResponse(testCase['content'] as String, 200));
          await viewModel.fetchFromUrl();

          final analysis = viewModel.analyzeExtractedContent();
          expect(analysis['quality'], equals(testCase['expectedQuality']));
          if (testCase['minScore'] != null) {
            expect(analysis['score'],
                greaterThanOrEqualTo(testCase['minScore'] as int));
          }
          if (testCase['maxScore'] != null) {
            expect(analysis['score'],
                lessThanOrEqualTo(testCase['maxScore'] as int));
          }
        }
      });
    });

    group('Clear Operations', () {
      test('should clear URL and data', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/recipe');
        await viewModel.fetchFromUrl();
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.clearUrl();

        // Assert
        expect(viewModel.url, isEmpty);
        expect(viewModel.extractedText, isEmpty);
        expect(viewModel.hasExtractedText, isFalse);
        expect(viewModel.parsedRecipe, isNull);
        expect(notificationCount, greaterThan(0));
      });
    });

    group('Debug State', () {
      test('should provide comprehensive debug information', () async {
        // Arrange
        viewModel.updateUrl('https://www.ica.se/recept/pannkakor');
        await viewModel.fetchFromUrl();

        // Act
        final debug = viewModel.debugState;

        // Assert
        expect(debug['urlValidationErrors'], isEmpty);
        expect(debug['isKnownRecipeSite'], isTrue);
        expect(debug['urlSuggestions'], isNotEmpty);
        expect(debug['contentAnalysis'], isNotNull);
        expect(debug['urlLength'], greaterThan(0));
        expect(debug['hasExtractedContent'], isTrue);
        expect(debug['extractedContentLength'], greaterThan(0));
      });
    });

    group('Lifecycle', () {
      test('should dispose without errors', () {
        // Arrange
        final testViewModel = TestableUrlImportViewModel(
          importManager: mockImportManager,
          testHttpClient: mockHttpClient,
        );

        // Act & Assert
        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test('should handle multiple operations', () async {
        // Act - Multiple operations
        viewModel.updateUrl('https://www.example.com/recipe1');
        await viewModel.fetchFromUrl();
        viewModel.updateUrl('https://www.example.com/recipe2');
        await viewModel.fetchAndParse();
        viewModel.clearUrl();
        viewModel.updateUrl('https://www.example.com/recipe3');
        await viewModel.fetchFromUrl(); // Need to fetch before import
        await viewModel.importAndSave();

        // Assert
        expect(viewModel.url, equals('https://www.example.com/recipe3'));
        expect(viewModel.hasParsedRecipe, isTrue);
        expect(viewModel.error, isNull);
      });

      test('should handle concurrent fetch operations gracefully', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/recipe');

        // Act - Start multiple fetch operations
        final fetch1 = viewModel.fetchFromUrl();
        final fetch2 = viewModel.fetchFromUrl();

        await Future.wait([fetch1, fetch2]);

        // Assert - Should handle gracefully without errors
        expect(viewModel.hasError, isFalse);
        expect(viewModel.hasExtractedText, isTrue);
      });
    });

    // BUT-947: list-aware URL import — pasting several URLs imports each one
    // with per-URL progress and partial-success handling.
    group('Multiple URL import (BUT-947)', () {
      test('parseUrls splits newline/comma/space lists and keeps only http(s)',
          () {
        final urls = UrlImportViewModel.parseUrls(
          'https://a.com/r1\nhttps://b.com/r2, https://c.com/r3 not-a-url '
          'ftp://d.com/x',
        );

        expect(urls, [
          'https://a.com/r1',
          'https://b.com/r2',
          'https://c.com/r3',
        ]);
      });

      test('parseUrls de-duplicates while preserving order', () {
        final urls = UrlImportViewModel.parseUrls(
          'https://a.com/r1 https://a.com/r1 https://b.com/r2',
        );

        expect(urls, ['https://a.com/r1', 'https://b.com/r2']);
      });

      test('parseUrls drops private/reserved hosts (SSRF guard)', () {
        // The single-URL path rejects these with errorUrlPrivateAddress; the
        // batch path must apply the same guard or pasting a list becomes an
        // SSRF vector. Each public sibling proves the drop isn't over-broad.
        final urls = UrlImportViewModel.parseUrls(
          'https://public.com/ok '
          'http://localhost/x '
          'http://127.0.0.1/x '
          'http://192.168.1.10/x '
          'http://10.0.0.5/x '
          'http://169.254.1.1/x '
          'https://other.com/ok',
        );

        expect(urls, ['https://public.com/ok', 'https://other.com/ok']);
      });

      test('isMultiUrl is true only when input parses to more than one URL',
          () {
        viewModel.updateUrl('https://a.com/r1');
        expect(viewModel.isMultiUrl, isFalse);

        viewModel.updateUrl('https://a.com/r1\nhttps://b.com/r2');
        expect(viewModel.isMultiUrl, isTrue);
      });

      test('fetchMultipleUrls fetches every URL and records per-URL success',
          () async {
        viewModel.updateUrl('https://a.com/r1\nhttps://b.com/r2');

        await viewModel.fetchMultipleUrls();

        expect(viewModel.urlResults, hasLength(2));
        expect(viewModel.urlResults.every((r) => r.isSuccess), isTrue);
        expect(viewModel.hasAnyUrlSuccess, isTrue);
        expect(viewModel.allUrlsFailed, isFalse);
        expect(viewModel.hasError, isFalse);
      });

      test(
          'fetchMultipleUrls fetches URLs sequentially, never concurrently '
          '(BUT-947 cost/rate-limit safety)', () async {
        final tracking = ConcurrencyTrackingUrlImportViewModel(
          importManager: mockImportManager,
        );
        addTearDown(tracking.dispose);
        tracking.updateUrl(
          'https://a.com/r1\nhttps://b.com/r2\nhttps://c.com/r3',
        );

        await tracking.fetchMultipleUrls();

        // Sequential fetch => only one request is ever in flight. A regression
        // to Future.wait (concurrent fan-out) would push this to 3 and fail.
        expect(tracking.maxInFlight, 1);
        expect(tracking.urlResults, hasLength(3));
        expect(tracking.urlResults.every((r) => r.isSuccess), isTrue);
      });

      test('partial failure keeps successful rows and does not set batch error',
          () async {
        // Second URL fails; first succeeds.
        when(() => mockHttpClient.get(
              Uri.parse('https://b.com/r2'),
              headers: any(named: 'headers'),
            )).thenThrow(Exception('boom'));

        viewModel.updateUrl('https://a.com/r1\nhttps://b.com/r2');
        await viewModel.fetchMultipleUrls();

        expect(viewModel.urlResults[0].isSuccess, isTrue);
        expect(viewModel.urlResults[1].isFailure, isTrue);
        expect(viewModel.hasAnyUrlSuccess, isTrue);
        expect(viewModel.allUrlsFailed, isFalse);
        // Partial success → no global blocking error banner.
        expect(viewModel.hasError, isFalse);
      });

      test('all URLs failing surfaces the batch-level error', () async {
        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenThrow(Exception('boom'));

        viewModel.updateUrl('https://a.com/r1\nhttps://b.com/r2');
        await viewModel.fetchMultipleUrls();

        expect(viewModel.allUrlsFailed, isTrue);
        expect(viewModel.hasError, isTrue);
      });

      test('retryUrl re-fetches only the targeted failed URL', () async {
        // index 0 fails (primary + fallback both throw), index 1 succeeds.
        when(() => mockHttpClient.get(
              Uri.parse('https://a.com/bad'),
              headers: any(named: 'headers'),
            )).thenThrow(Exception('down'));

        viewModel.updateUrl('https://a.com/bad\nhttps://b.com/r2');
        await viewModel.fetchMultipleUrls();
        expect(viewModel.urlResults[0].isFailure, isTrue);
        expect(viewModel.urlResults[1].isSuccess, isTrue);

        // The site comes back up; retrying just that row should now succeed.
        when(() => mockHttpClient.get(
              Uri.parse('https://a.com/bad'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => TestHttpResponse(testHtmlContent, 200));

        await viewModel.retryUrl(0);

        expect(viewModel.urlResults[0].isSuccess, isTrue);
        expect(viewModel.urlResults[1].isSuccess, isTrue);
      });

      test('fetchMultipleUrls with no fetchable URLs sets the validation error',
          () async {
        // isMultiUrl can be true while parseUrls yields nothing fetchable
        // (e.g. two non-http tokens). The early-return must surface the
        // "enter a valid URL" message rather than leaving an empty silent UI.
        viewModel.updateUrl('ftp://a.com/x ftp://b.com/y');

        await viewModel.fetchMultipleUrls();

        expect(viewModel.urlResults, isEmpty);
        expect(viewModel.error, equals('Vänligen ange en giltig URL'));
      });

      test('retryUrl that recovers an all-failed batch clears the batch error',
          () async {
        // Distinct from the partial-batch retry test: here EVERY url fails
        // first, so the batch-level error banner is set. A successful retry
        // must clear it — otherwise the user sees "none could be fetched"
        // sitting above a now-successful row.
        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenThrow(Exception('all down'));

        viewModel.updateUrl('https://a.com/r1\nhttps://b.com/r2');
        await viewModel.fetchMultipleUrls();
        expect(viewModel.allUrlsFailed, isTrue);
        expect(viewModel.hasError, isTrue);

        // One link comes back; retry just that row.
        when(() => mockHttpClient.get(
              Uri.parse('https://a.com/r1'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => TestHttpResponse(testHtmlContent, 200));

        await viewModel.retryUrl(0);

        expect(viewModel.urlResults[0].isSuccess, isTrue);
        expect(viewModel.hasAnyUrlSuccess, isTrue);
        expect(viewModel.hasError, isFalse);
      });

      test('retryUrl ignores an out-of-range index without throwing', () async {
        viewModel.updateUrl('https://a.com/r1\nhttps://b.com/r2');
        await viewModel.fetchMultipleUrls();
        final before = viewModel.urlResults;

        await viewModel.retryUrl(99);
        await viewModel.retryUrl(-1);

        // No crash, batch untouched.
        expect(viewModel.urlResults, equals(before));
      });

      test('editing the URL clears prior batch results', () async {
        viewModel.updateUrl('https://a.com/r1\nhttps://b.com/r2');
        await viewModel.fetchMultipleUrls();
        expect(viewModel.urlResults, isNotEmpty);

        viewModel.updateUrl('https://single.com/r');
        expect(viewModel.urlResults, isEmpty);
      });

      // successfulUrlCount drives the "Importera N recept" CTA count. It must
      // count ONLY the successful rows — not the total, not failures. A regression
      // that counted total rows (or off-by-one) would offer to import N recipes
      // when only M fetched, dead-ending the user on the paste step.
      test('successfulUrlCount counts only successful rows, excluding failures',
          () async {
        // r2 fails; r1 and r3 succeed → count must be 2, not 3.
        when(() => mockHttpClient.get(
              Uri.parse('https://b.com/r2'),
              headers: any(named: 'headers'),
            )).thenThrow(Exception('boom'));

        viewModel.updateUrl(
          'https://a.com/r1\nhttps://b.com/r2\nhttps://c.com/r3',
        );
        await viewModel.fetchMultipleUrls();

        expect(viewModel.urlResults, hasLength(3));
        expect(viewModel.successfulUrlCount, 2,
            reason: 'two of three succeeded — the failed row must not be '
                'counted toward the CTA');
      });

      test('successfulUrlCount is zero when every URL failed', () async {
        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenThrow(Exception('all down'));

        viewModel.updateUrl('https://a.com/r1\nhttps://b.com/r2');
        await viewModel.fetchMultipleUrls();

        expect(viewModel.allUrlsFailed, isTrue);
        expect(viewModel.successfulUrlCount, 0);
      });

      // While the batch is in flight every row is seeded with UrlFetchStatus
      // .loading (and UrlImportResult.isLoading reflects it). The view renders a
      // spinner per loading row; if isLoading didn't track the loading status,
      // the rows would render as pending/blank during the fetch. Prove it by
      // inspecting the rows the instant the sequential loop is mid-flight.
      test('rows expose isLoading while the batch fetch is in flight',
          () async {
        late List<UrlImportResult> midFlightSnapshot;
        final tracking = _LoadingObservingUrlImportViewModel(
          importManager: mockImportManager,
          onMidFetch: (vm) => midFlightSnapshot = vm.urlResults,
        );
        addTearDown(tracking.dispose);

        tracking.updateUrl('https://a.com/r1\nhttps://b.com/r2');
        await tracking.fetchMultipleUrls();

        // Captured during the first row's fetch: at least one row reports
        // isLoading (the one being processed is still seeded loading).
        expect(midFlightSnapshot.any((r) => r.isLoading), isTrue,
            reason: 'rows must report isLoading while their fetch is pending');
        // After settle, nothing is left loading.
        expect(tracking.urlResults.any((r) => r.isLoading), isFalse);
      });

      // clearUrlResults() is the explicit "discard the batch" affordance (the
      // view calls it when the user backs out). It must empty the rows AND
      // notify so the surface rebuilds; and it must be a no-op (no spurious
      // notification) when there's nothing to clear.
      test('clearUrlResults empties the batch and notifies', () async {
        viewModel.updateUrl('https://a.com/r1\nhttps://b.com/r2');
        await viewModel.fetchMultipleUrls();
        expect(viewModel.urlResults, isNotEmpty);

        var notifications = 0;
        viewModel.addListener(() => notifications++);

        viewModel.clearUrlResults();

        expect(viewModel.urlResults, isEmpty);
        expect(notifications, greaterThanOrEqualTo(1));
      });

      test('clearUrlResults is a silent no-op when already empty', () {
        expect(viewModel.urlResults, isEmpty);
        var notifications = 0;
        viewModel.addListener(() => notifications++);

        viewModel.clearUrlResults();

        expect(viewModel.urlResults, isEmpty);
        expect(notifications, 0,
            reason: 'clearing an already-empty batch must not notify and '
                'trigger a needless rebuild');
      });

      // BUT-1295: successfulBatchText is what feeds a settled batch fetch into
      // the shared multi-recipe paste step. It must join ONLY the successful
      // rows' extracted text with the '\n\n' boundary the multi-recipe
      // splitter treats as a recipe separator — a failed row contributes
      // nothing (no body, no stray blank gap). The testable VM returns the raw
      // HTTP body as the extracted text, so a distinct per-URL body lets each
      // test assert the exact join.
      group('successfulBatchText (BUT-1295)', () {
        // Stub a distinct, recognizable body per URL; throw for any URL the
        // test wants to fail so both the primary and fallback fetch fail.
        void stubBodies(
          Map<String, String> bodyByUrl, {
          Set<String> failUrls = const {},
        }) {
          for (final entry in bodyByUrl.entries) {
            when(() => mockHttpClient.get(
                  Uri.parse(entry.key),
                  headers: any(named: 'headers'),
                )).thenAnswer((_) async => TestHttpResponse(entry.value, 200));
          }
          for (final url in failUrls) {
            when(() => mockHttpClient.get(
                  Uri.parse(url),
                  headers: any(named: 'headers'),
                )).thenThrow(Exception('down'));
          }
        }

        test(
            '[success, failure, success] joins ONLY the two successes with '
            'the \\n\\n separator, skipping the failed row', () async {
          stubBodies(
            {
              'https://a.com/r1': 'BODY_A',
              'https://b.com/r2': 'BODY_B', // will fail
              'https://c.com/r3': 'BODY_C',
            },
            failUrls: {'https://b.com/r2'},
          );

          viewModel.updateUrl(
            'https://a.com/r1\nhttps://b.com/r2\nhttps://c.com/r3',
          );
          await viewModel.fetchMultipleUrls();

          // Sanity: the middle row really did fail, so this proves the skip.
          expect(viewModel.urlResults[0].isSuccess, isTrue);
          expect(viewModel.urlResults[1].isFailure, isTrue);
          expect(viewModel.urlResults[2].isSuccess, isTrue);

          expect(viewModel.successfulBatchText, 'BODY_A\n\nBODY_C',
              reason: 'only the two successful bodies are joined, with the '
                  'recipe-boundary separator and no gap for the failure');
        });

        test('single success yields exactly that body with no separator',
            () async {
          stubBodies(
            {
              'https://a.com/r1': 'BODY_A',
              'https://b.com/r2': 'BODY_B', // will fail
            },
            failUrls: {'https://b.com/r2'},
          );

          viewModel.updateUrl('https://a.com/r1\nhttps://b.com/r2');
          await viewModel.fetchMultipleUrls();

          expect(viewModel.successfulBatchText, 'BODY_A',
              reason: 'a lone success must not be wrapped in a trailing or '
                  'leading separator');
        });

        test('all-failure batch yields an empty string', () async {
          stubBodies(
            const {},
            failUrls: {'https://a.com/r1', 'https://b.com/r2'},
          );

          viewModel.updateUrl('https://a.com/r1\nhttps://b.com/r2');
          await viewModel.fetchMultipleUrls();

          expect(viewModel.allUrlsFailed, isTrue);
          expect(viewModel.successfulBatchText, isEmpty,
              reason: 'no successful rows means nothing to feed the paste '
                  'step — the empty string, not a stray separator');
        });
      });
    });

    // BUT-1273: recipe-index / listing-page expansion. Intent: a detected
    // listing page surfaces an opt-in candidate, and accepting it expands into
    // the existing multi-URL batch (reusing its per-URL fetch + tolerance).
    group('index-page expansion (BUT-1273)', () {
      const harvested = [
        'https://recept.example.se/recept/kycklinggryta-med-curry',
        'https://recept.example.se/recept/vegetarisk-lasagne',
      ];

      TestableUrlImportViewModel buildWith(List<String> links) =>
          TestableUrlImportViewModel(
            importManager: mockImportManager,
            testHttpClient: mockHttpClient,
            indexExpander: _FakeIndexExpander(links),
          );

      test('detectIndexPage surfaces an opt-in candidate when links are found',
          () async {
        final vm = buildWith(harvested);
        addTearDown(vm.dispose);

        await vm.detectIndexPage();

        expect(vm.isIndexPageCandidate, isTrue);
        expect(vm.indexPageLinks, harvested);
      });

      test('detectIndexPage stays silent for a non-index page (no links)',
          () async {
        final vm = buildWith(const []);
        addTearDown(vm.dispose);

        await vm.detectIndexPage();

        expect(vm.isIndexPageCandidate, isFalse,
            reason: 'an ordinary recipe page must not show the expand banner');
      });

      test('expandIndexPage fans the harvested links into the batch flow',
          () async {
        final vm = buildWith(harvested);
        addTearDown(vm.dispose);
        await vm.detectIndexPage();

        await vm.expandIndexPage();

        expect(vm.urlResults.length, harvested.length,
            reason: 'each harvested link becomes a batch row');
        expect(vm.successfulUrlCount, harvested.length,
            reason: 'the stub HTTP client returns 200 for every URL');
        expect(vm.isIndexPageCandidate, isFalse,
            reason: 'expanding consumes the candidate so the banner clears');
      });

      test('editing the URL clears a pending index candidate', () async {
        final vm = buildWith(harvested);
        addTearDown(vm.dispose);
        await vm.detectIndexPage();
        expect(vm.isIndexPageCandidate, isTrue);

        vm.updateUrl('https://recept.example.se/recept/en-annan-ratt');

        expect(vm.isIndexPageCandidate, isFalse,
            reason: 'a stale banner must not survive a fresh URL edit');
      });

      test('expandIndexPage is a no-op when there is no candidate', () async {
        final vm = buildWith(const []);
        addTearDown(vm.dispose);

        await vm.expandIndexPage();

        expect(vm.urlResults, isEmpty);
      });

      test('a URL edited during the probe discards the stale result', () async {
        final vm = buildWith(harvested);
        addTearDown(vm.dispose);

        // Start the probe, then edit the URL before harvest resolves (the await
        // yields control here before the fake's microtask completes).
        final probe = vm.detectIndexPage();
        vm.updateUrl('https://recept.example.se/recept/en-helt-annan-ratt');
        await probe;

        expect(vm.isIndexPageCandidate, isFalse,
            reason: 'links harvested for the old URL must not surface after a '
                'mid-probe edit');
      });
    });
  });
}
