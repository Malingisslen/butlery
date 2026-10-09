/// Pantry view ("Skafferiet") — displays the user's tracked ingredients
/// organized by location with expiry tracking and an add bottom sheet.
///
/// Designed as a sub-tab under the shopping area — does not own its own
/// Scaffold or app bar. Wrap in a parent that provides layout chrome.
library;

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/pantry/pantry_selection_manager.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/add_pantry_item_sheet.dart';
import 'package:butlery/views/pantry/pantry_item_card.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/loading_state_builder.dart';
import 'package:butlery/widgets/common/press_fill.dart';

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
                emptyBuilder: (context) => _PantryEmptyState(
                  onAdd: () => _showAddSheet(context, viewModel),
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
            child: _PantryBulkBar(
              count: selection.selectedCount,
              onClose: selection.clearSelection,
              onDelete: () => _deleteSelected(context, viewModel, selection),
            ),
          )
        else
          Positioned(
            right: AppDimensions.spacingLg,
            bottom: AppDimensions.spacingLg,
            child: _PantryFab(
              onPressed: () => _showAddSheet(context, viewModel),
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
        top: AppDimensions.spacingMd,
        bottom: 96,
      ),
      children: [
        if (expiring.isNotEmpty)
          _PantrySection(
            title: l10n.pantrySectionExpiring,
            items: expiring,
            initiallyExpanded: true,
            urgent: true,
          ),
        for (final (i, place) in places.indexed)
          _PantrySection(
            title: place.title,
            items: place.items,
            initiallyExpanded: i == opened,
          ),
      ],
    );
  }
}

class _PantrySection extends StatelessWidget {
  const _PantrySection({
    required this.title,
    required this.items,
    this.initiallyExpanded = false,
    this.urgent = false,
  });

  final String title;
  final List<PantryItem> items;
  final bool initiallyExpanded;

  /// "Går snart ut" takes the danger tone on its edge; the places do not.
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // Skarmar v12 etapp 2 #skafferivyn: a group sits on paper (ink in dark)
    // with a muted edge and a hairline under it, never the recipe card's
    // ink edge and saffron rule.
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.spacingLg,
        0,
        AppDimensions.spacingLg,
        AppDimensions.spacingMd,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColorsDark.forestGreen : cs.surface,
        border: Border(
          left: BorderSide(color: urgent ? cs.error : cs.outline, width: 4),
          bottom: BorderSide(color: cs.outlineVariant, width: 3),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          iconColor: cs.onSurfaceVariant,
          collapsedIconColor: cs.onSurfaceVariant,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingLg,
            vertical: AppDimensions.spacingXs,
          ),
          childrenPadding: EdgeInsets.zero,
          title: Row(
            children: [
              Text(
                title.toLowerCase(),
                style: AppTextStyles.bodySmall.copyWith(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(
                '${items.length}',
                style: AppTextStyles.labelMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          children: [
            for (final item in items)
              PantryItemCard(key: ValueKey(item.id), item: item),
          ],
        ),
      ),
    );
  }
}

class _PantryFab extends StatelessWidget {
  const _PantryFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // An ink square in light (#skafferivyn); ink on the dark page would not
    // show, so dark turns it to paper with an ink plus.
    return Material(
      color: cs.onSurface,
      elevation: 4,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      // Its own node: without `container` the label merged into the pantry
      // tab's node, and a screen reader could not reach the button
      // (BUT-2261).
      child: Semantics(
        container: true,
        label: context.l10n.a11yPantryAddItem,
        button: true,
        child: PressFill(
          surface: PressSurface.ink,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 56,
              height: 56,
              child: ButleryIcon(
                ButleryIcons.plus,
                color: cs.surface,
                size: AppDimensions.iconSizeL,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// BUT-948: contextual bulk-action bar shown at the bottom while items are
/// selected. Pantry has no app-bar of its own (it's a sub-tab), so the bulk
/// actions live here instead of in a selection app-bar.
///
/// P5-U31: the counter is "{n} valda" (produktregler.md:876). The delete
/// action is off at zero with its name readable (P5-U32).
class _PantryBulkBar extends StatelessWidget {
  const _PantryBulkBar({
    required this.count,
    required this.onClose,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingSm,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const ButleryIcon(ButleryIcons.x),
                tooltip: context.l10n.commonCancel,
                color: cs.onPrimaryContainer,
                onPressed: onClose,
              ),
              Expanded(
                child: Text(
                  context.l10n.bulkSelectedCount(count),
                  style: AppTextStyles.titleSmall.copyWith(
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: count == 0 ? null : onDelete,
                style: TextButton.styleFrom(
                  foregroundColor: cs.onPrimaryContainer,
                  // The disabled role on surface.raised, never the 38 % fade
                  // styleFrom would give (tokens.json:71-74, :198):
                  // text.disabled.onRaised, #788477 light, #93A48D dark.
                  disabledForegroundColor: AppModeColors.textDisabled(
                    cs.brightness,
                  ),
                ),
                icon: const ButleryIcon(ButleryIcons.trash2),
                label: Text(context.l10n.commonDelete),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PantryEmptyState extends StatelessWidget {
  const _PantryEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.layoutMarginOf(context),
          vertical: AppDimensions.space16,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const VegetableIllustration(
              type: VegetableType.broccoli,
              size: 100,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              l10n.pantryEmptyTitle,
              style: AppTextStyles.headlineSmall.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              l10n.pantryEmptyDescription,
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            SizedBox(
              width: double.infinity,
              child: ActionButtons.primaryButton(
                context,
                label: l10n.pantryAddIngredient,
                onPressed: onAdd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
