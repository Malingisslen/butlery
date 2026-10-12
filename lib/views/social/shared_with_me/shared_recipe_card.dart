// lib/views/social/shared_with_me/shared_recipe_card.dart

import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_actions.dart';
import 'package:butlery/widgets/common/recipe_row_meta.dart';
import 'package:butlery/widgets/common/recipe_thumb.dart';
import 'package:butlery/widgets/social/shared_content_row.dart';

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
    final ago = timeago.format(sharedRecipe.sharedAt, locale: 'sv');

    return SharedContentRow(
      leading: RecipeThumb(imageUrl: sharedRecipe.recipeImageUrl),
      title: sharedRecipe.recipeTitle,
      subtitle: byFriend
          ? null
          : l10n.sharedFromNameAgo(sharedRecipe.sharedByDisplayName, ago),
      meta: byFriend
          ? RecipeRowMeta(
              lead: l10n.sharedSharedAgo(ago),
              minutes: sharedRecipe.recipeTimeMinutes,
            )
          : null,
      message: sharedRecipe.shareMessage,
      unread: !isRead,
      saved: recipes.isRecipeImported(sharedRecipe),
      saving: recipes.isOperating,
      framed: byFriend,
      onSave: () =>
          SharedContentActions.importRecipe(context, viewModel, sharedRecipe),
      onOpen: () => SharedContentActions.viewRecipe(
        context,
        viewModel,
        sharedRecipe,
        isRead: isRead,
      ),
      onActions: () => showSharedContentActions(
        context,
        title: sharedRecipe.recipeTitle,
        onReply: () => SharedContentActions.replyToSender(
          context,
          userId: sharedRecipe.sharedByUserId,
          displayName: sharedRecipe.sharedByDisplayName,
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
