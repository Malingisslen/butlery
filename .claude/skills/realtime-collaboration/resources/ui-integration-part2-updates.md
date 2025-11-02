# UI Integration - Part 2: Optimistic Updates & Notifications

Guide to implementing optimistic updates and collaborative editing notifications.

**Part of**: [ui-integration](./ui-integration.md) (split for readability)
**See also**: [Part 1: StreamBuilder](./ui-integration-part1-streambuilder.md), [Part 3: Conflicts](./ui-integration-part3-conflicts.md)

## Optimistic Updates

### Pattern: Optimistic Update with Rollback

```dart
class RecipeTitleEditor extends StatefulWidget {
  final String recipeId;
  final String currentTitle;

  @override
  _RecipeTitleEditorState createState() => _RecipeTitleEditorState();
}

class _RecipeTitleEditorState extends State<RecipeTitleEditor> {
  late TextEditingController _controller;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentTitle);
  }

  Future<void> _saveTitle() async {
    final newTitle = _controller.text;
    final originalTitle = widget.currentTitle;

    // 1. Update UI immediately (optimistic)
    setState(() {
      _errorMessage = null;
    });

    try {
      // 2. Send to server
      final service = ServiceLocator.get<RealtimeRecipeService>();
      await service.updateBasicInfo(
        widget.recipeId,
        title: newTitle,
      );

      // 3. Success - stream will update UI automatically
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Titel uppdaterad')),
      );
    } catch (e) {
      // 4. Error - rollback
      setState(() {
        _controller.text = originalTitle;
        _errorMessage = 'Kunde inte spara: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Titel',
            errorText: _errorMessage,
          ),
          onSubmitted: (_) => _saveTitle(),
        ),
        SizedBox(height: 8),
        ElevatedButton(
          onPressed: _saveTitle,
          child: Text('Spara'),
        ),
      ],
    );
  }
}
```

### Pattern: Optimistic List Update

```dart
class IngredientsList extends StatefulWidget {
  final String recipeId;
  final List<Ingredient> initialIngredients;

  @override
  _IngredientsListState createState() => _IngredientsListState();
}

class _IngredientsListState extends State<IngredientsList> {
  late List<Ingredient> _ingredients;
  final Set<String> _pendingAdds = {};
  final Set<String> _pendingDeletes = {};

  @override
  void initState() {
    super.initState();
    _ingredients = List.from(widget.initialIngredients);
  }

  Future<void> _addIngredient(Ingredient ingredient) async {
    // 1. Add to UI immediately (optimistic)
    setState(() {
      _ingredients.add(ingredient);
      _pendingAdds.add(ingredient.id!);
    });

    try {
      // 2. Send to server
      final service = ServiceLocator.get<RealtimeRecipeService>();
      await service.addIngredient(widget.recipeId, ingredient);

      // 3. Success - remove from pending
      setState(() {
        _pendingAdds.remove(ingredient.id!);
      });
    } catch (e) {
      // 4. Error - remove from UI
      setState(() {
        _ingredients.removeWhere((i) => i.id == ingredient.id);
        _pendingAdds.remove(ingredient.id!);
      });
      showError('Kunde inte lägga till ingrediens');
    }
  }

  Future<void> _removeIngredient(String ingredientId) async {
    // Save for rollback
    final ingredient = _ingredients.firstWhere((i) => i.id == ingredientId);
    final index = _ingredients.indexOf(ingredient);

    // 1. Remove from UI immediately (optimistic)
    setState(() {
      _ingredients.removeAt(index);
      _pendingDeletes.add(ingredientId);
    });

    try {
      // 2. Send to server
      final service = ServiceLocator.get<RealtimeRecipeService>();
      await service.removeIngredient(widget.recipeId, ingredientId);

      // 3. Success - remove from pending
      setState(() {
        _pendingDeletes.remove(ingredientId);
      });
    } catch (e) {
      // 4. Error - restore to UI
      setState(() {
        _ingredients.insert(index, ingredient);
        _pendingDeletes.remove(ingredientId);
      });
      showError('Kunde inte ta bort ingrediens');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _ingredients.length,
      itemBuilder: (context, index) {
        final ingredient = _ingredients[index];
        final isPending = _pendingAdds.contains(ingredient.id) ||
                          _pendingDeletes.contains(ingredient.id);

        return ListTile(
          title: Text(ingredient.name),
          subtitle: Text('${ingredient.amount} ${ingredient.unit}'),
          trailing: IconButton(
            icon: Icon(Icons.delete),
            onPressed: isPending
                ? null  // Disable while pending
                : () => _removeIngredient(ingredient.id!),
          ),
          // Visual indicator for pending operations
          leading: isPending
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.drag_handle),
        );
      },
    );
  }
}
```

---

## Collaborative Editing Notifications

### Edit Notification Snackbar

```dart
class RecipeEditNotifier extends StatefulWidget {
  final String recipeId;
  final Widget child;

  @override
  _RecipeEditNotifierState createState() => _RecipeEditNotifierState();
}

class _RecipeEditNotifierState extends State<RecipeEditNotifier> {
  int? _lastKnownEditCount;

  @override
  Widget build(BuildContext context) {
    final service = ServiceLocator.get<RealtimeRecipeService>();

    return StreamBuilder<RealtimeRecipe>(
      stream: service.watchRealtimeRecipe(widget.recipeId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return widget.child;

        final recipe = snapshot.data!;

        // Detect edit by another user
        if (_lastKnownEditCount != null &&
            recipe.editCount > _lastKnownEditCount! &&
            recipe.lastEditedBy != _currentUserId) {
          // Show notification
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(
                        _getUserAvatar(recipe.lastEditedBy!),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${recipe.lastEditedByDisplayName} uppdaterade receptet',
                      ),
                    ),
                  ],
                ),
                duration: Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'Visa',
                  onPressed: () {
                    // Scroll to changed section or show diff
                  },
                ),
              ),
            );
          });
        }

        _lastKnownEditCount = recipe.editCount;

        return widget.child;
      },
    );
  }
}
```

### Typing Indicator (for chat/comments)

```dart
class CommentTypingIndicator extends StatelessWidget {
  final String recipeId;

  @override
  Widget build(BuildContext context) {
    final presenceService = ServiceLocator.get<PresenceService>();

    return StreamBuilder<List<UserPresence>>(
      stream: presenceService.getTypingUsersStream(recipeId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SizedBox.shrink();
        }

        final typingUsers = snapshot.data!;
        final names = typingUsers
            .map((p) => _getUserDisplayName(p.userId))
            .take(3)
            .join(', ');

        return Padding(
          padding: EdgeInsets.all(8),
          child: Row(
            children: [
              TypingDotsAnimation(),
              SizedBox(width: 8),
              Text(
                typingUsers.length > 3
                    ? '$names och ${typingUsers.length - 3} andra skriver...'
                    : '$names skriver...',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TypingDotsAnimation extends StatefulWidget {
  @override
  _TypingDotsAnimationState createState() => _TypingDotsAnimationState();
}

class _TypingDotsAnimationState extends State<TypingDotsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            SizedBox(width: 4),
            _buildDot(1),
            SizedBox(width: 4),
            _buildDot(2),
          ],
        );
      },
    );
  }

  Widget _buildDot(int index) {
    final delay = index * 0.3;
    final value = (_controller.value + delay) % 1.0;
    final opacity = value < 0.5 ? 1.0 : 0.3;

    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}
```

---

## Next Steps

Continue with:
- **[Part 3: Conflicts](./ui-integration-part3-conflicts.md)** - Conflict resolution UI, performance optimization, and best practices

---

**Patterns**: Optimistic updates, rollback on error, collaborative notifications
**Status**: ✅ Production-ready
