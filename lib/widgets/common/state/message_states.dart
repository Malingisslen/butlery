// lib/widgets/common/state/message_states.dart
//
// UI Redesign: Error states now use red onion illustration

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';

/// MessageStates - Error, Success, Info, and Warning state implementations
/// Handles different message state variants with appropriate styling.
///
/// **UI Redesign:** Error states now use red onion (rodlok) illustration
/// instead of generic error icons.
class MessageStates {
  /// Build error state with red onion illustration.
  /// UI Redesign: Uses VegetableType.onion illustration.
  static Widget buildErrorState(
    BuildContext context, {
    String? title,
    String? message,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Color? iconColor,
    double? iconSize,
    EdgeInsets? padding,
  }) {
    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingXl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // UI Redesign: Red onion illustration for errors
              const VegetableIllustration(
                type: VegetableType.redOnion,
                size: 100,
              ),
              const SizedBox(height: AppDimensions.spacingLg),

              // Error titel
              Text(
                title ?? 'Ett fel uppstod',
                style: AppTextStyles.emptyStateTitle.copyWith(
                  color: AppColors.rust,
                ),
                textAlign: TextAlign.center,
              ),

              // Error meddelande
              if (message != null) ...[
                const SizedBox(height: AppDimensions.spacingM),
                Text(
                  message,
                  style: AppTextStyles.emptyStateBody,
                  textAlign: TextAlign.center,
                ),
              ],

              // Retry knapp - rust outline style for errors
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppDimensions.spacingXl),
                UtilityComponents.outlinedButton(
                  context,
                  label: actionLabel,
                  onPressed: onAction,
                  icon: Icons.refresh,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build success state
  static Widget buildSuccessState(
    BuildContext context, {
    String? title,
    String? message,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Color? iconColor,
    double? iconSize,
    EdgeInsets? padding,
  }) {
    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingXl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success ikon
              Icon(
                icon ?? Icons.check_circle_outline,
                size: iconSize ?? AppDimensions.iconSizeXl,
                color: iconColor ?? AppColors.success,
              ),
              const SizedBox(height: AppDimensions.spacingXl),

              // Success titel
              Text(
                title ?? 'Klart!',
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.success,
                ),
                textAlign: TextAlign.center,
              ),

              // Success meddelande
              if (message != null) ...[
                const SizedBox(height: AppDimensions.spacingM),
                Text(
                  message,
                  style: AppTextStyles.bodyMediumSuccess,
                  textAlign: TextAlign.center,
                ),
              ],

              // Action knapp
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppDimensions.spacingXl),
                UtilityComponents.primaryButton(
                  context,
                  label: actionLabel,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build info state
  static Widget buildInfoState(
    BuildContext context, {
    String? title,
    String? message,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Color? iconColor,
    double? iconSize,
    EdgeInsets? padding,
  }) {
    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingXl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon ?? Icons.info_outline,
                size: iconSize ?? AppDimensions.iconSizeL,
                color: iconColor ?? Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              if (title != null) ...[
                Text(
                  title,
                  style: AppTextStyles.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingM),
              ],
              if (message != null) ...[
                Text(
                  message,
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppDimensions.spacingXl),
                UtilityComponents.outlinedButton(
                  context,
                  label: actionLabel,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build warning state
  static Widget buildWarningState(
    BuildContext context, {
    String? title,
    String? message,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Color? iconColor,
    double? iconSize,
    EdgeInsets? padding,
  }) {
    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingXl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon ?? Icons.warning_outlined,
                size: iconSize ?? AppDimensions.iconSizeL,
                color: iconColor ?? AppColors.warning,
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              if (title != null) ...[
                Text(
                  title,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.warning,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingM),
              ],
              if (message != null) ...[
                Text(
                  message,
                  style: AppTextStyles.bodyMediumWarning,
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppDimensions.spacingXl),
                UtilityComponents.primaryButton(
                  context,
                  label: actionLabel,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
