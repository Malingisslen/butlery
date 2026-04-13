import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/content_detector_service.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';

import '../../test_support/base_unit_test.dart';

/// Minimal mock that does NOT override any methods concretely,
/// so all methods are stubbable via mocktail's when().
class _MockAnalyticsRepo extends Mock implements AnalyticsRepository {}

class _MockConsentService extends Mock implements ConsentService {}

void main() {
  group('AnalyticsService', () {
    late AnalyticsService service;
    late _MockAnalyticsRepo mockRepo;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(<String, Object>{});
      registerFallbackValue(DateTime.now());
      registerFallbackValue(ConsentPurpose.analytics);
    });

    setUp(() {
      mockRepo = _MockAnalyticsRepo();

      // Stub all repository methods used by the service and its trackers
      when(() => mockRepo.initialize()).thenAnswer((_) async {});
      when(() => mockRepo.observer).thenReturn(null);
      when(() => mockRepo.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          )).thenAnswer((_) async {});
      when(() => mockRepo.logLogin(
            loginMethod: any(named: 'loginMethod'),
          )).thenAnswer((_) async {});
      when(() => mockRepo.logSignUp(
            signUpMethod: any(named: 'signUpMethod'),
          )).thenAnswer((_) async {});
      when(() => mockRepo.logLogout()).thenAnswer((_) async {});
      when(() => mockRepo.logAccountDeleted(any())).thenAnswer((_) async {});
      when(() => mockRepo.setUserProperty(
            name: any(named: 'name'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});
      when(() => mockRepo.setAnalyticsCollectionEnabled(any()))
          .thenAnswer((_) async {});
      when(() => mockRepo.setUserProperties(
            recipeCount: any(named: 'recipeCount'),
            hasUsedImport: any(named: 'hasUsedImport'),
            hasSharedRecipe: any(named: 'hasSharedRecipe'),
            hasCooked: any(named: 'hasCooked'),
          )).thenAnswer((_) async {});
      when(() => mockRepo.logImportStarted(
            source: any(named: 'source'),
            platform: any(named: 'platform'),
            sessionId: any(named: 'sessionId'),
          )).thenAnswer((_) async {});
      when(() => mockRepo.logImportSuccess(
            source: any(named: 'source'),
            platform: any(named: 'platform'),
            recipeLength: any(named: 'recipeLength'),
            sessionId: any(named: 'sessionId'),
          )).thenAnswer((_) async {});
      when(() => mockRepo.logExtractionError(
            url: any(named: 'url'),
            platform: any(named: 'platform'),
            error: any(named: 'error'),
            errorType: any(named: 'errorType'),
          )).thenAnswer((_) async {});
      when(() => mockRepo.logManualCopyFallback(
            platform: any(named: 'platform'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async {});
      when(() => mockRepo.logRecipeCreated(
            source: any(named: 'source'),
            hasImage: any(named: 'hasImage'),
          )).thenAnswer((_) async {});
      when(() => mockRepo.logRecipeShared(
            method: any(named: 'method'),
          )).thenAnswer((_) async {});
      when(() => mockRepo.logRecipeCooked(
            recipeId: any(named: 'recipeId'),
            mealType: any(named: 'mealType'),
            isFirstTime: any(named: 'isFirstTime'),
            daysSinceLastCooked: any(named: 'daysSinceLastCooked'),
          )).thenAnswer((_) async {});
      when(() => mockRepo.logMenuGenerated(
            recipeCount: any(named: 'recipeCount'),
            method: any(named: 'method'),
          )).thenAnswer((_) async {});
      when(() => mockRepo.logRecipeDeleted(
            recipeId: any(named: 'recipeId'),
            mealType: any(named: 'mealType'),
            isPersonal: any(named: 'isPersonal'),
            createdAt: any(named: 'createdAt'),
            daysSinceCreated: any(named: 'daysSinceCreated'),
          )).thenAnswer((_) async {});

      service = AnalyticsService(repository: mockRepo);

      // Enable analytics consent so consent-gated methods work
      final mockConsent = _MockConsentService();
      when(() => mockConsent.hasConsent(any())).thenAnswer((_) async => true);
      service.setConsentService(mockConsent);
    });

    tearDown(() {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should have correct service name', () {
        expect(service.serviceName, equals('AnalyticsService'));
      });

      test('should expose observer from repository', () {
        expect(service.observer, isNull); // mocked as null
      });
    });

    group('Auth Events (consent-exempt)', () {
      test('should log login event', () async {
        await service.logLogin(method: 'email');
        verify(() => mockRepo.logLogin(loginMethod: 'email')).called(1);
      });

      test('should log sign up event', () async {
        await service.logSignUp(method: 'google');
        verify(() => mockRepo.logSignUp(signUpMethod: 'google')).called(1);
      });

      test('should log logout event', () async {
        await service.logLogout();
        verify(() => mockRepo.logLogout()).called(1);
      });

      test('should log account deleted event', () async {
        final params = {'user_id': 'u1', 'reason': 'requested'};
        await service.logAccountDeleted(params);
        verify(() => mockRepo.logAccountDeleted(params)).called(1);
      });
    });

    group('Import Events', () {
      test('should log import started', () async {
        await service.logImportStarted(source: 'web', platform: 'website');
        verify(() => mockRepo.logImportStarted(
              source: 'web',
              platform: 'website',
              sessionId: null,
            )).called(1);
      });

      test('should log import success', () async {
        await service.logImportSuccess(
          source: 'manual',
          platform: 'instagram',
          recipeLength: 1200,
        );
        verify(() => mockRepo.logImportSuccess(
              source: 'manual',
              platform: 'instagram',
              recipeLength: 1200,
              sessionId: null,
            )).called(1);
      });
    });

    group('Extraction Events', () {
      test('should log extraction error', () async {
        await service.logExtractionError(
          url: 'https://example.com',
          platform: SourcePlatform.website,
          error: 'timeout',
        );
        verify(() => mockRepo.logExtractionError(
              url: 'https://example.com',
              platform: 'website',
              error: 'timeout',
              errorType: null,
            )).called(1);
      });

      test('should log extraction error with explicit type', () async {
        await service.logExtractionError(
          url: 'https://example.com',
          platform: SourcePlatform.instagram,
          error: 'blocked',
          errorType: 'custom_error',
        );
        verify(() => mockRepo.logExtractionError(
              url: 'https://example.com',
              platform: 'instagram',
              error: 'blocked',
              errorType: 'custom_error',
            )).called(1);
      });

      test('should log manual copy fallback', () async {
        await service.logManualCopyFallback(
          platform: SourcePlatform.tiktok,
          reason: 'User chose manual',
        );
        verify(() => mockRepo.logManualCopyFallback(
              platform: 'tiktok',
              reason: 'User chose manual',
            )).called(1);
      });
    });

    group('Recipe Events', () {
      test('should log recipe created', () async {
        await service.logRecipeCreated(source: 'import', hasImage: true);
        verify(() => mockRepo.logRecipeCreated(
              source: 'import',
              hasImage: true,
            )).called(1);
      });

      test('should log recipe shared', () async {
        await service.logRecipeShared(method: 'link');
        verify(() => mockRepo.logRecipeShared(method: 'link')).called(1);
      });

      test('should log recipe cooked', () async {
        await service.logRecipeCooked(
          recipeId: 'r1',
          mealType: 'dinner',
          isFirstTime: false,
          daysSinceLastCooked: 7,
        );
        verify(() => mockRepo.logRecipeCooked(
              recipeId: 'r1',
              mealType: 'dinner',
              isFirstTime: false,
              daysSinceLastCooked: 7,
            )).called(1);
      });

      test('should log recipe deleted', () async {
        final created = DateTime(2026, 1, 1);
        await service.logRecipeDeleted(
          recipeId: 'r2',
          mealType: 'lunch',
          isPersonal: true,
          createdAt: created,
          daysSinceCreated: 30,
        );
        verify(() => mockRepo.logRecipeDeleted(
              recipeId: 'r2',
              mealType: 'lunch',
              isPersonal: true,
              createdAt: created,
              daysSinceCreated: 30,
            )).called(1);
      });
    });

    group('Menu Events', () {
      test('should log menu generated', () async {
        await service.logMenuGenerated(recipeCount: 7, method: 'auto');
        verify(() => mockRepo.logMenuGenerated(
              recipeCount: 7,
              method: 'auto',
            )).called(1);
      });
    });

    group('User Properties', () {
      test('should set user properties with recipe count', () async {
        await service.setUserProperties(recipeCount: 10);
        verify(() => mockRepo.setUserProperties(
              recipeCount: 10,
              hasUsedImport: null,
              hasSharedRecipe: null,
              hasCooked: null,
            )).called(1);
      });

      test('should set boolean user properties', () async {
        await service.setUserProperties(
          hasUsedImport: true,
          hasSharedRecipe: false,
          hasCooked: true,
        );
        verify(() => mockRepo.setUserProperties(
              recipeCount: null,
              hasUsedImport: true,
              hasSharedRecipe: false,
              hasCooked: true,
            )).called(1);
      });
    });

    group('Tracker Accessors', () {
      test('should expose all tracker modules', () {
        expect(service.recipe, isNotNull);
        expect(service.menu, isNotNull);
        expect(service.shopping, isNotNull);
        expect(service.social, isNotNull);
        expect(service.import, isNotNull);
        expect(service.system, isNotNull);
      });
    });
  });
}
