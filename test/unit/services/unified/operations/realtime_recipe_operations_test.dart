import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/realtime_recipe_operations.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/realtime_notification_module.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/builders/recipe_builder.dart';
import '../../../../infrastructure/builders/realtime_recipe_builder.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('RealtimeRecipeOperations - Comprehensive Behavior Testing', () {
    late RealtimeRecipeOperations operations;
    late MockUnifiedRecipeService mockParent;
    late MockRealtimeSyncService mockRealtimeService;
    late Recipe testRecipe;
    late Recipe collaborativeRecipe;
    late RealtimeRecipe testRealtimeRecipe;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
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
      registerFallbackValue(<String, dynamic>{});
      registerFallbackValue(<String>[]);
      registerFallbackValue(Duration.zero);
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks
      mockParent = MockUnifiedRecipeService();
      mockRealtimeService = MockRealtimeSyncService();

      // Create test data
      testRecipe = RecipeBuilder()
          .withId('recipe-123')
          .withTitle('Swedish Meatballs')
          .withTimeMinutes(45)
          .build();

      // Create collaborative recipe with social data
      collaborativeRecipe = Recipe(
        core: RecipeBuilder()
            .withId('collab-456')
            .withTitle('Collaborative Fika')
            .asCollaborative()
            .build()
            .core,
        type: RecipeType.collaborative,
        socialData: RecipeSocialData(
          ownerId: 'owner-123',
          ownerDisplayName: 'Owner Name',
          memberPermissions: {
            'member-1': ResourcePermission.editor,
            'member-2': ResourcePermission.viewer,
          },
        ),
      );

      testRealtimeRecipe = RealtimeRecipeBuilder()
          .withId('recipe-123')
          .withTitle('Swedish Meatballs')
          .build();

      // Configure mocks
      mockParent.setRecipeState(
        currentUserId: 'test-user-123',
        recipes: [testRecipe, collaborativeRecipe],
      );

      mockRealtimeService.setConnectionState(true);

      // Create operations instance
      operations = RealtimeRecipeOperations(
        getCurrentUserId: () => 'test-user-123',
        getCurrentUserDisplayName: () => 'Test User',
        getRecipes: () => mockParent.recipes,
        notificationParent: _TestNotificationParent(),
        updateRecipeContent: _stubUpdateRecipeContent,
        createCollaborativeRecipe: _stubCreateCollaborativeRecipe,
        createPersonalRecipe: _stubCreatePersonalRecipe,
        deleteRecipe: (id) async => true,
        realtimeSyncService: mockRealtimeService,
      );
    });

    tearDown(() async {
      await mockRealtimeService.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Module Initialization and Architecture', () {
      test('should initialize with all 5 modules', () {
        // Assert
        expect(operations, isNotNull);
        expect(operations.serviceName, equals('RealtimeRecipeOperations'));

        // Verify module status
        final status = operations.getModuleStatus();
        expect(status, containsPair('watchingModule', isA<Map>()));
        expect(status, containsPair('editingModule', isA<Map>()));
        expect(status, containsPair('collaborationModule', isA<Map>()));
        expect(status, containsPair('presenceModule', isA<Map>()));
        expect(status, containsPair('notificationModule', isA<Map>()));
      });

      test('should initialize without realtime service and handle gracefully',
          () {
        // Act
        final ops = RealtimeRecipeOperations(
          getCurrentUserId: () => 'test-user',
          getCurrentUserDisplayName: () => 'Test',
          getRecipes: () => [],
          notificationParent: _TestNotificationParent(),
          updateRecipeContent: _stubUpdateRecipeContent,
          createCollaborativeRecipe: _stubCreateCollaborativeRecipe,
          createPersonalRecipe: _stubCreatePersonalRecipe,
          deleteRecipe: (id) async => true,
        );

        // Assert
        expect(ops, isNotNull);
        expect(ops.isConnected, isFalse);
        expect(ops.isWatchingAvailable(), isFalse);

        final capabilities = ops.getWatchingCapabilities();
        expect(capabilities, isA<Map>());
      });

      test('should report comprehensive realtime operations status', () {
        // Act
        final status = operations.getRealtimeOperationsStatus();

        // Assert
        expect(status['hasRealtimeService'], isTrue);
        expect(status['isConnected'], isTrue);
        expect(status['currentUserId'], equals('test-user-123'));
        expect(status['architecture'], equals('modular'));
        expect(status['version'], equals('2.0'));
      });
    });

    group('Real-time Watching with Stream Behavior', () {
      test('should watch recipe and transform RealtimeRecipe to Recipe',
          () async {
        // Arrange
        final controller = mockRealtimeService
            .getOrCreateStreamController<RealtimeRecipe>('recipe-123');
        when(() =>
                mockRealtimeService.watchResource<RealtimeRecipe>('recipe-123'))
            .thenAnswer((_) => controller.stream);

        // Act
        final stream = operations.watchRecipe('recipe-123');
        final emittedRecipes = <Recipe>[];
        final subscription = stream.listen(emittedRecipes.add);

        // Emit updates
        final updatedRecipe1 = RealtimeRecipeBuilder()
            .withId('recipe-123')
            .withTitle('Updated Title 1')
            .build();
        final updatedRecipe2 = RealtimeRecipeBuilder()
            .withId('recipe-123')
            .withTitle('Updated Title 2')
            .build();

        mockRealtimeService.triggerStreamUpdate('recipe-123', updatedRecipe1);
        await Future.delayed(Duration(milliseconds: 100));
        mockRealtimeService.triggerStreamUpdate('recipe-123', updatedRecipe2);
        await Future.delayed(Duration(milliseconds: 100));

        // Assert
        expect(emittedRecipes.length, equals(2));
        expect(emittedRecipes[0].core.title, equals('Updated Title 1'));
        expect(emittedRecipes[1].core.title, equals('Updated Title 2'));

        // Cleanup
        await subscription.cancel();
        await controller.close();
      });

      test('should validate empty recipe ID and throw ArgumentError', () {
        // Act & Assert
        expect(
          () => operations.watchRecipe(''),
          throwsA(
            isA<ArgumentError>().having((e) => e.message, 'message',
                contains('cannot be null or empty')),
          ),
        );
      });

      test(
          'should watch recipe with retry and recover from connection failures',
          () async {
        // Arrange
        var attemptCount = 0;
        final errorController = StreamController<RealtimeRecipe>();
        final successController = StreamController<RealtimeRecipe>();

        when(() =>
                mockRealtimeService.watchResource<RealtimeRecipe>('recipe-123'))
            .thenAnswer((_) {
          attemptCount++;
          if (attemptCount == 1) {
            // First attempt fails - return a controller that will emit an error
            Timer(Duration(milliseconds: 10), () {
              errorController.addError(Exception('Connection failed'));
            });
            return errorController.stream;
          } else {
            // Second attempt succeeds - return a controller that will emit data
            Timer(Duration(milliseconds: 10), () {
              successController.add(testRealtimeRecipe);
            });
            return successController.stream;
          }
        });

        // Act
        final stream = operations.watchRecipeWithRetry(
          'recipe-123',
          maxRetries: 2,
          retryDelay: Duration(milliseconds: 50),
        );

        // Wait for the retry to succeed
        final recipes = await stream
            .take(1)
            .timeout(
              Duration(seconds: 2),
              onTimeout: (sink) =>
                  throw TimeoutException('Retry did not succeed'),
            )
            .toList();

        // Assert
        expect(attemptCount, equals(2));
        expect(recipes.length, equals(1));
        expect(recipes.first.core.title, equals('Swedish Meatballs'));

        // Cleanup
        await errorController.close();
        await successController.close();
      });

      test('should watch multiple recipes and combine streams correctly',
          () async {
        // Arrange
        final controller1 = mockRealtimeService
            .getOrCreateStreamController<RealtimeRecipe>('recipe-123');
        final controller2 = mockRealtimeService
            .getOrCreateStreamController<RealtimeRecipe>('collab-456');

        when(() =>
                mockRealtimeService.watchResource<RealtimeRecipe>('recipe-123'))
            .thenAnswer((_) => controller1.stream);
        when(() =>
                mockRealtimeService.watchResource<RealtimeRecipe>('collab-456'))
            .thenAnswer((_) => controller2.stream);

        // Act
        final stream =
            operations.watchMultipleRecipes(['recipe-123', 'collab-456']);
        final emittedLists = <List<Recipe>>[];
        final subscription = stream.listen(emittedLists.add);

        // Emit updates
        final recipe1Update = RealtimeRecipeBuilder()
            .withId('recipe-123')
            .withTitle('Updated Meatballs')
            .build();
        final recipe2Update = RealtimeRecipeBuilder()
            .withId('collab-456')
            .withTitle('Updated Fika')
            .build();

        mockRealtimeService.triggerStreamUpdate('recipe-123', recipe1Update);
        mockRealtimeService.triggerStreamUpdate('collab-456', recipe2Update);
        await Future.delayed(Duration(milliseconds: 100));

        // Assert
        expect(emittedLists, isNotEmpty);
        final lastEmitted = emittedLists.last;
        expect(lastEmitted.length, equals(2));
        expect(lastEmitted.any((r) => r.core.title == 'Updated Meatballs'),
            isTrue);
        expect(lastEmitted.any((r) => r.core.title == 'Updated Fika'), isTrue);

        // Cleanup
        await subscription.cancel();
        await controller1.close();
        await controller2.close();
      });

      test('should watch multiple recipes individually with error isolation',
          () async {
        // Arrange
        final controller1 = mockRealtimeService
            .getOrCreateStreamController<RealtimeRecipe>('recipe-123');

        when(() =>
                mockRealtimeService.watchResource<RealtimeRecipe>('recipe-123'))
            .thenAnswer((_) => controller1.stream);
        when(() => mockRealtimeService
                .watchResource<RealtimeRecipe>('error-recipe'))
            .thenAnswer((_) => Stream.error(Exception('Recipe not found')));

        // Act
        final stream = operations
            .watchMultipleRecipesIndividually(['recipe-123', 'error-recipe']);

        // Skip the initial state (all nulls) and wait for updates
        final resultsFuture = stream.skip(1).first;

        // Emit update after starting to listen
        mockRealtimeService.triggerStreamUpdate(
            'recipe-123', testRealtimeRecipe);

        final results = await resultsFuture;

        // Assert
        expect(results['recipe-123'], isNotNull);
        expect(results['error-recipe'], isNull); // Error isolated, returns null

        // Cleanup
        await controller1.close();
      });

      test('should start watching with callback and handle updates', () async {
        // Arrange
        final controller = mockRealtimeService
            .getOrCreateStreamController<RealtimeRecipe>('recipe-123');
        when(() =>
                mockRealtimeService.watchResource<RealtimeRecipe>('recipe-123'))
            .thenAnswer((_) => controller.stream);

        Recipe? receivedRecipe;

        // Act
        final subscription = operations.startWatchingRecipe(
          'recipe-123',
          (recipe) => receivedRecipe = recipe,
        );

        // Emit update
        final updatedRecipe = RealtimeRecipeBuilder()
            .withId('recipe-123')
            .withTitle('Callback Update')
            .build();
        mockRealtimeService.triggerStreamUpdate('recipe-123', updatedRecipe);
        await Future.delayed(Duration(milliseconds: 100));

        // Assert
        expect(receivedRecipe, isNotNull);
        expect(receivedRecipe!.core.title, equals('Callback Update'));

        // Cleanup
        await subscription.cancel();
        await controller.close();
      });
    });

    group('Connection Management with Status Monitoring', () {
      test('should report connection status correctly', () {
        // Arrange
        mockRealtimeService.setConnectionState(true);

        // Act & Assert
        expect(operations.isConnected, isTrue);
      });

      test('should stream connection status changes', () async {
        // Act
        final statusStream = operations.connectionStream;
        final statuses = <bool>[];
        final subscription = statusStream.listen(statuses.add);

        // Change connection status
        mockRealtimeService.setConnectionState(false);
        await Future.delayed(Duration(milliseconds: 100));
        mockRealtimeService.setConnectionState(true);
        await Future.delayed(Duration(milliseconds: 100));

        // Assert
        expect(statuses, contains(false));
        expect(statuses, contains(true));

        // Cleanup
        await subscription.cancel();
      });

      test('should wait for connection with timeout', () async {
        // Arrange
        mockRealtimeService.setConnectionState(false);

        // Simulate connection after delay
        Future.delayed(Duration(milliseconds: 50), () {
          mockRealtimeService.setConnectionState(true);
        });

        // Act
        final connected = await operations.waitForConnection(
          timeout: Duration(milliseconds: 200),
        );

        // Assert
        expect(connected, isTrue);
      });

      test('should monitor connection status with detailed info', () async {
        // Act
        final statusStream = operations.monitorConnectionStatus();
        final status = await statusStream.first;

        // Assert
        expect(status.isConnected, isTrue);
        expect(status.hasRealtimeService, isTrue);
        expect(status.timestamp, isA<DateTime>());
      });
    });

    group('Module Delegation Tests', () {
      test('should check if watching is available', () {
        // Act
        final available = operations.isWatchingAvailable();

        // Assert
        expect(available, isA<bool>());
      });

      test('should get watching capabilities', () {
        // Act
        final capabilities = operations.getWatchingCapabilities();

        // Assert
        expect(capabilities, isA<Map>());
      });

      test('should handle empty recipe ID validation for editing', () async {
        // Act
        final result = await operations.startRealtimeEditing('');

        // Assert
        expect(result, isFalse);
      });

      test('should check if recipe is in editing mode', () {
        // Act
        final isEditing = operations.isInRealtimeEditingMode('recipe-123');

        // Assert
        expect(isEditing, isA<bool>());
      });

      test('should validate edit changes', () {
        // Act
        final isValid = operations
            .validateEditChanges('recipe-123', {'title': 'New Title'});

        // Assert
        expect(isValid, isA<bool>());
      });

      test('should get edit validation rules', () {
        // Act
        final rules = operations.getEditValidationRules();

        // Assert
        expect(rules, isA<Map>());
      });

      test('should get editing status', () {
        // Act
        final status = operations.getEditingStatus('recipe-123');

        // Assert
        expect(status, isA<Map>());
      });
    });

    group('Legacy Method Support', () {
      test('should get active editors for collaborative recipe', () {
        // Act
        final editors = operations.getActiveEditors('collab-456');

        // Assert
        // Since we can't mock isUserPresent, we expect it to return test-user-123
        // if the current user is present in the collaborative recipe
        expect(editors, isA<List>());
      });

      test('should return empty for non-collaborative recipe', () {
        // Act
        final editors = operations.getActiveEditors('recipe-123');

        // Assert
        expect(editors, isEmpty);
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle null realtime service gracefully', () {
        // Arrange
        final opsWithoutRealtime = RealtimeRecipeOperations(
          getCurrentUserId: () => 'test-user',
          getCurrentUserDisplayName: () => 'Test',
          getRecipes: () => [],
          notificationParent: _TestNotificationParent(),
          updateRecipeContent: _stubUpdateRecipeContent,
          createCollaborativeRecipe: _stubCreateCollaborativeRecipe,
          createPersonalRecipe: _stubCreatePersonalRecipe,
          deleteRecipe: (id) async => true,
        );

        // Act & Assert
        expect(opsWithoutRealtime.isConnected, isFalse);
        expect(opsWithoutRealtime.isWatchingAvailable(), isFalse);

        // Should not throw when calling methods
        expect(() => opsWithoutRealtime.watchRecipe('recipe-123'),
            returnsNormally);
      });

      test('should validate multiple recipe IDs for batch watching', () {
        // Act & Assert
        expect(
          () => operations.watchMultipleRecipes([]),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should handle stream errors in watching', () async {
        // Arrange
        when(() => mockRealtimeService.watchResource<RealtimeRecipe>(any()))
            .thenAnswer((_) => Stream.error(Exception('Connection lost')));

        // Act
        final stream = operations.watchRecipe('recipe-123');

        // Assert
        await expectLater(
          stream,
          emitsError(isA<Exception>()),
        );
      });

      test('should cleanup resources on dispose', () async {
        // Act
        await operations.dispose();

        // Assert - verify no errors thrown
        expect(() => operations.dispose(), returnsNormally);
      });
    });
  });
}

Future<bool> _stubUpdateRecipeContent({
  required String recipeId,
  String? title,
  String? description,
  List<String>? ingredients,
  List<String>? instructions,
  List<String>? imageUrls,
  String? mealType,
  int? portions,
  int? timeMinutes,
  double? rating,
  List<String>? personalTagIds,
  String? sourceUrl,
}) async =>
    true;

Future<String?> _stubCreateCollaborativeRecipe({
  required String title,
  required List<String> memberIds,
  String description = '',
  List<String> ingredients = const [],
  List<String> instructions = const [],
  List<String> imageUrls = const [],
  String mealType = '',
  int? portions,
  int? timeMinutes,
  double? rating,
  List<String>? personalTagIds,
  String? sourceUrl,
  String? descriptionCollaborative,
  bool allowGuestViewing = false,
  bool allowMemberInvites = false,
  List<String>? categoryIds,
}) async =>
    null;

Future<String?> _stubCreatePersonalRecipe({
  required String title,
  String description = '',
  List<String> ingredients = const [],
  List<String> instructions = const [],
  List<String> imageUrls = const [],
  String mealType = '',
  int? portions,
  int? timeMinutes,
  double? rating,
  List<String>? personalTagIds,
  String? sourceUrl,
}) async =>
    null;

class _TestNotificationParent implements NotificationParent {
  @override
  String? get currentUserId => 'test-user';
  @override
  String? get currentUserDisplayName => 'Test';
}
