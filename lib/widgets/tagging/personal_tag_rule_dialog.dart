import 'package:flutter/material.dart';

import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/recipe_unified.dart';
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
    // Load tags first
    final viewModel = PersonalTagViewModel();
    await viewModel.initialize();
    final tags = viewModel.tags;
    viewModel.dispose();

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
    // Load tags first
    final viewModel = PersonalTagViewModel();
    await viewModel.initialize();
    final tags = viewModel.tags;
    viewModel.dispose();

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
      _conditions[index] = _conditions[index].copyWith(
        type: type,
        operator: operator,
        value: value,
      );
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
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
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
            _isEditing ? 'Redigera regel' : 'Skapa regel',
            style: AppTextStyles.titleLarge,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Regelnamn',
        hintText: 'T.ex. "Fiskrecept"',
        border: OutlineInputBorder(),
      ),
      enabled: !_isSaving,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Ange ett regelnamn';
        }
        return null;
      },
    );
  }

  Widget _buildTagSelector() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedTagId,
      decoration: const InputDecoration(
        labelText: 'Tillämpa på tagg',
        border: OutlineInputBorder(),
      ),
      items: widget.availableTags.map((tag) {
        return DropdownMenuItem(
          value: tag.id,
          child: Row(
            children: [
              const Icon(Icons.label, size: AppDimensions.iconSizeS, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
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
          return 'Välj en tagg';
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
          'Matchningsläge',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textMedium,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingS),
        SegmentedButton<MatchMode>(
          segments: const [
            ButtonSegment(
              value: MatchMode.all,
              label: Text('Alla villkor (AND)'),
              icon: Icon(Icons.all_inclusive, size: AppDimensions.iconSize18),
            ),
            ButtonSegment(
              value: MatchMode.any,
              label: Text('Något villkor (OR)'),
              icon: Icon(Icons.call_split, size: AppDimensions.iconSize18),
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
              'Villkor',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMedium,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _isSaving ? null : _addCondition,
              icon: const Icon(Icons.add, size: AppDimensions.iconSize18),
              label: const Text('Lägg till'),
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
      title: const Text('Regel aktiverad'),
      subtitle: Text(
        _isEnabled ? 'Regeln tillämpas på recept' : 'Regeln är pausad',
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
      title: const Text('Applicera på befintliga recept'),
      subtitle: _isCalculatingCount
          ? const Text('Beräknar...')
          : _affectedRecipeCount != null
              ? Text('$_affectedRecipeCount recept matchar')
              : const Text('Tagga matchande recept omedelbart'),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.error.withValues(alpha: AppDimensions.opacityMediumLight)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: AppDimensions.iconSizeM),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              _error!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
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
          child: const Text('Avbryt'),
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
              : Text(_isEditing ? 'Spara' : 'Skapa'),
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
        color: AppColors.backgroundBeige,
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
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  items: ConditionType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.label,
                          style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: enabled
                      ? (value) {
                          if (value != null) onTypeChanged(value);
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              // Operator dropdown
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<ConditionOperator>(
                  initialValue: condition.operator,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  items: ConditionOperator.values.map((op) {
                    return DropdownMenuItem(
                      value: op,
                      child:
                          Text(op.label, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: enabled
                      ? (value) {
                          if (value != null) onOperatorChanged(value);
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              // Delete button
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.close, size: AppDimensions.iconSizeM),
                  onPressed: enabled ? onDelete : null,
                  tooltip: 'Ta bort villkor',
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Value field - dropdown for property, text field for others
          if (condition.type == ConditionType.property)
            _buildPropertyDropdown()
          else
            TextFormField(
              initialValue: condition.value,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
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

  String _getHintText() {
    switch (condition.type) {
      case ConditionType.ingredient:
        return 'T.ex. "kyckling", "lax"';
      case ConditionType.property:
        return 'T.ex. "seafood", "meat", "dairy"';
      case ConditionType.keyword:
        return 'T.ex. "snabb", "vegetarisk"';
      case ConditionType.sourceUrl:
        return 'T.ex. "bbc.com", "reddit.com"';
      case ConditionType.cuisine:
        return 'T.ex. "italian", "asian"';
      case ConditionType.dietary:
        return 'T.ex. "vegetarian", "vegan"';
      case ConditionType.time:
        return 'Tillagningstid i minuter';
      case ConditionType.rating:
        return 'Betyg (1-5)';
      case ConditionType.recency:
        return 'Antal dagar sedan receptet lades till';
      case ConditionType.ownership:
        return 'T.ex. "personal", "shared", "collaborative"';
      case ConditionType.hasImage:
        return 'true eller false';
      case ConditionType.completeness:
        return 'T.ex. "description", "ingredients"';
    }
  }

  Widget _buildPropertyDropdown() {
    // Organize properties by category for better UX
    final categories = <String, List<String>>{
      'Allergener': [
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
      'Laktos': ['contains-lactose'],
      'Kött': ['meat', 'pork', 'beef', 'poultry', 'lamb', 'game'],
      'Fisk & skaldjur': [
        'seafood',
        'fish',
        'crustacean',
        'mollusc',
        'high-mercury'
      ],
      'Animaliskt': ['animal-product'],
      'Kost': ['contains-alcohol', 'is-spicy', 'plant-based', 'nightshade'],
      'Övrigt': ['doesnt-freeze-well', 'raw-safe'],
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
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textMedium,
            fontSize: 12,
          ),
        ),
      ));
      // Properties in category
      for (final prop in entry.value) {
        if (PropertyRegistry.isValid(prop)) {
          items.add(DropdownMenuItem<String>(
            value: prop,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(prop, style: const TextStyle(fontSize: 14)),
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
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        hintText: 'Välj egenskap...',
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
