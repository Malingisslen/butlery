// lib/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart';

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
    final permissionService = ServiceLocator.get<PermissionService>();
    final userService = ServiceLocator.get<UserService>();
    final currentUserId = permissionService.currentUser?.uid;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _getListTypeIcon(),
            color: _getListTypeColor(),
            size: AppDimensions.iconSizeAction,
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Text(
              _getDialogTitle(),
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
            label: 'Hantera delning',
            icon: Icons.manage_accounts,
            onPressed: () {
              Navigator.pop(context);
              _showManageSharing(context);
            },
          ),
        ActionButtons.primaryButton(
          context,
          label: 'Stäng',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildListInfoSection(BuildContext context) {
    return Card(
      color:
          _getListTypeColor().withValues(alpha: AppDimensions.opacityVeryLight),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Listinformation',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.forestGreen,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            _buildInfoRow('Namn', list.name),
            _buildInfoRow('Typ', _getListTypeLabel()),
            _buildInfoRow('Skapare', list.ownerDisplayName),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionSection(BuildContext context, String currentUserId) {
    final userPermission = list.memberPermissions[currentUserId];
    final isOwner = list.ownerId == currentUserId;

    String permissionLabel;
    String permissionDescription;
    IconData permissionIcon;
    Color permissionColor;

    if (isOwner) {
      permissionLabel = 'Administratör (Ägare)';
      permissionDescription =
          'Du äger denna lista och kan hantera alla aspekter av den';
      permissionIcon = Icons.admin_panel_settings;
      permissionColor = AppColors.forestGreen;
    } else {
      switch (userPermission) {
        case SharedListPermission.view:
          permissionLabel = 'Kan bara se';
          permissionDescription =
              'Du kan se listan och alla artiklar men inte redigera';
          permissionIcon = Icons.visibility;
          permissionColor = AppColors.textMedium;
          break;
        case SharedListPermission.edit:
          permissionLabel = 'Kan redigera';
          permissionDescription =
              'Du kan lägga till, ta bort och ändra artiklar i listan';
          permissionIcon = Icons.edit;
          permissionColor = AppColors.accent;
          break;
        case SharedListPermission.admin:
          permissionLabel = 'Administratör';
          permissionDescription =
              'Du kan redigera listan och hantera medlemmarnas behörigheter';
          permissionIcon = Icons.admin_panel_settings;
          permissionColor = AppColors.forestGreen;
          break;
        default:
          permissionLabel = 'Ej specificerad';
          permissionDescription =
              'Din behörighetsnivå är inte tydligt definierad';
          permissionIcon = Icons.help;
          permissionColor = AppColors.textMedium;
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
                  'Din behörighet',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.forestGreen,
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
    final allMembers = <String, SharedListPermission>{};

    if (!list.memberPermissions.containsKey(list.ownerId)) {
      allMembers[list.ownerId] = SharedListPermission.admin;
    }

    allMembers.addAll(list.memberPermissions);

    return Card(
      color: AppColors.forestGreen
          .withValues(alpha: AppDimensions.opacityVeryLight),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people,
                    color: AppColors.forestGreen,
                    size: AppDimensions.iconSizeM),
                const SizedBox(width: AppDimensions.spacingS),
                Text(
                  'Medlemmar (${allMembers.length})',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.forestGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            ...allMembers.entries.map((entry) {
              final isOwner = entry.key == list.ownerId;
              return _buildMemberRow(entry.key, entry.value, isOwner);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberRow(
      String userId, SharedListPermission permission, bool isOwner) {
    final String displayName = userDisplayNames[userId] ?? 'Okänd användare';

    String permissionLabel;
    IconData permissionIcon;
    Color permissionColor;

    if (isOwner) {
      permissionLabel = 'Ägare';
      permissionIcon = Icons.admin_panel_settings;
      permissionColor = AppColors.forestGreen;
    } else {
      switch (permission) {
        case SharedListPermission.view:
          permissionLabel = 'Kan se';
          permissionIcon = Icons.visibility;
          permissionColor = AppColors.textMedium;
          break;
        case SharedListPermission.edit:
          permissionLabel = 'Kan redigera';
          permissionIcon = Icons.edit;
          permissionColor = AppColors.accent;
          break;
        case SharedListPermission.admin:
          permissionLabel = 'Admin';
          permissionIcon = Icons.admin_panel_settings;
          permissionColor = AppColors.forestGreen;
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.forestGreen
                .withValues(alpha: AppDimensions.opacityVeryLight),
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.forestGreen,
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
                  style: AppTextStyles.text16Medium,
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
    return Card(
      color: AppColors.forestGreen
          .withValues(alpha: AppDimensions.opacityVeryLight),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history,
                    color: AppColors.forestGreen,
                    size: AppDimensions.iconSizeM),
                const SizedBox(width: AppDimensions.spacingS),
                Text(
                  'Senaste aktivitet',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.forestGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            if (list.lastActivityByDisplayName != null)
              _buildInfoRow('Av', list.lastActivityByDisplayName!),
            if (list.lastActivityAt != null)
              _buildInfoRow('När', _formatDateTime(list.lastActivityAt!)),
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
        return Icons.bookmark;
    }
  }

  Color _getListTypeColor() {
    switch (list.type) {
      case ListType.personal:
        return AppColors.forestGreen;
      case ListType.collaborative:
        return AppColors.forestGreen;
      case ListType.template:
        return AppColors.textMedium;
    }
  }

  String _getListTypeLabel() {
    switch (list.type) {
      case ListType.personal:
        return 'Personlig lista';
      case ListType.collaborative:
        return 'Delad lista';
      case ListType.template:
        return 'Mall-lista';
    }
  }

  String _getDialogTitle() {
    return 'Lista: ${list.name}';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte ladda vänner: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Nyss';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min sedan';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} tim sedan';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dagar sedan';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.year}';
    }
  }
}
