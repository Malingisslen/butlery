// lib/widgets/common/indicators/participant_list_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/realtime/participant_tracker.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/user/user_avatar_widgets.dart';
import 'package:butlery/theme/app_shadows.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

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
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
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
                Icon(
                  Icons.people,
                  color: cs.primary,
                  size: AppDimensions.iconSizeM,
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Text(
                  context.l10n.participantsCount(activities.length),
                  style: AppTextStyles.headlineSmall,
                ),
                const Spacer(),
                _buildOnlineIndicator(context),
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

  Widget _buildOnlineIndicator(BuildContext context) {
    final onlineCount = activities.where((a) => a.isOnline).length;
    final successColor = context.butleryColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: successColor.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusRound),
        border: Border.all(
          color: successColor.withValues(
            alpha: AppDimensions.opacityMediumLight,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppDimensions.spacingS,
            height: AppDimensions.spacingS,
            decoration: BoxDecoration(
              color: successColor,
              borderRadius: BorderRadius.circular(AppDimensions.spacingXs),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            context.l10n.participantsOnlineCount(onlineCount),
            style: AppTextStyles.successText,
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantChip(
    BuildContext context,
    ParticipantActivity activity,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isCurrentUser = activity.userId == currentUserId;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingS,
      ),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? cs.primary.withValues(alpha: AppDimensions.opacityVeryLight)
            : cs.surface,
        borderRadius: BorderRadius.circular(AppDimensions.iconSizeAction),
        border: Border.all(
          color: isCurrentUser
              ? cs.primary.withValues(alpha: AppDimensions.opacityMediumLight)
              : cs.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              _buildSimpleAvatar(context, activity.displayName, 24),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: AppDimensions.spacingS,
                  height: AppDimensions.spacingS,
                  decoration: BoxDecoration(
                    color: activity.isOnline
                        ? context.butleryColors.success
                        : cs.outline,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.spacingXs,
                    ),
                    border: Border.all(
                      color: cs.surface,
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
                isCurrentUser ? context.l10n.commonYou : activity.displayName,
                style: isCurrentUser
                    ? AppTextStyles.bodyLargeBold.copyWith(
                        color: cs.primary,
                      )
                    : AppTextStyles.bodyLarge,
              ),
              Text(
                activity.isOnline
                    ? context.l10n.userStatusOnline
                    : context.l10n.userStatusOffline,
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleAvatar(
    BuildContext context,
    String displayName,
    double size,
  ) {
    final cs = Theme.of(context).colorScheme;
    final initials = UserAvatarWidgets.getInitials(displayName);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.primary.withValues(alpha: AppDimensions.opacityVeryLight),
      ),
      child: Center(
        child: UserAvatarWidgets.initialsOrFallback(
          initials: initials,
          fontSize: size * 0.4,
          color: cs.primary,
        ),
      ),
    );
  }
}
