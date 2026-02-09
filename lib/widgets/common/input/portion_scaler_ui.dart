// lib/widgets/common/input/portion_scaler_ui.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

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
          'Portioner:',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textLight,
            fontWeight: FontWeight.w400,
          ),
        ),
        const Spacer(),
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
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingS,
                    vertical: AppDimensions.spacingXs,
                  ),
                  child: Text(
                    '$currentPortions',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: Theme.of(context).colorScheme.primary,
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
          padding: const EdgeInsets.all(AppDimensions.spacingSm),
          decoration: BoxDecoration(
            border: Border.all(
              color: onPressed != null
                  ? AppColors.forestGreen
                  : AppColors.divider,
              width: 1.5,
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
                  _buildStatusText(
                      currentPortions, originalPortions, convertToSwedish),
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
                    ? 'Använder svenska enheter'
                    : 'Konvertera amerikanska enheter',
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
    int currentPortions,
    int originalPortions,
    bool convertToSwedish,
  ) {
    final List<String> status = [];

    if (currentPortions != originalPortions) {
      status
          .add('Skalat från $originalPortions till $currentPortions portioner');
    }

    if (convertToSwedish) {
      status.add('Amerikanska enheter konverterade till svenska');
    }

    return status.join(' • ');
  }
}
