// BUT-2490: "Fasta dagar", the saved weekly rules of the week menu.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/recurring_day_rules_viewmodel.dart';
import 'package:butlery/views/recurring_day_rules/recurring_day_rule_editor_view.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// The row title "Måndag · middag"; shared by the list and the editor.
String recurringRuleTitle(BuildContext context, RecurringDayRule rule) =>
    '${context.l10n.recurringRuleDayLong(rule.day.name)}'
    ' · ${rule.meal.displayLabel}';

/// "Fisk", "Snabbt (under 30 min)" or "Fisk · snabbt".
String recurringRuleSubtitle(BuildContext context, RecurringDayRule rule) {
  final l = context.l10n;
  final food = rule.food;
  if (food == null) return l.recurringRuleQuickLabel;
  final name = l.recurringRuleFoodLabel(food.name);
  return rule.quick
      ? '$name · ${l.recurringRuleQuickShort.toLowerCase()}'
      : name;
}

class RecurringDayRulesView extends StatefulWidget {
  const RecurringDayRulesView({super.key});

  @override
  State<RecurringDayRulesView> createState() => _RecurringDayRulesViewState();
}

class _RecurringDayRulesViewState extends State<RecurringDayRulesView> {
  late final RecurringDayRulesViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = RecurringDayRulesViewModel();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RecurringDayRulesViewModel>.value(
      value: _vm,
      child: const _RecurringDayRulesContent(),
    );
  }
}

class _RecurringDayRulesContent extends StatelessWidget {
  const _RecurringDayRulesContent();

  void _openEditor(BuildContext context, {DayOfWeek? day}) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => RecurringDayRuleEditorView(initialDay: day),
        ),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    RecurringDayRulesViewModel vm,
    RecurringDayRule rule,
  ) async {
    final ok = await vm.delete(rule);
    if (!context.mounted) return;
    if (!ok) {
      SnackBarUtils.showFailure(context, what: vm.error!);
      return;
    }
    SnackBarUtils.showUndo(
      context,
      context.l10n.recurringRuleDeleted,
      onUndo: () => unawaited(vm.save(rule)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecurringDayRulesViewModel>();
    final l = context.l10n;
    final rules = vm.rules;
    return ButleryPage.undersida(
      title: l.recurringRulesTitle,
      body: rules.isEmpty
          ? StateWidget.empty(
              title: l.recurringRulesEmptyTitle,
              subtitle: l.recurringRulesEmptyBody,
              actionLabel: l.recurringRulesNew,
              onAction: () => _openEditor(context),
            )
          : ListView(
              padding: ButleryPageBody.margin(
                context,
                bottom: AppDimensions.space24,
              ),
              children: [
                ButleryListSection(
                  title: l.recurringRulesSection,
                  rows: [
                    for (final rule in rules)
                      Dismissible(
                        key: ValueKey('recurring-rule-${rule.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Theme.of(context).colorScheme.errorContainer,
                          alignment: AlignmentDirectional.centerEnd,
                          padding: const EdgeInsetsDirectional.only(
                            end: AppDimensions.space16,
                          ),
                          child: Text(
                            l.commonDelete,
                            style: AppTextStyles.bodyBold.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        onDismissed: (_) =>
                            unawaited(_delete(context, vm, rule)),
                        child: ButleryListRow.toggle(
                          label: recurringRuleTitle(context, rule),
                          subtitle: recurringRuleSubtitle(context, rule),
                          checked: rule.isActive,
                          onChanged: (active) async {
                            final ok = await vm.setPaused(rule, !active);
                            if (!ok && context.mounted) {
                              SnackBarUtils.showFailure(
                                context,
                                what: vm.error!,
                              );
                            }
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space16),
                FormButton(
                  label: l.recurringRulesNew,
                  expand: true,
                  onPressed: () => _openEditor(context),
                ),
                const SizedBox(height: AppDimensions.space12),
                Text(
                  l.recurringRulesHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}
