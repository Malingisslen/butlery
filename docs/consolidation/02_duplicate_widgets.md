# Duplicate Widgets Analysis

> Generated: 2025-12-27
> Scope: lib/widgets/ (227 files)

---

## Near-Duplicate Widget Pairs

### HIGH PRIORITY - Clear Consolidation Candidates

| Widget A | Widget B | Similarity % | What's Different | Recommendation |
|----------|----------|--------------|------------------|----------------|
| `indicators/admin_badge.dart` | `indicators/status_badge.dart` | 75% | Admin is status variant with icon | ✅ Create `BadgeBase` |
| `indicators/notification_badge.dart` | `indicators/member_count_badge.dart` | 70% | Different count display | ✅ Merge to `CountBadge` |
| `indicators/circular_icon_badge.dart` | `indicators/status_badge.dart` | 65% | Icon vs status display | ✅ Unify badge framework |
| `indicators/realtime_indicators.dart` | `indicators/realtime_status_widgets.dart` | 80% | Overlapping realtime UI | ✅ Merge files |
| `recipe/comment_item_widget.dart` | `recipe/comment_item_widgets.dart` | 85% | Naming suggests duplicate | ✅ Consolidate |
| `recipe/draft_recovery_dialog.dart` | `common/dialogs/draft_recovery_dialog.dart` | 90% | Location duplicate | ✅ Remove duplicate |

### MEDIUM PRIORITY - Partial Overlap

| Widget A | Widget B | Similarity % | What's Different | Recommendation |
|----------|----------|--------------|------------------|----------------|
| `common/dialogs/menu_selection_dialog.dart` | `common/dialogs/recipe_selection_dialogs.dart` | 60% | Content type only | ⚠️ Consider unified selection |
| `common/dialogs/shopping_list_selection_dialog.dart` | `common/dialogs/group_shopping_list_selection_dialog.dart` | 65% | Group vs personal | ⚠️ Parameterize |
| `common/input/portion_scaler.dart` | `common/input/portion_scaler_logic.dart` + `portion_scaler_ui.dart` | 100% | Split unnecessarily | ⚠️ Reconsider split |
| `common/friends/category_widgets.dart` | `common/friends/friend_category_widgets.dart` | 70% | Naming overlap | ⚠️ Clarify or merge |
| `social/groups/create_group_dialog.dart` | `social/groups/edit_group_dialog.dart` | 55% | Create vs edit mode | ⚠️ Use mode parameter |
| `social/groups/delete_group_dialog.dart` | `social/groups/empty_group_delete_dialog.dart` | 60% | Empty state variant | ⚠️ Merge with condition |

### LOW PRIORITY - Similar Purpose, Different Implementation

| Widget A | Widget B | Similarity % | What's Different | Recommendation |
|----------|----------|--------------|------------------|----------------|
| `messaging/fullscreen_image_viewer.dart` | `recipe_detail/fullscreen_image_viewer.dart` | 50% | Context-specific | ❌ Keep separate |
| `common/content_cards/recipe_card.dart` | `recipe/recipe_card.dart` | 45% | Different use cases | ❌ Keep separate |
| `common/input/shopping_list_card.dart` | `common/content_cards/shopping_list_card.dart` | 40% | Input vs display | ❌ Keep separate |

---

## Badge Widget Analysis

### Current State
5 separate badge implementations with no shared base:

```
lib/widgets/common/indicators/
├── admin_badge.dart          # Admin status with shield icon
├── circular_icon_badge.dart  # Icon with circular background
├── member_count_badge.dart   # Numeric count display
├── notification_badge.dart   # Notification dot/count
└── status_badge.dart         # Generic status indicator
```

### Shared Characteristics
All badges share:
- Circular/rounded container
- Background color (theme-based)
- Size variants (small, medium, large)
- Optional icon or text content
- Positioning logic (top-right, etc.)

### Proposed Unified Structure
```dart
// badge_base.dart
abstract class BadgeBase extends StatelessWidget {
  final BadgeSize size;
  final Color? backgroundColor;
  final BadgePosition position;
}

enum BadgeSize { small, medium, large }
enum BadgePosition { topRight, topLeft, bottomRight, bottomLeft }

// Specialized badges extend BadgeBase
class CountBadge extends BadgeBase { }      // For counts (notification, member)
class StatusBadge extends BadgeBase { }     // For status indicators
class IconBadge extends BadgeBase { }       // For icon badges (admin, etc.)
```

### Estimated Impact
- **Files reduced**: 5 → 3
- **Lines saved**: ~100-150
- **Maintenance**: Unified styling, easier theming

---

## Realtime Indicator Analysis

### Current State
Two files with overlapping purpose:

```
lib/widgets/common/indicators/
├── realtime_indicators.dart      # Realtime connection indicators
└── realtime_status_widgets.dart  # Realtime status display widgets
```

### Overlap Analysis
Both files contain:
- Connection status display
- Sync state indicators
- Participant presence UI
- Live update animations

### Recommendation
**Merge into single file**: `realtime_indicators.dart`

Organize by:
1. Connection indicators (online/offline/syncing)
2. Participant indicators (who's active)
3. Update indicators (live changes)

### Estimated Impact
- **Files reduced**: 2 → 1
- **Lines saved**: ~50-80
- **Clarity**: Single source for realtime UI

---

## Comment Widget Analysis

### Current State
Confusing naming in recipe widgets:

```
lib/widgets/recipe/
├── comment_item_widget.dart   # Primary comment display
└── comment_item_widgets.dart  # Plural naming - helper widgets?
```

### Investigation Required
Need to verify:
- Are these truly duplicates?
- Is `comment_item_widgets.dart` a collection of helpers?
- What exports do they provide?

### Recommendation
If duplicate: **Merge and rename clearly**
If helpers: **Rename to `comment_item_helpers.dart`**

---

## Dialog Widget Analysis

### Group Dialogs (Consolidation Opportunity)

```
lib/widgets/social/groups/
├── create_group_dialog.dart        # Create new group
├── delete_group_dialog.dart        # Delete group
├── edit_group_dialog.dart          # Edit group
├── empty_group_delete_dialog.dart  # Delete empty group
├── group_dialogs.dart              # Dialog utilities
├── ownership_transfer_dialog.dart  # Transfer ownership
└── remove_member_dialog.dart       # Remove member
```

### Pattern Analysis
- `create_group_dialog.dart` and `edit_group_dialog.dart` share ~55% code
- `delete_group_dialog.dart` and `empty_group_delete_dialog.dart` share ~60% code
- All should use `BaseDialog` pattern

### Proposed Structure
```dart
// group_form_dialog.dart - Handles create AND edit
class GroupFormDialog extends BaseDialog<Group?> {
  final GroupFormMode mode; // create or edit
  final Group? existingGroup; // null for create
}

// group_delete_dialog.dart - Handles all delete cases
class GroupDeleteDialog extends BaseDialog<bool> {
  final Group group;
  final bool isEmpty;
  final bool requiresTransfer;
}
```

### Estimated Impact
- **Files reduced**: 7 → 4
- **Lines saved**: ~200-300
- **Consistency**: All use BaseDialog

---

## Selection Dialog Analysis

### Current State
Multiple selection dialogs with similar patterns:

```
lib/widgets/common/dialogs/
├── menu_selection_dialog.dart              # Select menu
├── shopping_list_selection_dialog.dart     # Select shopping list
├── group_shopping_list_selection_dialog.dart # Select group list
└── recipe_selection/
    ├── friend_recipe_sharing_dialog.dart   # Share with friend
    ├── group_recipe_sharing_dialog.dart    # Share with group
    └── menu_recipe_selection_dialog.dart   # Add to menu
```

### Shared Patterns
All selection dialogs have:
- Search/filter functionality
- List display with selection
- Confirm/cancel actions
- Loading states
- Empty states

### Recommendation
Consider `BaseSelectionDialog<T>` pattern:

```dart
abstract class BaseSelectionDialog<T> extends BaseDialog<T?> {
  Widget buildSearchBar();
  Widget buildListItem(T item, bool isSelected);
  Future<List<T>> loadItems();
  String get emptyMessage;
}
```

### Estimated Impact
- **Code reuse**: 60-70% shared logic extracted
- **Consistency**: Unified selection UX
- **Testability**: Single base to test

---

## Portion Scaler Analysis

### Current State
Split into 3 files unnecessarily:

```
lib/widgets/common/input/
├── portion_scaler.dart       # Main widget
├── portion_scaler_logic.dart # Business logic
└── portion_scaler_ui.dart    # UI components
```

### Analysis
- Total complexity: ~200-250 lines combined
- Split seems premature - not at 500-line threshold
- Logic separation could be internal to main widget

### Recommendation
**Consider consolidating** unless there's specific reuse of logic elsewhere.

If logic is reused: Keep split but document why
If not reused: Merge back to single file

---

## Summary Statistics

| Category | Pairs Found | High Priority | Medium | Low |
|----------|-------------|---------------|--------|-----|
| Badge Widgets | 5 files | 5 | 0 | 0 |
| Realtime Indicators | 2 files | 2 | 0 | 0 |
| Comment Widgets | 2 files | 2 | 0 | 0 |
| Group Dialogs | 7 files | 0 | 4 | 0 |
| Selection Dialogs | 6 files | 0 | 3 | 0 |
| Portion Scaler | 3 files | 0 | 3 | 0 |
| Image Viewers | 2 files | 0 | 0 | 2 |
| Recipe Cards | 2 files | 0 | 0 | 2 |
| **TOTAL** | 29 files | 9 | 10 | 4 |

### Consolidation Potential
- **High Priority**: 9 files → ~4 files (save ~5 files)
- **Medium Priority**: 10 files → ~6 files (save ~4 files)
- **Total Potential**: Save ~9 files, ~500-700 lines
