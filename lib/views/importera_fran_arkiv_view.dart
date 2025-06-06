// lib/views/importera_fran_arkiv_view.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../data/archived_recipes.dart';
import '../data/dummy_data.dart';
import '../widgets/recipe_card.dart';
import '../widgets/search_bar.dart';
import '../widgets/action_button.dart';
import '../widgets/empty_state.dart';
import '../services/search_service.dart';

enum TimeFilter { all, under15, under30, under60 }

class ImporteraFranArkivView extends StatefulWidget {
  const ImporteraFranArkivView({super.key});

  @override
  State<ImporteraFranArkivView> createState() => _ImporteraFranArkivViewState();
}

class _ImporteraFranArkivViewState extends State<ImporteraFranArkivView> {
  final SearchService _searchService = SearchService();
  final Set<String> _selectedTags = {};
  final Set<String> _selectedRecipeIds = {};
  TimeFilter _selectedTimeFilter = TimeFilter.all;
  String _searchQuery = '';
  List<Recipe> _filteredRecipes = archivedRecipes;

  @override
  void initState() {
    super.initState();
    _applyFilters();
  }

  void _applyFilters() {
    List<Recipe> results = archivedRecipes;

    // Sökfilter
    if (_searchQuery.isNotEmpty) {
      results = _searchService.searchRecipes(results, _searchQuery);
    }

    // Tagg-filter: AND-logik
    if (_selectedTags.isNotEmpty) {
      results = _searchService.filterByTags(results, _selectedTags.toList());
    }

    // Tids-filter
    switch (_selectedTimeFilter) {
      case TimeFilter.under15:
        results = _searchService.filterByMaxTime(results, 15);
        break;
      case TimeFilter.under30:
        results = _searchService.filterByMaxTime(results, 30);
        break;
      case TimeFilter.under60:
        results = _searchService.filterByMaxTime(results, 60);
        break;
      case TimeFilter.all:
        break;
    }

    setState(() {
      _filteredRecipes = results;
      _selectedRecipeIds
        ..clear()
        ..addAll(_filteredRecipes.map((r) => r.id));
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyFilters();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
    _applyFilters();
  }

  void _toggleTimeFilter(TimeFilter filter) {
    setState(() {
      _selectedTimeFilter = filter;
    });
    _applyFilters();
  }

  void _toggleRecipeSelection(String id) {
    setState(() {
      if (_selectedRecipeIds.contains(id)) {
        _selectedRecipeIds.remove(id);
      } else {
        _selectedRecipeIds.add(id);
      }
    });
  }

  void _importSelectedRecipes() {
    final toImport =
        archivedRecipes
            .where((r) => _selectedRecipeIds.contains(r.id))
            .toList();
    dummyRecipesNotifier.value = [...dummyRecipesNotifier.value, ...toImport];
    Navigator.pop(context);
  }

  void _importAllRecipes() {
    dummyRecipesNotifier.value = [
      ...dummyRecipesNotifier.value,
      ...archivedRecipes,
    ];
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final allTags =
        archivedRecipes.expand((r) => r.tags ?? []).toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Importera från Butlerys arkiv')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Sökfält
            AppSearchBar(
              hintText: 'Sök i arkiv...',
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 16),

            // Tagg-filter
            if (allTags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                children:
                    allTags.map((tag) {
                      return FilterChip(
                        label: Text(tag),
                        selected: _selectedTags.contains(tag),
                        onSelected: (_) => _toggleTag(tag),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Tids-filter
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Alla'),
                  selected: _selectedTimeFilter == TimeFilter.all,
                  onSelected: (_) => _toggleTimeFilter(TimeFilter.all),
                ),
                ChoiceChip(
                  label: const Text('≤ 15 min'),
                  selected: _selectedTimeFilter == TimeFilter.under15,
                  onSelected: (_) => _toggleTimeFilter(TimeFilter.under15),
                ),
                ChoiceChip(
                  label: const Text('≤ 30 min'),
                  selected: _selectedTimeFilter == TimeFilter.under30,
                  onSelected: (_) => _toggleTimeFilter(TimeFilter.under30),
                ),
                ChoiceChip(
                  label: const Text('≤ 60 min'),
                  selected: _selectedTimeFilter == TimeFilter.under60,
                  onSelected: (_) => _toggleTimeFilter(TimeFilter.under60),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Sökstatistik
            if (_searchQuery.isNotEmpty ||
                _selectedTags.isNotEmpty ||
                _selectedTimeFilter != TimeFilter.all)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_filteredRecipes.length} av ${archivedRecipes.length} recept',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

            // Recept-lista
            Expanded(
              child:
                  _filteredRecipes.isEmpty
                      ? EmptyState(
                        icon: Icons.search_off,
                        title: 'Inga recept matchade filtren',
                        subtitle: 'Prova att justera sökning eller filter',
                        // ✅ Använder EmptyState widget istället för hardkodade färger
                      )
                      : ListView(
                        children:
                            _filteredRecipes.map((recipe) {
                              final selected = _selectedRecipeIds.contains(
                                recipe.id,
                              );
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: CompactRecipeCard(
                                  recipe: recipe,
                                  onTap:
                                      () => Navigator.pushNamed(
                                        context,
                                        '/receptDetalj',
                                        arguments: recipe,
                                      ),
                                  trailing: Checkbox(
                                    value: selected,
                                    onChanged:
                                        (_) =>
                                            _toggleRecipeSelection(recipe.id),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
            ),
            const SizedBox(height: 16),

            // Import-knapp
            ActionButton.primary(
              label:
                  _selectedRecipeIds.isNotEmpty
                      ? 'Lägg till de valda (${_selectedRecipeIds.length} st)'
                      : 'Lägg till alla recept (${archivedRecipes.length} st)',
              icon: Icons.upload,
              onPressed:
                  _selectedRecipeIds.isNotEmpty
                      ? _importSelectedRecipes
                      : _importAllRecipes,
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }
}
