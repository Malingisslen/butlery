// lib/views/importera_fran_arkiv_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/archive_import_viewmodel.dart';
import '../widgets/common/content_card.dart';
import '../widgets/common/search_filter_widget.dart';
import '../widgets/common/utility_components.dart';
import '../widgets/common/state_widget.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import '../core/injection.dart';

/// ✨ UPPDATERAD ARKIV IMPORT VY - MIGRERAD TILL UtilityComponents
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
        // ✅ MIGRERAD: Custom SnackBar → UtilityComponents.showSuccessSnackbar
        UtilityComponents.showSuccessSnackbar(context, 'Recept importerade!');
        Navigator.pop(context);
      } else {
        // ✅ MIGRERAD: Custom SnackBar → UtilityComponents.showErrorSnackbar
        UtilityComponents.showErrorSnackbar(context, viewModel.error!);
        viewModel.clearError();
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
              icon: Icon(Icons.error, color: AppColors.error),
              onPressed: () {
                // ✅ MIGRERAD: Custom SnackBar → UtilityComponents.showErrorSnackbar
                UtilityComponents.showErrorSnackbar(context, viewModel.error!);
                viewModel.clearError();
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
                  maxHeight: MediaQuery.of(context).size.height * 0.35,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(AppDimensions.paddingL),
                  child: Column(
                    children: [
                      SearchFilterWidget.searchOnly(
                        searchQuery: viewModel.searchQuery,
                        onSearchChanged: viewModel.updateSearch,
                        searchHint: 'Sök i arkiv...',
                        showStats: true,
                        resultCount: viewModel.searchQuery.isNotEmpty
                            ? viewModel.filteredRecipes.length
                            : null,
                      ),

                      SizedBox(height: AppDimensions.paddingL),

                      // Tagg-filter
                      if (allTags.isNotEmpty) ...[
                        Wrap(
                          spacing: AppDimensions.spacingS,
                          children: allTags.map((tag) {
                            return FilterChip(
                              label: Text(tag),
                              selected: viewModel.selectedTags.contains(tag),
                              onSelected: (_) => viewModel.toggleTag(tag),
                              backgroundColor: AppColors.cardWhite,
                              selectedColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                              checkmarkColor: AppColors.primaryBlue,
                            );
                          }).toList(),
                        ),
                        SizedBox(height: AppDimensions.paddingL),
                      ],

                      // Tids-filter
                      _buildTimeFilters(context, viewModel),
                    ],
                  ),
                ),
              ),

              // Divider mellan filter och innehåll
              const Divider(height: 1),

              // Avancerad filter-statistik
              if (viewModel.selectedTags.isNotEmpty ||
                  viewModel.timeFilter != TimeFilter.all)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingL,
                    vertical: AppDimensions.spacingS,
                  ),
                  child: _buildAdvancedStats(context, viewModel),
                ),

              // Recept-lista
              Expanded(
                child: _buildRecipeList(context, viewModel),
              ),

              // Import-knappar
              Container(
                padding: EdgeInsets.all(AppDimensions.spacingL),
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

          // Loading overlay - ✅ MIGRERAD: Custom overlay → UtilityComponents.loadingOverlay
          if (viewModel.isImporting)
            UtilityComponents.loadingOverlay(
              isLoading: true,
              loadingMessage: 'Importerar recept...',
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
      spacing: AppDimensions.spacingS,
      children: [
        ChoiceChip(
          label: const Text('Alla'),
          selected: viewModel.timeFilter == TimeFilter.all,
          onSelected: (_) => viewModel.setTimeFilter(TimeFilter.all),
          backgroundColor: viewModel.timeFilter == TimeFilter.all ? AppColors.primaryBlue : AppColors.cardWhite,
          selectedColor: AppColors.primaryBlue,
          labelStyle: AppTextStyles.labelSmall.copyWith(
            color: viewModel.timeFilter == TimeFilter.all ? AppColors.neutralLight : AppColors.textDark,
          ),
        ),
        ChoiceChip(
          label: const Text('≤ 15 min'),
          selected: viewModel.timeFilter == TimeFilter.under15,
          onSelected: (_) => viewModel.setTimeFilter(TimeFilter.under15),
          backgroundColor: viewModel.timeFilter == TimeFilter.under15 ? AppColors.primaryBlue : AppColors.cardWhite,
          selectedColor: AppColors.primaryBlue,
          labelStyle: AppTextStyles.labelSmall.copyWith(
            color: viewModel.timeFilter == TimeFilter.under15 ? AppColors.neutralLight : AppColors.textDark,
          ),
        ),
        ChoiceChip(
          label: const Text('≤ 30 min'),
          selected: viewModel.timeFilter == TimeFilter.under30,
          onSelected: (_) => viewModel.setTimeFilter(TimeFilter.under30),
          backgroundColor: viewModel.timeFilter == TimeFilter.under30 ? AppColors.primaryBlue : AppColors.cardWhite,
          selectedColor: AppColors.primaryBlue,
          labelStyle: AppTextStyles.labelSmall.copyWith(
            color: viewModel.timeFilter == TimeFilter.under30 ? AppColors.neutralLight : AppColors.textDark,
          ),
        ),
        ChoiceChip(
          label: const Text('≤ 60 min'),
          selected: viewModel.timeFilter == TimeFilter.under60,
          onSelected: (_) => viewModel.setTimeFilter(TimeFilter.under60),
          backgroundColor: viewModel.timeFilter == TimeFilter.under60 ? AppColors.primaryBlue : AppColors.cardWhite,
          selectedColor: AppColors.primaryBlue,
          labelStyle: AppTextStyles.labelSmall.copyWith(
            color: viewModel.timeFilter == TimeFilter.under60 ? AppColors.neutralLight : AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedStats(
    BuildContext context,
    ArchiveImportViewModel viewModel,
  ) {
    final filterParts = <String>[];

    if (viewModel.selectedTags.isNotEmpty) {
      filterParts.add('${viewModel.selectedTags.length} taggar');
    }

    if (viewModel.timeFilter != TimeFilter.all) {
      final timeLabel = _getTimeFilterLabel(viewModel.timeFilter);
      filterParts.add(timeLabel);
    }

    if (filterParts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .secondaryContainer
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            color: AppColors.textMedium,
            size: AppDimensions.iconSizeM,
          ),
          SizedBox(width: AppDimensions.spacingXs),
          Expanded(
            child: Text(
              'Filter: ${filterParts.join(' • ')}',
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${viewModel.selectedCount} valda',
            style: AppTextStyles.bodySmall.copyWith(
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

        return Padding(
          padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingXs),
          child: ContentCard.recipe(
            recipe: recipe,
            onTap: () => Navigator.pushNamed(
              context,
              '/receptDetalj',
              arguments: recipe,
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
            // ✅ MIGRERAD: ActionButton.outlined → UtilityComponents.outlinedButton
            child: UtilityComponents.outlinedButton(
              context,
              label: 'Markera alla',
              icon: Icons.select_all,
              onPressed:
                  viewModel.isImporting ? null : viewModel.toggleSelectAll,
            ),
          ),
          SizedBox(width: AppDimensions.spacingS),
          Expanded(
            flex: 2,
            // ✅ MIGRERAD: ActionButton.primary → UtilityComponents.primaryButton
            child: UtilityComponents.primaryButton(
              context,
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
