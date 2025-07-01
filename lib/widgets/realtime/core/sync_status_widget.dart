import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Enum som representerar olika synk-statusar
enum SyncStatus { syncing, synced, error }

/// Visar nuvarande status för datasykronisering
class SyncStatusWidget extends StatelessWidget {
  final SyncStatus status;
  final VoidCallback? onRetry;

  const SyncStatusWidget({
    super.key,
    required this.status,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case SyncStatus.syncing:
        return Row(
          children: [
            AppTheme.smallLoadingIndicator(),
            const SizedBox(width: AppTheme.spacingXs),
            const Text('Synkroniserar...'),
          ],
        );
      case SyncStatus.error:
        return Row(
          children: [
            Icon(Icons.error_outline,
                size: AppTheme.iconSizeInfo, color: AppTheme.errorColor),
            const SizedBox(width: AppTheme.spacingXs),
            Text('Synk-fel', style: AppTheme.errorTextStyle),
            if (onRetry != null) ...[
              const SizedBox(width: AppTheme.spacingXs),
              IconButton(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                iconSize: AppTheme.iconSizeAction,
              ),
            ],
          ],
        );
      case SyncStatus.synced:
      default:
        return Row(
          children: [
            Icon(Icons.check_circle,
                size: AppTheme.iconSizeInfo, color: AppTheme.successColor),
            const SizedBox(width: AppTheme.spacingXs),
            Text('Synkad', style: AppTheme.successTextStyle),
          ],
        );
    }
  }
}
