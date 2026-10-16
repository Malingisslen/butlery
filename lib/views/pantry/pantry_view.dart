/// Pantry view ("Skafferiet") — displays the user's tracked ingredients
/// organized by location with expiry tracking and an add bottom sheet.
///
/// Designed as a sub-tab under the shopping area — does not own its own
/// Scaffold or app bar. Wrap in a parent that provides layout chrome.
library;

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/pantry/pantry_selection_manager.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/add_pantry_item_sheet.dart';
import 'package:butlery/views/pantry/pantry_item_card.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/loading_state_builder.dart';
import 'package:butlery/widgets/common/list/section_band.dart';
import 'package:butlery/widgets/common/buttons/saffron_square_button.dart';
import 'package:butlery/widgets/common/selection_bulk_bar.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';

class PantryView extends StatefulWidget {
  /// [viewModel] and [selection] come from the view that hosts the pantry
  /// tab, which then owns and disposes them. "Välj" and the selection
  /// counter sit in that view's own top bar, so it needs the row count and
  /// the selection (produktregler.md:871-873). Without them the pantry makes
  /// and owns its own.
  const PantryView({super.key, this.viewModel, this.selection});

  final PantryViewModel? viewModel;
  final PantrySelectionManager? selection;

  @override
  State<PantryView> createState() => _PantryViewState();
}

class _PantryViewState extends State<PantryView> {
  late final PantryViewModel _vm;
  // BUT-948: view-local selection state (mirrors the personal-tags pattern).
  late final PantrySelectionManager _selection;
  late final bool _ownsViewModel;
  late final bool _ownsSelection;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _ownsSelection = widget.selection == null;
    _vm = widget.viewModel ?? ServiceLocator.get<PantryViewModel>();
    _selection = widget.selection ?? PantrySelectionManager();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _vm.loadPantry();
    });
  }

  @override
  void dispose() {
    if (_ownsSelection) _selection.dispose();
    if (_ownsViewModel) _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PantryViewModel>.value(value: _vm),
        ChangeNotifierProvider<PantrySelectionManager>.value(value: _selection),
      ],
      child: const _PantryViewContent(),
    );
  }
}

class _PantryViewContent extends StatelessWidget {
  const _PantryViewContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PantryViewModel>();
    final selection = context.watch<PantrySelectionManager>();

    return Stack(
      children: [
        Column(
          children: [
            LayoutComponents.offlineIndicator(),
            Expanded(
              child: LoadingStateBuilder<List<PantryItem>>(
                isLoading: viewModel.isLoading,
                loadingMessage: context.l10n.loadingPantry,
                error: viewModel.error,
                data: viewModel.items,
                onErrorRetry: () {
                  viewModel.clearError();
                  viewModel.loadPantry();
                },
                emptyBuilder: (context) => StateWidget.empty(
                  variant: EmptyStateVariant.noPantryItems,
                  actionLabel: context.l10n.pantryAddIngredient,
                  onAction: () => _showAddSheet(context, viewModel),
                ),
                builder: (context, items) => const _PantrySections(),
              ),
            ),
          ],
        ),
        // BUT-948: in selection mode a contextual bulk bar replaces the add FAB.
        if (selection.isSelectionMode)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SelectionBulkBar(
              count: selection.selectedCount,
              label: context.l10n.bulkSelectedCount(selection.selectedCount),
              onClose: selection.clearSelection,
              onDelete: () => _deleteSelected(context, viewModel, selection),
            ),
          )
        else
          Positioned(
            right: AppDimensions.layoutMarginOf(context),
            bottom: AppDimensions.space24,
            // Its own node: merged upward the label would land on the whole
            // tab's node and a screen reader could not reach the button.
            child: Semantics(
              container: true,
              child: SaffronSquareButton(
                semanticLabel: context.l10n.a11yPantryAddItem,
                onPressed: () => _showAddSheet(context, viewModel),
              ),
            ),
          ),
      ],
    );
  }

  /// BUT-948: bulk delete with a single undo snackbar (class-1 reversible).
  /// Captures the removed items and localized strings before the await so the
  /// undo can re-add them and no dead-context lookups happen post-clear.
  Future<void> _deleteSelected(
    BuildContext context,
    PantryViewModel viewModel,
    PantrySelectionManager selection,
  ) async {
    final ids = selection.selectedIds;
    if (ids.isEmpty) return;
    final removed = viewModel.items.where((i) => ids.contains(i.id)).toList();
    final undo = UndoSnackBar.capture(context);
    final message = context.l10n.pantryItemsRemovedUndoMessage(removed.length);

    selection.clearSelection();
    await viewModel.bulkRemoveItems(ids);
    // If the delete failed, the VM surfaces its own error — don't also show a
    // "N removed" undo snackbar that would restore items still present.
    if (viewModel.hasError) return;

    undo.show(message, onUndo: () => viewModel.restoreItems(removed));
  }

  Future<void> _showAddSheet(
    BuildContext context,
    PantryViewModel viewModel,
  ) async {
    await showButlerySheet<void>(
      context: context,
      builder: (sheetContext) => ChangeNotifierProvider<PantryViewModel>.value(
        value: viewModel,
        child: const AddPantryItemSheet(),
      ),
    );
  }
}

class _PantrySections extends StatelessWidget {
  const _PantrySections();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PantryViewModel>();
    final l10n = context.l10n;

    final expiring = vm.expiringItems;
    final places = [
      (l10n.pantrySectionFridge, PantryLocation.fridge),
      (l10n.pantrySectionFreezer, PantryLocation.freezer),
      (l10n.pantrySectionPantry, PantryLocation.pantry),
      (l10n.pantrySectionSpiceRack, PantryLocation.spiceRack),
    ].map((p) => (title: p.$1, items: vm.itemsByLocation(p.$2))).toList();
    // With nothing about to expire, the first place holding items opens, so
    // a stocked pantry never looks empty on arrival (BUT-2261, Malin
    // 2026-10-09).
    final opened = expiring.isNotEmpty
        ? -1
        : places.indexWhere((p) => p.items.isNotEmpty);

    return ListView(
      padding: const EdgeInsets.only(
        top: AppDimensions.space16,
        bottom: AppDimensions.fabClearance,
      ),
      children: [
        if (expiring.isNotEmpty)
          _PantrySection(
            key: const ValueKey('pantry-section-expiring'),
            title: l10n.pantrySectionExpiring,
            items: expiring,
            initiallyExpanded: true,
            urgent: true,
          ),
        for (final (i, place) in places.indexed)
          _PantrySection(
            key: ValueKey('pantry-section-${place.title}'),
            title: place.title,
            items: place.items,
            initiallyExpanded: i == opened,
          ),
      ],
    );
  }
}

class _PantrySection extends StatefulWidget {
  const _PantrySection({
    super.key,
    required this.title,
    required this.items,
    this.initiallyExpanded = false,
    this.urgent = false,
  });

  final String title;
  final List<PantryItem> items;
  final bool initiallyExpanded;

  /// "Utgår snart" takes the saffron bar and the warning tone; the places do
  /// not.
  final bool urgent;

  @override
  State<_PantrySection> createState() => _PantrySectionState();
}

class _PantrySectionState extends State<_PantrySection> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    // Skarmar v12 etapp 2 #skafferivyn: a group is a band with its rows
    // under it, hairlines between them, never a card.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.layoutMarginOf(context),
        0,
        AppDimensions.layoutMarginOf(context),
        AppDimensions.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionBand(
            title: widget.title,
            count: '${widget.items.length}',
            expanded: _open,
            tone: widget.urgent
                ? SectionBandTone.warning
                : SectionBandTone.standard,
            onTap: () => setState(() => _open = !_open),
          ),
          if (_open)
            for (final item in widget.items)
              PantryItemCard(key: ValueKey(item.id), item: item),
        ],
      ),
    );
  }
}
