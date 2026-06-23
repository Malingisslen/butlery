import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Inline warning row with icon and text.
///
/// Replaces the common Row+Icon+SizedBox+Expanded(Text) pattern
/// used across many views for inline status/warning messages.
class InlineWarning extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final TextStyle? textStyle;

  const InlineWarning({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppDimensions.iconSizeS, color: color),
        const SizedBox(width: AppDimensions.spacingXs),
        Expanded(
          child: Text(
            text,
            style:
                textStyle ??
                AppTextStyles.bodySmall.copyWith(
                  color: color,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ),
      ],
    );
  }
}
