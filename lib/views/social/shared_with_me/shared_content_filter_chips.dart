// lib/views/social/shared_with_me/shared_content_filter_chips.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/search_filter/quick_filter_chips.dart';

enum SharedContentFilter { all, recipes, menus, shoppingLists }

/// Single-select chips over the shared content kinds; "Allt" is the default.
class SharedContentFilterChips extends StatelessWidget {
  const SharedContentFilterChips({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final SharedContentFilter selected;
  final ValueChanged<SharedContentFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      SharedContentFilter.recipes: l10n.profileRecipes,
      SharedContentFilter.menus: l10n.profileMenus,
      SharedContentFilter.shoppingLists: l10n.shoppingLists,
    };
    return QuickFilterChips(
      allOptionLabel: l10n.feedFilterAll,
      options: [
        for (final entry in labels.entries)
          QuickFilterOption(id: entry.key.name, label: entry.value),
      ],
      selectedIds: selected == SharedContentFilter.all
          ? const {}
          : {selected.name},
      onFilterToggle: (id) {
        final tapped = SharedContentFilter.values.byName(id);
        onSelected(tapped == selected ? SharedContentFilter.all : tapped);
      },
    );
  }
}
