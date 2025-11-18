// lib/widgets/common/buttons/action_buttons.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// ActionButtons - Utility action buttons with loading support
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

    final Widget buttonChild = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingXs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(right: AppDimensions.spacingS),
              child: SizedBox(
                width: AppDimensions.iconSizeS,
                height: AppDimensions.iconSizeS,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            )
          else if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: AppDimensions.spacingS),
              child: Icon(icon),
            ),
          Flexible(
            child: Text(
              effectiveLabel,
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
          child: buttonChild,
        );
        break;
      case ActionButtonStyle.secondary:
        button = ElevatedButton(
          onPressed: effectiveOnPressed,
          child: buttonChild,
        );
        break;
      case ActionButtonStyle.outlined:
        button = OutlinedButton(
          onPressed: effectiveOnPressed,
          child: buttonChild,
        );
        break;
    }

    return isExpanded
        ? SizedBox(width: double.infinity, child: button)
        : ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: button,
          );
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

  /// Square button for recipe upload view - perfect square aspect ratio
  static Widget squareButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
    String? loadingText,
  }) {
    return AspectRatio(
      aspectRatio: 1.0, // Perfect square
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: AppDimensions.iconSizeM,
                height: AppDimensions.iconSizeM,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onPrimary,
                ),
              )
            else
              Icon(icon, size: AppDimensions.iconSizeXl),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              isLoading ? (loadingText ?? 'Laddar...') : label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Large prominent button for important actions (like archive)
  static Widget largeButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
    String? loadingText,
    double height = 100, // Slightly increased height
    EdgeInsets? margin,
  }) {
    final Widget button = SizedBox(
      height: height,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : () {
          // Button pressed - debug logging removed for production
          onPressed();
        },
        icon: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onPrimary,
                ),
              )
            : Icon(icon, size: AppDimensions.iconSizeXl, color: AppColors.onPrimary),
        label: Text(
          isLoading ? (loadingText ?? 'Laddar...') : label,
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );

    if (margin != null) {
      return Padding(padding: margin, child: button);
    }
    return button;
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

  /// Text button convenience method for minimal styling
  static Widget textButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    bool isExpanded = false,
    ButtonStyle? style,
  }) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final effectiveLabel = isLoading ? (loadingText ?? 'Laddar...') : label;

    final Widget buttonChild = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingXs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(right: AppDimensions.spacingS),
              child: SizedBox(
                width: AppDimensions.iconSizeS,
                height: AppDimensions.iconSizeS,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            )
          else if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: AppDimensions.spacingS),
              child: Icon(icon),
            ),
          Flexible(
            child: Text(
              effectiveLabel,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: isExpanded ? TextAlign.center : TextAlign.start,
            ),
          ),
        ],
      ),
    );

    final button = TextButton(
      onPressed: effectiveOnPressed,
      style: style,
      child: buttonChild,
    );

    return isExpanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  /// Standard cancel button that pops the dialog/screen with false result.
  /// This convenience method eliminates duplication of the cancel button pattern across
  /// 9+ locations in the codebase. All cancel buttons now have consistent behavior,
  /// wording, and styling.
  /// **Parameters:**
  /// - [label]: Custom label for the cancel button (defaults to 'Avbryt')
  /// - [result]: Value to return when cancel is pressed (defaults to false)
  /// **Usage Example:**
  /// ```dart
  /// AlertDialog(
  ///   title: Text('Confirm Action'),
  ///   content: Text('Are you sure?'),
  ///   actions: [
  ///     ActionButtons.cancel(context),
  ///     ActionButtons.primaryButton(
  ///       context,
  ///       label: 'Confirm',
  ///       onPressed: () => Navigator.pop(context, true),
  ///     ),
  ///   ],
  /// )
  /// ```
  static Widget cancel<T>(
    BuildContext context, {
    String label = 'Avbryt',
    T? result,
  }) {
    return secondaryButton(
      context,
      label: label,
      onPressed: () => Navigator.pop(context, result ?? false),
    );
  }
}

/// Floating Action Button Widget
/// Provides consistent FAB styling across the app following design separation principles.
class FloatingActionButtonWidget extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const FloatingActionButtonWidget({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.foregroundColor,
  });

  /// Message FAB for conversations
  const FloatingActionButtonWidget.message({
    super.key,
    required this.onPressed,
  }) : child = const Icon(Icons.message),
       backgroundColor = AppColors.primaryBlue,
       foregroundColor = AppColors.cardWhite;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: backgroundColor ?? AppColors.primaryBlue,
      foregroundColor: foregroundColor ?? AppColors.cardWhite,
      child: child,
    );
  }
}

/// Button style enumeration
enum ActionButtonStyle { primary, secondary, outlined }