// lib/views/main_views/mina_recept_view.dart - UPPDATERAD MED SearchFilterWidget

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // För SystemNavigator
import 'package:provider/provider.dart';
import '../../viewmodels/recipe_list_viewmodel.dart';
import '../../viewmodels/friends_viewmodel.dart'; // För vänskapsförfrågningar
import '../../viewmodels/shared_content_viewmodel.dart'; // ✅ NYTT: För delade recept/menyer
import '../../widgets/main_layout_menu.dart';
import '../../widgets/common/content_card.dart';
import '../../widgets/common/search_filter_widget.dart'; // ✅ NY IMPORT
import '../../widgets/common/state_widget.dart'; // ✅ MIGRATION: Ersätt EmptyState
import '../../widgets/offline_indicator.dart'; // För offline indicator
import '../widgets/user/user_display_widgets.dart'; // För avatar
import '../../services/search_service.dart';
import '../../services/offline_service.dart'
    as offline_service; // FIXA: Använd prefix
import '../../services/user_service.dart'; // För user service
import '../../theme/app_theme.dart';
import '../../core/injection.dart';
import '../../core/utils/logger.dart'; // ✅ LÄGG TILL för AppLogger

/// ✨ UPPDATERAD VY MED SearchFilterWidget - DRASTISKT FÖRENKLAD
/// Nu använder vi den unified SearchFilterWidget istället för separata komponenter
class MinaReceptView extends StatelessWidget {
  const MinaReceptView({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ FIXAT: SÄKER Provider setup MED RecipeListViewModel
    return MultiProvider(
      providers: [
        // ✅ KRITISK FIX: Lägg till RecipeListViewModel som FÖRSTA provider
        ChangeNotifierProvider<RecipeListViewModel>(
          create: (context) => sl<RecipeListViewModel>(),
        ),

        // ✅ SÄKERT: Använd befintliga singletons utan att skapa nya
        ChangeNotifierProvider.value(value: sl<UserService>()),
        ChangeNotifierProvider.value(value: sl<FriendsViewModel>()),
        ChangeNotifierProvider.value(value: sl<SharedContentViewModel>()),

        // ✅ LÄGG TILL: OfflineService för att kunna watch den
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

  /// ✅ SÄKER metod för att ladda social data
  void _safeLoadSocialData() {
    try {
      final friendsViewModel = context.read<FriendsViewModel>();
      final sharedContentViewModel = context.read<SharedContentViewModel>();

      // ✅ SAFE: Kontrollera att ViewModels inte är disposed innan användning
      if (mounted) {
        AppLogger.info('🔄 Laddar social data för MinaReceptView...');

        friendsViewModel.refresh();
        sharedContentViewModel.refresh();

        AppLogger.success('✅ Social data laddar för MinaReceptView');
      }
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av social data i MinaReceptView', e);
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
              backgroundColor: AppTheme.errorColor,
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Synkroniserar...'),
                ],
              ),
              duration: Duration(seconds: 30),
            ),
          );
        }

        // Synka offline-ändringar
        await offlineService.syncNow();

        // Uppdatera receptlistan
        await viewModel.refresh();

        // Visa success
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Synkronisering klar!'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Synkronisering misslyckades: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
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
            UserDisplayWidgets.avatar(
              size: ImageSize.medium,
              imageUrl: userService.currentUserProfile?.avatarUrl,
              displayName: userService.currentUserProfile?.displayName ??
                  'Okänd användare',
              showStatus: true,
              isOnline: userService.currentUserProfile?.isOnline ?? false,
            ),
            // ✅ TOTAL NOTIFICATION BADGE
            if (totalNotifications > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    totalNotifications > 99 ? '99+' : '$totalNotifications',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
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
      child: MainLayoutMenu(
        currentIndex: 0,
        title: 'Mina recept',
        actions: [
          // OFFLINE STATUS ICON
          const OfflineStatusIcon(),

          // ✅ UPPDATERAD: USER AVATAR med notification badge
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXs),
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
                      width: 8,
                      height: 8,
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
              icon: AppTheme.errorIcon(context),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(viewModel.error!),
                    action: SnackBarAction(
                      label: 'Försök igen',
                      onPressed: () {
                        viewModel.clearError();
                        viewModel.refresh();
                      },
                    ),
                  ),
                );
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
            // OFFLINE INDICATOR
            const OfflineIndicator(),

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
          padding: AppTheme.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppTheme.errorContainer(context, viewModel.error!),
              AppTheme.mediumGap,
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📵 Offline-läge - visar lokala recept'),
                backgroundColor: AppTheme.warningColor,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      },
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
        itemCount: recipes.length,
        itemBuilder: (context, index) {
          final recipe = recipes[index];

          return Padding(
            key: ValueKey(recipe.id),
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSm,
              vertical: AppTheme.spacingXs,
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
          SizedBox(width: AppTheme.spacingSm),
          Text(label),
          const Spacer(),
          if (isSelected)
            Icon(
              sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: AppTheme.iconSizeInfo,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }
}
