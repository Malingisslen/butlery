import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/trash_item.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/trash_viewmodel.dart';
import 'package:butlery/views/settings/widgets/trash_messages.dart';
import 'package:butlery/views/settings/widgets/trash_row.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/butlery_link.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// BUT-907: the trash for deleted recipes. A row opens a sheet to restore or
/// delete that recipe.
class TrashView extends StatefulWidget {
  const TrashView({super.key});

  @override
  State<TrashView> createState() => _TrashViewState();
}

class _TrashViewState extends State<TrashView> {
  late final TrashViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = TrashViewModel()..start();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TrashViewModel>.value(
      value: _vm,
      child: const _TrashContent(),
    );
  }
}

class _TrashContent extends StatelessWidget {
  const _TrashContent();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = context.watch<TrashViewModel>();
    return ButleryPage.undersida(
      title: l10n.trashTitle,
      backTo: l10n.moreTitle,
      body: _body(context, vm),
    );
  }

  Widget _body(BuildContext context, TrashViewModel vm) {
    final l10n = context.l10n;
    if (vm.hasError) {
      return StateWidget.error(
        message: l10n.trashLoadFailed,
        actionLabel: l10n.commonRetry,
        onAction: vm.start,
      );
    }
    if (vm.isLoading) return StateWidget.loading(message: l10n.trashLoading);
    if (vm.isEmpty) {
      return StateWidget.empty(
        title: l10n.trashEmptyTitle,
        subtitle: l10n.trashEmptyBody,
        icon: ButleryIcons.trash2,
      );
    }
    final margin = ButleryTopBar.sideMargin(context);
    return ListView(
      padding: EdgeInsetsDirectional.only(
        start: margin,
        end: margin,
        bottom: AppDimensions.space24,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.space16),
          child: Text(
            l10n.trashIntro(TrashItem.keptFor.inDays),
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          children: [
            _action(
              context,
              l10n.trashRestoreAll,
              ModeColors.of(Theme.of(context).brightness).textLink,
              vm.isWorking ? null : () => _restoreAll(context, vm),
            ),
            _action(
              context,
              l10n.trashEmptyAction,
              Theme.of(context).colorScheme.error,
              vm.isWorking ? null : () => _empty(context, vm),
            ),
          ],
        ),
        ButleryListSection(
          rows: [
            for (final item in vm.items)
              TrashRow(
                key: ValueKey(item.id),
                item: item,
                onTap: () => _openRecipeSheet(context, vm, item),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _openRecipeSheet(
    BuildContext context,
    TrashViewModel vm,
    TrashItem item,
  ) async {
    final l10n = context.l10n;
    final choice = await showButleryListSheet<_RecipeChoice>(
      context,
      title: item.title,
      rows: (sheetContext) => [
        ButleryListRow(
          label: l10n.trashRestoreRecipe,
          leading: ButleryIcons.undo,
          onTap: () => Navigator.of(sheetContext).pop(_RecipeChoice.restore),
        ),
        ButleryListRow.danger(
          label: l10n.trashDeleteConfirmAction,
          onTap: () => Navigator.of(sheetContext).pop(_RecipeChoice.delete),
        ),
      ],
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case _RecipeChoice.restore:
        final result = await vm.restoreOne(item.id);
        if (context.mounted) _announce(context, result);
      case _RecipeChoice.delete:
        await _deleteOne(context, vm, item);
    }
  }

  Future<void> _deleteOne(
    BuildContext context,
    TrashViewModel vm,
    TrashItem item,
  ) async {
    final l10n = context.l10n;
    final confirmed =
        await ConfirmationDialogs.showDestructiveConfirmationDialog(
          context,
          title: l10n.trashDeleteOneTitle(item.title),
          message: l10n.trashDeleteOneBody,
          confirmText: l10n.trashDeleteConfirmAction,
          cancelText: l10n.commonCancel,
        );
    if (!confirmed || !context.mounted) return;
    final result = await vm.deleteOne(item.id);
    if (context.mounted) _announce(context, result);
  }

  Widget _action(
    BuildContext context,
    String label,
    Color color,
    VoidCallback? onTap,
  ) {
    return ButleryLink(
      semanticLabel: label,
      onTap: onTap,
      child: Text(label, style: AppTextStyles.bodyBold.copyWith(color: color)),
    );
  }

  Future<void> _restoreAll(BuildContext context, TrashViewModel vm) async {
    final result = await vm.restoreAll();
    if (context.mounted) _announce(context, result);
  }

  Future<void> _empty(BuildContext context, TrashViewModel vm) async {
    final l10n = context.l10n;
    final confirmed =
        await ConfirmationDialogs.showDestructiveConfirmationDialog(
          context,
          title: l10n.trashEmptyConfirmTitle,
          message: l10n.trashEmptyConfirmBody,
          confirmText: l10n.trashEmptyAction,
          cancelText: l10n.commonCancel,
        );
    if (!confirmed || !context.mounted) return;
    final result = await vm.emptyTrash();
    if (context.mounted) _announce(context, result);
  }

  void _announce(BuildContext context, TrashActionResult? result) {
    if (result == null) return;
    final message = TrashMessages.forResult(context.l10n, result);
    if (result.outcome.isComplete) {
      SnackBarUtils.showSuccess(context, message);
    } else {
      SnackBarUtils.showWarning(context, message, showCloseButton: true);
    }
  }
}

enum _RecipeChoice { restore, delete }
