// lib/views/more/account_email_view.dart
//
// E-postadress under Konto & säkerhet: the address the account signs in
// with, and the form that changes it.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/account_security_viewmodel.dart';
import 'package:butlery/views/more/account_form_parts.dart';
import 'package:butlery/views/more/more_area_scaffold.dart';
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

  @override
  void dispose() {
    _passwordController.dispose();
    _newEmailController.dispose();
    _newEmailFocus.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    final success = await _viewModel.changeEmail(
      currentPassword: _passwordController.text,
      newEmail: _newEmailController.text,
    );

    if (!mounted) return;
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
      showAccountChangeFailure(context, _viewModel, onRetry: _change);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = AppTextStyles.bodyMedium.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final currentEmail = _viewModel.currentEmail;
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
                const SizedBox(height: AppDimensions.spacingMd),
                if (currentEmail != null)
                  Text(
                    currentEmail,
                    key: const ValueKey('accountEmail.current'),
                    style: AppTextStyles.bodyLarge,
                  ),
                const SizedBox(height: AppDimensions.spacingSm),
                // BUT-2171 = A: Firebase's verifyBeforeUpdateEmail confirms
                // only the new address; the old one is told afterwards and
                // can undo. The user reads that before asking for the
                // change, not in a two-line snackbar.
                Text(
                  l10n.accountSecurityEmailChangeHow,
                  key: const ValueKey('accountEmail.changeHow'),
                  style: muted,
                ),
                const SizedBox(height: AppDimensions.spacingL),
                ButleryPasswordField(
                  key: const ValueKey('accountEmail.password'),
                  label: l10n.accountSecurityCurrentPassword,
                  controller: _passwordController,
                  onSubmitted: (_) => _newEmailFocus.requestFocus(),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                LabeledField(
                  label: l10n.accountSecurityNewEmail,
                  child: TextField(
                    key: const ValueKey('accountEmail.newEmail'),
                    controller: _newEmailController,
                    focusNode: _newEmailFocus,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _change(),
                  ),
                ),
                AccountFormButton(
                  label: l10n.accountSecurityChangeEmail,
                  busy: _viewModel.isLoading,
                  onPressed: _change,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
