// lib/widgets/common/navigation/butlery_navigation_rail.dart
//
// NAV-INK: the same ink surface as the bottom row in both modes
// and the bottom row's
// capitalised labels (see butlery_bottom_navigation.dart).
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/navigation/add_sheet.dart';
import 'package:butlery/widgets/common/navigation/butlery_bottom_navigation.dart';
import 'package:butlery/widgets/common/navigation/navigation_item.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// The rail at 768 dp and up: the bottom row's
/// vocabulary standing up.
class ButleryNavigationRail extends StatelessWidget {
  const ButleryNavigationRail({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.onAdd,
  });

  final int? currentIndex;
  final List<AdaptiveNavigationItem> items;
  final ValueChanged<int> onTap;

  /// What the plus does. Null opens the add sheet.
  final VoidCallback? onAdd;

  /// The drawn rail width.
  static const double width = 104;

  @override
  Widget build(BuildContext context) {
    final ink = NavInkColors.of(context);
    Widget entry(int index) => _RailTab(
      item: items[index],
      isSelected: currentIndex != null && index == currentIndex,
      onTap: () => onTap(index),
      ink: ink,
    );
    final last = items.length - 1;

    return navigationLandmark(
      context: context,
      child: ColoredBox(
        key: inkSurfaceKey,
        color: ink.surface,
        child: onInkSurface(
          child: SafeArea(
            right: false,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  const SizedBox(height: AppDimensions.space16),
                  Semantics(
                    sortKey: const OrdinalSortKey(0),
                    child: ButleryAddButton(
                      ring: false,
                      onPressed: onAdd ?? () => showButleryAddSheet(context),
                    ),
                  ),
                  Container(
                    width: AppDimensions.minTouchTarget,
                    height: 1,
                    margin: const EdgeInsets.symmetric(
                      vertical: AppDimensions.space16,
                    ),
                    color: ink.divider,
                  ),
                  Expanded(
                    child: navigationTabList(
                      child: Column(
                        children: [
                          for (var i = 0; i < last; i++) entry(i),
                          const Spacer(),
                          if (last >= 0) entry(last),
                          const SizedBox(height: AppDimensions.space16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The ink surface, for tests.
  static const Key inkSurfaceKey = ValueKey<String>('test-rail-ink-surface');
}

/// One destination in the rail: icon over the label, 64 dp tall, the saffron
/// strip at its start when chosen.
///
/// The rail takes the bottom row's vocabulary
/// ("samma vokabulär"): navLabel 11/700
class _RailTab extends StatelessWidget {
  const _RailTab({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.ink,
  });

  final AdaptiveNavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final NavInkColors ink;

  static const double _minHeight = 64;
  static const double _stripWidth = 4;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? ink.selected : ink.unselected;
    return Semantics(
      container: true,
      role: SemanticsRole.tab,
      identifier: 'nav-${item.route}',
      label: item.accessibleLabel,
      selected: isSelected,
      child: ButleryControlFocus(
        child: Material(
          type: MaterialType.transparency,
          child: PressFill(
            surface: PressSurface.ink,
            child: InkWell(
              key: ValueKey('test-rail-${item.route}'),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: _minHeight,
                  minWidth: double.infinity,
                ),
                child: ExcludeSemantics(
                  child: Stack(
                    children: [
                      if (isSelected)
                        PositionedDirectional(
                          start: 0,
                          top: AppDimensions.space8,
                          bottom: AppDimensions.space8,
                          width: _stripWidth,
                          child: ColoredBox(color: ink.marker),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.space8,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              NavBadgedIcon(
                                icon: isSelected ? item.activeIcon : item.icon,
                                badgeCount: item.badgeCount,
                                color: color,
                              ),
                              const SizedBox(height: AppDimensions.space4),
                              Text(
                                item.label,
                                style: AppTextStyles.navLabel.copyWith(
                                  color: color,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
