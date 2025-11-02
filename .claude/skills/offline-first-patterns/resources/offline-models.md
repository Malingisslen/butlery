# Offline Models

Guide to offline data models: RecipeOfflineData structure, sync metadata, and offline state management.

## Overview

**Key Model**: `RecipeOfflineData` - Embedded in Recipe model for sync tracking

**Purpose**: Track offline edits, sync status, and pending changes per recipe

---

## RecipeOfflineData

**Location**: `lib/models/recipe_unified.dart` (embedded in Recipe model)

### Structure

```dart
class RecipeOfflineData {
  final DateTime? lastSyncedAt;
  final bool isModifiedOffline;
  final List<String>? pendingChanges;

  RecipeOfflineData({
    this.lastSyncedAt,
    required this.isModifiedOffline,
    this.pendingChanges,
  });

  // Check if recipe needs sync
  bool get needsSync {
    return isModifiedOffline || lastSyncedAt == null;
  }

  // Check if never synced
  bool get isNeverSynced {
    return lastSyncedAt == null;
  }

  // Time since last sync
  Duration? get timeSinceSync {
    if (lastSyncedAt == null) return null;
    return DateTime.now().difference(lastSyncedAt!);
  }
}
```

### Factory Constructors

```dart
// Create for new offline edit
factory RecipeOfflineData.modified({
  required List<String> changes,
}) {
  return RecipeOfflineData(
    isModifiedOffline: true,
    lastSyncedAt: null,
    pendingChanges: changes,
  );
}

// Create after successful sync
factory RecipeOfflineData.synced() {
  return RecipeOfflineData(
    isModifiedOffline: false,
    lastSyncedAt: DateTime.now(),
    pendingChanges: null,
  );
}

// Create for unmodified offline recipe
factory RecipeOfflineData.unmodified({
  required DateTime syncedAt,
}) {
  return RecipeOfflineData(
    isModifiedOffline: false,
    lastSyncedAt: syncedAt,
    pendingChanges: null,
  );
}
```

### Serialization

```dart
Map<String, dynamic> toJson() {
  return {
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    'isModifiedOffline': isModifiedOffline,
    'pendingChanges': pendingChanges,
  };
}

factory RecipeOfflineData.fromJson(Map<String, dynamic> json) {
  return RecipeOfflineData(
    lastSyncedAt: json['lastSyncedAt'] != null
        ? DateTime.parse(json['lastSyncedAt'] as String)
        : null,
    isModifiedOffline: json['isModifiedOffline'] as bool? ?? false,
    pendingChanges: (json['pendingChanges'] as List?)
        ?.cast<String>(),
  );
}
```

---

## Recipe Model Integration

### Embedded Offline Data

```dart
class Recipe {
  final String? id;
  final String title;
  final List<Ingredient> ingredients;
  final List<String> instructions;

  // Offline metadata
  final RecipeOfflineData offlineData;

  Recipe({
    this.id,
    required this.title,
    required this.ingredients,
    required this.instructions,
    RecipeOfflineData? offlineData,
  }) : offlineData = offlineData ?? RecipeOfflineData.unmodified(
         syncedAt: DateTime.now(),
       );

  // Convenience getters
  bool get needsSync => offlineData.needsSync;
  bool get isModifiedOffline => offlineData.isModifiedOffline;
  DateTime? get lastSyncedAt => offlineData.lastSyncedAt;
}
```

---

## Usage Patterns

### Pattern 1: Mark Recipe as Modified Offline

```dart
Future<void> updateRecipeOffline(Recipe recipe) async {
  // Update recipe fields
  recipe.title = 'New Title';
  recipe.ingredients.add(newIngredient);

  // Mark as modified offline
  recipe.offlineData = RecipeOfflineData.modified(
    changes: ['title', 'ingredients'],
  );

  // Save offline
  await offlineService.saveRecipeOfflineForUser(
    recipe: recipe,
    userId: currentUserId,
  );

  // Add to sync queue
  await offlineService.addToSyncQueue(recipe.id!);
}
```

### Pattern 2: Mark as Synced After Successful Sync

```dart
Future<void> syncRecipe(Recipe recipe) async {
  try {
    // Sync to Firebase
    await _recipeRepository.update(recipe);

    // Mark as synced
    recipe.offlineData = RecipeOfflineData.synced();

    // Save updated metadata
    await offlineService.saveRecipeOfflineForUser(
      recipe: recipe,
      userId: currentUserId,
    );

    // Remove from sync queue
    await offlineService.removeFromSyncQueue(recipe.id!);

    print('✅ Recipe synced successfully');
  } catch (e) {
    print('❌ Sync failed: $e');
    // Keep offline data unchanged (still needs sync)
  }
}
```

### Pattern 3: Check if Sync Needed

```dart
Future<List<Recipe>> getRecipesNeedingSync() async {
  final allRecipes = await offlineService.getAllRecipesOfflineForUser(userId);

  return allRecipes.where((recipe) => recipe.needsSync).toList();
}

// Display in UI
Widget build(BuildContext context) {
  return FutureBuilder<List<Recipe>>(
    future: getRecipesNeedingSync(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return SizedBox.shrink();

      final count = snapshot.data!.length;
      if (count == 0) return SizedBox.shrink();

      return Chip(
        label: Text('$count recept behöver synkas'),
        backgroundColor: Colors.orange,
      );
    },
  );
}
```

### Pattern 4: Display Sync Status

```dart
class RecipeSyncStatus extends StatelessWidget {
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    if (recipe.isModifiedOffline) {
      return Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: Colors.orange),
          SizedBox(width: 4),
          Text(
            'Ändrat offline - synkas snart',
            style: TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ],
      );
    }

    if (recipe.offlineData.isNeverSynced) {
      return Row(
        children: [
          Icon(Icons.cloud_upload, size: 16, color: Colors.blue),
          SizedBox(width: 4),
          Text(
            'Väntar på första synk',
            style: TextStyle(color: Colors.blue, fontSize: 12),
          ),
        ],
      );
    }

    final syncAge = recipe.offlineData.timeSinceSync;
    if (syncAge != null && syncAge.inMinutes < 5) {
      return Row(
        children: [
          Icon(Icons.cloud_done, size: 16, color: Colors.green),
          SizedBox(width: 4),
          Text(
            'Synkad nyligen',
            style: TextStyle(color: Colors.green, fontSize: 12),
          ),
        ],
      );
    }

    return SizedBox.shrink();
  }
}
```

---

## Pending Changes Tracking

### Track Specific Field Changes

```dart
class OfflineChangeTracker {
  final List<String> _pendingChanges = [];

  void trackChange(String fieldName) {
    if (!_pendingChanges.contains(fieldName)) {
      _pendingChanges.add(fieldName);
    }
  }

  List<String> getPendingChanges() {
    return List.from(_pendingChanges);
  }

  void clearChanges() {
    _pendingChanges.clear();
  }
}

// Usage
final tracker = OfflineChangeTracker();

// User edits title
recipe.title = 'New Title';
tracker.trackChange('title');

// User adds ingredient
recipe.ingredients.add(newIngredient);
tracker.trackChange('ingredients');

// Save with tracked changes
recipe.offlineData = RecipeOfflineData.modified(
  changes: tracker.getPendingChanges(),
);
```

### Display Pending Changes

```dart
class PendingChangesIndicator extends StatelessWidget {
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final changes = recipe.offlineData.pendingChanges;
    if (changes == null || changes.isEmpty) {
      return SizedBox.shrink();
    }

    return Wrap(
      spacing: 4,
      children: changes.map((change) {
        return Chip(
          label: Text(_formatFieldName(change)),
          backgroundColor: Colors.orange.shade100,
          deleteIcon: Icon(Icons.sync, size: 16),
        );
      }).toList(),
    );
  }

  String _formatFieldName(String field) {
    switch (field) {
      case 'title': return 'Titel';
      case 'ingredients': return 'Ingredienser';
      case 'instructions': return 'Instruktioner';
      default: return field;
    }
  }
}
```

---

## Sync Age Display

```dart
class SyncAgeDisplay extends StatelessWidget {
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final syncAge = recipe.offlineData.timeSinceSync;

    if (syncAge == null) {
      return Text('Aldrig synkad', style: TextStyle(color: Colors.grey));
    }

    final ageText = _formatSyncAge(syncAge);
    final color = _getAgeColor(syncAge);

    return Row(
      children: [
        Icon(Icons.access_time, size: 14, color: color),
        SizedBox(width: 4),
        Text(
          'Synkad $ageText',
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }

  String _formatSyncAge(Duration age) {
    if (age.inMinutes < 1) return 'just nu';
    if (age.inMinutes < 60) return '${age.inMinutes} min sedan';
    if (age.inHours < 24) return '${age.inHours} timmar sedan';
    return '${age.inDays} dagar sedan';
  }

  Color _getAgeColor(Duration age) {
    if (age.inMinutes < 5) return Colors.green;
    if (age.inHours < 1) return Colors.blue;
    if (age.inHours < 24) return Colors.orange;
    return Colors.red;
  }
}
```

---

## Testing

```dart
group('RecipeOfflineData', () {
  test('needsSync returns true for modified offline', () {
    final data = RecipeOfflineData.modified(changes: ['title']);

    expect(data.needsSync, isTrue);
    expect(data.isModifiedOffline, isTrue);
  });

  test('needsSync returns true for never synced', () {
    final data = RecipeOfflineData(
      isModifiedOffline: false,
      lastSyncedAt: null,
    );

    expect(data.needsSync, isTrue);
    expect(data.isNeverSynced, isTrue);
  });

  test('needsSync returns false after sync', () {
    final data = RecipeOfflineData.synced();

    expect(data.needsSync, isFalse);
    expect(data.isModifiedOffline, isFalse);
    expect(data.lastSyncedAt, isNotNull);
  });

  test('timeSinceSync calculates correctly', () {
    final data = RecipeOfflineData.unmodified(
      syncedAt: DateTime.now().subtract(Duration(hours: 2)),
    );

    expect(data.timeSinceSync!.inHours, 2);
  });
});
```

---

## Best Practices

1. **Always set offline data** - Mark edits immediately
2. **Track specific changes** - Use pendingChanges for field-level tracking
3. **Update after sync** - Mark as synced after successful Firebase save
4. **Display status to user** - Show sync age and pending changes
5. **Clear on sync** - Remove pendingChanges after successful sync

---

## Related Resources

- [offline-service.md](offline-service.md) - OfflineService using these models
- [sync-mechanisms.md](sync-mechanisms.md) - Sync logic with offline data
- [ui-integration.md](ui-integration.md) - UI components displaying offline status

---

**Model**: RecipeOfflineData (embedded in Recipe)
**Fields**: lastSyncedAt, isModifiedOffline, pendingChanges
**Status**: ✅ Production-ready
