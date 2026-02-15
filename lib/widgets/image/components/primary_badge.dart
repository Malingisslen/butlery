import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Badge indicating primary image status
class PrimaryBadge extends StatelessWidget {
  const PrimaryBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      top: AppDimensions.paddingM,
      left: AppDimensions.paddingM,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingSm,
          vertical: AppDimensions.spacingXs,
        ),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(AppDimensions.paddingM),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star,
              size: AppDimensions.iconSizeS,
              color: cs.onPrimary,
            ),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              'Primary',
              style: AppTextStyles.metadataEmphasized.copyWith(
                color: cs.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
