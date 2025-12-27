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

// Constants and theming
import 'package:butlery/core/constants/app_strings.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

// Widget components for modern UI architecture
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/content_card.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/menus/sort_menu_builder.dart';
import 'package:butlery/widgets/common/social_components/recipe_list_avatar_badge.dart';

// Service integration for functionality and data management
import 'package:butlery/services/search_service.dart';
import 'package:butlery/services/offline_service.dart' as offline_service;
import 'package:butlery/services/user_service.dart';

// Theme system integration
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

// Core services and utilities
import 'package:butlery/core/providers/application_provider.dart';
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

    // ✅ SÄKERT: Ladda data efter widget mount med safety checks
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _safeLoadSocialData();
        _safeLoadRecipeData();
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
              '❌ Fel vid delayed friends data refresh i MinaReceptView', e);
        }
      });
    } catch (e) {
      AppLogger.error(
          '❌ Fel vid setup av delayed friends refresh i MinaReceptView', e);
    }
  }

  /// Load recipe data through RecipeListViewModel with mount safety checks.
  void _safeLoadRecipeData() {
    try {
      if (mounted) {
        AppLogger.info('🔄 Laddar receptdata för MinaReceptView...');

        // RecipeListViewModel laddar automatiskt data från RecipeService
        // Inget explicit refresh behövs här - providern hanterar detta

        AppLogger.success('✅ Receptdata redo för MinaReceptView');
      }
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av receptdata i MinaReceptView', e);
    }
  }

  void _onSortChanged(SortCriteria? criteria) {
    if (criteria != null) {
      final viewModel = context.read<RecipeListViewModel>();
      viewModel.updateSort(criteria);
    }
  }

  // Exit-dialog
  Future<void> _showExitDialog(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.exitApp),
        content: const Text(AppStrings.exitAppConfirmation),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.commonCancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          ActionButtons.primaryButton(
            context,
            label: AppStrings.exit,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (shouldExit == true && context.mounted) {
      SystemNavigator.pop();
    }
  }

  // Synkronisera med online
  Future<void> _syncWithOnline() async {
    final offlineService = context.read<offline_service.OfflineService>();
    final viewModel = context.read<RecipeListViewModel>();

    if (offlineService.isOnline) {
      try {
        // Visa loading indicator
        if (mounted) {
          SnackBarUtils.showInfo(context, 'Synkroniserar...');
        }

        // Synka offline-ändringar
        await offlineService.syncNow();

        // Uppdatera receptlistan
        await viewModel.refresh();

        // Visa success
        if (mounted) {
          SnackBarUtils.showSuccess(context, 'Synkronisering klar!');
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showError(context, 'Synkronisering misslyckades: $e');
        }
      }
    }
  }

  /// Build recipe interface with filtering, search, sorting, and social integration.
  @override
  Widget build(BuildContext context) {
    // ✅ FIXAT: Nu kan vi använda watch för RecipeListViewModel eftersom den finns i MultiProvider
    final viewModel = context.watch<RecipeListViewModel>();
    final offlineService = context.watch<offline_service.OfflineService>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _showExitDialog(context);
        }
      },
      child: LayoutComponents.mainMenu(
        // ✅ UPPDATERAD WIDGET
        currentIndex: 0,
        title: 'Mina recept',
        actions: [
          // OFFLINE STATUS ICON - ✅ UPPDATERAD
          LayoutComponents.offlineStatusIcon(),

          // ✅ UPPDATERAD: USER AVATAR med notification badge
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingXs),
            child: RecipeListAvatarBadge(),
          ),

          // Error indicator
          if (viewModel.hasError)
            Semantics(
              label: 'Visa felmeddelande',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.error, color: AppColors.error),
                onPressed: () {
                  SnackBarUtils.showError(context, viewModel.error!);
                },
                tooltip: 'Visa fel',
              ),
            ),

          // Sort menu
          Semantics(
            label: 'Sortera recept',
            button: true,
            child: PopupMenuButton<SortCriteria>(
              icon: Icon(
                Icons.sort,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              tooltip: 'Sortera',
              onSelected: _onSortChanged,
              itemBuilder: (context) => SortMenuBuilder.buildItems(
                context: context,
                currentSort: viewModel.sortCriteria,
                sortAscending: viewModel.sortAscending,
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            // OFFLINE INDICATOR - ✅ UPPDATERAD
            LayoutComponents.offlineIndicator(),

            // ✅ HELT NY: SearchFilterWidget ersätter ~50 rader kod!
            SearchFilterWidget(
              // Search properties
              searchQuery: viewModel.searchQuery,
              onSearchChanged: viewModel.updateSearch,
              searchHint: 'Sök recept...',

              // Filter properties
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

              // UI state
              showFilters: _showFilters,
              onToggleFilters: () =>
                  setState(() => _showFilters = !_showFilters),
              hasActiveFilters: viewModel.hasActiveFilters,
              onClearAllFilters: viewModel.clearAllFilters,

              // Results info
              resultCount: viewModel.recipes.length,
              showStats: true,
            ),

            // Huvudinnehåll
            Expanded(child: _buildContent(viewModel, offlineService)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    RecipeListViewModel viewModel,
    offline_service.OfflineService offlineService,
  ) {
    // Loading state
    if (viewModel.isLoading) {
      return Column(
        children: [
          // ✅ MIGRATION: StateWidget skeleton loader
          Expanded(child: StateWidget.skeletonRecipeList(itemCount: 5)),
        ],
      );
    }

    // Error state - uses StateWidget for consistency
    if (viewModel.hasError) {
      return StateWidget.error(
        message: viewModel.error!,
        onAction: () {
          viewModel.clearError();
          viewModel.refresh();
        },
        actionLabel: 'Försök igen',
      );
    }

    // Hämta filtrerade och sorterade recept från ViewModel
    final recipes = viewModel.recipes;

    // Empty states
    if (recipes.isEmpty) {
      return viewModel.searchQuery.isEmpty && !viewModel.hasActiveFilters
          // ✅ MIGRATION: StateWidget no recipes
          ? StateWidget.noRecipes(
              onAction: () => Navigator.pushNamed(context, '/laggTill'),
            )
          // ✅ MIGRATION: StateWidget no search results
          : StateWidget.noSearchResults(
              onAction: viewModel.searchQuery.isNotEmpty
                  ? () => viewModel.updateSearch('')
                  : viewModel.clearAllFilters,
              actionLabel: viewModel.searchQuery.isNotEmpty
                  ? 'Rensa sökning'
                  : 'Rensa filter',
            );
    }

    // Responsive recipe list/grid with RefreshIndicator
    return RefreshIndicator(
      onRefresh: () async {
        // Om online, synka först
        if (offlineService.isOnline) {
          await _syncWithOnline();
        } else {
          // Om offline, bara refresh från lokal cache
          await viewModel.refresh();
          if (mounted) {
            SnackBarUtils.showWarning(
                context, 'Offline-läge - visar lokala recept');
          }
        }
      },
      child: Column(
        children: [
          Expanded(
            // ✅ RESPONSIVE: Automatically switches between ListView (mobile) and GridView (tablet/desktop)
            child: LayoutComponents.responsiveListGrid(
              items: recipes,
              tabletColumns: 2, // 2 columns on tablet
              desktopColumns: 3, // 3 columns on desktop
              spacing: AppDimensions.responsiveGridSpacing(context),
              padding: AppDimensions.responsiveContentPadding(context),
              shrinkWrap: false,
              gridChildAspectRatio: 0.75, // Recipe cards are taller than wide
              animate: true, // Staggered entrance animations
              itemBuilder: (context, recipe) {
                // Get allergen preferences for recipe cards
                final userService = context.watch<UserService>();
                final allergenPrefs = userService.allergenPreferences;

                return ContentCard(
                  key: ValueKey(recipe.id),
                  item: recipe,
                  type: ContentCardType.recipe,
                  userAllergenPrefs: allergenPrefs.showOnCards
                      ? allergenPrefs.trackedAllergens
                      : null,
                  onTap: () async {
                    // Navigera till detaljer
                    await Navigator.pushNamed(
                      context,
                      '/receptDetalj',
                      arguments: recipe,
                    );

                    // Ingen refresh behövs - ViewModel lyssnar på RecipeService
                  },
                );
              },
            ),
          ),
          // PERFORMANCE FIX: Load More button for pagination
          if (viewModel.canLoadMore)
            Padding(
              padding: AppDimensions.responsiveContentPadding(context),
              child: ActionButtons.primaryButton(
                context,
                label: 'Visa fler recept',
                onPressed: () => viewModel.loadMore(),
              ),
            ),
        ],
      ),
    );
  }
}
