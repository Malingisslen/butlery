import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// Diameter of the paper ring behind a hero icon button (Komponentark
/// v1:81-89 draws 40 px). The hitbox around it is 48 dp.
const double _paperRingSize = 40;

/// An icon button on the media hero: an ink icon in a paper ring, 48 dp
/// hitbox, the canonical focus ring around the hitbox (Komponentark
/// v1:81-89 "Ikonknappar i pappersringar"; Grafisk manual v6:381).
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
  /// hitboxes abut (Komponentark v1, "Utan foto · typografiskt huvud").
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
                  color: cs.primary,
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
            child: Tooltip(message: tooltip, child: tappable),
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
    return Container(
      key: const ValueKey('recipe-detail-paper-ring'),
      width: _paperRingSize,
      height: _paperRingSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pressed
            ? AppModeColors.surfaceRaisedOnPhoto()
            : visible
            ? Theme.of(context).colorScheme.onPrimary
            : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

/// The hero's popup menu button, in the same paper ring as
/// [RecipeHeroButton] (Komponentark v1:81-89).
class RecipeHeroMenuButton<T> extends StatefulWidget {
  const RecipeHeroMenuButton({
    required this.icon,
    required this.itemBuilder,
    required this.onSelected,
    this.ringVisible = true,
    super.key,
  });

  final bool ringVisible;
  final IconData icon;
  final List<PopupMenuEntry<T>> Function(BuildContext) itemBuilder;
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
            // The menu route captures the themes around the button, so its
            // rows rest on base and take that surface's press.
            child: PressFill(
              surface: PressSurface.base,
              child: PopupMenuButton<T>(
                padding: EdgeInsets.zero,
                style: ButtonStyle(overlayColor: ownPressOverlay),
                icon: _PaperRing(
                  pressed: _pressed || _hovered,
                  visible: widget.ringVisible,
                  child: ButleryIcon(
                    widget.icon,
                    color: cs.primary,
                    size: AppDimensions.iconSizeM,
                  ),
                ),
                itemBuilder: widget.itemBuilder,
                onSelected: widget.onSelected,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
