// lib/widgets/common/source_url_display.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Widget to display source URL information with consistent styling
class SourceUrlDisplay extends StatelessWidget {
  final String sourceUrl;

  const SourceUrlDisplay({
    super.key,
    required this.sourceUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.backgroundTint,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(
            Icons.link,
            size: AppDimensions.iconSizeM,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              'Importerat från: $sourceUrl',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMedium,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
