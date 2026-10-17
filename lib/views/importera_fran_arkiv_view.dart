// lib/views/importera_fran_arkiv_view.dart

import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/archive_import_viewmodel.dart';
import 'package:butlery/views/archive_import/archive_filter_sheet.dart';
import 'package:butlery/widgets/common/butlery_link.dart';
import 'package:butlery/widgets/common/butlery_search_box.dart';
import 'package:butlery/widgets/common/buttons/choice_option.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/widgets/common/list/check_row.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/common/badges/unified_badge.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

class ImporteraFranArkivView extends StatefulWidget {
  const ImporteraFranArkivView({super.key});

  @override
  State<ImporteraFranArkivView> createState() => _ImporteraFranArkivViewState();
}

class _ImporteraFranArkivViewState extends State<ImporteraFranArkivView> {
  late final ArchiveImportViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<ArchiveImportViewModel>();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: const _ImporteraFranArkivViewContent(),
    );
  }
}

class _ImporteraFranArkivViewContent extends StatelessWidget {
  const _ImporteraFranArkivViewContent();

  /// How many tag pills fit beside "Fler" on one line.
  static const int _pillCount = 3;

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
      // A failure stays on screen as the error view with "Försök igen".
      if (viewModel.error == null) {
        SnackBarUtils.showSuccess(context, context.l10n.importRecipesImported);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ArchiveImportViewModel>();

    return ButleryPage.undersida(
      title: context.l10n.importArchiveTitle,
      width: PageWidth.wide,
      actions: [
        if (viewModel.hasSelection)
          Center(
            child: UnifiedBadge.status(
              label: context.l10n.importSelectedCount(
                viewModel.selectedCount,
              ),
            ),
          ),
      ],
      body: Stack(
        children: [
          Column(
            children: [
              // Natural height, but scrolls on its own when it would take more
              // than a third of the screen (a phone on its side), so the list
              // below keeps room.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height / 3,
                ),
                child: SingleChildScrollView(
                  padding: AppDimensions.responsiveContentPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ButlerySearchBox(
                        hintText: context.l10n.importSearchArchive,
                        onChanged: viewModel.updateSearch,
                      ),
                      const SizedBox(height: AppDimensions.space12),
                      _buildFilterPills(context, viewModel),
                      const SizedBox(height: AppDimensions.space8),
                      _buildHeadingRow(context, viewModel),
                    ],
                  ),
                ),
              ),
              Expanded(child: _buildRecipeList(context, viewModel)),
              BottomActionContainer(
                child: _buildImportButton(context, viewModel),
              ),
            ],
          ),
          if (viewModel.isImporting)
            UtilityComponents.loadingOverlay(
              isLoading: true,
              loadingMessage: context.l10n.importImportingRecipesProgress,
            ),
        ],
      ),
    );
  }

  Widget _buildFilterPills(
    BuildContext context,
    ArchiveImportViewModel viewModel,
  ) {
    final all = viewModel.availableTags.toList()..sort();
    // A chosen tag always has its pill, so what filters the list stays visible.
    final chosen = all.where(viewModel.selectedTags.contains).toList();
    final rest = all.where((t) => !viewModel.selectedTags.contains(t));
    final shown = [...chosen, ...rest].take(_pillCount).toList()..sort();
    final moreActive =
        viewModel.timeFilter != TimeFilter.all ||
        chosen.any((t) => !shown.contains(t));
    return Wrap(
      spacing: AppDimensions.space8,
      runSpacing: AppDimensions.space8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final tag in shown)
          ChoiceOption(
            label: tag,
            selected: viewModel.selectedTags.contains(tag),
            onSelected: () => viewModel.toggleTag(tag),
          ),
        ButleryLink(
          onTap: () => showArchiveFilterSheet(context, viewModel),
          child: Text(
            context.l10n.importMoreFilters,
            style: _linkStyle(context, bold: moreActive),
          ),
        ),
      ],
    );
  }

  Widget _buildHeadingRow(
    BuildContext context,
    ArchiveImportViewModel viewModel,
  ) {
    return Row(
      children: [
        Expanded(
          child: SectionHeading(
            context.l10n.importArchivedHeading(
              viewModel.filteredRecipes.length,
            ),
          ),
        ),
        ButleryLink(
          onTap: viewModel.isImporting ? null : viewModel.toggleSelectAll,
          child: Text(
            context.l10n.commonSelectAll,
            style: _linkStyle(context, bold: true),
          ),
        ),
      ],
    );
  }

  TextStyle _linkStyle(BuildContext context, {required bool bold}) {
    return (bold ? AppTextStyles.labelLarge : AppTextStyles.labelMedium)
        .copyWith(color: context.modeColors.textLink);
  }

  String? _subtitle(BuildContext context, Recipe recipe) {
    final minutes = recipe.timeMinutes ?? 0;
    final parts = [
      if (recipe.mealType.isNotEmpty) recipe.mealType,
      if (minutes > 0) context.l10n.importRecipeMinutes(minutes),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget _buildRecipeList(
    BuildContext context,
    ArchiveImportViewModel viewModel,
  ) {
    final recipes = viewModel.filteredRecipes;

    if (viewModel.hasError) {
      return StateWidget.error(
        message: viewModel.error!,
        onAction: () {
          viewModel.clearError();
          _handleImport(context, viewModel);
        },
        actionLabel: context.l10n.commonRetry,
      );
    }

    if (recipes.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.importNoRecipesMatchedFilters,
        subtitle: context.l10n.importTryAdjustFilters,
        icon: ButleryIcons.searchOff,
      );
    }

    final sideInset =
        AppDimensions.responsiveContentPadding(context).horizontal / 2;
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: sideInset),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return CheckRow(
          key: ValueKey(recipe.id),
          title: recipe.title,
          subtitle: _subtitle(context, recipe),
          checked: viewModel.selectedRecipeIds.contains(recipe.id),
          onChanged: (_) => viewModel.toggleRecipeSelection(recipe.id),
        );
      },
    );
  }

  Widget _buildImportButton(
    BuildContext context,
    ArchiveImportViewModel viewModel,
  ) {
    final count = viewModel.hasSelection
        ? viewModel.selectedCount
        : viewModel.filteredRecipes.length;
    return UtilityComponents.primaryButton(
      context,
      label: context.l10n.importRestoreCount(count),
      onPressed: viewModel.isImporting || count == 0
          ? null
          : () => _handleImport(context, viewModel),
      isLoading: viewModel.isImporting,
      loadingText: context.l10n.importImporting,
      isExpanded: true,
    );
  }
}
