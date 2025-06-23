// lib/views/main_views/mina_recept_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // För SystemNavigator
import 'package:provider/provider.dart';
import '../../viewmodels/recipe_list_viewmodel.dart';
import '../../widgets/main_layout_menu.dart';
import '../../widgets/recipe_card.dart';
import '../../widgets/search_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chips.dart';
import '../../widgets/offline_indicator.dart'; // För offline indicator
import '../../widgets/user_avatar.dart'; // För avatar
import '../../services/search_service.dart';
import '../../services/offline_service.dart'
    as offline_service; // FIXA: Använd prefix
import '../../services/user_service.dart'; // För user service
import '../../theme/app_theme.dart';
import '../../core/injection.dart';
import '../../widgets/skeleton_loader.dart';

/// ✨ UPPDATERAD VY MED OFFLINE SUPPORT OCH USER AVATAR
/// Nu visar vi offline-status och synkroniserar med pull-to-refresh
class MinaReceptView extends StatelessWidget {
  const MinaReceptView({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap med ChangeNotifierProvider för att tillhandahålla ViewModel
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => sl<RecipeListViewModel>()),
        ChangeNotifierProvider.value(value: sl<UserService>()),
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
  final TextEditingController _searchController = TextEditingController();
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    // Lyssna på text-ändringar och uppdatera ViewModel
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    // Hämta ViewModel och uppdatera sökfrågan
    final viewModel = context.read<RecipeListViewModel>();
    viewModel.updateSearch(_searchController.text);
  }

  void _onSearchCleared() {
    _searchController.clear();
    // Text controller listener kommer automatiskt uppdatera ViewModel
  }

  void _onSortChanged(SortCriteria? criteria) {
    if (criteria != null) {
      final viewModel = context.read<RecipeListViewModel>();
      viewModel.updateSort(criteria);
    }
  }

  // Återställ alla filter
  void _clearAllFilters() {
    final viewModel = context.read<RecipeListViewModel>();
    viewModel.clearAllFilters();
    setState(() {
      _showFilters = false;
    });
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

  @override
  Widget build(BuildContext context) {
    // Watch för att lyssna på ViewModel-ändringar
    final viewModel = context.watch<RecipeListViewModel>();
    final offlineService = context.watch<offline_service.OfflineService>();
    final userService = context.watch<UserService>();

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

          // USER AVATAR med social funktionalitet (logout, backup, etc.)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXs),
            child: UserAvatar.social(
              imageUrl: userService.currentUserProfile?.avatarUrl,
              displayName: userService.currentUserProfile?.displayName ??
                  'Okänd användare',
            ),
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

            // Sökfält
            Padding(
              padding: EdgeInsets.all(AppTheme.spacingSmPlus),
              child: AppSearchBar(
                controller: _searchController,
                hintText: 'Sök recept...',
                onChanged:
                    (_) {}, // ViewModel uppdateras via controller listener
                onClear: _onSearchCleared,
              ),
            ),

            // FILTER CHIPS SEKTION - animerad visning
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _showFilters
                  ? Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tidsfilter
                          FilterChips(
                            title: 'Tillagningstid',
                            options: RecipeFilters.timeFilters,
                            selectedIds: viewModel.activeTimeFilters,
                            onToggle: viewModel.toggleTimeFilter,
                            scrollable: false,
                          ),

                          SizedBox(height: AppTheme.spacingSm),

                          // Måltidstyp-filter
                          FilterChips(
                            title: 'Måltidstyp',
                            options: RecipeFilters.mealTypeFilters,
                            selectedIds: viewModel.activeMealTypeFilters,
                            onToggle: viewModel.toggleMealTypeFilter,
                            scrollable: false,
                          ),

                          SizedBox(height: AppTheme.spacingSm),

                          // Betygsfilter
                          FilterChips(
                            title: 'Betyg',
                            options: RecipeFilters.ratingFilters,
                            selectedIds: viewModel.activeRatingFilters,
                            onToggle: viewModel.toggleRatingFilter,
                            scrollable: false,
                          ),

                          // Rensa filter-knapp om det finns aktiva filter
                          if (viewModel.hasActiveFilters)
                            Padding(
                              padding: EdgeInsets.all(AppTheme.spacingSmPlus),
                              child: Center(
                                child: TextButton.icon(
                                  onPressed: _clearAllFilters,
                                  icon: const Icon(Icons.clear),
                                  label: const Text('Rensa alla filter'),
                                ),
                              ),
                            ),

                          SizedBox(height: AppTheme.spacingSm),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
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
          // Behåll sökfältet synligt om det finns söktext
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingSmPlus),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    size: AppTheme.iconSizeInfo,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: AppTheme.spacingXs),
                  Text(
                    'Söker...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          // Skeleton loader istället för spinner
          const Expanded(child: RecipeListSkeleton(itemCount: 5)),
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

    // Sök- och filterstatistik
    Widget statsWidget = const SizedBox.shrink();
    if (viewModel.searchQuery.isNotEmpty || viewModel.hasActiveFilters) {
      final statsText = <String>[];

      if (viewModel.searchQuery.isNotEmpty) {
        statsText.add('Sökning: "${viewModel.searchQuery}"');
      }

      if (viewModel.hasActiveFilters) {
        final filterCount = viewModel.activeTimeFilters.length +
            viewModel.activeMealTypeFilters.length +
            viewModel.activeRatingFilters.length;
        statsText.add('$filterCount filter aktiva');
      }

      statsText.add('${recipes.length} recept hittades');

      statsWidget = Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSmPlus,
          vertical: AppTheme.spacingXs,
        ),
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: AppTheme.iconSizeInfo,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            SizedBox(width: AppTheme.spacingXs),
            Expanded(
              child: Text(
                statsText.join(' • '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    // Empty states
    if (recipes.isEmpty) {
      return Column(
        children: [
          statsWidget,
          Expanded(
            child: viewModel.searchQuery.isEmpty && !viewModel.hasActiveFilters
                ? EmptyState.noRecipes(
                    onAction: () => Navigator.pushNamed(context, '/laggTill'),
                  )
                : EmptyState.noSearchResults(
                    onAction: viewModel.searchQuery.isNotEmpty
                        ? _onSearchCleared
                        : _clearAllFilters,
                    actionLabel: viewModel.searchQuery.isNotEmpty
                        ? 'Rensa sökning'
                        : 'Rensa filter',
                  ),
          ),
        ],
      );
    }

    // Receptlista med RefreshIndicator som synkar om online
    return Column(
      children: [
        statsWidget,
        Expanded(
          child: RefreshIndicator(
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
                  child: RecipeCard(
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
          ),
        ),
      ],
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
