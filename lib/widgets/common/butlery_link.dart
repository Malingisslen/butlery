// lib/widgets/common/butlery_link.dart
//
// Länken: 48 dp träffyta och tangentbordsfokus med den kanoniska ringen
// (fas2/block288-uxfrysning.json, interaktion CSR::ROLE::link::DEFAULT och
// CSR::ROLE::link::FOCUSED; tokens.json touchTarget och focusRing;
// tillgänglighetshandoff HA285-A).
//
// En länk i löpande text blir lika hög som träffytan, så raden den står på
// blir högre. Texten står kvar på radens baslinje.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// A link: [child] in a box of at least 48 × 48 dp that takes keyboard
/// focus, draws the canonical focus ring around the box, and reads as a link
/// to a screen reader.
///
/// [child] carries the link's look (text.link and an underline). Inside
/// running text, put it in a [WidgetSpan] with
/// `PlaceholderAlignment.baseline`.
class ButleryLink extends StatelessWidget {
  const ButleryLink({
    required this.onTap,
    required this.child,
    this.semanticLabel,
    this.surface = PressSurface.base,
    super.key,
  });

  final VoidCallback? onTap;
  final Widget child;

  /// The name a screen reader reads with the link role.
  final String? semanticLabel;

  /// The surface the link stands on, which decides its pressed fill.
  final PressSurface surface;

  @override
  Widget build(BuildContext context) {
    return ButleryControlFocus(
      child: PressFill(
        surface: surface,
        child: InkWell(
          onTap: onTap,
          // Below the InkWell so its tap and focus merge into this node; the
          // label replaces the visible text, which would otherwise read twice.
          child: Semantics(
            link: true,
            label: semanticLabel,
            excludeSemantics: semanticLabel != null,
            child: _Centered(child: child),
          ),
        ),
      ),
    );
  }
}

/// [Align] at the child's size, centring it, that can also answer a dry
/// baseline. A link in running text is a baseline-aligned [WidgetSpan], and a
/// dialog measures its content dry ([IntrinsicWidth]); [Align]'s render box
/// does not implement `computeDryBaseline` and throws there.
class _Centered extends SingleChildRenderObjectWidget {
  const _Centered({required super.child});

  @override
  RenderPositionedBox createRenderObject(BuildContext context) =>
      _RenderCentered(textDirection: Directionality.maybeOf(context));

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPositionedBox renderObject,
  ) {
    renderObject.textDirection = Directionality.maybeOf(context);
  }
}

class _RenderCentered extends RenderPositionedBox {
  _RenderCentered({super.textDirection})
    : super(widthFactor: 1, heightFactor: 1);

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final child = this.child;
    if (child == null) return null;
    final loose = constraints.loosen();
    final childBaseline = child.getDryBaseline(loose, baseline);
    if (childBaseline == null) return null;
    final free = getDryLayout(constraints) - child.getDryLayout(loose);
    return childBaseline + resolvedAlignment.alongOffset(free as Offset).dy;
  }
}
