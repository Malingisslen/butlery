import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/content_detector_service.dart';
import '../../infrastructure/helpers/_base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  late ContentDetectorService service;
  
  setUpAll(() async {
    // Initialize base test infrastructure for consistency
    await BaseUnitTest.setupUnit();
  });
  
  setUp(() {
    service = ContentDetectorService();
  });
  
  tearDown(() async {
    // Reset any mock state between tests
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });
  
  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });
  
  group('ContentDetectorService', () {
    group('Initialization', () {
      test('should maintain singleton pattern', () {
        // Arrange & Act
        final service1 = ContentDetectorService();
        final service2 = ContentDetectorService();
        
        // Assert
        expect(identical(service1, service2), isTrue);
      });
      
      test('should have correct service name', () {
        // Assert
        expect(service.serviceName, equals('ContentDetectorService'));
      });
    });
    
    group('Social Media URL Detection', () {
      test('should detect Instagram post URL', () async {
        // Act
        final result = await service.detectContent('https://instagram.com/p/ABC123xyz');
        
        // Assert
        expect(result.type, equals(ContentType.socialMediaUrl));
        expect(result.platform, equals(SourcePlatform.instagram));
        expect(result.extractedUrl, equals('https://instagram.com/p/ABC123xyz'));
        expect(result.metadata['requiresWebView'], isTrue);
      });
      
      test('should detect Instagram reel URL', () async {
        // Act
        final result = await service.detectContent('Check this out: https://instagram.com/reel/XYZ789abc');
        
        // Assert
        expect(result.type, equals(ContentType.socialMediaUrl));
        expect(result.platform, equals(SourcePlatform.instagram));
        expect(result.extractedUrl, equals('https://instagram.com/reel/XYZ789abc'));
      });
      
      test('should detect shortened Instagram URL', () async {
        // Act
        final result = await service.detectContent('https://instagr.am/p/ShortLink123');
        
        // Assert
        expect(result.type, equals(ContentType.socialMediaUrl));
        expect(result.platform, equals(SourcePlatform.instagram));
      });
      
      test('should detect Facebook post URL', () async {
        // Act
        final result = await service.detectContent('https://facebook.com/username/posts/123456789');
        
        // Assert
        expect(result.type, equals(ContentType.socialMediaUrl));
        expect(result.platform, equals(SourcePlatform.facebook));
        expect(result.metadata['requiresWebView'], isTrue);
      });
      
      test('should detect Facebook watch URL', () async {
        // Act
        final result = await service.detectContent('https://facebook.com/watch/?v=987654321');
        
        // Assert
        expect(result.type, equals(ContentType.socialMediaUrl));
        expect(result.platform, equals(SourcePlatform.facebook));
      });
      
      test('should detect shortened Facebook URL', () async {
        // Act
        final result = await service.detectContent('https://fb.watch/AbCdEfG');
        
        // Assert
        expect(result.type, equals(ContentType.socialMediaUrl));
        expect(result.platform, equals(SourcePlatform.facebook));
      });
      
      test('should detect TikTok video URL', () async {
        // Act
        final result = await service.detectContent('https://tiktok.com/@username/video/123456789');
        
        // Assert
        expect(result.type, equals(ContentType.socialMediaUrl));
        expect(result.platform, equals(SourcePlatform.tiktok));
        expect(result.metadata['requiresWebView'], isTrue);
      });
      
      test('should detect shortened TikTok URL', () async {
        // Act
        final result = await service.detectContent('https://vm.tiktok.com/ZM8abc123');
        
        // Assert
        expect(result.type, equals(ContentType.socialMediaUrl));
        expect(result.platform, equals(SourcePlatform.tiktok));
      });
      
      test('should detect YouTube video URL', () async {
        // Act
        final result = await service.detectContent('https://youtube.com/watch?v=dQw4w9WgXcQ');
        
        // Assert
        expect(result.type, equals(ContentType.recipeUrl));
        expect(result.platform, equals(SourcePlatform.website));
        expect(result.extractedUrl, equals('https://youtube.com/watch?v=dQw4w9WgXcQ'));
      });
      
      test('should detect YouTube shorts URL', () async {
        // Act
        final result = await service.detectContent('https://youtube.com/shorts/ABC123');
        
        // Assert
        expect(result.type, equals(ContentType.recipeUrl));
        expect(result.platform, equals(SourcePlatform.website));
      });
      
      test('should detect shortened YouTube URL', () async {
        // Act
        final result = await service.detectContent('https://youtu.be/VideoId123');
        
        // Assert
        expect(result.type, equals(ContentType.recipeUrl));
        expect(result.platform, equals(SourcePlatform.website));
      });
    });
    
    group('Recipe URL Detection', () {
      test('should detect general recipe website URL', () async {
        // Act
        final result = await service.detectContent('https://www.arla.se/recept/pasta-carbonara');
        
        // Assert
        expect(result.type, equals(ContentType.recipeUrl));
        expect(result.platform, equals(SourcePlatform.website));
        expect(result.extractedUrl, equals('https://www.arla.se/recept/pasta-carbonara'));
      });
      
      test('should detect URL with additional text', () async {
        // Act
        final result = await service.detectContent(
          'Check out this recipe: https://ica.se/recept/kottbullar with cream sauce'
        );
        
        // Assert
        expect(result.type, equals(ContentType.recipeUrl));
        expect(result.extractedUrl, equals('https://ica.se/recept/kottbullar'));
      });
      
      test('should extract first URL from multiple URLs', () async {
        // Act
        final result = await service.detectContent(
          'https://first.com/recipe and https://second.com/recipe'
        );
        
        // Assert
        expect(result.extractedUrl, equals('https://first.com/recipe'));
      });
    });
    
    group('Recipe Text Detection', () {
      test('should detect Swedish recipe text with ingredients', () async {
        // Act
        final result = await service.detectContent(
          'Recept för köttbullar\nIngredienser:\n500g köttfärs\n1 dl mjölk'
        );
        
        // Assert
        expect(result.type, equals(ContentType.recipeText));
        expect(result.platform, isNull);
        expect(result.metadata['detectedKeywords'], contains('recept'));
        expect(result.metadata['detectedKeywords'], contains('ingredienser'));
      });
      
      test('should detect Swedish cooking instructions', () async {
        // Act
        final result = await service.detectContent(
          'Tillredning: Sätt ugnen på 200 grader. Blanda alla ingredienser och stek i 15 minuter.'
        );
        
        // Assert
        expect(result.type, equals(ContentType.recipeText));
        expect(result.metadata['detectedKeywords'], contains('tillredning'));
        expect(result.metadata['detectedKeywords'], contains('ugn'));
        expect(result.metadata['detectedKeywords'], contains('grader'));
      });
      
      test('should detect Swedish measurements', () async {
        // Act
        final result = await service.detectContent(
          'Ta 2 matskedar socker, 3 teskedar salt och 5 deciliter mjöl'
        );
        
        // Assert
        expect(result.type, equals(ContentType.recipeText));
        expect(result.metadata['detectedKeywords'], contains('matsked'));
        expect(result.metadata['detectedKeywords'], contains('tesked'));
        expect(result.metadata['detectedKeywords'], contains('deciliter'));
      });
      
      test('should detect English recipe text', () async {
        // Act
        final result = await service.detectContent(
          'Recipe: Chocolate Cake\nIngredients: 2 cups flour, 1 cup sugar\nInstructions: Mix and bake'
        );
        
        // Assert
        expect(result.type, equals(ContentType.recipeText));
        expect(result.metadata['detectedKeywords'], contains('recipe'));
        expect(result.metadata['detectedKeywords'], contains('ingredients'));
        expect(result.metadata['detectedKeywords'], contains('instructions'));
      });
      
      test('should detect mixed Swedish and English recipe keywords', () async {
        // Act
        final result = await service.detectContent(
          'Recept recipe with 2 cups mjöl and instruktioner för cooking'
        );
        
        // Assert
        expect(result.type, equals(ContentType.recipeText));
        expect(result.metadata['detectedKeywords'], contains('recept'));
        expect(result.metadata['detectedKeywords'], contains('recipe'));
      });
    });
    
    group('Plain Text Detection', () {
      test('should detect plain text without recipe keywords', () async {
        // Act
        final result = await service.detectContent(
          'This is just a regular message without any special content'
        );
        
        // Assert
        expect(result.type, equals(ContentType.plainText));
        expect(result.platform, isNull);
        expect(result.extractedUrl, isNull);
      });
      
      test('should handle empty content', () async {
        // Act
        final result = await service.detectContent('');
        
        // Assert
        expect(result.type, equals(ContentType.plainText));
        expect(result.originalContent, equals(''));
      });
      
      test('should handle whitespace-only content', () async {
        // Act
        final result = await service.detectContent('   \n\t  ');
        
        // Assert
        expect(result.type, equals(ContentType.plainText));
      });
    });
    
    group('URL Validation', () {
      test('should validate correct HTTP URL', () {
        // Act & Assert
        expect(service.isValidUrl('http://example.com'), isTrue);
      });
      
      test('should validate correct HTTPS URL', () {
        // Act & Assert
        expect(service.isValidUrl('https://example.com/path'), isTrue);
      });
      
      test('should reject invalid URL', () {
        // Act & Assert
        expect(service.isValidUrl('not a url'), isFalse);
      });
      
      test('should reject null URL', () {
        // Act & Assert
        expect(service.isValidUrl(null), isFalse);
      });
      
      test('should reject empty URL', () {
        // Act & Assert
        expect(service.isValidUrl(''), isFalse);
      });
      
      test('should reject URL without scheme', () {
        // Act & Assert
        expect(service.isValidUrl('example.com'), isFalse);
      });
      
      test('should reject non-HTTP schemes', () {
        // Act & Assert
        expect(service.isValidUrl('ftp://example.com'), isFalse);
        expect(service.isValidUrl('mailto:test@example.com'), isFalse);
      });
    });
    
    group('Metadata Handling', () {
      test('should include metadata for social media URLs', () async {
        // Act
        final result = await service.detectContent(
          'Check this out: https://instagram.com/p/ABC123 amazing recipe!'
        );
        
        // Assert
        expect(result.metadata['requiresWebView'], isTrue);
        expect(result.metadata['hasAdditionalText'], isTrue);
      });
      
      test('should include detected keywords in metadata', () async {
        // Act
        final result = await service.detectContent(
          'Recept: Blanda 2 matskedar socker med 3 dl mjölk'
        );
        
        // Assert
        expect(result.metadata['detectedKeywords'], isA<List<String>>());
        expect(result.metadata['detectedKeywords'], isNotEmpty);
        expect(result.metadata['source'], contains('kopierad'));
      });
      
      test('should preserve original content', () async {
        // Arrange
        const originalContent = 'ORIGINAL: https://test.com/recipe';
        
        // Act
        final result = await service.detectContent(originalContent);
        
        // Assert
        expect(result.originalContent, equals(originalContent));
      });
    });
    
    group('Edge Cases', () {
      test('should handle very long content', () async {
        // Arrange
        final longContent = 'Recept ${'x' * 10000}';
        
        // Act
        final result = await service.detectContent(longContent);
        
        // Assert
        expect(result.type, equals(ContentType.recipeText));
        expect(result.originalContent, equals(longContent));
      });
      
      test('should handle special characters in URLs', () async {
        // Act
        final result = await service.detectContent(
          'https://example.com/recipe?id=123&name=test#section'
        );
        
        // Assert
        expect(result.type, equals(ContentType.recipeUrl));
        expect(result.extractedUrl, equals('https://example.com/recipe?id=123&name=test#section'));
      });
      
      test('should handle URLs with unicode characters', () async {
        // Act
        final result = await service.detectContent(
          'https://example.com/recept/köttbullar'
        );
        
        // Assert
        expect(result.type, equals(ContentType.recipeUrl));
        expect(result.extractedUrl, isNotNull);
      });
      
      test('should be case insensitive for keyword detection', () async {
        // Act
        final result = await service.detectContent(
          'RECEPT INGREDIENSER TILLREDNING'
        );
        
        // Assert
        expect(result.type, equals(ContentType.recipeText));
      });
      
      test('should handle mixed content with URL and recipe keywords', () async {
        // Act
        final result = await service.detectContent(
          'https://instagram.com/p/ABC123 recept ingredienser'
        );
        
        // Assert - URL takes precedence
        expect(result.type, equals(ContentType.socialMediaUrl));
        expect(result.platform, equals(SourcePlatform.instagram));
      });
      
      test('should handle malformed URLs gracefully', () async {
        // Act
        final result = await service.detectContent(
          'http://[invalid url with brackets]'
        );
        
        // Assert - Production code treats malformed URLs as plain text
        expect(result.type, equals(ContentType.plainText));
      });
      
      test('should handle content with line breaks', () async {
        // Act
        final result = await service.detectContent(
          'Recept\n\nIngredienser:\n- Mjöl\n- Socker\n\nTillredning:\nBlanda allt'
        );
        
        // Assert
        expect(result.type, equals(ContentType.recipeText));
      });
      
      test('should detect recipe keywords in different positions', () async {
        // Act
        final result = await service.detectContent(
          'Start text then recept in middle and ingredienser at end'
        );
        
        // Assert
        expect(result.type, equals(ContentType.recipeText));
      });
    });
    
    group('Debug Functionality', () {
      test('should have debug patterns method', () {
        // Act & Assert
        expect(() => service.debugPatterns(), returnsNormally);
      });
    });
  });
}