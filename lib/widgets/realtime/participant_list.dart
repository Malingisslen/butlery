// lib/widgets/realtime/participant_list.dart - FIXED MED 100% APPTHEME

import 'package:flutter/material.dart';
import '../../viewmodels/realtime/participant_tracker.dart';
import '../../widgets/user_avatar.dart';
import '../../theme/app_theme.dart';

/// Lista deltagare med online status och management actions
class ParticipantList extends StatelessWidget {
  final List<ParticipantActivity> activities;
  final String currentUserId;
  final bool canManageParticipants;
  final Function(String userId)? onRemoveParticipant;
  final Function(String userId)? onChangePermission;

  const ParticipantList({
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

    return Container(
      decoration: AppTheme.cardDecoration,
      child: Padding(
        padding: AppTheme.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppTheme.actionIcon(context, Icons.people,
                    color: AppTheme.primaryColor),
                AppTheme.smallHorizontalGap,
                Text(
                  'Deltagare (${activities.length})',
                  style: AppTheme.sectionTitleStyle,
                ),
                const Spacer(),
                _buildOnlineIndicator(context),
              ],
            ),
            AppTheme.mediumGap,

            // Participants grid
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
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

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.chipRadius,
        border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppTheme.spacingSm,
            height: AppTheme.spacingSm,
            decoration: BoxDecoration(
              color: AppTheme.successColor,
              borderRadius: BorderRadius.circular(AppTheme.spacingXs),
            ),
          ),
          SizedBox(width: AppTheme.spacingXs),
          Text(
            '$onlineCount online',
            style: AppTheme.successTextStyle.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantChip(
      BuildContext context, ParticipantActivity activity) {
    final isCurrentUser = activity.userId == currentUserId;
    final canRemove = canManageParticipants && !isCurrentUser;

    return GestureDetector(
      onLongPress:
          canRemove ? () => _showParticipantMenu(context, activity) : null,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCurrentUser
                ? AppTheme.primaryColor.withValues(alpha: 0.3)
                : AppTheme.dividerColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                UserAvatar.small(
                  displayName: activity.displayName,
                ),

                // Online indicator
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: AppTheme.spacingSm,
                    height: AppTheme.spacingSm,
                    decoration: BoxDecoration(
                      color: activity.isOnline
                          ? AppTheme.successColor
                          : AppTheme.textTertiary,
                      borderRadius: BorderRadius.circular(AppTheme.spacingXs),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            AppTheme.smallHorizontalGap,

            // Name and status
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isCurrentUser ? 'Du' : activity.displayName,
                  style: isCurrentUser
                      ? AppTheme.bodyStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        )
                      : AppTheme.bodyStyle,
                ),
                Text(
                  _getActivityText(activity),
                  style: AppTheme.captionStyle,
                ),
              ],
            ),

            // Management menu indicator
            if (canRemove) ...[
              SizedBox(width: AppTheme.spacingXs),
              AppTheme.infoIcon(context, icon: Icons.more_vert),
            ],
          ],
        ),
      ),
    );
  }

  String _getActivityText(ParticipantActivity activity) {
    if (activity.isOnline) {
      return 'Online';
    } else if (activity.wasActiveWithin(const Duration(minutes: 30))) {
      return 'Nyligen aktiv';
    } else if (activity.wasActiveWithin(const Duration(hours: 1))) {
      return 'Aktiv senaste timmen';
    } else {
      return 'Offline';
    }
  }

  void _showParticipantMenu(
      BuildContext context, ParticipantActivity activity) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
          borderRadius: AppTheme.bottomSheetBorderRadius),
      builder: (context) => _ParticipantMenu(
        activity: activity,
        onRemove: onRemoveParticipant,
        onChangePermission: onChangePermission,
      ),
    );
  }
}

/// Menu för att hantera deltagare
class _ParticipantMenu extends StatelessWidget {
  final ParticipantActivity activity;
  final Function(String userId)? onRemove;
  final Function(String userId)? onChangePermission;

  const _ParticipantMenu({
    required this.activity,
    this.onRemove,
    this.onChangePermission,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppTheme.cardPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              UserAvatar.medium(
                displayName: activity.displayName,
              ),
              AppTheme.mediumHorizontalGap,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.displayName,
                      style: AppTheme.cardTitleStyle,
                    ),
                    Text(
                      activity.isOnline ? 'Online' : 'Offline',
                      style: activity.isOnline
                          ? AppTheme.successTextStyle
                          : AppTheme.metadataStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),

          AppTheme.mediumGap,
          Divider(color: AppTheme.dividerColor, height: AppTheme.dividerHeight),

          // Actions
          if (onChangePermission != null)
            ListTile(
              leading: AppTheme.actionIcon(context, Icons.security),
              title: Text('Ändra behörigheter', style: AppTheme.bodyStyle),
              onTap: () {
                Navigator.of(context).pop();
                onChangePermission?.call(activity.userId);
              },
            ),

          if (onRemove != null)
            ListTile(
              leading: AppTheme.actionIcon(context, Icons.person_remove,
                  color: AppTheme.errorColor),
              title: Text(
                'Ta bort från meny',
                style: AppTheme.errorTextStyle,
              ),
              onTap: () {
                Navigator.of(context).pop();
                _confirmRemoval(context);
              },
            ),

          // Cancel
          AppTheme.smallGap,
          OutlinedButton(
            style: AppTheme.secondaryButtonStyle,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoval(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ta bort deltagare', style: AppTheme.sectionTitleStyle),
        content: Text(
          'Vill du ta bort ${activity.displayName} från denna meny? '
          'De kommer inte längre kunna se eller redigera menyn.',
          style: AppTheme.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRemove?.call(activity.userId);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );
  }
}
