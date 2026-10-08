import 'package:flutter/material.dart';

import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/animations/animated_list_item.dart';

/// For a scroll view that has other slivers above the items: a list with
/// spacing on a phone, a fixed-column grid on a tablet or desktop. Items are
/// built lazily.
class SliverResponsiveListGrid<T> extends StatelessWidget {
  const SliverResponsiveListGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.tabletColumns,
    this.desktopColumns,
    this.spacing,
    this.padding,
    this.gridChildAspectRatio,
    this.animate = false,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final int? tabletColumns;
  final int? desktopColumns;
  final double? spacing;
  final EdgeInsetsGeometry? padding;
  final double? gridChildAspectRatio;
  final bool animate;

  Widget _item(BuildContext context, int index) {
    final child = itemBuilder(context, items[index]);
    return animate ? AnimatedListItem(index: index, child: child) : child;
  }

  @override
  Widget build(BuildContext context) {
    final gap = spacing ?? AppDimensions.responsiveGridSpacing(context);
    final useGrid =
        Breakpoints.isTablet(context) || Breakpoints.isDesktop(context);
    final Widget sliver = useGrid
        ? SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: Breakpoints.valueForCategory(
                context: context,
                mobile: 1,
                tablet: tabletColumns ?? 2,
                desktop: desktopColumns ?? 3,
                desktopLarge: 4,
              ),
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              childAspectRatio: gridChildAspectRatio ?? 1.0,
            ),
            itemCount: items.length,
            itemBuilder: _item,
          )
        : SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => SizedBox(height: gap),
            itemBuilder: _item,
          );
    return SliverPadding(
      padding: padding ?? AppDimensions.responsiveContentPadding(context),
      sliver: sliver,
    );
  }
}
