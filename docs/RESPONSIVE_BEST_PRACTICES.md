# Responsive Design Best Practices

**Version**: 1.0
**Last Updated**: 2025-11-17
**Related**: [Responsive Design Guide](RESPONSIVE_DESIGN_GUIDE.md)

## Table of Contents

1. [Quick Do's and Don'ts](#quick-dos-and-donts)
2. [Common Anti-Patterns](#common-anti-patterns)
3. [Performance Considerations](#performance-considerations)
4. [Migration Guide](#migration-guide)
5. [Testing Best Practices](#testing-best-practices)
6. [Troubleshooting](#troubleshooting)

---

## Quick Do's and Don'ts

### ✅ DO

**Always use the Center + ConstrainedBox pattern:**
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

**Use responsive utilities from AppDimensions:**
```dart
// ✅ Good
padding: AppDimensions.responsiveContentPadding(context),

// ✅ Good
spacing: AppDimensions.responsiveGridSpacing(context),

// ✅ Good
elevation: AppDimensions.responsiveCardElevation(context),
```

**Use LayoutComponents for responsive values:**
```dart
// ✅ Good
final maxWidth = LayoutComponents.valueFor(
  context: context,
  mobile: double.infinity,
  tablet: 700,
  desktop: 800,
);
```

**Import the correct packages:**
```dart
// ✅ Good - Always import these for responsive views
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/theme/app_dimensions.dart';
```

**Use ResponsiveListGrid for lists/galleries:**
```dart
// ✅ Good - Auto-adjusts columns
ResponsiveListGrid(
  items: recipes,
  itemBuilder: (context, recipe) => RecipeCard(recipe: recipe),
  gridAspectRatio: 0.75,
)
```

**Test on all screen sizes:**
```dart
// ✅ Good - Test mobile, tablet, desktop
// - Mobile: 360x640, 375x667, 414x896
// - Tablet: 768x1024, 834x1112, 1024x1366
// - Desktop: 1280x720, 1920x1080, 2560x1440
```

---

### ❌ DON'T

**Don't use hardcoded padding/spacing:**
```dart
// ❌ Bad - Hardcoded padding
Padding(
  padding: EdgeInsets.all(16),
  child: child,
)

// ✅ Good - Responsive padding
Padding(
  padding: AppDimensions.responsiveContentPadding(context),
  child: child,
)
```

**Don't use MediaQuery.of(context).size.width directly:**
```dart
// ❌ Bad - Manual width checking
final width = MediaQuery.of(context).size.width;
final columns = width > 1280 ? 3 : width > 768 ? 2 : 1;

// ✅ Good - Use LayoutComponents
final columns = LayoutComponents.getGridColumns(context);
```

**Don't forget to constrain width on large screens:**
```dart
// ❌ Bad - Content stretches too wide on desktop
body: Padding(
  padding: EdgeInsets.all(16),
  child: Column(children: [...]),
)

// ✅ Good - Constrained for readability
body: Center(
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
      child: Column(children: [...]),
    ),
  ),
)
```

**Don't use wrong max width for content type:**
```dart
// ❌ Bad - Auth form too wide
constraints: BoxConstraints(maxWidth: 1200)  // Too wide for a login form!

// ✅ Good - Appropriate width for auth
constraints: BoxConstraints(
  maxWidth: LayoutComponents.valueFor(
    context: context,
    mobile: double.infinity,
    tablet: 500,
    desktop: 600,
  ),
)
```

**Don't forget mobile fallback:**
```dart
// ❌ Bad - No mobile value (will fallback but not ideal)
maxWidth: LayoutComponents.valueFor(
  context: context,
  tablet: 700,
  desktop: 800,
)

// ✅ Good - Explicit mobile value
maxWidth: LayoutComponents.valueFor(
  context: context,
  mobile: double.infinity,  // Explicit mobile behavior
  tablet: 700,
  desktop: 800,
)
```

**Don't nest multiple ConstrainedBox unnecessarily:**
```dart
// ❌ Bad - Nested constraints conflict
ConstrainedBox(
  constraints: BoxConstraints(maxWidth: 800),
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: 600),  // Inner constraint wins
    child: content,
  ),
)

// ✅ Good - Single constraint at appropriate level
ConstrainedBox(
  constraints: BoxConstraints(maxWidth: 800),
  child: content,
)
```

---

## Common Anti-Patterns

### Anti-Pattern 1: Hardcoding Breakpoints

**Problem**: Directly checking screen width instead of using utilities.

```dart
// ❌ Anti-pattern
final screenWidth = MediaQuery.of(context).size.width;
if (screenWidth > 1280) {
  // Desktop layout
} else if (screenWidth > 768) {
  // Tablet layout
} else {
  // Mobile layout
}
```

**Solution**: Use LayoutComponents device category checks.

```dart
// ✅ Best practice
if (LayoutComponents.isDesktop(context)) {
  // Desktop layout
} else if (LayoutComponents.isTablet(context)) {
  // Tablet layout
} else {
  // Mobile layout
}
```

**Why**: Breakpoints are centralized and maintainable. If we change breakpoint values, all code updates automatically.

---

### Anti-Pattern 2: Not Constraining Loading Overlays

**Problem**: Loading overlays stretch full width on desktop, looking awkward.

```dart
// ❌ Anti-pattern
if (isLoading)
  ColoredBox(
    color: Colors.black.withValues(alpha: 0.5),
    child: Center(
      child: CircularProgressIndicator(),  // Centered but no width constraint
    ),
  ),
```

**Solution**: Constrain overlays separately from main content.

```dart
// ✅ Best practice
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
```

**Why**: Visual hierarchy - overlays should be narrower than main content for better UX.

---

### Anti-Pattern 3: Inconsistent Padding

**Problem**: Mixing hardcoded padding with responsive padding.

```dart
// ❌ Anti-pattern
Column(
  children: [
    Padding(
      padding: EdgeInsets.all(16),  // Hardcoded
      child: Widget1(),
    ),
    Padding(
      padding: AppDimensions.responsiveContentPadding(context),  // Responsive
      child: Widget2(),
    ),
  ],
)
```

**Solution**: Use responsive padding consistently.

```dart
// ✅ Best practice
Column(
  children: [
    Padding(
      padding: AppDimensions.responsiveContentPadding(context),
      child: Widget1(),
    ),
    Padding(
      padding: AppDimensions.responsiveContentPadding(context),
      child: Widget2(),
    ),
  ],
)
```

**Why**: Consistent spacing across all screen sizes improves visual polish.

---

### Anti-Pattern 4: Wrong Width for Content Type

**Problem**: Using the same max width for all views regardless of content.

```dart
// ❌ Anti-pattern - Same width for everything
// Auth form
constraints: BoxConstraints(maxWidth: 900)  // Too wide!

// Discovery feed
constraints: BoxConstraints(maxWidth: 600)  // Too narrow!
```

**Solution**: Match width to content type using content width strategy.

```dart
// ✅ Best practice - Appropriate widths

// Auth form (Narrow: 500-600px)
constraints: BoxConstraints(
  maxWidth: LayoutComponents.valueFor(
    context: context,
    mobile: double.infinity,
    tablet: 500,
    desktop: 600,
  ),
)

// Discovery feed (Wide: 900-1200px)
constraints: BoxConstraints(
  maxWidth: LayoutComponents.valueFor(
    context: context,
    mobile: double.infinity,
    tablet: 900,
    desktop: 1200,
  ),
)
```

**Why**: Different content types need different optimal widths for best UX.

---

### Anti-Pattern 5: Not Using SafeArea

**Problem**: Content hidden behind system UI (notches, home indicators).

```dart
// ❌ Anti-pattern
body: Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: 800),
    child: Column(children: [...]),
  ),
)
```

**Solution**: Always wrap in SafeArea for mobile views.

```dart
// ✅ Best practice
body: SafeArea(
  child: Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 800),
      child: Column(children: [...]),
    ),
  ),
)
```

**Why**: Prevents content from being hidden behind notches and system UI.

---

### Anti-Pattern 6: Manual ListView → GridView Switching

**Problem**: Manually checking breakpoints to switch between list and grid.

```dart
// ❌ Anti-pattern
body: LayoutComponents.isTablet(context) || LayoutComponents.isDesktop(context)
    ? GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: LayoutComponents.isDesktop(context) ? 3 : 2,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => ItemCard(item: items[index]),
      )
    : ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) => ItemCard(item: items[index]),
      ),
```

**Solution**: Use ResponsiveListGrid component.

```dart
// ✅ Best practice
body: ResponsiveListGrid(
  items: items,
  itemBuilder: (context, item) => ItemCard(item: item),
  gridAspectRatio: 0.75,
  // Automatically: 1 column → 2 columns → 3 columns
)
```

**Why**: Cleaner code, automatic column adjustment, consistent behavior.

---

## Performance Considerations

### 1. Avoid Rebuilding on Every Resize

**Problem**: Responsive utilities call `MediaQuery.of(context)` which rebuilds on window resize.

**Solution**: Use `MediaQuery.of(context).size` sparingly and cache results when possible.

```dart
// ⚠️ Rebuilds on every resize
@override
Widget build(BuildContext context) {
  final maxWidth = LayoutComponents.valueFor(
    context: context,
    mobile: double.infinity,
    tablet: 700,
    desktop: 800,
  );

  // Heavy computation here...

  return ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth));
}
```

**Optimization**: If you have expensive computations, consider memoization or splitting into separate widgets.

```dart
// ✅ Better - Heavy computation in separate widget
@override
Widget build(BuildContext context) {
  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: LayoutComponents.valueFor(
          context: context,
          mobile: double.infinity,
          tablet: 700,
          desktop: 800,
        ),
      ),
      child: ExpensiveWidget(),  // Only rebuilds when its inputs change
    ),
  );
}
```

---

### 2. Use ResponsiveBuilder for Complex Layouts

For views with completely different layouts on different screen sizes, use `ResponsiveBuilder`:

```dart
ResponsiveBuilder(
  mobile: (context) => MobileLayout(),
  tablet: (context) => TabletLayout(),
  desktop: (context) => DesktopLayout(),
)
```

**Why**: Clearer than nested conditionals, easier to maintain separate layouts.

---

### 3. Lazy Loading for Large Grids

When using ResponsiveListGrid with many items, ensure proper lazy loading:

```dart
// ✅ Good - Built-in lazy loading
ResponsiveListGrid(
  items: largeListOfItems,  // Can handle thousands of items
  itemBuilder: (context, item) => ItemCard(item: item),
  gridAspectRatio: 0.75,
)
```

**Why**: ResponsiveListGrid uses ListView.builder/GridView.builder internally for efficient lazy loading.

---

### 4. Optimize Images for Screen Size

Load appropriate image sizes for different devices:

```dart
// ✅ Good - Responsive image loading
Image.network(
  recipe.imageUrl,
  width: LayoutComponents.valueFor(
    context: context,
    mobile: 400,
    tablet: 600,
    desktop: 800,
  ),
  cacheWidth: LayoutComponents.valueFor(
    context: context,
    mobile: 400,
    tablet: 600,
    desktop: 800,
  ),
)
```

**Why**: Don't load 4K images on mobile devices - saves bandwidth and memory.

---

## Migration Guide

### How to Make an Existing View Responsive

Follow this step-by-step checklist:

#### Step 1: Import Required Packages

```dart
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/theme/app_dimensions.dart';
```

#### Step 2: Identify Content Type

Determine which content width strategy applies:
- **Narrow (500-600px)**: Auth, dialogs, simple forms
- **Medium (700-800px)**: Import, creation, detail views
- **Wide (900-1200px)**: Complex layouts, discovery, planning
- **Adaptive Grid**: Lists, galleries

#### Step 3: Wrap Main Content

Add Center + ConstrainedBox pattern:

```dart
// Before
body: Padding(
  padding: EdgeInsets.all(16),
  child: Column(children: [...]),
)

// After
body: SafeArea(
  child: Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: LayoutComponents.valueFor(
          context: context,
          mobile: double.infinity,
          tablet: 700,  // Adjust based on content type
          desktop: 800,
        ),
      ),
      child: Padding(
        padding: AppDimensions.responsiveContentPadding(context),
        child: Column(children: [...]),
      ),
    ),
  ),
)
```

#### Step 4: Replace Hardcoded Padding

Replace all hardcoded padding with responsive utilities:

```dart
// Before
padding: EdgeInsets.all(16)

// After
padding: AppDimensions.responsiveContentPadding(context)
```

#### Step 5: Handle Loading Overlays

If view has loading overlays, constrain them:

```dart
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
```

#### Step 6: Convert Lists to Grids (if applicable)

For list views that should be grids on larger screens:

```dart
// Before
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemCard(item: items[index]),
)

// After
ResponsiveListGrid(
  items: items,
  itemBuilder: (context, item) => ItemCard(item: item),
  gridAspectRatio: 0.75,
)
```

#### Step 7: Handle CustomScrollView (if applicable)

For sliver-based views, use SliverToBoxAdapter with constraints:

```dart
// Before
SliverPadding(
  padding: EdgeInsets.all(16),
  sliver: SliverList(
    delegate: SliverChildListDelegate([...]),
  ),
)

// After
SliverToBoxAdapter(
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
        child: Column(children: [...]),
      ),
    ),
  ),
)
```

#### Step 8: Test on All Screen Sizes

Test the view on:
- **Mobile**: 360x640, 375x667, 414x896
- **Tablet**: 768x1024, 834x1112, 1024x1366
- **Desktop**: 1280x720, 1920x1080, 2560x1440

Check:
- ✅ Content doesn't stretch too wide on desktop
- ✅ Content is centered on large screens
- ✅ Padding adapts to screen size
- ✅ Navigation switches from bottom bar to rail
- ✅ All functionality works on all screen sizes

#### Step 9: Run Flutter Analyze

```bash
flutter analyze
```

Ensure no new issues introduced.

#### Step 10: Commit Changes

```bash
git add lib/views/my_view.dart
git commit -m "feat: Make my_view responsive (Issue #025)"
```

---

### Migration Example

**Before (not responsive)**:
```dart
class MyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My View')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Content', style: AppTextStyles.headlineSmall),
            SizedBox(height: 24),
            // ... more content
          ],
        ),
      ),
    );
  }
}
```

**After (responsive)**:
```dart
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/theme/app_dimensions.dart';

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
                  Text(
                    'Content',
                    style: AppTextStyles.headlineSmall,
                    textAlign: LayoutComponents.isDesktop(context)
                        ? TextAlign.center
                        : TextAlign.start,
                  ),
                  SizedBox(
                    height: LayoutComponents.valueFor(
                      context: context,
                      mobile: AppDimensions.spacingL,
                      tablet: AppDimensions.spacingXl,
                      desktop: AppDimensions.spacingXl * 1.5,
                    ),
                  ),
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

**Changes made**:
1. ✅ Added imports for `LayoutComponents` and `AppDimensions`
2. ✅ Wrapped body in `SafeArea`
3. ✅ Added `Center` widget for horizontal centering
4. ✅ Added `ConstrainedBox` with responsive max width (∞→700→800px)
5. ✅ Changed padding from hardcoded to `AppDimensions.responsiveContentPadding()`
6. ✅ Made heading center-aligned on desktop
7. ✅ Made spacing responsive (24px → 36px → 54px)

---

## Testing Best Practices

### Manual Testing Checklist

When testing a responsive view, verify:

- [ ] **Mobile (360x640)**:
  - Content uses full width (no horizontal scrolling)
  - Padding is appropriate (16px)
  - Bottom navigation bar visible
  - All interactive elements reachable
  - Images scale correctly

- [ ] **Mobile Large (414x896)**:
  - Same as mobile but with more vertical space
  - Content doesn't look too stretched

- [ ] **Tablet (768x1024)**:
  - Content is centered and constrained
  - Max width applied correctly
  - Navigation rail appears on left
  - Padding increased (24px)
  - Grid views show 2 columns (if applicable)

- [ ] **Desktop (1920x1080)**:
  - Content centered with appropriate max width
  - Large margins on both sides
  - Navigation rail on left
  - Padding increased (32px)
  - Grid views show 3 columns (if applicable)
  - Loading overlays don't stretch too wide

### Widget Testing

Test responsive behavior in widget tests:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/responsive/breakpoints.dart';

void main() {
  testWidgets('View is responsive on mobile', (WidgetTester tester) async {
    // Set mobile screen size
    tester.binding.window.physicalSizeTestValue = Size(360, 640);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    // Verify full-width content on mobile
    final constrainedBox = tester.widget<ConstrainedBox>(
      find.byType(ConstrainedBox).first,
    );
    expect(constrainedBox.constraints.maxWidth, double.infinity);
  });

  testWidgets('View is responsive on tablet', (WidgetTester tester) async {
    // Set tablet screen size
    tester.binding.window.physicalSizeTestValue = Size(768, 1024);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    // Verify constrained content on tablet
    final constrainedBox = tester.widget<ConstrainedBox>(
      find.byType(ConstrainedBox).first,
    );
    expect(constrainedBox.constraints.maxWidth, 700);
  });

  testWidgets('View is responsive on desktop', (WidgetTester tester) async {
    // Set desktop screen size
    tester.binding.window.physicalSizeTestValue = Size(1920, 1080);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    // Verify constrained content on desktop
    final constrainedBox = tester.widget<ConstrainedBox>(
      find.byType(ConstrainedBox).first,
    );
    expect(constrainedBox.constraints.maxWidth, 800);
  });
}
```

### Golden Testing

Create golden tests for different screen sizes:

```dart
testWidgets('View matches golden on mobile', (WidgetTester tester) async {
  tester.binding.window.physicalSizeTestValue = Size(360, 640);
  tester.binding.window.devicePixelRatioTestValue = 1.0;
  addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(MyView),
    matchesGoldenFile('goldens/my_view_mobile.png'),
  );
});
```

---

## Troubleshooting

### Issue: Content Not Centered on Desktop

**Symptom**: Content is left-aligned on large screens.

**Cause**: Missing `Center` widget.

**Solution**: Wrap content in `Center`:
```dart
body: Center(  // ← Add this
  child: ConstrainedBox(/* ... */),
)
```

---

### Issue: Content Stretches Too Wide

**Symptom**: Content is hard to read on large screens (text lines too long).

**Cause**: Missing `ConstrainedBox` or wrong max width.

**Solution**: Add appropriate max width:
```dart
ConstrainedBox(
  constraints: BoxConstraints(
    maxWidth: LayoutComponents.valueFor(
      context: context,
      mobile: double.infinity,
      tablet: 700,
      desktop: 800,  // Adjust based on content type
    ),
  ),
  child: content,
)
```

---

### Issue: Content Has No Padding on Edges

**Symptom**: Content touches screen edges on mobile.

**Cause**: Missing `Padding` widget.

**Solution**: Add responsive padding:
```dart
Padding(
  padding: AppDimensions.responsiveContentPadding(context),
  child: content,
)
```

---

### Issue: Horizontal Scrollbar Appears

**Symptom**: Horizontal scrollbar on mobile.

**Cause**: Content wider than screen width.

**Solution**: Ensure `mobile: double.infinity` in constraints:
```dart
constraints: BoxConstraints(
  maxWidth: LayoutComponents.valueFor(
    context: context,
    mobile: double.infinity,  // ← Important!
    tablet: 700,
    desktop: 800,
  ),
)
```

---

### Issue: Navigation Doesn't Switch to Rail

**Symptom**: Bottom navigation bar shows on tablet/desktop.

**Cause**: Not using `LayoutComponents.mainMenu()` or custom scaffold.

**Solution**: Use `LayoutComponents.mainMenu()` for automatic navigation switching:
```dart
return LayoutComponents.mainMenu(
  currentIndex: 1,
  body: /* your content */,
)
```

Or check `ButleryAdaptiveNavigation` implementation if using custom scaffold.

---

### Issue: Loading Overlay Stretches Too Wide

**Symptom**: Loading spinner is awkwardly wide on desktop.

**Cause**: Loading overlay not constrained.

**Solution**: Constrain overlay separately:
```dart
if (isLoading)
  ColoredBox(
    color: Colors.black.withValues(alpha: 0.5),
    child: Center(
      child: ConstrainedBox(  // ← Add this
        constraints: BoxConstraints(
          maxWidth: LayoutComponents.valueFor(
            context: context,
            mobile: double.infinity,
            tablet: 500,
            desktop: 600,
          ),
        ),
        child: CircularProgressIndicator(),
      ),
    ),
  ),
```

---

### Issue: Content Behind System UI

**Symptom**: Content hidden behind notch or home indicator on iPhone.

**Cause**: Missing `SafeArea`.

**Solution**: Wrap body in `SafeArea`:
```dart
body: SafeArea(  // ← Add this
  child: Center(
    child: ConstrainedBox(/* ... */),
  ),
)
```

---

### Issue: Grid Doesn't Switch on Tablet

**Symptom**: Still showing ListView on tablet instead of GridView.

**Cause**: Not using `ResponsiveListGrid`.

**Solution**: Replace ListView with ResponsiveListGrid:
```dart
// Before
ListView.builder(...)

// After
ResponsiveListGrid(
  items: items,
  itemBuilder: (context, item) => ItemCard(item: item),
  gridAspectRatio: 0.75,
)
```

---

## Summary

### Key Takeaways

1. **Always use the Center + ConstrainedBox pattern** for responsive views
2. **Match max width to content type** (narrow/medium/wide/grid)
3. **Use responsive utilities** from AppDimensions and LayoutComponents
4. **Test on all screen sizes** (mobile, tablet, desktop)
5. **Constrain loading overlays** separately from main content
6. **Use SafeArea** to avoid system UI overlap
7. **Use ResponsiveListGrid** for automatic list/grid switching
8. **Follow migration guide** for consistent implementation

### Quick Reference

**Imports**:
```dart
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/theme/app_dimensions.dart';
```

**Basic Pattern**:
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

**Content Widths**:
- Narrow: 500-600px (auth, dialogs)
- Medium: 700-800px (forms, detail views)
- Wide: 900-1200px (complex layouts)
- Grid: No constraint (auto-columns)

For comprehensive guidance, see [Responsive Design Guide](RESPONSIVE_DESIGN_GUIDE.md).
