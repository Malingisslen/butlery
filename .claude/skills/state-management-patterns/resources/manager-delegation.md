# Manager Delegation Pattern

Facade pattern for complex ViewModels that exceed 500 lines - delegates responsibilities to specialized manager classes while maintaining a single public interface.

## Pattern Overview

Manager delegation breaks large ViewModels into:
- **Main ViewModel**: Facade exposing public API
- **Specialized Managers**: Handle specific features
- **Clear Boundaries**: Each manager has single responsibility
- **Aggregated State**: ViewModel combines manager states

This is the **accepted pattern** for files exceeding 500 lines in Butlery.

## When to Use

**Use manager delegation when**:
- ViewModel exceeds or approaches 500 lines
- Clear feature boundaries exist (search, selection, validation, etc.)
- Multiple complex workflows in one screen
- State management becomes difficult to follow

**Example candidates**:
- Form ViewModels with validation, image handling, autosave
- List ViewModels with search, filter, selection, pagination
- Social ViewModels with friends, search, categories, requests
- Complex wizards or multi-step flows

## Basic Structure

```dart
// Main ViewModel (Facade)
class RecipeFormViewModel extends ChangeNotifier {
  // Managers
  late final RecipeValidationManager _validationManager;
  late final RecipeImageManager _imageManager;
  late final RecipeAutosaveManager _autosaveManager;

  // Services
  final RecipeService _recipeService;

  // Simple local state
  Recipe? _recipe;

  // Expose manager state via getters
  Map<String, String?> get validationErrors => _validationManager.errors;
  bool get hasValidationErrors => _validationManager.hasErrors;
  List<RecipeImage> get images => _imageManager.images;
  bool get isAutosaving => _autosaveManager.isAutosaving;

  RecipeFormViewModel({
    required RecipeService recipeService,
    Recipe? recipe,
  })  : _recipeService = recipeService,
        _recipe = recipe {
    // Initialize managers
    _validationManager = RecipeValidationManager();
    _imageManager = RecipeImageManager();
    _autosaveManager = RecipeAutosaveManager(
      onSave: _handleAutosave,
    );

    // Register manager listeners
    _validationManager.addListener(_onValidationChanged);
    _imageManager.addListener(_onImagesChanged);
    _autosaveManager.addListener(notifyListeners);
  }

  // Delegate to managers
  void validateTitle(String value) {
    _validationManager.validateTitle(value);
  }

  Future<void> pickImage() async {
    await _imageManager.pickImage();
  }

  void triggerAutosave() {
    _autosaveManager.scheduleAutosave();
  }

  // Aggregation logic
  bool get canSave {
    return !hasValidationErrors &&
           images.isNotEmpty &&
           !isAutosaving;
  }

  void _onValidationChanged() {
    notifyListeners();  // Propagate to UI
  }

  void _onImagesChanged() {
    triggerAutosave();  // Trigger autosave when images change
    notifyListeners();
  }

  Future<void> _handleAutosave() async {
    if (_recipe != null && !hasValidationErrors) {
      await _recipeService.update(_recipe!);
    }
  }

  @override
  void dispose() {
    _validationManager.dispose();
    _imageManager.dispose();
    _autosaveManager.dispose();
    super.dispose();
  }
}
```

## Manager Base Class

```dart
/// Base class for ViewModel managers
abstract class ViewModelManager extends ChangeNotifier {
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Safely call notifyListeners if not disposed
  void notifyIfNotDisposed() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }
}
```

## Manager Examples

### Validation Manager

```dart
class RecipeValidationManager extends ViewModelManager {
  final Map<String, String?> _errors = {};

  Map<String, String?> get errors => Map.unmodifiable(_errors);
  bool get hasErrors => _errors.values.any((e) => e != null);
  bool get isValid => !hasErrors;

  void validateTitle(String value) {
    if (value.isEmpty) {
      _errors['title'] = 'Title is required';
    } else if (value.length < 3) {
      _errors['title'] = 'Title must be at least 3 characters';
    } else {
      _errors.remove('title');
    }
    notifyIfNotDisposed();
  }

  void validatePortions(int value) {
    if (value < 1) {
      _errors['portions'] = 'Must be at least 1';
    } else if (value > 100) {
      _errors['portions'] = 'Must be at most 100';
    } else {
      _errors.remove('portions');
    }
    notifyIfNotDisposed();
  }

  void clearErrors() {
    _errors.clear();
    notifyIfNotDisposed();
  }
}
```

### Selection Manager

```dart
class RecipeSelectionManager extends ViewModelManager {
  Set<String> _selectedIds = {};
  SelectionMode _mode = SelectionMode.none;

  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  SelectionMode get mode => _mode;
  bool get isSelecting => _mode != SelectionMode.none;
  int get selectedCount => _selectedIds.length;
  bool get hasSelection => _selectedIds.isNotEmpty;

  void enterSelectionMode() {
    _mode = SelectionMode.multiple;
    notifyIfNotDisposed();
  }

  void exitSelectionMode() {
    _mode = SelectionMode.none;
    _selectedIds.clear();
    notifyIfNotDisposed();
  }

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyIfNotDisposed();
  }

  void selectAll(List<String> ids) {
    _selectedIds.addAll(ids);
    notifyIfNotDisposed();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyIfNotDisposed();
  }
}
```

### Search Manager

```dart
class FriendsSearchManager extends ViewModelManager {
  String _query = '';
  List<User> _results = [];
  bool _isSearching = false;

  String get query => _query;
  List<User> get results => List.unmodifiable(_results);
  bool get isSearching => _isSearching;
  bool get hasQuery => _query.isNotEmpty;
  bool get hasResults => _results.isNotEmpty;

  Timer? _debounceTimer;

  Future<void> search(String query, Future<List<User>> Function(String) searchFn) async {
    _query = query;
    notifyIfNotDisposed();

    // Debounce
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      _results = [];
      _isSearching = false;
      notifyIfNotDisposed();
      return;
    }

    _isSearching = true;
    notifyIfNotDisposed();

    _debounceTimer = Timer(Duration(milliseconds: 500), () async {
      try {
        _results = await searchFn(query);
      } catch (e) {
        _results = [];
      } finally {
        _isSearching = false;
        notifyIfNotDisposed();
      }
    });
  }

  void clearSearch() {
    _query = '';
    _results = [];
    _debounceTimer?.cancel();
    notifyIfNotDisposed();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
```

### Image Manager

```dart
class RecipeImageManager extends ViewModelManager {
  final ImagePickerService _imagePicker;
  List<RecipeImage> _images = [];
  bool _isPickingImage = false;

  List<RecipeImage> get images => List.unmodifiable(_images);
  bool get isPickingImage => _isPickingImage;
  bool get hasImages => _images.isNotEmpty;
  int get imageCount => _images.length;

  RecipeImageManager({ImagePickerService? imagePicker})
      : _imagePicker = imagePicker ?? ServiceLocator.get<ImagePickerService>();

  Future<void> pickImage() async {
    _isPickingImage = true;
    notifyIfNotDisposed();

    try {
      final image = await _imagePicker.pickImage();
      if (image != null) {
        _images.add(image);
      }
    } finally {
      _isPickingImage = false;
      notifyIfNotDisposed();
    }
  }

  void removeImage(int index) {
    if (index >= 0 && index < _images.length) {
      _images.removeAt(index);
      notifyIfNotDisposed();
    }
  }

  void reorderImages(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final image = _images.removeAt(oldIndex);
    _images.insert(newIndex, image);
    notifyIfNotDisposed();
  }

  void clearImages() {
    _images.clear();
    notifyIfNotDisposed();
  }
}
```

### Autosave Manager

```dart
class RecipeAutosaveManager extends ViewModelManager {
  final Future<void> Function() onSave;

  Timer? _autosaveTimer;
  bool _isAutosaving = false;
  DateTime? _lastSaved;

  bool get isAutosaving => _isAutosaving;
  DateTime? get lastSaved => _lastSaved;
  bool get hasUnsavedChanges => _lastSaved == null ||
      DateTime.now().difference(_lastSaved!) > Duration(seconds: 30);

  RecipeAutosaveManager({required this.onSave});

  void scheduleAutosave({Duration delay = const Duration(seconds: 3)}) {
    _autosaveTimer?.cancel();

    _autosaveTimer = Timer(delay, () async {
      await _performAutosave();
    });
  }

  Future<void> _performAutosave() async {
    if (_isAutosaving) return;

    _isAutosaving = true;
    notifyIfNotDisposed();

    try {
      await onSave();
      _lastSaved = DateTime.now();
    } catch (e) {
      // Log error but don't propagate
    } finally {
      _isAutosaving = false;
      notifyIfNotDisposed();
    }
  }

  Future<void> forceSave() async {
    _autosaveTimer?.cancel();
    await _performAutosave();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }
}
```

## Real-World Example: FriendsViewModel

```dart
/// Friends management ViewModel using manager delegation
/// Total: 905 lines (acceptable with facade pattern)
class FriendsViewModel extends ChangeNotifier {
  // Managers (extracted to separate files)
  late final FriendsSearchManager _searchManager;
  late final FriendsProfileCacheManager _profileManager;
  late final FriendsSelectionManager _selectionManager;
  late final FriendsCategoryManager _categoryManager;
  late final FriendsFilterManager _filterManager;
  late final FriendsRequestManager _requestManager;

  // Services
  final UnifiedFriendsService _friendsService;

  // Local state (minimal)
  List<UserProfile> _friends = [];
  bool _isLoading = false;

  // Public getters (expose manager state)
  List<UserProfile> get friends => _friends;
  bool get isLoading => _isLoading;

  // Search manager state
  String get searchQuery => _searchManager.searchQuery;
  bool get isSearching => _searchManager.isSearching;
  List<UserProfile> get searchResults => _searchManager.searchResults;

  // Selection manager state
  Set<String> get selectedIds => _selectionManager.selectedIds;
  bool get isSelecting => _selectionManager.isSelecting;
  int get selectedCount => _selectionManager.selectedCount;

  // Category manager state
  List<FriendCategory> get categories => _categoryManager.categories;
  FriendCategory? get selectedCategory => _categoryManager.selectedCategory;

  // Filter manager state
  FriendFilter get currentFilter => _filterManager.currentFilter;
  List<UserProfile> get filteredFriends => _filterManager.apply(_friends);

  // Request manager state
  List<FriendRequest> get pendingRequests => _requestManager.pendingRequests;
  int get pendingCount => _requestManager.pendingCount;

  FriendsViewModel({
    required UnifiedFriendsService friendsService,
  }) : _friendsService = friendsService {
    // Initialize managers
    _searchManager = FriendsSearchManager();
    _profileManager = FriendsProfileCacheManager();
    _selectionManager = FriendsSelectionManager();
    _categoryManager = FriendsCategoryManager();
    _filterManager = FriendsFilterManager();
    _requestManager = FriendsRequestManager();

    // Register listeners
    _searchManager.addListener(_onSearchChanged);
    _selectionManager.addListener(notifyListeners);
    _categoryManager.addListener(_onCategoryChanged);
    _filterManager.addListener(notifyListeners);
    _requestManager.addListener(notifyListeners);

    // Load initial data
    _loadInitialData();
  }

  // Delegate methods
  Future<void> search(String query) async {
    await _searchManager.search(query, _friendsService.searchFriends);
  }

  void toggleSelection(String userId) {
    _selectionManager.toggleSelection(userId);
  }

  void selectCategory(FriendCategory category) {
    _categoryManager.selectCategory(category);
  }

  void setFilter(FriendFilter filter) {
    _filterManager.setFilter(filter);
  }

  Future<void> sendFriendRequest(String userId) async {
    await _requestManager.sendRequest(userId, _friendsService);
  }

  // Aggregation methods
  Future<void> deleteSelected() async {
    for (final id in selectedIds) {
      await _friendsService.removeFriend(id);
      _friends.removeWhere((f) => f.userId == id);
    }
    _selectionManager.clearSelection();
    notifyListeners();
  }

  void _onSearchChanged() {
    // Could trigger additional logic
    notifyListeners();
  }

  void _onCategoryChanged() {
    _loadFriendsForCategory();
    notifyListeners();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadFriends(),
      _requestManager.loadPendingRequests(_friendsService),
      _categoryManager.loadCategories(),
    ]);
  }

  Future<void> _loadFriends() async {
    _isLoading = true;
    notifyListeners();

    try {
      _friends = await _friendsService.getFriends();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFriendsForCategory() async {
    final category = _categoryManager.selectedCategory;
    if (category == null) {
      await _loadFriends();
    } else {
      _friends = await _friendsService.getFriendsByCategory(category.id);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _searchManager.dispose();
    _profileManager.dispose();
    _selectionManager.dispose();
    _categoryManager.dispose();
    _filterManager.dispose();
    _requestManager.dispose();
    super.dispose();
  }
}
```

## File Organization

```
lib/viewmodels/
├── friends_viewmodel.dart           (905 lines - facade)
└── friends/
    ├── friends_search_manager.dart       (120 lines)
    ├── friends_profile_cache_manager.dart (150 lines)
    ├── friends_selection_manager.dart    (80 lines)
    ├── friends_category_manager.dart     (180 lines)
    ├── friends_filter_manager.dart       (100 lines)
    └── friends_request_manager.dart      (140 lines)
```

## Testing Manager-Based ViewModels

### Test Individual Managers

```dart
void main() {
  group('RecipeValidationManager', () {
    late RecipeValidationManager manager;

    setUp(() {
      manager = RecipeValidationManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('validates title correctly', () {
      manager.validateTitle('');
      expect(manager.hasErrors, isTrue);
      expect(manager.errors['title'], 'Title is required');

      manager.validateTitle('ab');
      expect(manager.hasErrors, isTrue);

      manager.validateTitle('Valid Title');
      expect(manager.hasErrors, isFalse);
    });

    test('notifies listeners on validation change', () {
      var notificationCount = 0;
      manager.addListener(() => notificationCount++);

      manager.validateTitle('Test');

      expect(notificationCount, 1);
    });
  });
}
```

### Test ViewModel with Mocked Managers

```dart
void main() {
  late RecipeFormViewModel viewModel;
  late MockRecipeService mockService;
  late MockRecipeValidationManager mockValidation;

  setUp(() {
    mockService = MockRecipeService();
    mockValidation = MockRecipeValidationManager();

    viewModel = RecipeFormViewModel(
      recipeService: mockService,
      validationManager: mockValidation,  // Inject mock
    );
  });

  test('canSave returns false when validation errors', () {
    when(() => mockValidation.hasErrors).thenReturn(true);

    expect(viewModel.canSave, isFalse);
  });

  test('delegates validation to manager', () {
    viewModel.validateTitle('Test');

    verify(() => mockValidation.validateTitle('Test')).called(1);
  });
}
```

## Benefits

1. **Maintainability**: Each manager has single responsibility
2. **Testability**: Test managers independently
3. **Reusability**: Managers can be shared across ViewModels
4. **Scalability**: Add new managers without modifying main ViewModel
5. **Code Review**: Easier to review focused manager files
6. **Acceptable File Size**: 500+ lines OK with clear modularization

## When NOT to Use

Don't use manager delegation for:
- Simple ViewModels (<300 lines)
- ViewModels with no clear feature boundaries
- When BaseViewModel or AsyncOperationMixin is sufficient
- Over-engineering simple CRUD screens

## Best Practices

1. **Single Responsibility**: Each manager handles one feature
2. **Clear Naming**: `<Feature>Manager` (SearchManager, ValidationManager)
3. **Encapsulation**: Managers expose only necessary state
4. **Listener Management**: Main ViewModel registers manager listeners
5. **Disposal**: Always dispose managers in main ViewModel
6. **Testing**: Test managers independently first
7. **Documentation**: Document manager responsibilities

## Common Manager Types

- **ValidationManager**: Form validation
- **SearchManager**: Debounced search
- **SelectionManager**: Multi-select state
- **FilterManager**: Data filtering
- **PaginationManager**: Infinite scroll
- **CacheManager**: Data caching
- **SyncManager**: Data synchronization
- **ImageManager**: Image handling
- **AutosaveManager**: Automatic saving

## Related Resources

- [ChangeNotifier Pattern](changenotifier-pattern.md) - Manager foundation
- [AsyncOperationMixin](async-operation-mixin.md) - Alternative for simpler cases
- butlery-architecture skill - Facade pattern overview
