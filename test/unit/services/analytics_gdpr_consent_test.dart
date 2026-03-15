import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/mixins/singleton_service_mixin.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('AnalyticsService GDPR Consent', () {
    late MockAnalyticsRepository mockRepository;
    late MockConsentService mockConsentService;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(<String, Object>{});
      registerFallbackValue(DateTime.now());
    });

    setUp(() {
      SingletonServiceMixin.resetForTesting();
      mockRepository = MockAnalyticsRepository();
      mockConsentService = MockConsentService();

      // Stub all repository methods
      when(() => mockRepository.initialize()).thenAnswer((_) async {});
      when(() => mockRepository.logRecipeCooked(
            recipeId: any(named: 'recipeId'),
            mealType: any(named: 'mealType'),
            isFirstTime: any(named: 'isFirstTime'),
            daysSinceLastCooked: any(named: 'daysSinceLastCooked'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.logRecipeDeleted(
            recipeId: any(named: 'recipeId'),
            mealType: any(named: 'mealType'),
            isPersonal: any(named: 'isPersonal'),
            createdAt: any(named: 'createdAt'),
            daysSinceCreated: any(named: 'daysSinceCreated'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.logMenuGenerated(
            recipeCount: any(named: 'recipeCount'),
            method: any(named: 'method'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.setUserProperties(
            recipeCount: any(named: 'recipeCount'),
            hasUsedImport: any(named: 'hasUsedImport'),
            hasSharedRecipe: any(named: 'hasSharedRecipe'),
            hasCooked: any(named: 'hasCooked'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.logLogin(
            loginMethod: any(named: 'loginMethod'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.logLogout()).thenAnswer((_) async {});
    });

    tearDown(() {
      SingletonServiceMixin.resetForTesting();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    test('should default to false when ConsentService is null', () async {
      final service = AnalyticsService(repository: mockRepository);
      // No setConsentService call — consent is null

      await service.setUserProperties(recipeCount: 5);

      verifyNever(() => mockRepository.setUserProperties(
            recipeCount: any(named: 'recipeCount'),
            hasUsedImport: any(named: 'hasUsedImport'),
            hasSharedRecipe: any(named: 'hasSharedRecipe'),
            hasCooked: any(named: 'hasCooked'),
          ));
    });

    test('logRecipeCooked should respect consent denial', () async {
      when(() => mockConsentService.hasConsent(any()))
          .thenAnswer((_) async => false);

      final service = AnalyticsService(repository: mockRepository);
      service.setConsentService(mockConsentService);

      await service.logRecipeCooked(recipeId: 'r1', mealType: 'dinner');

      verifyNever(() => mockRepository.logRecipeCooked(
            recipeId: any(named: 'recipeId'),
            mealType: any(named: 'mealType'),
            isFirstTime: any(named: 'isFirstTime'),
            daysSinceLastCooked: any(named: 'daysSinceLastCooked'),
          ));
    });

    test('logRecipeDeleted should respect consent denial', () async {
      when(() => mockConsentService.hasConsent(any()))
          .thenAnswer((_) async => false);

      SingletonServiceMixin.resetForTesting();
      final service = AnalyticsService(repository: mockRepository);
      service.setConsentService(mockConsentService);

      await service.logRecipeDeleted(
        recipeId: 'r2',
        mealType: 'lunch',
        isPersonal: true,
        createdAt: DateTime.now(),
      );

      verifyNever(() => mockRepository.logRecipeDeleted(
            recipeId: any(named: 'recipeId'),
            mealType: any(named: 'mealType'),
            isPersonal: any(named: 'isPersonal'),
            createdAt: any(named: 'createdAt'),
            daysSinceCreated: any(named: 'daysSinceCreated'),
          ));
    });

    test('logMenuGenerated should respect consent denial', () async {
      when(() => mockConsentService.hasConsent(any()))
          .thenAnswer((_) async => false);

      final service = AnalyticsService(repository: mockRepository);
      service.setConsentService(mockConsentService);

      await service.logMenuGenerated(recipeCount: 5, method: 'auto');

      verifyNever(() => mockRepository.logMenuGenerated(
            recipeCount: any(named: 'recipeCount'),
            method: any(named: 'method'),
          ));
    });

    test('setUserProperties should respect consent denial', () async {
      when(() => mockConsentService.hasConsent(any()))
          .thenAnswer((_) async => false);

      SingletonServiceMixin.resetForTesting();
      final service = AnalyticsService(repository: mockRepository);
      service.setConsentService(mockConsentService);

      await service.setUserProperties(recipeCount: 10);

      verifyNever(() => mockRepository.setUserProperties(
            recipeCount: any(named: 'recipeCount'),
            hasUsedImport: any(named: 'hasUsedImport'),
            hasSharedRecipe: any(named: 'hasSharedRecipe'),
            hasCooked: any(named: 'hasCooked'),
          ));
    });

    test('auth events should bypass consent', () async {
      when(() => mockConsentService.hasConsent(any()))
          .thenAnswer((_) async => false);

      SingletonServiceMixin.resetForTesting();
      final service = AnalyticsService(repository: mockRepository);
      service.setConsentService(mockConsentService);

      await service.logLogin(method: 'email');
      await service.logLogout();

      verify(() => mockRepository.logLogin(loginMethod: 'email')).called(1);
      verify(() => mockRepository.logLogout()).called(1);
    });

    test('should allow events when consent is granted', () async {
      when(() => mockConsentService.hasConsent(any()))
          .thenAnswer((_) async => true);

      SingletonServiceMixin.resetForTesting();
      final service = AnalyticsService(repository: mockRepository);
      service.setConsentService(mockConsentService);

      await service.setUserProperties(recipeCount: 5);

      verify(() => mockRepository.setUserProperties(
            recipeCount: 5,
            hasUsedImport: null,
            hasSharedRecipe: null,
            hasCooked: null,
          )).called(1);
    });
  });
}
