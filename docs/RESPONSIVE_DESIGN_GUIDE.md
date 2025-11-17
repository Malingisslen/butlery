# Responsive Design Guide

**Version**: 1.0
**Last Updated**: 2025-11-17
**Status**: Phase 3 Complete (10/10 tier 1 views)

## Table of Contents

1. [Overview](#overview)
2. [Breakpoint System](#breakpoint-system)
3. [Responsive Utilities](#responsive-utilities)
4. [The Center + ConstrainedBox Pattern](#the-center--constrainedbox-pattern)
5. [Content Width Strategy](#content-width-strategy)
6. [Common Patterns](#common-patterns)
7. [Real-World Examples](#real-world-examples)
8. [Testing Responsive Layouts](#testing-responsive-layouts)

---

## Overview

Butlery's responsive design system enables the app to provide excellent user experiences across mobile phones, tablets, and desktop screens. The system follows **Material Design 3** guidelines and provides a consistent, maintainable approach to responsive layouts.

### Key Principles

1. **Mobile-First**: Start with mobile layout, enhance for larger screens
2. **Progressive Enhancement**: Add features/layout changes as screen size increases
3. **Consistent Patterns**: Use the same responsive approach across all views
4. **Content-Appropriate Width**: Match max width to content type and reading comfort
5. **Adaptive Navigation**: Automatically switch navigation patterns (bottom nav → rail)

### Device Categories

The responsive system supports 6 device categories:

| Category | Width Range | Typical Devices |
|----------|-------------|-----------------|
| **mobile** | 0-599px | Small phones |
| **mobileLarge** | 600-767px | Large phones |
| **tablet** | 768-1023px | Tablets (portrait) |
| **tabletLarge** | 1024-1279px | Tablets (landscape) |
| **desktop** | 1280-1919px | Laptops, small monitors |
| **desktopLarge** | 1920px+ | Large monitors, 4K displays |

### Architecture Components

```
lib/core/responsive/
├── breakpoints.dart          # Core breakpoint system
└── responsive_builder.dart   # Responsive widget builders

lib/widgets/common/responsive/
├── responsive_grid.dart      # Grid components
└── adaptive_navigation.dart  # Navigation patterns

lib/theme/
└── app_dimensions.dart       # Responsive utilities
```

---

## Breakpoint System

### Core Breakpoints

The breakpoint system is defined in `lib/core/responsive/breakpoints.dart`:

```dart
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 768;
  static const double tabletLarge = 1024;
  static const double desktop = 1280;
  static const double desktopLarge = 1920;
}
```

### Device Category Detection

```dart
// Check device category
if (Breakpoints.isMobile(context)) {
  // Mobile-specific layout
}

if (Breakpoints.isTablet(context)) {
  // Tablet-specific layout
}

if (Breakpoints.isDesktop(context)) {
  // Desktop-specific layout
}
```

### Responsive Value Selection

Use `LayoutComponents.valueFor()` for responsive values:

```dart
final maxWidth = LayoutComponents.valueFor(
  context: context,
  mobile: double.infinity,    // Full width on mobile
  tablet: 700,                // 700px max on tablet
  desktop: 800,               // 800px max on desktop
);

final spacing = LayoutComponents.valueFor(
  context: context,
  mobile: 16.0,
  tablet: 24.0,
  desktop: 32.0,
);
```

**Fallback behavior**: If a breakpoint value isn't provided, the system falls back gracefully:
- `desktop` → `tabletLarge` → `tablet` → `mobileLarge` → `mobile`

---

## Responsive Utilities

### AppDimensions Responsive Utilities

`lib/theme/app_dimensions.dart` provides comprehensive responsive utilities:

#### Content Padding

```dart
// Horizontal padding: 16px → 24px → 32px
final padding = AppDimensions.responsiveContentPadding(context);

// Use in widgets:
Padding(
  padding: AppDimensions.responsiveContentPadding(context),
  child: child,
)
```

#### Grid Spacing

```dart
// Grid spacing: 12px → 16px → 20px
final spacing = AppDimensions.responsiveGridSpacing(context);
```

#### Card Elevation

```dart
// Card elevation: 1 → 2 → 3
final elevation = AppDimensions.responsiveCardElevation(context);
```

#### Icon Size

```dart
// Icon size: 24px → 28px → 32px
final iconSize = AppDimensions.responsiveIconSize(context);
```

#### Border Radius

```dart
// Border radius: 8px → 12px → 16px
final radius = AppDimensions.responsiveBorderRadius(context);
```

### LayoutComponents Utilities

`lib/widgets/common/layout_components.dart` provides high-level layout utilities:

```dart
// Device category checks
LayoutComponents.isMobile(context);
LayoutComponents.isTablet(context);
LayoutComponents.isDesktop(context);

// Responsive value selection
LayoutComponents.valueFor(
  context: context,
  mobile: value1,
  tablet: value2,
  desktop: value3,
);

// Grid column count: 1 → 2 → 3
final columns = LayoutComponents.getGridColumns(context);
```

---

## The Center + ConstrainedBox Pattern

**This is the primary pattern for making views responsive in Butlery.**

### Basic Pattern

```dart
Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: LayoutComponents.valueFor(
        context: context,
        mobile: double.infinity,  // Full width on mobile
        tablet: 700,              // Constrained on tablet
        desktop: 800,             // Constrained on desktop
      ),
    ),
    child: Padding(
      padding: AppDimensions.responsiveContentPadding(context),
      child: /* Your content here */,
    ),
  ),
)
```

### Why This Pattern?

1. **Center**: Horizontally centers content on large screens
2. **ConstrainedBox**: Limits maximum width for better readability
3. **Padding**: Adds responsive spacing around content
4. **double.infinity on mobile**: Content uses full width on small screens
5. **Fixed max width on tablet/desktop**: Content doesn't stretch too wide

### Visual Effect

```
Mobile (< 600px):           Tablet (768px):          Desktop (1920px):
┌──────────────┐           ┌───────────────────┐    ┌─────────────────────────────┐
│              │           │  ┌───────────┐   │    │         ┌───────────┐        │
│  Full Width  │           │  │ Max 700px │   │    │         │ Max 800px │        │
│   Content    │           │  │  Content  │   │    │         │  Content  │        │
│              │           │  └───────────┘   │    │         └───────────┘        │
└──────────────┘           └───────────────────┘    └─────────────────────────────┘
```

---

## Content Width Strategy

Different view types need different optimal widths for best user experience:

### Narrow Width (500-600px)

**Use cases**: Authentication, dialogs, simple forms
**Why**: Optimal reading width, focused user input, single-column focus

```dart
constraints: BoxConstraints(
  maxWidth: LayoutComponents.valueFor(
    context: context,
    mobile: double.infinity,
    tablet: 500,
    desktop: 600,
  ),
),
```

**Examples**:
- `auth_view.dart` - Login/signup forms
- Loading overlays and dialogs
- Simple confirmation screens

### Medium Width (700-800px)

**Use cases**: Import flows, creation forms, detail views
**Why**: Balance between readability and content density

```dart
constraints: BoxConstraints(
  maxWidth: LayoutComponents.valueFor(
    context: context,
    mobile: double.infinity,
    tablet: 700,
    desktop: 800,
  ),
),
```

**Examples**:
- `lagg_till_recept_view.dart` - Recipe addition menu
- `file_import_view.dart` - File import interface
- `recipe_detail_view.dart` - Recipe detail page
- `edit_recipe_view.dart` - Recipe editing form
- `skriv_sjalv_recept_view.dart` - Manual recipe creation
- `unified_shopping_view.dart` - Shopping list

### Wide Width (900-1200px)

**Use cases**: Complex layouts, discovery feeds, menu planning
**Why**: Need horizontal space for multi-column content

```dart
constraints: BoxConstraints(
  maxWidth: LayoutComponents.valueFor(
    context: context,
    mobile: double.infinity,
    tablet: 900,
    desktop: 1200,
  ),
),
```

**Examples**:
- `veckomeny_view.dart` - Weekly menu planner
- `discovery_dashboard_view.dart` - Social discovery feed

### Adaptive Grid (No Fixed Width)

**Use cases**: Content lists, galleries, card grids
**Why**: Maximize screen real estate with responsive columns

```dart
ResponsiveListGrid(
  items: items,
  itemBuilder: (context, item) => RecipeCard(recipe: item),
  gridAspectRatio: 0.75,  // Cards are taller than wide
  // Automatically adjusts: 1 column → 2 columns → 3 columns
)
```

**Examples**:
- `mina_recept_view.dart` - Recipe list/grid

---

## Common Patterns

### Pattern 1: Basic View with Centered Content

**Use for**: Most standard views (forms, lists, detail pages)

```dart
class MyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My View')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 700,
                desktop: 800,
              ),
            ),
            child: Padding(
              padding: AppDimensions.responsiveContentPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Content here'),
                  // ... more content
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

### Pattern 2: Scrollable Content with Constraints

**Use for**: Long-form content, forms, detail views

```dart
SingleChildScrollView(
  child: Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: LayoutComponents.valueFor(
          context: context,
          mobile: double.infinity,
          tablet: 800,
          desktop: 900,
        ),
      ),
      child: Padding(
        padding: AppDimensions.responsiveContentPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... scrollable content
          ],
        ),
      ),
    ),
  ),
)
```

### Pattern 3: CustomScrollView with Slivers

**Use for**: Complex scrolling layouts with app bars, tabs

```dart
CustomScrollView(
  slivers: [
    SliverAppBar(/* ... */),

    // Constrained sliver content
    SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: LayoutComponents.valueFor(
              context: context,
              mobile: double.infinity,
              tablet: 900,
              desktop: 1200,
            ),
          ),
          child: Padding(
            padding: AppDimensions.responsiveContentPadding(context),
            child: Column(children: [/* ... */]),
          ),
        ),
      ),
    ),
  ],
)
```

### Pattern 4: Responsive Loading Overlay

**Use for**: Loading states over forms or content

```dart
Stack(
  children: [
    // Main content (constrained as usual)
    Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800),
        child: MyForm(),
      ),
    ),

    // Loading overlay (narrower constraint for visual hierarchy)
    if (isLoading)
      ColoredBox(
        color: AppColors.backgroundBeige.withValues(alpha: 0.8),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 500,
                desktop: 600,
              ),
            ),
            child: StateWidget.loading(message: 'Loading...'),
          ),
        ),
      ),
  ],
)
```

### Pattern 5: Responsive Grid

**Use for**: Recipe lists, image galleries, card grids

```dart
ResponsiveListGrid(
  items: recipes,
  itemBuilder: (context, recipe) => RecipeCard(recipe: recipe),
  gridAspectRatio: 0.75,  // Aspect ratio for grid items
  // Automatically switches:
  // - Mobile: 1 column ListView
  // - Tablet: 2 column GridView
  // - Desktop: 3 column GridView
)
```

### Pattern 6: Responsive Spacing

**Use for**: Vertical spacing that adapts to screen size

```dart
Column(
  children: [
    Widget1(),
    SizedBox(
      height: LayoutComponents.valueFor(
        context: context,
        mobile: AppDimensions.spacingL,      // 24px
        tablet: AppDimensions.spacingXl,     // 36px
        desktop: AppDimensions.spacingXl * 1.5,  // 54px
      ),
    ),
    Widget2(),
  ],
)
```

### Pattern 7: Responsive Text Alignment

**Use for**: Headings that should center on desktop

```dart
Text(
  'Heading',
  style: AppTextStyles.headlineSmall,
  textAlign: LayoutComponents.isDesktop(context)
      ? TextAlign.center
      : TextAlign.start,
)
```

---

## Real-World Examples

### Example 1: Authentication View

**File**: `lib/views/auth_view.dart`
**Width Strategy**: Narrow (500-600px)

```dart
body: Consumer<AuthViewModel>(
  builder: (context, viewModel, _) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: LayoutComponents.valueFor(
            context: context,
            mobile: double.infinity,
            tablet: 500,
            desktop: 600,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: AppDimensions.responsiveContentPadding(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeader(context),
                SizedBox(
                  height: LayoutComponents.valueFor(
                    context: context,
                    mobile: AppDimensions.spacingXxl,
                    tablet: AppDimensions.spacingXxl * 1.5,
                    desktop: AppDimensions.spacingXxl * 2,
                  ),
                ),
                _buildAuthCard(context, viewModel),
              ],
            ),
          ),
        ),
      ),
    );
  },
)
```

**Key features**:
- Narrow max width for focused auth form
- Responsive spacing between header and form (2x → 1.5x → 2x)
- Centered layout on all devices
- Scrollable for small screens

### Example 2: Recipe List with Grid

**File**: `lib/views/mina_recept_view.dart`
**Width Strategy**: Adaptive Grid (no constraint)

```dart
body: Consumer<MinaReceptViewModel>(
  builder: (context, viewModel, child) {
    return ResponsiveListGrid(
      items: viewModel.recipes,
      itemBuilder: (context, recipe) => RecipeCard(
        recipe: recipe,
        onTap: () => _navigateToRecipe(context, recipe),
      ),
      gridAspectRatio: 0.75,  // Recipe cards are taller than wide
      emptyWidget: Center(
        child: Text('Inga recept'),
      ),
    );
  },
)
```

**Key features**:
- Automatic column adjustment: 1 → 2 → 3 columns
- ListView on mobile, GridView on tablet/desktop
- Responsive spacing between items
- No manual breakpoint handling needed

### Example 3: Complex View with Tabs

**File**: `lib/views/social/discovery_dashboard_view.dart`
**Width Strategy**: Wide (900-1200px)

```dart
Widget _buildTabBar(BuildContext context, DiscoveryDashboardViewModel viewModel) {
  return SliverToBoxAdapter(
    child: ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: LayoutComponents.valueFor(
              context: context,
              mobile: double.infinity,
              tablet: 900,
              desktop: 1200,
            ),
          ),
          child: Container(
            margin: AppDimensions.responsiveHorizontalPadding(context),
            decoration: BoxDecoration(/* ... */),
            child: TabBar(/* ... */),
          ),
        ),
      ),
    ),
  );
}

Widget _buildDiscoveryTab(BuildContext context, DiscoveryDashboardViewModel viewModel) {
  return SingleChildScrollView(
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: LayoutComponents.valueFor(
            context: context,
            mobile: double.infinity,
            tablet: 900,
            desktop: 1200,
          ),
        ),
        child: Padding(
          padding: AppDimensions.responsiveContentPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search UI
              _buildSearchBar(context, viewModel),
              SizedBox(height: AppDimensions.spacingL),

              // Search results
              if (viewModel.isSearching) ...[
                _buildSearchResults(context, viewModel),
              ] else ...[
                _buildDefaultContent(context, viewModel),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
```

**Key features**:
- Wide layout for complex social feed
- Consistent constraints across tab bar and all tabs
- Responsive padding and spacing
- All 3 tabs use same pattern (Discovery, Activity, Recommendations)

### Example 4: Form with Loading Overlay

**File**: `lib/views/edit_recipe_view.dart`
**Width Strategy**: Medium (800-900px) + Narrow overlay (500-600px)

```dart
body: Stack(
  children: [
    // Main form content
    Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: LayoutComponents.valueFor(
            context: context,
            mobile: double.infinity,
            tablet: 800,
            desktop: 900,
          ),
        ),
        child: Column(
          children: [
            _buildSmartBanners(context, widget.recipe),
            Expanded(
              child: Padding(
                padding: AppDimensions.responsiveContentPadding(context),
                child: Form(
                  key: _formKey,
                  child: ListView(/* form fields */),
                ),
              ),
            ),
          ],
        ),
      ),
    ),

    // Loading overlay (narrower for visual hierarchy)
    if (viewModel.isSaving)
      ColoredBox(
        color: AppColors.backgroundBeige.withValues(alpha: 0.8),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 500,
                desktop: 600,
              ),
            ),
            child: StateWidget.loading(message: 'Uppdaterar recept...'),
          ),
        ),
      ),
  ],
)
```

**Key features**:
- Medium width for recipe editing form
- Narrower overlay for loading state (visual hierarchy)
- Full-screen Stack pattern with responsive constraints
- Maintains form usability across all screen sizes

---

## Testing Responsive Layouts

### Manual Testing

**Test on multiple screen sizes**:

1. **Mobile** (360x640, 375x667, 414x896)
   - iPhone SE, iPhone 8, iPhone 11 Pro Max
   - Check: Full-width content, appropriate padding

2. **Tablet** (768x1024, 834x1112, 1024x1366)
   - iPad, iPad Pro
   - Check: Centered content, max width applied, navigation rail

3. **Desktop** (1280x720, 1920x1080, 2560x1440)
   - Laptop, desktop monitor, 4K display
   - Check: Content centered, reasonable max width, not too wide

### Flutter DevTools

Use Flutter DevTools to test responsive layouts:

```bash
flutter run -d chrome
```

1. Open DevTools in browser
2. Use device toolbar to test different screen sizes
3. Use responsive design mode to test custom dimensions

### Widget Tests

Test responsive behavior in widget tests:

```dart
testWidgets('View is responsive on tablet', (WidgetTester tester) async {
  // Set tablet screen size
  tester.binding.window.physicalSizeTestValue = Size(768, 1024);
  tester.binding.window.devicePixelRatioTestValue = 1.0;
  addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

  await tester.pumpWidget(MyApp());

  // Test that max width constraint is applied
  final constrainedBox = tester.widget<ConstrainedBox>(
    find.byType(ConstrainedBox),
  );

  expect(constrainedBox.constraints.maxWidth, 700);
});
```

### Checklist for New Responsive Views

- [ ] Import `LayoutComponents` and `AppDimensions`
- [ ] Apply Center + ConstrainedBox pattern
- [ ] Use appropriate content width strategy
- [ ] Apply responsive padding with `AppDimensions.responsiveContentPadding()`
- [ ] Test on mobile, tablet, and desktop screen sizes
- [ ] Check that navigation adapts correctly (bottom nav → rail)
- [ ] Verify loading states and overlays are responsive
- [ ] Ensure text alignment is appropriate for each screen size
- [ ] Test scrolling behavior on small and large screens
- [ ] Run `flutter analyze` to check for issues

---

## Quick Reference Card

### Import Statement
```dart
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/theme/app_dimensions.dart';
```

### Basic Responsive Pattern
```dart
Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: LayoutComponents.valueFor(
        context: context,
        mobile: double.infinity,
        tablet: 700,
        desktop: 800,
      ),
    ),
    child: Padding(
      padding: AppDimensions.responsiveContentPadding(context),
      child: /* content */,
    ),
  ),
)
```

### Content Width Guidelines
- **Narrow (500-600px)**: Auth, dialogs, simple forms
- **Medium (700-800px)**: Import, creation, detail views
- **Wide (900-1200px)**: Complex layouts, discovery, planning
- **Adaptive Grid**: Lists, galleries (no fixed width)

### Device Category Checks
```dart
LayoutComponents.isMobile(context)   // < 600px
LayoutComponents.isTablet(context)   // 768-1023px
LayoutComponents.isDesktop(context)  // ≥ 1280px
```

### Responsive Utilities
```dart
AppDimensions.responsiveContentPadding(context)    // 16→24→32px
AppDimensions.responsiveGridSpacing(context)       // 12→16→20px
AppDimensions.responsiveCardElevation(context)     // 1→2→3
AppDimensions.responsiveIconSize(context)          // 24→28→32px
AppDimensions.responsiveBorderRadius(context)      // 8→12→16px
```

---

## Migration Guide

See `docs/RESPONSIVE_BEST_PRACTICES.md` for detailed migration guide and anti-patterns to avoid.

## Related Documentation

- **Progress Report**: `.claude/analysis/RESPONSIVE_PHASE3_PROGRESS.md`
- **Best Practices**: `docs/RESPONSIVE_BEST_PRACTICES.md` (to be created)
- **CLAUDE.md**: Project-wide responsive design patterns
