import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/auth/password_reset_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/password_reset_viewmodel.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

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
  bool _obscurePassword = true;
  bool _obscureRepeat = true;

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
    return Scaffold(
      appBar: ButleryTopBar.undersida(title: context.l10n.setNewPasswordTitle),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: switch (vm.stage) {
              PasswordResetStage.checking => Center(
                child: PlateLineMessage(
                  message: context.l10n.setNewPasswordChecking,
                ),
              ),
              PasswordResetStage.done => const SizedBox.shrink(),
              PasswordResetStage.checkFailed => InlineError(
                key: const ValueKey('setNewPassword.checkFailed'),
                what: _checkFailedText(context, vm.checkFailure),
                preserved: context.l10n.setNewPasswordNothingChanged,
                actionLabel: context.l10n.commonRetry,
                onAction: vm.retryCheck,
              ),
              PasswordResetStage.linkInvalid => _buildLinkInvalid(context, vm),
              PasswordResetStage.ready => _buildForm(context, vm),
            },
          ),
        ),
      ),
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
        const SizedBox(height: AppDimensions.spacingSm),
        Text(
          context.l10n.setNewPasswordLinkInvalidBody,
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppDimensions.spacingXl),
        // Requesting a link is a signed-out action; someone signed in to
        // another account only leaves.
        if (vm.signedInElsewhere)
          OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(context.l10n.setNewPasswordClose),
          )
        else
          FilledButton(
            key: const ValueKey('setNewPassword.requestNew'),
            onPressed: _requestNewLink,
            child: Text(context.l10n.setNewPasswordRequestNew),
          ),
      ],
    );
  }

  Widget _buildForm(BuildContext context, PasswordResetViewModel vm) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final busy = vm.isLoading;
    return AutofillGroup(
      child: FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.setNewPasswordForAccount(vm.email!),
              key: const ValueKey('setNewPassword.account'),
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            TextField(
              key: const ValueKey('setNewPassword.password'),
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _repeatFocus.requestFocus(),
              decoration: InputDecoration(
                labelText: l.accountSecurityNewPassword,
                border: const OutlineInputBorder(),
                suffixIcon: _visibilityToggle(
                  obscured: _obscurePassword,
                  onToggle: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            TextField(
              key: const ValueKey('setNewPassword.repeat'),
              controller: _repeatController,
              focusNode: _repeatFocus,
              obscureText: _obscureRepeat,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: l.setNewPasswordRepeat,
                border: const OutlineInputBorder(),
                suffixIcon: _visibilityToggle(
                  obscured: _obscureRepeat,
                  onToggle: () =>
                      setState(() => _obscureRepeat = !_obscureRepeat),
                ),
              ),
            ),
            if (vm.error != null) ...[
              const SizedBox(height: AppDimensions.spacingMd),
              InlineError(
                what: vm.error!,
                preserved: l.setNewPasswordNothingChanged,
              ),
            ],
            const SizedBox(height: AppDimensions.spacingL),
            // The plate line along the button's edge while saving, never a
            // spinner (Komponentark v1:365, :372).
            BusyButtonSemantics(
              busy: busy,
              name: l.setNewPasswordSave,
              child: FilledButton(
                key: const ValueKey('setNewPassword.save'),
                onPressed: busy ? PlateLineButton.ignore : _save,
                style: busy
                    ? PlateLineButton.busyStyle(
                        null,
                        Theme.of(context).filledButtonTheme.style,
                      )
                    : null,
                child: Text(l.setNewPasswordSave),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visibilityToggle({
    required bool obscured,
    required VoidCallback onToggle,
  }) {
    return IconButton(
      icon: ButleryIcon(obscured ? ButleryIcons.eye : ButleryIcons.eyeOff),
      tooltip: obscured
          ? context.l10n.tooltipShowPassword
          : context.l10n.tooltipHidePassword,
      onPressed: onToggle,
    );
  }
}
