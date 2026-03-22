// lib/views/recipe_detail_view.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_content.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_actions.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_metadata.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_comments.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_sharing_status.dart';
import 'package:butlery/views/recipe_detail/fullscreen_image_viewer.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/widgets/tagging/tagging_widgets.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:butlery/widgets/social/report_content_dialog.dart';
import 'package:butlery/core/constants/routes.dart';

/// Menu actions for the recipe detail overflow menu.
enum _MenuAction {
  edit,
  fork,
  generateShoppingList,
  reTag,
  editTags,
  delete,
  toggleCollaboration,
  source,
  report,
}

/// Recipe Detail View - Complete recipe display with metadata, actions, and social features
/// This view provides comprehensive recipe details including:
/// - Recipe content (description, images, instructions)
/// - Recipe metadata (portions, time, rating, tags)
/// - Social features (comments, sharing, ratings)
/// - User actions (edit, delete, share, fork)
/// - Portion scaling functionality
/// - Fullscreen image viewing
class RecipeDetailView extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailView({
    super.key,
    required this.recipe,
  });

  @override
  State<RecipeDetailView> createState() => _RecipeDetailViewState();
}

class _RecipeDetailViewState extends State<RecipeDetailView> {
  late final SocialRecipeViewModel _socialRecipeViewModel;

  @override
  void initState() {
    super.initState();
    _socialRecipeViewModel = ServiceLocator.get<SocialRecipeViewModel>();
  }

  @override
  void dispose() {
    _socialRecipeViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RecipeDetailViewModel(recipe: widget.recipe),
        ),
        ChangeNotifierProvider<SocialRecipeViewModel>.value(
          value: _socialRecipeViewModel,
        ),
        ChangeNotifierProvider.value(
          value: ServiceLocator.get<UserService>(),
        ),
      ],
      child: _RecipeDetailViewContent(recipe: widget.recipe),
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
        setState(() {
          _actions.onPortionChanged(
              widget.recipe.portions ?? 1, widget.recipe.ingredients);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<RecipeDetailViewModel>(
      builder: (context, viewModel, child) {
        // Loading state (if deleting)
        if (viewModel.isDeleting) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.recipeDeleting),
              backgroundColor: cs.surface,
            ),
            backgroundColor: cs.surface,
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final recipe = viewModel.recipe;
        final bottomPadding = MediaQuery.of(context).padding.bottom;

        return Scaffold(
          backgroundColor: cs.surface,
          bottomNavigationBar: ButleryBottomNavigation(
            currentIndex: 0,
            items: ButleryAdaptiveNavigation.getNavigationItems(context),
            onTap: (index) {
              final route =
                  ButleryAdaptiveNavigation.getNavigationItems(context)[index]
                      .route;
              Navigator.pushNamed(context, route);
            },
          ),
          // UI Redesign: FAB cart button for quick add to shopping list
          floatingActionButton: SizedBox(
            width: 48,
            height: 48,
            child: FloatingActionButton(
              onPressed: () => _actions.showAddToCartConfirmation(context),
              tooltip: context.l10n.shoppingAddToList,
              backgroundColor: cs.primary,
              elevation: 2,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                color: cs.onPrimary,
                size: AppDimensions.iconSizeM,
              ),
            ),
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: LayoutComponents.offlineIndicator(),
              ),
              // App bar with recipe title and actions
              // UI Redesign: Hero buttons are solid cream squares with green icons
              SliverAppBar(
                expandedHeight: 200.0,
                floating: false,
                pinned: true,
                backgroundColor: cs.surface,
                foregroundColor: cs.onSurface,
                // UI Redesign: Custom leading widget (back button)
                leading: Padding(
                  padding: AppDimensions.paddingAll8,
                  child: _HeroButton(
                    icon: Icons.arrow_back,
                    onPressed: () => Navigator.pop(context),
                    tooltip: context.l10n.accessibilityBackButton,
                  ),
                ),
                title: const SizedBox.shrink(),
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
                                  Colors.transparent,
                                  cs.onSurface.withValues(
                                      alpha: AppDimensions.opacityMediumLight),
                                ],
                              ),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: recipe.imageUrls.first,
                              cacheKey: FirebaseUrlUtils.stableCacheKey(
                                  recipe.imageUrls.first),
                              fit: BoxFit.cover,
                              memCacheWidth: (600 *
                                      MediaQuery.of(context).devicePixelRatio)
                                  .round(),
                              placeholder: (context, url) => ColoredBox(
                                color: cs.surfaceContainerHighest,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) {
                                return ColoredBox(
                                  color: cs.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.restaurant,
                                    size: AppDimensions.iconSizeHero,
                                    color: cs.onSurfaceVariant,
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      : ColoredBox(
                          color: cs.primaryContainer,
                          child: Center(
                            child: VegetableIllustration(
                              type: VegetableIllustration.randomForRecipe(
                                  recipe.id),
                              size: 120,
                              opacity: 0.85,
                            ),
                          ),
                        ),
                ),
                // UI Redesign: Hero action buttons with cream background
                actions: [
                  // Start cooking mode
                  Padding(
                    padding: AppDimensions.paddingVertical8,
                    child: _HeroButton(
                      icon: Icons.restaurant,
                      onPressed: () => Navigator.pushNamed(
                        context,
                        Routes.cookingMode,
                        arguments: recipe,
                      ),
                      tooltip: context.l10n.recipeStartCookingTooltip,
                    ),
                  ),
                  // Favorite toggle
                  Padding(
                    padding: AppDimensions.paddingVertical8,
                    child: _HeroButton(
                      icon: recipe.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      onPressed: () => viewModel.toggleFavorite(),
                      tooltip: recipe.isFavorite
                          ? context.l10n.favoritesRemove
                          : context.l10n.favoritesAdd,
                    ),
                  ),
                  // Internal sharing with friends and groups
                  Padding(
                    padding: AppDimensions.paddingVertical8,
                    child: _HeroButton(
                      icon: Icons.people_outline,
                      onPressed: () => _actions.showSocialShareDialog(context),
                      tooltip: context.l10n.recipeShareWithFriends,
                    ),
                  ),
                  // External sharing
                  Padding(
                    padding: AppDimensions.paddingVertical8,
                    child: _HeroButton(
                      icon: Icons.share_outlined,
                      onPressed: () => _actions.shareRecipe(context),
                      tooltip: context.l10n.recipeShareExternal,
                    ),
                  ),
                  // More actions menu
                  Padding(
                    padding: const EdgeInsets.only(
                        top: AppDimensions.spacingSm,
                        bottom: AppDimensions.spacingSm,
                        right: AppDimensions.spacingSm),
                    child: _HeroMenuButton(
                      icon: Icons.more_horiz,
                      itemBuilder: (context) {
                        final menuCs = Theme.of(context).colorScheme;
                        return [
                          PopupMenuItem(
                            value: _MenuAction.edit,
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined,
                                    size: AppDimensions.iconSizeM,
                                    color: menuCs.primary),
                                const SizedBox(width: AppDimensions.spacingM),
                                Text(context.l10n.recipeEdit),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: _MenuAction.fork,
                            child: Row(
                              children: [
                                Icon(Icons.content_copy_outlined,
                                    size: AppDimensions.iconSizeM,
                                    color: menuCs.primary),
                                const SizedBox(width: AppDimensions.spacingM),
                                Text(context.l10n.recipeCreateCopy),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: _MenuAction.generateShoppingList,
                            child: Row(
                              children: [
                                Icon(Icons.shopping_cart_outlined,
                                    size: AppDimensions.iconSizeM,
                                    color: menuCs.primary),
                                const SizedBox(width: AppDimensions.spacingM),
                                Text(context.l10n.recipeCreateShoppingList),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: _MenuAction.reTag,
                            child: Row(
                              children: [
                                Icon(Icons.local_offer_outlined,
                                    size: AppDimensions.iconSizeM,
                                    color: menuCs.primary),
                                const SizedBox(width: AppDimensions.spacingM),
                                Text(context.l10n.recipeUpdateTags),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: _MenuAction.editTags,
                            child: Row(
                              children: [
                                Icon(Icons.edit_note,
                                    size: AppDimensions.iconSizeM,
                                    color: menuCs.primary),
                                const SizedBox(width: AppDimensions.spacingM),
                                Text(context.l10n.recipeEditTags),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: _MenuAction.delete,
                            child: Row(
                              children: [
                                Icon(Icons.delete_outlined,
                                    size: AppDimensions.iconSizeM,
                                    color: menuCs.error),
                                const SizedBox(width: AppDimensions.spacingM),
                                Text(context.l10n.recipeDelete,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: menuCs.error,
                                        )),
                              ],
                            ),
                          ),
                          // Collaboration toggle (owner only)
                          if (recipe.createdBy ==
                              ServiceLocator.get<PermissionService>()
                                  .currentUserId)
                            PopupMenuItem(
                              value: _MenuAction.toggleCollaboration,
                              child: Row(
                                children: [
                                  Icon(
                                    recipe.isCollaborative
                                        ? Icons.group_off_outlined
                                        : Icons.group_add_outlined,
                                    size: AppDimensions.iconSizeM,
                                    color: menuCs.primary,
                                  ),
                                  const SizedBox(width: AppDimensions.spacingM),
                                  Text(recipe.isCollaborative
                                      ? context.l10n.recipeCollaborationDisable
                                      : context.l10n.recipeCollaborationEnable),
                                ],
                              ),
                            ),
                          if (recipe.sourceUrl != null &&
                              recipe.sourceUrl!.isNotEmpty)
                            PopupMenuItem(
                              value: _MenuAction.source,
                              child: Row(
                                children: [
                                  Icon(Icons.link_outlined,
                                      size: AppDimensions.iconSizeM,
                                      color: menuCs.primary),
                                  const SizedBox(width: AppDimensions.spacingM),
                                  Text(context.l10n.recipeViewSource),
                                ],
                              ),
                            ),
                          PopupMenuItem(
                            value: _MenuAction.report,
                            child: Row(
                              children: [
                                Icon(Icons.flag_outlined,
                                    size: AppDimensions.iconSizeM,
                                    color: menuCs.error),
                                const SizedBox(width: AppDimensions.spacingM),
                                Text(context.l10n.reportContent),
                              ],
                            ),
                          ),
                        ];
                      },
                      onSelected: (action) =>
                          _handleMenuAction(context, action, viewModel, recipe),
                    ),
                  ),
                ],
              ),

              // Recipe content - RESPONSIVE: Center and constrain on large screens
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title section: white bg + green border-bottom per mockup
                        Container(
                          width: double.infinity,
                          padding:
                              AppDimensions.responsiveContentPadding(context),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            border: Border(
                              bottom: BorderSide(
                                color: cs.secondary,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Recipe title (lowercase per mockup)
                              Text(
                                recipe.title.toLowerCase(),
                                style: AppTextStyles.titleLarge.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary,
                                  letterSpacing: 1,
                                ),
                              ),
                              if (recipe.sourceUrl != null &&
                                  recipe.sourceUrl!.isNotEmpty) ...[
                                const SizedBox(height: AppDimensions.spacingXs),
                                Semantics(
                                  link: true,
                                  child: GestureDetector(
                                    onTap: () => _launchSourceUrl(
                                        context, recipe.sourceUrl!),
                                    child: Text(
                                      context.l10n.recipeSourceFrom(
                                          Uri.tryParse(recipe.sourceUrl!)
                                                  ?.host ??
                                              recipe.sourceUrl!),
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: cs.onSurfaceVariant,
                                        decoration: TextDecoration.underline,
                                      ),
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
                              // Dietary/allergen badges (inside title section per mockup)
                              Selector<UserService, UserAllergenPreferences>(
                                selector: (_, svc) => svc.allergenPreferences,
                                builder: (context, allergenPrefs, _) {
                                  final tagResult = recipe.tagResult;
                                  if (tagResult == null ||
                                      !allergenPrefs.showOnDetail) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        top: AppDimensions.spacingSm),
                                    child: TagResultDisplay(
                                      tagResult: tagResult,
                                      userAllergenPrefs:
                                          allergenPrefs.trackedAllergens,
                                      userDietaryPrefs:
                                          allergenPrefs.trackedDietary,
                                      showCoverage: tagResult.coverage < 1.0,
                                      isDegraded: ServiceLocator.tryGet<
                                                  TaggingService>()
                                              ?.isInDegradedMode ??
                                          false,
                                    ),
                                  );
                                },
                              ),

                              // Description (inside title section, above green divider)
                              if (recipe.description.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: AppDimensions.spacingSm),
                                  child: Text(
                                    recipe.description,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppDimensions.spacingMd),

                        // Recipe main content
                        Selector<UserService, UserAllergenPreferences>(
                          selector: (_, svc) => svc.allergenPreferences,
                          builder: (context, allergenPrefs, _) {
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
                        // Sharing status panel (owner only)
                        RecipeDetailSharingStatus(
                          recipe: recipe,
                          onSharingChanged: () => setState(() {}),
                        ),

                        const SizedBox(height: AppDimensions.spacingMd),

                        // Recipe comments
                        RecipeDetailComments(
                          recipe: recipe,
                          onCommentPosted: () {
                            setState(() {});
                          },
                        ),

                        // Bottom padding for safe area
                        SizedBox(
                            height: bottomPadding + AppDimensions.spacingXl),
                      ],
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

  Future<void> _handleMenuAction(BuildContext context, _MenuAction action,
      RecipeDetailViewModel viewModel, Recipe recipe) async {
    switch (action) {
      case _MenuAction.edit:
        _actions.editRecipe(context);
      case _MenuAction.fork:
        Navigator.pushNamed(context, Routes.redigeraRecept,
            arguments: recipe.copyWith(
              title: '${recipe.title} (Copy)',
            ));
      case _MenuAction.generateShoppingList:
        await _actions.generateShoppingListFromRecipe(context);
      case _MenuAction.reTag:
        await _actions.retagRecipe(context);
      case _MenuAction.editTags:
        final overrides = await TagEditorDialog.show(context, recipe);
        if (overrides != null && context.mounted) {
          try {
            final updated = recipe.copyWith(tagOverrides: overrides);
            final recipeService = ServiceLocator.get<UnifiedRecipeService>();
            await recipeService.updateRecipe(updated);
            viewModel.updateRecipe(updated);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.commonErrorOccurred)),
              );
            }
          }
        }
      case _MenuAction.delete:
        await _actions.deleteRecipe(context);
      case _MenuAction.toggleCollaboration:
        await _actions.toggleCollaboration(context);
      case _MenuAction.source:
        if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) {
          _actions.handleSourceUrlClick(context, recipe.sourceUrl!);
        }
      case _MenuAction.report:
        ReportContentDialog.show(
          context: context,
          contentType: 'recipe',
          contentId: recipe.id,
          contentOwnerId: recipe.createdBy,
        );
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
    final cs = Theme.of(context).colorScheme;

    final button = Material(
      color: cs.surface,
      borderRadius: BorderRadius.zero,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: cs.primary,
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
  final List<PopupMenuEntry<_MenuAction>> Function(BuildContext) itemBuilder;
  final void Function(_MenuAction) onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.zero,
        child: PopupMenuButton<_MenuAction>(
          padding: EdgeInsets.zero,
          icon: Icon(
            icon,
            color: cs.primary,
            size: AppDimensions.iconSizeM,
          ),
          itemBuilder: itemBuilder,
          onSelected: onSelected,
        ),
      ),
    );
  }
}
