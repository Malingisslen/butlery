/// The Regler section of a tag's page: one row per rule and a last row that
/// adds one.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';

class TagDetailRulesSection extends StatelessWidget {
  final PersonalTag tag;
  final PersonalTagViewModel viewModel;
  final ValueChanged<PersonalTagRule> onEditRule;
  final ValueChanged<PersonalTagRule> onDeleteRule;
  final ValueChanged<PersonalTagRule> onToggleRule;
  final VoidCallback onAddRule;

  const TagDetailRulesSection({
    super.key,
    required this.tag,
    required this.viewModel,
    required this.onEditRule,
    required this.onDeleteRule,
    required this.onToggleRule,
    required this.onAddRule,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ButleryListSection(
      title: l10n.tagDetailRulesSection,
      rows: [
        for (final rule in tag.rules)
          ButleryListRow(
            key: ValueKey(rule.id),
            label: rule.name,
            subtitle: _subtitle(context, rule),
            value: rule.isEnabled
                ? l10n.tagDetailRuleStateOn
                : l10n.tagDetailRuleStateOff,
            // A rule can be switched, edited and deleted, so its row opens
            // a sheet of those instead of carrying only one of them.
            onTap: () => _openRuleSheet(context, rule),
          ),
        ButleryListRow(
          label: l10n.tagDetailAddRule,
          leading: ButleryIcons.plus,
          onTap: onAddRule,
        ),
      ],
    );
  }

  void _openRuleSheet(BuildContext context, PersonalTagRule rule) {
    final l10n = context.l10n;
    showButleryListSheet<void>(
      context,
      title: rule.name,
      rows: (sheetContext) => [
        ButleryListRow(
          label: rule.isEnabled
              ? l10n.tagDetailRuleDisable
              : l10n.tagDetailRuleEnable,
          onTap: () {
            Navigator.pop(sheetContext);
            onToggleRule(rule);
          },
        ),
        ButleryListRow(
          label: l10n.tagDetailRuleEdit,
          onTap: () {
            Navigator.pop(sheetContext);
            onEditRule(rule);
          },
        ),
        ButleryListRow.danger(
          label: l10n.tagDetailRuleDeleteAction,
          onTap: () {
            Navigator.pop(sheetContext);
            onDeleteRule(rule);
          },
        ),
      ],
    );
  }

  String _subtitle(BuildContext context, PersonalTagRule rule) {
    final summary = _conditionSummary(context, rule);
    if (viewModel.isLoadingRuleStats) return summary;
    return '$summary · ${context.l10n.tagDetailRuleMatches(viewModel.getRuleMatchCount(rule.id))}';
  }

  static String _conditionSummary(BuildContext context, PersonalTagRule rule) {
    if (rule.conditions.isEmpty) return context.l10n.tagDetailRuleNoConditions;

    final parts = rule.conditions.take(3).map((c) {
      final value = c.type.isNumeric
          ? c.numericValue.toString()
          : c.stringValue;
      return '${c.type.label} ${c.operator.label} "$value"';
    }).toList();

    final summary = parts.join(
      rule.matchMode == MatchMode.all
          ? context.l10n.tagDetailRuleOperatorAnd
          : context.l10n.tagDetailRuleOperatorOr,
    );

    if (rule.conditions.length > 3) {
      final count = rule.conditions.length - 3;
      return '$summary ${context.l10n.tagDetailRuleMoreConditions(count)}';
    }
    return summary;
  }
}
