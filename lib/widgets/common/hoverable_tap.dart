import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Lightweight web/desktop hover affordance for small interactive elements
/// (badges, custom chips, inline tap-links) that aren't Material widgets and so
/// don't get a hover state for free. Adds a pointer cursor and a subtle
/// scale-up on hover; the scale is a paint-only transform so it never reflows
/// surrounding layout. No visible change on touch platforms (no pointer).
///
/// Material chips (FilterChip/ChoiceChip) and InkWell already hover natively —
/// only wrap genuinely-interactive bare GestureDetector tap targets (BUT-1363).
class HoverableTap extends StatefulWidget {
  const HoverableTap({super.key, required this.child, this.enabled = true});

  final Widget child;

  /// When false, renders [child] untouched — pass the same condition that gates
  /// the tap handler so decorative elements never get a pointer cursor.
  final bool enabled;

  @override
  State<HoverableTap> createState() => _HoverableTapState();
}

class _HoverableTapState extends State<HoverableTap> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.04 : 1.0,
        duration: AppDimensions.animationDurationFast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
