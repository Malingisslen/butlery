// lib/widgets/styled/styled_input.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Pre-styled input widgets to eliminate design-in-views violations
/// Provides consistent input styling patterns used throughout the app
class StyledInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
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

  const StyledInput({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
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
  });

  /// Standard text input
  const StyledInput.text({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.onChanged,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.focusNode,
    this.autofillHints,
    this.semanticLabel,
  })  : onTap = null,
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
    this.controller,
    this.onChanged,
    this.validator,
    this.suffixIcon,
    this.focusNode,
    this.obscureText = true,
    this.enabled = true,
    this.semanticLabel,
  })  : onTap = null,
        readOnly = false,
        autofocus = false,
        maxLines = 1,
        minLines = null,
        maxLength = null,
        keyboardType = TextInputType.visiblePassword,
        textInputAction = TextInputAction.done,
        inputFormatters = null,
        prefixIcon = const Icon(Icons.lock_outline),
        contentPadding = null,
        autofillHints = const [AutofillHints.password],
        showWarning = false;

  /// Email input with validation
  const StyledInput.email({
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
  })  : onTap = null,
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
        prefixIcon = const Icon(Icons.email),
        suffixIcon = null,
        contentPadding = null,
        autofillHints = const [AutofillHints.email],
        showWarning = false;

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
  })  : onTap = null,
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
        prefixIcon = const Icon(Icons.phone),
        suffixIcon = null,
        contentPadding = null,
        autofillHints = const [AutofillHints.telephoneNumber],
        showWarning = false;

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
  })  : onTap = null,
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
        showWarning = false;

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
  })  : onTap = null,
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
        showWarning = false;

  /// Search input
  const StyledInput.search({
    super.key,
    this.hint,
    this.controller,
    this.onChanged,
    this.suffixIcon,
    this.focusNode,
    this.semanticLabel,
  })  : label = null,
        helperText = null,
        errorText = null,
        onTap = null,
        enabled = true,
        readOnly = false,
        obscureText = false,
        autofocus = false,
        maxLines = 1,
        minLines = null,
        maxLength = null,
        keyboardType = TextInputType.text,
        textInputAction = TextInputAction.search,
        inputFormatters = null,
        validator = null,
        prefixIcon = const Icon(Icons.search),
        contentPadding = null,
        autofillHints = null,
        showWarning = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Wrap with Semantics when a semanticLabel is provided but no visible label
    final effectiveSemanticLabel =
        semanticLabel ?? (label == null ? hint : null);

    final field = TextFormField(
      controller: controller,
      onChanged: onChanged,
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
      inputFormatters: inputFormatters ??
          (keyboardType == TextInputType.number
              ? [FilteringTextInputFormatter.digitsOnly]
              : null),
      validator: validator,
      focusNode: focusNode,
      autofillHints: autofillHints,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        contentPadding: contentPadding ??
            const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMd,
              vertical: (AppDimensions.spacingSm + AppDimensions.spacingXs),
            ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
          borderSide: const BorderSide(),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
          borderSide: BorderSide(
            color: showWarning ? context.butleryColors.warning : cs.outline,
            width: AppDimensions.borderWidthStandard,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
          // BUT-533: rust focus ring at 3px — matches global InputDecoration
          // theme so keyboard navigation is visibly trackable on cream.
          borderSide: const BorderSide(
            color: AppColors.rust,
            width: AppDimensions.borderWidthThick + 1,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
          borderSide: BorderSide(
            color: cs.error,
            width: AppDimensions.borderWidthStandard,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
          borderSide: BorderSide(
            color: cs.error,
            width: AppDimensions.borderWidthThick,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
          borderSide: BorderSide(
            color: cs.outline.withValues(alpha: AppDimensions.opacityHalf),
            width: AppDimensions.borderWidthStandard,
          ),
        ),
        filled: true,
        fillColor: enabled
            ? cs.surfaceContainerHighest
            : cs.surfaceContainerHighest
                .withValues(alpha: AppDimensions.opacityDark),
      ),
    );

    // BUT-539: When no visible label is provided, Material's TextField cannot
    // synthesize a screen-reader label from labelText, so an explicit Semantics
    // wrapper carries label + hint + current value. When a visible label IS
    // present, TextField's built-in Semantics already covers all three slots —
    // wrapping again would double-announce.
    if (effectiveSemanticLabel != null && label == null) {
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
      label:
          label != null ? (isRequired ? '$label (obligatorisk)' : label) : null,
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
                  Text(
                    ' *',
                    style: AppTextStyles.labelText.copyWith(
                      color: cs.error,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          child,
          if (errorText != null) ...[
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              errorText!,
              style: AppTextStyles.captionText.copyWith(
                color: cs.error,
              ),
            ),
          ],
          if (helperText != null && errorText == null) ...[
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              helperText!,
              style: AppTextStyles.captionText,
            ),
          ],
          const SizedBox(height: AppDimensions.spacingMd),
        ],
      ),
    );
  }
}
