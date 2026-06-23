// lib/views/recipe_detail/recipe_detail_tablet_content.dart
//
// Two-column tablet layout for recipe detail. Reuses all existing sub-widgets
// from the mobile layout — only the spatial arrangement changes.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe/recipe_completeness.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_actions.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_content.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_comments.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_shared_widgets.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_sharing_status.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/widgets/recipe/heirloom_section.dart';

/// Two-column tablet layout for recipe detail content (below the SliverAppBar).
///
/// Left column: title, metadata, allergen badges, description, sharing, comments.
/// Right column: completeness banner, recipe content (tags, images, ingredients, instructions).
class RecipeDetailTabletContent extends StatefulWidget {
  final Recipe recipe;
  final RecipeDetailViewModel viewModel;
  final bool scrollToComments;
  final RecipeDetailActions actions;

  const RecipeDetailTabletContent({
    super.key,
    required this.recipe,
    required this.viewModel,
    required this.scrollToComments,
    required this.actions,
  });

  @override
  State<RecipeDetailTabletContent> createState() =>
      _RecipeDetailTabletContentState();
}

class _RecipeDetailTabletContentState extends State<RecipeDetailTabletContent> {
  RecipeDetailActions get _actions => widget.actions;

  @override
  Widget build(BuildContext context) {
    final recipe = widget.viewModel.recipe;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column: metadata + social (~40%)
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: bottomPadding + AppDimensions.spacingXl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RecipeDetailSharedWidgets.buildTitleSection(
                  context: context,
                  recipe: recipe,
                  viewModel: widget.viewModel,
                  actions: _actions,
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                // BUT-410: heirloom scan sits in the narrower left column so
                // the parsed text has room to breathe on the right.
                if (recipe.heirloom != null) ...[
                  HeirloomSection(
                    heirloom: recipe.heirloom!,
                    maxHeight: 420,
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                ],
                RecipeDetailSharingStatus(
                  recipe: recipe,
                  onSharingChanged: () => setState(() {}),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                RecipeDetailComments(
                  recipe: recipe,
                  initiallyExpanded: widget.scrollToComments,
                  onCommentPosted: () => setState(() {}),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: AppDimensions.spacingMd),

        // Right column: recipe content (~60%)
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: bottomPadding + AppDimensions.spacingXl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recipe.completenessScore < incompleteThreshold)
                  RecipeDetailSharedWidgets.buildCompletenessBanner(
                    context,
                    recipe,
                  ),
                Selector<UserService, UserAllergenPreferences>(
                  selector: (_, svc) => svc.allergenPreferences,
                  builder: (context, allergenPrefs, _) {
                    return RecipeDetailContent(
                      viewModel: widget.viewModel,
                      scaledIngredients: _actions.scaledIngredients,
                      currentPortions: _actions.currentPortions,
                      onPortionChanged: (portions, ingredients) {
                        setState(() {
                          _actions.onPortionChanged(portions, ingredients);
                        });
                      },
                      onImageTap: (imageUrls, index) =>
                          RecipeDetailSharedWidgets.showFullscreenImage(
                            context,
                            imageUrls,
                            index,
                          ),
                      userAllergenPrefs: allergenPrefs.showOnDetail
                          ? allergenPrefs.trackedAllergens
                          : null,
                      userDietaryPrefs: allergenPrefs.showOnDetail
                          ? allergenPrefs.trackedDietary
                          : null,
                      showCoverage: allergenPrefs.showCoverage,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
