# Design Hardcoding Audit - Complete Analysis

**Date**: 2026-01-11
**Purpose**: Pre-redesign audit to identify all design decisions made outside `/theme` system
**Status**: Complete - 341 files analyzed (102 views, 239 widgets)

---

## Executive Summary

Your theming infrastructure is **well-structured** with comprehensive design tokens in `AppColors`, `AppDimensions`, and `AppTextStyles`. However, **significant hardcoding remains** across the codebase that will block a clean redesign.

### Key Findings:
- ✅ **Theme System**: Excellent foundation with M3 components
- ⚠️ **12+ brand color hexcodes** in platform badges (CRITICAL)
- ⚠️ **40+ files** with hardcoded spacing/padding
- ⚠️ **30+ files** with hardcoded border radius
- ⚠️ **14 files** with custom shadow definitions
- ⚠️ **50+ instances** of hardcoded icon sizes
- ⚠️ **7 files** with inline gradient definitions

### Impact Level:
- **CRITICAL**: Platform brand colors will break completely
- **HIGH**: 60+ files need systematic refactoring
- **MEDIUM**: 20+ files need consistency improvements

---

## 1. CRITICAL ISSUES (Will Break Redesign)

### 1.1 Direct Hex Color Codes

**🔴 HIGH SEVERITY** - Non-themeable brand colors

| File | Count | Issue |
|------|-------|-------|
| `lib/widgets/import/platform_badge_widget.dart` | 12 | YouTube, TikTok, Instagram, Pinterest, etc. |

**Examples:**
```dart
// CURRENT - BAD
Color(0xFFFF0000)  // YouTube Red
Color(0xFF00F2EA)  // TikTok Cyan
Color(0xFFE1306C)  // Instagram Pink
Color(0xFF1DA1F2)  // Twitter Blue
Color(0xFFE60023)  // Pinterest Red
Color(0xFF25D366)  // WhatsApp Green
Color(0xFF0088CC)  // Telegram Blue
Color(0xFFBD081C)  // Allrecipes Red
Color(0xFFFF6600)  // ICA Orange
Color(0xFF006341)  // Coop Green
Color(0xFFE30613)  // Arla Red
Color(0xFF000000)  // Köket.se Black
```

**RECOMMENDATION:**
Create `lib/theme/brand_colors.dart`:
```dart
abstract class BrandColors {
  // Social Platforms
  static const youtube = Color(0xFFFF0000);
  static const tiktok = Color(0xFF00F2EA);
  static const instagram = Color(0xFFE1306C);
  static const twitter = Color(0xFF1DA1F2);
  static const pinterest = Color(0xFFE60023);
  static const whatsapp = Color(0xFF25D366);
  static const telegram = Color(0xFF0088CC);

  // Recipe Platforms
  static const allrecipes = Color(0xFFBD081C);
  static const ica = Color(0xFFFF6600);
  static const coop = Color(0xFF006341);
  static const arla = Color(0xFFE30613);
  static const koketSe = Color(0xFF000000);
}
```

---

## 2. HIGH PRIORITY (Major Redesign Work)

### 2.1 Hardcoded Spacing & Padding

**🟠 HIGH SEVERITY** - 40+ files mixing theme and hardcoded values

#### View Files (8 instances):
| File | Examples |
|------|----------|
| `lib/views/social/discovery_dashboard_view.dart` | Multiple `EdgeInsets` with numeric values |
| `lib/views/tag_detail_view.dart` | Mixed theme + hardcoded padding |
| `lib/views/settings/mfa_settings_view.dart` | Direct `EdgeInsets` definitions |
| `lib/views/legal/privacy_policy_view.dart` | Hardcoded spacing |
| `lib/views/auth/mfa_challenge_dialog.dart` | Numeric padding values |
| `lib/views/account/consent_management_view.dart` | Direct spacing |
| `lib/views/account/data_export_view.dart` | Hardcoded EdgeInsets |
| `lib/views/smart_import_view.dart` | Mixed usage |

#### Widget Files (4 primary + many secondary):
| File | Examples |
|------|----------|
| `lib/widgets/tagging/personal_tag_edit_dialog.dart` | `EdgeInsets.symmetric(horizontal: 12, vertical: 8)` |
| `lib/widgets/import/text_line_selector.dart` | Hardcoded padding |
| `lib/widgets/import/components/import_dialog_footer.dart` | Numeric values |
| `lib/widgets/import/assisted_import_dialog.dart` | Direct EdgeInsets |

**BAD Pattern:**
```dart
padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)
EdgeInsets.only(left: 8, right: 8)
const EdgeInsets.all(20)
const SizedBox(height: 16)
```

**GOOD Pattern:**
```dart
padding: EdgeInsets.symmetric(
  horizontal: AppDimensions.spacingSm,
  vertical: AppDimensions.spacingXs,
)
SizedBox(height: AppDimensions.spacingMd)
```

**Available Constants:**
```dart
AppDimensions.spacingXxs  // 2px
AppDimensions.spacingXs   // 4px
AppDimensions.spacingSm   // 8px
AppDimensions.spacingMd   // 12px
AppDimensions.spacing     // 16px
AppDimensions.spacingLg   // 24px
AppDimensions.spacingXl   // 32px
AppDimensions.spacingXxl  // 48px
```

---

### 2.2 Hardcoded Border Radius

**🟠 HIGH SEVERITY** - 30+ files with numeric border radius

| File | Count | Examples |
|------|-------|----------|
| `lib/views/tag_detail_view.dart` | 1 | `BorderRadius.circular(12)` |
| `lib/views/social/discovery_dashboard_view.dart` | 3 | `circular(16)`, `circular(8)` |
| `lib/widgets/tagging/tag_result_display.dart` | Multiple | Various radius values |
| `lib/widgets/tagging/personal_tag_selector.dart` | Multiple | Hardcoded numbers |
| `lib/widgets/tagging/personal_tag_manager_dialog.dart` | Multiple | Direct values |
| `lib/widgets/import/platform_badge_widget.dart` | 1 | `BorderRadius.circular(16)` |
| `lib/widgets/import/text_line_selector.dart` | Multiple | Numeric values |
| `lib/widgets/import/components/editable_list_builder.dart` | Multiple | Direct radius |

**BAD Pattern:**
```dart
BorderRadius.circular(8)
BorderRadius.circular(12)
BorderRadius.circular(16)
BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))
```

**GOOD Pattern:**
```dart
BorderRadius.circular(AppDimensions.borderRadiusM)
BorderRadius.circular(AppDimensions.borderRadiusL)
```

**Available Constants:**
```dart
AppDimensions.borderRadiusS     // 4px
AppDimensions.borderRadiusM     // 8px
AppDimensions.borderRadiusL     // 12px
AppDimensions.borderRadiusXl    // 12px
AppDimensions.borderRadiusRound // 50px
```

---

### 2.3 Hardcoded Icon Sizes

**🟠 HIGH SEVERITY** - 50+ instances across 40+ files

#### View Files:
- `lib/views/tag_detail_view.dart`
- `lib/views/social/add_members_to_group_view.dart`
- `lib/views/social/shared_with_me/shared_content_search_bar.dart`
- `lib/views/recipe_detail/handlers/recipe_personal_tag_handler.dart`
- `lib/views/personal_tags_view.dart`
- `lib/views/legal/privacy_policy_view.dart`
- `lib/views/file_import_view.dart`
- `lib/views/account/consent_management_view.dart`
- Plus 10+ more view files

#### Widget Files:
- `lib/widgets/tagging/personal_tag_rule_dialog.dart` - `Icon(Icons.label, size: 16)`
- `lib/widgets/tagging/personal_tag_selector.dart`
- Plus 15+ more widget files

**BAD Pattern:**
```dart
Icon(Icons.label, size: 16)
Icon(Icons.add, size: 20)
Icon(Icons.close, size: 24)
```

**GOOD Pattern:**
```dart
Icon(Icons.label, size: AppDimensions.iconSizeS)
Icon(Icons.add, size: AppDimensions.iconSizeM)
Icon(Icons.close, size: AppDimensions.iconSizeL)
```

**Available Constants:**
```dart
AppDimensions.iconSizeS       // 16px
AppDimensions.iconSizeM       // 20px
AppDimensions.iconSizeL       // 24px
AppDimensions.iconSizeXl      // 32px
AppDimensions.iconSizeXxl     // 48px
AppDimensions.iconSizeHero    // 72px
AppDimensions.iconSizeAction  // 20px
```

---

### 2.4 Hardcoded Container/SizedBox Dimensions

**🟠 HIGH SEVERITY** - Scattered width/height values

| File | Issue | Examples |
|------|-------|----------|
| `lib/views/social/discovery_dashboard/trending_content_section.dart` | Card dimensions | `width: 160, height: 100` |
| `lib/views/social/discovery_dashboard/discovery_app_bar.dart` | Spacer heights | `const SizedBox(height: 40)` |
| `lib/widgets/messaging/typing_indicator.dart` | Avatar/dot sizes | `width: 32`, `width: 24`, `width: 4` |
| `lib/widgets/branding/app_logo.dart` | Logo size | `size = 120.0` |
| `lib/widgets/messaging/message_bubble.dart` | Swipe threshold | `static const double _swipeThreshold = 80.0` |

**RECOMMENDATION:**
Extend `AppDimensions` with common sizes:
```dart
// Add to AppDimensions
static const double cardWidthSmall = 160.0;
static const double cardHeightSmall = 100.0;
static const double avatarSizeSmall = 32.0;
static const double avatarSizeMedium = 40.0;
static const double swipeThreshold = 80.0;
```

---

## 3. MEDIUM PRIORITY (Visual Consistency)

### 3.1 Hardcoded Box Shadows

**🟡 MEDIUM SEVERITY** - 14 files with custom shadow definitions

#### View Files (6):
- `lib/views/unified_shopping/widgets/shopping_list_header.dart`
- `lib/views/social/discovery_dashboard/trending_content_section.dart`
- `lib/views/social/discovery_dashboard/recommendations_section.dart`
- `lib/views/social/discovery_dashboard/friend_activity_section.dart`
- `lib/views/social/discovery_dashboard/discovery_categories.dart`
- `lib/views/social/discovery_dashboard/discovery_search_section.dart`

#### Widget Files (8):
- `lib/widgets/tagging/personal_tag_color_picker.dart`
- `lib/widgets/messaging/typing_indicator.dart`
- `lib/widgets/image/components/image_grid_widgets.dart`
- `lib/widgets/common/universal_share_dialog.dart`
- `lib/widgets/common/search_filter/filters_panel_widget.dart`
- `lib/widgets/common/indicators/participant_list_widget.dart`
- `lib/widgets/common/content_cards/image_preview_card.dart`
- `lib/widgets/branding/app_logo.dart`

**BAD Pattern:**
```dart
boxShadow: [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.1),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
]
```

**RECOMMENDATION:**
Create `lib/theme/app_shadows.dart`:
```dart
abstract class AppShadows {
  static List<BoxShadow> get subtle => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
}
```

**Current Available (limited):**
```dart
AppDimensions.cardShadow  // Basic shadow list
AppDimensions.elevationLow    // 2.0
AppDimensions.elevationMedium // 4.0
AppDimensions.elevationHigh   // 8.0
```

---

### 3.2 Hardcoded Typography

**🟡 MEDIUM SEVERITY** - 6+ files with direct TextStyle definitions

| File | Issue | Count |
|------|-------|-------|
| `lib/views/tag_detail_view.dart` | `TextStyle(fontSize: ...)` | 1 |
| `lib/views/recipe_detail_view.dart` | Inline font sizes | 1 |
| `lib/views/auth/mfa_challenge_dialog.dart` | Direct font sizing | 1 |
| `lib/widgets/tagging/personal_tag_rule_dialog.dart` | `TextStyle(fontSize: 14)` | Multiple |
| `lib/widgets/recipe/draft_recovery_dialog.dart` | Hardcoded sizes | 2+ |
| `lib/widgets/messaging/messaging_ui_components.dart` | Direct TextStyle | 2+ |

**BAD Pattern:**
```dart
TextStyle(fontSize: 14, fontWeight: FontWeight.w500)
TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
Text('Label', style: TextStyle(fontSize: 12))
```

**GOOD Pattern:**
```dart
Text('Label', style: AppTextStyles.labelMedium)
Text('Body', style: AppTextStyles.bodySmall)
Text('Title', style: AppTextStyles.titleLarge)
```

**Available Text Styles:**
- `AppTextStyles.displayLarge/Medium/Small`
- `AppTextStyles.headlineLarge/Medium/Small`
- `AppTextStyles.titleLarge/Medium/Small`
- `AppTextStyles.bodyLarge/Medium/Small`
- `AppTextStyles.labelLarge/Medium/Small`

---

### 3.3 Hardcoded Gradient Definitions

**🟡 MEDIUM SEVERITY** - 7 files with inline gradients

| File | Purpose |
|------|---------|
| `lib/views/social/discovery_dashboard/discovery_section_header.dart` | Custom gradient |
| `lib/views/social/discovery_dashboard/discovery_app_bar.dart` | AppBar gradient |
| `lib/views/recipe_detail_view.dart` | Image overlay |
| `lib/widgets/styled/styled_card.dart` | Skeleton loading |
| `lib/widgets/image/recipe_image_widget.dart` | Image overlay |
| `lib/widgets/image/avatar_image_widget.dart` | Avatar gradient |
| `lib/widgets/common/state/skeleton_components.dart` | Loading skeleton |

**BAD Pattern:**
```dart
gradient: LinearGradient(
  colors: [
    Colors.black.withValues(alpha: 0.7),
    Colors.transparent,
  ],
  begin: Alignment.bottomCenter,
  end: Alignment.topCenter,
)
```

**RECOMMENDATION:**
Create `lib/theme/app_gradients.dart`:
```dart
abstract class AppGradients {
  static const imageOverlay = LinearGradient(
    colors: [
      Color(0xB3000000), // Black 70%
      Color(0x00000000), // Transparent
    ],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
  );

  static const skeletonLoading = LinearGradient(
    colors: [
      Color(0xFFEEEEEE),
      Color(0xFFF5F5F5),
      Color(0xFFEEEEEE),
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment(-1.0, 0.0),
    end: Alignment(1.0, 0.0),
  );

  static LinearGradient appBarGradient(BuildContext context) {
    final theme = Theme.of(context);
    return LinearGradient(
      colors: [
        theme.colorScheme.primary,
        theme.colorScheme.primaryContainer,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
```

---

### 3.4 Hardcoded Dialog Dimensions

**🟡 MEDIUM SEVERITY** - Multiple dialog files

**Examples:**
- `lib/widgets/tagging/personal_tag_rule_dialog.dart` - `maxWidth: 500, maxHeight: 700`
- Multiple bottom sheets with `initialChildSize: 0.7, maxChildSize: 0.9`
- Import dialogs with fixed constraints

**BAD Pattern:**
```dart
Container(
  constraints: BoxConstraints(maxWidth: 500, maxHeight: 700),
  child: Dialog(...),
)
```

**GOOD Pattern:**
```dart
Container(
  constraints: BoxConstraints(
    maxWidth: AppDimensions.responsiveMaxFormWidth(context),
  ),
  child: Dialog(...),
)
```

**Available Responsive Helpers:**
```dart
AppDimensions.responsiveMaxFormWidth(context)
AppDimensions.responsiveDialogWidth(context)
AppDimensions.maxContentWidth      // 500px (narrow)
AppDimensions.maxContentWidthWide  // 1200px
```

---

## 4. LOW PRIORITY (Consistency Improvements)

### 4.1 Hardcoded Animation Durations

**Files (5+):**
- `lib/widgets/messaging/typing_indicator.dart` - `Duration(milliseconds: 1200)`
- `lib/widgets/messaging/message_bubble.dart` - `Duration(milliseconds: 200)`
- Various animation files

**Available Constants:**
```dart
AppDimensions.animationDurationFast     // 150ms
AppDimensions.animationDurationMedium   // 200ms
AppDimensions.animationDurationCommon   // 300ms
AppDimensions.animationDurationSlow     // 350ms
AppDimensions.animationDurationLong     // 500ms
```

---

### 4.2 Scattered Font Weights

**39+ files** with direct `fontWeight` usage:
```dart
fontWeight: FontWeight.w600
fontWeight: FontWeight.w700
fontWeight: FontWeight.bold
fontWeight: FontWeight.w500
```

**RECOMMENDATION:**
These should be consolidated into `AppTextStyles` usage rather than scattered throughout.

---

## 5. PATTERN ANALYSIS

### 5.1 Worst Offender Files

**TOP 10 Files Needing Most Work:**

1. ⭐ **`lib/widgets/import/platform_badge_widget.dart`**
   - 12 brand color hexcodes (CRITICAL)
   - 1 hardcoded border radius
   - Must create BrandColors class first

2. ⭐ **`lib/views/social/discovery_dashboard/trending_content_section.dart`**
   - Custom box shadows
   - Hardcoded card dimensions (160x100)
   - Border radius values

3. ⭐ **`lib/views/social/discovery_dashboard/discovery_app_bar.dart`**
   - Custom gradient definition
   - Hardcoded spacing
   - Direct dimension values

4. ⭐ **`lib/widgets/messaging/typing_indicator.dart`**
   - Multiple hardcoded dimensions (32, 24, 4)
   - Custom animation duration (1200ms)
   - Box shadow definition

5. **`lib/widgets/tagging/personal_tag_rule_dialog.dart`**
   - Mixed hardcoded typography
   - Icon sizes (16px)
   - Dialog dimensions (500x700)

6. **`lib/views/social/discovery_dashboard/` (all 6 files)**
   - Consistent pattern of shadow hardcoding
   - Gradient definitions
   - Spacing inconsistencies

7. **`lib/widgets/branding/app_logo.dart`**
   - Hardcoded logo size (120.0)
   - Custom shadow calculation
   - Should be in AppDimensions

8. **`lib/widgets/messaging/message_bubble.dart`**
   - Swipe threshold (80.0)
   - Animation duration (200ms)

9. **`lib/widgets/import/` (multiple dialog files)**
   - Dialog dimensions
   - Spacing inconsistencies
   - Mixed theme usage

10. **`lib/widgets/tagging/` (5+ files)**
    - Scattered icon sizes
    - Border radius values
    - Spacing patterns

---

### 5.2 Common Anti-Patterns

**Pattern 1: Mixed Theme Usage**
```dart
// BAD - mixing theme with hardcoded
padding: EdgeInsets.symmetric(
  horizontal: AppDimensions.spacingSm,  // ✓ Theme
  vertical: 8,                          // ✗ Hardcoded
)
```

**Pattern 2: Magic Numbers**
```dart
// BAD - what does 160 represent?
Container(width: 160, height: 100)

// GOOD - semantic naming
Container(
  width: AppDimensions.cardWidthSmall,
  height: AppDimensions.cardHeightSmall,
)
```

**Pattern 3: Inline Styles**
```dart
// BAD - scattered definitions
Text('Label', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))

// GOOD - semantic style
Text('Label', style: AppTextStyles.labelMedium)
```

---

## 6. REDESIGN ACTION PLAN

### Phase 1: Expand Theme System (Foundation)

**Create New Theme Files:**

1. **`lib/theme/brand_colors.dart`**
   ```dart
   abstract class BrandColors {
     // Social platforms
     static const youtube = Color(0xFFFF0000);
     static const tiktok = Color(0xFF00F2EA);
     // ... all 12 platform colors
   }
   ```

2. **`lib/theme/app_shadows.dart`**
   ```dart
   abstract class AppShadows {
     static List<BoxShadow> get subtle => [...];
     static List<BoxShadow> get card => [...];
     static List<BoxShadow> get elevated => [...];
     static List<BoxShadow> get floating => [...];
   }
   ```

3. **`lib/theme/app_gradients.dart`**
   ```dart
   abstract class AppGradients {
     static const imageOverlay = LinearGradient(...);
     static const skeletonLoading = LinearGradient(...);
     static LinearGradient appBarGradient(BuildContext context) {...}
   }
   ```

**Extend Existing Files:**

4. **`lib/theme/app_dimensions.dart` - Add:**
   ```dart
   // Container Sizes
   static const double cardWidthSmall = 160.0;
   static const double cardHeightSmall = 100.0;
   static const double avatarSizeXs = 24.0;
   static const double avatarSizeSm = 32.0;
   static const double avatarSizeMd = 40.0;
   static const double avatarSizeLg = 48.0;
   static const double swipeThreshold = 80.0;

   // Logo Sizes
   static const double logoSizeSmall = 60.0;
   static const double logoSizeMedium = 120.0;
   static const double logoSizeLarge = 180.0;
   ```

---

### Phase 2: Systematic Replacement

**Week 1: Critical Issues**
- [ ] Create `BrandColors` class
- [ ] Replace all 12 platform colors in `platform_badge_widget.dart`
- [ ] Test all import flows with platform badges

**Week 2: High Priority - Spacing**
- [ ] Replace hardcoded `EdgeInsets` in 8 view files
- [ ] Replace hardcoded `EdgeInsets` in 12 widget files
- [ ] Verify responsive behavior

**Week 3: High Priority - Visual Elements**
- [ ] Create `AppShadows` class
- [ ] Replace shadow definitions in 14 files
- [ ] Replace border radius in 30+ files
- [ ] Replace icon sizes in 40+ files

**Week 4: Medium Priority - Refinements**
- [ ] Create `AppGradients` class
- [ ] Replace gradient definitions in 7 files
- [ ] Replace dialog dimensions
- [ ] Replace container dimensions

**Week 5: Low Priority - Polish**
- [ ] Replace animation durations
- [ ] Consolidate font weight usage
- [ ] Final validation pass

---

### Phase 3: Validation & Testing

**Automated Checks:**
```bash
# Search for remaining hardcoded patterns
grep -r "Color(0x" lib/views/ lib/widgets/ --include="*.dart"
grep -r "BorderRadius.circular([0-9]" lib/ --include="*.dart"
grep -r "EdgeInsets\." lib/ --include="*.dart" | grep -E "[0-9]+"
grep -r "fontSize: [0-9]" lib/ --include="*.dart"
grep -r "Icon.*size: [0-9]" lib/ --include="*.dart"
```

**Manual Testing:**
- [ ] Light/Dark mode switches
- [ ] Responsive layouts (mobile, tablet, desktop)
- [ ] All discovery dashboard sections
- [ ] Platform badge rendering
- [ ] Dialog appearance and sizing
- [ ] Animation smoothness
- [ ] Shadow rendering quality

---

## 7. SEARCH COMMANDS FOR FINDING ISSUES

Use these grep commands to find remaining hardcoded values:

```bash
# Find hex colors
grep -r "Color(0x" lib/ --include="*.dart" | grep -v "lib/theme/"

# Find hardcoded border radius
grep -r "BorderRadius.circular(" lib/ --include="*.dart" | grep -E "\([0-9]"

# Find hardcoded padding/margins with numbers
grep -r "EdgeInsets\." lib/ --include="*.dart" | grep -E "\b[0-9]+\.?[0-9]*\b"

# Find hardcoded font sizes
grep -r "fontSize:" lib/ --include="*.dart" | grep -E "fontSize: [0-9]"

# Find hardcoded icon sizes
grep -r "Icon\(" lib/ --include="*.dart" | grep "size:" | grep -E "[0-9]+"

# Find hardcoded SizedBox dimensions
grep -r "SizedBox(" lib/ --include="*.dart" | grep -E "(width|height): [0-9]"

# Find hardcoded BoxShadow
grep -r "BoxShadow(" lib/ --include="*.dart" | grep -v "lib/theme/"

# Find hardcoded LinearGradient
grep -r "LinearGradient(" lib/ --include="*.dart" | grep -v "lib/theme/"

# Find hardcoded animation durations
grep -r "Duration(milliseconds:" lib/ --include="*.dart"

# Find direct fontWeight usage
grep -r "fontWeight: FontWeight\." lib/ --include="*.dart"
```

---

## 8. FILES INVENTORY

### Critical Files (Immediate Attention Required):
- `lib/widgets/import/platform_badge_widget.dart` ⭐⭐⭐

### High Priority Files (Week 2-3):
**Views:**
- `lib/views/social/discovery_dashboard_view.dart`
- `lib/views/social/discovery_dashboard/trending_content_section.dart`
- `lib/views/social/discovery_dashboard/discovery_app_bar.dart`
- `lib/views/social/discovery_dashboard/recommendations_section.dart`
- `lib/views/social/discovery_dashboard/friend_activity_section.dart`
- `lib/views/social/discovery_dashboard/discovery_categories.dart`
- `lib/views/tag_detail_view.dart`
- `lib/views/settings/mfa_settings_view.dart`

**Widgets:**
- `lib/widgets/messaging/typing_indicator.dart`
- `lib/widgets/messaging/message_bubble.dart`
- `lib/widgets/tagging/personal_tag_rule_dialog.dart`
- `lib/widgets/tagging/personal_tag_edit_dialog.dart`
- `lib/widgets/branding/app_logo.dart`

### Medium Priority Files (Week 4):
- All remaining discovery dashboard files
- All tagging widget files (5+)
- All import widget files (8+)
- Dialog files with dimension hardcoding

### Low Priority Files (Week 5):
- Files with only animation duration issues
- Files with only font weight scattered usage
- Minor spacing inconsistencies

---

## 9. SUCCESS METRICS

**After redesign completion, you should achieve:**
- ✅ Zero hex color codes outside `/theme/brand_colors.dart`
- ✅ Zero numeric border radius values
- ✅ Zero hardcoded `EdgeInsets` with literal numbers
- ✅ Zero inline `TextStyle` definitions
- ✅ Zero hardcoded icon sizes
- ✅ Zero custom shadow definitions outside theme
- ✅ Zero gradient definitions outside theme
- ✅ 100% theme-driven design system

**Validation Command:**
```bash
# This should return ZERO results after refactoring:
grep -r "Color(0x" lib/views/ lib/widgets/ --include="*.dart" | \
  grep -v "lib/theme/" | wc -l
```

---

## 10. NOTES & RECOMMENDATIONS

### Best Practices for Redesign:
1. **Never mix** theme constants with hardcoded values
2. **Always use semantic names** (e.g., `cardWidthSmall` not `width160`)
3. **Create theme constants** before replacing values
4. **Test after each phase** - don't batch all changes
5. **Use responsive helpers** for dialog/container sizing
6. **Consider dark mode** when defining shadows and overlays
7. **Document rationale** for any new theme constants

### Migration Tips:
- Start with `BrandColors` - most critical and isolated
- Use find/replace with regex for systematic changes
- Create theme constants in batches by category
- Test visual regression after each category
- Keep PR sizes manageable (1-2 categories per PR)

### Future-Proofing:
Once redesign is complete:
- Add linter rules to prevent hardcoded design values
- Create component library documentation
- Establish code review checklist for design consistency
- Consider design tokens system for cross-platform design

---

**END OF AUDIT**

This document provides a complete map for migrating to a 100% theme-driven design system. Prioritize Phase 1 (theme expansion) before systematic replacement in Phase 2.
