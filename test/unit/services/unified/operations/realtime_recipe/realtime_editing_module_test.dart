// test/unit/services/unified/operations/realtime_recipe/realtime_editing_module_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/realtime_editing_module.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/builders/recipe_builder.dart';

void main() {
  group('RealtimeEditingModule', () {
    late MockUnifiedRecipeService mockParentService;
    late MockRealtimeSyncService mockRealtimeSyncService;
    late RealtimeEditingModule editingModule;
    late Recipe testRecipe;
    late Recipe collaborativeRecipe;
    
    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(<String, dynamic>{});
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      
      // Create mocks
      mockParentService = MockUnifiedRecipeService();
      mockRealtimeSyncService = MockRealtimeSyncService();
      
      // Create test data
      testRecipe = RecipeBuilder()
          .withId('recipe_1')
          .withTitle('Test Recipe')
          .withCreatedBy('user_123')
          .build();
      
      collaborativeRecipe = RecipeBuilder()
          .withId('recipe_2')
          .withTitle('Collaborative Recipe')
          .withCreatedBy('user_123')
          .asCollaborative()
          .build();
      
      // Configure mock services
      mockParentService.setServiceState(
        userId: 'user_123',
        recipes: [testRecipe, collaborativeRecipe],
      );
      
      mockRealtimeSyncService.setServiceState(
        isConnected: true,
      );
      
      // Create editing module instance
      editingModule = RealtimeEditingModule(mockParentService, mockRealtimeSyncService);
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });
    
    group('Editing Session Management', () {
      test('should start realtime editing session', () async {
        // Act
        final result = await editingModule.startRealtimeEditing('recipe_1');
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should not start editing without proper permissions', () async {
        // Arrange
        mockParentService.setServiceState(
          userId: 'other_user',
          recipes: [testRecipe],
        );
        
        // Act
        final result = await editingModule.startRealtimeEditing('recipe_1');
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should not start editing when recipe not found', () async {
        // Act
        final result = await editingModule.startRealtimeEditing('nonexistent');
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should not start editing without realtime service', () async {
        // Arrange
        editingModule = RealtimeEditingModule(mockParentService, null);
        
        // Act
        final result = await editingModule.startRealtimeEditing('recipe_1');
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should stop realtime editing session', () async {
        // Arrange
        await editingModule.startRealtimeEditing('recipe_1');
        
        // Act
        final result = await editingModule.stopRealtimeEditing('recipe_1');
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should check if recipe is in realtime editing mode', () {
        // Act
        final isEditing = editingModule.isInRealtimeEditingMode('recipe_2');
        
        // Assert
        expect(isEditing, isTrue); // Collaborative recipe
      });
      
      test('should report non-collaborative recipe not in editing mode', () {
        // Act
        final isEditing = editingModule.isInRealtimeEditingMode('recipe_1');
        
        // Assert
        expect(isEditing, isFalse);
      });
    });
    
    group('Realtime Editing Operations', () {
      test('should make realtime edit successfully', () async {
        // Arrange
        final changes = {'title': 'Updated Title'};
        
        // Act
        final result = await editingModule.makeRealtimeEdit(
          recipeId: 'recipe_1',
          changes: changes,
          editDescription: 'Updated title',
        );
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should fall back to regular edit without realtime service', () async {
        // Arrange
        editingModule = RealtimeEditingModule(mockParentService, null);
        final changes = {'title': 'Updated Title'};
        
        // Act
        final result = await editingModule.makeRealtimeEdit(
          recipeId: 'recipe_1',
          changes: changes,
        );
        
        // Assert
        expect(result, isTrue);
      });
    });
  });
}

// Mock classes
class MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {
  String? _currentUserId = 'user_123';
  List<Recipe> _recipes = [];
  
  void setServiceState({
    String? userId,
    List<Recipe>? recipes,
  }) {
    if (userId != null) _currentUserId = userId;
    if (recipes != null) _recipes = recipes;
  }
  
  @override
  String? get currentUserId => _currentUserId;
  
  @override
  List<Recipe> get recipes => _recipes;
}

class MockRealtimeSyncService extends Mock implements RealtimeSyncService {
  bool _isConnected = true;
  
  void setServiceState({
    bool? isConnected,
  }) {
    if (isConnected != null) _isConnected = isConnected;
  }
  
  @override
  bool get isConnected => _isConnected;
}