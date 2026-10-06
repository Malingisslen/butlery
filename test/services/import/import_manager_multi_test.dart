import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  group('ImportManager.autoParseMulti', () {
    late ImportManager importManager;
    late MockPersonalRecipeOperations mockPersonalOps;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
    });

    setUp(() {
      mockPersonalOps = MockPersonalRecipeOperations();
      when(
        () => mockPersonalOps.addUnifiedRecipe(any()),
      ).thenAnswer((_) async => RecipeOperationResult.success('Added'));
      importManager = ImportManager.withStrategies(
        mockPersonalOps,
        [TextImportStrategy()],
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    const threeRecipePage = '''
Pannkakor
Ingredienser:
3 dl vetemjöl
2 ägg
Gör så här:
Vispa ihop smeten och stek i smör.

Våfflor
Ingredienser:
4 dl vetemjöl
3 dl grädde
Gör så här:
Grädda i våffeljärn tills gyllene.

Plättar
Ingredienser:
2 dl vetemjöl
2 dl mjölk
Gör så här:
Stek små plättar i plättlagg.''';

    const singleRecipe = '''
Pannkakor
Ingredienser:
3 dl vetemjöl
2 ägg
Gör så här:
Vispa ihop smeten och stek i smör.''';

    test(
      'returns exactly one recipe for a single-recipe blob (identity)',
      () async {
        final result = await importManager.autoParseMulti(singleRecipe);
        expect(result.successfulRecipes, hasLength(1));
      },
    );

    test('returns three recipes for a three-recipe page', () async {
      final result = await importManager.autoParseMulti(threeRecipePage);
      expect(
        result.successfulRecipes.length,
        greaterThanOrEqualTo(3),
        reason: 'each title→ingredients→instructions block parses',
      );
    });

    test('is parse-only — never saves to PersonalRecipeOperations', () async {
      await importManager.autoParseMulti(threeRecipePage);
      verifyNever(() => mockPersonalOps.addUnifiedRecipe(any()));
    });
  });
  // Review of resa 11: a paste of several recipes went through autoParseMulti,
  // which skipped the limit autoImport checks.
  group('ImportManager.autoParseMulti rate limit', () {
    late _CountingRateLimiter limiter;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      limiter = _CountingRateLimiter();
      final getIt = GetIt.instance;
      if (getIt.isRegistered<ImportRateLimiter>()) {
        getIt.unregister<ImportRateLimiter>();
      }
      getIt.registerSingleton<ImportRateLimiter>(limiter);
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(DIContainer());
    });

    tearDown(() async {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<ImportRateLimiter>()) {
        getIt.unregister<ImportRateLimiter>();
      }
      app_provider.ServiceLocator.reset();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    const page =
        'Pannkakor\nIngredienser:\n3 dl vetemjöl\n2 ägg\n'
        'Gör så här:\nVispa ihop och stek.';

    ImportManager manager() => ImportManager.withStrategies(
      MockPersonalRecipeOperations(),
      [TextImportStrategy()],
    );

    test('a denied limit parses nothing and says why', () async {
      limiter.deny = true;

      final result = await manager().autoParseMulti(page);

      expect(result.successfulRecipes, isEmpty);
      expect(result.results.single.rateLimitDenied, same(limiter.denial));
      expect(limiter.recorded, isEmpty);
    });

    test('an already measured parse is not checked again', () async {
      limiter.deny = true;

      final result = await manager().autoParseMulti(page, channel: null);

      expect(result.successfulRecipes, hasLength(1));
      expect(limiter.checks, 0);
    });
  });
}

class _CountingRateLimiter extends Fake implements ImportRateLimiter {
  bool deny = false;
  int checks = 0;
  final List<ImportOperation> recorded = [];
  final denial = const RateLimitDenied(
    message: 'limit',
    retryAfter: Duration(minutes: 1),
    limitType: LimitType.perMinute,
    suggestedAction: FallbackAction.retryLater,
  );

  @override
  Future<RateLimitResult> checkLimit(ImportOperation operation) async {
    checks++;
    return deny
        ? denial
        : const RateLimitAllowed(
            remainingInWindow: 5,
            limitType: LimitType.perMinute,
          );
  }

  @override
  Future<void> recordUsage(ImportOperation operation) async {
    recorded.add(operation);
  }
}
