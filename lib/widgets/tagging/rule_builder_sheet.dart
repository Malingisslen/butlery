/// Bottom sheet for building or editing a personal tag automation rule.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/tagging/rule_condition_card.dart';

/// Bottom sheet that allows creating or editing a [PersonalTagRule].
///
/// Returns the created/edited rule via [Navigator.pop] or null if cancelled.
class RuleBuilderSheet extends StatefulWidget {
  final PersonalTag tag;
  final PersonalTagRule? existingRule;

  const RuleBuilderSheet({
    super.key,
    required this.tag,
    this.existingRule,
  });

  @override
  State<RuleBuilderSheet> createState() => _RuleBuilderSheetState();
}

class _RuleBuilderSheetState extends State<RuleBuilderSheet> {
  final _nameController = TextEditingController();
  MatchMode _matchMode = MatchMode.all;
  List<RuleCondition> _conditions = [];
  bool _isEnabled = true;

  bool get _isEditing => widget.existingRule != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingRule != null) {
      final rule = widget.existingRule!;
      _nameController.text = rule.name;
      _matchMode = rule.matchMode;
      _conditions = List.from(rule.conditions);
      _isEnabled = rule.isEnabled;
    } else {
      _conditions = [
        const RuleCondition(
          type: ConditionType.ingredient,
          operator: ConditionOperator.contains,
          value: '',
        ),
      ];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addCondition() {
    setState(() {
      _conditions.add(
        const RuleCondition(
          type: ConditionType.ingredient,
          operator: ConditionOperator.contains,
          value: '',
        ),
      );
    });
  }

  void _removeCondition(int index) {
    if (_conditions.length > 1) {
      setState(() {
        _conditions.removeAt(index);
      });
    }
  }

  void _updateCondition(
    int index, {
    ConditionType? type,
    ConditionOperator? operator,
    String? value,
  }) {
    setState(() {
      _conditions[index] = _conditions[index].copyWith(
        type: type,
        operator: operator,
        value: value,
      );
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      SnackBarUtils.showError(context, context.l10n.ruleNameRequired);
      return;
    }

    for (final condition in _conditions) {
      if (condition.type.isNumeric) {
        if (condition.numericValue == 0) {
          SnackBarUtils.showError(
            context,
            context.l10n.ruleAllConditionsNeedValue,
          );
          return;
        }
      } else {
        if (condition.stringValue.trim().isEmpty) {
          SnackBarUtils.showError(
            context,
            context.l10n.ruleAllConditionsNeedValue,
          );
          return;
        }
      }
    }

    PersonalTagRule rule;
    if (_isEditing) {
      rule = widget.existingRule!.copyWith(
        name: name,
        conditions: _conditions,
        matchMode: _matchMode,
        isEnabled: _isEnabled,
      );
    } else {
      rule = PersonalTagRule.create(
        tagId: widget.tag.id,
        name: name,
        conditions: _conditions,
        matchMode: _matchMode,
        isEnabled: _isEnabled,
      );
    }

    Navigator.of(context).pop(rule);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.borderRadiusM),
            ),
          ),
          child: Column(
            children: [
              _buildHandleBar(colorScheme),
              _buildHeader(),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppDimensions.spacingLg),
                  children: [
                    _buildNameField(),
                    const SizedBox(height: AppDimensions.spacingLg),
                    _buildMatchModeSelector(),
                    const SizedBox(height: AppDimensions.spacingLg),
                    _buildConditionsHeader(),
                    const SizedBox(height: AppDimensions.spacingSm),
                    _buildConditionsList(),
                    const SizedBox(height: AppDimensions.spacingLg),
                    _buildEnabledSwitch(),
                    const SizedBox(height: AppDimensions.spacingXxl),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandleBar(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(top: AppDimensions.paddingM),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: colorScheme.onSurfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingLg),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _isEditing
                  ? context.l10n.ruleEditTitle
                  : context.l10n.ruleNewTitle,
              style: AppTextStyles.titleLarge,
            ),
          ),
          Flexible(
            fit: FlexFit.loose,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonCancel),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Flexible(
            fit: FlexFit.loose,
            child: FilledButton(
              onPressed: _save,
              child: Text(
                _isEditing
                    ? context.l10n.commonSave
                    : context.l10n.commonCreate,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: context.l10n.ruleNameLabel,
        hintText: context.l10n.ruleNameHint,
        border: const OutlineInputBorder(),
      ),
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildMatchModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.ruleMatchModeLabel, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppDimensions.spacingSm),
        SegmentedButton<MatchMode>(
          segments: [
            ButtonSegment(
              value: MatchMode.all,
              label: Text(context.l10n.ruleMatchModeAllShort),
            ),
            ButtonSegment(
              value: MatchMode.any,
              label: Text(context.l10n.ruleMatchModeAnyShort),
            ),
          ],
          selected: {_matchMode},
          onSelectionChanged: (selection) {
            setState(() => _matchMode = selection.first);
          },
        ),
      ],
    );
  }

  Widget _buildConditionsHeader() {
    return Row(
      children: [
        Text(context.l10n.ruleConditionsLabel, style: AppTextStyles.labelLarge),
        const Spacer(),
        Flexible(
          fit: FlexFit.loose,
          child: TextButton.icon(
            onPressed: _addCondition,
            icon: const Icon(Icons.add, size: AppDimensions.iconSize18),
            label: Text(context.l10n.commonAdd),
          ),
        ),
      ],
    );
  }

  Widget _buildConditionsList() {
    return Column(
      children: List.generate(_conditions.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
          child: RuleConditionCard(
            key: ValueKey('condition_$index'),
            condition: _conditions[index],
            canDelete: _conditions.length > 1,
            onTypeChanged: (type) => _updateCondition(index, type: type),
            onOperatorChanged: (op) => _updateCondition(index, operator: op),
            onValueChanged: (value) => _updateCondition(index, value: value),
            onDelete: () => _removeCondition(index),
          ),
        );
      }),
    );
  }

  Widget _buildEnabledSwitch() {
    return SwitchListTile(
      value: _isEnabled,
      onChanged: (value) => setState(() => _isEnabled = value),
      title: Text(context.l10n.ruleEnabledTitle),
      subtitle: Text(
        _isEnabled
            ? context.l10n.ruleEnabledNewRecipes
            : context.l10n.rulePausedSubtitle,
        style: AppTextStyles.bodySmall,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}
