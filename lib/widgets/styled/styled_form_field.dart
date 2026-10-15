// lib/widgets/styled/styled_form_field.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

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
