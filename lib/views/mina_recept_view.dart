// lib/views/mina_recept_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // NY IMPORT för SystemNavigator
import 'package:provider/provider.dart';
import '../viewmodels/recipe_list_viewmodel.dart';
import '../widgets/main_layout_menu.dart';
import '../widgets/recipe_card.dart';
import '../widgets/search_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/profile_dialog.dart';
import '../widgets/filter_chips.dart'; // NY IMPORT för filter chips
import '../services/search_service.dart';
import '../theme/app_theme.dart';
import '../core/injection.dart';
import '../widgets/skeleton_loader.dart';

/// ✨ UPPDATERAD VY MED FILTER CHIPS
/// Nu har vi integrerat filtreringsfunktionalitet med filter chips UI
class MinaReceptView extends StatelessWidget {
  const MinaReceptView({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap med ChangeNotifierProvider för att tillhandahålla ViewModel
    return ChangeNotifierProvider(
      create: (_) => sl<RecipeListViewModel>(),
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
  bool _showFilters = false; // NY STATE för att visa/dölja filter

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

  // NY METOD för att återställa alla filter
  void _clearAllFilters() {
    final viewModel = context.read<RecipeListViewModel>();
    viewModel
        .clearAllFilters(); // Ändrat från clearFilters till clearAllFilters
    setState(() {
      _showFilters = false;
    });
  }

  // NY METOD för exit-dialog
  Future<void> _showExitDialog(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
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

  @override
  Widget build(BuildContext context) {
    // Watch för att lyssna på ViewModel-ändringar
    final viewModel = context.watch<RecipeListViewModel>();

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
          // Profil-knapp - alltid först i actions-listan
          IconButton(
            icon: Icon(
              Icons.account_circle,
              color: Theme.of(context).colorScheme.primary,
              size: AppTheme.iconSizeNavigation,
            ),
            onPressed: () => showProfileDialog(context),
            tooltip: 'Min profil',
          ),

          // NY FILTER-KNAPP med indikator för aktiva filter
          IconButton(
            icon: Stack(
              children: [
                Icon(
                  Icons.filter_list,
                  color:
                      _showFilters
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
            itemBuilder:
                (context) => [
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
              child:
                  _showFilters
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
                              selectedIds:
                                  viewModel
                                      .activeTimeFilters, // Ändrat från selectedTimeFilters
                              onToggle: viewModel.toggleTimeFilter,
                              scrollable: false,
                            ),

                            SizedBox(height: AppTheme.spacingSm),

                            // Måltidstyp-filter
                            FilterChips(
                              title: 'Måltidstyp',
                              options: RecipeFilters.mealTypeFilters,
                              selectedIds:
                                  viewModel
                                      .activeMealTypeFilters, // Ändrat från selectedMealTypeFilters
                              onToggle: viewModel.toggleMealTypeFilter,
                              scrollable:
                                  false, // Ändrat till false för att visa alla chips i wrap
                            ),

                            SizedBox(height: AppTheme.spacingSm),

                            // Betygsfilter
                            FilterChips(
                              title: 'Betyg',
                              options: RecipeFilters.ratingFilters,
                              selectedIds:
                                  viewModel
                                      .activeRatingFilters, // Ändrat från selectedRatingFilters
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
            Expanded(child: _buildContent(viewModel)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(RecipeListViewModel viewModel) {
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
        final filterCount =
            viewModel.activeTimeFilters.length +
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
            child:
                viewModel.searchQuery.isEmpty && !viewModel.hasActiveFilters
                    ? EmptyState.noRecipes(
                      onAction: () => Navigator.pushNamed(context, '/laggTill'),
                    )
                    : EmptyState.noSearchResults(
                      onAction:
                          viewModel.searchQuery.isNotEmpty
                              ? _onSearchCleared
                              : _clearAllFilters,
                      actionLabel:
                          viewModel.searchQuery.isNotEmpty
                              ? 'Rensa sökning'
                              : 'Rensa filter',
                    ),
          ),
        ],
      );
    }

    // Receptlista
    return Column(
      children: [
        statsWidget,
        Expanded(
          child: RefreshIndicator(
            onRefresh: viewModel.refresh,
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
