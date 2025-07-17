// lib/widgets/common/layout/status_indicators.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../services/offline_service.dart';

/// Status indicators for app state display
///
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
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingSm,
          ),
          color: backgroundColor ?? AppTheme.warningColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                color: AppTheme.neutralLight,
                size: AppTheme.iconSizeSmall,
              ),
              AppTheme.smallHorizontalGap,
              Text(
                message ?? 'Offline-läge - Ändringar sparas lokalt',
                style: AppTheme.bodyStyle.copyWith(
                  color: AppTheme.neutralLight,
                  fontWeight: FontWeight.w500,
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

        return Padding(
          padding: EdgeInsets.only(right: AppTheme.spacingSm),
          child: Icon(
            Icons.cloud_off,
            color: AppTheme.warningColor,
            size: AppTheme.iconSizeAction,
          ),
        );
      },
    );
  }
}