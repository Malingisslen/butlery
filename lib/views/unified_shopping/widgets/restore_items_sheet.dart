import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/content_time_labels.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/unified/shopping_row_snapshot.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/shopping/restorable_rows.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';

/// BUT-2140: "Återställ varor" — the rows removed or changed in the last 30
/// days, with a restore button on each line.
///
/// Restoring swaps versions, so what is replaced becomes the new `previous`
/// and Ångra is always possible: class 1 per BUT-954, no dialog.
class RestoreItemsSheet extends StatelessWidget {
  const RestoreItemsSheet({super.key, required this.viewModel});

  final UnifiedShoppingViewModel viewModel;

  static const Duration undoDuration = Duration(seconds: 7);

  /// Opens the sheet; a tap on a line closes it and restores that line from
  /// [context], so the snackbar with Ångra is not hidden behind the sheet.
  static Future<void> show(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
  ) async {
    final choice = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RestoreItemsSheet(viewModel: viewModel),
    );
    if (choice == null || !context.mounted) return;
    if (choice is ShoppingRowSnapshot) {
      await _restoreRemoved(context, viewModel, choice);
    } else if (choice is UnifiedShoppingItem) {
      await _restoreChanged(context, viewModel, choice);
    }
  }

  static Future<void> _restoreRemoved(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    ShoppingRowSnapshot entry,
  ) async {
    final l = context.l10n;
    final message = l.shoppingRestoredRemoved(entry.name);
    final undoLabel = l.commonUndo;
    final ok = await viewModel.restoreRemovedRow(entry);
    if (!context.mounted) return;
    if (!ok) return _fail(context, viewModel);
    SnackBarUtils.showSuccessWithAction(
      context,
      message,
      actionLabel: undoLabel,
      duration: undoDuration,
      onAction: () async {
        final undone = await viewModel.removeItem(entry.id);
        if (!undone && context.mounted) _fail(context, viewModel);
      },
    );
  }

  static Future<void> _restoreChanged(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    UnifiedShoppingItem item,
  ) async {
    final l = context.l10n;
    final message = l.shoppingRestoredChanged(item.previous?.name ?? item.name);
    final undoLabel = l.commonUndo;
    final ok = await viewModel.restoreChangedRow(item.id);
    if (!context.mounted) return;
    if (!ok) return _fail(context, viewModel);
    SnackBarUtils.showSuccessWithAction(
      context,
      message,
      actionLabel: undoLabel,
      duration: undoDuration,
      onAction: () async {
        final undone = await viewModel.restoreChangedRow(item.id);
        if (!undone && context.mounted) _fail(context, viewModel);
      },
    );
  }

  static void _fail(BuildContext context, UnifiedShoppingViewModel viewModel) {
    final reason = viewModel.consumeMutationError();
    SnackBarUtils.showFailure(
      context,
      what: reason ?? context.l10n.errorGeneric,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final l = context.l10n;
        final list = viewModel.activeList;
        final now = DateTime.now();
        final removed = list == null
            ? const <ShoppingRowSnapshot>[]
            : RestorableRows.restorableAt(list, now);
        final changed = list == null
            ? const <UnifiedShoppingItem>[]
            : RestorableRows.changedAt(list, now);

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            children: [
              Text(l.shoppingRestoreItems, style: AppTextStyles.titleMedium),
              const SizedBox(height: AppDimensions.spacingMd),
              if (removed.isEmpty && changed.isEmpty)
                Text(l.shoppingRestoreEmpty),
              if (removed.isNotEmpty) ...[
                _Heading(l.shoppingRestoreGroupRemoved),
                for (final entry in removed)
                  _RestoreLine(
                    key: ValueKey('restore-removed-${entry.id}'),
                    name: entry.name,
                    text: _amountText(entry.toItem(), withName: true),
                    at: entry.at,
                    now: now,
                    onRestore: () => Navigator.of(context).pop(entry),
                  ),
              ],
              if (changed.isNotEmpty) ...[
                _Heading(l.shoppingRestoreGroupChanged),
                for (final item in changed)
                  _RestoreLine(
                    key: ValueKey('restore-changed-${item.id}'),
                    name: item.previous!.name,
                    text: l.shoppingRestoreChangedLine(
                      _amountText(item.previous!.toItem(), withName: true),
                      _currentText(item.previous!, item),
                    ),
                    at: item.previous!.at,
                    now: now,
                    onRestore: () => Navigator.of(context).pop(item),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// "Ägg 12 st": the name, then amount and unit when the row has an amount.
  static String _amountText(UnifiedShoppingItem row, {required bool withName}) {
    final parts = [
      if (withName) row.name,
      if (row.amount != 0.0) row.formattedAmount,
      if (row.amount != 0.0 && row.formattedUnit.isNotEmpty) row.formattedUnit,
    ];
    return parts.join(' ');
  }

  /// What the row says now: only the amount when the name is unchanged, so
  /// "Ägg 12 st (nu: 6 st)" and not "(nu: Ägg 6 st)".
  static String _currentText(
    ShoppingRowSnapshot before,
    UnifiedShoppingItem now,
  ) {
    final sameName = before.name == now.name;
    final text = _amountText(now, withName: !sameName);
    return text.isEmpty ? now.name : text;
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
    child: Semantics(
      header: true,
      child: Text(text, style: AppTextStyles.titleSmall),
    ),
  );
}

class _RestoreLine extends StatelessWidget {
  const _RestoreLine({
    super.key,
    required this.name,
    required this.text,
    required this.at,
    required this.now,
    required this.onRestore,
  });

  final String name;
  final String text;
  final DateTime at;
  final DateTime now;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(text),
      subtitle: Text(ContentTimeLabels.whenLabel(l, at, now)),
      trailing: Semantics(
        label: l.shoppingRestoreButtonFor(name),
        button: true,
        excludeSemantics: true,
        child: TextButton(
          onPressed: onRestore,
          child: Text(l.shoppingRestoreButton),
        ),
      ),
    );
  }
}
