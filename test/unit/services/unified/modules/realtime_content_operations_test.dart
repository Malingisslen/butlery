/// Unit tests for RealtimeContentOperations - Handles real-time content editing operations
///
/// Tests real-time operations including:
/// - Core real-time edit operations
/// - Basic field updates (title, description, portions, time)
/// - Ingredient operations (add, update, remove, reorder)
/// - Instruction operations (add, update, remove, reorder)
/// - Batch operations
/// - Validation helpers
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Production imports
import 'package:butlery/services/unified/modules/realtime_content_operations.dart';

// Test infrastructure
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('RealtimeContentOperations', () {
    late Map<String, StreamSubscription<DocumentSnapshot>>
    activeEditingSessions;
    late Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits;
    late String? lastError;
    late int conflictResolutionCallCount;
    late Map<String, dynamic>? lastAppliedEdit;

    setUpAll(() async {
      // Initialize test infrastructure once for all tests
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      // Initialize service locator for each test
      await TestServiceLocator.initialize();

      // Reset test state
      activeEditingSessions = {};
      pendingRealtimeEdits = {};
      lastError = null;
      conflictResolutionCallCount = 0;
      lastAppliedEdit = null;
    });

    tearDown(() async {
      // Reset mocks and service locator after each test
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      // Final cleanup after all tests
      await BaseUnitTest.teardownUnit();
    });

    // Helper functions
    void setError(String error) {
      lastError = error;
    }

    Future<void> applyEditWithConflictResolution(
      String recipeId,
      Map<String, dynamic> edit,
    ) async {
      conflictResolutionCallCount++;
      lastAppliedEdit = edit;
    }

    StreamSubscription<DocumentSnapshot> createMockSubscription() {
      // Create a mock stream subscription without creating actual DocumentSnapshot
      final controller = StreamController<DocumentSnapshot>();
      final subscription = controller.stream.listen((_) {});
      controller.close(); // Close immediately to avoid leaks
      return subscription;
    }

    RealtimeEditContext createTestContext({
      required String currentUserId,
      String? currentUserDisplayName,
    }) {
      return RealtimeEditContext(
        currentUserId: currentUserId,
        currentUserDisplayName: currentUserDisplayName,
        activeEditingSessions: activeEditingSessions,
        pendingRealtimeEdits: pendingRealtimeEdits,
        applyEditWithConflictResolution: applyEditWithConflictResolution,
        setError: setError,
      );
    }

    group('Core Real-time Edit Operation', () {
      test('should make real-time edit successfully', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const currentUserId = 'user-123';
        const currentUserDisplayName = 'Test User';
        final changes = {'title': 'New Title'};

        // Add active session
        activeEditingSessions[recipeId] = createMockSubscription();

        // Act
        final result = await RealtimeContentOperations.makeRealtimeEdit(
          context: createTestContext(
            currentUserId: currentUserId,
            currentUserDisplayName: currentUserDisplayName,
          ),
          recipeId: recipeId,
          changes: changes,
        );

        // Assert
        expect(result, isTrue);
        expect(conflictResolutionCallCount, equals(1));
        expect(pendingRealtimeEdits[recipeId], isNotEmpty);
        expect(lastAppliedEdit?['editedBy'], equals(currentUserId));
        expect(
          lastAppliedEdit?['editedByDisplayName'],
          equals(currentUserDisplayName),
        );
        expect(lastAppliedEdit?['title'], equals('New Title'));
      });

      test('should fail when not in editing mode', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const currentUserId = 'user-123';
        final changes = {'title': 'New Title'};

        // No active session

        // Act
        final result = await RealtimeContentOperations.makeRealtimeEdit(
          context: createTestContext(
            currentUserId: currentUserId,
            currentUserDisplayName: null,
          ),
          recipeId: recipeId,
          changes: changes,
        );

        // Assert
        expect(result, isFalse);
        expect(lastError, contains('Inte i realtidsredigeringsläge'));
        expect(conflictResolutionCallCount, equals(0));
      });

      test('should handle conflict resolution errors', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const currentUserId = 'user-123';
        final changes = {'title': 'New Title'};

        activeEditingSessions[recipeId] = createMockSubscription();

        // Make conflict resolution throw error
        Future<void> failingConflictResolution(
          String id,
          Map<String, dynamic> edit,
        ) async {
          throw Exception('Conflict resolution failed');
        }

        // Create custom context with failing conflict resolution
        final customContext = RealtimeEditContext(
          currentUserId: currentUserId,
          currentUserDisplayName: null,
          activeEditingSessions: activeEditingSessions,
          pendingRealtimeEdits: pendingRealtimeEdits,
          applyEditWithConflictResolution: failingConflictResolution,
          setError: setError,
        );

        // Act
        final result = await RealtimeContentOperations.makeRealtimeEdit(
          context: customContext,
          recipeId: recipeId,
          changes: changes,
        );

        // Assert
        expect(result, isFalse);
        expect(lastError, contains('Kunde inte genomföra realtidsändring'));
      });
    });

    group('Basic Field Updates', () {
      setUp(() {
        // Add active session for all field update tests
        activeEditingSessions['recipe-1'] = createMockSubscription();
      });

      test('should update title in real-time', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const newTitle = 'Updated Title';
        const currentUserId = 'user-123';

        // Act
        final result = await RealtimeContentOperations.updateTitleRealtime(
          context: createTestContext(
            currentUserId: currentUserId,
            currentUserDisplayName: 'Test User',
          ),
          recipeId: recipeId,
          newTitle: newTitle,
        );

        // Assert
        expect(result, isTrue);
        expect(lastAppliedEdit?['title'], equals(newTitle));
        expect(lastAppliedEdit?['field'], equals('title'));
      });

      test('should reject empty title', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const newTitle = '   '; // Empty after trim
        const currentUserId = 'user-123';

        // Act
        final result = await RealtimeContentOperations.updateTitleRealtime(
          context: createTestContext(
            currentUserId: currentUserId,
            currentUserDisplayName: null,
          ),
          recipeId: recipeId,
          newTitle: newTitle,
        );

        // Assert
        expect(result, isFalse);
        expect(lastError, contains('Titel kan inte vara tom'));
      });

      test('should update description in real-time', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const newDescription = 'Updated description';
        const currentUserId = 'user-123';

        // Act
        final result =
            await RealtimeContentOperations.updateDescriptionRealtime(
              context: createTestContext(
                currentUserId: currentUserId,
                currentUserDisplayName: null,
              ),
              recipeId: recipeId,
              newDescription: newDescription,
            );

        // Assert
        expect(result, isTrue);
        expect(lastAppliedEdit?['description'], equals(newDescription));
        expect(lastAppliedEdit?['field'], equals('description'));
      });

      test('should update portions in real-time', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const newPortions = 6;
        const currentUserId = 'user-123';

        // Act
        final result = await RealtimeContentOperations.updatePortionsRealtime(
          context: createTestContext(
            currentUserId: currentUserId,
            currentUserDisplayName: null,
          ),
          recipeId: recipeId,
          newPortions: newPortions,
        );

        // Assert
        expect(result, isTrue);
        expect(lastAppliedEdit?['portions'], equals(newPortions));
        expect(lastAppliedEdit?['field'], equals('portions'));
      });

      test('should reject invalid portions', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const newPortions = 0; // Invalid
        const currentUserId = 'user-123';

        // Act
        final result = await RealtimeContentOperations.updatePortionsRealtime(
          context: createTestContext(
            currentUserId: currentUserId,
            currentUserDisplayName: null,
          ),
          recipeId: recipeId,
          newPortions: newPortions,
        );

        // Assert
        expect(result, isFalse);
        expect(lastError, contains('Portioner måste vara större än 0'));
      });

      test('should update time in real-time', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const newTimeMinutes = 45;
        const currentUserId = 'user-123';

        // Act
        final result = await RealtimeContentOperations.updateTimeRealtime(
          context: createTestContext(
            currentUserId: currentUserId,
            currentUserDisplayName: null,
          ),
          recipeId: recipeId,
          newTimeMinutes: newTimeMinutes,
        );

        // Assert
        expect(result, isTrue);
        expect(lastAppliedEdit?['timeMinutes'], equals(newTimeMinutes));
        expect(lastAppliedEdit?['field'], equals('timeMinutes'));
      });

      test('should reject invalid time', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const newTimeMinutes = -10; // Invalid
        const currentUserId = 'user-123';

        // Act
        final result = await RealtimeContentOperations.updateTimeRealtime(
          context: createTestContext(
            currentUserId: currentUserId,
            currentUserDisplayName: null,
          ),
          recipeId: recipeId,
          newTimeMinutes: newTimeMinutes,
        );

        // Assert
        expect(result, isFalse);
        expect(lastError, contains('Tid måste vara större än 0 minuter'));
      });
    });

    group('Ingredient Operations', () {
      setUp(() {
        activeEditingSessions['recipe-1'] = createMockSubscription();
      });

      test('should add ingredient in real-time', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const ingredient = '2 cups flour';
        const currentUserId = 'user-123';

        // Act
        final result = await RealtimeContentOperations.addIngredientRealtime(
          context: createTestContext(
            currentUserId: currentUserId,
            currentUserDisplayName: null,
          ),
          recipeId: recipeId,
          ingredient: ingredient,
          index: null,
        );

        // Assert
        expect(result, isTrue);
        expect(lastAppliedEdit?['operation'], equals('add_ingredient'));
        expect(lastAppliedEdit?['ingredient'], equals(ingredient));
        expect(lastAppliedEdit?['field'], equals('ingredients'));
      });

      test('should reject empty ingredient', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const ingredient = '  '; // Empty after trim
        const currentUserId = 'user-123';

        // Act
        final result = await RealtimeContentOperations.addIngredientRealtime(
          context: createTestContext(
            currentUserId: currentUserId,
            currentUserDisplayName: null,
          ),
          recipeId: recipeId,
          ingredient: ingredient,
          index: null,
        );

        // Assert
        expect(result, isFalse);
        expect(lastError, contains('Ingrediens kan inte vara tom'));
      });

      test('should update ingredient in real-time', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const index = 2;
        const newIngredient = '3 cups flour';
        const currentUserId = 'user-123';

        // Act
        final result = await RealtimeContentOperations.updateIngredientRealtime(
          context: createTestContext(
            currentUserId: currentUserId,
            currentUserDisplayName: null,
          ),
          recipeId: recipeId,
          index: index,
          newIngredient: newIngredient,
        );

        // Assert
        expect(result, isTrue);
        expect(lastAppliedEdit?['operation'], equals('update_ingredient'));
        expect(lastAppliedEdit?['index'], equals(index));
        expect(lastAppliedEdit?['ingredient'], equals(newIngredient));
      });

      test('should reject invalid index for update', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const index = -1; // Invalid
        const newIngredient = '3 cups flour';
        const currentUserId = 'user-123';

        // Act
        final result = await RealtimeContentOperations.updateIngredientRealtime(
          context: createTestContext(
            currentUserId: currentUserId,
            currentUserDisplayName: null,
          ),
          recipeId: recipeId,
          index: index,
          newIngredient: newIngredient,
        );

        // Assert
        expect(result, isFalse);
        expect(lastError, contains('Ogiltigt ingrediens-index'));
      });

      test('should remove ingredient in real-time', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const index = 1;
        const currentUserId = 'user-123';

        // Act
        final result = await RealtimeContentOperations.removeIngredientRealtime(
          context: createTestContext(
            currentUserId: currentUserId,
            currentUserDisplayName: null,
          ),
          recipeId: recipeId,
          index: index,
        );

        // Assert
        expect(result, isTrue);
        expect(lastAppliedEdit?['operation'], equals('remove_ingredient'));
        expect(lastAppliedEdit?['index'], equals(index));
      });

      test('should reorder ingredients in real-time', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const fromIndex = 1;
        const toIndex = 3;
        const currentUserId = 'user-123';

        // Act
        final result =
            await RealtimeContentOperations.reorderIngredientsRealtime(
              context: createTestContext(
                currentUserId: currentUserId,
                currentUserDisplayName: null,
              ),
              recipeId: recipeId,
              fromIndex: fromIndex,
              toIndex: toIndex,
            );

        // Assert
        expect(result, isTrue);
        expect(lastAppliedEdit?['operation'], equals('reorder_ingredient'));
        expect(lastAppliedEdit?['fromIndex'], equals(fromIndex));
        expect(lastAppliedEdit?['toIndex'], equals(toIndex));
      });

      test('should handle same index reordering', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const fromIndex = 2;
        const toIndex = 2; // Same as from
        const currentUserId = 'user-123';

        // Act
        final result =
            await RealtimeContentOperations.reorderIngredientsRealtime(
              context: createTestContext(
                currentUserId: currentUserId,
                currentUserDisplayName: null,
              ),
              recipeId: recipeId,
              fromIndex: fromIndex,
              toIndex: toIndex,
            );

        // Assert
        expect(result, isTrue); // No change needed
        expect(
          conflictResolutionCallCount,
          equals(0),
        ); // Should not call conflict resolution
      });
    });

    group('Instruction Operations', () {
      setUp(() {
        activeEditingSessions['recipe-1'] = createMockSubscription();
      });

      test('should add instruction in real-time', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const instruction = 'Preheat oven to 350°F';
        const currentUserId = 'user-123';

        // Act
        final result = await RealtimeContentOperations.addInstructionRealtime(
          context: createTestContext(
            currentUserId: currentUserId,
            currentUserDisplayName: null,
          ),
          recipeId: recipeId,
          instruction: instruction,
          index: 0,
        );

        // Assert
        expect(result, isTrue);
        expect(lastAppliedEdit?['operation'], equals('add_instruction'));
        expect(lastAppliedEdit?['instruction'], equals(instruction));
        expect(lastAppliedEdit?['index'], equals(0));
        expect(lastAppliedEdit?['field'], equals('instructions'));
      });

      test('should update instruction in real-time', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const index = 1;
        const newInstruction = 'Mix ingredients thoroughly';
        const currentUserId = 'user-123';

        // Act
        final result =
            await RealtimeContentOperations.updateInstructionRealtime(
              context: createTestContext(
                currentUserId: currentUserId,
                currentUserDisplayName: null,
              ),
              recipeId: recipeId,
              index: index,
              newInstruction: newInstruction,
            );

        // Assert
        expect(result, isTrue);
        expect(lastAppliedEdit?['operation'], equals('update_instruction'));
        expect(lastAppliedEdit?['index'], equals(index));
        expect(lastAppliedEdit?['instruction'], equals(newInstruction));
      });

      test('should remove instruction in real-time', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const index = 2;
        const currentUserId = 'user-123';

        // Act
        final result =
            await RealtimeContentOperations.removeInstructionRealtime(
              context: createTestContext(
                currentUserId: currentUserId,
                currentUserDisplayName: null,
              ),
              recipeId: recipeId,
              index: index,
            );

        // Assert
        expect(result, isTrue);
        expect(lastAppliedEdit?['operation'], equals('remove_instruction'));
        expect(lastAppliedEdit?['index'], equals(index));
      });

      test('should reorder instructions in real-time', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const fromIndex = 0;
        const toIndex = 2;
        const currentUserId = 'user-123';

        // Act
        final result =
            await RealtimeContentOperations.reorderInstructionsRealtime(
              context: createTestContext(
                currentUserId: currentUserId,
                currentUserDisplayName: null,
              ),
              recipeId: recipeId,
              fromIndex: fromIndex,
              toIndex: toIndex,
            );

        // Assert
        expect(result, isTrue);
        expect(lastAppliedEdit?['operation'], equals('reorder_instruction'));
        expect(lastAppliedEdit?['fromIndex'], equals(fromIndex));
        expect(lastAppliedEdit?['toIndex'], equals(toIndex));
      });
    });

    group('Batch Operations', () {
      test('should apply batch edits', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const currentUserId = 'user-123';
        final edits = [
          {'field': 'title', 'value': 'New Title'},
          {'field': 'description', 'value': 'New Description'},
          {'operation': 'add_ingredient', 'ingredient': 'Salt'},
        ];

        activeEditingSessions[recipeId] = createMockSubscription();

        // Act
        final result = await RealtimeContentOperations.applyBatchEdits(
          context: createTestContext(
            currentUserId: currentUserId,
            currentUserDisplayName: 'Test User',
          ),
          recipeId: recipeId,
          edits: edits,
        );

        // Assert
        expect(result, isTrue);
        expect(lastAppliedEdit?['operation'], equals('batch_edit'));
        expect(lastAppliedEdit?['edits'], equals(edits));
        expect(lastAppliedEdit?['field'], equals('batch'));
      });

      test('should handle empty batch', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const currentUserId = 'user-123';
        final edits = <Map<String, dynamic>>[];

        activeEditingSessions[recipeId] = createMockSubscription();

        // Act
        final result = await RealtimeContentOperations.applyBatchEdits(
          context: createTestContext(
            currentUserId: currentUserId,
            currentUserDisplayName: null,
          ),
          recipeId: recipeId,
          edits: edits,
        );

        // Assert
        expect(result, isTrue); // Empty batch succeeds
        expect(conflictResolutionCallCount, equals(0)); // No edits applied
      });
    });

    group('Validation Helpers', () {
      test('should validate ingredient content', () {
        // Valid ingredients
        expect(
          RealtimeFieldOperations.isValidIngredient('2 cups flour'),
          isTrue,
        );
        expect(
          RealtimeFieldOperations.isValidIngredient('Salt to taste'),
          isTrue,
        );

        // Invalid ingredients
        expect(RealtimeFieldOperations.isValidIngredient(''), isFalse);
        expect(RealtimeFieldOperations.isValidIngredient('  '), isFalse);
        expect(
          RealtimeFieldOperations.isValidIngredient('<script>alert()</script>'),
          isFalse,
        );
        expect(
          RealtimeFieldOperations.isValidIngredient('a' * 201),
          isFalse,
        ); // Too long
      });

      test('should validate instruction content', () {
        // Valid instructions
        expect(
          RealtimeFieldOperations.isValidInstruction('Mix ingredients'),
          isTrue,
        );
        expect(
          RealtimeFieldOperations.isValidInstruction(
            'Bake for 30 minutes at 350°F',
          ),
          isTrue,
        );

        // Invalid instructions
        expect(RealtimeFieldOperations.isValidInstruction(''), isFalse);
        expect(RealtimeFieldOperations.isValidInstruction('  '), isFalse);
        expect(
          RealtimeFieldOperations.isValidInstruction('<div>test</div>'),
          isFalse,
        );
        expect(
          RealtimeFieldOperations.isValidInstruction('a' * 1001),
          isFalse,
        ); // Too long
      });

      test('should sanitize text content', () {
        // Remove HTML tags
        expect(
          RealtimeFieldOperations.sanitizeTextContent('<b>Bold</b> text'),
          equals('Bold text'),
        );

        // Normalize whitespace
        expect(
          RealtimeFieldOperations.sanitizeTextContent('  Multiple   spaces  '),
          equals('Multiple spaces'),
        );

        // Combined sanitization - the regex removes tags but keeps content between them
        expect(
          RealtimeFieldOperations.sanitizeTextContent(
            '  <script>alert()</script>  Text  ',
          ),
          equals('alert() Text'),
        );
      });

      test('should validate index for list operations', () {
        const listLength = 5;

        // Valid indices without append
        expect(RealtimeFieldOperations.isValidIndex(0, listLength), isTrue);
        expect(RealtimeFieldOperations.isValidIndex(4, listLength), isTrue);

        // Invalid indices without append
        expect(RealtimeFieldOperations.isValidIndex(-1, listLength), isFalse);
        expect(RealtimeFieldOperations.isValidIndex(5, listLength), isFalse);

        // Valid indices with append
        expect(
          RealtimeFieldOperations.isValidIndex(
            5,
            listLength,
            allowAppend: true,
          ),
          isTrue,
        );

        // Invalid indices with append
        expect(
          RealtimeFieldOperations.isValidIndex(
            6,
            listLength,
            allowAppend: true,
          ),
          isFalse,
        );
      });
    });
  });
}
