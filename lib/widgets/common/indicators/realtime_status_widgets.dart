// lib/widgets/common/indicators/realtime_status_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_motion.dart';
import 'package:butlery/viewmodels/realtime/connection_monitor.dart';
import 'package:butlery/widgets/common/indicators/connection_dot.dart';

/// Realtime status widget showing connection status
class RealtimeStatusWidget extends StatelessWidget {
  final bool isOnline;
  final String statusDescription;
  final ConnectionStatus status;
  final bool showText;
  final EdgeInsets? padding;

  const RealtimeStatusWidget({
    super.key,
    required this.isOnline,
    required this.statusDescription,
    required this.status,
    this.showText = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: statusDescription,
      child: Container(
        padding: padding ?? const EdgeInsets.all(AppDimensions.space4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: AnimationUtils.getDuration(
                context,
                AppMotion.standard,
              ),
              child: ConnectionDot(key: ValueKey(status), status: status),
            ),
            if (showText) ...[
              const SizedBox(width: AppDimensions.space4),
              AnimatedSwitcher(
                duration: AnimationUtils.getDuration(
                  context,
                  AppMotion.standard,
                ),
                child: Text(
                  statusDescription,
                  key: ValueKey(statusDescription),
                  style: isOnline
                      ? AppTextStyles.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        )
                      : AppTextStyles.labelMedium.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Realtime status banner for offline state
class RealtimeStatusBanner extends StatelessWidget {
  final bool isOnline;
  final String statusDescription;
  final ConnectionStatus status;
  final VoidCallback? onRetry;

  const RealtimeStatusBanner({
    super.key,
    required this.isOnline,
    required this.statusDescription,
    required this.status,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isOnline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        (AppDimensions.space8 + AppDimensions.space4),
      ),
      // An error notice (B83-2): the mode's tint with no border, and the
      // title in the on-colour that reads on that tint.
      color: context.modeColors.surfaceTintDanger,
      child: Row(
        children: [
          ConnectionDot(status: status),
          const SizedBox(
            width: (AppDimensions.space8 + AppDimensions.space4),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.realtimeOffline,
                  style: AppTextStyles.titleBold.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                Text(
                  statusDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(context.l10n.commonRetry),
            ),
        ],
      ),
    );
  }
}
