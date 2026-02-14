/// Rules section for the tag detail view showing automation rules.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/tagging/tag_detail_rule_tile.dart';

/// Displays the automation rules section with header, empty state, and rule list.
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
    final colorScheme = Theme.of(context).colorScheme;
    final rules = tag.rules;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context),
        const SizedBox(height: AppDimensions.spacingSm),
        Text(
          context.l10n.tagDetailRulesDescription,
          style: AppTextStyles.bodySmall.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        if (rules.isEmpty)
          _buildEmptyState(context)
        else
          ...rules.map((rule) => _buildRuleTile(rule)),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.auto_awesome, size: AppDimensions.iconSizeM),
        const SizedBox(width: AppDimensions.spacingSm),
        Expanded(
          child: Text(
            context.l10n.tagDetailRulesTitle,
            style: AppTextStyles.titleMedium,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        Flexible(
          fit: FlexFit.loose,
          child: FilledButton.tonalIcon(
            onPressed: onAddRule,
            icon: const Icon(Icons.add, size: AppDimensions.iconSize18),
            label: Text(context.l10n.commonAdd),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingXl),
        child: Column(
          children: [
            const Icon(Icons.rule, size: 48),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              context.l10n.tagDetailRulesEmptyTitle,
              style: AppTextStyles.titleMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              context.l10n.tagDetailRulesEmptySubtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            OutlinedButton.icon(
              onPressed: onAddRule,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.tagDetailRulesCreateFirst),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleTile(PersonalTagRule rule) {
    return TagDetailRuleTile(
      key: ValueKey(rule.id),
      rule: rule,
      matchCount: viewModel.getRuleMatchCount(rule.id),
      isLoadingStats: viewModel.isLoadingRuleStats,
      onToggleEnabled: (_) => onToggleRule(rule),
      onTap: () => onEditRule(rule),
      onEdit: () => onEditRule(rule),
      onDelete: () => onDeleteRule(rule),
    );
  }
}
