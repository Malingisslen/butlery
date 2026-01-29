/// Full-screen view for viewing and editing a personal tag.
///
/// Shows tag details, embedded rules, and usage statistics.
/// Allows editing tag properties and managing automation rules.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Full-screen view for viewing and editing a single personal tag.
class TagDetailView extends StatelessWidget {
  final String tagId;

  const TagDetailView({super.key, required this.tagId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PersonalTagViewModel()
        ..initialize()
        ..selectTag(tagId),
      child: _TagDetailViewContent(tagId: tagId),
    );
  }
}

class _TagDetailViewContent extends StatefulWidget {
  final String tagId;

  const _TagDetailViewContent({required this.tagId});

  @override
  State<_TagDetailViewContent> createState() => _TagDetailViewContentState();
}

class _TagDetailViewContentState extends State<_TagDetailViewContent> {
  bool _isEditMode = false;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load rule effectiveness stats after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<PersonalTagViewModel>();
      if (!viewModel.isLoadingRuleStats) {
        viewModel.loadRuleEffectiveness();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _enterEditMode(PersonalTag tag) {
    setState(() {
      _isEditMode = true;
      _nameController.text = tag.name;
    });
  }

  void _cancelEditMode() {
    setState(() {
      _isEditMode = false;
    });
  }

  Future<void> _saveChanges(BuildContext context, PersonalTag tag) async {
    final viewModel = context.read<PersonalTagViewModel>();
    final newName = _nameController.text.trim();

    if (newName.isEmpty) {
      SnackBarUtils.showError(context, 'Taggnamn krävs');
      return;
    }

    try {
      final updated = tag.copyWith(name: newName);
      await viewModel.updateTag(updated);

      if (context.mounted) {
        setState(() => _isEditMode = false);
        SnackBarUtils.showSuccess(context, 'Tagg uppdaterad');
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, 'Kunde inte uppdatera taggen');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PersonalTagViewModel>(
      builder: (context, viewModel, _) {
        final tag = viewModel.getTagById(widget.tagId);

        if (viewModel.isLoading && tag == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: '',
              ),
              title: const Text('Läser in...'),
            ),
            body: StateWidget.loading(),
          );
        }

        if (tag == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: '',
              ),
              title: const Text('Tagg'),
            ),
            body: StateWidget.error(
              message: 'Taggen kunde inte hittas',
              onAction: () => Navigator.of(context).maybePop(),
            ),
          );
        }

        return Scaffold(
          appBar: _buildAppBar(context, tag),
          body: _buildBody(context, viewModel, tag),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, PersonalTag tag) {
    if (_isEditMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancelEditMode,
        ),
        title: const Text('Redigera tagg'),
        actions: [
          TextButton(
            onPressed: () => _saveChanges(context, tag),
            child: const Text('Spara'),
          ),
        ],
      );
    }

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
        tooltip: '',
      ),
      title: Text(tag.name),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          tooltip: 'Redigera',
          onPressed: () => _enterEditMode(tag),
        ),
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, value, tag),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'apply_rules',
              child: ListTile(
                leading: Icon(Icons.play_arrow),
                title: Text('Kör regler'),
                subtitle: Text('Tillämpa på befintliga recept'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: AppColors.error),
                title:
                    Text('Ta bort', style: TextStyle(color: AppColors.error)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    PersonalTagViewModel viewModel,
    PersonalTag tag,
  ) {
    if (_isEditMode) {
      return _buildEditModeBody(context, tag);
    }

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth =
              constraints.maxWidth > 700 ? 700.0 : constraints.maxWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: contentWidth,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.spacingLg),
                children: [
                  _buildTagHeader(context, tag, viewModel),
                  const SizedBox(height: AppDimensions.spacingXl),
                  _buildRulesSection(context, viewModel, tag),
                  const SizedBox(height: AppDimensions.spacingXxl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTagHeader(
    BuildContext context,
    PersonalTag tag,
    PersonalTagViewModel viewModel,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final usageCount = viewModel.getUsageCount(tag.name);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: colorScheme.primary
                  .withValues(alpha: AppDimensions.opacityLight),
              child: Icon(
                Icons.label,
                color: colorScheme.primary,
                size: 32,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tag.name, style: AppTextStyles.titleLarge),
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    usageCount == 1 ? '1 recept' : '$usageCount recept',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (tag.rules.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      '${tag.rules.where((r) => r.isEnabled).length}/${tag.rules.length} regler aktiva',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditModeBody(BuildContext context, PersonalTag tag) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth =
              constraints.maxWidth > 700 ? 700.0 : constraints.maxWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: contentWidth,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.spacingLg),
                children: [
                  Text('Namn', style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppDimensions.spacingSm),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Taggnamn',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppDimensions.spacingXxl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRulesSection(
    BuildContext context,
    PersonalTagViewModel viewModel,
    PersonalTag tag,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final rules = tag.rules;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: AppDimensions.iconSizeM),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              child: Text(
                'Automatiseringsregler',
                style: AppTextStyles.titleMedium,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            Flexible(
              fit: FlexFit.loose,
              child: FilledButton.tonalIcon(
                onPressed: () => _addRule(context, tag),
                icon: const Icon(Icons.add, size: AppDimensions.iconSize18),
                label: const Text('Lägg till'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        Text(
          'Regler tillämpar taggen automatiskt på recept som matchar villkoren.',
          style: AppTextStyles.bodySmall.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        if (rules.isEmpty)
          _buildEmptyRulesState(context, tag)
        else
          ...rules.map((rule) => _buildRuleTile(context, viewModel, tag, rule)),
      ],
    );
  }

  Widget _buildEmptyRulesState(BuildContext context, PersonalTag tag) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingXl),
        child: Column(
          children: [
            const Icon(
              Icons.rule,
              size: 48,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              'Inga regler ännu',
              style: AppTextStyles.titleMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              'Skapa regler för att automatiskt tagga recept',
              style: AppTextStyles.bodySmall.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            OutlinedButton.icon(
              onPressed: () => _addRule(context, tag),
              icon: const Icon(Icons.add),
              label: const Text('Skapa första regeln'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleTile(
    BuildContext context,
    PersonalTagViewModel viewModel,
    PersonalTag tag,
    PersonalTagRule rule,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final conditionSummary = _buildConditionSummary(rule);
    final matchCount = viewModel.getRuleMatchCount(rule.id);
    final isLoadingStats = viewModel.isLoadingRuleStats;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
      child: ListTile(
        leading: Icon(
          rule.isEnabled ? Icons.check_circle : Icons.pause_circle,
          color:
              rule.isEnabled ? AppColors.success : colorScheme.onSurfaceVariant,
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
                'Beräknar...',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Text(
                matchCount == 1
                    ? '1 recept matchar'
                    : '$matchCount recept matchar',
                style: AppTextStyles.bodySmall.copyWith(
                  color: matchCount > 0
                      ? AppColors.success
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
              onChanged: (value) => _toggleRuleEnabled(context, tag, rule),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: AppDimensions.iconSizeM),
              onSelected: (action) =>
                  _handleRuleAction(context, action, tag, rule),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Redigera'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: AppColors.error),
                    title: Text('Ta bort',
                        style: TextStyle(color: AppColors.error)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _editRule(context, tag, rule),
      ),
    );
  }

  String _buildConditionSummary(PersonalTagRule rule) {
    if (rule.conditions.isEmpty) return 'Inga villkor';

    final parts = rule.conditions.take(3).map((c) {
      final type = c.type.label;
      final op = c.operator.label;
      final value =
          c.type.isNumeric ? c.numericValue.toString() : c.stringValue;
      return '$type $op "$value"';
    }).toList();

    final summary = parts.join(
      rule.matchMode == MatchMode.all ? ' OCH ' : ' ELLER ',
    );

    if (rule.conditions.length > 3) {
      return '$summary (+${rule.conditions.length - 3} till)';
    }

    return summary;
  }

  Future<void> _addRule(BuildContext context, PersonalTag tag) async {
    final result = await _showRuleBuilderDialog(context, tag, null);
    if (result != null && context.mounted) {
      final viewModel = context.read<PersonalTagViewModel>();
      try {
        await viewModel.createRule(tag.id, result);
        if (context.mounted) {
          SnackBarUtils.showSuccess(context, 'Regel skapad');
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(context, 'Kunde inte skapa regeln');
        }
      }
    }
  }

  Future<void> _editRule(
    BuildContext context,
    PersonalTag tag,
    PersonalTagRule rule,
  ) async {
    final result = await _showRuleBuilderDialog(context, tag, rule);
    if (result != null && context.mounted) {
      final viewModel = context.read<PersonalTagViewModel>();
      try {
        await viewModel.updateRule(tag.id, result);
        if (context.mounted) {
          SnackBarUtils.showSuccess(context, 'Regel uppdaterad');
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(context, 'Kunde inte uppdatera regeln');
        }
      }
    }
  }

  Future<PersonalTagRule?> _showRuleBuilderDialog(
    BuildContext context,
    PersonalTag tag,
    PersonalTagRule? existingRule,
  ) {
    return showModalBottomSheet<PersonalTagRule>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _RuleBuilderSheet(
        tag: tag,
        existingRule: existingRule,
      ),
    );
  }

  Future<void> _toggleRuleEnabled(
    BuildContext context,
    PersonalTag tag,
    PersonalTagRule rule,
  ) async {
    final viewModel = context.read<PersonalTagViewModel>();
    try {
      await viewModel.toggleRuleEnabled(tag.id, rule.id);
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, 'Kunde inte ändra regelstatus');
      }
    }
  }

  Future<void> _handleRuleAction(
    BuildContext context,
    String action,
    PersonalTag tag,
    PersonalTagRule rule,
  ) async {
    switch (action) {
      case 'edit':
        await _editRule(context, tag, rule);
        break;
      case 'delete':
        await _deleteRule(context, tag, rule);
        break;
    }
  }

  Future<void> _deleteRule(
    BuildContext context,
    PersonalTag tag,
    PersonalTagRule rule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort regel?'),
        content: Text('Är du säker på att du vill ta bort "${rule.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final viewModel = context.read<PersonalTagViewModel>();
      try {
        await viewModel.deleteRule(tag.id, rule.id);
        if (context.mounted) {
          SnackBarUtils.showSuccess(context, 'Regel borttagen');
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(context, 'Kunde inte ta bort regeln');
        }
      }
    }
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    String action,
    PersonalTag tag,
  ) async {
    switch (action) {
      case 'apply_rules':
        await _applyRulesToRecipes(context);
        break;
      case 'delete':
        await _deleteTag(context, tag);
        break;
    }
  }

  Future<void> _applyRulesToRecipes(BuildContext context) async {
    final viewModel = context.read<PersonalTagViewModel>();

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: AppDimensions.spacingMd),
            Text('Kör regler på recept...'),
          ],
        ),
      ),
    );

    try {
      final result = await viewModel.applyRulesToExistingRecipes();

      if (context.mounted) {
        Navigator.pop(context); // Close progress dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.hasChanges
                  ? '${result.tagsApplied} taggar tillämpade på ${result.recipesModified} recept'
                  : 'Inga recept matchade reglerna',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close progress dialog
        SnackBarUtils.showError(context, 'Kunde inte köra regler');
      }
    }
  }

  Future<void> _deleteTag(BuildContext context, PersonalTag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort tagg?'),
        content: Text(
          'Är du säker på att du vill ta bort "${tag.name}"? '
          'Taggen tas bort från alla recept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final viewModel = context.read<PersonalTagViewModel>();
      try {
        await viewModel.deleteTag(tag.id);
        if (context.mounted) {
          Navigator.of(context).pop(); // Return to tags list
          SnackBarUtils.showSuccess(context, 'Tagg borttagen');
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(context, 'Kunde inte ta bort taggen');
        }
      }
    }
  }
}

/// Bottom sheet for building/editing a rule.
class _RuleBuilderSheet extends StatefulWidget {
  final PersonalTag tag;
  final PersonalTagRule? existingRule;

  const _RuleBuilderSheet({
    required this.tag,
    this.existingRule,
  });

  @override
  State<_RuleBuilderSheet> createState() => _RuleBuilderSheetState();
}

class _RuleBuilderSheetState extends State<_RuleBuilderSheet> {
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

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      SnackBarUtils.showError(context, 'Ange ett regelnamn');
      return;
    }

    // Validate conditions have values
    for (final condition in _conditions) {
      if (condition.type.isNumeric) {
        if (condition.numericValue == 0) {
          SnackBarUtils.showError(context, 'Alla villkor måste ha ett värde');
          return;
        }
      } else {
        if (condition.stringValue.trim().isEmpty) {
          SnackBarUtils.showError(context, 'Alla villkor måste ha ett värde');
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
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: AppDimensions.paddingM),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadius2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingLg),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'Redigera regel' : 'Ny regel',
                        style: AppTextStyles.titleLarge,
                      ),
                    ),
                    Flexible(
                      fit: FlexFit.loose,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Avbryt'),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Flexible(
                      fit: FlexFit.loose,
                      child: FilledButton(
                        onPressed: _save,
                        child: Text(_isEditing ? 'Spara' : 'Skapa'),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppDimensions.spacingLg),
                  children: [
                    // Name field
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Regelnamn',
                        hintText: 'T.ex. "Fiskrecept"',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),

                    // Match mode
                    Text('Matchningsläge', style: AppTextStyles.labelLarge),
                    const SizedBox(height: AppDimensions.spacingSm),
                    SegmentedButton<MatchMode>(
                      segments: const [
                        ButtonSegment(
                          value: MatchMode.all,
                          label: Text('Alla (AND)'),
                        ),
                        ButtonSegment(
                          value: MatchMode.any,
                          label: Text('Något (OR)'),
                        ),
                      ],
                      selected: {_matchMode},
                      onSelectionChanged: (selection) {
                        setState(() => _matchMode = selection.first);
                      },
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),

                    // Conditions
                    Row(
                      children: [
                        Text('Villkor', style: AppTextStyles.labelLarge),
                        const Spacer(),
                        Flexible(
                          fit: FlexFit.loose,
                          child: TextButton.icon(
                            onPressed: _addCondition,
                            icon: const Icon(Icons.add,
                                size: AppDimensions.iconSize18),
                            label: const Text('Lägg till'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    ...List.generate(_conditions.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppDimensions.spacingSm),
                        child: _ConditionCard(
                          key: ValueKey('condition_$index'),
                          condition: _conditions[index],
                          canDelete: _conditions.length > 1,
                          onTypeChanged: (type) =>
                              _updateCondition(index, type: type),
                          onOperatorChanged: (op) =>
                              _updateCondition(index, operator: op),
                          onValueChanged: (value) =>
                              _updateCondition(index, value: value),
                          onDelete: () => _removeCondition(index),
                        ),
                      );
                    }),
                    const SizedBox(height: AppDimensions.spacingLg),

                    // Enabled switch
                    SwitchListTile(
                      value: _isEnabled,
                      onChanged: (value) => setState(() => _isEnabled = value),
                      title: const Text('Regel aktiverad'),
                      subtitle: Text(
                        _isEnabled
                            ? 'Regeln tillämpas på nya recept'
                            : 'Regeln är pausad',
                        style: AppTextStyles.bodySmall,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
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
}

/// A card for editing a single condition.
class _ConditionCard extends StatefulWidget {
  final RuleCondition condition;
  final bool canDelete;
  final ValueChanged<ConditionType> onTypeChanged;
  final ValueChanged<ConditionOperator> onOperatorChanged;
  final ValueChanged<String> onValueChanged;
  final VoidCallback onDelete;

  const _ConditionCard({
    super.key,
    required this.condition,
    required this.canDelete,
    required this.onTypeChanged,
    required this.onOperatorChanged,
    required this.onValueChanged,
    required this.onDelete,
  });

  @override
  State<_ConditionCard> createState() => _ConditionCardState();
}

class _ConditionCardState extends State<_ConditionCard> {
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

  List<ConditionOperator> _getOperatorsForType(ConditionType type) {
    if (type.isNumeric) {
      return [
        ConditionOperator.lessThan,
        ConditionOperator.lessThanOrEqual,
        ConditionOperator.greaterThan,
        ConditionOperator.greaterThanOrEqual,
        ConditionOperator.equals,
        if (type == ConditionType.recency) ConditionOperator.withinDays,
      ];
    }
    if (type == ConditionType.property) {
      return [ConditionOperator.has, ConditionOperator.notHas];
    }
    return [
      ConditionOperator.contains,
      ConditionOperator.equals,
      ConditionOperator.startsWith,
      ConditionOperator.notContains,
      ConditionOperator.notEquals,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final operators = _getOperatorsForType(widget.condition.type);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          children: [
            Row(
              children: [
                // Type dropdown
                Expanded(
                  child: DropdownButtonFormField<ConditionType>(
                    initialValue: widget.condition.type,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: ConditionType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.label, style: AppTextStyles.text14),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        widget.onTypeChanged(value);
                        // Reset operator if current one is invalid for new type
                        final newOperators = _getOperatorsForType(value);
                        if (!newOperators.contains(widget.condition.operator)) {
                          widget.onOperatorChanged(newOperators.first);
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                // Operator dropdown
                Expanded(
                  child: DropdownButtonFormField<ConditionOperator>(
                    initialValue: operators.contains(widget.condition.operator)
                        ? widget.condition.operator
                        : operators.first,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: operators.map((op) {
                      return DropdownMenuItem(
                        value: op,
                        child: Text(op.label, style: AppTextStyles.text14),
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
                    tooltip: 'Ta bort villkor',
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            // Value field
            TextField(
              controller: _valueController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
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
        return 'Tid i minuter';
      case ConditionType.rating:
        return 'Betyg (1-5)';
      case ConditionType.recency:
        return 'Antal dagar';
      case ConditionType.ownership:
        return 'T.ex. "personal", "shared", "collaborative"';
      case ConditionType.hasImage:
        return 'true eller false';
      case ConditionType.completeness:
        return 'T.ex. "description", "ingredients"';
    }
  }
}
