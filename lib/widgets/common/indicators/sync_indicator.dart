import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Sync status states derived from Firestore snapshot metadata.
enum SyncStatus {
  synced,
  pendingWrites,
  offline,
}

/// Compact indicator showing Firestore sync state.
///
/// Derives state from Firestore snapshot metadata:
/// - [hasPendingWrites]: local changes haven't reached the server yet
/// - [isFromCache]: snapshot came from local cache (device is offline)
///
/// Visibility:
/// - Synced: hidden by default (no visual noise)
/// - Pending writes: warning-colored icon with pulse animation
/// - Offline: muted icon, static
class SyncIndicator extends StatefulWidget {
  final bool hasPendingWrites;
  final bool isFromCache;
  final bool alwaysVisible;

  const SyncIndicator({
    super.key,
    required this.hasPendingWrites,
    required this.isFromCache,
    this.alwaysVisible = false,
  });

  @override
  State<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends State<SyncIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _reduceMotion = false;

  /// Firestore returns the first snapshot from cache (`fromCache: true`) for
  /// a second or two even when online, before the server responds. Showing
  /// the offline icon for that blink is misleading. We delay committing to
  /// offline state until the cache flag has persisted past this grace period.
  static const Duration _offlineGracePeriod = Duration(seconds: 3);
  Timer? _offlineDebounce;
  bool _debouncedOffline = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: AppDimensions.animationDurationExtended,
    );
    _pulseAnimation =
        Tween<double>(
          begin: AppDimensions.opacityMedium,
          end: 1.0,
        ).animate(
          CurvedAnimation(
            parent: _pulseController,
            curve: Curves.easeInOut,
          ),
        );
    _syncOfflineDebounce();
    _updateAnimation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = !AnimationUtils.shouldAnimate(context);
    if (_reduceMotion && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(SyncIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFromCache != widget.isFromCache) {
      _syncOfflineDebounce();
    }
    if (oldWidget.hasPendingWrites != widget.hasPendingWrites ||
        oldWidget.isFromCache != widget.isFromCache) {
      _updateAnimation();
    }
  }

  /// Only mark the widget as "offline" once `isFromCache` has persisted for
  /// [_offlineGracePeriod] — prevents the boot-time cache snapshot from
  /// flashing the offline icon.
  ///
  /// On Flutter web, Firestore's web SDK keeps `fromCache: true` on many
  /// snapshots even while actively talking to the server, so the flag is an
  /// unreliable offline signal there. We suppress offline state entirely on
  /// web — Firebase handles sync and surfaces genuine failures through
  /// per-request errors.
  void _syncOfflineDebounce() {
    _offlineDebounce?.cancel();
    if (kIsWeb || !widget.isFromCache) {
      // Already cleared — nothing to notify. Guards initState where
      // setState() is illegal and avoids waking up parent rebuilds.
      if (!_debouncedOffline) return;
      if (mounted) {
        setState(() => _debouncedOffline = false);
      } else {
        _debouncedOffline = false;
      }
      return;
    }
    _offlineDebounce = Timer(_offlineGracePeriod, () {
      if (mounted && widget.isFromCache) {
        setState(() => _debouncedOffline = true);
      }
    });
  }

  void _updateAnimation() {
    if (_status == SyncStatus.pendingWrites && !_reduceMotion) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  SyncStatus get _status {
    if (widget.hasPendingWrites) return SyncStatus.pendingWrites;
    if (_debouncedOffline) return SyncStatus.offline;
    return SyncStatus.synced;
  }

  @override
  void dispose() {
    _offlineDebounce?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    if (status == SyncStatus.synced && !widget.alwaysVisible) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: _semanticsLabel(status),
      child: Tooltip(
        message: _tooltipMessage(status),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: status == SyncStatus.pendingWrites
                  ? _pulseAnimation.value
                  : 1.0,
              child: child,
            );
          },
          child: _buildIndicator(status),
        ),
      ),
    );
  }

  Widget _buildIndicator(SyncStatus status) {
    final colors = context.butleryColors;
    final cs = Theme.of(context).colorScheme;
    final (color, icon) = switch (status) {
      SyncStatus.synced => (colors.success, Icons.cloud_done_outlined),
      SyncStatus.pendingWrites => (colors.warning, Icons.cloud_upload_outlined),
      SyncStatus.offline => (cs.onSurfaceVariant, Icons.cloud_off_outlined),
    };

    return Container(
      padding: AppDimensions.paddingAll3,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusRound),
      ),
      child: Icon(
        icon,
        size: AppDimensions.iconSizeS,
        color: color,
      ),
    );
  }

  String _tooltipMessage(SyncStatus status) {
    return switch (status) {
      SyncStatus.synced => 'Synkroniserad',
      SyncStatus.pendingWrites => 'Sparar...',
      SyncStatus.offline => 'Offline',
    };
  }

  String _semanticsLabel(SyncStatus status) {
    return switch (status) {
      SyncStatus.synced => 'Data synkroniserad',
      SyncStatus.pendingWrites => 'Sparar till servern',
      SyncStatus.offline => 'Offline-läge',
    };
  }
}
