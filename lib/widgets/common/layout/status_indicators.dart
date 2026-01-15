// lib/widgets/common/layout/status_indicators.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/services/offline_service.dart';

/// Status indicators for app state display
/// This module provides widgets for displaying app status like
/// offline indicators and connection status.
class StatusIndicators {
  /// Offline indicator that shows when the app is offline
  /// Exactly like original OfflineIndicator
  static Widget offlineIndicator({
    String? message,
    Color? backgroundColor,
  }) {
    return OfflineIndicator(
      message: message,
      backgroundColor: backgroundColor,
    );
  }

  /// Small offline status icon for app bar
  static Widget offlineStatusIcon() {
    return const OfflineStatusIcon();
  }
}

/// Offline indicator widget that shows when the app is offline
class OfflineIndicator extends StatelessWidget {
  final String? message;
  final Color? backgroundColor;

  const OfflineIndicator({
    super.key,
    this.message,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineService>(
      builder: (context, offlineService, child) {
        // Show nothing if online
        if (offlineService.isOnline) {
          return const SizedBox.shrink();
        }

        // Show offline banner
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingL,
            vertical: AppDimensions.spacingS,
          ),
          color: backgroundColor ?? AppColors.warning,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off,
                color: AppColors.neutralLight,
                size: AppDimensions.iconSizeM,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Text(
                message ?? 'Offline-läge - Ändringar sparas lokalt',
                style: AppTextStyles.text16Medium.copyWith(
                  color: AppColors.neutralLight,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small offline status icon for app bar
class OfflineStatusIcon extends StatelessWidget {
  const OfflineStatusIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineService>(
      builder: (context, offlineService, child) {
        if (offlineService.isOnline) {
          return const SizedBox.shrink();
        }

        return const Padding(
          padding: EdgeInsetsDirectional.only(end: AppDimensions.spacingS),
          child: Icon(
            Icons.cloud_off,
            color: AppColors.warning,
            size: AppDimensions.iconSizeAction,
          ),
        );
      },
    );
  }
}
