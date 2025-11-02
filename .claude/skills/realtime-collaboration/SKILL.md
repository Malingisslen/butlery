# Real-Time Collaboration Skill

**Purpose**: Master real-time collaborative editing, presence tracking, and conflict resolution in Butlery

**Domain**: Firebase real-time streams, collaborative editing, presence awareness, conflict resolution

**Use Cases**:
- Implementing collaborative recipe editing
- Building shared menu management
- Adding presence tracking (online status, typing indicators)
- Handling edit conflicts in real-time
- Optimistic UI updates for collaborative features

---

## Quick Reference

### Real-Time Services

**RealtimeRecipeService** - Multi-user recipe collaboration
```dart
// Create collaborative recipe
final realtimeRecipe = await _realtimeRecipeService.createRealtimeRecipe(
  recipe: myRecipe,
  sharedWith: ['user-id-1', 'user-id-2'],
  ownerPermission: PermissionLevel.editor,
);

// Watch real-time updates
final stream = _realtimeRecipeService.watchRealtimeRecipe(recipeId);

// Update content with automatic conflict resolution
await _realtimeRecipeService.updateBasicInfo(
  recipeId,
  title: 'New Title',
  description: 'Updated description',
);

// Add participants
await _realtimeRecipeService.addParticipant(
  recipeId,
  userId: 'new-user-id',
  permission: PermissionLevel.editor,
);
```

**RealtimeMenuService** - Category-based menu collaboration
```dart
// Create collaborative menu
final realtimeMenu = await _realtimeMenuService.createRealtimeMenu(
  menu: myMenu,
  sharedWith: userIds,
);

// Watch menu updates
final stream = _realtimeMenuService.watchRealtimeMenu(menuId);

// Update category
await _realtimeMenuService.addRecipeToCategory(
  menuId,
  categoryName: 'Middag',
  recipe: newRecipe,
);
```

**PresenceService** - User presence and typing indicators
```dart
// Watch user online status
final presenceStream = _presenceService.getPresenceStream(userId);

// Watch multiple users (batch)
final presences = _presenceService.getMultiplePresenceStream(userIds);

// Start typing indicator
await _presenceService.startTyping(conversationId);

// Stop typing
await _presenceService.stopTyping(conversationId);

// Get typing users
final typingStream = _presenceService.getTypingUsersStream(conversationId);
```

**RealtimeSyncService** - Core synchronization engine
```dart
// Watch any realtime resource
final stream = _syncService.watchResource<RealtimeRecipe>(resourceId);

// Update with conflict resolution
await _syncService.updateResource<RealtimeRecipe>(
  resourceId,
  updater: (current) {
    current.recipe.title = 'New Title';
    return current;
  },
);

// Resolve conflict manually
await _syncService.resolveConflict<RealtimeRecipe>(
  resourceId,
  localVersion: local,
  serverVersion: server,
);
```

---

## Core Architecture

### Realtime Resource Model Hierarchy

```
RealtimeResource (base class)
├─ id, type, ownerId, ownerDisplayName
├─ participants: Map<userId, PermissionLevel>
├─ lastEditedAt, lastEditedBy, lastEditedByDisplayName
├─ editCount (conflict resolution key)
├─ createdAt, isActive, metadata
├─ Permission methods: hasPermission(), canUserEdit(), isOwner()
└─ Activity tracking: timeSinceLastEdit, hasRecentActivity

  ├─ RealtimeRecipe
  │  └─ Recipe recipe (title, ingredients, instructions, etc.)
  │
  └─ RealtimeMenu
     └─ RealtimeMenuData data (categories, recipes, notes)
```

### Permission Levels
```dart
enum PermissionLevel {
  owner,   // Full control, cannot be removed
  admin,   // Can manage participants
  editor,  // Can edit content (write access)
  viewer,  // Can view only (read access)
}
```

### Conflict Resolution Strategy

**Primary Key**: `editCount` (incremented on each edit)
- Higher editCount wins conflict
- Ensures most recent collaborative work is preserved

**Secondary Key**: `lastEditedAt` (timestamp)
- Used as tiebreaker if editCounts equal
- Newer timestamp wins

**Field-Level Merging**: For complex conflicts
- Preserve both changes where possible
- Merge non-conflicting fields
- Log conflict details for audit

---

## Real-Time Patterns

### Pattern 1: StreamBuilder Integration

```dart
class CollaborativeRecipeView extends StatelessWidget {
  final String recipeId;

  @override
  Widget build(BuildContext context) {
    final service = ServiceLocator.get<RealtimeRecipeService>();

    return StreamBuilder<RealtimeRecipe>(
      stream: service.watchRealtimeRecipe(recipeId),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingIndicator();
        }

        // Error state
        if (snapshot.hasError) {
          return ErrorWidget(error: snapshot.error.toString());
        }

        // No data
        if (!snapshot.hasData) {
          return EmptyState(message: 'Recipe not found');
        }

        // Success - render recipe
        final realtimeRecipe = snapshot.data!;
        return RecipeDisplay(recipe: realtimeRecipe);
      },
    );
  }
}
```

### Pattern 2: Optimistic Updates

```dart
Future<void> updateRecipeTitle(String recipeId, String newTitle) async {
  // 1. Update UI immediately (optimistic)
  setState(() {
    _localRecipe.title = newTitle;
  });

  try {
    // 2. Send to Firebase
    await _realtimeRecipeService.updateBasicInfo(
      recipeId,
      title: newTitle,
    );
    // 3. Stream automatically broadcasts to all users
    // 4. Conflict resolution runs if needed
  } catch (e) {
    // 5. Revert on error
    setState(() {
      _localRecipe.title = _previousTitle;
    });
    showError('Failed to update: $e');
  }
}
```

### Pattern 3: Presence Indicators

```dart
class ParticipantList extends StatelessWidget {
  final List<String> userIds;

  @override
  Widget build(BuildContext context) {
    final presenceService = ServiceLocator.get<PresenceService>();

    return StreamBuilder<Map<String, UserPresence>>(
      stream: presenceService.getMultiplePresenceStream(userIds),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();

        final presences = snapshot.data!;
        return Row(
          children: userIds.map((userId) {
            final presence = presences[userId];
            final isOnline = presence?.status == UserStatus.online;

            return Padding(
              padding: EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(
                      _getUserAvatar(userId),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
```

### Pattern 4: Typing Indicators

```dart
class TypingIndicator extends StatelessWidget {
  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final presenceService = ServiceLocator.get<PresenceService>();

    return StreamBuilder<List<UserPresence>>(
      stream: presenceService.getTypingUsersStream(conversationId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SizedBox.shrink();
        }

        final typingUsers = snapshot.data!;
        final names = typingUsers
            .map((p) => _getUserDisplayName(p.userId))
            .join(', ');

        return Row(
          children: [
            ThreeDotsAnimation(),
            SizedBox(width: 8),
            Text('$names skriver...'),
          ],
        );
      },
    );
  }
}
```

---

## Conflict Resolution

### Automatic Resolution (editCount-based)

```dart
// RealtimeSyncService handles this automatically
Future<void> _resolveConflict(
  RealtimeResource local,
  RealtimeResource server,
) async {
  // 1. Compare editCounts
  if (server.editCount > local.editCount) {
    // Server wins - more edits
    return server;
  } else if (local.editCount > server.editCount) {
    // Local wins - more edits
    return local;
  }

  // 2. Tiebreaker: Compare timestamps
  if (server.lastEditedAt.isAfter(local.lastEditedAt)) {
    return server;
  } else {
    return local;
  }
}
```

### Manual Conflict Resolution

```dart
Future<void> resolveRecipeConflict(
  String recipeId,
  RealtimeRecipe local,
  RealtimeRecipe server,
) async {
  // Custom merge logic for recipe-specific conflicts
  final merged = RealtimeRecipe(
    id: recipeId,
    recipe: Recipe(
      title: server.recipe.title,  // Keep server title
      ingredients: _mergeIngredients(
        local.recipe.ingredients,
        server.recipe.ingredients,
      ),  // Merge both ingredient lists
      instructions: server.recipe.instructions,  // Keep server
    ),
    participants: server.participants,
    lastEditedAt: DateTime.now(),
    lastEditedBy: _currentUserId,
    editCount: max(local.editCount, server.editCount) + 1,
  );

  await _syncService.resolveConflict<RealtimeRecipe>(
    recipeId,
    localVersion: merged,
    serverVersion: server,
  );
}
```

---

## Activity Tracking

### Activity Status
```dart
// RealtimeMetadata provides activity calculations
final isActive = recipe.hasRecentActivity;  // Edited in last 7 days
final activityLevel = recipe.activityLevel;  // 1-5 scale
final activityText = recipe.activityText;    // "Aktiv nu" or "Inaktiv"

// Display activity indicator
Container(
  width: 10,
  height: 10,
  decoration: BoxDecoration(
    color: recipe.hasRecentActivity ? Colors.green : Colors.grey,
    shape: BoxShape.circle,
  ),
);

Text(recipe.activityText);  // "Aktiv nu" or "Inaktiv"
```

### Edit History
```dart
// Last editor display
Text('Senast redigerad av ${recipe.lastEditedByDisplayName}');
Text(recipe.lastEditedTimeAgo);  // "2 timmar sedan"

// Change summary
final summary = recipe.getChangesSummary();
Text('${summary.totalEdits} ändringar av ${summary.uniqueEditors} användare');
```

---

## Best Practices

1. **Use Streams for All Real-Time Data**
   - StreamBuilder for UI updates
   - Automatic cleanup via stream subscription
   - Error propagation through stream errors

2. **Implement Optimistic Updates**
   - Update local state immediately
   - Send to Firebase in background
   - Revert on error

3. **Multi-Level Permission Validation**
   - Service layer checks permissions
   - Model layer validates operations
   - Sync layer enforces security rules

4. **Graceful Conflict Handling**
   - Let RealtimeSyncService handle automatic resolution
   - Use editCount as primary resolution key
   - Implement custom merge logic only when necessary

5. **Presence Management**
   - Use debouncing for typing indicators (500ms)
   - Implement heartbeats for online status (1 minute)
   - Clean up stale presence data (5 seconds for typing)

6. **Performance Optimization**
   - Cache current resource locally
   - Batch presence queries (limit: 10 per query)
   - Lazy stream initialization
   - Dispose streams properly

---

## Common Patterns

### Create and Share Recipe
```dart
Future<RealtimeRecipe> createAndShareRecipe(
  Recipe recipe,
  List<String> friendIds,
) async {
  final service = ServiceLocator.get<RealtimeRecipeService>();

  // Create collaborative recipe
  final realtimeRecipe = await service.createRealtimeRecipe(
    recipe: recipe,
    sharedWith: friendIds,
    ownerPermission: PermissionLevel.editor,
  );

  return realtimeRecipe;
}
```

### Watch and Display Real-Time Updates
```dart
class RealtimeRecipeWidget extends StatefulWidget {
  final String recipeId;

  @override
  _RealtimeRecipeWidgetState createState() => _RealtimeRecipeWidgetState();
}

class _RealtimeRecipeWidgetState extends State<RealtimeRecipeWidget> {
  late final RealtimeRecipeService _service;
  late final Stream<RealtimeRecipe> _recipeStream;

  @override
  void initState() {
    super.initState();
    _service = ServiceLocator.get<RealtimeRecipeService>();
    _recipeStream = _service.watchRealtimeRecipe(widget.recipeId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RealtimeRecipe>(
      stream: _recipeStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LoadingWidget();
        return RecipeContent(recipe: snapshot.data!);
      },
    );
  }
}
```

### Add Participant to Recipe
```dart
Future<void> inviteToRecipe(
  String recipeId,
  String userId,
  PermissionLevel permission,
) async {
  final service = ServiceLocator.get<RealtimeRecipeService>();

  await service.addParticipant(
    recipeId,
    userId: userId,
    permission: permission,
  );

  showSnackbar('User invited to recipe');
}
```

### Track Typing Status
```dart
class MessageInput extends StatefulWidget {
  final String conversationId;

  @override
  _MessageInputState createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  late final PresenceService _presenceService;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _presenceService = ServiceLocator.get<PresenceService>();
  }

  void _onTextChanged(String text) {
    // Start typing indicator
    _presenceService.startTyping(widget.conversationId);

    // Reset timer
    _typingTimer?.cancel();
    _typingTimer = Timer(Duration(seconds: 3), () {
      _presenceService.stopTyping(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _presenceService.stopTyping(widget.conversationId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: _onTextChanged,
      decoration: InputDecoration(hintText: 'Skriv meddelande...'),
    );
  }
}
```

---

## Resources

Detailed guides for specific real-time collaboration topics:

- **[realtime-services.md](resources/realtime-services.md)** - RealtimeRecipeService, RealtimeMenuService, RealtimeSyncService
- **[presence-tracking.md](resources/presence-tracking.md)** - PresenceService, online status, typing indicators
- **[conflict-resolution.md](resources/conflict-resolution.md)** - Automatic and manual conflict resolution strategies
- **[realtime-models.md](resources/realtime-models.md)** - RealtimeResource, RealtimeRecipe, RealtimeMenu, metadata
- **[ui-integration.md](resources/ui-integration.md)** - StreamBuilder patterns, indicators, optimistic updates

---

## Related Skills

- **dependency-injection-patterns** - Service registration and access patterns
- **offline-first-patterns** - Local caching and sync strategies
- **gdpr-compliance** - Audit logging for collaborative actions

---

**Status**: ✅ Production-ready
**Coverage**: Recipes, Menus, Shopping Lists
**Performance**: Optimized with caching and lazy loading
**Conflict Resolution**: Automatic with manual override support
