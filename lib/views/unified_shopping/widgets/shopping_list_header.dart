// lib/views/unified_shopping/widgets/shopping_list_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_shadows.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// Header section with the list selector and its management buttons.
///
/// The list's secondary actions (sort categories, uncheck all) live in the
/// root bar's overflow menu (Skarmar v12 del 2 #inkop :862-870 draws only
/// "mer" + "plus" in the header — see [ShoppingAppBar.buildHeaderActions]).
class ShoppingListHeader {
  static Widget build(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    VoidCallback onRenameList,
    VoidCallback onDeleteList, {
    VoidCallback? onConvertList,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        boxShadow: AppShadows.subtle,
      ),
      child: _buildListSelector(
        context,
        viewModel,
        onRenameList,
        onDeleteList,
        onConvertList,
      ),
    );
  }

  static Widget _buildListSelector(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    VoidCallback onRenameList,
    VoidCallback onDeleteList,
    VoidCallback? onConvertList,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        // Dropdown container
        Expanded(
          child: Container(
            padding: AppDimensions.paddingSymmetric16x12,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: DropdownButtonHideUnderline(
              child: PressFill(
                surface: PressSurface.base,
                child: DropdownButton<String>(
                  iconEnabledColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  iconDisabledColor: AppModeColors.textDisabled(
                    Theme.of(context).brightness,
                  ),
                  value: viewModel.activeList?.id,
                  hint: Text(context.l10n.shoppingSelectList),
                  isExpanded: true,
                  // The list's name over its item count grows with the text
                  // size, so the button takes its content's height.
                  itemHeight: null,
                  icon: const ButleryIcon(ButleryIcons.chevronDown),
                  onChanged: (listId) {
                    if (listId != null) {
                      viewModel.setActiveList(listId);
                    }
                  },
                  items: viewModel.lists.map((list) {
                    return DropdownMenuItem<String>(
                      value: list.id,
                      child: _buildListDropdownItem(context, list),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),

        // Management buttons (only show if there's an active list)
        if (viewModel.activeList != null) ...[
          const SizedBox(width: AppDimensions.space4),

          // Rename button
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: AppIconButton(
              icon: ButleryIcons.pencil,
              onPressed: onRenameList,
              semanticLabel: context.l10n.shoppingRenameList,
              // text.primary itself, never faded (tokens.json:40-53).
              color: cs.onSurface,
              iconSize: AppDimensions.iconSizeAction,
            ),
          ),

          // Convert button - show when user owns the list
          if (onConvertList != null) ...[
            const SizedBox(width: AppDimensions.spacingXs),
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(
                  AppDimensions.radiusCard,
                ),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: AppIconButton(
                icon: ButleryIcons.swapHorizontal,
                onPressed: onConvertList,
                semanticLabel: viewModel.activeList?.isPersonal == true
                    ? context.l10n.shoppingConvertToCollaborative
                    : context.l10n.shoppingConvertToPersonal,
                color: cs.onSurface,
                iconSize: AppDimensions.iconSizeAction,
              ),
            ),
          ],

          const SizedBox(width: AppDimensions.spacingXs),

          // Delete button
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: AppIconButton(
              icon: ButleryIcons.trash2,
              onPressed: onDeleteList,
              semanticLabel: context.l10n.shoppingDeleteList,
              // text.primary itself, never faded (tokens.json:40-53).
              color: cs.onSurface,
              iconSize: AppDimensions.iconSizeAction,
            ),
          ),
        ],
      ],
    );
  }

  /// Build enhanced dropdown item with sharing status indicators
  static Widget _buildListDropdownItem(
    BuildContext context,
    UnifiedShoppingList list,
  ) {
    final cs = Theme.of(context).colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1;
    final permissionService = ServiceLocator.get<PermissionService>();
    final currentUserId = permissionService.currentUser?.uid;

    // Get sharing status
    IconData sharingIcon;
    Color sharingColor;
    Color? permissionTextColor;
    String? permissionText;

    switch (list.type) {
      case ListType.personal:
        sharingIcon = ButleryIcons.user;
        sharingColor = cs.onSurface;
        break;
      case ListType.collaborative:
        if (currentUserId != null) {
          final isOwner = list.ownerId == currentUserId;
          final userPermission = list.memberPermissions[currentUserId];

          if (isOwner) {
            sharingIcon = ButleryIcons.crown;
            sharingColor = cs.onSurface;
            permissionText = context.l10n.shoppingPermissionOwner;
          } else {
            switch (userPermission) {
              case SharedListPermission.view:
                sharingIcon = ButleryIcons.eye;
                sharingColor = cs.onSurfaceVariant;
                permissionText = context.l10n.shoppingPermissionView;
                break;
              case SharedListPermission.edit:
                sharingIcon = ButleryIcons.pencil;
                sharingColor = cs.secondary;
                permissionTextColor = context.modeColors.textAccent;
                permissionText = context.l10n.shoppingPermissionEdit;
                break;
              case SharedListPermission.admin:
                sharingIcon = ButleryIcons.crown;
                sharingColor = cs.onSurface;
                permissionText = context.l10n.shoppingPermissionAdmin;
                break;
              default:
                sharingIcon = ButleryIcons.users;
                sharingColor = cs.onSurface;
                permissionText = context.l10n.shoppingPermissionShared;
            }
          }
        } else {
          sharingIcon = ButleryIcons.users;
          sharingColor = cs.tertiary;
          permissionText = context.l10n.shoppingPermissionShared;
        }
        break;
      case ListType.template:
        sharingIcon = ButleryIcons.savedTemplate;
        sharingColor = cs.onSurfaceVariant;
        permissionText = context.l10n.shoppingPermissionTemplate;
        break;
    }

    return Row(
      children: [
        ButleryIcon(
          sharingIcon,
          size: AppDimensions.iconSizeM,
          color: sharingColor,
        ),
        const SizedBox(width: AppDimensions.space4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // BUT-2193 (Malin, 2026-10-03): cut at the normal text size.
              Text(
                list.name,
                style: AppTextStyles.contentLabel,
                maxLines: largeText ? null : 1,
                overflow: largeText ? null : TextOverflow.ellipsis,
              ),
              Wrap(
                children: [
                  Text(
                    context.l10n.shoppingItemCount(list.items.length),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  if (permissionText != null) ...[
                    Text(
                      ' • $permissionText',
                      style: AppTextStyles.metadataEmphasized.copyWith(
                        color: permissionTextColor ?? sharingColor,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
