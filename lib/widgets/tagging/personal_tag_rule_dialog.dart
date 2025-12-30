import 'package:flutter/material.dart';

import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/services/tagging/config/property_registry.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

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

  const PersonalTagRuleDialog({
    super.key,
    this.existingRule,
    required this.availableTags,
    this.preselectedTagId,
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

  void _updateCondition(int index, {
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
      Navigator.of(context).pop(rule);
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
              if (tag.icon != null) ...[
                Text(tag.icon!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
              ],
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _colorFromHex(tag.color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(tag.name),
            ],
          ),
        );
      }).toList(),
      onChanged: _isSaving ? null : (value) {
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
              icon: Icon(Icons.all_inclusive, size: 18),
            ),
            ButtonSegment(
              value: MatchMode.any,
              label: Text('Något villkor (OR)'),
              icon: Icon(Icons.call_split, size: 18),
            ),
          ],
          selected: {_matchMode},
          onSelectionChanged: _isSaving ? null : (selection) {
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
              icon: const Icon(Icons.add, size: 18),
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
      onChanged: _isSaving ? null : (value) {
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

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
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

  Color _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.primaryBlue;
    try {
      final buffer = StringBuffer();
      if (hex.length == 7) buffer.write('FF');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return AppColors.primaryBlue;
    }
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
                      child: Text(type.label, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: enabled ? (value) {
                    if (value != null) onTypeChanged(value);
                  } : null,
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
                      child: Text(op.label, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: enabled ? (value) {
                    if (value != null) onOperatorChanged(value);
                  } : null,
                ),
              ),
              const SizedBox(width: 8),
              // Delete button
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
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
    }
  }

  Widget _buildPropertyDropdown() {
    // Organize properties by category for better UX
    final categories = <String, List<String>>{
      'Allergener': ['dairy', 'egg', 'fish', 'crustacean', 'mollusc', 'peanut',
                    'tree-nut', 'wheat', 'contains-gluten', 'soy', 'sesame',
                    'celery', 'mustard', 'lupin', 'sulfites'],
      'Laktos': ['contains-lactose'],
      'Kött': ['meat', 'pork', 'beef', 'poultry', 'lamb', 'game'],
      'Fisk & skaldjur': ['seafood', 'fish', 'crustacean', 'mollusc', 'high-mercury'],
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
      onChanged: enabled ? (value) {
        if (value != null && !value.startsWith('__header_')) {
          onValueChanged(value);
        }
      } : null,
    );
  }
}
