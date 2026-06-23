import 'package:flutter/material.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// A reusable wrapper that adds a subtle hover affordance to custom interactive
/// cards on pointer-capable platforms (web / desktop). Flutter's built-in
/// [InkWell] hover highlight is suppressed on cards that paint their own
/// decoration, so custom cards otherwise feel "dead" under a mouse cursor.
///
/// On hover the wrapper cross-fades from [restDecoration] to [hoverDecoration]
/// (e.g. a slightly stronger shadow or a faint background shift) and switches
/// the mouse cursor to [SystemMouseCursors.click] when [enabled].
///
/// **Reduced motion (WCAG 2.3.3):** when the user has "Reduce Motion" enabled,
/// the decoration still changes on hover — only the animation duration collapses
/// to [Duration.zero] so the change is instant rather than animated.
///
/// **Square design language:** the wrapper imposes no corner radius of its own.
/// Callers pass decorations that already encode the project's square-corner
/// convention; nothing here rounds anything.
///
/// On touch devices [MouseRegion] hover events never fire, so this widget is a
/// no-op there and renders [restDecoration] — no behavioural change versus a
/// plain decorated container.
class HoverableCard extends StatefulWidget {
  const HoverableCard({
    super.key,
    required this.child,
    required this.restDecoration,
    required this.hoverDecoration,
    this.margin,
    this.enabled = true,
    this.duration = AppDimensions.animationDurationFast,
    this.curve = Curves.easeOut,
  });

  /// The card content painted on top of the animated decoration.
  final Widget child;

  /// Decoration shown when the pointer is not hovering the card.
  final Decoration restDecoration;

  /// Decoration shown while the pointer hovers the card (subtle lift / shift).
  final Decoration hoverDecoration;

  /// Outer margin around the card. Kept on a plain [Container] so layout and
  /// existing margin-based tests are unaffected by the hover animation.
  final EdgeInsetsGeometry? margin;

  /// When false, no hover decoration is applied and the cursor stays default —
  /// use for non-interactive cards so they don't imply clickability.
  final bool enabled;

  /// Hover cross-fade duration (honoured only when reduced-motion is off).
  final Duration duration;

  /// Hover cross-fade curve.
  final Curve curve;

  @override
  State<HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<HoverableCard> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (!widget.enabled || _hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final showHover = widget.enabled && _hovered;
    final effectiveDuration = AnimationUtils.getReducedDuration(
      context,
      widget.duration,
    );

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Container(
        margin: widget.margin,
        child: AnimatedContainer(
          duration: effectiveDuration,
          curve: widget.curve,
          decoration: showHover
              ? widget.hoverDecoration
              : widget.restDecoration,
          child: widget.child,
        ),
      ),
    );
  }
}
