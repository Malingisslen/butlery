import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';

/// The frame every text field stands in (Komponentark v1 §11): the label
/// above the box, not floating in its edge, and the focus ring around the
/// box. [child] is a TextField or TextFormField whose decoration carries no
/// labelText; give a TextFormField `errorBuilder: FieldErrorLine.builder` so
/// its errors carry the glyph too.
class LabeledField extends StatelessWidget {
  final String? label;
  final Widget child;

  const LabeledField({super.key, this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    // The ring goes around the input box only, not the helper, error or
    // counter line under it, and shows for keyboard focus (decision D3).
    final field = _TapTargetFrame(
      semanticLabel: label,
      child: ButleryFocusRing(
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        bounds: FocusRingBounds.textFieldBox,
        child: child,
      ),
    );
    if (label == null) return field;

    // The visible label is excluded and the field takes its name from a
    // Semantics label, so the text field node reads the label and value
    // once, as a floating label did.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(
            label!,
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(
          height: AppDimensions.space8 - AppDimensions.fieldTapPad,
        ),
        field,
      ],
    );
  }
}

/// The box is drawn [AppDimensions.controlVisualHeight] tall; this pads the
/// hit area to the 48 dp touch target (B-03) and hands a tap in the padding
/// to the field inside.
class _TapTargetFrame extends StatelessWidget {
  final Widget child;
  final String? semanticLabel;

  const _TapTargetFrame({required this.child, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    // MergeSemantics gives the field's node the frame's 48 dp rect, so a
    // screen reader's touch target is the same as the hit area.
    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        excludeFromSemantics: true,
        onTap: () => _focusField(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.fieldTapPad,
          ),
          child: semanticLabel == null
              ? child
              : Semantics(label: semanticLabel, child: child),
        ),
      ),
    );
  }

  static void _focusField(BuildContext context) {
    EditableTextState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is EditableTextState) {
        found = element.state as EditableTextState;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    if (found != null && !found!.widget.readOnly) found!.requestKeyboard();
  }
}
