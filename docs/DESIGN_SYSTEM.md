# Butlery Design System Guide

**Last Updated**: 2026-01-11
**Status**: Active - 100% Theme-Driven

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

### Border Radius

```dart
// ❌ BAD
borderRadius: BorderRadius.circular(8)

// ✅ GOOD
borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)
```

### Brand Colors

```dart
// ❌ BAD
color: Color(0xFFFF0000)  // YouTube red

// ✅ GOOD
color: BrandColors.youtube
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
- `spacing6` = 6px
- `spacingSm` = 8px
- `spacingMd` = 16px
- `spacingLg` = 24px
- `spacingXl` = 32px
- `spacingXxl` = 48px

### AppDimensions.padding*

- `paddingXxs` = 2px
- `paddingS` = 8px
- `paddingM` = 12px
- `paddingL` = 16px
- `paddingXl` = 20px

### AppDimensions.borderRadius*

- `borderRadiusXs` = 2px
- `borderRadiusS` = 4px
- `borderRadius6` = 6px
- `borderRadiusM` = 8px
- `borderRadiusL` = 12px
- `borderRadius16` = 16px
- `borderRadius20` = 20px
- `borderRadiusRound` = 50px
- `borderRadius100` = 100px

### AppShadows

- `AppShadows.subtle` - Minimal elevation (~1dp)
- `AppShadows.card` - Standard card shadow (~2dp)
- `AppShadows.elevated` - Dialog/modal shadow (~4dp)
- `AppShadows.floating` - FAB shadow (~8dp)

### BrandColors

**Social Media**:
- `BrandColors.youtube`, `twitter`, `instagram`, `facebook`
- `BrandColors.tiktok`, `pinterest`, `whatsapp`, `telegram`, `reddit`

**Swedish Recipe Platforms**:
- `BrandColors.allrecipes`, `ica`, `coop`, `arla`, `koketSe`

**Fallback**:
- `BrandColors.generic` - Neutral gray for unknown platforms

## Architecture Integration

### File Locations

- **Theme Files**: `lib/theme/`
  - `app_colors.dart` - Color palette
  - `app_dimensions.dart` - Spacing, sizing, opacity
  - `app_text_styles.dart` - Typography
  - `app_shadows.dart` - Shadow definitions
  - `brand_colors.dart` - Platform brand colors

### Import Pattern

```dart
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_shadows.dart';
import 'package:butlery/theme/brand_colors.dart';
```

## Benefits

### Consistency
All components use the same design tokens, ensuring visual cohesion.

### Dark Mode
Opacity constants work perfectly with both light and dark themes.

### Redesign-Ready
Change a single constant to update the entire app.

### Type Safety
Compile-time constants prevent typos and runtime errors.

### Performance
Zero runtime cost - all constants are compile-time evaluated.

## Migration Status

✅ **100% Theme-Driven** (as of 2026-01-11)
- 0 hardcoded opacity values
- 0 hardcoded colors (except semantic theme colors)
- 0 hardcoded dimensions
- Complete shadow library
- Centralized brand colors

See `/docs/architecture/DESIGN_SYSTEM_MIGRATION_PLAN.md` for migration history.
