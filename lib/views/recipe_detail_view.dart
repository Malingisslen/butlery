// lib/views/recipe_detail_view.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_content.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_actions.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_metadata.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_comments.dart';
import 'package:butlery/views/recipe_detail/fullscreen_image_viewer.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/services/user_service.dart';

/// Recipe Detail View - Complete recipe display with metadata, actions, and social features
/// This view provides comprehensive recipe details including:
/// - Recipe content (description, images, instructions)
/// - Recipe metadata (portions, time, rating, tags)
/// - Social features (comments, sharing, ratings)
/// - User actions (edit, delete, share, fork)
/// - Portion scaling functionality
/// - Fullscreen image viewing
class RecipeDetailView extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailView({
    super.key,
    required this.recipe,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RecipeDetailViewModel(recipe: recipe),
        ),
        ChangeNotifierProvider<SocialRecipeViewModel>(
          create: (_) => ServiceLocator.get<SocialRecipeViewModel>(),
        ),
        ChangeNotifierProvider.value(
          value: ServiceLocator.get<UserService>(),
        ),
      ],
      child: _RecipeDetailViewContent(recipe: recipe),
    );
  }
}

class _RecipeDetailViewContent extends StatefulWidget {
  final Recipe recipe;

  const _RecipeDetailViewContent({required this.recipe});

  @override
  State<_RecipeDetailViewContent> createState() =>
      _RecipeDetailViewContentState();
}

class _RecipeDetailViewContentState extends State<_RecipeDetailViewContent> {
  late RecipeDetailActions _actions;

  @override
  void initState() {
    super.initState();
    _actions = RecipeDetailActions();

    // Initialize scaled ingredients with original recipe portions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _actions.onPortionChanged(
            widget.recipe.portions ?? 1, widget.recipe.ingredients);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecipeDetailViewModel>(
      builder: (context, viewModel, child) {
        // Loading state (if deleting)
        if (viewModel.isDeleting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Tar bort recept...'),
              backgroundColor: AppColors.cream,
            ),
            backgroundColor: AppColors.cream,
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final recipe = viewModel.recipe;
        final bottomPadding = MediaQuery.of(context).padding.bottom;

        return Scaffold(
          backgroundColor: AppColors.cream,
          body: CustomScrollView(
            slivers: [
              // App bar with recipe title and actions
              SliverAppBar(
                expandedHeight: 200.0,
                floating: false,
                pinned: true,
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: AppColors.textDark,
                iconTheme: const IconThemeData(
                  color: AppColors.cardWhite,
                  size: AppDimensions.iconSizeL,
                ),
                actionsIconTheme: const IconThemeData(
                  color: AppColors.cardWhite,
                  size: AppDimensions.iconSizeL,
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingM,
                      vertical: AppDimensions.paddingS,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cream.withValues(alpha: AppDimensions.opacityExtraDark),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.borderRadiusM),
                    ),
                    child: Text(
                      recipe.title,
                      style: AppTextStyles.bodyLargeBold,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  background: recipe.imageUrls.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _showFullscreenImage(
                              context, recipe.imageUrls, 0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.transparent,
                                  AppColors.textDark.withValues(alpha: AppDimensions.opacityMediumLight),
                                ],
                              ),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: recipe.imageUrls.first,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const ColoredBox(
                                color: AppColors.cardWhite,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) {
                                return const ColoredBox(
                                  color: AppColors.cardWhite,
                                  child: Icon(
                                    Icons.restaurant,
                                    size: AppDimensions.iconSizeHero,
                                    color: AppColors.textSecondary,
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      : const ColoredBox(
                          color: AppColors.cardWhite,
                          child: Icon(
                            Icons.restaurant,
                            size: AppDimensions.iconSizeHero,
                            color: AppColors.textSecondary,
                          ),
                        ),
                ),
                actions: [
                  // Internal sharing with friends and groups
                  Semantics(
                    label: 'Dela recept med vänner och grupper',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.people_outline),
                      onPressed: () => _actions.showSocialShareDialog(context),
                      tooltip: 'Dela med vänner',
                    ),
                  ),
                  // External sharing
                  Semantics(
                    label: 'Dela recept externt',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () => _actions.shareRecipe(context),
                      tooltip: 'Dela externt',
                    ),
                  ),
                  // More actions menu
                  Semantics(
                    label: 'Fler receptåtgärder',
                    button: true,
                    child: PopupMenuButton(
                      icon: const Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: AppDimensions.iconSizeM),
                              SizedBox(width: AppDimensions.spacingM),
                              Text('Redigera recept'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'fork',
                          child: Row(
                            children: [
                              Icon(Icons.content_copy,
                                  size: AppDimensions.iconSizeM),
                              SizedBox(width: AppDimensions.spacingM),
                              Text('Skapa kopia'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'generate_shopping_list',
                          child: Row(
                            children: [
                              Icon(Icons.shopping_cart,
                                  size: AppDimensions.iconSizeM),
                              SizedBox(width: AppDimensions.spacingM),
                              Text('Skapa inköpslista'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 're_tag',
                          child: Row(
                            children: [
                              Icon(Icons.local_offer,
                                  size: AppDimensions.iconSizeM),
                              SizedBox(width: AppDimensions.spacingM),
                              Text('Uppdatera taggar'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete,
                                  size: AppDimensions.iconSizeM,
                                  color: AppColors.error),
                              const SizedBox(width: AppDimensions.spacingM),
                              Text('Delete Recipe',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.error,
                                      )),
                            ],
                          ),
                        ),
                        if (recipe.sourceUrl != null &&
                            recipe.sourceUrl!.isNotEmpty)
                          const PopupMenuItem(
                            value: 'source',
                            child: Row(
                              children: [
                                Icon(Icons.link, size: AppDimensions.iconSizeM),
                                SizedBox(width: AppDimensions.spacingM),
                                Text('View Source'),
                              ],
                            ),
                          ),
                      ],
                      onSelected: (value) =>
                          _handleMenuAction(context, value, viewModel, recipe),
                    ),
                  ),
                ],
              ),

              // Recipe content - ✅ RESPONSIVE: Center and constrain on large screens
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: LayoutComponents.valueFor(
                        context: context,
                        mobile: double.infinity,
                        tablet: 800,
                        desktop: 900,
                      ),
                    ),
                    child: Padding(
                      padding: AppDimensions.responsiveContentPadding(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Recipe metadata
                          RecipeDetailMetadata(
                            viewModel: viewModel,
                            currentPortions: _actions.currentPortions,
                            isScaled: _actions.currentPortions !=
                                (recipe.portions ?? 1),
                          ),
                          const SizedBox(height: AppDimensions.spacingXl),

                          // Recipe main content
                          Builder(
                            builder: (context) {
                              final userService = context.watch<UserService>();
                              final allergenPrefs =
                                  userService.allergenPreferences;
                              return RecipeDetailContent(
                                viewModel: viewModel,
                                scaledIngredients: _actions.scaledIngredients,
                                onPortionChanged: (portions, ingredients) {
                                  setState(() {
                                    _actions.onPortionChanged(
                                        portions, ingredients);
                                  });
                                },
                                onImageTap: (imageUrls, index) =>
                                    _showFullscreenImage(
                                        context, imageUrls, index),
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
                          const SizedBox(height: AppDimensions.spacingXl),

                          // Recipe comments
                          RecipeDetailComments(
                            recipe: recipe,
                            onCommentPosted: () {
                              // Refresh recipe data after comment posted
                              setState(() {});
                            },
                          ),

                          // Bottom padding for safe area (Android gesture navigation)
                          SizedBox(
                              height: bottomPadding + AppDimensions.spacingXl),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFullscreenImage(
      BuildContext context, List<String> imageUrls, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullscreenImageViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _handleMenuAction(BuildContext context, String action,
      RecipeDetailViewModel viewModel, Recipe recipe) async {
    switch (action) {
      case 'edit':
        _actions.editRecipe(context);
        break;
      case 'fork':
        // Create a copy of the recipe
        Navigator.pushNamed(context, '/editRecipe',
            arguments: recipe.copyWith(
              title: '${recipe.title} (Copy)',
            ));
        break;
      case 'generate_shopping_list':
        await _actions.generateShoppingListFromRecipe(context);
        break;
      case 're_tag':
        await _actions.retagRecipe(context);
        break;
      case 'delete':
        await _actions.deleteRecipe(context);
        // Navigation is handled by RecipeDetailActions.deleteRecipe()
        break;
      case 'source':
        if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) {
          _actions.handleSourceUrlClick(context, recipe.sourceUrl!);
        }
        break;
    }
  }
}
