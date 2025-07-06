// lib/views/importera_fran_arkiv_view.dart
// 🔄 UPPDATERAD: Migrerad från AppSearchBar till SearchFilterWidget.searchOnly()

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/archive_import_viewmodel.dart';
import '../widgets/common/content_card.dart';
import '../widgets/common/search_filter_widget.dart'; // ✅ NY IMPORT
import '../widgets/action_button.dart';
import '../widgets/common/state_widget.dart'; // ✅ MIGRATION: Ersätt EmptyState
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
          Column(
            children: [
              // Filter-sektion i en scrollbar container
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height *
                      0.35, // Max 35% av skärmhöjden
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(AppTheme.spacingMd),
                  child: Column(
                    children: [
                      // 🔄 UPPDATERAD: SearchFilterWidget.searchOnly() istället för AppSearchBar
                      SearchFilterWidget.searchOnly(
                        searchQuery: viewModel.searchQuery,
                        onSearchChanged: viewModel.updateSearch,
                        searchHint: 'Sök i arkiv...',
                        showStats: true, // ✨ BONUS: Visa sökstatistik
                        resultCount: viewModel.searchQuery.isNotEmpty
                            ? viewModel.filteredRecipes.length
                            : null,
                      ),

                      SizedBox(height: AppTheme.spacingMd),

                      // Tagg-filter
                      if (allTags.isNotEmpty) ...[
                        Wrap(
                          spacing: AppTheme.spacingSm,
                          children: allTags.map((tag) {
                            return AppTheme.filterChip(
                              label: tag,
                              selected: viewModel.selectedTags.contains(
                                tag,
                              ),
                              onSelected: () => viewModel.toggleTag(tag),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: AppTheme.spacingMd),
                      ],

                      // Tids-filter
                      _buildTimeFilters(context, viewModel),
                    ],
                  ),
                ),
              ),

              // Divider mellan filter och innehåll
              const Divider(height: 1),

              // 🔄 UPPDATERAD: Förenklad sökstatistik (SearchFilterWidget visar redan grundläggande stats)
              if (viewModel.selectedTags.isNotEmpty ||
                  viewModel.timeFilter != TimeFilter.all)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: AppTheme.spacingSm,
                  ),
                  child: _buildAdvancedStats(context, viewModel),
                ),

              // Recept-lista
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                  child: _buildRecipeList(context, viewModel),
                ),
              ),

              // Import-knappar
              Container(
                padding: EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: _buildImportButtons(context, viewModel),
              ),
            ],
          ),

          // Loading overlay
          if (viewModel.isImporting)
            Container(
              color: Colors.black26,
              child: Center(
                child: Container(
                  padding: AppTheme.cardPadding,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
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

  /// 🔄 UPPDATERAD: Fokusera på avancerad filter-statistik (SearchFilterWidget hanterar grundläggande)
  Widget _buildAdvancedStats(
    BuildContext context,
    ArchiveImportViewModel viewModel,
  ) {
    final filterParts = <String>[];

    // Lägg till tagg-filter info
    if (viewModel.selectedTags.isNotEmpty) {
      filterParts.add('${viewModel.selectedTags.length} taggar');
    }

    // Lägg till tids-filter info
    if (viewModel.timeFilter != TimeFilter.all) {
      final timeLabel = _getTimeFilterLabel(viewModel.timeFilter);
      filterParts.add(timeLabel);
    }

    if (filterParts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .secondaryContainer
            .withValues(alpha: 0.3),
        borderRadius: AppTheme.smallRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          AppTheme.filterIcon(context),
          SizedBox(width: AppTheme.spacingXs),
          Expanded(
            child: Text(
              'Filter: ${filterParts.join(' • ')}',
              style: AppTheme.captionStyle.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${viewModel.selectedCount} valda',
            style: AppTheme.captionStyle.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeFilterLabel(TimeFilter filter) {
    switch (filter) {
      case TimeFilter.under15:
        return '≤ 15 min';
      case TimeFilter.under30:
        return '≤ 30 min';
      case TimeFilter.under60:
        return '≤ 60 min';
      case TimeFilter.all:
        return 'Alla tider';
    }
  }

  Widget _buildRecipeList(
    BuildContext context,
    ArchiveImportViewModel viewModel,
  ) {
    final recipes = viewModel.filteredRecipes;

    if (recipes.isEmpty) {
      // ✅ MIGRATION: StateWidget empty state
      return StateWidget.empty(
        title: 'Inga recept matchade filtren',
        subtitle: 'Prova att justera sökning eller filter',
        icon: Icons.search_off,
      );
    }

    return ListView.builder(
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        final selected = viewModel.selectedRecipeIds.contains(recipe.id);

        return Padding(
          padding: EdgeInsets.symmetric(vertical: AppTheme.spacingXxs),
          // ✅ UPPDATERAD: Använd ContentCard.compactRecipe istället för CompactRecipeCard
          child: ContentCard.compactRecipe(
            recipe: recipe,
            onTap: () => Navigator.pushNamed(
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
    return SafeArea(
      top: false,
      child: Row(
        children: [
          Expanded(
            child: ActionButton.outlined(
              label: 'Markera alla',
              icon: Icons.select_all,
              onPressed:
                  viewModel.isImporting ? null : viewModel.toggleSelectAll,
            ),
          ),
          SizedBox(width: AppTheme.spacingSm),
          Expanded(
            flex: 2,
            child: ActionButton.primary(
              label: viewModel.hasSelection
                  ? 'Importera valda (${viewModel.selectedCount})'
                  : 'Importera alla (${viewModel.archivedRecipes.length})',
              icon: Icons.upload,
              onPressed: viewModel.isImporting
                  ? null
                  : () => _handleImport(context, viewModel),
              isLoading: viewModel.isImporting,
              loadingText: 'Importerar...',
            ),
          ),
        ],
      ),
    );
  }
}
