/// Personal recipe management view with filtering, social integration, and offline support.
/// Displays user's recipe collection with search/filter capabilities, friend notifications,
/// and offline synchronization. Uses multi-provider architecture for state management.
/// **Key Features:**
/// - Recipe browsing with search, filtering, and sorting
/// - Social notifications (friend requests, shared content)
/// - Offline-first design with sync status
/// - Multi-provider integration (RecipeListViewModel, FriendsViewModel, SharedContentCoordinatorViewModel)
///
/// HEM-HERO (package 6): this view is the Hem tab. The greeting and the
/// week's plan for tonight stand above the library (Skarmar v12 del 1
/// #hemrecept: "hälsning + ikväll överst, receptbiblioteket direkt under"),
/// in `lib/views/hem/`; an empty library is Hem's empty state (#hemtom).
///
/// Q6-16 = B (produktbeslut 2026-09-27b): Hem has no top bar. The greeting
/// is at the top, under the offline banner, and "Välj", the ingredient
/// search and the grid/list toggle are in the library's header row
/// (MinaReceptLibraryHeader), which also carries selection mode (B-46 on
/// Hem).
///
/// BUT-441: facade pattern. Per-recipe rendering, empty/onboarding states,
/// discovery shelves, selection-mode AppBar, and filter-chip helpers live
/// in `lib/views/mina_recept/`. It carries a rationale row in
/// `docs/architecture/ACCEPTED_LARGE_FILES.md`, which is where its measured
/// length lives. Future slice candidates if the 500-line code-style cap
/// becomes binding: `_buildCookingSessionCard` + `_safeLoadSocialData` +
/// `_safeLoadRecipeData`.

// lib/views/main_views/mina_recept_view.dart

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/keyboard/app_actions.dart'
    show mainTabSwitchRequest;
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/viewmodels/hem/hem_viewmodel.dart';
import 'package:butlery/views/hem/hem_empty_state.dart';
import 'package:butlery/views/hem/hem_library_scroll.dart';
import 'package:butlery/views/hem/hem_section.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart'
    show LayoutScaffolds;

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
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/content_sized_grid.dart';
import 'package:butlery/widgets/common/responsive/sliver_responsive_list_grid.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/swipe_hint_banner.dart';
import 'package:butlery/widgets/common/search_filter/quick_filter_chips.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
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
import 'package:butlery/views/mina_recept/library_header_row.dart';
import 'package:butlery/views/mina_recept/recipe_card_widget.dart';
import 'package:butlery/views/mina_recept/selection_app_bar.dart';

/// BUT-403 identifier scheme for this view (browser a11y tree hooks):
///  - `btn-add-recipe`     → empty state "Lägg till recept"
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
  late final HemViewModel _hemViewModel;

  @override
  void initState() {
    super.initState();
    _recipeListViewModel = ServiceLocator.get<RecipeListViewModel>();
    _queryViewModel = RecipeQueryViewModel();
    _friendsViewModel = ServiceLocator.get<FriendsViewModel>();
    _hemViewModel = HemViewModel.fromServices();
    // HEM-HERO: the week is often read before the library has loaded; the
    // hero picks up its recipe (Börja laga, minutes, pantry) when it lands.
    _recipeListViewModel.addListener(_hemViewModel.resolveRecipe);
  }

  @override
  void dispose() {
    _recipeListViewModel.removeListener(_hemViewModel.resolveRecipe);
    _recipeListViewModel.dispose();
    _queryViewModel.dispose();
    _friendsViewModel.dispose();
    _hemViewModel.dispose();
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
          value: _friendsViewModel,
        ),
        // Shared content and notification management (modular coordinator)
        ChangeNotifierProvider.value(
          value: ServiceLocator.get<SharedContentCoordinatorViewModel>(),
        ),
        // Offline functionality and synchronization service
        ChangeNotifierProvider.value(
          value: ServiceLocator.get<offline_service.OfflineService>(),
        ),
        // Personal tags for filtering (singleton from DI)
        ChangeNotifierProvider<PersonalTagViewModel>.value(
          value: ServiceLocator.get<PersonalTagViewModel>(),
        ),
        ChangeNotifierProvider<RecipeQueryViewModel>.value(
          value: _queryViewModel,
        ),
        ChangeNotifierProvider<HemViewModel>.value(value: _hemViewModel),
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

  /// BUT-1028: scroll-offset persistence for the recipe list. The offset is
  /// read from the library's scroll notifications and restored through the
  /// NestedScrollView's inner controller.
  final GlobalKey<NestedScrollViewState> _nestedScrollKey =
      GlobalKey<NestedScrollViewState>();
  late final PersistenceService _persistence;

  /// The library's last scroll offset, for the flush on teardown.
  double? _lastLibraryOffset;

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
    // Best-effort flush of the final offset on teardown (route change / pop),
    // so we don't lose the last scroll. The timer is cancelled first so no
    // later debounce can overwrite this write.
    final last = _lastLibraryOffset;
    if (last != null) _persistence.setRecipeListScrollOffset(last);
    _sessionsHolder.dispose();
    super.dispose();
  }

  void _onLibraryScrolled(double offset) {
    _lastLibraryOffset = offset;
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
      final inner = _nestedScrollKey.currentState?.innerController;
      final notReady =
          inner == null ||
          inner.positions.length != 1 ||
          inner.position.maxScrollExtent <= 0;
      if (notReady) {
        if (_restoreAttempts++ < 30) _applyPendingRestore();
        return;
      }
      final max = inner.position.maxScrollExtent;
      // The inner position's jumpTo goes through the NestedScrollView, which
      // scrolls the Hem header out first.
      inner.jumpTo(_pendingRestoreOffset!.clamp(0.0, max));
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _safeLoadSocialData();
        _safeLoadRecipeData();
        // Initialize personal tags now that user is authenticated
        context.read<PersonalTagViewModel>().initialize();
        // Load search history for recent search chips
        context.read<RecipeListViewModel>().loadSearchHistory();
        // HEM-HERO: the week's plan for the hero card.
        context.read<HemViewModel>().load();
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
            '🔄 Refreshing friends data for MinaReceptView (delayed)...',
          );
          friendsViewModel.refresh();

          AppLogger.success(
            '✅ Friends data refreshed for MinaReceptView (delayed)',
          );
        } catch (e) {
          AppLogger.error(
            '❌ Error during delayed friends data refresh in MinaReceptView',
            e,
          );
        }
      });
    } catch (e) {
      AppLogger.error(
        '❌ Error setting up delayed friends refresh in MinaReceptView',
        e,
      );
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
            SnackBarUtils.showFailure(context, what: result.message);
          }
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showFailure(
            context,
            what: context.l10n.syncFailed(
              SnackBarUtils.userFriendlyMessage(context, e),
            ),
          );
        }
      }
    }
  }

  /// Build recipe interface with filtering, search, sorting, and social integration.
  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecipeListViewModel>();
    final isOnline = context.select<offline_service.OfflineService, bool>(
      (svc) => svc.isOnline,
    );
    final allergenPrefs = context.select<UserService, UserAllergenPreferences>(
      (svc) => svc.allergenPreferences,
    );
    final personalTags = context.watch<PersonalTagViewModel>().tags;
    final recipeCount = viewModel.recipes.length;
    // Row 4 of produktregler.md:271: an empty library is Hem's empty state.
    final libraryEmpty =
        !viewModel.isLoading &&
        !viewModel.hasError &&
        viewModel.recipes.isEmpty &&
        viewModel.searchQuery.isEmpty &&
        !viewModel.hasActiveFilters;
    final firstName = context.select<UserService, String?>(
      (svc) => hemFirstName(svc.currentUserProfile?.displayName),
    );

    // Q6-16 = B (produktbeslut 2026-09-27b, after the prototype): no top
    // bar. The profile avatar it carried stays on Mer (MoreView), and the
    // offline icon's news is the offline banner, which stays at the top
    // (P3). Välj, the ingredient search, the toggle and selection mode are
    // in the library's header row (_buildLibrary).
    return Scaffold(
      body: FocusTraversalGroup(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // The offline banner, with its count of waiting changes, is the
              // one offline signal on Hem (Skarmar v12 del 4 #hemoffline;
              // package-3 answers A-03 and A-09). The separate sync icon went
              // in package 7.
              LayoutComponents.offlineIndicator(),
              Expanded(
                // HEM-HERO: the greeting and tonight scroll away above the
                // library, so a large text size never squeezes the list out.
                child: HemLibraryScroll(
                  nestedKey: _nestedScrollKey,
                  onLibraryScrolled: _onLibraryScrolled,
                  header: viewModel.isSelectionMode
                      ? null
                      : HemSection(
                          viewModel: context.read<HemViewModel>(),
                          now: clock.now(),
                          firstName: firstName,
                          libraryEmpty: libraryEmpty,
                          isOnline: isOnline,
                          onStartCooking: (recipe) => Navigator.of(
                            context,
                          ).pushNamed(Routes.cookingMode, arguments: recipe),
                          onOpenMenu: () => mainTabSwitchRequest.value =
                              LayoutScaffolds.menuTab,
                        ),
                  pinned: _buildLibrary(
                    context,
                    viewModel: viewModel,
                    personalTags: personalTags,
                    recipeCount: recipeCount,
                    libraryEmpty: libraryEmpty,
                  ),
                  body: _buildContent(viewModel, isOnline, allergenPrefs),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The library under the Hem section: presence, the cooking card, search
  /// and filters.
  Widget _buildLibrary(
    BuildContext context, {
    required RecipeListViewModel viewModel,
    required List<PersonalTag> personalTags,
    required int recipeCount,
    required bool libraryEmpty,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Q6-16 = B: the library's own header row under the Ikväll band,
        // "Dina recept · N" with Välj, the ingredient search and the
        // toggle; in selection mode the counter and Avbryt (B-46 on Hem).
        // #hemtom draws no library header over an empty library.
        if (viewModel.isSelectionMode || !libraryEmpty)
          MinaReceptLibraryHeader(
            viewModel: viewModel,
            actions: minaReceptRootActions(context, viewModel),
          ),
        // BUT-407: live online-members presence bar (union across groups).
        const FamilyPresenceBar(),
        // BUT-408: live cooking session card for the user's friend groups.
        _buildCookingSessionCard(),
        // #hemtom draws no search or filters over an empty library.
        if (!viewModel.isSelectionMode && !libraryEmpty) ...[
          SearchFilterWidget(
            searchQuery: viewModel.searchQuery,
            onSearchChanged: viewModel.updateSearch,
            searchHint: context.l10n.recipeSearchHint,
            // Spoken search query lands as if typed (voice plan Phase 2a).
            enableVoiceInput: true,
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
            onToggleFilters: () => setState(() => _showFilters = !_showFilters),
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
        ],
      ],
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
        .where(
          (FriendCategory c) =>
              c.ownerId == userId || c.friendUserIds.contains(userId),
        )
        .map((g) => g.id)
        .toList(growable: false);
    if (groups.isEmpty) return const SizedBox.shrink();

    final offlineService =
        ServiceLocator.tryGet<offline_service.OfflineService>();
    _sessionsHolder.refresh(
      module,
      groups,
      userId,
      // BUT-1360: keep the "X lagar just nu" card showing the last-known
      // sessions while the device is offline instead of blanking out.
      isOffline: () => offlineService != null && !offlineService.isOnline,
    );
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
    if (!mounted) return;
    final id = recipe.id;
    viewModel.deleteRecipe(id);
    // The delete commits when the snackbar closes, so Ångra is gone from the
    // screen before the commit lands.
    SnackBarUtils.showUndoDeferred(
      context,
      context.l10n.recipeDeleted,
      onUndo: () => viewModel.undoDeleteById(id),
      onCommit: () => viewModel.commitDeletes([id]),
    );
  }

  /// The grid toggle on Mina recept.
  ///
  /// [SliverContentSizedGrid] rather than a `GridView`, and
  /// [ContentSizedGrid]'s doc carries the measurements behind that
  /// (BUT-1911).
  Widget _buildRecipeGrid(
    BuildContext context, {
    required RecipeListViewModel viewModel,
    required List<Recipe> recipes,
    required UserAllergenPreferences allergenPrefs,
  }) {
    return SliverPadding(
      padding: AppDimensions.responsiveContentPadding(context),
      sliver: SliverContentSizedGrid(
        spacing: AppDimensions.responsiveGridSpacing(context),
        columns: AppDimensions.recipeGridColumns(context),
        itemCount: recipes.length,
        itemBuilder: (context, index) => MinaReceptRecipeCard(
          viewModel: viewModel,
          recipe: recipes[index],
          allergenPrefs: allergenPrefs,
          onDelete: (recipe) => _handleDeleteWithUndo(viewModel, recipe),
          index: index,
        ),
      ),
    );
  }

  Widget _buildContent(
    RecipeListViewModel viewModel,
    bool isOnline,
    UserAllergenPreferences allergenPrefs,
  ) {
    if (viewModel.isLoading) {
      return HemLibraryScroll.boxBody(
        StateWidget.skeletonRecipeList(itemCount: 5),
        scrolls: true,
      );
    }

    final recipes = viewModel.recipes;

    // P5-U05: an error in one section never empties the whole view
    // (produktregler.md:297). With recipes already fetched, the library stays
    // and the error is a box above it; only a view with nothing to show gets
    // the full-view error.
    if (MinaReceptSectionError.emptiesView(
      hasError: viewModel.hasError,
      hasRecipes: recipes.isNotEmpty,
    )) {
      return HemLibraryScroll.boxBody(
        StateWidget.error(
          message: viewModel.error!,
          onAction: () {
            viewModel.clearError();
            viewModel.refresh();
          },
          actionLabel: context.l10n.commonRetry,
        ),
      );
    }

    if (recipes.isEmpty) {
      return HemLibraryScroll.boxBody(
        viewModel.searchQuery.isEmpty && !viewModel.hasActiveFilters
            ? const HemEmptyState()
            : StateWidget.noSearchResults(
                onAction: viewModel.searchQuery.isNotEmpty
                    ? () => viewModel.updateSearch('')
                    : viewModel.clearAllFilters,
                actionLabel: viewModel.searchQuery.isNotEmpty
                    ? context.l10n.searchClearSearch
                    : context.l10n.searchClearFilters,
              ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        unawaited(context.read<HemViewModel>().load());
        if (isOnline) {
          await _syncWithOnline();
        } else {
          await viewModel.refresh();
          if (mounted) {
            SnackBarUtils.showWarning(
              context,
              context.l10n.offlineShowingLocal,
            );
          }
        }
      },
      // BUT-2254: everything between the quick chips and the cards scrolls
      // with the cards. In a Column above an Expanded grid it pushed the
      // cards off a phone screen, and at 200 % text the grid got no height.
      // HEM-HERO / BUT-1028: one primary scrollable with no controller of its
      // own, attached to the PrimaryScrollController of Hem's
      // NestedScrollView, which links it to the Hem header; the offset is
      // persisted from its notifications (HemLibraryScroll).
      child: HemLibraryScroll.sliverBody(
        key: ValueKey(
          viewModel.isGridView
              ? 'recipe-grid-scrollable'
              : 'recipe-list-scrollable',
        ),
        slivers: [
          // BUT-982: first-use hint teaching the swipe-to-edit / -delete card
          // gesture; self-dismisses once per device.
          if (!viewModel.isSelectionMode)
            const SliverToBoxAdapter(child: SwipeHintBanner()),
          if (viewModel.hasError)
            SliverToBoxAdapter(
              child: Padding(
                padding: AppDimensions.responsiveContentPadding(context),
                child: MinaReceptSectionError(
                  onRetry: () {
                    viewModel.clearError();
                    viewModel.refresh();
                  },
                ),
              ),
            ),
          if (viewModel.showOnboardingBanner)
            SliverToBoxAdapter(
              child: MinaReceptOnboardingBanner(viewModel: viewModel),
            ),
          if (viewModel.showWelcomeBanner)
            SliverToBoxAdapter(
              child: MinaReceptWelcomeBanner(viewModel: viewModel),
            ),
          if (viewModel.searchQuery.isEmpty && !viewModel.hasActiveFilters)
            SliverToBoxAdapter(
              child: MinaReceptDiscoveryShelves(
                queryVm: context.read<RecipeQueryViewModel>(),
                seasonalMonthFuture: _seasonalMonthFuture,
                seasonalHeroService: _seasonalHeroService,
              ),
            ),
          if (viewModel.isGridView)
            _buildRecipeGrid(
              context,
              viewModel: viewModel,
              recipes: recipes,
              allergenPrefs: allergenPrefs,
            )
          else
            SliverResponsiveListGrid<Recipe>(
              items: recipes,
              tabletColumns: 2,
              desktopColumns: 3,
              spacing: AppDimensions.responsiveGridSpacing(context),
              padding: AppDimensions.responsiveContentPadding(context),
              gridChildAspectRatio: AppDimensions.recipeGridAspectRatio(
                context,
              ),
              animate: true,
              itemBuilder: (context, recipe) => MinaReceptRecipeCard(
                viewModel: viewModel,
                recipe: recipe,
                allergenPrefs: allergenPrefs,
                onDelete: (r) => _handleDeleteWithUndo(viewModel, r),
                index: recipes.indexOf(recipe),
              ),
            ),
          if (viewModel.canLoadMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: AppDimensions.responsiveContentPadding(context),
                child: ActionButtons.primaryButton(
                  context,
                  label: context.l10n.recipeShowMore,
                  onPressed: () => viewModel.loadMore(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// P5-U05 (hem ERROR): the error box of the recipe section on the start
/// view. The three parts of produktregler.md:298 (content-style-guide.md:
/// 87-97): what happened, what was kept, and Försök igen.
class MinaReceptSectionError extends StatelessWidget {
  const MinaReceptSectionError({required this.onRetry, super.key});

  /// Clears the error and fetches again.
  final VoidCallback onRetry;

  /// Whether an error takes the whole view. "Fel i en sektion tömmer aldrig
  /// hela vyn" (produktregler.md:297): only a view with nothing fetched to
  /// show gets the full-view error; with recipes the library stays and this
  /// box sits above it.
  static bool emptiesView({required bool hasError, required bool hasRecipes}) =>
      hasError && !hasRecipes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InlineError(
      what: l10n.minaReceptRefreshFailed,
      preserved: l10n.minaReceptRefreshPreserved,
      actionLabel: l10n.commonRetry,
      onAction: onRetry,
    );
  }
}

/// The library header row's actions outside selection mode (Q6-16 = B:
/// they were the top bar's, and Hem has none).
///
/// "Välj" comes first, as on the other five surfaces (B-46;
/// produktregler.md:870-874; Skarmar v12 etapp 9 #flervalingang), and is
/// left out under two recipes. Then the ingredient search and the grid/list
/// toggle. The top bar's offline icon is not carried over: the offline
/// banner at the top of Hem says the same.
@visibleForTesting
List<Widget> minaReceptRootActions(
  BuildContext context,
  RecipeListViewModel viewModel,
) {
  return [
    // Long-press stays as a shortcut, never the only way in. Outside a bar
    // the row gives no colour, so Välj takes text.primary itself.
    ...buildMinaReceptSelectEntry(
      context,
      viewModel,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
    ),
    // BUT-977: surface the pantry-match IngredientSearchView power
    // feature (previously only reachable via Cmd+K). Distinct
    // kitchen icon so it doesn't read as the in-list text filter.
    IconButton(
      icon: const ButleryIcon(Icons.kitchen_outlined),
      tooltip: context.l10n.ingredientSearchTitle,
      onPressed: () => Navigator.of(context).pushNamed(Routes.ingredientSearch),
    ),
    IconButton(
      icon: ButleryIcon(
        viewModel.isGridView ? Icons.view_list : Icons.grid_view,
      ),
      tooltip: viewModel.isGridView
          ? context.l10n.viewModeList
          : context.l10n.viewModeGrid,
      onPressed: viewModel.toggleViewMode,
    ),
  ];
}
