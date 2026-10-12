// lib/views/photo_import/photo_quality_warning.dart

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// What the quality check found wrong with the photo, and how to take a better
/// one. The caller shows it only when the score is under the threshold.
class PhotoQualityWarning extends StatelessWidget {
  const PhotoQualityWarning({super.key, required this.viewModel});

  final PhotoImportViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        AppDimensions.space12,
      ),
      decoration: BoxDecoration(
        color: context.modeColors.surfaceTintWarning,
        borderRadius: BorderRadius.circular(
          AppDimensions.radiusControl,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ButleryIcon(
                ButleryIcons.triangleAlert,
                color: AppModeColors.textWarning(
                  cs.brightness,
                ),
                size: AppDimensions.iconSizeM,
              ),
              const SizedBox(width: AppDimensions.space4),
              Expanded(
                child: Text(
                  context.l10n.importImageQualityLow(
                    (viewModel.qualityScore! * 100).toInt(),
                  ),
                  style: AppTextStyles.titleSmall.copyWith(
                    color: context.modeColors.onWarningContainer,
                  ),
                ),
              ),
            ],
          ),
          if (viewModel.recommendations != null &&
              viewModel.recommendations!.isNotEmpty) ...[
            const SizedBox(
              height: AppDimensions.space8,
            ),
            Text(
              context.l10n.importImprovementSuggestions,
              style: AppTextStyles.badgeLarge.copyWith(
                color: context.modeColors.onWarningContainer,
              ),
            ),
            const SizedBox(
              height: AppDimensions.space4,
            ),
            ...viewModel.recommendations!.map(
              (rec) => Padding(
                padding: const EdgeInsets.only(
                  bottom: AppDimensions.space4,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.modeColors.onWarningContainer,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rec,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.modeColors.onWarningContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.space8),
          Text(
            context.l10n.importOcrMayFail,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.modeColors.onWarningContainer,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
