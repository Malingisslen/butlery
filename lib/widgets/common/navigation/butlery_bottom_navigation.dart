// lib/widgets/common/navigation/butlery_bottom_navigation.dart
//
// PQ-17 = A (fas2/produktbeslut-2026-09-23.json): the shell's navigation is
// four destinations in a tab list plus a separate round saffron "Lägg till".
//
//   Komponentark v1:661-667  "Bottennavigation · 4 destinationer + 1 knapp":
//                             4 tabs in one tablist, the plus outside it,
//                             56 px + 3 px ring = 62 px outer diameter,
//                             62 dp hitbox; focus ring around the whole tab.
//   tillganglighetshandoff 'Navigation & toppfält' (row 131): tablist with 4
//                             tabs + a separate button named "Lägg till" with
//                             its own focus stop; the selected tab is exposed
//                             as selected, not only by the saffron line; the
//                             tablist is read last.
//   produktregler.md:1052-1058 (§ 21.2): the rail carries the bottom row's
//                             vocabulary (same surface, lowercase labels, the
//                             saffron marker as a strip at the selected
//                             entry's start) and "lägg till" is a round
//                             saffron button at the top of the rail.
//   Skarmar v12 etapp 10 #bredskal: the rail drawn at 104 dp, the plus on top,
//                             a divider, the destinations, "mer" at the foot.
//
// Identity is the destination's route (`nav-{route}`), never its position.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/accessibility_utils.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/navigation/add_sheet.dart';
import 'package:butlery/widgets/common/navigation/navigation_item.dart';

/// BUT-557: the container-level navigation landmark (WCAG 1.3.1).
Widget navigationLandmark({
  required BuildContext context,
  required Widget child,
}) => Semantics(
  label: context.l10n.a11yNavigationLandmark,
  container: true,
  explicitChildNodes: true,
  child: child,
);

/// The destinations as a tab list: the tabs are its only children, so the
/// plus button can never be read as a tab (Flutter checks this in debug).
Widget navigationTabList({required Widget child}) => Semantics(
  role: SemanticsRole.tabBar,
  container: true,
  explicitChildNodes: true,
  // Read after everything else in the bar, the plus included
  // (tillganglighetshandoff 'Navigation & toppfält').
  sortKey: const OrdinalSortKey(1),
  child: child,
);

/// The bottom row: four destinations with the plus in the middle.
///
/// Colours are the bar's existing tokens, kept as they were (see the
/// interpretation in PQ-17's commit): surface (surfaceContainerLow resolves to
/// surface.base, #F5F4ED light / #17251D dark), text.primary for the chosen
/// tab and text.secondary for the others (tokens.json semantic), and
/// action.primary saffron (colorScheme.secondary) for the chosen line.
class ButleryBottomNavigation extends StatelessWidget {
  const ButleryBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.onAdd,
    this.showAddAction = true,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
  });

  /// The chosen destination, or null when the view is none of them.
  final int? currentIndex;
  final List<AdaptiveNavigationItem> items;
  final ValueChanged<int> onTap;

  /// What the plus does. Null opens the add sheet (Skarmar v12 del 1
  /// #plussheet).
  final VoidCallback? onAdd;

  /// Whether the plus is drawn. The shell always draws it.
  final bool showAddAction;

  /// Override background color (defaults to surfaceContainerLow).
  final Color? backgroundColor;

  /// Override selected item color (defaults to onSurface).
  final Color? selectedItemColor;

  /// Override unselected item color (defaults to onSurfaceVariant).
  final Color? unselectedItemColor;

  /// The row's height: the plus's 62 dp outer diameter plus 1 dp above and
  /// below (Komponentark v1:667).
  static const double barHeight = ButleryAddButton.outerDiameter + 2;

  @override
  Widget build(BuildContext context) {
    final split = showAddAction ? (items.length + 1) ~/ 2 : items.length;
    Widget tab(int index) => Expanded(
      child: _BottomNavTab(
        item: items[index],
        isSelected: currentIndex != null && index == currentIndex,
        onTap: () => onTap(index),
        selectedColor: selectedItemColor,
        unselectedColor: unselectedItemColor,
      ),
    );

    return navigationLandmark(
      context: context,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color:
              backgroundColor ??
              Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        child: SafeArea(
          top: false,
          child: AccessibilityUtils.clampTextScaling(
            context: context,
            child: SizedBox(
              height: barHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  navigationTabList(
                    child: Row(
                      children: [
                        for (var i = 0; i < split; i++) tab(i),
                        // The plus's slot. Not a tab, so nothing is here in
                        // the tab list.
                        if (showAddAction) const Spacer(),
                        for (var i = split; i < items.length; i++) tab(i),
                      ],
                    ),
                  ),
                  if (showAddAction)
                    Semantics(
                      sortKey: const OrdinalSortKey(0),
                      child: ButleryAddButton(
                        onPressed: onAdd ?? () => showButleryAddSheet(context),
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

/// One destination in the bottom row.
class _BottomNavTab extends StatelessWidget {
  const _BottomNavTab({
    required this.item,
    required this.isSelected,
    required this.onTap,
    this.selectedColor,
    this.unselectedColor,
  });

  final AdaptiveNavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? unselectedColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isSelected
        ? (selectedColor ?? cs.onSurface)
        : (unselectedColor ?? cs.onSurfaceVariant);
    final label = item.label.toLowerCase();
    // navLabel 11/700 for every tab (tokens.json typography.roles.navLabel;
    // Grafisk manual v6:244 "Aldrig 400 under 12 px"). The chosen tab is told
    // by colour, the line and the selected state, never by weight alone.
    final style = AppTextStyles.navLabel.copyWith(
      color: color,
      letterSpacing: 1,
    );

    // BUT-403: identifier `nav-{route}` for browser a11y tree queries.
    return Semantics(
      container: true,
      role: SemanticsRole.tab,
      identifier: 'nav-${item.route}',
      label: item.accessibleLabel,
      selected: isSelected,
      // Komponentark v1:667: the focus ring goes around the whole tab.
      child: ButleryControlFocus(
        child: InkWell(
          key: ValueKey('test-nav-${item.route}'),
          onTap: onTap,
          splashColor: cs.surfaceContainerHighest.withValues(alpha: 0.1),
          highlightColor: cs.surfaceContainerHighest.withValues(alpha: 0.05),
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NavBadgedIcon(
                  icon: isSelected ? item.activeIcon : item.icon,
                  badgeCount: item.badgeCount,
                  color: color,
                ),
                const SizedBox(height: AppDimensions.spacingXxs),
                Text(
                  label,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimensions.spacingXxs),
                // The saffron line under the chosen label, as wide as the
                // text (Komponentark v1:663; produktregler.md:1055).
                AnimatedContainer(
                  duration: AnimationUtils.getDuration(
                    context,
                    AppDimensions.animationDurationFast,
                  ),
                  height: AppDimensions.spacingXxs,
                  width: isSelected ? _textWidth(label, style) : 0,
                  color: isSelected ? cs.secondary : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static double _textWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }
}

/// A destination icon with its optional count.
class NavBadgedIcon extends StatelessWidget {
  const NavBadgedIcon({
    required this.icon,
    required this.color,
    this.badgeCount,
    super.key,
  });

  final IconData icon;
  final Color color;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final glyph = Icon(icon, color: color, size: AppDimensions.iconSizeL);
    final count = badgeCount;
    if (count == null || count <= 0) return glyph;
    return Badge(
      label: Text(
        '$count',
        style: AppTextStyles.navLabel.copyWith(color: cs.onSecondary),
      ),
      backgroundColor: cs.secondary,
      child: glyph,
    );
  }
}

/// The round saffron "Lägg till": an action, never a destination
/// (produktregler.md:1056).
///
/// action.primary saffron (colorScheme.secondary, #CE7C1E in both modes) with
/// the glyph in text.onActionPrimary (colorScheme.onSecondary, #17251D in both
/// modes), as drawn (Komponentark v1:665). The ring is paper
/// (colorScheme.onPrimary, #F5F4ED in both modes), drawn 3 px outside the
/// 56 px surface; the rail draws it without a ring (#bredskal).
class ButleryAddButton extends StatelessWidget {
  const ButleryAddButton({
    required this.onPressed,
    this.ring = true,
    super.key,
  });

  final VoidCallback onPressed;

  /// Whether the 3 px paper ring is drawn (the bottom row) or not (the rail).
  final bool ring;

  /// The saffron surface (Komponentark v1:667).
  static const double surfaceDiameter = 56;

  /// The ring's width on each side (Komponentark v1:667).
  static const double ringWidth = 3;

  /// Surface plus ring: the component's size and its hitbox (Komponentark
  /// v1:667, "hitbox 62 dp").
  static const double outerDiameter = surfaceDiameter + 2 * ringWidth;

  static const Key buttonKey = ValueKey<String>('test-nav-add');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = ring ? outerDiameter : surfaceDiameter;
    return Semantics(
      container: true,
      button: true,
      identifier: 'nav-add',
      label: context.l10n.navigationAddAction,
      child: ButleryControlFocus(
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox.square(
          dimension: size,
          child: Material(
            key: buttonKey,
            color: cs.secondary,
            shape: CircleBorder(
              side: ring
                  ? BorderSide(
                      color: cs.onPrimary,
                      width: ringWidth,
                      strokeAlign: BorderSide.strokeAlignInside,
                    )
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: ExcludeSemantics(
                child: Icon(
                  Icons.add,
                  color: cs.onSecondary,
                  size: AppDimensions.iconSizeL,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
