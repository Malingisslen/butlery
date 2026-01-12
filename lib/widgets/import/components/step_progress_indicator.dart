// lib/widgets/import/components/step_progress_indicator.dart

import 'package:flutter/material.dart';

/// Progress indicator showing step completion status.
class StepProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          for (int i = 1; i <= totalSteps; i++) ...[
            if (i > 1)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= currentStep
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
              ),
            _buildStepIndicator(
              stepNumber: i,
              isActive: i == currentStep,
              isCompleted: i < currentStep,
              theme: theme,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepIndicator({
    required int stepNumber,
    required bool isActive,
    required bool isCompleted,
    required ThemeData theme,
  }) {
    final colorScheme = theme.colorScheme;

    Color backgroundColor;
    Color textColor;

    if (isCompleted) {
      backgroundColor = colorScheme.primary;
      textColor = colorScheme.onPrimary;
    } else if (isActive) {
      backgroundColor = colorScheme.primary;
      textColor = colorScheme.onPrimary;
    } else {
      backgroundColor = colorScheme.surfaceContainerHighest;
      textColor = colorScheme.onSurfaceVariant;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
      ),
      child: Center(
        child: isCompleted
            ? Icon(Icons.check, size: AppDimensions.iconSizeS, color: textColor)
            : Text(
                '$stepNumber',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
