# UI Integration

Comprehensive guide to integrating real-time collaboration into Flutter UI.

**Note**: This guide has been split into 3 focused parts for better readability (<400 lines each):

---

## Guide Structure

### [Part 1: StreamBuilder & Indicators](./ui-integration-part1-streambuilder.md) (~300 lines)

**Topics**:
- StreamBuilder pattern (basic, with overlay, multiple streams)
- Real-time indicators (last editor, activity badge, participant avatars)
- Edit count badges
- Online status visualization

**When to use**: Setting up real-time data streams and activity indicators

---

### [Part 2: Optimistic Updates & Notifications](./ui-integration-part2-updates.md) (~370 lines)

**Topics**:
- Optimistic update patterns with rollback
- Optimistic list updates (add/remove with pending states)
- Edit notification snackbars
- Typing indicators with animations
- Collaborative editing notifications

**When to use**: Implementing immediate UI feedback and user activity notifications

---

### [Part 3: Conflict Resolution & Best Practices](./ui-integration-part3-conflicts.md) (~285 lines)

**Topics**:
- Conflict resolution dialogs
- Version comparison UI
- Performance optimization (debouncing, pagination)
- Best practices checklist
- Edge case handling

**When to use**: Handling conflicts and optimizing performance

---

## Quick Reference

### StreamBuilder Pattern
```dart
StreamBuilder<RealtimeRecipe>(
  stream: service.watchRealtimeRecipe(recipeId),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return LoadingWidget();
    return RecipeContent(recipe: snapshot.data!);
  },
)
```

### Optimistic Update
```dart
// 1. Update UI immediately
setState(() => _items.add(newItem));

// 2. Send to server
await service.addItem(newItem);

// 3. On error: rollback
catch (e) { setState(() => _items.remove(newItem)); }
```

### Real-Time Indicator
```dart
ActivityBadge(
  isActive: recipe.hasRecentActivity,
  lastEditor: recipe.lastEditedByDisplayName,
)
```

---

## Navigation

**Choose your topic**:
- Need to set up real-time streams? → [Part 1](./ui-integration-part1-streambuilder.md)
- Need to implement optimistic updates? → [Part 2](./ui-integration-part2-updates.md)
- Need to handle conflicts or optimize? → [Part 3](./ui-integration-part3-conflicts.md)

**See all parts**:
- [Part 1: StreamBuilder & Indicators](./ui-integration-part1-streambuilder.md)
- [Part 2: Optimistic Updates & Notifications](./ui-integration-part2-updates.md)
- [Part 3: Conflict Resolution & Best Practices](./ui-integration-part3-conflicts.md)

---

**Total**: ~955 lines split into 3 manageable parts
**Status**: ✅ Production-ready patterns
**Last Updated**: 2025-01-31
