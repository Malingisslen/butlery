// lib/widgets/common/butlery_app_focus_ring.dart
//
// Fokusringen på appnivå (BUT-2148). Den ritas runt den kontroll som har
// tangentbordsfokus när kontrollen inte ritar en egen ring. Därmed kan temats
// fokusfyllning tas bort: enligt beslut D3 får en fokusmarkering bara tas
// bort när ringen sitter på samma kontroll (WCAG 2.4.7).
//
// Samma ring som ButleryFocusRing: 2 px, 3 px utanför kontrollen, ink på
// ljust och papper på mörkt (tokens.json:155-160), och bara vid
// tangentbordsfokus (FocusHighlightMode.traditional).

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';

/// Draws the canonical focus ring around whatever has keyboard focus below
/// it, unless a [ButleryFocusRing] is already showing for it.
///
/// Put it once around the app, in `MaterialApp.builder`, so it paints above
/// every route. A focus node that is a scope or skips traversal is not a
/// control and gets no ring.
class ButleryAppFocusRing extends StatefulWidget {
  const ButleryAppFocusRing({required this.child, super.key});

  final Widget child;

  /// For `MaterialApp.builder`.
  static Widget builder(BuildContext context, Widget? child) =>
      ButleryAppFocusRing(child: child ?? const SizedBox.shrink());

  @override
  State<ButleryAppFocusRing> createState() => _ButleryAppFocusRingState();
}

class _ButleryAppFocusRingState extends State<ButleryAppFocusRing> {
  _Ring? _ring;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocus);
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
    ButleryFocusRing.showing.addListener(_update);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocus);
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    ButleryFocusRing.showing.removeListener(_update);
    super.dispose();
  }

  void _onFocus() => _afterNextFrame();

  void _onHighlightMode(FocusHighlightMode _) => _afterNextFrame();

  /// A focus change is decided after the next frame, never at once. A ring on
  /// a button learns of its focus while the button builds and counts itself
  /// in [ButleryFocusRing.showing] after that frame, so deciding at once
  /// painted the app ring for one frame around a button that rings itself.
  void _afterNextFrame() {
    _schedule();
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _update() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      _schedule();
      return;
    }
    if (!mounted) return;
    final ring = _measure();
    if (ring != _ring) setState(() => _ring = ring);
    // The focused control can move without focus changing (a scroll), so the
    // ring is measured again after every frame while it shows.
    if (ring != null) _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _update();
    });
  }

  _Ring? _measure() {
    if (FocusManager.instance.highlightMode != FocusHighlightMode.traditional) {
      return null;
    }
    if (ButleryFocusRing.showing.value > 0) return null;
    final node = FocusManager.instance.primaryFocus;
    if (node == null || node is FocusScopeNode || node.skipTraversal) {
      return null;
    }
    // A text field's focus node sits on the bare text line; the ring goes
    // around the field's input box, as on a field that rings itself.
    final editing =
        node.context
            ?.findAncestorWidgetOfExactType<EditableText>()
            ?.focusNode ==
        node;
    final field = editing
        ? node.context?.findAncestorStateOfType<State<TextField>>()
        : null;
    final target = (field?.context ?? node.context)?.findRenderObject();
    final self = context.findRenderObject();
    if (target is! RenderBox ||
        !target.attached ||
        !target.hasSize ||
        self is! RenderBox) {
      return null;
    }
    final local =
        (field == null ? null : textFieldInputBox(target)) ??
        Offset.zero & target.size;
    final rect = MatrixUtils.transformRect(target.getTransformTo(self), local);
    if (rect.isEmpty) return null;
    return _Ring(
      rect,
      AppModeColors.focusRing(FocusRingSurface.of(node.context!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ring = _ring;
    return CustomPaint(
      foregroundPainter: ring == null ? null : _AppRingPainter(ring),
      child: widget.child,
    );
  }
}

@immutable
class _Ring {
  const _Ring(this.rect, this.color);

  final Rect rect;
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is _Ring && other.rect == rect && other.color == color;

  @override
  int get hashCode => Object.hash(rect, color);
}

class _AppRingPainter extends CustomPainter {
  const _AppRingPainter(this.ring);

  final _Ring ring;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      ring.rect.inflate(ButleryFocusRing.inflate),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppDimensions.focusRingWidth
        ..color = ring.color,
    );
  }

  @override
  bool shouldRepaint(_AppRingPainter old) => old.ring != ring;
}
