import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';
import 'package:flutter/services.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/surfaces/butlery_disc.dart';

/// Diameter of the paper ring behind a hero icon button (Komponentark
/// v1:81-89 draws 40 px). The hitbox around it is 48 dp.
const double _paperRingSize = 40;

/// The icon colour on the hero. Ink on the paper ring, which is paper in both
/// modes; with no ring the icon stands on the page, so it follows the page
/// (ink on paper is 1.27:1 against the dark surface).
Color _heroIconColor(ColorScheme cs, {required bool onPaper}) =>
    onPaper ? cs.primary : cs.onSurface;

/// An icon button on the media hero: an ink icon in a paper ring, 48 dp
/// hitbox, the canonical focus ring around the hitbox (Komponentark
/// v1:81-89 "Ikonknappar i pappersringar").
///
/// Paper and ink are the same in both modes, because the ring stands on a
/// photo, not on the theme's surface: onPrimary is paper #F5F4ED and
/// primary is ink #24382C in both schemes (lib/theme/app_colors.dart
/// lightColorScheme and darkColorScheme).
class RecipeHeroButton extends StatefulWidget {
  const RecipeHeroButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.ringVisible = true,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  /// False on a page without a photo: the ring stands on a photo, and with
  /// none behind it the icons are drawn bare on the paper and the 48 dp
  /// hitboxes abut ("Utan foto · typografiskt huvud").
  final bool ringVisible;

  @override
  State<RecipeHeroButton> createState() => _RecipeHeroButtonState();
}

class _RecipeHeroButtonState extends State<RecipeHeroButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Tooltip alone gives screen readers a hint, not a "button" role —
    // wrap explicitly so callers without their own Semantics ancestor
    // (e.g. the back button at AppBar.leading) still announce correctly.
    final tappable = ButleryControlFocus(
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          overlayColor: ownPressOverlay,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          onHover: (value) => setState(() => _hovered = value),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onPressed();
          },
          child: SizedBox(
            width: AppDimensions.minTouchTarget,
            height: AppDimensions.minTouchTarget,
            child: Center(
              child: _PaperRing(
                pressed: _pressed || _hovered,
                visible: widget.ringVisible,
                child: ButleryIcon(
                  widget.icon,
                  color: _heroIconColor(
                    cs,
                    onPaper: widget.ringVisible || _pressed || _hovered,
                  ),
                  size: AppDimensions.iconSizeM,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final tooltip = widget.tooltip;
    final hasTooltip = tooltip != null && tooltip.isNotEmpty;
    final labelled = hasTooltip
        ? Semantics(
            label: context.l10n.a11yHeroButton(tooltip),
            button: true,
            child: Tooltip(
              message: tooltip,
              excludeFromSemantics: true,
              child: tappable,
            ),
          )
        : tappable;
    return labelled;
  }
}

/// The 40 px paper circle behind a hero icon. While [pressed] it is
/// surface.raised #E6EAD9, opaque, over the photo and on the collapsed bar
/// alike (produktbeslut R8-3 = A).
class _PaperRing extends StatelessWidget {
  const _PaperRing({
    required this.pressed,
    required this.child,
    this.visible = true,
  });

  final bool pressed;
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ButleryDisc(
      key: const ValueKey('recipe-detail-paper-ring'),
      size: _paperRingSize,
      color: pressed
          ? AppModeColors.surfaceRaisedOnPhoto()
          : visible
          ? Theme.of(context).colorScheme.onPrimary
          : Colors.transparent,
      child: Center(child: child),
    );
  }
}

/// The hero's popup menu button, in the same paper ring as
/// [RecipeHeroButton].
class RecipeHeroMenuButton<T> extends StatefulWidget {
  const RecipeHeroMenuButton({
    required this.icon,
    required this.choices,
    required this.onSelected,
    required this.tooltip,
    this.ringVisible = true,
    super.key,
  });

  final bool ringVisible;
  final String tooltip;
  final IconData icon;
  final List<ButleryMenuChoice<T>> choices;
  final void Function(T) onSelected;

  @override
  State<RecipeHeroMenuButton<T>> createState() =>
      _RecipeHeroMenuButtonState<T>();
}

class _RecipeHeroMenuButtonState<T> extends State<RecipeHeroMenuButton<T>> {
  bool _pressed = false;
  bool _hovered = false;

  void _press(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // PopupMenuButton reports no highlight, so the ring follows the pointer.
    return ButleryControlFocus(
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      child: SizedBox(
        width: AppDimensions.minTouchTarget,
        height: AppDimensions.minTouchTarget,
        child: Listener(
          onPointerDown: (_) => _press(true),
          onPointerUp: (_) => _press(false),
          onPointerCancel: (_) => _press(false),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: ButleryMenu<T>(
              padding: EdgeInsets.zero,
              semanticLabel: widget.tooltip,
              style: ButtonStyle(overlayColor: ownPressOverlay),
              iconWidget: _PaperRing(
                pressed: _pressed || _hovered,
                visible: widget.ringVisible,
                child: ButleryIcon(
                  widget.icon,
                  color: _heroIconColor(
                    cs,
                    onPaper: widget.ringVisible || _pressed || _hovered,
                  ),
                  size: AppDimensions.iconSizeM,
                ),
              ),
              choices: widget.choices,
              onSelected: widget.onSelected,
            ),
          ),
        ),
      ),
    );
  }
}
