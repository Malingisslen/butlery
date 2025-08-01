/// Comprehensive recipe detail view providing advanced recipe interaction and social engagement for Flutter applications.
///
/// This module implements sophisticated recipe detail presentation following Single Responsibility Principle,
/// specializing in recipe display, portion scaling, social interaction, and comprehensive recipe management.
/// It provides complete recipe detail interface while maintaining clean separation from business logic,
/// data persistence, and state management through MVVM architecture and modular component integration.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles recipe detail UI presentation concerns:
/// - **Recipe Presentation Excellence**: Comprehensive recipe display with metadata, content, and visual elements
/// - **Portion Scaling Intelligence**: Advanced portion scaling with ingredient calculations and user control
/// - **Social Interaction System**: Complete comment system with engagement tracking and social features
/// - **Multi-Image Management**: Sophisticated image carousel with fullscreen viewing and navigation
/// - **Action Management**: Comprehensive recipe actions including editing, sharing, and deletion coordination
///
/// **What This Module Does NOT Handle:**
/// - Recipe business logic and data operations (handled by RecipeDetailViewModel and services)
/// - Social interaction business logic (handled by SocialRecipeViewModel and social services)
/// - Image processing and storage (handled by image services and cloud storage)
/// - Navigation logic and routing (handled by application routing and navigation services)
///
/// **Recipe Detail View Architecture:**
/// - **Modular Component Integration**: Clean separation through specialized detail components (metadata, content, actions)
/// - **Multi-Provider Architecture**: Comprehensive state management with RecipeDetailViewModel and SocialRecipeViewModel
/// - **Responsive Design**: Optimized layout for different screen sizes and orientations
/// - **Social Integration**: Complete social features with collaborative banners and comment system
/// - **Action Delegation**: Clean action handling through RecipeDetailActions module
///
/// **Usage Examples:**
/// ```dart
/// // Navigate to recipe detail view
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => RecipeDetailView(recipe: selectedRecipe),
///   ),
/// );
/// 
/// // The view provides comprehensive recipe interaction:
/// // - Recipe metadata display with portions, time, and rating
/// // - Recipe content with ingredients, instructions, and images
/// // - Portion scaling with real-time ingredient calculations
/// // - Social features with comments and collaborative indicators
/// // - Action management with editing, sharing, and deletion
/// 
/// // Integration with specialized components:
/// // - RecipeDetailMetadata for recipe metadata presentation
/// // - RecipeDetailContent for recipe content and portion scaling
/// // - RecipeDetailComments for social interaction and engagement
/// // - RecipeDetailActions for action handling and user operations
/// ```

// lib/views/recipe_detail_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';

// Import all recipe detail modules for modular architecture
import 'package:butlery/views/recipe_detail/recipe_detail_actions.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_metadata.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_content.dart';
import 'package:butlery/widgets/recipe/recipe_detail_comments.dart';
/// Comprehensive recipe detail view providing advanced recipe interaction through multi-provider architecture.
///
/// Manages complete recipe detail presentation enabling recipe display, portion scaling, social interaction,
/// and comprehensive recipe management while maintaining clean separation between UI presentation
/// and business logic through MVVM architecture and specialized component integration.
///
/// **Core Responsibilities:**
/// - Advanced recipe presentation with metadata, content, and visual element coordination
/// - Multi-provider state management with RecipeDetailViewModel and SocialRecipeViewModel integration
/// - Modular component architecture with specialized detail components and action handling
/// - Social interaction coordination with comment system and collaborative feature integration
/// - Responsive design implementation with comprehensive layout and user experience optimization
class RecipeDetailView extends StatelessWidget {
  /// Recipe data model for detail presentation and interaction coordination.
  /// 
  /// Stores complete recipe information enabling recipe detail display,
  /// portion scaling, social interaction, and comprehensive recipe management.
  final Recipe recipe;

  /// Creates comprehensive recipe detail view with multi-provider architecture and component integration.
  /// 
  /// [recipe] Recipe data model for detail presentation and interaction coordination
  /// 
  /// Establishes recipe detail interface with multi-provider state management,
  /// modular component integration, and comprehensive recipe interaction functionality
  /// through clean architectural separation and responsive design coordination.
  const RecipeDetailView({super.key, required this.recipe});

  /// Comprehensive multi-provider widget construction with state management and component integration.
  /// 
  /// [context] Build context for provider creation and widget construction coordination
  /// 
  /// Constructs recipe detail view with multi-provider architecture enabling comprehensive
  /// state management, business logic separation, and component integration through
  /// RecipeDetailViewModel and SocialRecipeViewModel coordination.
  /// 
  /// **Multi-Provider Architecture:**
  /// - RecipeDetailViewModel for recipe state management and business logic coordination
  /// - SocialRecipeViewModel for social interaction and comment system management
  /// - Service locator integration for dependency injection and service coordination
  /// - Clean state management with provider-based reactive architecture
  /// 
  /// Returns multi-provider recipe detail view with comprehensive state management.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Recipe detail state management with service integration
        ChangeNotifierProvider(
          create: (_) => RecipeDetailViewModel(
            recipe: recipe,
            recipeService: ServiceLocator.get(),
            analyticsService: ServiceLocator.get(),
          ),
        ),
        // Social interaction state management for comment system
        ChangeNotifierProvider(
          create: (_) => SocialRecipeViewModel(
            friendsService: ServiceLocator.get(),
          ),
        ),
        // Additional recipe detail view model for extended functionality
        ChangeNotifierProvider<RecipeDetailViewModel>(
          create: (_) => ServiceLocator.get<RecipeDetailViewModel>(),
        ),
      ],
      child: _RecipeDetailViewContent(recipe: recipe),
    );
  }
}

/// Recipe detail view content managing actions, state, and component coordination through stateful architecture.
///
/// Handles complete recipe detail presentation lifecycle including action initialization,
/// component coordination, and user interaction management while maintaining clean
/// state management and proper action delegation through RecipeDetailActions integration.
class _RecipeDetailViewContent extends StatefulWidget {
  /// Recipe data model for content presentation and interaction coordination.
  /// 
  /// Stores complete recipe information enabling recipe detail content display,
  /// action management, and comprehensive user interaction functionality.
  final Recipe recipe;

  /// Creates recipe detail view content with action management and component integration.
  /// 
  /// [recipe] Recipe data model for content presentation and interaction coordination
  /// 
  /// Establishes recipe detail content with action delegation, component coordination,
  /// and comprehensive user interaction management through stateful architecture.
  const _RecipeDetailViewContent({required this.recipe});

  /// Creates recipe detail view content state with action management and lifecycle coordination.
  /// 
  /// Establishes stateful recipe detail content enabling action initialization,
  /// component coordination, and comprehensive user interaction management
  /// through proper state lifecycle and action delegation coordination.
  @override
  State<_RecipeDetailViewContent> createState() => _RecipeDetailViewContentState();
}

/// Recipe detail view content state managing action delegation and component lifecycle coordination.
///
/// Handles complete recipe detail state management including action initialization,
/// component coordination, and user interaction handling while maintaining clean
/// action delegation and proper lifecycle management through RecipeDetailActions integration.
class _RecipeDetailViewContentState extends State<_RecipeDetailViewContent> {
  /// Recipe detail actions manager for comprehensive action delegation and user interaction handling.
  /// 
  /// Manages all recipe detail actions including editing, sharing, deletion, portion scaling,
  /// and image viewing enabling clean action delegation and comprehensive user interaction.
  final RecipeDetailActions _actions = RecipeDetailActions();
  
  /// Action initialization with context binding and lifecycle preparation.
  /// 
  /// Initializes recipe detail actions enabling comprehensive user interaction,
  /// portion scaling, image viewing, and action delegation through proper
  /// context binding and lifecycle management coordination.
  /// 
  /// **Initialization Process:**
  /// - Action manager initialization with context binding and state preparation
  /// - Component lifecycle coordination with proper resource management
  /// - User interaction preparation with action delegation and event handling
  @override
  void initState() {
    super.initState();
    _actions.initializeActions(context);
  }

  /// Comprehensive recipe detail interface construction with modular components and action integration.
  /// 
  /// [context] Build context for theme access and component construction coordination
  /// 
  /// Constructs complete recipe detail interface featuring modular component architecture,
  /// action management, social interaction, and comprehensive recipe presentation through
  /// consumer-based state management and specialized component integration.
  /// 
  /// **Interface Architecture:**
  /// - Consumer-based state management with RecipeDetailViewModel reactive coordination
  /// - Modular component integration with specialized detail components
  /// - Action toolbar with editing, sharing, and deletion functionality
  /// - Social integration with comment system and collaborative features
  /// - Responsive layout with optimized spacing and user experience coordination
  /// 
  /// **Component Integration:**
  /// - RecipeDetailMetadata for portions, time, rating, and source information
  /// - RecipeDetailContent for description, ingredients, instructions, and images
  /// - RecipeDetailComments for social interaction and engagement features
  /// - RecipeDetailActions for comprehensive action delegation and user operations
  /// 
  /// Returns complete recipe detail interface with comprehensive functionality.
  @override
  Widget build(BuildContext context) {
    return Consumer<RecipeDetailViewModel>(
      builder: (context, viewModel, child) {
        final recipe = viewModel.recipe;
        
        return LayoutComponents.mainMenu(
          body: SingleChildScrollView(
            padding: AppDimensions.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recipe header with title and collaborative indicators
                _buildHeader(context, viewModel),
                const SizedBox(height: AppDimensions.spacingXl),
                
                // Recipe metadata with portions, time, rating, and source
                RecipeDetailMetadata(
                  viewModel: viewModel,
                  currentPortions: _actions.currentPortions,
                  isScaled: _actions.currentPortions != recipe.portions,
                ),
                const SizedBox(height: AppDimensions.spacingXl),
                
                // Recipe content with ingredients, instructions, and images
                RecipeDetailContent(
                  viewModel: viewModel,
                  scaledIngredients: _actions.scaledIngredients,
                  onPortionChanged: _actions.onPortionChanged,
                  onImageTap: (imageUrls, index) => _actions.showFullscreenImages(
                    context,
                    imageUrls,
                    initialIndex: index,
                  ),
                ),
                
                // Social comments section with engagement features
                Consumer<SocialRecipeViewModel>(
                  builder: (context, socialViewModel, child) {
                    return RecipeDetailComments(
                      socialViewModel: socialViewModel,
                      recipeId: viewModel.recipe.id,
                      onCommentPosted: () {
                        // Optional post-comment actions for enhanced user experience
                      },
                    );
                  },
                ),
                
                // Bottom spacing for optimal user experience
                const SizedBox(height: AppDimensions.spacingXxxl),
              ],
            ),
          ),
          title: recipe.title,
          actions: [
            // Recipe editing button with accessibility
            IconButton(
              onPressed: () => _actions.editRecipe(context),
              icon: const Icon(Icons.edit),
              tooltip: 'Redigera recept',
            ),
            
            // Comprehensive actions menu with sharing and management
            PopupMenuButton<String>(
              onSelected: (action) => _handleAction(context, action, viewModel),
              itemBuilder: (context) => [
                // System sharing option
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share, size: AppDimensions.iconSizeAction),
                      SizedBox(width: AppDimensions.spacingM),
                      Text('Dela'),
                    ],
                  ),
                ),
                // Social sharing with friends
                const PopupMenuItem(
                  value: 'share_social',
                  child: Row(
                    children: [
                      Icon(Icons.people, size: AppDimensions.iconSizeAction),
                      SizedBox(width: AppDimensions.spacingM),
                      Text('Dela med vänner'),
                    ],
                  ),
                ),
                // Recipe deletion with confirmation
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete,
                        size: AppDimensions.iconSizeAction,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: AppDimensions.spacingM),
                      Text(
                        'Ta bort',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Comprehensive recipe header construction with title and collaborative features coordination.
  /// 
  /// [context] Build context for theme access and component construction coordination
  /// [viewModel] RecipeDetailViewModel instance for recipe data access and state management
  /// 
  /// Constructs recipe detail header featuring recipe title, collaborative indicators,
  /// and visual design elements enabling recipe identification and social feature
  /// presentation through comprehensive header design and component integration.
  /// 
  /// **Header Features:**
  /// - Recipe title presentation with enhanced typography and visual hierarchy
  /// - Collaborative banner integration with social feature indicators
  /// - Card-based design with consistent theming and visual elements
  /// - Responsive layout with proper spacing and alignment coordination
  /// 
  /// Returns recipe header widget with title and collaborative feature integration.
  Widget _buildHeader(BuildContext context, RecipeDetailViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipe title with enhanced typography
          Text(
            viewModel.recipe.title,
            style: AppTextStyles.sectionTitleStyle.copyWith(
              fontSize: AppTextStyles.displaySmall.fontSize,
            ),
          ),
          
          // Collaborative banner for social feature indication
          SocialComponents.smartCollaborativeBanner(
            context: context,
            contentId: viewModel.recipe.id,
          ),
        ],
      ),
    );
  }

  /// Comprehensive action handling with delegation and user interaction coordination.
  /// 
  /// [context] Build context for action execution and user interface coordination
  /// [action] Action identifier for action type determination and delegation
  /// [viewModel] RecipeDetailViewModel instance for recipe state access and management
  /// 
  /// Handles comprehensive recipe detail actions including sharing, social sharing,
  /// and deletion through action delegation and user interaction management enabling
  /// complete recipe management functionality with proper action coordination.
  /// 
  /// **Action Handling Features:**
  /// - Action delegation to RecipeDetailActions for clean separation of concerns
  /// - Comprehensive action support including sharing, social sharing, and deletion
  /// - User interaction coordination with proper context and state management
  /// - Asynchronous action handling with proper error handling and user feedback
  /// 
  /// **Supported Actions:**
  /// - `'share'`: Recipe sharing with system share dialog and content distribution
  /// - `'share_social'`: Social sharing with friend selection and social platform integration
  /// - `'delete'`: Recipe deletion with confirmation dialog and data management
  Future<void> _handleAction(
    BuildContext context,
    String action,
    RecipeDetailViewModel viewModel,
  ) async {
    switch (action) {
      case 'share':
        await _actions.shareRecipe(context);
        break;
      case 'share_social':
        await _actions.showSocialShareDialog(context);
        break;
      case 'delete':
        await _actions.deleteRecipe(context);
        break;
    }
  }
}