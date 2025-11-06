# MVVM + Repository Pattern

**Complete guide to Butlery's 4-layer architecture**

**Last Updated**: January 2025
**Related Guides**: [Architecture Overview](ARCHITECTURE_OVERVIEW.md) | [DI System](DI_SYSTEM.md) | [Best Practices](BEST_PRACTICES.md)

---

## Pattern Overview

Butlery implements the **Model-View-ViewModel (MVVM)** pattern combined with the **Repository Pattern** for clean separation of concerns:

```
┌──────────┐     observes     ┌──────────────┐     uses      ┌────────────┐
│   View   │ ─────────────── │  ViewModel   │ ───────────── │  Service   │
└──────────┘                  └──────────────┘               └────────────┘
                                                                    │ uses
                                                              ┌─────▼──────┐
                                                              │ Repository │
                                                              └────────────┘
                                                                    │ implements
                                                              ┌─────▼──────┐
                                                              │  Firebase  │
                                                              └────────────┘
```

**Key Principles:**
- **Separation of Concerns**: Each layer has a single responsibility
- **Testability**: Every layer can be unit tested independently
- **Dependency Inversion**: Depend on abstractions, not concrete implementations
- **Unidirectional Data Flow**: Data flows down, events flow up

---

## Repository Layer

Repositories handle **data access** and **Firebase operations**.

### Base Repository Interface

```dart
// lib/repositories/interfaces/repository.dart
abstract class Repository<T> {
  Future<T> create(T entity);
  Future<T?> read(String id);
  Future<List<T>> readAll();
  Future<void> update(T entity);
  Future<void> delete(String id);
}
```

### Domain-Specific Repository Interfaces

**AuthRepository Interface:**
```dart
// lib/repositories/interfaces/auth_repository.dart
abstract class AuthRepository {
  Future<UserCredential> login(String email, String password);
  Future<UserCredential> createUser(String email, String password);
  Future<void> signOut();
  User? get currentUser;
  String? get currentUserId;
  Stream<User?> authStateChanges();
}
```

**RecipeRepository Interface:**
```dart
// lib/repositories/interfaces/recipe_repository.dart
abstract class RecipeRepository {
  Future<Recipe> create(Recipe recipe);
  Future<Recipe?> read(String id);
  Future<List<Recipe>> readAll();
  Stream<List<Recipe>> watchRecipes(String userId);
  Future<List<Recipe>> searchRecipes(String query);
}
```

### Firebase Implementations

**Firebase Auth Repository:**
```dart
// lib/repositories/firebase/firebase_auth_repository.dart
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;

  FirebaseAuthRepository({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  @override
  Future<UserCredential> login(String email, String password) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
  // ... other implementations
}
```

**Firebase Recipe Repository:**
```dart
// lib/repositories/firebase/firebase_recipe_repository.dart
class FirebaseRecipeRepository implements RecipeRepository {
  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;

  FirebaseRecipeRepository({
    FirebaseFirestore? firestore,
    required AuthRepository authRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _authRepository = authRepository;

  @override
  Future<Recipe> create(Recipe recipe) async {
    final ref = _userCollection;
    if (ref == null) throw Exception('No authenticated user');
    await ref.doc(recipe.id).set(recipe.toFirestore());
    return recipe;
  }

  // User-scoped data access
  CollectionReference<Map<String, dynamic>>? get _userCollection {
    final uid = _authRepository.currentUserId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('recipes');
  }
}
```

### Repository Directory Structure

```
lib/repositories/
├── interfaces/           # Abstract interfaces
│   ├── repository.dart
│   ├── auth_repository.dart
│   ├── recipe_repository.dart
│   ├── user_repository.dart
│   ├── friends_repository.dart
│   └── social_recipe_repository.dart
├── firebase/            # Firebase implementations
│   ├── firebase_auth_repository.dart
│   ├── firebase_recipe_repository.dart
│   ├── firebase_user_repository.dart
│   ├── firebase_friends_repository.dart
│   └── firebase_social_recipe_repository.dart
└── firestore_repository.dart  # Generic Firestore wrapper
```

---

## Service Layer

Services handle **business logic** and coordinate between repositories.

### Key Services

1. **AuthService**: Authentication workflows
2. **UnifiedRecipeService**: Recipe CRUD and business logic
3. **UserService**: User profile management
4. **UnifiedFriendsService**: Social connections
5. **SocialRecipeService**: Recipe sharing functionality
6. **OfflineService**: Local storage and sync

### Service Implementation Pattern

```dart
class RecipeService extends ChangeNotifier {
  final RecipeRepository _recipeRepository;
  final AuthRepository _authRepository;

  RecipeService({
    required RecipeRepository recipeRepository,
    required AuthRepository authRepository,
  }) : _recipeRepository = recipeRepository,
       _authRepository = authRepository;

  // Business logic methods
  Future<void> createRecipe(Recipe recipe) async {
    final userId = _authRepository.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    await _recipeRepository.create(recipe);
    notifyListeners();
  }

  @override
  void dispose() {
    // Clean up resources
    super.dispose();
  }
}
```

### CRITICAL Data Source Rule

```dart
// ✅ CORRECT: Use UserService for complete user data
final userService = ServiceLocator.get<UserService>();
final userData = userService.currentUserProfile; // Settings, avatar, social features

// ✅ CORRECT: Use PermissionService only for auth/permissions
final permissionService = ServiceLocator.get<PermissionService>();
final canEdit = permissionService.currentUser; // Basic auth checks

// ❌ WRONG: Don't mix data sources!
// This leads to settings not persisting and UI inconsistencies
```

---

## ViewModel Layer

ViewModels manage **presentation logic** and **state** for views.

### ViewModel Pattern

```dart
class RecipeViewModel extends ChangeNotifier {
  final _recipeService = ServiceLocator.get<UnifiedRecipeService>();
  final _authService = ServiceLocator.get<AuthService>();

  List<Recipe> _recipes = [];
  bool _isLoading = false;
  String? _error;

  List<Recipe> get recipes => _recipes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadRecipes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _recipes = await _recipeService.getRecipes();
    } catch (e) {
      _error = 'Failed to load recipes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Clean up subscriptions
    super.dispose();
  }
}
```

### ViewModel Statistics

- **89 ViewModels** in codebase
- **69% test coverage** (61/89 tested - better than documented!)
- **Grade**: A

---

## Manager Delegation Pattern

**For Complex ViewModels (>500 lines or multiple concerns)**

### Pattern Overview

Facade ViewModel delegates to specialized manager classes to maintain Single Responsibility Principle.

### When to Use

- ✅ ViewModel >500 lines with distinct concerns
- ✅ Complex state management (forms, search, caching, real-time)
- ✅ Multiple feature areas in one ViewModel
- ✅ Need to test individual concerns in isolation

### Examples in Codebase

- **FriendsViewModel** (15+ ViewModels use this pattern)
  - Delegates to: `FriendsSearchManager`, `FriendsProfileCacheManager`, `FriendsSelectionManager`
- **RecipeFormViewModel** (905 lines - exemplary facade)
  - Delegates to 6 managers: Image, Ingredient, Instruction, Tag, Validation, AutoSave
- **CollaborativeShoppingViewModel**
  - Delegates to: List management, item management, member management, sync management

### Implementation Pattern

```dart
// Facade ViewModel coordinates managers
class FriendsViewModel extends ChangeNotifier {
  // Specialized managers handle distinct concerns
  late final FriendsSearchManager _searchManager;
  late final FriendsProfileCacheManager _profileCacheManager;
  late final FriendsSelectionManager _selectionManager;

  FriendsViewModel({
    required UserService userService,
    required FriendsService friendsService,
  }) {
    // Initialize managers with dependencies
    _searchManager = FriendsSearchManager(friendsService);
    _profileCacheManager = FriendsProfileCacheManager(userService);
    _selectionManager = FriendsSelectionManager();
  }

  // Expose manager functionality through facade
  Future<void> searchFriends(String query) async {
    final results = await _searchManager.search(query);
    notifyListeners();
  }

  UserProfile? getCachedProfile(String userId) {
    return _profileCacheManager.getProfile(userId);
  }

  void selectFriend(String friendId) {
    _selectionManager.select(friendId);
    notifyListeners();
  }

  @override
  void dispose() {
    _searchManager.dispose();
    _profileCacheManager.dispose();
    _selectionManager.dispose();
    super.dispose();
  }
}

// Manager classes are focused and testable
class FriendsSearchManager {
  final FriendsService _friendsService;

  FriendsSearchManager(this._friendsService);

  List<UserProfile> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;

  List<UserProfile> get results => _searchResults;
  bool get isSearching => _isSearching;
  String? get error => _searchError;

  Future<List<UserProfile>> search(String query) async {
    _isSearching = true;
    _searchError = null;

    try {
      _searchResults = await _friendsService.searchUsers(query);
      return _searchResults;
    } catch (e) {
      _searchError = 'Search failed: $e';
      return [];
    } finally {
      _isSearching = false;
    }
  }

  void dispose() {
    _searchResults = [];
  }
}
```

### Benefits

- ✅ Each manager stays <500 lines (testable, maintainable)
- ✅ Clear separation of concerns
- ✅ Managers are independently testable
- ✅ ViewModel facade coordinates without bloat
- ✅ Easy to add new managers without modifying existing code

### Testing Pattern

```dart
// Test managers in isolation
test('FriendsSearchManager handles search correctly', () async {
  final mockService = MockFriendsService();
  final manager = FriendsSearchManager(mockService);

  when(mockService.searchUsers(any))
      .thenAnswer((_) async => [testUserProfile]);

  final results = await manager.search('John');

  expect(results, hasLength(1));
  expect(manager.isSearching, false);
  expect(manager.error, isNull);
});

// Test ViewModel coordination
test('FriendsViewModel coordinates managers', () {
  final viewModel = FriendsViewModel(
    userService: mockUserService,
    friendsService: mockFriendsService,
  );

  // Verify facade delegates correctly
  viewModel.searchFriends('query');
  verify(mockFriendsService.searchUsers('query')).called(1);
});
```

### Anti-Patterns to Avoid

- ❌ Don't create managers for simple ViewModels (<500 lines)
- ❌ Don't make managers depend on each other (keep them independent)
- ❌ Don't leak manager implementations to Views (expose through facade only)
- ❌ Don't use this pattern prematurely (start simple, refactor when needed)

---

## View Layer

Views are **pure UI components** that observe ViewModels.

### View Pattern

```dart
class RecipeListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecipeViewModel()..loadRecipes(),
      child: Consumer<RecipeViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return LoadingIndicator();
          }

          if (viewModel.error != null) {
            return ErrorDisplay(error: viewModel.error!);
          }

          return ListView.builder(
            itemCount: viewModel.recipes.length,
            itemBuilder: (context, index) {
              return RecipeCard(recipe: viewModel.recipes[index]);
            },
          );
        },
      ),
    );
  }
}
```

### View Statistics

- **~100 Views** in codebase
- **ComponentThemes** used 100%
- **Swedish localization** complete

### View Best Practices

**✅ DO:**
- Use ChangeNotifierProvider to provide ViewModels
- Access ViewModels via Consumer or Provider.of
- Keep views stateless when possible
- Extract reusable widgets to separate files

**❌ DON'T:**
- Put business logic in views
- Access repositories or services directly
- Mix multiple ViewModels in a single view without clear separation
- Create stateful views when ChangeNotifier can handle the state

---

## Complete Flow Example

### Creating a New Recipe

**1. User taps "Save" button in View:**
```dart
// lib/views/edit_recipe_view.dart
ElevatedButton(
  onPressed: () => viewModel.saveRecipe(recipe),
  child: Text('Save'),
)
```

**2. ViewModel handles the event:**
```dart
// lib/viewmodels/recipe_form_viewmodel.dart
Future<void> saveRecipe(Recipe recipe) async {
  _isSaving = true;
  notifyListeners();

  try {
    await _recipeService.createRecipe(recipe);
    _navigationService.goBack();
  } catch (e) {
    _error = 'Failed to save: $e';
  } finally {
    _isSaving = false;
    notifyListeners();
  }
}
```

**3. Service coordinates business logic:**
```dart
// lib/services/unified/unified_recipe_service.dart
Future<void> createRecipe(Recipe recipe) async {
  // Validate recipe
  _validateRecipe(recipe);

  // Create via repository
  await _recipeRepository.create(recipe);

  // Update cache
  _cache.add(recipe);

  // Notify listeners
  notifyListeners();
}
```

**4. Repository persists to Firebase:**
```dart
// lib/repositories/firebase/firebase_recipe_repository.dart
@override
Future<Recipe> create(Recipe recipe) async {
  final ref = _userCollection;
  if (ref == null) throw Exception('No authenticated user');

  await ref.doc(recipe.id).set(recipe.toFirestore());
  return recipe;
}
```

---

## Architecture Benefits

### Testability
- Each layer tested independently
- Easy to mock dependencies
- Clear interfaces for testing

### Maintainability
- Clear separation of concerns
- Easy to locate and fix bugs
- Each class has single responsibility

### Scalability
- Add new features without modifying existing code
- Easy to add new services/repositories
- Manager pattern handles complex ViewModels

### Flexibility
- Can swap Firebase for another backend
- Easy to add caching or offline support
- Testable without Firebase emulator

---

## Common Patterns

### Loading States
```dart
// In ViewModel
bool _isLoading = false;
bool get isLoading => _isLoading;

// In View
if (viewModel.isLoading) {
  return LoadingIndicator();
}
```

### Error Handling
```dart
// In ViewModel
String? _error;
String? get error => _error;

void clearError() {
  _error = null;
  notifyListeners();
}

// In View
if (viewModel.error != null) {
  return ErrorDisplay(
    error: viewModel.error!,
    onRetry: viewModel.clearError,
  );
}
```

### Real-time Updates
```dart
// In Repository
Stream<List<Recipe>> watchRecipes(String userId) {
  return _firestore
      .collection('users')
      .doc(userId)
      .collection('recipes')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Recipe.fromFirestore(doc))
          .toList());
}

// In ViewModel
StreamSubscription? _recipesSubscription;

void watchRecipes() {
  _recipesSubscription = _recipeService
      .watchRecipes()
      .listen((recipes) {
    _recipes = recipes;
    notifyListeners();
  });
}

@override
void dispose() {
  _recipesSubscription?.cancel();
  super.dispose();
}
```

---

## Next Steps

- **Implement a feature**: Follow this pattern for new features
- **Learn DI System**: See [DI_SYSTEM.md](DI_SYSTEM.md) for dependency injection
- **Firebase Integration**: See [FIREBASE_INTEGRATION.md](FIREBASE_INTEGRATION.md) for backend details
- **Best Practices**: See [BEST_PRACTICES.md](BEST_PRACTICES.md) for common scenarios

---

**Last Updated**: January 2025 | **Verified Against**: Actual codebase implementation
