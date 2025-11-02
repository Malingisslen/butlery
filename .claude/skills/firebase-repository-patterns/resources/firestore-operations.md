# Firestore Operations

Advanced Firestore query patterns, batch operations, transactions, and real-time streaming for Butlery repositories.

## Query Patterns

### Basic Queries

```dart
class RecipeRepository extends BaseFirebaseRepository<Recipe> {
  /// Get user's recipes
  Future<List<Recipe>> getUserRecipes(String userId) async {
    return await query(
      (collection) => collection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true),
    );
  }

  /// Get public recipes
  Future<List<Recipe>> getPublicRecipes({int limit = 20}) async {
    return await query(
      (collection) => collection
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(limit),
    );
  }

  /// Get recipes by tag
  Future<List<Recipe>> getRecipesByTag(String tag) async {
    return await query(
      (collection) => collection.where('tags', arrayContains: tag),
    );
  }
}
```

### Compound Queries

Firestore requires composite indexes for compound queries:

```dart
/// Get user's public recipes sorted by rating
Future<List<Recipe>> getUserPublicRecipesByRating(String userId) async {
  return await query(
    (collection) => collection
        .where('userId', isEqualTo: userId)
        .where('visibility', isEqualTo: 'public')
        .orderBy('averageRating', descending: true)
        .limit(50),
  );
}

// Firestore composite index required:
// Collection: recipes
// Fields: userId (Ascending), visibility (Ascending), averageRating (Descending)
```

### Array Queries

```dart
/// Get recipes shared with user
Future<List<Recipe>> getSharedWithMe(String userId) async {
  return await query(
    (collection) => collection
        .where('sharedWith', arrayContains: userId),
  );
}

/// Get recipes with any of the provided tags
Future<List<Recipe>> getRecipesByAnyTag(List<String> tags) async {
  return await query(
    (collection) => collection
        .where('tags', arrayContainsAny: tags)
        .limit(50), // arrayContainsAny limited to 10 items
  );
}
```

### Range Queries

```dart
/// Get recently updated recipes
Future<List<Recipe>> getRecentlyUpdated({int days = 7}) async {
  final cutoffDate = DateTime.now().subtract(Duration(days: days));

  return await query(
    (collection) => collection
        .where('updatedAt', isGreaterThan: Timestamp.fromDate(cutoffDate))
        .orderBy('updatedAt', descending: true),
  );
}

/// Get recipes by rating range
Future<List<Recipe>> getRecipesByRatingRange({
  required double minRating,
  required double maxRating,
}) async {
  return await query(
    (collection) => collection
        .where('averageRating', isGreaterThanOrEqualTo: minRating)
        .where('averageRating', isLessThanOrEqualTo: maxRating)
        .orderBy('averageRating', descending: true),
  );
}
```

### Text Search Patterns

Firestore doesn't support full-text search natively, use these patterns:

```dart
/// Search by title prefix (case-insensitive)
Future<List<Recipe>> searchByTitlePrefix(String prefix) async {
  final lowercasePrefix = prefix.toLowerCase();

  return await query(
    (collection) => collection
        .where('titleLowercase', isGreaterThanOrEqualTo: lowercasePrefix)
        .where('titleLowercase', isLessThan: lowercasePrefix + 'z')
        .limit(20),
  );
}

// When saving recipe, store lowercase version:
@override
Map<String, dynamic> toFirestore(Recipe recipe) {
  return {
    'title': recipe.title,
    'titleLowercase': recipe.title.toLowerCase(),
    // ... other fields
  };
}

/// For advanced full-text search, use Algolia or Elasticsearch
/// Store search index externally and query by recipe IDs
Future<List<Recipe>> fullTextSearch(String searchTerm) async {
  // 1. Query search service (Algolia, etc.)
  final searchResults = await _searchService.search(searchTerm);
  final recipeIds = searchResults.map((r) => r.id).toList();

  // 2. Fetch full recipes from Firestore
  if (recipeIds.isEmpty) return [];

  return await batchGetByIds(recipeIds);
}
```

## Pagination Patterns

### Offset Pagination (Simple but Expensive)

```dart
class RecipeRepository extends BaseFirebaseRepository<Recipe> {
  Future<List<Recipe>> getRecipesPage({
    required int page,
    required int pageSize,
  }) async {
    return await query(
      (collection) => collection
          .orderBy('createdAt', descending: true)
          .limit(pageSize)
          .offset(page * pageSize), // Warning: Reads all skipped documents!
    );
  }
}
```

**Warning**: Offset pagination reads and discards all skipped documents, making it expensive for large datasets.

### Cursor Pagination (Efficient)

```dart
class RecipeRepository extends BaseFirebaseRepository<Recipe> {
  /// Get first page
  Future<RecipePage> getFirstPage({int pageSize = 20}) async {
    final recipes = await query(
      (collection) => collection
          .orderBy('createdAt', descending: true)
          .limit(pageSize),
    );

    return RecipePage(
      recipes: recipes,
      hasMore: recipes.length == pageSize,
      lastDocument: recipes.isNotEmpty ? recipes.last : null,
    );
  }

  /// Get next page using cursor
  Future<RecipePage> getNextPage({
    required Recipe lastRecipe,
    int pageSize = 20,
  }) async {
    final recipes = await query(
      (collection) => collection
          .orderBy('createdAt', descending: true)
          .startAfter([Timestamp.fromDate(lastRecipe.createdAt)])
          .limit(pageSize),
    );

    return RecipePage(
      recipes: recipes,
      hasMore: recipes.length == pageSize,
      lastDocument: recipes.isNotEmpty ? recipes.last : null,
    );
  }
}

class RecipePage {
  final List<Recipe> recipes;
  final bool hasMore;
  final Recipe? lastDocument;

  RecipePage({
    required this.recipes,
    required this.hasMore,
    this.lastDocument,
  });
}
```

### Infinite Scroll Implementation

```dart
class RecipeListViewModel extends ChangeNotifier with AsyncOperationMixin {
  final RecipeRepository _repository;
  List<Recipe> _recipes = [];
  Recipe? _lastRecipe;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  List<Recipe> get recipes => _recipes;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> loadInitialRecipes() async {
    await executeAsync(() async {
      final page = await _repository.getFirstPage(pageSize: 20);
      _recipes = page.recipes;
      _lastRecipe = page.lastDocument;
      _hasMore = page.hasMore;
    });
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore || _lastRecipe == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _repository.getNextPage(
        lastRecipe: _lastRecipe!,
        pageSize: 20,
      );

      _recipes.addAll(page.recipes);
      _lastRecipe = page.lastDocument;
      _hasMore = page.hasMore;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
}
```

## Real-time Streams

### Single Document Stream

```dart
class RecipeRepository extends BaseFirebaseRepository<Recipe> {
  /// Watch single recipe for changes
  Stream<Recipe?> watchRecipe(String recipeId) {
    return watch(recipeId);
  }
}

// Usage in ViewModel
class RecipeDetailViewModel extends ChangeNotifier {
  final RecipeRepository _repository;
  StreamSubscription<Recipe?>? _recipeSubscription;
  Recipe? _recipe;

  Recipe? get recipe => _recipe;

  void watchRecipe(String recipeId) {
    _recipeSubscription?.cancel();

    _recipeSubscription = _repository.watchRecipe(recipeId).listen(
      (recipe) {
        _recipe = recipe;
        notifyListeners();
      },
      onError: (error) {
        // Handle error
      },
    );
  }

  @override
  void dispose() {
    _recipeSubscription?.cancel();
    super.dispose();
  }
}
```

### Collection Stream

```dart
/// Watch all user recipes
Stream<List<Recipe>> watchUserRecipes(String userId) {
  return queryStream(
    (collection) => collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true),
  );
}

/// Watch recipes with filters
Stream<List<Recipe>> watchRecipesByTag(String tag) {
  return queryStream(
    (collection) => collection
        .where('tags', arrayContains: tag)
        .orderBy('createdAt', descending: true)
        .limit(50),
  );
}
```

### Collaborative Real-time Updates

```dart
class CollaborativeShoppingListRepository extends BaseFirebaseRepository<ShoppingList> {
  /// Watch list items being checked/unchecked in real-time
  Stream<ShoppingList?> watchList(String listId) {
    return watch(listId);
  }

  /// Watch active users in list
  Stream<List<String>> watchActiveUsers(String listId) {
    return firestore
        .collection('shoppingLists')
        .doc(listId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return <String>[];
      return List<String>.from(doc.data()?['activeUsers'] ?? []);
    });
  }
}

// Usage in ViewModel for collaborative features
class CollaborativeListViewModel extends ChangeNotifier {
  StreamSubscription<ShoppingList?>? _listSubscription;
  StreamSubscription<List<String>>? _activeUsersSubscription;

  ShoppingList? _list;
  List<String> _activeUsers = [];

  void startWatching(String listId) {
    _listSubscription = _repository.watchList(listId).listen((list) {
      _list = list;
      notifyListeners();
    });

    _activeUsersSubscription = _repository.watchActiveUsers(listId).listen((users) {
      _activeUsers = users;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _listSubscription?.cancel();
    _activeUsersSubscription?.cancel();
    super.dispose();
  }
}
```

## Batch Operations

### Batch Writes

```dart
class RecipeRepository extends BaseFirebaseRepository<Recipe> {
  /// Import multiple recipes at once
  Future<void> importRecipes(List<Recipe> recipes) async {
    if (recipes.isEmpty) return;

    // Validate all before importing
    for (final recipe in recipes) {
      await validateCreatePermission(recipe);
    }

    // Firestore batches limited to 500 operations
    const batchSize = 500;

    for (var i = 0; i < recipes.length; i += batchSize) {
      final batch = firestore.batch();
      final end = (i + batchSize < recipes.length) ? i + batchSize : recipes.length;
      final batchRecipes = recipes.sublist(i, end);

      for (final recipe in batchRecipes) {
        final docRef = firestore
            .collection(_getCollectionPath())
            .doc(recipe.id);
        batch.set(docRef, toFirestore(recipe));
      }

      await batch.commit();
    }

    await logAuditEvent(
      action: 'recipes_imported',
      resourceId: 'batch',
      userId: authRepository.currentUserId!,
      metadata: {'count': recipes.length},
    );
  }

  /// Bulk update tags
  Future<void> bulkUpdateTags(
    List<String> recipeIds,
    List<String> tags,
  ) async {
    const batchSize = 500;

    for (var i = 0; i < recipeIds.length; i += batchSize) {
      final batch = firestore.batch();
      final end = (i + batchSize < recipeIds.length) ? i + batchSize : recipeIds.length;
      final batchIds = recipeIds.sublist(i, end);

      for (final id in batchIds) {
        final docRef = firestore
            .collection(_getCollectionPath())
            .doc(id);
        batch.update(docRef, {'tags': tags});
      }

      await batch.commit();
    }
  }

  /// Bulk delete
  Future<void> bulkDelete(List<String> recipeIds) async {
    for (final id in recipeIds) {
      await validateDeletePermission(id);
    }

    const batchSize = 500;

    for (var i = 0; i < recipeIds.length; i += batchSize) {
      final batch = firestore.batch();
      final end = (i + batchSize < recipeIds.length) ? i + batchSize : recipeIds.length;
      final batchIds = recipeIds.sublist(i, end);

      for (final id in batchIds) {
        final docRef = firestore
            .collection(_getCollectionPath())
            .doc(id);
        batch.delete(docRef);
      }

      await batch.commit();
    }
  }
}
```

### Batch Reads

```dart
/// Get multiple recipes by ID
Future<List<Recipe>> batchGetByIds(List<String> recipeIds) async {
  if (recipeIds.isEmpty) return [];

  final recipes = <Recipe>[];

  // Firestore 'in' queries limited to 10 items
  const maxInQuery = 10;

  for (var i = 0; i < recipeIds.length; i += maxInQuery) {
    final end = (i + maxInQuery < recipeIds.length) ? i + maxInQuery : recipeIds.length;
    final batchIds = recipeIds.sublist(i, end);

    final results = await query(
      (collection) => collection.where(FieldPath.documentId, whereIn: batchIds),
    );

    recipes.addAll(results);
  }

  return recipes;
}
```

## Transactions

Transactions ensure atomic operations across multiple documents:

```dart
class RecipeRepository extends BaseFirebaseRepository<Recipe> {
  /// Transfer recipe ownership atomically
  Future<void> transferOwnership({
    required String recipeId,
    required String newOwnerId,
  }) async {
    await firestore.runTransaction((transaction) async {
      final recipeRef = firestore
          .collection(_getCollectionPath())
          .doc(recipeId);

      // Read current recipe
      final recipeDoc = await transaction.get(recipeRef);
      if (!recipeDoc.exists) {
        throw NotFoundException('Recipe not found');
      }

      final recipe = fromFirestore(recipeDoc);

      // Validate current user is owner
      if (recipe.userId != authRepository.currentUserId) {
        throw UnauthorizedException('Only owner can transfer');
      }

      // Update recipe with new owner
      transaction.update(recipeRef, {'userId': newOwnerId});

      // Update statistics (atomic counters)
      final oldOwnerStatsRef = firestore
          .collection('userStats')
          .doc(recipe.userId);
      transaction.update(oldOwnerStatsRef, {
        'recipeCount': FieldValue.increment(-1),
      });

      final newOwnerStatsRef = firestore
          .collection('userStats')
          .doc(newOwnerId);
      transaction.update(newOwnerStatsRef, {
        'recipeCount': FieldValue.increment(1),
      });
    });
  }

  /// Increment view count atomically
  Future<void> incrementViewCount(String recipeId) async {
    final recipeRef = firestore
        .collection(_getCollectionPath())
        .doc(recipeId);

    await recipeRef.update({
      'viewCount': FieldValue.increment(1),
      'lastViewed': FieldValue.serverTimestamp(),
    });
  }
}
```

### Transaction with Read-Write Pattern

```dart
/// Add comment and update comment count atomically
Future<Comment> addCommentWithCount({
  required String recipeId,
  required Comment comment,
}) async {
  return await firestore.runTransaction((transaction) async {
    final recipeRef = firestore.collection('sharedRecipes').doc(recipeId);
    final commentRef = recipeRef.collection('comments').doc(comment.id);

    // Read recipe to validate access
    final recipeDoc = await transaction.get(recipeRef);
    if (!recipeDoc.exists) {
      throw NotFoundException('Recipe not found');
    }

    // Add comment
    transaction.set(commentRef, comment.toFirestore());

    // Increment comment count
    transaction.update(recipeRef, {
      'commentCount': FieldValue.increment(1),
      'lastCommentedAt': FieldValue.serverTimestamp(),
    });

    return comment;
  });
}
```

## Optimistic Updates

For better UX, update UI immediately and sync to Firestore in background:

```dart
class RecipeViewModel extends ChangeNotifier {
  final RecipeRepository _repository;
  List<Recipe> _recipes = [];

  Future<void> toggleFavorite(Recipe recipe) async {
    // 1. Optimistic update - update UI immediately
    final updatedRecipe = recipe.copyWith(isFavorite: !recipe.isFavorite);
    final index = _recipes.indexWhere((r) => r.id == recipe.id);
    if (index != -1) {
      _recipes[index] = updatedRecipe;
      notifyListeners();
    }

    // 2. Sync to Firestore in background
    try {
      await _repository.update(updatedRecipe);
    } catch (e) {
      // 3. Revert on failure
      _recipes[index] = recipe;
      notifyListeners();
      rethrow;
    }
  }
}
```

## Subcollections

### Managing Subcollections

```dart
class RecipeRepository extends BaseFirebaseRepository<Recipe> {
  /// Get comments subcollection repository
  CommentRepository commentsFor(String recipeId) {
    return CommentRepository(
      recipeId: recipeId,
      firestore: firestore,
      authRepository: authRepository,
    );
  }

  /// Delete recipe and all subcollections
  Future<void> deleteRecipeWithSubcollections(String recipeId) async {
    await validateDeletePermission(recipeId);

    final batch = firestore.batch();

    // Delete recipe document
    final recipeRef = firestore
        .collection(_getCollectionPath())
        .doc(recipeId);
    batch.delete(recipeRef);

    // Delete all comments
    final comments = await commentsFor(recipeId).getAll();
    for (final comment in comments) {
      final commentRef = recipeRef.collection('comments').doc(comment.id);
      batch.delete(commentRef);
    }

    // Delete all ratings
    final ratingsSnapshot = await recipeRef.collection('ratings').get();
    for (final doc in ratingsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
```

## Performance Optimization

### Query Result Caching

```dart
class RecipeRepository extends BaseFirebaseRepository<Recipe> {
  final Map<String, CachedQuery<List<Recipe>>> _queryCache = {};

  Future<List<Recipe>> getUserRecipesCached(String userId) async {
    final cacheKey = 'user_recipes_$userId';
    final now = DateTime.now();

    // Check cache
    if (_queryCache.containsKey(cacheKey)) {
      final cached = _queryCache[cacheKey]!;
      if (now.difference(cached.timestamp).inMinutes < 5) {
        return cached.data;
      }
    }

    // Query Firestore
    final recipes = await getUserRecipes(userId);

    // Cache result
    _queryCache[cacheKey] = CachedQuery(
      data: recipes,
      timestamp: now,
    );

    return recipes;
  }

  void clearCache() {
    _queryCache.clear();
  }
}

class CachedQuery<T> {
  final T data;
  final DateTime timestamp;

  CachedQuery({required this.data, required this.timestamp});
}
```

### Firestore Best Practices

1. **Use indexes**: Create composite indexes for compound queries
2. **Limit results**: Always use `.limit()` to prevent excessive reads
3. **Avoid offset pagination**: Use cursor-based pagination instead
4. **Denormalize data**: Store commonly accessed data together
5. **Batch operations**: Group multiple writes into batches
6. **Cache aggressively**: Cache frequently accessed data
7. **Use subcollections wisely**: Balance between nested and flat structure

## Testing Firestore Operations

```dart
void main() {
  late FakeFirebaseFirestore firestore;
  late RecipeRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = RecipeRepository(
      firestore: firestore,
      authRepository: MockAuthRepository(),
    );
  });

  group('Queries', () {
    test('filters by tag', () async {
      await firestore.collection('recipes').add({
        'title': 'Pizza',
        'tags': ['italian', 'dinner'],
      });
      await firestore.collection('recipes').add({
        'title': 'Pasta',
        'tags': ['italian', 'lunch'],
      });

      final italian = await repository.getRecipesByTag('italian');

      expect(italian.length, 2);
    });

    test('paginates results', () async {
      for (var i = 0; i < 50; i++) {
        await firestore.collection('recipes').add({
          'title': 'Recipe $i',
          'createdAt': Timestamp.fromDate(
            DateTime(2025, 1, 1).add(Duration(days: i)),
          ),
        });
      }

      final page1 = await repository.getFirstPage(pageSize: 20);
      expect(page1.recipes.length, 20);
      expect(page1.hasMore, isTrue);

      final page2 = await repository.getNextPage(
        lastRecipe: page1.lastDocument!,
        pageSize: 20,
      );
      expect(page2.recipes.length, 20);
    });
  });

  group('Streams', () {
    test('watches recipe changes', () async {
      await firestore.collection('recipes').doc('recipe_1').set({
        'title': 'Original',
        'portions': 4,
      });

      final stream = repository.watchRecipe('recipe_1');

      expect(
        stream,
        emitsInOrder([
          predicate<Recipe?>((r) => r?.title == 'Original'),
          predicate<Recipe?>((r) => r?.title == 'Updated'),
        ]),
      );

      await Future.delayed(Duration(milliseconds: 100));

      await firestore.collection('recipes').doc('recipe_1').update({
        'title': 'Updated',
      });
    });
  });

  group('Batch Operations', () {
    test('imports multiple recipes', () async {
      final recipes = List.generate(
        10,
        (i) => Recipe(
          id: 'recipe_$i',
          userId: 'user_1',
          title: 'Recipe $i',
          portions: 4,
        ),
      );

      await repository.importRecipes(recipes);

      final docs = await firestore.collection('recipes').get();
      expect(docs.docs.length, 10);
    });
  });
}
```

## Related Resources

- [Base Repository Usage](base-repository-usage.md) - Repository fundamentals
- [Permission Validation Patterns](permission-validation-patterns.md) - Security and access control
