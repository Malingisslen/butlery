// "Skapa konto" from guest (BUT-920): name, e-mail and password, or a Google or
// Apple account, added to the guest's own account, so everything the guest
// saved stays.
library;

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/brand/provider_button.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/services/account/age_verification_service.dart';
import 'package:butlery/services/auth/auth_provider_flows.dart';
import 'package:butlery/services/auth/guest_auth_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/auth/auth_surface.dart';
import 'package:butlery/widgets/auth/terms_consent_row.dart';
import 'package:butlery/widgets/styled/field_helper_line.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/guest/guest_erasure.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';

class GuestUpgradeView extends StatefulWidget {
  const GuestUpgradeView({super.key});

  static const Key nameKey = ValueKey('guestUpgrade.name');
  static const Key emailKey = ValueKey('guestUpgrade.email');
  static const Key passwordKey = ValueKey('guestUpgrade.password');
  static const Key submitKey = ValueKey('guestUpgrade.submit');
  static const Key signInInsteadKey = ValueKey('guestUpgrade.signInInstead');
  static Key providerKey(SignInProvider provider) =>
      ValueKey('guestUpgrade.provider.${provider.analyticsMethod}');

  @override
  State<GuestUpgradeView> createState() => _GuestUpgradeViewState();
}

class _GuestUpgradeViewState extends State<GuestUpgradeView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AuthService? _auth;
  GuestAuthService? _guestAuth;
  AgeVerificationService? _ageVerification;
  UserService? _userService;

  bool _submitAttempted = false;
  bool _termsAccepted = false;
  bool _passwordVisible = false;
  bool _busy = false;
  bool _emailInUse = false;
  SignInProvider? _providerInUse;
  String? _error;

  // The e-mail is linked but the server has not yet given the account its
  // age claim; the button then only retries that step.
  bool _linked = false;

  // The name the linked provider gave the account, which stands in for the
  // name field.
  String? _providerName;
  bool _linkedWithProvider = false;

  @override
  void initState() {
    super.initState();
    _auth = ServiceLocator.tryGet<AuthService>();
    _guestAuth = ServiceLocator.tryGet<GuestAuthService>();
    _ageVerification = ServiceLocator.tryGet<AgeVerificationService>();
    _userService = ServiceLocator.tryGet<UserService>();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_linked) return _finish();

    if (!_submitAttempted) setState(() => _submitAttempted = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_termsAccepted) {
      SnackBarUtils.showWarning(context, context.l10n.authTermsAcceptRequired);
      return;
    }
    final guestAuth = _guestAuth;
    if (guestAuth == null) {
      setState(() => _error = context.l10n.errorUnexpected);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _emailInUse = false;
      _providerInUse = null;
      _error = null;
    });

    try {
      await guestAuth.upgradeGuest(
        displayName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on GuestUpgradeException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _emailInUse = e.reason == GuestUpgradeFailure.emailInUse;
        _error = _emailInUse ? null : e.message;
      });
      return;
    }
    _linked = true;
    await _finish();
  }

  Future<void> _upgradeWithProvider(SignInProvider provider) async {
    if (_busy) return;
    final guestAuth = _guestAuth;
    if (guestAuth == null) {
      setState(() => _error = context.l10n.errorUnexpected);
      return;
    }
    setState(() {
      _busy = true;
      _emailInUse = false;
      _providerInUse = null;
      _error = null;
    });

    final GuestProviderLink? link;
    try {
      link = await guestAuth.upgradeGuestWithProvider(provider);
    } on GuestUpgradeException catch (e) {
      if (!mounted) return;
      final inUse = e.reason == GuestUpgradeFailure.providerInUse;
      setState(() {
        _busy = false;
        _providerInUse = inUse ? provider : null;
        _error = inUse ? null : e.message;
      });
      return;
    }
    if (link == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    _linked = true;
    _linkedWithProvider = true;
    _providerName = link.displayName;
    await _finish();
  }

  /// The steps after the link: the age claim and the profile name. Only the
  /// claim can stop the screen; the name is best-effort, as at sign-up.
  Future<void> _finish() async {
    if (!_busy) setState(() => _busy = true);
    try {
      await _ageVerification?.finishGuestUpgrade();
    } catch (e) {
      AppLogger.error('Guest upgrade: finishGuestUpgrade failed', e);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = context.l10n.guestUpgradeFinishFailed;
      });
      return;
    }

    final userService = _userService;
    if (userService != null) {
      // The profile reads its e-mail from Auth, which only has one now, and
      // isMinor from the server's age check.
      await userService.retryLoadProfile();
      final isMinor = userService.currentUserProfile?.isMinor ?? true;
      await userService.createOrUpdateProfile(
        displayName: _linkedWithProvider
            ? (_providerName ?? userService.currentUserProfile?.displayName)
                  .orEmpty()
            : _nameController.text.trim(),
        // Searchable from here, as a new adult account is; a guest was not,
        // and a minor never is.
        isSearchable: isMinor ? null : true,
      );
    }

    if (!mounted) return;
    SnackBarUtils.showSuccess(
      context,
      _linkedWithProvider
          ? context.l10n.guestUpgradeDoneProvider
          : context.l10n.guestUpgradeDone,
    );
    Navigator.of(context).pop();
  }

  Future<void> _signInInstead() async {
    final l10n = context.l10n;
    final confirmed = await GuestErasure.confirm(
      context,
      title: l10n.guestSignInInsteadTitle,
      body: l10n.guestSignInInsteadBody,
      confirmLabel: l10n.guestSignInInsteadConfirm,
    );
    if (!confirmed || !mounted) return;
    final erased = await GuestErasure.eraseAndSignOut(
      context,
      reason: 'guest_sign_in_instead',
    );
    if (erased && mounted) {
      // The sign-in screen opens on "Logga in".
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil(Routes.auth, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_busy,
      child: AuthSurface(
        subtitle: l10n.guestUpgradeBody,
        child: Form(
          key: _formKey,
          autovalidateMode: _submitAttempted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._providerButtons(context),
              ..._fields(context),
              const SizedBox(height: AppDimensions.space16),
              TermsConsentRow(
                accepted: _termsAccepted,
                onChanged: _busy || _linked
                    ? null
                    : (value) => setState(() => _termsAccepted = value),
              ),
              const SizedBox(height: AppDimensions.space16),
              if (_emailInUse || _providerInUse != null) ...[
                StateWidget.error(
                  message: _providerInUse != null
                      ? l10n.signInMethodsAlreadyUsed(
                          AuthProviderFlows.providerName(_providerInUse!),
                        )
                      : l10n.errorEmailAlreadyInUse,
                ),
                ButleryTextButton(
                  key: GuestUpgradeView.signInInsteadKey,
                  label: l10n.guestSignInInstead,
                  onPressed: _busy ? null : _signInInstead,
                ),
                const SizedBox(height: AppDimensions.space16),
              ],
              if (_error != null) ...[
                StateWidget.error(message: _error!),
                const SizedBox(height: AppDimensions.space16),
              ],
              HeroButton(
                key: GuestUpgradeView.submitKey,
                label: _linked ? l10n.commonRetry : l10n.guestCreateAccount,
                onPressed: _submit,
                busy: _busy,
                expand: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _providerButtons(BuildContext context) {
    final auth = _auth;
    if (auth == null || _linked) return const [];
    final offered = [
      for (final provider in SignInProvider.values)
        if (auth.isProviderOffered(provider)) provider,
    ];
    if (offered.isEmpty) return const [];
    return [
      for (final provider in offered) ...[
        ProviderButton(
          key: GuestUpgradeView.providerKey(provider),
          provider: provider,
          onPressed: _busy ? null : () => _upgradeWithProvider(provider),
        ),
        const SizedBox(height: AppDimensions.space8 + AppDimensions.space4),
      ],
      const SizedBox(height: AppDimensions.space8),
      ButleryLabelledDivider(label: context.l10n.commonOr),
      const SizedBox(height: AppDimensions.space24),
    ];
  }

  List<Widget> _fields(BuildContext context) {
    final l10n = context.l10n;
    final enabled = !_busy && !_linked;
    return [
      StyledInput(
        key: GuestUpgradeView.nameKey,
        label: l10n.authYourName,
        hint: l10n.guestUpgradeNameHint,
        controller: _nameController,
        enabled: enabled,
        textInputAction: TextInputAction.next,
        validator: FormValidators.authName(),
        autofillHints: const [AutofillHints.name],
      ),
      const SizedBox(height: AppDimensions.space16),
      StyledInput(
        key: GuestUpgradeView.emailKey,
        label: l10n.authEmail,
        hint: l10n.authEmailHint,
        controller: _emailController,
        enabled: enabled,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        validator: FormValidators.authEmail(),
        autofillHints: const [AutofillHints.email],
        onChanged: (_) {
          if (_emailInUse) setState(() => _emailInUse = false);
        },
      ),
      const SizedBox(height: AppDimensions.space16),
      StyledInput(
        key: GuestUpgradeView.passwordKey,
        label: l10n.authPassword,
        hint: l10n.authPasswordChoose,
        controller: _passwordController,
        enabled: enabled,
        obscureText: !_passwordVisible,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        suffixIcon: AppIconButton(
          icon: _passwordVisible ? ButleryIcons.eyeOff : ButleryIcons.eye,
          iconSize: AppDimensions.iconSizeM,
          semanticLabel: _passwordVisible
              ? l10n.a11yHidePassword
              : l10n.a11yShowPassword,
          onPressed: enabled
              ? () => setState(() => _passwordVisible = !_passwordVisible)
              : null,
        ),
        validator: FormValidators.strongPassword(),
        autofillHints: const [AutofillHints.newPassword],
      ),
      FieldHelperLine(l10n.passwordRuleHint),
    ];
  }
}
