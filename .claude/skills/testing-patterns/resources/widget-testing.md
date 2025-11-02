# Widget Testing Patterns

Widget testing in Flutter validates UI behavior, user interactions, and widget composition. This guide covers Butlery-specific widget testing patterns.

## Testing Philosophy

Widget tests verify:
- UI renders correctly with different data states
- User interactions trigger expected behavior
- Navigation flows work as intended
- Forms validate and submit correctly
- Error states display appropriately

## Basic Widget Test Structure

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  group('RecipeCard', () {
    testWidgets('displays recipe title and portions', (tester) async {
      // Arrange
      final recipe = Recipe(
        id: '1',
        title: 'Pasta Carbonara',
        portions: 4,
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipeCard(recipe: recipe),
          ),
        ),
      );

      // Assert
      expect(find.text('Pasta Carbonara'), findsOneWidget);
      expect(find.text('4 portions'), findsOneWidget);
    });
  });
}
```

## Finding Widgets

Flutter provides multiple finders for locating widgets:

```dart
// Find by text
expect(find.text('Save'), findsOneWidget);

// Find by type
expect(find.byType(ElevatedButton), findsOneWidget);

// Find by key (use for dynamic content)
expect(find.byKey(Key('recipe_1')), findsOneWidget);

// Find by icon
expect(find.byIcon(Icons.delete), findsOneWidget);

// Find widgets by predicate
expect(find.byWidgetPredicate((widget) =>
  widget is Text && widget.data?.contains('Error') == true
), findsOneWidget);

// Multiple matches
expect(find.byType(RecipeCard), findsNWidgets(3));
expect(find.text('Loading'), findsNothing);
```

## Pumping Widgets

Control widget rebuild cycles and animations:

```dart
testWidgets('shows loading state then content', (tester) async {
  // Initial pump - builds widget tree
  await tester.pumpWidget(buildWidget());

  // Verify loading state
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  // Pump again to process pending timers/futures
  await tester.pump();

  // Skip ahead in time
  await tester.pump(Duration(seconds: 1));

  // Pump until all animations complete
  await tester.pumpAndSettle();

  // Verify content loaded
  expect(find.text('Recipe Title'), findsOneWidget);
});
```

**pump() vs pumpAndSettle():**
- `pump()`: Single frame rebuild (use for controlled steps)
- `pumpAndSettle()`: Waits for all animations/timers (use after interactions)

## Interaction Testing

Simulate user interactions:

```dart
testWidgets('delete button shows confirmation dialog', (tester) async {
  await tester.pumpWidget(buildWidget());

  // Tap a button
  await tester.tap(find.byIcon(Icons.delete));
  await tester.pumpAndSettle();

  // Verify dialog appears
  expect(find.text('Delete Recipe?'), findsOneWidget);

  // Tap confirm
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();
});

testWidgets('entering text updates field', (tester) async {
  await tester.pumpWidget(buildWidget());

  // Enter text
  await tester.enterText(find.byType(TextField), 'New Recipe Name');
  await tester.pump();

  // Verify text appears
  expect(find.text('New Recipe Name'), findsOneWidget);
});

testWidgets('scrolling loads more items', (tester) async {
  await tester.pumpWidget(buildWidget());

  // Scroll down
  await tester.drag(find.byType(ListView), Offset(0, -300));
  await tester.pumpAndSettle();

  // Verify more items loaded
  expect(find.byType(RecipeCard), findsNWidgets(15));
});

testWidgets('long press shows context menu', (tester) async {
  await tester.pumpWidget(buildWidget());

  // Long press
  await tester.longPress(find.byType(RecipeCard).first);
  await tester.pumpAndSettle();

  expect(find.text('Edit'), findsOneWidget);
  expect(find.text('Delete'), findsOneWidget);
});
```

## Testing with Provider

Test widgets that depend on ChangeNotifier ViewModels:

```dart
testWidgets('displays recipes from ViewModel', (tester) async {
  // Arrange
  final mockViewModel = MockRecipeViewModel();
  when(() => mockViewModel.recipes).thenReturn([
    Recipe(id: '1', title: 'Recipe 1'),
    Recipe(id: '2', title: 'Recipe 2'),
  ]);
  when(() => mockViewModel.isLoading).thenReturn(false);

  // Act
  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<RecipeViewModel>.value(
        value: mockViewModel,
        child: RecipeListView(),
      ),
    ),
  );

  // Assert
  expect(find.text('Recipe 1'), findsOneWidget);
  expect(find.text('Recipe 2'), findsOneWidget);
});

testWidgets('calls ViewModel method on button tap', (tester) async {
  final mockViewModel = MockRecipeViewModel();
  when(() => mockViewModel.deleteRecipe(any())).thenAnswer((_) async {});

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<RecipeViewModel>.value(
        value: mockViewModel,
        child: RecipeDetailView(recipeId: '1'),
      ),
    ),
  );

  // Tap delete button
  await tester.tap(find.byIcon(Icons.delete));
  await tester.pumpAndSettle();

  // Tap confirm in dialog
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();

  // Verify ViewModel method called
  verify(() => mockViewModel.deleteRecipe('1')).called(1);
});
```

## Testing ViewModel State Changes

Verify widget updates when ViewModel notifies listeners:

```dart
testWidgets('rebuilds when ViewModel changes', (tester) async {
  final viewModel = RecipeViewModel();

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<RecipeViewModel>.value(
        value: viewModel,
        child: RecipeListView(),
      ),
    ),
  );

  // Initial state - loading
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  // Simulate data load
  viewModel.setRecipes([
    Recipe(id: '1', title: 'Loaded Recipe'),
  ]);
  await tester.pump(); // Rebuild after notifyListeners

  // Verify UI updated
  expect(find.byType(CircularProgressIndicator), findsNothing);
  expect(find.text('Loaded Recipe'), findsOneWidget);
});
```

## Form Testing

Test form validation and submission:

```dart
testWidgets('validates required fields', (tester) async {
  final mockViewModel = MockRecipeFormViewModel();

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<RecipeFormViewModel>.value(
        value: mockViewModel,
        child: RecipeFormView(),
      ),
    ),
  );

  // Try to submit without entering data
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();

  // Verify validation errors appear
  expect(find.text('Title is required'), findsOneWidget);
  expect(find.text('Portions must be at least 1'), findsOneWidget);
});

testWidgets('submits form with valid data', (tester) async {
  final mockViewModel = MockRecipeFormViewModel();
  when(() => mockViewModel.saveRecipe()).thenAnswer((_) async => true);

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<RecipeFormViewModel>.value(
        value: mockViewModel,
        child: RecipeFormView(),
      ),
    ),
  );

  // Enter valid data
  await tester.enterText(
    find.byKey(Key('title_field')),
    'New Recipe',
  );
  await tester.enterText(
    find.byKey(Key('portions_field')),
    '4',
  );

  // Submit form
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();

  // Verify save method called
  verify(() => mockViewModel.saveRecipe()).called(1);
});
```

## Navigation Testing

Test navigation flows and route transitions:

```dart
testWidgets('navigates to detail view on tap', (tester) async {
  final mockRouter = MockAppRouter();

  await tester.pumpWidget(
    MaterialApp(
      home: Provider<AppRouter>.value(
        value: mockRouter,
        child: RecipeListView(),
      ),
    ),
  );

  // Tap recipe card
  await tester.tap(find.byType(RecipeCard).first);
  await tester.pumpAndSettle();

  // Verify navigation called
  verify(() => mockRouter.push(RecipeDetailRoute(recipeId: '1'))).called(1);
});

testWidgets('back button pops route', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RecipeDetailView(recipeId: '1'),
    ),
  );

  // Tap back button
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();

  // Verify returned to previous route
  expect(find.byType(RecipeDetailView), findsNothing);
});
```

## Stream and AsyncSnapshot Testing

Test widgets that consume streams:

```dart
testWidgets('displays stream data', (tester) async {
  final controller = StreamController<List<Recipe>>();

  await tester.pumpWidget(
    MaterialApp(
      home: StreamBuilder<List<Recipe>>(
        stream: controller.stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return CircularProgressIndicator();
          }
          return RecipeList(recipes: snapshot.data!);
        },
      ),
    ),
  );

  // Initial state - no data
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  // Emit data
  controller.add([Recipe(id: '1', title: 'Stream Recipe')]);
  await tester.pump(); // Process stream event

  // Verify data displayed
  expect(find.byType(CircularProgressIndicator), findsNothing);
  expect(find.text('Stream Recipe'), findsOneWidget);

  controller.close();
});

testWidgets('handles stream errors', (tester) async {
  final controller = StreamController<List<Recipe>>();

  await tester.pumpWidget(
    MaterialApp(
      home: StreamBuilder<List<Recipe>>(
        stream: controller.stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          }
          return CircularProgressIndicator();
        },
      ),
    ),
  );

  // Emit error
  controller.addError('Failed to load');
  await tester.pump();

  // Verify error displayed
  expect(find.textContaining('Error: Failed to load'), findsOneWidget);

  controller.close();
});
```

## Testing Conditional UI

Test different UI states based on data:

```dart
testWidgets('shows empty state when no recipes', (tester) async {
  final mockViewModel = MockRecipeViewModel();
  when(() => mockViewModel.recipes).thenReturn([]);
  when(() => mockViewModel.isLoading).thenReturn(false);

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<RecipeViewModel>.value(
        value: mockViewModel,
        child: RecipeListView(),
      ),
    ),
  );

  expect(find.text('No recipes yet'), findsOneWidget);
  expect(find.byType(RecipeCard), findsNothing);
});

testWidgets('shows error state on failure', (tester) async {
  final mockViewModel = MockRecipeViewModel();
  when(() => mockViewModel.hasError).thenReturn(true);
  when(() => mockViewModel.errorMessage).thenReturn('Network error');

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<RecipeViewModel>.value(
        value: mockViewModel,
        child: RecipeListView(),
      ),
    ),
  );

  expect(find.textContaining('Network error'), findsOneWidget);
  expect(find.byIcon(Icons.error), findsOneWidget);
});
```

## Testing Dialogs and Bottom Sheets

```dart
testWidgets('shows confirmation dialog', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RecipeDetailView(recipeId: '1'),
    ),
  );

  // Tap delete
  await tester.tap(find.byIcon(Icons.delete));
  await tester.pumpAndSettle();

  // Verify dialog appears
  expect(find.byType(AlertDialog), findsOneWidget);
  expect(find.text('Delete Recipe?'), findsOneWidget);
  expect(find.text('Cancel'), findsOneWidget);
  expect(find.text('Delete'), findsOneWidget);

  // Dismiss dialog
  await tester.tap(find.text('Cancel'));
  await tester.pumpAndSettle();

  // Verify dialog dismissed
  expect(find.byType(AlertDialog), findsNothing);
});

testWidgets('shows bottom sheet', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RecipeListView(),
    ),
  );

  // Tap share button
  await tester.tap(find.byIcon(Icons.share));
  await tester.pumpAndSettle();

  // Verify bottom sheet appears
  expect(find.byType(BottomSheet), findsOneWidget);
  expect(find.text('Share with Friends'), findsOneWidget);
});
```

## Testing Lists and Infinite Scroll

```dart
testWidgets('loads more items on scroll', (tester) async {
  final mockViewModel = MockRecipeViewModel();
  when(() => mockViewModel.recipes).thenReturn(
    List.generate(20, (i) => Recipe(id: '$i', title: 'Recipe $i')),
  );
  when(() => mockViewModel.loadMore()).thenAnswer((_) async {});

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<RecipeViewModel>.value(
        value: mockViewModel,
        child: RecipeListView(),
      ),
    ),
  );

  // Scroll to bottom
  await tester.dragUntilVisible(
    find.text('Recipe 19'),
    find.byType(ListView),
    Offset(0, -300),
  );
  await tester.pumpAndSettle();

  // Verify loadMore called
  verify(() => mockViewModel.loadMore()).called(greaterThanOrEqualTo(1));
});
```

## Testing Custom Widgets

Test reusable custom widgets in isolation:

```dart
testWidgets('IngredientListItem displays correctly', (tester) async {
  final ingredient = Ingredient(
    name: 'Flour',
    amount: '2',
    unit: 'cups',
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: IngredientListItem(
          ingredient: ingredient,
          onTap: () {},
        ),
      ),
    ),
  );

  expect(find.text('Flour'), findsOneWidget);
  expect(find.text('2 cups'), findsOneWidget);
});

testWidgets('IngredientListItem calls callback on tap', (tester) async {
  var tapped = false;
  final ingredient = Ingredient(name: 'Salt', amount: '1', unit: 'tsp');

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: IngredientListItem(
          ingredient: ingredient,
          onTap: () => tapped = true,
        ),
      ),
    ),
  );

  await tester.tap(find.byType(IngredientListItem));
  expect(tapped, isTrue);
});
```

## Common Widget Test Patterns

### Helper Method for Building Test Widgets

```dart
Widget buildTestWidget({
  required Widget child,
  RecipeViewModel? viewModel,
}) {
  return MaterialApp(
    home: viewModel != null
        ? ChangeNotifierProvider<RecipeViewModel>.value(
            value: viewModel,
            child: child,
          )
        : child,
  );
}

// Usage
testWidgets('test example', (tester) async {
  await tester.pumpWidget(
    buildTestWidget(
      viewModel: mockViewModel,
      child: RecipeListView(),
    ),
  );
});
```

### Testing Loading States

```dart
testWidgets('shows loading indicator', (tester) async {
  final mockViewModel = MockRecipeViewModel();
  when(() => mockViewModel.isLoading).thenReturn(true);

  await tester.pumpWidget(buildTestWidget(
    viewModel: mockViewModel,
    child: RecipeListView(),
  ));

  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```

### Testing Error States

```dart
testWidgets('displays error message', (tester) async {
  final mockViewModel = MockRecipeViewModel();
  when(() => mockViewModel.hasError).thenReturn(true);
  when(() => mockViewModel.errorMessage).thenReturn('Failed to load recipes');

  await tester.pumpWidget(buildTestWidget(
    viewModel: mockViewModel,
    child: RecipeListView(),
  ));

  expect(find.textContaining('Failed to load recipes'), findsOneWidget);
});
```

## Best Practices

1. **Use Keys for Dynamic Content**: When testing lists or dynamic widgets, use Keys to reliably find specific items
2. **Await pumpAndSettle**: Always await pumpAndSettle() after interactions to ensure animations complete
3. **Test User Flows**: Focus on complete user interactions, not individual widgets in isolation
4. **Mock ViewModels**: Test widget behavior independently from business logic
5. **Test Error States**: Verify widgets handle loading, error, and empty states correctly
6. **Keep Tests Focused**: One test per scenario - don't test multiple behaviors in a single test
7. **Use Descriptive Test Names**: Clearly describe what is being tested

## Common Pitfalls

**Don't forget MaterialApp wrapper:**
```dart
// ❌ Wrong - widget needs material ancestor
await tester.pumpWidget(RecipeCard(recipe: recipe));

// ✅ Correct
await tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: RecipeCard(recipe: recipe)),
  ),
);
```

**Don't forget to pump after state changes:**
```dart
// ❌ Wrong - won't see state change
viewModel.setRecipes([]);
expect(find.text('No recipes'), findsOneWidget); // Fails!

// ✅ Correct
viewModel.setRecipes([]);
await tester.pump(); // Rebuild after notifyListeners
expect(find.text('No recipes'), findsOneWidget); // Passes
```

**Don't test implementation details:**
```dart
// ❌ Wrong - testing internal widget structure
expect(find.byType(Container), findsNWidgets(5));

// ✅ Correct - testing user-visible behavior
expect(find.text('Recipe Title'), findsOneWidget);
expect(find.byIcon(Icons.favorite), findsOneWidget);
```

## Related Resources

- [ViewModel Testing](viewmodel-testing.md) - Testing ViewModels that power widgets
- [Service Testing](service-testing.md) - Testing business logic layer
- [Integration Testing](integration-testing.md) - End-to-end user flow testing
