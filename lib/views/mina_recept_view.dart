// lib/views/mina_recept_view.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../widgets/main_layout_menu.dart';
import '../widgets/recipe_card.dart';
import '../widgets/search_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/recipe_service_widget.dart';
import '../services/search_service.dart';
import '../theme/app_theme.dart';

/// ✨ UPPDATERAD VY MED RECIPESERVICE INTEGRATION
class MinaReceptView extends StatefulWidget {
  const MinaReceptView({super.key});

  @override
  State<MinaReceptView> createState() => _MinaReceptViewState();
}

class _MinaReceptViewState extends State<MinaReceptView> {
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();
  final RecipeService _recipeService = RecipeService();

  String _searchQuery = '';
  SortCriteria _currentSort = SortCriteria.title;
  bool _sortAscending = true;

  List<Recipe>? _cachedFilteredRecipes;
  String? _lastSearchQuery;
  SortCriteria? _lastSortCriteria;
  bool? _lastSortAscending;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _cachedFilteredRecipes = null;
    });
  }

  void _onSearchCleared() {
    setState(() {
      _searchQuery = '';
    });
  }

  void _onSortChanged(SortCriteria? criteria) {
    if (criteria != null) {
      setState(() {
        if (_currentSort == criteria) {
          _sortAscending = !_sortAscending;
        } else {
          _currentSort = criteria;
          _sortAscending = true;
        }
        _cachedFilteredRecipes = null;
      });
    }
  }

  List<Recipe> _getFilteredAndSortedRecipes(List<Recipe> allRecipes) {
    // ✅ Kontrollera om vi kan använda cached resultat
    if (_cachedFilteredRecipes != null &&
        _lastSearchQuery == _searchQuery &&
        _lastSortCriteria == _currentSort &&
        _lastSortAscending == _sortAscending) {
      return _cachedFilteredRecipes!;
    }

    // Först sökning
    final searchResults = _searchService.searchRecipes(
      allRecipes,
      _searchQuery,
    );

    // Sedan sortering
    final sorted = _searchService.sortRecipes(
      searchResults,
      _currentSort,
      ascending: _sortAscending,
    );

    // ✅ Cacha resultatet
    _cachedFilteredRecipes = sorted;
    _lastSearchQuery = _searchQuery;
    _lastSortCriteria = _currentSort;
    _lastSortAscending = _sortAscending;

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return MainLayoutMenu(
      currentIndex: 0,
      title: 'Mina recept',
      actions: [
        // Error indicator (visar om RecipeService har fel)
        RecipeServiceConsumer(
          builder: (context, recipeService, child) {
            if (recipeService.hasError) {
              return IconButton(
                icon: AppTheme.errorIcon(context),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(recipeService.lastError!),
                      action: SnackBarAction(
                        label: 'Försök igen',
                        onPressed: () {
                          recipeService.clearError();
                        },
                      ),
                    ),
                  );
                },
                tooltip: 'Visa fel',
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // Sort menu
        PopupMenuButton<SortCriteria>(
          icon: Icon(
            _sortAscending ? Icons.sort : Icons.sort,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          tooltip: 'Sortera',
          onSelected: _onSortChanged,
          itemBuilder:
              (context) => [
                _buildSortMenuItem(SortCriteria.title, 'Titel', Icons.title),
                _buildSortMenuItem(SortCriteria.time, 'Tid', Icons.access_time),
                _buildSortMenuItem(SortCriteria.rating, 'Betyg', Icons.star),
                _buildSortMenuItem(
                  SortCriteria.mealType,
                  'Måltidstyp',
                  Icons.restaurant,
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
              onChanged: _onSearchChanged,
              onClear: _onSearchCleared,
            ),
          ),

          // Huvudinnehåll med RecipeService integration
          Expanded(
            child: RecipeServiceWidget(
              showLoadingOverlay:
                  false, // Visa loading state istället för overlay
              builder: (recipes) {
                final filteredRecipes = _getFilteredAndSortedRecipes(recipes);

                // Sökstatistik
                Widget searchStats = const SizedBox.shrink();
                if (_searchQuery.isNotEmpty) {
                  searchStats = Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSmPlus,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: AppTheme.iconSizeInfo,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: AppTheme.spacingXs),
                        Text(
                          '${filteredRecipes.length} recept hittades',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Empty states
                if (filteredRecipes.isEmpty) {
                  return Column(
                    children: [
                      searchStats,
                      Expanded(
                        child:
                            _searchQuery.isEmpty
                                ? EmptyState.noRecipes(
                                  onAction:
                                      () => Navigator.pushNamed(
                                        context,
                                        '/laggTill',
                                      ),
                                )
                                : EmptyState.noSearchResults(
                                  onAction: _onSearchCleared,
                                  actionLabel: 'Rensa sökning',
                                ),
                      ),
                    ],
                  );
                }

                // Receptlista
                return Column(
                  children: [
                    searchStats,
                    if (_searchQuery.isNotEmpty) AppTheme.smallGap,

                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(
                          vertical: AppTheme.spacingSm,
                        ),
                        itemCount: filteredRecipes.length,
                        itemBuilder: (context, index) {
                          final recipe = filteredRecipes[index];

                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingSm,
                              vertical: AppTheme.spacingXs,
                            ),
                            child: RecipeCard(
                              recipe: recipe,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/receptDetalj',
                                  arguments: recipe,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              errorBuilder: (error) {
                return Center(
                  child: Padding(
                    padding: AppTheme.screenPadding,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppTheme.errorContainer(context, error),
                        AppTheme.mediumGap,
                        ElevatedButton(
                          onPressed: () {
                            _recipeService.clearError();
                            _recipeService.initialize();
                          },
                          child: const Text('Försök igen'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<SortCriteria> _buildSortMenuItem(
    SortCriteria criteria,
    String label,
    IconData icon,
  ) {
    final isSelected = _currentSort == criteria;

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
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: AppTheme.iconSizeInfo,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }
}
