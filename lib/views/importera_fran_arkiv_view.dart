// lib/views/importera_fran_arkiv_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/archive_import_viewmodel.dart';
import 'package:butlery/widgets/common/content_card.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/bottom_action_bar.dart';
import 'package:butlery/widgets/common/filter_status_chip.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// UPPDATERAD ARKIV IMPORT VY - MIGRERAD TILL UtilityComponents
class ImporteraFranArkivView extends StatelessWidget {
  const ImporteraFranArkivView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServiceLocator.get<ArchiveImportViewModel>(),
      child: const _ImporteraFranArkivViewContent(),
    );
  }
}

class _ImporteraFranArkivViewContent extends StatelessWidget {
  const _ImporteraFranArkivViewContent();

  Future<void> _handleImport(
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
        UtilityComponents.showSuccessSnackbar(
            context, context.l10n.importRecipesImported);
        Navigator.pop(context);
      } else {
        UtilityComponents.showErrorSnackbar(context, viewModel.error!);
        viewModel.clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewModel = context.watch<ArchiveImportViewModel>();
    final allTags = viewModel.availableTags.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.importFromArchive),
        actions: [
          if (viewModel.hasError)
            IconButton(
              icon: Icon(Icons.error, color: cs.error),
              onPressed: () {
                UtilityComponents.showErrorSnackbar(context, viewModel.error!);
                viewModel.clearError();
              },
              tooltip: context.l10n.importShowError,
            ),
        ],
      ),
      body: SafeArea(
        // RESPONSIVE: Center and constrain content on large screens (Wide layout for batch processing)
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 900,
                desktop: 1200,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    // Filter-sektion i en scrollbar container
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.35,
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding:
                              AppDimensions.responsiveContentPadding(context),
                          child: Column(
                            children: [
                              SearchFilterWidget.searchOnly(
                                searchQuery: viewModel.searchQuery,
                                onSearchChanged: viewModel.updateSearch,
                                searchHint: context.l10n.importSearchArchive,
                                showStats: true,
                                resultCount: viewModel.searchQuery.isNotEmpty
                                    ? viewModel.filteredRecipes.length
                                    : null,
                              ),

                              const SizedBox(height: AppDimensions.paddingL),

                              // Tagg-filter
                              if (allTags.isNotEmpty) ...[
                                Wrap(
                                  spacing: AppDimensions.spacingS,
                                  children: allTags.map((tag) {
                                    return FilterChip(
                                      label: Text(tag),
                                      selected:
                                          viewModel.selectedTags.contains(tag),
                                      onSelected: (_) =>
                                          viewModel.toggleTag(tag),
                                      backgroundColor:
                                          cs.surfaceContainerHighest,
                                      selectedColor: cs.primary.withValues(
                                          alpha: AppDimensions.opacityLight),
                                      checkmarkColor: cs.primary,
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: AppDimensions.paddingL),
                              ],

                              // Tids-filter
                              _buildTimeFilters(context, viewModel),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Divider mellan filter och innehall
                    const Divider(height: 1),

                    // Avancerad filter-statistik
                    if (viewModel.selectedTags.isNotEmpty ||
                        viewModel.timeFilter != TimeFilter.all)
                      Padding(
                        padding: const EdgeInsets.symmetric(
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
                    BottomActionBar(
                      child: _buildImportButtons(context, viewModel),
                    ),
                  ],
                ),

                // Loading overlay
                if (viewModel.isImporting)
                  UtilityComponents.loadingOverlay(
                    isLoading: true,
                    loadingMessage: context.l10n.importImportingRecipesProgress,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeFilters(
    BuildContext context,
    ArchiveImportViewModel viewModel,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: AppDimensions.spacingS,
      children: [
        ChoiceChip(
          label: Text(context.l10n.importFilterAll),
          selected: viewModel.timeFilter == TimeFilter.all,
          onSelected: (_) => viewModel.setTimeFilter(TimeFilter.all),
          backgroundColor: viewModel.timeFilter == TimeFilter.all
              ? cs.primary
              : cs.surfaceContainerHighest,
          selectedColor: cs.primary,
          labelStyle: AppTextStyles.labelSmall.copyWith(
            color: viewModel.timeFilter == TimeFilter.all
                ? cs.onPrimary
                : cs.onSurface,
          ),
        ),
        ChoiceChip(
          label: const Text('<= 15 min'),
          selected: viewModel.timeFilter == TimeFilter.under15,
          onSelected: (_) => viewModel.setTimeFilter(TimeFilter.under15),
          backgroundColor: viewModel.timeFilter == TimeFilter.under15
              ? cs.primary
              : cs.surfaceContainerHighest,
          selectedColor: cs.primary,
          labelStyle: AppTextStyles.labelSmall.copyWith(
            color: viewModel.timeFilter == TimeFilter.under15
                ? cs.onPrimary
                : cs.onSurface,
          ),
        ),
        ChoiceChip(
          label: const Text('<= 30 min'),
          selected: viewModel.timeFilter == TimeFilter.under30,
          onSelected: (_) => viewModel.setTimeFilter(TimeFilter.under30),
          backgroundColor: viewModel.timeFilter == TimeFilter.under30
              ? cs.primary
              : cs.surfaceContainerHighest,
          selectedColor: cs.primary,
          labelStyle: AppTextStyles.labelSmall.copyWith(
            color: viewModel.timeFilter == TimeFilter.under30
                ? cs.onPrimary
                : cs.onSurface,
          ),
        ),
        ChoiceChip(
          label: const Text('<= 60 min'),
          selected: viewModel.timeFilter == TimeFilter.under60,
          onSelected: (_) => viewModel.setTimeFilter(TimeFilter.under60),
          backgroundColor: viewModel.timeFilter == TimeFilter.under60
              ? cs.primary
              : cs.surfaceContainerHighest,
          selectedColor: cs.primary,
          labelStyle: AppTextStyles.labelSmall.copyWith(
            color: viewModel.timeFilter == TimeFilter.under60
                ? cs.onPrimary
                : cs.onSurface,
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
      filterParts
          .add(context.l10n.importTagsCount(viewModel.selectedTags.length));
    }

    if (viewModel.timeFilter != TimeFilter.all) {
      final timeLabel = _getTimeFilterLabel(context, viewModel.timeFilter);
      filterParts.add(timeLabel);
    }

    if (filterParts.isEmpty) return const SizedBox.shrink();

    return FilterStatusChip(
      filterParts: filterParts,
      selectedCount: viewModel.selectedCount,
    );
  }

  String _getTimeFilterLabel(BuildContext context, TimeFilter filter) {
    switch (filter) {
      case TimeFilter.under15:
        return '<= 15 min';
      case TimeFilter.under30:
        return '<= 30 min';
      case TimeFilter.under60:
        return '<= 60 min';
      case TimeFilter.all:
        return context.l10n.importFilterAllTimes;
    }
  }

  Widget _buildRecipeList(
    BuildContext context,
    ArchiveImportViewModel viewModel,
  ) {
    final recipes = viewModel.filteredRecipes;

    if (recipes.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.importNoRecipesMatchedFilters,
        subtitle: context.l10n.importTryAdjustFilters,
        icon: Icons.search_off,
      );
    }

    return ListView.builder(
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];

        return Padding(
          padding:
              const EdgeInsets.symmetric(vertical: AppDimensions.spacingXs),
          child: ContentCard(
            key: ValueKey(recipe.id),
            item: recipe,
            type: ContentCardType.recipe,
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
            child: UtilityComponents.outlinedButton(
              context,
              label: context.l10n.commonSelectAll,
              icon: Icons.select_all,
              onPressed:
                  viewModel.isImporting ? null : viewModel.toggleSelectAll,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            flex: 2,
            child: UtilityComponents.primaryButton(
              context,
              label: viewModel.hasSelection
                  ? context.l10n.importSelectedCount(viewModel.selectedCount)
                  : context.l10n
                      .importAllCount(viewModel.archivedRecipes.length),
              icon: Icons.upload,
              onPressed: viewModel.isImporting
                  ? null
                  : () => _handleImport(context, viewModel),
              isLoading: viewModel.isImporting,
              loadingText: context.l10n.importImporting,
            ),
          ),
        ],
      ),
    );
  }

  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions
    // Dispose of resources    super.dispose();
  }
}
