import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/widgets/styled/butlery_password_field.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/auth/password_reset_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/password_reset_viewmodel.dart';
import 'package:butlery/widgets/auth/auth_surface.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/widgets/styled/field_helper_line.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

/// "Välj nytt lösenord", opened by the link in the "glömt lösenord" mail
/// (BUT-2170; flow 06 `återställ → sätt nytt`). The two fields follow the
/// Kontosäkerhet password fields in Skarmar v12 etapp 6.
class SetNewPasswordView extends StatefulWidget {
  const SetNewPasswordView({super.key, required this.code});

  /// Firebase's one-time action code from the link.
  final String code;

  @override
  State<SetNewPasswordView> createState() => _SetNewPasswordViewState();
}

class _SetNewPasswordViewState extends State<SetNewPasswordView> {
  late final PasswordResetViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ServiceLocator.get<PasswordResetViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _vm.start(widget.code);
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PasswordResetViewModel>.value(
      value: _vm,
      child: const _SetNewPasswordContent(),
    );
  }
}

class _SetNewPasswordContent extends StatefulWidget {
  const _SetNewPasswordContent();

  @override
  State<_SetNewPasswordContent> createState() => _SetNewPasswordContentState();
}

class _SetNewPasswordContentState extends State<_SetNewPasswordContent> {
  final _passwordController = TextEditingController();
  final _repeatController = TextEditingController();
  final _repeatFocus = FocusNode();

  @override
  void dispose() {
    _passwordController.dispose();
    _repeatController.dispose();
    _repeatFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final vm = context.read<PasswordResetViewModel>();
    final saved = await vm.save(
      newPassword: _passwordController.text,
      repeated: _repeatController.text,
    );
    if (!saved || !mounted) return;
    final navigator = Navigator.of(context);
    if (vm.signedInElsewhere) {
      SnackBarUtils.showSuccess(
        context,
        context.l10n.setNewPasswordSavedOther(vm.email!),
      );
      navigator.pop();
      return;
    }
    navigator.pushNamedAndRemoveUntil(Routes.auth, (_) => false);
  }

  void _requestNewLink() {
    context.read<PasswordResetViewModel>().requestNewLink();
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.auth, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PasswordResetViewModel>();
    final l = context.l10n;
    final ready = vm.stage == PasswordResetStage.ready;
    return AuthSurface(
      subtitle: ready
          ? l.setNewPasswordForAccount(vm.email!)
          : l.setNewPasswordTitle,
      child: switch (vm.stage) {
        PasswordResetStage.checking => Center(
          child: PlateLineMessage(message: l.setNewPasswordChecking),
        ),
        PasswordResetStage.done => const SizedBox.shrink(),
        PasswordResetStage.checkFailed => InlineError(
          key: const ValueKey('setNewPassword.checkFailed'),
          what: _checkFailedText(context, vm.checkFailure),
          preserved: l.setNewPasswordNothingChanged,
          actionLabel: l.commonRetry,
          onAction: vm.retryCheck,
        ),
        PasswordResetStage.linkInvalid => _buildLinkInvalid(context, vm),
        PasswordResetStage.ready => _buildForm(context, vm),
      },
    );
  }

  String _checkFailedText(BuildContext context, PasswordResetFailure? why) {
    final l = context.l10n;
    final cause = switch (why) {
      PasswordResetFailure.network => l.errorNetwork,
      PasswordResetFailure.tooManyAttempts => l.errorTooManyAttempts,
      _ => null,
    };
    return cause == null
        ? l.setNewPasswordCheckFailed
        : '${l.setNewPasswordCheckFailed} $cause';
  }

  Widget _buildLinkInvalid(BuildContext context, PasswordResetViewModel vm) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('setNewPassword.linkInvalid'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.setNewPasswordLinkInvalidTitle,
          style: tt.titleLarge,
        ),
        const SizedBox(height: AppDimensions.space8),
        Text(
          context.l10n.setNewPasswordLinkInvalidBody,
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppDimensions.space32),
        // Requesting a link is a signed-out action; someone signed in to
        // another account only leaves.
        if (vm.signedInElsewhere)
          ActionButtons.outlinedButton(
            context,
            label: context.l10n.setNewPasswordClose,
            onPressed: () => Navigator.of(context).maybePop(),
            isExpanded: true,
          )
        else
          HeroButton(
            key: const ValueKey('setNewPassword.requestNew'),
            label: context.l10n.setNewPasswordRequestNew,
            onPressed: _requestNewLink,
            expand: true,
          ),
      ],
    );
  }

  Widget _buildForm(BuildContext context, PasswordResetViewModel vm) {
    final l = context.l10n;
    final busy = vm.isLoading;
    return AutofillGroup(
      child: FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ButleryPasswordField(
              fieldKey: const ValueKey('setNewPassword.password'),
              label: l.accountSecurityNewPassword,
              controller: _passwordController,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _repeatFocus.requestFocus(),
            ),
            FieldHelperLine(l.passwordRuleHint),
            const SizedBox(height: AppDimensions.space16),
            ListenableBuilder(
              listenable: Listenable.merge([
                _passwordController,
                _repeatController,
              ]),
              builder: (context, _) => ButleryPasswordField(
                fieldKey: const ValueKey('setNewPassword.repeat'),
                label: l.setNewPasswordRepeat,
                controller: _repeatController,
                focusNode: _repeatFocus,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                validText:
                    ButleryPasswordField.matches(
                      _passwordController.text,
                      _repeatController.text,
                    )
                    ? l.passwordsMatch
                    : null,
              ),
            ),
            if (vm.error != null) ...[
              const SizedBox(height: AppDimensions.space16),
              InlineError(
                what: vm.error!,
                preserved: l.setNewPasswordNothingChanged,
              ),
            ],
            const SizedBox(height: AppDimensions.space16),
            HeroButton(
              key: const ValueKey('setNewPassword.save'),
              label: l.setNewPasswordSave,
              onPressed: _save,
              busy: busy,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}
