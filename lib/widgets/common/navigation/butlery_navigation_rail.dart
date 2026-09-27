// lib/widgets/common/navigation/butlery_navigation_rail.dart
//
// PQ-17: the shell's rail from 768 dp (produktregler.md:1052-1058, § 21.2;
// Skarmar v12 etapp 10 #bredskal). "Skenan bär bottenradens vokabulär: samma
// botten, gemena etiketter, och rostmarkeringen — liggande som en list till
// vänster om vald post", and "lägg till" is a round saffron button at the top.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/navigation/add_sheet.dart';
import 'package:butlery/widgets/common/navigation/butlery_bottom_navigation.dart';
import 'package:butlery/widgets/common/navigation/navigation_item.dart';

/// The rail at 768 dp and up (produktregler.md:1054): the bottom row's
/// vocabulary standing up, drawn in Skarmar v12 etapp 10 #bredskal.
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

  /// The drawn rail width (#bredskal: 104 px).
  static const double width = 104;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget entry(int index) => _RailTab(
      item: items[index],
      isSelected: currentIndex != null && index == currentIndex,
      onTap: () => onTap(index),
    );
    // #bredskal: every destination but the last at the top, the last ("mer")
    // at the foot of the rail.
    final last = items.length - 1;

    return navigationLandmark(
      context: context,
      child: ColoredBox(
        // The same bottom as the bottom row ("samma botten",
        // produktregler.md:1055), which is kept on paper here. Unresolved:
        // #bredskal (Skarmar v12 etapp 10 :72) draws the rail on surface.ink
        // #24382c, and Komponentark v1:662 draws the bottom row on ink too;
        // no rule line names surfaceContainerLow. Open for the product owner.
        color: cs.surfaceContainerLow,
        child: SafeArea(
          right: false,
          child: SizedBox(
            width: width,
            child: Column(
              children: [
                const SizedBox(height: AppDimensions.spacingMd),
                Semantics(
                  sortKey: const OrdinalSortKey(0),
                  child: ButleryAddButton(
                    ring: false,
                    onPressed: onAdd ?? () => showButleryAddSheet(context),
                  ),
                ),
                // #bredskal draws border.onInk #3f5145 on ink. While the rail
                // stays on paper (open, see the surface above) the divider is
                // border.subtle, colorScheme.outlineVariant.
                Container(
                  width: AppDimensions.minTouchTarget,
                  height: 1,
                  margin: const EdgeInsets.symmetric(
                    vertical: AppDimensions.spacingMd,
                  ),
                  color: cs.outlineVariant,
                ),
                Expanded(
                  child: navigationTabList(
                    child: Column(
                      children: [
                        for (var i = 0; i < last; i++) entry(i),
                        const Spacer(),
                        if (last >= 0) entry(last),
                        const SizedBox(height: AppDimensions.spacingMd),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One destination in the rail: icon over the lowercase label, 64 dp tall,
/// the saffron strip at its start when chosen (#bredskal).
class _RailTab extends StatelessWidget {
  const _RailTab({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final AdaptiveNavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;

  static const double _minHeight = 64;
  static const double _stripWidth = 4;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isSelected ? cs.onSurface : cs.onSurfaceVariant;
    return Semantics(
      container: true,
      role: SemanticsRole.tab,
      identifier: 'nav-${item.route}',
      label: item.accessibleLabel,
      selected: isSelected,
      child: ButleryControlFocus(
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
                      top: AppDimensions.spacingSm,
                      bottom: AppDimensions.spacingSm,
                      width: _stripWidth,
                      child: ColoredBox(color: cs.secondary),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.spacingSm,
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
                          const SizedBox(height: AppDimensions.spacingXs),
                          Text(
                            item.label.toLowerCase(),
                            style: AppTextStyles.navLabel.copyWith(
                              color: color,
                              letterSpacing: 1,
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
    );
  }
}
