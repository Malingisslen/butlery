// lib/views/auth_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/styled/styled_widgets.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/views/legal/privacy_policy_view.dart';
import 'package:butlery/views/mina_recept_view.dart';
import 'package:butlery/core/utils/logger.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

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
  bool _ageConfirmed = false;
  late final AuthViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<AuthViewModel>();
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
                  child: _buildGreenHeader(),
                ),
                Container(
                  height: AppDimensions.spacingXs,
                  color: AppColors.rust,
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
                          child: _buildLoginCard(viewModel),
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

  Widget _buildGreenHeader() {
    return Container(
      color: AppColors.forestGreenDark,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingXl,
        AppDimensions.spacingXxl,
        AppDimensions.spacingXl,
        AppDimensions.spacingXl + AppDimensions.spacingSm,
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/illustrations/broccoli.png',
                height: 60,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: AppDimensions.spacingL),
              Padding(
                padding: const EdgeInsets.only(top: AppDimensions.paddingMs),
                child: Text(
                  'butlery',
                  style: AppTextStyles.headlineBold.copyWith(
                    fontSize: 38,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1,
                    color: AppColors.cream,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingL),
          Text(
            context.l10n.authTagline,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.cardWhite,
            ),
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
                  height: AppDimensions.spacingLg + AppDimensions.spacingXs),

              // Name field (registration only)
              if (!viewModel.isLoginMode) ...[
                _buildLabeledField(
                  label: context.l10n.authYourName,
                  child: TextFormField(
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
                  key: const Key('password_field'),
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscureText: !viewModel.isPasswordVisible,
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
                        icon: Icon(
                          viewModel.isPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: AppDimensions.iconSizeAction,
                        ),
                        onPressed: viewModel.togglePasswordVisibility,
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
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

              // Age confirmation (registration only)
              if (!viewModel.isLoginMode) ...[
                const SizedBox(height: AppDimensions.spacingMd),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _ageConfirmed,
                        onChanged: viewModel.isLoading
                            ? null
                            : (value) =>
                                setState(() => _ageConfirmed = value ?? false),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Expanded(
                      child: Semantics(
                        button: true,
                        toggled: _ageConfirmed,
                        child: GestureDetector(
                          onTap: viewModel.isLoading
                              ? null
                              : () => setState(
                                  () => _ageConfirmed = !_ageConfirmed),
                          child: Text(
                            context.l10n.authAgeConfirmation,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: cs.onSurface),
                          ),
                        ),
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

              // Submit button
              StyledButton.primary(
                key: const Key('submit_button'),
                text: viewModel.isLoginMode
                    ? context.l10n.authLogin
                    : context.l10n.authCreateAccount,
                onPressed:
                    viewModel.isLoading ? null : () => _handleSubmit(viewModel),
                isLoading: viewModel.isLoading,
                width: double.infinity,
              ),

              const SizedBox(height: AppDimensions.spacingLg),

              // "eller" divider
              Row(
                children: [
                  Expanded(child: Divider(color: cs.outlineVariant)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingMd),
                    child: Text(
                      context.l10n.commonOr,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: cs.onSurfaceVariant),
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
                  onPressed:
                      viewModel.isLoading ? null : viewModel.toggleAuthMode,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cs.primary),
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
          style: AppTextStyles.bodySmall
              .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingModerate,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: cs.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: cs.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: cs.primary),
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

  Widget _buildFooter() {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingMd),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              link: true,
              child: InkWell(
                onTap: () =>
                    Navigator.pushNamed(context, Routes.termsOfService),
                child: Text(
                  context.l10n.authTermsOfService,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: cs.onPrimaryContainer,
                    decoration: TextDecoration.underline,
                    decorationColor: cs.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            Text(
              ' \u00B7 ',
              style: AppTextStyles.labelMedium
                  .copyWith(color: cs.onSurfaceVariant),
            ),
            Semantics(
              link: true,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyView(),
                  ),
                ),
                child: Text(
                  context.l10n.profilePrivacyPolicy,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: cs.onPrimaryContainer,
                    decoration: TextDecoration.underline,
                    decorationColor: cs.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit(AuthViewModel viewModel) async {
    viewModel.clearError();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Age confirmation required for registration
    if (!viewModel.isLoginMode && !_ageConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.authAgeConfirmationRequired),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    bool success;

    if (viewModel.isLoginMode) {
      success = await viewModel.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } else {
      success = await viewModel.register(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _nameController.text,
      );
    }

    if (success && mounted) {
      AppLogger.debug(
          'AuthView: LOGIN SUCCESS - Direct navigation to main app');

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MinaReceptView(),
        ),
      );
    }
  }

  Future<void> _showPasswordResetDialog(
    BuildContext context,
    AuthViewModel viewModel,
  ) async {
    String emailValue = '';

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
                ),
                onChanged: (value) {
                  emailValue = value;
                },
              ),
            ],
          ),
          actions: [
            StyledButton.secondary(
              key: const Key('back_to_login_button'),
              text: context.l10n.commonCancel,
              onPressed: () => Navigator.of(dialogContext).pop(null),
            ),
            StyledButton.primary(
              key: const Key('send_reset_button'),
              text: context.l10n.commonSend,
              onPressed: () {
                final trimmed = emailValue.trim();
                Navigator.of(dialogContext)
                    .pop(trimmed.isNotEmpty ? trimmed : null);
              },
            ),
          ],
        ),
      ),
    );

    if (email == null || !mounted) return;

    // ignore: use_build_context_synchronously
    final messenger = ScaffoldMessenger.of(context);
    // ignore: use_build_context_synchronously
    final theme = Theme.of(context);
    // ignore: use_build_context_synchronously
    final l10n = context.l10n;
    final primaryColor = theme.colorScheme.primary
        .withValues(alpha: AppDimensions.opacityVeryDark);
    final errorColor = theme.colorScheme.error;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final success = await viewModel.sendPasswordReset(email);

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? l10n.authResetEmailSent
                : viewModel.errorMessage ?? l10n.authResetEmailFailed,
          ),
          backgroundColor: success ? primaryColor : errorColor,
        ),
      );
    });
  }
}
