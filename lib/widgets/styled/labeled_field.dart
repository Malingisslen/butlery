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
    final field = ButleryFocusRing(
      borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      bounds: FocusRingBounds.textFieldBox,
      child: child,
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
        const SizedBox(height: AppDimensions.spacingSm),
        Semantics(label: label, child: field),
      ],
    );
  }
}
