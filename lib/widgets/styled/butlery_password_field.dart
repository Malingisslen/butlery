import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/buttons/app_icon_button.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/styled/field_valid_mark.dart';
import 'package:butlery/widgets/styled/labeled_field.dart';

/// A password field: the label above the box, a show/hide button at its
/// end, and optionally the validated mark before the button, as a repeated
/// password that matches shows "Lösenorden matchar".
class ButleryPasswordField extends StatefulWidget {
  const ButleryPasswordField({
    required this.label,
    required this.controller,
    this.fieldKey,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
    this.validText,
    super.key,
  });

  final String label;
  final TextEditingController controller;

  /// Key on the inner TextField, for finders that read the field itself.
  final Key? fieldKey;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;

  /// The validated state's word, shown with a check before the button.
  final String? validText;

  /// Whether a repeated password matches the first: only once something is
  /// typed, so an empty pair is not called a match.
  static bool matches(String password, String repeated) =>
      repeated.isNotEmpty && repeated == password;

  @override
  State<ButleryPasswordField> createState() => _ButleryPasswordFieldState();
}

class _ButleryPasswordFieldState extends State<ButleryPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final toggle = AppIconButton(
      icon: _obscured ? ButleryIcons.eye : ButleryIcons.eyeOff,
      semanticLabel: _obscured
          ? context.l10n.tooltipShowPassword
          : context.l10n.tooltipHidePassword,
      onPressed: () => setState(() => _obscured = !_obscured),
    );
    final valid = widget.validText;
    return LabeledField(
      label: widget.label,
      child: TextField(
        key: widget.fieldKey,
        controller: widget.controller,
        focusNode: widget.focusNode,
        obscureText: _obscured,
        autofillHints: widget.autofillHints,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          // Always a Row, so the button keeps its place in the tree and its
          // focus when the mark comes and goes.
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (valid != null) Flexible(child: FieldValidMark(valid)),
              toggle,
            ],
          ),
        ),
      ),
    );
  }
}
