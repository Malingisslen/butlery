// lib/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/adaptive_icon.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Comprehensive sharing status dialog showing detailed information about list collaboration
class ShoppingShareStatusDialog extends StatelessWidget {
  final UnifiedShoppingList list;
  final Map<String, String> userDisplayNames;

  const ShoppingShareStatusDialog({
    super.key,
    required this.list,
    this.userDisplayNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final permissionService = ServiceLocator.get<PermissionService>();
    final userService = ServiceLocator.get<UserService>();
    final currentUserId = permissionService.currentUser?.uid;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _getListTypeIcon(),
            color: _getListTypeColor(cs),
            size: AppDimensions.iconSizeAction,
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Text(
              _getDialogTitle(context),
              style: AppTextStyles.titleLarge,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildListInfoSection(context),
              if (currentUserId != null && list.isCollaborative) ...[
                const SizedBox(height: AppDimensions.spacingL),
                _buildPermissionSection(context, currentUserId),
              ],
              if (list.isCollaborative) ...[
                const SizedBox(height: AppDimensions.spacingL),
                _buildMembersSection(context, userService),
              ],
              if (list.lastActivityAt != null) ...[
                const SizedBox(height: AppDimensions.spacingL),
                _buildActivitySection(context),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (list.isCollaborative &&
            currentUserId != null &&
            _canManageSharing(currentUserId))
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.shoppingManageSharing,
            icon: Icons.manage_accounts,
            onPressed: () {
              Navigator.pop(context);
              _showManageSharing(context);
            },
          ),
        ActionButtons.primaryButton(
          context,
          label: context.l10n.commonClose,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildListInfoSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: _getListTypeColor(cs)
          .withValues(alpha: AppDimensions.opacityVeryLight),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.shoppingListInfo,
              style: AppTextStyles.titleMedium.copyWith(
                color: cs.primary,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            _buildInfoRow(context.l10n.commonName, list.name),
            _buildInfoRow(context.l10n.commonType, _getListTypeLabel(context)),
            _buildInfoRow(context.l10n.shoppingCreator, list.ownerDisplayName),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionSection(BuildContext context, String currentUserId) {
    final cs = Theme.of(context).colorScheme;
    final userPermission = list.memberPermissions[currentUserId];
    final isOwner = list.ownerId == currentUserId;

    String permissionLabel;
    String permissionDescription;
    IconData permissionIcon;
    Color permissionColor;

    if (isOwner) {
      permissionLabel = context.l10n.shoppingAdminOwner;
      permissionDescription = context.l10n.shoppingAdminOwnerDescription;
      permissionIcon = Icons.admin_panel_settings;
      permissionColor = cs.primary;
    } else {
      switch (userPermission) {
        case SharedListPermission.view:
          permissionLabel = context.l10n.shoppingPermissionViewOnly;
          permissionDescription =
              context.l10n.shoppingPermissionViewDescription;
          permissionIcon = Icons.visibility;
          permissionColor = cs.onSurfaceVariant;
          break;
        case SharedListPermission.edit:
          permissionLabel = context.l10n.shoppingPermissionEdit;
          permissionDescription =
              context.l10n.shoppingPermissionEditDescription;
          permissionIcon = Icons.edit;
          permissionColor = cs.secondary;
          break;
        case SharedListPermission.admin:
          permissionLabel = context.l10n.shoppingPermissionAdministrator;
          permissionDescription =
              context.l10n.shoppingPermissionAdminDescription;
          permissionIcon = Icons.admin_panel_settings;
          permissionColor = cs.primary;
          break;
        default:
          permissionLabel = context.l10n.shoppingPermissionUnspecified;
          permissionDescription =
              context.l10n.shoppingPermissionUnspecifiedDescription;
          permissionIcon = Icons.help;
          permissionColor = cs.onSurfaceVariant;
      }
    }

    return Card(
      color: permissionColor.withValues(alpha: AppDimensions.opacityVeryLight),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(permissionIcon,
                    color: permissionColor, size: AppDimensions.iconSizeM),
                const SizedBox(width: AppDimensions.spacingS),
                Text(
                  context.l10n.shoppingYourPermission,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              permissionLabel,
              style: AppTextStyles.bodyBold,
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              permissionDescription,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersSection(BuildContext context, UserService userService) {
    final cs = Theme.of(context).colorScheme;
    final allMembers = <String, SharedListPermission>{};

    if (!list.memberPermissions.containsKey(list.ownerId)) {
      allMembers[list.ownerId] = SharedListPermission.admin;
    }

    allMembers.addAll(list.memberPermissions);

    return Card(
      color: cs.primary.withValues(alpha: AppDimensions.opacityVeryLight),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people,
                    color: cs.primary, size: AppDimensions.iconSizeM),
                const SizedBox(width: AppDimensions.spacingS),
                Text(
                  context.l10n.shoppingMembersCount(allMembers.length),
                  style: AppTextStyles.titleMedium.copyWith(
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            ...allMembers.entries.map((entry) {
              final isOwner = entry.key == list.ownerId;
              return _buildMemberRow(context, entry.key, entry.value, isOwner);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberRow(BuildContext context, String userId,
      SharedListPermission permission, bool isOwner) {
    final cs = Theme.of(context).colorScheme;
    final String displayName =
        userDisplayNames[userId] ?? context.l10n.shoppingUnknownUser;

    String permissionLabel;
    IconData permissionIcon;
    Color permissionColor;

    if (isOwner) {
      permissionLabel = context.l10n.shoppingPermissionOwner;
      permissionIcon = Icons.admin_panel_settings;
      permissionColor = cs.primary;
    } else {
      switch (permission) {
        case SharedListPermission.view:
          permissionLabel = context.l10n.shoppingPermissionView;
          permissionIcon = Icons.visibility;
          permissionColor = cs.onSurfaceVariant;
          break;
        case SharedListPermission.edit:
          permissionLabel = context.l10n.shoppingPermissionEdit;
          permissionIcon = Icons.edit;
          permissionColor = cs.secondary;
          break;
        case SharedListPermission.admin:
          permissionLabel = context.l10n.shoppingPermissionAdmin;
          permissionIcon = Icons.admin_panel_settings;
          permissionColor = cs.primary;
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor:
                cs.primary.withValues(alpha: AppDimensions.opacityVeryLight),
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: AppTextStyles.labelLarge.copyWith(
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTextStyles.contentTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Icon(permissionIcon,
                        size: AppDimensions.iconSizeS, color: permissionColor),
                    const SizedBox(width: AppDimensions.spacingXs),
                    Text(
                      permissionLabel,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: permissionColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.primary.withValues(alpha: AppDimensions.opacityVeryLight),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history,
                    color: cs.primary, size: AppDimensions.iconSizeM),
                const SizedBox(width: AppDimensions.spacingS),
                Text(
                  context.l10n.shoppingRecentActivity,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            if (list.lastActivityByDisplayName != null)
              _buildInfoRow(
                  context.l10n.shoppingBy, list.lastActivityByDisplayName!),
            if (list.lastActivityAt != null)
              _buildInfoRow(context.l10n.shoppingWhen,
                  _formatDateTime(context, list.lastActivityAt!)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: AppTextStyles.labelMedium,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getListTypeIcon() {
    switch (list.type) {
      case ListType.personal:
        return Icons.person;
      case ListType.collaborative:
        return Icons.people;
      case ListType.template:
        return AdaptiveIcons.savedTemplate;
    }
  }

  Color _getListTypeColor(ColorScheme cs) {
    switch (list.type) {
      case ListType.personal:
        return cs.primary;
      case ListType.collaborative:
        return cs.primary;
      case ListType.template:
        return cs.onSurfaceVariant;
    }
  }

  String _getListTypeLabel(BuildContext context) {
    switch (list.type) {
      case ListType.personal:
        return context.l10n.shoppingPersonalList;
      case ListType.collaborative:
        return context.l10n.shoppingSharedList;
      case ListType.template:
        return context.l10n.shoppingTemplateList;
    }
  }

  String _getDialogTitle(BuildContext context) {
    return list.name;
  }

  bool _canManageSharing(String currentUserId) {
    if (list.ownerId == currentUserId) return true;
    final userPermission = list.memberPermissions[currentUserId];
    return userPermission == SharedListPermission.admin;
  }

  Future<void> _showManageSharing(BuildContext context) async {
    try {
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();
      await friendsService.initialize();
      final availableFriends = friendsService.friends;

      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => ShoppingMemberManagementDialog(
            list: list,
            userDisplayNames: userDisplayNames,
            availableFriends: availableFriends,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error loading friends for member management: $e');
      if (context.mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(context.l10n.shoppingCouldNotLoadFriends(e.toString())),
            backgroundColor: cs.error,
          ),
        );
      }
    }
  }

  String _formatDateTime(BuildContext context, DateTime dateTime) {
    final now = clock.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return context.l10n.shoppingJustNow;
    } else if (difference.inHours < 1) {
      return context.l10n.shoppingMinutesAgo(difference.inMinutes);
    } else if (difference.inDays < 1) {
      return context.l10n.shoppingHoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return context.l10n.shoppingDaysAgo(difference.inDays);
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.year}';
    }
  }
}
