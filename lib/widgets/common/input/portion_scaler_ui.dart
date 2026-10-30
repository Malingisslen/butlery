// lib/widgets/common/input/portion_scaler_ui.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/buttons/toggle_button_style.dart';
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
    bool compact = false,
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
          compact,
        ),

        // Only add gap when status/toggle content follows
        if (currentPortions != originalPortions ||
            convertToSwedish ||
            hasAmericanUnits)
          const SizedBox(height: AppDimensions.space8),

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
    bool compact,
  ) {
    // A Wrap, so the controls move under the label when large text leaves
    // no room beside it. Full width, as the Row was, so a caller's
    // background still spans the row; the compact scaler sits beside a
    // heading and takes only the width it needs.
    final header = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: compact ? AppDimensions.space8 : AppDimensions.space16,
      children: [
        Text(
          context.l10n.scalerPortionsLabel,
          style: AppTextStyles.bodyBold.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        _buildPortionControls(
          context,
          currentPortions,
          minPortions,
          maxPortions,
          scaleAnimation,
          onUpdatePortions,
          compact,
        ),
      ],
    );
    return compact ? header : SizedBox(width: double.infinity, child: header);
  }

  /// Builds the portion control buttons
  static Widget _buildPortionControls(
    BuildContext context,
    int currentPortions,
    int minPortions,
    int maxPortions,
    Animation<double> scaleAnimation,
    Function(int) onUpdatePortions,
    bool compact,
  ) {
    return AnimatedBuilder(
      animation: scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: scaleAnimation.value,
          // One adjustable value: the number is its value, and a swipe up or
          // down steps it as the two buttons do.
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            label: context.l10n.scalerPortionsLabel,
            value: '$currentPortions',
            increasedValue: currentPortions < maxPortions
                ? '${currentPortions + 1}'
                : null,
            decreasedValue: currentPortions > minPortions
                ? '${currentPortions - 1}'
                : null,
            onIncrease: currentPortions < maxPortions
                ? () => onUpdatePortions(currentPortions + 1)
                : null,
            onDecrease: currentPortions > minPortions
                ? () => onUpdatePortions(currentPortions - 1)
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Minus button
                _buildControlButton(
                  context,
                  icon: ButleryIcons.minus,
                  compact: compact,
                  onPressed: currentPortions > minPortions
                      ? () => onUpdatePortions(currentPortions - 1)
                      : null,
                ),

                // Current portions
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space12,
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      '$currentPortions',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // Plus button
                _buildControlButton(
                  context,
                  icon: ButleryIcons.plus,
                  compact: compact,
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
    required bool compact,
  }) {
    final cs = Theme.of(context).colorScheme;
    final box = compact
        ? AppDimensions.compactStepperButton
        : AppDimensions.minTouchTarget;
    final label = icon == ButleryIcons.minus
        ? context.l10n.portionDecrease
        : context.l10n.portionIncrease;
    return Semantics(
      label: label,
      button: true,
      enabled: onPressed != null,
      child: ButleryControlFocus(
        child: Material(
          type: MaterialType.transparency,
          child: PressFill(
            surface: PressSurface.raised,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.zero,
              child: SizedBox.square(
                dimension: AppDimensions.minTouchTarget,
                child: Center(
                  child: Ink(
                    width: box,
                    height: box,
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
                          size: compact
                              ? AppDimensions.iconSizeM
                              : AppDimensions.iconSizeL,
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
            vertical: AppDimensions.space4,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ButleryIcon(
                convertToSwedish ? ButleryIcons.globe : ButleryIcons.hash,
                size: AppDimensions.iconSizeS,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: AppDimensions.space4),
              Flexible(
                child: Text(
                  _buildStatusText(
                    context,
                    currentPortions,
                    originalPortions,
                    convertToSwedish,
                  ),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.space8),
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
            // One name for the control and a state that changes, rather than
            // a label that changes with the state.
            child: Semantics(
              toggled: convertToSwedish,
              label: context.l10n.scalerConvertAmericanUnits,
              button: true,
              excludeSemantics: true,
              onTap: onToggleUnitConversion,
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
                  style: AppTextStyles.labelMedium,
                ),
                style: toggleOutlinedButtonStyle(
                  Theme.of(context).colorScheme,
                  selected: convertToSwedish,
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
