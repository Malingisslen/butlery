// lib/views/main_views/mina_recept_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/recipe_list_viewmodel.dart';
import '../../viewmodels/friends_viewmodel.dart';
import '../../viewmodels/shared_content_viewmodel.dart';
import '../../widgets/common/layout_components.dart';
import '../../widgets/common/content_card.dart';
import '../../widgets/common/search_filter_widget.dart';
import '../../widgets/common/state_widget.dart';
import '../../services/search_service.dart';
import '../../services/offline_service.dart' as offline_service;
import '../../widgets/common/social_components.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_text_styles.dart';
import '../../core/injection.dart';
import '../../core/utils/logger.dart';
import '../../core/constants/routes.dart';
import '../../core/utils/snackbar_utils.dart';

class MinaReceptView extends StatelessWidget {
  const MinaReceptView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<RecipeListViewModel>(
          create: (context) => sl<RecipeListViewModel>(),
        ),
        ChangeNotifierProvider.value(value: sl<UserService>()),
        ChangeNotifierProvider.value(value: sl<FriendsViewModel>()),
        ChangeNotifierProvider.value(value: sl<SharedContentViewModel>()),
        ChangeNotifierProvider.value(
            value: sl<offline_service.OfflineService>()),
      ],
      child: const _MinaReceptViewContent(),
    );
  }
}

/// Separerad content widget för bättre struktur
class _MinaReceptViewContent extends StatefulWidget {
  const _MinaReceptViewContent();

  @override
  State<_MinaReceptViewContent> createState() => _MinaReceptViewContentState();
}

class _MinaReceptViewContentState extends State<_MinaReceptViewContent> {
  bool _showFilters = false; // ✅ BEHÅLLS för filter toggle

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

  /// ✅ SÄKER metod för att ladda social data - nu optimerad för att undvika dublettladdningar
  void _safeLoadSocialData() {
    try {
      // 🚀 PERFORMANCE FIX: Only refresh if content hasn't been loaded yet
      // SocialRecipeService handles initial loading automatically via auth listener
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;

        try {
          final friendsViewModel = context.read<FriendsViewModel>();

          // Only refresh friends - SharedContentViewModel loads automatically via service
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

  /// ✅ NYTT: Säker metod för att ladda receptdata
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
        title: const Text('Avsluta Butlery?'),
        content: const Text('Vill du verkligen avsluta appen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Avsluta'),
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

  /// ✅ FIXAD: Bygger avatar med total notification badge + SÄKER Consumer
  Widget _buildUserAvatarWithBadge() {
    return Consumer3<UserService, FriendsViewModel, SharedContentViewModel>(
      builder: (context, userService, friendsViewModel, sharedContentViewModel,
          child) {
        // ✅ SAFETY: Hantera disposed ViewModels gracefully
        int pendingFriendRequests = 0;
        int unreadRecipes = 0;
        int unreadMenus = 0;

        try {
          pendingFriendRequests = friendsViewModel.pendingRequestsCount;
          unreadRecipes = sharedContentViewModel.unreadRecipesCount;
          unreadMenus = sharedContentViewModel.unreadMenusCount;
        } catch (e) {
          AppLogger.warning(
              '⚠️ Ett eller flera ViewModels är disposed - visar fallback notification badge');
          // Fallback till 0 om ViewModels är disposed
        }

        final totalNotifications =
            pendingFriendRequests + unreadRecipes + unreadMenus;

        return Stack(
          children: [
            SocialComponents.avatar(
              user: userService.currentUserProfile,
              size: ImageSize.medium,
              showOnlineStatus: true,
              isClickable: true,
              onTap: () => LayoutComponents.showProfileMenu(
                context,
                userImageUrl: userService.currentUserProfile?.avatarUrl,
                displayName:
                    userService.currentUserProfile?.displayName ?? 'Användare',
                email: userService.currentUserProfile?.email,
                onEditProfile: () =>
                    Navigator.pushNamed(context, Routes.profileEdit),
                onViewFriends: () =>
                    Navigator.pushNamed(context, Routes.friends),
                onViewShared: () => Navigator.pushNamed(context, Routes.shared),
                onViewNotifications: () =>
                    Navigator.pushNamed(context, Routes.friendRequests),
              ),
            ),
            // ✅ TOTAL NOTIFICATION BADGE
            if (totalNotifications > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(AppDimensions.spacingXs),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: AppDimensions.borderWidthThick,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    totalNotifications > 99 ? '99+' : '$totalNotifications',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.neutralLight,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingXs),
            child: _buildUserAvatarWithBadge(),
          ),

          // Filter-knapp med indikator för aktiva filter
          IconButton(
            icon: Stack(
              children: [
                Icon(
                  Icons.filter_list,
                  color: _showFilters
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                // Visa en prick om det finns aktiva filter
                if (viewModel.hasActiveFilters)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: AppDimensions.spacingS,
                      height: AppDimensions.spacingS,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            tooltip: 'Filtrera',
          ),

          // Error indicator
          if (viewModel.hasError)
            IconButton(
              icon: Icon(Icons.error, color: AppColors.error),
              onPressed: () {
                SnackBarUtils.showError(context, viewModel.error!);
              },
              tooltip: 'Visa fel',
            ),

          // Sort menu
          PopupMenuButton<SortCriteria>(
            icon: Icon(
              Icons.sort,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: 'Sortera',
            onSelected: _onSortChanged,
            itemBuilder: (context) => [
              _buildSortMenuItem(
                SortCriteria.title,
                'Titel',
                Icons.title,
                viewModel.sortCriteria,
                viewModel.sortAscending,
              ),
              _buildSortMenuItem(
                SortCriteria.time,
                'Tid',
                Icons.access_time,
                viewModel.sortCriteria,
                viewModel.sortAscending,
              ),
              _buildSortMenuItem(
                SortCriteria.rating,
                'Betyg',
                Icons.star,
                viewModel.sortCriteria,
                viewModel.sortAscending,
              ),
              _buildSortMenuItem(
                SortCriteria.mealType,
                'Måltidstyp',
                Icons.restaurant,
                viewModel.sortCriteria,
                viewModel.sortAscending,
              ),
            ],
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
              onTimeFilterToggle: viewModel.toggleTimeFilter,
              onMealTypeFilterToggle: viewModel.toggleMealTypeFilter,
              onRatingFilterToggle: viewModel.toggleRatingFilter,

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

    // Error state
    if (viewModel.hasError) {
      return Center(
        child: Padding(
          padding: AppDimensions.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(AppDimensions.paddingM),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                  border: Border.all(color: AppColors.error),
                ),
                child: Text(
                  viewModel.error!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              ElevatedButton(
                onPressed: () {
                  viewModel.clearError();
                  viewModel.refresh();
                },
                child: const Text('Försök igen'),
              ),
            ],
          ),
        ),
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

    // Receptlista med RefreshIndicator som synkar om online
    return RefreshIndicator(
      onRefresh: () async {
        // Om online, synka först
        if (offlineService.isOnline) {
          await _syncWithOnline();
        } else {
          // Om offline, bara refresh från lokal cache
          await viewModel.refresh();
          if (mounted) {
            SnackBarUtils.showWarning(context, 'Offline-läge - visar lokala recept');
          }
        }
      },
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
        itemCount: recipes.length,
        itemBuilder: (context, index) {
          final recipe = recipes[index];

          return Padding(
            key: ValueKey(recipe.id),
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingS,
              vertical: AppDimensions.spacingXs,
            ),
            child: ContentCard.recipe(
              recipe: recipe,
              onTap: () async {
                // Navigera till detaljer
                await Navigator.pushNamed(
                  context,
                  '/receptDetalj',
                  arguments: recipe,
                );

                // Ingen refresh behövs - ViewModel lyssnar på RecipeService
              },
            ),
          );
        },
      ),
    );
  }

  PopupMenuItem<SortCriteria> _buildSortMenuItem(
    SortCriteria criteria,
    String label,
    IconData icon,
    SortCriteria currentSort,
    bool sortAscending,
  ) {
    final isSelected = currentSort == criteria;

    return PopupMenuItem(
      value: criteria,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
          SizedBox(width: AppDimensions.spacingS),
          Text(label),
          const Spacer(),
          if (isSelected)
            Icon(
              sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: AppDimensions.iconSizeM,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }
}
