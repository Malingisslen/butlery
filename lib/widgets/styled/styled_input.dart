// lib/widgets/styled/styled_input.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';

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
        contentPadding = null;

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
        autofillHints = const [AutofillHints.password];

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
        autofillHints = const [AutofillHints.email];

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
        autofillHints = const [AutofillHints.telephoneNumber];

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
        autofillHints = null;

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
        autofillHints = null;

  /// Search input
  const StyledInput.search({
    super.key,
    this.hint,
    this.controller,
    this.onChanged,
    this.suffixIcon,
    this.focusNode,
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
        autofillHints = null;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
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
            color: Theme.of(context).colorScheme.outline,
            width: AppDimensions.borderWidthStandard,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: AppDimensions.borderWidthThick,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: AppDimensions.borderWidthStandard,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: AppDimensions.borderWidthThick,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: AppDimensions.opacityHalf),
            width: AppDimensions.borderWidthStandard,
          ),
        ),
        filled: true,
        fillColor: enabled
            ? AppColors.cardWhite
            : AppColors.cardWhite.withValues(alpha: AppDimensions.opacityDark),
      ),
    );
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
    return Column(
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
                    color: AppColors.error,
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
              color: AppColors.error,
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
    );
  }
}
