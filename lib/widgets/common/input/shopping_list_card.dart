// lib/widgets/common/input/shopping_list_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/widgets/common/input/shopping_list_actions.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Shopping list card widget
/// This module provides display components for shopping lists including
/// cards, badges, and status indicators.
class ShoppingListCard extends StatelessWidget {
  final UnifiedShoppingList list;
  final UnifiedShoppingViewModel viewModel;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showActions;

  const ShoppingListCard({
    super.key,
    required this.list,
    required this.viewModel,
    required this.isSelected,
    this.onTap,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingXs,
      ),
      child: Material(
        elevation: AppDimensions.elevationMedium,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        color: isSelected
            ? cs.primary.withValues(alpha: AppDimensions.opacityVeryLight)
            : null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildListHeader(context),
                const SizedBox(height: AppDimensions.spacingM),
                _buildListMetadata(context),
                if (list.itemCount > 0) ...[
                  const SizedBox(height: AppDimensions.spacingM),
                  _buildListPreview(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build list header with name and actions
  Widget _buildListHeader(BuildContext context) {
    return Row(
      children: [
        // List icon
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacingXs),
          decoration: BoxDecoration(
            color: _getListTypeColor(context)
                .withValues(alpha: AppDimensions.opacityVeryLight),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          child: Icon(
            _getListTypeIcon(),
            size: AppDimensions.iconSizeAction,
            color: _getListTypeColor(context),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingM),

        // List name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                list.name,
                style: isSelected
                    ? AppTextStyles.titleBold
                    : AppTextStyles.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (list.description?.isNotEmpty == true) ...[
                const SizedBox(height: AppDimensions.spacingXxs),
                Text(
                  list.description!,
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),

        // Actions menu
        if (showActions)
          ShoppingListActions.buildListActionsButton(
            context,
            list,
            viewModel,
          ),
      ],
    );
  }

  /// Build list metadata (items count, type, etc.)
  Widget _buildListMetadata(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: AppDimensions.spacingS,
      runSpacing: AppDimensions.spacingXs,
      children: [
        // Items count
        _buildMetadataBadge(
          context,
          Icons.shopping_cart,
          '${list.itemCount} ${context.l10n.shoppingItems}',
          cs.onSurfaceVariant,
        ),

        // List type
        _buildMetadataBadge(
          context,
          _getListTypeIcon(),
          _getListTypeLabel(context),
          _getListTypeColor(context),
        ),

        // Collaboration info
        if (list.isCollaborative) ...[
          _buildMetadataBadge(
            context,
            Icons.people,
            context.l10n.friendMemberCount(list.memberCount),
            cs.primary,
          ),
          // User permission badge
          ..._buildUserPermissionBadge(context),
        ],

        // Recent activity
        if (list.hasRecentActivity) ...[
          _buildMetadataBadge(
            context,
            Icons.access_time,
            context.l10n.shoppingActive,
            context.butleryColors.warning,
          ),
        ],
      ],
    );
  }

  /// Build list preview showing first few items
  Widget _buildListPreview(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final previewItems = list.items.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingS),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.shoppingRecentItems,
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          ...previewItems.map((item) => Padding(
                padding:
                    const EdgeInsets.only(bottom: AppDimensions.spacingXxs),
                child: Row(
                  children: [
                    Icon(
                      item.isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: AppDimensions.iconSizeM,
                      color: item.isCompleted
                          ? context.butleryColors.success
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Expanded(
                      child: Text(
                        item.name,
                        style: AppTextStyles.bodySmall.copyWith(
                          decoration: item.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
          if (list.itemCount > 3) ...[
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              context.l10n.shoppingAndMore(list.itemCount - 3),
              style: AppTextStyles.bodySmall.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build metadata badge
  Widget _buildMetadataBadge(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingXs,
        vertical: AppDimensions.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppDimensions.iconSizeM,
            color: color,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Get list type icon
  IconData _getListTypeIcon() {
    switch (list.type) {
      case ShoppingListType.personal:
        return Icons.person;
      case ShoppingListType.collaborative:
        return Icons.people;
      case ShoppingListType.template:
        return Icons.bookmark;
    }
  }

  /// Get list type label
  String _getListTypeLabel(BuildContext context) {
    switch (list.type) {
      case ShoppingListType.personal:
        return context.l10n.shoppingPersonal;
      case ShoppingListType.collaborative:
        return context.l10n.shoppingShared;
      case ShoppingListType.template:
        return context.l10n.shoppingTemplate;
    }
  }

  /// Get list type color
  Color _getListTypeColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (list.type) {
      case ShoppingListType.personal:
        return cs.primary;
      case ShoppingListType.collaborative:
        return cs.primary;
      case ShoppingListType.template:
        return context.butleryColors.warning;
    }
  }

  /// Build user permission badge for collaborative lists
  List<Widget> _buildUserPermissionBadge(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!list.isCollaborative) return [];

    final permissionService = ServiceLocator.get<PermissionService>();
    final currentUserId = permissionService.currentUser?.uid;
    if (currentUserId == null) return [];

    final isOwner = list.ownerId == currentUserId;
    final userPermission = list.memberPermissions[currentUserId];

    String permissionLabel;
    IconData permissionIcon;
    Color permissionColor;

    if (isOwner) {
      permissionLabel = context.l10n.shoppingOwner;
      permissionIcon = Icons.admin_panel_settings;
      permissionColor = cs.primary;
    } else {
      switch (userPermission) {
        case SharedListPermission.view:
          permissionLabel = context.l10n.shoppingCanView;
          permissionIcon = Icons.visibility;
          permissionColor = context.butleryColors.warning;
          break;
        case SharedListPermission.edit:
          permissionLabel = context.l10n.shoppingCanEdit;
          permissionIcon = Icons.edit;
          permissionColor = context.butleryColors.success;
          break;
        case SharedListPermission.admin:
          permissionLabel = context.l10n.shoppingAdmin;
          permissionIcon = Icons.admin_panel_settings;
          permissionColor = cs.primary;
          break;
        default:
          permissionLabel = context.l10n.shoppingCanEdit;
          permissionIcon = Icons.edit;
          permissionColor = context.butleryColors.success;
      }
    }

    return [
      _buildMetadataBadge(
        context,
        permissionIcon,
        permissionLabel,
        permissionColor,
      ),
    ];
  }
}

/// Empty state widget for when no lists are available
class ShoppingListEmptyState extends StatelessWidget {
  final VoidCallback? onCreateList;

  const ShoppingListEmptyState({
    super.key,
    this.onCreateList,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: AppDimensions.iconSizeXxl,
            color: cs.outline,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            context.l10n.shoppingCreateFirstList,
            style: AppTextStyles.titleLarge.copyWith(
              color: cs.outline,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            context.l10n.shoppingCreateFirstListDescription,
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (onCreateList != null) ...[
            const SizedBox(height: AppDimensions.spacingXl),
            ActionButtons.primaryButton(
              context,
              label: context.l10n.shoppingCreateList,
              icon: Icons.add,
              onPressed: onCreateList!,
            ),
          ],
        ],
      ),
    );
  }
}
