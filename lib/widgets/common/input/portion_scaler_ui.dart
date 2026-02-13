// lib/widgets/common/input/portion_scaler_ui.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// UI components for the portion scaler widget.
///
/// Renders only the portion controls (header + status + unit toggle).
/// Ingredient rendering is handled by the caller (recipe_detail_content.dart).
class PortionScalerUI {
  /// Builds the portion scaler controls (no ingredient list).
  static Widget buildScaler({
    required BuildContext context,
    required int currentPortions,
    required int originalPortions,
    required bool convertToSwedish,
    required bool hasAmericanUnits,
    required int minPortions,
    required int maxPortions,
    required Animation<double> scaleAnimation,
    required Function(int) onUpdatePortions,
    required VoidCallback onToggleUnitConversion,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with portion controls
        _buildHeader(
          context,
          currentPortions,
          minPortions,
          maxPortions,
          scaleAnimation,
          onUpdatePortions,
        ),

        const SizedBox(height: AppDimensions.spacingM),

        // Status info
        if (currentPortions != originalPortions || convertToSwedish)
          _buildStatusInfo(
            context,
            currentPortions,
            originalPortions,
            convertToSwedish,
          ),

        // Unit conversion toggle
        if (hasAmericanUnits)
          _buildUnitConversionToggle(
            context,
            convertToSwedish,
            onToggleUnitConversion,
          ),
      ],
    );
  }

  /// Builds the header with portion controls
  static Widget _buildHeader(
    BuildContext context,
    int currentPortions,
    int minPortions,
    int maxPortions,
    Animation<double> scaleAnimation,
    Function(int) onUpdatePortions,
  ) {
    return Row(
      children: [
        Text(
          context.l10n.scalerPortionsLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.forestGreenDark,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        _buildPortionControls(
          context,
          currentPortions,
          minPortions,
          maxPortions,
          scaleAnimation,
          onUpdatePortions,
        ),
      ],
    );
  }

  /// Builds the portion control buttons
  static Widget _buildPortionControls(
    BuildContext context,
    int currentPortions,
    int minPortions,
    int maxPortions,
    Animation<double> scaleAnimation,
    Function(int) onUpdatePortions,
  ) {
    return AnimatedBuilder(
      animation: scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: scaleAnimation.value,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Minus button
              _buildControlButton(
                context,
                icon: Icons.remove,
                onPressed: currentPortions > minPortions
                    ? () => onUpdatePortions(currentPortions - 1)
                    : null,
              ),

              // Current portions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$currentPortions',
                  style: AppTextStyles.bodyBold.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forestGreenDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Plus button
              _buildControlButton(
                context,
                icon: Icons.add,
                onPressed: currentPortions < maxPortions
                    ? () => onUpdatePortions(currentPortions + 1)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds individual control buttons
  static Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.zero,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            border: Border.all(
              color:
                  onPressed != null ? AppColors.forestGreen : AppColors.divider,
              width: 2.0,
            ),
          ),
          child: Icon(
            icon,
            size: AppDimensions.iconSizeL,
            color: onPressed != null
                ? AppColors.forestGreen
                : AppColors.textMedium,
          ),
        ),
      ),
    );
  }

  /// Builds the status information banner
  static Widget _buildStatusInfo(
    BuildContext context,
    int currentPortions,
    int originalPortions,
    bool convertToSwedish,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingS,
            vertical: AppDimensions.spacingXs,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                convertToSwedish ? Icons.language : Icons.calculate,
                size: AppDimensions.iconSizeS,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: AppDimensions.spacingXs),
              Flexible(
                child: Text(
                  _buildStatusText(context, currentPortions, originalPortions,
                      convertToSwedish),
                  style: AppTextStyles.metadataEmphasized.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacingM),
      ],
    );
  }

  /// Builds the unit conversion toggle button
  static Widget _buildUnitConversionToggle(
    BuildContext context,
    bool convertToSwedish,
    VoidCallback onToggleUnitConversion,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingS),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onToggleUnitConversion,
              icon: Icon(
                convertToSwedish ? Icons.check_circle : Icons.language,
                size: AppDimensions.iconSizeS,
              ),
              label: Text(
                convertToSwedish
                    ? context.l10n.scalerUsingSwedishUnits
                    : context.l10n.scalerConvertAmericanUnits,
                style: AppTextStyles.metadataEmphasized,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: convertToSwedish
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
                side: BorderSide(
                  color: convertToSwedish
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                backgroundColor: convertToSwedish
                    ? Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: AppDimensions.opacityMediumLight)
                    : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingS,
                  vertical: AppDimensions.spacingXs,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the status text for the info banner
  static String _buildStatusText(
    BuildContext context,
    int currentPortions,
    int originalPortions,
    bool convertToSwedish,
  ) {
    final List<String> status = [];

    if (currentPortions != originalPortions) {
      status.add(
          context.l10n.scalerScaledFromTo(originalPortions, currentPortions));
    }

    if (convertToSwedish) {
      status.add(context.l10n.scalerAmericanConverted);
    }

    return status.join(' • ');
  }
}
