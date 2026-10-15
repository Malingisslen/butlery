/// Dialog and bottom sheet methods for the PersonalTagsView.
///
/// Extracted to keep the main view under 500 lines.
/// All methods are static and take BuildContext + dependencies as parameters.
/// BUG-022 FIX: ViewModel operations execute BEFORE popping dialogs to prevent
/// Provider notifyListeners() from firing during dialog disposal on Flutter Web.
library;

import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/views/personal_tags/personal_tag_bulk_dialogs.dart';
import 'package:butlery/views/personal_tags/personal_tag_name_dialog.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/dialogs/destructive_confirmation_dialog.dart';
import 'package:butlery/widgets/common/dialogs/retag_progress_dialog.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/widgets/common/share_dialog/share_sheet.dart';

enum _TagsBarAction { sort, applyRules }

/// Static helper class for all dialogs and bottom sheets in PersonalTagsView.
abstract final class PersonalTagDialogs {
  /// BUT-1185: merge dialog for the multi-select flow. Delegates to
  /// [PersonalTagBulkDialogs] (kept separate to respect the 500-line limit).
  static Future<void> showMergeDialog(
    BuildContext context,
    List<PersonalTag> selectedTags,
  ) => PersonalTagBulkDialogs.showMergeDialog(context, selectedTags);

  /// BUT-1185: bulk-delete confirmation for the multi-select flow.
  static Future<void> showBulkDeleteDialog(
    BuildContext context,
    List<PersonalTag> selectedTags,
  ) => PersonalTagBulkDialogs.showBulkDeleteDialog(context, selectedTags);

  /// The bar's "more" sheet: sorting and applying the rules to every recipe.
  static Future<void> showMoreActions(
    BuildContext context, {
    required Future<void> Function() onSort,
  }) async {
    final action = await showButleryListSheet<_TagsBarAction>(
      context,
      title: context.l10n.rootBarMoreActions,
      rows: (sheetContext) => [
        ButleryListRow(
          label: context.l10n.commonSort,
          leading: ButleryIcons.arrowUpDown,
          onTap: () => Navigator.pop(sheetContext, _TagsBarAction.sort),
        ),
        ButleryListRow(
          label: context.l10n.personalTagApplyRulesToAll,
          leading: ButleryIcons.refreshCw,
          onTap: () => Navigator.pop(sheetContext, _TagsBarAction.applyRules),
        ),
      ],
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _TagsBarAction.applyRules:
        showRetagDialog(context);
      case _TagsBarAction.sort:
        await onSort();
    }
  }

  /// Shows the retag-all-recipes progress dialog.
  static void showRetagDialog(BuildContext context) {
    showButleryDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RetagProgressDialog(
        retagFunction: (onProgress) async {
          final taggingService = ServiceLocator.get<TaggingService>();
          final authService = ServiceLocator.get<AuthService>();
          final recipeService = ServiceLocator.get<UnifiedRecipeService>();

          return await taggingService.retagUserRecipes(
            userId: authService.currentUser!.uid,
            getRecipes: () => recipeService.personal.fetchAllUserRecipes(
              authService.currentUser!.uid,
            ),
            saveRecipe: (recipe) => recipeService.personal.updateRecipe(recipe),
            onProgress: onProgress,
          );
        },
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
      if (!friendsService.isInitialized) await friendsService.initialize();
      if (!context.mounted) return;
      final friends = friendsService.friends;
      final groups = friendsService.categoriesList;

      final viewModel = UniversalShareDialogViewModel(
        socialRecipeCoordinator: ServiceLocator.get<SocialRecipeCoordinator>(),
        shoppingService: ServiceLocator.get<UnifiedShoppingService>(),
      );

      if (!context.mounted) return;

      await showUniversalShareSheet(
        context,
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
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.personalTagCouldNotShare,
        );
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

    final confirmed = await showButleryDialog<bool>(
      context: context,
      builder: (context) => ButleryDialog.confirm(
        title: enable
            ? context.l10n.personalTagEnableAllRulesConfirm
            : context.l10n.personalTagDisableAllRulesConfirm,
        message: enable
            ? context.l10n.personalTagEnableAllRulesMessage(
                tag.rules.length,
                tag.name,
              )
            : context.l10n.personalTagDisableAllRulesMessage(
                tag.rules.length,
                tag.name,
              ),
        primaryLabel: enable
            ? context.l10n.commonEnable
            : context.l10n.commonDisable,
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
          SnackBarUtils.showFailure(
            context,
            what: context.l10n.personalTagCouldNotChangeRules,
          );
        }
      }
    }
  }

  /// Shows a dialog to create a new tag.
  static Future<void> showCreateTagDialog(BuildContext context) async {
    final l10n = context.l10n;
    final viewModel = context.read<PersonalTagViewModel>();
    final created = await showButleryDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PersonalTagNameDialog(
        title: l10n.personalTagCreateTag,
        fieldLabel: l10n.personalTagNameLabel,
        hint: l10n.personalTagNameHint,
        confirmLabel: l10n.commonCreate,
        emptyMessage: l10n.validationTagNameRequired,
        submit: (name) async {
          final invalid = viewModel.validateTagName(name);
          if (invalid != null) return invalid;
          if (await viewModel.tagNameExists(name)) {
            return l10n.tagAlreadyExists;
          }
          if (await viewModel.createTag(name: name)) return null;
          return viewModel.error ?? l10n.personalTagCouldNotCreate;
        },
      ),
    );
    if (created == null || !context.mounted) return;
    SnackBarUtils.showSuccess(context, l10n.personalTagCreated);
  }

  /// Shows a dialog to create a new group.
  static Future<void> showCreateGroupDialog(BuildContext context) async {
    final l10n = context.l10n;
    final viewModel = context.read<PersonalTagViewModel>();
    final created = await showButleryDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PersonalTagNameDialog(
        title: l10n.personalTagCreateGroup,
        fieldLabel: l10n.personalTagGroupNameLabel,
        hint: l10n.personalTagGroupNameHint,
        confirmLabel: l10n.commonCreate,
        emptyMessage: l10n.validationGroupNameRequired,
        submit: (name) async {
          if (await viewModel.createGroup(name: name)) return null;
          return viewModel.error ?? l10n.personalTagCouldNotCreateGroup;
        },
      ),
    );
    if (created == null || !context.mounted) return;
    SnackBarUtils.showSuccess(context, l10n.personalTagGroupCreated);
  }

  /// Shows a dialog to move a tag to a different group.
  static Future<void> showMoveTagToGroupDialog(
    BuildContext context,
    PersonalTag tag,
  ) async {
    final viewModel = context.read<PersonalTagViewModel>();
    final groups = viewModel.groups;
    const createNewSentinel = '__create_new__';

    final selectedGroupId = await showButleryListSheet<String>(
      context,
      title: context.l10n.personalTagMoveToGroup,
      rows: (sheetContext) => [
        ButleryListRow(
          label: context.l10n.personalTagNoGroup,
          leading: tag.groupId == null ? ButleryIcons.check : null,
          onTap: () => Navigator.pop(sheetContext, ''),
        ),
        for (final group in groups)
          ButleryListRow(
            label: group.name,
            leading: tag.groupId == group.id ? ButleryIcons.check : null,
            onTap: () => Navigator.pop(sheetContext, group.id),
          ),
        ButleryListRow(
          label: context.l10n.personalTagCreateNewGroup,
          leading: ButleryIcons.plus,
          onTap: () => Navigator.pop(sheetContext, createNewSentinel),
        ),
      ],
    );

    if (selectedGroupId == null || !context.mounted) return;

    if (selectedGroupId == createNewSentinel) {
      await _showCreateGroupAndMoveTagDialog(context, tag);
      return;
    }

    final groupId = selectedGroupId.isEmpty ? null : selectedGroupId;
    final moved = await viewModel.moveTagToGroup(tag.id, groupId);
    if (!context.mounted) return;
    if (moved) {
      SnackBarUtils.showSuccess(context, context.l10n.personalTagMoved);
    } else {
      SnackBarUtils.showFailure(
        context,
        what: viewModel.error ?? context.l10n.personalTagCouldNotMove,
      );
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
    final l10n = context.l10n;
    final viewModel = context.read<PersonalTagViewModel>();
    final created = await showButleryDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PersonalTagNameDialog(
        title: l10n.personalTagCreateNewGroup,
        fieldLabel: l10n.personalTagGroupNameLabel,
        hint: l10n.personalTagGroupNameHint,
        confirmLabel: l10n.commonCreate,
        emptyMessage: l10n.validationGroupNameRequired,
        submit: (name) async {
          // A retry after a failed move must not create the group again.
          var group = viewModel.groups.where((g) => g.name == name).lastOrNull;
          if (group == null) {
            if (!await viewModel.createGroup(name: name)) {
              return viewModel.error ?? l10n.personalTagCouldNotCreateGroup;
            }
            group = viewModel.groups.where((g) => g.name == name).lastOrNull;
          }
          if (group == null ||
              !await viewModel.moveTagToGroup(tag.id, group.id)) {
            return viewModel.error ?? l10n.personalTagCouldNotMove;
          }
          return null;
        },
      ),
    );
    if (created == null || !context.mounted) return;
    SnackBarUtils.showSuccess(
      context,
      l10n.personalTagGroupCreatedAndTagMoved,
    );
  }

  static Future<void> _showRenameGroupDialog(
    BuildContext context,
    PersonalTagGroup group,
  ) async {
    final l10n = context.l10n;
    final viewModel = context.read<PersonalTagViewModel>();
    final renamed = await showButleryDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PersonalTagNameDialog(
        title: l10n.personalTagRenameGroup,
        fieldLabel: l10n.personalTagGroupNameLabel,
        initialName: group.name,
        confirmLabel: l10n.commonSave,
        emptyMessage: l10n.validationGroupNameRequired,
        submit: (name) async {
          if (await viewModel.updateGroup(group.copyWith(name: name))) {
            return null;
          }
          return viewModel.error ?? l10n.errorCouldNotUpdateGroup;
        },
      ),
    );
    if (renamed == null || !context.mounted) return;
    SnackBarUtils.showSuccess(context, l10n.personalTagGroupUpdated);
  }

  static Future<void> _showDeleteGroupDialog(
    BuildContext context,
    PersonalTagGroup group,
  ) async {
    final viewModel = context.read<PersonalTagViewModel>();
    final deleted = await DestructiveConfirmationDialog.show(
      context,
      title: context.l10n.personalTagDeleteGroupConfirm,
      message: context.l10n.personalTagDeleteGroupMessage(group.name),
      primaryActionText: context.l10n.personalTagDeleteGroup,
      onConfirm: () async {
        // deleteGroup reports a failure as false, not by throwing; the
        // dialog shows its inline error with Försök igen only on a throw.
        if (!await viewModel.deleteGroup(group.id)) {
          throw StateError('Delete personal tag group failed');
        }
      },
    );
    if (deleted != true || !context.mounted) return;
    SnackBarUtils.showSuccess(context, context.l10n.personalTagGroupDeleted);
  }
}
