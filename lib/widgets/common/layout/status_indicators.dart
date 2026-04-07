// lib/widgets/common/layout/status_indicators.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Status indicators for app state display
/// This module provides widgets for displaying app status like
/// offline indicators and connection status.
class StatusIndicators {
  /// Offline indicator that shows when the app is offline
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

/// Offline indicator with animated transitions and "back online" confirmation.
/// Uses ServiceLocator to access OfflineService directly so it works in any
/// route without requiring a ChangeNotifierProvider ancestor.
class OfflineIndicator extends StatefulWidget {
  final String? message;
  final Color? backgroundColor;

  const OfflineIndicator({
    super.key,
    this.message,
    this.backgroundColor,
  });

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator> {
  late final OfflineService _offlineService;
  bool _wasOffline = false;
  bool _showBackOnline = false;

  @override
  void initState() {
    super.initState();
    _offlineService = ServiceLocator.get<OfflineService>();
    _offlineService.addListener(_onConnectivityChanged);
    _wasOffline = !_offlineService.isOnline;
  }

  @override
  void dispose() {
    _offlineService.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onConnectivityChanged() {
    final isOnline = _offlineService.isOnline;
    if (isOnline && _wasOffline) {
      // Went from offline → online: show confirmation briefly
      if (mounted) {
        setState(() => _showBackOnline = true);
        Future.delayed(AppDimensions.snackbarDuration, () {
          if (mounted) setState(() => _showBackOnline = false);
        });
      }
    }
    _wasOffline = !isOnline;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = !_offlineService.isOnline;
    final cs = Theme.of(context).colorScheme;
    final textColor = cs.surfaceContainerHighest;

    Widget? banner;
    if (isOffline) {
      banner = Container(
        key: const ValueKey('offline'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingL,
          vertical: AppDimensions.spacingS,
        ),
        color: widget.backgroundColor ?? context.butleryColors.warning,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off,
                color: textColor, size: AppDimensions.iconSizeM),
            const SizedBox(width: AppDimensions.spacingM),
            Text(
              widget.message ?? context.l10n.indicatorOfflineMode,
              style: AppTextStyles.contentTitle.copyWith(color: textColor),
            ),
          ],
        ),
      );
    } else if (_showBackOnline) {
      banner = Container(
        key: const ValueKey('online'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingL,
          vertical: AppDimensions.spacingS,
        ),
        color: context.butleryColors.success,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi, color: textColor, size: AppDimensions.iconSizeM),
            const SizedBox(width: AppDimensions.spacingM),
            Text(
              context.l10n.indicatorBackOnline,
              style: AppTextStyles.contentTitle.copyWith(color: textColor),
            ),
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: AppDimensions.animationDurationCommon,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1.0,
        child: child,
      ),
      child: banner ?? const SizedBox.shrink(),
    );
  }
}

/// Small offline status icon for app bar.
/// Uses ServiceLocator to access OfflineService directly so it works in any
/// route without requiring a ChangeNotifierProvider ancestor.
class OfflineStatusIcon extends StatelessWidget {
  const OfflineStatusIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final offlineService = ServiceLocator.get<OfflineService>();

    return ListenableBuilder(
      listenable: offlineService,
      builder: (context, child) {
        if (offlineService.isOnline) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding:
              const EdgeInsetsDirectional.only(end: AppDimensions.spacingS),
          child: Icon(
            Icons.cloud_off,
            color: context.butleryColors.warning,
            size: AppDimensions.iconSizeAction,
          ),
        );
      },
    );
  }
}
