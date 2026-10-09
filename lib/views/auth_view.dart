// lib/views/auth_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/brand/butlery_lockup.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/session_timeout_service.dart';
import 'package:butlery/views/auth/mfa_challenge_view.dart';
import 'package:butlery/views/auth/password_reset_done_notice.dart';
import 'package:butlery/services/auth/password_reset_service.dart';
import 'package:butlery/app/auth/auth_wrapper.dart';
import 'package:butlery/theme/field_text_style.dart';
import 'package:butlery/widgets/common/butlery_link.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  /// The screen a user is sent to after a successful LOGIN.
  /// Overridable in tests so the post-login navigation can be asserted without
  /// inflating the entire main-menu service graph. Defaults to AuthWrapper, so
  /// an account that never verified its e-mail or finished onboarding (and with
  /// it the age check) meets those gates on login too, not only on cold start.
  @visibleForTesting
  static WidgetBuilder postLoginDestinationBuilder = (context) =>
      const AuthWrapper();

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _nameFocus = FocusNode();
  bool _termsAccepted = false;

  // After the first submit an error follows the field as the user types,
  // instead of standing until the next press of the button.
  bool _submitAttempted = false;
  late final AuthViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<AuthViewModel>();
    _takePasswordResetHandoff();
  }

  /// After "Välj nytt lösenord" (BUT-2170): a saved password lands here with
  /// the address filled in and a receipt; a dead link opens "Glömt
  /// lösenord" so a new one can be sent.
  void _takePasswordResetHandoff() {
    switch (PasswordResetHandoff.pending) {
      case PasswordResetDone(:final email):
        _emailController.text = email;
      case PasswordResetRequestNewLink():
        PasswordResetHandoff.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showPasswordResetDialog(context, _viewModel);
        });
      case null:
        break;
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: Consumer<AuthViewModel>(
          builder: (context, viewModel, _) {
            return Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: _buildHeader(context),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: AppDimensions.spacingLg,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (SessionEndNotice.pending != null)
                                _buildSessionEndNotice(
                                  cs,
                                  SessionEndNotice.pending!,
                                ),
                              if (PasswordResetHandoff.pending
                                  is PasswordResetDone)
                                PasswordResetDoneNotice(
                                  onClose: () =>
                                      setState(PasswordResetHandoff.clear),
                                ),
                              _buildLoginCard(viewModel),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The locked logo lockup on the page background, per the drawing
  /// (Skarmar v12 del 2 #inloggning rad 1467-1490, #inloggningmorkt rad
  /// 1205-1228): a centred 148 px lockup in a `padding:56px 28px 0` block,
  /// the tagline 10 px below it, no divider underneath. The green header and
  /// the broccoli illustration are gone; the logo is never written as text
  /// (beslut 2026-09-30, B96-2 = A).
  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 56, 28, 0),
      child: Column(
        children: [
          const ButleryLockup(),
          const SizedBox(height: 10),
          Text(
            context.l10n.authTagline,
            textAlign: TextAlign.center,
            // The drawing's 13/400 has no role; bodyMedium (14/400) keeps the
            // weight. The 12/400 caption role failed the rendered
            // text-contrast check at 360 dp in both modes.
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Skarmar v12 etapp 9 #globsessiontyst (globala tillstand och flerval:98)
  /// draws the notice and its words.
  /// A background timeout could not warn, so it is explained here, calmly:
  /// "som en lugn upplysning (`surface.raised`, `text.success`-glyf) med
  /// skälet och antalet väntande ändringar. Aldrig som fel"
  /// (produktregler.md:834). `surface.raised` is `surfaceContainerHighest`
  /// and `text.success` is `modeColors.success`, in both modes
  /// (app_colors.dart / app_colors_dark.dart).
  Widget _buildSessionEndNotice(ColorScheme cs, SessionEnd end) {
    final l10n = context.l10n;
    // The drawn body is secondary ink, bold parts in ink (#globsessiontyst):
    // semantic text.body, #37453A light / #F5F4ED dark (tokens.json:58-60).
    // The drawing's dark #C9D3C4 is the palette's bodyOnDark, which the
    // semantic token does not deliver; the token wins.
    final bodyColor = AppModeColors.textBody(cs.brightness);
    return Container(
      key: const ValueKey('auth.sessionEndNotice'),
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingXl),
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ButleryIcon(
            ButleryIcons.circleCheck,
            color: context.modeColors.success,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.sessionEndedBackgroundTitle,
                  style: AppTextStyles.bodyBold.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                Text(
                  l10n.sessionEndedBackgroundReason,
                  style: AppTextStyles.bodyMedium.copyWith(color: bodyColor),
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                Text(
                  l10n.sessionEndedBackgroundPending(end.pendingChanges.total),
                  style: AppTextStyles.bodyMedium.copyWith(color: bodyColor),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.commonClose,
            icon: ButleryIcon(ButleryIcons.x, color: cs.onSurfaceVariant),
            onPressed: () => setState(SessionEndNotice.clear),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(AuthViewModel viewModel) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingXl,
        vertical: AppDimensions.spacingLg + AppDimensions.spacingXs,
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: _submitAttempted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  viewModel.isLoginMode
                      ? context.l10n.authLogin
                      : context.l10n.authCreateAccount,
                  style: AppTextStyles.headlineMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(
                height: AppDimensions.spacingLg + AppDimensions.spacingXs,
              ),

              // Name field (registration only)
              if (!viewModel.isLoginMode) ...[
                _buildLabeledField(
                  label: context.l10n.authYourName,
                  child: TextFormField(
                    style: fieldTextStyle(
                      context,
                      enabled: !viewModel.isLoading,
                    ),
                    key: const Key('name_field'),
                    controller: _nameController,
                    focusNode: _nameFocus,
                    textInputAction: TextInputAction.next,
                    enabled: !viewModel.isLoading,
                    decoration: _inputDecoration(
                      hint: context.l10n.authEnterYourName,
                    ),
                    validator: FormValidators.authName(),
                    autofillHints: const [AutofillHints.name],
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_emailFocus);
                    },
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
              ],

              // Email field
              _buildLabeledField(
                label: context.l10n.authEmail,
                child: TextFormField(
                  style: fieldTextStyle(context, enabled: !viewModel.isLoading),
                  key: const Key('email_field'),
                  controller: _emailController,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !viewModel.isLoading,
                  decoration: _inputDecoration(
                    hint: context.l10n.authEmailHint,
                  ),
                  validator: FormValidators.authEmail(),
                  autofillHints: const [AutofillHints.email],
                  onFieldSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_passwordFocus);
                  },
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMd),

              // Password field
              _buildLabeledField(
                label: context.l10n.authPassword,
                child: TextFormField(
                  style: fieldTextStyle(context, enabled: !viewModel.isLoading),
                  key: const Key('password_field'),
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscureText: !viewModel.isPasswordVisible,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleSubmit(viewModel),
                  enabled: !viewModel.isLoading,
                  decoration: _inputDecoration(
                    hint: viewModel.isLoginMode
                        ? context.l10n.authEnterPassword
                        : context.l10n.authPasswordMinLength,
                    suffixIcon: Semantics(
                      label: viewModel.isPasswordVisible
                          ? context.l10n.a11yHidePassword
                          : context.l10n.a11yShowPassword,
                      button: true,
                      enabled: !viewModel.isLoading,
                      child: IconButton(
                        icon: const ButleryIcon(
                          // One glyph for both states until design draws the second one
                          // (P7-U08 open question); the tooltip/label carries the state.
                          ButleryIcons.eye,
                          size: AppDimensions.iconSizeAction,
                        ),
                        onPressed: viewModel.togglePasswordVisibility,
                        tooltip: viewModel.isPasswordVisible
                            ? context.l10n.a11yHidePassword
                            : context.l10n.a11yShowPassword,
                      ),
                    ),
                  ),
                  validator: viewModel.isLoginMode
                      ? FormValidators.authPassword()
                      : FormValidators.strongPassword(),
                  autofillHints: const [AutofillHints.password],
                ),
              ),

              // Forgot password (login mode only)
              if (viewModel.isLoginMode) ...[
                const SizedBox(height: AppDimensions.spacingSm),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: viewModel.isLoading
                        ? null
                        : () => _showPasswordResetDialog(context, viewModel),
                    // BUT-1380: keep the compact padding but drop the
                    // shrink-wrapped tap target — Flutter's default `padded`
                    // size restores the 48dp hit area (WCAG 2.5.5 / Material)
                    // without changing the visible layout.
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      context.l10n.authForgotPassword,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ],

              if (!viewModel.isLoginMode) ...[
                const SizedBox(height: AppDimensions.spacingMd),
                // Terms acceptance (registration only)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildConsentCheckbox(
                      value: _termsAccepted,
                      // The sentence beside the box is split into links, so
                      // the box carries the whole of it as its name.
                      semanticLabel:
                          '${context.l10n.authTermsAcceptPrefix}'
                          '${context.l10n.authTermsOfService}'
                          '${context.l10n.authTermsAcceptMiddle}'
                          '${context.l10n.profilePrivacyPolicy}',
                      onChanged: viewModel.isLoading
                          ? null
                          : (value) => setState(
                              () => _termsAccepted = value ?? false,
                            ),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Expanded(
                      // BUT-1426: the inline ToS / Privacy links were
                      // TapGestureRecognizer spans — no link role, no
                      // accessible name.
                      // The plain-label words toggle the checkbox.
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Semantics(
                            button: true,
                            toggled: _termsAccepted,
                            child: GestureDetector(
                              onTap: viewModel.isLoading
                                  ? null
                                  : () => setState(
                                      () => _termsAccepted = !_termsAccepted,
                                    ),
                              child: Text(
                                context.l10n.authTermsAcceptPrefix,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                          ),
                          ButleryLink(
                            semanticLabel: context.l10n.a11yTermsOfServiceLink,
                            onTap: _navigateToTerms,
                            child: Text(
                              context.l10n.authTermsOfService,
                              style: _termsLinkStyle(cs),
                            ),
                          ),
                          Text(
                            context.l10n.authTermsAcceptMiddle,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                          ButleryLink(
                            semanticLabel: context.l10n.a11yPrivacyPolicyLink,
                            onTap: _navigateToPrivacy,
                            child: Text(
                              context.l10n.profilePrivacyPolicy,
                              style: _termsLinkStyle(cs),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppDimensions.spacingLg),

              // Error message
              if (viewModel.errorMessage != null) ...[
                StateWidget.error(message: viewModel.errorMessage!),
                const SizedBox(height: AppDimensions.spacingMd),
              ],

              // The step's one saffron action, "Logga in" or "Skapa konto"
              // (Skarmar v12 etapp 3 'Auth — logga in', 'Auth — skapa
              // konto'; Grafisk manual v6:219). Working keeps the name and
              // draws the plate line under it (Komponentark v1:372).
              HeroButton(
                key: const ValueKey('auth.submit'),
                label: viewModel.isLoginMode
                    ? context.l10n.authLogin
                    : context.l10n.authCreateAccount,
                onPressed: () => _handleSubmit(viewModel),
                busy: viewModel.isLoading,
                expand: true,
              ),

              const SizedBox(height: AppDimensions.spacingLg),

              // "eller" divider
              Row(
                children: [
                  Expanded(child: Divider(color: cs.outlineVariant)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingMd,
                    ),
                    child: Text(
                      context.l10n.commonOr,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: cs.outlineVariant)),
                ],
              ),

              const SizedBox(height: AppDimensions.spacingLg),

              // Toggle button (Skapa konto / Logga in)
              SizedBox(
                width: double.infinity,
                height: AppDimensions.buttonHeight,
                child: OutlinedButton(
                  onPressed: viewModel.isLoading
                      ? null
                      : () {
                          // Clear mode-specific state so switching login<->signup
                          // doesn't carry a stale password or name.
                          _passwordController.clear();
                          _nameController.clear();
                          setState(() => _submitAttempted = false);
                          viewModel.toggleAuthMode();
                        },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cs.onSurface),
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: Text(
                    viewModel.isLoginMode
                        ? context.l10n.authCreateAccount
                        : context.l10n.authLogin,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    Widget? suffixIcon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: cs.onSurfaceVariant),
      filled: true,
      fillColor: cs.surfaceContainerLow,
      // A field on surface.base: hover takes surface.raised (BUT-2205).
      hoverColor: cs.surfaceContainerHighest,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.space12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: cs.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: cs.outline),
      ),
      // Focus is the canonical ring colour at the ring's width, ink on
      // light and paper on dark, never saffron (tokens.json:155-160;
      // Grafisk manual v6:209; enhet-4 auth_view.dart:528).
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: context.modeColors.focusRing,
          width: AppDimensions.focusRingWidth,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: cs.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: cs.error),
      ),
    );
  }

  /// A consent checkbox with a >=48dp tap target (WCAG 2.5.5 / EAA) while the
  /// visible box stays compact. BUT-1426: the old SizedBox(24,24) clamped the
  /// hit area to half the minimum touch target — Checkbox's default
  /// `materialTapTargetSize.padded` restores 48dp inside this box.
  Widget _buildConsentCheckbox({
    required bool value,
    required ValueChanged<bool?>? onChanged,
    required String semanticLabel,
  }) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Checkbox(
        value: value,
        onChanged: onChanged,
        semanticLabel: semanticLabel,
      ),
    );
  }

  // text.link (R8-11 = A).
  TextStyle _termsLinkStyle(ColorScheme cs) => AppTextStyles.bodySmall.copyWith(
    color: context.modeColors.textLink,
    decoration: TextDecoration.underline,
    decorationColor: context.modeColors.textLink,
  );

  void _navigateToTerms() =>
      Navigator.pushNamed(context, Routes.termsOfService);

  void _navigateToPrivacy() =>
      Navigator.pushNamed(context, Routes.privacyPolicy);

  Widget _buildFooter() {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      // The links' 48 dp boxes stand in for the vertical padding the row had.
      // The equal side padding keeps the gap on both sides of the dot the
      // same when a link's text is narrower than its 48 dp box.
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingSm,
            ),
            child: ButleryLink(
              semanticLabel: context.l10n.a11yTermsOfServiceLink,
              onTap: _navigateToTerms,
              child: Text(
                context.l10n.authTermsOfService,
                style: AppTextStyles.labelMedium.copyWith(
                  color: context.modeColors.textLink,
                  decoration: TextDecoration.underline,
                  decorationColor: context.modeColors.textLink,
                ),
              ),
            ),
          ),
          // A separator, not content: a screen reader reads the two links.
          ExcludeSemantics(
            child: Text(
              '\u00B7',
              style: AppTextStyles.labelMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingSm,
            ),
            child: ButleryLink(
              semanticLabel: context.l10n.a11yPrivacyPolicyLink,
              onTap: _navigateToPrivacy,
              child: Text(
                context.l10n.profilePrivacyPolicy,
                style: AppTextStyles.labelMedium.copyWith(
                  color: context.modeColors.textLink,
                  decoration: TextDecoration.underline,
                  decorationColor: context.modeColors.textLink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Set synchronously: the viewmodel's busy flag only turns on after the
  // service's first await, so a double tap or Enter plus a tap would otherwise
  // run the whole submit (and the login navigation) twice.
  bool _submitting = false;

  Future<void> _handleSubmit(AuthViewModel viewModel) async {
    if (_submitting) return;
    _submitting = true;
    try {
      await _runSubmit(viewModel);
    } finally {
      _submitting = false;
    }
  }

  Future<void> _runSubmit(AuthViewModel viewModel) async {
    viewModel.clearError();

    if (!_submitAttempted) setState(() => _submitAttempted = true);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Terms acceptance required for registration
    if (!viewModel.isLoginMode && !_termsAccepted) {
      SnackBarUtils.showWarning(context, context.l10n.authTermsAcceptRequired);
      return;
    }

    FocusScope.of(context).unfocus();

    // Capture the mode before the async gap — toggleAuthMode could in theory
    // race, and we must branch navigation on the mode the submit ran under.
    final wasLoginMode = viewModel.isLoginMode;

    bool success;

    var signedInWithBackupCode = false;
    if (wasLoginMode) {
      success = await viewModel.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // Two-step verification: the password was right and the second factor
      // is asked for (P6-U09; Skarmar v12 etapp 3 #authmfa).
      final challenge = viewModel.pendingMfaChallenge;
      if (!success && challenge != null && mounted) {
        final result = await Navigator.of(context).push<MfaChallengeResult>(
          MaterialPageRoute(
            builder: (_) => MfaChallengeView(
              challenge: challenge,
              email: _emailController.text.trim(),
              password: _passwordController.text,
            ),
          ),
        );
        success = result != null;
        signedInWithBackupCode =
            result == MfaChallengeResult.signedInWithBackupCode;
      }
    } else {
      success = await viewModel.register(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _nameController.text,
      );
    }

    // A successful REGISTER must NOT navigate manually: letting the auth-state
    // change drive AuthWrapper routes the new user through verification ->
    // onboarding.
    if (success && wasLoginMode && mounted) {
      AppLogger.debug(
        'AuthView: LOGIN SUCCESS',
      );

      final navigator = Navigator.of(context);
      navigator.pushReplacement(
        MaterialPageRoute(builder: AuthView.postLoginDestinationBuilder),
      );
      SessionEndNotice.clear();
      PasswordResetHandoff.clear();
      // After a timeout, the same account lands where it was
      // (TR::FLOW::06::session::utgang; Q-P6-E07).
      final userId = ServiceLocator.get<AuthService>().currentUserId;
      final returnTo = userId == null
          ? null
          : SessionReturnPath.takeFor(userId);
      if (returnTo != null) {
        navigator.pushNamed(returnTo.routeName, arguments: returnTo.arguments);
      }
      // A backup code switched the phone factor off; say so, and where to
      // add a phone again (P6-U09, TR::FLOW::06::mfa::aterstallning-engangskoder).
      if (signedInWithBackupCode) {
        SnackBarUtils.showInfo(
          context,
          context.l10n.mfaBackupCodeRecovered,
          duration: const Duration(seconds: 10),
          showCloseButton: true,
        );
      }
    }
  }

  Future<void> _showPasswordResetDialog(
    BuildContext context,
    AuthViewModel viewModel,
  ) async {
    String emailValue = '';
    String? emailError;

    // Capture before async gap (showDialog)
    final l10n = context.l10n;

    final email = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.authResetPassword),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.authResetPasswordInstructions,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              TextField(
                key: const Key('reset_email_field'),
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: context.l10n.authEmail,
                  hintText: context.l10n.authEmailHint,
                  errorText: emailError,
                ),
                onChanged: (value) {
                  emailValue = value;
                  if (emailError != null) {
                    setDialogState(() => emailError = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            ActionButtons.secondaryButton(
              context,
              label: context.l10n.commonCancel,
              onPressed: () => Navigator.of(dialogContext).pop(null),
            ),
            // "Skicka" is the dialog's saffron action (Skarmar v12 etapp 3
            // 'Auth — glömt lösenordet'), sized to its label in the row.
            FilledButton(
              key: const ValueKey('auth.resetSend'),
              style:
                  ComponentThemes.heroButtonStyle(
                    Theme.of(context).colorScheme,
                  ).copyWith(
                    minimumSize: const WidgetStatePropertyAll(
                      Size(0, AppDimensions.minTouchTarget),
                    ),
                  ),
              onPressed: () {
                final trimmed = emailValue.trim();
                // Validate inline so a malformed address is caught before we
                // fire the reset (and surface success for a non-existent one).
                if (ValidationUtils.validateEmail(trimmed) != null) {
                  setDialogState(() => emailError = l10n.authInvalidEmail);
                  return;
                }
                Navigator.of(dialogContext).pop(trimmed);
              },
              child: Text(context.l10n.commonSend),
            ),
          ],
        ),
      ),
    );

    if (email == null || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final success = await viewModel.sendPasswordReset(email);

      if (!mounted) return;

      if (success) {
        SnackBarUtils.showSuccess(this.context, l10n.authResetEmailSent);
      } else {
        SnackBarUtils.showFailure(
          this.context,
          what: viewModel.errorMessage ?? l10n.authResetEmailFailed,
        );
      }
    });
  }
}
