import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:butlery/viewmodels/url_import_viewmodel.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_strategy.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Using centralized mocks from production_mocks.dart:
// - MockImportManager with setImportManagerState() method
// - MockTextImportStrategy with stubbing support

// Using local mock patterns that follow centralized architecture
// TODO: Resolve import issue with centralized mocks in future cleanup
class MockHttpClient extends Mock implements http.Client {}

// Test HTTP Response
class TestHttpResponse extends http.Response {
  TestHttpResponse(super.body, super.statusCode);
}

// Testable version that allows HTTP client injection
class TestableUrlImportViewModel extends UrlImportViewModel {
  final http.Client? testHttpClient;

  TestableUrlImportViewModel({
    required super.importManager,
    this.testHttpClient,
  });

  @override
  Future<String> fetchContentFromUrl(String url) async {
    if (testHttpClient != null) {
      try {
        final response = await testHttpClient!.get(
          Uri.parse(url),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'sv-SE,sv;q=0.9,en;q=0.8',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
          },
        );

        if (response.statusCode != 200) {
          throw Exception(
              'Kunde inte hämta innehåll från URL: HTTP ${response.statusCode}');
        }

        final htmlContent = response.body;

        if (htmlContent.isEmpty) {
          throw Exception('Inget innehåll hittades på denna sida');
        }

        return htmlContent;
      } catch (e) {
        // Fallback to basic fetch
        final response = await testHttpClient!.get(
          Uri.parse(url),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        );

        if (response.statusCode != 200) {
          throw Exception(
              'Kunde inte hämta innehåll: HTTP ${response.statusCode}');
        }

        // Basic HTML content extraction
        String content = response.body;

        // Remove HTML tags for basic text extraction
        content = content.replaceAll(RegExp(r'<[^>]*>'), ' ');
        content = content.replaceAll(RegExp(r'\s+'), ' ');
        content = content.trim();

        if (content.length < 100) {
          throw Exception(
              'Innehållet är för kort för att innehålla ett recept');
        }

        return content;
      }
    }
    return super.fetchContentFromUrl(url);
  }
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
            contains('✅ URL från känd receptsida - bör fungera bra'));
      });

      test('should warn for unknown site', () {
        // Arrange
        viewModel.updateUrl('https://www.example.com/page');

        // Act
        final suggestions = viewModel.getUrlSuggestions();

        // Assert
        expect(suggestions,
            contains('ℹ️ Okänd sida - innehållsextraktion kan variera'));
      });

      test('should identify recipe keywords in URL', () {
        // Arrange
        viewModel.updateUrl('https://www.example.com/recipe/pasta');

        // Act
        final suggestions = viewModel.getUrlSuggestions();

        // Assert
        expect(suggestions, contains('✅ URL innehåller receptnyckelord'));
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
                '⚠️ Mycket lång URL - försök kopiera huvudreceptsidans URL'));
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
          expect(
              suggestions,
              contains(
                  '📱 Social media-länk - innehållsextraktion kan vara begränsad'));
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
            contains('✅ URL från känd receptsida - bör fungera bra'));
        // When only one positive suggestion and is known site, should show optimal
        expect(suggestions.any((s) => s.contains('Optimal')), isTrue);
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

      test('should handle 404 error', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/notfound');
        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => TestHttpResponse('Not Found', 404));

        // Act
        await viewModel.fetchFromUrl();

        // Assert
        expect(viewModel.hasExtractedText, isFalse);
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, contains('Kunde inte hämta innehåll'));
      });

      test('should handle empty response', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/empty');
        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async {
          // Both primary and fallback return empty
          return TestHttpResponse('', 200);
        });

        // Act
        await viewModel.fetchFromUrl();

        // Assert
        expect(viewModel.hasExtractedText, isFalse);
        expect(viewModel.hasError, isTrue);
        // Empty content falls back to basic fetch which checks length < 100
        expect(viewModel.error,
            anyOf(contains('Inget innehåll hittades'), contains('för kort')));
      });

      test('should handle network error', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/error');
        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenThrow(Exception('Network error'));

        // Act
        await viewModel.fetchFromUrl();

        // Assert
        expect(viewModel.hasExtractedText, isFalse);
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, contains('Failed to fetch content'));
      });

      test('should use fallback fetch on primary failure', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/recipe');
        var callCount = 0;
        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw Exception('Primary fetch failed');
          }
          return TestHttpResponse(testHtmlContent, 200);
        });

        // Act
        await viewModel.fetchFromUrl();

        // Assert
        expect(viewModel.hasExtractedText, isTrue);
        expect(callCount, equals(2)); // Primary + fallback
      });

      test('should reject short content', () async {
        // Arrange
        viewModel.updateUrl('https://www.example.com/short');
        // Make first call fail to trigger fallback, then return short content in fallback
        var callCount = 0;
        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw Exception('Force fallback');
          }
          return TestHttpResponse('<html><body>Too short</body></html>', 200);
        });

        // Act
        await viewModel.fetchFromUrl();

        // Assert
        expect(viewModel.hasExtractedText, isFalse);
        expect(viewModel.error, contains('för kort'));
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

        // Act
        await viewModel.fetchAndParse();

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
  });
}
