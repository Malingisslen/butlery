# Flutter Widget Guidelines

Comprehensive guide to Butlery's Flutter widget patterns, including LoadingStateBuilder, StateWidget, facade pattern, and common widget library.

## Overview

Butlery uses consistent widget patterns for:
- **State Display**: LoadingStateBuilder and StateWidget
- **Widget Composition**: Facade pattern for complex UIs
- **Reusable Components**: Common widget library (widgets/common/)
- **Builder Pattern**: Flexible rendering with builder functions
- **Swedish Localization**: All UI text in Swedish

## Core Patterns

### 5 Widget Patterns

```
1. LoadingStateBuilder
   └─> Automatic state detection (15+ views)
       └─> loading/error/empty/data states

2. StateWidget
   └─> Factory constructors for common states
       └─> StateWidget.loading(), .error(), .empty()

3. Facade Widget Pattern
   └─> Complex UIs split into focused sub-widgets
       └─> Single responsibility, <500 lines

4. Builder Pattern
   └─> Widgets accept builder functions
       └─> Flexible rendering, reusable components

5. Common Widget Library
   └─> 100+ reusable components
       └─> widgets/common/ organized by category
```

## Quick Reference

### Using LoadingStateBuilder

```dart
class RecipeListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<RecipeViewModel>(
      builder: (context, viewModel, _) {
        return LoadingStateBuilder<List<Recipe>>(
          isLoading: viewModel.isLoading,
          error: viewModel.error,
          data: viewModel.recipes,
          builder: (context, recipes) {
            return ListView.builder(
              itemCount: recipes.length,
              itemBuilder: (context, i) => RecipeCard(recipes[i]),
            );
          },
          emptyState: EmptyStateVariant.noRecipes,
          onEmptyAction: () => viewModel.createRecipe(),
        );
      },
    );
  }
}
```

### Using StateWidget

```dart
// Loading state
StateWidget.loading(message: 'Laddar recept...')

// Error state with retry
StateWidget.error(
  message: 'Kunde inte ladda recept',
  onAction: () => viewModel.retry(),
  actionLabel: 'Försök igen',
)

// Empty state
StateWidget.empty(
  title: 'Inga recept',
  message: 'Lägg till ditt första recept',
  icon: Icons.receipt_long,
)

// Preset empty states
StateWidget.noRecipes(onAction: () => createRecipe())
StateWidget.noFriends(onAction: () => searchFriends())
```

## When to Use This Skill

Auto-activates when:
- Creating or modifying widgets
- Building UI layouts
- Working with stateless/stateful widgets
- Implementing loading/error states
- Creating reusable components

## Deep Dive Resources

Explore specific widget patterns:

1. **[LoadingStateBuilder Pattern](resources/loading-state-builder.md)**
   - Automatic state detection
   - Builder function usage
   - Empty state handling
   - Error state with retry
   - Loading indicators

2. **[StateWidget Factory](resources/state-widget.md)**
   - Factory constructors
   - Preset empty states
   - Skeleton loading states
   - Swedish localization
   - Custom state widgets

3. **[Widget Composition](resources/widget-composition.md)**
   - Facade pattern for complex widgets
   - Single-responsibility widgets
   - Widget extraction patterns
   - Component organization
   - Testing composite widgets

4. **[Common Widgets Library](resources/common-widgets.md)**
   - widgets/common/ structure
   - Dialogs and buttons
   - Indicators and layouts
   - Input components
   - Social widgets

## Critical Rules

### ALWAYS Use LoadingStateBuilder for State Management

```dart
// ❌ WRONG - Manual state checking
if (viewModel.isLoading) {
  return CircularProgressIndicator();
} else if (viewModel.hasError) {
  return Text('Error: ${viewModel.error}');
} else if (viewModel.recipes.isEmpty) {
  return Text('No recipes');
} else {
  return RecipeList(viewModel.recipes);
}

// ✅ CORRECT - LoadingStateBuilder handles all states
return LoadingStateBuilder<List<Recipe>>(
  isLoading: viewModel.isLoading,
  error: viewModel.error,
  data: viewModel.recipes,
  builder: (context, recipes) => RecipeList(recipes),
  emptyState: EmptyStateVariant.noRecipes,
);
```

### ALWAYS Extract Large Widgets into Smaller Components

```dart
// ❌ WRONG - 800-line widget with everything
class RecipeDetailView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column([
      // 200 lines of header code
      // 300 lines of ingredient list
      // 200 lines of instructions
      // 100 lines of actions
    ]);
  }
}

// ✅ CORRECT - Facade with extracted components
class RecipeDetailView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column([
      RecipeDetailHeader(),
      RecipeIngredientsList(),
      RecipeInstructionsList(),
      RecipeDetailActions(),
    ]);
  }
}
```

### ALWAYS Use const Constructors When Possible

```dart
// ❌ WRONG - Missing const
Padding(
  padding: EdgeInsets.all(16),
  child: Text('Hello'),
)

// ✅ CORRECT - Use const for performance
const Padding(
  padding: EdgeInsets.all(16),
  child: Text('Hello'),
)
```

### NEVER Create Widgets in Methods (Use Builder Methods)

```dart
// ❌ WRONG - Widget created in method
Widget _buildHeader() {
  return Container(...);  // Creates new widget on every call
}

// ✅ CORRECT - Extract to separate widget class
class RecipeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(...);
  }
}

// OR use builder method if truly needed
Widget build(BuildContext context) {
  return Column([
    _buildHeader(context),  // OK if simple
  ]);
}
```

## Common Widget Patterns

### Stateless vs Stateful

```dart
// Stateless - No mutable state
class RecipeCard extends StatelessWidget {
  final Recipe recipe;

  const RecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(title: Text(recipe.title)),
    );
  }
}

// Stateful - Has mutable state (controller, animation)
class RecipeSearchBar extends StatefulWidget {
  @override
  _RecipeSearchBarState createState() => _RecipeSearchBarState();
}

class _RecipeSearchBarState extends State<RecipeSearchBar> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _controller);
  }
}
```

### Key Usage

```dart
// Use keys for dynamic lists
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return RecipeCard(
      key: ValueKey(items[index].id),  // Helps Flutter identify widgets
      recipe: items[index],
    );
  },
)
```

### Conditional Rendering

```dart
// Ternary for simple conditions
isEditing
    ? EditButton(onTap: save)
    : ViewButton(onTap: edit)

// If statement for complex conditions
if (recipe.hasImage) ImageWidget(recipe.imageUrl),
if (recipe.isFavorite) FavoriteIcon(),

// Null-aware for optional widgets
recipe.notes != null
    ? NotesSection(notes: recipe.notes!)
    : SizedBox.shrink()
```

## Layout Patterns

### Column and Row

```dart
// Column - Vertical layout
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Title'),
    SizedBox(height: 8),
    Text('Subtitle'),
  ],
)

// Row - Horizontal layout
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    IconButton(icon: Icon(Icons.favorite)),
    Text('4 portions'),
    IconButton(icon: Icon(Icons.share)),
  ],
)
```

### ListView

```dart
// ListView.builder for large lists
ListView.builder(
  itemCount: recipes.length,
  itemBuilder: (context, index) {
    return RecipeCard(recipes[index]);
  },
)

// ListView with separator
ListView.separated(
  itemCount: recipes.length,
  itemBuilder: (context, index) => RecipeCard(recipes[index]),
  separatorBuilder: (context, index) => Divider(),
)
```

### GridView

```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 1.0,
    crossAxisSpacing: 8,
    mainAxisSpacing: 8,
  ),
  itemCount: recipes.length,
  itemBuilder: (context, index) {
    return RecipeCard(recipes[index]);
  },
)
```

## Swedish Localization

All UI text in Swedish:

```dart
// Button labels
ElevatedButton(
  onPressed: save,
  child: Text('Spara'),  // Not "Save"
)

// Empty states
StateWidget.empty(
  title: 'Inga recept',
  message: 'Lägg till ditt första recept',
)

// Error messages
StateWidget.error(
  message: 'Kunde inte ladda recept',
  actionLabel: 'Försök igen',
)

// Loading messages
StateWidget.loading(message: 'Laddar...')
```

## Testing Widgets

### Basic Widget Test

```dart
testWidgets('displays recipe title', (tester) async {
  final recipe = Recipe(id: '1', title: 'Pasta');

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RecipeCard(recipe: recipe),
      ),
    ),
  );

  expect(find.text('Pasta'), findsOneWidget);
});
```

### Testing with Provider

```dart
testWidgets('displays loading state', (tester) async {
  final mockViewModel = MockRecipeViewModel();
  when(() => mockViewModel.isLoading).thenReturn(true);

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<RecipeViewModel>.value(
        value: mockViewModel,
        child: RecipeListView(),
      ),
    ),
  );

  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```

## Anti-Patterns to Avoid

### 1. Creating Widgets in Build Method (⚠️)

```dart
// ❌ WRONG - Creates new widget on every rebuild
@override
Widget build(BuildContext context) {
  final card = Container(...);  // DON'T
  return Column([card]);
}

// ✅ CORRECT - Extract to const or separate widget
@override
Widget build(BuildContext context) {
  return Column([
    const RecipeCard(...),
  ]);
}
```

### 2. Not Using const (⚠️)

```dart
// ❌ WRONG - Misses optimization opportunity
Text('Hello')
Padding(padding: EdgeInsets.all(8))

// ✅ CORRECT - Use const
const Text('Hello')
const Padding(padding: EdgeInsets.all(8))
```

### 3. Deeply Nested Widgets (🔥 HIGH)

```dart
// ❌ WRONG - Hard to read and maintain
return Container(
  child: Padding(
    child: Column(
      children: [
        Row(
          children: [
            Container(
              child: Text(...),
            ),
          ],
        ),
      ],
    ),
  ),
);

// ✅ CORRECT - Extract to separate widgets
return Container(
  child: Padding(
    child: Column([
      _HeaderRow(),
      _ContentSection(),
    ]),
  ),
);
```

### 4. Manual State Checking (⚠️)

```dart
// ❌ WRONG - Repetitive state checking
if (isLoading) return CircularProgressIndicator();
if (hasError) return ErrorWidget();
if (isEmpty) return EmptyWidget();
return ContentWidget();

// ✅ CORRECT - Use LoadingStateBuilder
return LoadingStateBuilder(
  isLoading: isLoading,
  error: error,
  data: data,
  builder: (context, data) => ContentWidget(data),
);
```

## Best Practices

1. **Prefer StatelessWidget**: Use StatefulWidget only when needed
2. **Use const**: Always use const constructors when possible
3. **Extract Widgets**: Keep widgets under 200 lines
4. **Use Keys**: For dynamic lists and animations
5. **Dispose Resources**: Always dispose controllers, animations
6. **Swedish Text**: All user-facing text in Swedish
7. **LoadingStateBuilder**: For all state-dependent UIs
8. **Common Widgets**: Reuse from widgets/common/

## Related Skills

- **state-management-patterns** - Using ViewModels with widgets
- **testing-patterns** - Widget testing strategies
- **butlery-architecture** - MVVM view layer

## Examples from Codebase

See real implementations:
- `lib/widgets/common/` - 100+ reusable components
- `lib/widgets/loading_state_builder.dart` - State management widget
- `lib/widgets/state_widget.dart` - State factory
- `lib/views/social/` - 61 social views demonstrating patterns
- `lib/views/mina_recept_view.dart` - Facade pattern example
