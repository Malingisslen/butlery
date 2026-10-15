// lib/widgets/styled/styled_input.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/styled/styled_input_borders.dart';
import 'package:flutter/services.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/styled/field_error_line.dart';
import 'package:butlery/widgets/styled/field_valid_mark.dart';
import 'package:butlery/widgets/styled/labeled_field.dart';
import 'package:butlery/theme/field_text_style.dart';

/// Pre-styled input widgets to eliminate design-in-views violations
/// Provides consistent input styling patterns used throughout the app
class StyledInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;

  /// The validated state: a check and this word at the end of the box,
  /// such as "Ledigt". Not shown while [errorText] is set.
  final String? validText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final EdgeInsetsGeometry? contentPadding;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;

  /// Semantic label for screen readers when no visible label is present.
  /// Falls back to [label] or [hint] if not provided.
  final String? semanticLabel;

  /// Amber warning border for fields that may need review (e.g. low-confidence AI parse).
  final bool showWarning;

  /// words for names and titles, sentences for free text.
  final TextCapitalization textCapitalization;

  /// Off for codes and handles, where a suggestion would rewrite the value.
  final bool autocorrect;

  /// Square corners, as the onboarding screens draw their fields.
  final bool square;

  /// A unit after the text ("min"), and a counter that replaces the length one.
  final String? suffixText, counterText;

  /// The keyboard's action key (done, search, send).
  final ValueChanged<String>? onSubmitted;

  const StyledInput({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.validText,
    this.controller,
    this.onChanged,
    this.onTap,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.contentPadding,
    this.focusNode,
    this.autofillHints,
    this.semanticLabel,
    this.showWarning = false,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.onSubmitted,
    this.square = false,
    this.suffixText,
    this.counterText,
  });

  /// Standard text input
  const StyledInput.text({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.validText,
    this.controller,
    this.onChanged,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.focusNode,
    this.autofillHints,
    this.semanticLabel,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.onSubmitted,
  }) : square = false,
       suffixText = null,
       counterText = null,
       onTap = null,
       enabled = true,
       readOnly = false,
       obscureText = false,
       autofocus = false,
       maxLines = 1,
       minLines = null,
       maxLength = null,
       keyboardType = TextInputType.text,
       textInputAction = TextInputAction.next,
       inputFormatters = null,
       contentPadding = null,
       showWarning = false;

  /// Password input with configurable obscured text
  const StyledInput.password({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.validText,
    this.controller,
    this.onChanged,
    this.validator,
    this.suffixIcon,
    this.focusNode,
    this.obscureText = true,
    this.enabled = true,
    this.semanticLabel,
  }) : square = false,
       suffixText = null,
       counterText = null,
       onTap = null,
       readOnly = false,
       autofocus = false,
       maxLines = 1,
       minLines = null,
       maxLength = null,
       keyboardType = TextInputType.visiblePassword,
       textInputAction = TextInputAction.done,
       inputFormatters = null,
       prefixIcon = const ButleryIcon(ButleryIcons.lock),
       contentPadding = null,
       autofillHints = const [AutofillHints.password],
       showWarning = false,
       textCapitalization = TextCapitalization.none,
       autocorrect = true,
       onSubmitted = null;

  /// Email input with validation
  const StyledInput.email({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.validText,
    this.controller,
    this.onChanged,
    this.validator,
    this.focusNode,
    this.semanticLabel,
  }) : square = false,
       suffixText = null,
       counterText = null,
       onTap = null,
       enabled = true,
       readOnly = false,
       obscureText = false,
       autofocus = false,
       maxLines = 1,
       minLines = null,
       maxLength = null,
       keyboardType = TextInputType.emailAddress,
       textInputAction = TextInputAction.next,
       inputFormatters = null,
       prefixIcon = const ButleryIcon(ButleryIcons.mail),
       suffixIcon = null,
       contentPadding = null,
       autofillHints = const [AutofillHints.email],
       showWarning = false,
       textCapitalization = TextCapitalization.none,
       autocorrect = true,
       onSubmitted = null;

  /// Phone number input
  const StyledInput.phone({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.onChanged,
    this.validator,
    this.focusNode,
    this.semanticLabel,
  }) : square = false,
       suffixText = null,
       counterText = null,
       onTap = null,
       validText = null,
       enabled = true,
       readOnly = false,
       obscureText = false,
       autofocus = false,
       maxLines = 1,
       minLines = null,
       maxLength = null,
       keyboardType = TextInputType.phone,
       textInputAction = TextInputAction.done,
       inputFormatters = null,
       prefixIcon = const ButleryIcon(ButleryIcons.smartphone),
       suffixIcon = null,
       contentPadding = null,
       autofillHints = const [AutofillHints.telephoneNumber],
       showWarning = false,
       textCapitalization = TextCapitalization.none,
       autocorrect = true,
       onSubmitted = null;

  /// Multi-line text input
  const StyledInput.multiline({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.onChanged,
    this.validator,
    this.maxLines = 5,
    this.minLines = 3,
    this.maxLength,
    this.focusNode,
    this.semanticLabel,
  }) : square = false,
       suffixText = null,
       counterText = null,
       onTap = null,
       validText = null,
       enabled = true,
       readOnly = false,
       obscureText = false,
       autofocus = false,
       keyboardType = TextInputType.multiline,
       textInputAction = TextInputAction.newline,
       inputFormatters = null,
       prefixIcon = null,
       suffixIcon = null,
       contentPadding = null,
       autofillHints = null,
       showWarning = false,
       textCapitalization = TextCapitalization.none,
       autocorrect = true,
       onSubmitted = null;

  /// Number input
  const StyledInput.number({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.onChanged,
    this.validator,
    this.focusNode,
    this.semanticLabel,
  }) : square = false,
       suffixText = null,
       counterText = null,
       onTap = null,
       validText = null,
       enabled = true,
       readOnly = false,
       obscureText = false,
       autofocus = false,
       maxLines = 1,
       minLines = null,
       maxLength = null,
       keyboardType = TextInputType.number,
       textInputAction = TextInputAction.done,
       inputFormatters = null,
       prefixIcon = null,
       suffixIcon = null,
       contentPadding = null,
       autofillHints = null,
       showWarning = false,
       textCapitalization = TextCapitalization.none,
       autocorrect = true,
       onSubmitted = null;

  Widget? _suffix() {
    final valid = validText;
    if (valid == null || errorText != null) return suffixIcon;
    final mark = FieldValidMark(valid);
    if (suffixIcon == null) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: mark),
        suffixIcon!,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wrap with Semantics when a semanticLabel is provided but no visible label
    final effectiveSemanticLabel =
        semanticLabel ?? (label == null ? hint : null);

    final borders = styledInputBorders(
      context,
      square: square,
      showWarning: showWarning,
    );

    final textField = TextFormField(
      controller: controller,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      onTap: onTap,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: obscureText,
      autofocus: autofocus,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters:
          inputFormatters ??
          (keyboardType == TextInputType.number
              ? [FilteringTextInputFormatter.digitsOnly]
              : null),
      validator: validator,
      errorBuilder: FieldErrorLine.builder,
      focusNode: focusNode,
      autofillHints: autofillHints,
      style: fieldTextStyle(
        context,
        enabled: enabled,
        base: AppTextStyles.bodyMedium,
      ),
      decoration: InputDecoration(
        hintText: hint,
        helperText: helperText,
        error: errorText == null ? null : FieldErrorLine(errorText!),
        prefixIcon: prefixIcon,
        suffixIcon: _suffix(),
        suffixText: suffixText,
        counterText: counterText,
        contentPadding:
            contentPadding ??
            const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical: (AppDimensions.space8 + AppDimensions.space4),
            ),
        border: borders.base,
        enabledBorder: borders.resting,
        // Focus is the ring outside the box (ButleryFocusRing below); the
        // edge keeps its resting width and colour, focused or not, with or
        // without an error: "fokus är ringen (2 px/3 px offset), kanten
        // byter aldrig tjocklek" (Grafisk manual v6:423; Komponentark
        // v1:657). This replaces BUT-533's 3 px saffron edge.
        focusedBorder: borders.resting,
        errorBorder: borders.error,
        focusedErrorBorder: borders.error,
        // Disabled: 1 px surface.disabled edge on surface.raised, never
        // opacity (Grafisk manual v6:423; Komponentark v1:423
        // light, :514 dark).
        disabledBorder: borders.disabled,
      ),
    );

    if (label != null) {
      return LabeledField(label: label, child: textField);
    }

    // BUT-539: with no label, an explicit Semantics wrapper carries the
    // screen-reader name, hint and current value.
    final field = LabeledField(child: textField);
    if (effectiveSemanticLabel != null) {
      return Semantics(
        label: effectiveSemanticLabel,
        hint: hint,
        value: controller?.text,
        textField: true,
        child: field,
      );
    }

    return field;
  }
}

/// Form field wrapper with consistent spacing and error handling
class StyledFormField extends StatelessWidget {
  final Widget child;
  final String? label;
  final bool isRequired;
  final String? errorText;
  final String? helperText;

  const StyledFormField({
    super.key,
    required this.child,
    this.label,
    this.isRequired = false,
    this.errorText,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      label: label != null && isRequired
          ? context.l10n.a11yRequiredFieldSuffix
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Row(
              children: [
                Text(
                  label!,
                  style: AppTextStyles.labelText,
                ),
                if (isRequired)
                  ExcludeSemantics(
                    child: Text(
                      ' *',
                      style: AppTextStyles.labelText.copyWith(
                        color: cs.error,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.space8),
          ],
          child,
          if (errorText != null) ...[
            const SizedBox(height: AppDimensions.space4),
            Text(
              errorText!,
              style: AppTextStyles.captionText.copyWith(
                color: cs.error,
              ),
            ),
          ],
          if (helperText != null && errorText == null) ...[
            const SizedBox(height: AppDimensions.space4),
            Text(
              helperText!,
              style: AppTextStyles.captionText,
            ),
          ],
          const SizedBox(height: AppDimensions.space16),
        ],
      ),
    );
  }
}
