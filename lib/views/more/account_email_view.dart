// lib/views/more/account_email_view.dart
//
// E-postadress under Konto & säkerhet: the address the account signs in
// with, and the form that changes it.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/account_security_viewmodel.dart';
import 'package:butlery/views/more/account_form_parts.dart';
import 'package:butlery/views/more/more_area_scaffold.dart';
import 'package:butlery/widgets/common/profile/handlers/auth_action_handler.dart';
import 'package:butlery/widgets/styled/butlery_password_field.dart';
import 'package:butlery/widgets/styled/labeled_field.dart';

class AccountEmailView extends StatefulWidget {
  const AccountEmailView({super.key});

  @override
  State<AccountEmailView> createState() => _AccountEmailViewState();
}

class _AccountEmailViewState extends State<AccountEmailView> {
  final _viewModel = AccountSecurityViewModel();

  final _passwordController = TextEditingController();
  final _newEmailController = TextEditingController();

  final _newEmailFocus = FocusNode();

  /// Set from the first tap until the change has ended, so a second tap
  /// while a sign-in sheet or the second factor is open starts nothing.
  bool _working = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _newEmailController.dispose();
    _newEmailFocus.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await _change();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _change({bool reauthenticated = false}) async {
    final vm = _viewModel;
    final confirmation = vm.emailChangeConfirmation;
    if (confirmation == EmailChangeConfirmation.unavailable) return;
    var confirmed = reauthenticated;
    // Without a password the change is confirmed through Google or Apple,
    // after the address itself has passed the form's check (C7).
    if (confirmation == EmailChangeConfirmation.provider && !confirmed) {
      final problem = vm.newEmailProblem(_newEmailController.text);
      if (problem != null) {
        SnackBarUtils.showFailure(context, what: problem);
        return;
      }
      String? reauthError;
      confirmed = await AuthActionHandler.reauthenticate(
        context,
        onError: (message) => reauthError = message,
      );
      if (!mounted) return;
      if (!confirmed) {
        if (reauthError != null) {
          SnackBarUtils.showFailure(context, what: reauthError!);
        }
        return;
      }
    }
    final success = await vm.changeEmail(
      currentPassword: confirmation == EmailChangeConfirmation.password
          ? _passwordController.text
          : null,
      newEmail: _newEmailController.text,
      reauthenticated: confirmed,
    );

    if (!mounted) return;
    if (!success && vm.pendingSecondFactor != null) {
      if (await confirmSecondFactor(context, vm) && mounted) {
        await _change(reauthenticated: true);
      }
      return;
    }
    // A failure stays until tapped; the new outcome replaces it rather
    // than queueing behind it.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (success) {
      _passwordController.clear();
      _newEmailController.clear();
      SnackBarUtils.showSuccess(
        context,
        context.l10n.accountSecurityEmailVerificationSent,
      );
    } else if (_viewModel.error != null) {
      showAccountChangeFailure(context, _viewModel, onRetry: _submit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = AppTextStyles.bodyMedium.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final currentEmail = _viewModel.currentEmail;
    final confirmation = _viewModel.emailChangeConfirmation;
    return MoreAreaScaffold.backTo(
      l10n.settingsAccountAreaTitle,
      title: l10n.settingsAccountEmail,
      sections: [
        ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => FocusTraversalGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimensions.space16),
                if (currentEmail != null)
                  Text(
                    currentEmail,
                    key: const ValueKey('accountEmail.current'),
                    style: AppTextStyles.bodyLarge,
                  ),
                const SizedBox(height: AppDimensions.space8),
                // BUT-2171 = A: Firebase's verifyBeforeUpdateEmail confirms
                // only the new address; the old one is told afterwards and
                // can undo. The user reads that before asking for the
                // change, not in a two-line snackbar.
                Text(
                  l10n.accountSecurityEmailChangeHow,
                  key: const ValueKey('accountEmail.changeHow'),
                  style: muted,
                ),
                const SizedBox(height: AppDimensions.space12),
                switch (confirmation) {
                  EmailChangeConfirmation.password => ButleryPasswordField(
                    key: const ValueKey('accountEmail.password'),
                    label: l10n.accountSecurityCurrentPassword,
                    controller: _passwordController,
                    onSubmitted: (_) => _newEmailFocus.requestFocus(),
                  ),
                  EmailChangeConfirmation.provider => Text(
                    l10n.accountSecurityEmailProviderReauth(
                      _viewModel.reauthProviderName.orEmpty(),
                    ),
                    key: const ValueKey('accountEmail.providerReauth'),
                    style: muted,
                  ),
                  EmailChangeConfirmation.unavailable => Text(
                    l10n.accountSecurityEmailCannotConfirmHere,
                    key: const ValueKey('accountEmail.cannotConfirmHere'),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                },
                const SizedBox(height: AppDimensions.space16),
                LabeledField(
                  label: l10n.accountSecurityNewEmail,
                  child: TextField(
                    key: const ValueKey('accountEmail.newEmail'),
                    controller: _newEmailController,
                    focusNode: _newEmailFocus,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                AccountFormButton(
                  label: l10n.accountSecurityChangeEmail,
                  busy: _viewModel.isLoading || _working,
                  onPressed: confirmation == EmailChangeConfirmation.unavailable
                      ? null
                      : _submit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
