// lib/widgets/common/indicators/participant_list_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/realtime/participant_tracker.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_shadows.dart';

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
        boxShadow: AppShadows.subtle,
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
                  color: AppColors.forestGreen,
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
        color: AppColors.success.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusRound),
        border: Border.all(
          color: AppColors.success.withValues(alpha: AppDimensions.opacityMediumLight),
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
            style: AppTextStyles.successText,
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
            ? AppColors.forestGreen.withValues(alpha: AppDimensions.opacityVeryLight)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.iconSizeAction),
        border: Border.all(
          color: isCurrentUser
              ? AppColors.forestGreen.withValues(alpha: AppDimensions.opacityMediumLight)
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
                    borderRadius:
                        BorderRadius.circular(AppDimensions.spacingXs),
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
                    ? AppTextStyles.bodyLargeBold.copyWith(
                        color: AppColors.forestGreen,
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
        color: AppColors.forestGreen.withValues(alpha: AppDimensions.opacityVeryLight),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.bodyLargeBold.copyWith(
            fontSize: size * 0.4,
            color: AppColors.forestGreen,
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
