// lib/widgets/common/input/portion_scaler_ui.dart

import 'package:flutter/material.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_styles.dart';

/// UI components for the portion scaler widget
class PortionScalerUI {
  /// Builds the complete portion scaler widget
  static Widget buildScaler({
    required BuildContext context,
    required int currentPortions,
    required int originalPortions,
    required List<String> scaledIngredients,
    required List<String> originalIngredients,
    required bool convertToSwedish,
    required bool hasAmericanUnits,
    required int minPortions,
    required int maxPortions,
    required Animation<double> scaleAnimation,
    required Function(int) onUpdatePortions,
    required VoidCallback onToggleUnitConversion,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
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

          // Scaled ingredients
          _buildScaledIngredients(
            context,
            currentPortions,
            originalPortions,
            scaledIngredients,
            originalIngredients,
            convertToSwedish,
          ),
        ],
      ),
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
        Icon(
          Icons.restaurant_menu,
          color: Theme.of(context).colorScheme.primary,
          size: AppDimensions.iconSizeS,
        ),
        const SizedBox(width: AppDimensions.spacingXs),
        Text(
          'Portioner',
          style: AppTextStyles.titleMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
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
          child: Container(
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
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.spacingS),
          child: Icon(
            icon,
            size: AppDimensions.iconSizeS,
            color: onPressed != null
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
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
                  _buildStatusText(currentPortions, originalPortions, convertToSwedish),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
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
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w500,
                ),
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
                        .withValues(alpha: 0.3)
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

  /// Builds the scaled ingredients list
  static Widget _buildScaledIngredients(
    BuildContext context,
    int currentPortions,
    int originalPortions,
    List<String> scaledIngredients,
    List<String> originalIngredients,
    bool convertToSwedish,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredienser för $currentPortions ${currentPortions == 1 ? 'portion' : 'portioner'}:',
          style: AppTextStyles.bodyLarge.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingM),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: scaledIngredients.asMap().entries.map((entry) {
              final index = entry.key;
              final ingredient = entry.value;
              final originalIngredient = index < originalIngredients.length
                  ? originalIngredients[index]
                  : '';
              final isChanged = currentPortions != originalPortions ||
                  convertToSwedish ||
                  ingredient != originalIngredient;

              return _buildIngredientItem(
                context,
                ingredient,
                isChanged,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Builds individual ingredient item
  static Widget _buildIngredientItem(
    BuildContext context,
    String ingredient,
    bool isChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimensions.spacingXs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bullet point
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(
              top: 8,
              right: AppDimensions.spacingS,
            ),
            decoration: BoxDecoration(
              color: isChanged
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              shape: BoxShape.circle,
            ),
          ),

          // Ingredient text
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: AppTextStyles.bodyLarge.copyWith(
                color: isChanged
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isChanged ? FontWeight.w600 : FontWeight.normal,
              ),
              child: Text(ingredient),
            ),
          ),

          // Changed indicator
          if (isChanged)
            Icon(
              Icons.refresh,
              size: AppDimensions.iconSizeS,
              color: Theme.of(context).colorScheme.primary,
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
      status.add('Skalat från $originalPortions till $currentPortions portioner');
    }

    if (convertToSwedish) {
      status.add('Amerikanska enheter konverterade till svenska');
    }

    return status.join(' • ');
  }
}