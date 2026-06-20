/// Personal recipe management view with filtering, social integration, and offline support.
/// Displays user's recipe collection with search/filter capabilities, friend notifications,
/// and offline synchronization. Uses multi-provider architecture for state management.
/// **Key Features:**
/// - Recipe browsing with search, filtering, and sorting
/// - Social notifications (friend requests, shared content)
/// - Offline-first design with sync status
/// - Multi-provider integration (RecipeListViewModel, FriendsViewModel, SharedContentCoordinatorViewModel)
///
/// BUT-441: facade pattern. Per-recipe rendering, empty/onboarding states,
/// discovery shelves, selection-mode AppBar, and filter-chip helpers live
/// in `lib/views/mina_recept/`. Was 1017 lines (+48% over the accepted-large
/// entry of 687 in `docs/architecture/ACCEPTED_LARGE_FILES.md`); now under
/// that entry. Future slice candidates if the 500-line code-style cap
/// becomes binding: `_buildCookingSessionCard` + `_safeLoadSocialData` +
/// `_safeLoadRecipeData`.

// lib/views/main_views/mina_recept_view.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ViewModel integration for comprehensive state management
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/viewmodels/recipe/recipe_query_viewmodel.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/views/personal_tags_view.dart';

// Models
import 'package:butlery/models/recipe_unified.dart';

// Constants and theming
import 'package:butlery/core/extensions/localization_extension.dart';

import 'package:butlery/core/constants/routes.dart';

// Widget components for modern UI architecture
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/swipe_hint_banner.dart';
import 'package:butlery/widgets/common/search_filter/quick_filter_chips.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/indicators/sync_indicator.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/social_components/recipe_list_avatar_badge.dart';
import 'package:butlery/widgets/common/main_view_header.dart';
import 'package:butlery/widgets/cooking/cooking_session_card.dart';
import 'package:butlery/widgets/social/family_presence_bar.dart';

// BUT-408: live cooking session presence
import 'package:butlery/models/cooking/cooking_session.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/unified/operations/cooking/cooking_session_module.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/cooking/cooking_session_stream.dart';

// Service integration for functionality and data management
import 'package:butlery/services/offline_service.dart' as offline_service;
import 'package:butlery/services/user_service.dart';

// Theme system integration
import 'package:butlery/theme/app_dimensions.dart';

// Core services and utilities
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/models/seasonal/seasonal_month.dart';
import 'package:butlery/services/seasonal/seasonal_hero_service.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/user_allergen_preferences.dart';

// BUT-441 facade extractions
import 'package:butlery/views/mina_recept/discovery_shelves_widget.dart';
import 'package:butlery/views/mina_recept/empty_state_widgets.dart';
import 'package:butlery/views/mina_recept/filter_chip_helpers.dart';
import 'package:butlery/views/mina_recept/recipe_card_widget.dart';
import 'package:butlery/views/mina_recept/selection_app_bar.dart';

/// BUT-403 identifier scheme for this view (browser a11y tree hooks):
///  - `btn-import-recipe`  → empty state "import" CTA
///  - `btn-add-recipe`     → empty state "add recipe" link
///  - `recipe-card-{index}` → each recipe card in the list/grid
///
/// Personal recipe management view with multi-provider architecture.
class MinaReceptView extends StatefulWidget {
  const MinaReceptView({super.key});

  @override
  State<MinaReceptView> createState() => _MinaReceptViewState();
}

class _MinaReceptViewState extends State<MinaReceptView> {
  late final RecipeListViewModel _recipeListViewModel;
  late final RecipeQueryViewModel _queryViewModel;
  late final FriendsViewModel _friendsViewModel;

  @override
  void initState() {
    super.initState();
    _recipeListViewModel = ServiceLocator.get<RecipeListViewModel>();
    _queryViewModel = RecipeQueryViewModel();
    _friendsViewModel = ServiceLocator.get<FriendsViewModel>();
  }

  @override
  void dispose() {
    _recipeListViewModel.dispose();
    _queryViewModel.dispose();
    _friendsViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Recipe collection state management
        ChangeNotifierProvider<RecipeListViewModel>.value(
          value: _recipeListViewModel,
        ),
        // User profile and authentication service
        ChangeNotifierProvider.value(value: ServiceLocator.get<UserService>()),
        // Social relationship and friend management
        ChangeNotifierProvider<FriendsViewModel>.value(
            value: _friendsViewModel),
        // Shared content and notification management (modular coordinator)
        ChangeNotifierProvider.value(
            value: ServiceLocator.get<SharedContentCoordinatorViewModel>()),
        // Offline functionality and synchronization service
        ChangeNotifierProvider.value(
            value: ServiceLocator.get<offline_service.OfflineService>()),
        // Personal tags for filtering (singleton from DI)
        ChangeNotifierProvider<PersonalTagViewModel>.value(
          value: ServiceLocator.get<PersonalTagViewModel>(),
        ),
        ChangeNotifierProvider<RecipeQueryViewModel>.value(
          value: _queryViewModel,
        ),
      ],
      child: const _MinaReceptViewContent(),
    );
  }
}

/// Stateful content widget for recipe view with filter and social data management.
class _MinaReceptViewContent extends StatefulWidget {
  const _MinaReceptViewContent();

  @override
  State<_MinaReceptViewContent> createState() => _MinaReceptViewContentState();
}

/// State class managing filter visibility and social data loading.
class _MinaReceptViewContentState extends State<_MinaReceptViewContent> {
  /// Filter panel visibility state.
  bool _showFilters = false;

  /// BUT-409: cached seasonal month future. Resolved once in initState so the
  /// hero header's FutureBuilder doesn't rebuild a new future each frame.
  late final Future<SeasonalMonth?> _seasonalMonthFuture;
  late final SeasonalHeroService _seasonalHeroService;

  /// BUT-408: merged cooking-session stream, owned by this state so parent
  /// rebuilds don't re-allocate subscriptions.
  final CookingSessionStreamHolder _sessionsHolder =
      CookingSessionStreamHolder();

  /// BUT-1028: scroll-offset persistence for the recipe list. The controller is
  /// shared by both view modes via an ambient [PrimaryScrollController] (only
  /// one of the grid/list is mounted at a time), so a single controller covers
  /// both without threading one through the shared `responsiveListGrid` helper.
  final ScrollController _scrollController = ScrollController();
  late final PersistenceService _persistence;

  /// 300ms debounce mirroring BUT-1018's filter-write debounce, so rapid
  /// scrolling doesn't burn a prefs write per frame.
  Timer? _scrollPersistTimer;

  /// Pending offset to restore once the list has laid out enough extent. Held
  /// across post-frame retries because recipe data loads asynchronously after
  /// first paint, so the scroll extent is 0 on the earliest frames.
  double? _pendingRestoreOffset;
  int _restoreAttempts = 0;

  @override
  void dispose() {
    _scrollPersistTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    // Best-effort flush of the final offset on teardown (route change / pop)
    // before the controller detaches, so we don't lose the last scroll. The
    // listener is removed first so no later debounce can overwrite this write.
    if (_scrollController.hasClients) {
      _persistence.setRecipeListScrollOffset(_scrollController.offset);
    }
    _scrollController.dispose();
    _sessionsHolder.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    _scrollPersistTimer?.cancel();
    _scrollPersistTimer = Timer(
      const Duration(milliseconds: 300),
      () => _persistence.setRecipeListScrollOffset(offset),
    );
  }

  Future<void> _restoreScrollOffset() async {
    final saved = await _persistence.getRecipeListScrollOffset();
    if (!mounted || saved <= 0) return;
    _pendingRestoreOffset = saved;
    _applyPendingRestore();
  }

  /// Jumps to the saved offset once the list reports a non-zero max extent.
  /// Retries across frames (data loads async) up to a bounded cap, then gives
  /// up — restore is best-effort ("within a few hundred px"), never blocking.
  void _applyPendingRestore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingRestoreOffset == null) return;
      final notReady = !_scrollController.hasClients ||
          _scrollController.position.maxScrollExtent <= 0;
      if (notReady) {
        if (_restoreAttempts++ < 30) _applyPendingRestore();
        return;
      }
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(_pendingRestoreOffset!.clamp(0.0, max));
      _pendingRestoreOffset = null;
    });
  }

  /// Initialize state and load social/recipe data after widget mount.
  @override
  void initState() {
    super.initState();

    // BUT-409: seasonal data loads once from bundled asset.
    _seasonalHeroService = ServiceLocator.get<SeasonalHeroService>();
    _seasonalMonthFuture = _seasonalHeroService.getCurrentMonth();

    // BUT-1028: scroll-offset persistence.
    _persistence = ServiceLocator.get<PersistenceService>();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _safeLoadSocialData();
        _safeLoadRecipeData();
        // Initialize personal tags now that user is authenticated
        context.read<PersonalTagViewModel>().initialize();
        // Load search history for recent search chips
        context.read<RecipeListViewModel>().loadSearchHistory();
        // BUT-1028: restore the previous scroll position (best-effort).
        _restoreScrollOffset();
      }
    });
  }

  /// Load social data with delayed refresh and mount safety checks.
  void _safeLoadSocialData() {
    try {
      // 🚀 PERFORMANCE FIX: Only refresh if content hasn't been loaded yet
      // SocialRecipeService handles initial loading automatically via auth listener
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;

        try {
          final friendsViewModel = context.read<FriendsViewModel>();

          // Only refresh friends - SharedContentCoordinatorViewModel loads automatically via service
          AppLogger.info(
              '🔄 Refreshing friends data for MinaReceptView (delayed)...');
          friendsViewModel.refresh();

          AppLogger.success(
              '✅ Friends data refreshed for MinaReceptView (delayed)');
        } catch (e) {
          AppLogger.error(
              '❌ Error during delayed friends data refresh in MinaReceptView',
              e);
        }
      });
    } catch (e) {
      AppLogger.error(
          '❌ Error setting up delayed friends refresh in MinaReceptView', e);
    }
  }

  /// Load recipe data through RecipeListViewModel with mount safety checks.
  void _safeLoadRecipeData() {
    try {
      if (mounted) {
        AppLogger.info('🔄 Loading recipe data for MinaReceptView...');

        // RecipeListViewModel loads data automatically from RecipeService
        // No explicit refresh needed here - provider handles this

        AppLogger.success('✅ Recipe data ready for MinaReceptView');
      }
    } catch (e) {
      AppLogger.error('❌ Error loading recipe data in MinaReceptView', e);
    }
  }

  // Sync with online
  Future<void> _syncWithOnline() async {
    final offlineService = context.read<offline_service.OfflineService>();
    final viewModel = context.read<RecipeListViewModel>();

    if (offlineService.isOnline) {
      try {
        if (mounted) {
          SnackBarUtils.showInfo(context, context.l10n.statusSyncing);
        }

        final result = await offlineService.syncNow();
        await viewModel.refresh();

        if (mounted) {
          if (result.success && !(result.isRetry)) {
            SnackBarUtils.showSuccess(context, context.l10n.syncComplete);
          } else if (result.success && result.isRetry) {
            SnackBarUtils.showInfo(context, result.message);
          } else {
            SnackBarUtils.showError(context, result.message);
          }
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showError(
              context,
              context.l10n.syncFailed(
                SnackBarUtils.userFriendlyMessage(context, e),
              ));
        }
      }
    }
  }

  /// Build recipe interface with filtering, search, sorting, and social integration.
  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecipeListViewModel>();
    final isOnline = context
        .select<offline_service.OfflineService, bool>((svc) => svc.isOnline);
    final allergenPrefs = context.select<UserService, UserAllergenPreferences>(
        (svc) => svc.allergenPreferences);
    final personalTags = context.watch<PersonalTagViewModel>().tags;
    final recipeCount = viewModel.recipes.length;

    // Selection mode uses a different app bar
    final PreferredSizeWidget appBar = viewModel.isSelectionMode
        ? buildMinaReceptSelectionAppBar(context, viewModel)
        : MainViewHeader(
            title: context.l10n.minaReceptHeaderTitle,
            ghostIllustration: VegetableType.broccoli,
            countBadge: context.l10n.recipeCountBadge(recipeCount),
            trailing: const RecipeListAvatarBadge(),
            actions: [
              // BUT-977: surface the pantry-match IngredientSearchView power
              // feature (previously only reachable via Cmd+K). Distinct
              // kitchen icon so it doesn't read as the in-list text filter.
              IconButton(
                icon: const Icon(Icons.kitchen_outlined),
                tooltip: context.l10n.ingredientSearchTitle,
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.ingredientSearch),
              ),
              IconButton(
                icon: Icon(
                  viewModel.isGridView ? Icons.view_list : Icons.grid_view,
                ),
                tooltip: viewModel.isGridView
                    ? context.l10n.viewModeList
                    : context.l10n.viewModeGrid,
                onPressed: viewModel.toggleViewMode,
              ),
              LayoutComponents.offlineStatusIcon(),
            ],
          );

    return Scaffold(
      appBar: appBar,
      body: FocusTraversalGroup(
          child: Column(
        children: [
          LayoutComponents.offlineIndicator(),
          SyncIndicator(
            hasPendingWrites: viewModel.hasPendingWrites,
            isFromCache: viewModel.isFromCache,
          ),
          // BUT-407: live online-members presence bar (union across groups).
          const FamilyPresenceBar(),
          // BUT-408: live cooking session card for the user's friend groups.
          _buildCookingSessionCard(),
          if (!viewModel.isSelectionMode) ...[
            SearchFilterWidget(
              searchQuery: viewModel.searchQuery,
              onSearchChanged: viewModel.updateSearch,
              searchHint: context.l10n.recipeSearchHint,
              activeTimeFilters: viewModel.activeTimeFilters,
              activeMealTypeFilters: viewModel.activeMealTypeFilters,
              activeRatingFilters: viewModel.activeRatingFilters,
              activeAllergenFilters: viewModel.activeAllergenFilters,
              activeDietaryFilters: viewModel.activeDietaryFilters,
              onTimeFilterToggle: viewModel.toggleTimeFilter,
              onMealTypeFilterToggle: viewModel.toggleMealTypeFilter,
              onRatingFilterToggle: viewModel.toggleRatingFilter,
              onAllergenFilterToggle: viewModel.toggleAllergenFilter,
              onDietaryFilterToggle: viewModel.toggleDietaryFilter,
              personalTagIds: personalTags,
              activePersonalTagFilters: viewModel.activePersonalTagFilters,
              excludedPersonalTagFilters: viewModel.excludedPersonalTagFilters,
              onPersonalTagFilterToggle: viewModel.togglePersonalTagFilter,
              onExcludedPersonalTagFilterToggle:
                  viewModel.toggleExcludedPersonalTagFilter,
              onManagePersonalTags: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PersonalTagsView(),
                  ),
                );
              },
              // BUT-987: deep-link to allergen/dietary prefs from the filter
              // panel — the prefs drive the allergen/dietary filters above.
              onManageFoodPreferences: () =>
                  Navigator.of(context).pushNamed(Routes.settingsAllergens),
              searchHistory: viewModel.searchHistory,
              onHistoryTap: (query) => viewModel.updateSearch(query),
              onHistoryRemove: viewModel.removeFromSearchHistory,
              showFilters: _showFilters,
              onToggleFilters: () =>
                  setState(() => _showFilters = !_showFilters),
              hasActiveFilters: viewModel.hasActiveFilters,
              onClearAllFilters: viewModel.clearAllFilters,
              resultCount: recipeCount,
              showStats: false,
            ),
            Selector<UserService, Set<String>>(
              selector: (_, svc) => svc.allergenPreferences.trackedAllergens,
              builder: (context, trackedAllergens, _) => QuickFilterChips(
                options: [
                  ...QuickFilterChips.getDefaultRecipeFilters(context),
                  ...QuickFilterChips.getAllergenFilters(trackedAllergens),
                ],
                selectedIds: getMinaReceptQuickFilterIds(viewModel),
                onFilterToggle: (filterId) => handleMinaReceptQuickFilterToggle(
                  context,
                  viewModel,
                  filterId,
                ),
                trailing: MinaReceptSortChip(viewModel: viewModel),
              ),
            ),
            // BUT-982: first-use hint teaching the swipe-to-edit / -delete card
            // gesture; self-dismisses once per device.
            const SwipeHintBanner(),
          ],
          Expanded(child: _buildContent(viewModel, isOnline, allergenPrefs)),
        ],
      )),
    );
  }

  /// BUT-408: Live "X lagar just nu" card. Combines all the user's friend
  /// category groups into a single merged stream so the card shows any
  /// currently-cooking friend regardless of which group they're in.
  /// Hidden entirely when no active sessions stream through.
  Widget _buildCookingSessionCard() {
    final module = ServiceLocator.tryGet<CookingSessionModule>();
    final friends = ServiceLocator.tryGet<UnifiedFriendsService>();
    if (module == null || friends == null) return const SizedBox.shrink();

    final userId = friends.currentUserId;
    if (userId == null) return const SizedBox.shrink();

    final groups = friends.categoriesList
        .where((FriendCategory c) =>
            c.ownerId == userId || c.friendUserIds.contains(userId))
        .map((g) => g.id)
        .toList(growable: false);
    if (groups.isEmpty) return const SizedBox.shrink();

    _sessionsHolder.refresh(module, groups, userId);
    final stream = _sessionsHolder.stream;
    if (stream == null) return const SizedBox.shrink();

    return StreamBuilder<List<CookingSession>>(
      stream: stream,
      builder: (_, snapshot) {
        final sessions = snapshot.data ?? const <CookingSession>[];
        return CookingSessionCard(sessions: sessions);
      },
    );
  }

  void _handleDeleteWithUndo(RecipeListViewModel viewModel, Recipe recipe) {
    final id = recipe.id;
    viewModel.deleteRecipe(id);
    if (mounted) {
      SnackBarUtils.showSuccessWithAction(
        context,
        context.l10n.recipeDeleted,
        actionLabel: context.l10n.commonUndo,
        onAction: () => viewModel.undoDeleteById(id),
        duration: const Duration(seconds: 5),
      );
    }
  }

  Widget _buildContent(
    RecipeListViewModel viewModel,
    bool isOnline,
    UserAllergenPreferences allergenPrefs,
  ) {
    if (viewModel.isLoading) {
      return Column(
        children: [
          Expanded(child: StateWidget.skeletonRecipeList(itemCount: 5)),
        ],
      );
    }

    if (viewModel.hasError) {
      return StateWidget.error(
        message: viewModel.error!,
        onAction: () {
          viewModel.clearError();
          viewModel.refresh();
        },
        actionLabel: context.l10n.commonRetry,
      );
    }

    final recipes = viewModel.recipes;

    if (recipes.isEmpty) {
      return viewModel.searchQuery.isEmpty && !viewModel.hasActiveFilters
          ? const MinaReceptEmptyState()
          : StateWidget.noSearchResults(
              onAction: viewModel.searchQuery.isNotEmpty
                  ? () => viewModel.updateSearch('')
                  : viewModel.clearAllFilters,
              actionLabel: viewModel.searchQuery.isNotEmpty
                  ? context.l10n.searchClearSearch
                  : context.l10n.searchClearFilters,
            );
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (isOnline) {
          await _syncWithOnline();
        } else {
          await viewModel.refresh();
          if (mounted) {
            SnackBarUtils.showWarning(
                context, context.l10n.offlineShowingLocal);
          }
        }
      },
      child: Column(
        children: [
          if (viewModel.showOnboardingBanner)
            MinaReceptOnboardingBanner(viewModel: viewModel),
          if (viewModel.searchQuery.isEmpty && !viewModel.hasActiveFilters) ...[
            MinaReceptDiscoveryShelves(
              queryVm: context.read<RecipeQueryViewModel>(),
              seasonalMonthFuture: _seasonalMonthFuture,
              seasonalHeroService: _seasonalHeroService,
            ),
          ],
          Expanded(
            // BUT-1028: ambient controller so both grid and list modes attach
            // to the same ScrollController for offset persistence/restore.
            child: PrimaryScrollController(
              controller: _scrollController,
              child: viewModel.isGridView
                  ? GridView.builder(
                      // Distinct key so toggling view mode tears down this
                      // Scrollable before the list-mode one attaches to the
                      // shared controller (avoids a transient double-attach).
                      key: const ValueKey('recipe-grid-scrollable'),
                      primary: true,
                      padding: AppDimensions.responsiveContentPadding(context),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: LayoutComponents.isMobile(context)
                            ? 2
                            : LayoutComponents.isTablet(context)
                                ? 3
                                : 4,
                        crossAxisSpacing:
                            AppDimensions.responsiveGridSpacing(context),
                        mainAxisSpacing:
                            AppDimensions.responsiveGridSpacing(context),
                        childAspectRatio: 0.75,
                      ),
                      itemCount: recipes.length,
                      itemBuilder: (context, index) => MinaReceptRecipeCard(
                        viewModel: viewModel,
                        recipe: recipes[index],
                        allergenPrefs: allergenPrefs,
                        onDelete: (recipe) =>
                            _handleDeleteWithUndo(viewModel, recipe),
                        index: index,
                      ),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('recipe-list-scrollable'),
                      child: LayoutComponents.responsiveListGrid(
                        items: recipes,
                        tabletColumns: 2,
                        desktopColumns: 3,
                        spacing: AppDimensions.responsiveGridSpacing(context),
                        padding:
                            AppDimensions.responsiveContentPadding(context),
                        shrinkWrap: false,
                        gridChildAspectRatio: 0.75,
                        animate: true,
                        itemBuilder: (context, recipe) => MinaReceptRecipeCard(
                          viewModel: viewModel,
                          recipe: recipe,
                          allergenPrefs: allergenPrefs,
                          onDelete: (r) => _handleDeleteWithUndo(viewModel, r),
                          index: recipes.indexOf(recipe),
                        ),
                      ),
                    ),
            ),
          ),
          if (viewModel.canLoadMore)
            Padding(
              padding: AppDimensions.responsiveContentPadding(context),
              child: ActionButtons.primaryButton(
                context,
                label: context.l10n.recipeShowMore,
                onPressed: () => viewModel.loadMore(),
              ),
            ),
        ],
      ),
    );
  }
}
