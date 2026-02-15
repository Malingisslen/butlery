/// Tile widget displaying a single automation rule within the tag detail view.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Displays a rule with its status, condition summary, and match count.
class TagDetailRuleTile extends StatelessWidget {
  final PersonalTagRule rule;
  final int matchCount;
  final bool isLoadingStats;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TagDetailRuleTile({
    super.key,
    required this.rule,
    required this.matchCount,
    required this.isLoadingStats,
    required this.onToggleEnabled,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final conditionSummary = _buildConditionSummary(context, rule);

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
      child: ListTile(
        leading: Icon(
          rule.isEnabled ? Icons.check_circle : Icons.pause_circle,
          color: rule.isEnabled
              ? context.butleryColors.success
              : colorScheme.onSurfaceVariant,
        ),
        title: Text(rule.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conditionSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            if (isLoadingStats)
              Text(
                context.l10n.tagDetailRuleCalculating,
                style: AppTextStyles.bodySmall.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Text(
                context.l10n.tagDetailRuleMatches(matchCount),
                style: AppTextStyles.bodySmall.copyWith(
                  color: matchCount > 0
                      ? context.butleryColors.success
                      : colorScheme.onSurfaceVariant,
                  fontWeight:
                      matchCount > 0 ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: rule.isEnabled,
              onChanged: (_) => onToggleEnabled(rule.isEnabled),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: AppDimensions.iconSizeM),
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: const Icon(Icons.edit),
                    title: Text(context.l10n.commonEdit),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: colorScheme.error),
                    title: Text(context.l10n.commonDelete,
                        style: TextStyle(color: colorScheme.error)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        onEdit();
      case 'delete':
        onDelete();
    }
  }

  static String _buildConditionSummary(
      BuildContext context, PersonalTagRule rule) {
    if (rule.conditions.isEmpty) return context.l10n.tagDetailRuleNoConditions;

    final parts = rule.conditions.take(3).map((c) {
      final type = c.type.label;
      final op = c.operator.label;
      final value =
          c.type.isNumeric ? c.numericValue.toString() : c.stringValue;
      return '$type $op "$value"';
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
