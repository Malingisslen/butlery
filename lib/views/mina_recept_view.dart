/// Personal recipe management view with filtering, social integration, and offline support.
/// Displays user's recipe collection with search/filter capabilities, friend notifications,
/// and offline synchronization. Uses multi-provider architecture for state management.
/// **Key Features:**
/// - Recipe browsing with search, filtering, and sorting
/// - Social notifications (friend requests, shared content)
/// - Offline-first design with sync status
/// - Multi-provider integration (RecipeListViewModel, FriendsViewModel, SharedContentCoordinatorViewModel)

// lib/views/main_views/mina_recept_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
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
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

// Widget components for modern UI architecture
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/content_card.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/search_filter/quick_filter_chips.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/indicators/sync_indicator.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/menus/sort_menu_builder.dart';
import 'package:butlery/widgets/common/social_components/recipe_list_avatar_badge.dart';
import 'package:butlery/widgets/common/main_view_header.dart';
import 'package:butlery/widgets/recipe/collection_insights_card.dart';
import 'package:butlery/widgets/recipe/recipe_shelf.dart';
import 'package:butlery/services/tagging/tag_config_service.dart';

// Service integration for functionality and data management
import 'package:butlery/services/search_service.dart';
import 'package:butlery/services/offline_service.dart' as offline_service;
import 'package:butlery/services/user_service.dart';

// Theme system integration
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

// Core services and utilities
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/core/utils/season_utils.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/user_allergen_preferences.dart';

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

  /// Cuisine key → display name map, loaded once in initState.
  Map<String, String> _cuisineDisplayNames = const {};

  void _loadCuisineNames() {
    try {
      final config = ServiceLocator.get<TagConfigService>().configOrNull;
      if (config != null) {
        _cuisineDisplayNames = {
          for (final e in config.cuisines.enabledEntries) e.key: e.getTag('sv'),
        };
      }
    } catch (_) {
      // Config not available — insights card will skip cuisines
    }
  }

  /// Initialize state and load social/recipe data after widget mount.
  @override
  void initState() {
    super.initState();

    // Load data after widget mount with safety checks
    _loadCuisineNames();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _safeLoadSocialData();
        _safeLoadRecipeData();
        // Initialize personal tags now that user is authenticated
        context.read<PersonalTagViewModel>().initialize();
        // Load search history for recent search chips
        context.read<RecipeListViewModel>().loadSearchHistory();
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

  void _onSortChanged(SortCriteria? criteria) {
    if (criteria != null) {
      // Defer to next frame so PopupMenu fully tears down before rebuild
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final viewModel = context.read<RecipeListViewModel>();
        viewModel.updateSort(criteria);
      });
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

  /// Get active quick filter IDs from ViewModel state.
  Set<String> _getQuickFilterIds(RecipeListViewModel viewModel) {
    final ids = <String>{};
    if (viewModel.activeTimeFilters.contains(RecipeFilters.filterQuick)) {
      ids.add(RecipeFilters.filterQuick);
    }
    if (viewModel.activeDietaryFilters
        .contains(RecipeFilters.filterVegetarian)) {
      ids.add(RecipeFilters.filterVegetarian);
    }
    if (viewModel.favoritesOnly) {
      ids.add(RecipeFilters.filterFavorites);
    }
    if (viewModel.pantryOnly) {
      ids.add(RecipeFilters.filterPantry);
    }
    // Allergen quick-filter chips
    ids.addAll(viewModel.activeAllergenFilters);
    return ids;
  }

  /// Handle quick filter chip toggle.
  void _onQuickFilterToggle(RecipeListViewModel viewModel, String filterId) {
    if (RecipeFilters.allergenFilterIds.contains(filterId)) {
      viewModel.toggleAllergenFilter(filterId);
      return;
    }
    switch (filterId) {
      case RecipeFilters.filterQuick:
        viewModel.toggleTimeFilter(RecipeFilters.filterQuick);
        break;
      case RecipeFilters.filterVegetarian:
        viewModel.toggleDietaryFilter(RecipeFilters.filterVegetarian);
        break;
      case RecipeFilters.filterFavorites:
        viewModel.toggleFavoritesFilter();
        break;
      case RecipeFilters.filterPantry:
        viewModel.togglePantryFilter();
        break;
      case RecipeFilters.filterIngredientSearch:
        Navigator.pushNamed(context, Routes.ingredientSearch);
        return;
    }
  }

  /// Chip-styled sort button for the filter chips row.
  Widget _buildSortChip(RecipeListViewModel viewModel) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<SortCriteria>(
      onSelected: _onSortChanged,
      itemBuilder: (context) => SortMenuBuilder.buildItems(
        context: context,
        currentSort: viewModel.sortCriteria,
        sortAscending: viewModel.sortAscending,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingSm,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius20),
          border: Border.all(
            color: cs.outlineVariant,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sort,
              size: AppDimensions.iconSizeS,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              context.l10n.commonSort,
              style: AppTextStyles.labelMedium.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(RecipeListViewModel viewModel) {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: cs.primaryContainer,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: viewModel.clearSelection,
      ),
      title: Text(
        context.l10n.bulkSelectedCount(viewModel.selectedCount),
        style: AppTextStyles.titleMedium,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: context.l10n.bulkSelectAll,
          onPressed: viewModel.selectAll,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: context.l10n.bulkDelete,
          onPressed: () async {
            final count = viewModel.selectedCount;
            final confirmed = await CommonDialogActions.showDeleteConfirmation(
              context: context,
              itemName: '$count recept',
              itemType: 'recept',
              warningMessage: context.l10n.bulkDeleteConfirmMessage,
              icon: Icons.delete_sweep,
            );
            if (confirmed == true) {
              viewModel.deleteSelected();
              viewModel.clearSelection();
              if (mounted) {
                SnackBarUtils.showSuccessWithAction(
                  context,
                  context.l10n.bulkDeleteSuccess(count),
                  actionLabel: context.l10n.commonUndo,
                  onAction: () => viewModel.undoBulkDelete(),
                  duration: const Duration(seconds: 7),
                );
              }
            }
          },
        ),
      ],
    );
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
        ? _buildSelectionAppBar(viewModel)
        : MainViewHeader(
            title: 'dina\nrecept',
            ghostIllustration: VegetableType.broccoli,
            countBadge: context.l10n.recipeCountBadge(recipeCount),
            trailing: const RecipeListAvatarBadge(),
            actions: [
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
                selectedIds: _getQuickFilterIds(viewModel),
                onFilterToggle: (filterId) =>
                    _onQuickFilterToggle(viewModel, filterId),
                trailing: _buildSortChip(viewModel),
              ),
            ),
          ],
          Expanded(child: _buildContent(viewModel, isOnline, allergenPrefs)),
        ],
      )),
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

  void _navigateToRecipe(Recipe recipe) {
    Navigator.pushNamed(context, Routes.receptDetalj, arguments: recipe);
  }

  Widget _buildDiscoveryShelves(RecipeQueryViewModel queryVm) {
    final inSeason = queryVm.getInSeasonRecipes();
    return Column(
      children: [
        if (inSeason.length >= 2) _buildSeasonalBanner(inSeason.length),
        RecipeShelf(
          title: context.l10n.seasonalInSeasonNow,
          recipes: inSeason,
          onRecipeTap: _navigateToRecipe,
        ),
        RecipeShelf(
          title: context.l10n.dormantRecipesTitle,
          recipes: queryVm.getDormantRecipes(),
          onRecipeTap: _navigateToRecipe,
        ),
        RecipeShelf(
          title: context.l10n.seasonalForgottenFavorites,
          recipes: queryVm.getForgottenFavorites(),
          onRecipeTap: _navigateToRecipe,
        ),
      ],
    );
  }

  Widget _buildSeasonalBanner(int count) {
    final cs = Theme.of(context).colorScheme;
    final season = SeasonUtils.currentSeasonTag();
    final message = switch (season) {
      'vår' => context.l10n.seasonalBannerSpring(count),
      'sommar' => context.l10n.seasonalBannerSummer(count),
      'höst' => context.l10n.seasonalBannerAutumn(count),
      _ => context.l10n.seasonalBannerWinter(count),
    };
    return Container(
      margin: AppDimensions.responsiveContentPadding(context),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.eco, color: cs.primary, size: 20),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(
    RecipeListViewModel viewModel,
    Recipe recipe,
    UserAllergenPreferences allergenPrefs,
  ) {
    final isSelected = viewModel.selectedIds.contains(recipe.id);
    final cs = Theme.of(context).colorScheme;

    Widget card = ContentCard(
      key: ValueKey(recipe.id),
      item: recipe,
      type: ContentCardType.recipe,
      style: viewModel.isGridView
          ? ContentCardStyle.grid
          : ContentCardStyle.detailed,
      userAllergenPrefs:
          allergenPrefs.showOnCards ? allergenPrefs.trackedAllergens : null,
      userDietaryPrefs:
          allergenPrefs.showOnCards ? allergenPrefs.trackedDietary : null,
      matchPercent:
          viewModel.pantryOnly ? viewModel.pantryMatches[recipe.id] : null,
      onFavoriteToggle: viewModel.isSelectionMode
          ? null
          : () => viewModel.toggleFavorite(recipe.id),
      onTap: viewModel.isSelectionMode
          ? () => viewModel.toggleSelection(recipe.id)
          : () async {
              await Navigator.pushNamed(
                context,
                Routes.receptDetalj,
                arguments: recipe,
              );
            },
      onLongPress: viewModel.isSelectionMode
          ? null
          : () => viewModel.enterSelectionMode(recipe.id),
    );

    // Selection overlay
    if (viewModel.isSelectionMode) {
      card = Stack(
        children: [
          card,
          if (isSelected)
            Positioned.fill(
              child: Container(
                color: cs.primary.withValues(alpha: 0.15),
              ),
            ),
          Positioned(
            top: AppDimensions.spacingSm,
            left: AppDimensions.spacingSm,
            child: Semantics(
              selected: isSelected,
              label: isSelected
                  ? context.l10n.a11yRecipeSelected(recipe.title)
                  : context.l10n.a11yRecipeNotSelected(recipe.title),
              child: Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? cs.primary : cs.outline,
                size: AppDimensions.iconSizeM,
              ),
            ),
          ),
        ],
      );
    }

    // Swipe gestures only in normal mode
    if (!viewModel.isSelectionMode) {
      card = Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(
            label: context.l10n.a11ySwipeEditAction,
          ): () => Navigator.pushNamed(
                context,
                Routes.redigeraRecept,
                arguments: recipe,
              ),
          CustomSemanticsAction(
            label: context.l10n.a11ySwipeDeleteAction,
          ): () async {
            final confirmed =
                await CommonDialogActions.showRecipeDeleteConfirmation(
              context: context,
              recipeName: recipe.title,
            );
            if (confirmed == true) {
              _handleDeleteWithUndo(viewModel, recipe);
            }
          },
        },
        child: Dismissible(
          key: Key('recipe-${recipe.id}'),
          direction: DismissDirection.horizontal,
          confirmDismiss: (direction) async {
            HapticFeedback.mediumImpact();
            if (direction == DismissDirection.endToStart) {
              final confirmed =
                  await CommonDialogActions.showRecipeDeleteConfirmation(
                context: context,
                recipeName: recipe.title,
              );
              if (confirmed == true) {
                _handleDeleteWithUndo(viewModel, recipe);
              }
              return false;
            } else if (direction == DismissDirection.startToEnd) {
              Navigator.pushNamed(
                context,
                Routes.redigeraRecept,
                arguments: recipe,
              );
              return false;
            }
            return false;
          },
          background: ExcludeSemantics(
            child: Container(
              alignment: AlignmentDirectional.centerStart,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingLg),
              color: cs.primary,
              child: Icon(Icons.edit,
                  color: cs.onPrimary, size: AppDimensions.iconSize28),
            ),
          ),
          secondaryBackground: ExcludeSemantics(
            child: Container(
              alignment: AlignmentDirectional.centerEnd,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingLg),
              color: cs.error,
              child: Icon(Icons.delete,
                  color: cs.onError, size: AppDimensions.iconSize28),
            ),
          ),
          child: card,
        ),
      );
    }

    return card;
  }

  Widget _buildEmptyState() {
    final userService = context.read<UserService>();
    final profile = userService.currentUserProfile;
    final isNewUser = profile != null &&
        DateTime.now().difference(profile.joinedAt).inDays < 7;

    if (!isNewUser) {
      return StateWidget.noRecipes(
        onAction: () => Navigator.pushNamed(context, Routes.laggTill),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final hasPrefs = profile.allergenPreferences != null &&
        (profile.allergenPreferences!.trackedAllergens.isNotEmpty ||
            profile.allergenPreferences!.trackedDietary.isNotEmpty);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const VegetableIllustration(
              type: VegetableType.broccoli,
              size: 100,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              context.l10n.emptyStateNewUserTitle,
              style: AppTextStyles.headlineMedium.copyWith(color: cs.primary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              hasPrefs
                  ? context.l10n.emptyStateNewUserWithPrefs
                  : context.l10n.emptyStateNewUserDescription,
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            SizedBox(
              width: double.infinity,
              child: ActionButtons.primaryButton(
                context,
                label: context.l10n.emptyStateImportAction,
                onPressed: () =>
                    Navigator.pushNamed(context, Routes.smartImport),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, Routes.laggTill),
              child: Text(context.l10n.emptyStateOtherOptions),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingBanner(RecipeListViewModel viewModel) {
    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: const Key('onboarding-banner'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => viewModel.dismissOnboardingBanner(),
      child: Container(
        margin: AppDimensions.responsiveContentPadding(context),
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: cs.primary),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              child: Text(
                context.l10n.onboardingSkippedBanner,
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                viewModel.dismissOnboardingBanner();
                Navigator.pushNamed(context, Routes.settingsAllergens);
              },
              child: Text(context.l10n.onboardingSkippedBannerAction),
            ),
          ],
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
          ? _buildEmptyState()
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
          if (viewModel.showOnboardingBanner) _buildOnboardingBanner(viewModel),
          if (viewModel.searchQuery.isEmpty && !viewModel.hasActiveFilters) ...[
            CollectionInsightsCard(
              recipes: viewModel.recipes,
              cuisineDisplayNames: _cuisineDisplayNames,
            ),
            _buildDiscoveryShelves(context.read<RecipeQueryViewModel>()),
          ],
          Expanded(
            child: viewModel.isGridView
                ? GridView.builder(
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
                    itemBuilder: (context, index) => _buildRecipeCard(
                        viewModel, recipes[index], allergenPrefs),
                  )
                : LayoutComponents.responsiveListGrid(
                    items: recipes,
                    tabletColumns: 2,
                    desktopColumns: 3,
                    spacing: AppDimensions.responsiveGridSpacing(context),
                    padding: AppDimensions.responsiveContentPadding(context),
                    shrinkWrap: false,
                    gridChildAspectRatio: 0.75,
                    animate: true,
                    itemBuilder: (context, recipe) =>
                        _buildRecipeCard(viewModel, recipe, allergenPrefs),
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
