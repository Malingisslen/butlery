import 'package:flutter/material.dart';
import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/shopping_store.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/app_icon_button.dart';
import 'package:butlery/widgets/common/chips/butlery_action_chip.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet_header.dart';

/// One chip under the list header: which store this list is sorted for.
class ShoppingStoreBar extends StatelessWidget {
  final UnifiedShoppingViewModel viewModel;

  const ShoppingStoreBar({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (viewModel.activeList == null) return const SizedBox.shrink();
    final store = viewModel.activeStore;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.space16,
          AppDimensions.space8,
          AppDimensions.space16,
          0,
        ),
        child: ButleryActionChip(
          label: store == null
              ? context.l10n.shoppingStoreChipNone
              : context.l10n.shoppingStoreChip(store.name),
          icon: ButleryIcons.pin,
          onPressed: () => StorePickerSheet.show(context, viewModel),
        ),
      ),
    );
  }
}

/// Bottom sheet for choosing, adding and removing the user's stores.
class StorePickerSheet extends StatelessWidget {
  final UnifiedShoppingViewModel viewModel;

  const StorePickerSheet({super.key, required this.viewModel});

  static Future<void> show(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
  ) {
    return showButlerySheet<void>(
      context: context,
      builder: (_) => StorePickerSheet(viewModel: viewModel),
    );
  }

  Future<void> _add(BuildContext context) async {
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    if (viewModel.shoppingStores.length >= ShoppingStore.maxStores) {
      await DialogFactory.showError(
        context,
        title: l10n.shoppingStoreAdd,
        message: l10n.shoppingStoreLimit(ShoppingStore.maxStores),
      );
      return;
    }
    final name = await DialogFactory.showTextInput(
      context,
      title: l10n.shoppingStoreAdd,
      hintText: l10n.shoppingStoreAddHint,
      confirmText: l10n.commonCreate,
      required: true,
    );
    if (name == null || name.trim().isEmpty) return;
    await viewModel.addStoreAndSelect(name);
    navigator.pop();
  }

  Future<void> _delete(BuildContext context, ShoppingStore store) async {
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    final confirmed =
        await ConfirmationDialogs.showDestructiveConfirmationDialog(
          context,
          title: l10n.shoppingStoreDeleteTitle,
          message: l10n.shoppingStoreDeleteMessage(store.name),
          confirmText: l10n.shoppingStoreDeleteConfirm,
        );
    if (!confirmed) return;
    await viewModel.deleteStore(store.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final active = viewModel.activeStore;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.space8),
            child: ButlerySheetHeader(
              title: context.l10n.shoppingStorePickerTitle,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final store in viewModel.shoppingStores)
                  ButleryItemRow(
                    title: store.name,
                    selected: store.id == active?.id,
                    showCheck: true,
                    onTap: () async {
                      final navigator = Navigator.of(context);
                      await viewModel.selectStore(store.id);
                      navigator.pop();
                    },
                    trailing: AppIconButton(
                      semanticLabel: context.l10n.shoppingStoreDeleteConfirm,
                      icon: ButleryIcons.close,
                      onPressed: () => _delete(context, store),
                    ),
                  ),
                ButleryItemRow(
                  title: context.l10n.shoppingStoreNone,
                  subtitle: context.l10n.shoppingStoreNoneSubtitle,
                  selected: active == null,
                  showCheck: true,
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    await viewModel.selectStore(null);
                    navigator.pop();
                  },
                ),
                ButleryItemRow(
                  title: context.l10n.shoppingStoreAdd,
                  leadingIcon: ButleryIcons.plus,
                  onTap: () => _add(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
