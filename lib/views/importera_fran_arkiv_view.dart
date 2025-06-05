import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../data/archived_recipes.dart';
import '../data/dummy_data.dart';

enum TimeFilter { all, under15, under30, under60 }

class ImporteraFranArkivView extends StatefulWidget {
  const ImporteraFranArkivView({super.key});

  @override
  State<ImporteraFranArkivView> createState() => _ImporteraFranArkivViewState();
}

class _ImporteraFranArkivViewState extends State<ImporteraFranArkivView> {
  final Set<String> _selectedTags = {};
  final Set<String> _selectedRecipeIds = {};
  TimeFilter _selectedTimeFilter = TimeFilter.all;
  List<Recipe> _filteredRecipes = archivedRecipes;

  @override
  void initState() {
    super.initState();
    _applyFilters();
  }

  void _applyFilters() {
    List<Recipe> results = archivedRecipes;

    // Tagg-filter: AND-logik
    if (_selectedTags.isNotEmpty) {
      results =
          results.where((r) {
            return _selectedTags.every((t) => r.tags?.contains(t) ?? false);
          }).toList();
    }

    // Tids-filter: <= logik
    switch (_selectedTimeFilter) {
      case TimeFilter.under15:
        results = results.where((r) => (r.timeMinutes ?? 0) <= 15).toList();
        break;
      case TimeFilter.under30:
        results = results.where((r) => (r.timeMinutes ?? 0) <= 30).toList();
        break;
      case TimeFilter.under60:
        results = results.where((r) => (r.timeMinutes ?? 0) <= 60).toList();
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

  void _toggleTag(String tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    } else {
      _selectedTags.add(tag);
    }
    _applyFilters();
  }

  void _toggleTimeFilter(TimeFilter filter) {
    _selectedTimeFilter = filter;
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
            // Tagg-filter
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
                  label: const Text('<= 15 min'),
                  selected: _selectedTimeFilter == TimeFilter.under15,
                  onSelected: (_) => _toggleTimeFilter(TimeFilter.under15),
                ),
                ChoiceChip(
                  label: const Text('<= 30 min'),
                  selected: _selectedTimeFilter == TimeFilter.under30,
                  onSelected: (_) => _toggleTimeFilter(TimeFilter.under30),
                ),
                ChoiceChip(
                  label: const Text('<= 60 min'),
                  selected: _selectedTimeFilter == TimeFilter.under60,
                  onSelected: (_) => _toggleTimeFilter(TimeFilter.under60),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Recept-lista
            Expanded(
              child: ListView(
                children:
                    _filteredRecipes.map((recipe) {
                      final selected = _selectedRecipeIds.contains(recipe.id);
                      return InkWell(
                        onTap:
                            () => Navigator.pushNamed(
                              context,
                              '/receptDetalj',
                              arguments: recipe,
                            ),
                        child: ListTile(
                          leading: Checkbox(
                            value: selected,
                            onChanged: (_) => _toggleRecipeSelection(recipe.id),
                          ),
                          title: Text(recipe.title),
                          subtitle: Text(
                            '${recipe.timeMinutes ?? '?'} min, ${recipe.portions ?? '?'} port',
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Import-knapp
            ElevatedButton.icon(
              icon: const Icon(Icons.upload),
              label: Text(
                _selectedRecipeIds.isNotEmpty
                    ? 'Lägg till de valda (${_selectedRecipeIds.length} st)'
                    : 'Lägg till alla recept (${archivedRecipes.length} st)',
              ),
              onPressed:
                  _selectedRecipeIds.isNotEmpty
                      ? _importSelectedRecipes
                      : _importAllRecipes,
            ),
          ],
        ),
      ),
    );
  }
}
