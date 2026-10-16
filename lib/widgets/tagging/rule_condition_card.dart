/// Card widget for editing a single rule condition within the rule builder.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/services/tagging/config/operator_registry.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/input/styled_input.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/cards/styled_card.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';

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
    _valueController = TextEditingController(
      text: widget.condition.stringValue,
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final operators = OperatorRegistry.getValidOperators(widget.condition.type);

    return StyledCard(
      padding: const EdgeInsets.all(AppDimensions.space16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ButleryDropdown<ConditionType>(
                  dense: true,
                  semanticLabel: context.l10n.ruleConditionsLabel,
                  value: widget.condition.type,
                  options: [
                    for (final type in ConditionType.values)
                      ButleryDropdownOption<ConditionType>(
                        value: type,
                        label: type.label,
                      ),
                  ],
                  onChanged: (value) {
                    widget.onTypeChanged(value);
                    final newOperators = OperatorRegistry.getValidOperators(
                      value,
                    );
                    if (!newOperators.contains(widget.condition.operator)) {
                      widget.onOperatorChanged(newOperators.first);
                    }
                  },
                ),
              ),
              const SizedBox(width: AppDimensions.space8),
              Expanded(
                child: ButleryDropdown<ConditionOperator>(
                  dense: true,
                  semanticLabel: context.l10n.ruleConditionsLabel,
                  value: operators.contains(widget.condition.operator)
                      ? widget.condition.operator
                      : operators.first,
                  options: [
                    for (final op in operators)
                      ButleryDropdownOption<ConditionOperator>(
                        value: op,
                        label: op.label,
                      ),
                  ],
                  onChanged: widget.onOperatorChanged,
                ),
              ),
              if (widget.canDelete) ...[
                const SizedBox(width: AppDimensions.space8),
                AppIconButton(
                  icon: ButleryIcons.x,
                  onPressed: widget.onDelete,
                  semanticLabel: context.l10n.ruleRemoveCondition,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppDimensions.space8),
          StyledInput(
            controller: _valueController,
            semanticLabel: _getHintText(widget.condition.type),
            hint: _getHintText(widget.condition.type),
            contentPadding: AppDimensions.paddingAll12,
            // A rating such as 4.5 must stay typeable.
            keyboardType: widget.condition.type.isNumeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            onChanged: widget.onValueChanged,
          ),
        ],
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
      case ConditionType.cookedRecency:
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
