import 'package:butlery/viewmodels/menu/week_template_viewmodel.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/menu/templates/week_template_preview_sheet.dart';
import 'package:butlery/widgets/menu/veckomeny_dialogs.dart';
import 'package:flutter/material.dart';

/// BUT-2522: the week menu's "Mallar och sparade menyer" sheet, with the
/// template actions wired to the calendar the view shows.
Future<void> showTemplatesAndSavedMenus(
  BuildContext context, {
  required MenuViewModel viewModel,
  required WeeklyMenuPlanViewModel calendar,
  ValueChanged<String>? onTemplateSelected,
}) {
  return VeckomenyDialogs.showLoadMenuBottomSheet(
    context,
    viewModel: viewModel,
    onTemplateSelected: onTemplateSelected,
    onUseWeekTemplate: (template) {
      final entries = template.templateEntries;
      if (entries == null || !context.mounted) return;
      showWeekTemplatePreview(
        context,
        calendar: calendar,
        name: template.name,
        entries: entries,
      );
    },
    onRenameWeekTemplate: (menuId, name) async {
      final vm = WeekTemplateViewModel.fromLocator(calendar);
      final ok = await vm.rename(menuId, name);
      vm.dispose();
      return ok;
    },
  );
}
