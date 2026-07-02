// lib/views/recipe_detail/handlers/recipe_management_handler.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/share_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/views/family/who_is_eating_sheet.dart';
import 'package:butlery/views/family/family_rating_entry_view.dart';

/// Recipe management action handler
/// Handles recipe CRUD operations: delete, edit, mark as cooked, and share.
class RecipeManagementHandler {
  /// Delete recipe with confirmation dialog.
  ///
  /// BUT-927: matches the bulk-delete UX in `RecipeDeleteManager` —
  /// optimistically remove the recipe from the local list, navigate back,
  /// show a 5-second snackbar with an Undo action, and only commit the
  /// Firestore delete + analytics after the timer fires (or skip both if
  /// the user pressed Undo).
  static Future<void> deleteRecipe(
    BuildContext context, {
    required VoidCallback onSuccess,
    required VoidCallback popNavigation,
  }) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final confirmed = await CommonDialogActions.showRecipeDeleteConfirmation(
      context: context,
      recipeName: viewModel.recipe.title,
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    // Capture everything we need before popping the route — once the detail
    // view is gone, `context` is no longer mounted and `viewModel` may be
    // disposed by the time the timer fires.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final recipeService = ServiceLocator.get<UnifiedRecipeService>();
    final analyticsService = ServiceLocator.get<AnalyticsService>();
    final recipe = viewModel.recipe;

    final originalIndex = recipeService.optimisticRemoveWithIndex(recipe.id);

    popNavigation();
    onSuccess();

    var undone = false;
    final timer = Timer(const Duration(seconds: 5), () async {
      if (undone) return;
      try {
        // Note: `optimisticRemoveWithIndex` already stripped the recipe
        // from the local list. `recipeService.deleteRecipe` issues the
        // Firestore delete + fires the BUT-893 weekly-menu cascade; its
        // `recipes.removeWhere` step is a no-op at this point.
        final committed = await recipeService.deleteRecipe(recipe.id);
        if (!committed) {
          AppLogger.warning(
            'BUT-927 delete commit returned false: ${recipe.id}',
          );
          return;
        }
        await analyticsService.logRecipeDeleted(
          recipeId: recipe.id,
          mealType: recipe.mealType,
          isPersonal: recipe.isPersonal,
          createdAt: recipe.createdAt,
        );
        await analyticsService.setUserProperties(
          recipeCount: recipeService.recipes.length,
        );
      } catch (e, st) {
        AppLogger.error('BUT-927 delete commit failed: $e\n$st');
      }
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.recipeDeleted),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: l10n.commonUndo,
          onPressed: () {
            undone = true;
            timer.cancel();
            recipeService.optimisticRestoreAt(recipe, originalIndex);
          },
        ),
      ),
    );
  }

  /// Navigate to edit recipe view and refresh recipe on return
  static Future<void> editRecipe(BuildContext context) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();

    try {
      final result = await Navigator.pushNamed(
        context,
        Routes.editRecipe,
        arguments: viewModel.recipe,
      );

      // Edit view pops with `true` after a successful save — refresh local state
      if (result == true && context.mounted) {
        final recipeService = ServiceLocator.get<UnifiedRecipeService>();
        final updated = recipeService.getRecipeById(viewModel.recipe.id);
        if (updated != null) {
          viewModel.updateRecipe(updated);
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(context, context.l10n.recipeCouldNotOpenEditor);
    }
  }

  /// Mark recipe as cooked
  static Future<void> markAsCooked(BuildContext context) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();

    // Already logged today → keep the neutral message and skip the picker.
    if (viewModel.wasCookedToday) {
      SnackBarUtils.showInfo(context, context.l10n.recipeAlreadyCookedToday);
      return;
    }

    // Ask who ate. Returns null when dismissed (log nothing), a "skipped"
    // result for "hoppa över" (log with no attendance), or the picked members.
    final who = await showWhoIsEatingSheet(
      context,
      recipeTitle: viewModel.recipe.title,
    );
    if (who == null || !context.mounted) return;

    try {
      // markAsCooked returns false when nothing was recorded — most commonly
      // because the recipe was already logged today (per-day dedup). Only show
      // success on a real write; otherwise a neutral "already logged" message.
      final recorded = await viewModel.markAsCooked(
        attendeeMemberIds: who.attendeeMemberIds,
      );
      if (!context.mounted) return;
      if (recorded) {
        // BUT-1360: offline, the cook event is queued locally — tell the user
        // it'll sync rather than implying it already reached the server.
        if (!SnackBarUtils.showPendingSyncIfOffline(context)) {
          SnackBarUtils.showSuccess(context, context.l10n.recipeMarkedAsCooked);
        }
        // Auto-chain the family rating entry for the diners who ate. Only when
        // attendance was actually picked — a solo household ("hoppa över" /
        // skipped) gets no redundant rating screen.
        if (!who.skipped && who.attendeeMemberIds.isNotEmpty) {
          await showFamilyRatingEntry(
            context,
            recipeId: viewModel.recipe.id,
            recipeTitle: viewModel.recipe.title,
            presentMemberIds: who.attendeeMemberIds,
          );
        }
      } else {
        SnackBarUtils.showInfo(context, context.l10n.recipeAlreadyCookedToday);
      }
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(context, context.l10n.recipeCouldNotMarkAsCooked);
    }
  }

  /// Open the family rating entry manually (the "Betygsätt som familj" button
  /// on the recipe detail). No attendance context → rate the whole roster.
  static Future<void> rateAsFamily(BuildContext context) async {
    if (!context.mounted) return;
    final viewModel = context.read<RecipeDetailViewModel>();
    await showFamilyRatingEntry(
      context,
      recipeId: viewModel.recipe.id,
      recipeTitle: viewModel.recipe.title,
    );
  }

  /// Share recipe via share service
  static Future<void> shareRecipe(BuildContext context) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final shareService = ServiceLocator.get<ShareService>();

    try {
      await shareService.shareRecipe(viewModel.recipe);
      if (!context.mounted) return;
      SnackBarUtils.showSuccess(context, context.l10n.recipeShared);
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(context, context.l10n.recipeCouldNotShare);
    }
  }

  /// Toggle collaborative editing on a recipe.
  /// Shows enable dialog (friend picker) or disable confirmation based on current state.
  static Future<void> toggleCollaboration(BuildContext context) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final recipe = viewModel.recipe;

    if (recipe.isCollaborative) {
      await _confirmDisableCollaboration(context, recipe);
    } else {
      await _showEnableCollaborationDialog(context, recipe);
    }
  }

  /// Show dialog to select friends as collaborators, then enable collaboration
  static Future<void> _showEnableCollaborationDialog(
    BuildContext context,
    Recipe recipe,
  ) async {
    final friendsService = ServiceLocator.get<UnifiedFriendsService>();
    final friends = friendsService.friendsList;

    if (friends.isEmpty) {
      SnackBarUtils.showError(context, context.l10n.collaborationNoFriends);
      return;
    }

    final selectedIds = <String>{};

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogCs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(context.l10n.collaborationEnableTitle),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView(
                children: friends
                    .map(
                      (friend) => CheckboxListTile(
                        title: Text(friend.displayName),
                        subtitle: friend.email.isNotEmpty
                            ? Text(friend.email)
                            : null,
                        value: selectedIds.contains(friend.uid),
                        activeColor: dialogCs.primary,
                        onChanged: (v) => setDialogState(() {
                          if (v == true) {
                            selectedIds.add(friend.uid);
                          } else {
                            selectedIds.remove(friend.uid);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.l10n.commonCancel),
              ),
              TextButton(
                onPressed: selectedIds.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: Text(context.l10n.commonEnable),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true && selectedIds.isNotEmpty) {
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      final success = await recipeService.realtime.enableCollaborativeEditing(
        recipe.id,
        selectedIds.toList(),
      );

      if (!context.mounted) return;
      if (success) {
        SnackBarUtils.showSuccess(context, context.l10n.collaborationEnabled);
      } else {
        SnackBarUtils.showError(
          context,
          context.l10n.collaborationCouldNotEnable,
        );
      }
    }
  }

  /// Show confirmation dialog and disable collaboration
  static Future<void> _confirmDisableCollaboration(
    BuildContext context,
    Recipe recipe,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.collaborationDeactivateTitle),
        content: Text(context.l10n.collaborationDeactivateMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.commonDeactivate),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      final success = await recipeService.realtime.disableCollaborativeEditing(
        recipe.id,
      );

      if (!context.mounted) return;
      if (success) {
        SnackBarUtils.showSuccess(
          context,
          context.l10n.collaborationDeactivated,
        );
      } else {
        SnackBarUtils.showError(
          context,
          context.l10n.collaborationCouldNotDeactivate,
        );
      }
    }
  }
}
