import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/helpers/recipe_auth_state_handler.dart';
import 'package:butlery/services/unified/modules/recipe_cache_module.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../infrastructure/factories/mock_factory.dart';
import '../../../../infrastructure/factories/recipe_factory.dart';
import '../../../../infrastructure/mocks/production_mocks.dart' as mocks;

class _MockCacheModule extends Mock implements RecipeCacheModule {}

void main() {
  test('recipes the live sync puts on screen while the cache is re-read '
      'after sign-in are listed once and kept', () async {
    final recipes = <Recipe>[];
    final cache = _MockCacheModule();
    final auth = mocks.MockFirebaseAuthRepository()
      ..setAuthState(
        user: MockFactory.createMockUser(uid: 'u1') as User?,
        userId: 'u1',
      );
    final early = RecipeFactory.build(id: 'early', title: 'Gröt');
    final late = RecipeFactory.build(id: 'late', title: 'Soppa');
    final cachedOnly = RecipeFactory.build(id: 'cached', title: 'Paj');

    var reads = 0;
    when(cache.initializeCache).thenAnswer((_) async {
      reads++;
      if (reads == 1) return <Recipe>[];
      // The sync delivers two recipes while this read is in flight. Both
      // reach the screen list directly; the read returns an older copy of
      // `early` from the cache, and `late` was cached after the read had
      // passed it.
      recipes
        ..add(early)
        ..add(late);
      return [early.copyWith(title: 'Gammal gröt'), cachedOnly];
    });
    when(cache.startFirebaseSync).thenAnswer((_) async {});

    await RecipeAuthStateHandler(
      cacheModule: cache,
      authRepository: auth,
      recipes: recipes,
      setError: (_) {},
      setLoading: (_) {},
      notifyListeners: () {},
    ).reloadUserRecipes('u1');

    expect(recipes.map((r) => r.id).toList()..sort(), [
      'cached',
      'early',
      'late',
    ]);
    expect(recipes.firstWhere((r) => r.id == 'early').title, 'Gröt');
  });
}
