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
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:url_launcher/url_launcher.dart';

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
              title: Text(context.l10n.recipeDeleting),
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
          // UI Redesign: FAB cart button for quick add to shopping list
          floatingActionButton: SizedBox(
            width: 48,
            height: 48,
            child: FloatingActionButton(
              onPressed: () => _actions.showAddToCartConfirmation(context),
              backgroundColor: AppColors.forestGreen,
              elevation: 2,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              child: const Icon(
                Icons.shopping_cart,
                color: AppColors.cardWhite,
                size: AppDimensions.iconSizeM,
              ),
            ),
          ),
          body: CustomScrollView(
            slivers: [
              // App bar with recipe title and actions
              // UI Redesign: Hero buttons are solid cream squares with green icons
              SliverAppBar(
                expandedHeight: 200.0,
                floating: false,
                pinned: true,
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: AppColors.textDark,
                // UI Redesign: Custom leading widget (back button)
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _HeroButton(
                    icon: Icons.arrow_back,
                    onPressed: () => Navigator.pop(context),
                    tooltip: context.l10n.accessibilityBackButton,
                  ),
                ),
                // Show recipe title in collapsed app bar
              title: Text(
                recipe.title,
                style: AppTextStyles.bodyLargeBold,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              flexibleSpace: FlexibleSpaceBar(
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
                      : ColoredBox(
                          color: AppColors.cream,
                          child: Center(
                            child: VegetableIllustration(
                              type: VegetableIllustration.randomForRecipe(recipe.id),
                              size: 120,
                              opacity: 0.6,
                            ),
                          ),
                        ),
                ),
                // UI Redesign: Hero action buttons with cream background
                actions: [
                  // Internal sharing with friends and groups
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _HeroButton(
                      icon: Icons.people_outline,
                      onPressed: () => _actions.showSocialShareDialog(context),
                      tooltip: context.l10n.recipeShareWithFriends,
                    ),
                  ),
                  // External sharing
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _HeroButton(
                      icon: Icons.share_outlined,
                      onPressed: () => _actions.shareRecipe(context),
                      tooltip: context.l10n.recipeShareExternal,
                    ),
                  ),
                  // More actions menu
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8, right: 8),
                    child: _HeroMenuButton(
                      icon: Icons.more_horiz,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit_outlined, size: AppDimensions.iconSizeM),
                              const SizedBox(width: AppDimensions.spacingM),
                              Text(context.l10n.recipeEdit),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'fork',
                          child: Row(
                            children: [
                              const Icon(Icons.content_copy_outlined,
                                  size: AppDimensions.iconSizeM),
                              const SizedBox(width: AppDimensions.spacingM),
                              Text(context.l10n.recipeCreateCopy),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'generate_shopping_list',
                          child: Row(
                            children: [
                              const Icon(Icons.shopping_cart_outlined,
                                  size: AppDimensions.iconSizeM),
                              const SizedBox(width: AppDimensions.spacingM),
                              Text(context.l10n.recipeCreateShoppingList),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 're_tag',
                          child: Row(
                            children: [
                              const Icon(Icons.local_offer_outlined,
                                  size: AppDimensions.iconSizeM),
                              const SizedBox(width: AppDimensions.spacingM),
                              Text(context.l10n.recipeUpdateTags),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outlined,
                                  size: AppDimensions.iconSizeM,
                                  color: AppColors.error),
                              const SizedBox(width: AppDimensions.spacingM),
                              Text(context.l10n.recipeDelete,
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
                          PopupMenuItem(
                            value: 'source',
                            child: Row(
                              children: [
                                const Icon(Icons.link_outlined, size: AppDimensions.iconSizeM),
                                const SizedBox(width: AppDimensions.spacingM),
                                Text(context.l10n.recipeViewSource),
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
                          // Recipe title below hero image
                          Text(
                            recipe.title,
                            style: AppTextStyles.titleLarge.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppColors.forestGreenDark,
                            ),
                          ),
                          if (recipe.sourceUrl != null &&
                              recipe.sourceUrl!.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.spacingXs),
                            GestureDetector(
                              onTap: () => _launchSourceUrl(context, recipe.sourceUrl!),
                              child: Text(
                                context.l10n.recipeSourceFrom(Uri.tryParse(recipe.sourceUrl!)?.host ?? recipe.sourceUrl!),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textMedium,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppDimensions.spacingSm),

                          // Recipe metadata
                          RecipeDetailMetadata(
                            viewModel: viewModel,
                            currentPortions: _actions.currentPortions,
                            isScaled: _actions.currentPortions !=
                                (recipe.portions ?? 1),
                          ),
                          const SizedBox(height: AppDimensions.spacingMd),

                          // Recipe main content
                          Builder(
                            builder: (context) {
                              final userService = context.watch<UserService>();
                              final allergenPrefs =
                                  userService.allergenPreferences;
                              return RecipeDetailContent(
                                viewModel: viewModel,
                                scaledIngredients: _actions.scaledIngredients,
                                currentPortions: _actions.currentPortions,
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
                          const SizedBox(height: AppDimensions.spacingMd),

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

  Future<void> _launchSourceUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Silently fail — URL is best-effort
    }
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

/// UI Redesign: Hero button with solid cream background and green icon.
/// Used for back button and action buttons in recipe detail hero image.
class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.cream,
      borderRadius: BorderRadius.zero,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: AppColors.forestGreen,
            size: AppDimensions.iconSizeM,
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// UI Redesign: Hero menu button with solid cream background for popup menus.
class _HeroMenuButton extends StatelessWidget {
  const _HeroMenuButton({
    required this.icon,
    required this.itemBuilder,
    required this.onSelected,
  });

  final IconData icon;
  final List<PopupMenuEntry<String>> Function(BuildContext) itemBuilder;
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: AppColors.cream,
        borderRadius: BorderRadius.zero,
        child: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          icon: Icon(
            icon,
            color: AppColors.forestGreen,
            size: AppDimensions.iconSizeM,
          ),
          itemBuilder: itemBuilder,
          onSelected: onSelected,
        ),
      ),
    );
  }
}
