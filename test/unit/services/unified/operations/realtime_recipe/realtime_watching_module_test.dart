// test/unit/services/unified/operations/realtime_recipe/realtime_watching_module_test.dart

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/realtime_watching_module.dart';
import 'package:butlery/services/realtime/realtime_types.dart' as rt;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/builders/recipe_builder.dart';
import '../../../../../infrastructure/builders/realtime_recipe_builder.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;

void main() {
  group('RealtimeWatchingModule', () {
    late MockUnifiedRecipeService mockParentService;
    late MockRealtimeSyncService mockRealtimeSyncService;
    late RealtimeWatchingModule watchingModule;
    late Recipe testRecipe;
    late RealtimeRecipe testRealtimeRecipe;

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(Recipe(
        core: RecipeCore(
          id: 'test',
          title: 'Test',
          description: 'Test',
          ingredients: [],
          instructions: [],
          mealType: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        type: RecipeType.personal,
      ));
      registerFallbackValue(RealtimeRecipeBuilder().build());
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Create mocks
      mockParentService = MockUnifiedRecipeService();
      mockRealtimeSyncService = MockRealtimeSyncService();

      // Initialize production ServiceLocator with MockDIContainer
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(MockDIContainer());

      // Create test data
      testRecipe = RecipeBuilder()
          .withId('recipe_1')
          .withTitle('Test Recipe')
          .asRealtime()
          .build();

      testRealtimeRecipe = RealtimeRecipeBuilder()
          .withId('recipe_1')
          .withTitle('Test Recipe')
          .build();

      // Configure mock services using centralized mock methods
      mockParentService.setRecipeState(
        recipes: [testRecipe],
      );

      mockRealtimeSyncService.setConnectionState(true);

      // Create watching module instance
      watchingModule = RealtimeWatchingModule(
        getRecipes: () => mockParentService.recipes,
        realtimeSyncService: mockRealtimeSyncService,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });

    group('Single Recipe Watching', () {
      test('should watch recipe with realtime service', () async {
        // Arrange
        when(() => mockRealtimeSyncService.watchResource<RealtimeRecipe>(
            'recipe_1')).thenAnswer((_) => Stream.value(testRealtimeRecipe));

        // Act
        final stream = watchingModule.watchRecipe('recipe_1');

        // Assert
        final recipe = await stream.first;
        expect(recipe.id, equals('recipe_1'));
      });

      test('should fall back to polling when realtime service unavailable',
          () async {
        // Arrange
        watchingModule = RealtimeWatchingModule(
          getRecipes: () => mockParentService.recipes,
        );

        // Act
        final stream = watchingModule.watchRecipe('recipe_1');

        // Assert
        await expectLater(
          stream.take(1),
          emitsInOrder([isA<Recipe>()]),
        );
      });

      test('should watch recipe with retry on failure', () async {
        // Arrange
        when(() => mockRealtimeSyncService.watchResource<RealtimeRecipe>(
            'recipe_1')).thenAnswer((_) => Stream.value(testRealtimeRecipe));

        // Act
        final stream = watchingModule.watchRecipeWithRetry(
          'recipe_1',
          maxRetries: 2,
          retryDelay: Duration(milliseconds: 10),
        );

        // Assert
        final recipe = await stream.first;
        expect(recipe.id, equals('recipe_1'));
      });

      test('should handle watch errors gracefully', () async {
        // Arrange
        when(() => mockRealtimeSyncService
                .watchResource<RealtimeRecipe>('recipe_1'))
            .thenAnswer((_) => Stream.error(Exception('Watch failed')));

        // Act
        final stream = watchingModule.watchRecipe('recipe_1');

        // Assert
        await expectLater(
          stream.handleError((error) {}),
          emitsDone,
        );
      });
    });

    group('Multiple Recipe Watching', () {
      test('should watch multiple recipes simultaneously', () async {
        // Arrange
        final recipe2 =
            RecipeBuilder().withId('recipe_2').withTitle('Recipe 2').build();
        mockParentService.setRecipeState(
          recipes: [testRecipe, recipe2],
        );

        when(() => mockRealtimeSyncService.watchResource<RealtimeRecipe>(
            'recipe_1')).thenAnswer((_) => Stream.value(testRealtimeRecipe));
        when(() =>
            mockRealtimeSyncService
                .watchResource<RealtimeRecipe>('recipe_2')).thenAnswer((_) =>
            Stream.value(RealtimeRecipeBuilder().withId('recipe_2').build()));

        // Act
        final stream =
            watchingModule.watchMultipleRecipes(['recipe_1', 'recipe_2']);

        // Assert — production emits whenever any subscription updates
        // currentRecipes. The first emission contains 1 recipe (whichever
        // sub fired first); the second contains both. Wait for the
        // both-arrived state instead of racing the microtask order.
        final recipes = await stream.firstWhere((r) => r.length == 2);
        expect(recipes.length, equals(2));
      });

      test('should watch multiple recipes individually with error handling',
          () async {
        // Arrange
        when(() => mockRealtimeSyncService.watchResource<RealtimeRecipe>(
            'recipe_1')).thenAnswer((_) => Stream.value(testRealtimeRecipe));
        when(() => mockRealtimeSyncService
                .watchResource<RealtimeRecipe>('recipe_2'))
            .thenAnswer((_) => Stream.error(Exception('Recipe 2 error')));

        // Act
        final stream = watchingModule
            .watchMultipleRecipesIndividually(['recipe_1', 'recipe_2']);

        // Assert
        final result = await stream.first;
        expect(result['recipe_1'], isNotNull);
        expect(result['recipe_2'], isNull);
      });

      test('should fall back to polling for multiple recipes', () async {
        // Arrange
        watchingModule = RealtimeWatchingModule(
          getRecipes: () => mockParentService.recipes,
        );

        // Act
        final stream = watchingModule.watchMultipleRecipes(['recipe_1']);

        // Assert
        await expectLater(
          stream.take(1),
          emitsInOrder([isA<List<Recipe>>()]),
        );
      });
    });

    group('Connection Monitoring', () {
      test('should report connection status', () {
        // Act
        final isConnected = watchingModule.isConnected;

        // Assert
        expect(isConnected, isTrue);
      });

      test('should stream connection status changes', () async {
        // Arrange
        final connectionController = StreamController<bool>();
        when(() => mockRealtimeSyncService.connectionStream)
            .thenAnswer((_) => connectionController.stream);

        // Act
        final stream = watchingModule.connectionStream;
        connectionController.add(true);
        connectionController.add(false);

        // Assert
        await expectLater(
          stream.take(2),
          emitsInOrder([true, false]),
        );

        // Cleanup
        await connectionController.close();
      });

      test('should wait for connection with timeout', () async {
        // Arrange
        final connectionController = StreamController<bool>();
        when(() => mockRealtimeSyncService.connectionStream)
            .thenAnswer((_) => connectionController.stream);
        mockRealtimeSyncService.setConnectionState(false);

        // Act
        final future = watchingModule.waitForConnection(
          timeout: Duration(milliseconds: 100),
        );

        // Simulate connection after delay
        Future.delayed(Duration(milliseconds: 50), () {
          connectionController.add(true);
        });

        // Assert
        final result = await future;
        expect(result, isTrue);

        // Cleanup
        await connectionController.close();
      });

      test('should timeout when waiting for connection', () async {
        // Arrange
        when(() => mockRealtimeSyncService.connectionStream)
            .thenAnswer((_) => Stream.value(false));
        mockRealtimeSyncService.setConnectionState(false);

        // Act
        final result = await watchingModule.waitForConnection(
          timeout: Duration(milliseconds: 100),
        );

        // Assert
        expect(result, isFalse);
      });

      test('should monitor connection status with metadata', () async {
        // Arrange
        final connectionController = StreamController<bool>();
        when(() => mockRealtimeSyncService.connectionStream)
            .thenAnswer((_) => connectionController.stream);

        // Act
        final stream = watchingModule.monitorConnectionStatus();
        connectionController.add(true);

        // Assert
        final status = await stream.first;
        expect(status.isConnected, isTrue);
        expect(status.hasRealtimeService, isTrue);
        expect(status.timestamp, isA<DateTime>());

        // Cleanup
        await connectionController.close();
      });
    });

    // BUT-1112: the module re-exposes the underlying RealtimeSyncService
    // error side-channel so callers (e.g. a global error banner) can listen
    // for sync failures without reaching through to the sync service.
    group('Error side-channel (BUT-1112)', () {
      test('errorStream forwards SyncErrors from the injected sync service',
          () async {
        // Intent: a SyncError emitted by the underlying service must reach a
        // subscriber of the module's errorStream. Fails if the getter stops
        // forwarding or returns a different (empty/own) stream.
        final errorFuture = watchingModule.errorStream.first;

        final syncError = rt.SyncError(
          type: rt.SyncErrorType.firestoreError,
          message: 'boom',
          resourceId: 'recipe_1',
        );
        mockRealtimeSyncService.setError(syncError);

        final received = await errorFuture;
        expect(received.type, equals(rt.SyncErrorType.firestoreError));
        expect(received.resourceId, equals('recipe_1'));
      });

      test(
          'errorStream is an inert empty stream in polling-fallback mode '
          '(no sync service injected)', () async {
        // Intent: when constructed without a RealtimeSyncService the module
        // runs in polling mode where there is no sync error source. A
        // subscriber must complete (onDone) without an error and without
        // hanging — not throw an NPE on the null service. Fails if the
        // null-coalescing fallback is removed.
        final pollingModule = RealtimeWatchingModule(
          getRecipes: () => mockParentService.recipes,
          // no realtimeSyncService
        );

        var emittedAny = false;
        await pollingModule.errorStream.forEach((_) => emittedAny = true);

        expect(emittedAny, isFalse);
      });
    });

    group('Watch Management', () {
      test('should start watching recipe with callback', () async {
        // Arrange
        when(() => mockRealtimeSyncService.watchResource<RealtimeRecipe>(
            'recipe_1')).thenAnswer((_) => Stream.value(testRealtimeRecipe));

        Recipe? receivedRecipe;

        // Act
        final subscription = watchingModule.startWatchingRecipe(
          'recipe_1',
          (recipe) => receivedRecipe = recipe,
        );

        await Future.delayed(Duration(milliseconds: 10));

        // Assert
        expect(receivedRecipe, isNotNull);
        expect(receivedRecipe!.id, equals('recipe_1'));

        // Cleanup
        await subscription.cancel();
      });

      test('should handle errors in watch callback', () async {
        // Arrange
        when(() => mockRealtimeSyncService
                .watchResource<RealtimeRecipe>('recipe_1'))
            .thenAnswer((_) => Stream.error(Exception('Watch error')));

        dynamic capturedError;

        // Act
        final subscription = watchingModule.startWatchingRecipe(
          'recipe_1',
          (_) {},
          onError: (error) => capturedError = error,
        );

        await Future.delayed(Duration(milliseconds: 10));

        // Assert
        expect(capturedError, isNotNull);

        // Cleanup
        await subscription.cancel();
      });
    });

    group('Utility Methods', () {
      test('should check if watching is available', () {
        // Act
        final isAvailable = watchingModule.isWatchingAvailable();

        // Assert
        expect(isAvailable, isTrue);
      });

      test('should report watching capabilities', () {
        // Act
        final capabilities = watchingModule.getWatchingCapabilities();

        // Assert
        expect(capabilities['hasRealtimeService'], isTrue);
        expect(capabilities['isConnected'], isTrue);
        expect(capabilities['canWatchSingle'], isTrue);
        expect(capabilities['canWatchMultiple'], isTrue);
        expect(capabilities['hasRetry'], isTrue);
        expect(capabilities['hasConnectionMonitoring'], isTrue);
      });

      test('should report limited capabilities without realtime service', () {
        // Arrange
        watchingModule = RealtimeWatchingModule(
          getRecipes: () => mockParentService.recipes,
        );

        // Act
        final capabilities = watchingModule.getWatchingCapabilities();

        // Assert
        expect(capabilities['hasRealtimeService'], isFalse);
        expect(capabilities['canWatchSingle'],
            isTrue); // Still available with polling
        expect(capabilities['canWatchMultiple'],
            isTrue); // Still available with polling
      });
    });
  });
}

// Using centralized mocks from production_mocks.dart:
// MockUnifiedRecipeService, MockRealtimeSyncService
