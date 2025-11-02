# ChangeNotifier Pattern

The foundational state management pattern in Butlery using BaseViewModel and ChangeNotifier for reactive UI updates.

## Pattern Overview

ChangeNotifier is Flutter's built-in observable pattern:
- **ViewModels** extend ChangeNotifier (via BaseViewModel)
- **Private state** with public getters
- **notifyListeners()** triggers UI rebuilds
- **Consumer** widgets react to changes
- **Automatic disposal** via Provider

## BaseViewModel Structure

```dart
abstract class BaseViewModel extends ChangeNotifier {
  bool _isDisposed = false;

  /// Loading state
  bool get isLoading => _isLoading;
  bool _isLoading = false;

  /// Error state
  String? get error => _error;
  String? _error;
  bool get hasError => _error != null;

  /// Execute async operation with automatic loading/error handling
  Future<void> executeAsync(Future<void> Function() operation) async {
    if (_isDisposed) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await operation();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
```

## Standard ViewModel Pattern

### Basic Structure

```dart
class RecipeViewModel extends BaseViewModel {
  final UnifiedRecipeService _service;

  // Private state
  List<Recipe> _recipes = [];
  Recipe? _selectedRecipe;
  String _searchQuery = '';

  // Public getters (read-only access)
  List<Recipe> get recipes => _recipes;
  Recipe? get selectedRecipe => _selectedRecipe;
  String get searchQuery => _searchQuery;

  // Derived state
  List<Recipe> get filteredRecipes {
    if (_searchQuery.isEmpty) return _recipes;
    return _recipes
        .where((r) => r.title.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  bool get hasRecipes => _recipes.isNotEmpty;
  int get recipeCount => _recipes.length;

  // Constructor with dependency injection
  RecipeViewModel({
    required UnifiedRecipeService service,
  }) : _service = service;

  // State modification methods
  Future<void> loadRecipes() async {
    await executeAsync(() async {
      _recipes = await _service.personal.getUserRecipes();
    });
  }

  void selectRecipe(Recipe recipe) {
    _selectedRecipe = recipe;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();  // Triggers filteredRecipes recalculation
  }

  @override
  void dispose() {
    // Clean up resources
    super.dispose();
  }
}
```

## State Lifecycle

### 1. Initialization

```dart
class RecipeViewModel extends BaseViewModel {
  RecipeViewModel({required UnifiedRecipeService service})
      : _service = service {
    // Initialize state in constructor
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await loadRecipes();
  }
}
```

### 2. State Updates

```dart
// Method that modifies state
Future<void> deleteRecipe(String id) async {
  await executeAsync(() async {
    await _service.personal.deleteRecipe(id);
    // Update local state
    _recipes.removeWhere((r) => r.id == id);
    // executeAsync calls notifyListeners() automatically
  });
}

// Synchronous state update
void toggleFavorite(Recipe recipe) {
  final updated = recipe.copyWith(isFavorite: !recipe.isFavorite);
  final index = _recipes.indexWhere((r) => r.id == recipe.id);
  if (index != -1) {
    _recipes[index] = updated;
  }
  notifyListeners();  // Must call manually for sync operations
}
```

### 3. Disposal

```dart
@override
void dispose() {
  // Cancel subscriptions
  _recipeSubscription?.cancel();

  // Dispose controllers
  _searchController.dispose();

  // Clean up other resources
  _timer?.cancel();

  super.dispose();  // MUST call super.dispose()
}
```

## notifyListeners() Rules

### When to Call

```dart
// ✅ After modifying state
void updateTitle(String title) {
  _title = title;
  notifyListeners();  // UI will rebuild
}

// ✅ After async operation (manually)
Future<void> save() async {
  await _service.save(_data);
  _isSaved = true;
  notifyListeners();
}

// ✅ executeAsync calls it automatically
Future<void> load() async {
  await executeAsync(() async {
    _data = await _service.load();
    // notifyListeners() called by executeAsync
  });
}
```

### When NOT to Call

```dart
// ❌ NEVER in getters
List<Recipe> get recipes {
  notifyListeners();  // CRITICAL ERROR - infinite loop!
  return _recipes;
}

// ❌ NEVER in build methods (infinite loop)
// ❌ NEVER in dispose (already disposing)
// ❌ NEVER before async operation completes
Future<void> save() async {
  notifyListeners();  // TOO EARLY - nothing changed yet!
  await _service.save(_data);
  notifyListeners();  // ✅ Correct place
}
```

## State Properties Patterns

### Loading States

```dart
class MyViewModel extends BaseViewModel {
  // Multiple loading states for different operations
  bool _isLoadingRecipes = false;
  bool _isSaving = false;
  bool _isDeleting = false;

  bool get isLoadingRecipes => _isLoadingRecipes;
  bool get isSaving => _isSaving;
  bool get isDeleting => _isDeleting;
  bool get isBusy => _isLoadingRecipes || _isSaving || _isDeleting;

  Future<void> loadRecipes() async {
    _isLoadingRecipes = true;
    notifyListeners();

    try {
      _recipes = await _service.getUserRecipes();
    } finally {
      _isLoadingRecipes = false;
      notifyListeners();
    }
  }
}
```

### Error States

```dart
class MyViewModel extends BaseViewModel {
  String? _loadError;
  String? _saveError;

  String? get loadError => _loadError;
  String? get saveError => _saveError;
  bool get hasErrors => _loadError != null || _saveError != null;

  void clearErrors() {
    _loadError = null;
    _saveError = null;
    notifyListeners();
  }

  Future<void> save() async {
    _saveError = null;
    notifyListeners();

    try {
      await _service.save(_data);
    } catch (e) {
      _saveError = e.toString();
      notifyListeners();
    }
  }
}
```

### Selection States

```dart
class RecipeListViewModel extends BaseViewModel {
  Set<String> _selectedIds = {};
  SelectionMode _selectionMode = SelectionMode.none;

  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  SelectionMode get selectionMode => _selectionMode;
  bool get isSelecting => _selectionMode != SelectionMode.none;
  int get selectedCount => _selectedIds.length;
  bool get hasSelection => _selectedIds.isNotEmpty;

  void enterSelectionMode() {
    _selectionMode = SelectionMode.multiple;
    notifyListeners();
  }

  void exitSelectionMode() {
    _selectionMode = SelectionMode.none;
    _selectedIds.clear();
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }
}
```

## Derived State

Computed properties based on other state:

```dart
class RecipeViewModel extends BaseViewModel {
  List<Recipe> _recipes = [];
  String _searchQuery = '';
  RecipeFilter _filter = RecipeFilter.all;

  // Derived state (computed on access)
  List<Recipe> get filteredRecipes {
    var result = _recipes;

    // Apply search
    if (_searchQuery.isNotEmpty) {
      result = result
          .where((r) => r.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Apply filter
    switch (_filter) {
      case RecipeFilter.favorites:
        result = result.where((r) => r.isFavorite).toList();
        break;
      case RecipeFilter.recent:
        result = result
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case RecipeFilter.all:
        break;
    }

    return result;
  }

  List<Recipe> get favoriteRecipes => _recipes.where((r) => r.isFavorite).toList();
  int get favoriteCount => _recipes.where((r) => r.isFavorite).length;
  bool get hasFavorites => _recipes.any((r) => r.isFavorite);
}
```

**Important**: Derived getters should NOT modify state or call notifyListeners().

## Form ViewModels

Specialized pattern for form state management:

```dart
class RecipeFormViewModel extends BaseViewModel {
  // Controllers for text inputs
  final TextEditingController titleController;
  final TextEditingController descriptionController;

  // Form state
  int _portions = 4;
  List<Ingredient> _ingredients = [];
  List<String> _instructions = [];

  // Validation errors
  String? _titleError;
  String? _portionsError;

  // Getters
  int get portions => _portions;
  List<Ingredient> get ingredients => List.unmodifiable(_ingredients);
  String? get titleError => _titleError;
  bool get isValid => _titleError == null && _portionsError == null;

  RecipeFormViewModel({
    Recipe? recipe,
  }) : titleController = TextEditingController(text: recipe?.title),
       descriptionController = TextEditingController(text: recipe?.description) {
    // Add listeners to controllers
    titleController.addListener(_validateTitle);
  }

  void _validateTitle() {
    if (titleController.text.isEmpty) {
      _titleError = 'Title required';
    } else if (titleController.text.length < 3) {
      _titleError = 'Title must be at least 3 characters';
    } else {
      _titleError = null;
    }
    notifyListeners();
  }

  void setPortions(int value) {
    if (value < 1) {
      _portionsError = 'Must be at least 1';
    } else {
      _portionsError = null;
      _portions = value;
    }
    notifyListeners();
  }

  void addIngredient(Ingredient ingredient) {
    _ingredients.add(ingredient);
    notifyListeners();
  }

  void removeIngredient(int index) {
    _ingredients.removeAt(index);
    notifyListeners();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}
```

## Testing ChangeNotifier ViewModels

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

  group('State Management', () {
    test('notifies listeners when recipes loaded', () async {
      var notificationCount = 0;
      viewModel.addListener(() => notificationCount++);

      when(() => mockService.personal.getUserRecipes())
          .thenAnswer((_) async => [testRecipe]);

      await viewModel.loadRecipes();

      expect(notificationCount, greaterThan(0));
      expect(viewModel.recipes, [testRecipe]);
    });

    test('updates loading state during async operation', () async {
      when(() => mockService.personal.getUserRecipes())
          .thenAnswer((_) => Future.delayed(
            Duration(milliseconds: 100),
            () => [testRecipe],
          ));

      expect(viewModel.isLoading, isFalse);

      final loadTask = viewModel.loadRecipes();
      await Future.delayed(Duration(milliseconds: 10));

      expect(viewModel.isLoading, isTrue);

      await loadTask;

      expect(viewModel.isLoading, isFalse);
    });

    test('sets error on failure', () async {
      when(() => mockService.personal.getUserRecipes())
          .thenThrow(Exception('Network error'));

      await viewModel.loadRecipes();

      expect(viewModel.hasError, isTrue);
      expect(viewModel.error, contains('Network error'));
    });
  });
}
```

## Best Practices

1. **Private State**: Always use private fields (`_field`) with public getters
2. **Immutable Collections**: Return `List.unmodifiable()` or copies of collections
3. **Computed Properties**: Use getters for derived state (no side effects)
4. **Resource Cleanup**: Always dispose controllers, subscriptions, timers
5. **Error Handling**: Use try-catch with error state properties
6. **Loading States**: Track loading state for better UX
7. **Validation**: Validate input and track validation errors
8. **Single Responsibility**: One ViewModel per screen/feature

## Common Pitfalls

1. **Forgetting notifyListeners()** - UI won't update
2. **Calling notifyListeners() in getters** - Infinite loop
3. **Not disposing resources** - Memory leaks
4. **Exposing mutable state** - External modification
5. **Modifying state in getters** - Side effects
6. **Not using executeAsync()** - Manual loading/error handling

## Related Resources

- [AsyncOperationMixin](async-operation-mixin.md) - Advanced async patterns
- [Manager Delegation](manager-delegation.md) - Complex ViewModel patterns
- [Provider & Consumer](provider-consumer.md) - Using ViewModels in views
