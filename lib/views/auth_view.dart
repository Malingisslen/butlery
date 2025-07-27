// lib/views/auth_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/branding/app_logo.dart';
import 'package:butlery/widgets/styled/styled_widgets.dart';
import 'package:butlery/core/validators/form_validators.dart';

/// AuthView hanterar login och registrering
///
/// Denna view:
/// - Visar ett vackert login/register-formulär
/// - Följer Butlery's theme konsekvent
/// - Hanterar form-validering
/// - Ger feedback vid fel
class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  // Focus nodes för bättre UX
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _nameFocus = FocusNode();

  @override
  void dispose() {
    // Rensa upp controllers och focus nodes
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
    return ChangeNotifierProvider(
      create: (_) => sl<AuthViewModel>(),
      child: Scaffold(
        backgroundColor: AppColors.backgroundBeige,
        body: SafeArea(
          child: Consumer<AuthViewModel>(
            builder: (context, viewModel, _) {
              return Center(
                child: SingleChildScrollView(
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
              );
            },
          ),
        ),
      ),
    );
  }

  /// Bygger header med app-namn och välkomsttext
  Widget _buildHeader(BuildContext context) {
    return const Column(
      children: [
        // App branding with logo and name
        AppBranding.auth(
          tagline: 'Smart recepthantering för din vardag',
        ),
      ],
    );
  }

  /// Bygger auth-kortet med formulär
  Widget _buildAuthCard(BuildContext context, AuthViewModel viewModel) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
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
        ),
      ),
    );
  }

  /// Namn-fält för registrering
  Widget _buildNameField(AuthViewModel viewModel) {
    return TextFormField(
      controller: _nameController,
      focusNode: _nameFocus,
      textInputAction: TextInputAction.next,
      enabled: !viewModel.isLoading,
      decoration: const InputDecoration(
        labelText: 'Ditt namn',
        hintText: 'Ange ditt namn',
        prefixIcon: Icon(Icons.person_outline, size: AppDimensions.iconSizeAction),
      ),
      validator: FormValidators.authName(),
      onFieldSubmitted: (_) {
        FocusScope.of(context).requestFocus(_emailFocus);
      },
    );
  }

  /// Email-fält
  Widget _buildEmailField(AuthViewModel viewModel) {
    return StyledInput.email(
      controller: _emailController,
      focusNode: _emailFocus,
      label: 'Email',
      hint: 'din.email@exempel.se',
      validator: FormValidators.authEmail(),
      onChanged: (_) {
        FocusScope.of(context).requestFocus(_passwordFocus);
      },
    );
  }

  /// Lösenords-fält
  Widget _buildPasswordField(AuthViewModel viewModel) {
    return StyledInput.password(
      controller: _passwordController,
      focusNode: _passwordFocus,
      label: 'Lösenord',
      hint: viewModel.isLoginMode ? 'Ange ditt lösenord' : 'Minst 6 tecken',
      obscureText: !viewModel.isPasswordVisible,
      enabled: !viewModel.isLoading,
      validator: FormValidators.authPassword(isSignUp: !viewModel.isLoginMode),
      suffixIcon: IconButton(
        icon: Icon(
          viewModel.isPasswordVisible
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: AppDimensions.iconSizeAction,
        ),
        onPressed: viewModel.togglePasswordVisibility,
      ),
      onChanged: (_) => _handleSubmit(viewModel),
    );
  }

  /// Glömt lösenord-knapp
  Widget _buildForgotPasswordButton(
    BuildContext context,
    AuthViewModel viewModel,
  ) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed:
            viewModel.isLoading
                ? null
                : () => _showPasswordResetDialog(context, viewModel),
        child: Text(
          'Glömt lösenord?',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryBlue),
        ),
      ),
    );
  }

  /// Error-meddelande
  Widget _buildErrorMessage(String message) {
    return StateWidget.error(
      message: message,
      onAction: () => context.read<AuthViewModel>().clearError(),
    );
  }

  /// Submit-knapp
  Widget _buildSubmitButton(AuthViewModel viewModel) {
    return FilledButton(
      onPressed: viewModel.isLoading ? null : () => _handleSubmit(viewModel),
      child:
          viewModel.isLoading
              ? const SizedBox(
                  width: AppDimensions.iconSizeS,
                  height: AppDimensions.iconSizeS,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.cardWhite),
                  ),
                )
              : Text(viewModel.isLoginMode ? 'Logga in' : 'Skapa konto'),
    );
  }

  /// Toggle mellan login och register
  Widget _buildToggleButton(AuthViewModel viewModel) {
    return TextButton(
      onPressed: viewModel.isLoading ? null : viewModel.toggleAuthMode,
      child: RichText(
        text: TextSpan(
          text:
              viewModel.isLoginMode
                  ? 'Har du inget konto? '
                  : 'Har du redan ett konto? ',
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: viewModel.isLoginMode ? 'Skapa konto' : 'Logga in',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hanterar formulär-submit
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
      // Navigation hanteras av main.dart baserat på auth state
      // Vi behöver inte göra något här
    }
  }

  /// Visar dialog för lösenordsåterställning
  Future<void> _showPasswordResetDialog(
    BuildContext context,
    AuthViewModel viewModel,
  ) async {
    final emailController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Återställ lösenord'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ange din email-adress så skickar vi instruktioner för att återställa ditt lösenord.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppDimensions.spacingXl),
                TextField(
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
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Avbryt'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Skicka'),
              ),
            ],
          ),
    );

    if (result == true && mounted) {
      // Spara messenger referensen FÖRE async operation
      // ignore: use_build_context_synchronously
      final messenger = ScaffoldMessenger.of(context);

      final success = await viewModel.sendPasswordReset(emailController.text);

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Email skickad! Kontrollera din inkorg.'
                : viewModel.errorMessage ?? 'Kunde inte skicka email',
          ),
          backgroundColor:
              success ? AppColors.success : AppColors.error,
        ),
      );
    }

    emailController.dispose();
  }
}
