import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// The validated state's mark at the end of the box: a check and a short
/// word in text.success, while the edge keeps its resting colour
/// ("Validerad": "malin_lagar … ✓ Ledigt"). The word
/// says it, so the state never rests on colour alone. It goes in the
/// field's suffix, inside a Flexible, so a long word gives way to the typed
/// text; its own live-region node reads it when it appears.
class FieldValidMark extends StatelessWidget {
  final String message;

  const FieldValidMark(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.modeColors.success;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ButleryIcon(
              ButleryIcons.check,
              size: AppDimensions.iconSizeXs,
              color: color,
            ),
            const SizedBox(width: AppDimensions.space4),
            Flexible(
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.overline.copyWith(
                  letterSpacing: 0,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
