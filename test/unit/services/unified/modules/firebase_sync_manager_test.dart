/// Unit tests for FirebaseSyncManager
///
/// Tests sync lifecycle, change routing, health monitoring, and status queries.
/// Rewritten 2026-04-13: removed all Future.delayed, use deterministic streams.
library;

// ignore_for_file: cancel_subscriptions

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/services/unified/modules/firebase_sync_manager.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_change.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import '../../../../infrastructure/builders/recipe_builder.dart';

class _MockRecipeRepository extends Mock implements RecipeRepository {}

void main() {
  late _MockRecipeRepository mockRecipeRepo;
  late FakeFirebaseFirestore fakeFirestore;
  late Recipe testRecipe;

  setUp(() {
    mockRecipeRepo = _MockRecipeRepository();
    fakeFirestore = FakeFirebaseFirestore();
    testRecipe = RecipeBuilder().withTitle('Test Recipe').build();

    // Register mock so GetIt.instance<RecipeRepository>() resolves
    final getIt = GetIt.instance;
    if (getIt.isRegistered<RecipeRepository>()) {
      getIt.unregister<RecipeRepository>();
    }
    getIt.registerSingleton<RecipeRepository>(mockRecipeRepo);
  });

  tearDown(() async {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<RecipeRepository>()) {
      getIt.unregister<RecipeRepository>();
    }
  });

  group('startFirebaseSync', () {
    test('returns map with personal and collaborative subscriptions', () async {
      // Arrange: personal sync returns a stream subscription
      final controller = StreamController<List<RecipeChange>>();
      when(
        () => mockRecipeRepo.subscribeToUserRecipes(
          any(),
          any(),
          onError: any(named: 'onError'),
          onSyncStatusChanged: any(named: 'onSyncStatusChanged'),
        ),
      ).thenReturn(controller.stream.listen((_) {}));

      // Act
      final subs = await FirebaseSyncManager.startFirebaseSync(
        currentUserId: 'user-1',
        onRecipeUpdated: (_, __) {},
        onRecipeRemoved: (_, __) {},
        onSyncError: (_, __) {},
        firestore: fakeFirestore,
      );

      // Assert
      expect(subs, containsPair('personal_recipes', isA<StreamSubscription>()));
      expect(
        subs,
        containsPair('collaborative_recipes', isA<StreamSubscription>()),
      );
      expect(subs.length, equals(2));

      // Cleanup
      await FirebaseSyncManager.stopFirebaseSync(subscriptions: subs);
      await controller.close();
    });

    test('routes personal recipe changes to onRecipeUpdated', () async {
      final updatedRecipes = <Recipe>[];
      final controller = StreamController<List<RecipeChange>>();

      when(
        () => mockRecipeRepo.subscribeToUserRecipes(
          any(),
          any(),
          onError: any(named: 'onError'),
          onSyncStatusChanged: any(named: 'onSyncStatusChanged'),
        ),
      ).thenAnswer((invocation) {
        final callback =
            invocation.positionalArguments[1]
                as void Function(List<RecipeChange>);
        return controller.stream.listen((changes) => callback(changes));
      });

      final subs = await FirebaseSyncManager.startFirebaseSync(
        currentUserId: 'user-1',
        onRecipeUpdated: (recipe, source) => updatedRecipes.add(recipe),
        onRecipeRemoved: (_, __) {},
        onSyncError: (_, __) {},
        firestore: fakeFirestore,
      );

      // Emit a change
      controller.add([
        RecipeChange(type: RecipeChangeType.added, recipe: testRecipe),
      ]);
      await Future.microtask(() {}); // flush stream

      expect(updatedRecipes, hasLength(1));
      expect(updatedRecipes.first.id, equals(testRecipe.id));

      await FirebaseSyncManager.stopFirebaseSync(subscriptions: subs);
      await controller.close();
    });

    test('routes personal recipe removals to onRecipeRemoved', () async {
      final removedIds = <String>[];
      final controller = StreamController<List<RecipeChange>>();

      when(
        () => mockRecipeRepo.subscribeToUserRecipes(
          any(),
          any(),
          onError: any(named: 'onError'),
          onSyncStatusChanged: any(named: 'onSyncStatusChanged'),
        ),
      ).thenAnswer((invocation) {
        final callback =
            invocation.positionalArguments[1]
                as void Function(List<RecipeChange>);
        return controller.stream.listen((changes) => callback(changes));
      });

      final subs = await FirebaseSyncManager.startFirebaseSync(
        currentUserId: 'user-1',
        onRecipeUpdated: (_, __) {},
        onRecipeRemoved: (id, source) => removedIds.add(id),
        onSyncError: (_, __) {},
        firestore: fakeFirestore,
      );

      controller.add([
        RecipeChange(type: RecipeChangeType.removed, recipe: testRecipe),
      ]);
      await Future.microtask(() {});

      expect(removedIds, contains(testRecipe.id));

      await FirebaseSyncManager.stopFirebaseSync(subscriptions: subs);
      await controller.close();
    });
  });

  group('stopFirebaseSync', () {
    test('cancels all subscriptions and clears map', () async {
      final controller = StreamController<List<RecipeChange>>();
      when(
        () => mockRecipeRepo.subscribeToUserRecipes(
          any(),
          any(),
          onError: any(named: 'onError'),
          onSyncStatusChanged: any(named: 'onSyncStatusChanged'),
        ),
      ).thenReturn(controller.stream.listen((_) {}));

      final subs = await FirebaseSyncManager.startFirebaseSync(
        currentUserId: 'user-1',
        onRecipeUpdated: (_, __) {},
        onRecipeRemoved: (_, __) {},
        onSyncError: (_, __) {},
        firestore: fakeFirestore,
      );

      expect(subs, isNotEmpty);

      await FirebaseSyncManager.stopFirebaseSync(subscriptions: subs);

      expect(subs, isEmpty);
      await controller.close();
    });
  });

  group('stopSpecificSync', () {
    test('stops only the named sync stream', () async {
      final controller = StreamController<List<RecipeChange>>();
      when(
        () => mockRecipeRepo.subscribeToUserRecipes(
          any(),
          any(),
          onError: any(named: 'onError'),
          onSyncStatusChanged: any(named: 'onSyncStatusChanged'),
        ),
      ).thenReturn(controller.stream.listen((_) {}));

      final subs = await FirebaseSyncManager.startFirebaseSync(
        currentUserId: 'user-1',
        onRecipeUpdated: (_, __) {},
        onRecipeRemoved: (_, __) {},
        onSyncError: (_, __) {},
        firestore: fakeFirestore,
      );

      await FirebaseSyncManager.stopSpecificSync(
        subscriptions: subs,
        syncType: 'personal_recipes',
      );

      expect(subs.containsKey('personal_recipes'), isFalse);
      expect(subs.containsKey('collaborative_recipes'), isTrue);

      await FirebaseSyncManager.stopFirebaseSync(subscriptions: subs);
      await controller.close();
    });

    test('no-op for non-existent sync type', () async {
      final subs = <String, StreamSubscription>{};

      // Should not throw
      await FirebaseSyncManager.stopSpecificSync(
        subscriptions: subs,
        syncType: 'nonexistent',
      );

      expect(subs, isEmpty);
    });
  });

  group('ensureSyncHealth', () {
    test('restarts missing personal sync', () async {
      final controller = StreamController<List<RecipeChange>>();
      when(
        () => mockRecipeRepo.subscribeToUserRecipes(
          any(),
          any(),
          onError: any(named: 'onError'),
          onSyncStatusChanged: any(named: 'onSyncStatusChanged'),
        ),
      ).thenReturn(controller.stream.listen((_) {}));

      // Start with only collaborative (simulate personal dropped)
      final subs = <String, StreamSubscription>{
        'collaborative_recipes': fakeFirestore
            .collection('test')
            .snapshots()
            .listen((_) {}),
      };

      await FirebaseSyncManager.ensureSyncHealth(
        subscriptions: subs,
        currentUserId: 'user-1',
        onRecipeUpdated: (_, __) {},
        onRecipeRemoved: (_, __) {},
        onSyncError: (_, __) {},
        firestore: fakeFirestore,
      );

      expect(subs.containsKey('personal_recipes'), isTrue);
      expect(subs.length, equals(2));

      await FirebaseSyncManager.stopFirebaseSync(subscriptions: subs);
      await controller.close();
    });

    test('no-op when all syncs are active', () async {
      final controller = StreamController<List<RecipeChange>>();
      when(
        () => mockRecipeRepo.subscribeToUserRecipes(
          any(),
          any(),
          onError: any(named: 'onError'),
          onSyncStatusChanged: any(named: 'onSyncStatusChanged'),
        ),
      ).thenReturn(controller.stream.listen((_) {}));

      final subs = await FirebaseSyncManager.startFirebaseSync(
        currentUserId: 'user-1',
        onRecipeUpdated: (_, __) {},
        onRecipeRemoved: (_, __) {},
        onSyncError: (_, __) {},
        firestore: fakeFirestore,
      );

      final countBefore = subs.length;

      await FirebaseSyncManager.ensureSyncHealth(
        subscriptions: subs,
        currentUserId: 'user-1',
        onRecipeUpdated: (_, __) {},
        onRecipeRemoved: (_, __) {},
        onSyncError: (_, __) {},
        firestore: fakeFirestore,
      );

      expect(subs.length, equals(countBefore));

      await FirebaseSyncManager.stopFirebaseSync(subscriptions: subs);
      await controller.close();
    });
  });

  group('getSyncStatus', () {
    test('returns correct status for active syncs', () {
      final subs = <String, StreamSubscription>{
        'personal_recipes': Stream.empty().listen((_) {}),
        'collaborative_recipes': Stream.empty().listen((_) {}),
      };

      final status = FirebaseSyncManager.getSyncStatus(
        subscriptions: subs,
        currentUserId: 'user-1',
      );

      expect(status['isSyncing'], isTrue);
      expect(status['subscriptionCount'], equals(2));
      expect(status['personalSyncActive'], isTrue);
      expect(status['collaborativeSyncActive'], isTrue);
      expect(status['currentUserId'], equals('user-1'));
    });

    test('returns correct status for empty syncs', () {
      final status = FirebaseSyncManager.getSyncStatus(
        subscriptions: {},
        currentUserId: null,
      );

      expect(status['isSyncing'], isFalse);
      expect(status['subscriptionCount'], equals(0));
      expect(status['personalSyncActive'], isFalse);
      expect(status['collaborativeSyncActive'], isFalse);
    });
  });

  group('utility methods', () {
    test('isSyncing returns true when subscriptions exist', () {
      final subs = <String, StreamSubscription>{
        'personal_recipes': Stream.empty().listen((_) {}),
      };
      expect(FirebaseSyncManager.isSyncing(subs), isTrue);
    });

    test('isSyncing returns false for empty map', () {
      expect(FirebaseSyncManager.isSyncing({}), isFalse);
    });

    test('isPersonalSyncActive checks key', () {
      final subs = <String, StreamSubscription>{
        'personal_recipes': Stream.empty().listen((_) {}),
      };
      expect(FirebaseSyncManager.isPersonalSyncActive(subs), isTrue);
      expect(FirebaseSyncManager.isCollaborativeSyncActive(subs), isFalse);
    });

    test('getActiveSubscriptions returns key list', () {
      final subs = <String, StreamSubscription>{
        'personal_recipes': Stream.empty().listen((_) {}),
        'collaborative_recipes': Stream.empty().listen((_) {}),
      };
      expect(
        FirebaseSyncManager.getActiveSubscriptions(subs),
        containsAll(['personal_recipes', 'collaborative_recipes']),
      );
    });
  });

  group('collaborative sync via Firestore', () {
    test('collaborative sync listens to realtimeRecipes collection', () async {
      final controller = StreamController<List<RecipeChange>>();
      when(
        () => mockRecipeRepo.subscribeToUserRecipes(
          any(),
          any(),
          onError: any(named: 'onError'),
          onSyncStatusChanged: any(named: 'onSyncStatusChanged'),
        ),
      ).thenReturn(controller.stream.listen((_) {}));

      final subs = await FirebaseSyncManager.startFirebaseSync(
        currentUserId: 'user-1',
        onRecipeUpdated: (_, __) {},
        onRecipeRemoved: (_, __) {},
        onSyncError: (_, __) {},
        firestore: fakeFirestore,
      );

      // Collaborative sub should be listening to realtimeRecipes
      expect(subs['collaborative_recipes'], isNotNull);

      await FirebaseSyncManager.stopFirebaseSync(subscriptions: subs);
      await controller.close();
    });
  });
}
