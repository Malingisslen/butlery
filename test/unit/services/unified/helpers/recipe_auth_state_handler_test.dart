import 'dart:async';

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

  /// Proves: a reload still reading the cache when the account signs out does
  /// not put that account's recipes back on screen after the list was cleared.
  test('a reload in flight at sign-out is dropped (BUT-2517)', () async {
    final recipes = <Recipe>[];
    final cache = _MockCacheModule();
    final auth = mocks.MockFirebaseAuthRepository()
      ..setAuthState(
        user: MockFactory.createMockUser(uid: 'u1') as User?,
        userId: 'u1',
      );
    final gate = Completer<List<Recipe>>();
    when(cache.initializeCache).thenAnswer((_) => gate.future);
    when(cache.startFirebaseSync).thenAnswer((_) async {});
    final handler = RecipeAuthStateHandler(
      cacheModule: cache,
      authRepository: auth,
      recipes: recipes,
      setError: (_) {},
      setLoading: (_) {},
      notifyListeners: () {},
    );

    final inFlight = handler.reloadUserRecipes('u1');
    handler.handleAuthStateChange(null);
    gate.complete([RecipeFactory.build(id: 'forra', title: 'Förra kontots')]);
    await inFlight;

    expect(recipes, isEmpty);
    verifyNever(cache.startFirebaseSync);
  });

  /// Proves: when the account changes from A to B while A's reload is still
  /// reading, A's recipes are dropped and B's reload alone fills the list.
  test(
    'a reload in flight at an account switch is dropped (BUT-2517)',
    () async {
      final recipes = <Recipe>[];
      final cache = _MockCacheModule();
      final auth = mocks.MockFirebaseAuthRepository()
        ..setAuthState(
          user: MockFactory.createMockUser(uid: 'b') as User?,
          userId: 'b',
        );
      final gateA = Completer<List<Recipe>>();
      var reads = 0;
      when(cache.initializeCache).thenAnswer((_) {
        reads++;
        if (reads == 1) return gateA.future;
        return Future.value([
          RecipeFactory.build(id: 'b1', title: 'B:s recept'),
        ]);
      });
      when(cache.startFirebaseSync).thenAnswer((_) async {});
      final handler = RecipeAuthStateHandler(
        cacheModule: cache,
        authRepository: auth,
        recipes: recipes,
        setError: (_) {},
        setLoading: (_) {},
        notifyListeners: () {},
      );

      final reloadA = handler.reloadUserRecipes('a');
      handler.handleAuthStateChange('b');
      gateA.complete([RecipeFactory.build(id: 'a1', title: 'A:s recept')]);
      await reloadA;
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(recipes.map((r) => r.id), ['b1']);
    },
  );

  /// Proves: cancelInFlight stops a reload that is still reading.
  test('cancelInFlight drops a reload in flight (BUT-2517)', () async {
    final recipes = <Recipe>[];
    final cache = _MockCacheModule();
    final auth = mocks.MockFirebaseAuthRepository()
      ..setAuthState(
        user: MockFactory.createMockUser(uid: 'u1') as User?,
        userId: 'u1',
      );
    final gate = Completer<List<Recipe>>();
    when(cache.initializeCache).thenAnswer((_) => gate.future);
    when(cache.startFirebaseSync).thenAnswer((_) async {});
    final handler = RecipeAuthStateHandler(
      cacheModule: cache,
      authRepository: auth,
      recipes: recipes,
      setError: (_) {},
      setLoading: (_) {},
      notifyListeners: () {},
    );

    final inFlight = handler.reloadUserRecipes('u1');
    handler.cancelInFlight();
    gate.complete([RecipeFactory.build(id: 'forra')]);
    await inFlight;

    expect(recipes, isEmpty);
  });
}
