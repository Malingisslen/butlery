# Consolidation Proposals

> Generated: 2025-12-27
> Format: Detailed proposals for each consolidation opportunity

---

## Proposal 1: Import System Consolidation

**Priority**: ✅ HIGH - Highest Impact

### Files Involved
**ViewModels (7 files)**:
- `lib/viewmodels/photo_import_viewmodel.dart`
- `lib/viewmodels/archive_import_viewmodel.dart`
- `lib/viewmodels/url_import_viewmodel.dart`
- `lib/viewmodels/text_import_viewmodel.dart`
- `lib/viewmodels/smart_import_viewmodel.dart`
- `lib/viewmodels/assisted_import_viewmodel.dart`
- `lib/viewmodels/import_base_viewmodel.dart`

**Views (6 files)**:
- `lib/views/photo_import_view.dart`
- `lib/views/file_import_view.dart`
- `lib/views/import_via_url_view.dart`
- `lib/views/importera_fran_arkiv_view.dart`
- `lib/views/smart_import_view.dart`
- `lib/views/receive_share_view.dart`

### Current State
- 7 separate ViewModels sharing ~70% identical code
- 6 separate Views with ~60% identical UI structure
- Each import source has its own complete implementation
- Common patterns: loading state, progress tracking, parsed recipe preview, error handling, finalization

### Proposed Solution

**Phase 1: ViewModel Consolidation**
```dart
// lib/viewmodels/import/import_content_viewmodel.dart
class ImportContentViewModel extends ImportBaseViewModel {
  final ImportStrategy _strategy;

  // Factory constructors for each source
  factory ImportContentViewModel.photo() =>
      ImportContentViewModel(PhotoImportStrategy());
  factory ImportContentViewModel.url() =>
      ImportContentViewModel(UrlImportStrategy());
  factory ImportContentViewModel.archive() =>
      ImportContentViewModel(ArchiveImportStrategy());
  factory ImportContentViewModel.text() =>
      ImportContentViewModel(TextImportStrategy());

  // Shared implementation
  Future<void> startImport() => _strategy.execute(this);
}

// lib/viewmodels/import/strategies/
abstract class ImportStrategy {
  Future<void> execute(ImportContentViewModel vm);
  Widget buildSourceSelector(BuildContext context);
}
```

**Phase 2: View Consolidation**
```dart
// lib/views/import/base_import_view.dart
abstract class BaseImportView<T extends ImportContentViewModel> extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<T>(
      create: (_) => createViewModel(),
      child: Consumer<T>(
        builder: (context, vm, _) => Scaffold(
          appBar: buildAppBar(context, vm),
          body: Column(
            children: [
              buildSourceSelector(context, vm),  // Override per source
              Expanded(child: buildPreview(context, vm)),
              ImportProgressWidget(progress: vm.progress),
              ImportActionButtons(vm: vm),
            ],
          ),
        ),
      ),
    );
  }

  T createViewModel();
  Widget buildSourceSelector(BuildContext context, T vm);
}
```

### Benefits
- **Lines reduced**: ~600-800 across ViewModels, ~400-500 across Views
- **Maintenance**: Single codebase for import flow
- **Testing**: Test base once, test strategies individually
- **Consistency**: Unified import UX across all sources

### Risks
- **Breaking changes**: Existing import functionality must be preserved
- **Edge cases**: Each import source has unique error conditions
- **Migration effort**: Significant refactoring required

### Recommendation: ✅ DO IT

### Reasoning
This is the highest-impact consolidation opportunity. The import system is a core user flow with significant code duplication. The strategy pattern is a natural fit for the varying input sources while sharing common infrastructure.

---

## Proposal 2: Badge Widget Unification

**Priority**: ✅ HIGH - Quick Win

### Files Involved
- `lib/widgets/common/indicators/admin_badge.dart`
- `lib/widgets/common/indicators/status_badge.dart`
- `lib/widgets/common/indicators/notification_badge.dart`
- `lib/widgets/common/indicators/member_count_badge.dart`
- `lib/widgets/common/indicators/circular_icon_badge.dart`

### Current State
- 5 separate badge implementations
- No shared base class
- Similar styling, sizing, positioning logic
- Each reimplements container, colors, sizing

### Proposed Solution
```dart
// lib/widgets/common/indicators/badge_base.dart
abstract class BadgeBase extends StatelessWidget {
  final BadgeSize size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final BadgePosition position;

  const BadgeBase({
    this.size = BadgeSize.medium,
    this.backgroundColor,
    this.foregroundColor,
    this.position = BadgePosition.topRight,
  });

  @protected
  Widget buildContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? _defaultBackground(context),
        shape: BoxShape.circle,
      ),
      constraints: _sizeConstraints,
      child: Center(child: buildContent(context)),
    );
  }
}

// Specialized badges
class CountBadge extends BadgeBase { }      // notification, member count
class IconBadge extends BadgeBase { }       // admin, status with icon
class StatusBadge extends BadgeBase { }     // generic status
```

### Benefits
- **Files reduced**: 5 → 3 files
- **Lines saved**: ~100-150 lines
- **Consistency**: Unified badge styling and theming
- **Extensibility**: Easy to add new badge types

### Risks
- **Low risk**: Purely additive change, existing badges can gradually migrate

### Recommendation: ✅ DO IT

### Reasoning
Quick win with minimal risk. Creates a foundation for consistent badge UI. Can be done incrementally without breaking existing code.

---

## Proposal 3: Realtime Indicators Merge

**Priority**: ✅ HIGH - Quick Win

### Files Involved
- `lib/widgets/common/indicators/realtime_indicators.dart`
- `lib/widgets/common/indicators/realtime_status_widgets.dart`

### Current State
- Two files with overlapping purpose
- Both contain connection status and sync indicators
- Unclear which to use for new features

### Proposed Solution
Merge into single file: `realtime_indicators.dart`

Organize by component type:
```dart
// lib/widgets/common/indicators/realtime_indicators.dart

// Connection indicators
class ConnectionStatusIndicator extends StatelessWidget { }
class OnlineIndicator extends StatelessWidget { }
class OfflineIndicator extends StatelessWidget { }

// Sync indicators
class SyncStatusIndicator extends StatelessWidget { }
class SyncingIndicator extends StatelessWidget { }
class SyncedIndicator extends StatelessWidget { }

// Participant indicators
class ActiveParticipantsIndicator extends StatelessWidget { }
class PresenceIndicator extends StatelessWidget { }
```

### Benefits
- **Files reduced**: 2 → 1
- **Lines saved**: ~50-80 (deduplication)
- **Clarity**: Single source for realtime UI

### Risks
- **Low risk**: File merge, no API changes

### Recommendation: ✅ DO IT

### Reasoning
Simple consolidation with clear benefit. Reduces confusion about which file to use.

---

## Proposal 4: Dialog BaseDialog Adoption

**Priority**: ✅ HIGH - Pattern Enforcement

### Files Involved
- `lib/widgets/common/dialogs/menu_selection_dialog.dart`
- `lib/widgets/common/dialogs/shopping_list_selection_dialog.dart`
- `lib/widgets/recipe/draft_recovery_dialog.dart`
- `lib/widgets/social/groups/create_group_dialog.dart`
- `lib/widgets/social/groups/edit_group_dialog.dart`
- `lib/widgets/social/groups/delete_group_dialog.dart`
- `lib/widgets/social/groups/empty_group_delete_dialog.dart`

### Current State
- `BaseDialog` exists (522 lines) with proper structure
- 7+ dialogs don't extend BaseDialog
- Inconsistent dialog appearance and behavior

### Proposed Solution
Migrate each dialog to extend `BaseDialog<T>`:

```dart
// Before
class MenuSelectionDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        children: [
          // Custom header
          // Custom content
          // Custom footer
        ],
      ),
    );
  }
}

// After
class MenuSelectionDialog extends BaseDialog<Menu?> {
  @override
  Widget buildHeader(BuildContext context) => Text('Select Menu');

  @override
  Widget buildContent(BuildContext context) => MenuListWidget();

  @override
  List<Widget> buildActions(BuildContext context) => [
    CancelButton(onPressed: () => close(null)),
    SelectButton(onPressed: () => close(selectedMenu)),
  ];
}
```

### Benefits
- **Consistency**: Unified dialog appearance
- **Code reduction**: Shared header, footer, loading, error handling
- **Accessibility**: BaseDialog handles focus, keyboard navigation

### Risks
- **Moderate risk**: UI changes may be visible to users
- **Testing**: Each dialog needs visual testing after migration

### Recommendation: ✅ DO IT

### Reasoning
Enforces existing pattern. Improves consistency. Can be done dialog-by-dialog.

---

## Proposal 5: Extraction Service Consolidation

**Priority**: ✅ HIGH - Architecture Clarity

### Files Involved
- `lib/services/social_media_extractor.dart` (top-level)
- `lib/services/extraction/extractors/instagram_content_extractor.dart`
- `lib/services/extraction/extractors/recipe_site_content_extractor.dart`
- `lib/services/extraction/extractors/social_platform_content_extractor.dart`
- `lib/services/extraction/platform_detector.dart`

### Current State
- `social_media_extractor.dart` at top level
- `extraction/` subdirectory with similar extractors
- Unclear architecture and entry points

### Proposed Solution
1. Move `social_media_extractor.dart` into `extraction/extractors/`
2. Create unified entry point:

```dart
// lib/services/extraction/extraction_service.dart
class ExtractionService extends BaseService {
  final PlatformDetector _detector;
  final ExtractorRegistry _registry;

  Future<ExtractedContent> extract(String url) async {
    final platform = await _detector.detect(url);
    final extractor = _registry.getExtractor(platform);
    return extractor.extract(url);
  }
}

// lib/services/extraction/extractor_registry.dart
class ExtractorRegistry {
  ContentExtractor getExtractor(Platform platform) {
    switch (platform) {
      case Platform.instagram: return InstagramContentExtractor();
      case Platform.tiktok: return TikTokContentExtractor();
      case Platform.recipeSite: return RecipeSiteContentExtractor();
      // ...
    }
  }
}
```

### Benefits
- **Clarity**: Single entry point for extraction
- **Consistency**: All extractors in same location
- **Extensibility**: Easy to add new platforms via registry

### Risks
- **Import changes**: Files importing old location need updates
- **Testing**: Verify all extraction paths still work

### Recommendation: ✅ DO IT

### Reasoning
Improves architecture clarity. Establishes clear extraction pattern. Relatively low risk.

---

## Proposal 6: Account Operations Consolidation

**Priority**: ⚠️ MEDIUM - Over-modularization Fix

### Files Involved
**Deletion (4 micro-files)**:
- `lib/services/account/account_deletion/content_deletion_operations.dart`
- `lib/services/account/account_deletion/social_deletion_operations.dart`
- `lib/services/account/account_deletion/profile_deletion_operations.dart`
- `lib/services/account/account_deletion/storage_deletion_operations.dart`

**Export (5 micro-files)**:
- `lib/services/account/export/content_export_manager.dart`
- `lib/services/account/export/social_export_manager.dart`
- `lib/services/account/export/activity_export_manager.dart`
- `lib/services/account/export/compliance_export_manager.dart`
- `lib/services/account/export/preferences_export_manager.dart`

### Current State
- 9 files, each 60-100 lines
- Violates "don't over-modularize" principle
- Each file has minimal unique logic

### Proposed Solution
```dart
// Consolidate deletion: 4 → 2 files
// content_and_social_deletion.dart
class ContentAndSocialDeletionOperations {
  Future<void> deleteUserContent(String userId);
  Future<void> deleteSocialConnections(String userId);
}

// profile_and_storage_deletion.dart
class ProfileAndStorageDeletionOperations {
  Future<void> deleteUserProfile(String userId);
  Future<void> deleteUserStorage(String userId);
}

// Consolidate export: 5 → 3 files
// content_and_social_export.dart
// activity_and_preferences_export.dart
// compliance_export.dart (keep separate - regulatory concern)
```

### Benefits
- **Files reduced**: 9 → 5 files
- **Reduced navigation**: Fewer files to open
- **Clearer responsibility**: Logical groupings

### Risks
- **Low risk**: Internal refactoring only
- **Regulatory**: Keep compliance separate for audit purposes

### Recommendation: ⚠️ CONSIDER

### Reasoning
Fixes over-modularization but impact is limited to maintainability. Not user-facing.

---

## Proposal 7: Shared Content ViewModel Simplification

**Priority**: ⚠️ MEDIUM - Needs Investigation

### Files Involved
- `lib/viewmodels/shared_content/base_shared_content_viewmodel.dart`
- `lib/viewmodels/shared_content/shared_recipe_viewmodel.dart`
- `lib/viewmodels/shared_content/shared_menu_viewmodel.dart`
- `lib/viewmodels/shared_content/shared_shopping_viewmodel.dart`
- `lib/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart`
- `lib/viewmodels/shared_content/shared_content_search_viewmodel.dart`

### Current State
- 6 ViewModels in shared content hierarchy
- `shared_content_search_viewmodel.dart` may be redundant
- `shared_menu_viewmodel.dart` and `shared_shopping_viewmodel.dart` may have minimal overrides

### Investigation Required
Before consolidating, verify:
1. How many methods do `shared_menu_viewmodel` and `shared_shopping_viewmodel` override?
2. Is `shared_content_search_viewmodel` used outside coordinator?
3. What unique behavior does each specialized ViewModel provide?

### Proposed Solution (If Investigation Confirms)
```dart
// Option A: Remove redundant search VM
// 6 files → 5 files

// Option B: Parameterize if overrides are minimal
class SharedContentViewModel<T extends BaseSharedContent> {
  // Type-specific behavior via generics
}
```

### Benefits
- **Potential files reduced**: 6 → 4-5 files
- **Clarity**: Clearer ViewModel responsibilities

### Risks
- **Investigation needed**: Don't consolidate without understanding current usage
- **Type safety**: Generics may reduce type safety

### Recommendation: ⚠️ CONSIDER - Investigate First

### Reasoning
Potential simplification but requires investigation. Don't consolidate blindly.

---

## Proposal 8: Group Dialogs Consolidation

**Priority**: ⚠️ MEDIUM - Pattern Simplification

### Files Involved
- `lib/widgets/social/groups/create_group_dialog.dart`
- `lib/widgets/social/groups/edit_group_dialog.dart`
- `lib/widgets/social/groups/delete_group_dialog.dart`
- `lib/widgets/social/groups/empty_group_delete_dialog.dart`
- `lib/widgets/social/groups/ownership_transfer_dialog.dart`
- `lib/widgets/social/groups/remove_member_dialog.dart`
- `lib/widgets/social/groups/group_dialogs.dart`

### Current State
- 7 dialog files in groups/
- Create and edit share ~55% code
- Delete variations share ~60% code

### Proposed Solution
```dart
// group_form_dialog.dart (replaces create + edit)
class GroupFormDialog extends BaseDialog<Group?> {
  final GroupFormMode mode; // create or edit
  final Group? existingGroup;

  GroupFormDialog.create() : mode = GroupFormMode.create, existingGroup = null;
  GroupFormDialog.edit(this.existingGroup) : mode = GroupFormMode.edit;
}

// group_action_dialogs.dart (replaces delete + empty_delete + transfer + remove)
class GroupActionDialog extends BaseDialog<bool> {
  final GroupActionType type;
  final Group group;
  final Member? targetMember;

  // Factory constructors for each action type
}
```

### Benefits
- **Files reduced**: 7 → 3-4 files
- **Lines saved**: ~200-300
- **Consistency**: Unified group dialog patterns

### Risks
- **Complexity**: Mode/type switching adds conditional logic
- **Testing**: More test cases per file

### Recommendation: ⚠️ CONSIDER

### Reasoning
Good consolidation opportunity but adds internal complexity. Evaluate if mode switching is cleaner than separate files.

---

## Proposal 9: Realtime Coordination Unification

**Priority**: ⚠️ MEDIUM - Architecture Clarity

### Files Involved
- `lib/services/realtime_sync_service.dart` (top-level)
- `lib/services/realtime/` (7 modules)
- `lib/services/unified/modules/realtime_recipe_module.dart`
- `lib/services/unified/modules/realtime_menu_module.dart`

### Current State
- Realtime logic scattered across locations
- Potential duplicate module names
- Unclear which module handles what

### Investigation Required
1. Is `realtime_sync_service.dart` still used or superseded by unified modules?
2. Are there actually duplicate `realtime_*_module.dart` files?
3. What's the intended architecture for realtime?

### Proposed Solution (After Investigation)
```dart
// All realtime under unified/
lib/services/unified/
├── modules/
│   └── realtime/
│       ├── realtime_recipe_module.dart
│       ├── realtime_menu_module.dart
│       ├── conflict_resolution_module.dart
│       └── connection_state_module.dart

// Remove or deprecate top-level realtime_sync_service.dart
```

### Recommendation: ⚠️ CONSIDER - Investigate First

### Reasoning
Needs investigation to understand current architecture before proposing changes.

---

## Proposal 10: Portion Scaler Consolidation

**Priority**: ❌ LEAVE AS-IS (unless reuse confirmed)

### Files Involved
- `lib/widgets/common/input/portion_scaler.dart`
- `lib/widgets/common/input/portion_scaler_logic.dart`
- `lib/widgets/common/input/portion_scaler_ui.dart`

### Current State
- 3 files totaling ~200-250 lines
- Split appears premature (not at 500-line threshold)

### Investigation Required
1. Is `portion_scaler_logic.dart` reused elsewhere?
2. Is `portion_scaler_ui.dart` reused elsewhere?

### Proposed Solution (If No Reuse)
Merge back to single `portion_scaler.dart`

### Recommendation: ❌ LEAVE AS-IS

### Reasoning
If there's reuse, the split is justified. If not, it's a minor issue. Low priority.

---

## Proposal 11: Comment Widget Clarification

**Priority**: ✅ HIGH - Naming Fix

### Files Involved
- `lib/widgets/recipe/comment_item_widget.dart`
- `lib/widgets/recipe/comment_item_widgets.dart`

### Current State
- Confusing naming: singular vs plural
- Unclear which is primary

### Investigation Required
1. What does each file export?
2. Is one a helper for the other?

### Proposed Solution
If duplicate: Merge and keep `comment_item_widget.dart`
If helpers: Rename to `comment_item_helpers.dart`

### Recommendation: ✅ DO IT

### Reasoning
Naming clarity is important for maintainability. Quick fix.

---

## Summary: Proposal Decision Matrix

| # | Proposal | Priority | Risk | Effort | Impact | Decision |
|---|----------|----------|------|--------|--------|----------|
| 1 | Import System | HIGH | Medium | High | High | ✅ DO IT |
| 2 | Badge Unification | HIGH | Low | Low | Medium | ✅ DO IT |
| 3 | Realtime Indicators | HIGH | Low | Low | Low | ✅ DO IT |
| 4 | Dialog BaseDialog | HIGH | Medium | Medium | Medium | ✅ DO IT |
| 5 | Extraction Service | HIGH | Low | Medium | Medium | ✅ DO IT |
| 6 | Account Operations | MEDIUM | Low | Low | Low | ⚠️ CONSIDER |
| 7 | Shared Content VMs | MEDIUM | Medium | Medium | Low | ⚠️ INVESTIGATE |
| 8 | Group Dialogs | MEDIUM | Medium | Medium | Medium | ⚠️ CONSIDER |
| 9 | Realtime Coordination | MEDIUM | Medium | Medium | Medium | ⚠️ INVESTIGATE |
| 10 | Portion Scaler | LOW | Low | Low | Low | ❌ LEAVE AS-IS |
| 11 | Comment Widget | HIGH | Low | Low | Low | ✅ DO IT |

### Recommended Implementation Order
1. **Quick Wins First**: Badge, Realtime Indicators, Comment Widget (1-2 days)
2. **Pattern Enforcement**: Dialog BaseDialog adoption (2-3 days)
3. **Architecture Clarity**: Extraction Service (1 day)
4. **High Impact**: Import System (1-2 weeks)
5. **Investigation**: Shared Content VMs, Realtime Coordination
6. **If Time Permits**: Account Operations, Group Dialogs
