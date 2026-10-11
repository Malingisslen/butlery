import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Badge indicating primary image status
class PrimaryBadge extends StatelessWidget {
  const PrimaryBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      top: AppDimensions.space12,
      left: AppDimensions.space12,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space8,
          vertical: AppDimensions.space4,
        ),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(AppDimensions.space12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ButleryIcon(
              ButleryIcons.primary,
              size: AppDimensions.iconSizeS,
              color: cs.onPrimary,
            ),
            const SizedBox(width: AppDimensions.space4),
            Text(
              'Primary',
              style: AppTextStyles.labelMedium.copyWith(
                color: cs.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
