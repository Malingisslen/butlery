// lib/views/importera_fran_arkiv_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/archive_import_viewmodel.dart';
import '../widgets/recipe_card.dart';
import '../widgets/search_bar.dart';
import '../widgets/action_button.dart';
import '../widgets/empty_state.dart';
import '../theme/app_theme.dart';
import '../core/injection.dart';

/// ✨ UPPDATERAD ARKIV IMPORT VY MED ARCHIVEIMPORTVIEWMODEL
class ImporteraFranArkivView extends StatelessWidget {
  const ImporteraFranArkivView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => sl<ArchiveImportViewModel>(),
      child: const _ImporteraFranArkivViewContent(),
    );
  }
}

class _ImporteraFranArkivViewContent extends StatelessWidget {
  const _ImporteraFranArkivViewContent();

  void _handleImport(
    BuildContext context,
    ArchiveImportViewModel viewModel,
  ) async {
    if (viewModel.hasSelection) {
      await viewModel.importSelectedRecipes();
    } else {
      await viewModel.importAllRecipes();
    }

    if (context.mounted) {
      if (viewModel.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recept importerade!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.error!),
            backgroundColor: AppTheme.errorColor,
            action: SnackBarAction(
              label: 'OK',
              onPressed: viewModel.clearError,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ArchiveImportViewModel>();
    final allTags = viewModel.availableTags.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importera från Butlerys arkiv'),
        actions: [
          if (viewModel.hasError)
            IconButton(
              icon: AppTheme.errorIcon(context),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(viewModel.error!),
                    action: SnackBarAction(
                      label: 'Stäng',
                      onPressed: viewModel.clearError,
                    ),
                  ),
                );
              },
              tooltip: 'Visa fel',
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
                  onChanged: viewModel.updateSearch,
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
                            selected: viewModel.selectedTags.contains(tag),
                            onSelected: () => viewModel.toggleTag(tag),
                          );
                        }).toList(),
                  ),
                  SizedBox(height: AppTheme.spacingMd),
                ],

                // Tids-filter
                _buildTimeFilters(context, viewModel),
                SizedBox(height: AppTheme.spacingMd),

                // Sökstatistik
                if (viewModel.searchQuery.isNotEmpty ||
                    viewModel.selectedTags.isNotEmpty ||
                    viewModel.timeFilter != TimeFilter.all)
                  _buildSearchStats(context, viewModel),

                // Recept-lista
                Expanded(child: _buildRecipeList(context, viewModel)),
                SizedBox(height: AppTheme.spacingMd),

                // Import-knappar
                _buildImportButtons(context, viewModel),
              ],
            ),
          ),

          // Loading overlay
          if (viewModel.isImporting)
            Container(
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
                        'Importerar recept...',
                        style: AppTheme.subtitleStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeFilters(
    BuildContext context,
    ArchiveImportViewModel viewModel,
  ) {
    return Wrap(
      spacing: AppTheme.spacingSm,
      children: [
        AppTheme.choiceChip(
          label: 'Alla',
          selected: viewModel.timeFilter == TimeFilter.all,
          onSelected: () => viewModel.setTimeFilter(TimeFilter.all),
        ),
        AppTheme.choiceChip(
          label: '≤ 15 min',
          selected: viewModel.timeFilter == TimeFilter.under15,
          onSelected: () => viewModel.setTimeFilter(TimeFilter.under15),
        ),
        AppTheme.choiceChip(
          label: '≤ 30 min',
          selected: viewModel.timeFilter == TimeFilter.under30,
          onSelected: () => viewModel.setTimeFilter(TimeFilter.under30),
        ),
        AppTheme.choiceChip(
          label: '≤ 60 min',
          selected: viewModel.timeFilter == TimeFilter.under60,
          onSelected: () => viewModel.setTimeFilter(TimeFilter.under60),
        ),
      ],
    );
  }

  Widget _buildSearchStats(
    BuildContext context,
    ArchiveImportViewModel viewModel,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Row(
        children: [
          AppTheme.filterIcon(context),
          SizedBox(width: AppTheme.spacingXs),
          Text(
            '${viewModel.filteredRecipes.length} av ${viewModel.archivedRecipes.length} recept',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            '${viewModel.selectedCount} valda',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeList(
    BuildContext context,
    ArchiveImportViewModel viewModel,
  ) {
    final recipes = viewModel.filteredRecipes;

    if (recipes.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'Inga recept matchade filtren',
        subtitle: 'Prova att justera sökning eller filter',
      );
    }

    return ListView.builder(
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        final selected = viewModel.selectedRecipeIds.contains(recipe.id);

        return Padding(
          padding: EdgeInsets.symmetric(vertical: AppTheme.spacingXxs),
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
              onChanged: (_) => viewModel.toggleRecipeSelection(recipe.id),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImportButtons(
    BuildContext context,
    ArchiveImportViewModel viewModel,
  ) {
    return Row(
      children: [
        Expanded(
          child: ActionButton.outlined(
            label: 'Markera alla',
            icon: Icons.select_all,
            onPressed: viewModel.isImporting ? null : viewModel.toggleSelectAll,
          ),
        ),
        SizedBox(width: AppTheme.spacingSm),
        Expanded(
          flex: 2,
          child: ActionButton.primary(
            label:
                viewModel.hasSelection
                    ? 'Importera valda (${viewModel.selectedCount})'
                    : 'Importera alla (${viewModel.archivedRecipes.length})',
            icon: Icons.upload,
            onPressed:
                viewModel.isImporting
                    ? null
                    : () => _handleImport(context, viewModel),
            isLoading: viewModel.isImporting,
            loadingText: 'Importerar...',
          ),
        ),
      ],
    );
  }
}
