// lib/widgets/common/buttons/action_buttons.dart

import 'package:flutter/material.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// ActionButtons - Utility action buttons with loading support
///
/// Provides consistent button styling and loading states for the app.
class ActionButtons {
  /// Standard action button med loading support och flera styles
  static Widget actionButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    ActionButtonStyle style = ActionButtonStyle.primary,
    bool isExpanded = false,
  }) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final effectiveLabel = isLoading ? (loadingText ?? 'Laddar...') : label;

    Widget buttonChild = Padding(
      padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingXs),
      child: Row(
        mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            Padding(
              padding: EdgeInsets.only(right: AppDimensions.spacingS),
              child: SizedBox(
                width: AppDimensions.iconSizeS,
                height: AppDimensions.iconSizeS,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.cardWhite),
                ),
              ),
            )
          else if (icon != null)
            Padding(
              padding: EdgeInsets.only(right: AppDimensions.spacingS),
              child: Icon(
                icon,
                size: AppDimensions.iconSizeS,
                color: AppColors.cardWhite,
              ),
            ),
          Flexible(
            fit: isExpanded ? FlexFit.tight : FlexFit.loose,
            child: Text(
              effectiveLabel,
              style: AppTextStyles.buttonPrimary,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: isExpanded ? TextAlign.center : TextAlign.start,
            ),
          ),
        ],
      ),
    );

    Widget button;
    switch (style) {
      case ActionButtonStyle.primary:
        button = ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: AppColors.cardWhite,
            elevation: AppDimensions.elevationLow,
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingL,
              vertical: AppDimensions.paddingM,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            ),
          ),
          child: buttonChild,
        );
        break;
      case ActionButtonStyle.secondary:
        button = ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: AppColors.cardWhite,
            elevation: AppDimensions.elevationLow,
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingL,
              vertical: AppDimensions.paddingM,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            ),
          ).copyWith(
            backgroundColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.secondary,
            ),
          ),
          child: buttonChild,
        );
        break;
      case ActionButtonStyle.outlined:
        button = OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryBlue,
            backgroundColor: Colors.transparent,
            elevation: 0,
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingL,
              vertical: AppDimensions.paddingM,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            ),
            side: BorderSide(color: AppColors.primaryBlue),
          ),
          child: buttonChild,
        );
        break;
    }

    return isExpanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  /// Primary action button convenience method
  static Widget primaryButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    bool isExpanded = false,
  }) {
    return actionButton(
      context,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      style: ActionButtonStyle.primary,
      isExpanded: isExpanded,
    );
  }

  /// Secondary action button convenience method
  static Widget secondaryButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    bool isExpanded = false,
  }) {
    return actionButton(
      context,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      style: ActionButtonStyle.secondary,
      isExpanded: isExpanded,
    );
  }

  /// Outlined action button convenience method
  static Widget outlinedButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    bool isExpanded = false,
  }) {
    return actionButton(
      context,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      style: ActionButtonStyle.outlined,
      isExpanded: isExpanded,
    );
  }
}

/// Button style enumeration
enum ActionButtonStyle { primary, secondary, outlined }