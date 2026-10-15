// lib/widgets/social/collaborative/components/collaborative_connection_widgets.dart

import 'package:butlery/widgets/common/surfaces/butlery_disc.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/viewmodels/realtime/connection_monitor.dart';
import 'package:butlery/widgets/common/indicators/connection_dot.dart';

/// Connection status widgets for collaborative content
class CollaborativeConnectionWidgets {
  /// Show connection status for collaborative content
  static Widget connectionStatus({
    required bool isOnline,
    required String statusText,
    ConnectionStatus? status,
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
              vertical: AppDimensions.space4,
            ),
            decoration: BoxDecoration(
              color: modeColors.surfaceTintSuccess,
              borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ConnectionDot(status: ConnectionStatus.connected),
                const SizedBox(width: AppDimensions.space4),
                Text(
                  context.l10n.collaborativeOnline,
                  style: AppTextStyles.labelMedium.copyWith(
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
          padding: const EdgeInsets.all(AppDimensions.space12),
          decoration: BoxDecoration(
            color: context.modeColors.surfaceTintDanger,
          ),
          child: Row(
            children: [
              if (status != null) ...[
                ConnectionDot(status: status),
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
                ButleryTextButton(
                  label: context.l10n.commonRetry,
                  tone: ButleryTextButtonTone.onErrorBanner,
                  onPressed: onRetry,
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
        return ButleryDisc(
          size: size,
          color: isOnline
              ? (onlineColor ?? context.modeColors.success)
              : (offlineColor ?? cs.error),
        );
      },
    );
  }
}
