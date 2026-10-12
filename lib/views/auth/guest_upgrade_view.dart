// "Skapa konto" from guest (BUT-920): name, e-mail and password added to the
// guest's own account, so everything the guest saved stays.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/services/account/age_verification_service.dart';
import 'package:butlery/services/auth/guest_auth_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/field_text_style.dart';
import 'package:butlery/widgets/styled/field_error_line.dart';
import 'package:butlery/widgets/styled/labeled_field.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/guest/guest_erasure.dart';

class GuestUpgradeView extends StatefulWidget {
  const GuestUpgradeView({super.key});

  static const Key nameKey = ValueKey('guestUpgrade.name');
  static const Key emailKey = ValueKey('guestUpgrade.email');
  static const Key passwordKey = ValueKey('guestUpgrade.password');
  static const Key submitKey = ValueKey('guestUpgrade.submit');
  static const Key signInInsteadKey = ValueKey('guestUpgrade.signInInstead');

  @override
  State<GuestUpgradeView> createState() => _GuestUpgradeViewState();
}

class _GuestUpgradeViewState extends State<GuestUpgradeView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  GuestAuthService? _guestAuth;
  AgeVerificationService? _ageVerification;
  UserService? _userService;

  bool _submitAttempted = false;
  bool _passwordVisible = false;
  bool _busy = false;
  bool _emailInUse = false;
  String? _error;

  // The e-mail is linked but the server has not yet given the account its
  // age claim; the button then only retries that step.
  bool _linked = false;

  @override
  void initState() {
    super.initState();
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
    final guestAuth = _guestAuth;
    if (guestAuth == null) {
      setState(() => _error = context.l10n.errorUnexpected);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _emailInUse = false;
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
        displayName: _nameController.text.trim(),
        // Searchable from here, as a new adult account is; a guest was not,
        // and a minor never is.
        isSearchable: isMinor ? null : true,
      );
    }

    if (!mounted) return;
    SnackBarUtils.showSuccess(context, context.l10n.guestUpgradeDone);
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
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: ButleryPage.undersida(
        title: l10n.guestCreateAccount,
        width: PageWidth.compact,
        showTabBar: false,
        body: Form(
          key: _formKey,
          autovalidateMode: _submitAttempted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: AutofillGroup(
            child: ListView(
              padding: ButleryPageBody.margin(
                context,
                top: AppDimensions.space24,
                bottom: AppDimensions.space24,
              ),
              children: [
                Text(
                  l10n.guestUpgradeBody,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimensions.space32),
                ..._fields(context),
                const SizedBox(height: AppDimensions.space24),
                if (_emailInUse) ...[
                  StateWidget.error(message: l10n.errorEmailAlreadyInUse),
                  TextButton(
                    key: GuestUpgradeView.signInInsteadKey,
                    onPressed: _busy ? null : _signInInstead,
                    child: Text(l10n.guestSignInInstead),
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
      ),
    );
  }

  List<Widget> _fields(BuildContext context) {
    final l10n = context.l10n;
    final enabled = !_busy && !_linked;
    return [
      LabeledField(
        label: l10n.authYourName,
        child: TextFormField(
          key: GuestUpgradeView.nameKey,
          style: fieldTextStyle(context, enabled: enabled),
          controller: _nameController,
          enabled: enabled,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: l10n.authEnterYourName,
          ),
          errorBuilder: FieldErrorLine.builder,
          validator: FormValidators.authName(),
          autofillHints: const [AutofillHints.name],
        ),
      ),
      const SizedBox(height: AppDimensions.space16),
      LabeledField(
        label: l10n.authEmail,
        child: TextFormField(
          key: GuestUpgradeView.emailKey,
          style: fieldTextStyle(context, enabled: enabled),
          controller: _emailController,
          enabled: enabled,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(hintText: l10n.authEmailHint),
          errorBuilder: FieldErrorLine.builder,
          validator: FormValidators.authEmail(),
          autofillHints: const [AutofillHints.email],
          onChanged: (_) {
            if (_emailInUse) setState(() => _emailInUse = false);
          },
        ),
      ),
      const SizedBox(height: AppDimensions.space16),
      LabeledField(
        label: l10n.authPassword,
        child: TextFormField(
          key: GuestUpgradeView.passwordKey,
          style: fieldTextStyle(context, enabled: enabled),
          controller: _passwordController,
          enabled: enabled,
          obscureText: !_passwordVisible,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: l10n.authPasswordMinLength,
            suffixIcon: IconButton(
              icon: ButleryIcon(
                _passwordVisible ? ButleryIcons.eyeOff : ButleryIcons.eye,
                size: AppDimensions.iconSizeM,
              ),
              onPressed: enabled
                  ? () => setState(() => _passwordVisible = !_passwordVisible)
                  : null,
              tooltip: _passwordVisible
                  ? l10n.a11yHidePassword
                  : l10n.a11yShowPassword,
            ),
          ),
          errorBuilder: FieldErrorLine.builder,
          validator: FormValidators.strongPassword(),
          autofillHints: const [AutofillHints.password],
        ),
      ),
    ];
  }
}
