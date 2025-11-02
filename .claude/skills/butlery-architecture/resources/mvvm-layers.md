# MVVM Layer Separation in Butlery

This document provides detailed guidance on layer responsibilities and communication patterns in Butlery's MVVM architecture.

## The Four Layers

### 1. Presentation Layer
**Location**: `lib/views/`, `lib/viewmodels/`, `lib/widgets/`
**Responsibility**: UI and presentation logic only

#### Views (`lib/views/`)
- Stateless or Stateful widgets
- **NO business logic** - only UI composition
- **NO direct service access** - use ViewModels via Provider
- **NO data fetching** - ViewModels handle this

**✅ Good View Example**:
```dart
// lib/views/recipe_detail_view.dart
class RecipeDetailView extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailView({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServiceLocator.get<RecipeDetailViewModel>()
        ..initialize(recipe),
      child: Consumer<RecipeDetailViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          return Scaffold(
            appBar: AppBar(title: Text(viewModel.recipe.title)),
            body: _buildRecipeContent(context, viewModel),
          );
        },
      ),
    );
  }

  Widget _buildRecipeContent(BuildContext context, RecipeDetailViewModel vm) {
    // UI composition only
    return Column(
      children: [
        RecipeImage(imageUrl: vm.recipe.imageUrl),
        RecipeIngredients(ingredients: vm.recipe.ingredients),
        RecipeInstructions(instructions: vm.recipe.instructions),
      ],
    );
  }
}
```

**❌ Bad View Example**:
```dart
class BadView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // ❌ Direct service access in view
    final service = ServiceLocator.get<RecipeService>();

    return ElevatedButton(
      onPressed: () async {
        // ❌ Business logic in view
        final recipe = await service.getRecipe(recipeId);
        // ❌ No loading/error handling
      },
      child: Text('Load Recipe'),
    );
  }
}
```

#### ViewModels (`lib/viewmodels/`)
- Extend `ChangeNotifier` with `StateNotifierMixin` and optionally `AsyncOperationMixin`
- **NO direct repository access** - use services
- **YES** to loading/error state management
- **YES** to user input validation
- **YES** to coordinating multiple services

**✅ Good ViewModel Example**:
```dart
// lib/viewmodels/recipe_list_viewmodel.dart
class RecipeListViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {
  final UnifiedRecipeService _recipeService;

  List<Recipe> _recipes = [];
  List<Recipe> get recipes => List.unmodifiable(_recipes);

  RecipeListViewModel({
    UnifiedRecipeService? recipeService,
  }) : _recipeService = recipeService ?? ServiceLocator.get<UnifiedRecipeService>();

  Future<void> loadRecipes() => executeAsync(() async {
    _recipes = await _recipeService.personal.getAllRecipes();
    notifyListeners();
  });
  // isLoading, hasError, errorMessage provided by AsyncOperationMixin

  Future<void> deleteRecipe(String id) => executeAsync(() async {
    await _recipeService.personal.deleteRecipe(id);
    _recipes.removeWhere((r) => r.id == id);
    notifyListeners();
  });
}
```

**❌ Bad ViewModel Example**:
```dart
class BadViewModel extends ChangeNotifier {
  final RecipeRepository _repository;  // ❌ Direct repository access

  BadViewModel({required RecipeRepository repository})
      : _repository = repository;

  Future<void> loadRecipes() async {
    // ❌ No loading state management
    // ❌ No error handling
    _recipes = await _repository.readAll();  // ❌ Bypasses business logic
    notifyListeners();
  }
}
```

#### Widgets (`lib/widgets/`)
- Reusable UI components
- Can be stateful or stateless
- Accept data via constructor parameters
- Callbacks for user interactions

**✅ Good Widget Example**:
```dart
// lib/widgets/recipe/recipe_card.dart
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const RecipeCard({
    required this.recipe,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          children: [
            if (recipe.imageUrl != null)
              CachedNetworkImage(imageUrl: recipe.imageUrl!),
            Text(recipe.title, style: Theme.of(context).textTheme.titleLarge),
            Text('${recipe.portions} portioner'),
          ],
        ),
      ),
    );
  }
}
```

---

### 2. Business Layer
**Location**: `lib/services/`
**Responsibility**: Business logic, workflows, coordinating repositories

#### Services (`lib/services/`)
- **MUST** extend `BaseService` (includes ErrorHandlingMixin)
- Coordinate one or more repositories
- Implement business rules and workflows
- **NO direct Firebase access** - use repositories
- **YES** to auth checks, network checks, caching
- **YES** to coordinating multiple data sources

**✅ Good Service Example**:
```dart
// lib/services/recipe_discovery_service.dart
class RecipeDiscoveryService extends BaseService {
  final SocialRecipeRepository _socialRepository;
  final UserRepository _userRepository;
  final FriendsRepository _friendsRepository;

  RecipeDiscoveryService({
    required SocialRecipeRepository socialRepository,
    required UserRepository userRepository,
    required FriendsRepository friendsRepository,
  })  : _socialRepository = socialRepository,
        _userRepository = userRepository,
        _friendsRepository = friendsRepository;

  @override
  String get serviceName => 'RecipeDiscoveryService';

  Future<List<SharedRecipe>> discoverRecipes() async {
    return await executeServiceOperation(
      () async {
        // Business logic: get recipes from friends
        final friendIds = await _friendsRepository.getFriendIds();
        final userProfile = await _userRepository.getCurrentUserProfile();

        // Business logic: filter based on user preferences
        final recipes = await _socialRepository.getDiscoverableRecipes();
        return recipes.where((recipe) {
          return friendIds.contains(recipe.ownerId) ||
              _matchesUserPreferences(recipe, userProfile);
        }).toList();
      },
      operationName: 'Discover recipes',
      requiresAuth: true,
    );
  }

  bool _matchesUserPreferences(SharedRecipe recipe, UserProfile profile) {
    // Business rule implementation
    return true;  // Simplified
  }
}
```

**❌ Bad Service Example**:
```dart
// ❌ Not extending BaseService
class BadService {
  Future<Recipe?> getRecipe(String id) async {
    try {  // ❌ Manual error handling
      // ❌ Direct Firestore access
      final doc = await FirebaseFirestore.instance
          .collection('recipes')
          .doc(id)
          .get();

      return Recipe.fromFirestore(doc);
    } catch (e) {
      print('Error: $e');  // ❌ Poor error handling
      return null;
    }
  }
}
```

#### Layered Services (Unified Services)

Complex domains use a **layered service architecture**:

```dart
// lib/services/unified/unified_recipe_service.dart
class UnifiedRecipeService extends BaseService {
  final PersonalRecipeModule _personal;
  final SocialRecipeCoordinator _social;
  final RealtimeRecipeService _realtime;
  final RecipeSharingManager _share;

  // Layer 1: Personal Operations
  PersonalRecipeModule get personal => _personal;

  // Layer 2: Social Operations
  SocialRecipeCoordinator get social => _social;

  // Layer 3: Realtime Operations
  RealtimeRecipeService get realtime => _realtime;

  // Layer 4: Share Operations
  RecipeSharingManager get share => _share;

  @override
  String get serviceName => 'UnifiedRecipeService';
}
```

**Usage Rules**:
- Personal operations: `service.personal.createRecipe(...)`
- Social operations: `service.social.shareWithFriends(...)`
- Realtime operations: `service.realtime.watchRecipe(...)`
- Share operations: `service.share.generateShareLink(...)`

**Don't mix layers** - each layer has its own responsibility.

---

### 3. Data Layer
**Location**: `lib/repositories/`, `lib/models/`
**Responsibility**: Data access, persistence, CRUD operations

#### Repositories (`lib/repositories/`)
- **MUST** extend `BaseFirebaseRepository<T>` for Firebase
- Implement repository interface from `lib/repositories/interfaces/`
- Handle all Firestore operations
- **MUST** validate permissions on CRUD operations
- **MUST** audit log sensitive operations
- **NO business logic** - only data access

**✅ Good Repository Example**:
```dart
// lib/repositories/firebase/firebase_recipe_repository.dart
class FirebaseRecipeRepository extends BaseFirebaseRepository<Recipe>
    with UserScopedFirebaseRepository<Recipe>
    implements RecipeRepository {

  FirebaseRecipeRepository({required super.authRepository});

  @override
  String get collectionName => 'recipes';

  @override
  Recipe fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Recipe.fromFirestore(doc);
  }

  @override
  Map<String, dynamic> toFirestore(Recipe recipe) {
    return recipe.toFirestore();
  }

  @override
  String getId(Recipe recipe) => recipe.id;

  @override
  Future<bool> validateUpdatePermission(String userId, Recipe entity) async {
    // Permission validation: user must own the recipe
    final ownerId = entity.socialData?.ownerId ?? entity.createdBy ?? userId;
    return ownerId == userId;
  }

  // CRUD operations inherited from BaseFirebaseRepository with:
  // - Permission validation (automatic via validateUpdatePermission)
  // - Audit logging (automatic via BaseFirebaseRepository)
  // - Error handling (automatic via ErrorHandlingMixin)
}
```

**❌ Bad Repository Example**:
```dart
// ❌ Not extending BaseFirebaseRepository
class BadRepository implements RecipeRepository {
  Future<Recipe> create(Recipe recipe) async {
    // ❌ No permission validation
    // ❌ No audit logging
    // ❌ Direct Firestore usage
    await FirebaseFirestore.instance
        .collection('recipes')
        .doc(recipe.id)
        .set(recipe.toMap());

    return recipe;
  }
}
```

#### Models (`lib/models/`)
- Immutable data classes
- Serialization methods: `fromFirestore()`, `toFirestore()`
- No business logic
- Use `copyWith()` for immutability

**✅ Good Model Example**:
```dart
// lib/models/recipe.dart
class Recipe {
  final String id;
  final String title;
  final List<String> ingredients;
  final DateTime createdAt;

  const Recipe({
    required this.id,
    required this.title,
    required this.ingredients,
    required this.createdAt,
  });

  factory Recipe.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Recipe(
      id: doc.id,
      title: data['title'] as String? ?? '',
      ingredients: (data['ingredients'] as List?)?.cast<String>() ?? [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'ingredients': ingredients,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Recipe copyWith({
    String? id,
    String? title,
    List<String>? ingredients,
    DateTime? createdAt,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      ingredients: ingredients ?? this.ingredients,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
```

---

### 4. Infrastructure Layer
**Location**: Firebase SDK, Platform APIs
**Responsibility**: External services, platform integration

- Firebase SDK (`cloud_firestore`, `firebase_auth`, `firebase_storage`)
- Platform services (`camera`, `image_picker`, `shared_preferences`)
- Network clients (`http`, `connectivity_plus`)

**Never access directly** - always use repositories or services.

---

## Communication Patterns

### View → ViewModel
```dart
// View listens to ViewModel via Provider
Consumer<RecipeViewModel>(
  builder: (context, viewModel, child) {
    return Text(viewModel.recipe.title);
  },
)

// View calls ViewModel methods
onPressed: () => viewModel.deleteRecipe()
```

### ViewModel → Service
```dart
// ViewModel accesses service via ServiceLocator or constructor injection
final service = ServiceLocator.get<UnifiedRecipeService>();

// ViewModel calls service methods
await service.personal.createRecipe(recipe);
```

### Service → Repository
```dart
// Service accesses repository via constructor injection
class MyService extends BaseService {
  final RecipeRepository _repository;

  MyService({required RecipeRepository repository})
      : _repository = repository;

  // Service calls repository methods
  await _repository.create(recipe);
}
```

### Repository → Firebase
```dart
// Repository accesses Firebase via BaseFirebaseRepository
// Firestore instance injected via constructor
// Operations use inherited methods: create(), read(), update(), delete()
```

---

## Layer Violation Detection

### ❌ View → Service (SKIP ViewModel)
```dart
// ❌ View directly accessing service
class BadView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final service = ServiceLocator.get<RecipeService>();  // ❌ No ViewModel

    return ElevatedButton(
      onPressed: () => service.deleteRecipe(id),  // ❌ Business logic in view
      child: Text('Delete'),
    );
  }
}
```

### ❌ ViewModel → Repository (SKIP Service)
```dart
// ❌ ViewModel directly accessing repository
class BadViewModel extends ChangeNotifier {
  final RecipeRepository _repository;  // ❌ Should use service

  Future<void> loadRecipes() async {
    _recipes = await _repository.readAll();  // ❌ Bypasses business logic
  }
}
```

### ❌ Service → Firebase (SKIP Repository)
```dart
// ❌ Service directly accessing Firebase
class BadService extends BaseService {
  Future<Recipe?> getRecipe(String id) async {
    // ❌ Direct Firestore access
    final doc = await FirebaseFirestore.instance
        .collection('recipes')
        .doc(id)
        .get();

    return Recipe.fromFirestore(doc);
  }
}
```

---

## Testing Each Layer

### Testing Views
- Use `testWidgets()` from `flutter_test`
- Pump the widget with test data
- Verify UI elements render correctly
- Test user interactions

### Testing ViewModels
- Mock services using `mocktail`
- Test state changes
- Verify `notifyListeners()` is called
- Test loading/error states

### Testing Services
- Mock repositories using `mocktail`
- Test business logic
- Verify repository method calls
- Test error handling

### Testing Repositories
- Use `FakeFirebaseFirestore` for Firestore operations
- Test CRUD operations
- Verify permission validation
- Test audit logging

---

## Summary: Layer Checklist

**Presentation Layer**:
- [ ] Views have NO business logic
- [ ] Views access ViewModels via Provider
- [ ] ViewModels extend ChangeNotifier
- [ ] ViewModels use services (not repositories)

**Business Layer**:
- [ ] Services extend BaseService
- [ ] Services coordinate repositories
- [ ] Services implement business rules
- [ ] Services use repositories (not Firebase directly)

**Data Layer**:
- [ ] Repositories extend BaseFirebaseRepository
- [ ] Repositories validate permissions
- [ ] Repositories audit log operations
- [ ] Models have serialization methods

**No Violations**:
- [ ] No View → Service direct access
- [ ] No ViewModel → Repository direct access
- [ ] No Service → Firebase direct access
- [ ] No legacy `sl<T>()` pattern
