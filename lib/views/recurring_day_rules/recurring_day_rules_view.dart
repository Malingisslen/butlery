// BUT-2490: "Fasta dagar", the saved weekly rules of the week menu.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/recurring_day_rules/recurring_day_rule_store.dart';
import 'package:butlery/viewmodels/recurring_day_rules_viewmodel.dart';
import 'package:butlery/views/recurring_day_rules/recurring_day_rule_editor_view.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
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
  const RecurringDayRulesView({
    this.scope = const RecurringRuleScope.personal(),
    super.key,
  });

  /// Whose rules: the signed-in user's own, or a group's.
  final RecurringRuleScope scope;

  @override
  State<RecurringDayRulesView> createState() => _RecurringDayRulesViewState();
}

class _RecurringDayRulesViewState extends State<RecurringDayRulesView> {
  late final RecurringDayRulesViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = RecurringDayRulesViewModel(store: widget.scope.createStore());
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
      child: _RecurringDayRulesContent(scope: widget.scope),
    );
  }
}

class _RecurringDayRulesContent extends StatelessWidget {
  const _RecurringDayRulesContent({required this.scope});

  final RecurringRuleScope scope;

  // The editor shares this list's model: a group's rules are read live, and an
  // editor with its own empty copy would save over them.
  void _openEditor(
    BuildContext context,
    RecurringDayRulesViewModel vm, {
    DayOfWeek? day,
  }) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => RecurringDayRuleEditorView(
            initialDay: day,
            scope: scope,
            viewModel: vm,
          ),
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
    final canEdit = vm.canEdit;
    final group = scope.isGroup;
    return ButleryPage.undersida(
      title: group
          ? l.recurringRulesGroupTitle(scope.groupName.orEmpty())
          : l.recurringRulesTitle,
      body: rules.isEmpty
          ? StateWidget.empty(
              title: l.recurringRulesEmptyTitle,
              subtitle: !group
                  ? l.recurringRulesEmptyBody
                  : canEdit
                  ? l.recurringRulesGroupEmptyBodyAdmin
                  : l.recurringRulesGroupEmptyBodyMember,
              actionLabel: canEdit ? l.recurringRulesNew : null,
              onAction: canEdit ? () => _openEditor(context, vm) : null,
            )
          : ListView(
              padding: ButleryPageBody.margin(
                context,
                bottom: AppDimensions.space24,
              ),
              children: [
                ButleryListSection(
                  title: group
                      ? l.recurringRulesGroupSection
                      : l.recurringRulesSection,
                  rows: [
                    for (final rule in rules)
                      canEdit
                          ? _editableRow(context, vm, rule)
                          : _readOnlyRow(context, rule),
                  ],
                ),
                const SizedBox(height: AppDimensions.space16),
                if (canEdit) ...[
                  FormButton(
                    label: l.recurringRulesNew,
                    expand: true,
                    onPressed: () => _openEditor(context, vm),
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  Text(
                    l.recurringRulesHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else
                  _MemberInfo(text: l.recurringRulesGroupMemberInfo),
              ],
            ),
    );
  }

  // A member reads the rules: no switch, no swipe, and a paused rule says so.
  Widget _readOnlyRow(BuildContext context, RecurringDayRule rule) {
    final subtitle = recurringRuleSubtitle(context, rule);
    return ButleryListRow.info(
      key: ValueKey('recurring-rule-${rule.id}'),
      label: recurringRuleTitle(context, rule),
      value: rule.isActive
          ? subtitle
          : '$subtitle · ${context.l10n.recurringRulePausedShort}',
    );
  }

  Widget _editableRow(
    BuildContext context,
    RecurringDayRulesViewModel vm,
    RecurringDayRule rule,
  ) {
    final l = context.l10n;
    return Dismissible(
      key: ValueKey('recurring-rule-${rule.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: AppDimensions.space16),
        child: Text(
          l.commonDelete,
          style: AppTextStyles.bodyBold.copyWith(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
      onDismissed: (_) => unawaited(_delete(context, vm, rule)),
      child: ButleryListRow.toggle(
        label: recurringRuleTitle(context, rule),
        subtitle: recurringRuleSubtitle(context, rule),
        checked: rule.isActive,
        onChanged: (active) async {
          final ok = await vm.setPaused(rule, !active);
          if (!ok && context.mounted) {
            SnackBarUtils.showFailure(context, what: vm.error!);
          }
        },
      ),
    );
  }
}

class _MemberInfo extends StatelessWidget {
  const _MemberInfo({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppDimensions.space8,
      children: [
        ButleryIcon(
          ButleryIcons.info,
          size: AppDimensions.iconSizeM,
          color: cs.onSurfaceVariant,
        ),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
