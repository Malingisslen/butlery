import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/menu/templates/week_template_save_dialog.dart';

/// "Spara veckan" under the personal calendar week, once the week has dishes.
/// A separate widget because the calendar widget is over the file limit.
class VeckomenySaveWeekButton extends StatelessWidget {
  const VeckomenySaveWeekButton({super.key});

  @override
  Widget build(BuildContext context) {
    final planVm = context.watch<WeeklyMenuPlanViewModel>();
    // Selection mode owns the taps on the calendar; a save then would race it.
    if (!planVm.hasEntries || planVm.selectionMode) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space16),
      child: ActionButtons.secondaryButton(
        context,
        key: const ValueKey('veckomeny-save-week'),
        label: context.l10n.weekTemplateSaveWeekButton,
        isExpanded: true,
        onPressed: () => showSaveWeekTemplateDialog(context, planVm),
      ),
    );
  }
}
