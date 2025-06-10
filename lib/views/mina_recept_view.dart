// lib/views/mina_recept_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/recipe_list_viewmodel.dart';
import '../widgets/main_layout_menu.dart';
import '../widgets/recipe_card.dart';
import '../widgets/search_bar.dart';
import '../widgets/empty_state.dart';
import '../services/search_service.dart';
import '../theme/app_theme.dart';
import '../core/injection.dart';

/// ✨ UPPDATERAD VY MED VIEWMODEL PATTERN
/// Nu använder vi Provider och RecipeListViewModel istället för setState
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

  @override
  Widget build(BuildContext context) {
    // Watch för att lyssna på ViewModel-ändringar
    final viewModel = context.watch<RecipeListViewModel>();

    return MainLayoutMenu(
      currentIndex: 0,
      title: 'Mina recept',
      actions: [
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
              onChanged: (_) {}, // ViewModel uppdateras via controller listener
              onClear: _onSearchCleared,
            ),
          ),

          // Huvudinnehåll
          Expanded(child: _buildContent(viewModel)),
        ],
      ),
    );
  }

  Widget _buildContent(RecipeListViewModel viewModel) {
    // Loading state
    if (viewModel.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppTheme.mediumLoadingIndicator(),
            AppTheme.smallGap,
            Text('Laddar recept...', style: AppTheme.subtitleStyle),
          ],
        ),
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

    // Sökstatistik
    Widget searchStats = const SizedBox.shrink();
    if (viewModel.searchQuery.isNotEmpty) {
      searchStats = Padding(
        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingSmPlus),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: AppTheme.iconSizeInfo,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: AppTheme.spacingXs),
            Text(
              '${recipes.length} recept hittades',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          searchStats,
          Expanded(
            child:
                viewModel.searchQuery.isEmpty
                    ? EmptyState.noRecipes(
                      onAction: () => Navigator.pushNamed(context, '/laggTill'),
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
        if (viewModel.searchQuery.isNotEmpty) AppTheme.smallGap,
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
