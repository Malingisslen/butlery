import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog_frame.dart';
import 'package:butlery/widgets/common/butlery_segment_switch.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_close_button.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/tagging/config/operator_registry.dart';
import 'package:butlery/services/tagging/config/property_registry.dart';
import 'package:butlery/services/tagging/config/valid_properties.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/theme/error_text_style.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

/// Prefix marking a disabled category-header dropdown item; its value is a
/// sentinel that is never a real property.
const String _kHeaderPrefix = '__header_';

/// BUT-1618: a stored condition value the vocabulary no longer recognises
/// (e.g. the retired 'wheat'). Excludes the header sentinels so a malformed
/// stored value shaped like one can't be both a retired item AND a header.
@visibleForTesting
bool isRetiredProperty(String value) =>
    value.isNotEmpty &&
    !value.startsWith(_kHeaderPrefix) &&
    !PropertyRegistry.isValid(value);

/// One entry in the property dropdown: a category header (disabled), a
/// selectable property, or the flagged retired stored value. The widget builds
/// its dropdown options directly from this list, so a test over it exercises
/// the REAL dropdown — not a parallel copy.
typedef PropertyDropdownEntry = ({
  String value,
  bool isHeader,
  bool isRetired,
  String? categoryId,
});

/// The dropdown's `initialValue` for [storedValue]: the value itself only when
/// it matches a selectable item — a valid property, or a retired value (the
/// flagged item). Any OTHER non-empty value (a corrupted/imported/legacy value,
/// e.g. one shaped like a `__header_` sentinel) matches zero items, so this
/// returns null (unselected) rather than let DropdownButtonFormField assert on
/// open. Shares [isRetiredProperty]/[PropertyRegistry] with the item builder.
@visibleForTesting
String? dropdownInitialValue(String storedValue) =>
    (PropertyRegistry.isValid(storedValue) || isRetiredProperty(storedValue))
    ? storedValue
    : null;

/// The ordered dropdown entries for [storedValue]: a retired stored value first
/// (flagged), then each category header followed by its properties.
/// `DropdownButtonFormField.initialValue` (= storedValue) must match exactly
/// one entry — a retired value that fell out is the "editing a rule with a
/// retired property crashes the dropdown" bug.
@visibleForTesting
List<PropertyDropdownEntry> propertyDropdownEntries(String storedValue) => [
  if (isRetiredProperty(storedValue))
    (value: storedValue, isHeader: false, isRetired: true, categoryId: null),
  for (final entry in kIngredientPropertyCategories.entries) ...[
    (
      value: '$_kHeaderPrefix${entry.key}',
      isHeader: true,
      isRetired: false,
      categoryId: entry.key,
    ),
    for (final prop in entry.value)
      (value: prop, isHeader: false, isRetired: false, categoryId: null),
  ],
];

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

    return showButleryDialog<PersonalTagRule>(
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

    return showButleryDialog<PersonalTagRuleResult>(
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
      var updated = _conditions[index].copyWith(
        type: type,
        operator: operator,
        value: value,
      );
      // Reset operator if invalid for new type
      if (type != null &&
          !OperatorRegistry.isValidCombination(
            updated.type,
            updated.operator,
          )) {
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
        tagId: _selectedTagId.orEmpty(),
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
        Navigator.of(context).pop(
          PersonalTagRuleResult(
            rule: rule,
            applyToExisting: _applyToExisting,
          ),
        );
      } else {
        Navigator.of(context).pop(rule);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ButleryDialogFrame(
      maxHeight: AppDimensions.dialogMaxHeightLarge,
      padding: const EdgeInsets.all(AppDimensions.space16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: AppDimensions.space12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildNameField(),
                    const SizedBox(height: AppDimensions.space8),
                    _buildTagSelector(),
                    const SizedBox(height: AppDimensions.space8),
                    _buildMatchModeSelector(),
                    const SizedBox(height: AppDimensions.space8),
                    _buildConditionsSection(),
                    const SizedBox(height: AppDimensions.space8),
                    _buildEnabledSwitch(),
                    if (widget.showApplyToExisting) ...[
                      const SizedBox(height: AppDimensions.space8),
                      _buildApplyToExistingSection(),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: AppDimensions.space8),
                      _buildError(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space12),
            _buildActions(),
          ],
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
        ButleryCloseButton(semanticLabel: context.l10n.commonClose),
      ],
    );
  }

  Widget _buildNameField() {
    return StyledInput(
      label: context.l10n.ruleNameLabel,
      controller: _nameController,
      hint: context.l10n.ruleNameHint,
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
    return ButleryDropdown<String>(
      label: context.l10n.ruleApplyToTag,
      semanticLabel: context.l10n.ruleApplyToTag,
      value: _selectedTagId,
      options: [
        for (final tag in widget.availableTags)
          ButleryDropdownOption<String>(
            value: tag.id,
            label: tag.name,
            icon: ButleryIcons.tag,
            iconColor: Theme.of(context).colorScheme.onSurface,
          ),
      ],
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimensions.space4),
        ButlerySegmentSwitch<MatchMode>(
          choices: [
            (MatchMode.all, context.l10n.ruleMatchModeAllConditions),
            (MatchMode.any, context.l10n.ruleMatchModeAnyCondition),
          ],
          selected: _matchMode,
          onChanged: _isSaving
              ? null
              : (picked) => setState(() => _matchMode = picked),
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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            ButleryTextButton(
              onPressed: _isSaving ? null : _addCondition,
              icon: ButleryIcons.plus,
              label: context.l10n.commonAdd,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space4),
        ...List.generate(_conditions.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.space4),
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
    return ButleryListRow.toggle(
      label: context.l10n.ruleEnabledTitle,
      subtitle: _isEnabled
          ? context.l10n.ruleEnabledSubtitle
          : context.l10n.rulePausedSubtitle,
      checked: _isEnabled,
      enabled: !_isSaving,
      onChanged: (value) => setState(() => _isEnabled = value),
    );
  }

  Widget _buildApplyToExistingSection() {
    return ButleryCheckboxTile(
      boxFirst: true,
      value: _applyToExisting,
      onChanged: _isSaving
          ? null
          : (value) async {
              setState(() => _applyToExisting = value);
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
    );
  }

  Widget _buildError() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space12),
      decoration: BoxDecoration(
        color: context.modeColors.surfaceTintDanger,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Row(
        children: [
          ButleryIcon(
            ButleryIcons.triangleAlert,
            color: cs.onErrorContainer,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.space4),
          Expanded(
            child: Text(
              _error!,
              style: errorTextStyle(cs, onDangerTint: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    // OverflowBar hands the buttons loose constraints, which the theme's
    // infinite minimum button width needs; a Row would not.
    return OverflowBar(
      alignment: MainAxisAlignment.end,
      spacing: AppDimensions.space8,
      children: [
        DialogCancelButton(enabled: !_isSaving),
        ButleryDialogPrimary(
          label: _isEditing
              ? context.l10n.commonSave
              : context.l10n.commonCreate,
          busy: _isSaving,
          onPressed: _save,
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Type dropdown
              Expanded(
                flex: 2,
                child: ButleryDropdown<ConditionType>(
                  dense: true,
                  semanticLabel: context.l10n.ruleConditionsLabel,
                  value: condition.type,
                  options: [
                    for (final type in ConditionType.values)
                      ButleryDropdownOption<ConditionType>(
                        value: type,
                        label: type.label,
                      ),
                  ],
                  onChanged: enabled ? onTypeChanged : null,
                ),
              ),
              const SizedBox(width: AppDimensions.space8),
              // Operator dropdown (filtered by condition type)
              Expanded(
                flex: 2,
                child: _buildOperatorDropdown(context),
              ),
              const SizedBox(width: AppDimensions.space8),
              // Delete button
              if (canDelete)
                AppIconButton(
                  icon: ButleryIcons.x,
                  onPressed: enabled ? onDelete : null,
                  semanticLabel: context.l10n.ruleRemoveCondition,
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.space8),
          // Value field - dropdown for property, text field for others
          if (condition.type == ConditionType.property)
            _buildPropertyDropdown(context)
          else
            _ConditionValueField(
              initialValue: condition.value,
              hint: _getHintText(context),
              enabled: enabled,
              numeric: condition.type.isNumeric,
              onChanged: onValueChanged,
            ),
        ],
      ),
    );
  }

  Widget _buildOperatorDropdown(BuildContext context) {
    final validOperators = OperatorRegistry.getValidOperators(condition.type);
    final currentOperator = validOperators.contains(condition.operator)
        ? condition.operator
        : validOperators.first;

    return ButleryDropdown<ConditionOperator>(
      dense: true,
      semanticLabel: context.l10n.ruleConditionsLabel,
      value: currentOperator,
      options: [
        for (final op in validOperators)
          ButleryDropdownOption<ConditionOperator>(value: op, label: op.label),
      ],
      onChanged: enabled ? onOperatorChanged : null,
    );
  }

  String _getHintText(BuildContext context) {
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
      case ConditionType.cookedRecency:
        return context.l10n.ruleHintRecency;
      case ConditionType.ownership:
        return context.l10n.ruleHintOwnership;
      case ConditionType.hasImage:
        return context.l10n.ruleHintHasImage;
      case ConditionType.completeness:
        return context.l10n.ruleHintCompleteness;
    }
  }

  /// Localized labels for the shared vocabulary's category ids.
  String _categoryLabel(BuildContext context, String categoryId) {
    switch (categoryId) {
      case 'allergens':
        return context.l10n.ruleCategoryAllergens;
      case 'lactose':
        return context.l10n.ruleCategoryLactose;
      case 'meat':
        return context.l10n.ruleCategoryMeat;
      case 'seafood':
        return context.l10n.ruleCategorySeafood;
      case 'animal':
        return context.l10n.ruleCategoryAnimal;
      case 'diet':
        return context.l10n.ruleCategoryDiet;
      case 'other':
        return context.l10n.ruleCategoryOther;
      default:
        return categoryId;
    }
  }

  Widget _buildPropertyDropdown(BuildContext context) {
    final storedValue = condition.value;
    // Built from the shared, tested [propertyDropdownEntries] seam so the
    // dropdown-value invariant (a retired stored value stays selectable exactly
    // once, or DropdownButtonFormField's initialValue asserts) is exercised by
    // its unit test on the SAME code path this renders. A retired stored value
    // (e.g. 'wheat', BUT-1498) appears first, flagged — blanking it would hide
    // that the rule matches nothing until a live property is picked.
    return ButleryDropdown<String>(
      dense: true,
      semanticLabel: context.l10n.ruleSelectProperty,
      hint: context.l10n.ruleSelectProperty,
      value: dropdownInitialValue(storedValue),
      options: [
        for (final e in propertyDropdownEntries(storedValue))
          ButleryDropdownOption<String>(
            value: e.value,
            header: e.isHeader,
            error: e.isRetired,
            indented: !e.isHeader && !e.isRetired,
            label: e.isHeader
                ? _categoryLabel(context, e.categoryId!)
                : e.isRetired
                ? context.l10n.rulePropertyRetired(e.value)
                : e.value,
          ),
      ],
      onChanged: enabled ? onValueChanged : null,
    );
  }
}

/// The free-text value of a condition. It keeps its own controller, so a
/// rebuild of the row while the user types does not rewrite the text.
class _ConditionValueField extends StatefulWidget {
  const _ConditionValueField({
    required this.initialValue,
    required this.hint,
    required this.enabled,
    required this.numeric,
    required this.onChanged,
  });

  final String initialValue;
  final String hint;
  final bool enabled;
  final bool numeric;
  final ValueChanged<String> onChanged;

  @override
  State<_ConditionValueField> createState() => _ConditionValueFieldState();
}

class _ConditionValueFieldState extends State<_ConditionValueField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StyledInput(
      controller: _controller,
      semanticLabel: widget.hint,
      hint: widget.hint,
      contentPadding: AppDimensions.paddingAll12,
      enabled: widget.enabled,
      // A rating such as 4.5 must stay typeable.
      keyboardType: widget.numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      onChanged: widget.onChanged,
    );
  }
}
