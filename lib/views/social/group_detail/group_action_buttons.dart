// lib/views/social/group_detail/group_action_buttons.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/component_themes.dart';

/// Builds action buttons for group detail view.
class GroupActionButtons extends StatelessWidget {
  final FriendCategory group;
  final VoidCallback onShareRecipe;
  final VoidCallback onShareMenu;
  final VoidCallback onShareShoppingList;
  final VoidCallback onEditGroup;
  final VoidCallback onDeleteGroup;
  final VoidCallback onLeaveGroup;

  const GroupActionButtons({
    super.key,
    required this.group,
    required this.onShareRecipe,
    required this.onShareMenu,
    required this.onShareShoppingList,
    required this.onEditGroup,
    required this.onDeleteGroup,
    required this.onLeaveGroup,
  });

  bool get _isAdmin =>
      ServiceLocator.get<PermissionService>().isGroupAdmin(group.id);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSharingSection(),
        const SizedBox(height: AppDimensions.spacingL),
        const Divider(),
        const SizedBox(height: AppDimensions.spacingL),
        _buildManagementSection(),
      ],
    );
  }

  Widget _buildSharingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dela med gruppen',
          style:
              AppTextStyles.titleBold,
        ),
        const SizedBox(height: AppDimensions.spacingM),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShareRecipe,
                icon: const Icon(Icons.restaurant_menu),
                label: const Text('Dela recept'),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShareMenu,
                icon: const Icon(Icons.calendar_today),
                label: const Text('Dela meny'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onShareShoppingList,
            icon: const Icon(Icons.shopping_cart),
            label: const Text('Dela inkopslista'),
          ),
        ),
      ],
    );
  }

  Widget _buildManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hantera grupp',
          style:
              AppTextStyles.titleBold,
        ),
        const SizedBox(height: AppDimensions.spacingM),
        if (_isAdmin) ...[
          FilledButton.icon(
            onPressed: onEditGroup,
            icon: const Icon(Icons.edit),
            label: const Text('Redigera grupp'),
          ),
          const SizedBox(height: AppDimensions.spacingL),
          OutlinedButton.icon(
            onPressed: onDeleteGroup,
            icon: const Icon(Icons.delete),
            label: const Text('Ta bort grupp'),
            style: ComponentThemes.deleteButtonStyle,
          ),
        ] else
          OutlinedButton.icon(
            onPressed: onLeaveGroup,
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Lamna grupp'),
            style: ComponentThemes.outlinedButtonStyle,
          ),
      ],
    );
  }
}
