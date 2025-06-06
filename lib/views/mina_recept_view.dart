// lib/views/mina_recept_view.dart

import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/recipe.dart';
import '../widgets/main_layout_menu.dart';
import '../widgets/recipe_card.dart';
import '../widgets/search_bar.dart';
import '../widgets/empty_state.dart';
import '../services/search_service.dart';
import '../theme/app_theme.dart';

class MinaReceptView extends StatefulWidget {
  const MinaReceptView({super.key});

  @override
  State<MinaReceptView> createState() => _MinaReceptViewState();
}

class _MinaReceptViewState extends State<MinaReceptView> {
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();

  String _searchQuery = '';
  SortCriteria _currentSort = SortCriteria.title;
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
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
      });
    }
  }

  List<Recipe> _getFilteredAndSortedRecipes() {
    final allRecipes = dummyRecipesNotifier.value;

    // Först sökning
    final searchResults = _searchService.searchRecipes(
      allRecipes,
      _searchQuery,
    );

    // Sedan sortering
    return _searchService.sortRecipes(
      searchResults,
      _currentSort,
      ascending: _sortAscending,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainLayoutMenu(
      currentIndex: 0,
      title: 'Mina recept',
      actions: [
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
            padding: EdgeInsets.all(
              AppTheme.spacingSm + 4,
            ), // ✅ 12px från theme
            child: AppSearchBar(
              controller: _searchController,
              hintText: 'Sök recept...',
              onChanged: _onSearchChanged,
              onClear: _onSearchCleared,
            ),
          ),

          // Sökstatistik
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSm + 4,
              ), // ✅ 12px från theme
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: AppTheme.spacingXs), // ✅ 4px från theme
                  Text(
                    '${_getFilteredAndSortedRecipes().length} recept hittades',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

          // Receptlista
          Expanded(
            child: ValueListenableBuilder<List<Recipe>>(
              valueListenable: dummyRecipesNotifier,
              builder: (context, recipeList, _) {
                final filteredRecipes = _getFilteredAndSortedRecipes();

                if (filteredRecipes.isEmpty) {
                  if (_searchQuery.isEmpty) {
                    return EmptyState.noRecipes(
                      onAction: () => Navigator.pushNamed(context, '/laggTill'),
                    );
                  } else {
                    return EmptyState.noSearchResults(
                      onAction: _onSearchCleared,
                      actionLabel: 'Rensa sökning',
                    );
                  }
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(
                    vertical: AppTheme.spacingSm,
                  ), // ✅ 8px från theme
                  itemCount: filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = filteredRecipes[index];

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSm, // ✅ 8px från theme
                        vertical: AppTheme.spacingXs, // ✅ 4px från theme
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
          SizedBox(width: AppTheme.spacingSm), // ✅ 8px från theme
          Text(label),
          const Spacer(),
          if (isSelected)
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }
}
