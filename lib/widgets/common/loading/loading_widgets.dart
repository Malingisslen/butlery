// lib/widgets/common/loading/loading_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

/// LoadingWidgets - Loading and error utility components
/// Provides loading overlays, error boundaries, and responsive wrappers.
class LoadingWidgets {
  /// Loading overlay shown over existing content
  static Widget loadingOverlay({
    Widget? child,
    bool isLoading = false,
    String? loadingMessage,
    Color? overlayColor,
  }) {
    if (!isLoading) {
      return child ?? const SizedBox.shrink();
    }

    final overlay = Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return ColoredBox(
          color:
              overlayColor ??
              cs.onSurface.withValues(alpha: AppDimensions.opacityMediumLight),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(
                  AppDimensions.borderRadiusL,
                ),
              ),
              // Plate line plus text, never a spinner (produktregler.md:163,
              // B-18). Without a message the generic one stands in: the line
              // never carries the news alone.
              child: PlateLineMessage(
                message: loadingMessage ?? context.l10n.loadingGeneric,
              ),
            ),
          ),
        );
      },
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
                  child: Builder(
                    builder: (ctx) {
                      final cs = Theme.of(ctx).colorScheme;
                      return Container(
                        padding: const EdgeInsets.all(AppDimensions.paddingM),
                        decoration: BoxDecoration(
                          color: cs.error.withValues(
                            alpha: AppDimensions.opacityVeryLight,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.borderRadiusM,
                          ),
                          border: Border.all(
                            color: cs.error.withValues(
                              alpha: AppDimensions.opacityMediumLight,
                            ),
                          ),
                        ),
                        child: Text(
                          ctx.l10n.errorUnexpected,
                          style: AppTextStyles.bodyMediumError,
                        ),
                      );
                    },
                  ),
                ),
              );
        }
      },
    );
  }

  /// Responsive wrapper for adaptive layout
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
