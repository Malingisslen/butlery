// lib/widgets/common/buttons/action_buttons.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/animated_pressable.dart';

/// ActionButtons - Utility action buttons with loading support
/// Provides consistent button styling and loading states for the app.
class ActionButtons {
  static Widget actionButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    ActionButtonStyle style = ActionButtonStyle.primary,
    bool isExpanded = false,
    bool enablePressAnimation = true,
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
              padding: EdgeInsetsDirectional.only(end: AppDimensions.spacingS),
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
              padding:
                  const EdgeInsetsDirectional.only(end: AppDimensions.spacingS),
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

    final semanticLabel = isLoading ? '$label, laddar' : label;

    final result = Semantics(
      label: semanticLabel,
      button: true,
      enabled: effectiveOnPressed != null,
      child: isExpanded
          ? SizedBox(width: double.infinity, child: button)
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: button,
            ),
    );

    if (!enablePressAnimation || isLoading) return result;
    return AnimatedPressable(
      enabled: effectiveOnPressed != null,
      child: result,
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
    bool enablePressAnimation = true,
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
      enablePressAnimation: enablePressAnimation,
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
    bool enablePressAnimation = true,
  }) {
    final semanticLabel = isLoading ? '$label, laddar' : label;

    final result = Semantics(
      label: semanticLabel,
      button: true,
      enabled: !isLoading,
      child: AspectRatio(
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
      ),
    );

    if (!enablePressAnimation || isLoading) return result;
    return AnimatedPressable(
      enabled: true,
      child: result,
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
    bool enablePressAnimation = true,
  }) {
    final semanticLabel = isLoading ? '$label, laddar' : label;

    final Widget button = Semantics(
      label: semanticLabel,
      button: true,
      enabled: !isLoading,
      child: SizedBox(
        height: height,
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : onPressed,
          icon: isLoading
              ? const SizedBox(
                  width: AppDimensions.iconSizeAction,
                  height: AppDimensions.iconSizeAction,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : Icon(icon,
                  size: AppDimensions.iconSizeXl, color: AppColors.onPrimary),
          label: Text(
            isLoading ? (loadingText ?? 'Laddar...') : label,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.onPrimary,
            ),
          ),
        ),
      ),
    );

    final Widget result =
        margin != null ? Padding(padding: margin, child: button) : button;

    if (!enablePressAnimation || isLoading) return result;
    return AnimatedPressable(
      enabled: true,
      child: result,
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
    bool enablePressAnimation = true,
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
      enablePressAnimation: enablePressAnimation,
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
    bool enablePressAnimation = true,
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
      enablePressAnimation: enablePressAnimation,
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
    bool enablePressAnimation = true,
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
              padding: EdgeInsetsDirectional.only(end: AppDimensions.spacingS),
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
              padding:
                  const EdgeInsetsDirectional.only(end: AppDimensions.spacingS),
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

    final semanticLabel = isLoading ? '$label, laddar' : label;

    final result = Semantics(
      label: semanticLabel,
      button: true,
      enabled: effectiveOnPressed != null,
      child:
          isExpanded ? SizedBox(width: double.infinity, child: button) : button,
    );

    if (!enablePressAnimation || isLoading) return result;
    return AnimatedPressable(
      enabled: effectiveOnPressed != null,
      child: result,
    );
  }

  /// Cancel button that pops the current context.
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

  /// Semantic label for screen readers. Required for accessibility.
  final String semanticLabel;

  /// Whether to show press animation feedback.
  final bool enablePressAnimation;

  const FloatingActionButtonWidget({
    super.key,
    required this.onPressed,
    required this.child,
    required this.semanticLabel,
    this.backgroundColor,
    this.foregroundColor,
    this.enablePressAnimation = true,
  });

  /// Message FAB for conversations
  const FloatingActionButtonWidget.message({
    super.key,
    required this.onPressed,
    this.enablePressAnimation = true,
  })  : child = const Icon(Icons.message),
        backgroundColor = AppColors.primaryBlue,
        foregroundColor = AppColors.cardWhite,
        semanticLabel = 'Nytt meddelande';

  @override
  Widget build(BuildContext context) {
    final result = Semantics(
      label: semanticLabel,
      button: true,
      enabled: onPressed != null,
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: backgroundColor ?? AppColors.primaryBlue,
        foregroundColor: foregroundColor ?? AppColors.cardWhite,
        child: child,
      ),
    );

    if (!enablePressAnimation) return result;
    return AnimatedPressable(
      enabled: onPressed != null,
      child: result,
    );
  }
}

/// Button style enumeration
enum ActionButtonStyle { primary, secondary, outlined }
