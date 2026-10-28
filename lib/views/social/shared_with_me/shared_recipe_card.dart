// lib/views/social/shared_with_me/shared_recipe_card.dart

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/stored_display_name.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_actions.dart';
import 'package:butlery/widgets/common/recipe_row_meta.dart';
import 'package:butlery/widgets/common/recipe_thumb.dart';
import 'package:butlery/widgets/social/shared_content_row.dart';
import 'package:butlery/widgets/social/shared_receive_sheet.dart';

/// A shared recipe as a [SharedContentRow]. On one friend's page the sharer
/// is the heading, so the line under the name carries the time and the
/// cooking time instead of the name.
class SharedRecipeCard {
  static Widget build(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedRecipe sharedRecipe, {
    bool byFriend = false,
  }) {
    final l10n = context.l10n;
    final recipes = viewModel.recipeViewModel;
    final isRead = recipes.isRecipeViewed(sharedRecipe);
    final ago = ContextualTimeFormatter.standard(
      sharedRecipe.sharedAt,
      localeName: Localizations.localeOf(context).toString(),
    );

    final saved = recipes.isRecipeImported(sharedRecipe);
    final fromLine = l10n.sharedFromNameAgo(
      storedNameOr(sharedRecipe.sharedByDisplayName, l10n.displayUnknownUser),
      ago,
    );

    return SharedContentRow(
      leading: RecipeThumb(imageUrl: sharedRecipe.recipeImageUrl),
      title: sharedRecipe.recipeTitle,
      subtitle: byFriend ? null : fromLine,
      meta: byFriend
          ? RecipeRowMeta(
              lead: l10n.sharedSharedAgo(ago),
              minutes: sharedRecipe.recipeTimeMinutes,
            )
          : null,
      message: sharedRecipe.shareMessage,
      unread: !isRead,
      saved: saved,
      saving: recipes.isOperating,
      framed: byFriend,
      onSave: () =>
          SharedContentActions.importRecipe(context, viewModel, sharedRecipe),
      onOpen: () async {
        if (saved) {
          return SharedContentActions.viewRecipe(
            context,
            viewModel,
            sharedRecipe,
            isRead: isRead,
          );
        }
        if (!isRead) recipes.markAsViewed(sharedRecipe);
        final choice = await showSharedReceiveSheet(
          context,
          title: sharedRecipe.recipeTitle,
          fromLine: fromLine,
          permission: sharedRecipe.permission,
          message: sharedRecipe.shareMessage,
        );
        if (!context.mounted || choice == null) return;
        return switch (choice) {
          SharedReceiveChoice.accept => SharedContentActions.importRecipe(
            context,
            viewModel,
            sharedRecipe,
          ),
          SharedReceiveChoice.view => SharedContentActions.viewRecipe(
            context,
            viewModel,
            sharedRecipe,
            isRead: isRead,
          ),
        };
      },
      onActions: () => showSharedContentActions(
        context,
        title: sharedRecipe.recipeTitle,
        onReply: () => SharedContentActions.replyToSender(
          context,
          userId: sharedRecipe.sharedByUserId,
          // Persisted on the conversation, so no display label.
          displayName: knownStoredName(
            sharedRecipe.sharedByDisplayName,
          ).orEmpty(),
        ),
        onDismiss: () => SharedContentActions.dismissRecipe(
          context,
          viewModel,
          sharedRecipe,
        ),
        onUnshare: () =>
            SharedContentActions.unshareRecipe(context, sharedRecipe),
      ),
    );
  }
}
