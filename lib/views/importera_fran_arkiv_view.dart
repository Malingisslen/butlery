// lib/views/importera_fran_arkiv_view.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../data/archived_recipes.dart';
import '../services/recipe_service.dart';
import '../widgets/recipe_card.dart';
import '../widgets/search_bar.dart';
import '../widgets/action_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/recipe_service_widget.dart';
import '../services/search_service.dart';
import '../theme/app_theme.dart';

enum TimeFilter { all, under15, under30, under60 }

/// ✨ UPPDATERAD ARKIV IMPORT VY MED RECIPESERVICE
class ImporteraFranArkivView extends StatefulWidget {
  const ImporteraFranArkivView({super.key});

  @override
  State<ImporteraFranArkivView> createState() => _ImporteraFranArkivViewState();
}

class _ImporteraFranArkivViewState extends State<ImporteraFranArkivView> {
  final SearchService _searchService = SearchService();
  final RecipeService _recipeService = RecipeService();
  final Set<String> _selectedTags = {};
  final Set<String> _selectedRecipeIds = {};

  TimeFilter _selectedTimeFilter = TimeFilter.all;
  String _searchQuery = '';
  List<Recipe> _filteredRecipes = archivedRecipes;
  bool _isImporting = false;

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

  Future<void> _importSelectedRecipes() async {
    if (_selectedRecipeIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Inga recept valda')));
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      final toImport =
          archivedRecipes
              .where((r) => _selectedRecipeIds.contains(r.id))
              .toList();

      final result = await _recipeService.addMultipleRecipes(toImport);

      if (!mounted) return;

      if (result.isSuccess) {
        RecipeServiceSnackbar.showSuccess(context, result.message);
        if (result.warnings != null && result.warnings!.isNotEmpty) {
          // Visa varningar om några recept inte kunde läggas till
          RecipeServiceSnackbar.showWarning(
            context,
            'Några recept kunde inte läggas till: ${result.warnings!.length} fel',
          );
        }
        Navigator.pop(context);
      } else {
        RecipeServiceSnackbar.showError(context, result.message);
      }
    } catch (e) {
      if (!mounted) return;
      RecipeServiceSnackbar.showError(
        context,
        'Import misslyckades: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _importAllRecipes() async {
    setState(() {
      _isImporting = true;
    });

    try {
      final result = await _recipeService.addMultipleRecipes(archivedRecipes);

      if (!mounted) return;

      if (result.isSuccess) {
        RecipeServiceSnackbar.showSuccess(context, result.message);
        if (result.warnings != null && result.warnings!.isNotEmpty) {
          RecipeServiceSnackbar.showWarning(
            context,
            'Några recept kunde inte läggas till: ${result.warnings!.length} fel',
          );
        }
        Navigator.pop(context);
      } else {
        RecipeServiceSnackbar.showError(context, result.message);
      }
    } catch (e) {
      if (!mounted) return;
      RecipeServiceSnackbar.showError(
        context,
        'Import misslyckades: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTags =
        archivedRecipes.expand((r) => r.tags ?? []).toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importera från Butlerys arkiv'),
        actions: [
          // Visa RecipeService errors
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
                          label: 'Stäng',
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
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              children: [
                // Sökfält
                AppSearchBar(
                  hintText: 'Sök i arkiv...',
                  onChanged: _onSearchChanged,
                ),
                SizedBox(height: AppTheme.spacingMd),

                // Tagg-filter
                if (allTags.isNotEmpty) ...[
                  Wrap(
                    spacing: AppTheme.spacingSm,
                    children:
                        allTags.map((tag) {
                          return AppTheme.filterChip(
                            label: tag,
                            selected: _selectedTags.contains(tag),
                            onSelected: () => _toggleTag(tag),
                          );
                        }).toList(),
                  ),
                  SizedBox(height: AppTheme.spacingMd),
                ],

                // Tids-filter
                Wrap(
                  spacing: AppTheme.spacingSm,
                  children: [
                    AppTheme.choiceChip(
                      label: 'Alla',
                      selected: _selectedTimeFilter == TimeFilter.all,
                      onSelected: () => _toggleTimeFilter(TimeFilter.all),
                    ),
                    AppTheme.choiceChip(
                      label: '≤ 15 min',
                      selected: _selectedTimeFilter == TimeFilter.under15,
                      onSelected: () => _toggleTimeFilter(TimeFilter.under15),
                    ),
                    AppTheme.choiceChip(
                      label: '≤ 30 min',
                      selected: _selectedTimeFilter == TimeFilter.under30,
                      onSelected: () => _toggleTimeFilter(TimeFilter.under30),
                    ),
                    AppTheme.choiceChip(
                      label: '≤ 60 min',
                      selected: _selectedTimeFilter == TimeFilter.under60,
                      onSelected: () => _toggleTimeFilter(TimeFilter.under60),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacingMd),

                // Sökstatistik
                if (_searchQuery.isNotEmpty ||
                    _selectedTags.isNotEmpty ||
                    _selectedTimeFilter != TimeFilter.all)
                  Padding(
                    padding: EdgeInsets.only(bottom: AppTheme.spacingSm),
                    child: Row(
                      children: [
                        AppTheme.filterIcon(context),
                        SizedBox(width: AppTheme.spacingXs),
                        Text(
                          '${_filteredRecipes.length} av ${archivedRecipes.length} recept',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_selectedRecipeIds.length} valda',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
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
                          )
                          : ListView(
                            children:
                                _filteredRecipes.map((recipe) {
                                  final selected = _selectedRecipeIds.contains(
                                    recipe.id,
                                  );
                                  return Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: AppTheme.spacingXxs,
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
                                            (_) => _toggleRecipeSelection(
                                              recipe.id,
                                            ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                ),
                SizedBox(height: AppTheme.spacingMd),

                // Import-knappar
                Row(
                  children: [
                    Expanded(
                      child: ActionButton.outlined(
                        label: 'Markera alla',
                        icon: Icons.select_all,
                        onPressed:
                            _isImporting
                                ? null
                                : () {
                                  setState(() {
                                    if (_selectedRecipeIds.length ==
                                        _filteredRecipes.length) {
                                      _selectedRecipeIds.clear();
                                    } else {
                                      _selectedRecipeIds
                                        ..clear()
                                        ..addAll(
                                          _filteredRecipes.map((r) => r.id),
                                        );
                                    }
                                  });
                                },
                      ),
                    ),
                    SizedBox(width: AppTheme.spacingSm),
                    Expanded(
                      flex: 2,
                      child: ActionButton.primary(
                        label:
                            _selectedRecipeIds.isNotEmpty
                                ? 'Importera valda (${_selectedRecipeIds.length})'
                                : 'Importera alla (${archivedRecipes.length})',
                        icon: Icons.upload,
                        onPressed:
                            _isImporting
                                ? null
                                : (_selectedRecipeIds.isNotEmpty
                                    ? _importSelectedRecipes
                                    : _importAllRecipes),
                        isLoading: _isImporting,
                        loadingText: 'Importerar...',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Loading overlay för RecipeService
          RecipeServiceConsumer(
            builder: (context, recipeService, child) {
              if (recipeService.isLoading && !_isImporting) {
                return Container(
                  color: Colors.black26,
                  child: Center(
                    child: Container(
                      padding: AppTheme.cardPadding,
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: AppTheme.largeRadius,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppTheme.mediumLoadingIndicator(),
                          AppTheme.smallGap,
                          Text(
                            'Bearbetar recept...',
                            style: AppTheme.subtitleStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
