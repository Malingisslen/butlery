/// Simple 3-step progress indicator for the import process.
///
/// Shows progress through: Fetching → Analyzing → Creating
/// with animated transitions between steps.
library;

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// A simple 3-step progress indicator for import operations.
class ImportProgressWidget extends StatelessWidget {
  /// Current step (0 = not started, 1 = fetching, 2 = analyzing, 3 = creating/done).
  final int currentStep;

  /// Progress message to display below the indicator.
  final String message;

  /// Whether the import is currently in progress.
  final bool isLoading;

  /// Whether to show the widget (hidden when step is 0 and not loading).
  final bool isVisible;

  /// Elapsed time since import started. Shown next to the message when non-null and > 0.
  final Duration? elapsed;

  const ImportProgressWidget({
    super.key,
    required this.currentStep,
    required this.message,
    this.isLoading = false,
    this.isVisible = true,
    this.elapsed,
  });

  /// Builds message with elapsed time suffix using l10n.
  String _buildDisplayMessage(BuildContext context) {
    if (elapsed == null || elapsed!.inSeconds < 1) return message;
    final elapsedText = context.l10n.importElapsedSeconds(elapsed!.inSeconds);
    return '$message ($elapsedText)';
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible || (currentStep == 0 && !isLoading)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedOpacity(
      duration: AnimationUtils.getDuration(
          context, AppDimensions.animationDurationMedium),
      opacity: isVisible ? 1.0 : 0.0,
      child: Container(
        padding: AppDimensions.paddingSymmetric20x16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Step indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepIndicator(
                  step: 1,
                  label: context.l10n.importStepFetching,
                  isActive: currentStep >= 1,
                  isComplete: currentStep > 1,
                  isLoading: isLoading && currentStep == 1,
                  colorScheme: colorScheme,
                ),
                _StepConnector(
                  isActive: currentStep > 1,
                  colorScheme: colorScheme,
                ),
                _StepIndicator(
                  step: 2,
                  label: context.l10n.importStepAnalyzing,
                  isActive: currentStep >= 2,
                  isComplete: currentStep > 2,
                  isLoading: isLoading && currentStep == 2,
                  colorScheme: colorScheme,
                ),
                _StepConnector(
                  isActive: currentStep > 2,
                  colorScheme: colorScheme,
                ),
                _StepIndicator(
                  step: 3,
                  label: context.l10n.importStepCreating,
                  isActive: currentStep >= 3,
                  isComplete: currentStep > 3,
                  isLoading: isLoading && currentStep == 3,
                  colorScheme: colorScheme,
                ),
              ],
            ),

            // Progress message with optional elapsed time
            if (message.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.paddingM),
              AnimatedSwitcher(
                duration: AnimationUtils.getDuration(
                    context, AppDimensions.animationDurationMedium),
                child: Text(
                  _buildDisplayMessage(context),
                  key: ValueKey('$message-${elapsed?.inSeconds ?? 0}'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Individual step indicator circle.
class _StepIndicator extends StatelessWidget {
  final int step;
  final String label;
  final bool isActive;
  final bool isComplete;
  final bool isLoading;
  final ColorScheme colorScheme;

  const _StepIndicator({
    required this.step,
    required this.label,
    required this.isActive,
    required this.isComplete,
    required this.isLoading,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: AnimationUtils.getDuration(
              context, const Duration(milliseconds: 250)),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: isActive ? colorScheme.primary : colorScheme.outline,
              width: 2,
            ),
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(colorScheme.onPrimary),
                    ),
                  )
                : isComplete
                    ? Icon(
                        Icons.check,
                        size: AppDimensions.iconSizeM,
                        color: colorScheme.onPrimary,
                      )
                    : Text(
                        '$step',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: isActive
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          label,
          style:
              (isActive ? AppTextStyles.badgeLarge : AppTextStyles.labelSmall)
                  .copyWith(
            color:
                isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Connector line between steps.
class _StepConnector extends StatelessWidget {
  final bool isActive;
  final ColorScheme colorScheme;

  const _StepConnector({
    required this.isActive,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingXl),
      child: AnimatedContainer(
        duration: AnimationUtils.getDuration(
            context, const Duration(milliseconds: 250)),
        width: 40,
        height: 2,
        color: isActive ? colorScheme.primary : colorScheme.outlineVariant,
      ),
    );
  }
}
