# Base Repository Usage

Guide to extending and using BaseFirebaseRepository for consistent Firebase operations in Butlery.

## BaseFirebaseRepository Overview

BaseFirebaseRepository provides standard CRUD operations, permission validation, audit logging, and streaming support for all Firebase repositories.

**Benefits:**
- Eliminates CRUD boilerplate (create, read, update, delete)
- Enforces permission validation on all operations
- Automatic audit logging for security compliance (GDPR Article 30)
- Built-in error handling and retry logic
- Streaming support for real-time updates
- Batch operation helpers

## Basic Repository Structure

```dart
import 'package:butlery/repositories/base/base_firebase_repository.dart';

class RecipeRepository extends BaseFirebaseRepository<Recipe> {
  RecipeRepository({
    required FirebaseFirestore firestore,
    required AuthRepository authRepository,
  }) : super(
    firestore: firestore,
    authRepository: authRepository,
    collectionPath: 'users/{userId}/recipes',
  );

  @override
  Recipe fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Recipe.fromFirestore(doc);
  }

  @override
  Map<String, dynamic> toFirestore(Recipe recipe) {
    return recipe.toFirestore();
  }
}
```

## Collection Path Patterns

### User-Scoped Collections

For personal user data that should be isolated per user:

```dart
class PersonalRecipeRepository extends BaseFirebaseRepository<Recipe> {
  PersonalRecipeRepository({
    required super.firestore,
    required super.authRepository,
  }) : super(
    // {userId} is automatically replaced with current user's ID
    collectionPath: 'users/{userId}/recipes',
  );
}

// Firestore structure:
// users/
//   user_1/
//     recipes/
//       recipe_1: { title: "My Recipe" }
//   user_2/
//     recipes/
//       recipe_2: { title: "Their Recipe" }
```

**Benefits:**
- Automatic data isolation
- Simpler security rules
- Efficient queries (no need to filter by userId)
- Supports offline persistence per user

**Use for:** Personal recipes, menus, shopping lists, settings

### Global Collections

For shared data accessible across users:

```dart
class SharedRecipeRepository extends BaseFirebaseRepository<SharedRecipe> {
  SharedRecipeRepository({
    required super.firestore,
    required super.authRepository,
  }) : super(
    collectionPath: 'sharedRecipes',
  );
}

// Firestore structure:
// sharedRecipes/
//   recipe_1: { ownerId: "user_1", sharedWith: ["user_2", "user_3"] }
//   recipe_2: { ownerId: "user_2", sharedWith: ["user_1"] }
```

**Use for:** Shared recipes, comments, ratings, friend requests, group content

### Subcollections in Global Collections

```dart
class CommentRepository extends BaseFirebaseRepository<Comment> {
  final String recipeId;

  CommentRepository({
    required this.recipeId,
    required super.firestore,
    required super.authRepository,
  }) : super(
    collectionPath: 'sharedRecipes/$recipeId/comments',
  );
}

// Firestore structure:
// sharedRecipes/
//   recipe_1/
//     comments/
//       comment_1: { userId: "user_1", text: "Great!" }
```

## Implementing fromFirestore and toFirestore

### Simple Model

```dart
class Recipe {
  final String id;
  final String userId;
  final String title;
  final int portions;

  Recipe({
    required this.id,
    required this.userId,
    required this.title,
    required this.portions,
  });

  factory Recipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Recipe(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      portions: data['portions'] as int? ?? 4,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'portions': portions,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

// Repository
@override
Recipe fromFirestore(DocumentSnapshot doc) {
  return Recipe.fromFirestore(doc);
}

@override
Map<String, dynamic> toFirestore(Recipe recipe) {
  return recipe.toFirestore();
}
```

### Complex Model with Nested Objects

```dart
class Recipe {
  final String id;
  final String title;
  final List<Ingredient> ingredients;
  final List<String> instructions;
  final DateTime createdAt;

  // fromFirestore with nested data
  factory Recipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Recipe(
      id: doc.id,
      title: data['title'] as String,
      ingredients: (data['ingredients'] as List<dynamic>?)
          ?.map((i) => Ingredient.fromMap(i as Map<String, dynamic>))
          .toList() ?? [],
      instructions: List<String>.from(data['instructions'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // toFirestore with nested data
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'ingredients': ingredients.map((i) => i.toMap()).toList(),
      'instructions': instructions,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class Ingredient {
  final String name;
  final String amount;
  final String unit;

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      name: map['name'] as String,
      amount: map['amount'] as String,
      unit: map['unit'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
    };
  }
}
```

## Using Built-in CRUD Operations

BaseFirebaseRepository provides standard CRUD operations:

### Create

```dart
// In repository - no need to override, use directly
Future<Recipe> createRecipe(Recipe recipe) async {
  return await create(recipe);
}

// Automatically:
// 1. Validates create permission
// 2. Generates document ID if needed
// 3. Adds to Firestore
// 4. Logs audit event
// 5. Returns created entity
```

### Read

```dart
// Get by ID
Future<Recipe?> getRecipe(String id) async {
  return await getById(id);
}

// Get all (user-scoped collections only)
Future<List<Recipe>> getAllRecipes() async {
  return await getAll();
}

// Custom query
Future<List<Recipe>> getPublicRecipes() async {
  return await query(
    (collection) => collection
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(20),
  );
}
```

### Update

```dart
Future<Recipe> updateRecipe(Recipe recipe) async {
  return await update(recipe);
}

// Automatically:
// 1. Validates update permission
// 2. Updates in Firestore
// 3. Logs audit event
// 4. Returns updated entity
```

### Delete

```dart
Future<void> deleteRecipe(String id) async {
  await delete(id);
}

// Automatically:
// 1. Validates delete permission
// 2. Deletes from Firestore
// 3. Logs audit event
```

## Custom Queries

Add domain-specific queries to your repository:

```dart
class RecipeRepository extends BaseFirebaseRepository<Recipe> {
  // ... constructor and required methods

  /// Get user's recipes sorted by creation date
  Future<List<Recipe>> getUserRecipes({
    required String userId,
    int limit = 50,
  }) async {
    return await query(
      (collection) => collection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit),
    );
  }

  /// Search recipes by title
  Future<List<Recipe>> searchRecipes(String searchTerm) async {
    final lowercaseSearch = searchTerm.toLowerCase();
    return await query(
      (collection) => collection
          .where('titleLowercase', isGreaterThanOrEqualTo: lowercaseSearch)
          .where('titleLowercase', isLessThan: lowercaseSearch + 'z')
          .limit(20),
    );
  }

  /// Get recipes by tag
  Future<List<Recipe>> getRecipesByTag(String tag) async {
    return await query(
      (collection) => collection
          .where('tags', arrayContains: tag),
    );
  }

  /// Get recently updated recipes
  Future<List<Recipe>> getRecentlyUpdated({int days = 7}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return await query(
      (collection) => collection
          .where('updatedAt', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .orderBy('updatedAt', descending: true),
    );
  }
}
```

## Streaming Operations

### Watch Single Document

```dart
Stream<Recipe?> watchRecipe(String recipeId) {
  return watch(recipeId);
}

// Usage in service
class RecipeService {
  Stream<Recipe?> watchRecipe(String recipeId) {
    return _repository.watchRecipe(recipeId);
  }
}

// Usage in ViewModel
class RecipeDetailViewModel extends ChangeNotifier {
  StreamSubscription? _recipeSubscription;

  void startWatching(String recipeId) {
    _recipeSubscription = _recipeService
        .watchRecipe(recipeId)
        .listen((recipe) {
      _recipe = recipe;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _recipeSubscription?.cancel();
    super.dispose();
  }
}
```

### Watch Collection

```dart
Stream<List<Recipe>> watchUserRecipes(String userId) {
  return queryStream(
    (collection) => collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true),
  );
}
```

## Error Handling

BaseFirebaseRepository handles common errors:

```dart
// Automatic error handling for:
// - Document not found (returns null for getById)
// - Permission denied (throws UnauthorizedException)
// - Network errors (throws NetworkException)
// - Invalid data (throws ValidationException)

try {
  final recipe = await _repository.getById(id);
  if (recipe == null) {
    // Document not found
  }
} on UnauthorizedException {
  // User doesn't have permission
} on NetworkException {
  // Network error
} on ValidationException catch (e) {
  // Validation failed: e.message
}
```

## Batch Operations

### Batch Create

```dart
Future<void> importRecipes(List<Recipe> recipes) async {
  await batchCreate(recipes);
}

// Automatically validates permissions and creates all in a single batch
```

### Batch Update

```dart
Future<void> updateRecipeTags(List<Recipe> recipes) async {
  await batchUpdate(recipes);
}
```

### Batch Delete

```dart
Future<void> deleteAllUserRecipes(String userId) async {
  final recipes = await getUserRecipes(userId: userId);
  await batchDelete(recipes.map((r) => r.id).toList());
}
```

## Advanced Patterns

### Repository with Multiple Collections

```dart
class SocialRecipeRepository extends BaseFirebaseRepository<SharedRecipe> {
  SocialRecipeRepository({
    required super.firestore,
    required super.authRepository,
  }) : super(
    collectionPath: 'sharedRecipes',
  );

  /// Access related comments subcollection
  CommentRepository commentsFor(String recipeId) {
    return CommentRepository(
      recipeId: recipeId,
      firestore: firestore,
      authRepository: authRepository,
    );
  }

  /// Access related ratings subcollection
  RatingRepository ratingsFor(String recipeId) {
    return RatingRepository(
      recipeId: recipeId,
      firestore: firestore,
      authRepository: authRepository,
    );
  }
}

// Usage
final comments = await _socialRecipeRepository
    .commentsFor(recipeId)
    .getAll();
```

### Custom Validation

```dart
@override
Future<void> validateCreatePermission(Recipe recipe) async {
  await super.validateCreatePermission(recipe);

  // Custom business rules
  if (recipe.title.length < 3) {
    throw ValidationException('Title must be at least 3 characters');
  }

  if (recipe.portions < 1 || recipe.portions > 100) {
    throw ValidationException('Portions must be between 1 and 100');
  }

  // Check user quota
  final userRecipes = await getUserRecipes(userId: recipe.userId);
  if (userRecipes.length >= 500) {
    throw QuotaExceededException('Maximum 500 recipes per user');
  }
}
```

## Testing Repositories

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockAuthRepository mockAuth;
  late RecipeRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockAuthRepository();
    when(() => mockAuth.currentUserId).thenReturn('user_1');

    repository = RecipeRepository(
      firestore: fakeFirestore,
      authRepository: mockAuth,
    );
  });

  group('CRUD Operations', () {
    test('creates recipe', () async {
      final recipe = Recipe(
        id: 'recipe_1',
        userId: 'user_1',
        title: 'Test Recipe',
        portions: 4,
      );

      final created = await repository.create(recipe);

      expect(created.id, 'recipe_1');
      expect(created.title, 'Test Recipe');

      final doc = await fakeFirestore
          .collection('users')
          .doc('user_1')
          .collection('recipes')
          .doc('recipe_1')
          .get();

      expect(doc.exists, isTrue);
      expect(doc['title'], 'Test Recipe');
    });

    test('gets recipe by id', () async {
      await fakeFirestore
          .collection('users')
          .doc('user_1')
          .collection('recipes')
          .doc('recipe_1')
          .set({
        'userId': 'user_1',
        'title': 'Existing Recipe',
        'portions': 4,
      });

      final recipe = await repository.getById('recipe_1');

      expect(recipe, isNotNull);
      expect(recipe!.title, 'Existing Recipe');
    });

    test('updates recipe', () async {
      await fakeFirestore
          .collection('users')
          .doc('user_1')
          .collection('recipes')
          .doc('recipe_1')
          .set({
        'userId': 'user_1',
        'title': 'Original',
        'portions': 4,
      });

      final updated = Recipe(
        id: 'recipe_1',
        userId: 'user_1',
        title: 'Updated',
        portions: 6,
      );

      await repository.update(updated);

      final doc = await fakeFirestore
          .collection('users')
          .doc('user_1')
          .collection('recipes')
          .doc('recipe_1')
          .get();

      expect(doc['title'], 'Updated');
      expect(doc['portions'], 6);
    });

    test('deletes recipe', () async {
      await fakeFirestore
          .collection('users')
          .doc('user_1')
          .collection('recipes')
          .doc('recipe_1')
          .set({
        'userId': 'user_1',
        'title': 'To Delete',
        'portions': 4,
      });

      await repository.delete('recipe_1');

      final doc = await fakeFirestore
          .collection('users')
          .doc('user_1')
          .collection('recipes')
          .doc('recipe_1')
          .get();

      expect(doc.exists, isFalse);
    });
  });
}
```

## Best Practices

1. **Always extend BaseFirebaseRepository**: Don't create custom repository from scratch
2. **Use user-scoped collections for personal data**: Simplifies security and queries
3. **Implement custom queries as repository methods**: Keep query logic in repository layer
4. **Add business-specific validation**: Override validateCreatePermission, etc.
5. **Use streaming for real-time features**: Leverage watch() and queryStream()
6. **Test with FakeFirebaseFirestore**: Unit test repositories without real Firebase
7. **Keep serialization in models**: fromFirestore/toFirestore belong in model classes

## Related Resources

- [Permission Validation Patterns](permission-validation-patterns.md) - Security and access control
- [Firestore Operations](firestore-operations.md) - Advanced queries, transactions, batches