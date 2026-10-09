import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/trash_viewmodel.dart';
import 'package:butlery/views/settings/widgets/trash_footer.dart';
import 'package:butlery/views/settings/widgets/trash_messages.dart';
import 'package:butlery/views/settings/widgets/trash_row.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// BUT-907: the trash for deleted recipes. Rows are marked, then restored or
/// deleted for good; with nothing marked the footer empties the whole trash.
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
    final showList = !vm.isLoading && !vm.hasError && !vm.isEmpty;
    return BaseScaffold(
      title: l10n.trashTitle,
      actions: [
        if (showList)
          ActionButtons.textButton(
            context,
            label: vm.allSelected ? l10n.trashSelectNone : l10n.trashSelectAll,
            onPressed: vm.isWorking ? null : vm.toggleAll,
          ),
      ],
      body: _body(context, vm),
      bottomNavigationBar: showList
          ? TrashFooter(
              selectedCount: vm.selectedCount,
              busy: vm.isWorking,
              onRestore: () => _restore(context, vm),
              onDelete: () => _delete(context, vm),
              onEmpty: () => _empty(context, vm),
            )
          : null,
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
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingSm),
      itemCount: vm.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final item = vm.items[i];
        return TrashRow(
          key: ValueKey(item.id),
          item: item,
          selected: vm.isSelected(item.id),
          onToggle: () => vm.toggle(item.id),
        );
      },
    );
  }

  Future<void> _restore(BuildContext context, TrashViewModel vm) async {
    final result = await vm.restoreSelected();
    if (result != null && context.mounted) _announce(context, result);
  }

  Future<void> _delete(BuildContext context, TrashViewModel vm) async {
    final l10n = context.l10n;
    final confirmed =
        await ConfirmationDialogs.showDestructiveConfirmationDialog(
          context,
          title: l10n.trashDeleteConfirmTitle,
          message: l10n.trashDeleteConfirmBody(vm.selectedCount),
          confirmText: l10n.trashDeleteConfirmAction,
          cancelText: l10n.commonCancel,
        );
    if (!confirmed || !context.mounted) return;
    final result = await vm.deleteSelected();
    if (result != null && context.mounted) _announce(context, result);
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
    if (result != null && context.mounted) _announce(context, result);
  }

  void _announce(BuildContext context, TrashActionResult result) {
    final message = TrashMessages.forResult(context.l10n, result);
    if (result.outcome.isComplete) {
      SnackBarUtils.showSuccess(context, message);
    } else {
      SnackBarUtils.showWarning(context, message, showCloseButton: true);
    }
  }
}
