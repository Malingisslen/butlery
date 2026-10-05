/// The tag audit row is written in the background: a save must not wait for
/// it. Offline, a Firestore write's future does not complete until the device
/// is back online, so an awaited audit write held the whole save.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/unified/modules/personal_recipe_module.dart';

import '../../../../infrastructure/factories/recipe_factory.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../test_support/base_unit_test.dart';

class _MockTaggingService extends Mock implements TaggingService {}

class _MockAuditRepository extends Mock implements FirebaseAuditRepository {}

void main() {
  late _MockTaggingService tagging;
  late _MockAuditRepository audit;
  late PersonalRecipeModule module;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(RecipeFactory.build());
  });

  setUp(() {
    production.ServiceLocator.initialize(DIContainer());
    audit = _MockAuditRepository();
    // Never completes, like a Firestore write made offline.
    when(
      () => audit.logTagModification(
        userId: any(named: 'userId'),
        recipeId: any(named: 'recipeId'),
        previousTags: any(named: 'previousTags'),
        newTags: any(named: 'newTags'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) => Completer<void>().future);
    GetIt.instance.registerSingleton<FirebaseAuditRepository>(audit);

    tagging = _MockTaggingService();
    when(() => tagging.generateTags(any())).thenAnswer(
      (_) async => TagResult(
        tags: const {},
        allergenStatus: const {},
        dietaryStatus: const {},
        coverage: 1.0,
        generatedAt: clock.now(),
      ),
    );

    module = PersonalRecipeModule(
      recipeRepository: MockRecipeRepository(),
      userRepository: MockUserRepository(),
      getCacheHelper: FakeJsonCacheHelper.new,
      getCurrentUserId: () => 'test-user-123',
      getCurrentUserDisplayName: () => 'Test User',
      setError: (_) {},
      notifyListeners: () {},
      getServiceAdapter: MockRecipeServiceAdapter.new,
      taggingService: tagging,
    );
  });

  tearDown(() async {
    await GetIt.instance.unregister<FirebaseAuditRepository>();
    production.ServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  test('a save does not wait for the tag audit write', () async {
    final Recipe recipe = RecipeFactory.build(
      id: 'test-recipe-1',
      createdBy: 'test-user-123',
    );

    final ids = await module
        .importRecipesFromData([recipe.toJson()])
        .timeout(const Duration(seconds: 2));

    expect(ids, hasLength(1));
    verify(
      () => audit.logTagModification(
        userId: 'test-user-123',
        recipeId: any(named: 'recipeId'),
        previousTags: any(named: 'previousTags'),
        newTags: any(named: 'newTags'),
        source: 'import',
      ),
    ).called(1);
  });
}
