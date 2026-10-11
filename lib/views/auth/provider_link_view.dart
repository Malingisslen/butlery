import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/theme/field_text_style.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/auth/auth_provider_flows.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/auth/provider_link_viewmodel.dart';
import 'package:butlery/views/auth/mfa_challenge_view.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/styled/field_error_line.dart';
import 'package:butlery/widgets/styled/labeled_field.dart';

/// "Koppla ihop" (BUT-916 mockup screen 3): a Google/Apple sign-in found a
/// password account at the same verified address. The password is asked for
/// once; the view pops with how the sign-in ended, or null when left.
class ProviderLinkView extends StatefulWidget {
  const ProviderLinkView({super.key, this.viewModel});

  @visibleForTesting
  final ProviderLinkViewModel? viewModel;

  @override
  State<ProviderLinkView> createState() => _ProviderLinkViewState();
}

class _ProviderLinkViewState extends State<ProviderLinkView> {
  late final ProviderLinkViewModel _vm =
      widget.viewModel ?? ProviderLinkViewModel();

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: _vm,
    child: const _ProviderLinkContent(),
  );
}

class _ProviderLinkContent extends StatefulWidget {
  const _ProviderLinkContent();

  @override
  State<_ProviderLinkContent> createState() => _ProviderLinkContentState();
}

class _ProviderLinkContentState extends State<_ProviderLinkContent> {
  final _password = TextEditingController();
  bool _obscure = true;
  bool _finished = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _leave(MfaChallengeResult? result) {
    _finished = true;
    Navigator.of(context).pop(result);
  }

  Future<void> _submit(ProviderLinkViewModel vm) async {
    final link = vm.pending;
    if (link == null) return;
    final password = _password.text;
    if (await vm.submit(password)) {
      if (mounted) _leave(MfaChallengeResult.signedIn);
      return;
    }
    final challenge = vm.pendingMfaChallenge;
    if (challenge == null || !mounted) return;
    final result = await Navigator.of(context).push<MfaChallengeResult>(
      MaterialPageRoute(
        builder: (_) => MfaChallengeView(
          challenge: challenge,
          email: link.email,
          password: password,
        ),
      ),
    );
    if (result != null && mounted) _leave(result);
  }

  Future<void> _forgot(ProviderLinkViewModel vm) async {
    final sent = await vm.sendPasswordReset();
    if (!mounted) return;
    if (sent) {
      SnackBarUtils.showSuccess(context, context.l10n.authResetEmailSent);
    } else {
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.authResetEmailFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProviderLinkViewModel>();
    final link = vm.pending;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_finished) vm.cancel();
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: ButleryPageBody(
            width: PageWidth.compact,
            child: SingleChildScrollView(
              padding: ButleryPageBody.margin(
                context,
                top: AppDimensions.space32,
                bottom: AppDimensions.space24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.providerLinkTitle,
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  if (link != null)
                    Text(
                      l10n.providerLinkBody(
                        link.email,
                        AuthProviderFlows.providerName(link.provider),
                      ),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  const SizedBox(height: AppDimensions.space24),
                  LabeledField(
                    label: l10n.authPassword,
                    child: TextField(
                      key: const ValueKey('providerLink.password'),
                      controller: _password,
                      obscureText: _obscure,
                      style: fieldTextStyle(
                        context,
                        enabled: !vm.isLoading && link != null,
                      ),
                      enabled: !vm.isLoading && link != null,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(vm),
                      decoration: InputDecoration(
                        error: vm.error == null
                            ? null
                            : FieldErrorLine(vm.error!),
                        suffixIcon: IconButton(
                          tooltip: _obscure
                              ? l10n.a11yShowPassword
                              : l10n.a11yHidePassword,
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: ButleryIcon(
                            _obscure ? ButleryIcons.eye : ButleryIcons.eyeOff,
                            size: AppDimensions.iconSizeM,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space24),
                  HeroButton(
                    key: const ValueKey('providerLink.submit'),
                    label: l10n.providerLinkSubmit,
                    onPressed: link == null || vm.isLoading
                        ? null
                        : () => _submit(vm),
                    busy: vm.isLoading,
                    expand: true,
                  ),
                  const SizedBox(height: AppDimensions.space8),
                  TextButton(
                    onPressed: vm.isLoading ? null : () => _forgot(vm),
                    child: Text(l10n.authForgotPassword),
                  ),
                  DialogCancelButton(
                    key: const ValueKey('providerLink.cancel'),
                    enabled: !vm.isLoading,
                    onPressed: () {
                      vm.cancel();
                      _leave(null);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
