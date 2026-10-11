// lib/views/more/account_password_view.dart
//
// Lösenord under Konto & säkerhet: change the password with the current one.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/account_security_viewmodel.dart';
import 'package:butlery/views/more/account_form_parts.dart';
import 'package:butlery/views/more/more_area_scaffold.dart';
import 'package:butlery/widgets/styled/butlery_password_field.dart';

class AccountPasswordView extends StatefulWidget {
  const AccountPasswordView({super.key});

  @override
  State<AccountPasswordView> createState() => _AccountPasswordViewState();
}

class _AccountPasswordViewState extends State<AccountPasswordView> {
  final _viewModel = AccountSecurityViewModel();

  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    final success = await _viewModel.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
      confirmPassword: _confirmController.text,
    );

    if (!mounted) return;
    // A failure stays until tapped; the new outcome replaces it rather
    // than queueing behind it.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (success) {
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
      SnackBarUtils.showSuccess(
        context,
        context.l10n.accountSecurityPasswordChanged,
      );
    } else if (_viewModel.error != null) {
      showAccountChangeFailure(context, _viewModel, onRetry: _change);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MoreAreaScaffold.backTo(
      l10n.settingsAccountAreaTitle,
      title: l10n.settingsAccountPassword,
      sections: [
        ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => FocusTraversalGroup(
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppDimensions.spacingMd),
                  ButleryPasswordField(
                    key: const ValueKey('accountPassword.current'),
                    label: l10n.accountSecurityCurrentPassword,
                    controller: _currentController,
                    onSubmitted: (_) => _newFocus.requestFocus(),
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  ButleryPasswordField(
                    key: const ValueKey('accountPassword.new'),
                    label: l10n.accountSecurityNewPassword,
                    controller: _newController,
                    focusNode: _newFocus,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: (_) => _confirmFocus.requestFocus(),
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      _newController,
                      _confirmController,
                    ]),
                    builder: (context, _) => ButleryPasswordField(
                      key: const ValueKey('accountPassword.confirm'),
                      label: l10n.accountSecurityConfirmPassword,
                      controller: _confirmController,
                      focusNode: _confirmFocus,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _change(),
                      validText:
                          ButleryPasswordField.matches(
                            _newController.text,
                            _confirmController.text,
                          )
                          ? l10n.passwordsMatch
                          : null,
                    ),
                  ),
                  AccountFormButton(
                    label: l10n.accountSecurityChangePassword,
                    busy: _viewModel.isLoading,
                    onPressed: _change,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
