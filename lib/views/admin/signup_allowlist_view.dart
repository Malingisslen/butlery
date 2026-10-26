import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/admin/signup_invite.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/signup_allowlist_viewmodel.dart';
import 'package:butlery/views/admin/widgets/admin_tab_header.dart';
import 'package:butlery/widgets/admin/admin_table.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/input/styled_input.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Admin-only "Gästlista" tab (BUT-2452): the addresses that may create an
/// account while the guest-list gate is on.
class SignupAllowlistView extends StatefulWidget {
  const SignupAllowlistView({super.key, this.viewModel});

  /// Injected by tests; the tab builds its own otherwise.
  final SignupAllowlistViewModel? viewModel;

  @override
  State<SignupAllowlistView> createState() => _SignupAllowlistViewState();
}

class _SignupAllowlistViewState extends State<SignupAllowlistView> {
  late final SignupAllowlistViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = widget.viewModel ?? SignupAllowlistViewModel();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SignupAllowlistViewModel>.value(
      value: _vm,
      child: const _GuestListContent(),
    );
  }
}

class _GuestListContent extends StatelessWidget {
  const _GuestListContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SignupAllowlistViewModel>();
    return AdminTabPage(
      title: context.l10n.adminGuestListTitle,
      actions: [
        AppIconButton(
          icon: ButleryIcons.refreshCw,
          semanticLabel: context.l10n.adminRefresh,
          onPressed: vm.isLoading ? null : vm.refresh,
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.space16),
        children: [
          const _InviteForm(),
          const SizedBox(height: AppDimensions.space24),
          _list(context, vm),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, SignupAllowlistViewModel vm) {
    final l10n = context.l10n;
    if (vm.isLoading && vm.invites.isEmpty) {
      return StateWidget.loading(message: l10n.adminGuestListLoading);
    }
    if (vm.error != null && vm.invites.isEmpty) {
      return StateWidget.error(message: vm.error!, onAction: vm.refresh);
    }
    if (vm.invites.isEmpty) {
      return StateWidget.empty(
        title: l10n.adminGuestListEmpty,
        icon: ButleryIcons.userPlus,
      );
    }
    final cs = Theme.of(context).colorScheme;
    final now = clock.now();
    return AdminTable(
      columns: [
        AdminTableColumn(label: l10n.adminGuestListColEmail, flex: 5),
        AdminTableColumn(label: l10n.adminGuestListColInvited, flex: 3),
        const AdminTableColumn(label: '', flex: 2, alignEnd: true),
      ],
      rows: [
        for (final invite in vm.invites)
          AdminTableRow(
            cells: [invite.email, _invitedLabel(context, invite, now), ''],
            cellColors: invite.isExpiredAt(now)
                ? [cs.onSurfaceVariant, cs.onSurfaceVariant, null]
                : null,
            cellWidgets: [
              null,
              null,
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: ActionButtons.textButton(
                  context,
                  label: l10n.adminGuestListRemove,
                  onPressed: vm.isSubmitting
                      ? null
                      : () => _confirmRemove(context, vm, invite.email),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    SignupAllowlistViewModel vm,
    String email,
  ) async {
    final l10n = context.l10n;
    final confirmed =
        await ConfirmationDialogs.showDestructiveConfirmationDialog(
          context,
          title: l10n.adminGuestListRemoveTitle,
          message: l10n.adminGuestListRemoveMessage(email),
          confirmText: l10n.adminGuestListRemove,
        );
    if (confirmed) await vm.remove(email);
  }
}

/// Day and month of the invite; an expired one says so, since it stays listed
/// until the TTL removes it.
String _invitedLabel(BuildContext context, SignupInvite invite, DateTime now) {
  final d = invite.invitedAt;
  final date = d == null ? '—' : '${d.day}/${d.month}';
  return invite.isExpiredAt(now)
      ? '$date · ${context.l10n.adminGuestListExpired}'
      : date;
}

class _InviteForm extends StatefulWidget {
  const _InviteForm();

  @override
  State<_InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends State<_InviteForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(SignupAllowlistViewModel vm) async {
    if (vm.isSubmitting) return;
    final ok = await vm.invite(_controller.text);
    if (ok && mounted) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SignupAllowlistViewModel>();
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StyledInput(
          controller: _controller,
          label: l10n.adminGuestListEmailLabel,
          errorText: vm.actionError,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          onSubmitted: (_) => _submit(vm),
        ),
        const SizedBox(height: AppDimensions.space8),
        Text(
          l10n.adminGuestListHelp,
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimensions.space12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ActionButtons.primaryButton(
            context,
            label: l10n.adminGuestListInvite,
            icon: ButleryIcons.userPlus,
            isLoading: vm.isSubmitting,
            onPressed: vm.isSubmitting ? null : () => _submit(vm),
          ),
        ),
      ],
    );
  }
}
