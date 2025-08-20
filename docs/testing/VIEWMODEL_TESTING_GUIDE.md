# 🎯 ViewModel Testing Guide

## Critical Status: 9.3% Coverage (5/54 tested)
**Priority: CRITICAL** - ViewModels control all UI logic and user interactions

## Why ViewModel Testing is Critical

ViewModels are the **brain of your UI** - they:
- Handle all user interactions
- Manage UI state and loading states
- Coordinate between services and views
- Control navigation and dialogs
- Validate user input

**Poor ViewModel testing = Bugs in production UI**

## ViewModel Test Structure

### Base ViewModel Test Pattern
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';

void main() {
  group('YourViewModel', () {
    late YourViewModel viewModel;
    late MockService mockService;
    late MockAuthService mockAuthService;
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Create mocks using factory
      mockService = MockFactory.createUnifiedRecipeService();
      mockAuthService = MockFactory.createAuthService();
      
      // Configure initial states
      mockAuthService.setAuthState(
        isAuthenticated: true,
        currentUser: UserBuilder().build(),
      );
      
      // Register mocks
      TestServiceLocator.registerMock<UnifiedRecipeService>(mockService);
      TestServiceLocator.registerMock<AuthService>(mockAuthService);
      
      // Create ViewModel
      viewModel = YourViewModel();
    });
    
    tearDown(() async {
      viewModel.dispose();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });
    
    // Test categories...
  });
}
```

## Essential ViewModel Test Categories

### 1. Initialization & Loading States
```dart
group('Initialization', () {
  test('should start with loading state', () {
    expect(viewModel.isLoading, isTrue);
    expect(viewModel.hasError, isFalse);
    expect(viewModel.data, isEmpty);
  });
  
  test('should load initial data on init', () async {
    // Arrange
    final testData = [TestModel()];
    when(() => mockService.fetchData())
        .thenAnswer((_) async => testData);
    
    // Act
    await viewModel.initialize();
    
    // Assert
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.data, equals(testData));
    verify(() => mockService.fetchData()).called(1);
  });
});
```

### 2. User Interaction Handling
```dart
group('User Interactions', () {
  test('should handle item selection', () {
    // Arrange
    final item = TestModel(id: '123');
    var notificationCount = 0;
    viewModel.addListener(() => notificationCount++);
    
    // Act
    viewModel.selectItem(item);
    
    // Assert
    expect(viewModel.selectedItem, equals(item));
    expect(notificationCount, greaterThan(0));
  });
  
  test('should handle form submission', () async {
    // Arrange
    viewModel.titleController.text = 'Test Title';
    viewModel.descriptionController.text = 'Test Description';
    
    when(() => mockService.create(any()))
        .thenAnswer((_) async => true);
    
    // Act
    await viewModel.submitForm();
    
    // Assert
    expect(viewModel.isSubmitting, isFalse);
    verify(() => mockService.create(any())).called(1);
  });
});
```

### 3. Validation Logic
```dart
group('Validation', () {
  test('should validate required fields', () {
    // Arrange
    viewModel.titleController.text = '';
    
    // Act
    final isValid = viewModel.validateForm();
    
    // Assert
    expect(isValid, isFalse);
    expect(viewModel.titleError, isNotNull);
  });
  
  test('should validate email format', () {
    // Test various email formats
    expect(viewModel.validateEmail('test@example.com'), isTrue);
    expect(viewModel.validateEmail('invalid'), isFalse);
  });
});
```

### 4. Error Handling & Recovery
```dart
group('Error Handling', () {
  test('should show error when service fails', () async {
    // Arrange
    when(() => mockService.fetchData())
        .thenThrow(Exception('Network error'));
    
    // Act
    await viewModel.loadData();
    
    // Assert
    expect(viewModel.hasError, isTrue);
    expect(viewModel.errorMessage, contains('Network'));
    expect(viewModel.isLoading, isFalse);
  });
  
  test('should retry on user request', () async {
    // Arrange
    viewModel.setError('Initial error');
    when(() => mockService.fetchData())
        .thenAnswer((_) async => testData);
    
    // Act
    await viewModel.retry();
    
    // Assert
    expect(viewModel.hasError, isFalse);
    expect(viewModel.data, isNotEmpty);
  });
});
```

### 5. State Transitions
```dart
group('State Transitions', () {
  test('should transition through states correctly', () async {
    // Track state changes
    final states = <ViewState>[];
    viewModel.addListener(() {
      states.add(viewModel.currentState);
    });
    
    // Trigger state changes
    await viewModel.performComplexOperation();
    
    // Verify state sequence
    expect(states, [
      ViewState.loading,
      ViewState.processing,
      ViewState.success,
    ]);
  });
});
```

### 6. Pagination & Infinite Scroll
```dart
group('Pagination', () {
  test('should load more items when scrolled', () async {
    // Arrange
    final page1 = List.generate(10, (i) => Item(id: '$i'));
    final page2 = List.generate(10, (i) => Item(id: '${i+10}'));
    
    when(() => mockService.fetchPage(1))
        .thenAnswer((_) async => page1);
    when(() => mockService.fetchPage(2))
        .thenAnswer((_) async => page2);
    
    // Act
    await viewModel.loadInitial();
    await viewModel.loadMore();
    
    // Assert
    expect(viewModel.items, hasLength(20));
    expect(viewModel.hasMore, isTrue);
  });
});
```

## Priority ViewModels to Test

### Critical User Paths (15 ViewModels)
1. **recipe_form_viewmodel.dart** - Recipe creation/editing
2. **recipe_detail_viewmodel.dart** - Recipe viewing
3. **recipe_list_viewmodel.dart** - Recipe browsing
4. **unified_shopping_viewmodel.dart** - Shopping list management
5. **collaborative_shopping_viewmodel.dart** - Shared shopping
6. **chat_viewmodel.dart** - Messaging
7. **conversations_viewmodel.dart** - Chat list
8. **import_base_viewmodel.dart** - Recipe import
9. **url_import_viewmodel.dart** - Web scraping
10. **user_profile_viewmodel.dart** - User settings
11. **realtime_menu_viewmodel.dart** - Menu planning
12. **social_recipe_viewmodel.dart** - Recipe sharing
13. **discovery_dashboard_viewmodel.dart** - Content discovery
14. **group_content_viewmodel.dart** - Group features
15. **shared_content_viewmodel.dart** - Shared items

### Secondary Priority (20 ViewModels)
- Archive import
- Photo import
- Text import
- Friend management
- Group creation
- Invitations
- Recipe selection
- Menu sub-ViewModels
- Realtime sub-ViewModels

## Common ViewModel Testing Patterns

### Testing Loading States
```dart
test('should manage loading states correctly', () async {
  // Initially loading
  expect(viewModel.isLoading, isTrue);
  
  // Start async operation
  final future = viewModel.loadData();
  expect(viewModel.isLoading, isTrue);
  
  // Complete operation
  await future;
  expect(viewModel.isLoading, isFalse);
});
```

### Testing Debounced Actions
```dart
test('should debounce search input', () async {
  // Type quickly
  viewModel.onSearchChanged('a');
  viewModel.onSearchChanged('ab');
  viewModel.onSearchChanged('abc');
  
  // Wait for debounce
  await Future.delayed(Duration(milliseconds: 500));
  
  // Should only search once
  verify(() => mockService.search('abc')).called(1);
});
```

### Testing Navigation
```dart
test('should navigate to detail on item tap', () {
  // Arrange
  final item = Item(id: '123');
  
  // Act
  viewModel.onItemTap(item);
  
  // Assert
  expect(viewModel.navigationEvents, contains(
    NavigationEvent.detail(itemId: '123'),
  ));
});
```

### Testing Disposal
```dart
test('should clean up resources on dispose', () {
  // Arrange
  final subscription = viewModel.dataStream.listen((_) {});
  
  // Act
  viewModel.dispose();
  
  // Assert
  expect(viewModel.isDisposed, isTrue);
  expect(() => viewModel.notifyListeners(), throwsFlutterError);
});
```

## ViewModel-Specific Examples

### RecipeFormViewModel
```dart
test('should validate recipe before saving', () async {
  // Missing required field
  viewModel.titleController.text = '';
  
  final result = await viewModel.saveRecipe();
  
  expect(result, isFalse);
  expect(viewModel.validationErrors, isNotEmpty);
  verifyNever(() => mockService.saveRecipe(any()));
});
```

### UnifiedShoppingViewModel
```dart
test('should sync shopping list changes', () async {
  // Add item
  await viewModel.addItem('Milk');
  
  // Should update local state
  expect(viewModel.items, contains('Milk'));
  
  // Should sync to service
  verify(() => mockService.addShoppingItem('Milk')).called(1);
});
```

### ChatViewModel
```dart
test('should mark messages as read when viewed', () async {
  // Arrange
  final unreadMessages = [Message(id: '1', read: false)];
  mockService.setMessages(unreadMessages);
  
  // Act
  await viewModel.initialize();
  
  // Assert
  verify(() => mockService.markAsRead(['1'])).called(1);
});
```

## Testing Checklist for ViewModels

### Must Test
- [ ] **Initialization**: Correct initial state
- [ ] **Loading States**: isLoading, isRefreshing, etc.
- [ ] **Error States**: hasError, errorMessage
- [ ] **User Actions**: All button taps, form submissions
- [ ] **Validation**: All form validation logic
- [ ] **State Changes**: notifyListeners called appropriately
- [ ] **Cleanup**: dispose() releases resources

### Should Test
- [ ] **Navigation**: Navigation events triggered
- [ ] **Permissions**: Auth checks before actions
- [ ] **Concurrency**: No race conditions
- [ ] **Edge Cases**: Empty lists, null values
- [ ] **Performance**: No unnecessary rebuilds

### Nice to Have
- [ ] **Animations**: Animation controllers
- [ ] **Accessibility**: Screen reader support
- [ ] **Localization**: Translated strings

## Anti-Patterns to Avoid

### ❌ DON'T
```dart
// Don't test Flutter widgets in ViewModel tests
test('should render correctly', () {
  // This belongs in widget tests!
});

// Don't test service implementation
test('should query database', () {
  // Test the ViewModel's use of the service, not the service itself
});

// Don't skip dispose testing
// ViewModels often have subscriptions that must be cleaned up
```

### ✅ DO
```dart
// Test ViewModel logic
test('should calculate total price with tax', () {
  viewModel.setItems([Item(price: 10), Item(price: 20)]);
  expect(viewModel.totalWithTax, equals(33)); // 30 + 10% tax
});

// Test state management
test('should notify listeners when data changes', () {
  var notified = false;
  viewModel.addListener(() => notified = true);
  viewModel.updateData();
  expect(notified, isTrue);
});
```

## Coverage Goals

### Per ViewModel
- **Minimum 5 tests** per ViewModel
- **All public methods** tested
- **All user interactions** tested
- **Critical ViewModels**: 10+ tests

### Overall Goals
1. **Immediate**: Test 15 critical ViewModels (28% coverage)
2. **Week 1**: Achieve 50% coverage (27/54)
3. **Week 2**: Achieve 80% coverage (43/54)
4. **Goal**: 90% coverage with 250+ tests

## Running ViewModel Tests

```bash
# Run all ViewModel tests
cmd.exe /c "flutter test test/unit/viewmodels/"

# Run specific ViewModel test
cmd.exe /c "flutter test test/unit/viewmodels/recipe_form_viewmodel_test.dart"

# With coverage
cmd.exe /c "flutter test --coverage test/unit/viewmodels/"
```

---
*Created: January 2025*
*Current Coverage: 9.3% (5/54) - CRITICAL GAP*
*Target: 90% coverage ensuring robust UI logic*