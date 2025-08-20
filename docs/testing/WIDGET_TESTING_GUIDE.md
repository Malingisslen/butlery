# 🎨 Widget Testing Guide

## Current Status: 0% Coverage (0 widget tests)
**Priority: MEDIUM** - After fixing service and ViewModel gaps

## Why Widget Testing Matters

Widget tests verify that your UI:
- Renders correctly with different data states
- Responds to user interactions properly
- Shows appropriate loading and error states
- Maintains accessibility standards
- Works across different screen sizes

## Widget Test Structure

### Basic Widget Test Pattern
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  group('WidgetName', () {
    late MockViewModel mockViewModel;
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      mockViewModel = MockViewModel();
      // Configure initial state
      mockViewModel.setViewModelState(
        isLoading: false,
        data: [],
      );
    });
    
    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });
    
    Widget createTestWidget({Widget? child}) {
      return MaterialApp(
        home: ChangeNotifierProvider<ViewModel>.value(
          value: mockViewModel,
          child: child ?? WidgetUnderTest(),
        ),
      );
    }
    
    // Tests follow...
  });
}
```

## Essential Widget Test Categories

### 1. Initial Rendering
```dart
group('Initial Rendering', () {
  testWidgets('should display correctly with data', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(
      data: [Item(title: 'Test Item')],
    );
    
    // Act
    await tester.pumpWidget(createTestWidget());
    
    // Assert
    expect(find.text('Test Item'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });
  
  testWidgets('should show empty state', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(data: []);
    
    // Act
    await tester.pumpWidget(createTestWidget());
    
    // Assert
    expect(find.text('No items found'), findsOneWidget);
    expect(find.byIcon(Icons.inbox), findsOneWidget);
  });
});
```

### 2. Loading States
```dart
group('Loading States', () {
  testWidgets('should show loading indicator', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(isLoading: true);
    
    // Act
    await tester.pumpWidget(createTestWidget());
    
    // Assert
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Test Item'), findsNothing);
  });
  
  testWidgets('should hide loading when complete', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(isLoading: true);
    await tester.pumpWidget(createTestWidget());
    
    // Act
    mockViewModel.setViewModelState(
      isLoading: false,
      data: [Item()],
    );
    await tester.pump();
    
    // Assert
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
});
```

### 3. User Interactions
```dart
group('User Interactions', () {
  testWidgets('should handle tap on item', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(
      data: [Item(id: '123', title: 'Tap Me')],
    );
    
    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('Tap Me'));
    await tester.pump();
    
    // Assert
    verify(() => mockViewModel.onItemTap('123')).called(1);
  });
  
  testWidgets('should submit form on button press', (tester) async {
    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.enterText(find.byType(TextField), 'Test Input');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    
    // Assert
    verify(() => mockViewModel.submitForm('Test Input')).called(1);
  });
});
```

### 4. Error States
```dart
group('Error States', () {
  testWidgets('should display error message', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(
      hasError: true,
      errorMessage: 'Network error occurred',
    );
    
    // Act
    await tester.pumpWidget(createTestWidget());
    
    // Assert
    expect(find.text('Network error occurred'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);
  });
  
  testWidgets('should show retry button on error', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(hasError: true);
    
    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('Retry'));
    
    // Assert
    verify(() => mockViewModel.retry()).called(1);
  });
});
```

### 5. Form Validation
```dart
group('Form Validation', () {
  testWidgets('should show validation errors', (tester) async {
    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('Submit'));
    await tester.pump();
    
    // Assert
    expect(find.text('Title is required'), findsOneWidget);
  });
  
  testWidgets('should enable submit when valid', (tester) async {
    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.enterText(
      find.byKey(Key('title_field')),
      'Valid Title',
    );
    await tester.pump();
    
    // Assert
    final submitButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(submitButton.onPressed, isNotNull);
  });
});
```

## Priority Widgets to Test

### Critical User Interface Components (20 widgets)
1. **RecipeCard** - Most viewed component
2. **RecipeForm** - Recipe creation/editing
3. **ShoppingListItem** - Shopping list interaction
4. **ChatMessage** - Message display
5. **SearchBar** - Search functionality
6. **NavigationDrawer** - Main navigation
7. **BottomNavBar** - Tab navigation
8. **LoadingOverlay** - Loading states
9. **ErrorWidget** - Error display
10. **EmptyStateWidget** - Empty states
11. **RecipeDetailHeader** - Recipe viewing
12. **IngredientsList** - Ingredients display
13. **InstructionsList** - Instructions display
14. **CommentSection** - Social features
15. **RatingWidget** - Rating display/input
16. **ShareDialog** - Sharing functionality
17. **FilterChips** - Filtering UI
18. **UserAvatar** - User display
19. **NotificationCard** - Notifications
20. **MenuDayCard** - Menu planning

### Screen-Level Tests (10 screens)
1. **HomeScreen** - Main entry point
2. **RecipeDetailScreen** - Core viewing
3. **RecipeFormScreen** - Core editing
4. **ShoppingListScreen** - Shopping feature
5. **ProfileScreen** - User management
6. **ChatScreen** - Messaging
7. **DiscoveryScreen** - Content discovery
8. **MenuPlannerScreen** - Menu planning
9. **ImportScreen** - Import functionality
10. **SettingsScreen** - App configuration

## Common Widget Testing Patterns

### Testing Scrollable Content
```dart
testWidgets('should scroll to load more items', (tester) async {
  // Arrange
  mockViewModel.setViewModelState(
    data: List.generate(20, (i) => Item(id: '$i')),
  );
  
  // Act
  await tester.pumpWidget(createTestWidget());
  await tester.drag(find.byType(ListView), Offset(0, -500));
  await tester.pump();
  
  // Assert
  verify(() => mockViewModel.loadMore()).called(1);
});
```

### Testing Animations
```dart
testWidgets('should animate on state change', (tester) async {
  // Act
  await tester.pumpWidget(createTestWidget());
  mockViewModel.triggerAnimation();
  
  // Pump frames for animation
  await tester.pump();
  await tester.pump(Duration(milliseconds: 500));
  
  // Assert
  final opacity = tester.widget<AnimatedOpacity>(
    find.byType(AnimatedOpacity),
  );
  expect(opacity.opacity, equals(1.0));
});
```

### Testing Dialogs
```dart
testWidgets('should show confirmation dialog', (tester) async {
  // Act
  await tester.pumpWidget(createTestWidget());
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();
  
  // Assert
  expect(find.text('Are you sure?'), findsOneWidget);
  expect(find.text('Cancel'), findsOneWidget);
  expect(find.text('Confirm'), findsOneWidget);
});
```

### Testing Navigation
```dart
testWidgets('should navigate to detail screen', (tester) async {
  // Arrange
  final navigatorKey = GlobalKey<NavigatorState>();
  
  // Act
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: WidgetUnderTest(),
      routes: {
        '/detail': (_) => DetailScreen(),
      },
    ),
  );
  await tester.tap(find.text('View Details'));
  await tester.pumpAndSettle();
  
  // Assert
  expect(find.byType(DetailScreen), findsOneWidget);
});
```

## Widget Test Best Practices

### DO ✅
```dart
// Use testWidgets for async widget tests
testWidgets('description', (tester) async {
  // Test implementation
});

// Use pumpAndSettle for animations
await tester.pumpAndSettle();

// Use Keys for finding specific widgets
await tester.tap(find.byKey(Key('submit_button')));

// Test accessibility
expect(
  tester.getSemantics(find.text('Title')),
  matchesSemantics(label: 'Recipe title'),
);
```

### DON'T ❌
```dart
// Don't test implementation details
verify(() => mockViewModel._privateMethod()); // Bad!

// Don't use arbitrary delays
await Future.delayed(Duration(seconds: 1)); // Bad!

// Don't test framework behavior
expect(find.byType(Container), findsWidgets); // Pointless!

// Don't ignore golden tests for complex UIs
// Add golden tests for important screens
```

## Golden Tests for Visual Regression

```dart
testWidgets('should match golden file', (tester) async {
  // Arrange
  await tester.pumpWidget(createTestWidget());
  
  // Act & Assert
  await expectLater(
    find.byType(RecipeCard),
    matchesGoldenFile('goldens/recipe_card.png'),
  );
});
```

Update golden files:
```bash
cmd.exe /c "flutter test --update-goldens"
```

## Testing Different Screen Sizes

```dart
testWidgets('should adapt to tablet size', (tester) async {
  // Set tablet size
  tester.binding.window.physicalSizeTestValue = Size(1024, 768);
  tester.binding.window.devicePixelRatioTestValue = 1.0;
  
  // Act
  await tester.pumpWidget(createTestWidget());
  
  // Assert - Should show master-detail layout
  expect(find.byType(MasterDetailView), findsOneWidget);
  
  // Clean up
  addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
});
```

## Widget Testing Checklist

### Per Widget
- [ ] **Renders correctly** with valid data
- [ ] **Handles empty state** appropriately
- [ ] **Shows loading state** when loading
- [ ] **Displays errors** clearly
- [ ] **Responds to taps** correctly
- [ ] **Validates input** if applicable
- [ ] **Accessible** with semantic labels
- [ ] **Responsive** to different screen sizes

### Per Screen
- [ ] **Navigation works** between screens
- [ ] **State preserved** on navigation
- [ ] **Dialogs display** correctly
- [ ] **Keyboard handling** for forms
- [ ] **Scroll behavior** correct
- [ ] **Pull to refresh** if applicable

## Coverage Goals

### Initial Phase (Week 1)
- Test 20 critical components
- Test 5 main screens
- Achieve 30% widget coverage

### Phase 2 (Week 2)
- Test remaining components
- Test all screens
- Add golden tests
- Achieve 60% widget coverage

### Final Goal
- 80% widget coverage
- All critical paths tested
- Visual regression tests
- Accessibility verified

## Running Widget Tests

```bash
# Run all widget tests
cmd.exe /c "flutter test test/widget/"

# Run specific widget test
cmd.exe /c "flutter test test/widget/components/recipe_card_test.dart"

# Update golden files
cmd.exe /c "flutter test --update-goldens test/widget/"

# With coverage
cmd.exe /c "flutter test --coverage test/widget/"
```

## Project Structure for Widget Tests

```
test/widget/
├── components/           # Reusable component tests
│   ├── recipe_card_test.dart
│   ├── shopping_list_item_test.dart
│   └── ...
├── screens/             # Full screen tests
│   ├── home_screen_test.dart
│   ├── recipe_detail_screen_test.dart
│   └── ...
├── dialogs/            # Dialog tests
│   ├── share_dialog_test.dart
│   └── ...
└── goldens/            # Golden test files
    ├── recipe_card.png
    └── ...
```

---
*Created: January 2025*
*Current Coverage: 0% (0 widget tests)*
*Target: 80% coverage for robust UI testing*