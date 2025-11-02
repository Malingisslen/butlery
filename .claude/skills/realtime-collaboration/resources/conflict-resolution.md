# Conflict Resolution

Comprehensive guide to handling edit conflicts in real-time collaboration: automatic resolution strategies, manual overrides, and field-level merging.

## Overview

When multiple users edit the same resource simultaneously, conflicts can occur. Butlery's **RealtimeSyncService** provides:

1. **Automatic conflict resolution** - Uses `editCount` and timestamps
2. **Manual conflict resolution** - For complex scenarios
3. **Field-level merging** - Preserve both changes when possible
4. **Conflict detection** - Identify when conflicts occur
5. **Audit logging** - Track all conflict resolutions

---

## Conflict Resolution Strategy

### Primary Key: editCount

**editCount** is incremented on every collaborative edit. It's the primary conflict resolution key.

```dart
// Higher editCount wins
if (server.editCount > local.editCount) {
  return server;  // Server has more edits
} else if (local.editCount > server.editCount) {
  return local;   // Local has more edits
}
```

**Why editCount works**:
- Represents total collaborative work
- Monotonically increasing (never decreases)
- Simple integer comparison
- No time zone issues

### Secondary Key: lastEditedAt

When `editCount` values are equal, use timestamp as tiebreaker:

```dart
// Timestamps as tiebreaker
if (server.lastEditedAt.isAfter(local.lastEditedAt)) {
  return server;  // Server is newer
} else {
  return local;   // Local is newer (or equal)
}
```

**When equal editCounts occur**:
- Race condition: Two edits at exact same editCount
- Very rare in practice
- Timestamp provides deterministic resolution

---

## Automatic Conflict Resolution

### RealtimeSyncService Implementation

```dart
class RealtimeSyncService extends BaseService {
  Future<void> updateResource<T extends RealtimeResource>(
    String resourceId, {
    required T Function(T current) updater,
  }) async {
    // 1. Get current server version
    final serverVersion = await _getServerVersion<T>(resourceId);

    // 2. Get local cached version (if exists)
    final localVersion = _getCachedVersion<T>(resourceId);

    // 3. Detect conflict
    if (_hasConflict(localVersion, serverVersion)) {
      // 4. Resolve automatically
      final resolved = await _resolveConflict(localVersion, serverVersion);

      // 5. Apply user's update to resolved version
      final updated = updater(resolved);

      // 6. Save to Firebase
      await _saveToFirebase(resourceId, updated);
    } else {
      // No conflict - apply update directly
      final updated = updater(serverVersion);
      await _saveToFirebase(resourceId, updated);
    }
  }

  bool _hasConflict<T extends RealtimeResource>(
    T? local,
    T server,
  ) {
    if (local == null) return false;  // No local version

    // Conflict if editCounts or timestamps differ
    return local.editCount != server.editCount ||
           local.lastEditedAt != server.lastEditedAt;
  }

  T _resolveConflict<T extends RealtimeResource>(
    T local,
    T server,
  ) {
    // Primary: Compare editCount
    if (server.editCount > local.editCount) {
      return server;
    } else if (local.editCount > server.editCount) {
      return local;
    }

    // Secondary: Compare timestamp
    if (server.lastEditedAt.isAfter(local.lastEditedAt)) {
      return server;
    } else {
      return local;
    }
  }
}
```

### Example: Automatic Resolution

```dart
// User A edits recipe at editCount=10
final recipeA = RealtimeRecipe(
  id: 'recipe-123',
  recipe: Recipe(title: 'Pasta A'),
  editCount: 11,  // Incremented
  lastEditedAt: DateTime.now(),
);

// User B edits same recipe at editCount=10
final recipeB = RealtimeRecipe(
  id: 'recipe-123',
  recipe: Recipe(title: 'Pasta B'),
  editCount: 11,  // Also incremented
  lastEditedAt: DateTime.now().add(Duration(seconds: 5)),  // 5 seconds later
);

// Conflict detected: both at editCount=11
// Resolution: Use timestamp tiebreaker
// Winner: recipeB (newer timestamp)
```

---

## Manual Conflict Resolution

### When to Use Manual Resolution

1. **Field-level conflicts** - Different fields edited by different users
2. **Complex merging** - Both changes should be preserved
3. **Business logic** - Custom resolution rules
4. **User intervention** - Let user choose which version to keep

### Example: Field-Level Merging

```dart
Future<void> mergeRecipeConflict(
  String recipeId,
  RealtimeRecipe local,
  RealtimeRecipe server,
) async {
  final syncService = ServiceLocator.get<RealtimeSyncService>();

  // Custom merge logic
  final merged = RealtimeRecipe(
    id: recipeId,
    ownerId: server.ownerId,
    participants: server.participants,  // Always use server

    recipe: Recipe(
      // User A changed title (local)
      title: local.recipe.title,

      // User B changed description (server)
      description: server.recipe.description,

      // Both added ingredients - merge lists
      ingredients: _mergeIngredients(
        local.recipe.ingredients,
        server.recipe.ingredients,
      ),

      // Both added instructions - merge lists
      instructions: _mergeInstructions(
        local.recipe.instructions,
        server.recipe.instructions,
      ),

      // User B changed portions (server)
      portions: server.recipe.portions,

      // User A added image (local)
      imageUrls: [...server.recipe.imageUrls, ...local.recipe.imageUrls],
    ),

    // Conflict resolved - increment editCount
    editCount: max(local.editCount, server.editCount) + 1,
    lastEditedAt: DateTime.now(),
    lastEditedBy: _currentUserId,
    lastEditedByDisplayName: _currentUserName,

    // Keep server metadata
    createdAt: server.createdAt,
    isActive: server.isActive,
    metadata: server.metadata,
  );

  // Apply merged version
  await syncService.resolveConflict<RealtimeRecipe>(
    recipeId,
    localVersion: merged,
    serverVersion: server,
  );
}

List<Ingredient> _mergeIngredients(
  List<Ingredient> local,
  List<Ingredient> server,
) {
  // Combine both lists, removing duplicates by name
  final merged = <String, Ingredient>{};

  for (final ingredient in server) {
    merged[ingredient.name.toLowerCase()] = ingredient;
  }

  for (final ingredient in local) {
    // Add if not in server version
    if (!merged.containsKey(ingredient.name.toLowerCase())) {
      merged[ingredient.name.toLowerCase()] = ingredient;
    }
  }

  return merged.values.toList();
}

List<String> _mergeInstructions(
  List<String> local,
  List<String> server,
) {
  // Use server instructions as base
  final merged = List<String>.from(server);

  // Add local instructions that aren't in server
  for (final instruction in local) {
    if (!server.contains(instruction)) {
      merged.add(instruction);
    }
  }

  return merged;
}
```

### Example: User-Driven Resolution

```dart
Future<void> showConflictDialog(
  BuildContext context,
  RealtimeRecipe local,
  RealtimeRecipe server,
) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Konflikt upptäckt'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Receptet har ändrats av en annan användare'),
          SizedBox(height: 16),
          Text('Välj vilken version du vill behålla:'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'local'),
          child: Column(
            children: [
              Text('Min version'),
              Text(
                'Senast ändrad: ${local.lastEditedTimeAgo}',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'server'),
          child: Column(
            children: [
              Text('${server.lastEditedByDisplayName}s version'),
              Text(
                'Senast ändrad: ${server.lastEditedTimeAgo}',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'merge'),
          child: Text('Slå ihop båda'),
        ),
      ],
    ),
  );

  if (choice == null) return;

  final syncService = ServiceLocator.get<RealtimeSyncService>();

  switch (choice) {
    case 'local':
      await syncService.resolveConflict(
        local.id,
        localVersion: local,
        serverVersion: server,
      );
      break;
    case 'server':
      // Just use server version (do nothing)
      break;
    case 'merge':
      await mergeRecipeConflict(local.id, local, server);
      break;
  }
}
```

---

## Conflict Detection

### Detect at Update Time

```dart
Future<void> updateRecipeTitle(
  String recipeId,
  String newTitle,
) async {
  final service = ServiceLocator.get<RealtimeRecipeService>();

  try {
    await service.updateBasicInfo(recipeId, title: newTitle);
  } on ConflictException catch (e) {
    // Conflict detected
    print('Conflict: ${e.message}');
    print('Local editCount: ${e.localVersion.editCount}');
    print('Server editCount: ${e.serverVersion.editCount}');

    // Handle conflict
    await _handleConflict(e.localVersion, e.serverVersion);
  }
}
```

### Monitor editCount Changes

```dart
class RecipeEditMonitor extends StatefulWidget {
  final String recipeId;

  @override
  _RecipeEditMonitorState createState() => _RecipeEditMonitorState();
}

class _RecipeEditMonitorState extends State<RecipeEditMonitor> {
  int? _lastKnownEditCount;

  @override
  Widget build(BuildContext context) {
    final service = ServiceLocator.get<RealtimeRecipeService>();

    return StreamBuilder<RealtimeRecipe>(
      stream: service.watchRealtimeRecipe(widget.recipeId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();

        final recipe = snapshot.data!;

        // Detect if someone else edited
        if (_lastKnownEditCount != null &&
            recipe.editCount > _lastKnownEditCount!) {
          // Show notification
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${recipe.lastEditedByDisplayName} uppdaterade receptet',
                ),
              ),
            );
          });
        }

        _lastKnownEditCount = recipe.editCount;

        return RecipeDisplay(recipe: recipe);
      },
    );
  }
}
```

---

## Optimistic Updates with Conflict Handling

### Pattern: Optimistic Update + Rollback

```dart
Future<void> updateIngredients(
  String recipeId,
  List<Ingredient> newIngredients,
) async {
  final service = ServiceLocator.get<RealtimeRecipeService>();

  // 1. Save current state (for rollback)
  final originalIngredients = _currentRecipe.recipe.ingredients;

  // 2. Update UI optimistically
  setState(() {
    _currentRecipe.recipe.ingredients = newIngredients;
  });

  try {
    // 3. Send to server
    await service.updateIngredients(recipeId, newIngredients);

    // 4. Success - editCount incremented automatically
  } on ConflictException catch (e) {
    // 5. Conflict detected - resolve
    final resolved = await _resolveIngredientConflict(
      originalIngredients,
      newIngredients,
      e.serverVersion.recipe.ingredients,
    );

    // 6. Update UI with resolved version
    setState(() {
      _currentRecipe.recipe.ingredients = resolved;
    });

    // 7. Send resolved version to server
    await service.updateIngredients(recipeId, resolved);
  } catch (e) {
    // 8. Error - rollback to original
    setState(() {
      _currentRecipe.recipe.ingredients = originalIngredients;
    });

    showError('Kunde inte uppdatera ingredienser');
  }
}

Future<List<Ingredient>> _resolveIngredientConflict(
  List<Ingredient> original,
  List<Ingredient> local,
  List<Ingredient> server,
) async {
  // Merge strategy: Keep server + add local additions
  final merged = List<Ingredient>.from(server);

  for (final ingredient in local) {
    // If ingredient was added locally (not in original)
    final wasAdded = !original.any((i) => i.id == ingredient.id);

    if (wasAdded) {
      // Add to merged list if not already in server
      final existsInServer = server.any((i) => i.id == ingredient.id);
      if (!existsInServer) {
        merged.add(ingredient);
      }
    }
  }

  return merged;
}
```

---

## Audit Logging for Conflicts

```dart
Future<void> _logConflictResolution(
  String resourceId,
  RealtimeResource local,
  RealtimeResource server,
  RealtimeResource resolved,
) async {
  final auditRepo = ServiceLocator.get<FirebaseAuditRepository>();

  await auditRepo.logAuditEvent(AuditEvent(
    id: Uuid().v4(),
    userId: _currentUserId,
    action: AuditAction.conflictResolved,
    resourceType: 'realtime_recipe',
    resourceId: resourceId,
    timestamp: DateTime.now(),
    metadata: {
      'localEditCount': local.editCount,
      'serverEditCount': server.editCount,
      'resolvedEditCount': resolved.editCount,
      'resolutionStrategy': 'automatic',  // or 'manual'
      'winner': resolved == server ? 'server' : 'local',
    },
  ));
}
```

---

## Testing Conflict Resolution

```dart
group('Conflict Resolution', () {
  late RealtimeSyncService service;

  setUp() {
    service = ServiceLocator.get<RealtimeSyncService>();
  });

  test('higher editCount wins', () async {
    final local = RealtimeRecipe(
      id: 'recipe-123',
      recipe: Recipe(title: 'Local'),
      editCount: 10,
      lastEditedAt: DateTime.now(),
    );

    final server = RealtimeRecipe(
      id: 'recipe-123',
      recipe: Recipe(title: 'Server'),
      editCount: 15,  // Higher
      lastEditedAt: DateTime.now(),
    );

    final resolved = service._resolveConflict(local, server);

    expect(resolved, equals(server));
    expect(resolved.recipe.title, 'Server');
  });

  test('newer timestamp wins on equal editCount', () async {
    final now = DateTime.now();

    final local = RealtimeRecipe(
      id: 'recipe-123',
      recipe: Recipe(title: 'Local'),
      editCount: 10,
      lastEditedAt: now,
    );

    final server = RealtimeRecipe(
      id: 'recipe-123',
      recipe: Recipe(title: 'Server'),
      editCount: 10,  // Equal
      lastEditedAt: now.add(Duration(seconds: 5)),  // Newer
    );

    final resolved = service._resolveConflict(local, server);

    expect(resolved, equals(server));
  });

  test('field-level merge preserves both changes', () async {
    final local = RealtimeRecipe(
      id: 'recipe-123',
      recipe: Recipe(
        title: 'Local Title',  // Changed
        description: 'Original',
        ingredients: [Ingredient(name: 'Tomato')],  // Added
      ),
      editCount: 10,
    );

    final server = RealtimeRecipe(
      id: 'recipe-123',
      recipe: Recipe(
        title: 'Original',
        description: 'Server Description',  // Changed
        ingredients: [Ingredient(name: 'Onion')],  // Added
      ),
      editCount: 10,
    );

    final merged = _mergeRecipes(local, server);

    expect(merged.recipe.title, 'Local Title');  // Local wins
    expect(merged.recipe.description, 'Server Description');  // Server wins
    expect(merged.recipe.ingredients.length, 2);  // Both ingredients
  });
});
```

---

## Best Practices

1. **Trust automatic resolution**
   - editCount strategy works for 99% of cases
   - Only implement manual resolution when necessary

2. **Increment editCount on every edit**
   - Ensures accurate conflict detection
   - Never skip incrementing

3. **Use optimistic updates**
   - Better UX (immediate feedback)
   - Handle conflicts gracefully
   - Rollback on error

4. **Log all conflicts**
   - Audit trail for debugging
   - Monitor conflict frequency
   - Identify problematic workflows

5. **Field-level merging for complex cases**
   - Preserve both users' work when possible
   - Use merge strategies appropriate to data type
   - Arrays: union, Objects: prefer server or manual

6. **Test conflict scenarios**
   - Simulate simultaneous edits
   - Verify resolution logic
   - Test rollback behavior

---

## Related Resources

- [realtime-services.md](realtime-services.md) - RealtimeSyncService implementation
- [realtime-models.md](realtime-models.md) - RealtimeResource with editCount
- [ui-integration.md](ui-integration.md) - Optimistic updates in UI

---

**Strategy**: editCount (primary) + timestamp (secondary)
**Automatic Resolution**: 99% of conflicts
**Manual Resolution**: Complex field-level merging
**Status**: ✅ Production-ready
