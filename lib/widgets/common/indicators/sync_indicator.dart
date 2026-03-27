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

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: AppDimensions.animationDurationExtended,
    );
    _pulseAnimation = Tween<double>(
      begin: AppDimensions.opacityMedium,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
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
    if (oldWidget.hasPendingWrites != widget.hasPendingWrites ||
        oldWidget.isFromCache != widget.isFromCache) {
      _updateAnimation();
    }
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
    if (widget.isFromCache) return SyncStatus.offline;
    return SyncStatus.synced;
  }

  @override
  void dispose() {
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
