/// Pantry item list tile used inside each section of [PantryView], plus
/// its expiry status badge.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/viewmodels/pantry/pantry_selection_manager.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/add_pantry_item_sheet.dart';

class PantryItemCard extends StatelessWidget {
  const PantryItemCard({super.key, required this.item});

  final PantryItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewModel = context.read<PantryViewModel>();
    final selection = context.watch<PantrySelectionManager>();
    final selectionMode = selection.isSelectionMode;
    final selected = selection.isSelected(item.id);

    // Captured BEFORE dismissal: onDismissed fires after the row's element
    // is deactivated, so context lookups there would hit a dead element.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final removedMessage =
        context.l10n.pantryItemRemovedUndoMessage(item.ingredientName);
    final undoLabel = context.l10n.commonUndo;

    // BUT-948: in selection mode tap toggles and long-press is a no-op (already
    // selecting); otherwise tap edits and long-press enters selection.
    final tappable = Semantics(
      label: selectionMode
          ? context.l10n.a11yPantrySelectItem(item.ingredientName)
          : context.l10n.a11yPantryEditItem(item.ingredientName),
      button: true,
      selected: selectionMode ? selected : null,
      child: InkWell(
        onTap: selectionMode
            ? () => selection.toggleSelection(item.id)
            : () => _showEditSheet(context, viewModel),
        onLongPress:
            selectionMode ? null : () => selection.enterSelectionMode(item.id),
        child: _buildRow(context, cs,
            selectionMode: selectionMode, selected: selected),
      ),
    );

    // No swipe-to-delete while selecting — the bulk bar owns deletion then.
    if (selectionMode) return tappable;

    return Dismissible(
      key: ValueKey('pantry-${item.id}'),
      direction: DismissDirection.endToStart,
      // BUT-954: pantry rows are the reversible-destructive class — a row is
      // trivially recreatable, so swipe deletes without a confirm dialog and
      // the snackbar's "Ångra" restores it. (Rule: ui-conventions.md →
      // "Destructive-action confirmation".)
      onDismissed: (_) => _removeWithUndo(
        viewModel,
        messenger: messenger,
        message: removedMessage,
        undoLabel: undoLabel,
      ),
      background: Container(
        color: cs.error,
        alignment: AlignmentDirectional.centerEnd,
        padding:
            const EdgeInsets.symmetric(horizontal: AppDimensions.spacingLg),
        child: Icon(Icons.delete, color: cs.onError),
      ),
      child: tappable,
    );
  }

  Widget _buildRow(
    BuildContext context,
    ColorScheme cs, {
    required bool selectionMode,
    required bool selected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingLg,
        vertical: AppDimensions.spacingMd,
      ),
      decoration: BoxDecoration(
        color: selected ? cs.primary.withValues(alpha: 0.12) : null,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (selectionMode) ...[
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? cs.primary : cs.onSurfaceVariant,
              size: AppDimensions.iconSizeM,
            ),
            const SizedBox(width: AppDimensions.spacingMd),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.ingredientName,
                  style: AppTextStyles.bodyLarge
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.formattedQuantity} ${item.unit}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (item.expiryDate != null) ...[
            const SizedBox(width: AppDimensions.spacingSm),
            _ExpiryBadge(item: item),
          ],
        ],
      ),
    );
  }

  void _removeWithUndo(
    PantryViewModel viewModel, {
    required ScaffoldMessengerState? messenger,
    required String message,
    required String undoLabel,
  }) {
    viewModel.removeItem(item.id);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: undoLabel,
          onPressed: () => viewModel.restoreItem(item),
        ),
        duration: const Duration(seconds: 7),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showEditSheet(BuildContext context, PantryViewModel viewModel) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetContext) => ChangeNotifierProvider<PantryViewModel>.value(
        value: viewModel,
        child: AddPantryItemSheet(existingItem: item),
      ),
    );
  }
}

class _ExpiryBadge extends StatelessWidget {
  const _ExpiryBadge({required this.item});

  final PantryItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.butleryColors;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final status = item.expiryStatus;

    final (bg, fg, text) = switch (status) {
      PantryExpiryStatus.expired => (
          cs.errorContainer,
          cs.onErrorContainer,
          l10n.pantryExpiryExpired,
        ),
      PantryExpiryStatus.expiringSoon => (
          colors.warningContainer,
          colors.onWarningContainer,
          _expiringSoonLabel(context, item.daysUntilExpiry ?? 0),
        ),
      PantryExpiryStatus.fresh => (
          colors.successContainer,
          colors.onSuccessContainer,
          _freshLabel(context, item.expiryDate!),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSm,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(color: bg),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _expiringSoonLabel(BuildContext context, int days) {
    final l10n = context.l10n;
    if (days <= 0) return l10n.pantryExpiryToday;
    return l10n.pantryExpiryInDays(days);
  }

  String _freshLabel(BuildContext context, DateTime date) {
    // Numeric date keeps the label locale-agnostic without pulling in
    // intl's DateFormat; the surrounding label is localized.
    return '${context.l10n.pantryExpiryLabel} ${date.day}/${date.month}';
  }
}
