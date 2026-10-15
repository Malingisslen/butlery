/// The automatic rules of a tag's page: a heading with its "+ Ny regel" link,
/// then one row per rule with its words, what it has tagged and a switch.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/widgets/common/input/butlery_switch.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';

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
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(child: SectionHeading(l10n.tagDetailRulesHeading)),
              ButleryTextButton(
                onPressed: onAddRule,
                label: l10n.tagDetailNewRule,
                tone: ButleryTextButtonTone.link,
              ),
            ],
          ),
        ),
        for (final rule in tag.rules)
          _RuleRow(
            key: ValueKey(rule.id),
            rule: rule,
            subtitle: _subtitle(context, rule),
            onToggle: () => onToggleRule(rule),
            // A rule can be edited and deleted, so its words open a sheet of
            // those; the switch beside them is the on/off.
            onOpen: () => _openRuleSheet(context, rule),
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
    return '$summary · ${context.l10n.tagDetailRuleTagged(viewModel.getRuleMatchCount(rule.id))}';
  }

  static String _conditionSummary(BuildContext context, PersonalTagRule rule) {
    final l10n = context.l10n;
    if (rule.conditions.isEmpty) return l10n.tagDetailRuleNoConditions;

    final parts = rule.conditions.take(3).map((c) {
      if (c.type.isNumeric) {
        final n = c.numericValue;
        return l10n.tagDetailRuleSummaryNumber(
          c.type.label,
          c.operator.label,
          n == n.roundToDouble() ? '${n.round()}' : '$n',
        );
      }
      return '${c.type.label} ${c.operator.label} "${c.stringValue}"';
    }).toList();

    final summary = parts.join(
      rule.matchMode == MatchMode.all
          ? l10n.tagDetailRuleOperatorAnd
          : l10n.tagDetailRuleOperatorOr,
    );

    if (rule.conditions.length > 3) {
      final count = rule.conditions.length - 3;
      return '$summary ${l10n.tagDetailRuleMoreConditions(count)}';
    }
    return summary;
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.rule,
    required this.subtitle,
    required this.onToggle,
    required this.onOpen,
    super.key,
  });

  final PersonalTagRule rule;
  final String subtitle;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              child: PressFill(
                surface: PressSurface.base,
                child: InkWell(
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.space16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.name,
                          style: AppTextStyles.bodySmallBold.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space4),
                        Text(
                          subtitle,
                          style: AppTextStyles.captionText.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.space8),
          Semantics(
            label: rule.name,
            child: ButlerySwitch(
              value: rule.isEnabled,
              onChanged: (_) => onToggle(),
            ),
          ),
        ],
      ),
    );
  }
}
