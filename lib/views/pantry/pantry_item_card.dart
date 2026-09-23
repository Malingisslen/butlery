/// Pantry item list tile used inside each section of [PantryView], plus
/// its expiry status badge.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
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

  /// When the row was last changed, per content-style-guide.md:34-36:
  /// relative only for the latest days (`nu` · `5 min sedan` · `i dag 14:02`
  /// · `i går`), then the date (`9 juli`, with the year when it is not this
  /// year). Clock times are 24-hour with a colon (content-style-guide.md:30).
  ///
  /// Interpretation: produktregler.md:105 says the row's timestamp updates,
  /// but no drawing shows the row with one, so the word "ändrad" names what
  /// the time is.
  static String changedLabel(
    AppLocalizations l10n,
    DateTime changedAt,
    DateTime now,
  ) {
    final at = changedAt.toLocal();
    final local = now.toLocal();
    final age = local.difference(at);
    if (age.inMinutes < 1) return l10n.pantryItemChangedNow;
    if (age.inHours < 1) return l10n.pantryItemChangedMinutesAgo(age.inMinutes);
    final today = DateTime(local.year, local.month, local.day);
    final day = DateTime(at.year, at.month, at.day);
    if (day == today) {
      final time =
          '${at.hour.toString().padLeft(2, '0')}:'
          '${at.minute.toString().padLeft(2, '0')}';
      return l10n.pantryItemChangedToday(time);
    }
    if (day == today.subtract(const Duration(days: 1))) {
      return l10n.pantryItemChangedYesterday;
    }
    final date = at.year == local.year
        ? DateFormat.MMMMd(l10n.localeName).format(at)
        : DateFormat.yMMMMd(l10n.localeName).format(at);
    return l10n.pantryItemChangedOn(date);
  }

  /// The line under the name: the amount, and when the row last changed.
  String _metaLine(BuildContext context) {
    final amount = '${item.formattedQuantity} ${item.unit}'.trim();
    final changedAt = item.updatedAt;
    if (changedAt == null) return amount;
    final changed = changedLabel(context.l10n, changedAt, clock.now());
    // An unknown amount ("har hemma") shows no unit on its own.
    return item.quantity == null ? changed : '$amount · $changed';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewModel = context.read<PantryViewModel>();
    final selection = context.watch<PantrySelectionManager>();
    final selectionMode = selection.isSelectionMode;
    final selected = selection.isSelected(item.id);

    // Captured BEFORE dismissal: onDismissed fires after the row's element
    // is deactivated, so context lookups there would hit a dead element.
    final undo = UndoSnackBar.capture(context);
    final removedMessage = context.l10n.pantryItemRemovedUndoMessage(
      item.ingredientName,
    );

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
        onLongPress: selectionMode
            ? null
            : () => selection.enterSelectionMode(item.id),
        child: _buildRow(
          context,
          cs,
          selectionMode: selectionMode,
          selected: selected,
        ),
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
        undo: undo,
        message: removedMessage,
      ),
      background: Container(
        color: cs.error,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingLg,
        ),
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
      // A chosen row is surface.selected, never a 12 % ink tint, and the
      // hairline is border.subtle itself, never faded (enhet-3 valda
      // tonplattor pantry_item_card.dart:102; tokens.json:40-53). The
      // primaryContainer / outlineVariant slots carry those tokens in both
      // schemes.
      decoration: BoxDecoration(
        color: selected ? cs.primaryContainer : null,
        border: Border(
          top: BorderSide(color: cs.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (selectionMode) ...[
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? cs.onSurface : cs.onSurfaceVariant,
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
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _metaLine(context),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
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
    required UndoSnackBar undo,
    required String message,
  }) {
    viewModel.removeItem(item.id);
    undo.show(message, onUndo: () => viewModel.restoreItem(item));
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
