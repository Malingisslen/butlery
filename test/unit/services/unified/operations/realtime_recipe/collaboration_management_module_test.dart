// test/unit/services/unified/operations/realtime_recipe/collaboration_management_module_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/collaboration_management_module.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/providers/application_provider.dart' as app_provider;
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/builders/recipe_builder.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('CollaborationManagementModule', () {
    late MockUnifiedRecipeService mockParentService;
    late MockRealtimeSyncService mockRealtimeSyncService;
    late MockPermissionService mockPermissionService;
    late CollaborationManagementModule collaborationModule;
    late Recipe testRecipe;
    late Recipe collaborativeRecipe;
    
    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(<String>[]);
      registerFallbackValue(UserProfile(
        uid: 'test',
        email: 'test@example.com',
        displayName: 'Test User',
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      ));
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Create mocks
      mockParentService = MockUnifiedRecipeService();
      mockRealtimeSyncService = MockRealtimeSyncService();
      
      // Create test data
      
      testRecipe = RecipeBuilder()
          .withId('recipe_1')
          .withTitle('Personal Recipe')
          .withCreatedBy('user_123')
          .build();
      
      collaborativeRecipe = RecipeBuilder()
          .withId('recipe_2')
          .withTitle('Collaborative Recipe')
          .withCreatedBy('user_123')
          .asCollaborative()
          .build();
      
      // Get and configure permission service mock
      mockPermissionService = TestServiceLocator.get<PermissionService>() as MockPermissionService;
      mockPermissionService.setPermissionState(
        defaultHasPermission: true,
        currentUserId: 'user_123',
      );
      
      // Initialize production ServiceLocator with MockDIContainer
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(MockDIContainer());
      
      // Configure mock services
      mockParentService.setServiceState(
        userId: 'user_123',
        recipes: [testRecipe, collaborativeRecipe],
      );
      
      // Create collaboration module instance
      collaborationModule = CollaborationManagementModule(mockParentService, mockRealtimeSyncService);
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });
    
    group('Collaboration Lifecycle', () {
      test('should enable collaborative editing for personal recipe', () async {
        // Arrange
        when(() => mockParentService.createCollaborativeRecipe(
          title: any(named: 'title'),
          memberIds: any(named: 'memberIds'),
          description: any(named: 'description'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          rating: any(named: 'rating'),
          tags: any(named: 'tags'),
          sourceUrl: any(named: 'sourceUrl'),
        )).thenAnswer((_) async => 'collab_recipe_1');
        
        when(() => mockParentService.deleteRecipe('recipe_1'))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await collaborationModule.enableCollaborativeEditing(
          'recipe_1',
          ['user_456', 'user_789'],
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParentService.createCollaborativeRecipe(
          title: 'Personal Recipe',
          memberIds: ['user_456', 'user_789'],
          description: any(named: 'description'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          rating: any(named: 'rating'),
          tags: any(named: 'tags'),
          sourceUrl: any(named: 'sourceUrl'),
        )).called(1);
      });
      
      test('should not enable collaboration for already collaborative recipe', () async {
        // Act
        final result = await collaborationModule.enableCollaborativeEditing(
          'recipe_2',
          ['user_456'],
        );
        
        // Assert
        expect(result, isTrue); // Returns true but doesn't create new
      });
      
      test('should not enable collaboration without members', () async {
        // Act
        final result = await collaborationModule.enableCollaborativeEditing(
          'recipe_1',
          [],
        );
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should not enable collaboration without owner permission', () async {
        // Arrange
        mockPermissionService.setPermissionState(
          defaultHasPermission: false,
        );
        
        // Act
        final result = await collaborationModule.enableCollaborativeEditing(
          'recipe_1',
          ['user_456'],
        );
        
        // Assert
        expect(result, isFalse);
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

class MockRealtimeSyncService extends Mock implements RealtimeSyncService {}