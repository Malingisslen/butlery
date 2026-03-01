/// Full-screen view for viewing and editing a personal tag.
///
/// Shows tag details, embedded rules, and usage statistics.
/// Allows editing tag properties and managing automation rules.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/widgets/tagging/rule_builder_sheet.dart';
import 'package:butlery/widgets/tagging/tag_detail_header.dart';
import 'package:butlery/widgets/tagging/tag_detail_rules_section.dart';

/// Full-screen view for viewing and editing a single personal tag.
class TagDetailView extends StatelessWidget {
  final String tagId;

  const TagDetailView({super.key, required this.tagId});

  @override
  Widget build(BuildContext context) {
    final vm = ServiceLocator.get<PersonalTagViewModel>()..selectTag(tagId);
    return ChangeNotifierProvider<PersonalTagViewModel>.value(
      value: vm,
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
      SnackBarUtils.showError(context, context.l10n.tagDetailNameRequired);
      return;
    }

    try {
      final updated = tag.copyWith(name: newName);
      await viewModel.updateTag(updated);

      if (context.mounted) {
        setState(() => _isEditMode = false);
        SnackBarUtils.showSuccess(context, context.l10n.tagDetailUpdated);
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, context.l10n.tagDetailCouldNotUpdate);
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
                tooltip: context.l10n.commonBack,
              ),
              title: Text(context.l10n.commonLoading),
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
                tooltip: context.l10n.commonBack,
              ),
              title: Text(context.l10n.tagDetailDefaultTitle),
            ),
            body: StateWidget.error(
              message: context.l10n.tagDetailNotFound,
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
          tooltip: context.l10n.commonClose,
        ),
        title: Text(context.l10n.tagDetailEditTitle),
        actions: [
          TextButton(
            onPressed: () => _saveChanges(context, tag),
            child: Text(context.l10n.commonSave),
          ),
        ],
      );
    }

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
        tooltip: context.l10n.commonBack,
      ),
      title: Text(tag.name),
      actions: [
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: 'Dela',
          onPressed: () => _shareTag(context, tag),
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          tooltip: context.l10n.commonEdit,
          onPressed: () => _enterEditMode(tag),
        ),
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, value, tag),
          itemBuilder: (menuContext) => [
            PopupMenuItem(
              value: 'apply_rules',
              child: ListTile(
                leading: const Icon(Icons.play_arrow),
                title: Text(context.l10n.tagDetailApplyRules),
                subtitle: Text(context.l10n.tagDetailApplyRulesSubtitle),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete,
                    color: Theme.of(context).colorScheme.error),
                title: Text(context.l10n.commonDelete,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
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
                  TagDetailHeader(
                    tag: tag,
                    usageCount: viewModel.getUsageCount(tag.name),
                  ),
                  const SizedBox(height: AppDimensions.spacingXl),
                  TagDetailRulesSection(
                    tag: tag,
                    viewModel: viewModel,
                    onEditRule: (rule) => _editRule(context, tag, rule),
                    onDeleteRule: (rule) => _deleteRule(context, tag, rule),
                    onToggleRule: (rule) =>
                        _toggleRuleEnabled(context, tag, rule),
                    onAddRule: () => _addRule(context, tag),
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
                  Text(context.l10n.commonName,
                      style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppDimensions.spacingSm),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: context.l10n.tagDetailNameHint,
                      border: const OutlineInputBorder(),
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

  Future<void> _shareTag(BuildContext context, PersonalTag tag) async {
    try {
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();
      final friends = friendsService.friends;
      final groups = friendsService.categoriesList;

      final viewModel = UniversalShareDialogViewModel(
        socialRecipeCoordinator: ServiceLocator.get<SocialRecipeCoordinator>(),
        shoppingService: ServiceLocator.get<UnifiedShoppingService>(),
      );

      if (!context.mounted) return;

      await showDialog(
        context: context,
        builder: (dialogContext) => UniversalShareDialog.personalTag(
          tagId: tag.id,
          tagName: tag.name,
          viewModel: viewModel,
          availableFriends: friends,
          availableGroups: groups,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, context.l10n.tagShareError);
      }
    }
  }

  Future<void> _addRule(BuildContext context, PersonalTag tag) async {
    final result = await _showRuleBuilderSheet(context, tag, null);
    if (result != null && context.mounted) {
      final viewModel = context.read<PersonalTagViewModel>();
      try {
        await viewModel.createRule(tag.id, result);
        if (context.mounted) {
          SnackBarUtils.showSuccess(context, context.l10n.tagDetailRuleCreated);
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(
              context, context.l10n.tagDetailCouldNotCreateRule);
        }
      }
    }
  }

  Future<void> _editRule(
    BuildContext context,
    PersonalTag tag,
    PersonalTagRule rule,
  ) async {
    final result = await _showRuleBuilderSheet(context, tag, rule);
    if (result != null && context.mounted) {
      final viewModel = context.read<PersonalTagViewModel>();
      try {
        await viewModel.updateRule(tag.id, result);
        if (context.mounted) {
          SnackBarUtils.showSuccess(context, context.l10n.tagDetailRuleUpdated);
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(
              context, context.l10n.tagDetailCouldNotUpdateRule);
        }
      }
    }
  }

  Future<PersonalTagRule?> _showRuleBuilderSheet(
    BuildContext context,
    PersonalTag tag,
    PersonalTagRule? existingRule,
  ) {
    return showModalBottomSheet<PersonalTagRule>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => RuleBuilderSheet(
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
        SnackBarUtils.showError(
            context, context.l10n.tagDetailCouldNotChangeRuleStatus);
      }
    }
  }

  Future<void> _deleteRule(
    BuildContext context,
    PersonalTag tag,
    PersonalTagRule rule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.tagDetailDeleteRuleConfirm),
        content: Text(context.l10n.tagDetailDeleteRuleMessage(rule.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final viewModel = context.read<PersonalTagViewModel>();
      try {
        await viewModel.deleteRule(tag.id, rule.id);
        if (context.mounted) {
          SnackBarUtils.showSuccess(context, context.l10n.tagDetailRuleDeleted);
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(
              context, context.l10n.tagDetailCouldNotDeleteRule);
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
      case 'delete':
        await _deleteTag(context, tag);
    }
  }

  Future<void> _applyRulesToRecipes(BuildContext context) async {
    final viewModel = context.read<PersonalTagViewModel>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: AppDimensions.spacingMd),
            Text(context.l10n.tagDetailApplyingRules),
          ],
        ),
      ),
    );

    try {
      final result = await viewModel.applyRulesToExistingRecipes();

      if (context.mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.hasChanges
                  ? context.l10n.tagDetailRulesAppliedSuccess(
                      result.tagsApplied, result.recipesModified)
                  : context.l10n.tagDetailNoRecipesMatched,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(
          'Failed to apply rules to recipes', e, 'TagDetailView', stackTrace);
      if (context.mounted) {
        Navigator.pop(context);
        SnackBarUtils.showError(
            context, context.l10n.tagDetailCouldNotApplyRules);
      }
    }
  }

  Future<void> _deleteTag(BuildContext context, PersonalTag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.tagDetailDeleteTagConfirm),
        content: Text(context.l10n.tagDetailDeleteTagMessage(tag.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final viewModel = context.read<PersonalTagViewModel>();
      try {
        await viewModel.deleteTag(tag.id);
        if (context.mounted) {
          Navigator.of(context).pop();
          SnackBarUtils.showSuccess(context, context.l10n.tagDetailDeleted);
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(
              context, context.l10n.tagDetailCouldNotDelete);
        }
      }
    }
  }
}
