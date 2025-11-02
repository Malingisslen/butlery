# AsyncOperationMixin

Advanced async state management mixin providing debouncing, caching, named operations, and concurrency control for ViewModels.

## Overview

AsyncOperationMixin enhances BaseViewModel with:
- **Named Operations**: Prevent duplicate concurrent executions
- **Debouncing**: Delay execution until input stops (search)
- **Throttling**: Rate limit execution frequency
- **Caching**: Store and reuse operation results
- **Batch Operations**: Execute multiple operations together
- **Automatic State**: Loading/error management built-in

## When to Use

**Use AsyncOperationMixin when**:
- Search or filter operations (debouncing)
- API calls that shouldn't run concurrently
- Operations that benefit from caching
- Complex async workflows

**Don't use when**:
- Simple CRUD operations (use BaseViewModel)
- Well-architected custom state management (streams, managers)
- ViewModels with complex business logic (may conflict)

## Basic Usage

```dart
class FriendsViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {
  final FriendsService _service;

  List<User> _friends = [];
  List<User> get friends => _friends;

  FriendsViewModel({
    required FriendsService service,
  }) : _service = service;

  // Simple async operation with automatic loading/error states
  Future<void> loadFriends() async {
    await executeAsync(() async {
      _friends = await _service.getFriends();
    });
  }
}
```

**What executeAsync() provides**:
- Sets `isLoading = true` before operation
- Clears error state
- Catches exceptions and sets `error`
- Sets `isLoading = false` after completion
- Calls `notifyListeners()` at appropriate times

## Named Operations

Prevent duplicate concurrent executions of the same operation:

```dart
class RecipeViewModel extends ChangeNotifier with AsyncOperationMixin {
  Future<void> loadRecipes() async {
    // Only one 'load_recipes' operation can run at a time
    await executeNamedOperation(
      'load_recipes',
      () async {
        _recipes = await _service.getUserRecipes();
      },
    );
  }

  Future<void> refreshRecipes() async {
    // Same name = won't run if loadRecipes() is still running
    await executeNamedOperation(
      'load_recipes',
      () async {
        _recipes = await _service.getUserRecipes();
      },
    );
  }
}
```

**Testing named operations**:

```dart
test('prevents duplicate named operations', () async {
  when(() => mockService.getUserRecipes())
      .thenAnswer((_) => Future.delayed(Duration(seconds: 1), () => []));

  // Start first operation
  final op1 = viewModel.loadRecipes();

  // Start second operation (should be ignored)
  final op2 = viewModel.loadRecipes();

  await Future.wait([op1, op2]);

  // Service called only once
  verify(() => mockService.getUserRecipes()).called(1);
});
```

## Debouncing

Delay execution until input stops changing (perfect for search):

```dart
class SearchViewModel extends ChangeNotifier with AsyncOperationMixin {
  final SearchService _service;

  String _searchQuery = '';
  List<Result> _results = [];

  List<Result> get results => _results;

  // Debounce search - waits 500ms after last call
  Future<void> search(String query) async {
    _searchQuery = query;

    await executeDebounced(
      'search',  // Operation name
      () async {
        if (_searchQuery.isEmpty) {
          _results = [];
        } else {
          _results = await _service.search(_searchQuery);
        }
      },
      Duration(milliseconds: 500),  // Debounce duration
    );
  }
}

// Usage in view
TextField(
  onChanged: (value) => viewModel.search(value),
  // User types: "r" -> "re" -> "rec" -> "recipe"
  // Only searches once after user stops typing for 500ms
)
```

**How debouncing works**:
1. User types "r" → timer starts (500ms)
2. User types "re" → previous timer canceled, new timer starts
3. User types "rec" → previous timer canceled, new timer starts
4. User stops typing → after 500ms, search executes once

## Throttling

Rate limit execution frequency:

```dart
class LocationViewModel extends ChangeNotifier with AsyncOperationMixin {
  Future<void> updateLocation(LatLng location) async {
    // Throttle - execute at most once per 2 seconds
    await executeThrottled(
      'update_location',
      () async {
        await _service.updateLocation(location);
      },
      Duration(seconds: 2),
    );
  }
}

// If called 10 times in 5 seconds, only executes 3 times (at 0s, 2s, 4s)
```

## Caching

Cache operation results with automatic expiry:

```dart
class ProfileViewModel extends ChangeNotifier with AsyncOperationMixin {
  Future<UserProfile?> loadProfile(String userId) async {
    return await executeCached(
      'profile_$userId',  // Cache key
      () async => await _service.getUserProfile(userId),
      Duration(minutes: 5),  // Cache expires after 5 minutes
    );
  }

  // Clear cache manually
  void clearProfileCache(String userId) {
    clearCache('profile_$userId');
  }

  // Clear all cache
  void clearAllCache() {
    clearAllCaches();
  }
}
```

**Cache behavior**:
- First call: Executes operation, stores result
- Subsequent calls (within 5 min): Returns cached result immediately
- After expiry: Executes operation again, updates cache

## Batch Operations

Execute multiple operations together:

```dart
class SyncViewModel extends ChangeNotifier with AsyncOperationMixin {
  Future<void> syncAll() async {
    await executeBatch([
      () => _recipeService.sync(),
      () => _menuService.sync(),
      () => _shoppingService.sync(),
    ]);
  }
}

// All operations run in parallel
// Loading state managed automatically
// If any fails, error is set
```

## Sequential Operations

Execute operations one after another:

```dart
class SetupViewModel extends ChangeNotifier with AsyncOperationMixin {
  Future<void> setupAccount() async {
    await executeSequential([
      () => _createUserProfile(),
      () => _setupDefaultPreferences(),
      () => _loadInitialData(),
    ]);
  }
}

// Operations run in order: profile → preferences → data
// If any fails, sequence stops
```

## State Properties

AsyncOperationMixin includes StateNotifierMixin:

```dart
class MyViewModel extends ChangeNotifier with AsyncOperationMixin {
  // Automatically available:
  bool get isLoading => ...;        // Any operation running?
  String? get error => ...;         // Last error message
  bool get hasError => ...;         // Has error?
  bool get isSuccess => ...;        // Last operation succeeded?

  void clearError() { ... }         // Clear error state
  void clearSuccess() { ... }       // Clear success state
}
```

## Real-World Example: Friends Search

```dart
class FriendsViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {
  final FriendsService _service;

  List<User> _allFriends = [];
  List<User> _searchResults = [];
  String _searchQuery = '';

  List<User> get friends => _searchQuery.isEmpty ? _allFriends : _searchResults;
  String get searchQuery => _searchQuery;

  FriendsViewModel({required FriendsService service})
      : _service = service {
    loadFriends();
  }

  // Load friends with caching
  Future<void> loadFriends() async {
    await executeCached(
      'all_friends',
      () async {
        _allFriends = await _service.getFriends();
      },
      Duration(minutes: 5),
    );
  }

  // Debounced search
  Future<void> search(String query) async {
    _searchQuery = query;
    notifyListeners();  // Update query immediately

    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    await executeDebounced(
      'search_friends',
      () async {
        _searchResults = await _service.searchFriends(query);
      },
      Duration(milliseconds: 500),
    );
  }

  // Named operation prevents duplicate sends
  Future<void> sendFriendRequest(String userId) async {
    await executeNamedOperation(
      'send_request_$userId',
      () async {
        await _service.sendFriendRequest(userId);
        await loadFriends();  // Refresh
      },
    );
  }
}
```

## Decision Framework

**Use AsyncOperationMixin when**:
- ✅ Simple ViewModels with straightforward async operations
- ✅ Search/filter features needing debouncing
- ✅ Operations that shouldn't run concurrently
- ✅ Data that benefits from caching

**Use BaseViewModel instead when**:
- ✅ Custom state management is well-architected
- ✅ Stream-based reactive patterns
- ✅ Complex business logic with multiple state machines
- ✅ Manager-based delegation pattern (facade)

**Migration example**:

```dart
// Before: Manual state management
class RecipeViewModel extends BaseViewModel {
  bool _isLoading = false;
  String? _error;

  Future<void> loadRecipes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _recipes = await _service.getUserRecipes();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

// After: AsyncOperationMixin
class RecipeViewModel extends ChangeNotifier with AsyncOperationMixin {
  Future<void> loadRecipes() async {
    await executeAsync(() async {
      _recipes = await _service.getUserRecipes();
    });
    // isLoading, error, notifyListeners() handled automatically
  }
}
```

## Testing AsyncOperationMixin

```dart
void main() {
  late SearchViewModel viewModel;
  late MockSearchService mockService;

  setUp(() {
    mockService = MockSearchService();
    viewModel = SearchViewModel(service: mockService);
  });

  group('Debouncing', () {
    test('debounces rapid search calls', () async {
      when(() => mockService.search(any()))
          .thenAnswer((_) async => []);

      // Rapid calls
      viewModel.search('a');
      viewModel.search('ab');
      viewModel.search('abc');

      // Wait for debounce period
      await Future.delayed(Duration(milliseconds: 600));

      // Only last search executed
      verify(() => mockService.search('abc')).called(1);
      verifyNever(() => mockService.search('a'));
      verifyNever(() => mockService.search('ab'));
    });
  });

  group('Named Operations', () {
    test('prevents concurrent named operations', () async {
      when(() => mockService.load())
          .thenAnswer((_) => Future.delayed(Duration(seconds: 1)));

      final op1 = viewModel.loadData();
      final op2 = viewModel.loadData();

      await Future.wait([op1, op2]);

      verify(() => mockService.load()).called(1);
    });
  });

  group('Caching', () {
    test('caches operation results', () async {
      when(() => mockService.getProfile('user1'))
          .thenAnswer((_) async => testProfile);

      // First call
      final result1 = await viewModel.loadProfile('user1');

      // Second call (should use cache)
      final result2 = await viewModel.loadProfile('user1');

      // Service called only once
      verify(() => mockService.getProfile('user1')).called(1);

      expect(result1, result2);
    });
  });

  group('State Management', () {
    test('sets loading state during operation', () async {
      when(() => mockService.load())
          .thenAnswer((_) => Future.delayed(
            Duration(milliseconds: 100),
            () => [],
          ));

      expect(viewModel.isLoading, isFalse);

      final loadTask = viewModel.loadData();

      await Future.delayed(Duration(milliseconds: 10));
      expect(viewModel.isLoading, isTrue);

      await loadTask;
      expect(viewModel.isLoading, isFalse);
    });

    test('sets error on failure', () async {
      when(() => mockService.load())
          .thenThrow(Exception('Failed'));

      await viewModel.loadData();

      expect(viewModel.hasError, isTrue);
      expect(viewModel.error, contains('Failed'));
    });
  });
}
```

## Best Practices

1. **Name Operations Clearly**: Use descriptive names like `'load_recipes'` not `'op1'`
2. **Choose Right Debounce Duration**: 300-500ms for search, 1000ms for expensive operations
3. **Cache Wisely**: Cache stable data, not frequently changing data
4. **Clear Cache When Needed**: Clear cache after mutations (create/update/delete)
5. **Test Async Behavior**: Test debouncing, concurrency, error handling
6. **Don't Overuse**: Simple operations don't need all these features

## Common Patterns

### Search with Debouncing

```dart
Future<void> search(String query) async {
  _query = query;
  await executeDebounced('search', () async {
    _results = await _service.search(query);
  }, Duration(milliseconds: 500));
}
```

### Load with Caching

```dart
Future<void> loadData() async {
  await executeCached('data', () async {
    _data = await _service.load();
  }, Duration(minutes: 10));
}
```

### Prevent Duplicate Submissions

```dart
Future<void> submit() async {
  await executeNamedOperation('submit', () async {
    await _service.submit(_form);
  });
}
```

## Related Resources

- [ChangeNotifier Pattern](changenotifier-pattern.md) - Foundation for AsyncOperationMixin
- [Manager Delegation](manager-delegation.md) - Alternative for complex state
- Testing patterns - See testing-patterns skill
