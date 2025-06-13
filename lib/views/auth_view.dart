// lib/views/auth_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../core/injection.dart';
import '../theme/app_theme.dart';

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
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Consumer<AuthViewModel>(
            builder: (context, viewModel, _) {
              return Center(
                child: SingleChildScrollView(
                  padding: AppTheme.screenPadding,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo/Header område
                      _buildHeader(context),
                      AppTheme.hugeGap,

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
    return Column(
      children: [
        // App-ikon (kan ersättas med logotyp senare)
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: AppTheme.roundRadius,
          ),
          child: Icon(
            Icons.restaurant_menu,
            size: AppTheme.iconSizeHero,
            color: Colors.white,
          ),
        ),
        AppTheme.mediumGap,

        // App-namn
        Text(
          'Butlery',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        AppTheme.smallGap,

        // Välkomsttext
        Text(
          'Smart recepthantering för din vardag',
          style: AppTheme.subtitleStyle,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Bygger auth-kortet med formulär
  Widget _buildAuthCard(BuildContext context, AuthViewModel viewModel) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: AppTheme.cardDecoration,
      padding: AppTheme.sectionPadding,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rubrik
            Text(
              viewModel.isLoginMode ? 'Logga in' : 'Skapa konto',
              style: AppTheme.sectionTitleStyle,
              textAlign: TextAlign.center,
            ),
            AppTheme.largeGap,

            // Namn-fält (bara vid registrering)
            if (!viewModel.isLoginMode) ...[
              _buildNameField(viewModel),
              AppTheme.mediumGap,
            ],

            // Email-fält
            _buildEmailField(viewModel),
            AppTheme.mediumGap,

            // Lösenords-fält
            _buildPasswordField(viewModel),

            // Glömt lösenord (bara vid login)
            if (viewModel.isLoginMode) ...[
              AppTheme.smallGap,
              _buildForgotPasswordButton(context, viewModel),
            ],

            AppTheme.largeGap,

            // Error-meddelande
            if (viewModel.errorMessage != null) ...[
              _buildErrorMessage(viewModel.errorMessage!),
              AppTheme.mediumGap,
            ],

            // Submit-knapp
            _buildSubmitButton(viewModel),
            AppTheme.mediumGap,

            // Toggle login/register
            _buildToggleButton(viewModel),
          ],
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
      decoration: InputDecoration(
        labelText: 'Ditt namn',
        hintText: 'Ange ditt namn',
        prefixIcon: Icon(Icons.person_outline, size: AppTheme.iconSizeAction),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Namn krävs';
        }
        if (value.length < 2) {
          return 'Namnet måste vara minst 2 tecken';
        }
        return null;
      },
      onFieldSubmitted: (_) {
        FocusScope.of(context).requestFocus(_emailFocus);
      },
    );
  }

  /// Email-fält
  Widget _buildEmailField(AuthViewModel viewModel) {
    return TextFormField(
      controller: _emailController,
      focusNode: _emailFocus,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      enabled: !viewModel.isLoading,
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'din.email@exempel.se',
        prefixIcon: Icon(Icons.email_outlined, size: AppTheme.iconSizeAction),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Email krävs';
        }
        // Enkel email-validering
        if (!value.contains('@') || !value.contains('.')) {
          return 'Ange en giltig email-adress';
        }
        return null;
      },
      onFieldSubmitted: (_) {
        FocusScope.of(context).requestFocus(_passwordFocus);
      },
    );
  }

  /// Lösenords-fält
  Widget _buildPasswordField(AuthViewModel viewModel) {
    return TextFormField(
      controller: _passwordController,
      focusNode: _passwordFocus,
      obscureText: !viewModel.isPasswordVisible,
      textInputAction: TextInputAction.done,
      enabled: !viewModel.isLoading,
      decoration: InputDecoration(
        labelText: 'Lösenord',
        hintText:
            viewModel.isLoginMode ? 'Ange ditt lösenord' : 'Minst 6 tecken',
        prefixIcon: Icon(Icons.lock_outline, size: AppTheme.iconSizeAction),
        suffixIcon: IconButton(
          icon: Icon(
            viewModel.isPasswordVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: AppTheme.iconSizeAction,
          ),
          onPressed: viewModel.togglePasswordVisibility,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Lösenord krävs';
        }
        if (!viewModel.isLoginMode && value.length < 6) {
          return 'Lösenordet måste vara minst 6 tecken';
        }
        return null;
      },
      onFieldSubmitted: (_) => _handleSubmit(viewModel),
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
          style: AppTheme.captionStyle.copyWith(color: AppTheme.primaryColor),
        ),
      ),
    );
  }

  /// Error-meddelande
  Widget _buildErrorMessage(String message) {
    return AppTheme.errorContainer(context, message);
  }

  /// Submit-knapp
  Widget _buildSubmitButton(AuthViewModel viewModel) {
    return FilledButton(
      onPressed: viewModel.isLoading ? null : () => _handleSubmit(viewModel),
      style: AppTheme.primaryButtonStyle,
      child:
          viewModel.isLoading
              ? AppTheme.smallLoadingIndicator(context)
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
                color: AppTheme.primaryColor,
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
                AppTheme.mediumGap,
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
              success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }

    emailController.dispose();
  }
}
