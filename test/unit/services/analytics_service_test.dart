import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/analytics/winback_attribution_service.dart';
import 'package:butlery/services/content_detector_service.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;

import '../../test_support/base_unit_test.dart';

/// Minimal mock that does NOT override any methods concretely,
/// so all methods are stubbable via mocktail's when().
class _MockAnalyticsRepo extends Mock implements AnalyticsRepository {}

class _MockConsentService extends Mock implements ConsentService {}

class _MockWinbackAttributionService extends Mock
    implements WinbackAttributionService {}

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
            imageFormat: any(named: 'imageFormat'),
          )).thenAnswer((_) async {});
      when(() => mockRepo.logImportSuccess(
            source: any(named: 'source'),
            platform: any(named: 'platform'),
            recipeLength: any(named: 'recipeLength'),
            sessionId: any(named: 'sessionId'),
            imageFormat: any(named: 'imageFormat'),
            imageFormatSent: any(named: 'imageFormatSent'),
          )).thenAnswer((_) async {});
      when(() => mockRepo.logExtractionError(
            url: any(named: 'url'),
            platform: any(named: 'platform'),
            error: any(named: 'error'),
            errorType: any(named: 'errorType'),
            imageFormat: any(named: 'imageFormat'),
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
              imageFormat: 'unknown',
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
              imageFormat: 'unknown',
              imageFormatSent: 'unknown',
            )).called(1);
      });

      // BUT-662: photo OCR path threads original + post-conversion format
      // through to the repository so HEIC prevalence is measurable.
      test('should pass imageFormat through to import success', () async {
        await service.logImportSuccess(
          source: 'photo',
          imageFormat: 'heic',
          imageFormatSent: 'jpeg',
        );
        verify(() => mockRepo.logImportSuccess(
              source: 'photo',
              platform: null,
              recipeLength: null,
              sessionId: null,
              imageFormat: 'heic',
              imageFormatSent: 'jpeg',
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
              imageFormat: 'unknown',
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
              imageFormat: 'unknown',
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

      test('should log recipe shared via generic logEvent path', () async {
        // BUT-532: routes through logEvent (not the dedicated repo method) so
        // the new method/recipient_count/recipe_id params can ride along, and
        // recipe_id passes through the repo's PII hash gate.
        await service.logRecipeShared(
          method: 'link',
          recipeId: 'r1',
          recipientCount: 3,
        );
        final captured = verify(() => mockRepo.logEvent(
              name: 'recipe_shared',
              parameters: captureAny(named: 'parameters'),
            )).captured.single as Map<String, Object>;
        expect(captured['method'], 'link');
        expect(captured['recipe_id'], 'r1');
        expect(captured['recipient_count_bucket'], '2-5');
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
        expect(service.import, isNotNull);
        expect(service.system, isNotNull);
        expect(service.social, isNotNull);
      });
    });
  });

  /// BUT-691 follow-up: typed delegate methods (`logRecipeCooked`,
  /// `logImportSuccess`, `logMenuGenerated`) bypass `logEvent` and route
  /// directly to the repository's typed methods. Without their own probe
  /// site, win-back attribution would silently miss the three events that
  /// matter most for the conversion funnel. These tests assert each typed
  /// method fires exactly one probe with the canonical FA event name.
  group('AnalyticsService — Win-back probe on typed delegate paths', () {
    late AnalyticsService service;
    late _MockAnalyticsRepo mockRepo;
    late _MockWinbackAttributionService mockWinback;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(<String, Object>{});
      registerFallbackValue(DateTime.now());
      registerFallbackValue(ConsentPurpose.analytics);
      // Production ServiceLocator must be initialized so the probe's
      // ServiceLocator.get<WinbackAttributionService>() resolves.
      prod.ServiceLocator.initialize(DIContainer());
    });

    setUp(() {
      mockRepo = _MockAnalyticsRepo();
      mockWinback = _MockWinbackAttributionService();

      when(() => mockRepo.initialize()).thenAnswer((_) async {});
      when(() => mockRepo.observer).thenReturn(null);
      when(() => mockRepo.logImportSuccess(
            source: any(named: 'source'),
            platform: any(named: 'platform'),
            recipeLength: any(named: 'recipeLength'),
            sessionId: any(named: 'sessionId'),
            imageFormat: any(named: 'imageFormat'),
            imageFormatSent: any(named: 'imageFormatSent'),
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

      when(() => mockWinback.attemptAttribution(any()))
          .thenAnswer((_) async {});
      // Hot-path optimization in AnalyticsService skips the probe when
      // hasContext == false — these tests verify probe is INVOKED, so
      // we stub hasContext to true.
      when(() => mockWinback.hasContext).thenReturn(true);

      // Register the Winback mock via GetIt so the production
      // ServiceLocator.get<WinbackAttributionService>() resolves to it.
      final getIt = GetIt.instance;
      if (getIt.isRegistered<WinbackAttributionService>()) {
        getIt.unregister<WinbackAttributionService>();
      }
      getIt.registerSingleton<WinbackAttributionService>(mockWinback);

      service = AnalyticsService(repository: mockRepo);

      final mockConsent = _MockConsentService();
      when(() => mockConsent.hasConsent(any())).thenAnswer((_) async => true);
      service.setConsentService(mockConsent);
    });

    tearDown(() {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<WinbackAttributionService>()) {
        getIt.unregister<WinbackAttributionService>();
      }
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      prod.ServiceLocator.reset();
      await BaseUnitTest.teardownUnit();
    });

    test('logRecipeCooked probes attribution with recipe_cooked', () async {
      await service.logRecipeCooked(
        recipeId: 'r1',
        mealType: 'dinner',
        isFirstTime: false,
        daysSinceLastCooked: 7,
      );
      // Probe is fire-and-forget — let the unawaited future settle.
      await Future<void>.delayed(Duration.zero);
      verify(() => mockWinback.attemptAttribution('recipe_cooked')).called(1);
    });

    test('logImportSuccess probes attribution with import_success', () async {
      await service.logImportSuccess(
        source: 'manual',
        platform: 'instagram',
        recipeLength: 1200,
      );
      await Future<void>.delayed(Duration.zero);
      verify(() => mockWinback.attemptAttribution('import_success')).called(1);
    });

    test('logMenuGenerated probes attribution with menu_generated', () async {
      await service.logMenuGenerated(recipeCount: 7, method: 'auto');
      await Future<void>.delayed(Duration.zero);
      verify(() => mockWinback.attemptAttribution('menu_generated')).called(1);
    });
  });
}
