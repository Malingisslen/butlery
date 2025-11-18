// lib/widgets/common/loading/loading_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/core/utils/logger.dart';

/// LoadingWidgets - Loading and error utility components
/// Provides loading overlays, error boundaries, and responsive wrappers.
class LoadingWidgets {
  /// Loading overlay som visas över existerande innehåll
  static Widget loadingOverlay({
    Widget? child,
    bool isLoading = false,
    String? loadingMessage,
    Color? overlayColor,
  }) {
    if (!isLoading) {
      return child ?? const SizedBox.shrink();
    }

    final overlay = ColoredBox(
      color: overlayColor ?? AppColors.neutralDark.withValues(alpha: 0.3),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: AppDimensions.iconSizeM,
                height: AppDimensions.iconSizeM,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                ),
              ),
              if (loadingMessage != null) ...[
                const SizedBox(height: AppDimensions.spacingM),
                Text(
                  loadingMessage,
                  style: AppTextStyles.titleMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (child != null) {
      return Stack(children: [child, overlay]);
    }
    return overlay;
  }

  /// Error boundary som hanterar exceptions gracefully
  static Widget errorBoundary({
    required Widget child,
    Widget? errorWidget,
    Function(Object error, StackTrace stack)? onError,
  }) {
    return Builder(
      builder: (context) {
        try {
          return child;
        } catch (error, stack) {
          onError?.call(error, stack);
          AppLogger.error('Error boundary caught exception: $error');

          return errorWidget ??
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingM),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Ett oväntat fel uppstod',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                    ),
                  ),
                ),
              );
        }
      },
    );
  }

  /// Responsive wrapper för adaptiv layout
  static Widget responsiveWrapper({
    required Widget child,
    double? maxWidth,
    EdgeInsets? padding,
  }) {
    return Builder(
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final effectiveMaxWidth =
            maxWidth ?? (screenWidth > 768 ? 600 : double.infinity);

        return Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
            padding: padding ?? const EdgeInsets.all(AppDimensions.paddingL),
            child: child,
          ),
        );
      },
    );
  }
}