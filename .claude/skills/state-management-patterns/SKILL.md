# State Management Patterns

Comprehensive guide to Butlery's state management patterns using Provider, ChangeNotifier, and reactive ViewModels.

## Overview

Butlery uses Provider + ChangeNotifier for state management:
- **ViewModels**: Extend BaseViewModel or ChangeNotifier
- **Provider**: Dependency injection and lifecycle management
- **Consumer**: Reactive UI updates on state changes
- **AsyncOperationMixin**: Advanced async state management
- **Manager Delegation**: Facade pattern for complex state

## Core Patterns

### 5 State Management Patterns

```
1. BaseViewModel + ChangeNotifier
   └─> Standard pattern (90% of ViewModels)
       └─> Manual state + notifyListeners()

2. AsyncOperationMixin
   └─> Advanced async operations (15 ViewModels)
       └─> Debouncing, caching, named operations

3. Manager Delegation
   └─> Complex ViewModels (facade pattern)
       └─> Specialized managers for features

4. StateNotifierMixin
   └─> Standardized loading/error states
       └─> Automatic state properties

5. Provider + Consumer
   └─> View layer state access
       └─> Reactive UI updates
```

## Quick Reference

### Creating a ViewModel

```dart
class RecipeViewModel extends BaseViewModel {
  final RecipeService _service;

  List<Recipe> _recipes = [];
  List<Recipe> get recipes => _recipes;

  RecipeViewModel({required RecipeService service})
      : _service = service;

  Future<void> loadRecipes() async {
    await executeAsync(() async {
      _recipes = await _service.personal.getUserRecipes();
      notifyListeners();
    });
  }
}
```

### Using in View

```dart
class RecipeListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServiceLocator.get<RecipeViewModel>(),
      child: Consumer<RecipeViewModel>(
        builder: (context, viewModel, child) {
          return LoadingStateBuilder(
            isLoading: viewModel.isLoading,
            error: viewModel.error,
            data: viewModel.recipes,
            builder: (context, recipes) => RecipeList(recipes),
          );
        },
      ),
    );
  }
}
```

## When to Use This Skill

Auto-activates when:
- Creating or modifying ViewModels
- Implementing state management
- Using Provider or ChangeNotifier
- Working with async operations
- Building reactive UIs

## Deep Dive Resources

Explore specific state management patterns:

1. **[ChangeNotifier Pattern](resources/changenotifier-pattern.md)**
   - BaseViewModel structure
   - State properties and getters
   - notifyListeners() usage
   - executeAsync() wrapper
   - Loading and error states

2. **[AsyncOperationMixin](resources/async-operation-mixin.md)**
   - Named operations (prevent duplicates)
   - Debouncing for search/input
   - Caching with expiry
   - Throttling for rate limiting
   - Batch and sequential operations

3. **[Manager Delegation](resources/manager-delegation.md)**
   - Facade pattern for 500+ line ViewModels
   - Specialized manager classes
   - Manager communication patterns
   - State aggregation
   - Testing manager-based ViewModels

4. **[Provider & Consumer](resources/provider-consumer.md)**
   - Provider types (ChangeNotifierProvider, etc.)
   - Consumer vs context.watch vs context.read
   - Multi-provider patterns
   - Scoped state management
   - Testing with Provider

## Critical Rules

### ALWAYS Extend BaseViewModel or ChangeNotifier

```dart
// ❌ WRONG - Plain class won't notify UI
class RecipeViewModel {
  List<Recipe> recipes = [];
}

// ✅ CORRECT - Extends BaseViewModel
class RecipeViewModel extends BaseViewModel {
  List<Recipe> _recipes = [];
  List<Recipe> get recipes => _recipes;
}
```

### ALWAYS Call notifyListeners() After State Changes

```dart
// ❌ WRONG - UI won't update
Future<void> deleteRecipe(String id) async {
  await _service.deleteRecipe(id);
  _recipes.removeWhere((r) => r.id == id);
  // Missing notifyListeners()!
}

// ✅ CORRECT - Notifies listeners
Future<void> deleteRecipe(String id) async {
  await _service.deleteRecipe(id);
  _recipes.removeWhere((r) => r.id == id);
  notifyListeners();
}
```

### ALWAYS Use Private Fields with Public Getters

```dart
// ❌ WRONG - Public mutable state
class RecipeViewModel extends ChangeNotifier {
  List<Recipe> recipes = [];  // Can be modified externally!
}

// ✅ CORRECT - Private field with public getter
class RecipeViewModel extends ChangeNotifier {
  List<Recipe> _recipes = [];
  List<Recipe> get recipes => _recipes;  // Read-only access
}
```

### NEVER Modify State in Getters

```dart
// ❌ CRITICAL - Modifying state in getter
List<Recipe> get sortedRecipes {
  _recipes.sort((a, b) => ...);  // Modifies original list!
  return _recipes;
}

// ✅ CORRECT - Return new sorted list
List<Recipe> get sortedRecipes {
  return [..._recipes]..sort((a, b) => ...);
}
```

## Common Patterns

### Loading, Error, and Success States

```dart
class RecipeViewModel extends BaseViewModel {
  // Use StateNotifierMixin or manual state
  bool _isLoading = false;
  String? _error;
  List<Recipe> _recipes = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Recipe> get recipes => _recipes;

  Future<void> loadRecipes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _recipes = await _service.personal.getUserRecipes();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

### Form State Management

```dart
class RecipeFormViewModel extends ChangeNotifier {
  final TextEditingController titleController;
  final TextEditingController portionsController;

  String? _titleError;
  String? _portionsError;

  String? get titleError => _titleError;
  String? get portionsError => _portionsError;

  bool get isValid => _titleError == null && _portionsError == null;

  void validateTitle(String value) {
    if (value.isEmpty) {
      _titleError = 'Title required';
    } else if (value.length < 3) {
      _titleError = 'Title too short';
    } else {
      _titleError = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    titleController.dispose();
    portionsController.dispose();
    super.dispose();
  }
}
```

### List State Management

```dart
class RecipeListViewModel extends BaseViewModel {
  List<Recipe> _recipes = [];
  Set<String> _selectedIds = {};

  List<Recipe> get recipes => _recipes;
  Set<String> get selectedIds => _selectedIds;
  bool get hasSelection => _selectedIds.isNotEmpty;
  int get selectedCount => _selectedIds.length;

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    for (final id in _selectedIds) {
      await _service.deleteRecipe(id);
      _recipes.removeWhere((r) => r.id == id);
    }
    _selectedIds.clear();
    notifyListeners();
  }
}
```

## Anti-Patterns to Avoid

### 1. Calling notifyListeners() in Getters (🔥 CRITICAL)

```dart
// ❌ CRITICAL - Infinite rebuild loop
List<Recipe> get recipes {
  notifyListeners();  // NEVER do this!
  return _recipes;
}
```

### 2. Not Disposing Resources (🔥 HIGH)

```dart
// ❌ WRONG - Memory leak
class MyViewModel extends ChangeNotifier {
  final StreamSubscription _subscription;
  // Missing dispose()!
}

// ✅ CORRECT - Proper disposal
class MyViewModel extends ChangeNotifier {
  StreamSubscription? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

### 3. Exposing Mutable Collections (🔥 HIGH)

```dart
// ❌ WRONG - List can be modified externally
List<Recipe> get recipes => _recipes;

// ✅ CORRECT - Return unmodifiable list
List<Recipe> get recipes => List.unmodifiable(_recipes);

// OR return copy (if modification needed downstream)
List<Recipe> get recipes => [..._recipes];
```

### 4. Synchronous Operations in async Methods (⚠️ MEDIUM)

```dart
// ❌ WRONG - Blocks UI thread
Future<void> loadRecipes() async {
  _recipes = await _service.getUserRecipes();
  _processRecipes();  // Expensive sync operation!
  notifyListeners();
}

// ✅ CORRECT - Move to compute for heavy work
Future<void> loadRecipes() async {
  _recipes = await _service.getUserRecipes();
  _recipes = await compute(_processRecipesIsolate, _recipes);
  notifyListeners();
}
```

## Testing ViewModels

### Basic Test Structure

```dart
void main() {
  late RecipeViewModel viewModel;
  late MockRecipeService mockService;

  setUp(() {
    mockService = MockRecipeService();
    viewModel = RecipeViewModel(service: mockService);
  });

  tearDown(() {
    viewModel.dispose();
  });

  test('loads recipes successfully', () async {
    when(() => mockService.personal.getUserRecipes())
        .thenAnswer((_) async => [testRecipe]);

    await viewModel.loadRecipes();

    expect(viewModel.recipes, [testRecipe]);
    expect(viewModel.isLoading, isFalse);
  });
}
```

## Related Skills

- **testing-patterns** - Testing ViewModel state management
- **butlery-architecture** - MVVM architecture overview
- **flutter-widget-guidelines** - Using ViewModels in views

## Examples from Codebase

See real implementations:
- `lib/viewmodels/base_viewmodel.dart` - BaseViewModel foundation
- `lib/viewmodels/recipe/personal_recipe_viewmodel.dart` - Standard pattern
- `lib/viewmodels/friends_viewmodel.dart` - AsyncOperationMixin usage
- `lib/core/mixins/async_operation_mixin.dart` - AsyncOperationMixin source
- `lib/core/mixins/state_notifier_mixin.dart` - StateNotifierMixin source
