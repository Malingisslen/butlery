// lib/views/unified_shopping/widgets/shopping_list_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_shadows.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';

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
    bool showListPicker = true,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space16),
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
        showListPicker,
      ),
    );
  }

  static Widget _buildListSelector(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    VoidCallback onRenameList,
    VoidCallback onDeleteList,
    VoidCallback? onConvertList,
    bool showListPicker,
  ) {
    final cs = Theme.of(context).colorScheme;

    // BUT-723: beside the tablet's list of lists the picker would say the
    // same thing twice, so only the list's own buttons stay.
    final picker = showListPicker
        ? ButleryDropdown<String>(
            semanticLabel: context.l10n.shoppingSelectList,
            hint: context.l10n.shoppingSelectList,
            value: viewModel.activeList?.id,
            closedShowsSubtitle: true,
            options: [
              for (final list in viewModel.lists) _listOption(context, list),
            ],
            onChanged: viewModel.setActiveList,
          )
        : null;

    // Management buttons (only show if there's an active list)
    final buttons = <Widget>[
      if (viewModel.activeList != null) ...[
        ButleryOutlinedBox(
          paintOnly: true,
          color: cs.surface,
          borderColor: cs.outlineVariant,
          child: AppIconButton(
            icon: ButleryIcons.pencil,
            onPressed: onRenameList,
            semanticLabel: context.l10n.shoppingRenameList,
            // text.primary itself, never faded.
            color: cs.onSurface,
            iconSize: AppDimensions.iconSizeM,
          ),
        ),

        // Convert button - show when user owns the list
        if (onConvertList != null)
          ButleryOutlinedBox(
            paintOnly: true,
            color: cs.surface,
            borderColor: cs.outlineVariant,
            radius: AppDimensions.radiusCard,
            child: AppIconButton(
              icon: ButleryIcons.swapHorizontal,
              onPressed: onConvertList,
              semanticLabel: viewModel.activeList?.isPersonal == true
                  ? context.l10n.shoppingConvertToCollaborative
                  : context.l10n.shoppingConvertToPersonal,
              color: cs.onSurface,
              iconSize: AppDimensions.iconSizeM,
            ),
          ),

        ButleryOutlinedBox(
          paintOnly: true,
          color: cs.surface,
          borderColor: cs.outlineVariant,
          child: AppIconButton(
            icon: ButleryIcons.trash2,
            onPressed: onDeleteList,
            semanticLabel: context.l10n.shoppingDeleteList,
            // text.primary itself, never faded.
            color: cs.onSurface,
            iconSize: AppDimensions.iconSizeM,
          ),
        ),
      ],
    ];

    // Large text: the picker keeps the whole width and the buttons sit under
    // it, so the list's name is not broken in a column beside three buttons.
    if (isLargeText(context) && picker != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppDimensions.space4,
        children: [
          picker,
          if (buttons.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: AppDimensions.space4,
              children: buttons,
            ),
        ],
      );
    }
    return Row(
      spacing: AppDimensions.space4,
      children: [
        if (picker == null) const Spacer() else Expanded(child: picker),
        ...buttons,
      ],
    );
  }

  /// Build enhanced dropdown item with sharing status indicators
  static ButleryDropdownOption<String> _listOption(
    BuildContext context,
    UnifiedShoppingList list,
  ) {
    final cs = Theme.of(context).colorScheme;
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

    return ButleryDropdownOption<String>(
      value: list.id,
      label: list.name,
      icon: sharingIcon,
      iconColor: sharingColor,
      subtitle: context.l10n.shoppingItemCount(list.items.length),
      subtitleSuffix: permissionText,
      subtitleSuffixColor: permissionTextColor ?? sharingColor,
    );
  }
}
