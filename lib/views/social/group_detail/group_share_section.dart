// lib/views/social/group_detail/group_share_section.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';

/// "Dela med gruppen": the three things a group can be handed, offered as a
/// sheet from the page's outlined share button.
abstract final class GroupShareSection {
  /// The same three choices as a sheet, for the page's outlined "Dela
  /// recept, meny eller lista". The sheet closes first, then the page acts.
  static Future<void> showSheet(
    BuildContext context, {
    required VoidCallback onShareRecipe,
    required VoidCallback onShareMenu,
    required VoidCallback onShareShoppingList,
  }) async {
    final l10n = context.l10n;
    final choice = await showButleryListSheet<String>(
      context,
      title: l10n.groupShareWithGroupSection,
      rows: (sheetContext) => [
        ButleryListRow(
          label: l10n.groupShareRecipeRow,
          leading: ButleryIcons.utensils,
          onTap: () => Navigator.of(sheetContext).pop('recipe'),
        ),
        ButleryListRow(
          label: l10n.groupShareMenuRow,
          leading: ButleryIcons.calendar,
          onTap: () => Navigator.of(sheetContext).pop('menu'),
        ),
        ButleryListRow(
          label: l10n.groupShareShoppingListRow,
          leading: ButleryIcons.shoppingCart,
          onTap: () => Navigator.of(sheetContext).pop('list'),
        ),
      ],
    );
    switch (choice) {
      case 'recipe':
        onShareRecipe();
      case 'menu':
        onShareMenu();
      case 'list':
        onShareShoppingList();
    }
  }
}
