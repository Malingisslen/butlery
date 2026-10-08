// lib/widgets/common/input/portion_scaler_ui.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

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

        // Only add gap when status/toggle content follows
        if (currentPortions != originalPortions ||
            convertToSwedish ||
            hasAmericanUnits)
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
    // A Wrap, so the controls move under the label when large text leaves
    // no room beside it; full width, as the Row was, so a caller's
    // background still spans the row.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppDimensions.spacingMd,
        children: [
          Text(
            context.l10n.scalerPortionsLabel,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          _buildPortionControls(
            context,
            currentPortions,
            minPortions,
            maxPortions,
            scaleAnimation,
            onUpdatePortions,
          ),
        ],
      ),
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
                icon: ButleryIcons.minus,
                onPressed: currentPortions > minPortions
                    ? () => onUpdatePortions(currentPortions - 1)
                    : null,
              ),

              // Current portions
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingM,
                ),
                child: Text(
                  '$currentPortions',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Plus button
              _buildControlButton(
                context,
                icon: ButleryIcons.plus,
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
    final cs = Theme.of(context).colorScheme;
    final label = icon == ButleryIcons.minus
        ? context.l10n.portionDecrease
        : context.l10n.portionIncrease;
    return Semantics(
      label: label,
      button: true,
      enabled: onPressed != null,
      child: Material(
        color: Colors.transparent,
        child: Material(
          type: MaterialType.transparency,
          child: PressFill(
            surface: PressSurface.raised,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.zero,
              child: Ink(
                width: AppDimensions.minTouchTarget,
                height: AppDimensions.minTouchTarget,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: onPressed != null
                          ? cs.onSurface
                          : cs.outlineVariant,
                      width: 2.0,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.center,
                    child: ButleryIcon(
                      icon,
                      size: AppDimensions.iconSizeL,
                      color: onPressed != null
                          ? cs.onSurface
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
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
            horizontal: AppDimensions.space4,
            vertical: AppDimensions.spacingXs,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ButleryIcon(
                convertToSwedish ? ButleryIcons.globe : Icons.calculate,
                size: AppDimensions.iconSizeS,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: AppDimensions.spacingXs),
              Flexible(
                child: Text(
                  _buildStatusText(
                    context,
                    currentPortions,
                    originalPortions,
                    convertToSwedish,
                  ),
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
      margin: const EdgeInsets.only(bottom: AppDimensions.space4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onToggleUnitConversion,
              icon: ButleryIcon(
                convertToSwedish
                    ? ButleryIcons.circleCheck
                    : ButleryIcons.globe,
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
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurface,
                // Selected is the raised surface with a 1.5 px text.primary
                // border (B83-1).
                side: BorderSide(
                  color: convertToSwedish
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.outline,
                  width: convertToSwedish ? 1.5 : 1,
                ),
                backgroundColor: convertToSwedish
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space4,
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
        context.l10n.scalerScaledFromTo(originalPortions, currentPortions),
      );
    }

    if (convertToSwedish) {
      status.add(context.l10n.scalerAmericanConverted);
    }

    return status.join(' • ');
  }
}
