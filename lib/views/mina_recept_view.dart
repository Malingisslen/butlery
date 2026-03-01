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
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ViewModel integration for comprehensive state management
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
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
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/menus/sort_menu_builder.dart';
import 'package:butlery/widgets/common/social_components/recipe_list_avatar_badge.dart';
import 'package:butlery/widgets/common/main_view_header.dart';

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
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

/// Personal recipe management view with multi-provider architecture.
class MinaReceptView extends StatelessWidget {
  const MinaReceptView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Recipe collection state management
        ChangeNotifierProvider<RecipeListViewModel>(
          create: (context) => ServiceLocator.get<RecipeListViewModel>(),
        ),
        // User profile and authentication service
        ChangeNotifierProvider.value(value: ServiceLocator.get<UserService>()),
        // Social relationship and friend management
        ChangeNotifierProvider.value(
            value: ServiceLocator.get<FriendsViewModel>()),
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

  /// Initialize state and load social/recipe data after widget mount.
  @override
  void initState() {
    super.initState();

    // Load data after widget mount with safety checks
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _safeLoadSocialData();
        _safeLoadRecipeData();
        // Initialize personal tags now that user is authenticated
        context.read<PersonalTagViewModel>().initialize();
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

  // Exit dialog
  Future<void> _showExitDialog(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.navExitApp),
        content: Text(context.l10n.navExitAppConfirmation),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.commonCancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.navExit,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (shouldExit == true && context.mounted) {
      SystemNavigator.pop();
    }
  }

  // Sync with online
  Future<void> _syncWithOnline() async {
    final offlineService = context.read<offline_service.OfflineService>();
    final viewModel = context.read<RecipeListViewModel>();

    if (offlineService.isOnline) {
      try {
        // Show loading indicator
        if (mounted) {
          SnackBarUtils.showInfo(context, context.l10n.statusSyncing);
        }

        // Sync offline changes
        await offlineService.syncNow();

        // Update recipe list
        await viewModel.refresh();

        // Show success
        if (mounted) {
          SnackBarUtils.showSuccess(context, context.l10n.syncComplete);
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showError(
              context, context.l10n.syncFailed(
                SnackBarUtils.userFriendlyMessage(context, e),
              ));
        }
      }
    }
  }

  /// Get active quick filter IDs from ViewModel state.
  Set<String> _getQuickFilterIds(RecipeListViewModel viewModel) {
    final ids = <String>{};
    // 'quick' time filter maps to 'quick' chip
    if (viewModel.activeTimeFilters.contains('quick')) {
      ids.add('quick');
    }
    // 'vegetarian' dietary filter maps to 'vegetarian' chip
    if (viewModel.activeDietaryFilters.contains('vegetarian')) {
      ids.add('vegetarian');
    }
    if (viewModel.favoritesOnly) {
      ids.add('favorites');
    }
    return ids;
  }

  /// Handle quick filter chip toggle.
  void _onQuickFilterToggle(RecipeListViewModel viewModel, String filterId) {
    switch (filterId) {
      case 'quick':
        viewModel.toggleTimeFilter('quick');
        break;
      case 'vegetarian':
        viewModel.toggleDietaryFilter('vegetarian');
        break;
      case 'favorites':
        viewModel.toggleFavoritesFilter();
        break;
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
    final offlineService = context.watch<offline_service.OfflineService>();
    final personalTagViewModel = context.watch<PersonalTagViewModel>();
    final recipeCount = viewModel.recipes.length;

    // Selection mode uses a different app bar
    final PreferredSizeWidget appBar = viewModel.isSelectionMode
        ? _buildSelectionAppBar(viewModel)
        : MainViewHeader(
            title: 'dina\nrecept',
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          if (viewModel.isSelectionMode) {
            viewModel.clearSelection();
          } else {
            _showExitDialog(context);
          }
        }
      },
      child: LayoutComponents.mainMenu(
        currentIndex: 0,
        appBar: appBar,
        body: Column(
          children: [
            LayoutComponents.offlineIndicator(),
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
                personalTagIds: personalTagViewModel.tags,
                activePersonalTagFilters: viewModel.activePersonalTagFilters,
                excludedPersonalTagFilters:
                    viewModel.excludedPersonalTagFilters,
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
                showFilters: _showFilters,
                onToggleFilters: () =>
                    setState(() => _showFilters = !_showFilters),
                hasActiveFilters: viewModel.hasActiveFilters,
                onClearAllFilters: viewModel.clearAllFilters,
                resultCount: recipeCount,
                showStats: false,
              ),
              QuickFilterChips(
                options: QuickFilterChips.getDefaultRecipeFilters(context),
                selectedIds: _getQuickFilterIds(viewModel),
                onFilterToggle: (filterId) =>
                    _onQuickFilterToggle(viewModel, filterId),
                trailing: _buildSortChip(viewModel),
              ),
            ],
            Expanded(child: _buildContent(viewModel, offlineService)),
          ],
        ),
      ),
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

  Widget _buildRecipeCard(
    RecipeListViewModel viewModel,
    Recipe recipe,
  ) {
    final userService = context.watch<UserService>();
    final allergenPrefs = userService.allergenPreferences;
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
            child: Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? cs.primary : cs.outline,
              size: AppDimensions.iconSizeM,
            ),
          ),
        ],
      );
    }

    // Swipe gestures only in normal mode
    if (!viewModel.isSelectionMode) {
      card = Dismissible(
        key: Key('recipe-${recipe.id}'),
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) async {
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
        background: Container(
          alignment: AlignmentDirectional.centerStart,
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.spacingLg),
          color: cs.primary,
          child: Icon(Icons.edit,
              color: cs.onPrimary, size: AppDimensions.iconSize28),
        ),
        secondaryBackground: Container(
          alignment: AlignmentDirectional.centerEnd,
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.spacingLg),
          color: cs.error,
          child: Icon(Icons.delete,
              color: cs.onError, size: AppDimensions.iconSize28),
        ),
        child: card,
      );
    }

    return card;
  }

  Widget _buildContent(
    RecipeListViewModel viewModel,
    offline_service.OfflineService offlineService,
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
          ? StateWidget.noRecipes(
              onAction: () => Navigator.pushNamed(context, '/laggTill'),
            )
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
        if (offlineService.isOnline) {
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
                    itemBuilder: (context, index) =>
                        _buildRecipeCard(viewModel, recipes[index]),
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
                        _buildRecipeCard(viewModel, recipe),
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
