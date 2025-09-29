/// Comprehensive recipe editing view providing advanced recipe modification through focused component architecture for Flutter applications.
///
/// This module implements sophisticated recipe editing interface following Single Responsibility Principle and Focused Components Pattern,
/// specializing in recipe editing, collaborative features, and comprehensive form management with modern component delegation.
/// It provides complete recipe editing interface while maintaining clean separation from business logic, data persistence,
/// and state management through MVVM architecture and focused component integration.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles recipe editing UI presentation concerns through focused component architecture:
/// - **Recipe Editing Interface Excellence**: Comprehensive recipe modification with form validation and collaborative features
/// - **Focused Component Architecture**: Advanced component delegation through specialized edit recipe modules
/// - **Collaborative Status Integration**: Complete collaborative editing awareness with permission management and status display
/// - **Multi-Provider Coordination**: Advanced state management with multiple ViewModel integration and service coordination
/// - **Loading Overlay Management**: Sophisticated loading state handling with user feedback and operation progress
///
/// **What This Module Does NOT Handle:**
/// - Recipe editing business logic and data operations (handled by RecipeFormViewModel and recipe services)
/// - Collaborative editing infrastructure (handled by CollaborativeStatusViewModel and collaborative services)
/// - Form validation logic and data processing (handled by form validation services and input processing)
/// - Image processing and storage (handled by image services and cloud storage infrastructure)
///
/// **Edit Recipe View Architecture:**
/// - **Focused Component Pattern**: Clean delegation to specialized edit recipe components and module coordination
/// - **Multi-Provider Integration**: Comprehensive state management with AuthService, RecipeFormViewModel, and CollaborativeStatusViewModel
/// - **Facade Component Architecture**: Modern delegation through EditRecipeActions, EditRecipeAppBar, EditRecipeBanners, EditRecipeBottomBar, and EditRecipeFormFields
/// - **Collaborative Features**: Complete collaborative editing with status banners and permission-based action coordination
/// - **Loading State Management**: Advanced loading overlay with progress indication and user experience optimization
///
/// **Usage Examples:**
/// ```dart
/// // Navigate to recipe editing view
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => EditRecipeView(recipe: selectedRecipe),
///   ),
/// );
/// 
/// // The view provides comprehensive recipe editing functionality:
/// // - Recipe form editing with comprehensive validation and input management
/// // - Collaborative status awareness with permission management and user coordination
/// // - Smart banners with collaborative status and permission indicators
/// // - Permission-based action buttons with save and fork functionality
/// // - Loading overlay with operation progress and user feedback
/// 
/// // Focused component integration:
/// // - EditRecipeActions for save and fork functionality with validation coordination
/// // - EditRecipeAppBar for collaborative status display and navigation management
/// // - EditRecipeBanners for smart status banners and collaborative indicators
/// // - EditRecipeBottomBar for permission-based action buttons and user operations
/// // - EditRecipeFormFields for comprehensive form fields and input validation
/// ```

// lib/views/edit_recipe_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/views/edit_recipe/edit_recipe_actions.dart';
import 'package:butlery/views/edit_recipe/edit_recipe_app_bar.dart';
import 'package:butlery/views/edit_recipe/edit_recipe_banners.dart';
import 'package:butlery/views/edit_recipe/edit_recipe_bottom_bar.dart';
import 'package:butlery/views/edit_recipe/edit_recipe_form_fields.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
/// Comprehensive recipe editing view serving as facade for focused component architecture and collaborative editing.
///
/// This view has been refactored to use the focused components pattern for enhanced maintainability and clean separation:
/// - **edit_recipe_actions.dart**: Save and fork functionality with validation and collaborative coordination
/// - **edit_recipe_app_bar.dart**: AppBar with collaborative status display and navigation management
/// - **edit_recipe_banners.dart**: Smart banners for status display and collaborative indicators
/// - **edit_recipe_bottom_bar.dart**: Permissions-based action buttons with user operation coordination
/// - **edit_recipe_form_fields.dart**: All form fields and inputs with comprehensive validation
/// - **edit_recipe_image_picker.dart**: Image picker modal with upload and processing functionality
/// - **edit_recipe_dynamic_list.dart**: Dynamic list builder for ingredients and instructions management
///
/// **Multi-Provider Architecture:**
/// - AuthService for user authentication and permission management
/// - RecipeFormViewModel for recipe editing state and form coordination
/// - CollaborativeStatusViewModel for collaborative editing awareness and status management
///
/// **Core Responsibilities:**
/// - Advanced recipe editing interface with focused component delegation and collaborative features
/// - Multi-provider state management with comprehensive ViewModel integration and service coordination
/// - Loading state management with progress indication and user experience optimization
/// - Collaborative editing coordination with permission management and status display
/// - Form validation and submission with comprehensive error handling and user feedback
class EditRecipeView extends StatelessWidget {
  /// Recipe data model for editing and collaborative coordination.
  /// 
  /// Stores complete recipe information enabling recipe editing, collaborative features,
  /// and comprehensive recipe modification functionality with validation and processing.
  final Recipe recipe;

  /// Creates comprehensive recipe editing view with focused component architecture and multi-provider integration.
  /// 
  /// [recipe] Recipe data model for editing and collaborative coordination
  /// 
  /// Establishes recipe editing interface with multi-provider state management,
  /// focused component delegation, and comprehensive recipe editing functionality
  /// through clean architectural separation and collaborative feature integration.
  const EditRecipeView({super.key, required this.recipe});

  /// Comprehensive multi-provider widget construction with service integration and component delegation.
  /// 
  /// [context] Build context for provider creation and widget construction coordination
  /// 
  /// Constructs recipe editing view with multi-provider architecture enabling comprehensive
  /// state management, service integration, and component delegation through
  /// AuthService, RecipeFormViewModel, and CollaborativeStatusViewModel coordination.
  /// 
  /// **Multi-Provider Architecture:**
  /// - AuthService integration for user authentication and permission management
  /// - RecipeFormViewModel for recipe editing state management and form coordination
  /// - CollaborativeStatusViewModel for collaborative editing awareness and status management
  /// - Service locator integration for dependency injection and service coordination
  /// 
  /// Returns multi-provider recipe editing view with comprehensive functionality and component delegation.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // AuthService
        ChangeNotifierProvider<AuthService>.value(value: ServiceLocator.get<AuthService>()),

        // RecipeFormViewModel
        ChangeNotifierProvider<RecipeFormViewModel>(
          create: (_) => RecipeFormViewModel(
            recipeService: ServiceLocator.get(),
            analyticsService: ServiceLocator.get(),
            initialRecipe: recipe,
          ),
        ),

        // CollaborativeStatusViewModel
        ChangeNotifierProvider<CollaborativeStatusViewModel>(
          create: (_) => ServiceLocator.get<CollaborativeStatusViewModel>(),
        ),
      ],
      child: _EditRecipeViewContent(recipe: recipe),
    );
  }
}

/// Recipe editing view content managing form state, loading overlay, and component lifecycle coordination.
///
/// Handles complete recipe editing state management including form validation, loading states,
/// component coordination, and user interaction handling while maintaining clean
/// focused component architecture and proper lifecycle management.
class _EditRecipeViewContent extends StatefulWidget {
  /// Recipe data model for content editing and collaborative coordination.
  /// 
  /// Stores complete recipe information enabling recipe editing content management,
  /// form state coordination, and comprehensive user interaction functionality.
  final Recipe recipe;

  /// Creates recipe editing view content with focused component architecture and lifecycle management.
  /// 
  /// [recipe] Recipe data model for content editing and collaborative coordination
  /// 
  /// Establishes recipe editing content with component delegation, form management,
  /// and comprehensive user interaction coordination through stateful architecture.
  const _EditRecipeViewContent({required this.recipe});

  /// Creates recipe editing view content state with component coordination and lifecycle management.
  /// 
  /// Establishes stateful recipe editing content enabling form state management,
  /// component coordination, and comprehensive user interaction handling
  /// through proper state lifecycle and focused component delegation.
  @override
  State<_EditRecipeViewContent> createState() => _EditRecipeViewContentState();
}

/// Recipe editing view content state managing form validation, component delegation, and user interaction coordination.
///
/// Handles complete recipe editing state management including form key management, component delegation,
/// loading state coordination, and user interaction handling while maintaining clean
/// focused component architecture and proper lifecycle management through comprehensive integration.
class _EditRecipeViewContentState extends State<_EditRecipeViewContent> {
  /// Global form key for comprehensive form validation and submission coordination.
  /// 
  /// Manages form validation state enabling comprehensive input validation,
  /// submission coordination, and form state management throughout editing workflow.
  final _formKey = GlobalKey<FormState>();

  /// Comprehensive recipe editing interface construction with focused components and collaborative features.
  /// 
  /// [context] Build context for theme access and component construction coordination
  /// 
  /// Constructs complete recipe editing interface featuring focused component architecture,
  /// collaborative status integration, loading overlay management, and comprehensive
  /// form functionality through consumer-based state management and component delegation.
  /// 
  /// **Interface Architecture:**
  /// - Consumer-based state management with RecipeFormViewModel reactive coordination
  /// - Scaffold structure with comprehensive AppBar, body, and bottom navigation integration
  /// - Focused component delegation with specialized edit recipe modules
  /// - Loading overlay with progress indication and user feedback coordination
  /// - Smart banner integration with collaborative status and permission indicators
  /// 
  /// **Component Integration:**
  /// - EditRecipeAppBar for collaborative status display and navigation management
  /// - EditRecipeBottomBar for permission-based action buttons with save and fork functionality
  /// - EditRecipeBanners for smart status banners and collaborative indicators
  /// - EditRecipeFormFields for comprehensive form fields with validation and input management
  /// - Loading overlay with StateWidget integration and progress indication
  /// 
  /// **Collaborative Features:**
  /// - Collaborative status awareness with permission management and user coordination
  /// - Smart banners with collaborative indicators and status display
  /// - Permission-based actions with save and fork functionality coordination
  /// - Loading state management with operation progress and user experience optimization
  /// 
  /// Returns complete recipe editing interface with comprehensive functionality and focused component architecture.
  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecipeFormViewModel>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (!didPop) {
          if (viewModel.hasUnsavedChanges) {
            final shouldPop = await _showUnsavedChangesDialog(context) ?? false;
            if (shouldPop && context.mounted) {
              Navigator.of(context).pop();
            }
          } else {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
      // AppBar with collaborative status
      appBar: EditRecipeAppBar.build(context, widget.recipe),

      // Permissions-based bottom navigation bar
      bottomNavigationBar: EditRecipeBottomBar.build(
        context,
        () => _saveRecipe(context),
        () => _forkRecipe(context),
      ),

      body: Stack(
        children: [
          // Main content with banners and form
          Column(
            children: [
              // Smart banners (collaborative + permissions)
              EditRecipeBanners.buildSmartBanners(context, widget.recipe),
              
              // Form content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.paddingL,
                    AppDimensions.spacingXl, // More top padding for dropdown label
                    AppDimensions.paddingL,
                    AppDimensions.paddingL,
                  ),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: EditRecipeFormFields.buildFormFields(context, viewModel),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Loading overlay
          if (viewModel.isSaving)
            ColoredBox(
              color: AppColors.backgroundBeige.withValues(alpha: 0.8),
              child: Center(
                child: StateWidget.loading(
                  message: 'Uppdaterar recept...',
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }

  /// ARCHITECTURAL FIX: Form validation moved inside view to fix encapsulation violation
  /// Save recipe with form validation handled internally
  Future<void> _saveRecipe(BuildContext context) async {
    // Perform form validation within the view that owns the form
    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate()) {
      AppLogger.warning('Form validation failed for recipe save');
      return;
    }

    AppLogger.info('Form validation passed, proceeding with recipe save');
    // Only call action after validation passes - no form key needed
    await EditRecipeActions.saveRecipe(context, widget.recipe.id);
  }

  /// ARCHITECTURAL FIX: Form validation moved inside view to fix encapsulation violation  
  /// Fork recipe with form validation handled internally
  Future<void> _forkRecipe(BuildContext context) async {
    // Perform form validation within the view that owns the form
    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate()) {
      AppLogger.warning('Form validation failed for recipe fork');
      return;
    }

    AppLogger.info('Form validation passed, proceeding with recipe fork');
    // Only call action after validation passes - no form key needed
    await EditRecipeActions.forkRecipe(context);
  }

  /// Shows confirmation dialog for unsaved changes
  Future<bool?> _showUnsavedChangesDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Osparade ändringar'),
        content: const Text('Du har osparade ändringar. Vill du verkligen lämna utan att spara?'),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: 'Fortsätt redigera',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ActionButtons.primaryButton(
            context,
            label: 'Lämna utan att spara',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
  @override
  void dispose() {
    // HIGH PRIORITY FIX: Proper resource disposal to prevent memory leaks
    // No specific resources to dispose in this stateful widget as it only manages UI state
    // The ViewModels are disposed automatically by their respective ChangeNotifierProviders
    // Form key doesn't need disposal as it's automatically cleaned up
    AppLogger.debug('EditRecipeView disposed');
    super.dispose();
  }
}