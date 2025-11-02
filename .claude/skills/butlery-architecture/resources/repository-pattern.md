# Repository Pattern in Butlery

This guide covers Butlery's repository pattern implementation using BaseFirebaseRepository with permission validation, audit logging, and standardized CRUD operations.

## Overview

Repositories in Butlery handle all data access and persistence. They provide a clean abstraction over Firebase Firestore with built-in security and auditing.

**Key Characteristics**:
- Extend `BaseFirebaseRepository<T>` for Firebase repositories
- Implement repository interface from `lib/repositories/interfaces/`
- **MUST** validate permissions on all CRUD operations
- **MUST** audit log sensitive operations
- NO business logic - only data access

## BaseFirebaseRepository Architecture

### Core Functionality

BaseFirebaseRepository provides:
- ✅ Standard CRUD operations (create, read, update, delete)
- ✅ Permission validation via mixins
- ✅ Audit logging for GDPR Article 30 compliance
- ✅ Streaming support for real-time updates
- ✅ Batch operations
- ✅ User-scoped and global collections
- ✅ Error handling via ErrorHandlingMixin

### Basic Repository Implementation

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
    return Recipe.fromFirestore(doc);
  }

  @override
  Map<String, dynamic> toFirestore(Recipe recipe) {
    return recipe.toFirestore();
  }

  @override
  String getId(Recipe recipe) => recipe.id;
}
```

**That's it!** BaseFirebaseRepository provides all CRUD operations automatically.

## Permission Validation

### Why Permission Validation Matters

Permission validation ensures:
- Users can only access their own data
- Shared content respects ownership rules
- Security violations are logged
- GDPR compliance (data privacy)

### Validation Methods

Override these methods to implement permission checks:

```dart
class FirebaseRecipeRepository extends BaseFirebaseRepository<Recipe> {

  @override
  Future<bool> validateCreatePermission(String userId, Recipe entity) async {
    // User can create recipes for themselves
    final ownerId = entity.createdBy ?? userId;
    return ownerId == userId;
  }

  @override
  Future<bool> validateReadPermission(String userId, Recipe entity) async {
    // User can read their own recipes
    if (entity.createdBy == userId) return true;

    // Or recipes shared with them
    if (entity.socialData?.sharedWith?.contains(userId) ?? false) {
      return true;
    }

    return false;
  }

  @override
  Future<bool> validateUpdatePermission(String userId, Recipe entity) async {
    // Only owner can update
    final ownerId = entity.socialData?.ownerId ?? entity.createdBy ?? userId;
    return ownerId == userId;
  }

  @override
  Future<bool> validateDeletePermission(String userId, Recipe entity) async {
    // Only owner can delete
    final ownerId = entity.socialData?.ownerId ?? entity.createdBy ?? userId;
    return ownerId == userId;
  }
}
```

### Permission Validation Flow

When you call `repository.create(recipe)`:

1. **Pre-validation**: `validateCreatePermission()` is called
2. **If denied**: `PermissionDeniedException` thrown, audit logged
3. **If allowed**: Firestore operation proceeds
4. **Post-operation**: Audit log entry created

### Audit Logging

All permission checks are automatically logged:

```dart
// Automatic audit logging (no code needed)
// When permission denied:
await _auditRepository.log(AuditEvent(
  userId: userId,
  action: 'UNAUTHORIZED_CREATE_ATTEMPT',
  resourceType: 'Recipe',
  resourceId: recipe.id,
  timestamp: DateTime.now(),
));
```

## User-Scoped vs Global Collections

### User-Scoped Collections

User-scoped collections store data under user's document:
```
users/{userId}/recipes/{recipeId}
users/{userId}/menus/{menuId}
```

**Implementation**:
```dart
class FirebaseRecipeRepository extends BaseFirebaseRepository<Recipe>
    with UserScopedFirebaseRepository<Recipe> {  // ← User-scoped mixin

  @override
  String get collectionName => 'recipes';
  // Collection path automatically becomes: users/{userId}/recipes
}
```

### Global Collections

Global collections are shared across all users:
```
shared_recipes/{recipeId}
shared_menus/{menuId}
friends/{friendshipId}
```

**Implementation**:
```dart
class FirebaseSharedRecipeRepository extends BaseFirebaseRepository<SharedRecipe>
    implements SharedRecipeRepository {  // ← No user-scoped mixin

  @override
  String get collectionName => 'shared_recipes';
  // Collection path: shared_recipes (global)

  @override
  CollectionReference<Map<String, dynamic>> getCollectionRef() {
    return firestore.collection(collectionName);
  }
}
```

## CRUD Operations

### Create

```dart
// Service layer
final recipe = Recipe(
  id: const Uuid().v4(),
  title: 'My Recipe',
  ingredients: ['Ingredient 1'],
);

final created = await repository.create(recipe);
// ✅ Permission validated
// ✅ Audit logged
// ✅ Saved to Firestore
```

### Read (Single)

```dart
final recipe = await repository.read('recipe-id');
// ✅ Permission validated
// ✅ Returns null if not found or no permission
```

### Read (All)

```dart
final recipes = await repository.readAll();
// ✅ Returns only recipes user has permission to read
// ✅ User-scoped: automatic filtering by userId
// ✅ Global: filtered by permission validation
```

### Update

```dart
final updatedRecipe = recipe.copyWith(title: 'Updated Title');
await repository.update(updatedRecipe);
// ✅ Permission validated
// ✅ Audit logged
// ✅ Updated in Firestore
```

### Delete

```dart
await repository.delete('recipe-id');
// ✅ Permission validated
// ✅ Audit logged
// ✅ Deleted from Firestore
```

### Batch Operations

```dart
// Create multiple entities
await repository.batchCreate([recipe1, recipe2, recipe3]);

// Delete multiple entities
await repository.batchDelete(['id1', 'id2', 'id3']);
```

## Streaming Support

### Watch Single Entity

```dart
// In service layer
Stream<Recipe?> watchRecipe(String recipeId) {
  return repository.watch(recipeId);
}

// In ViewModel
_subscription = _service.watchRecipe(recipeId).listen((recipe) {
  if (recipe != null) {
    _recipe = recipe;
    notifyListeners();
  }
});
```

### Watch Collection

```dart
// In service layer
Stream<List<Recipe>> watchAllRecipes() {
  return repository.watchAll();
}

// In ViewModel
_subscription = _service.watchAllRecipes().listen((recipes) {
  _recipes = recipes;
  notifyListeners();
});
```

### Custom Queries

```dart
class FirebaseRecipeRepository extends BaseFirebaseRepository<Recipe> {
  // Custom query method
  Stream<List<Recipe>> watchRecipesByCategory(String category) {
    return getCollectionRef()
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => fromFirestore(doc))
            .toList());
  }
}
```

## Serialization (fromFirestore/toFirestore)

### fromFirestore Implementation

```dart
@override
Recipe fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data()!;

  return Recipe(
    id: doc.id,
    title: data['title'] as String? ?? '',
    description: data['description'] as String?,
    ingredients: (data['ingredients'] as List?)?.cast<String>() ?? [],
    portions: data['portions'] as int? ?? 4,
    createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    imageUrl: data['imageUrl'] as String?,
  );
}
```

**Tips**:
- Use null-safe operators (`as String?`, `?? ''`)
- Handle Timestamp → DateTime conversion
- Provide sensible defaults
- Cast lists to correct type

### toFirestore Implementation

```dart
@override
Map<String, dynamic> toFirestore(Recipe recipe) {
  return {
    'title': recipe.title,
    'description': recipe.description,
    'ingredients': recipe.ingredients,
    'portions': recipe.portions,
    'createdAt': Timestamp.fromDate(recipe.createdAt),
    'imageUrl': recipe.imageUrl,
    // Note: id is NOT included (stored as document ID)
  };
}
```

**Tips**:
- Don't include `id` (it's the document ID)
- Convert DateTime → Timestamp
- Omit null values if desired: `if (recipe.imageUrl != null) 'imageUrl': recipe.imageUrl`

### Better: Use SerializationUtils

Instead of manual parsing, use SerializationUtils for consistency:

```dart
@override
Recipe fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data()!;

  return Recipe(
    id: doc.id,
    title: SerializationUtils.safeString(data, 'title'),
    description: SerializationUtils.safeString(data, 'description'),
    ingredients: SerializationUtils.safeStringList(data, 'ingredients'),
    portions: SerializationUtils.safeInt(data, 'portions', defaultValue: 4),
    createdAt: SerializationUtils.safeDateTime(data, 'createdAt') ?? DateTime.now(),
    imageUrl: SerializationUtils.safeString(data, 'imageUrl'),
  );
}
```

## Repository Interface

Define repository interfaces for testability and abstraction:

```dart
// lib/repositories/interfaces/recipe_repository.dart
abstract class RecipeRepository {
  Future<Recipe> create(Recipe recipe);
  Future<Recipe?> read(String id);
  Future<List<Recipe>> readAll();
  Future<void> update(Recipe recipe);
  Future<void> delete(String id);

  Stream<Recipe?> watch(String id);
  Stream<List<Recipe>> watchAll();

  // Custom methods
  Future<List<Recipe>> searchByTitle(String query);
  Stream<List<Recipe>> watchByCategory(String category);
}

// Implementation
class FirebaseRecipeRepository extends BaseFirebaseRepository<Recipe>
    implements RecipeRepository {
  // Implement all interface methods
}
```

## Testing Repositories

Use FakeFirebaseFirestore for testing:

```dart
void main() {
  group('FirebaseRecipeRepository', () {
    late FirebaseRecipeRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepo = MockAuthRepository();
      mockAuthRepo.setAuthState(userId: 'user-1', isAuthenticated: true);

      repository = FirebaseRecipeRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    test('create() saves recipe to Firestore', () async {
      final recipe = Recipe(
        id: 'recipe-1',
        title: 'Test Recipe',
        createdBy: 'user-1',
      );

      await repository.create(recipe);

      final doc = await fakeFirestore
          .collection('users/user-1/recipes')
          .doc('recipe-1')
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()!['title'], equals('Test Recipe'));
    });

    test('create() validates permissions', () async {
      mockAuthRepo.setAuthState(user: null);

      final recipe = Recipe(id: 'recipe-1', title: 'Test');

      expect(
        () => repository.create(recipe),
        throwsA(isA<AuthenticationException>()),
      );
    });
  });
}
```

## Common Patterns

### Pattern 1: Soft Delete

```dart
class FirebaseRecipeRepository extends BaseFirebaseRepository<Recipe> {
  @override
  Future<void> delete(String id) async {
    // Soft delete: mark as deleted instead of removing
    final recipe = await read(id);
    if (recipe != null) {
      final deletedRecipe = recipe.copyWith(
        deletedAt: DateTime.now(),
        isDeleted: true,
      );
      await update(deletedRecipe);
    }
  }

  @override
  Future<List<Recipe>> readAll() async {
    final all = await super.readAll();
    // Filter out soft-deleted
    return all.where((r) => !(r.isDeleted ?? false)).toList();
  }
}
```

### Pattern 2: Pagination

```dart
class FirebaseRecipeRepository extends BaseFirebaseRepository<Recipe> {
  Future<List<Recipe>> readPage({
    required int pageSize,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = getCollectionRef()
        .orderBy('createdAt', descending: true)
        .limit(pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
  }
}
```

### Pattern 3: Search

```dart
class FirebaseRecipeRepository extends BaseFirebaseRepository<Recipe> {
  Future<List<Recipe>> searchByTitle(String query) async {
    final all = await readAll();
    return all.where((recipe) {
      return recipe.title.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  // Better: Use Firestore query (limited to prefix search)
  Future<List<Recipe>> searchByTitlePrefix(String prefix) async {
    final snapshot = await getCollectionRef()
        .where('title', isGreaterThanOrEqualTo: prefix)
        .where('title', isLessThan: prefix + '\uf8ff')
        .get();

    return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
  }
}
```

### Pattern 4: Composite Repositories (Facades)

For complex domains with multiple collections:

```dart
// lib/repositories/firebase/friends/firebase_friends_repository.dart
class FirebaseFriendsRepository implements FriendsRepository {
  final FirebaseFriendshipsRepository _friendships;
  final FirebaseFriendRequestsRepository _requests;
  final FirebaseBlockedUsersRepository _blocked;
  final FirebaseFriendSuggestionsRepository _suggestions;

  FirebaseFriendsRepository({
    required FirebaseFriendshipsRepository friendships,
    required FirebaseFriendRequestsRepository requests,
    required FirebaseBlockedUsersRepository blocked,
    required FirebaseFriendSuggestionsRepository suggestions,
  })  : _friendships = friendships,
        _requests = requests,
        _blocked = blocked,
        _suggestions = suggestions;

  // Delegates to sub-repositories
  @override
  Future<List<String>> getFriendIds() => _friendships.getFriendIds();

  @override
  Future<void> sendFriendRequest(String userId) =>
      _requests.sendRequest(userId);

  @override
  Future<void> blockUser(String userId) => _blocked.blockUser(userId);
}
```

## Repository Registration in DI

```dart
// In DI module
class ContentModule implements DIModule {
  @override
  Future<void> configure(GetIt container) async {
    // Register repository
    container.registerSingleton<RecipeRepository>(
      FirebaseRecipeRepository(
        authRepository: container<AuthRepository>(),
        auditRepository: container<FirebaseAuditRepository>(),
      ),
    );
  }
}
```

## Common Mistakes

### ❌ Mistake 1: Business Logic in Repository

```dart
// ❌ BAD
class FirebaseRecipeRepository extends BaseFirebaseRepository<Recipe> {
  Future<Recipe> createRecipeWithDefaults(String title) async {
    // ❌ Business logic: setting defaults
    final recipe = Recipe(
      id: Uuid().v4(),
      title: title,
      portions: 4,  // ❌ Default portions
      createdAt: DateTime.now(),
    );
    return await create(recipe);
  }
}

// ✅ GOOD - Business logic in service
class RecipeService extends BaseService {
  Future<Recipe> createRecipeWithDefaults(String title) async {
    final recipe = Recipe(
      id: Uuid().v4(),
      title: title,
      portions: 4,  // ✅ Default in service
      createdAt: DateTime.now(),
    );
    return await _repository.create(recipe);
  }
}
```

### ❌ Mistake 2: Not Validating Permissions

```dart
// ❌ BAD - No permission validation
class FirebaseRecipeRepository extends BaseFirebaseRepository<Recipe> {
  // Missing validateUpdatePermission override
  // Anyone can update any recipe!
}

// ✅ GOOD - Permission validation
class FirebaseRecipeRepository extends BaseFirebaseRepository<Recipe> {
  @override
  Future<bool> validateUpdatePermission(String userId, Recipe entity) async {
    return entity.createdBy == userId;
  }
}
```

### ❌ Mistake 3: Including ID in toFirestore

```dart
// ❌ BAD
@override
Map<String, dynamic> toFirestore(Recipe recipe) {
  return {
    'id': recipe.id,  // ❌ Don't include ID
    'title': recipe.title,
  };
}

// ✅ GOOD
@override
Map<String, dynamic> toFirestore(Recipe recipe) {
  return {
    'title': recipe.title,  // ✅ ID is document ID, not field
  };
}
```

## Summary Checklist

When creating a new repository:

- [ ] Extend `BaseFirebaseRepository<T>`
- [ ] Add `UserScopedFirebaseRepository<T>` mixin if user-scoped
- [ ] Implement repository interface
- [ ] Override `collectionName`
- [ ] Implement `fromFirestore()`
- [ ] Implement `toFirestore()`
- [ ] Implement `getId()`
- [ ] Override permission validation methods
- [ ] Write unit tests with FakeFirebaseFirestore
- [ ] Register in appropriate DI module
- [ ] NO business logic in repository
- [ ] NO direct Firestore access outside repository

---

**See Also**:
- [MVVM Layers](./mvvm-layers.md) - Layer responsibilities
- [Service Pattern](./service-pattern.md) - How services use repositories
- [Critical Anti-Patterns](./critical-anti-patterns.md) - What to avoid
