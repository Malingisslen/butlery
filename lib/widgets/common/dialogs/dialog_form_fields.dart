/// 🔍 AI INFO BLOCK:
/// Component: Dialog Form Fields - Common form field patterns for dialogs
/// File: lib/widgets/common/dialogs/dialog_form_fields.dart
/// Quick Guide: Prebuilt dialog form fields with consistent validation and styling
/// Dependencies IN: FormValidators, ValidationUtils, AppDimensions, l10n, Material UI,
///   SwedishDecimalInputFormatter/parseSwedishDecimal
/// Dependencies OUT: create_group_dialog.dart
/// Data flow: User input -> Validation -> Controller update
/// State management: TextEditingController-based
/// Purpose: One place for a dialog's field validation and styling (text,
///   dropdown, checkbox, switch)
/// Common issues: Validation consistency, styling uniformity, loading states
/// Test coverage: Form field validation tests with edge cases
/// Performance: Efficient validation, consistent styling
/// Analytics: None
/// Code smells: One production caller only (create_group_dialog.dart)
/// Connected to: FormValidators
/// Used in phases: Code Consolidation Phase - Form Field Unification

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/core/utils/swedish_decimal_input.dart';
import 'package:butlery/core/utils/validation_utils.dart';

/// Static builders for a dialog's form fields. Every TEXT variant funnels
/// through [buildTextFormField]; the dropdown, checkbox and switch builders
/// stand on their own.
class DialogFormFields {
  /// Standard text form field with consistent validation and styling
  static Widget buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    int? maxLength,
    int maxLines = 1,
    bool enabled = true,
    bool required = true,
    int minLength = 1,
    int maxLengthLimit = 100,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? customValidator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
          border: const OutlineInputBorder(),
          counterText: maxLength != null ? null : '',
        ),
        maxLength: maxLength,
        maxLines: maxLines,
        enabled: enabled,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        // BUT-517 follow-up: contentFilter must NEVER be bypassable. The old
        // shape `customValidator ?? combine([...defaults, contentFilter])`
        // silently dropped the profanity gate whenever a caller passed a
        // customValidator (foot-gun for any future UGC-bearing dialog field).
        // Always compose; customValidator runs first so its error wins on its
        // own concern, and contentFilter is the unconditional final step.
        validator: FormValidators.combine([
          ?customValidator,
          if (required)
            (value) =>
                ValidationUtils.validateRequired(value, fieldName: labelText),
          // Length only applies when there IS content — otherwise an optional
          // field with the default minLength=1 would always reject empty
          // input (regression caught when buildPhoneField etc. compose this
          // chain without explicitly opting out of length-checking).
          (value) {
            if (value == null || value.isEmpty) return null;
            return ValidationUtils.validateLength(
              value,
              minLength: minLength,
              maxLength: maxLengthLimit,
              fieldName: labelText,
            );
          },
          FormValidators.contentFilter(labelText),
        ]),
      ),
    );
  }

  /// Name field with standard validation.
  static Widget buildNameField({
    required BuildContext context,
    required TextEditingController controller,
    String? labelText,
    String? hintText,
    IconData prefixIcon = Icons.label_outline,
    bool enabled = true,
    int maxLength = 50,
    int minLength = 2,
  }) {
    return buildTextFormField(
      controller: controller,
      labelText: labelText ?? context.l10n.commonName,
      hintText: hintText,
      prefixIcon: prefixIcon,
      maxLength: maxLength,
      enabled: enabled,
      minLength: minLength,
      maxLengthLimit: maxLength,
    );
  }

  /// Description field with standard validation
  static Widget buildDescriptionField({
    required BuildContext context,
    required TextEditingController controller,
    String? labelText,
    String? hintText,
    IconData prefixIcon = Icons.description_outlined,
    bool enabled = true,
    int maxLength = 200,
    int maxLines = 3,
  }) {
    return buildTextFormField(
      controller: controller,
      labelText: labelText ?? context.l10n.dialogDescriptionLabel,
      hintText: hintText ?? context.l10n.dialogDescriptionHint,
      prefixIcon: prefixIcon,
      maxLength: maxLength,
      maxLines: maxLines,
      enabled: enabled,
      required: false, // Description is usually optional
      maxLengthLimit: maxLength,
    );
  }

  /// Amount/quantity field with numeric validation.
  ///
  /// Reads and writes the Swedish decimal COMMA, through the same formatter and
  /// parser every other hand-typed amount in the app uses. It did neither until
  /// BUT-1920: it filtered the field down to digits and a PERIOD with an
  /// ANCHORED pattern, so everything from a typed comma onward was discarded,
  /// and read what was left with a bare `double.tryParse`. It had no callers in
  /// `lib/` at the time, so the bug was waiting for whoever reached for the
  /// shared builder first.
  static Widget buildAmountField({
    required BuildContext context,
    required TextEditingController controller,
    String? labelText,
    String? hintText,
    IconData prefixIcon = Icons.numbers,
    bool enabled = true,
    double minValue = 0.1,
    double maxValue = 9999.0,
  }) {
    final effectiveLabelText = labelText ?? context.l10n.dialogAmountLabel;
    return buildTextFormField(
      controller: controller,
      labelText: effectiveLabelText,
      hintText: hintText ?? context.l10n.dialogAmountHint,
      prefixIcon: prefixIcon,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const [SwedishDecimalInputFormatter()],
      customValidator: (value) {
        if (value == null || value.trim().isEmpty) {
          return context.l10n.dialogAmountRequired;
        }

        final amount = parseSwedishDecimal(value);
        if (amount == null) {
          return context.l10n.dialogAmountInvalid;
        }

        if (amount < minValue) {
          return context.l10n.dialogAmountMin(minValue.toInt());
        }

        if (amount > maxValue) {
          return context.l10n.dialogAmountMax(maxValue.toInt());
        }

        return null;
      },
    );
  }

  /// Email field with email validation
  static Widget buildEmailField({
    required BuildContext context,
    required TextEditingController controller,
    String? labelText,
    String? hintText,
    bool enabled = true,
  }) {
    return buildTextFormField(
      controller: controller,
      labelText: labelText ?? context.l10n.dialogEmailLabel,
      hintText: hintText ?? context.l10n.dialogEmailHint,
      prefixIcon: Icons.email_outlined,
      enabled: enabled,
      keyboardType: TextInputType.emailAddress,
      customValidator: FormValidators.authEmail(),
      maxLengthLimit: 100,
    );
  }

  /// URL field with URL validation
  static Widget buildUrlField({
    required BuildContext context,
    required TextEditingController controller,
    String? labelText,
    String? hintText,
    bool enabled = true,
    bool required = false,
  }) {
    final effectiveLabelText = labelText ?? context.l10n.dialogUrlLabel;
    return buildTextFormField(
      controller: controller,
      labelText: effectiveLabelText,
      hintText: hintText ?? context.l10n.dialogUrlHint,
      prefixIcon: Icons.link,
      enabled: enabled,
      keyboardType: TextInputType.url,
      required: required,
      customValidator: (value) {
        if (!required && (value == null || value.trim().isEmpty)) {
          return null; // Optional field
        }

        if (required) {
          final requiredResult = FormValidators.required(effectiveLabelText)(
            value,
          );
          if (requiredResult != null) return requiredResult;
        }

        if (value != null && value.trim().isNotEmpty) {
          // Basic URL validation
          final urlPattern = RegExp(
            r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
          );
          if (!urlPattern.hasMatch(value.trim())) {
            return context.l10n.dialogInvalidUrl;
          }
        }

        return null;
      },
      maxLengthLimit: 500,
    );
  }

  /// Password field with password validation
  static Widget buildPasswordField({
    required BuildContext context,
    required TextEditingController controller,
    String? labelText,
    String? hintText,
    bool enabled = true,
    bool obscureText = true,
    int minLength = 6,
  }) {
    return buildTextFormField(
      controller: controller,
      labelText: labelText ?? context.l10n.authPassword,
      hintText: hintText,
      prefixIcon: Icons.lock_outline,
      enabled: enabled,
      customValidator: FormValidators.authPassword(),
      maxLengthLimit: 128,
    );
  }

  /// Search field with search-specific styling
  static Widget buildSearchField({
    required BuildContext context,
    required TextEditingController controller,
    String? labelText,
    String? hintText,
    bool enabled = true,
    VoidCallback? onClear,
  }) {
    return buildTextFormField(
      controller: controller,
      labelText: labelText ?? context.l10n.commonSearch,
      hintText: hintText ?? context.l10n.dialogSearchHint,
      prefixIcon: Icons.search,
      enabled: enabled,
      required: false,
      customValidator: (value) => null, // No validation for search
      maxLengthLimit: 100,
    );
  }

  /// Phone number field with phone validation
  static Widget buildPhoneField({
    required BuildContext context,
    required TextEditingController controller,
    String? labelText,
    String? hintText,
    bool enabled = true,
    bool required = false,
  }) {
    return buildTextFormField(
      controller: controller,
      labelText: labelText ?? context.l10n.dialogPhoneLabel,
      hintText: hintText ?? '+46 70 123 45 67',
      prefixIcon: Icons.phone_outlined,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      required: required,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
      ],
      customValidator: (value) {
        if (!required && (value == null || value.trim().isEmpty)) {
          return null;
        }

        if (required) {
          final requiredResult = FormValidators.required(
            labelText ?? context.l10n.dialogPhoneLabel,
          )(value);
          if (requiredResult != null) return requiredResult;
        }

        if (value != null && value.trim().isNotEmpty) {
          // Basic phone validation - at least 10 digits
          final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
          if (digitsOnly.length < 10) {
            return context.l10n.dialogPhoneInvalid;
          }
        }

        return null;
      },
      maxLengthLimit: 20,
    );
  }

  /// Dropdown field with standard styling
  static Widget buildDropdownField<T>({
    required BuildContext context,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    bool enabled = true,
    bool required = true,
    String? Function(T?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: enabled ? onChanged : null,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
          border: const OutlineInputBorder(),
        ),
        validator:
            validator ??
            (required
                ? (value) => value == null
                      ? context.l10n.dialogFieldRequired(labelText)
                      : null
                : null),
      ),
    );
  }

  /// Checkbox field with standard styling
  static Widget buildCheckboxField({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String title,
    String? subtitle,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
      child: CheckboxListTile(
        value: value,
        onChanged: enabled ? onChanged : null,
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  /// Switch field with standard styling
  static Widget buildSwitchField({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    String? subtitle,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
      child: SwitchListTile(
        value: value,
        onChanged: enabled ? onChanged : null,
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
