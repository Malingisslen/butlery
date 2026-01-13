# Design System Audit Report

**Date**: 2026-01-13
**Purpose**: Identify design decisions made outside of `/lib/theme/` before app redesign

## Executive Summary

The theme system in `/lib/theme/` is well-structured and comprehensive, covering colors, typography, spacing, shadows, and component themes. However, **significant violations exist across the codebase** where design values are hardcoded directly in views and widgets instead of using theme tokens.

### Impact Assessment

| Category | Theme Coverage | Violations Found | Priority |
|----------|---------------|------------------|----------|
| Colors | Excellent | ~20 files | Medium |
| Typography | Good | ~45+ files | High |
| Spacing/Padding | Good | ~223 files | Critical |
| Dimensions | Good | ~94+ files | High |
| Shadows | Good | ~12 files | Medium |
| Animation Durations | Good | ~50+ files | Low |

---

## 1. Color Violations

### Status: MOSTLY GOOD
All `Color(0x...)` hex values are correctly defined in theme files. However, some direct `Colors.xxx` usage exists outside theme.

### Violations Found

**Direct Colors.xxx usage (outside theme):**
```
lib/widgets/import/platform_badge_widget.dart:120  → Colors.black
lib/widgets/import/platform_badge_widget.dart:135  → Colors.black
lib/widgets/import/platform_badge_widget.dart:189  → Colors.black
lib/views/personal_tags_view.dart:222             → Colors.red
lib/views/personal_tags_view.dart:452             → Colors.red
lib/views/tag_detail_view.dart:176                → Colors.red
lib/views/tag_detail_view.dart:445                → Colors.red
lib/views/settings/mfa_settings_view.dart:406     → Colors.red.shade700
```

### Recommendation
Replace `Colors.red` with `AppColors.error` and `Colors.black` with `AppColors.textDark` or appropriate semantic color.

---

## 2. Typography Violations

### Status: HIGH PRIORITY
Many files define inline `TextStyle` with hardcoded `fontSize` and `fontWeight` instead of using `AppTextStyles`.

### Files with Hardcoded fontSize (45+ instances)

**Views:**
- `lib/main.dart:218, 227, 641` - fontSize: 24, 12, 16
- `lib/main_e2e_optimized.dart:217` - fontSize: 16
- `lib/main_e2e_emulator.dart:167, 175, 207` - fontSize: 24, 16, 12
- `lib/main_e2e_mock.dart:132, 140, 157` - fontSize: 24, 16, 12
- `lib/main_e2e_staging.dart:182, 190, 198, 203, 220` - fontSize: 24, 16, 14, 12
- `lib/views/recipe_detail_view.dart:137` - fontSize: 16
- `lib/views/tag_detail_view.dart:1071, 1105` - fontSize: 14
- `lib/views/auth/mfa_challenge_dialog.dart:213` - fontSize: 13
- `lib/core/providers/application_provider.dart:294, 315, 322` - fontSize: 16, 20, 16

**Widgets:**
- `lib/widgets/image/image_components.dart:270` - fontSize: 10
- `lib/widgets/image/components/upload_progress_widgets.dart:237` - fontSize: 11
- `lib/widgets/messaging/components/message_status_widget.dart:32, 117` - fontSize: 10
- `lib/widgets/image/image_picker_widget.dart:315` - fontSize: 10
- `lib/widgets/social/group_shared_shopping_list_card.dart:114, 166, 235` - fontSize: 10
- `lib/widgets/social/groups/shared_content_card.dart:139` - fontSize: 10
- `lib/widgets/social/groups/shared/group_dialog_components.dart:102` - fontSize: 20
- `lib/widgets/common/share_dialog/share_target_selection_enhanced.dart:344` - fontSize: 20
- `lib/widgets/tagging/personal_tag_rule_dialog.dart:596, 624, 747, 758` - fontSize: 14, 12

### Files with Hardcoded fontWeight (100+ instances)

Major violators (using inline fontWeight instead of AppTextStyles):
- `lib/views/social/friends_list/groups_tab.dart` - FontWeight.bold
- `lib/views/social/friends_list/group_invitation_card.dart` - FontWeight.bold
- `lib/widgets/import/components/editable_list_builder.dart` - FontWeight.w500, w600
- `lib/widgets/import/components/step_progress_indicator.dart` - FontWeight.w600
- `lib/widgets/import/text_line_selector.dart` - FontWeight.w600, w500
- `lib/widgets/messaging/conversation_list_item.dart` - FontWeight.bold, w500
- `lib/widgets/recipe/recipe_card.dart` - FontWeight.w600, w500
- `lib/widgets/social/collaborative/components/*.dart` - Various weights
- `lib/widgets/common/share_dialog/*.dart` - Various weights
- `lib/views/social/discovery_dashboard/*.dart` - Various weights
- `lib/widgets/common/friends/*.dart` - Various weights
- `lib/views/social/group_detail/*.dart` - Various weights

### Recommendation
1. Extend `AppTextStyles` with more semantic variants (e.g., `captionSmall`, `metaText`)
2. Replace all `.copyWith(fontWeight: ...)` with proper style references
3. Create widget-specific style constants where patterns repeat

---

## 3. Spacing & Padding Violations

### Status: CRITICAL - HIGHEST PRIORITY
**223 files** use `EdgeInsets.xxx()` with hardcoded values instead of `AppDimensions` constants.

### Top Violators by Directory

**Views (67 files):**
```
lib/views/social/ - 28 files
lib/views/messaging/ - 5 files
lib/views/recipe_detail/ - 5 files
lib/views/unified_shopping/ - 5 files
lib/views/account/ - 3 files
lib/views/settings/ - 2 files
```

**Widgets (139 files):**
```
lib/widgets/common/ - 60+ files
lib/widgets/social/ - 18 files
lib/widgets/messaging/ - 14 files
lib/widgets/image/ - 12 files
lib/widgets/tagging/ - 10 files
lib/widgets/recipe/ - 8 files
lib/widgets/import/ - 8 files
```

### Common Patterns Found

Most violations follow these patterns:
- `EdgeInsets.all(8)` → Should use `AppDimensions.paddingS` or similar
- `EdgeInsets.all(16)` → Should use `AppDimensions.paddingM`
- `EdgeInsets.symmetric(horizontal: 16, vertical: 8)` → Should use theme constants
- `EdgeInsets.only(...)` with hardcoded values

### Recommendation
1. Create more semantic EdgeInsets constants in `AppDimensions`:
   ```dart
   static const EdgeInsets cardPadding = EdgeInsets.all(spacingMd);
   static const EdgeInsets listItemPadding = EdgeInsets.symmetric(...);
   static const EdgeInsets dialogPadding = EdgeInsets.all(spacingLg);
   ```
2. Systematically replace all hardcoded EdgeInsets across 223 files

---

## 4. Dimension Violations (Height/Width)

### Status: HIGH PRIORITY

### SizedBox with Hardcoded Values (29 files)

Files using `SizedBox(height: X)` or `SizedBox(width: X)` with magic numbers:
- `lib/widgets/tagging/*.dart` - 5 files
- `lib/widgets/import/*.dart` - 5 files
- `lib/views/social/*.dart` - 8 files
- `lib/widgets/common/*.dart` - 6 files
- Various other files

### Hardcoded height: Values (94 files)

Major violators:
- `lib/views/social/discovery_dashboard/*.dart` - Multiple files
- `lib/views/social/friends_list/*.dart` - Multiple files
- `lib/widgets/common/dialogs/*.dart` - Multiple files
- `lib/widgets/messaging/*.dart` - Multiple files

### Hardcoded width: Values (86 files)

Similar distribution to height violations.

### Hardcoded maxWidth: Values (9 instances)

```
lib/services/messaging_media_service.dart:74, 174  → maxWidth: 1920
lib/viewmodels/photo_import_viewmodel.dart:304    → maxWidth: 2048
lib/views/smart_import_view.dart:83               → maxWidth: 600
lib/widgets/messaging/builders/message_content_builder.dart:207 → maxWidth: 250
lib/widgets/social/groups/shared/group_dialog_components.dart:287 → maxWidth: 200
lib/services/image_picker_service.dart:127, 228   → maxWidth: 2400
lib/widgets/common/buttons/action_buttons.dart:92 → maxWidth: 200
```

### Hardcoded Icon Sizes (6 instances)

```
lib/widgets/tagging/personal_tag_selector.dart:388        → size: 12
lib/widgets/tagging/allergen_status_badge.dart:197        → size: 14
lib/widgets/tagging/dietary_status_badge.dart:188         → size: 14
lib/widgets/tagging/personal_tag_manager_dialog.dart:571, 617 → size: 12, 14
lib/widgets/common/friends/category_selection_widgets.dart:285 → size: 18.0
```

### Recommendation
1. Add more semantic dimension constants to `AppDimensions`
2. Use `AppDimensions.iconSizeXs`, `iconSizeS`, etc. for all icon sizes
3. Define image constraint constants for media services

---

## 5. Shadow Violations

### Status: MEDIUM PRIORITY

### BoxShadow Outside Theme (12 instances)

```
lib/widgets/image/components/image_grid_widgets.dart:216
lib/views/unified_shopping/widgets/shopping_list_header.dart:28
lib/views/social/discovery_dashboard/trending_content_section.dart:93
lib/views/social/discovery_dashboard/discovery_categories.dart:64
lib/views/social/discovery_dashboard/friend_activity_section.dart:94
lib/views/social/discovery_dashboard/recommendations_section.dart:98
lib/widgets/tagging/personal_tag_color_picker.dart:115
lib/widgets/branding/app_logo.dart:76
lib/views/social/discovery_dashboard/discovery_search_section.dart:47
lib/widgets/messaging/typing_indicator.dart:127
lib/widgets/common/search_filter/filters_panel_widget.dart:75
lib/widgets/common/indicators/participant_list_widget.dart:36
lib/widgets/common/universal_share_dialog.dart:199
```

### Hardcoded Elevation (11 instances)

Most are `elevation: 0` which is acceptable, but some violations exist in component themes that should reference `AppDimensions.elevationXxx`.

### Recommendation
Use `AppShadows.subtle`, `AppShadows.card`, `AppShadows.elevated`, or `AppShadows.floating` instead of inline BoxShadow.

---

## 6. Animation Duration Violations

### Status: LOW PRIORITY

### Hardcoded Duration (50+ instances)

Many files use `Duration(milliseconds: XXX)` directly instead of theme constants.

**Common patterns:**
- `Duration(milliseconds: 300)` - Most common, should use `AppDimensions.animationDurationCommon`
- `Duration(milliseconds: 200)` - Should use `AppDimensions.animationDurationMedium`
- `Duration(milliseconds: 500)` - Should use `AppDimensions.animationDurationLong`
- `Duration(milliseconds: 150)` - Should use `AppDimensions.animationDurationFast`

**Note**: Many of these are in non-UI code (services, viewmodels) where using theme constants may not make sense. Focus on widget/view files.

### UI Files to Fix
- `lib/widgets/import/import_progress_widget.dart`
- `lib/widgets/tagging/personal_tag_color_picker.dart`
- `lib/widgets/import/platform_badge_widget.dart`
- `lib/widgets/image/simple_image_widget.dart`
- `lib/widgets/messaging/message_bubble.dart`
- `lib/widgets/common/state/skeleton_components.dart`

---

## 7. TextStyle Inline Violations

### Status: HIGH PRIORITY

Many widgets create inline `TextStyle()` objects instead of using `AppTextStyles`.

### Pattern Analysis

Common violation pattern:
```dart
// BAD - hardcoded style
Text('Label', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))

// GOOD - theme reference
Text('Label', style: AppTextStyles.labelLarge)
```

### Files with Most TextStyle Violations

1. `lib/views/tag_detail_view.dart` - Multiple inline TextStyles
2. `lib/views/personal_tags_view.dart` - Colors.red in TextStyle
3. `lib/widgets/tagging/personal_tag_rule_dialog.dart` - Multiple violations
4. `lib/main_e2e_*.dart` files - Testing entry points (lower priority)

---

## 8. Files Requiring No Changes (Theme Directory)

These files correctly define theme values and should NOT be modified:
- `lib/theme/app_colors.dart` ✓
- `lib/theme/app_dimensions.dart` ✓
- `lib/theme/app_shadows.dart` ✓
- `lib/theme/app_text_styles.dart` ✓
- `lib/theme/app_theme.dart` ✓
- `lib/theme/brand_colors.dart` ✓
- `lib/theme/theme_constants.dart` ✓
- `lib/theme/component_themes.dart` ✓
- `lib/theme/components/*.dart` ✓

---

## Remediation Priority

### Phase 1: Critical (Before Redesign)
1. **Spacing/Padding** - 223 files need EdgeInsets replacement
2. **Typography** - 45+ files with hardcoded fontSize/fontWeight

### Phase 2: High Priority
3. **Dimensions** - 94+ files with hardcoded height/width
4. **TextStyle** - Replace inline styles with AppTextStyles references

### Phase 3: Medium Priority
5. **Colors** - ~20 files with Colors.xxx violations
6. **Shadows** - 12 files with BoxShadow violations

### Phase 4: Low Priority
7. **Animation Durations** - 50+ files (many are non-UI, lower impact)

---

## Recommendations for Redesign

### 1. Extend AppDimensions
Add semantic padding/margin constants:
```dart
// Card-specific
static const EdgeInsets cardPadding = EdgeInsets.all(spacingMd);
static const EdgeInsets cardMargin = EdgeInsets.symmetric(vertical: spacingSm);

// List-specific
static const EdgeInsets listTilePadding = EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingSm);
static const EdgeInsets listSectionPadding = EdgeInsets.only(top: spacingLg);

// Dialog-specific
static const EdgeInsets dialogContentPadding = EdgeInsets.all(spacingLg);
static const EdgeInsets dialogActionsPadding = EdgeInsets.symmetric(horizontal: spacingMd);

// Form-specific
static const EdgeInsets formFieldPadding = EdgeInsets.symmetric(vertical: spacingSm);
```

### 2. Extend AppTextStyles
Add more semantic text styles:
```dart
static TextStyle get caption => bodySmall.copyWith(color: AppColors.textLight);
static TextStyle get overline => labelSmall.copyWith(letterSpacing: 1.5);
static TextStyle get metadata => bodySmall.copyWith(color: AppColors.textMedium);
```

### 3. Create Component-Specific Dimension Sets
```dart
class CardDimensions {
  static const padding = EdgeInsets.all(16);
  static const margin = EdgeInsets.symmetric(vertical: 8);
  static const borderRadius = 12.0;
  static const elevation = 2.0;
}
```

### 4. Linting Rule
Consider adding a custom lint rule to catch hardcoded design values in future development.

---

## Summary Statistics

| Category | Files Affected | Estimated LOC to Change |
|----------|---------------|------------------------|
| EdgeInsets | 223 | ~2000+ |
| fontSize/fontWeight | 100+ | ~500+ |
| height/width | 94+ | ~400+ |
| BoxShadow | 12 | ~50 |
| Colors.xxx | 20 | ~30 |
| Duration | 50+ | ~100 |
| **Total** | **~300 unique files** | **~3000+ lines** |

---

## Next Steps

1. Review and approve this audit
2. Extend theme constants as recommended
3. Create migration script or systematic replacement plan
4. Fix violations in priority order
5. Add linting rules to prevent regression
