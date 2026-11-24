import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/views/recurring_day_rules/recurring_day_rules_view.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';
import 'package:butlery/widgets/menu/group_menu_entry_button.dart';

enum _RootAction { fixedDays, save, clear }

/// The week menu's root-bar actions: the group week keeps its icon (it is
/// reached from here and from the group chat, BUT-1971); what is done seldom
/// shares one overflow menu, so the title always has room.
List<Widget> buildVeckomenyRootActions(
  BuildContext context, {
  required MenuViewModel viewModel,
  required bool isLiveMenu,
  required VoidCallback onSave,
  required VoidCallback onClear,
}) {
  return [
    const GroupMenuEntryButton(),
    ButleryMenu<_RootAction>(
      key: const ValueKey('veckomeny-root-more'),
      semanticLabel: context.l10n.rootBarMoreActions,
      onSelected: (action) {
        switch (action) {
          case _RootAction.fixedDays:
            Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const RecurringDayRulesView()),
            );
          case _RootAction.save:
            onSave();
          case _RootAction.clear:
            onClear();
        }
      },
      choices: [
        // Rules shape the user's own week, never the shared one on screen.
        if (!isLiveMenu)
          ButleryMenuChoice<_RootAction>(
            value: _RootAction.fixedDays,
            icon: ButleryIcons.refreshCw,
            label: context.l10n.recurringRulesTitle,
          ),
        if (viewModel.hasMenu)
          ButleryMenuChoice<_RootAction>(
            value: _RootAction.save,
            icon: ButleryIcons.save,
            label: context.l10n.menuSave,
          ),
        // A clear would empty the menu for everyone it is shared with.
        if (viewModel.hasMenu && !isLiveMenu)
          ButleryMenuChoice<_RootAction>(
            value: _RootAction.clear,
            icon: ButleryIcons.x,
            label: context.l10n.menuClear,
          ),
      ],
    ),
  ];
}
