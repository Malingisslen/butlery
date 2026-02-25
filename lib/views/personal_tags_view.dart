/// Full-screen view for managing personal tags and automation rules.
///
/// Displays user's personal tags organized by groups with options to:
/// - Create, edit, delete tags
/// - Navigate to tag detail for rule management
/// - Reorder tags within groups
///
/// Replaces the dialog-based PersonalTagManagerDialog with a full-screen approach.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/models/shared_personal_tag.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_personal_tag_repository.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/views/tag_detail_view.dart';
import 'package:butlery/widgets/common/dialogs/retag_progress_dialog.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';

/// Sort order for personal tags.
enum TagSortOrder {
  byName,
  byUsage,
  byRuleCount;
}

/// Full-screen view for managing personal tags.
class PersonalTagsView extends StatelessWidget {
  const PersonalTagsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PersonalTagViewModel>.value(
      value: ServiceLocator.get<PersonalTagViewModel>(),
      child: const _PersonalTagsViewContent(),
    );
  }
}

class _PersonalTagsViewContent extends StatefulWidget {
  const _PersonalTagsViewContent();

  @override
  State<_PersonalTagsViewContent> createState() =>
      _PersonalTagsViewContentState();
}

class _PersonalTagsViewContentState extends State<_PersonalTagsViewContent> {
  TagSortOrder _sortOrder = TagSortOrder.byUsage;
  List<SharedPersonalTag> _pendingSharedTags = [];

  @override
  void initState() {
    super.initState();
    // Load statistics and pending shared tags after initial build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<PersonalTagViewModel>();
      if (viewModel.hasTags && !viewModel.isLoadingStats) {
        viewModel.loadTagStatistics();
      }
      _loadPendingSharedTags();
    });
  }

  Future<void> _loadPendingSharedTags() async {
    final authService = ServiceLocator.get<AuthService>();
    final userId = authService.currentUser?.uid;
    if (userId == null) return;

    try {
      final repo = ServiceLocator.get<FirebaseSharedPersonalTagRepository>();
      final tags = await repo.getPendingForUser(userId);
      if (mounted) {
        setState(() => _pendingSharedTags = tags);
      }
    } catch (e) {
      AppLogger.warning('Failed to load pending shared tags: $e');
    }
  }

  Future<void> _importSharedTag(
      BuildContext context, SharedPersonalTag sharedTag) async {
    try {
      final personalTagService = ServiceLocator.get<PersonalTagService>();
      final result = await personalTagService.importSharedTag(sharedTag.id);
      if (result != null && context.mounted) {
        SnackBarUtils.showSuccess(context, context.l10n.tagImportedSuccess);
        // Remove from pending list and refresh
        setState(() {
          _pendingSharedTags.removeWhere((t) => t.id == sharedTag.id);
        });
        context.read<PersonalTagViewModel>().initialize();
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, context.l10n.commonErrorOccurred);
      }
    }
  }

  List<PersonalTag> _sortTags(List<PersonalTag> tags, PersonalTagViewModel vm) {
    final sorted = List<PersonalTag>.from(tags);
    switch (_sortOrder) {
      case TagSortOrder.byName:
        sorted.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case TagSortOrder.byUsage:
        sorted.sort((a, b) {
          final aCount = vm.getUsageCount(a.name);
          final bCount = vm.getUsageCount(b.name);
          return bCount.compareTo(aCount); // Descending
        });
      case TagSortOrder.byRuleCount:
        sorted.sort((a, b) {
          final aRules = a.rules.where((r) => r.isEnabled).length;
          final bRules = b.rules.where((r) => r.isEnabled).length;
          return bRules.compareTo(aRules); // Descending
        });
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: context.l10n.commonBack,
        ),
        title: Text(context.l10n.personalTagsViewTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: context.l10n.personalTagApplyRulesToAll,
            onPressed: () => _showRetagDialog(context),
          ),
          PopupMenuButton<TagSortOrder>(
            icon: const Icon(Icons.sort),
            tooltip: context.l10n.commonSort,
            onSelected: (order) => setState(() => _sortOrder = order),
            itemBuilder: (context) => TagSortOrder.values.map((order) {
              final label = switch (order) {
                TagSortOrder.byName => context.l10n.personalTagSortByName,
                TagSortOrder.byUsage => context.l10n.personalTagSortByUsage,
                TagSortOrder.byRuleCount =>
                  context.l10n.personalTagSortByRuleCount,
              };
              return PopupMenuItem(
                value: order,
                child: Row(
                  children: [
                    if (order == _sortOrder)
                      const Icon(Icons.check, size: AppDimensions.iconSize18)
                    else
                      const SizedBox(width: AppDimensions.iconSize18),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Text(label),
                  ],
                ),
              );
            }).toList(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            tooltip: context.l10n.commonCreate,
            onSelected: (value) {
              // Defer to next frame so PopupMenu fully dismisses before dialog opens
              // Fixes BUG-025 (RenderBox assertion) and BUG-022 (Provider lifecycle)
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                if (value == 'tag') {
                  _createTag(context);
                } else if (value == 'group') {
                  _createGroup(context);
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'tag',
                child: ListTile(
                  leading: const Icon(Icons.label_outline),
                  title: Text(context.l10n.personalTagCreateTag),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'group',
                child: ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(context.l10n.personalTagCreateGroup),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<PersonalTagViewModel>(
        builder: (context, viewModel, _) {
          if (viewModel.isLoading && !viewModel.hasTags) {
            return StateWidget.loading();
          }

          if (viewModel.hasError) {
            return StateWidget.error(
              message: viewModel.error ?? context.l10n.commonErrorOccurred,
              onAction: viewModel.initialize,
            );
          }

          if (!viewModel.hasTags) {
            return _buildEmptyState(context);
          }

          return _buildTagList(context, viewModel);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return StateWidget.empty(
      icon: Icons.label_outline,
      title: context.l10n.personalTagEmptyTitle,
      subtitle: context.l10n.personalTagEmptySubtitle,
      actionLabel: context.l10n.personalTagCreateTag,
      onAction: () => _createTag(context),
    );
  }

  Widget _buildTagList(BuildContext context, PersonalTagViewModel viewModel) {
    final groups = viewModel.groups;
    final ungroupedTags = _sortTags(viewModel.getTagsForGroup(null), viewModel);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth =
              constraints.maxWidth > 700 ? 700.0 : constraints.maxWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: contentWidth,
              child: RefreshIndicator(
                onRefresh: () async {
                  await viewModel.initialize();
                  await viewModel.loadTagStatistics();
                  await _loadPendingSharedTags();
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.spacingMd),
                  children: [
                    // Pending shared tags section
                    if (_pendingSharedTags.isNotEmpty)
                      _buildSharedTagsSection(context),

                    // Ungrouped tags section
                    if (ungroupedTags.isNotEmpty) ...[
                      _buildTagSection(
                        context,
                        viewModel,
                        title: context.l10n.personalTagSectionTags,
                        tags: ungroupedTags,
                        groupId: null,
                      ),
                    ],

                    // Grouped tags
                    for (final group in groups) ...[
                      _buildGroupSection(context, viewModel, group),
                    ],

                    // Bottom padding
                    const SizedBox(height: AppDimensions.spacingXxl),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSharedTagsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingLg,
            vertical: AppDimensions.spacingSm,
          ),
          child: Text(
            context.l10n.sharedWithYou,
            style: AppTextStyles.labelLarge.copyWith(
              color: colorScheme.primary,
            ),
          ),
        ),
        for (final shared in _pendingSharedTags)
          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingLg,
              vertical: AppDimensions.spacingXs,
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.primary
                    .withValues(alpha: AppDimensions.opacityLight),
                child: Icon(Icons.label,
                    color: colorScheme.primary, size: AppDimensions.iconSizeM),
              ),
              title: Text(shared.tagName),
              subtitle: Text(
                context.l10n.sharedByName(shared.sharedByDisplayName),
                style: AppTextStyles.bodySmall.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: FilledButton.tonal(
                onPressed: () => _importSharedTag(context, shared),
                child: Text(context.l10n.importTag),
              ),
            ),
          ),
        const SizedBox(height: AppDimensions.spacingMd),
        const Divider(),
      ],
    );
  }

  Widget _buildGroupSection(
    BuildContext context,
    PersonalTagViewModel viewModel,
    PersonalTagGroup group,
  ) {
    final tags = _sortTags(viewModel.getTagsForGroup(group.id), viewModel);

    return _buildTagSection(
      context,
      viewModel,
      title: group.name,
      tags: tags,
      groupId: group.id,
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: AppDimensions.iconSizeM),
        onSelected: (value) => _handleGroupAction(context, value, group),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: Text(context.l10n.commonRename),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete,
                  color: Theme.of(context).colorScheme.error),
              title: Text(context.l10n.personalTagDeleteGroup,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagSection(
    BuildContext context,
    PersonalTagViewModel viewModel, {
    required String title,
    required List<PersonalTag> tags,
    required String? groupId,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingLg,
            vertical: AppDimensions.spacingSm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
        ...tags.map((tag) => _buildTagTile(context, viewModel, tag)),
        if (tags.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingLg,
              vertical: AppDimensions.spacingMd,
            ),
            child: Text(
              context.l10n.personalTagGroupEmpty,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTagTile(
    BuildContext context,
    PersonalTagViewModel viewModel,
    PersonalTag tag,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final usageCount = viewModel.getUsageCount(tag.name);
    final ruleCount = tag.rules.length;
    final enabledRuleCount = tag.rules.where((r) => r.isEnabled).length;
    final hasActiveRules = enabledRuleCount > 0;
    final isUnused = usageCount == 0;

    return Semantics(
      label: context.l10n.personalTagTileSemantics(
          tag.name, usageCount, enabledRuleCount, ruleCount),
      button: true,
      child: Opacity(
        opacity: isUnused ? 0.6 : 1.0,
        child: ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: hasActiveRules
                    ? context.butleryColors.success
                        .withValues(alpha: AppDimensions.opacityLight)
                    : colorScheme.primary
                        .withValues(alpha: AppDimensions.opacityLight),
                child: Icon(
                  Icons.label,
                  color: hasActiveRules
                      ? context.butleryColors.success
                      : colorScheme.primary,
                  size: AppDimensions.iconSizeM,
                ),
              ),
              if (hasActiveRules)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: context.butleryColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 10,
                      color: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(tag.name),
          subtitle: Text(
            _buildSubtitle(context, usageCount, ruleCount, enabledRuleCount),
            style: AppTextStyles.bodySmall.copyWith(
              color: isUnused
                  ? colorScheme.onSurfaceVariant
                      .withValues(alpha: AppDimensions.opacityDark)
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _navigateToTagDetail(context, tag),
          onLongPress: () => _showTagOptions(context, tag),
        ),
      ),
    );
  }

  String _buildSubtitle(BuildContext context, int usageCount, int ruleCount,
      int enabledRuleCount) {
    final parts = <String>[];

    if (usageCount > 0) {
      parts.add(context.l10n.personalTagRecipeCount(usageCount));
    }

    if (ruleCount > 0) {
      if (enabledRuleCount == ruleCount) {
        parts.add(context.l10n.personalTagRuleCount(ruleCount));
      } else {
        parts.add(context.l10n
            .personalTagRuleCountActive(enabledRuleCount, ruleCount));
      }
    }

    return parts.isEmpty ? context.l10n.personalTagNoUsage : parts.join(' · ');
  }

  void _showRetagDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RetagProgressDialog(
        retagFunction: (onProgress) async {
          final taggingService = ServiceLocator.get<TaggingService>();
          final authService = ServiceLocator.get<AuthService>();
          final recipeRepo = ServiceLocator.get<RecipeRepository>();
          final recipeService = ServiceLocator.get<UnifiedRecipeService>();

          return await taggingService.retagUserRecipes(
            userId: authService.currentUser!.uid,
            getRecipes: () =>
                recipeRepo.fetchAllUserRecipes(authService.currentUser!.uid),
            saveRecipe: (recipe) => recipeService.personal.updateRecipe(recipe),
            onProgress: onProgress,
          );
        },
      ),
    );
  }

  void _navigateToTagDetail(BuildContext context, PersonalTag tag) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TagDetailView(tagId: tag.id),
      ),
    );
  }

  void _showTagOptions(BuildContext context, PersonalTag tag) {
    final hasRules = tag.rules.isNotEmpty;
    final enabledRuleCount = tag.rules.where((r) => r.isEnabled).length;
    final allRulesEnabled = enabledRuleCount == tag.rules.length;
    final allRulesDisabled = enabledRuleCount == 0;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLg),
              child: Row(
                children: [
                  const Icon(Icons.label, size: AppDimensions.iconSizeL),
                  const SizedBox(width: AppDimensions.spacingM),
                  Expanded(
                    child: Text(
                      tag.name,
                      style: AppTextStyles.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(context.l10n.commonShowDetails),
              onTap: () {
                Navigator.pop(sheetContext);
                _navigateToTagDetail(context, tag);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(context.l10n.commonEditName),
              onTap: () {
                Navigator.pop(sheetContext);
                _editTag(context, tag);
              },
            ),
            if (hasRules && !allRulesEnabled)
              ListTile(
                leading: Icon(Icons.play_arrow,
                    color: context.butleryColors.success),
                title: Text(context.l10n.personalTagEnableAllRules),
                subtitle: Text(context.l10n.personalTagRulesDisabled(
                    tag.rules.length - enabledRuleCount)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _toggleAllRules(context, tag, enable: true);
                },
              ),
            if (hasRules && !allRulesDisabled)
              ListTile(
                leading:
                    Icon(Icons.pause, color: context.butleryColors.warning),
                title: Text(context.l10n.personalTagDisableAllRules),
                subtitle:
                    Text(context.l10n.personalTagRulesActive(enabledRuleCount)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _toggleAllRules(context, tag, enable: false);
                },
              ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(context.l10n.commonShare),
              onTap: () {
                Navigator.pop(sheetContext);
                _shareTag(context, tag);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(context.l10n.personalTagMoveToGroup),
              onTap: () {
                Navigator.pop(sheetContext);
                _moveTagToGroup(context, tag);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.delete,
                  color: Theme.of(context).colorScheme.error),
              title: Text(context.l10n.personalTagDeleteTag,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(sheetContext);
                _deleteTag(context, tag);
              },
            ),
            const SizedBox(height: AppDimensions.spacingM),
          ],
        ),
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
        SnackBarUtils.showError(context, context.l10n.personalTagCouldNotShare);
      }
    }
  }

  Future<void> _toggleAllRules(
    BuildContext context,
    PersonalTag tag, {
    required bool enable,
  }) async {
    final viewModel = context.read<PersonalTagViewModel>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(enable
            ? context.l10n.personalTagEnableAllRulesConfirm
            : context.l10n.personalTagDisableAllRulesConfirm),
        content: Text(
          enable
              ? context.l10n
                  .personalTagEnableAllRulesMessage(tag.rules.length, tag.name)
              : context.l10n.personalTagDisableAllRulesMessage(
                  tag.rules.length, tag.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(enable
                ? context.l10n.commonEnable
                : context.l10n.commonDisable),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        for (final rule in tag.rules) {
          if (rule.isEnabled != enable) {
            await viewModel.toggleRuleEnabled(tag.id, rule.id);
          }
        }
        if (context.mounted) {
          SnackBarUtils.showSuccess(
            context,
            enable
                ? context.l10n.personalTagAllRulesEnabled
                : context.l10n.personalTagAllRulesDisabled,
          );
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(
              context, context.l10n.personalTagCouldNotChangeRules);
        }
      }
    }
  }

  Future<void> _createTag(BuildContext context) async {
    final viewModel = context.read<PersonalTagViewModel>();
    String tagName = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(context.l10n.personalTagCreateTag),
            content: TextField(
              onChanged: (v) => tagName = v,
              enabled: !isLoading,
              decoration: InputDecoration(
                labelText: context.l10n.personalTagNameLabel,
                hintText: context.l10n.personalTagNameHint,
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            actions: [
              TextButton(
                onPressed:
                    isLoading ? null : () => Navigator.pop(dialogContext),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final name = tagName.trim();
                        if (name.isEmpty) return;

                        final validationError =
                            viewModel.validateTagName(name);
                        if (validationError != null) {
                          if (context.mounted) {
                            SnackBarUtils.showError(
                                context, validationError);
                          }
                          return;
                        }

                        setState(() => isLoading = true);
                        final success =
                            await viewModel.createTag(name: name);

                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);

                        if (!context.mounted) return;
                        if (success) {
                          SnackBarUtils.showSuccess(
                              context, context.l10n.personalTagCreated);
                        } else {
                          SnackBarUtils.showError(
                            context,
                            viewModel.error ??
                                context.l10n.personalTagCouldNotCreate,
                          );
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.commonCreate),
              ),
            ],
          ),
        );
      },
    );
  }

  // BUG-022 FIX: All dialog methods execute ViewModel operations BEFORE
  // popping the dialog. This prevents Provider notifyListeners() from firing
  // during dialog disposal, which crashes on Flutter Web.

  Future<void> _createGroup(BuildContext context) async {
    final viewModel = context.read<PersonalTagViewModel>();
    String groupName = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(context.l10n.personalTagCreateGroup),
            content: TextField(
              onChanged: (v) => groupName = v,
              enabled: !isLoading,
              decoration: InputDecoration(
                labelText: context.l10n.personalTagGroupNameLabel,
                hintText: context.l10n.personalTagGroupNameHint,
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            actions: [
              TextButton(
                onPressed:
                    isLoading ? null : () => Navigator.pop(dialogContext),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final name = groupName.trim();
                        if (name.isEmpty) return;

                        setState(() => isLoading = true);
                        final success =
                            await viewModel.createGroup(name: name);

                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);

                        if (!context.mounted) return;
                        if (success) {
                          SnackBarUtils.showSuccess(
                              context, context.l10n.personalTagGroupCreated);
                        } else {
                          SnackBarUtils.showError(
                            context,
                            viewModel.error ??
                                context.l10n.personalTagCouldNotCreateGroup,
                          );
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.commonCreate),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editTag(BuildContext context, PersonalTag tag) async {
    final viewModel = context.read<PersonalTagViewModel>();
    String tagName = tag.name;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(context.l10n.personalTagEditTag),
            content: TextFormField(
              initialValue: tag.name,
              onChanged: (v) => tagName = v,
              enabled: !isLoading,
              decoration: InputDecoration(
                labelText: context.l10n.personalTagNameLabel,
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            actions: [
              TextButton(
                onPressed:
                    isLoading ? null : () => Navigator.pop(dialogContext),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final name = tagName.trim();
                        if (name.isEmpty) return;

                        setState(() => isLoading = true);
                        try {
                          final updated = tag.copyWith(name: name);
                          await viewModel.updateTag(updated);

                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);

                          if (!context.mounted) return;
                          SnackBarUtils.showSuccess(
                              context, context.l10n.personalTagUpdated);
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);

                          if (!context.mounted) return;
                          SnackBarUtils.showError(context, e.toString());
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.commonSave),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteTag(BuildContext context, PersonalTag tag) async {
    final viewModel = context.read<PersonalTagViewModel>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(context.l10n.personalTagDeleteTagConfirm),
            content: Text(context.l10n.personalTagDeleteTagMessage(tag.name)),
            actions: [
              TextButton(
                onPressed:
                    isLoading ? null : () => Navigator.pop(dialogContext),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        setState(() => isLoading = true);
                        try {
                          await viewModel.deleteTag(tag.id);

                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);

                          if (!context.mounted) return;
                          SnackBarUtils.showSuccess(
                              context, context.l10n.personalTagDeleted);
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);

                          if (!context.mounted) return;
                          SnackBarUtils.showError(context, e.toString());
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.commonDelete),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _moveTagToGroup(BuildContext context, PersonalTag tag) async {
    final viewModel = context.read<PersonalTagViewModel>();
    final groups = viewModel.groups;
    const createNewSentinel = '__create_new__';

    final selectedGroupId = await showDialog<String?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.personalTagMoveToGroup),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: ListTile(
              leading: const Icon(Icons.folder_off),
              title: Text(context.l10n.personalTagNoGroup),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          for (final group in groups)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, group.id),
              child: ListTile(
                leading: const Icon(Icons.folder),
                title: Text(group.name),
                contentPadding: EdgeInsets.zero,
                selected: tag.groupId == group.id,
              ),
            ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, createNewSentinel),
            child: ListTile(
              leading: const Icon(Icons.add),
              title: Text(context.l10n.personalTagCreateNewGroup),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );

    if (selectedGroupId == null || !context.mounted) return;

    if (selectedGroupId == createNewSentinel) {
      await _createGroupAndMoveTag(context, tag);
      return;
    }

    try {
      final groupId = selectedGroupId.isEmpty ? null : selectedGroupId;
      await viewModel.moveTagToGroup(tag.id, groupId);
      if (context.mounted) {
        SnackBarUtils.showSuccess(context, context.l10n.personalTagMoved);
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, e.toString());
      }
    }
  }

  Future<void> _createGroupAndMoveTag(
    BuildContext context,
    PersonalTag tag,
  ) async {
    final viewModel = context.read<PersonalTagViewModel>();
    String groupName = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(context.l10n.personalTagCreateNewGroup),
            content: TextField(
              onChanged: (v) => groupName = v,
              enabled: !isLoading,
              decoration: InputDecoration(
                labelText: context.l10n.personalTagGroupNameLabel,
                hintText: context.l10n.personalTagGroupNameHint,
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            actions: [
              TextButton(
                onPressed:
                    isLoading ? null : () => Navigator.pop(dialogContext),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final name = groupName.trim();
                        if (name.isEmpty) return;

                        setState(() => isLoading = true);
                        try {
                          final success =
                              await viewModel.createGroup(name: name);
                          if (success) {
                            final newGroup = viewModel.groups.lastOrNull;
                            if (newGroup != null) {
                              await viewModel.moveTagToGroup(
                                  tag.id, newGroup.id);
                            }
                          }

                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);

                          if (!context.mounted) return;
                          if (success) {
                            SnackBarUtils.showSuccess(
                              context,
                              context
                                  .l10n.personalTagGroupCreatedAndTagMoved,
                            );
                          }
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);

                          if (!context.mounted) return;
                          SnackBarUtils.showError(context, e.toString());
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.commonCreate),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleGroupAction(
    BuildContext context,
    String action,
    PersonalTagGroup group,
  ) async {
    final viewModel = context.read<PersonalTagViewModel>();

    switch (action) {
      case 'rename':
        String groupName = group.name;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            bool isLoading = false;
            return StatefulBuilder(
              builder: (context, setState) => AlertDialog(
                title: Text(context.l10n.personalTagRenameGroup),
                content: TextFormField(
                  initialValue: group.name,
                  onChanged: (v) => groupName = v,
                  enabled: !isLoading,
                  decoration: InputDecoration(
                      labelText: context.l10n.personalTagGroupNameLabel),
                  autofocus: true,
                ),
                actions: [
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: Text(context.l10n.commonCancel),
                  ),
                  FilledButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final name = groupName.trim();
                            if (name.isEmpty) return;

                            setState(() => isLoading = true);
                            try {
                              final updated =
                                  group.copyWith(name: name);
                              await viewModel.updateGroup(updated);

                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);

                              if (!context.mounted) return;
                              SnackBarUtils.showSuccess(context,
                                  context.l10n.personalTagGroupUpdated);
                            } catch (e) {
                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);

                              if (!context.mounted) return;
                              SnackBarUtils.showError(
                                  context, e.toString());
                            }
                          },
                    child: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : Text(context.l10n.commonSave),
                  ),
                ],
              ),
            );
          },
        );
        break;

      case 'delete':
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            bool isLoading = false;
            return StatefulBuilder(
              builder: (context, setState) => AlertDialog(
                title: Text(context.l10n.personalTagDeleteGroupConfirm),
                content: Text(
                    context.l10n.personalTagDeleteGroupMessage(group.name)),
                actions: [
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: Text(context.l10n.commonCancel),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.error),
                    onPressed: isLoading
                        ? null
                        : () async {
                            setState(() => isLoading = true);
                            try {
                              await viewModel.deleteGroup(group.id);

                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);

                              if (!context.mounted) return;
                              SnackBarUtils.showSuccess(context,
                                  context.l10n.personalTagGroupDeleted);
                            } catch (e) {
                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);

                              if (!context.mounted) return;
                              SnackBarUtils.showError(
                                  context, e.toString());
                            }
                          },
                    child: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : Text(context.l10n.commonDelete),
                  ),
                ],
              ),
            );
          },
        );
        break;
    }
  }
}
