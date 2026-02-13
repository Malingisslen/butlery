import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/tagging/config/operator_registry.dart';
import 'package:butlery/services/tagging/config/property_registry.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Result from rule dialog including apply to existing choice.
class PersonalTagRuleResult {
  final PersonalTagRule rule;
  final bool applyToExisting;

  const PersonalTagRuleResult({
    required this.rule,
    this.applyToExisting = false,
  });
}

/// Dialog for creating or editing a personal tag rule.
///
/// Rules automatically apply tags to recipes based on conditions.
class PersonalTagRuleDialog extends StatefulWidget {
  /// Existing rule to edit, or null for creating a new rule.
  final PersonalTagRule? existingRule;

  /// Available tags to choose from.
  final List<PersonalTag> availableTags;

  /// Pre-selected tag ID (for creating rule from tag context).
  final String? preselectedTagId;

  /// Recipes for preview count (optional).
  final List<Recipe>? recipesForPreview;

  /// Whether to show apply to existing option.
  final bool showApplyToExisting;

  const PersonalTagRuleDialog({
    super.key,
    this.existingRule,
    required this.availableTags,
    this.preselectedTagId,
    this.recipesForPreview,
    this.showApplyToExisting = false,
  });

  /// Shows the dialog with automatic ViewModel setup.
  static Future<PersonalTagRule?> show(
    BuildContext context, {
    PersonalTagRule? existingRule,
    String? preselectedTagId,
  }) async {
    final tags = ServiceLocator.get<PersonalTagViewModel>().tags;

    if (!context.mounted) return null;

    return showDialog<PersonalTagRule>(
      context: context,
      builder: (context) => PersonalTagRuleDialog(
        existingRule: existingRule,
        availableTags: tags,
        preselectedTagId: preselectedTagId,
      ),
    );
  }

  /// Shows the dialog with apply-to-existing option.
  ///
  /// Returns [PersonalTagRuleResult] with the rule and whether to apply
  /// to existing recipes.
  static Future<PersonalTagRuleResult?> showWithApplyOption(
    BuildContext context, {
    PersonalTagRule? existingRule,
    String? preselectedTagId,
    required List<Recipe> recipesForPreview,
  }) async {
    final tags = ServiceLocator.get<PersonalTagViewModel>().tags;

    if (!context.mounted) return null;

    return showDialog<PersonalTagRuleResult>(
      context: context,
      builder: (context) => PersonalTagRuleDialog(
        existingRule: existingRule,
        availableTags: tags,
        preselectedTagId: preselectedTagId,
        recipesForPreview: recipesForPreview,
        showApplyToExisting: true,
      ),
    );
  }

  @override
  State<PersonalTagRuleDialog> createState() => _PersonalTagRuleDialogState();
}

class _PersonalTagRuleDialogState extends State<PersonalTagRuleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _selectedTagId;
  MatchMode _matchMode = MatchMode.all;
  List<RuleCondition> _conditions = [];
  bool _isEnabled = true;
  bool _isSaving = false;
  String? _error;
  bool _applyToExisting = false;
  int? _affectedRecipeCount;
  bool _isCalculatingCount = false;

  bool get _isEditing => widget.existingRule != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingRule != null) {
      final rule = widget.existingRule!;
      _nameController.text = rule.name;
      _selectedTagId = rule.tagId;
      _matchMode = rule.matchMode;
      _conditions = List.from(rule.conditions);
      _isEnabled = rule.isEnabled;
    } else {
      _selectedTagId = widget.preselectedTagId;
      // Start with one empty condition
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
      _conditions.add(const RuleCondition(
        type: ConditionType.ingredient,
        operator: ConditionOperator.contains,
        value: '',
      ));
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
      var updated = _conditions[index].copyWith(
        type: type,
        operator: operator,
        value: value,
      );
      // Reset operator if invalid for new type
      if (type != null &&
          !OperatorRegistry.isValidCombination(
              updated.type, updated.operator)) {
        updated = updated.copyWith(
          operator: OperatorRegistry.getValidOperators(updated.type).first,
        );
      }
      _conditions[index] = updated;
    });
  }

  Future<void> _calculateAffectedCount() async {
    if (widget.recipesForPreview == null) return;

    setState(() => _isCalculatingCount = true);

    try {
      // Build a temporary rule to test against recipes
      final testRule = PersonalTagRule.create(
        tagId: _selectedTagId ?? '',
        name: 'test',
        conditions: _conditions,
        matchMode: _matchMode,
        isEnabled: true,
      );

      // Count matching recipes (no lookup data for preview)
      int count = 0;
      for (final recipe in widget.recipesForPreview!) {
        if (testRule.evaluate(recipe, null)) {
          count++;
        }
      }

      if (mounted) {
        setState(() => _affectedRecipeCount = count);
      }
    } finally {
      if (mounted) {
        setState(() => _isCalculatingCount = false);
      }
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Build the rule
    PersonalTagRule rule;
    if (_isEditing) {
      rule = widget.existingRule!.copyWith(
        tagId: _selectedTagId,
        name: _nameController.text.trim(),
        conditions: _conditions,
        matchMode: _matchMode,
        isEnabled: _isEnabled,
      );
    } else {
      rule = PersonalTagRule.create(
        tagId: _selectedTagId!,
        name: _nameController.text.trim(),
        conditions: _conditions,
        matchMode: _matchMode,
        isEnabled: _isEnabled,
      );
    }

    // Validate
    final validationError = PersonalTagRule.validate(rule);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    if (mounted) {
      if (widget.showApplyToExisting) {
        Navigator.of(context).pop(PersonalTagRuleResult(
          rule: rule,
          applyToExisting: _applyToExisting,
        ));
      } else {
        Navigator.of(context).pop(rule);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
            maxWidth: AppDimensions.dialogMaxWidthMedium,
            maxHeight: AppDimensions.dialogMaxHeightLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: AppDimensions.spacingL),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildNameField(),
                        const SizedBox(height: AppDimensions.spacingM),
                        _buildTagSelector(),
                        const SizedBox(height: AppDimensions.spacingM),
                        _buildMatchModeSelector(),
                        const SizedBox(height: AppDimensions.spacingM),
                        _buildConditionsSection(),
                        const SizedBox(height: AppDimensions.spacingM),
                        _buildEnabledSwitch(),
                        if (widget.showApplyToExisting) ...[
                          const SizedBox(height: AppDimensions.spacingM),
                          _buildApplyToExistingSection(),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: AppDimensions.spacingM),
                          _buildError(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingL),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _isEditing
                ? context.l10n.ruleEditTitle
                : context.l10n.ruleCreateTitle,
            style: AppTextStyles.titleLarge,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: context.l10n.commonClose,
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: context.l10n.ruleNameLabel,
        hintText: context.l10n.ruleNameHint,
        border: const OutlineInputBorder(),
      ),
      enabled: !_isSaving,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return context.l10n.ruleNameRequired;
        }
        return null;
      },
    );
  }

  Widget _buildTagSelector() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedTagId,
      decoration: InputDecoration(
        labelText: context.l10n.ruleApplyToTag,
        border: const OutlineInputBorder(),
      ),
      items: widget.availableTags.map((tag) {
        return DropdownMenuItem(
          value: tag.id,
          child: Row(
            children: [
              const Icon(Icons.label,
                  size: AppDimensions.iconSizeS, color: AppColors.forestGreen),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(tag.name),
            ],
          ),
        );
      }).toList(),
      onChanged: _isSaving
          ? null
          : (value) {
              setState(() => _selectedTagId = value);
            },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return context.l10n.ruleSelectTag;
        }
        return null;
      },
    );
  }

  Widget _buildMatchModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.ruleMatchModeLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textMedium,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingS),
        SegmentedButton<MatchMode>(
          segments: [
            ButtonSegment(
              value: MatchMode.all,
              label: Text(context.l10n.ruleMatchModeAllConditions),
              icon: const Icon(Icons.all_inclusive,
                  size: AppDimensions.iconSize18),
            ),
            ButtonSegment(
              value: MatchMode.any,
              label: Text(context.l10n.ruleMatchModeAnyCondition),
              icon:
                  const Icon(Icons.call_split, size: AppDimensions.iconSize18),
            ),
          ],
          selected: {_matchMode},
          onSelectionChanged: _isSaving
              ? null
              : (selection) {
                  setState(() => _matchMode = selection.first);
                },
        ),
      ],
    );
  }

  Widget _buildConditionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.l10n.ruleConditionsLabel,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMedium,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _isSaving ? null : _addCondition,
              icon: const Icon(Icons.add, size: AppDimensions.iconSize18),
              label: Text(context.l10n.commonAdd),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingS),
        ...List.generate(_conditions.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
            child: _ConditionRow(
              condition: _conditions[index],
              canDelete: _conditions.length > 1,
              enabled: !_isSaving,
              onTypeChanged: (type) => _updateCondition(index, type: type),
              onOperatorChanged: (op) => _updateCondition(index, operator: op),
              onValueChanged: (value) => _updateCondition(index, value: value),
              onDelete: () => _removeCondition(index),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEnabledSwitch() {
    return SwitchListTile(
      value: _isEnabled,
      onChanged: _isSaving
          ? null
          : (value) {
              setState(() => _isEnabled = value);
            },
      title: Text(context.l10n.ruleEnabledTitle),
      subtitle: Text(
        _isEnabled
            ? context.l10n.ruleEnabledSubtitle
            : context.l10n.rulePausedSubtitle,
        style: AppTextStyles.bodySmall,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildApplyToExistingSection() {
    return CheckboxListTile(
      value: _applyToExisting,
      onChanged: _isSaving
          ? null
          : (value) async {
              setState(() => _applyToExisting = value ?? false);
              if (_applyToExisting && _affectedRecipeCount == null) {
                await _calculateAffectedCount();
              }
            },
      title: Text(context.l10n.ruleApplyToExisting),
      subtitle: _isCalculatingCount
          ? Text(context.l10n.tagDetailRuleCalculating)
          : _affectedRecipeCount != null
              ? Text(context.l10n.tagDetailRuleMatches(_affectedRecipeCount!))
              : Text(context.l10n.ruleTagMatchingImmediately),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color:
            AppColors.error.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
            color: AppColors.error
                .withValues(alpha: AppDimensions.opacityMediumLight)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.error, size: AppDimensions.iconSizeM),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              _error!,
              style: AppTextStyles.errorText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        const SizedBox(width: AppDimensions.spacingM),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing
                  ? context.l10n.commonSave
                  : context.l10n.commonCreate),
        ),
      ],
    );
  }
}

/// A row for editing a single condition.
class _ConditionRow extends StatelessWidget {
  final RuleCondition condition;
  final bool canDelete;
  final bool enabled;
  final ValueChanged<ConditionType> onTypeChanged;
  final ValueChanged<ConditionOperator> onOperatorChanged;
  final ValueChanged<String> onValueChanged;
  final VoidCallback onDelete;

  const _ConditionRow({
    required this.condition,
    required this.canDelete,
    required this.enabled,
    required this.onTypeChanged,
    required this.onOperatorChanged,
    required this.onValueChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Type dropdown
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<ConditionType>(
                  initialValue: condition.type,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: AppDimensions.paddingSymmetric12x8,
                    border: OutlineInputBorder(),
                  ),
                  items: ConditionType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.label, style: AppTextStyles.formOption),
                    );
                  }).toList(),
                  onChanged: enabled
                      ? (value) {
                          if (value != null) onTypeChanged(value);
                        }
                      : null,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              // Operator dropdown (filtered by condition type)
              Expanded(
                flex: 2,
                child: _buildOperatorDropdown(),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              // Delete button
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.close, size: AppDimensions.iconSizeM),
                  onPressed: enabled ? onDelete : null,
                  tooltip: context.l10n.ruleRemoveCondition,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          // Value field - dropdown for property, text field for others
          if (condition.type == ConditionType.property)
            _buildPropertyDropdown()
          else
            TextFormField(
              initialValue: condition.value,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: AppDimensions.paddingAll12,
                hintText: _getHintText(),
                border: const OutlineInputBorder(),
              ),
              enabled: enabled,
              onChanged: onValueChanged,
            ),
        ],
      ),
    );
  }

  Widget _buildOperatorDropdown() {
    final validOperators = OperatorRegistry.getValidOperators(condition.type);
    final currentOperator = validOperators.contains(condition.operator)
        ? condition.operator
        : validOperators.first;

    return DropdownButtonFormField<ConditionOperator>(
      initialValue: currentOperator,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: AppDimensions.paddingSymmetric12x8,
        border: OutlineInputBorder(),
      ),
      items: validOperators.map((op) {
        return DropdownMenuItem(
          value: op,
          child: Text(op.label, style: AppTextStyles.formOption),
        );
      }).toList(),
      onChanged: enabled
          ? (value) {
              if (value != null) onOperatorChanged(value);
            }
          : null,
    );
  }

  String _getHintText() {
    switch (condition.type) {
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
        return context.l10n.ruleHintTime;
      case ConditionType.rating:
        return context.l10n.ruleHintRating;
      case ConditionType.recency:
        return context.l10n.ruleHintRecency;
      case ConditionType.ownership:
        return context.l10n.ruleHintOwnership;
      case ConditionType.hasImage:
        return context.l10n.ruleHintHasImage;
      case ConditionType.completeness:
        return context.l10n.ruleHintCompleteness;
    }
  }

  Widget _buildPropertyDropdown() {
    // Organize properties by category for better UX
    final categories = <String, List<String>>{
      context.l10n.ruleCategoryAllergens: [
        'dairy',
        'egg',
        'fish',
        'crustacean',
        'mollusc',
        'peanut',
        'tree-nut',
        'wheat',
        'contains-gluten',
        'soy',
        'sesame',
        'celery',
        'mustard',
        'lupin',
        'sulfites'
      ],
      context.l10n.ruleCategoryLactose: ['contains-lactose'],
      context.l10n.ruleCategoryMeat: [
        'meat',
        'pork',
        'beef',
        'poultry',
        'lamb',
        'game'
      ],
      context.l10n.ruleCategorySeafood: [
        'seafood',
        'fish',
        'crustacean',
        'mollusc',
        'high-mercury'
      ],
      context.l10n.ruleCategoryAnimal: ['animal-product'],
      context.l10n.ruleCategoryDiet: [
        'contains-alcohol',
        'is-spicy',
        'plant-based',
        'nightshade'
      ],
      context.l10n.ruleCategoryOther: ['doesnt-freeze-well', 'raw-safe'],
    };

    // Build grouped dropdown items
    final items = <DropdownMenuItem<String>>[];
    for (final entry in categories.entries) {
      // Category header (disabled)
      items.add(DropdownMenuItem<String>(
        enabled: false,
        value: '__header_${entry.key}',
        child: Text(
          entry.key,
          style: AppTextStyles.badgeLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ));
      // Properties in category
      for (final prop in entry.value) {
        if (PropertyRegistry.isValid(prop)) {
          items.add(DropdownMenuItem<String>(
            value: prop,
            child: Padding(
              padding: AppDimensions.paddingOnlyLeft8,
              child: Text(prop, style: AppTextStyles.formOption),
            ),
          ));
        }
      }
    }

    return DropdownButtonFormField<String>(
      initialValue: condition.value.isNotEmpty &&
              PropertyRegistry.isValid(condition.value)
          ? condition.value
          : null,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: AppDimensions.paddingAll12,
        hintText: context.l10n.ruleSelectProperty,
        border: OutlineInputBorder(),
      ),
      isExpanded: true,
      items: items,
      onChanged: enabled
          ? (value) {
              if (value != null && !value.startsWith('__header_')) {
                onValueChanged(value);
              }
            }
          : null,
    );
  }
}
