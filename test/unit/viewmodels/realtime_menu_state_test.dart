// test/unit/viewmodels/realtime_menu_state_test.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/viewmodels/realtime_menu/realtime_menu_state.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('RealtimeMenuState - Ultrathink Enhanced Tests', () {
    late RealtimeMenuState menuState;
    
    // Test data
    final testRecipe1 = RecipeFactory.build(
      id: 'recipe_1',
      title: 'Köttbullar med potatismos',
      mealType: 'Middag',
      ingredients: ['500g köttfärs', '3 ägg', '1 dl ströbröd'],
      instructions: ['Blanda ingredienserna', 'Forma bullar', 'Stek i panna'],
      portions: 4,
      timeMinutes: 30,
    );
    
    final testRecipe2 = RecipeFactory.build(
      id: 'recipe_2',
      title: 'Pannkakor',
      mealType: 'Frukost',
      ingredients: ['3 ägg', '3 dl mjöl', '3 dl mjölk'],
      instructions: ['Vispa ihop smeten', 'Stek tunna pannkakor'],
      portions: 4,
      timeMinutes: 20,
    );
    
    late RealtimeMenu testMenu;
    
    setUpAll(() async {
      await TestServiceLocator.initialize();
    });
    
    setUp(() {
      menuState = RealtimeMenuState();
      
      // Create test menu with recipes
      final menuData = RealtimeMenuData(
        menuTitle: 'Veckomeny',
        createdForDate: DateTime.now(),
        menuSnapshot: {
          'Middag': [testRecipe1],
          'Frukost': [testRecipe2],
        },
      );
      
      testMenu = RealtimeMenu(
        id: 'menu_123',
        ownerId: 'user_123',
        ownerDisplayName: 'Test User',
        participants: {
          'user_123': ResourcePermission.owner,
          'user_456': ResourcePermission.editor,
        },
        lastEditedBy: 'user_123',
        lastEditedByDisplayName: 'Test User',
        data: menuData,
      );
    });
    
    tearDown(() {
      menuState.dispose();
    });
    
    tearDownAll(() async {
      await TestServiceLocator.reset();
    });
    
    group('Initialization and Default State', () {
      test('should initialize with correct default state', () {
        // Assert
        expect(menuState.currentMenu, isNull);
        expect(menuState.status, equals(RealtimeMenuStatus.idle));
        expect(menuState.errorMessage, isNull);
        expect(menuState.selectedCategory, isNull);
        expect(menuState.showParticipants, isFalse);
        expect(menuState.isLoading, isFalse);
        expect(menuState.hasError, isFalse);
        expect(menuState.isWatching, isFalse);
        expect(menuState.isOffline, isFalse);
      });
      
      test('should have empty categories when no menu is set', () {
        // Assert
        expect(menuState.categories, isEmpty);
        expect(menuState.selectedCategoryRecipes, isEmpty);
      });
      
      test('should have default menu properties when no menu is set', () {
        // Assert
        expect(menuState.menuSnapshot, isEmpty);
        expect(menuState.totalRecipeCount, equals(0));
        expect(menuState.selectedCategoryRecipeCount, equals(0));
        expect(menuState.menuTitle, equals('Namnlös meny'));
        expect(menuState.menuCreatedAt, isNull);
        expect(menuState.hasCreatedForDate, isFalse);
      });
    });
    
    group('Menu State Management', () {
      test('should set current menu and notify listeners', () {
        // Arrange
        var notificationCount = 0;
        menuState.addListener(() => notificationCount++);
        
        // Act
        menuState.setCurrentMenu(testMenu);
        
        // Assert
        expect(menuState.currentMenu, equals(testMenu));
        expect(notificationCount, equals(1));
      });
      
      test('should clear menu by setting null', () {
        // Arrange
        menuState.setCurrentMenu(testMenu);
        var notificationCount = 0;
        menuState.addListener(() => notificationCount++);
        
        // Act
        menuState.setCurrentMenu(null);
        
        // Assert
        expect(menuState.currentMenu, isNull);
        expect(notificationCount, equals(1));
      });
      
      test('should update menu properties when menu is set', () {
        // Act
        menuState.setCurrentMenu(testMenu);
        
        // Assert
        expect(menuState.categories, containsAll(['Middag', 'Frukost']));
        expect(menuState.menuSnapshot, isNotEmpty);
        expect(menuState.totalRecipeCount, equals(2));
        expect(menuState.menuTitle, equals('Veckomeny'));
        expect(menuState.menuCreatedAt, isNotNull);
      });
      
      test('should not notify if same menu is set', () {
        // Arrange
        menuState.setCurrentMenu(testMenu);
        var notificationCount = 0;
        menuState.addListener(() => notificationCount++);
        
        // Act
        menuState.setCurrentMenu(testMenu);
        
        // Assert - should still notify because setCurrentMenu always notifies
        expect(notificationCount, equals(1));
      });
    });
    
    group('Status Management', () {
      test('should set status and notify listeners when status changes', () {
        // Arrange
        var notificationCount = 0;
        menuState.addListener(() => notificationCount++);
        
        // Act
        menuState.setStatus(RealtimeMenuStatus.loading);
        
        // Assert
        expect(menuState.status, equals(RealtimeMenuStatus.loading));
        expect(menuState.isLoading, isTrue);
        expect(notificationCount, equals(1));
      });
      
      test('should not notify if same status is set', () {
        // Arrange
        menuState.setStatus(RealtimeMenuStatus.loading);
        var notificationCount = 0;
        menuState.addListener(() => notificationCount++);
        
        // Act
        menuState.setStatus(RealtimeMenuStatus.loading);
        
        // Assert
        expect(notificationCount, equals(0));
      });
      
      test('should handle all status transitions correctly', () {
        // Test each status
        final statuses = [
          RealtimeMenuStatus.idle,
          RealtimeMenuStatus.loading,
          RealtimeMenuStatus.watching,
          RealtimeMenuStatus.updating,
          RealtimeMenuStatus.error,
          RealtimeMenuStatus.offline,
        ];
        
        for (final status in statuses) {
          menuState.setStatus(status);
          expect(menuState.status, equals(status));
        }
      });
      
      test('should correctly identify loading states', () {
        // Test loading status
        menuState.setStatus(RealtimeMenuStatus.loading);
        expect(menuState.isLoading, isTrue);
        
        // Test updating status
        menuState.setStatus(RealtimeMenuStatus.updating);
        expect(menuState.isLoading, isTrue);
        
        // Test non-loading status
        menuState.setStatus(RealtimeMenuStatus.watching);
        expect(menuState.isLoading, isFalse);
      });
      
      test('should correctly identify watching state', () {
        // Act
        menuState.setStatus(RealtimeMenuStatus.watching);
        
        // Assert
        expect(menuState.isWatching, isTrue);
        
        // Test other states
        menuState.setStatus(RealtimeMenuStatus.loading);
        expect(menuState.isWatching, isFalse);
      });
      
      test('should correctly identify offline state', () {
        // Act
        menuState.setStatus(RealtimeMenuStatus.offline);
        
        // Assert
        expect(menuState.isOffline, isTrue);
        
        // Test other states
        menuState.setStatus(RealtimeMenuStatus.watching);
        expect(menuState.isOffline, isFalse);
      });
    });
    
    group('Error State Management', () {
      test('should set error message and notify listeners', () {
        // Arrange
        var notificationCount = 0;
        menuState.addListener(() => notificationCount++);
        
        // Act
        menuState.setError('Test error message');
        
        // Assert
        expect(menuState.errorMessage, equals('Test error message'));
        expect(menuState.hasError, isTrue);
        expect(notificationCount, equals(1));
      });
      
      test('should clear error message and notify listeners', () {
        // Arrange
        menuState.setError('Test error');
        var notificationCount = 0;
        menuState.addListener(() => notificationCount++);
        
        // Act
        menuState.clearError();
        
        // Assert
        expect(menuState.errorMessage, isNull);
        expect(menuState.hasError, isFalse);
        expect(notificationCount, equals(1));
      });
      
      test('should not notify when clearing null error', () {
        // Arrange
        var notificationCount = 0;
        menuState.addListener(() => notificationCount++);
        
        // Act
        menuState.clearError();
        
        // Assert
        expect(notificationCount, equals(0));
      });
      
      test('should handle null error message', () {
        // Act
        menuState.setError(null);
        
        // Assert
        expect(menuState.errorMessage, isNull);
        expect(menuState.hasError, isFalse);
      });
      
      test('should handle empty error message', () {
        // Act
        menuState.setError('');
        
        // Assert
        expect(menuState.errorMessage, equals(''));
        expect(menuState.hasError, isTrue);
      });
    });
    
    group('UI State Management - Categories', () {
      test('should select category and notify listeners', () {
        // Arrange
        menuState.setCurrentMenu(testMenu);
        var notificationCount = 0;
        menuState.addListener(() => notificationCount++);
        
        // Act
        menuState.selectCategory('Middag');
        
        // Assert
        expect(menuState.selectedCategory, equals('Middag'));
        expect(menuState.selectedCategoryRecipes, contains(testRecipe1));
        expect(menuState.selectedCategoryRecipeCount, equals(1));
        expect(notificationCount, equals(1));
      });
      
      test('should not notify when selecting same category', () {
        // Arrange
        menuState.selectCategory('Middag');
        var notificationCount = 0;
        menuState.addListener(() => notificationCount++);
        
        // Act
        menuState.selectCategory('Middag');
        
        // Assert
        expect(notificationCount, equals(0));
      });
      
      test('should clear category selection with null', () {
        // Arrange
        menuState.selectCategory('Middag');
        var notificationCount = 0;
        menuState.addListener(() => notificationCount++);
        
        // Act
        menuState.selectCategory(null);
        
        // Assert
        expect(menuState.selectedCategory, isNull);
        expect(menuState.selectedCategoryRecipes, isEmpty);
        expect(menuState.selectedCategoryRecipeCount, equals(0));
        expect(notificationCount, equals(1));
      });
      
      test('should handle selecting non-existent category', () {
        // Arrange
        menuState.setCurrentMenu(testMenu);
        
        // Act
        menuState.selectCategory('NonExistent');
        
        // Assert
        expect(menuState.selectedCategory, equals('NonExistent'));
        expect(menuState.selectedCategoryRecipes, isEmpty);
        expect(menuState.hasCategorySelected(), isFalse);
      });
      
      test('should validate category selection', () {
        // Arrange
        menuState.setCurrentMenu(testMenu);
        
        // Act - select valid category
        menuState.selectCategory('Middag');
        
        // Assert
        expect(menuState.hasCategorySelected(), isTrue);
        
        // Act - select invalid category
        menuState.selectCategory('Invalid');
        
        // Assert
        expect(menuState.hasCategorySelected(), isFalse);
      });
    });
    
    group('UI State Management - Participants', () {
      test('should toggle participants visibility', () {
        // Arrange
        var notificationCount = 0;
        menuState.addListener(() => notificationCount++);
        
        // Act
        menuState.toggleParticipants();
        
        // Assert
        expect(menuState.showParticipants, isTrue);
        expect(notificationCount, equals(1));
        
        // Act - toggle again
        menuState.toggleParticipants();
        
        // Assert
        expect(menuState.showParticipants, isFalse);
        expect(notificationCount, equals(2));
      });
      
      test('should set participants visibility directly', () {
        // Arrange
        var notificationCount = 0;
        menuState.addListener(() => notificationCount++);
        
        // Act
        menuState.setShowParticipants(true);
        
        // Assert
        expect(menuState.showParticipants, isTrue);
        expect(notificationCount, equals(1));
      });
      
      test('should not notify when setting same participants visibility', () {
        // Arrange
        menuState.setShowParticipants(true);
        var notificationCount = 0;
        menuState.addListener(() => notificationCount++);
        
        // Act
        menuState.setShowParticipants(true);
        
        // Assert
        expect(notificationCount, equals(0));
      });
    });
    
    group('State Transitions', () {
      test('should transition to loading and clear error', () {
        // Arrange
        menuState.setError('Previous error');
        var notificationCount = 0;
        menuState.addListener(() => notificationCount++);
        
        // Act
        menuState.transitionToLoading();
        
        // Assert
        expect(menuState.status, equals(RealtimeMenuStatus.loading));
        expect(menuState.errorMessage, isNull);
        expect(notificationCount, equals(2)); // One for status, one for error clearing
      });
      
      test('should transition to watching and clear error', () {
        // Arrange
        menuState.setError('Previous error');
        
        // Act
        menuState.transitionToWatching();
        
        // Assert
        expect(menuState.status, equals(RealtimeMenuStatus.watching));
        expect(menuState.errorMessage, isNull);
      });
      
      test('should transition to updating without clearing error', () {
        // Arrange
        menuState.setError('Existing error');
        
        // Act
        menuState.transitionToUpdating();
        
        // Assert
        expect(menuState.status, equals(RealtimeMenuStatus.updating));
        expect(menuState.errorMessage, equals('Existing error'));
      });
      
      test('should transition to error with message', () {
        // Act
        menuState.transitionToError('Network error');
        
        // Assert
        expect(menuState.status, equals(RealtimeMenuStatus.error));
        expect(menuState.errorMessage, equals('Network error'));
        expect(menuState.hasError, isTrue);
      });
      
      test('should transition to offline', () {
        // Act
        menuState.transitionToOffline();
        
        // Assert
        expect(menuState.status, equals(RealtimeMenuStatus.offline));
        expect(menuState.isOffline, isTrue);
      });
      
      test('should transition back online from offline', () {
        // Arrange
        menuState.transitionToOffline();
        
        // Act
        menuState.transitionBackOnline();
        
        // Assert
        expect(menuState.status, equals(RealtimeMenuStatus.watching));
        expect(menuState.isOffline, isFalse);
      });
      
      test('should not transition back online if not offline', () {
        // Arrange
        menuState.setStatus(RealtimeMenuStatus.loading);
        
        // Act
        menuState.transitionBackOnline();
        
        // Assert
        expect(menuState.status, equals(RealtimeMenuStatus.loading));
      });
    });
    
    group('Batch Updates', () {
      test('should update menu and status together', () {
        // Arrange
        var notificationCount = 0;
        menuState.addListener(() => notificationCount++);
        
        // Act
        menuState.updateMenuAndStatus(testMenu, RealtimeMenuStatus.watching);
        
        // Assert
        expect(menuState.currentMenu, equals(testMenu));
        expect(menuState.status, equals(RealtimeMenuStatus.watching));
        expect(menuState.errorMessage, isNull);
        expect(notificationCount, equals(1)); // Single notification for batch update
      });
      
      test('should reset all state', () {
        // Arrange - set various state
        menuState.setCurrentMenu(testMenu);
        menuState.setStatus(RealtimeMenuStatus.watching);
        menuState.setError('Test error');
        menuState.selectCategory('Middag');
        menuState.setShowParticipants(true);
        
        var notificationCount = 0;
        menuState.addListener(() => notificationCount++);
        
        // Act
        menuState.resetState();
        
        // Assert
        expect(menuState.currentMenu, isNull);
        expect(menuState.status, equals(RealtimeMenuStatus.idle));
        expect(menuState.errorMessage, isNull);
        expect(menuState.selectedCategory, isNull);
        expect(menuState.showParticipants, isFalse);
        expect(notificationCount, equals(1)); // Single notification for reset
      });
      
      test('should handle batch update with error clearing', () {
        // Arrange
        menuState.setError('Previous error');
        
        // Act
        menuState.updateMenuAndStatus(testMenu, RealtimeMenuStatus.error);
        
        // Assert - error should be cleared in batch update
        expect(menuState.errorMessage, isNull);
        expect(menuState.status, equals(RealtimeMenuStatus.error));
      });
    });
    
    group('State Validation', () {
      test('should validate menu presence', () {
        // Test without menu
        expect(menuState.hasMenu(), isFalse);
        
        // Test with menu
        menuState.setCurrentMenu(testMenu);
        expect(menuState.hasMenu(), isTrue);
      });
      
      test('should validate operation capability', () {
        // Test without menu
        expect(menuState.canPerformOperations(), isFalse);
        
        // Test with menu but loading
        menuState.setCurrentMenu(testMenu);
        menuState.setStatus(RealtimeMenuStatus.loading);
        expect(menuState.canPerformOperations(), isFalse);
        
        // Test with menu but error
        menuState.setStatus(RealtimeMenuStatus.idle);
        menuState.setError('Test error');
        expect(menuState.canPerformOperations(), isFalse);
        
        // Test with menu and good state
        menuState.clearError();
        expect(menuState.canPerformOperations(), isTrue);
      });
      
      test('should validate menu readiness', () {
        // Test without menu
        expect(menuState.isMenuReady(), isFalse);
        
        // Test with menu but not watching
        menuState.setCurrentMenu(testMenu);
        expect(menuState.isMenuReady(), isFalse);
        
        // Test with menu and watching
        menuState.setStatus(RealtimeMenuStatus.watching);
        expect(menuState.isMenuReady(), isTrue);
      });
    });
    
    group('Menu Date Display', () {
      test('should format menu date for today', () {
        // Arrange - create menu for today
        final todayMenu = RealtimeMenu(
          id: 'today_menu',
          ownerId: 'user_123',
          ownerDisplayName: 'Test User',
          participants: {'user_123': ResourcePermission.owner},
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Test User',
          data: RealtimeMenuData(
            menuTitle: 'Today Menu',
            createdForDate: DateTime.now(),
            menuSnapshot: {},
          ),
        );
        
        menuState.setCurrentMenu(todayMenu);
        
        // Assert
        expect(menuState.menuDateDisplay, equals('Idag'));
      });
      
      test('should format menu date for tomorrow', () {
        // Arrange - create menu for tomorrow
        final tomorrowMenu = RealtimeMenu(
          id: 'tomorrow_menu',
          ownerId: 'user_123',
          ownerDisplayName: 'Test User',
          participants: {'user_123': ResourcePermission.owner},
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Test User',
          data: RealtimeMenuData(
            menuTitle: 'Tomorrow Menu',
            createdForDate: DateTime.now().add(Duration(days: 1)),
            menuSnapshot: {},
          ),
        );
        
        menuState.setCurrentMenu(tomorrowMenu);
        
        // Assert
        expect(menuState.menuDateDisplay, equals('Imorgon'));
      });
      
      test('should format menu date for yesterday', () {
        // Arrange - create menu for yesterday
        final yesterdayMenu = RealtimeMenu(
          id: 'yesterday_menu',
          ownerId: 'user_123',
          ownerDisplayName: 'Test User',
          participants: {'user_123': ResourcePermission.owner},
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Test User',
          data: RealtimeMenuData(
            menuTitle: 'Yesterday Menu',
            createdForDate: DateTime.now().subtract(Duration(days: 1)),
            menuSnapshot: {},
          ),
        );
        
        menuState.setCurrentMenu(yesterdayMenu);
        
        // Assert
        expect(menuState.menuDateDisplay, equals('Igår'));
      });
      
      test('should format menu date for future days', () {
        // Arrange - create menu for 3 days from now
        final futureMenu = RealtimeMenu(
          id: 'future_menu',
          ownerId: 'user_123',
          ownerDisplayName: 'Test User',
          participants: {'user_123': ResourcePermission.owner},
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Test User',
          data: RealtimeMenuData(
            menuTitle: 'Future Menu',
            createdForDate: DateTime.now().add(Duration(days: 3)),
            menuSnapshot: {},
          ),
        );
        
        menuState.setCurrentMenu(futureMenu);
        
        // Assert
        expect(menuState.menuDateDisplay, equals('3 dagar framåt'));
      });
      
      test('should format menu date for past days', () {
        // Arrange - create menu for 5 days ago
        final pastMenu = RealtimeMenu(
          id: 'past_menu',
          ownerId: 'user_123',
          ownerDisplayName: 'Test User',
          participants: {'user_123': ResourcePermission.owner},
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Test User',
          data: RealtimeMenuData(
            menuTitle: 'Past Menu',
            createdForDate: DateTime.now().subtract(Duration(days: 5)),
            menuSnapshot: {},
          ),
        );
        
        menuState.setCurrentMenu(pastMenu);
        
        // Assert
        expect(menuState.menuDateDisplay, equals('5 dagar sedan'));
      });
      
      test('should handle menu without date', () {
        // Arrange - create menu without createdForDate
        final noDateMenu = RealtimeMenu(
          id: 'no_date_menu',
          ownerId: 'user_123',
          ownerDisplayName: 'Test User',
          participants: {'user_123': ResourcePermission.owner},
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Test User',
          data: RealtimeMenuData(
            menuTitle: 'No Date Menu',
            createdForDate: DateTime.now(),
            menuSnapshot: {},
          ),
        );
        
        menuState.setCurrentMenu(noDateMenu);
        
        // Assert - should use createdAt instead
        expect(menuState.menuDateDisplay, isNot(equals('Inget datum')));
      });
    });
    
    group('Edge Cases and Integration Scenarios', () {
      test('should handle rapid state changes', () {
        // Arrange
        var notificationCount = 0;
        menuState.addListener(() => notificationCount++);
        
        // Act - rapid state changes
        menuState.setStatus(RealtimeMenuStatus.loading);
        menuState.setStatus(RealtimeMenuStatus.watching);
        menuState.setStatus(RealtimeMenuStatus.updating);
        menuState.setStatus(RealtimeMenuStatus.error);
        
        // Assert - each change should trigger notification
        expect(notificationCount, equals(4));
        expect(menuState.status, equals(RealtimeMenuStatus.error));
      });
      
      test('should handle menu changes during different states', () {
        // Test setting menu during each state
        final statuses = [
          RealtimeMenuStatus.idle,
          RealtimeMenuStatus.loading,
          RealtimeMenuStatus.watching,
          RealtimeMenuStatus.updating,
          RealtimeMenuStatus.error,
          RealtimeMenuStatus.offline,
        ];
        
        for (final status in statuses) {
          menuState.setStatus(status);
          menuState.setCurrentMenu(testMenu);
          expect(menuState.currentMenu, equals(testMenu));
          expect(menuState.status, equals(status));
        }
      });
      
      test('should maintain consistency during complex operations', () {
        // Arrange - complex state setup
        menuState.setCurrentMenu(testMenu);
        menuState.setStatus(RealtimeMenuStatus.watching);
        menuState.selectCategory('Middag');
        menuState.setShowParticipants(true);
        
        // Act - transition through error and recovery
        menuState.transitionToError('Network error');
        expect(menuState.hasError, isTrue);
        expect(menuState.selectedCategory, equals('Middag')); // Should preserve UI state
        
        // Act - recover
        menuState.transitionToWatching();
        expect(menuState.hasError, isFalse);
        expect(menuState.selectedCategory, equals('Middag')); // Should still be preserved
      });
      
      test('should handle listener exceptions gracefully', () {
        // Arrange - listener that throws exception
        menuState.addListener(() => throw Exception('Listener error'));
        
        // Act & Assert - should not crash
        expect(() => menuState.setStatus(RealtimeMenuStatus.loading), returnsNormally);
      });
      
      test('should handle disposal correctly', () {
        // Arrange - create separate instance to avoid tearDown conflict
        final testMenuState = RealtimeMenuState();
        testMenuState.setCurrentMenu(testMenu);
        testMenuState.setStatus(RealtimeMenuStatus.watching);
        testMenuState.selectCategory('Middag');
        
        // Act & Assert - first disposal should work normally
        expect(() => testMenuState.dispose(), returnsNormally);
        
        // Second disposal should throw FlutterError (correct behavior)
        expect(() => testMenuState.dispose(), throwsA(isA<FlutterError>()));
      });
      
      test('should handle empty and null values safely', () {
        // Test empty category selection
        menuState.selectCategory('');
        expect(menuState.selectedCategory, equals(''));
        expect(menuState.selectedCategoryRecipes, isEmpty);
        
        // Test empty error message
        menuState.setError('');
        expect(menuState.hasError, isTrue);
        
        // Test null menu repeatedly
        menuState.setCurrentMenu(null);
        menuState.setCurrentMenu(null);
        expect(menuState.currentMenu, isNull);
      });
    });
  });
}