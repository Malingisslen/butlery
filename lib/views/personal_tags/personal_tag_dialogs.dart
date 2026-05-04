/// Dialog and bottom sheet methods for the PersonalTagsView.
///
/// Extracted to keep the main view under 500 lines.
/// All methods are static and take BuildContext + dependencies as parameters.
/// BUG-022 FIX: ViewModel operations execute BEFORE popping dialogs to prevent
/// Provider notifyListeners() from firing during dialog disposal on Flutter Web.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/views/tag_detail_view.dart';
import 'package:butlery/widgets/common/dialogs/retag_progress_dialog.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';

/// Static helper class for all dialogs and bottom sheets in PersonalTagsView.
abstract final class PersonalTagDialogs {
  /// Shows the retag-all-recipes progress dialog.
  static void showRetagDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RetagProgressDialog(
        retagFunction: (onProgress) async {
          final taggingService = ServiceLocator.get<TaggingService>();
          final authService = ServiceLocator.get<AuthService>();
          final recipeService = ServiceLocator.get<UnifiedRecipeService>();

          return await taggingService.retagUserRecipes(
            userId: authService.currentUser!.uid,
            getRecipes: () => recipeService.personal
                .fetchAllUserRecipes(authService.currentUser!.uid),
            saveRecipe: (recipe) => recipeService.personal.updateRecipe(recipe),
            onProgress: onProgress,
          );
        },
      ),
    );
  }

  /// Shows a bottom sheet with tag action options.
  static void showTagOptionsSheet(
    BuildContext context,
    PersonalTag tag,
  ) {
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
                showEditTagDialog(context, tag);
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
                  showToggleAllRulesDialog(context, tag, enable: true);
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
                  showToggleAllRulesDialog(context, tag, enable: false);
                },
              ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(context.l10n.commonShare),
              onTap: () {
                Navigator.pop(sheetContext);
                showShareTagDialog(context, tag);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(context.l10n.personalTagMoveToGroup),
              onTap: () {
                Navigator.pop(sheetContext);
                showMoveTagToGroupDialog(context, tag);
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
                showDeleteTagDialog(context, tag);
              },
            ),
            const SizedBox(height: AppDimensions.spacingM),
          ],
        ),
      ),
    );
  }

  /// Shows the share tag dialog.
  static Future<void> showShareTagDialog(
    BuildContext context,
    PersonalTag tag,
  ) async {
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

  /// Shows confirmation dialog for toggling all rules on a tag.
  static Future<void> showToggleAllRulesDialog(
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

  /// Shows a dialog to create a new tag.
  static Future<void> showCreateTagDialog(BuildContext context) async {
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

                        final validationError = viewModel.validateTagName(name);
                        if (validationError != null) {
                          if (context.mounted) {
                            SnackBarUtils.showError(context, validationError);
                          }
                          return;
                        }

                        setState(() => isLoading = true);

                        final exists = await viewModel.tagNameExists(name);
                        if (exists) {
                          setState(() => isLoading = false);
                          if (context.mounted) {
                            SnackBarUtils.showError(
                                context, context.l10n.tagAlreadyExists);
                          }
                          return;
                        }

                        final success = await viewModel.createTag(name: name);

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

  /// Shows a dialog to create a new group.
  static Future<void> showCreateGroupDialog(BuildContext context) async {
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
                        final success = await viewModel.createGroup(name: name);

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

  /// Shows a dialog to edit a tag name.
  static Future<void> showEditTagDialog(
    BuildContext context,
    PersonalTag tag,
  ) async {
    final viewModel = context.read<PersonalTagViewModel>();
    String tagName = tag.name;

    // BUT-586: wrap in Form + GlobalKey + FormValidators.required so the
    // empty-name path surfaces an inline error instead of silently no-op-ing
    // when the user taps Save.
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(context.l10n.personalTagEditTag),
            content: Form(
              key: formKey,
              child: TextFormField(
                initialValue: tag.name,
                onChanged: (v) => tagName = v,
                enabled: !isLoading,
                decoration: InputDecoration(
                  labelText: context.l10n.personalTagNameLabel,
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                validator: FormValidators.required(
                  context.l10n.personalTagNameLabel,
                ),
              ),
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
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        final name = tagName.trim();

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
                          SnackBarUtils.showUserFriendlyError(context, e);
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

  /// Shows a confirmation dialog to delete a tag.
  static Future<void> showDeleteTagDialog(
    BuildContext context,
    PersonalTag tag,
  ) async {
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
                          SnackBarUtils.showUserFriendlyError(context, e);
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

  /// Shows a dialog to move a tag to a different group.
  static Future<void> showMoveTagToGroupDialog(
    BuildContext context,
    PersonalTag tag,
  ) async {
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
      await _showCreateGroupAndMoveTagDialog(context, tag);
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
        SnackBarUtils.showUserFriendlyError(context, e);
      }
    }
  }

  /// Handles group actions (rename/delete) from the group popup menu.
  static Future<void> handleGroupAction(
    BuildContext context,
    String action,
    PersonalTagGroup group,
  ) async {
    switch (action) {
      case 'rename':
        await _showRenameGroupDialog(context, group);
      case 'delete':
        await _showDeleteGroupDialog(context, group);
    }
  }

  static Future<void> _showCreateGroupAndMoveTagDialog(
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
                              context.l10n.personalTagGroupCreatedAndTagMoved,
                            );
                          }
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);

                          if (!context.mounted) return;
                          SnackBarUtils.showUserFriendlyError(context, e);
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

  static Future<void> _showRenameGroupDialog(
    BuildContext context,
    PersonalTagGroup group,
  ) async {
    final viewModel = context.read<PersonalTagViewModel>();
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
                          final updated = group.copyWith(name: name);
                          await viewModel.updateGroup(updated);

                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);

                          if (!context.mounted) return;
                          SnackBarUtils.showSuccess(
                              context, context.l10n.personalTagGroupUpdated);
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);

                          if (!context.mounted) return;
                          SnackBarUtils.showUserFriendlyError(context, e);
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

  static Future<void> _showDeleteGroupDialog(
    BuildContext context,
    PersonalTagGroup group,
  ) async {
    final viewModel = context.read<PersonalTagViewModel>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(context.l10n.personalTagDeleteGroupConfirm),
            content:
                Text(context.l10n.personalTagDeleteGroupMessage(group.name)),
            actions: [
              TextButton(
                onPressed:
                    isLoading ? null : () => Navigator.pop(dialogContext),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: isLoading
                    ? null
                    : () async {
                        setState(() => isLoading = true);
                        try {
                          await viewModel.deleteGroup(group.id);

                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);

                          if (!context.mounted) return;
                          SnackBarUtils.showSuccess(
                              context, context.l10n.personalTagGroupDeleted);
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);

                          if (!context.mounted) return;
                          SnackBarUtils.showUserFriendlyError(context, e);
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

  static void _navigateToTagDetail(BuildContext context, PersonalTag tag) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TagDetailView(tagId: tag.id),
      ),
    );
  }
}
