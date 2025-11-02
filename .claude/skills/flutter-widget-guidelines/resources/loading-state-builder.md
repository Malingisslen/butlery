# LoadingStateBuilder Pattern

Widget that automatically handles loading, error, empty, and data states - eliminating repetitive state checking boilerplate.

## Overview

LoadingStateBuilder is Butlery's primary state display widget:
- **Automatic State Detection**: Loading, error, empty, or data
- **Builder Function**: Renders data when available
- **Empty State Handling**: Preset variants or custom widgets
- **Error State**: With retry action support
- **Loading Indicators**: Centered or skeleton loaders

**Usage**: 15+ views in Butlery use this pattern

## Basic Usage

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
              itemBuilder: (context, index) {
                return RecipeCard(recipe: recipes[index]);
              },
            );
          },
          emptyState: EmptyStateVariant.noRecipes,
        );
      },
    );
  }
}
```

## State Detection Logic

LoadingStateBuilder automatically determines state:

```dart
// State priority (checked in order):
1. isLoading == true → Show loading indicator
2. error != null → Show error state
3. data == null → Show loading indicator
4. data is empty (list/map) → Show empty state
5. Otherwise → Call builder with data
```

## Parameters

### Required Parameters

```dart
LoadingStateBuilder<T>(
  isLoading: viewModel.isLoading,  // Loading state flag
  data: viewModel.items,            // Data to display (nullable)
  builder: (context, items) {       // Builder function for data
    return ListView(children: items);
  },
)
```

### Optional Parameters

```dart
LoadingStateBuilder<T>(
  // ... required params

  error: viewModel.error,              // Error message (nullable)
  emptyState: EmptyStateVariant.noRecipes,  // Preset empty state
  emptyWidget: CustomEmptyWidget(),    // Custom empty widget
  loadingWidget: CustomLoader(),       // Custom loading widget
  errorWidget: CustomErrorWidget(),    // Custom error widget
  onEmptyAction: () => createItem(),   // Empty state action
  onErrorAction: () => retry(),        // Error state retry action
  emptyMessage: 'Ingen data',          // Custom empty message
  errorMessage: 'Ett fel uppstod',     // Custom error message
)
```

## Loading State

### Default Loading Indicator

```dart
LoadingStateBuilder<List<Recipe>>(
  isLoading: true,
  data: null,
  builder: (context, recipes) => RecipeList(recipes),
)
// Shows: Centered CircularProgressIndicator
```

### Custom Loading Widget

```dart
LoadingStateBuilder<List<Recipe>>(
  isLoading: true,
  data: null,
  builder: (context, recipes) => RecipeList(recipes),
  loadingWidget: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      CircularProgressIndicator(),
      SizedBox(height: 16),
      Text('Laddar recept...'),
    ],
  ),
)
```

### Skeleton Loading State

```dart
LoadingStateBuilder<List<Recipe>>(
  isLoading: true,
  data: null,
  builder: (context, recipes) => RecipeList(recipes),
  loadingWidget: StateWidget.skeletonRecipeList(itemCount: 5),
)
```

## Error State

### Basic Error with Retry

```dart
LoadingStateBuilder<List<Recipe>>(
  isLoading: false,
  error: 'Kunde inte ladda recept',
  data: null,
  builder: (context, recipes) => RecipeList(recipes),
  onErrorAction: () => viewModel.retry(),
)
// Shows: Error icon, message, "Försök igen" button
```

### Custom Error Widget

```dart
LoadingStateBuilder<List<Recipe>>(
  isLoading: false,
  error: viewModel.error,
  data: null,
  builder: (context, recipes) => RecipeList(recipes),
  errorWidget: CustomErrorWidget(
    error: viewModel.error,
    onRetry: () => viewModel.retry(),
  ),
)
```

### Error Without Retry

```dart
LoadingStateBuilder<List<Recipe>>(
  isLoading: false,
  error: 'Permanent error',
  data: null,
  builder: (context, recipes) => RecipeList(recipes),
  // No onErrorAction = No retry button
)
```

## Empty State

### Preset Empty State Variants

```dart
enum EmptyStateVariant {
  noRecipes,
  noMenus,
  noShoppingLists,
  noFriends,
  noFriendRequests,
  noComments,
  noNotifications,
  noSearchResults,
  noContent,
}

// Usage
LoadingStateBuilder<List<Recipe>>(
  isLoading: false,
  data: [],  // Empty list
  builder: (context, recipes) => RecipeList(recipes),
  emptyState: EmptyStateVariant.noRecipes,
)
// Shows: Recipe icon, "Inga recept", "Lägg till ditt första recept"
```

### Empty State with Action

```dart
LoadingStateBuilder<List<Recipe>>(
  isLoading: false,
  data: [],
  builder: (context, recipes) => RecipeList(recipes),
  emptyState: EmptyStateVariant.noRecipes,
  onEmptyAction: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateRecipeView()),
    );
  },
)
// Shows empty state with "Lägg till recept" button
```

### Custom Empty Widget

```dart
LoadingStateBuilder<List<Recipe>>(
  isLoading: false,
  data: [],
  builder: (context, recipes) => RecipeList(recipes),
  emptyWidget: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.search, size: 64, color: Colors.grey),
      SizedBox(height: 16),
      Text('Inga sökresultat'),
      SizedBox(height: 8),
      Text('Prova ett annat sökord'),
    ],
  ),
)
```

### Custom Empty Message

```dart
LoadingStateBuilder<List<Recipe>>(
  isLoading: false,
  data: [],
  builder: (context, recipes) => RecipeList(recipes),
  emptyMessage: 'Du har inga favoritrecept än',
  onEmptyAction: () => browseRecipes(),
)
```

## Data State

### Simple List

```dart
LoadingStateBuilder<List<Recipe>>(
  isLoading: false,
  data: [recipe1, recipe2, recipe3],
  builder: (context, recipes) {
    return ListView.builder(
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        return RecipeCard(recipe: recipes[index]);
      },
    );
  },
)
```

### Single Object

```dart
LoadingStateBuilder<Recipe>(
  isLoading: false,
  data: recipe,
  builder: (context, recipe) {
    return RecipeDetailView(recipe: recipe);
  },
)
```

### Complex Data

```dart
LoadingStateBuilder<Map<String, List<Recipe>>>(
  isLoading: false,
  data: {'favorites': [...], 'recent': [...]},
  builder: (context, recipeMap) {
    return Column(
      children: [
        RecipeSection(title: 'Favoriter', recipes: recipeMap['favorites']),
        RecipeSection(title: 'Senaste', recipes: recipeMap['recent']),
      ],
    );
  },
)
```

## Real-World Examples

### Recipe List with All States

```dart
class RecipeListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<RecipeViewModel>(
      builder: (context, viewModel, _) {
        return LoadingStateBuilder<List<Recipe>>(
          // Loading state
          isLoading: viewModel.isLoading,
          loadingWidget: StateWidget.skeletonRecipeList(itemCount: 5),

          // Error state
          error: viewModel.error,
          onErrorAction: () => viewModel.loadRecipes(),

          // Empty state
          data: viewModel.recipes,
          emptyState: EmptyStateVariant.noRecipes,
          onEmptyAction: () {
            Navigator.pushNamed(context, '/recipe/create');
          },

          // Data state
          builder: (context, recipes) {
            return RefreshIndicator(
              onRefresh: () => viewModel.refresh(),
              child: ListView.builder(
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  return RecipeCard(
                    recipe: recipes[index],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailView(
                          recipeId: recipes[index].id,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
```

### Search Results with Custom Empty

```dart
class SearchResultsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SearchViewModel>(
      builder: (context, viewModel, _) {
        return LoadingStateBuilder<List<Recipe>>(
          isLoading: viewModel.isSearching,
          error: viewModel.error,
          data: viewModel.searchResults,

          emptyWidget: viewModel.searchQuery.isEmpty
              ? Center(child: Text('Ange ett sökord'))
              : StateWidget.noSearchResults(
                  searchQuery: viewModel.searchQuery,
                  onAction: () => viewModel.clearSearch(),
                ),

          builder: (context, results) {
            return Column(
              children: [
                SearchResultsHeader(count: results.length),
                Expanded(
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      return SearchResultCard(result: results[index]);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
```

### Friends List with Multiple States

```dart
class FriendsListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<FriendsViewModel>(
      builder: (context, viewModel, _) {
        return LoadingStateBuilder<List<UserProfile>>(
          isLoading: viewModel.isLoading,
          loadingWidget: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Laddar vänner...'),
            ],
          ),

          error: viewModel.error,
          errorMessage: 'Kunde inte ladda vänner',
          onErrorAction: () => viewModel.retry(),

          data: viewModel.friends,
          emptyState: EmptyStateVariant.noFriends,
          onEmptyAction: () {
            Navigator.pushNamed(context, '/friends/search');
          },

          builder: (context, friends) {
            return ListView.separated(
              itemCount: friends.length,
              separatorBuilder: (context, index) => Divider(),
              itemBuilder: (context, index) {
                return FriendListItem(
                  friend: friends[index],
                  onTap: () => viewModel.viewProfile(friends[index].userId),
                );
              },
            );
          },
        );
      },
    );
  }
}
```

## Benefits

**Eliminates Boilerplate**:
```dart
// Before LoadingStateBuilder (20+ lines)
if (viewModel.isLoading) {
  return Center(child: CircularProgressIndicator());
} else if (viewModel.hasError) {
  return Center(
    child: Column(
      children: [
        Icon(Icons.error),
        Text(viewModel.error!),
        ElevatedButton(
          onPressed: () => viewModel.retry(),
          child: Text('Försök igen'),
        ),
      ],
    ),
  );
} else if (viewModel.recipes.isEmpty) {
  return Center(
    child: Column(
      children: [
        Icon(Icons.receipt_long),
        Text('Inga recept'),
        ElevatedButton(
          onPressed: () => createRecipe(),
          child: Text('Lägg till recept'),
        ),
      ],
    ),
  );
} else {
  return ListView.builder(...);
}

// After LoadingStateBuilder (6 lines)
return LoadingStateBuilder<List<Recipe>>(
  isLoading: viewModel.isLoading,
  error: viewModel.error,
  data: viewModel.recipes,
  builder: (context, recipes) => ListView.builder(...),
  emptyState: EmptyStateVariant.noRecipes,
  onEmptyAction: () => createRecipe(),
);
```

**Consistency**: All views use same state display patterns
**Maintainability**: Change state display globally in one place
**Testability**: Easy to test different states

## Testing LoadingStateBuilder

```dart
testWidgets('shows loading state', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LoadingStateBuilder<List<String>>(
        isLoading: true,
        data: null,
        builder: (context, data) => ListView(),
      ),
    ),
  );

  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});

testWidgets('shows error state with retry', (tester) async {
  var retryTapped = false;

  await tester.pumpWidget(
    MaterialApp(
      home: LoadingStateBuilder<List<String>>(
        isLoading: false,
        error: 'Test error',
        data: null,
        builder: (context, data) => ListView(),
        onErrorAction: () => retryTapped = true,
      ),
    ),
  );

  expect(find.text('Test error'), findsOneWidget);
  expect(find.text('Försök igen'), findsOneWidget);

  await tester.tap(find.text('Försök igen'));
  expect(retryTapped, isTrue);
});

testWidgets('shows empty state', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LoadingStateBuilder<List<String>>(
        isLoading: false,
        data: [],
        builder: (context, data) => ListView(),
        emptyState: EmptyStateVariant.noRecipes,
      ),
    ),
  );

  expect(find.text('Inga recept'), findsOneWidget);
});

testWidgets('shows data when available', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LoadingStateBuilder<List<String>>(
        isLoading: false,
        data: ['Item 1', 'Item 2'],
        builder: (context, items) {
          return ListView(
            children: items.map((i) => Text(i)).toList(),
          );
        },
      ),
    ),
  );

  expect(find.text('Item 1'), findsOneWidget);
  expect(find.text('Item 2'), findsOneWidget);
});
```

## Best Practices

1. **Always Provide Error Retry**: Give users a way to recover
2. **Use Preset Empty States**: Consistent UX across app
3. **Custom Loading for Lists**: Use skeleton loaders for better UX
4. **Handle Null Data**: LoadingStateBuilder treats null as loading
5. **Type Safety**: Always specify generic type `<T>`
6. **Empty Actions**: Provide helpful empty state actions

## Common Pitfalls

**Not Handling Null Data**:
```dart
// ❌ WRONG - builder called with null!
LoadingStateBuilder<List<Recipe>>(
  isLoading: false,
  data: null,  // Will show loading state, not call builder
  builder: (context, recipes) => RecipeList(recipes),
)
```

**Forgetting Empty State**:
```dart
// ❌ WRONG - Empty list shows blank screen
LoadingStateBuilder<List<Recipe>>(
  isLoading: false,
  data: [],  // Empty but no emptyState specified
  builder: (context, recipes) => ListView.builder(...),
  // Missing: emptyState or emptyWidget
)
```

**Wrong Error Handling**:
```dart
// ❌ WRONG - No way to retry
LoadingStateBuilder<List<Recipe>>(
  isLoading: false,
  error: viewModel.error,
  data: null,
  builder: (context, recipes) => RecipeList(recipes),
  // Missing: onErrorAction for retry
)
```

## Related Resources

- [StateWidget Factory](state-widget.md) - Underlying state display widgets
- [Widget Composition](widget-composition.md) - Using in complex UIs
- state-management-patterns skill - ViewModel state management
