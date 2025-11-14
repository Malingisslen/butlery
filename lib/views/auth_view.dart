///
///
///
///
///
///
///

// lib/views/auth_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/branding/app_logo.dart';
import 'package:butlery/widgets/styled/styled_widgets.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/widgets/common/layout/auth_form_card.dart';
import 'package:butlery/core/constants/app_strings.dart';
import 'package:butlery/views/mina_recept_view.dart'; // ULTRATHINK: Direct navigation import
import 'package:butlery/core/utils/logger.dart'; // For AppLogger
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

///
///
class AuthView extends StatefulWidget {
  ///
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

///
class _AuthViewState extends State<AuthView> {

  ///
  final _formKey = GlobalKey<FormState>();

  ///
  final _emailController = TextEditingController();

  ///
  final _passwordController = TextEditingController();

  ///
  final _nameController = TextEditingController();


  ///
  final _emailFocus = FocusNode();

  ///
  final _passwordFocus = FocusNode();

  ///
  final _nameFocus = FocusNode();

  ///
  ///
  @override
  void dispose() {
    // Clean up form controllers to prevent memory leaks
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();

    // Clean up focus nodes for proper keyboard navigation disposal
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _nameFocus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServiceLocator.get<AuthViewModel>(),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Consumer<AuthViewModel>(
          builder: (context, viewModel, _) {
            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo/Header område
                      _buildHeader(context),
                      const SizedBox(height: AppDimensions.spacingXxl),

                      // Auth-kort
                      _buildAuthCard(context, viewModel),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  ///
  ///
  ///
  ///
  Widget _buildHeader(BuildContext context) {
    return const Column(
      children: [
        // App branding with logo, name, and Swedish localized tagline
        AppBranding.auth(
          tagline: 'Smart recepthantering för din vardag',
        ),
      ],
    );
  }

  ///
  ///
  ///
  ///
  Widget _buildAuthCard(BuildContext context, AuthViewModel viewModel) {
    return AuthFormCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rubrik
            Text(
              viewModel.isLoginMode ? 'Logga in' : 'Skapa konto',
              style: AppTextStyles.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingXl),

            // Namn-fält (bara vid registrering)
            if (!viewModel.isLoginMode) ...[
              _buildNameField(viewModel),
              const SizedBox(height: AppDimensions.spacingXl),
            ],

            // Email-fält
            _buildEmailField(viewModel),
            const SizedBox(height: AppDimensions.spacingXl),

            // Lösenords-fält
            _buildPasswordField(viewModel),

            // Glömt lösenord (bara vid login)
            if (viewModel.isLoginMode) ...[
              const SizedBox(height: AppDimensions.spacingM),
              _buildForgotPasswordButton(context, viewModel),
            ],

            const SizedBox(height: AppDimensions.spacingXl),

            // Error-meddelande
            if (viewModel.errorMessage != null) ...[
              _buildErrorMessage(viewModel.errorMessage!),
              const SizedBox(height: AppDimensions.spacingXl),
            ],

            // Submit-knapp
            _buildSubmitButton(viewModel),
            const SizedBox(height: AppDimensions.spacingXl),

            // Toggle login/register
            _buildToggleButton(viewModel),
          ],
        ),
      ),
    );
  }

  ///
  ///
  ///
  ///
  Widget _buildNameField(AuthViewModel viewModel) {
    return TextFormField(
      key: const Key('name_field'),
      controller: _nameController,
      focusNode: _nameFocus,
      textInputAction: TextInputAction.next,
      enabled: !viewModel.isLoading,
      decoration: const InputDecoration(
        labelText: 'Ditt namn',
        hintText: 'Ange ditt namn',
        prefixIcon:
            Icon(Icons.person_outline, size: AppDimensions.iconSizeAction),
      ),
      validator: FormValidators.authName(),
      onFieldSubmitted: (_) {
        FocusScope.of(context).requestFocus(_emailFocus);
      },
    );
  }

  ///
  ///
  ///
  ///
  Widget _buildEmailField(AuthViewModel viewModel) {
    return StyledInput.email(
      key: const Key('email_field'),
      controller: _emailController,
      focusNode: _emailFocus,
      label: 'E-post',
      hint: 'din.email@exempel.se',
      validator: FormValidators.authEmail(),
    );
  }

  ///
  ///
  ///
  ///
  Widget _buildPasswordField(AuthViewModel viewModel) {
    return StyledInput.password(
      key: const Key('password_field'),
      controller: _passwordController,
      focusNode: _passwordFocus,
      label: 'Lösenord',
      hint: viewModel.isLoginMode
          ? AppStrings.enterPassword
          : AppStrings.passwordMinLength,
      obscureText: !viewModel.isPasswordVisible,
      enabled: !viewModel.isLoading,
      validator: FormValidators.authPassword(isSignUp: !viewModel.isLoginMode),
      suffixIcon: Semantics(
        label: viewModel.isPasswordVisible
            ? 'Dölj lösenord'
            : 'Visa lösenord',
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
    );
  }

  ///
  ///
  ///
  ///
  Widget _buildForgotPasswordButton(
    BuildContext context,
    AuthViewModel viewModel,
  ) {
    return Align(
      alignment: Alignment.centerRight,
      child: ActionButtons.textButton(
        context,
        label: AppStrings.forgotPassword,
        onPressed: viewModel.isLoading
            ? null
            : () => _showPasswordResetDialog(context, viewModel),
        style: TextButton.styleFrom(
          textStyle: AppTextStyles.bodySmall,
        ),
      ),
    );
  }

  ///
  ///
  ///
  ///
  Widget _buildErrorMessage(String message) {
    return StateWidget.error(
      message: message,
      // Removed non-functional "Try Again" button - error messages are self-explanatory
    );
  }

  ///
  ///
  ///
  ///
  Widget _buildSubmitButton(AuthViewModel viewModel) {
    return StyledButton.primary(
      key: const Key('submit_button'),
      text: viewModel.isLoginMode ? 'Logga in' : 'Skapa konto',
      onPressed: viewModel.isLoading ? null : () => _handleSubmit(viewModel),
      isLoading: viewModel.isLoading,
    );
  }

  ///
  ///
  ///
  ///
  Widget _buildToggleButton(AuthViewModel viewModel) {
    return ActionButtons.textButton(
      context,
      label: viewModel.isLoginMode
          ? 'Har du inget konto? Skapa konto'
          : 'Har du redan ett konto? Logga in',
      onPressed: viewModel.isLoading ? null : viewModel.toggleAuthMode,
      style: TextButton.styleFrom(
        textStyle: AppTextStyles.bodyMedium,
      ),
    );
  }

  ///
  ///
  ///
  Future<void> _handleSubmit(AuthViewModel viewModel) async {
    // Rensa tidigare fel
    viewModel.clearError();

    // Validera formulär
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Stäng tangentbordet
    FocusScope.of(context).unfocus();

    bool success;

    if (viewModel.isLoginMode) {
      // Logga in
      success = await viewModel.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } else {
      // Registrera
      success = await viewModel.register(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _nameController.text,
      );
    }

    if (success && mounted) {
      // ULTRATHINK DIRECT: Force immediate navigation to main app using Navigator
      AppLogger.debug('AuthView: LOGIN SUCCESS - Direct navigation to main app');
      
      // Import the main view
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MinaReceptView(),
        ),
      );
    }
  }

  ///
  ///
  ///
  Future<void> _showPasswordResetDialog(
    BuildContext context,
    AuthViewModel viewModel,
  ) async {
    final emailController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.resetPassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              AppStrings.resetPasswordInstructions,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            TextField(
              key: const Key('reset_email_field'),
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'din.email@exempel.se',
              ),
            ),
          ],
        ),
        actions: [
          StyledButton.secondary(
            key: const Key('back_to_login_button'),
            text: AppStrings.cancel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          StyledButton.primary(
            key: const Key('send_reset_button'),
            text: AppStrings.send,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      // Spara alla context-beroende referenser FÖRE async operation
      // ignore: use_build_context_synchronously
      final messenger = ScaffoldMessenger.of(context);
      // ignore: use_build_context_synchronously
      final primaryColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.8);
      // ignore: use_build_context_synchronously
      final errorColor = Theme.of(context).colorScheme.error;

      final success = await viewModel.sendPasswordReset(emailController.text);

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Email skickad! Kontrollera din inkorg.'
                : viewModel.errorMessage ?? 'Kunde inte skicka email',
          ),
          backgroundColor: success ? primaryColor : errorColor,
        ),
      );
    }

    emailController.dispose();
  }
}
