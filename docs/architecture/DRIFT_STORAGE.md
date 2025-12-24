# Drift Local Storage System

**Complete guide to Butlery's offline-first local storage with Drift SQLite**

**Last Updated**: December 2025
**Related Guides**: [Architecture Overview](ARCHITECTURE_OVERVIEW.md) | [DI System](DI_SYSTEM.md) | [Firebase Integration](FIREBASE_INTEGRATION.md)

---

## Overview

Butlery implements an **offline-first architecture** using Drift (SQLite) for local data persistence. This enables:

- **Offline recipe access** when disconnected
- **Sync queue management** for pending changes
- **User data isolation** with composite keys
- **Reactive streams** for real-time UI updates

### Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                      OFFLINE SERVICES                          │
│  OfflineInitialization → OfflineService → OfflineSyncManager  │
└────────────────────────────────┬───────────────────────────────┘
                                 │
┌────────────────────────────────▼───────────────────────────────┐
│                      USER STORAGE                               │
│                    OfflineUserStorage                           │
│    User-scoped CRUD operations with JSON serialization         │
└────────────────────────────────┬───────────────────────────────┘
                                 │
┌────────────────────────────────▼───────────────────────────────┐
│                      DRIFT DATABASE                             │
│                       AppDatabase                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │  RecipeDao  │  │SyncQueueDao │  │  CacheDao   │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
└────────────────────────────────┬───────────────────────────────┘
                                 │
┌────────────────────────────────▼───────────────────────────────┐
│                    SQLite DATABASE                              │
│                   butlery_offline.db                            │
└────────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. AppDatabase (`lib/core/storage/drift/app_database.dart`)

The central Drift database managing all local storage:

```dart
@DriftDatabase(
  tables: [OfflineRecipes, SyncQueue, CacheEntries],
  daos: [RecipeDao, SyncQueueDao, CacheDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) => m.createAll(),
  );
}
```

**Database Tables:**

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `OfflineRecipes` | User recipes cached locally | `id`, `userId`, `recipeJson`, `needsSync` |
| `SyncQueue` | Pending changes to sync | `recipeId`, `userId`, `operation`, `queuedAt` |
| `CacheEntries` | General cache storage | `key`, `value`, `expiresAt` |

### 2. Data Access Objects (DAOs)

#### RecipeDao

Handles recipe CRUD with user isolation:

```dart
@DriftAccessor(tables: [OfflineRecipes])
class RecipeDao extends DatabaseAccessor<AppDatabase> with _$RecipeDaoMixin {
  RecipeDao(super.db);

  // User-scoped operations
  Future<void> upsertRecipe({
    required String id,
    required String userId,
    required String recipeJson,
    bool needsSync = false,
  });

  Future<OfflineRecipe?> getRecipe(String id, String userId);
  Future<List<OfflineRecipe>> getRecipesForUser(String userId);
  Stream<List<OfflineRecipe>> watchRecipesForUser(String userId);
  Future<int> deleteRecipe(String id, String userId);
  Future<int> deleteAllForUser(String userId);
  Future<int> countForUser(String userId);
}
```

#### SyncQueueDao

Manages the offline sync queue:

```dart
@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase> with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  Future<int> enqueue({
    required String userId,
    required String recipeId,
    required String operation,
  });

  Future<List<SyncQueueEntry>> getPendingForUser(String userId);
  Future<bool> hasPending(String userId);
  Future<int> countPending(String userId);
  Future<int> removeForRecipe(String userId, String recipeId);
  Future<int> clearForUser(String userId);
}
```

---

## Service Layer

### OfflineInitialization

Manages database initialization and connectivity monitoring:

```dart
class OfflineInitialization {
  late AppDatabase _database;
  bool _isInitialized = false;
  bool _isOnline = true;

  // Callbacks
  final VoidCallback? onConnectivityChanged;
  final VoidCallback? onReconnected;

  Future<void> initialize() async {
    _database = AppDatabase();
    await _initConnectivityMonitoring();
    _isInitialized = true;
  }

  AppDatabase get database {
    if (!_isInitialized) throw StateError('Not initialized');
    return _database;
  }

  bool get isOnline => _isOnline;
  bool get isInitialized => _isInitialized;

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> close() async {
    await _database.close();
  }
}
```

### OfflineUserStorage

User-scoped recipe storage with JSON serialization:

```dart
class OfflineUserStorage {
  final AppDatabase _database;

  OfflineUserStorage({required AppDatabase database}) : _database = database;

  // Save with sync flag
  Future<void> saveRecipeForUser(
    Recipe recipe,
    String userId, {
    required bool isOnline,
  }) async {
    await _database.recipeDao.upsertRecipe(
      id: recipe.id,
      userId: userId,
      recipeJson: jsonEncode(recipe.toJson()),
      needsSync: !isOnline,
    );

    if (!isOnline) {
      await _database.syncQueueDao.enqueue(
        userId: userId,
        recipeId: recipe.id,
        operation: 'update',
      );
    }
  }

  // Retrieve user recipes
  Future<List<Recipe>> getRecipesForUser(String userId) async {
    final records = await _database.recipeDao.getRecipesForUser(userId);
    return records.map((r) => Recipe.fromJson(jsonDecode(r.recipeJson))).toList();
  }

  // Watch for changes
  Stream<List<Recipe>> watchRecipesForUser(String userId) {
    return _database.recipeDao.watchRecipesForUser(userId).map(
      (records) => records.map((r) => Recipe.fromJson(jsonDecode(r.recipeJson))).toList(),
    );
  }
}
```

### OfflineSyncManager

Handles sync queue processing when back online:

```dart
class OfflineSyncManager {
  final AppDatabase _database;
  final FirestoreRepository _firestoreRepository;
  final AuthRepository _authRepository;
  final VoidCallback? onSyncStateChanged;

  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  Future<int> get queuedChangesCount async {
    final userId = _authRepository.currentUserId;
    if (userId == null) return 0;
    return _database.syncQueueDao.countPending(userId);
  }

  Future<bool> get hasQueuedChanges async {
    final userId = _authRepository.currentUserId;
    if (userId == null) return false;
    return _database.syncQueueDao.hasPending(userId);
  }

  Future<void> syncPendingChanges({required bool isOnline}) async {
    if (!isOnline || _isSyncing) return;
    // ... process sync queue
  }

  Future<SyncResult> syncNow({required bool isOnline}) async {
    if (!isOnline) return SyncResult.offline();
    if (_isSyncing) return SyncResult.inProgress();
    // ... manual sync
  }
}
```

---

## User Data Isolation

Recipes are stored with **composite keys** (userId + recipeId) to ensure:

1. **Multi-user support** - Different users on same device
2. **Data isolation** - Users cannot access each other's data
3. **Efficient queries** - Index on userId for fast lookups

```sql
CREATE TABLE offline_recipes (
  id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  recipe_json TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  needs_sync INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id, user_id)
);

CREATE INDEX idx_recipes_user ON offline_recipes(user_id);
```

---

## JSON Serialization

Recipes are stored as JSON strings rather than normalized tables:

**Advantages:**
- Simpler schema evolution
- Full recipe model preserved
- Matches Firestore document structure
- Easy debugging with readable data

**Implementation:**

```dart
// Save
final recipeJson = jsonEncode(recipe.toJson());
await recipeDao.upsertRecipe(recipeJson: recipeJson, ...);

// Load
final record = await recipeDao.getRecipe(id, userId);
final recipe = Recipe.fromJson(jsonDecode(record.recipeJson));
```

---

## Reactive Streams

Drift provides reactive streams for real-time UI updates:

```dart
// Watch user's recipes
Stream<List<Recipe>> watchRecipesForUser(String userId) {
  return _database.recipeDao.watchRecipesForUser(userId).map(
    (records) => records.map(_parseRecipe).toList(),
  );
}

// Usage in ViewModel
class RecipeViewModel extends ChangeNotifier {
  StreamSubscription? _subscription;

  void startWatching(String userId) {
    _subscription = _storage.watchRecipesForUser(userId).listen((recipes) {
      _recipes = recipes;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

---

## Sync Queue Operations

The sync queue tracks changes made while offline:

| Operation | Description | Queue Entry |
|-----------|-------------|-------------|
| `create` | New recipe created offline | Full recipe JSON |
| `update` | Existing recipe modified | Updated recipe JSON |
| `delete` | Recipe deleted offline | Recipe ID only |

**Sync Flow:**

```
1. User modifies recipe while offline
   │
   ├─▶ Save to OfflineRecipes with needsSync=true
   │
   └─▶ Enqueue operation in SyncQueue

2. Device comes back online
   │
   ├─▶ OfflineInitialization detects connectivity
   │
   ├─▶ Triggers onReconnected callback
   │
   └─▶ OfflineSyncManager.syncPendingChanges()
       │
       ├─▶ Get pending items from SyncQueue
       │
       ├─▶ For each item:
       │   ├─▶ Upload to Firestore
       │   ├─▶ Mark needsSync=false in OfflineRecipes
       │   └─▶ Remove from SyncQueue
       │
       └─▶ Notify sync complete
```

---

## Dependencies

```yaml
# pubspec.yaml
dependencies:
  drift: ^2.12.0
  sqlite3_flutter_libs: ^0.5.21

dev_dependencies:
  drift_dev: ^2.12.0
  build_runner: ^2.4.6
```

---

## Testing

Tests use mock DAOs with Mocktail:

```dart
class MockAppDatabase extends Mock implements AppDatabase {}
class MockRecipeDao extends Mock implements RecipeDao {}
class MockSyncQueueDao extends Mock implements SyncQueueDao {}

class FakeOfflineRecipe extends Fake implements OfflineRecipe {
  @override final String id;
  @override final String userId;
  @override final String recipeJson;
  // ...
}

void main() {
  late MockAppDatabase mockDatabase;
  late MockRecipeDao mockRecipeDao;

  setUp(() {
    mockDatabase = MockAppDatabase();
    mockRecipeDao = MockRecipeDao();
    when(() => mockDatabase.recipeDao).thenReturn(mockRecipeDao);
  });

  test('should save recipe with user isolation', () async {
    when(() => mockRecipeDao.upsertRecipe(
      id: any(named: 'id'),
      userId: any(named: 'userId'),
      recipeJson: any(named: 'recipeJson'),
      needsSync: any(named: 'needsSync'),
    )).thenAnswer((_) async {});

    await storage.saveRecipeForUser(recipe, 'user_123', isOnline: true);

    verify(() => mockRecipeDao.upsertRecipe(
      id: recipe.id,
      userId: 'user_123',
      recipeJson: any(named: 'recipeJson'),
      needsSync: false,
    )).called(1);
  });
}
```

---

## Migration from Hive

The codebase was migrated from Hive to Drift in December 2025:

**Key Changes:**

| Aspect | Hive (Old) | Drift (New) |
|--------|------------|-------------|
| Storage | Binary TypeAdapters | JSON in SQLite |
| Querying | Key-value lookups | SQL with indices |
| Streaming | Manual | Built-in reactive |
| User isolation | Manual key prefixes | Composite primary keys |
| Schema | TypeAdapter versioning | SQL migrations |

**Migration Scope:**
- Removed HiveObject from RecipeCore
- Deleted recipe_unified.g.dart (Hive TypeAdapter)
- Created Drift DAOs (RecipeDao, SyncQueueDao, CacheDao)
- Updated all offline services to use AppDatabase
- Updated test files with mock DAOs

---

## File Structure

```
lib/core/storage/drift/
├── app_database.dart          # Main database class
├── app_database.g.dart        # Generated Drift code
├── tables/
│   ├── offline_recipes.dart   # Recipe table definition
│   ├── sync_queue.dart        # Sync queue table
│   └── cache_entries.dart     # Cache table
└── daos/
    ├── recipe_dao.dart        # Recipe operations
    ├── sync_queue_dao.dart    # Sync queue operations
    └── cache_dao.dart         # Cache operations

lib/services/offline/
├── offline_initialization.dart  # Database + connectivity
├── offline_user_storage.dart    # User-scoped storage
└── offline_sync_manager.dart    # Sync queue processing
```

---

## Best Practices

### DO:
- Use composite keys for user isolation
- Store complete JSON for schema flexibility
- Use reactive streams for UI updates
- Handle offline/online transitions gracefully
- Clean up sync queue after successful sync

### DON'T:
- Access database before initialization
- Assume online connectivity
- Store sensitive data without encryption
- Skip user isolation checks
- Forget to close database on app shutdown

---

**Last Updated**: December 2025 | **Verified Against**: Actual codebase implementation
