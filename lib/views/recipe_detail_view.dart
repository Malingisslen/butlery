// lib/views/recipe_detail_view.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe/recipe_completeness.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_actions.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_content.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_comments.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_sharing_status.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_shared_widgets.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_tablet_content.dart';
import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/tagging/tagging_widgets.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';
import 'package:butlery/widgets/social/report_content_dialog.dart';
import 'package:butlery/widgets/recipe/cook_snap_gallery.dart';
import 'package:butlery/viewmodels/cook_snap_viewmodel.dart';
import 'package:butlery/services/cook_snap_service.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/services/recipe_print_service.dart' as print_service;
import 'package:image_picker/image_picker.dart';

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
  printRecipe,
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
  final bool scrollToComments;

  const RecipeDetailView({
    super.key,
    required this.recipe,
    this.scrollToComments = false,
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
      child: _RecipeDetailViewContent(
        recipe: widget.recipe,
        scrollToComments: widget.scrollToComments,
      ),
    );
  }
}

class _RecipeDetailViewContent extends StatefulWidget {
  final Recipe recipe;
  final bool scrollToComments;

  const _RecipeDetailViewContent({
    required this.recipe,
    this.scrollToComments = false,
  });

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
                expandedHeight: Breakpoints.isMobile(context)
                    ? 200.0
                    : MediaQuery.of(context).size.height * 0.3,
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
                  background: Hero(
                    tag: ImageConfig.recipeHeroTag(recipe.id),
                    child: recipe.imageUrls.isNotEmpty
                        ? GestureDetector(
                            onTap: () =>
                                RecipeDetailSharedWidgets.showFullscreenImage(
                                    context, recipe.imageUrls, 0),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    cs.onSurface.withValues(
                                        alpha:
                                            AppDimensions.opacityMediumLight),
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
                          if (kIsWeb)
                            PopupMenuItem(
                              value: _MenuAction.printRecipe,
                              child: Row(
                                children: [
                                  Icon(Icons.print_outlined,
                                      size: AppDimensions.iconSizeM,
                                      color: menuCs.primary),
                                  const SizedBox(width: AppDimensions.spacingM),
                                  Text(context.l10n.recipePrint),
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

              // Recipe content — tablet uses two-column layout, mobile single-column
              SliverToBoxAdapter(
                child: Breakpoints.isMobile(context)
                    ? _buildMobileContent(
                        context, viewModel, recipe, bottomPadding, cs)
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: RecipeDetailTabletContent(
                            recipe: recipe,
                            viewModel: viewModel,
                            scrollToComments: widget.scrollToComments,
                            actions: _actions,
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

  /// Mobile single-column content layout (original layout, extracted for readability).
  Widget _buildMobileContent(
    BuildContext context,
    RecipeDetailViewModel viewModel,
    Recipe recipe,
    double bottomPadding,
    ColorScheme cs,
  ) {
    return Center(
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
            RecipeDetailSharedWidgets.buildTitleSection(
              context: context,
              recipe: recipe,
              viewModel: viewModel,
              actions: _actions,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            if (recipe.completenessScore < incompleteThreshold)
              RecipeDetailSharedWidgets.buildCompletenessBanner(
                  context, recipe),
            Selector<UserService, UserAllergenPreferences>(
              selector: (_, svc) => svc.allergenPreferences,
              builder: (context, allergenPrefs, _) {
                return RecipeDetailContent(
                  viewModel: viewModel,
                  scaledIngredients: _actions.scaledIngredients,
                  currentPortions: _actions.currentPortions,
                  onPortionChanged: (portions, ingredients) {
                    setState(() {
                      _actions.onPortionChanged(portions, ingredients);
                    });
                  },
                  onImageTap: (imageUrls, index) =>
                      RecipeDetailSharedWidgets.showFullscreenImage(
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
            RecipeDetailSharingStatus(
              recipe: recipe,
              onSharingChanged: () => setState(() {}),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            _buildCookSnapGallery(recipe),
            const SizedBox(height: AppDimensions.spacingMd),
            RecipeDetailComments(
              recipe: recipe,
              initiallyExpanded: widget.scrollToComments,
              onCommentPosted: () => setState(() {}),
            ),
            SizedBox(height: bottomPadding + AppDimensions.spacingXl),
          ],
        ),
      ),
    );
  }

  Widget _buildCookSnapGallery(Recipe recipe) {
    return ChangeNotifierProvider(
      create: (_) => CookSnapViewModel(
        service: ServiceLocator.get<CookSnapService>(),
        recipeId: recipe.id,
        recipeAuthorId: recipe.createdBy ?? '',
        recipeName: recipe.core.title,
      ),
      child: Consumer<CookSnapViewModel>(
        builder: (context, vm, _) {
          final userId = ServiceLocator.get<PermissionService>().currentUserId;
          return CookSnapGallery(
            snaps: vm.snaps,
            isLoading: vm.isLoading,
            isUploading: vm.isUploading,
            currentUserId: userId,
            error: vm.error,
            onAdd: () => _showAddSnapSheet(context, vm),
            onDelete: (snapId) => vm.deleteSnap(snapId),
            onReport: (snap) => ReportContentDialog.show(
              context: context,
              contentType: 'cook_snap',
              contentId: snap.id,
              contentOwnerId: snap.userId,
            ),
          );
        },
      ),
    );
  }

  void _showAddSnapSheet(BuildContext context, CookSnapViewModel vm) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(context.l10n.cookSnapFromCamera),
              onTap: () {
                Navigator.pop(ctx);
                vm.addSnap(source: ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(context.l10n.cookSnapFromGallery),
              onTap: () {
                Navigator.pop(ctx);
                vm.addSnap(source: ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printRecipe(Recipe recipe) async {
    await print_service.printRecipeHtml(recipe);
  }

  Future<void> _handleMenuAction(BuildContext context, _MenuAction action,
      RecipeDetailViewModel viewModel, Recipe recipe) async {
    switch (action) {
      case _MenuAction.edit:
        _actions.editRecipe(context);
      case _MenuAction.fork:
        Navigator.pushNamed(context, Routes.skrivSjalv, arguments: {
          'initialRecipe': recipe.copyWith(
            title: context.l10n.recipeDuplicateTitle(recipe.title),
          ),
          'isTemplate': true,
        });
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
              SnackBarUtils.showError(
                  context, context.l10n.commonErrorOccurred);
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
      case _MenuAction.printRecipe:
        _printRecipe(recipe);
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
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
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
