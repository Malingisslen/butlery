# UI Patterns Analysis

> Generated: 2025-12-27
> Scope: Repeated UI structures in lib/views/ and lib/widgets/

---

## Repeated UI Structures

### Import View UI Pattern

| Pattern | Files Using It | Could Be Shared Component? | Notes |
|---------|----------------|---------------------------|-------|
| Import progress indicator | 6 import views | ✅ Yes - `ImportProgressWidget` exists | Verify adoption |
| Source selection UI | 5 import views | ✅ Yes | Camera/file/URL/text selector |
| Parsed recipe preview | 6 import views | ✅ Yes | Pre-import recipe display |
| Import error display | 6 import views | ✅ Yes | Error with retry option |
| Import success actions | 6 import views | ✅ Yes | Save/edit/cancel buttons |

**Current State**: Each import view implements these patterns independently.

**Proposed**: `BaseImportView` widget with slots for source-specific UI.

---

### Selection Dialog Pattern

| Pattern | Files Using It | Could Be Shared Component? | Notes |
|---------|----------------|---------------------------|-------|
| Searchable list | 6+ dialogs | ✅ Yes | Search bar + filtered list |
| Multi-select with chips | 4 dialogs | ✅ Yes | Selected items as chips |
| Loading/empty states | All dialogs | ✅ Already shared | Uses state components |
| Confirm/cancel footer | All dialogs | ✅ Yes - in BaseDialog | Verify adoption |

**Current State**: Selection dialogs share ~60-70% structure.

**Proposed**: `BaseSelectionDialog<T>` with customizable list item rendering.

---

### Content Card Pattern

| Pattern | Files Using It | Could Be Shared Component? | Notes |
|---------|----------------|---------------------------|-------|
| Card with image header | Recipe, Menu, Shopping cards | ✅ Already shared | `ContentCard` facade |
| Action button row | All content cards | ✅ Already shared | Part of card design |
| Metadata footer | Recipe, Menu cards | ✅ Already shared | Timestamps, author |
| Share indicator | Shared content cards | ✅ Already shared | Share status badge |

**Status**: ✅ WELL CONSOLIDATED - `ContentCard` facade handles this properly.

---

### List View Pattern

| Pattern | Files Using It | Could Be Shared Component? | Notes |
|---------|----------------|---------------------------|-------|
| Pull-to-refresh | 8+ list views | ✅ Could be standardized | RefreshIndicator wrapper |
| Infinite scroll | 5+ list views | ⚠️ Partial | Some use, some don't |
| Empty state | All list views | ✅ Already shared | `EmptyStateBuilder` |
| Loading skeleton | All list views | ✅ Already shared | `SkeletonComponents` |
| Error with retry | All list views | ✅ Already shared | Error state widgets |

**Status**: Mostly consolidated, but infinite scroll implementation varies.

---

### Form Scaffold Pattern

| Pattern | Files Using It | Could Be Shared Component? | Notes |
|---------|----------------|---------------------------|-------|
| Form with app bar | Recipe edit, Profile edit, Group create | ✅ Yes - `FormScaffold` | Verify adoption |
| Validation display | All forms | ✅ Already shared | `ValidationUtils` |
| Save/cancel buttons | All forms | ⚠️ Partially shared | Some custom implementations |
| Unsaved changes dialog | Recipe edit, Menu edit | ✅ Could share | Draft recovery pattern |

**Status**: `FormScaffold` exists but may be underutilized.

---

### Social Interaction Pattern

| Pattern | Files Using It | Could Be Shared Component? | Notes |
|---------|----------------|---------------------------|-------|
| Like/reaction button | Recipe detail, Comments | ✅ Already shared | `SocialFacade` |
| Comment section | Recipe detail, Shared content | ✅ Already shared | Comment widgets |
| Share action sheet | Multiple views | ✅ Already shared | `UniversalShareDialog` |
| User avatar + name | Throughout app | ✅ Already shared | `UserAvatarWidgets` |

**Status**: ✅ WELL CONSOLIDATED - Social patterns are well-factored.

---

### Realtime Collaboration Pattern

| Pattern | Files Using It | Could Be Shared Component? | Notes |
|---------|----------------|---------------------------|-------|
| Connection indicator | Recipe edit, Menu edit, Shopping | ✅ Could consolidate | `realtime_indicators.dart` |
| Participant list | Collaborative views | ✅ Partially shared | `ParticipantListWidget` |
| Conflict resolution UI | Recipe, Menu editing | ⚠️ Could share | Currently separate |
| Sync status | All collaborative views | ✅ Could consolidate | Multiple implementations |

**Status**: Realtime UI is scattered - consolidation opportunity.

---

### Navigation Pattern

| Pattern | Files Using It | Could Be Shared Component? | Notes |
|---------|----------------|---------------------------|-------|
| Bottom navigation | Main app shell | ✅ Already shared | `AdaptiveNavigation` |
| Tab bar | Multiple views | ✅ Already shared | `TabbedScaffold` |
| Drawer menu | Settings, Profile | ✅ Already shared | `ProfileMenu` |
| Back navigation | All detail views | ✅ Standard Flutter | AppBar back button |

**Status**: ✅ WELL CONSOLIDATED

---

### Settings/Preferences Pattern

| Pattern | Files Using It | Could Be Shared Component? | Notes |
|---------|----------------|---------------------------|-------|
| Settings group | Multiple settings views | ⚠️ Partially shared | Some custom |
| Toggle row | Notification, Privacy settings | ✅ Could share | `AdaptiveSwitch` exists |
| Action row | Account settings | ⚠️ Partially shared | Some custom |
| Info row | Profile, Account | ⚠️ Partially shared | Some custom |

**Status**: Settings UI could be more standardized.

---

## Existing Shared UI Patterns (POSITIVE EXAMPLES)

### Scaffold System ✅
```
lib/widgets/common/scaffolds/
├── base_scaffold.dart           # Base template
├── loading_scaffold.dart        # Loading state
├── error_scaffold.dart          # Error state
├── empty_state_scaffold.dart    # Empty state
├── form_scaffold.dart           # Form layout
├── list_scaffold.dart           # List layout
├── tabbed_scaffold.dart         # Tabbed layout
└── responsive_scaffold_builder.dart
```
**Adoption**: Good - most views use these.

### State Components ✅
```
lib/widgets/common/state/
├── empty_states.dart            # EmptyStateVariant enum
├── loading_states.dart          # LoadingVariant enum
├── message_states.dart          # Message displays
├── skeleton_components.dart     # Skeleton loaders
└── state_enums.dart             # Central enums
```
**Adoption**: Excellent - variant pattern is well-used.

### Social Facade ✅
```
lib/widgets/common/social/
├── social_facade.dart           # Master API (515 lines)
└── api/
    ├── social_avatar_api.dart
    ├── social_group_api.dart
    ├── social_invitation_api.dart
    └── social_helpers.dart
```
**Adoption**: Excellent - clean delegation pattern.

### Content Card Facade ✅
```
lib/widgets/common/content_card.dart (470 lines)
lib/widgets/common/content_cards/
├── recipe_card.dart
├── menu_card.dart
├── shopping_list_card.dart
├── friend_card.dart
├── image_preview_card.dart
└── text_display_card.dart
```
**Adoption**: Excellent - type-based delegation.

---

## UI Patterns Needing Consolidation

### 1. Import Views (HIGH PRIORITY)

**Current**: 6 separate views with ~70% identical structure

```
lib/views/
├── smart_import_view.dart
├── photo_import_view.dart
├── file_import_view.dart
├── import_via_url_view.dart
├── importera_fran_arkiv_view.dart
└── receive_share_view.dart
```

**Proposed Pattern**:
```dart
// base_import_view.dart
abstract class BaseImportView extends StatelessWidget {
  // Shared structure
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),
      body: Column(
        children: [
          buildSourceSelector(context),      // Override per source
          Expanded(child: buildPreview(context)),
          buildProgressIndicator(context),
          buildActionButtons(context),
        ],
      ),
    );
  }

  // Override points
  Widget buildSourceSelector(BuildContext context);
  Widget buildPreview(BuildContext context);
}
```

**Estimated Impact**:
- Lines reduced: ~400-500
- Consistency: Unified import UX

---

### 2. Group Dialogs (MEDIUM PRIORITY)

**Current**: 7 separate dialog files

```
lib/widgets/social/groups/
├── create_group_dialog.dart
├── edit_group_dialog.dart
├── delete_group_dialog.dart
├── empty_group_delete_dialog.dart
├── ownership_transfer_dialog.dart
├── remove_member_dialog.dart
└── group_dialogs.dart
```

**Proposed Pattern**:
```dart
// group_form_dialog.dart (create + edit combined)
class GroupFormDialog extends BaseDialog<Group?> {
  final GroupFormMode mode; // create, edit

  // Shared form fields, mode-specific behavior
}

// group_action_dialogs.dart (delete + transfer + remove combined)
class GroupActionDialog extends BaseDialog<bool> {
  final GroupAction action; // delete, transfer, remove

  // Shared confirmation pattern, action-specific message
}
```

**Estimated Impact**:
- Files: 7 → 3
- Lines reduced: ~200-300

---

### 3. Selection Dialogs (MEDIUM PRIORITY)

**Current**: 6+ selection dialogs with similar structure

```
lib/widgets/common/dialogs/
├── menu_selection_dialog.dart
├── shopping_list_selection_dialog.dart
├── group_shopping_list_selection_dialog.dart
└── recipe_selection/
    ├── friend_recipe_sharing_dialog.dart
    ├── group_recipe_sharing_dialog.dart
    └── menu_recipe_selection_dialog.dart
```

**Proposed Pattern**:
```dart
// base_selection_dialog.dart
abstract class BaseSelectionDialog<T> extends BaseDialog<T?> {
  // Shared structure
  Widget buildSearchBar();
  Widget buildList(List<T> items, T? selected);
  Widget buildItem(T item, bool isSelected);

  // Override points
  Future<List<T>> loadItems();
  String getItemTitle(T item);
  String get emptyMessage;
}

// Concrete implementations just override item-specific behavior
class RecipeSelectionDialog extends BaseSelectionDialog<Recipe> { }
class MenuSelectionDialog extends BaseSelectionDialog<Menu> { }
class ShoppingListSelectionDialog extends BaseSelectionDialog<ShoppingList> { }
```

**Estimated Impact**:
- Shared code: ~60-70%
- Consistency: Unified selection UX

---

### 4. Realtime Collaboration UI (MEDIUM PRIORITY)

**Current**: Scattered across multiple files

```
lib/widgets/common/indicators/
├── realtime_indicators.dart
└── realtime_status_widgets.dart

lib/widgets/social/collaborative/
└── components/
    ├── collaborative_participants_widgets.dart
    └── collaborative_status_widgets.dart
```

**Proposed Pattern**:
```dart
// realtime_ui/realtime_facade.dart
class RealtimeUIFacade {
  static Widget connectionIndicator({required ConnectionState state});
  static Widget participantList({required List<Participant> participants});
  static Widget syncStatus({required SyncState state});
  static Widget conflictBanner({required Conflict conflict, required VoidCallback onResolve});
}
```

**Estimated Impact**:
- Single source for realtime UI
- Consistent indicators across app

---

### 5. Settings Row Pattern (LOW PRIORITY)

**Current**: Custom implementations across settings views

**Proposed Pattern**:
```dart
// settings_row.dart
class SettingsRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget trailing;
  final VoidCallback? onTap;
}

class SettingsToggleRow extends SettingsRow {
  final bool value;
  final ValueChanged<bool> onChanged;
}

class SettingsActionRow extends SettingsRow {
  final String actionLabel;
  final VoidCallback onAction;
}
```

**Estimated Impact**:
- Consistent settings appearance
- Easier to add new settings

---

## Summary Table

| Pattern | Status | Files Affected | Action |
|---------|--------|----------------|--------|
| Import Views | ❌ Not consolidated | 6 views | Create BaseImportView |
| Group Dialogs | ⚠️ Partially | 7 dialogs | Merge to 3 dialogs |
| Selection Dialogs | ⚠️ Partially | 6+ dialogs | Create BaseSelectionDialog |
| Realtime UI | ⚠️ Scattered | 4+ files | Create RealtimeUIFacade |
| Settings Rows | ⚠️ Partially | Multiple | Standardize pattern |
| Content Cards | ✅ Consolidated | - | No action needed |
| Social Components | ✅ Consolidated | - | No action needed |
| State Components | ✅ Consolidated | - | No action needed |
| Scaffolds | ✅ Consolidated | - | No action needed |
| Navigation | ✅ Consolidated | - | No action needed |

### Consolidation Priority
1. **Import Views** - Highest user-facing impact
2. **Group Dialogs** - Clear consolidation path
3. **Selection Dialogs** - Common pattern opportunity
4. **Realtime UI** - Consistency improvement
5. **Settings Rows** - Lower priority refinement
