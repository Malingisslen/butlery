// lib/views/more/sign_in_method_dialogs.dart
//
// The dialogs Inloggningssätt asks with: a new password, and the question
// before a sign-in method goes (BUT-916 slice B).
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/validators/password_rule.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/widgets/styled/butlery_password_field.dart';

/// Asks for the new password twice. Null when the dialog is closed.
Future<String?> showSetPasswordDialog(
  BuildContext context, {
  required String email,
}) => showDialog<String>(
  context: context,
  builder: (_) => _SetPasswordDialog(email: email),
);

class _SetPasswordDialog extends StatefulWidget {
  const _SetPasswordDialog({required this.email});

  final String email;

  @override
  State<_SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends State<_SetPasswordDialog> {
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    final password = _password.text;
    if (!PasswordRule.accepts(password)) {
      setState(() => _problem = l10n.validationPasswordRule);
    } else if (password != _repeat.text) {
      setState(() => _problem = l10n.accountSecurityPasswordMismatch);
    } else {
      Navigator.pop(context, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.signInMethodsSetPassword),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.signInMethodsSetPasswordBody(widget.email)),
            const SizedBox(height: AppDimensions.space16),
            ButleryPasswordField(
              key: const ValueKey('signInMethods.newPassword'),
              label: l10n.accountSecurityNewPassword,
              controller: _password,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: AppDimensions.space16),
            ButleryPasswordField(
              key: const ValueKey('signInMethods.repeatPassword'),
              label: l10n.accountSecurityConfirmPassword,
              controller: _repeat,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (_problem != null) ...[
              const SizedBox(height: AppDimensions.space8),
              Text(
                _problem!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        const DialogCancelButton(),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.signInMethodsSetPassword),
        ),
      ],
    );
  }
}

/// The shared destructive confirmation (BUT-2366) for taking a method away.
Future<bool> confirmUnlink(
  BuildContext context, {
  required String title,
  required String message,
}) => ConfirmationDialogs.showDestructiveConfirmationDialog(
  context,
  title: title,
  message: message,
  confirmText: context.l10n.signInMethodsUnlink,
);
