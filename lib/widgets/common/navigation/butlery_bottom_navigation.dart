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
//                             vocabulary (same surface, the saffron marker as
//                             a strip at the selected entry's start) and
//                             "lägg till" is a round saffron button at the
//                             top of the rail.
//   Skarmar v12 etapp 10 #bredskal: the rail drawn at 104 dp, the plus on top,
//                             a divider, the destinations, "mer" at the foot.
//
// NAV-INK (package 6, the lead's decision): the bar and the rail stand on
// surface.ink #24382C in both modes, as Komponentark v1:662 and #bredskal
// (Skarmar v12 etapp 10 :72) draw them; produktregler.md:1055 names no
// colour. The labels are capitalised as the Komponentark draws them (Hem,
// Meny, Inköp, Mer; B-17 "Meny"). produktregler.md:1055 still says "gemena
// etiketter"; the lead chose the drawing.
//
// Identity is the destination's route (`nav-{route}`), never its position.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/accessibility_utils.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
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

/// The colours of the ink bar and the ink rail, one set for both modes: the
/// surface is surface.ink in both (tokens.json:112-115), so nothing on it
/// follows the page's brightness.
///
/// * [surface]: surface.ink #24382C, colorScheme.primary in both schemes
///   (app_colors.dart lightColorScheme and darkColorScheme).
/// * [selected]: paper #F5F4ED, colorScheme.onPrimary in both schemes; the
///   chosen tab's glyph and label (Komponentark v1:663, `color:#F5F4ED`).
/// * [unselected]: #93A48D, text.secondary (dark) (tokens.json:62-65); the
///   other tabs (Komponentark v1:663-666, `color:#93a48d`), 4.73:1 on ink.
/// * [marker]: action.primary saffron #CE7C1E, colorScheme.secondary in both
///   schemes; the plate line under the chosen label (Komponentark v1:663).
/// * [divider]: paper at the ladder's on-ink 0.18 step (tokens.json:40-53).
///   Interpretation: #bredskal draws border.onInk #3F5145
///   (tokens.json:223-227), which is not delivered to the app yet; the
///   ladder step (#4A5A4F on ink) is the nearest allowed value. Decorative,
///   no contrast floor.
@immutable
class NavInkColors {
  const NavInkColors._({
    required this.surface,
    required this.selected,
    required this.unselected,
    required this.marker,
    required this.divider,
  });

  factory NavInkColors.of(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return NavInkColors._(
      surface: cs.primary,
      selected: cs.onPrimary,
      unselected: AppModeColors.textSecondaryOnInk(),
      marker: cs.secondary,
      divider: cs.onPrimary.withValues(alpha: 0.18),
    );
  }

  final Color surface;
  final Color selected;
  final Color unselected;
  final Color marker;
  final Color divider;
}

/// Everything on the ink bar or rail: focus rings are paper, as on a dark
/// surface ("papper på mörkt", Komponentark v1:657; tokens.json:155-160
/// focusRing dark), in both modes.
Widget onInkSurface({required Widget child}) =>
    FocusRingSurface(brightness: Brightness.dark, child: child);

/// The bottom row: four destinations with the plus in the middle, on the
/// ink bar ([NavInkColors]) in both modes.
class ButleryBottomNavigation extends StatelessWidget {
  const ButleryBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.onAdd,
    this.showAddAction = true,
  });

  /// The ink surface, for tests.
  static const Key inkSurfaceKey = ValueKey<String>('test-nav-ink-surface');

  /// The chosen destination, or null when the view is none of them.
  final int? currentIndex;
  final List<AdaptiveNavigationItem> items;
  final ValueChanged<int> onTap;

  /// What the plus does. Null opens the add sheet (Skarmar v12 del 1
  /// #plussheet).
  final VoidCallback? onAdd;

  /// Whether the plus is drawn. The shell always draws it.
  final bool showAddAction;

  /// The row's height: the plus's 62 dp outer diameter plus 1 dp above and
  /// below (Komponentark v1:667).
  static const double barHeight = ButleryAddButton.outerDiameter + 2;

  @override
  Widget build(BuildContext context) {
    final ink = NavInkColors.of(context);
    final split = showAddAction ? (items.length + 1) ~/ 2 : items.length;
    Widget tab(int index) => Expanded(
      child: _BottomNavTab(
        item: items[index],
        isSelected: currentIndex != null && index == currentIndex,
        onTap: () => onTap(index),
        ink: ink,
      ),
    );

    return navigationLandmark(
      context: context,
      child: DecoratedBox(
        key: inkSurfaceKey,
        decoration: BoxDecoration(color: ink.surface),
        child: onInkSurface(
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
                          onPressed:
                              onAdd ?? () => showButleryAddSheet(context),
                        ),
                      ),
                  ],
                ),
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
    required this.ink,
  });

  final AdaptiveNavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final NavInkColors ink;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? ink.selected : ink.unselected;
    final label = item.label;
    // navLabel 11/700 for every tab (tokens.json typography.roles.navLabel;
    // Grafisk manual v6:244 "Aldrig 400 under 12 px"), without tracking, as
    // drawn (Komponentark v1:663). The chosen tab is told by colour, the line
    // and the selected state, never by weight alone.
    final style = AppTextStyles.navLabel.copyWith(color: color);

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
          // Paper at the on-ink 0.18 step while pressed (tokens.json:40-53).
          splashColor: ink.selected.withValues(alpha: 0.18),
          highlightColor: Colors.transparent,
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
                const SizedBox(height: AppDimensions.bottomNavStackGap),
                Text(
                  label,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimensions.bottomNavStackGap),
                // The saffron line under the chosen label, as wide as the
                // text (Komponentark v1:663; produktregler.md:1055).
                AnimatedContainer(
                  duration: AnimationUtils.getDuration(
                    context,
                    AppDimensions.animationDurationFast,
                  ),
                  height: AppDimensions.bottomNavMarkerThickness,
                  width: isSelected ? _textWidth(label, style) : 0,
                  decoration: BoxDecoration(
                    color: isSelected ? ink.marker : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusKnob,
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
///
/// Interpretation: the count is Material's rounded Badge with navLabel
/// 11/700 figures, in the drawn colours (saffron, count in ink). #bredskal
/// (Skarmar v12 etapp 10 :75) draws a square 16 px box with 10.5/700 tabular
/// figures; that geometry is not built here.
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
    final glyph = ButleryIcon(
      icon,
      color: color,
      size: AppDimensions.iconSizeL,
    );
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
///
/// NAV-INK: on the ink bar the paper ring is seen in both modes, as drawn
/// (Komponentark v1:665; Skarmar v12 del 4 #hem). #hemmorkt draws the ring
/// in the dark page colour #17251D instead; the lead chose one ink bar for
/// both modes, so the ring stays paper there too.
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
                child: ButleryIcon(
                  ButleryIcons.navAdd,
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
