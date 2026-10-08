// lib/widgets/social/collaborative/components/collaborative_connection_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';

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
          final modeColors = context.modeColors;
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space4,
              vertical: AppDimensions.spacingXs,
            ),
            decoration: BoxDecoration(
              color: modeColors.surfaceTintSuccess,
              borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: modeColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingXs),
                Text(
                  context.l10n.collaborativeOnline,
                  style: AppTextStyles.metadataEmphasized.copyWith(
                    color: modeColors.onSuccessContainer,
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
            color: context.modeColors.surfaceTintDanger,
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
                const SizedBox(width: AppDimensions.space4),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.collaborativeOffline,
                      style: AppTextStyles.bodyLargeBold.copyWith(
                        color: cs.onErrorContainer,
                      ),
                    ),
                    Text(
                      statusText,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onErrorContainer,
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
                      color: cs.onErrorContainer,
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
                ? (onlineColor ?? context.modeColors.success)
                : (offlineColor ?? cs.error),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
