/// Platform-adaptive text field widget.
/// Uses CupertinoTextField on iOS, TextFormField on Android.

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';

/// A platform-adaptive text field.
/// Automatically uses CupertinoTextField on iOS and Material TextFormField on Android.
class AdaptiveTextField extends StatelessWidget {
  /// Creates a platform-adaptive text field.
  const AdaptiveTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.label,
    this.helperText,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
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
    this.prefix,
    this.suffix,
    this.focusNode,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
  });

  /// Controller for the text field.
  final TextEditingController? controller;

  /// Placeholder text shown when the field is empty.
  final String? placeholder;

  /// Label text shown above the field (Material) or as placeholder (iOS).
  final String? label;

  /// Helper text shown below the field.
  final String? helperText;

  /// Error text shown below the field.
  final String? errorText;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits (e.g., presses enter).
  final ValueChanged<String>? onSubmitted;

  /// Called when the field is tapped.
  final VoidCallback? onTap;

  /// Whether the field is enabled.
  final bool enabled;

  /// Whether the field is read-only.
  final bool readOnly;

  /// Whether to obscure the text (for passwords).
  final bool obscureText;

  /// Whether to autofocus this field.
  final bool autofocus;

  /// Maximum number of lines.
  final int? maxLines;

  /// Minimum number of lines.
  final int? minLines;

  /// Maximum character length.
  final int? maxLength;

  /// Keyboard type to use.
  final TextInputType? keyboardType;

  /// Text input action button.
  final TextInputAction? textInputAction;

  /// Input formatters for validation.
  final List<TextInputFormatter>? inputFormatters;

  /// Validator function for form validation.
  final String? Function(String?)? validator;

  /// Widget to show at the start of the field.
  final Widget? prefix;

  /// Widget to show at the end of the field.
  final Widget? suffix;

  /// Focus node for this field.
  final FocusNode? focusNode;

  /// Autofill hints for the field.
  final Iterable<String>? autofillHints;

  /// Text capitalization behavior.
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isIOS) {
      return _buildCupertinoTextField(context);
    }
    return _buildMaterialTextField(context);
  }

  Widget _buildCupertinoTextField(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label (iOS shows it above the field)
        if (label != null) ...[
          Text(
            label!,
            style: AppTextStyles.labelMedium.copyWith(
              color: hasError ? Theme.of(context).colorScheme.error : null,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
        ],
        // Cupertino text field
        CupertinoTextField(
          controller: controller,
          placeholder: placeholder ?? label,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
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
          inputFormatters: inputFormatters,
          focusNode: focusNode,
          autofillHints: autofillHints,
          textCapitalization: textCapitalization,
          style: AppTextStyles.bodyMedium,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingSm + AppDimensions.spacingXs,
          ),
          decoration: BoxDecoration(
            color: enabled
                ? CupertinoColors.systemBackground.resolveFrom(context)
                : CupertinoColors.systemGrey6.resolveFrom(context),
            border: Border.all(
              color: hasError
                  ? CupertinoColors.systemRed
                  : CupertinoColors.systemGrey4.resolveFrom(context),
              width: hasError ? 2.0 : 1.0,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
          ),
          prefix: prefix != null
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppDimensions.spacingSm,
                  ),
                  child: prefix,
                )
              : null,
          suffix: suffix != null
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: AppDimensions.spacingSm,
                  ),
                  child: suffix,
                )
              : null,
        ),
        // Helper or error text
        if (helperText != null || errorText != null) ...[
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            errorText ?? helperText ?? '',
            style: AppTextStyles.labelSmall.copyWith(
              color: hasError
                  ? CupertinoColors.systemRed
                  : CupertinoColors.systemGrey,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMaterialTextField(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final restingBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
      borderSide: BorderSide(
        color: cs.outline,
        width: AppDimensions.borderWidthStandard,
      ),
    );
    final restingErrorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
      borderSide: BorderSide(
        color: cs.error,
        width: AppDimensions.borderWidthStandard,
      ),
    );
    // Focus is the ring outside the input box, shown for keyboard focus
    // (decision D3); the edge keeps its resting width and colour: "fokus är
    // ringen (2 px/3 px offset), kanten byter aldrig tjocklek" (Grafisk
    // manual v6:423; Komponentark v1:657).
    return ButleryFocusRing(
      borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
      bounds: FocusRingBounds.textFieldBox,
      child: _materialField(context, restingBorder, restingErrorBorder),
    );
  }

  Widget _materialField(
    BuildContext context,
    InputBorder restingBorder,
    InputBorder restingErrorBorder,
  ) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
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
      inputFormatters: inputFormatters,
      validator: validator,
      focusNode: focusNode,
      autofillHints: autofillHints,
      textCapitalization: textCapitalization,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: placeholder,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefix,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingSm + AppDimensions.spacingXs,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
          borderSide: const BorderSide(),
        ),
        enabledBorder: restingBorder,
        focusedBorder: restingBorder,
        errorBorder: restingErrorBorder,
        focusedErrorBorder: restingErrorBorder,
        // Disabled: 1 px surface.disabled edge on the same surface.raised
        // fill, never opacity (Grafisk manual v6:423; Komponentark v1:423
        // light, :514 dark).
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
          borderSide: BorderSide(
            color: AppModeColors.surfaceDisabled(Theme.of(context).brightness),
            width: AppDimensions.borderWidthStandard,
          ),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }
}
