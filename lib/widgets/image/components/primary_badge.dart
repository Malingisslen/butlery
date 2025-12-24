import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Badge indicating primary image status
class PrimaryBadge extends StatelessWidget {
  const PrimaryBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: AppDimensions.paddingM,
      left: AppDimensions.paddingM,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingSm,
          vertical: AppDimensions.spacingXs,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(AppDimensions.paddingM),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star,
              size: AppDimensions.iconSizeS,
              color: AppColors.cardWhite,
            ),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              'Primary',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.cardWhite,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
