// lib/views/mina_recept_view.dart

import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/recipe.dart';
import '../widgets/main_layout_menu.dart';
import '../widgets/recipe_card.dart';
import '../services/search_service.dart';

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
                PopupMenuItem(
                  value: SortCriteria.title,
                  child: Row(
                    children: [
                      Icon(
                        Icons.title,
                        color:
                            _currentSort == SortCriteria.title
                                ? Theme.of(context).colorScheme.primary
                                : null,
                      ),
                      const SizedBox(width: 8),
                      Text('Titel'),
                      if (_currentSort == SortCriteria.title)
                        Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: SortCriteria.time,
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color:
                            _currentSort == SortCriteria.time
                                ? Theme.of(context).colorScheme.primary
                                : null,
                      ),
                      const SizedBox(width: 8),
                      Text('Tid'),
                      if (_currentSort == SortCriteria.time)
                        Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: SortCriteria.rating,
                  child: Row(
                    children: [
                      Icon(
                        Icons.star,
                        color:
                            _currentSort == SortCriteria.rating
                                ? Theme.of(context).colorScheme.primary
                                : null,
                      ),
                      const SizedBox(width: 8),
                      Text('Betyg'),
                      if (_currentSort == SortCriteria.rating)
                        Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: SortCriteria.mealType,
                  child: Row(
                    children: [
                      Icon(
                        Icons.restaurant,
                        color:
                            _currentSort == SortCriteria.mealType
                                ? Theme.of(context).colorScheme.primary
                                : null,
                      ),
                      const SizedBox(width: 8),
                      Text('Måltidstyp'),
                      if (_currentSort == SortCriteria.mealType)
                        Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ],
        ),
      ],
      body: Column(
        children: [
          // Sökfält
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Sök recept',
                hintText: 'Titel, ingredienser, taggar...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                        : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Sökstatistik
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.restaurant_menu
                              : Icons.search_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Inga recept ännu'
                              : 'Inga recept matchade din sökning',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Lägg till ditt första recept genom att trycka på "Lägg till"',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = filteredRecipes[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
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
}
