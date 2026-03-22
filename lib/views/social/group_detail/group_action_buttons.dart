// lib/views/social/group_detail/group_action_buttons.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Builds action buttons for group detail view.
class GroupActionButtons extends StatelessWidget {
  final FriendCategory group;
  final bool isAdmin;
  final VoidCallback onShareRecipe;
  final VoidCallback onShareMenu;
  final VoidCallback onShareShoppingList;
  final VoidCallback onEditGroup;
  final VoidCallback onDeleteGroup;
  final VoidCallback onLeaveGroup;

  const GroupActionButtons({
    super.key,
    required this.group,
    required this.isAdmin,
    required this.onShareRecipe,
    required this.onShareMenu,
    required this.onShareShoppingList,
    required this.onEditGroup,
    required this.onDeleteGroup,
    required this.onLeaveGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSharingSection(context),
        const SizedBox(height: AppDimensions.spacingL),
        const Divider(),
        const SizedBox(height: AppDimensions.spacingL),
        _buildManagementSection(context),
      ],
    );
  }

  Widget _buildSharingSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.groupShareWithGroup,
          style: AppTextStyles.titleBold,
        ),
        const SizedBox(height: AppDimensions.spacingM),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShareRecipe,
                icon: const Icon(Icons.restaurant_menu),
                label: Text(context.l10n.groupShareRecipe),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShareMenu,
                icon: const Icon(Icons.calendar_today),
                label: Text(context.l10n.groupShareMenu),
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
            label: Text(context.l10n.groupShareShoppingList),
          ),
        ),
      ],
    );
  }

  Widget _buildManagementSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.groupManageGroup,
          style: AppTextStyles.titleBold,
        ),
        const SizedBox(height: AppDimensions.spacingM),
        if (isAdmin) ...[
          FilledButton.icon(
            onPressed: onEditGroup,
            icon: const Icon(Icons.edit),
            label: Text(context.l10n.groupEditGroup),
          ),
          const SizedBox(height: AppDimensions.spacingL),
          OutlinedButton.icon(
            onPressed: onDeleteGroup,
            icon: const Icon(Icons.delete),
            label: Text(context.l10n.groupDeleteGroup),
            style: ComponentThemes.deleteButtonStyle(
                Theme.of(context).colorScheme),
          ),
        ] else
          OutlinedButton.icon(
            onPressed: onLeaveGroup,
            icon: const Icon(Icons.exit_to_app),
            label: Text(context.l10n.groupLeaveGroup),
            style: ComponentThemes.outlinedButtonStyle(
                Theme.of(context).colorScheme),
          ),
      ],
    );
  }
}
