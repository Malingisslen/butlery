# UI Integration - Part 1: StreamBuilder & Indicators

Guide to using StreamBuilder for real-time data and implementing activity indicators.

**Part of**: [ui-integration](./ui-integration.md) (split for readability)
**See also**: [Part 2: Updates](./ui-integration-part2-updates.md), [Part 3: Conflicts](./ui-integration-part3-conflicts.md)

## Overview

Real-time collaboration requires careful UI integration to provide:
- **Instant feedback** - Optimistic updates for immediate response
- **Live synchronization** - StreamBuilder for real-time data
- **Activity indicators** - Show who's online, who's editing
- **Conflict awareness** - Notify users of simultaneous edits
- **Smooth UX** - Animations and transitions

---

## StreamBuilder Pattern

### Basic StreamBuilder

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
          return Center(child: CircularProgressIndicator());
        }

        // Error state
        if (snapshot.hasError) {
          return ErrorView(error: snapshot.error.toString());
        }

        // No data
        if (!snapshot.hasData) {
          return EmptyState(message: 'Recept hittades inte');
        }

        // Success - display recipe
        final realtimeRecipe = snapshot.data!;
        return RecipeContent(recipe: realtimeRecipe);
      },
    );
  }
}
```

### StreamBuilder with Loading Overlay

```dart
class CollaborativeRecipeViewWithOverlay extends StatelessWidget {
  final String recipeId;

  @override
  Widget build(BuildContext context) {
    final service = ServiceLocator.get<RealtimeRecipeService>();

    return StreamBuilder<RealtimeRecipe>(
      stream: service.watchRealtimeRecipe(recipeId),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasData = snapshot.hasData;

        return Stack(
          children: [
            // Main content (show cached if available)
            if (hasData)
              RecipeContent(recipe: snapshot.data!),

            // Loading overlay
            if (isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),

            // Error snackbar
            if (snapshot.hasError)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Material(
                  color: Colors.red,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Fel vid uppdatering: ${snapshot.error}',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
```

### Multiple Streams (CombineLatestStream)

```dart
class RecipeWithComments extends StatelessWidget {
  final String recipeId;

  @override
  Widget build(BuildContext context) {
    final recipeService = ServiceLocator.get<RealtimeRecipeService>();
    final commentService = ServiceLocator.get<CommentService>();

    return StreamBuilder<(RealtimeRecipe, List<Comment>)>(
      stream: Rx.combineLatest2(
        recipeService.watchRealtimeRecipe(recipeId),
        commentService.watchComments(recipeId),
        (recipe, comments) => (recipe, comments),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LoadingWidget();

        final (recipe, comments) = snapshot.data!;

        return Column(
          children: [
            RecipeContent(recipe: recipe),
            Divider(),
            CommentsSection(comments: comments),
          ],
        );
      },
    );
  }
}
```

---

## Real-Time Indicators

### Last Editor Indicator

```dart
class LastEditorIndicator extends StatelessWidget {
  final RealtimeRecipe recipe;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.edit, size: 16, color: Colors.grey),
        SizedBox(width: 4),
        Text(
          'Senast redigerad av ${recipe.lastEditedByDisplayName} ${recipe.lastEditedTimeAgo}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
```

### Activity Badge

```dart
class ActivityBadge extends StatelessWidget {
  final RealtimeRecipe recipe;

  @override
  Widget build(BuildContext context) {
    final isActive = recipe.hasRecentActivity;
    final color = isActive ? Colors.green : Colors.grey;

    return Tooltip(
      message: recipe.activityText,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 6),
            Text(
              recipe.activityText,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Participant Avatars with Online Status

```dart
class ParticipantAvatars extends StatelessWidget {
  final RealtimeRecipe recipe;

  @override
  Widget build(BuildContext context) {
    final presenceService = ServiceLocator.get<PresenceService>();
    final userIds = recipe.participants.keys.toList();

    return StreamBuilder<Map<String, UserPresence>>(
      stream: presenceService.getMultiplePresenceStream(userIds),
      builder: (context, snapshot) {
        final presences = snapshot.data ?? {};

        return Row(
          children: userIds.take(5).map((userId) {
            final presence = presences[userId];
            final isOnline = presence?.status == UserStatus.online;

            return Padding(
              padding: EdgeInsets.only(right: 4),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(
                      _getUserAvatar(userId),
                    ),
                  ),
                  // Online indicator
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
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

### Edit Count Badge

```dart
class EditCountBadge extends StatelessWidget {
  final int editCount;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(Icons.history, size: 16),
      label: Text('$editCount ändringar'),
      backgroundColor: Colors.blue.shade50,
    );
  }
}
```

---

## Next Steps

Continue with:
- **[Part 2: Updates](./ui-integration-part2-updates.md)** - Optimistic updates and collaborative notifications
- **[Part 3: Conflicts](./ui-integration-part3-conflicts.md)** - Conflict resolution UI and best practices

---

**Patterns**: StreamBuilder, real-time indicators, online status
**Status**: ✅ Production-ready
