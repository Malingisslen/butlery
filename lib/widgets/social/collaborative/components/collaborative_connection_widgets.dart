// lib/widgets/social/collaborative/components/collaborative_connection_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Connection status widgets for collaborative content
class CollaborativeConnectionWidgets {
  /// Show connection status for collaborative content
  static Widget connectionStatus({
    required bool isOnline,
    required String statusText,
    String? statusEmoji,
    bool showRetryButton = false,
    VoidCallback? onRetry,
  }) {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;

        if (isOnline) {
          final successColor = context.butleryColors.success;
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingS,
              vertical: AppDimensions.spacingXs,
            ),
            decoration: BoxDecoration(
              color: successColor.withValues(
                alpha: AppDimensions.opacityVeryLight,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.chipRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: successColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingXs),
                Text(
                  context.l10n.collaborativeOnline,
                  style: AppTextStyles.metadataEmphasized.copyWith(
                    color: successColor,
                  ),
                ),
              ],
            ),
          );
        }

        // Offline banner
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.spacingL),
          decoration: BoxDecoration(
            color: cs.error.withValues(alpha: AppDimensions.opacityVeryLight),
            border: Border.all(
              color: cs.error.withValues(
                alpha: AppDimensions.opacityMediumLight,
              ),
            ),
          ),
          child: Row(
            children: [
              if (statusEmoji != null) ...[
                Text(
                  statusEmoji,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: AppDimensions.iconSizeM.toDouble(),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingS),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.collaborativeOffline,
                      style: AppTextStyles.bodyLargeBold.copyWith(
                        color: cs.error,
                      ),
                    ),
                    Text(
                      statusText,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.error,
                      ),
                    ),
                  ],
                ),
              ),
              if (showRetryButton && onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  child: Text(
                    context.l10n.commonRetry,
                    style: AppTextStyles.buttonTextStyle.copyWith(
                      color: cs.error,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Simple online/offline indicator
  static Widget onlineIndicator({
    required bool isOnline,
    double size = 8,
    Color? onlineColor,
    Color? offlineColor,
  }) {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isOnline
                ? (onlineColor ?? context.butleryColors.success)
                : (offlineColor ?? cs.error),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
