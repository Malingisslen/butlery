import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/content_detector_service.dart';
import 'package:butlery/core/mixins/singleton_service_mixin.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('AnalyticsService', () {
    late AnalyticsService analyticsService;
    late MockAnalyticsRepository mockRepository;
    late MockFirebaseAnalyticsObserver mockObserver;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Reset singleton for test isolation
      SingletonServiceMixin.resetForTesting();

      // Create mocks
      mockRepository = MockAnalyticsRepository();
      mockObserver = MockFirebaseAnalyticsObserver();

      // Configure the analytics repository state
      mockRepository.setAnalyticsState(
        isInitialized: true,
        isEnabled: true,
      );

      // Register fallback values for mocktail
      registerFallbackValue(<String, Object>{});

      // Stub ALL repository methods that will be called
      when(() => mockRepository.initialize()).thenAnswer((_) async {});
      when(() => mockRepository.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.logLogin(
            loginMethod: any(named: 'loginMethod'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.logSignUp(
            signUpMethod: any(named: 'signUpMethod'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.logLogout()).thenAnswer((_) async {});
      when(() => mockRepository.logAccountDeleted(any()))
          .thenAnswer((_) async {});
      when(() => mockRepository.setUserProperty(
            name: any(named: 'name'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.setAnalyticsCollectionEnabled(any()))
          .thenAnswer((_) async {});

      // Stub import/extraction methods
      when(() => mockRepository.logImportStarted(
            source: any(named: 'source'),
            platform: any(named: 'platform'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.logImportSuccess(
            source: any(named: 'source'),
            platform: any(named: 'platform'),
            recipeLength: any(named: 'recipeLength'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.logExtractionError(
            url: any(named: 'url'),
            platform: any(named: 'platform'),
            error: any(named: 'error'),
            errorType: any(named: 'errorType'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.logManualCopyFallback(
            platform: any(named: 'platform'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async {});

      // Stub recipe methods
      when(() => mockRepository.logRecipeCreated(
            source: any(named: 'source'),
            hasImage: any(named: 'hasImage'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.logRecipeShared(
            method: any(named: 'method'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.logRecipeCooked(
            recipeId: any(named: 'recipeId'),
            mealType: any(named: 'mealType'),
            isFirstTime: any(named: 'isFirstTime'),
            daysSinceLastCooked: any(named: 'daysSinceLastCooked'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.logMenuGenerated(
            recipeCount: any(named: 'recipeCount'),
            method: any(named: 'method'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.logRecipeDeleted(
            recipeId: any(named: 'recipeId'),
            mealType: any(named: 'mealType'),
            isPersonal: any(named: 'isPersonal'),
            createdAt: any(named: 'createdAt'),
            daysSinceCreated: any(named: 'daysSinceCreated'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.logAccountDeleted(any()))
          .thenAnswer((_) async {});
      when(() => mockRepository.setUserProperties(
            recipeCount: any(named: 'recipeCount'),
            hasUsedImport: any(named: 'hasUsedImport'),
            hasSharedRecipe: any(named: 'hasSharedRecipe'),
            hasCooked: any(named: 'hasCooked'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.logLogout()).thenAnswer((_) async {});

      // Create service instance with mock repository
      analyticsService = AnalyticsService(repository: mockRepository);

      // Register mocks for automatic reset
      BaseUnitTest.registerMocks([mockRepository, mockObserver]);
    });

    tearDown(() async {
      mockRepository.resetForTesting();
      BaseUnitTest.resetMocks();
      SingletonServiceMixin.resetForTesting();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should be singleton instance with same repository', () {
        // Arrange & Act
        final instance1 = AnalyticsService(repository: mockRepository);
        final instance2 = AnalyticsService(repository: mockRepository);

        // Assert
        expect(identical(instance1, instance2), isTrue);
      });

      test('should have correct service name', () {
        // Assert
        expect(analyticsService.serviceName, equals('AnalyticsService'));
      });

      test('should provide observer from repository', () {
        // Act
        final observer = analyticsService.observer;

        // Assert
        expect(observer, isNotNull);
        expect(observer, equals(mockObserver));
      });
    });

    group('Import Events', () {
      test('should log import started event', () async {
        // Arrange
        const source = 'web_scraper';
        const platform = 'website';

        // Act
        await analyticsService.logImportStarted(
          source: source,
          platform: platform,
        );

        // Assert
        verify(() => mockRepository.logImportStarted(
              source: source,
              platform: platform,
            )).called(1);
      });

      test('should log import success event', () async {
        // Arrange
        const source = 'manual';
        const platform = 'instagram';
        const recipeLength = 1200;

        // Act
        await analyticsService.logImportSuccess(
          source: source,
          platform: platform,
          recipeLength: recipeLength,
        );

        // Assert
        verify(() => mockRepository.logImportSuccess(
              source: source,
              platform: platform,
              recipeLength: recipeLength,
            )).called(1);
      });
    });

    group('Extraction Events', () {
      test('should log extraction error with auto-categorization', () async {
        // Arrange
        const url = 'https://example.com/recipe';
        const platform = SourcePlatform.website;
        const error = 'Connection timeout';

        // Act
        await analyticsService.logExtractionError(
          url: url,
          platform: platform,
          error: error,
        );

        // Assert
        verify(() => mockRepository.logExtractionError(
              url: url,
              platform: platform.name,
              error: error,
              errorType: null,
            )).called(1);
      });

      test('should log extraction error with explicit type', () async {
        // Arrange
        const url = 'https://example.com/recipe';
        const platform = SourcePlatform.website;
        const error = 'Custom error';
        const errorType = 'custom_error';

        // Act
        await analyticsService.logExtractionError(
          url: url,
          platform: platform,
          error: error,
          errorType: errorType,
        );

        // Assert
        verify(() => mockRepository.logExtractionError(
              url: url,
              platform: platform.name,
              error: error,
              errorType: errorType,
            )).called(1);
      });

      test('should log manual copy fallback', () async {
        // Arrange
        const platform = SourcePlatform.instagram;
        const reason = 'User requested manual input';

        // Act
        await analyticsService.logManualCopyFallback(
          platform: platform,
          reason: reason,
        );

        // Assert
        verify(() => mockRepository.logManualCopyFallback(
              platform: platform.name,
              reason: reason,
            )).called(1);
      });
    });

    group('Recipe Events', () {
      test('should log recipe created event', () async {
        // Arrange
        const source = 'manual_entry';
        const hasImage = true;

        when(() => mockRepository.logRecipeCreated(
              source: any(named: 'source'),
              hasImage: any(named: 'hasImage'),
            )).thenAnswer((_) async {});

        // Act
        await analyticsService.logRecipeCreated(
          source: source,
          hasImage: hasImage,
        );

        // Assert
        verify(() => mockRepository.logRecipeCreated(
              source: source,
              hasImage: hasImage,
            )).called(1);
      });

      test('should log recipe shared event', () async {
        // Arrange
        const method = 'social_media';

        when(() => mockRepository.logRecipeShared(
              method: any(named: 'method'),
            )).thenAnswer((_) async {});

        // Act
        await analyticsService.logRecipeShared(
          method: method,
        );

        // Assert
        verify(() => mockRepository.logRecipeShared(
              method: method,
            )).called(1);
      });

      test('should log recipe cooked event', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const mealType = 'dinner';
        const isFirstTime = false;
        const daysSinceLastCooked = 7;

        when(() => mockRepository.logRecipeCooked(
              recipeId: any(named: 'recipeId'),
              mealType: any(named: 'mealType'),
              isFirstTime: any(named: 'isFirstTime'),
              daysSinceLastCooked: any(named: 'daysSinceLastCooked'),
            )).thenAnswer((_) async {});

        // Act
        await analyticsService.logRecipeCooked(
          recipeId: recipeId,
          mealType: mealType,
          isFirstTime: isFirstTime,
          daysSinceLastCooked: daysSinceLastCooked,
        );

        // Assert
        verify(() => mockRepository.logRecipeCooked(
              recipeId: recipeId,
              mealType: mealType,
              isFirstTime: isFirstTime,
              daysSinceLastCooked: daysSinceLastCooked,
            )).called(1);
      });

      test('should log recipe deleted event', () async {
        // Arrange
        const recipeId = 'recipe_456';
        const mealType = 'breakfast';
        const isPersonal = true;
        final createdAt = DateTime.now().subtract(const Duration(days: 30));
        const daysSinceCreated = 30;

        when(() => mockRepository.logRecipeDeleted(
              recipeId: any(named: 'recipeId'),
              mealType: any(named: 'mealType'),
              isPersonal: any(named: 'isPersonal'),
              createdAt: any(named: 'createdAt'),
              daysSinceCreated: any(named: 'daysSinceCreated'),
            )).thenAnswer((_) async {});

        // Act
        await analyticsService.logRecipeDeleted(
          recipeId: recipeId,
          mealType: mealType,
          isPersonal: isPersonal,
          createdAt: createdAt,
          daysSinceCreated: daysSinceCreated,
        );

        // Assert
        verify(() => mockRepository.logRecipeDeleted(
              recipeId: recipeId,
              mealType: mealType,
              isPersonal: isPersonal,
              createdAt: createdAt,
              daysSinceCreated: daysSinceCreated,
            )).called(1);
      });

      test('should calculate days since created if not provided', () async {
        // Arrange
        const recipeId = 'recipe_789';
        const mealType = 'lunch';
        const isPersonal = false;
        final createdAt = DateTime.now().subtract(const Duration(days: 15));

        when(() => mockRepository.logRecipeDeleted(
              recipeId: any(named: 'recipeId'),
              mealType: any(named: 'mealType'),
              isPersonal: any(named: 'isPersonal'),
              createdAt: any(named: 'createdAt'),
              daysSinceCreated: any(named: 'daysSinceCreated'),
            )).thenAnswer((_) async {});

        // Act
        await analyticsService.logRecipeDeleted(
          recipeId: recipeId,
          mealType: mealType,
          isPersonal: isPersonal,
          createdAt: createdAt,
        );

        // Assert
        verify(() => mockRepository.logRecipeDeleted(
              recipeId: recipeId,
              mealType: mealType,
              isPersonal: isPersonal,
              createdAt: createdAt,
              daysSinceCreated: null,
            )).called(1);
      });
    });

    group('Menu Events', () {
      test('should log menu generated event', () async {
        // Arrange
        const recipeCount = 7;
        const method = 'automatic';

        // Act
        await analyticsService.logMenuGenerated(
          recipeCount: recipeCount,
          method: method,
        );

        // Assert
        verify(() => mockRepository.logMenuGenerated(
              recipeCount: recipeCount,
              method: method,
            )).called(1);
      });
    });

    group('Authentication Events', () {
      test('should log login event', () async {
        // Arrange
        const method = 'email';

        when(() => mockRepository.logLogin(
              loginMethod: any(named: 'loginMethod'),
            )).thenAnswer((_) async {});

        // Act
        await analyticsService.logLogin(method: method);

        // Assert
        verify(() => mockRepository.logLogin(loginMethod: method)).called(1);
      });

      test('should log sign up event', () async {
        // Arrange
        const method = 'google';

        when(() => mockRepository.logSignUp(
              signUpMethod: any(named: 'signUpMethod'),
            )).thenAnswer((_) async {});

        // Act
        await analyticsService.logSignUp(method: method);

        // Assert
        verify(() => mockRepository.logSignUp(signUpMethod: method)).called(1);
      });

      test('should log logout event', () async {
        // Act
        await analyticsService.logLogout();

        // Assert
        verify(() => mockRepository.logLogout()).called(1);
      });
    });

    group('Account Deletion', () {
      test('should log account deleted event', () async {
        // Arrange
        final parameters = {
          'user_id': 'user_123',
          'reason': 'user_requested',
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Act
        await analyticsService.logAccountDeleted(parameters);

        // Assert
        verify(() => mockRepository.logAccountDeleted(parameters)).called(1);
      });

      test('should filter null values in parameters', () async {
        // Arrange
        final parameters = {
          'user_id': 'user_456',
          'reason': null, // Null value should be filtered
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Act
        await analyticsService.logAccountDeleted(parameters);

        // Assert
        verify(() => mockRepository.logAccountDeleted(parameters)).called(1);
      });
    });

    group('User Properties', () {
      test('should set user type based on recipe count', () async {
        // Test new user
        await analyticsService.setUserProperties(recipeCount: 2);
        verify(() => mockRepository.setUserProperties(
              recipeCount: 2,
              hasUsedImport: null,
              hasSharedRecipe: null,
              hasCooked: null,
            )).called(1);

        // Reset mocks
        clearInteractions(mockRepository);

        // Test casual user
        await analyticsService.setUserProperties(recipeCount: 8);
        verify(() => mockRepository.setUserProperties(
              recipeCount: 8,
              hasUsedImport: null,
              hasSharedRecipe: null,
              hasCooked: null,
            )).called(1);

        // Reset mocks
        clearInteractions(mockRepository);

        // Test active user
        await analyticsService.setUserProperties(recipeCount: 25);
        verify(() => mockRepository.setUserProperties(
              recipeCount: 25,
              hasUsedImport: null,
              hasSharedRecipe: null,
              hasCooked: null,
            )).called(1);

        // Reset mocks
        clearInteractions(mockRepository);

        // Test power user
        await analyticsService.setUserProperties(recipeCount: 60);
        verify(() => mockRepository.setUserProperties(
              recipeCount: 60,
              hasUsedImport: null,
              hasSharedRecipe: null,
              hasCooked: null,
            )).called(1);
      });

      test('should set recipe count range', () async {
        // Test different ranges
        final testCases = [
          (count: 0, expectedRange: '0'),
          (count: 3, expectedRange: '1-5'),
          (count: 8, expectedRange: '6-10'),
          (count: 15, expectedRange: '11-20'),
          (count: 35, expectedRange: '21-50'),
          (count: 100, expectedRange: '50+'),
        ];

        for (final testCase in testCases) {
          await analyticsService.setUserProperties(
            recipeCount: testCase.count,
          );

          verify(() => mockRepository.setUserProperties(
                recipeCount: testCase.count,
                hasUsedImport: null,
                hasSharedRecipe: null,
                hasCooked: null,
              )).called(1);

          // Reset for next test
          clearInteractions(mockRepository);
        }
      });

      test('should set boolean user properties', () async {
        // Act
        await analyticsService.setUserProperties(
          hasUsedImport: true,
          hasSharedRecipe: false,
          hasCooked: true,
        );

        // Assert
        verify(() => mockRepository.setUserProperties(
              recipeCount: null,
              hasUsedImport: true,
              hasSharedRecipe: false,
              hasCooked: true,
            )).called(1);
      });
    });

    group('Error Categorization', () {
      test('should categorize timeout errors', () async {
        const errors = [
          'Connection timeout',
          'Request TIMEOUT occurred',
          'timeout while loading',
        ];

        for (final error in errors) {
          await analyticsService.logExtractionError(
            url: 'test.com',
            platform: SourcePlatform.website,
            error: error,
          );

          verify(() => mockRepository.logExtractionError(
                url: 'test.com',
                platform: 'website',
                error: error,
                errorType: null,
              )).called(1);

          clearInteractions(mockRepository);
        }
      });

      test('should categorize no content errors', () async {
        const errors = [
          'Ingen text hittades',
          'ingen text i receptet',
        ];

        for (final error in errors) {
          await analyticsService.logExtractionError(
            url: 'test.com',
            platform: SourcePlatform.facebook,
            error: error,
          );

          verify(() => mockRepository.logExtractionError(
                url: 'test.com',
                platform: 'facebook',
                error: error,
                errorType: null,
              )).called(1);

          clearInteractions(mockRepository);
        }
      });

      test('should categorize page load errors', () async {
        const errors = [
          'Kunde inte ladda sidan',
          'kunde inte ladda receptet',
        ];

        for (final error in errors) {
          await analyticsService.logExtractionError(
            url: 'test.com',
            platform: SourcePlatform.tiktok,
            error: error,
          );

          verify(() => mockRepository.logExtractionError(
                url: 'test.com',
                platform: 'tiktok',
                error: error,
                errorType: null,
              )).called(1);

          clearInteractions(mockRepository);
        }
      });
    });

    group('Singleton Pattern', () {
      test('should maintain same instance across multiple factory calls', () {
        // Act
        final instance1 = AnalyticsService(repository: mockRepository);
        final instance2 = AnalyticsService(repository: mockRepository);
        final instance3 = AnalyticsService(repository: mockRepository);

        // Assert
        expect(identical(instance1, instance2), isTrue);
        expect(identical(instance2, instance3), isTrue);
      });

      test('should reset singleton for testing', () {
        // Arrange
        final instance1 = AnalyticsService(repository: mockRepository);

        // Act
        SingletonServiceMixin.resetForTesting();
        final instance2 = AnalyticsService(repository: mockRepository);

        // Assert
        expect(identical(instance1, instance2), isFalse);
      });
    });
  });
}
