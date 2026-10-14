import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/services/unified/helpers/recipe_utility_operations.dart';
import 'package:butlery/services/unified/modules/recipe_cache_module.dart';
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';

import '../../../../infrastructure/factories/recipe_factory.dart';
import '../../../../test_support/base_unit_test.dart';

class _MockCacheModule extends Mock implements RecipeCacheModule {}

class _MockAuthRepository extends Mock implements FirebaseAuthRepository {}

class _MockAdapter extends Mock implements RecipeServiceAdapter {}

void main() {
  late _MockCacheModule cache;
  late _MockAuthRepository auth;
  late List<Recipe> recipes;
  late List<bool> loading;
  late List<String> errors;
  late RecipeUtilityOperations ops;

  setUp(() async {
    await BaseUnitTest.setupUnit();
    cache = _MockCacheModule();
    auth = _MockAuthRepository();
    recipes = [
      RecipeFactory.build(id: 'old-1'),
      RecipeFactory.build(id: 'old-2'),
    ];
    loading = [];
    errors = [];
    when(() => auth.currentUser).thenReturn(null);
    when(() => cache.stopFirebaseSync()).thenAnswer((_) async {});
    ops = RecipeUtilityOperations(
      cacheModule: cache,
      authRepository: auth,
      recipes: recipes,
      getServiceAdapter: () => _MockAdapter(),
      getRecipeById: (id) => null,
      setError: errors.add,
      setLoading: loading.add,
      notifyListeners: () {},
    );
  });

  List<String> ids() => recipes.map((r) => r.id).toList();

  group('refresh', () {
    test('keeps the list on screen until the load has finished', () async {
      final gate = Completer<List<Recipe>>();
      when(() => cache.initializeCache()).thenAnswer((_) => gate.future);

      final pending = ops.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(ids(), ['old-1', 'old-2']);

      gate.complete([RecipeFactory.build(id: 'new-1')]);
      await pending;
    });

    test('replaces the list with the loaded recipes', () async {
      when(() => cache.initializeCache()).thenAnswer(
        (_) async => [
          RecipeFactory.build(id: 'new-1'),
          RecipeFactory.build(id: 'new-2'),
          RecipeFactory.build(id: 'new-3'),
        ],
      );

      await ops.refresh();

      expect(ids(), ['new-1', 'new-2', 'new-3']);
      expect(errors, isEmpty);
      expect(loading, [true, false]);
    });

    test('a throwing load reports the error and ends loading', () async {
      when(() => cache.initializeCache()).thenThrow(StateError('boom'));

      await ops.refresh();

      expect(errors, [AppLocale.current.errorCouldNotUpdateRecipes]);
      expect(loading, [true, false]);
      expect(ids(), ['old-1', 'old-2']);
    });
  });
}
