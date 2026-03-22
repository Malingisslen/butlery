/// Card widget for editing a single rule condition within the rule builder.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/services/tagging/config/operator_registry.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Editable card for a single rule condition with type, operator, and value fields.
class RuleConditionCard extends StatefulWidget {
  final RuleCondition condition;
  final bool canDelete;
  final ValueChanged<ConditionType> onTypeChanged;
  final ValueChanged<ConditionOperator> onOperatorChanged;
  final ValueChanged<String> onValueChanged;
  final VoidCallback onDelete;

  const RuleConditionCard({
    super.key,
    required this.condition,
    required this.canDelete,
    required this.onTypeChanged,
    required this.onOperatorChanged,
    required this.onValueChanged,
    required this.onDelete,
  });

  @override
  State<RuleConditionCard> createState() => _RuleConditionCardState();
}

class _RuleConditionCardState extends State<RuleConditionCard> {
  late TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _valueController =
        TextEditingController(text: widget.condition.stringValue);
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final operators = OperatorRegistry.getValidOperators(widget.condition.type);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ConditionType>(
                    initialValue: widget.condition.type,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingM,
                        vertical: AppDimensions.paddingMs,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: ConditionType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child:
                            Text(type.label, style: AppTextStyles.formOption),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        widget.onTypeChanged(value);
                        final newOperators =
                            OperatorRegistry.getValidOperators(value);
                        if (!newOperators.contains(widget.condition.operator)) {
                          widget.onOperatorChanged(newOperators.first);
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: DropdownButtonFormField<ConditionOperator>(
                    initialValue: operators.contains(widget.condition.operator)
                        ? widget.condition.operator
                        : operators.first,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingM,
                        vertical: AppDimensions.paddingMs,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: operators.map((op) {
                      return DropdownMenuItem(
                        value: op,
                        child: Text(op.label, style: AppTextStyles.formOption),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) widget.onOperatorChanged(value);
                    },
                  ),
                ),
                if (widget.canDelete) ...[
                  const SizedBox(width: AppDimensions.spacingSm),
                  IconButton(
                    icon:
                        const Icon(Icons.close, size: AppDimensions.iconSizeM),
                    onPressed: widget.onDelete,
                    tooltip: context.l10n.ruleRemoveCondition,
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            TextField(
              controller: _valueController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingM,
                  vertical: AppDimensions.paddingM,
                ),
                hintText: _getHintText(widget.condition.type),
                border: const OutlineInputBorder(),
              ),
              keyboardType: widget.condition.type.isNumeric
                  ? TextInputType.number
                  : TextInputType.text,
              onChanged: widget.onValueChanged,
            ),
          ],
        ),
      ),
    );
  }

  String _getHintText(ConditionType type) {
    switch (type) {
      case ConditionType.ingredient:
        return context.l10n.ruleHintIngredient;
      case ConditionType.property:
        return context.l10n.ruleHintProperty;
      case ConditionType.keyword:
        return context.l10n.ruleHintKeyword;
      case ConditionType.sourceUrl:
        return context.l10n.ruleHintSourceUrl;
      case ConditionType.cuisine:
        return context.l10n.ruleHintCuisine;
      case ConditionType.dietary:
        return context.l10n.ruleHintDietary;
      case ConditionType.time:
        return context.l10n.ruleHintTimeShort;
      case ConditionType.rating:
        return context.l10n.ruleHintRating;
      case ConditionType.recency:
        return context.l10n.ruleHintRecencyShort;
      case ConditionType.ownership:
        return context.l10n.ruleHintOwnership;
      case ConditionType.hasImage:
        return context.l10n.ruleHintHasImage;
      case ConditionType.completeness:
        return context.l10n.ruleHintCompleteness;
    }
  }
}
