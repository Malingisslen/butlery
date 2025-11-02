# Provider & Consumer Pattern

Guide to using Provider package for dependency injection and reactive state management in Butlery views.

## Overview

Provider is Butlery's state management solution:
- **Dependency Injection**: ViewModels injected into widget tree
- **Lifecycle Management**: Automatic creation and disposal
- **Reactive Updates**: Widgets rebuild on state changes
- **Scoped State**: State available to widget subtree

## Basic Usage

### Providing a ViewModel

```dart
class RecipeListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServiceLocator.get<RecipeViewModel>(),
      child: RecipeListContent(),
    );
  }
}
```

**Key points**:
- `create` callback instantiates ViewModel
- `ServiceLocator.get<T>()` for DI-registered ViewModels
- Provider disposes ViewModel automatically when widget removed

### Consuming State

```dart
class RecipeListContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<RecipeViewModel>(
      builder: (context, viewModel, child) {
        return ListView.builder(
          itemCount: viewModel.recipes.length,
          itemBuilder: (context, index) {
            return RecipeCard(recipe: viewModel.recipes[index]);
          },
        );
      },
    );
  }
}
```

**How it works**:
- `Consumer` listens to ViewModel changes
- `builder` called when ViewModel calls `notifyListeners()`
- Entire subtree rebuilds on state changes

## Provider Types

### ChangeNotifierProvider

Most common type for ViewModels:

```dart
ChangeNotifierProvider(
  create: (_) => RecipeViewModel(
    service: ServiceLocator.get<UnifiedRecipeService>(),
  ),
  child: RecipeView(),
)
```

### Provider (Non-reactive)

For services or immutable data:

```dart
Provider<RecipeService>(
  create: (_) => ServiceLocator.get<RecipeService>(),
  child: MyWidget(),
)
```

### StreamProvider

For reactive streams:

```dart
StreamProvider<List<Recipe>>(
  create: (_) => recipeService.watchRecipes(),
  initialData: [],
  child: RecipeList(),
)
```

### FutureProvider

For async data loading:

```dart
FutureProvider<UserProfile>(
  create: (_) => userService.getCurrentUser(),
  initialData: null,
  child: ProfileWidget(),
)
```

## Accessing State

### Three Access Patterns

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 1. Consumer - Rebuilds when state changes
    return Consumer<RecipeViewModel>(
      builder: (context, viewModel, child) {
        return Text(viewModel.recipes.length.toString());
      },
    );

    // 2. context.watch - Rebuilds when state changes
    final viewModel = context.watch<RecipeViewModel>();
    return Text(viewModel.recipes.length.toString());

    // 3. context.read - Does NOT rebuild
    final viewModel = context.read<RecipeViewModel>();
    viewModel.loadRecipes();  // Call methods, don't use for display
    return Container();
  }
}
```

### When to Use Each

**Consumer**:
- ✅ Need to rebuild part of widget tree
- ✅ Want to optimize with `child` parameter
- ✅ Multiple consumers in same widget

**context.watch**:
- ✅ Simpler syntax than Consumer
- ✅ Whole widget rebuilds on change (acceptable)
- ✅ Need state in multiple places

**context.read**:
- ✅ Calling ViewModel methods
- ✅ Event handlers (onPressed, onChanged)
- ✅ initState or other non-build methods
- ❌ NEVER in build method for displaying state

## Performance Optimization

### Consumer with child Parameter

```dart
Consumer<RecipeViewModel>(
  builder: (context, viewModel, child) {
    return Column(
      children: [
        Text('Recipes: ${viewModel.recipes.length}'),
        child!,  // This widget doesn't rebuild
      ],
    );
  },
  child: ExpensiveWidget(),  // Only built once
)
```

**child** parameter prevents rebuilding static parts of UI.

### Selector for Fine-Grained Updates

```dart
// Only rebuilds when recipe count changes, not other state
Selector<RecipeViewModel, int>(
  selector: (context, viewModel) => viewModel.recipes.length,
  builder: (context, count, child) {
    return Text('Total: $count');
  },
)
```

### Multiple Consumers

```dart
class RecipeView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Consumer 1 - Only rebuilds when loading state changes
        Consumer<RecipeViewModel>(
          builder: (context, vm, _) =>
            vm.isLoading ? CircularProgressIndicator() : Container(),
        ),

        // Consumer 2 - Only rebuilds when recipes change
        Consumer<RecipeViewModel>(
          builder: (context, vm, _) => RecipeList(recipes: vm.recipes),
        ),
      ],
    );
  }
}
```

## Multi-Provider

When multiple ViewModels needed:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (_) => RecipeViewModel(
        service: ServiceLocator.get<UnifiedRecipeService>(),
      ),
    ),
    ChangeNotifierProvider(
      create: (_) => MenuViewModel(
        service: ServiceLocator.get<UnifiedMenuService>(),
      ),
    ),
  ],
  child: HomeView(),
)
```

## Scoped Providers

Different scopes for different use cases:

### App-Level Provider

```dart
// In main.dart or MyApp widget
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppStateViewModel(),  // Available everywhere
      child: MaterialApp(...),
    );
  }
}
```

### Screen-Level Provider

```dart
class RecipeListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecipeViewModel(),  // Only available in this screen
      child: RecipeListView(),
    );
  }
}
```

### Widget-Level Provider

```dart
class RecipeDetailSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecipeDetailViewModel(),  // Very localized
      child: RecipeDetailContent(),
    );
  }
}
```

## Passing Arguments to ViewModels

### Via Constructor

```dart
class RecipeDetailView extends StatelessWidget {
  final String recipeId;

  const RecipeDetailView({required this.recipeId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecipeDetailViewModel(
        recipeId: recipeId,  // Pass argument
        service: ServiceLocator.get<UnifiedRecipeService>(),
      ),
      child: RecipeDetailContent(),
    );
  }
}
```

### Via ViewModel Method

```dart
class RecipeDetailView extends StatelessWidget {
  final String recipeId;

  const RecipeDetailView({required this.recipeId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final vm = ServiceLocator.get<RecipeDetailViewModel>();
        vm.loadRecipe(recipeId);  // Initialize with data
        return vm;
      },
      child: RecipeDetailContent(),
    );
  }
}
```

## Common Patterns

### LoadingStateBuilder with Provider

```dart
class RecipeListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServiceLocator.get<RecipeViewModel>(),
      child: Consumer<RecipeViewModel>(
        builder: (context, viewModel, _) {
          return LoadingStateBuilder<List<Recipe>>(
            isLoading: viewModel.isLoading,
            error: viewModel.error,
            data: viewModel.recipes,
            builder: (context, recipes) => RecipeList(recipes),
            emptyState: EmptyStateVariant.noRecipes,
            onEmptyAction: () => viewModel.createRecipe(),
          );
        },
      ),
    );
  }
}
```

### Form with Provider

```dart
class RecipeForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecipeFormViewModel(),
      child: Consumer<RecipeFormViewModel>(
        builder: (context, viewModel, _) {
          return Column(
            children: [
              TextField(
                controller: viewModel.titleController,
                decoration: InputDecoration(
                  errorText: viewModel.titleError,
                ),
                onChanged: (_) => viewModel.validateTitle(),
              ),
              ElevatedButton(
                onPressed: viewModel.isValid
                    ? () => viewModel.save()
                    : null,
                child: Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

### List with Selection

```dart
class RecipeListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<RecipeViewModel>(
      builder: (context, viewModel, _) {
        return ListView.builder(
          itemCount: viewModel.recipes.length,
          itemBuilder: (context, index) {
            final recipe = viewModel.recipes[index];
            final isSelected = viewModel.selectedIds.contains(recipe.id);

            return ListTile(
              title: Text(recipe.title),
              trailing: isSelected ? Icon(Icons.check) : null,
              onTap: () => viewModel.toggleSelection(recipe.id),
            );
          },
        );
      },
    );
  }
}
```

## Calling ViewModel Methods

### From Event Handlers

```dart
ElevatedButton(
  onPressed: () {
    // Use context.read to call methods
    context.read<RecipeViewModel>().deleteRecipe(recipeId);
  },
  child: Text('Delete'),
)
```

### From initState

```dart
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();

    // Call method after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecipeViewModel>().loadRecipes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecipeViewModel>(...);
  }
}
```

### From didChangeDependencies

```dart
class _MyWidgetState extends State<MyWidget> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Safe to use context.read here
    context.read<RecipeViewModel>().initialize();
  }
}
```

## Navigation with Provider

### Providing ViewModel Across Navigation

```dart
// Provide at root
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppStateViewModel(),
      child: MaterialApp(
        home: HomeScreen(),
      ),
    );
  }
}

// Access in any screen
class DetailsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateViewModel>();
    // appState available here
  }
}
```

### Scoped ViewModel for Screen

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider(
      create: (_) => RecipeDetailViewModel(recipeId: id),
      child: RecipeDetailView(),
    ),
  ),
);
```

## Testing with Provider

### Test ViewModel Directly

```dart
test('loads recipes successfully', () async {
  final mockService = MockRecipeService();
  final viewModel = RecipeViewModel(service: mockService);

  when(() => mockService.getUserRecipes())
      .thenAnswer((_) async => [testRecipe]);

  await viewModel.loadRecipes();

  expect(viewModel.recipes, [testRecipe]);
});
```

### Test Widget with Provider

```dart
testWidgets('displays recipes from ViewModel', (tester) async {
  final mockViewModel = MockRecipeViewModel();
  when(() => mockViewModel.recipes).thenReturn([testRecipe]);
  when(() => mockViewModel.isLoading).thenReturn(false);

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<RecipeViewModel>.value(
        value: mockViewModel,
        child: RecipeListView(),
      ),
    ),
  );

  expect(find.text(testRecipe.title), findsOneWidget);
});
```

## Anti-Patterns

### 1. Using context.watch in Event Handlers (❌)

```dart
// ❌ WRONG - Subscribes to changes unnecessarily
ElevatedButton(
  onPressed: () {
    final vm = context.watch<RecipeViewModel>();  // DON'T
    vm.deleteRecipe(id);
  },
)

// ✅ CORRECT - Use context.read
ElevatedButton(
  onPressed: () {
    context.read<RecipeViewModel>().deleteRecipe(id);
  },
)
```

### 2. Using context.read in build Method (❌)

```dart
// ❌ WRONG - Won't rebuild on changes
@override
Widget build(BuildContext context) {
  final vm = context.read<RecipeViewModel>();  // DON'T
  return Text(vm.recipes.length.toString());  // Stale data!
}

// ✅ CORRECT - Use context.watch or Consumer
@override
Widget build(BuildContext context) {
  final vm = context.watch<RecipeViewModel>();
  return Text(vm.recipes.length.toString());
}
```

### 3. Creating Provider in build Method (❌)

```dart
// ❌ WRONG - Creates new ViewModel on every rebuild
@override
Widget build(BuildContext context) {
  return ChangeNotifierProvider(
    create: (_) => RecipeViewModel(),  // RECREATED EVERY TIME!
    child: MyWidget(),
  );
}

// ✅ CORRECT - Provider at stable location
class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecipeViewModel(),  // Created once
      child: MyWidget(),
    );
  }
}
```

### 4. Not Disposing Resources (❌)

```dart
// ❌ WRONG - ViewModel created but never disposed
final viewModel = RecipeViewModel();  // Memory leak!

// ✅ CORRECT - Provider handles disposal
ChangeNotifierProvider(
  create: (_) => RecipeViewModel(),  // Disposed automatically
)
```

## Best Practices

1. **Scope Appropriately**: Provide at lowest common ancestor
2. **Use context.read for Methods**: Don't subscribe in event handlers
3. **Use Consumer for Optimization**: Rebuild only what's needed
4. **Test ViewModels Directly**: Don't require Provider for ViewModel tests
5. **Dispose via Provider**: Let Provider manage ViewModel lifecycle
6. **Avoid Global Providers**: Prefer scoped providers when possible
7. **Use MultiProvider**: Better than nested Providers

## Real-World Example

```dart
class RecipeDetailScreen extends StatelessWidget {
  final String recipeId;

  const RecipeDetailScreen({required this.recipeId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecipeDetailViewModel(
        recipeId: recipeId,
        service: ServiceLocator.get<UnifiedRecipeService>(),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<RecipeDetailViewModel>(
            builder: (context, vm, _) => Text(vm.recipe?.title ?? 'Loading...'),
          ),
          actions: [
            Consumer<RecipeDetailViewModel>(
              builder: (context, vm, _) {
                return IconButton(
                  icon: Icon(vm.isFavorite ? Icons.favorite : Icons.favorite_border),
                  onPressed: () => vm.toggleFavorite(),
                );
              },
            ),
          ],
        ),
        body: Consumer<RecipeDetailViewModel>(
          builder: (context, vm, _) {
            return LoadingStateBuilder(
              isLoading: vm.isLoading,
              error: vm.error,
              data: vm.recipe,
              builder: (context, recipe) => RecipeDetailContent(recipe),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.read<RecipeDetailViewModel>().edit(),
          child: Icon(Icons.edit),
        ),
      ),
    );
  }
}
```

## Related Resources

- [ChangeNotifier Pattern](changenotifier-pattern.md) - ViewModel foundation
- [AsyncOperationMixin](async-operation-mixin.md) - Advanced ViewModel patterns
- [Manager Delegation](manager-delegation.md) - Complex ViewModel structure
- flutter-widget-guidelines skill - Widget composition with Provider
