/// Pantry item list tile used inside each section of [PantryView], plus
/// its expiry status badge.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/add_pantry_item_sheet.dart';

class PantryItemCard extends StatelessWidget {
  const PantryItemCard({super.key, required this.item});

  final PantryItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewModel = context.read<PantryViewModel>();

    return Dismissible(
      key: ValueKey('pantry-${item.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => viewModel.removeItem(item.id),
      background: Container(
        color: cs.error,
        alignment: Alignment.centerRight,
        padding:
            const EdgeInsets.symmetric(horizontal: AppDimensions.spacingLg),
        child: Icon(Icons.delete, color: cs.onError),
      ),
      child: InkWell(
        onTap: () => _showEditSheet(context, viewModel),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingLg,
            vertical: AppDimensions.spacingMd,
          ),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
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
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await CommonDialogActions.showDeleteConfirmation(
      context: context,
      itemName: item.ingredientName,
      itemType: 'ingrediens',
    );
    return result ?? false;
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
