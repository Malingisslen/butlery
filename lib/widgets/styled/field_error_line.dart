import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// The line under a field in error: a status glyph and the message, both in
/// danger, so the error never rests on colour alone (Komponentark v1 §11:
/// "Fel beskrivs alltid i text, aldrig bara med färg").
class FieldErrorLine extends StatelessWidget {
  final String message;

  const FieldErrorLine(this.message, {super.key});

  /// For `TextFormField.errorBuilder`, so validator errors carry the glyph.
  static Widget builder(BuildContext context, String message) =>
      FieldErrorLine(message);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style =
        InputDecorationTheme.of(context).errorStyle ??
        AppTextStyles.errorText.copyWith(color: cs.error);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: ButleryIcon(
            ButleryIcons.info,
            size: AppDimensions.iconSizeXs,
            color: cs.error,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingXs),
        Flexible(child: Text(message, style: style)),
      ],
    );
  }
}
