import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// The line of help under a field, such as the rule for a password. It stays
/// in place while the field is in error, so the rule is read before the
/// mistake and not only after it.
class FieldHelperLine extends StatelessWidget {
  const FieldHelperLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space8),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
