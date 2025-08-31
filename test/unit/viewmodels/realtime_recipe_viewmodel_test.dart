// test/unit/viewmodels/realtime_recipe_viewmodel_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/recipe/realtime_recipe_viewmodel.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod_locator;

// ULTRATHINK CONVERSION: Local mock classes removed - using centralized mocks

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('RealtimeRecipeViewModel - Ultrathink Enhanced Tests', () {
    late RealtimeRecipeViewModel viewModel;
    late UnifiedRecipeService mockRecipeService; // Using interface type for centralized mock
    late MockRealtimeRecipeOperations mockRealtimeOps;
    
    // Test data
    const testRecipeId = 'recipe_123';
    const testUserId = 'user_456';
    const testUserDisplayName = 'Test User';
    const testIngredient = '2 cups flour';
    const testInstruction = 'Mix ingredients well';
    final testChanges = {'title': 'Updated Recipe'};
    final testRecipes = [
      RecipeFactory.build(id: testRecipeId, title: 'Test Recipe'),
      RecipeFactory.build(id: 'recipe_456', title: 'Another Recipe'),
    ];
    
    setUpAll(() async {
      await TestServiceLocator.initialize();
      
      // Register fallback values for mocktail
      registerFallbackValue(RecipeFactory.build());
      registerFallbackValue(<String, dynamic>{});
    });
    
    setUp(() {
      // ULTRATHINK FIX: Bridge production ServiceLocator to test mocks
      // This solves "ServiceLocator not initialized" errors when production code
      // calls ServiceLocator.get() but only TestServiceLocator was initialized
      final productionContainer = DIContainer();
      prod_locator.ServiceLocator.initialize(productionContainer);
      
      // Create mocks using centralized versions
      mockRecipeService = MockFactory.createUnifiedRecipeService(
        recipes: testRecipes,
        currentUserId: testUserId,
        currentUserDisplayName: testUserDisplayName,
      );
      mockRealtimeOps = MockRealtimeRecipeOperations();
      
      // Configure realtime operations property (not managed by setRecipeState)
      when(() => mockRecipeService.realtime).thenReturn(mockRealtimeOps);
      
      // Note: currentUserId, currentUserDisplayName, and recipes already configured by MockFactory.setRecipeState()
      
      // Configure realtime operations defaults
      when(() => mockRealtimeOps.isConnected).thenReturn(true);
      when(() => mockRealtimeOps.connectionStream).thenAnswer((_) => Stream.value(true));
      when(() => mockRealtimeOps.startRealtimeEditing(any())).thenAnswer((_) async => true);
      when(() => mockRealtimeOps.stopRealtimeEditing(any())).thenAnswer((_) async => true);
      when(() => mockRealtimeOps.makeRealtimeEdit(
        recipeId: any(named: 'recipeId'),
        changes: any(named: 'changes'),
        editDescription: any(named: 'editDescription'),
      )).thenAnswer((_) async => true);
      
      // Configure recipe service defaults
      when(() => mockRecipeService.isInRealtimeEditingSession(any())).thenReturn(true);
      when(() => mockRecipeService.addIngredient(any(), any())).thenAnswer((_) async => true);
      when(() => mockRecipeService.updateIngredient(any(), any(), any())).thenAnswer((_) async => true);
      when(() => mockRecipeService.removeIngredient(any(), any())).thenAnswer((_) async => true);
      when(() => mockRecipeService.addInstruction(any(), any())).thenAnswer((_) async => true);
      when(() => mockRecipeService.updateInstruction(any(), any(), any())).thenAnswer((_) async => true);
      when(() => mockRecipeService.removeInstruction(any(), any())).thenAnswer((_) async => true);
      
      // Create ViewModel with constructor dependency injection (ultrathink approach)
      viewModel = RealtimeRecipeViewModel(mockRecipeService);
    });
    
    tearDown(() async {
      // Only dispose if not already disposed (to avoid FlutterError in disposal tests)
      try {
        viewModel.dispose();
      } catch (e) {
        // Already disposed, ignore FlutterError
      }
      await TestServiceLocator.reset();
    });
    
    group('Initialization and Basic Properties', () {
      test('should initialize with correct service name', () {
        // Assert
        expect(viewModel.serviceName, equals('RealtimeRecipeViewModel'));
      });
      
      test('should expose current user information correctly', () {
        // Assert
        expect(viewModel.currentUserId, equals(testUserId));
        expect(viewModel.currentUserDisplayName, equals(testUserDisplayName));
      });
      
      test('should expose realtime connection status correctly', () {
        // Assert
        expect(viewModel.isRealtimeConnected, isTrue);
        expect(viewModel.realtimeConnectionStream, isA<Stream<bool>>());
      });
      
      test('should handle null current user gracefully', () {
        // Arrange - Use state configuration instead of stubbing
        (mockRecipeService as MockUnifiedRecipeService).setRecipeState(
          currentUserId: null,
          currentUserDisplayName: null,
        );
        
        // Assert
        expect(viewModel.currentUserId, isNull);
        expect(viewModel.currentUserDisplayName, isNull);
      });
      
      test('should handle disconnected realtime state', () {
        // Arrange
        when(() => mockRealtimeOps.isConnected).thenReturn(false);
        when(() => mockRealtimeOps.connectionStream).thenAnswer((_) => Stream.value(false));
        
        // Assert
        expect(viewModel.isRealtimeConnected, isFalse);
      });
    });
    
    group('Realtime Session Management', () {
      test('should start realtime editing successfully', () async {
        // Act
        final result = await viewModel.startRealtimeEditing(testRecipeId);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRealtimeOps.startRealtimeEditing(testRecipeId)).called(1);
      });
      
      test('should fail to start realtime editing with empty recipe ID', () async {
        // Act
        final result = await viewModel.startRealtimeEditing('');
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRealtimeOps.startRealtimeEditing(''));
      });
      
      test('should fail to start realtime editing with whitespace recipe ID', () async {
        // Act
        final result = await viewModel.startRealtimeEditing('   ');
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRealtimeOps.startRealtimeEditing('   '));
      });
      
      test('should stop realtime editing successfully', () async {
        // Act
        final result = await viewModel.stopRealtimeEditing(testRecipeId);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRealtimeOps.stopRealtimeEditing(testRecipeId)).called(1);
      });
      
      test('should fail to stop realtime editing with empty recipe ID', () async {
        // Act
        final result = await viewModel.stopRealtimeEditing('');
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRealtimeOps.stopRealtimeEditing(''));
      });
      
      test('should check if recipe is in realtime editing session', () {
        // Act
        final result = viewModel.isInRealtimeEditingSession(testRecipeId);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.isInRealtimeEditingSession(testRecipeId)).called(1);
      });
      
      test('should handle session check with empty recipe ID', () {
        // Act
        final result = viewModel.isInRealtimeEditingSession('');
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRecipeService.isInRealtimeEditingSession(''));
      });
      
      test('should handle session check when not in session', () {
        // Arrange
        when(() => mockRecipeService.isInRealtimeEditingSession(testRecipeId)).thenReturn(false);
        
        // Act
        final result = viewModel.isInRealtimeEditingSession(testRecipeId);
        
        // Assert
        expect(result, isFalse);
      });
    });
    
    group('Live Editing Operations', () {
      test('should make realtime edit successfully', () async {
        // Act
        final result = await viewModel.makeRealtimeEdit(
          recipeId: testRecipeId,
          changes: testChanges,
          editDescription: 'Test edit',
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRealtimeOps.makeRealtimeEdit(
          recipeId: testRecipeId,
          changes: testChanges,
          editDescription: 'Test edit',
        )).called(1);
      });
      
      test('should fail realtime edit with empty recipe ID', () async {
        // Act
        final result = await viewModel.makeRealtimeEdit(
          recipeId: '',
          changes: testChanges,
        );
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRealtimeOps.makeRealtimeEdit(
          recipeId: any(named: 'recipeId'),
          changes: any(named: 'changes'),
          editDescription: any(named: 'editDescription'),
        ));
      });
      
      test('should fail realtime edit with empty changes', () async {
        // Act
        final result = await viewModel.makeRealtimeEdit(
          recipeId: testRecipeId,
          changes: {},
        );
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRealtimeOps.makeRealtimeEdit(
          recipeId: any(named: 'recipeId'),
          changes: any(named: 'changes'),
          editDescription: any(named: 'editDescription'),
        ));
      });
      
      test('should make realtime edit without description', () async {
        // Act
        final result = await viewModel.makeRealtimeEdit(
          recipeId: testRecipeId,
          changes: testChanges,
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRealtimeOps.makeRealtimeEdit(
          recipeId: testRecipeId,
          changes: testChanges,
          editDescription: null,
        )).called(1);
      });
    });
    
    group('Realtime Content Operations - Ingredients', () {
      test('should add ingredient in realtime successfully', () async {
        // Act
        final result = await viewModel.addIngredientRealtime(testRecipeId, testIngredient);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.addIngredient(testRecipeId, testIngredient)).called(1);
      });
      
      test('should fail to add ingredient with empty recipe ID', () async {
        // Act
        final result = await viewModel.addIngredientRealtime('', testIngredient);
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRecipeService.addIngredient(any(), any()));
      });
      
      test('should fail to add ingredient with empty ingredient', () async {
        // Act
        final result = await viewModel.addIngredientRealtime(testRecipeId, '');
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRecipeService.addIngredient(any(), any()));
      });
      
      test('should fail to add ingredient when not in realtime session', () async {
        // Arrange
        when(() => mockRecipeService.isInRealtimeEditingSession(testRecipeId)).thenReturn(false);
        
        // Act
        final result = await viewModel.addIngredientRealtime(testRecipeId, testIngredient);
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRecipeService.addIngredient(any(), any()));
      });
      
      test('should update ingredient in realtime successfully', () async {
        // Act
        final result = await viewModel.updateIngredientRealtime(testRecipeId, 0, testIngredient);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.updateIngredient(testRecipeId, 0, testIngredient)).called(1);
      });
      
      test('should fail to update ingredient when not in realtime session', () async {
        // Arrange
        when(() => mockRecipeService.isInRealtimeEditingSession(testRecipeId)).thenReturn(false);
        
        // Act
        final result = await viewModel.updateIngredientRealtime(testRecipeId, 0, testIngredient);
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRecipeService.updateIngredient(any(), any(), any()));
      });
      
      test('should remove ingredient in realtime successfully', () async {
        // Act
        final result = await viewModel.removeIngredientRealtime(testRecipeId, 0);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.removeIngredient(testRecipeId, 0)).called(1);
      });
      
      test('should fail to remove ingredient when not in realtime session', () async {
        // Arrange
        when(() => mockRecipeService.isInRealtimeEditingSession(testRecipeId)).thenReturn(false);
        
        // Act
        final result = await viewModel.removeIngredientRealtime(testRecipeId, 0);
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRecipeService.removeIngredient(any(), any()));
      });
    });
    
    group('Realtime Content Operations - Instructions', () {
      test('should add instruction in realtime successfully', () async {
        // Act
        final result = await viewModel.addInstructionRealtime(testRecipeId, testInstruction);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.addInstruction(testRecipeId, testInstruction)).called(1);
      });
      
      test('should fail to add instruction when not in realtime session', () async {
        // Arrange
        when(() => mockRecipeService.isInRealtimeEditingSession(testRecipeId)).thenReturn(false);
        
        // Act
        final result = await viewModel.addInstructionRealtime(testRecipeId, testInstruction);
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRecipeService.addInstruction(any(), any()));
      });
      
      test('should update instruction in realtime successfully', () async {
        // Act
        final result = await viewModel.updateInstructionRealtime(testRecipeId, 0, testInstruction);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.updateInstruction(testRecipeId, 0, testInstruction)).called(1);
      });
      
      test('should fail to update instruction with empty instruction', () async {
        // Act
        final result = await viewModel.updateInstructionRealtime(testRecipeId, 0, '');
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRecipeService.updateInstruction(any(), any(), any()));
      });
      
      test('should remove instruction in realtime successfully', () async {
        // Act
        final result = await viewModel.removeInstructionRealtime(testRecipeId, 0);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.removeInstruction(testRecipeId, 0)).called(1);
      });
    });
    
    group('Realtime Watching', () {
      test('should watch recipe correctly', () {
        // Arrange
        final testRecipe = RecipeFactory.build(id: testRecipeId);
        when(() => mockRealtimeOps.watchRecipe(testRecipeId))
            .thenAnswer((_) => Stream.value(testRecipe));
        
        // Act
        final stream = viewModel.watchRecipe(testRecipeId);
        
        // Assert
        expect(stream, isA<Stream<Recipe>>());
        verify(() => mockRealtimeOps.watchRecipe(testRecipeId)).called(1);
      });
      
      test('should return empty stream for invalid recipe ID', () {
        // Act
        final stream = viewModel.watchRecipe('');
        
        // Assert
        expect(stream, isA<Stream<Recipe>>());
        verifyNever(() => mockRealtimeOps.watchRecipe(any()));
      });
      
      test('should watch multiple recipes correctly', () {
        // Arrange
        final recipeIds = [testRecipeId, 'recipe_456'];
        when(() => mockRealtimeOps.watchMultipleRecipes(recipeIds))
            .thenAnswer((_) => Stream.value(testRecipes));
        
        // Act
        final stream = viewModel.watchMultipleRecipes(recipeIds);
        
        // Assert
        expect(stream, isA<Stream<List<Recipe>>>());
        verify(() => mockRealtimeOps.watchMultipleRecipes(recipeIds)).called(1);
      });
      
      test('should return empty list stream for empty recipe IDs', () {
        // Act
        final stream = viewModel.watchMultipleRecipes([]);
        
        // Assert
        expect(stream, isA<Stream<List<Recipe>>>());
        // Verify it emits empty list
        stream.listen(expectAsync1((recipes) {
          expect(recipes, isEmpty);
        }));
      });
    });
    
    group('Active Editor Tracking', () {
      test('should get active editors asynchronously', () async {
        // Arrange
        final mockPresence = [
          {'userId': 'user_1', 'displayName': 'User 1'},
          {'userId': 'user_2', 'displayName': 'User 2'},
        ];
        when(() => mockRealtimeOps.getRecipePresence(testRecipeId))
            .thenAnswer((_) async => mockPresence);
        
        // Act
        final editors = await viewModel.getActiveEditorsAsync(testRecipeId);
        
        // Assert
        expect(editors, equals(['user_1', 'user_2']));
        verify(() => mockRealtimeOps.getRecipePresence(testRecipeId)).called(1);
      });
      
      test('should return empty list for empty recipe ID in async call', () async {
        // Act
        final editors = await viewModel.getActiveEditorsAsync('');
        
        // Assert
        expect(editors, isEmpty);
        verifyNever(() => mockRealtimeOps.getRecipePresence(any()));
      });
      
      test('should get active editors synchronously', () {
        // Arrange
        final activeEditors = ['user_1', 'user_2', testUserId];
        when(() => mockRealtimeOps.getActiveEditors(testRecipeId)).thenReturn(activeEditors);
        
        // Act
        final editors = viewModel.getActiveEditors(testRecipeId);
        
        // Assert
        expect(editors, equals(activeEditors));
        verify(() => mockRealtimeOps.getActiveEditors(testRecipeId)).called(1);
      });
      
      test('should get active editor count correctly', () {
        // Arrange
        when(() => mockRealtimeOps.getActiveEditors(testRecipeId)).thenReturn(['user_1', 'user_2']);
        
        // Act
        final count = viewModel.getActiveEditorCount(testRecipeId);
        
        // Assert
        expect(count, equals(2));
      });
      
      test('should check if user is actively editing', () {
        // Arrange
        when(() => mockRealtimeOps.getActiveEditors(testRecipeId)).thenReturn(['user_1', testUserId]);
        
        // Act
        final isEditing = viewModel.isUserActivelyEditing(testRecipeId, testUserId);
        
        // Assert
        expect(isEditing, isTrue);
      });
      
      test('should check if current user is actively editing', () {
        // Arrange
        when(() => mockRealtimeOps.getActiveEditors(testRecipeId)).thenReturn(['user_1', testUserId]);
        
        // Act
        final isEditing = viewModel.isCurrentUserActivelyEditing(testRecipeId);
        
        // Assert
        expect(isEditing, isTrue);
      });
      
      test('should handle current user being null for active editing check', () {
        // Arrange - Use state configuration instead of stubbing
        (mockRecipeService as MockUnifiedRecipeService).setRecipeState(
          currentUserId: null,
        );
        
        // Act
        final isEditing = viewModel.isCurrentUserActivelyEditing(testRecipeId);
        
        // Assert
        expect(isEditing, isFalse);
        verifyNever(() => mockRealtimeOps.getActiveEditors(any()));
      });
      
      test('should watch active editors correctly', () {
        // Arrange
        final mockPresence = [
          {'userId': 'user_1'},
          {'userId': 'user_2'},
        ];
        when(() => mockRealtimeOps.watchRecipePresence(testRecipeId))
            .thenAnswer((_) => Stream.value(mockPresence));
        
        // Act
        final stream = viewModel.watchActiveEditors(testRecipeId);
        
        // Assert
        expect(stream, isA<Stream<List<String>>>());
        stream.listen(expectAsync1((editors) {
          expect(editors, equals(['user_1', 'user_2']));
        }));
      });
      
      test('should return empty list stream for invalid recipe ID when watching editors', () {
        // Act
        final stream = viewModel.watchActiveEditors('');
        
        // Assert
        stream.listen(expectAsync1((editors) {
          expect(editors, isEmpty);
        }));
      });
    });
    
    group('Connection Management', () {
      test('should reconnect realtime successfully when connected', () async {
        // Act
        final result = await viewModel.reconnectRealtime();
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should reconnect realtime when disconnected', () async {
        // Arrange
        when(() => mockRealtimeOps.isConnected).thenReturn(false);
        
        // Act
        final result = await viewModel.reconnectRealtime();
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should disconnect realtime successfully', () async {
        // Arrange
        when(() => mockRealtimeOps.clearAllPresence()).thenAnswer((_) async {});
        
        // Act & Assert - should not throw
        await expectLater(viewModel.disconnectRealtime(), completes);
        verify(() => mockRealtimeOps.clearAllPresence()).called(1);
      });
    });
    
    group('Session State Management', () {
      test('should get active realtime sessions correctly', () {
        // Arrange
        when(() => mockRecipeService.isInRealtimeEditingSession(testRecipeId)).thenReturn(true);
        when(() => mockRecipeService.isInRealtimeEditingSession('recipe_456')).thenReturn(false);
        
        // Act
        final sessions = viewModel.getActiveRealtimeSessions();
        
        // Assert
        expect(sessions[testRecipeId], isTrue);
        expect(sessions['recipe_456'], isFalse);
        expect(sessions.length, equals(2));
      });
      
      test('should get active realtime recipe IDs correctly', () {
        // Arrange
        when(() => mockRecipeService.isInRealtimeEditingSession(testRecipeId)).thenReturn(true);
        when(() => mockRecipeService.isInRealtimeEditingSession('recipe_456')).thenReturn(false);
        
        // Act
        final activeIds = viewModel.getActiveRealtimeRecipeIds();
        
        // Assert
        expect(activeIds, contains(testRecipeId));
        expect(activeIds, isNot(contains('recipe_456')));
        expect(activeIds.length, equals(1));
      });
      
      test('should get active session count correctly', () {
        // Arrange
        when(() => mockRecipeService.isInRealtimeEditingSession(testRecipeId)).thenReturn(true);
        when(() => mockRecipeService.isInRealtimeEditingSession('recipe_456')).thenReturn(false);
        
        // Act
        final count = viewModel.getActiveSessionCount();
        
        // Assert
        expect(count, equals(1));
      });
    });
    
    group('Conflict Resolution', () {
      test('should resolve edit conflict with local resolution', () async {
        // Arrange
        final localChanges = {'title': 'Local Title'};
        final remoteChanges = {'title': 'Remote Title'};
        when(() => mockRealtimeOps.resolveConflict(
          recipeId: any(named: 'recipeId'),
          localVersion: any(named: 'localVersion'),
          remoteVersion: any(named: 'remoteVersion'),
          resolution: any(named: 'resolution'),
        )).thenAnswer((_) async => true);
        
        // Act
        final result = await viewModel.resolveEditConflict(
          recipeId: testRecipeId,
          localChanges: localChanges,
          remoteChanges: remoteChanges,
          resolution: 'local',
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRealtimeOps.resolveConflict(
          recipeId: testRecipeId,
          localVersion: any(named: 'localVersion'),
          remoteVersion: any(named: 'remoteVersion'),
          resolution: 'local',
        )).called(1);
      });
      
      test('should resolve edit conflict with remote resolution', () async {
        // Arrange
        final localChanges = {'title': 'Local Title'};
        final remoteChanges = {'title': 'Remote Title'};
        when(() => mockRealtimeOps.resolveConflict(
          recipeId: any(named: 'recipeId'),
          localVersion: any(named: 'localVersion'),
          remoteVersion: any(named: 'remoteVersion'),
          resolution: any(named: 'resolution'),
        )).thenAnswer((_) async => true);
        
        // Act
        final result = await viewModel.resolveEditConflict(
          recipeId: testRecipeId,
          localChanges: localChanges,
          remoteChanges: remoteChanges,
          resolution: 'remote',
        );
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should resolve edit conflict with merge resolution', () async {
        // Arrange
        final localChanges = {'title': 'Local Title', 'description': 'Local Desc'};
        final remoteChanges = {'title': 'Remote Title'};
        when(() => mockRealtimeOps.resolveConflict(
          recipeId: any(named: 'recipeId'),
          localVersion: any(named: 'localVersion'),
          remoteVersion: any(named: 'remoteVersion'),
          resolution: any(named: 'resolution'),
        )).thenAnswer((_) async => true);
        
        // Act
        final result = await viewModel.resolveEditConflict(
          recipeId: testRecipeId,
          localChanges: localChanges,
          remoteChanges: remoteChanges,
          resolution: 'merge',
        );
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should fail conflict resolution with empty recipe ID', () async {
        // Act
        final result = await viewModel.resolveEditConflict(
          recipeId: '',
          localChanges: {'title': 'Test'},
          remoteChanges: {'title': 'Test'},
          resolution: 'local',
        );
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should fail conflict resolution with invalid resolution type', () async {
        // Act & Assert
        await expectLater(
          viewModel.resolveEditConflict(
            recipeId: testRecipeId,
            localChanges: {'title': 'Test'},
            remoteChanges: {'title': 'Test'},
            resolution: 'invalid',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
    
    group('Realtime Analytics', () {
      test('should get realtime stats correctly', () {
        // Arrange
        when(() => mockRecipeService.isInRealtimeEditingSession(testRecipeId)).thenReturn(true);
        when(() => mockRecipeService.isInRealtimeEditingSession('recipe_456')).thenReturn(false);
        when(() => mockRealtimeOps.getActiveEditors(testRecipeId)).thenReturn(['user_1', 'user_2']);
        when(() => mockRealtimeOps.getActiveEditors('recipe_456')).thenReturn([]);
        when(() => mockRealtimeOps.getActiveEditors(testRecipeId)).thenReturn([testUserId]);
        
        // Act
        final stats = viewModel.getRealtimeStats();
        
        // Assert
        expect(stats['isConnected'], isTrue);
        expect(stats['activeSessionCount'], equals(1));
        expect(stats['totalActiveEditors'], isA<int>());
        expect(stats['currentUserActiveSessions'], isA<int>());
      });
      
      test('should get realtime usage by recipe correctly', () {
        // Arrange
        when(() => mockRecipeService.isInRealtimeEditingSession(testRecipeId)).thenReturn(true);
        when(() => mockRecipeService.isInRealtimeEditingSession('recipe_456')).thenReturn(false);
        when(() => mockRealtimeOps.getActiveEditors(testRecipeId)).thenReturn(['user_1', 'user_2']);
        
        // Act
        final usage = viewModel.getRealtimeUsageByRecipe();
        
        // Assert
        expect(usage[testRecipeId], equals(2));
        expect(usage.containsKey('recipe_456'), isFalse);
      });
      
      test('should handle empty active sessions in analytics', () {
        // Arrange
        when(() => mockRecipeService.isInRealtimeEditingSession(any())).thenReturn(false);
        
        // Act
        final stats = viewModel.getRealtimeStats();
        final usage = viewModel.getRealtimeUsageByRecipe();
        
        // Assert
        expect(stats['activeSessionCount'], equals(0));
        expect(stats['totalActiveEditors'], equals(0));
        expect(usage, isEmpty);
      });
    });
    
    group('Edge Cases and Error Handling', () {
      test('should handle service exceptions gracefully', () async {
        // Arrange
        when(() => mockRealtimeOps.startRealtimeEditing(testRecipeId))
            .thenThrow(Exception('Network error'));
        
        // Act 
        final result = await viewModel.startRealtimeEditing(testRecipeId);
        
        // Assert - should return false when service throws exception
        expect(result, isFalse);
      });
      
      test('should handle recipe not found in conflict resolution', () async {
        // Arrange - Use state configuration instead of stubbing
        (mockRecipeService as MockUnifiedRecipeService).setRecipeState(
          recipes: [],
        );
        
        // Act & Assert
        await expectLater(
          viewModel.resolveEditConflict(
            recipeId: 'nonexistent_recipe',
            localChanges: {'title': 'Test'},
            remoteChanges: {'title': 'Test'},
            resolution: 'local',
          ),
          throwsA(isA<Exception>()),
        );
      });
      
      test('should handle null presence data in active editors async', () async {
        // Arrange
        when(() => mockRealtimeOps.getRecipePresence(testRecipeId))
            .thenAnswer((_) async => [{'userId': null}]);
        
        // Act
        final editors = await viewModel.getActiveEditorsAsync(testRecipeId);
        
        // Assert
        expect(editors, equals([''])); // null gets converted to empty string
      });
      
      test('should handle empty recipes list in session management', () {
        // Arrange - Use state configuration instead of stubbing
        (mockRecipeService as MockUnifiedRecipeService).setRecipeState(
          recipes: [],
        );
        
        // Act
        final sessions = viewModel.getActiveRealtimeSessions();
        final count = viewModel.getActiveSessionCount();
        
        // Assert
        expect(sessions, isEmpty);
        expect(count, equals(0));
      });
    });
    
    group('Lifecycle and Disposal', () {
      test('should dispose without throwing', () {
        // Act & Assert
        expect(() => viewModel.dispose(), returnsNormally);
      });
      
      test('should handle multiple dispose calls', () {
        // Act & Assert - First dispose should work, subsequent should throw
        expect(() => viewModel.dispose(), returnsNormally);
        expect(() => viewModel.dispose(), throwsFlutterError);
      });
      
      test('should throw FlutterError when accessing after disposal', () {
        // Arrange
        viewModel.dispose();
        
        // Act & Assert
        expect(() => viewModel.currentUserId, throwsFlutterError);
        expect(() => viewModel.isRealtimeConnected, throwsFlutterError);
        expect(() => viewModel.addListener(() {}), throwsFlutterError);
      });
    });
  });
}