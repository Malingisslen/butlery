// lib/views/recipe_detail/recipe_profile_visibility.dart

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/recipe/recipe_ownership.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/moderation/content_filter_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/widgets/common/badges/unified_badge.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Only a recipe nobody else is a member of can go on the public profile: a
/// shared one has co-owners who never agreed to publish it.
bool canOfferProfileVisibility(Recipe recipe) =>
    recipe.type == RecipeType.personal &&
    (recipe.socialData?.memberPermissions?.isEmpty ?? true);

/// The ⋯ menu row for the owner, or null when the recipe cannot be public.
ButleryMenuChoice<T>? profileVisibilityChoice<T>(
  BuildContext context, {
  required Recipe recipe,
  required T value,
}) {
  if (!canOfferProfileVisibility(recipe)) return null;
  final l10n = context.l10n;
  if (_viewerIsMinor()) {
    return ButleryMenuChoice<T>(
      itemKey: const ValueKey('test-recipe-detail-profile-visibility'),
      value: value,
      icon: ButleryIcons.eye,
      label: l10n.recipeProfileVisibilityShow,
      subtitle: l10n.recipeProfileVisibilityMinorHint,
      enabled: false,
    );
  }
  return ButleryMenuChoice<T>(
    itemKey: const ValueKey('test-recipe-detail-profile-visibility'),
    value: value,
    icon: recipe.showOnProfile ? ButleryIcons.eyeOff : ButleryIcons.eye,
    label: recipe.showOnProfile
        ? l10n.recipeProfileVisibilityHide
        : l10n.recipeProfileVisibilityShow,
  );
}

// An unknown profile counts as an adult: firestore.rules is what actually
// refuses a minor, this only decides what the menu offers.
bool _viewerIsMinor() =>
    ServiceLocator.get<UserService>().currentUserProfile?.isMinor ?? false;

/// Whether [recipe]'s public text passes the same profanity filter as every
/// other user-generated surface. The text is what a stranger will read.
bool recipeTextIsPublishable(Recipe recipe) {
  final filter = ServiceLocator.tryGet<ContentFilterService>();
  if (filter == null) return true;
  final fields = {
    'title': recipe.title,
    'description': recipe.description,
    'ingredients': recipe.ingredients.join('\n'),
    'instructions': recipe.instructions.join('\n'),
  };
  return fields.entries.every(
    (f) => filter.ensureClean(f.value, fieldName: f.key).isClean,
  );
}

/// Turns the recipe's profile visibility on or off from the detail menu.
/// Turning on is gated by the content filter and a confirmation; turning off
/// saves at once because removing is always safe.
Future<void> changeProfileVisibility(
  BuildContext context,
  RecipeDetailViewModel viewModel,
) async {
  final recipe = viewModel.recipe;
  final show = !recipe.showOnProfile;
  final l10n = context.l10n;

  if (show) {
    if (!recipeTextIsPublishable(recipe)) {
      SnackBarUtils.showFailure(
        context,
        what: l10n.recipeProfileVisibilityBlockedContent,
      );
      return;
    }
    final confirmed = await CommonDialogActions.showActionConfirmation(
      context: context,
      title: l10n.recipeProfileVisibilityConfirmTitle(recipe.title),
      message: l10n.recipeProfileVisibilityConfirmBody,
      confirmText: l10n.recipeProfileVisibilityConfirmAction,
      cancelText: l10n.recipeProfileVisibilityCancel,
      icon: ButleryIcons.eye,
    );
    if (confirmed != true || !context.mounted) return;
  }

  final updated = recipe.copyWith(
    showOnProfile: show,
    showOnProfileChangedAt: clock.now(),
  );
  var saved = false;
  try {
    saved = await ServiceLocator.get<UnifiedRecipeService>().updateRecipe(
      updated,
    );
  } catch (_) {
    saved = false;
  }
  if (!context.mounted) return;
  if (!saved) {
    SnackBarUtils.showFailure(
      context,
      what: l10n.recipeProfileVisibilityFailed,
    );
    return;
  }
  viewModel.updateRecipe(updated);
  SnackBarUtils.showSuccess(
    context,
    show
        ? l10n.recipeProfileVisibilityShownSnack
        : l10n.recipeProfileVisibilityHiddenSnack,
  );
}

/// "Publikt" in the header while the owner's recipe is on the profile.
class RecipeProfileVisibilityPill extends StatelessWidget {
  const RecipeProfileVisibilityPill({required this.recipe, super.key});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    // A shared recipe is never on the profile, whatever its flag says.
    if (!recipe.showOnProfile || !canOfferProfileVisibility(recipe)) {
      return const SizedBox.shrink();
    }
    final isOwner =
        recipe.ownerUid == null ||
        recipe.ownerUid ==
            ServiceLocator.get<PermissionService>().currentUserId;
    if (!isOwner) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space8),
      child: UnifiedBadge.status(
        label: context.l10n.recipeProfileVisibilityBadge,
        icon: ButleryIcons.eye,
      ),
    );
  }
}

/// A template for "Skapa kopia" from someone's public copy. The photo URLs
/// point into the owner's Storage path and stop working when it is unpublished.
Recipe withoutPublicPhotos(Recipe recipe) {
  final copy = recipe.copyWith(imageUrls: const []);
  return Recipe(
    core: copy.core.copyWith(thumbnailUrl: null),
    type: copy.type,
    socialData: copy.socialData,
    realtimeData: copy.realtimeData,
    offlineData: copy.offlineData,
    rev: copy.rev,
  );
}
