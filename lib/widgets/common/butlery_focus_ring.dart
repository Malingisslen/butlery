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
//
// Ringen visas vid tangentbordsfokus (FocusHighlightMode.traditional), som
// CSS :focus-visible (beslut D3). Det gäller även textfält.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';

/// Tells the focus rings below it which kind of surface they stand on.
///
/// The ring is ink on light and paper on dark (tokens.json:155-160). That
/// follows the theme's brightness, except where a component paints its own
/// surface of the other kind: the subpage top bar stands on surface.ink in
/// light mode too (Komponentark v1:73), and an ink ring there would vanish.
/// Such a component wraps its content in a [FocusRingSurface].
class FocusRingSurface extends InheritedWidget {
  const FocusRingSurface({
    required this.brightness,
    required super.child,
    super.key,
  });

  /// The brightness of the surface the rings below stand on.
  final Brightness brightness;

  /// The surface brightness for rings at [context]: the nearest
  /// [FocusRingSurface], or the theme's brightness.
  static Brightness of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<FocusRingSurface>()
          ?.brightness ??
      Theme.of(context).brightness;

  @override
  bool updateShouldNotify(FocusRingSurface oldWidget) =>
      oldWidget.brightness != brightness;
}

/// What the ring goes around.
enum FocusRingBounds {
  /// The whole child.
  child,

  /// The input box of the text field inside the child: the decorated box
  /// the user types in, without the helper, error or counter line under
  /// it. Falls back to the whole child if no text field box is found.
  textFieldBox,
}

/// Draws the canonical focus ring around [child].
///
/// The ring shows only for keyboard or other traditional focus
/// ([FocusHighlightMode.traditional]), like CSS `:focus-visible`
/// (beslut-paket2 D3, recorded as an interpretation), on buttons and text
/// fields alike.
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
    this.bounds = FocusRingBounds.child,
    super.key,
  });

  /// The control the ring goes around.
  final Widget child;

  /// Focus state reported by the caller, or null to observe [child].
  final bool? focused;

  /// The control's own corner radius.
  final BorderRadius borderRadius;

  /// What the ring goes around.
  final FocusRingBounds bounds;

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

  bool get _visible =>
      _hasFocus &&
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  /// The rectangle the ring goes around, in the child's coordinates, read
  /// at paint time so it always matches the current layout.
  Rect _target(Size childSize) {
    final whole = Offset.zero & childSize;
    if (widget.bounds == FocusRingBounds.child || !mounted) return whole;
    final root = context.findRenderObject();
    if (root is! RenderBox) return whole;
    return _textFieldBox(root) ?? whole;
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
    final color = AppModeColors.focusRing(FocusRingSurface.of(context));
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
                target: _target,
                followsLayout: widget.bounds != FocusRingBounds.child,
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
                target: _target,
                followsLayout: widget.bounds != FocusRingBounds.child,
              ),
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}

/// The input box of the first text field inside [root], in [root]'s
/// coordinates, or null.
///
/// Material's InputDecorator paints its box (fill and border) in a leaf
/// CustomPaint that sits beside the editable text, in the same decorator.
/// So: find the RenderEditable, then walk up to the first ancestor that has
/// such a leaf as a direct child. The helper, error and counter line are
/// separate children of the decorator, outside the box.
Rect? _textFieldBox(RenderBox root) {
  RenderEditable? editable;
  void findEditable(RenderObject node) {
    if (editable != null) return;
    if (node is RenderEditable) {
      editable = node;
      return;
    }
    node.visitChildren(findEditable);
  }

  findEditable(root);
  RenderObject? node = editable?.parent;
  while (node != null) {
    RenderCustomPaint? box;
    node.visitChildren((c) {
      if (box == null &&
          c is RenderCustomPaint &&
          c.child == null &&
          c.foregroundPainter != null) {
        box = c;
      }
    });
    final found = box;
    if (found != null && found.hasSize && found.attached) {
      return MatrixUtils.transformRect(
        found.getTransformTo(root),
        Offset.zero & found.size,
      );
    }
    if (identical(node, root)) break;
    node = node.parent;
  }
  return null;
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.color,
    required this.borderRadius,
    required this.inflate,
    required this.target,
    required this.followsLayout,
  });

  final Color color;
  final BorderRadius borderRadius;

  /// Distance from the control's edge to the middle of the stroke. Negative
  /// draws inside the edge.
  final double inflate;

  /// The rectangle the ring goes around, for a child of the given size.
  final Rect Function(Size childSize) target;

  /// True when [target] reads a layout inside the child, which may change
  /// without this painter changing.
  final bool followsLayout;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = target(size).inflate(inflate);
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
      followsLayout ||
      old.color != color ||
      old.borderRadius != borderRadius ||
      old.inflate != inflate;
}
