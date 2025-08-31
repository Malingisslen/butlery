// lib/views/recipe_detail_view.dart

import 'package:flutter/material.dart';
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

/// Recipe Detail View - Complete recipe display with metadata, actions, and social features
///
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
              title: const Text('Deleting Recipe...'),
              backgroundColor: AppColors.backgroundBeige,
            ),
            backgroundColor: AppColors.backgroundBeige,
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final recipe = viewModel.recipe;

        return Scaffold(
          backgroundColor: AppColors.backgroundBeige,
          body: CustomScrollView(
            slivers: [
              // App bar with recipe title and actions
              SliverAppBar(
                expandedHeight: 200.0,
                floating: false,
                pinned: true,
                backgroundColor: AppColors.backgroundBeige,
                foregroundColor: AppColors.textDark,
                iconTheme: const IconThemeData(
                  color: AppColors.primaryBlue,
                  size: AppDimensions.iconSizeL,
                ),
                actionsIconTheme: const IconThemeData(
                  color: AppColors.primaryBlue,
                  size: AppDimensions.iconSizeL,
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingM,
                      vertical: AppDimensions.paddingS,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundBeige.withValues(alpha: 0.9),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.borderRadiusM),
                    ),
                    child: Text(
                      recipe.title,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontSize: 16, // Smaller for app bar
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  background: recipe.imageUrls.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _showFullscreenImage(
                              context, recipe.imageUrls, 0),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black26,
                                ],
                              ),
                            ),
                            child: Image.network(
                              recipe.imageUrls.first,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const ColoredBox(
                                  color: AppColors.cardColor,
                                  child: Icon(
                                    Icons.restaurant,
                                    size: 80,
                                    color: AppColors.textSecondary,
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      : const ColoredBox(
                          color: AppColors.cardColor,
                          child: Icon(
                            Icons.restaurant,
                            size: 80,
                            color: AppColors.textSecondary,
                          ),
                        ),
                ),
                actions: [
                  // Share button
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () => _actions.shareRecipe(context),
                    tooltip: 'Share Recipe',
                  ),
                  // More actions menu
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: AppDimensions.spacingM),
                            Text('Edit Recipe'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'fork',
                        child: Row(
                          children: [
                            Icon(Icons.content_copy, size: 20),
                            SizedBox(width: AppDimensions.spacingM),
                            Text('Make Copy'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete,
                                size: 20, color: AppColors.error),
                            SizedBox(width: AppDimensions.spacingM),
                            Text('Delete Recipe',
                                style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                      if (recipe.sourceUrl != null &&
                          recipe.sourceUrl!.isNotEmpty)
                        const PopupMenuItem(
                          value: 'source',
                          child: Row(
                            children: [
                              Icon(Icons.link, size: 20),
                              SizedBox(width: AppDimensions.spacingM),
                              Text('View Source'),
                            ],
                          ),
                        ),
                    ],
                    onSelected: (value) =>
                        _handleMenuAction(context, value, viewModel, recipe),
                  ),
                ],
              ),

              // Recipe content
              SliverPadding(
                padding: AppDimensions.screenPadding,
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Recipe metadata
                    RecipeDetailMetadata(
                      viewModel: viewModel,
                      currentPortions: _actions.currentPortions,
                      isScaled:
                          _actions.currentPortions != (recipe.portions ?? 1),
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),

                    // Recipe main content
                    RecipeDetailContent(
                      viewModel: viewModel,
                      scaledIngredients: _actions.scaledIngredients,
                      onPortionChanged: (portions, ingredients) {
                        setState(() {
                          _actions.onPortionChanged(portions, ingredients);
                        });
                      },
                      onImageTap: (imageUrls, index) =>
                          _showFullscreenImage(context, imageUrls, index),
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

                    // Bottom padding for safe area
                    const SizedBox(height: AppDimensions.spacingXl),
                  ]),
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
