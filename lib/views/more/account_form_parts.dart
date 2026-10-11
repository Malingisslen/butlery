// lib/views/more/account_form_parts.dart
//
// What the E-postadress and Lösenord pages under Konto & säkerhet are built
// from, so both forms draw the same password field and the same button.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/account_security_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/styled/labeled_field.dart';

/// A password field with its label above the box and a show/hide button.
class AccountPasswordField extends StatefulWidget {
  const AccountPasswordField({
    required this.label,
    required this.controller,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;

  @override
  State<AccountPasswordField> createState() => _AccountPasswordFieldState();
}

class _AccountPasswordFieldState extends State<AccountPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: widget.label,
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        obscureText: _obscured,
        autofillHints: widget.autofillHints,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          suffixIcon: IconButton(
            icon: ButleryIcon(
              _obscured ? ButleryIcons.eye : ButleryIcons.eyeOff,
            ),
            tooltip: _obscured
                ? context.l10n.tooltipShowPassword
                : context.l10n.tooltipHidePassword,
            onPressed: () => setState(() => _obscured = !_obscured),
          ),
        ),
      ),
    );
  }
}

/// The form's one primary button, last on the page. While the view model
/// works it keeps its name and gets the plate line along its bottom edge,
/// never a spinner (Komponentark v1:365, :372); busy is not disabled, it
/// ignores presses instead (PlateLineButton.ignore).
class AccountFormButton extends StatelessWidget {
  const AccountFormButton({
    required this.label,
    required this.busy,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.spacingL),
      child: BusyButtonSemantics(
        busy: busy,
        name: label,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: busy ? PlateLineButton.ignore : onPressed,
            style: busy
                ? PlateLineButton.busyStyle(
                    null,
                    Theme.of(context).filledButtonTheme.style,
                  )
                : null,
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

/// A failed change is the failure snackbar, never OK. A failure without a known cause offers Försök igen, which runs
/// the change again with the fields as they are; a named cause or a form
/// error gets Stäng (AccountSecurityViewModel.canRetry).
void showAccountChangeFailure(
  BuildContext context,
  AccountSecurityViewModel viewModel, {
  required Future<void> Function() onRetry,
}) {
  SnackBarUtils.showFailure(
    context,
    what: viewModel.error!,
    action: viewModel.canRetry ? FailureAction.retry(onRetry) : null,
  );
}
