// lib/views/social/group_detail/group_share_section.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';

/// "Dela med gruppen": the three things a group can be handed.
class GroupShareSection extends StatelessWidget {
  const GroupShareSection({
    super.key,
    required this.onShareRecipe,
    required this.onShareMenu,
    required this.onShareShoppingList,
  });

  final VoidCallback onShareRecipe;
  final VoidCallback onShareMenu;
  final VoidCallback onShareShoppingList;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ButleryListSection(
      title: l10n.groupShareWithGroupSection,
      rows: [
        ButleryListRow(
          label: l10n.groupShareRecipeRow,
          leading: ButleryIcons.utensils,
          onTap: onShareRecipe,
        ),
        ButleryListRow(
          label: l10n.groupShareMenuRow,
          leading: ButleryIcons.calendar,
          onTap: onShareMenu,
        ),
        ButleryListRow(
          label: l10n.groupShareShoppingListRow,
          leading: ButleryIcons.shoppingCart,
          onTap: onShareShoppingList,
        ),
      ],
    );
  }
}
