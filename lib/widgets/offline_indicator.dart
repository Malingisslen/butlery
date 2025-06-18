// lib/widgets/offline_indicator.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/offline_service.dart';
import '../theme/app_theme.dart';

/// Widget som visar offline/online status
class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineService>(
      builder: (context, offlineService, child) {
        // Visa ingenting om online
        if (offlineService.isOnline) {
          return const SizedBox.shrink();
        }

        // Visa offline-banner
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingSm,
          ),
          color: AppTheme.warningColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                color: Colors.white,
                size: AppTheme.iconSizeSmall,
              ),
              SizedBox(width: AppTheme.spacingSm),
              Text(
                'Offline-läge - Ändringar sparas lokalt',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
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

/// Liten offline-indikator för app bar
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
