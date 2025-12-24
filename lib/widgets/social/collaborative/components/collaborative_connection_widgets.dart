// lib/widgets/social/collaborative/components/collaborative_connection_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

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
    if (isOnline) {
      // Minimal indicator when everything works
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingS,
          vertical: AppDimensions.spacingXs,
        ),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.chipRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              'Online',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w500,
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
        color: AppColors.error.withValues(alpha: 0.1),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          if (statusEmoji != null) ...[
            Builder(
              builder: (context) => Text(
                statusEmoji,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: AppDimensions.iconSizeM.toDouble(),
                    ),
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
                  'Offline',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                Text(
                  statusText,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          if (showRetryButton && onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Försök igen',
                style: AppTextStyles.buttonTextStyle.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Simple online/offline indicator
  static Widget onlineIndicator({
    required bool isOnline,
    double size = 8,
    Color? onlineColor,
    Color? offlineColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOnline
            ? (onlineColor ?? AppColors.success)
            : (offlineColor ?? AppColors.error),
        shape: BoxShape.circle,
      ),
    );
  }
}
