import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/widgets/tagging/personal_tag_edit_dialog.dart';
import 'package:butlery/widgets/tagging/personal_tag_rule_dialog.dart';

/// Dialog for managing personal tags and automation rules.
///
/// Two tabs:
/// - Taggar: View, create, edit, delete personal tags
/// - Regler: View, create, edit, delete automation rules
class PersonalTagManagerDialog extends StatefulWidget {
  const PersonalTagManagerDialog({super.key});

  /// Shows the dialog.
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider(
        create: (_) => PersonalTagViewModel()..initialize(),
        child: const PersonalTagManagerDialog(),
      ),
    );
  }

  @override
  State<PersonalTagManagerDialog> createState() =>
      _PersonalTagManagerDialogState();
}

class _PersonalTagManagerDialogState extends State<PersonalTagManagerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Load tag statistics after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatsWhenReady();
    });
  }

  /// Loads tag statistics once tags are available.
  void _loadStatsWhenReady() {
    final viewModel = context.read<PersonalTagViewModel>();
    if (viewModel.hasTags && !viewModel.isLoadingStats) {
      viewModel.loadTagStatistics();
    } else if (viewModel.isLoading) {
      // Retry after a short delay if still loading
      Future.delayed(AppDimensions.animationDurationCommon, () {
        if (mounted) _loadStatsWhenReady();
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // Rules are now embedded in tags, no separate watching needed
  }

  // Tag operations
  Future<void> _createTag() async {
    final viewModel = context.read<PersonalTagViewModel>();

    final result = await PersonalTagEditDialog.show(
      context,
      checkNameExists: viewModel.tagNameExists,
    );

    if (result != null && mounted) {
      await viewModel.createTag(name: result.name);
    }
  }

  Future<void> _editTag(PersonalTag tag) async {
    final viewModel = context.read<PersonalTagViewModel>();

    final result = await PersonalTagEditDialog.show(
      context,
      existingTag: tag,
      checkNameExists: viewModel.tagNameExists,
    );

    if (result != null && mounted) {
      await viewModel.updateTag(result);
    }
  }

  Future<void> _deleteTag(PersonalTag tag) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort tagg?'),
        content: Text(
          'Är du säker på att du vill ta bort "${tag.name}"? '
          'Alla regler kopplade till denna tagg kommer också att tas bort.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<PersonalTagViewModel>().deleteTag(tag.id);
    }
  }

  // Rule operations - rules are now embedded in tags
  Future<void> _createRule(String tagId) async {
    final viewModel = context.read<PersonalTagViewModel>();

    final result = await PersonalTagRuleDialog.show(context);

    if (result != null && mounted) {
      await viewModel.createRule(tagId, result);
    }
  }

  Future<void> _editRule(String tagId, PersonalTagRule rule) async {
    final viewModel = context.read<PersonalTagViewModel>();

    final result = await PersonalTagRuleDialog.show(
      context,
      existingRule: rule,
    );

    if (result != null && mounted) {
      await viewModel.updateRule(tagId, result);
    }
  }

  Future<void> _deleteRule(String tagId, PersonalTagRule rule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort regel?'),
        content: Text(
          'Är du säker på att du vill ta bort regeln "${rule.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<PersonalTagViewModel>().deleteRule(tagId, rule.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDimensions.dialogMaxWidthMedium, maxHeight: AppDimensions.dialogMaxHeightMedium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingL,
                AppDimensions.paddingL,
                AppDimensions.paddingS,
                0,
              ),
              child: _buildHeader(),
            ),

            // TabBar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingL,
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primaryBlue,
                unselectedLabelColor: AppColors.textMedium,
                indicatorColor: AppColors.primaryBlue,
                tabs: const [
                  Tab(text: 'Taggar'),
                  Tab(text: 'Regler'),
                ],
              ),
            ),

            const Divider(height: 1),

            // TabBarView content
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTagsTab(),
                  _buildRulesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.local_offer_outlined,
          color: AppColors.primaryBlue,
          size: AppDimensions.iconSizeAction,
        ),
        const SizedBox(width: AppDimensions.spacingM),
        Expanded(
          child: Text(
            'Mina taggar',
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

  // ============================================================
  // TAGS TAB
  // ============================================================

  Widget _buildTagsTab() {
    return Consumer<PersonalTagViewModel>(
      builder: (context, viewModel, _) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (viewModel.hasError) {
          return _buildError(viewModel.error!, viewModel.initialize);
        }

        return Column(
          children: [
            Expanded(
              child: viewModel.hasTags
                  ? _buildTagList(viewModel.tags)
                  : _buildTagsEmptyState(),
            ),
            const Divider(height: 1),
            _buildTagsFooter(),
          ],
        );
      },
    );
  }

  Widget _buildTagsEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.label_outline,
              color: AppColors.textMedium.withValues(alpha: AppDimensions.opacityHalf),
              size: AppDimensions.iconSizeXXXl,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              'Inga taggar ännu',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text(
              'Skapa din första tagg för att organisera dina recept.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMedium,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingL),
            FilledButton.icon(
              onPressed: _createTag,
              icon: const Icon(Icons.add),
              label: const Text('Skapa tagg'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagList(List<PersonalTag> tags) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
      itemCount: tags.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final tag = tags[index];
        return _buildTagTile(tag);
      },
    );
  }

  Widget _buildTagTile(PersonalTag tag) {
    final viewModel = context.watch<PersonalTagViewModel>();
    final usageCount = viewModel.getUsageCount(tag.name);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.spacingXs,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityLightSubtle),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
        child: const Center(
          child: Icon(Icons.label, size: AppDimensions.iconSizeM, color: AppColors.primaryBlue),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              tag.name,
              style: AppTextStyles.text14Medium,
            ),
          ),
          if (!viewModel.isLoadingStats && usageCount > 0)
            Container(
              padding: AppDimensions.paddingSymmetric8x2,
              decoration: BoxDecoration(
                color: AppColors.backgroundBeige,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
              ),
              child: Text(
                '$usageCount recept',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMedium,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        'Skapad ${_formatDate(tag.createdAt)}',
        style: AppTextStyles.metadataEmphasized,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            color: AppColors.primaryBlue,
            onPressed: () => _editTag(tag),
            tooltip: 'Redigera',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: AppColors.error,
            onPressed: () => _deleteTag(tag),
            tooltip: 'Ta bort',
          ),
        ],
      ),
    );
  }

  Widget _buildTagsFooter() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Stäng'),
          ),
          FilledButton.icon(
            onPressed: _createTag,
            icon: const Icon(Icons.add, size: AppDimensions.iconSizeM),
            label: const Text('Ny tagg'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RULES TAB
  // ============================================================

  Widget _buildRulesTab() {
    return Consumer<PersonalTagViewModel>(
      builder: (context, viewModel, _) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (viewModel.hasError) {
          return _buildError(viewModel.error!, viewModel.initialize);
        }

        // Check if user has tags first
        if (!viewModel.hasTags) {
          return _buildNoTagsForRules();
        }

        // Get all rules from all tags
        final tagsWithRules =
            viewModel.tags.where((t) => t.rules.isNotEmpty).toList();
        final hasRules = tagsWithRules.isNotEmpty;

        return Column(
          children: [
            Expanded(
              child: hasRules
                  ? _buildRuleList(tagsWithRules)
                  : _buildRulesEmptyState(),
            ),
            const Divider(height: 1),
            _buildRulesFooter(),
          ],
        );
      },
    );
  }

  Widget _buildNoTagsForRules() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_outlined,
              color: AppColors.warning,
              size: AppDimensions.iconSizeXxl,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              'Skapa en tagg först',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text(
              'Du behöver minst en tagg för att kunna skapa automationsregler.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMedium,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingL),
            FilledButton.icon(
              onPressed: () {
                _tabController.animateTo(0);
                _createTag();
              },
              icon: const Icon(Icons.add),
              label: const Text('Skapa tagg'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesEmptyState() {
    final viewModel = context.watch<PersonalTagViewModel>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.textMedium.withValues(alpha: AppDimensions.opacityHalf),
              size: AppDimensions.iconSizeXXXl,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              'Inga regler ännu',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text(
              'Skapa regler för att automatiskt lägga till taggar baserat på ingredienser eller nyckelord.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMedium,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingL),
            // Show dropdown to select tag, then create rule
            _buildAddRuleForTagButton(viewModel.tags),
          ],
        ),
      ),
    );
  }

  Widget _buildAddRuleForTagButton(List<PersonalTag> tags) {
    return PopupMenuButton<String>(
      child: FilledButton.icon(
        onPressed: null, // PopupMenuButton handles the tap
        icon: const Icon(Icons.add),
        label: const Text('Skapa regel för tagg'),
      ),
      itemBuilder: (context) => tags.map((tag) {
        return PopupMenuItem<String>(
          value: tag.id,
          child: Row(
            children: [
              const Icon(Icons.label, size: AppDimensions.iconSizeXs, color: AppColors.primaryBlue),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(tag.name),
            ],
          ),
        );
      }).toList(),
      onSelected: (tagId) => _createRule(tagId),
    );
  }

  Widget _buildRuleList(List<PersonalTag> tagsWithRules) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
      itemCount: tagsWithRules.length,
      itemBuilder: (context, index) {
        final tag = tagsWithRules[index];
        return _buildRuleGroup(tag, tag.rules);
      },
    );
  }

  Widget _buildRuleGroup(PersonalTag tag, List<PersonalTagRule> rules) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tag header
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.paddingL,
            AppDimensions.paddingM,
            AppDimensions.paddingL,
            AppDimensions.paddingS,
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityLightSubtle),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                child: const Center(
                  child:
                      Icon(Icons.label, size: AppDimensions.iconSize14, color: AppColors.primaryBlue),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Expanded(
                child: Text(
                  tag.name,
                  style: AppTextStyles.bodyBold,
                ),
              ),
              // Add rule button for this tag
              IconButton(
                icon: const Icon(Icons.add, size: AppDimensions.iconSizeM),
                color: AppColors.primaryBlue,
                onPressed: () => _createRule(tag.id),
                tooltip: 'Lägg till regel',
              ),
            ],
          ),
        ),
        // Rules for this tag
        ...rules.map((rule) => _buildRuleTile(tag.id, rule)),
        const Divider(height: AppDimensions.spacingM),
      ],
    );
  }

  Widget _buildRuleTile(String tagId, PersonalTagRule rule) {
    final viewModel = context.read<PersonalTagViewModel>();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
      ),
      leading: Icon(
        rule.isEnabled ? Icons.check_circle : Icons.pause_circle_outline,
        color: rule.isEnabled ? AppColors.success : AppColors.textLight,
      ),
      title: Text(
        rule.name,
        style: AppTextStyles.bodyMedium.copyWith(
          color: rule.isEnabled ? null : AppColors.textMedium,
        ),
      ),
      subtitle: Text(
        _buildRuleSummary(rule),
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textMedium,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Enable/disable toggle
          Switch(
            value: rule.isEnabled,
            onChanged: (_) => viewModel.toggleRuleEnabled(tagId, rule.id),
            activeTrackColor: AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityHalf),
            activeThumbColor: AppColors.primaryBlue,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: AppDimensions.iconSizeM),
            color: AppColors.primaryBlue,
            onPressed: () => _editRule(tagId, rule),
            tooltip: 'Redigera',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: AppDimensions.iconSizeM),
            color: AppColors.error,
            onPressed: () => _deleteRule(tagId, rule),
            tooltip: 'Ta bort',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  String _buildRuleSummary(PersonalTagRule rule) {
    final conditionCount = rule.conditions.length;
    final modeText = rule.matchMode == MatchMode.all ? 'alla' : 'något';
    if (conditionCount == 1) {
      return '1 villkor';
    }
    return '$conditionCount villkor, $modeText måste matcha';
  }

  Widget _buildRulesFooter() {
    final viewModel = context.watch<PersonalTagViewModel>();
    final hasEnabledRules = viewModel.enabledRules.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Stäng'),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasEnabledRules)
                Padding(
                  padding: AppDimensions.paddingOnlyRight8,
                  child: OutlinedButton.icon(
                    onPressed: _applyRulesToRecipes,
                    icon: const Icon(Icons.play_arrow, size: AppDimensions.iconSizeM),
                    label: const Text('Kör regler'),
                  ),
                ),
              // Show dropdown to select tag for new rule
              _buildAddRuleForTagButton(viewModel.tags),
            ],
          ),
        ],
      ),
    );
  }

  /// Applies all enabled rules to existing recipes with progress dialog.
  Future<void> _applyRulesToRecipes() async {
    final viewModel = context.read<PersonalTagViewModel>();

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kör regler på befintliga recept'),
        content: const Text(
          'Detta kommer att granska alla dina recept och lägga till '
          'taggar enligt dina aktiverade regler.\n\n'
          'Taggar som redan finns på recept påverkas inte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kör'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Show progress dialog
    int progress = 0;
    int total = 0;

    final progressDialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppDimensions.spacingM),
              Text(
                total > 0
                    ? 'Bearbetar recept $progress av $total...'
                    : 'Hämtar recept...',
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await viewModel.applyRulesToExistingRecipes(
        onProgress: (completed, totalCount) {
          progress = completed;
          total = totalCount;
        },
      );

      // Close progress dialog
      if (mounted) Navigator.of(context).pop();
      await progressDialog;

      // Show result
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.hasChanges
                  ? '${result.recipesModified} recept uppdaterades med '
                      '${result.tagsApplied} nya taggar'
                  : 'Inga recept behövde uppdateras',
            ),
            backgroundColor: result.hasChanges ? AppColors.success : null,
          ),
        );
      }
    } catch (e) {
      // Close progress dialog
      if (mounted) Navigator.of(context).pop();
      await progressDialog;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fel vid regelkörning: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ============================================================
  // SHARED WIDGETS
  // ============================================================

  Widget _buildError(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: AppDimensions.iconSizeXxl,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              error,
              style: AppTextStyles.bodyMediumError,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            TextButton(
              onPressed: onRetry,
              child: const Text('Försök igen'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
