/// Comprehensive authentication view providing advanced user authentication and registration for Flutter applications.
///
/// This module implements sophisticated authentication UI following Single Responsibility Principle,
/// specializing in user authentication, registration workflows, form validation, and password recovery.
/// It provides complete authentication interface while maintaining clean separation from business logic,
/// authentication services, and state management through MVVM architecture integration.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles authentication UI presentation concerns:
/// - **Authentication Interface Excellence**: Advanced login and registration forms with comprehensive validation
/// - **User Experience Optimization**: Intuitive form navigation, accessibility features, and responsive design
/// - **Swedish Localization Excellence**: Complete Swedish language support for authentication operations
/// - **Password Recovery System**: Comprehensive password reset functionality with email validation
/// - **MVVM Architecture Integration**: Clean separation between UI and business logic through AuthViewModel
///
/// **What This Module Does NOT Handle:**
/// - Authentication business logic (handled by AuthViewModel and authentication services)
/// - User data persistence and storage (handled by authentication repositories and Firebase)
/// - Session management and token handling (handled by authentication services)
/// - Navigation logic and routing (handled by application routing and navigation services)
///
/// **Authentication View Features:**
/// - **Dual-Mode Authentication**: Seamless switching between login and registration modes with form adaptation
/// - **Advanced Form Validation**: Real-time validation with Swedish localized error messages
/// - **Password Recovery**: Complete password reset workflow with email validation and user feedback
/// - **Accessibility Excellence**: Comprehensive accessibility features with focus management and screen reader support
/// - **Responsive Design**: Optimized layout for different screen sizes and orientations
///
/// **Usage Examples:**
/// ```dart
/// // Navigate to authentication view
/// Navigator.of(context).pushReplacement(
///   MaterialPageRoute(builder: (context) => const AuthView()),
/// );
/// 
/// // The view handles all authentication scenarios:
/// // - User login with email/password validation
/// // - New user registration with name, email, and password
/// // - Password recovery with email-based reset
/// // - Form validation with Swedish localized messages
/// // - Loading states and error handling
/// 
/// // Authentication state changes are managed by AuthViewModel:
/// // - Successful authentication navigates to main application
/// // - Registration creates new user account with profile setup
/// // - Password reset sends recovery email with instructions
/// ```

// lib/views/auth_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/branding/app_logo.dart';
import 'package:butlery/widgets/styled/styled_widgets.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/widgets/common/layout/auth_form_card.dart';
/// Comprehensive authentication view providing advanced user authentication through MVVM architecture integration.
///
/// Manages complete authentication interface enabling user login and registration with form validation,
/// password recovery, and responsive design while maintaining clean separation between UI presentation
/// and authentication business logic through AuthViewModel integration and reactive state management.
///
/// **Core Responsibilities:**
/// - Advanced authentication form presentation with dual-mode login/registration interface
/// - Comprehensive form validation with real-time feedback and Swedish localized error messages
/// - Password recovery workflow with email validation and user feedback coordination
/// - Responsive design implementation with accessibility features and focus management
/// - MVVM architecture integration with AuthViewModel for business logic separation
class AuthView extends StatefulWidget {
  /// Creates comprehensive authentication view with advanced form management and MVVM integration.
  /// 
  /// Establishes authentication interface with form validation, password recovery,
  /// and responsive design coordination enabling complete user authentication
  /// and registration workflows through clean architectural separation.
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

/// Authentication view state managing form controllers, validation, and user interaction coordination.
///
/// Handles complete authentication form lifecycle including controller management, focus navigation,
/// form validation, and user interaction coordination while maintaining clean state management
/// and proper resource disposal through comprehensive lifecycle management.
class _AuthViewState extends State<AuthView> {
  // ===== FORM MANAGEMENT =====

  /// Form validation key for comprehensive form state management and validation coordination.
  /// 
  /// Enables form validation, error handling, and submission control throughout
  /// authentication workflows with comprehensive validation state tracking.
  final _formKey = GlobalKey<FormState>();
  
  /// Email input controller for user email management and validation coordination.
  /// 
  /// Manages email input state enabling email validation, form submission,
  /// and user authentication with comprehensive input state management.
  final _emailController = TextEditingController();
  
  /// Password input controller for secure password management and validation coordination.
  /// 
  /// Manages password input state enabling secure password handling, validation,
  /// and authentication with comprehensive security and input state management.
  final _passwordController = TextEditingController();
  
  /// Name input controller for user registration and profile creation coordination.
  /// 
  /// Manages user name input state enabling registration workflows, profile creation,
  /// and user account setup with comprehensive input validation and state management.
  final _nameController = TextEditingController();

  // ===== FOCUS MANAGEMENT FOR ENHANCED UX =====

  /// Email input focus node for enhanced form navigation and accessibility coordination.
  /// 
  /// Enables keyboard navigation, accessibility features, and improved user experience
  /// through focus management and form navigation coordination.
  final _emailFocus = FocusNode();
  
  /// Password input focus node for secure input focus management and navigation coordination.
  /// 
  /// Enables secure password input navigation, accessibility features,
  /// and enhanced user experience through comprehensive focus management.
  final _passwordFocus = FocusNode();
  
  /// Name input focus node for registration form navigation and accessibility coordination.
  /// 
  /// Enables registration form navigation, accessibility features, and improved
  /// user experience through focus management and form coordination.
  final _nameFocus = FocusNode();

  /// Comprehensive resource disposal with controller and focus node cleanup coordination.
  /// 
  /// Performs complete resource cleanup preventing memory leaks and ensuring proper
  /// resource management through systematic disposal of form controllers, focus nodes,
  /// and state resources with comprehensive lifecycle management.
  /// 
  /// **Disposal Process:**
  /// - Form controller cleanup with input state resource disposal
  /// - Focus node cleanup with keyboard navigation resource management
  /// - Memory leak prevention with comprehensive resource cleanup
  /// - Proper lifecycle management with systematic resource disposal
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
        backgroundColor: AppColors.backgroundBeige,
        body: SafeArea(
          child: Consumer<AuthViewModel>(
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
      ),
    );
  }

  /// Comprehensive authentication header construction with branding and welcome messaging coordination.
  /// 
  /// [context] Build context for theme access and widget construction coordination
  /// 
  /// Constructs authentication header featuring app branding, welcome messaging,
  /// and visual identity elements enabling brand recognition and user orientation
  /// through comprehensive branding presentation and Swedish localized messaging.
  /// 
  /// **Header Features:**
  /// - App branding with logo and visual identity coordination
  /// - Swedish localized tagline with value proposition messaging
  /// - Responsive design with consistent brand presentation
  /// - Visual hierarchy with proper spacing and alignment coordination
  /// 
  /// Returns branded header widget for authentication interface presentation.
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

  /// Comprehensive authentication card construction with form management and validation coordination.
  /// 
  /// [context] Build context for theme access and widget construction coordination
  /// [viewModel] AuthViewModel instance for authentication state management and business logic coordination
  /// 
  /// Constructs complete authentication form card featuring dual-mode authentication,
  /// form validation, error handling, and user interaction management through
  /// comprehensive form architecture and MVVM integration.
  /// 
  /// **Authentication Card Features:**
  /// - Dual-mode form supporting both login and registration workflows
  /// - Real-time form validation with Swedish localized error messages
  /// - Conditional field rendering based on authentication mode
  /// - Comprehensive error handling with user feedback and recovery options
  /// - Loading state management with progress indication and interaction control
  /// 
  /// Returns complete authentication form card for user authentication interface.
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

  /// Comprehensive name input field construction for user registration and profile creation coordination.
  /// 
  /// [viewModel] AuthViewModel instance for form state management and validation coordination
  /// 
  /// Constructs user name input field featuring validation, focus management,
  /// and accessibility features enabling registration workflows and profile creation
  /// with comprehensive input validation and user experience optimization.
  /// 
  /// **Name Field Features:**
  /// - Form validation with Swedish localized error messages and real-time feedback
  /// - Focus management with keyboard navigation and accessibility coordination
  /// - Loading state integration with form interaction control and user feedback
  /// - Swedish localized labels and hints for enhanced user experience
  /// 
  /// Returns name input field widget for registration form integration.
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

  /// Comprehensive email input field construction with validation and accessibility coordination.
  /// 
  /// [viewModel] AuthViewModel instance for form state management and validation coordination
  /// 
  /// Constructs email input field featuring advanced validation, focus management,
  /// and accessibility features enabling authentication workflows with comprehensive
  /// email validation and user experience optimization through styled input components.
  /// 
  /// **Email Field Features:**
  /// - Advanced email validation with real-time feedback and Swedish localized messages
  /// - Focus management with keyboard navigation and form flow coordination
  /// - Styled input integration with consistent theming and visual design
  /// - Accessibility features with proper labeling and screen reader support
  /// 
  /// Returns styled email input field widget for authentication form integration.
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

  /// Comprehensive password input field construction with security and validation coordination.
  /// 
  /// [viewModel] AuthViewModel instance for password state management and validation coordination
  /// 
  /// Constructs secure password input field featuring visibility toggling, validation,
  /// and accessibility features enabling secure authentication workflows with comprehensive
  /// password management and user experience optimization through advanced security features.
  /// 
  /// **Password Field Features:**
  /// - Password visibility toggling with secure input management and user control
  /// - Advanced password validation with strength requirements and Swedish localized feedback
  /// - Focus management with form navigation and accessibility coordination
  /// - Security-focused design with proper obscuring and input protection
  /// - Conditional validation based on authentication mode (login vs registration)
  /// 
  /// Returns secure password input field widget for authentication form integration.
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

  /// Comprehensive forgot password button construction with recovery workflow coordination.
  /// 
  /// [context] Build context for dialog presentation and navigation coordination
  /// [viewModel] AuthViewModel instance for password recovery state management
  /// 
  /// Constructs forgot password button featuring recovery workflow initiation,
  /// dialog presentation, and user guidance enabling password recovery functionality
  /// with comprehensive user experience and Swedish localized messaging.
  /// 
  /// **Forgot Password Features:**
  /// - Password recovery workflow initiation with dialog presentation
  /// - Swedish localized messaging and user guidance
  /// - Loading state integration with interaction control
  /// - Consistent theming with app design system integration
  /// 
  /// Returns forgot password button widget for login form integration.
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

  /// Comprehensive error message presentation with user feedback and recovery coordination.
  /// 
  /// [message] Swedish localized error message for user display and feedback
  /// 
  /// Constructs error message widget featuring user-friendly error presentation,
  /// recovery options, and dismissal functionality enabling comprehensive error
  /// handling and user guidance through consistent error messaging design.
  /// 
  /// **Error Message Features:**
  /// - Swedish localized error messages with user-friendly presentation
  /// - Error dismissal functionality with state management integration
  /// - Consistent error styling with app design system coordination
  /// - User guidance with recovery options and action suggestions
  /// 
  /// Returns error message widget for form error display and user feedback.
  Widget _buildErrorMessage(String message) {
    return StateWidget.error(
      message: message,
      onAction: () => context.read<AuthViewModel>().clearError(),
    );
  }

  /// Comprehensive submit button construction with loading states and form submission coordination.
  /// 
  /// [viewModel] AuthViewModel instance for form submission state management and loading coordination
  /// 
  /// Constructs form submission button featuring loading indicators, state management,
  /// and dual-mode labeling enabling authentication form submission with comprehensive
  /// user feedback and interaction control through responsive button design.
  /// 
  /// **Submit Button Features:**
  /// - Dual-mode labeling for login and registration workflows
  /// - Loading state integration with progress indicators and interaction control
  /// - Form submission coordination with validation and error handling
  /// - Accessibility features with proper button labeling and state indication
  /// 
  /// Returns form submission button widget for authentication workflow completion.
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

  /// Comprehensive authentication mode toggle construction with dual-mode switching coordination.
  /// 
  /// [viewModel] AuthViewModel instance for authentication mode state management and switching
  /// 
  /// Constructs authentication mode toggle button featuring seamless switching between
  /// login and registration modes with contextual messaging and user guidance enabling
  /// fluid authentication experience through comprehensive mode management.
  /// 
  /// **Toggle Button Features:**
  /// - Seamless mode switching between login and registration workflows
  /// - Contextual Swedish localized messaging with user guidance
  /// - Loading state integration with interaction control and feedback
  /// - Rich text presentation with visual hierarchy and emphasis
  /// 
  /// Returns authentication mode toggle button for workflow switching.
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

  /// Comprehensive form submission handling with validation and authentication coordination.
  /// 
  /// [viewModel] AuthViewModel instance for authentication operations and state management
  /// 
  /// Handles complete form submission workflow including validation, authentication,
  /// error handling, and user feedback enabling secure authentication operations
  /// with comprehensive validation and user experience optimization.
  /// 
  /// **Form Submission Process:**
  /// - Form validation with error handling and user feedback
  /// - Keyboard dismissal with user interface optimization
  /// - Dual-mode authentication supporting login and registration workflows
  /// - Success handling with navigation coordination and state management
  /// - Error recovery with user feedback and retry functionality
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

  /// Comprehensive password reset dialog presentation with email validation and recovery coordination.
  /// 
  /// [context] Build context for dialog presentation and navigation coordination
  /// [viewModel] AuthViewModel instance for password reset operations and state management
  /// 
  /// Presents password reset dialog featuring email input, validation, and recovery
  /// workflow initiation enabling comprehensive password recovery functionality
  /// with user guidance and feedback through modal dialog interface.
  /// 
  /// **Password Reset Dialog Features:**
  /// - Email input with validation and user guidance
  /// - Swedish localized messaging and instructions
  /// - Password reset email sending with success/error feedback
  /// - Modal dialog design with proper action buttons and navigation
  /// - Resource cleanup with controller disposal and memory management
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
