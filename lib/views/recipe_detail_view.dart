// lib/views/recipe_detail_view.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:butlery/models/recipe/source_artefact.dart';
import 'package:butlery/views/recipe_detail/recipe_source_artefact_sheet.dart';
import 'package:butlery/widgets/common/icons/adaptive_icon.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/views/recipe_detail/cook_snap_visibility.dart';
import 'package:butlery/views/recipe_detail/cook_snap_visibility_dialog.dart';
import 'package:butlery/views/recipe_detail/comment_visibility.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/models/recipe/recipe_completeness.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/views/recipe_detail/fork_placement.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_actions.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_content.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_comments.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_sharing_status.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_shared_widgets.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_tablet_content.dart';
import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/tagging/tagging_widgets.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';
import 'package:butlery/widgets/social/report_content_dialog.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/widgets/recipe/cook_snap_gallery.dart';
import 'package:butlery/widgets/recipe/heirloom_section.dart';
import 'package:butlery/viewmodels/cook_snap_viewmodel.dart';
import 'package:butlery/services/cook_snap_service.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/services/recipe_print_service.dart' as print_service;
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/widgets/image/image_picker_dialogs.dart';
import 'package:butlery/core/utils/external_link.dart';

/// BUT-403 identifier scheme for this view (browser a11y tree hooks):
///  - `btn-edit-recipe`     → overflow menu → Edit
///  - `btn-delete-recipe`   → overflow menu → Delete
///  - `btn-share-recipe`    → hero bar external share
///  - `btn-share-friends`   → hero bar friend share
///  - `btn-start-cooking`   → hero bar start cooking-mode
///  - `btn-mark-cooked`     → "Lagat idag" chip in metadata (handled in
///     recipe_detail_metadata.dart)
///
/// Menu actions for the recipe detail overflow menu.
enum _MenuAction {
  edit,
  fork,
  addToMenu,
  generateShoppingList,
  reTag,
  editTags,
  delete,
  toggleCollaboration,
  source,
  viewSourceArtefact,
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

  // When true, owner actions (favorite, edit, edit-tags, delete) are hidden.
  // Non-owner actions (save-a-copy, comments, ratings) remain visible.
  // Use this when showing a friend's recipe that the current user cannot edit.
  final bool readOnly;

  // When non-null, the owner is viewing their own recipe via a share-request
  // notification. A banner is shown prompting them to share the recipe with
  // the requester.
  final SocialRequest? shareRequest;

  /// BUT-1613: present count carried from a planned weekly-menu meal, forwarded
  /// to cooking mode so it opens pre-scaled to who's home. Null for every other
  /// entry point into recipe detail.
  final int? presentServings;

  /// The name of the view the back button returns to. It gives the button
  /// the name "Tillbaka till [backTo]" (Komponentark v1:74-78;
  /// tillgänglighetshandoff:132). Null keeps "Tillbaka".
  final String? backTo;

  const RecipeDetailView({
    super.key,
    required this.recipe,
    this.scrollToComments = false,
    this.readOnly = false,
    this.shareRequest,
    this.presentServings,
    this.backTo,
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
        readOnly: widget.readOnly,
        shareRequest: widget.shareRequest,
        presentServings: widget.presentServings,
        backTo: widget.backTo,
      ),
    );
  }
}

class _RecipeDetailViewContent extends StatefulWidget {
  final Recipe recipe;
  final bool scrollToComments;
  final bool readOnly;
  final SocialRequest? shareRequest;

  /// BUT-1613: present count forwarded to cooking mode (see RecipeDetailView).
  final int? presentServings;
  final String? backTo;

  const _RecipeDetailViewContent({
    required this.recipe,
    this.scrollToComments = false,
    this.readOnly = false,
    this.shareRequest,
    this.presentServings,
    this.backTo,
  });

  @override
  State<_RecipeDetailViewContent> createState() =>
      _RecipeDetailViewContentState();
}

class _RecipeDetailViewContentState extends State<_RecipeDetailViewContent> {
  late RecipeDetailActions _actions;
  UserService? _userService;

  @override
  void initState() {
    super.initState();
    _actions = RecipeDetailActions();

    // BUT-1322: portion state initialized synchronously (household-size
    // default, recipe portions as scaling base) so the first frame already
    // renders the right amounts and the PortionScaler mounts with the right
    // initial value. Replaces the old post-frame onPortionChanged bootstrap.
    _actions.initializeScaling(widget.recipe);

    // BUT-1515: on a cold deep-link into a recipe the user profile can still be
    // loading when initializeScaling runs above, so the household-size default
    // falls back to the recipe's own portions. Re-apply it once the profile
    // finishes loading (UserService notifies), unless the user has meanwhile
    // scaled by hand.
    _userService = ServiceLocator.get<UserService>();
    _userService!.addListener(_onUserServiceChanged);
  }

  void _onUserServiceChanged() {
    if (!mounted) return;
    if (_actions.refreshHouseholdDefault(widget.recipe)) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _userService?.removeListener(_onUserServiceChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<RecipeDetailViewModel>(
      builder: (context, viewModel, child) {
        // Loading state (if deleting)
        // The loading line says what is happening: "Raderar receptet …"
        // (enhet-0 recipeDeleting; content-style-guide.md:63, :84). The bar
        // keeps the recipe's name so the user still knows where they are.
        if (viewModel.isDeleting) {
          return Scaffold(
            appBar: ButleryTopBar.undersida(
              title: viewModel.recipe.title,
              backTo: widget.backTo,
            ),
            backgroundColor: cs.surface,
            body: StateWidget.loading(message: context.l10n.recipeDeleting),
          );
        }

        final recipe = viewModel.recipe;
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        // Someone else's recipe: "Spara till mitt kök" is the one saffron
        // action, and "Börja laga" steps down (Skarmar v12 etapp 11
        // 'Receptet brett — någon annans'; Grafisk manual v6:219).
        final isOthersRecipe = showForkInAppBar(
          recipe.createdBy,
          ServiceLocator.get<PermissionService>().currentUserId,
        );
        void startCooking() => Navigator.pushNamed(
          context,
          Routes.cookingMode,
          // BUT-1613: forward the present count (map form) when this detail
          // view was opened from a planned meal, so cooking mode opens
          // pre-scaled. Bare Recipe otherwise.
          arguments: widget.presentServings == null
              ? recipe
              : {'recipe': recipe, 'presentServings': widget.presentServings},
        );

        return Scaffold(
          backgroundColor: cs.surface,
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RecipeActionBar(
                isOthersRecipe: isOthersRecipe,
                onStartCooking: startCooking,
                onSaveToMyKitchen: () => _handleMenuAction(
                  context,
                  _MenuAction.fork,
                  viewModel,
                  recipe,
                ),
                onAddToShoppingList: () =>
                    _actions.showAddToCartConfirmation(context),
              ),
              ButleryBottomNavigation(
                currentIndex: 0,
                items: ButleryAdaptiveNavigation.getNavigationItems(context),
                onTap: (index) {
                  final route = ButleryAdaptiveNavigation.getNavigationItems(
                    context,
                  )[index].route;
                  Navigator.pushNamed(context, route);
                },
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: LayoutComponents.offlineIndicator(),
              ),
              // App bar with recipe title and actions
              // UI Redesign: Hero buttons are solid cream squares with green icons
              // BUT-706: stays a Material SliverAppBar — the Hero-image
              // flexibleSpace collapsing header has no CupertinoSliverNavigationBar
              // equivalent. (The deleting-state bar above uses AdaptiveAppBar.)
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
                    tooltip: widget.backTo == null
                        ? context.l10n.accessibilityBackButton
                        : context.l10n.commonBackTo(widget.backTo!),
                  ),
                ),
                // Mönster 3 · Mediehero (Komponentark v1:81-89): the title
                // stands under the hero, never on top of the food.
                title: const SizedBox.shrink(),
                flexibleSpace: FlexibleSpaceBar(
                  background: Hero(
                    tag: ImageConfig.recipeHeroTag(recipe.id),
                    child: recipe.imageUrls.isNotEmpty
                        ? Semantics(
                            label: context.l10n.a11yRecipeImageFullscreen,
                            button: true,
                            child: GestureDetector(
                              onTap: () =>
                                  RecipeDetailSharedWidgets.showFullscreenImage(
                                    context,
                                    recipe.imageUrls,
                                    0,
                                  ),
                              child: CachedNetworkImage(
                                imageUrl: recipe.imageUrls.first,
                                cacheKey: FirebaseUrlUtils.stableCacheKey(
                                  recipe.imageUrls.first,
                                ),
                                fit: BoxFit.cover,
                                memCacheWidth:
                                    (600 *
                                            MediaQuery.of(
                                              context,
                                            ).devicePixelRatio)
                                        .round(),
                                // A still plate while the photo loads,
                                // never a spinner (U05 test plan).
                                placeholder: (context, url) => ColoredBox(
                                  color: cs.surfaceContainerHighest,
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
                                  recipe.id,
                                ),
                                size: 120,
                              ),
                            ),
                          ),
                  ),
                ),
                // UI Redesign: Hero action buttons with cream background
                actions: [
                  // Favorite toggle — owner-only (hidden for a friend's recipe)
                  if (!widget.readOnly)
                    Padding(
                      key: const ValueKey('test-recipe-detail-favorite'),
                      padding: AppDimensions.paddingVertical8,
                      child: Semantics(
                        identifier: 'btn-favorite-recipe',
                        button: true,
                        label: recipe.isFavorite
                            ? context.l10n.favoritesRemove
                            : context.l10n.favoritesAdd,
                        child: _HeroButton(
                          icon: recipe.isFavorite
                              ? AdaptiveIcons.favouriteFilled
                              : AdaptiveIcons.favouriteOutline,
                          onPressed: () async {
                            await viewModel.toggleFavorite();
                            if (!context.mounted) return;
                            // BUT-905: announce the new state to screen readers,
                            // which the icon swap alone doesn't convey.
                            SemanticsService.sendAnnouncement(
                              View.of(context),
                              viewModel.recipe.isFavorite
                                  ? context.l10n.a11yRecipeFavorited
                                  : context.l10n.a11yRecipeUnfavorited,
                              Directionality.of(context),
                            );
                          },
                          tooltip: recipe.isFavorite
                              ? context.l10n.favoritesRemove
                              : context.l10n.favoritesAdd,
                        ),
                      ),
                    ),
                  // Internal sharing with friends and groups
                  Padding(
                    key: const ValueKey('test-recipe-detail-share-friends'),
                    padding: AppDimensions.paddingVertical8,
                    child: Semantics(
                      identifier: 'btn-share-friends',
                      button: true,
                      label: context.l10n.recipeShareWithFriends,
                      child: _HeroButton(
                        icon: Icons.people_outline,
                        onPressed: () =>
                            _actions.showSocialShareDialog(context),
                        tooltip: context.l10n.recipeShareWithFriends,
                      ),
                    ),
                  ),
                  // External sharing
                  Padding(
                    key: const ValueKey('test-recipe-detail-share-recipe'),
                    padding: AppDimensions.paddingVertical8,
                    child: Semantics(
                      identifier: 'btn-share-recipe',
                      button: true,
                      label: context.l10n.recipeShareExternal,
                      child: _HeroButton(
                        icon: Icons.share_outlined,
                        onPressed: () => _actions.shareRecipe(context),
                        tooltip: context.l10n.recipeShareExternal,
                      ),
                    ),
                  ),
                  // "Spara till mitt kök" is the saffron action in the
                  // bar below on someone else's recipe (BUT-972), so the
                  // shopping list moves up here as a paper-ring button.
                  if (isOthersRecipe)
                    Padding(
                      key: const ValueKey('test-recipe-detail-add-to-list'),
                      padding: AppDimensions.paddingVertical8,
                      child: _HeroButton(
                        icon: Icons.shopping_cart_outlined,
                        onPressed: () =>
                            _actions.showAddToCartConfirmation(context),
                        tooltip: context.l10n.recipeAddToShoppingList,
                      ),
                    ),
                  // More actions menu
                  Padding(
                    key: const ValueKey('test-recipe-detail-more'),
                    padding: const EdgeInsetsDirectional.only(
                      top: AppDimensions.spacingSm,
                      bottom: AppDimensions.spacingSm,
                      end: AppDimensions.spacingSm,
                    ),
                    child: Semantics(
                      identifier: 'btn-recipe-more',
                      button: true,
                      // Was mislabelled `recipeEdit` ("Redigera recept") — this
                      // menu opens Edit/Copy/Delete/Report, so the SR name must
                      // describe the menu, not one item (WCAG 4.1.2).
                      label: context.l10n.a11yRecipeMoreActions,
                      child: _HeroMenuButton(
                        icon: Icons.more_horiz,
                        itemBuilder: (context) {
                          final menuCs = Theme.of(context).colorScheme;
                          return [
                            // Edit — owner-only (hidden for a friend's recipe)
                            if (!widget.readOnly)
                              ButleryMenuItem(
                                key: const ValueKey('test-recipe-detail-edit'),
                                value: _MenuAction.edit,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit_outlined,
                                      size: AppDimensions.iconSizeM,
                                      color: menuCs.primary,
                                    ),
                                    const SizedBox(
                                      width: AppDimensions.spacingM,
                                    ),
                                    Text(context.l10n.recipeEdit),
                                  ],
                                ),
                              ),
                            // Owned/local recipes keep "Create copy" here as a
                            // secondary action; shared recipes promote it to the
                            // app-bar instead (BUT-972).
                            if (showForkInOverflow(
                              recipe.createdBy,
                              ServiceLocator.get<PermissionService>()
                                  .currentUserId,
                            ))
                              ButleryMenuItem(
                                value: _MenuAction.fork,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.content_copy_outlined,
                                      size: AppDimensions.iconSizeM,
                                      color: menuCs.primary,
                                    ),
                                    const SizedBox(
                                      width: AppDimensions.spacingM,
                                    ),
                                    Text(context.l10n.recipeCreateCopy),
                                  ],
                                ),
                              ),
                            // BUT-999: add to weekly menu — opens the
                            // multi-select day/slot picker.
                            ButleryMenuItem(
                              key: const ValueKey(
                                'test-recipe-detail-add-to-menu',
                              ),
                              value: _MenuAction.addToMenu,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_month_outlined,
                                    size: AppDimensions.iconSizeM,
                                    color: menuCs.primary,
                                  ),
                                  const SizedBox(width: AppDimensions.spacingM),
                                  Text(context.l10n.bulkAddToMenu),
                                ],
                              ),
                            ),
                            ButleryMenuItem(
                              value: _MenuAction.generateShoppingList,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.shopping_cart_outlined,
                                    size: AppDimensions.iconSizeM,
                                    color: menuCs.primary,
                                  ),
                                  const SizedBox(width: AppDimensions.spacingM),
                                  Text(context.l10n.recipeCreateShoppingList),
                                ],
                              ),
                            ),
                            // reTag/editTags/delete — owner-only
                            if (!widget.readOnly)
                              ButleryMenuItem(
                                value: _MenuAction.reTag,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.local_offer_outlined,
                                      size: AppDimensions.iconSizeM,
                                      color: menuCs.primary,
                                    ),
                                    const SizedBox(
                                      width: AppDimensions.spacingM,
                                    ),
                                    Text(context.l10n.recipeUpdateTags),
                                  ],
                                ),
                              ),
                            if (!widget.readOnly)
                              ButleryMenuItem(
                                value: _MenuAction.editTags,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit_note,
                                      size: AppDimensions.iconSizeM,
                                      color: menuCs.primary,
                                    ),
                                    const SizedBox(
                                      width: AppDimensions.spacingM,
                                    ),
                                    Text(context.l10n.recipeEditTags),
                                  ],
                                ),
                              ),
                            if (!widget.readOnly)
                              ButleryMenuItem(
                                key: const ValueKey(
                                  'test-recipe-detail-delete',
                                ),
                                value: _MenuAction.delete,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outlined,
                                      size: AppDimensions.iconSizeM,
                                      color: menuCs.error,
                                    ),
                                    const SizedBox(
                                      width: AppDimensions.spacingM,
                                    ),
                                    Text(
                                      context.l10n.recipeDelete,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: menuCs.error,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            // Collaboration toggle (owner only)
                            if (recipe.createdBy ==
                                ServiceLocator.get<PermissionService>()
                                    .currentUserId)
                              ButleryMenuItem(
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
                                    const SizedBox(
                                      width: AppDimensions.spacingM,
                                    ),
                                    Text(
                                      recipe.isCollaborative
                                          ? context
                                                .l10n
                                                .recipeCollaborationDisable
                                          : context
                                                .l10n
                                                .recipeCollaborationEnable,
                                    ),
                                  ],
                                ),
                              ),
                            // BUT-1819: hidden unless the value is a real
                            // link. Otherwise the menu offers an action that
                            // can only produce an error — the same dead
                            // affordance the source ROW just stopped drawing.
                            if (isSafeExternalUrl(recipe.sourceUrl))
                              ButleryMenuItem(
                                value: _MenuAction.source,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.link_outlined,
                                      size: AppDimensions.iconSizeM,
                                      color: menuCs.primary,
                                    ),
                                    const SizedBox(
                                      width: AppDimensions.spacingM,
                                    ),
                                    Text(context.l10n.recipeViewSource),
                                  ],
                                ),
                              ),
                            // BUT-1079: the captured source artefact (OCR text,
                            // transcript, pasted text) — distinct from the URL
                            // open above.
                            if (recipe.core.sourceArtefact != null)
                              ButleryMenuItem(
                                value: _MenuAction.viewSourceArtefact,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.description_outlined,
                                      size: AppDimensions.iconSizeM,
                                      color: menuCs.primary,
                                    ),
                                    const SizedBox(
                                      width: AppDimensions.spacingM,
                                    ),
                                    Text(context.l10n.recipeViewCapturedSource),
                                  ],
                                ),
                              ),
                            if (kIsWeb)
                              ButleryMenuItem(
                                value: _MenuAction.printRecipe,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.print_outlined,
                                      size: AppDimensions.iconSizeM,
                                      color: menuCs.primary,
                                    ),
                                    const SizedBox(
                                      width: AppDimensions.spacingM,
                                    ),
                                    Text(context.l10n.recipePrint),
                                  ],
                                ),
                              ),
                            ButleryMenuItem(
                              value: _MenuAction.report,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.flag_outlined,
                                    size: AppDimensions.iconSizeM,
                                    color: menuCs.error,
                                  ),
                                  const SizedBox(width: AppDimensions.spacingM),
                                  Text(context.l10n.reportContent),
                                ],
                              ),
                            ),
                          ];
                        },
                        onSelected: (action) => _handleMenuAction(
                          context,
                          action,
                          viewModel,
                          recipe,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Share-request banner: shown when the owner opens their own recipe
              // via a share-request notification (FCM nav helper). Lets them
              // accept or dismiss the request inline without navigating away.
              if (widget.shareRequest != null &&
                  recipe.createdBy ==
                      ServiceLocator.get<PermissionService>().currentUserId)
                SliverToBoxAdapter(
                  child: _ShareRequestBanner(
                    shareRequest: widget.shareRequest!,
                  ),
                ),

              // Recipe content — tablet uses two-column layout, mobile single-column
              SliverToBoxAdapter(
                child: Breakpoints.isMobile(context)
                    ? _buildMobileContent(
                        context,
                        viewModel,
                        recipe,
                        bottomPadding,
                        cs,
                      )
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
            // BUT-410: render heirloom scan above recipe content so the
            // "Farmors lapp" leads visually without losing the parsed text.
            if (recipe.heirloom != null) ...[
              HeirloomSection(heirloom: recipe.heirloom!),
              const SizedBox(height: AppDimensions.spacingMd),
            ],
            if (recipe.completenessScore < incompleteThreshold)
              RecipeDetailSharedWidgets.buildCompletenessBanner(
                context,
                recipe,
              ),
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
    final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
    return ChangeNotifierProvider(
      create: (_) => CookSnapViewModel(
        service: ServiceLocator.get<CookSnapService>(),
        recipeId: recipe.id,
        recipeAuthorId: recipe.createdBy.orEmpty(),
        recipeName: recipe.core.title,
      ),
      child: Consumer<CookSnapViewModel>(
        builder: (context, vm, _) {
          return CookSnapGallery(
            snaps: vm.snaps,
            isLoading: vm.isLoading,
            isUploading: vm.isUploading,
            currentUserId: currentUserId,
            error: vm.error,
            onAdd: () => _showAddSnapSheet(context, vm, recipe),
            onDelete: (snapId) => _deleteCookSnapWithUndo(snapId, vm),
            onReport: (snap) => ReportContentDialog.show(
              context: context,
              contentType: ContentType.cookSnap,
              contentId: snap.id,
              contentOwnerId: snap.userId,
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddSnapSheet(
    BuildContext context,
    CookSnapViewModel vm,
    Recipe recipe,
  ) async {
    final source = await ImagePickerDialogs.showImageSourceDialog(context);
    if (source == null || !mounted) return;

    // BUT-901: a cook snap inherits the recipe's visibility. Disclose who will
    // see it before uploading — but only when there IS an audience beyond the
    // author (public or shared recipes). Private recipes add no friction.
    final audience = cookSnapAudience(
      recipe,
      ServiceLocator.get<PermissionService>().currentUserId.orEmpty(),
      _friendDisplayNames(),
    );
    // BUT-1214: the disclosure doubles as the per-snap override choice —
    // share with the recipe's audience (default) or keep the photo
    // author-only. Private recipes skip the dialog; the audience is already
    // just the author, so an override is meaningless there.
    var visibility = CookSnapVisibility.sameAsRecipe;
    if (audience.scope != CookSnapVisibilityScope.private) {
      if (!context.mounted) return;
      final choice = await _confirmSnapVisibility(context, audience);
      if (choice == null || !mounted) return;
      visibility = choice;
    }

    vm.addSnap(source: source, visibility: visibility);
  }

  Map<String, String> _friendDisplayNames() {
    final names = <String, String>{};
    try {
      for (final f in ServiceLocator.get<UnifiedFriendsService>().friendsList) {
        names[f.uid] = f.displayName;
      }
    } catch (_) {
      // Friends unavailable — the disclosure falls back to a count.
    }
    return names;
  }

  /// BUT-901: confirmation that discloses the cook snap's audience (it inherits
  /// the parent recipe's visibility) before upload. BUT-1214: also offers the
  /// per-snap override — "Samma som receptet" (default) or "Bara jag". Returns
  /// the chosen visibility, or null if cancelled.
  Future<CookSnapVisibility?> _confirmSnapVisibility(
    BuildContext context,
    ({CookSnapVisibilityScope scope, List<String> resolvedNames, int total})
    audience,
  ) {
    final String message;
    if (audience.scope == CookSnapVisibilityScope.public) {
      message = context.l10n.cookSnapVisibilityPublic;
    } else {
      // Shared: never under-state — formatCommentAudience discloses the true
      // total (unresolved members counted), falling back to a count-only label.
      final formatted = formatCommentAudience(
        audience.resolvedNames,
        audience.total,
        countLabel: context.l10n.recipeCommentVisiblePeople,
      );
      message = context.l10n.cookSnapVisibleTo(formatted.orEmpty());
    }

    return showCookSnapVisibilityDialog(context, message: message);
  }

  /// BUT-937: confirm-dialog + 7s snackbar undo mirroring the comment
  /// pattern shipped in BUT-943 (recipe_detail_comments.dart:300-338).
  /// Snap stays visible during the window (no optimistic removal);
  /// timeout commits the delete, Undo tap short-circuits it.
  Future<void> _deleteCookSnapWithUndo(
    String snapId,
    CookSnapViewModel vm,
  ) async {
    final confirmed = await CommonDialogActions.showDeleteConfirmation(
      context: context,
      itemName: '', // The dialog already says "Delete photo"; no identifier.
      itemType: 'foto',
      icon: Icons.photo_outlined,
    );
    if (confirmed != true || !mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    var undone = false;
    final controller = SnackBarUtils.showUndo(
      context,
      context.l10n.cookSnapDeletedUndoMessage,
      onUndo: () => undone = true,
    );
    await controller?.closed;
    if (undone || !mounted) return;

    await vm.deleteSnap(snapId);
  }

  Future<void> _printRecipe(Recipe recipe) async {
    await print_service.printRecipeHtml(recipe);
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    _MenuAction action,
    RecipeDetailViewModel viewModel,
    Recipe recipe,
  ) async {
    switch (action) {
      case _MenuAction.edit:
        assert(!widget.readOnly, 'edit must be unreachable in readOnly mode');
        _actions.editRecipe(context);
      case _MenuAction.fork:
        Navigator.pushNamed(
          context,
          Routes.manualEntry,
          arguments: {
            'initialRecipe': recipe.copyWith(
              title: context.l10n.recipeDuplicateTitle(recipe.title),
            ),
            'isTemplate': true,
          },
        );
      case _MenuAction.addToMenu:
        await _actions.addToMenu(context);
      case _MenuAction.generateShoppingList:
        await _actions.generateShoppingListFromRecipe(context);
      case _MenuAction.reTag:
        assert(!widget.readOnly, 'reTag must be unreachable in readOnly mode');
        await _actions.retagRecipe(context);
      case _MenuAction.editTags:
        assert(
          !widget.readOnly,
          'editTags must be unreachable in readOnly mode',
        );
        final overrides = await TagEditorDialog.show(context, recipe);
        if (overrides != null && context.mounted) {
          // BUT-1304: route the persist through the ViewModel (MVVM) instead of
          // hitting UnifiedRecipeService directly from the View. The VM owns the
          // optimistic local update + revert-on-failure.
          final saved = await viewModel.updateRecipeTagOverrides(overrides);
          if (!saved && context.mounted) {
            SnackBarUtils.showError(context, context.l10n.commonErrorOccurred);
          }
        }
      case _MenuAction.delete:
        assert(!widget.readOnly, 'delete must be unreachable in readOnly mode');
        await _actions.deleteRecipe(context);
      case _MenuAction.toggleCollaboration:
        await _actions.toggleCollaboration(context);
      case _MenuAction.source:
        // BUT-1819: the SAME predicate the menu item is gated on (:690). It
        // used to be `isNotEmpty` here, which is weaker — harmless, since a
        // hidden item cannot be dispatched, but it is the version a future
        // editor reads as the rule.
        if (isSafeExternalUrl(recipe.sourceUrl)) {
          _actions.handleSourceUrlClick(context, recipe.sourceUrl!);
        }
      case _MenuAction.viewSourceArtefact:
        final artefact = recipe.core.sourceArtefact;
        if (artefact != null) {
          showSourceArtefactSheet(
            context: context,
            artefact: artefact,
            onReextract: () =>
                _reextractFromSource(context, artefact, viewModel),
          );
        }
      case _MenuAction.printRecipe:
        _printRecipe(recipe);
      case _MenuAction.report:
        ReportContentDialog.show(
          context: context,
          contentType: ContentType.recipe,
          contentId: recipe.id,
          contentOwnerId: recipe.createdBy,
        );
    }
  }

  /// BUT-1205: confirm + drive the re-extract. All business logic (strategy
  /// selection, import, copyWith assembly, persistence, id/createdAt/
  /// sourceArtefact preservation) lives in
  /// [RecipeDetailViewModel.reextractFromSource]; the View only gates it behind
  /// a confirmation dialog (it discards manual edits) and maps the returned
  /// outcome to snackbar feedback. The source sheet UI itself lives in
  /// recipe_detail/recipe_source_artefact_sheet.dart.
  Future<void> _reextractFromSource(
    BuildContext context,
    SourceArtefact artefact,
    RecipeDetailViewModel viewModel,
  ) async {
    final confirmed = await CommonDialogActions.showActionConfirmation(
      context: context,
      title: context.l10n.recipeSourceReextractConfirmTitle,
      message: context.l10n.recipeSourceReextractConfirmMessage,
      confirmText: context.l10n.recipeSourceReextractConfirmAction,
      icon: Icons.refresh_outlined,
      isDangerous: true,
    );
    if (confirmed != true || !context.mounted) return;

    SnackBarUtils.showInfo(
      context,
      context.l10n.recipeSourceReextractInProgress,
    );

    final outcome = await viewModel.reextractFromSource(artefact);
    if (!context.mounted) return;

    if (outcome == ReextractOutcome.success) {
      SnackBarUtils.showSuccess(
        context,
        context.l10n.recipeSourceReextractSuccess,
      );
    } else {
      SnackBarUtils.showError(
        context,
        context.l10n.recipeSourceReextractFailed,
      );
    }
  }
}

/// UI Redesign: Hero button with solid cream background and green icon.
/// Used for back button and action buttons in recipe detail hero image.
/// Diameter of the paper ring behind a hero icon button (Komponentark
/// v1:81-89 draws 40 px). The hitbox around it is 48 dp.
const double _paperRingSize = 40;

/// An icon button on the media hero: an ink icon in a paper ring, 48 dp
/// hitbox, the canonical focus ring around the hitbox (Komponentark
/// v1:81-89 "Ikonknappar i pappersringar"; Grafisk manual v6:381).
///
/// Paper and ink are the same in both modes, because the ring stands on a
/// photo, not on the theme's surface: onPrimary is paper #F5F4ED and
/// primary is ink #24382C in both schemes (lib/theme/app_colors.dart
/// lightColorScheme and darkColorScheme).
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

    // Tooltip alone gives screen readers a hint, not a "button" role —
    // wrap explicitly so callers without their own Semantics ancestor
    // (e.g. the back button at AppBar.leading) still announce correctly.
    final tappable = ButleryControlFocus(
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          child: SizedBox(
            width: AppDimensions.minTouchTarget,
            height: AppDimensions.minTouchTarget,
            child: Center(
              child: _PaperRing(
                child: Icon(
                  icon,
                  color: cs.primary,
                  size: AppDimensions.iconSizeM,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final hasTooltip = tooltip != null && tooltip!.isNotEmpty;
    final labelled = hasTooltip
        ? Semantics(
            label: context.l10n.a11yHeroButton(tooltip!),
            button: true,
            child: Tooltip(message: tooltip!, child: tappable),
          )
        : tappable;
    return labelled;
  }
}

/// The 40 px paper circle behind a hero icon.
class _PaperRing extends StatelessWidget {
  const _PaperRing({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('recipe-detail-paper-ring'),
      width: _paperRingSize,
      height: _paperRingSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary,
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

/// The sticky action bar over the bottom navigation (Komponentark v1
/// "Sticky action bar": "Börja laga" and "Lägg 2 varor", 1 px top edge, the
/// content's side margin; Skarmar v12 del 1 'Receptdetalj').
///
/// It holds the view's one saffron action (Grafisk manual v6:219): "Börja
/// laga" on your own recipe, "Spara till mitt kök" on someone else's
/// (Skarmar v12 etapp 11). The other button is ink. Below 360 dp the
/// buttons stack.
class _RecipeActionBar extends StatelessWidget {
  const _RecipeActionBar({
    required this.isOthersRecipe,
    required this.onStartCooking,
    required this.onSaveToMyKitchen,
    required this.onAddToShoppingList,
  });

  final bool isOthersRecipe;
  final VoidCallback onStartCooking;
  final VoidCallback onSaveToMyKitchen;
  final VoidCallback onAddToShoppingList;

  static const double _stackBelow = 360;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    final startCooking = Semantics(
      identifier: 'btn-start-cooking',
      button: true,
      child: FilledButton(
        key: const ValueKey('test-recipe-detail-start-cooking'),
        style: isOthersRecipe ? null : ComponentThemes.heroButtonStyle(cs),
        onPressed: onStartCooking,
        child: Text(l10n.recipeStartCookingTooltip),
      ),
    );

    final Widget first;
    final Widget second;
    if (isOthersRecipe) {
      first = Semantics(
        identifier: 'btn-save-copy',
        button: true,
        child: FilledButton(
          key: const ValueKey('test-recipe-detail-save-copy'),
          style: ComponentThemes.heroButtonStyle(cs),
          onPressed: onSaveToMyKitchen,
          child: Text(l10n.recipeSaveToMyKitchen),
        ),
      );
      second = startCooking;
    } else {
      first = startCooking;
      // Light: the theme's ink fill (Skarmar v12 del 1 'Receptdetalj',
      // background:#24382c). Dark: no fill, a 1.5 px paper outline and
      // paper text (Skarmar v12 del 1 'Receptdetalj — mörkt läge',
      // border:1.5px solid #f5f4ed), since ink on #17251D does not read as
      // a button. cs.onSurface is paper #F5F4ED in the dark scheme
      // (app_colors.dart:331).
      final isDark = cs.brightness == Brightness.dark;
      second = FilledButton(
        key: const ValueKey('test-recipe-detail-add-to-list'),
        style: isDark
            ? FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: cs.onSurface,
                side: BorderSide(color: cs.onSurface, width: 1.5),
              )
            : null,
        onPressed: onAddToShoppingList,
        child: Text(l10n.recipeAddToShoppingList),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingL,
          vertical: AppDimensions.spacingModerate,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < _stackBelow) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  first,
                  const SizedBox(height: AppDimensions.spacingSm),
                  second,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: first),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(child: second),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Banner shown when the recipe owner opens their own recipe in response to a
/// share-request notification. Lets them accept (share) or dismiss inline.
class _ShareRequestBanner extends StatefulWidget {
  const _ShareRequestBanner({required this.shareRequest});

  final SocialRequest shareRequest;

  @override
  State<_ShareRequestBanner> createState() => _ShareRequestBannerState();
}

class _ShareRequestBannerState extends State<_ShareRequestBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final name = widget.shareRequest.fromUserName.orEmpty();

    return ColoredBox(
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingM,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.recipeShareRequestBanner(name),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingM),
            TextButton(
              onPressed: () => _onShare(name),
              child: Text(context.l10n.recipeShareRequestShareAction(name)),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _dismissed = true),
              tooltip: context.l10n.commonClose,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onShare(String name) async {
    final ok = await ServiceLocator.get<SocialRecipeService>()
        .acceptRecipeShareRequest(widget.shareRequest);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.recipeShareRequestShared(name))),
      );
      setState(() => _dismissed = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.commonErrorOccurred)),
      );
    }
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

    // The same paper ring as the other hero buttons (Komponentark v1:81-89).
    return ButleryControlFocus(
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      child: SizedBox(
        width: AppDimensions.minTouchTarget,
        height: AppDimensions.minTouchTarget,
        child: PopupMenuButton<_MenuAction>(
          padding: EdgeInsets.zero,
          icon: _PaperRing(
            child: Icon(icon, color: cs.primary, size: AppDimensions.iconSizeM),
          ),
          itemBuilder: itemBuilder,
          onSelected: onSelected,
        ),
      ),
    );
  }
}
