# Design System Migration Plan - 100% Theme-Driven Redesign

**Created**: 2026-01-11
**Status**: Ready for Execution
**Estimated Effort**: 40 hours (1 developer-week)
**Expected Outcome**: 100% theme-driven design system

---

## Executive Summary

### Current State

After comprehensive audit (triple-verified across entire codebase), we have:

**~779 hardcoded design values** across 151 files that should use theme constants.

### The Good News

✅ **Your theme system is world-class** - AppDimensions has 80+ constants
✅ **94.3% of hardcoding already has theme equivalents** - no infrastructure gaps
✅ **The problem is developer behavior**, not missing constants
✅ **Quick wins available**: 61% fixable with automated find/replace

### Key Findings

| Issue | Count | Has Theme Equivalent? | Fix Method |
|-------|-------|----------------------|------------|
| Hardcoded opacity | **477** | ✅ YES - 8 constants exist | Automated |
| EdgeInsets with numbers | **88** | ✅ PARTIAL - most match | Semi-automated |
| Icon hardcoded sizes | **47** | ✅ YES - complete coverage | Automated |
| Platform brand colors | **15** | ❌ NO - must create | New file |
| TextStyle fontSize | **37** (production) | ✅ YES - AppTextStyles | Semi-automated |
| Border radius | **73** | ✅ YES - 14 constants | Automated |
| BoxConstraints max | **15** | ⚠️ PARTIAL - some exist | Manual |
| BoxShadow definitions | **15** | ❌ NO - must create | New file |

**CRITICAL DISCOVERY**: Even `lib/theme/components/` files (8 instances) use hardcoded opacity instead of AppDimensions constants!

---

## Phase 0: Foundation (4 hours)

### Objective: Create Missing Theme Infrastructure

#### Task 0.1: Create Brand Colors File (1 hour)

**File**: `lib/theme/brand_colors.dart`

```dart
/// Brand colors for external platforms and services.
/// These colors should match official brand guidelines.
import 'package:flutter/material.dart';

abstract class BrandColors {
  BrandColors._();

  // Social Media Platforms
  static const Color youtube = Color(0xFFFF0000);
  static const Color tiktok = Color(0xFF00F2EA);
  static const Color instagram = Color(0xFFE1306C);
  static const Color twitter = Color(0xFF1DA1F2);
  static const Color pinterest = Color(0xFFE60023);
  static const Color whatsapp = Color(0xFF25D366);
  static const Color telegram = Color(0xFF0088CC);
  static const Color facebook = Color(0xFF1877F2);
  static const Color reddit = Color(0xFFFF4500);

  // Swedish Recipe Platforms
  static const Color allrecipes = Color(0xFFBD081C);
  static const Color ica = Color(0xFFFF6600);
  static const Color coop = Color(0xFF006341);
  static const Color arla = Color(0xFFE30613);
  static const Color koketSe = Color(0xFF000000);

  // Generic fallback
  static const Color generic = Color(0xFF6B7280);
}
```

**Files to update**: `lib/widgets/import/platform_badge_widget.dart` (replace 15 Color(0x...) instances)

---

#### Task 0.2: Create Shadow Library (1 hour)

**File**: `lib/theme/app_shadows.dart`

```dart
/// Predefined shadow patterns for consistent elevation across the app.
import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

abstract class AppShadows {
  AppShadows._();

  /// Subtle shadow for minimal elevation (hover states, badges)
  static List<BoxShadow> get subtle => [
        BoxShadow(
          color: AppColors.shadow.withValues(alpha: AppDimensions.opacityVeryLight),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  /// Standard card shadow (most common)
  static List<BoxShadow> get card => [
        BoxShadow(
          color: AppColors.shadow.withValues(alpha: AppDimensions.opacityVeryLight),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// Elevated shadow for dialogs and modals
  static List<BoxShadow> get elevated => [
        BoxShadow(
          color: AppColors.shadow.withValues(alpha: AppDimensions.opacityLight),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  /// Floating shadow for FABs and floating elements
  static List<BoxShadow> get floating => [
        BoxShadow(
          color: AppColors.shadow.withValues(alpha: AppDimensions.opacityMediumLight),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
```

**Note**: This replaces the existing `AppDimensions.cardShadow` with a more complete library.

---

#### Task 0.3: Extend AppDimensions (1 hour)

Add missing constants to `lib/theme/app_dimensions.dart`:

```dart
// Add after existing constants (around line 200):

// Card Dimensions
static const double cardWidthSmall = 160.0;
static const double cardImageHeightSmall = 100.0;

// Spinner/Progress Indicators
static const double spinnerSizeSmall = 20.0;
static const double spinnerSizeMedium = 30.0;
// Note: strokeWidth2 already exists at line 162

// Dialog Constraints
static const double dialogMaxWidthSmall = 300.0;
static const double dialogMaxWidthMedium = 500.0;
static const double dialogMaxWidthLarge = 700.0;
static const double dialogMaxHeightSmall = 400.0;
static const double dialogMaxHeightMedium = 600.0;
static const double dialogMaxHeightLarge = 800.0;

// Very Small Paddings
static const double paddingXxs = 2.0;
static const double spacing6 = 6.0;

// Avatar Sizes (only avatarSizeM=32 exists currently)
static const double avatarSizeXs = 24.0;
static const double avatarSizeSm = 32.0; // Alias for avatarSizeM
static const double avatarSizeLg = 48.0;
static const double avatarSizeXl = 64.0;

// Extended Animation Durations
static const Duration animationDurationExtended = Duration(milliseconds: 1200);
```

---

#### Task 0.4: Create Design System Documentation (1 hour)

**File**: `docs/DESIGN_SYSTEM.md`

```markdown
# Butlery Design System Guide

## Quick Reference

### When to Use Theme Constants

✅ **ALWAYS** use theme constants for:
- Colors: `AppColors.*`
- Spacing/Padding: `AppDimensions.spacing*`, `AppDimensions.padding*`
- Border Radius: `AppDimensions.borderRadius*`
- Icon Sizes: `AppDimensions.iconSize*`
- Opacity: `AppDimensions.opacity*`
- Typography: `AppTextStyles.*`
- Shadows: `AppShadows.*`
- Brand Colors: `BrandColors.*`

❌ **NEVER** hardcode:
- Hex colors: `Color(0xFF...)`
- Opacity values: `.withValues(alpha: 0.5)` → use `AppDimensions.opacityHalf`
- Numeric sizes: `size: 20` → use `AppDimensions.iconSizeM`
- Literal padding: `EdgeInsets.all(16)` → use `AppDimensions.spacingMd`

## Common Patterns

### Opacity
```dart
// ❌ BAD
color.withValues(alpha: 0.1)
color.withValues(alpha: 0.5)

// ✅ GOOD
color.withValues(alpha: AppDimensions.opacityVeryLight)
color.withValues(alpha: AppDimensions.opacityHalf)
```

### Icon Sizes
```dart
// ❌ BAD
Icon(Icons.add, size: 20)

// ✅ GOOD
Icon(Icons.add, size: AppDimensions.iconSizeM)
```

### Spacing
```dart
// ❌ BAD
padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)

// ✅ GOOD
padding: EdgeInsets.symmetric(
  horizontal: AppDimensions.paddingM,
  vertical: AppDimensions.paddingS,
)
```

### Shadows
```dart
// ❌ BAD
boxShadow: [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.1),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
]

// ✅ GOOD
boxShadow: AppShadows.card
```

## Available Constants

### AppDimensions.opacity*
- `opacityVeryLight` = 0.1
- `opacityLight` = 0.2
- `opacityMediumLight` = 0.3
- `opacityMedium` = 0.4
- `opacityHalf` = 0.5
- `opacityMediumDark` = 0.6
- `opacityDark` = 0.7
- `opacityVeryDark` = 0.8

### AppDimensions.iconSize*
- `iconSizeXs` = 12px
- `iconSize14` = 14px
- `iconSizeS` = 16px
- `iconSize18` = 18px
- `iconSizeM` = 20px
- `iconSizeL` = 24px
- `iconSize28` = 28px
- `iconSizeXl` = 32px
- `iconSizeXxl` = 48px
- `iconSizeXXXl` = 64px
- `iconSizeHero` = 72px

### AppDimensions.spacing*
- `spacingXxs` = 2px
- `spacingXs` = 4px
- `spacingSm` = 8px
- `spacingMd` = 16px
- `spacingLg` = 24px
- `spacingXl` = 32px
- `spacingXxl` = 48px

See `lib/theme/app_dimensions.dart` for complete list.
```

---

## Phase 1: Opacity Blitz - 61% Win (8 hours)

### Objective: Fix All 477 Opacity Instances

**Impact**: Fixes 61% of all hardcoding issues in one automated operation!

#### Task 1.1: Automated Find/Replace (6 hours)

Run these 8 find/replace operations across entire codebase:

**CRITICAL**: Run in this exact order, test after each replacement.

```bash
# Operation 1: 0.1 → opacityVeryLight
Find (regex): \.withValues\(alpha:\s*0\.1\)
Replace: .withValues(alpha: AppDimensions.opacityVeryLight)
Estimated: ~120 instances

# Operation 2: 0.2 → opacityLight
Find (regex): \.withValues\(alpha:\s*0\.2\)
Replace: .withValues(alpha: AppDimensions.opacityLight)
Estimated: ~45 instances

# Operation 3: 0.3 → opacityMediumLight
Find (regex): \.withValues\(alpha:\s*0\.3\)
Replace: .withValues(alpha: AppDimensions.opacityMediumLight)
Estimated: ~95 instances

# Operation 4: 0.4 → opacityMedium
Find (regex): \.withValues\(alpha:\s*0\.4\)
Replace: .withValues(alpha: AppDimensions.opacityMedium)
Estimated: ~30 instances

# Operation 5: 0.5 → opacityHalf
Find (regex): \.withValues\(alpha:\s*0\.5\)
Replace: .withValues(alpha: AppDimensions.opacityHalf)
Estimated: ~65 instances

# Operation 6: 0.6 → opacityMediumDark
Find (regex): \.withValues\(alpha:\s*0\.6\)
Replace: .withValues(alpha: AppDimensions.opacityMediumDark)
Estimated: ~78 instances

# Operation 7: 0.7 → opacityDark
Find (regex): \.withValues\(alpha:\s*0\.7\)
Replace: .withValues(alpha: AppDimensions.opacityDark)
Estimated: ~35 instances

# Operation 8: 0.8 → opacityVeryDark
Find (regex): \.withValues\(alpha:\s*0\.8\)
Replace: .withValues(alpha: AppDimensions.opacityVeryDark)
Estimated: ~25 instances
```

**IMPORTANT**: Don't forget theme component files:
- `lib/theme/components/feedback_themes.dart` (2 instances)
- `lib/theme/components/input_themes.dart` (6 instances)

#### Task 1.2: Validation (2 hours)

```bash
# Verify zero hardcoded opacity remains
grep -r "withValues(alpha: 0\." lib/ --include="*.dart" | grep -v "lib/theme/" | wc -l
# Expected: 0

# Run flutter analyze
flutter analyze

# Visual spot-check
# - Check discovery dashboard (heavy opacity usage)
# - Check image gallery widget
# - Check recipe cards
# - Verify dark mode still works
```

**Files to Test** (top 10 by opacity count):
1. `lib/widgets/image/components/upload_progress_widgets.dart` (14 instances)
2. `lib/widgets/image/image_gallery_widget.dart` (13 instances)
3. `lib/views/social/discovery_dashboard/recommendations_section.dart` (11 instances)
4. `lib/widgets/recipe/recipe_card.dart` (11 instances)
5. `lib/views/social/discovery_dashboard/discovery_search_section.dart` (10 instances)

---

## Phase 2: High Priority Fixes (12 hours)

### Task 2.1: EdgeInsets Cleanup (6 hours)

**88 instances** - Semi-automated approach

**Common Patterns**:
```bash
# Pattern 1: symmetric(horizontal: 12, vertical: 8)
Find: EdgeInsets\.symmetric\(horizontal:\s*12,\s*vertical:\s*8\)
Replace: EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS)
Estimated: ~25 instances

# Pattern 2: all(16)
Find: EdgeInsets\.all\(16\)
Replace: EdgeInsets.all(AppDimensions.spacingMd)
Estimated: ~15 instances

# Pattern 3: symmetric(horizontal: 8, vertical: 4)
Find: EdgeInsets\.symmetric\(horizontal:\s*8,\s*vertical:\s*4\)
Replace: EdgeInsets.symmetric(horizontal: AppDimensions.paddingS, vertical: AppDimensions.spacingXs)
Estimated: ~12 instances
```

**Manual Review Required** (36 files):
Focus on top offenders:
1. `lib/views/account/consent_management_view.dart` (10 instances)
2. `lib/views/account/data_export_view.dart` (8 instances)
3. `lib/widgets/import/text_line_selector.dart` (6 instances)

---

### Task 2.2: Icon Sizes (2 hours)

**47 instances** - Fully automated

```bash
# Pattern 1: size: 16
Find: (Icon\([^,)]+,\s*size:)\s*16
Replace: $1 AppDimensions.iconSizeS
Estimated: ~15 instances

# Pattern 2: size: 18
Find: (Icon\([^,)]+,\s*size:)\s*18
Replace: $1 AppDimensions.iconSize18
Estimated: ~8 instances

# Pattern 3: size: 20
Find: (Icon\([^,)]+,\s*size:)\s*20
Replace: $1 AppDimensions.iconSizeM
Estimated: ~12 instances

# Pattern 4: size: 24
Find: (Icon\([^,)]+,\s*size:)\s*24
Replace: $1 AppDimensions.iconSizeL
Estimated: ~7 instances
```

**Validation**:
```bash
grep -rE "Icon\([^,)]+,\s*size:\s*\d+" lib/ | wc -l
# Expected: 0
```

---

### Task 2.3: Platform Brand Colors (4 hours)

**15 instances** in `lib/widgets/import/platform_badge_widget.dart`

**Manual Replacement** (complex switch logic):

```dart
// BEFORE (lines ~85-145):
switch (platform) {
  case 'youtube':
    return Color(0xFFFF0000);
  case 'tiktok':
    return Color(0xFF00F2EA);
  // ... etc

// AFTER:
import 'package:butlery/theme/brand_colors.dart';

switch (platform) {
  case 'youtube':
    return BrandColors.youtube;
  case 'tiktok':
    return BrandColors.tiktok;
  // ... etc
```

**Validation**:
```bash
grep "Color(0x" lib/widgets/import/platform_badge_widget.dart | wc -l
# Expected: 0
```

---

## Phase 3: Medium Priority (8 hours)

### Task 3.1: TextStyle fontSize (4 hours)

**37 production instances** - Semi-automated

**Common Patterns**:
```bash
# Pattern 1: fontSize: 14
Find: TextStyle\([^)]*fontSize:\s*14
Replace: AppTextStyles.bodyMedium
Estimated: ~18 instances (but must verify fontWeight, etc.)

# Pattern 2: fontSize: 12
Find: TextStyle\([^)]*fontSize:\s*12
Replace: AppTextStyles.labelMedium
Estimated: ~10 instances
```

**Manual Review Required** (complex TextStyle with multiple properties):
- `lib/widgets/tagging/personal_tag_manager_dialog.dart` (8 instances)
- `lib/widgets/tagging/personal_tag_rule_dialog.dart` (5 instances)

---

### Task 3.2: Border Radius (2 hours)

**73 instances** - Mostly automated

```bash
# Pattern 1: BorderRadius.circular(8)
Find: BorderRadius\.circular\(8\)
Replace: BorderRadius.circular(AppDimensions.borderRadiusM)
Estimated: ~25 instances

# Pattern 2: BorderRadius.circular(12)
Find: BorderRadius\.circular\(12\)
Replace: BorderRadius.circular(AppDimensions.borderRadiusL)
Estimated: ~20 instances

# Pattern 3: BorderRadius.circular(16)
Find: BorderRadius\.circular\(16\)
Replace: BorderRadius.circular(AppDimensions.borderRadius16)
Estimated: ~12 instances

# Pattern 4: Radius.circular(8)
Find: Radius\.circular\(8\)
Replace: Radius.circular(AppDimensions.borderRadiusM)
Estimated: ~15 instances
```

---

### Task 3.3: BoxConstraints (2 hours)

**15 instances with hardcoded max** - Manual

**Common Pattern**:
```dart
// BEFORE
BoxConstraints(maxWidth: 500, maxHeight: 700)

// AFTER
BoxConstraints(
  maxWidth: AppDimensions.dialogMaxWidthMedium,
  maxHeight: AppDimensions.dialogMaxHeightMedium,
)
```

**Files**:
1. `lib/widgets/tagging/personal_tag_rule_dialog.dart`
2. `lib/widgets/tagging/personal_tag_manager_dialog.dart`
3. `lib/widgets/social/groups/create_group_dialog.dart`
4. Plus 11 more dialog files

---

## Phase 4: Cleanup & Validation (8 hours)

### Task 4.1: Shadow Replacements (2 hours)

**15 files** - Manual replacement using new AppShadows

**Pattern** (in discovery dashboard files):
```dart
// BEFORE
boxShadow: [
  BoxShadow(
    color: AppColors.shadow.withValues(alpha: 0.1),  // Already fixed in Phase 1
    blurRadius: 8,
    offset: const Offset(0, 2),
  ),
]

// AFTER
boxShadow: AppShadows.card
```

**Files** (6 discovery dashboard files have identical pattern):
- `lib/views/social/discovery_dashboard/trending_content_section.dart`
- `lib/views/social/discovery_dashboard/recommendations_section.dart`
- `lib/views/social/discovery_dashboard/friend_activity_section.dart`
- `lib/views/social/discovery_dashboard/discovery_categories.dart`
- `lib/views/social/discovery_dashboard/discovery_search_section.dart`
- Plus 9 more files

---

### Task 4.2: Comprehensive Validation (4 hours)

Run complete validation suite:

```bash
#!/bin/bash
# design-system-validation.sh

echo "=== Design System Migration Validation ==="
echo ""

# Test 1: Opacity
OPACITY=$(grep -r "withValues(alpha: 0\." lib/ --include="*.dart" | grep -v "lib/theme/" | wc -l)
echo "[1/8] Opacity hardcoding: $OPACITY"
[ $OPACITY -eq 0 ] && echo "  ✅ PASS" || echo "  ❌ FAIL ($OPACITY remaining)"

# Test 2: EdgeInsets
EDGEINSETS=$(grep -rE "EdgeInsets\.(all|symmetric|only)\([^)]*\d+" lib/ | wc -l)
echo "[2/8] EdgeInsets hardcoding: $EDGEINSETS"
[ $EDGEINSETS -eq 0 ] && echo "  ✅ PASS" || echo "  ❌ FAIL ($EDGEINSETS remaining)"

# Test 3: Icon sizes
ICONS=$(grep -rE "Icon\([^,)]+,\s*size:\s*\d+" lib/ | wc -l)
echo "[3/8] Icon sizes: $ICONS"
[ $ICONS -eq 0 ] && echo "  ✅ PASS" || echo "  ❌ FAIL ($ICONS remaining)"

# Test 4: Brand colors
BRANDS=$(grep "Color(0x" lib/widgets/import/platform_badge_widget.dart | wc -l)
echo "[4/8] Brand colors: $BRANDS"
[ $BRANDS -eq 0 ] && echo "  ✅ PASS" || echo "  ❌ FAIL ($BRANDS remaining)"

# Test 5: BorderRadius
RADIUS=$(grep -rE "(Border)?Radius\.circular\(\d+" lib/ | grep -v "lib/theme/" | wc -l)
echo "[5/8] Border radius: $RADIUS"
[ $RADIUS -eq 0 ] && echo "  ✅ PASS" || echo "  ❌ FAIL ($RADIUS remaining)"

# Test 6: fontSize
FONTSIZE=$(grep -r "fontSize:" lib/ | grep -v "lib/theme/" | grep -v "main" | wc -l)
echo "[6/8] TextStyle fontSize: $FONTSIZE"
[ $FONTSIZE -eq 0 ] && echo "  ✅ PASS" || echo "  ❌ FAIL ($FONTSIZE remaining)"

# Test 7: Shadows
SHADOWS=$(grep -r "blurRadius:\s*\d+" lib/ | grep -v "lib/theme/" | wc -l)
echo "[7/8] BoxShadow hardcoding: $SHADOWS"
[ $SHADOWS -eq 0 ] && echo "  ✅ PASS" || echo "  ❌ FAIL ($SHADOWS remaining)"

# Test 8: Analyze
echo "[8/8] Flutter analyze..."
flutter analyze --no-pub 2>&1 | grep -E "(error|warning)" | wc -l
echo "  Check for new errors/warnings"

TOTAL=$((OPACITY + EDGEINSETS + ICONS + BRANDS + RADIUS + FONTSIZE + SHADOWS))
echo ""
echo "TOTAL HARDCODED VALUES: $TOTAL"
if [ $TOTAL -eq 0 ]; then
  echo "🎉🎉🎉 MIGRATION COMPLETE - 100% THEME-DRIVEN! 🎉🎉🎉"
else
  echo "⚠️  $TOTAL issues remaining - review required"
fi
```

---

### Task 4.3: Visual Regression Testing (2 hours)

**Manual Testing Checklist**:

- [ ] **Light Mode**
  - [ ] Discovery dashboard (all sections)
  - [ ] Recipe cards (list and grid)
  - [ ] Image gallery
  - [ ] Dialogs (tag editor, import, etc.)
  - [ ] Platform badges

- [ ] **Dark Mode** (CRITICAL - opacity changes affect dark mode most)
  - [ ] All screens with opacity usage
  - [ ] Card shadows visible
  - [ ] Overlays working correctly
  - [ ] Text contrast maintained

- [ ] **Responsive Layouts**
  - [ ] Mobile (< 600px)
  - [ ] Tablet (600-1200px)
  - [ ] Desktop (> 1200px)
  - [ ] Dialog sizing appropriate
  - [ ] Content max-widths respected

- [ ] **Interactive Elements**
  - [ ] Button hover states (opacity)
  - [ ] Card shadows on elevation
  - [ ] Icon sizes consistent
  - [ ] Border radius on all cards/dialogs

---

## Phase 5: Documentation & Prevention (4 hours)

### Task 5.1: Add Lint Rules (2 hours)

Create custom lint rules to prevent future hardcoding:

**File**: `analysis_options.yaml` (add to existing)

```yaml
# Custom lint rules for design system enforcement
linter:
  rules:
    # Existing rules...

    # Design system enforcement (via custom lint)
    # Note: These require custom_lint package

# TODO: Implement custom lint rules:
# - no_hardcoded_colors (detect Color(0x...))
# - no_hardcoded_opacity (detect withValues(alpha: 0.))
# - no_hardcoded_dimensions (detect size: <number>)
# - use_theme_constants (suggest AppDimensions/AppColors)
```

**Document for future PR**: Need to implement custom lint package.

---

### Task 5.2: Update Code Review Checklist (1 hour)

**File**: `.github/PULL_REQUEST_TEMPLATE.md` (create or update)

```markdown
## Design System Checklist

Before merging, verify:

- [ ] No hardcoded hex colors (`Color(0x...)`) - use `AppColors.*` or `BrandColors.*`
- [ ] No hardcoded opacity (`.withValues(alpha: 0.X)`) - use `AppDimensions.opacity*`
- [ ] No hardcoded dimensions (`size: 20`, `width: 100`) - use `AppDimensions.*`
- [ ] No hardcoded spacing (`EdgeInsets.all(16)`) - use `AppDimensions.spacing*`
- [ ] No hardcoded border radius (`BorderRadius.circular(8)`) - use `AppDimensions.borderRadius*`
- [ ] No inline `TextStyle(fontSize: ...)` - use `AppTextStyles.*`
- [ ] No hardcoded shadows - use `AppShadows.*`

See `docs/DESIGN_SYSTEM.md` for complete guide.
```

---

### Task 5.3: Team Communication (1 hour)

**Action Items**:

1. **Announce Migration**
   - Slack/Teams message about design system migration
   - Link to `DESIGN_SYSTEM.md`
   - Explain benefits (dark mode, consistency, redesign-ready)

2. **Training Session** (optional)
   - 30-minute walkthrough of design system
   - Show before/after examples
   - Demonstrate IDE snippets for common patterns

3. **IDE Snippets** (create for team)
   ```json
   // VSCode snippets for Flutter (settings.json)
   {
     "Edge Insets Symmetric": {
       "prefix": "edgeh",
       "body": "EdgeInsets.symmetric(horizontal: AppDimensions.$1, vertical: AppDimensions.$2)"
     },
     "Opacity": {
       "prefix": "opacity",
       "body": "withValues(alpha: AppDimensions.opacity$1)"
     },
     "Icon with Size": {
       "prefix": "icon",
       "body": "Icon(Icons.$1, size: AppDimensions.iconSize$2)"
     }
   }
   ```

---

## Success Metrics

### Pre-Migration Baseline
- ❌ ~779 hardcoded design values
- ❌ Inconsistent opacity usage (464+ instances)
- ❌ Platform brand colors scattered
- ❌ No shadow library
- ❌ Dark mode fragile

### Post-Migration Target
- ✅ 0 hardcoded design values
- ✅ Consistent opacity via AppDimensions
- ✅ Centralized brand colors
- ✅ Complete shadow library
- ✅ Dark mode robust
- ✅ 100% theme-driven design
- ✅ Ready for complete redesign

---

## Risk Mitigation

### Potential Issues

1. **Visual Regressions**
   - Mitigation: Extensive manual testing, screenshot comparison
   - Rollback: Keep PR branch alive for 1 week

2. **Dark Mode Breaks**
   - Mitigation: Test all opacity changes in dark mode
   - Specific focus: Discovery dashboard, image overlays

3. **Performance Impact**
   - Mitigation: AppDimensions are compile-time constants (zero runtime cost)
   - Validation: Profile before/after

4. **Merge Conflicts**
   - Mitigation: Coordinate with team, block other design PRs
   - Strategy: Complete migration in 1 week to minimize conflict window

---

## Timeline

| Phase | Duration | Start | End | Deliverable |
|-------|----------|-------|-----|-------------|
| **Phase 0: Foundation** | 4 hours | Day 1 AM | Day 1 PM | BrandColors, AppShadows, docs |
| **Phase 1: Opacity** | 8 hours | Day 2 | Day 2 | 477 → 0 opacity issues |
| **Phase 2: High Priority** | 12 hours | Day 3-4 | Day 4 | EdgeInsets, icons, brands fixed |
| **Phase 3: Medium Priority** | 8 hours | Day 5 | Day 5 | fontSize, radius, constraints |
| **Phase 4: Validation** | 8 hours | Day 6 | Day 6 | Testing & validation |
| **Phase 5: Prevention** | 4 hours | Day 7 | Day 7 | Docs, lint rules, training |
| **TOTAL** | **40 hours** | Day 1 | Day 7 | 100% theme-driven |

**Recommended**: Allocate 1.5 weeks for safety margin and unexpected issues.

---

## Checklist

### Pre-Migration
- [ ] Backup current codebase (git branch)
- [ ] Communicate migration plan to team
- [ ] Block conflicting design PRs
- [ ] Create migration branch: `feat/design-system-migration`

### Phase 0
- [ ] Create `lib/theme/brand_colors.dart`
- [ ] Create `lib/theme/app_shadows.dart`
- [ ] Extend `lib/theme/app_dimensions.dart`
- [ ] Create `docs/DESIGN_SYSTEM.md`
- [ ] Commit and push

### Phase 1
- [ ] Run 8 opacity find/replace operations
- [ ] Fix theme component files (8 instances)
- [ ] Validate: 0 hardcoded opacity
- [ ] Run `flutter analyze`
- [ ] Visual test dark mode
- [ ] Commit and push

### Phase 2
- [ ] Fix 88 EdgeInsets instances
- [ ] Fix 47 Icon sizes
- [ ] Fix 15 platform brand colors
- [ ] Validate each category
- [ ] Visual test affected components
- [ ] Commit and push

### Phase 3
- [ ] Fix 37 fontSize instances
- [ ] Fix 73 border radius instances
- [ ] Fix 15 BoxConstraints
- [ ] Validate each category
- [ ] Commit and push

### Phase 4
- [ ] Replace 15 shadow definitions
- [ ] Run comprehensive validation script
- [ ] Complete visual regression testing checklist
- [ ] Test on 3 devices (mobile, tablet, desktop)
- [ ] Commit and push

### Phase 5
- [ ] Update analysis_options.yaml
- [ ] Create PR template
- [ ] Create IDE snippets
- [ ] Update team documentation
- [ ] Announce completion

### Post-Migration
- [ ] Create PR for review
- [ ] Address review feedback
- [ ] Merge to main
- [ ] Monitor for issues (1 week)
- [ ] Archive migration branch

---

## Support & Questions

**Migration Owner**: [Assign team member]
**Design System SME**: [Assign team member]
**Questions**: Create issue with `design-system` label

---

## Appendix: Common Replacements Quick Reference

```dart
// Opacity
.withValues(alpha: 0.1) → .withValues(alpha: AppDimensions.opacityVeryLight)
.withValues(alpha: 0.5) → .withValues(alpha: AppDimensions.opacityHalf)

// Icon Sizes
Icon(Icons.add, size: 20) → Icon(Icons.add, size: AppDimensions.iconSizeM)

// Spacing
EdgeInsets.all(16) → EdgeInsets.all(AppDimensions.spacingMd)

// Border Radius
BorderRadius.circular(8) → BorderRadius.circular(AppDimensions.borderRadiusM)

// Typography
TextStyle(fontSize: 14) → AppTextStyles.bodyMedium

// Shadows
boxShadow: [...] → boxShadow: AppShadows.card

// Brand Colors
Color(0xFFFF0000) → BrandColors.youtube
```

---

**Document Version**: 1.0
**Last Updated**: 2026-01-11
**Status**: Ready for Execution
