// lib/widgets/common/indicators/participant_list_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/realtime/participant_tracker.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Participant list widget showing active participants
class ParticipantListWidget extends StatelessWidget {
  final List<ParticipantActivity> activities;
  final String currentUserId;
  final bool canManageParticipants;
  final Function(String userId)? onRemoveParticipant;
  final Function(String userId)? onChangePermission;

  const ParticipantListWidget({
    super.key,
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
    return DecoratedBox(
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
      padding: const EdgeInsets.symmetric(
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
      padding: const EdgeInsets.symmetric(
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
