// lib/widgets/common/responsive/responsive_grid.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/animations/animated_list_item.dart';

/// Responsive grid that automatically adjusts column count based on screen width
/// Usage:
/// ```dart
/// ResponsiveGrid(
///   children: [
///     RecipeCard(...),
///     RecipeCard(...),
///     // ... more items
///   ],
/// )
/// ```
/// Column count automatically adjusts:
/// - Mobile: 1 column
/// - Tablet: 2 columns
/// - Desktop: 3 columns
/// - Large Desktop: 4 columns
class ResponsiveGrid extends StatelessWidget {
  /// Grid items (provide this OR lazyItemBuilder+itemCount)
  final List<Widget>? children;

  /// Lazy item builder for on-demand widget construction
  final IndexedWidgetBuilder? lazyItemBuilder;

  /// Item count for lazy builder mode
  final int? lazyItemCount;

  /// Spacing between grid items
  /// If null, uses AppDimensions.responsiveGridSpacing
  final double? spacing;

  /// Custom column counts (overrides breakpoint-based defaults)
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;

  /// Aspect ratio for grid items
  /// If null, items size naturally based on content
  final double? childAspectRatio;

  /// Main axis spacing (vertical spacing between rows)
  final double? mainAxisSpacing;

  /// Cross axis spacing (horizontal spacing between columns)
  final double? crossAxisSpacing;

  /// Padding around the grid
  final EdgeInsetsGeometry? padding;

  /// Whether grid should shrink-wrap (for use in scrollable parent)
  final bool shrinkWrap;

  /// Scroll physics
  final ScrollPhysics? physics;

  /// Whether to animate items with staggered entrance animation
  final bool animate;

  const ResponsiveGrid({
    super.key,
    this.children,
    this.lazyItemBuilder,
    this.lazyItemCount,
    this.spacing,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
    this.childAspectRatio,
    this.mainAxisSpacing,
    this.crossAxisSpacing,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.animate = false,
  });

  int _getColumnCount(BuildContext context) {
    return Breakpoints.valueForCategory(
      context: context,
      mobile: mobileColumns ?? 1,
      tablet: tabletColumns ?? 2,
      desktop: desktopColumns ?? 3,
      desktopLarge: 4,
    );
  }

  double _getSpacing(BuildContext context) {
    return spacing ?? AppDimensions.responsiveGridSpacing(context);
  }

  @override
  Widget build(BuildContext context) {
    final columnCount = _getColumnCount(context);
    final gridSpacing = _getSpacing(context);

    final isLazy = lazyItemBuilder != null;
    final count = isLazy ? (lazyItemCount ?? 0) : children!.length;

    return GridView.builder(
      padding: padding ?? AppDimensions.responsiveContentPadding(context),
      shrinkWrap: shrinkWrap,
      physics: physics,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
        mainAxisSpacing: mainAxisSpacing ?? gridSpacing,
        crossAxisSpacing: crossAxisSpacing ?? gridSpacing,
        childAspectRatio: childAspectRatio ?? 1.0,
      ),
      itemCount: count,
      itemBuilder: isLazy
          ? lazyItemBuilder!
          : (context, index) {
              final child = children![index];
              if (animate) {
                return AnimatedListItem(index: index, child: child);
              }
              return child;
            },
    );
  }
}

/// Responsive grid using extent (min item width) instead of column count
/// Better for items with variable sizes - grid automatically fits as many
/// columns as possible while respecting minimum item width.
/// Usage:
/// ```dart
/// ResponsiveGridExtent(
///   maxCrossAxisExtent: 300, // Min 300px per item
///   children: [
///     RecipeCard(...),
///     RecipeCard(...),
///   ],
/// )
/// ```
class ResponsiveGridExtent extends StatelessWidget {
  /// Grid items
  final List<Widget> children;

  /// Maximum width for each grid item
  /// Grid will fit as many columns as possible respecting this width
  final double maxCrossAxisExtent;

  /// Main axis spacing (vertical spacing between rows)
  final double? mainAxisSpacing;

  /// Cross axis spacing (horizontal spacing between columns)
  final double? crossAxisSpacing;

  /// Aspect ratio for grid items
  final double? childAspectRatio;

  /// Padding around the grid
  final EdgeInsetsGeometry? padding;

  /// Whether grid should shrink-wrap
  final bool shrinkWrap;

  /// Scroll physics
  final ScrollPhysics? physics;

  const ResponsiveGridExtent({
    super.key,
    required this.children,
    required this.maxCrossAxisExtent,
    this.mainAxisSpacing,
    this.crossAxisSpacing,
    this.childAspectRatio,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final gridSpacing = AppDimensions.responsiveGridSpacing(context);

    return GridView.builder(
      padding: padding ?? AppDimensions.responsiveContentPadding(context),
      shrinkWrap: shrinkWrap,
      physics: physics,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        mainAxisSpacing: mainAxisSpacing ?? gridSpacing,
        crossAxisSpacing: crossAxisSpacing ?? gridSpacing,
        childAspectRatio: childAspectRatio ?? 1.0,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

/// Responsive wrap that adjusts spacing based on screen size
/// Similar to Wrap widget but with responsive spacing.
/// Usage:
/// ```dart
/// ResponsiveWrap(
///   children: [
///     Chip(label: Text('Tag 1')),
///     Chip(label: Text('Tag 2')),
///   ],
/// )
/// ```
class ResponsiveWrap extends StatelessWidget {
  /// Wrap items
  final List<Widget> children;

  /// Spacing between items
  final double? spacing;

  /// Run spacing (spacing between rows)
  final double? runSpacing;

  /// Alignment
  final WrapAlignment alignment;

  /// Cross-axis alignment
  final WrapCrossAlignment crossAxisAlignment;

  /// Run alignment
  final WrapAlignment runAlignment;

  /// Text direction
  final TextDirection? textDirection;

  /// Vertical direction
  final VerticalDirection verticalDirection;

  const ResponsiveWrap({
    super.key,
    required this.children,
    this.spacing,
    this.runSpacing,
    this.alignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.runAlignment = WrapAlignment.start,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
  });

  @override
  Widget build(BuildContext context) {
    final defaultSpacing = Breakpoints.valueFor(
      context: context,
      mobile: AppDimensions.spacingSm,
      tablet: AppDimensions.spacingMd,
      desktop: AppDimensions.spacingMd,
    );

    return Wrap(
      spacing: spacing ?? defaultSpacing,
      runSpacing: runSpacing ?? defaultSpacing,
      alignment: alignment,
      crossAxisAlignment: crossAxisAlignment,
      runAlignment: runAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      children: children,
    );
  }
}

/// Responsive staggered grid for items with varying heights
/// Perfect for masonry-style layouts (like Pinterest).
/// Note: This is a simplified version. For production, consider using
/// flutter_staggered_grid_view package.
/// Usage:
/// ```dart
/// ResponsiveStaggeredGrid(
///   children: [
///     Container(height: 100, ...),
///     Container(height: 150, ...),
///     Container(height: 120, ...),
///   ],
/// )
/// ```
class ResponsiveStaggeredGrid extends StatelessWidget {
  /// Grid items
  final List<Widget> children;

  /// Custom column counts
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;

  /// Spacing between items
  final double? spacing;

  /// Padding around grid
  final EdgeInsetsGeometry? padding;

  const ResponsiveStaggeredGrid({
    super.key,
    required this.children,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
    this.spacing,
    this.padding,
  });

  int _getColumnCount(BuildContext context) {
    return Breakpoints.valueForCategory(
      context: context,
      mobile: mobileColumns ?? 1,
      tablet: tabletColumns ?? 2,
      desktop: desktopColumns ?? 3,
      desktopLarge: 4,
    );
  }

  @override
  Widget build(BuildContext context) {
    final columnCount = _getColumnCount(context);
    final gridSpacing = spacing ?? AppDimensions.responsiveGridSpacing(context);

    // Distribute children into columns
    final columns = List.generate(columnCount, (_) => <Widget>[]);

    for (var i = 0; i < children.length; i++) {
      final columnIndex = i % columnCount;
      columns[columnIndex].add(children[i]);
    }

    return Padding(
      padding: padding ?? AppDimensions.responsiveContentPadding(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          columnCount,
          (index) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : gridSpacing / 2,
                right: index == columnCount - 1 ? 0 : gridSpacing / 2,
              ),
              child: Column(
                children: columns[index]
                    .map(
                      (child) => Padding(
                        padding: EdgeInsets.only(bottom: gridSpacing),
                        child: child,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Responsive list that switches to grid on larger screens
/// Shows as vertical list on mobile, grid on tablet/desktop.
/// Usage:
/// ```dart
/// ResponsiveListGrid(
///   items: recipeList,
///   itemBuilder: (context, recipe) => RecipeCard(recipe: recipe),
/// )
/// ```
class ResponsiveListGrid<T> extends StatelessWidget {
  /// Items to display
  final List<T> items;

  /// Builder for each item
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Custom breakpoint for switching to grid (defaults to tablet: 600px)
  final double? gridBreakpoint;

  /// Grid column count on tablet
  final int? tabletColumns;

  /// Grid column count on desktop
  final int? desktopColumns;

  /// Spacing between items
  final double? spacing;

  /// Padding
  final EdgeInsetsGeometry? padding;

  /// Whether to shrink wrap
  final bool shrinkWrap;

  /// Scroll physics
  final ScrollPhysics? physics;

  /// Aspect ratio for grid items (if null, items size based on content)
  final double? gridChildAspectRatio;

  /// Whether to animate items with staggered entrance animation
  final bool animate;

  const ResponsiveListGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.gridBreakpoint,
    this.tabletColumns,
    this.desktopColumns,
    this.spacing,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.gridChildAspectRatio,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final useGrid =
        Breakpoints.isTablet(context) || Breakpoints.isDesktop(context);

    if (useGrid) {
      return ResponsiveGrid(
        tabletColumns: tabletColumns,
        desktopColumns: desktopColumns,
        spacing: spacing,
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: physics,
        childAspectRatio: gridChildAspectRatio,
        animate: animate,
        lazyItemCount: items.length,
        lazyItemBuilder: (context, index) {
          final child = itemBuilder(context, items[index]);
          if (animate) {
            return AnimatedListItem(index: index, child: child);
          }
          return child;
        },
      );
    } else {
      // Mobile: vertical list
      return ListView.separated(
        padding: padding ?? AppDimensions.responsiveContentPadding(context),
        shrinkWrap: shrinkWrap,
        physics: physics,
        itemCount: items.length,
        separatorBuilder: (context, index) => SizedBox(
          height: spacing ?? AppDimensions.responsiveGridSpacing(context),
        ),
        itemBuilder: (context, index) {
          final child = itemBuilder(context, items[index]);
          if (animate) {
            return AnimatedListItem(index: index, child: child);
          }
          return child;
        },
      );
    }
  }
}
