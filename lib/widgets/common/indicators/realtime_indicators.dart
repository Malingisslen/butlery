// lib/widgets/common/indicators/realtime_indicators.dart

import 'package:flutter/material.dart';
import '../../../viewmodels/realtime/participant_tracker.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_styles.dart';

/// Realtime indicators for collaborative features
class RealtimeIndicators {
  /// ✏️ Indikator för vem som redigerar just nu
  /// Replaces: EditIndicator
  static Widget editIndicator({
    required String editorName,
    String? editorId,
    required String editingWhat,
    Color? color,
    bool isVisible = true,
    Duration animationDuration = const Duration(milliseconds: 300),
  }) {
    return _EditIndicatorWidget(
      editorName: editorName,
      editorId: editorId,
      editingWhat: editingWhat,
      color: color,
      isVisible: isVisible,
      animationDuration: animationDuration,
    );
  }

  /// 👥 Lista över aktiva deltagare med management
  /// Replaces: ParticipantList
  static Widget participantList({
    required List<ParticipantActivity> activities,
    required String currentUserId,
    bool canManageParticipants = false,
    Function(String userId)? onRemoveParticipant,
    Function(String userId)? onChangePermission,
  }) {
    return _ParticipantListWidget(
      activities: activities,
      currentUserId: currentUserId,
      canManageParticipants: canManageParticipants,
      onRemoveParticipant: onRemoveParticipant,
      onChangePermission: onChangePermission,
    );
  }

  /// 🌐 Connection status indikator
  /// Replaces: RealtimeStatusIndicator
  static Widget realtimeStatus({
    required bool isOnline,
    required String statusDescription,
    required String statusEmoji,
    bool showText = false,
    EdgeInsets? padding,
  }) {
    return _RealtimeStatusWidget(
      isOnline: isOnline,
      statusDescription: statusDescription,
      statusEmoji: statusEmoji,
      showText: showText,
      padding: padding ?? const EdgeInsets.all(AppDimensions.spacingS),
    );
  }

  /// 📢 Expanderat status banner för större visningar
  static Widget realtimeStatusBanner({
    required bool isOnline,
    required String statusDescription,
    required String statusEmoji,
    VoidCallback? onRetry,
  }) {
    return _RealtimeStatusBanner(
      isOnline: isOnline,
      statusDescription: statusDescription,
      statusEmoji: statusEmoji,
      onRetry: onRetry,
    );
  }
}

// =====================================
// 🔒 PRIVATE IMPLEMENTATION WIDGETS
// =====================================

/// ✏️ Edit indicator widget
class _EditIndicatorWidget extends StatefulWidget {
  final String editorName;
  final String? editorId;
  final String editingWhat;
  final Color? color;
  final bool isVisible;
  final Duration animationDuration;

  const _EditIndicatorWidget({
    required this.editorName,
    this.editorId,
    required this.editingWhat,
    this.color,
    this.isVisible = true,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<_EditIndicatorWidget> createState() => _EditIndicatorWidgetState();
}

class _EditIndicatorWidgetState extends State<_EditIndicatorWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isVisible) {
      _fadeController.forward();
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_EditIndicatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _fadeController.forward();
        _pulseController.repeat(reverse: true);
      } else {
        _fadeController.reverse();
        _pulseController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primaryBlue;

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.editorName} redigerar ${widget.editingWhat}',
                  style: TextStyle(
                    fontSize: AppTextStyles.bodySmall.fontSize,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}

/// 👥 Participant list widget
class _ParticipantListWidget extends StatelessWidget {
  final List<ParticipantActivity> activities;
  final String currentUserId;
  final bool canManageParticipants;
  final Function(String userId)? onRemoveParticipant;
  final Function(String userId)? onChangePermission;

  const _ParticipantListWidget({
    required this.activities,
    required this.currentUserId,
    this.canManageParticipants = false,
    this.onRemoveParticipant,
    this.onChangePermission,
  });

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.1),
            blurRadius: AppDimensions.elevationLow,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.people,
                  color: AppColors.primaryBlue,
                  size: AppDimensions.iconSizeM,
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Text(
                  'Deltagare (${activities.length})',
                  style: AppTextStyles.headlineSmall,
                ),
                const Spacer(),
                _buildOnlineIndicator(),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            Wrap(
              spacing: AppDimensions.spacingS,
              runSpacing: AppDimensions.spacingS,
              children: activities.map((activity) {
                return _buildParticipantChip(context, activity);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineIndicator() {
    final onlineCount = activities.where((a) => a.isOnline).length;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusRound),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppDimensions.spacingS,
            height: AppDimensions.spacingS,
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(AppDimensions.spacingXs),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            '$onlineCount online',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantChip(
      BuildContext context, ParticipantActivity activity) {
    final isCurrentUser = activity.userId == currentUserId;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingS,
      ),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primaryBlue.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.iconSizeAction),
        border: Border.all(
          color: isCurrentUser
              ? AppColors.primaryBlue.withValues(alpha: 0.3)
              : AppColors.divider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              _buildSimpleAvatar(activity.displayName, 24),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: AppDimensions.spacingS,
                  height: AppDimensions.spacingS,
                  decoration: BoxDecoration(
                    color: activity.isOnline
                        ? AppColors.success
                        : AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(AppDimensions.spacingXs),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isCurrentUser ? 'Du' : activity.displayName,
                style: isCurrentUser
                    ? AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      )
                    : AppTextStyles.bodyLarge,
              ),
              Text(
                activity.isOnline ? 'Online' : 'Offline',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleAvatar(String displayName, double size) {
    final initials = _getInitials(displayName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryBlue.withValues(alpha: 0.1),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.bodyLarge.copyWith(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryBlue,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';

    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      final word = words[0];
      return word.length >= 2
          ? '${word[0]}${word[1]}'.toUpperCase()
          : word[0].toUpperCase();
    } else {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
  }
}

/// 🌐 Realtime status widget
class _RealtimeStatusWidget extends StatelessWidget {
  final bool isOnline;
  final String statusDescription;
  final String statusEmoji;
  final bool showText;
  final EdgeInsets? padding;

  const _RealtimeStatusWidget({
    required this.isOnline,
    required this.statusDescription,
    required this.statusEmoji,
    this.showText = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: statusDescription,
      child: Container(
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingS),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                statusEmoji,
                key: ValueKey(statusEmoji),
                style: TextStyle(fontSize: AppTextStyles.bodyLarge.fontSize),
              ),
            ),
            if (showText) ...[
              const SizedBox(width: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  statusDescription,
                  key: ValueKey(statusDescription),
                  style: TextStyle(
                    fontSize: AppTextStyles.bodySmall.fontSize,
                    color: isOnline
                        ? Theme.of(context).colorScheme.onSurface
                        : AppColors.error,
                    fontWeight: isOnline ? FontWeight.normal : FontWeight.bold,
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

/// 📢 Realtime status banner
class _RealtimeStatusBanner extends StatelessWidget {
  final bool isOnline;
  final String statusDescription;
  final String statusEmoji;
  final VoidCallback? onRetry;

  const _RealtimeStatusBanner({
    required this.isOnline,
    required this.statusDescription,
    required this.statusEmoji,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isOnline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: AppColors.error.withValues(alpha: 0.1),
      child: Row(
        children: [
          Text(statusEmoji, style: TextStyle(fontSize: AppDimensions.iconSizeM.toDouble())),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Offline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                Text(statusDescription, style: TextStyle(fontSize: AppTextStyles.bodyLarge.fontSize)),
              ],
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Försök igen'),
            ),
        ],
      ),
    );
  }
}