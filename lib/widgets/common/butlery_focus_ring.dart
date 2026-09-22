// lib/widgets/common/butlery_focus_ring.dart
//
// Fokusringen — en ring för hela systemet.
//
// Kanon: 2 px ring, 3 px utanför kontrollen, ink på ljust och papper på
// mörkt, aldrig saffran och aldrig en tjockare kant i stället för ringen
// (tokens.json:155-160; Grafisk manual v6:209, :582; Komponentark v1:393,
// :657).
//
// Ringen målas i närmaste Overlay (OverlayPortal), inte i kontrollens eget
// träd. Därför klipps den inte av en ClipRRect, ett Card eller en ListView
// runt kontrollen, trots att den ligger 3 px utanför kontrollens kant. Den
// målas framför sin egen route men bakom routes ovanpå (ark, dialoger).
// Saknas Overlay målas ringen i kontrollens kant i stället, med samma färg
// och bredd.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';

/// When the ring shows.
enum FocusRingVisibility {
  /// Only while the focus came from a keyboard or other traditional input
  /// ([FocusHighlightMode.traditional]), like CSS `:focus-visible` for
  /// buttons and other controls.
  keyboard,

  /// On every focus. For text entry, which CSS `:focus-visible` also marks
  /// on pointer focus, because the user is about to type.
  always,
}

/// Draws the canonical focus ring around [child].
///
/// The ring observes focus; it never takes focus itself and does not change
/// the traversal order. With [focused] null it follows focus anywhere inside
/// [child]. A caller that already knows the focus state (a button theme
/// reading its widget states) passes [focused] instead.
///
/// The ring runs parallel to the control's corners: [borderRadius] is the
/// control's own radius, and the ring's radius is that plus the gap, the way
/// a CSS outline follows border-radius. A square control gets a square ring.
class ButleryFocusRing extends StatefulWidget {
  const ButleryFocusRing({
    required this.child,
    this.focused,
    this.borderRadius = BorderRadius.zero,
    this.visibility = FocusRingVisibility.keyboard,
    super.key,
  });

  /// The control the ring goes around.
  final Widget child;

  /// Focus state reported by the caller, or null to observe [child].
  final bool? focused;

  /// The control's own corner radius.
  final BorderRadius borderRadius;

  /// When the ring shows.
  final FocusRingVisibility visibility;

  /// Distance from the control's edge to the middle of the ring's stroke.
  static const double inflate =
      AppDimensions.focusRingOffset + AppDimensions.focusRingWidth / 2;

  @override
  State<ButleryFocusRing> createState() => _ButleryFocusRingState();
}

class _ButleryFocusRingState extends State<ButleryFocusRing> {
  final OverlayPortalController _portal = OverlayPortalController(
    debugLabel: 'ButleryFocusRing',
  );
  bool _observedFocus = false;

  bool get _hasFocus => widget.focused ?? _observedFocus;

  bool get _visible {
    if (!_hasFocus) return false;
    return switch (widget.visibility) {
      FocusRingVisibility.always => true,
      FocusRingVisibility.keyboard =>
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional,
    };
  }

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
    _sync();
  }

  @override
  void didUpdateWidget(ButleryFocusRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    super.dispose();
  }

  void _onHighlightMode(FocusHighlightMode mode) {
    if (!mounted) return;
    setState(_sync);
  }

  void _onFocusChange(bool hasFocus) {
    if (!mounted) return;
    setState(() {
      _observedFocus = hasFocus;
      _sync();
    });
  }

  bool _syncScheduled = false;

  /// Shows or hides the ring in the Overlay. The portal may not be toggled
  /// while the tree is building (a button reports its focus from inside its
  /// own build), so a toggle requested then runs right after the frame.
  void _sync() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_syncScheduled) return;
      _syncScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _syncScheduled = false;
        if (mounted) _sync();
      });
      return;
    }
    if (_visible) {
      if (!_portal.isShowing) _portal.show();
    } else if (_portal.isShowing) {
      _portal.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppModeColors.focusRing(Theme.of(context).brightness);
    Widget child = widget.child;
    if (widget.focused == null) {
      child = Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onFocusChange: _onFocusChange,
        child: child,
      );
    }

    if (Overlay.maybeOf(context) == null) {
      // No Overlay to paint into: draw the ring at the control's edge.
      return CustomPaint(
        foregroundPainter: _visible
            ? _RingPainter(
                color: color,
                borderRadius: widget.borderRadius,
                inflate: -AppDimensions.focusRingWidth / 2,
              )
            : null,
        child: child,
      );
    }

    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: (context, info) => IgnorePointer(
        child: Align(
          alignment: Alignment.topLeft,
          child: Transform(
            transform: info.childPaintTransform,
            child: CustomPaint(
              // A copy: the layout protocol forbids adopting another render
              // object's size as this one's.
              size: Size(info.childSize.width, info.childSize.height),
              painter: _RingPainter(
                color: color,
                borderRadius: widget.borderRadius,
                inflate: ButleryFocusRing.inflate,
              ),
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.color,
    required this.borderRadius,
    required this.inflate,
  });

  final Color color;
  final BorderRadius borderRadius;

  /// Distance from the control's edge to the middle of the stroke. Negative
  /// draws inside the edge.
  final double inflate;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).inflate(inflate);
    Radius grow(Radius r) => r == Radius.zero
        ? Radius.zero
        : Radius.elliptical(
            (r.x + inflate).clamp(0, double.infinity),
            (r.y + inflate).clamp(0, double.infinity),
          );
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: grow(borderRadius.topLeft),
      topRight: grow(borderRadius.topRight),
      bottomLeft: grow(borderRadius.bottomLeft),
      bottomRight: grow(borderRadius.bottomRight),
    ).scaleRadii();
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppDimensions.focusRingWidth
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.color != color ||
      old.borderRadius != borderRadius ||
      old.inflate != inflate;
}
