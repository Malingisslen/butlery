/// Comprehensive recipe form ViewModel providing advanced recipe creation and editing for Flutter applications.
///
/// This module implements sophisticated recipe form management following Single Responsibility Principle,
/// handling all aspects of recipe creation and editing through focused manager architecture including form state management,
/// collaborative editing, image management, and permission coordination. It provides complete recipe form infrastructure
/// while maintaining clean separation from UI rendering, data persistence, and business logic implementation.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles recipe form presentation layer concerns through specialized manager delegation:
/// - **Form State Excellence**: Comprehensive recipe form state management with validation, change tracking, and data coordination
/// - **Collaborative Editing Intelligence**: Advanced real-time collaborative editing with live participant tracking and conflict resolution
/// - **Image Management System**: Sophisticated multi-image upload, ordering, and storage coordination with performance optimization
/// - **Permission Management**: Comprehensive permission system with role-based access control and collaborative sharing
/// - **Manager Architecture**: Clean delegation to focused managers for maintainable and scalable recipe form functionality
///
/// **What This Module Does NOT Handle:**
/// - UI rendering and widget creation (handled by RecipeFormView and recipe form UI components)
/// - Recipe data persistence and storage (handled by UnifiedRecipeService and data repositories)
/// - Image processing and storage operations (handled by specialized image services and cloud storage)
/// - Collaborative infrastructure implementation (handled by Firebase and real-time synchronization services)
///
/// **Recipe Form ViewModel Architecture:**
/// - **RecipeFormState**: Comprehensive form state management with validation and data coordination
/// - **RecipeCollaborativeManager**: Real-time collaborative editing with participant management and synchronization
/// - **RecipeImageManager**: Multi-image upload, ordering, and storage management with performance optimization
/// - **RecipePermissionManager**: Permission system with role-based access control and sharing capabilities
/// - **Focused Manager Pattern**: Clean delegation architecture for maintainable and scalable functionality
///
/// **Usage Examples:**
/// ```dart
/// // Initialize recipe form ViewModel for creation
/// final recipeFormViewModel = RecipeFormViewModel(
///   recipeService: unifiedRecipeService,
///   analyticsService: analyticsService,
/// );
/// 
/// // Initialize for editing existing recipe
/// final editFormViewModel = RecipeFormViewModel(
///   recipeService: unifiedRecipeService,
///   initialRecipe: existingRecipe,
/// );
/// 
/// // Form data management
/// recipeFormViewModel.setTitle('Vegetarisk Pasta Carbonara');
/// recipeFormViewModel.setDescription('Krämig pasta med vegetariska alternativ');
/// recipeFormViewModel.setMealType('Middag');
/// recipeFormViewModel.setPortions(4);
/// recipeFormViewModel.setTimeMinutes(30);
/// 
/// // Dynamic list management
/// recipeFormViewModel.addIngredient();
/// recipeFormViewModel.updateIngredient(0, '200g pasta');
/// recipeFormViewModel.addInstruction();
/// recipeFormViewModel.updateInstruction(0, 'Koka pastan al dente');
/// 
/// // Image management
/// await recipeFormViewModel.pickAndUploadImage(context);
/// recipeFormViewModel.setPrimaryImage(imageUrl);
/// recipeFormViewModel.reorderImages(0, 2);
/// 
/// // Recipe operations
/// final savedRecipe = await recipeFormViewModel.saveRecipe();
/// final forkedRecipe = await recipeFormViewModel.forkRecipe();
/// final deleted = await recipeFormViewModel.deleteRecipe();
/// 
/// // Collaborative features
/// await recipeFormViewModel.enableCollaborativeMode();
/// await recipeFormViewModel.inviteUserToCollaboration(
///   'user123', 'Anna Svensson', ResourcePermission.editor
/// );
/// 
/// // Form state monitoring
/// if (recipeFormViewModel.hasUnsavedChanges) {
///   // Show save prompt
/// }
/// if (recipeFormViewModel.isSaving) {
///   // Show saving progress
/// }
/// ```

// lib/viewmodels/recipe_form_viewmodel.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';

// Import focused managers
import 'package:butlery/viewmodels/recipe_form/recipe_form_state.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_collaborative_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_image_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_permission_manager.dart';

// ===== FOCUSED MANAGER ARCHITECTURE =====

/// Comprehensive recipe form ViewModel providing advanced recipe creation and editing through focused manager architecture.
///
/// Serves as the main coordinator for all recipe form operations, delegating to specialized managers
/// for form state, collaborative editing, image management, and permission control while maintaining
/// clean MVVM architecture separation between recipe form business logic and UI presentation concerns.
class RecipeFormViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final UnifiedRecipeService _recipeService;
  // final AnalyticsService _analyticsService; // Currently unused
  final _uuid = const Uuid();

  // ===== FOCUSED MANAGER ARCHITECTURE =====
  
  /// Form state manager for comprehensive recipe data and validation coordination.
  late final RecipeFormState _state;
  
  /// Collaborative editing manager for real-time synchronization and participant management.
  late final RecipeCollaborativeManager _collaborativeManager;
  
  /// Image management system for multi-image upload, ordering, and storage coordination.
  late final RecipeImageManager _imageManager;
  
  /// Permission management system for access control and collaborative sharing.
  late final RecipePermissionManager _permissionManager;

  /// Initializes recipe form ViewModel with comprehensive manager coordination and service integration.
  /// 
  /// [recipeService] Optional UnifiedRecipeService instance for dependency injection
  /// [analyticsService] Optional AnalyticsService instance for analytics tracking
  /// [initialRecipe] Optional existing recipe for editing mode initialization
  /// [isTemplate] Whether initializing as template for recipe creation patterns
  /// 
  /// Establishes focused manager architecture with specialized components for recipe form management,
  /// sets up reactive state coordination, and initializes permission systems for complete
  /// recipe creation and editing functionality with collaborative features.
  RecipeFormViewModel({
    UnifiedRecipeService? recipeService,
    AnalyticsService? analyticsService,
    Recipe? initialRecipe,
    bool isTemplate = false,
  }) : _recipeService = recipeService ?? ServiceLocator.get<UnifiedRecipeService>() {
       // _analyticsService = analyticsService ?? ServiceLocator.get<AnalyticsService>();
    
    // Initialize focused managers
    _state = RecipeFormState(initialRecipe: initialRecipe, isTemplate: isTemplate);
    _collaborativeManager = RecipeCollaborativeManager();
    _imageManager = RecipeImageManager();
    _permissionManager = RecipePermissionManager();

    // Set up listeners
    _setupManagerListeners();

    // Load permissions if editing existing recipe
    if (initialRecipe != null && !isTemplate) {
      _loadInitialPermissions(initialRecipe);
    }
  }

  // ===== FORM STATE ACCESSORS (DELEGATE TO SPECIALIZED MANAGERS) =====

  /// Original recipe data for editing mode and change comparison functionality.
  /// 
  /// Delegates to RecipeFormState for original recipe access enabling
  /// edit mode initialization and unsaved changes detection.
  Recipe? get originalRecipe => _state.originalRecipe;
  
  /// Save operation state for UI progress indication and interaction control.
  /// 
  /// Provides real-time save status for loading indicators and user interaction
  /// management during recipe save operations and form submission.
  bool get isSaving => _state.isSaving;
  
  /// Fork operation state for UI progress indication and copy functionality.
  /// 
  /// Indicates active recipe forking operation for progress display
  /// and interaction control during recipe duplication processes.
  bool get isForking => _state.isForking;
  
  /// Current error message for user feedback and error state management.
  /// 
  /// Delegates to RecipeFormState for centralized error handling with localized
  /// Swedish error messages for comprehensive user feedback and error recovery.
  String? get error => _state.error;
  
  /// Error state indicator for UI conditional rendering and error handling.
  /// 
  /// Provides boolean error state check for UI error display decisions
  /// and error state management throughout recipe form operations.
  bool get hasError => _state.hasError;
  
  /// Editing mode indicator for form behavior and UI conditional rendering.
  /// 
  /// Indicates whether form is in edit mode for existing recipe modification
  /// versus creation mode for new recipe functionality.
  bool get isEditing => _state.isEditing;
  
  /// Form validation state for submission control and UI enabling.
  /// 
  /// Combines all form validation requirements for form submission enabling
  /// and comprehensive validation status across all form fields.
  bool get isValid => _state.isValid;
  
  /// Unsaved changes detection for navigation prompts and data protection.
  /// 
  /// Compares current form state with original recipe data to detect modifications
  /// requiring user confirmation before navigation or form abandonment.
  /// Essential for preventing data loss and providing proper user experience.
  bool get hasUnsavedChanges {
    if (!isEditing || originalRecipe == null) return false;
    // Simple check - if any basic field has changed
    return title != (originalRecipe?.core.title ?? '') ||
           description != (originalRecipe?.core.description ?? '') ||
           mealType != (originalRecipe?.core.mealType ?? 'Middag');
  }

  // ===== RECIPE FORM DATA ACCESSORS =====

  /// Recipe title for form display and validation coordination.
  /// 
  /// Delegates to RecipeFormState for title access enabling UI binding
  /// and form validation throughout recipe creation and editing operations.
  String get title => _state.title;
  
  /// Recipe description for detailed content management and form coordination.
  /// 
  /// Provides access to recipe description for UI display and validation
  /// enabling comprehensive recipe content management and user input coordination.
  String get description => _state.description;
  
  /// Meal type selection for categorization and Swedish localized meal planning.
  /// 
  /// Provides meal type access with Swedish localization support for
  /// recipe categorization and meal planning functionality.
  String get mealType => _state.mealType;
  
  /// Portion count for serving size management and recipe scaling.
  /// 
  /// Provides portion information for recipe serving calculations
  /// and meal planning coordination with nullable support for optional data.
  int? get portions => _state.portions;
  
  /// Cooking time in minutes for meal planning and recipe organization.
  /// 
  /// Provides cooking time information for meal planning calculations
  /// and recipe filtering with nullable support for optional timing data.
  int? get timeMinutes => _state.timeMinutes;
  
  /// Recipe rating for quality assessment and recipe recommendation.
  /// 
  /// Provides rating information for recipe quality indication
  /// and recommendation systems with nullable support for unrated recipes.
  double? get rating => _state.rating;
  
  /// Image URLs for visual recipe presentation and gallery management.
  /// 
  /// Delegates to RecipeFormState for image URL access enabling
  /// multi-image display and visual recipe presentation coordination.
  List<String> get imageUrls => _state.imageUrls;
  
  /// Source URL for recipe attribution and external reference management.
  /// 
  /// Provides source URL access for recipe attribution and external linking
  /// with nullable support for original recipes without external sources.
  String? get sourceUrl => _state.sourceUrl;
  
  /// Ingredient list for recipe content management and shopping integration.
  /// 
  /// Delegates to RecipeFormState for ingredient access enabling
  /// dynamic ingredient management and shopping list integration.
  List<String> get ingredients => _state.ingredients;
  
  /// Instruction list for cooking guidance and recipe execution.
  /// 
  /// Provides instruction access for step-by-step cooking guidance
  /// and recipe execution with dynamic instruction management capabilities.
  List<String> get instructions => _state.instructions;
  
  /// Tag list for recipe organization and search functionality.
  /// 
  /// Delegates to RecipeFormState for tag access enabling
  /// recipe categorization and advanced search functionality.
  List<String> get tags => _state.tags;

  // ===== SPECIALIZED MANAGER ACCESSORS =====
  
  /// Ingredients manager for dynamic ingredient list coordination and management.
  /// 
  /// Provides access to specialized ingredient management functionality
  /// enabling dynamic list operations and form field coordination.
  get ingredientsManager => _state.ingredientsManager;
  
  /// Instructions manager for dynamic instruction list coordination and management.
  /// 
  /// Provides access to specialized instruction management functionality
  /// enabling step-by-step recipe guidance and dynamic list operations.
  get instructionsManager => _state.instructionsManager;
  
  /// Tags manager for dynamic tag list coordination and organization.
  /// 
  /// Provides access to specialized tag management functionality
  /// enabling recipe categorization and dynamic tag operations.
  get tagsManager => _state.tagsManager;

  // ===== COLLABORATIVE EDITING ACCESSORS =====
  
  /// Collaborative mode indicator for real-time editing functionality and UI coordination.
  /// 
  /// Indicates whether recipe form is in collaborative mode enabling
  /// real-time synchronization and multi-user editing features.
  bool get isCollaborative => _collaborativeManager.isCollaborative;
  
  /// Firebase connection status for collaborative infrastructure and connectivity indication.
  /// 
  /// Provides real-time connection status for collaborative editing infrastructure
  /// enabling connection feedback and collaborative feature availability.
  bool get isConnectedToFirebase => _collaborativeManager.isConnectedToFirebase;
  
  /// Connection status text for user feedback and collaborative state display.
  /// 
  /// Provides Swedish localized connection status messages for user feedback
  /// and collaborative editing state indication in the user interface.
  String get connectionStatusText => _collaborativeManager.connectionStatusText;
  
  /// Collaborative participants for participant management and social coordination.
  /// 
  /// Provides list of active collaborative participants enabling
  /// participant display and collaborative member management functionality.
  List<UserProfile> get collaborativeParticipants => _collaborativeManager.collaborativeParticipants;
  
  /// Live editors for real-time presence indication and collaborative awareness.
  /// 
  /// Provides access to currently active editors enabling
  /// real-time presence indication and collaborative editing awareness.
  get liveEditors => _collaborativeManager.liveEditors;

  // ===== IMAGE MANAGEMENT ACCESSORS =====
  
  /// Image upload operation state for UI progress indication and interaction control.
  /// 
  /// Indicates active image upload operation for progress display
  /// and user interaction management during image processing operations.
  bool get isUploadingImage => _imageManager.isUploadingImage;
  
  /// Image upload error message for user feedback and error handling.
  /// 
  /// Provides localized error messages from image upload operations
  /// for user display and comprehensive error state management.
  String? get imageUploadError => _imageManager.imageUploadError;
  
  /// Image upload error state indicator for UI conditional rendering and error handling.
  /// 
  /// Indicates presence of image upload errors for UI error display decisions
  /// and error state management throughout image operations.
  bool get hasImageUploadError => _imageManager.hasImageUploadError;
  
  /// Image addition capability indicator for UI control and limit enforcement.
  /// 
  /// Indicates whether additional images can be added based on image limits
  /// enabling UI control state and image limit enforcement.
  bool get canAddMoreImages => _imageManager.canAddMoreImages;

  // ===== PERMISSION SYSTEM ACCESSORS =====
  
  /// Edit permission for form modification and content management functionality.
  /// 
  /// Indicates whether user has edit permission for recipe form modification
  /// enabling comprehensive form editing and content management capabilities.
  bool get canEdit => _permissionManager.canEdit;
  
  /// View permission for recipe form display and content access functionality.
  /// 
  /// Indicates whether user has view permission for recipe form display
  /// enabling content access and form viewing capabilities.
  bool get canView => _permissionManager.canView;
  
  /// Share permission for collaborative features and recipe distribution functionality.
  /// 
  /// Indicates whether user has share permission for collaborative sharing
  /// enabling recipe distribution and collaborative feature access.
  bool get canShare => _permissionManager.canShare;
  
  /// Invite permission for collaborative member management and invitation functionality.
  /// 
  /// Indicates whether user has invite permission for collaborative invitations
  /// enabling member management and collaborative team building.
  bool get canInvite => _permissionManager.canInvite;
  
  /// Delete permission for recipe removal and cleanup operations.
  /// 
  /// Indicates whether user has delete permission for recipe removal
  /// enabling comprehensive recipe management and cleanup functionality.
  bool get canDelete => _permissionManager.canDelete;
  
  /// Owner status for administrative functions and comprehensive recipe management.
  /// 
  /// Indicates whether user is recipe owner enabling administrative functions
  /// and comprehensive recipe management capabilities.
  bool get isOwner => _permissionManager.isOwner;
  
  /// Permission availability indicator for UI conditional rendering and feature enabling.
  /// 
  /// Indicates whether user has any permissions for UI conditional display
  /// and feature availability throughout recipe form functionality.
  bool get hasPermissions => _permissionManager.hasPermissions;

  // ===== FORM CONFIGURATION CONSTANTS =====
  
  /// Available meal types for Swedish localized meal categorization and selection.
  /// 
  /// Provides comprehensive meal type options with Swedish localization
  /// for recipe categorization and meal planning functionality.
  static const List<String> mealTypes = RecipeFormState.mealTypes;
  
  /// Maximum image limit for performance optimization and storage management.
  /// 
  /// Defines maximum number of images per recipe for performance optimization
  /// and storage resource management throughout image operations.
  static const int maxImages = RecipeFormState.maxImages;

  // ===== RECIPE MANAGEMENT OPERATIONS =====

  /// Saves recipe with comprehensive validation, service coordination, and collaborative synchronization.
  /// 
  /// Returns saved Recipe instance if successful, null if validation fails or save errors occur.
  /// Performs complete recipe save flow including validation, permission checking, service coordination,
  /// and collaborative state management for comprehensive recipe persistence and synchronization.
  /// 
  /// **Save Process:**
  /// - Form validation with comprehensive field checking
  /// - Permission validation for save operation authorization
  /// - Service-coordinated recipe persistence with error handling
  /// - Collaborative state synchronization for real-time updates
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final savedRecipe = await recipeFormViewModel.saveRecipe();
  /// if (savedRecipe != null) {
  ///   // Navigate to recipe detail or show success
  /// } else {
  ///   // Display validation errors or save failure
  /// }
  /// ```
  Future<Recipe?> saveRecipe() async {
    if (!_state.isValid) {
      _state.setError('Fyll i alla obligatoriska fält');
      return null;
    }

    if (!canEdit) {
      _state.setError('Du har inte behörighet att spara detta recept');
      return null;
    }

    _state.setSaving(true);
    _state.clearError();

    try {
      return await safeExecute<Recipe>(
        () async {
          // Skapa recept från state
          final recipe = _state.createRecipe(
            recipeId: _state.isEditing ? _state.originalRecipe!.id : _uuid.v4(),
          );

          // Spara via service
          Recipe savedRecipe;
          if (_state.isEditing) {
            final result = await _recipeService.personal.updateUnifiedRecipe(recipe);
            if (result.isSuccess) {
              savedRecipe = recipe;
            } else {
              throw Exception(result.message ?? 'Failed to update recipe');
            }
          } else {
            final result = await _recipeService.personal.addUnifiedRecipe(recipe);
            if (result.isSuccess) {
              savedRecipe = recipe;
            } else {
              throw Exception(result.message ?? 'Failed to create recipe');
            }
          }

          // Uppdatera collaborative state om aktivt
          if (isCollaborative) {
            await _collaborativeManager.updateRecipeInFirebase(savedRecipe);
          }

          AppLogger.info('Recept sparat: ${savedRecipe.id}');
          return savedRecipe;
        },
        operationName: 'Save Recipe',
        customErrorMessage: null, // Handle error with custom logic below
      );
    } catch (e) {
      AppLogger.error('Fel vid sparande av recept: $e');
      _state.setError('Kunde inte spara recept: $e');
      return null;
    } finally {
      _state.setSaving(false);
    }
  }

  /// Forks recipe creating independent copy with comprehensive duplication and state management.
  /// 
  /// Returns forked Recipe instance if successful, null if operation fails.
  /// Performs complete recipe forking flow including data duplication, service coordination,
  /// and analytics tracking for comprehensive recipe copy functionality and user workflow support.
  /// 
  /// **Fork Process:**
  /// - Recipe data duplication with new unique identifier
  /// - Service-coordinated recipe creation with error handling
  /// - Analytics tracking for fork operation monitoring
  /// - State management with progress indication
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final forkedRecipe = await recipeFormViewModel.forkRecipe();
  /// if (forkedRecipe != null) {
  ///   // Navigate to forked recipe or show success
  /// } else {
  ///   // Handle fork failure
  /// }
  /// ```
  Future<Recipe?> forkRecipe() async {
    if (_state.originalRecipe == null) {
      _state.setError('Inget recept att forka');
      return null;
    }

    _state.setForking(true);
    _state.clearError();

    try {
      return await safeExecute<Recipe>(
        () async {
          // Skapa nytt recept från state
          final newRecipe = _state.createRecipe(recipeId: _uuid.v4());
          
          // Spara som nytt recipe
          final result = await _recipeService.personal.addUnifiedRecipe(newRecipe);
          if (!result.isSuccess) {
            throw Exception(result.message ?? 'Failed to fork recipe');
          }
          final savedRecipe = newRecipe;
          
          // _analyticsService.trackRecipeForked(_state.originalRecipe!.id, savedRecipe.id);
          AppLogger.info('Recept forkat: ${savedRecipe.id}');
          
          return savedRecipe;
        },
        operationName: 'Fork Recipe',
        customErrorMessage: null, // Handle error with custom logic below
      );
    } catch (e) {
      AppLogger.error('Fel vid forkning av recept: $e');
      _state.setError('Kunde inte forka recept: $e');
      return null;
    } finally {
      _state.setForking(false);
    }
  }

  /// Deletes recipe with comprehensive cleanup, permission validation, and collaborative coordination.
  /// 
  /// Returns true if deletion succeeds, false if operation fails or permission denied.
  /// Performs complete recipe deletion flow including permission validation, service coordination,
  /// collaborative cleanup, and resource management for comprehensive recipe removal and cleanup.
  /// 
  /// **Deletion Process:**
  /// - Permission validation for delete operation authorization
  /// - Service-coordinated recipe deletion with error handling
  /// - Collaborative state cleanup and participant notification
  /// - Image and resource cleanup for complete removal
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final deleted = await recipeFormViewModel.deleteRecipe();
  /// if (deleted) {
  ///   // Navigate back to recipe list
  /// } else {
  ///   // Display deletion error or permission denial
  /// }
  /// ```
  Future<bool> deleteRecipe() async {
    if (_state.originalRecipe == null) {
      _state.setError('Inget recept att ta bort');
      return false;
    }

    if (!canDelete) {
      _state.setError('Du har inte behörighet att ta bort detta recept');
      return false;
    }

    _state.clearError();

    final result = await safeExecute<bool>(
      () async {
        await _recipeService.deleteRecipe(_state.originalRecipe!.id);
        
        // Cleanup collaborative state
        if (isCollaborative) {
          await _collaborativeManager.leaveCollaborativeMode();
        }
        
        // Cleanup images
        await _imageManager.clearAllImages();
        
        // _analyticsService.trackRecipeDeleted(_state.originalRecipe!.id);
        AppLogger.info('Recept borttaget: ${_state.originalRecipe!.id}');
        
        return true;
      },
      operationName: 'Delete Recipe',
      customErrorMessage: null, // Handle error with custom logic below
    );

    if (result == null) {
      _state.setError('Kunde inte ta bort recept');
      return false;
    }

    return result;
  }

  // ===== RECIPE FORM DATA SETTERS =====

  /// Updates recipe title with state coordination and collaborative synchronization.
  /// 
  /// [title] New recipe title for form state and collaborative updates
  /// 
  /// Delegates to RecipeFormState for title management with automatic collaborative
  /// synchronization for real-time updates in collaborative editing mode.
  void setTitle(String title) {
    _state.setTitle(title);
    _syncToCollaborative();
  }

  /// Updates recipe description with comprehensive state management and collaborative coordination.
  /// 
  /// [description] New recipe description for detailed content management
  /// 
  /// Performs description update with automatic collaborative synchronization
  /// enabling real-time content updates in collaborative editing scenarios.
  void setDescription(String description) {
    _state.setDescription(description);
    _syncToCollaborative();
  }

  /// Updates meal type selection with Swedish localization and collaborative synchronization.
  /// 
  /// [mealType] New meal type for recipe categorization and meal planning
  /// 
  /// Manages meal type update with automatic collaborative synchronization
  /// for consistent categorization in collaborative editing mode.
  void setMealType(String mealType) {
    _state.setMealType(mealType);
    _syncToCollaborative();
  }

  /// Updates portion count with nullable support and collaborative coordination.
  /// 
  /// [portions] New portion count for serving size management
  /// 
  /// Handles portion update with automatic collaborative synchronization
  /// supporting nullable values for optional portion information.
  void setPortions(int? portions) {
    _state.setPortions(portions);
    _syncToCollaborative();
  }

  /// Updates cooking time with nullable support and collaborative synchronization.
  /// 
  /// [timeMinutes] New cooking time in minutes for meal planning
  /// 
  /// Manages time update with automatic collaborative synchronization
  /// supporting nullable values for optional timing information.
  void setTimeMinutes(int? timeMinutes) {
    _state.setTimeMinutes(timeMinutes);
    _syncToCollaborative();
  }

  /// Updates recipe rating with nullable support and collaborative coordination.
  /// 
  /// [rating] New recipe rating for quality assessment
  /// 
  /// Handles rating update with automatic collaborative synchronization
  /// supporting nullable values for unrated recipes.
  void setRating(double? rating) {
    _state.setRating(rating);
    _syncToCollaborative();
  }

  /// Updates source URL with nullable support and collaborative synchronization.
  /// 
  /// [sourceUrl] New source URL for recipe attribution and external linking
  /// 
  /// Manages source URL update with automatic collaborative synchronization
  /// supporting nullable values for original recipes without external sources.
  void setSourceUrl(String? sourceUrl) {
    _state.setSourceUrl(sourceUrl);
    _syncToCollaborative();
  }

  // ===== BACKWARD COMPATIBILITY SUPPORT =====

  /// Sets portions from double value with automatic conversion for backward compatibility.
  /// 
  /// [portions] Double portion value for automatic integer conversion
  /// 
  /// Provides backward compatibility for existing code using double values
  /// with automatic conversion to integer for consistent portion management.
  void setPortionsFromDouble(double? portions) {
    setPortions(portions?.toInt());
  }

  /// Sets cooking time from double value with automatic conversion for backward compatibility.
  /// 
  /// [timeMinutes] Double time value for automatic integer conversion
  /// 
  /// Provides backward compatibility for existing code using double values
  /// with automatic conversion to integer for consistent time management.
  void setTimeMinutesFromDouble(double? timeMinutes) {
    setTimeMinutes(timeMinutes?.toInt());
  }

  // ===== COMPREHENSIVE IMAGE MANAGEMENT OPERATIONS =====

  /// Displays image picker dialog with comprehensive selection options and upload coordination.
  /// 
  /// [context] BuildContext for dialog display and UI coordination
  /// 
  /// Delegates to RecipeImageManager for image selection dialog with automatic
  /// image URL synchronization and collaborative state management.
  Future<void> showImagePickerDialog(BuildContext context) async {
    await _imageManager.showImagePickerDialog(context);
    _syncImageUrls();
  }

  /// Adds image from URL with validation and comprehensive state synchronization.
  /// 
  /// [imageUrl] Image URL for addition to recipe image collection
  /// 
  /// Performs image URL addition through RecipeImageManager with automatic
  /// state synchronization and collaborative coordination.
  Future<void> addImageFromUrl(String imageUrl) async {
    await _imageManager.addImageFromUrl(imageUrl);
    _syncImageUrls();
  }

  /// Uploads image from file with comprehensive processing and storage coordination.
  /// 
  /// [imageFile] XFile instance for image upload and processing
  /// 
  /// Performs image file upload through RecipeImageManager with automatic
  /// recipe ID generation and comprehensive state synchronization.
  Future<void> uploadImageFromFile(XFile imageFile) async {
    final recipeId = _state.originalRecipe?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
    await _imageManager.uploadImageFromFile(imageFile, recipeId);
    _syncImageUrls();
  }

  /// Removes image with comprehensive cleanup and storage management.
  /// 
  /// [imageUrl] Image URL for removal and cleanup operations
  /// 
  /// Delegates to RecipeImageManager for image removal with automatic
  /// cleanup, storage management, and state synchronization.
  Future<void> removeImageAndCleanup(String imageUrl) async {
    await _imageManager.removeImageAndCleanup(imageUrl);
    _syncImageUrls();
  }

  /// Moves image to first position for primary image designation and visual hierarchy.
  /// 
  /// [imageUrl] Image URL for primary position assignment
  /// 
  /// Performs image reordering through RecipeImageManager with automatic
  /// state synchronization and collaborative coordination.
  void moveImageToFirst(String imageUrl) {
    _imageManager.moveImageToFirst(imageUrl);
    _syncImageUrls();
  }

  /// Reorders images with comprehensive position management and state coordination.
  /// 
  /// [oldIndex] Current image position for reordering operation
  /// [newIndex] Target image position for reordering coordination
  /// 
  /// Delegates to RecipeImageManager for image reordering with automatic
  /// state synchronization and collaborative updates.
  void reorderImages(int oldIndex, int newIndex) {
    _imageManager.reorderImages(oldIndex, newIndex);
    _syncImageUrls();
  }

  // ===== MISSING API METHODS (for backward compatibility) =====

  /// Save fork - creates a copy of the current recipe
  Future<Recipe?> saveFork() async {
    return await forkRecipe();
  }

  /// Pick and upload single image
  Future<void> pickAndUploadImage(BuildContext context) async {
    await showImagePickerDialog(context);
  }

  /// Pick multiple images
  Future<void> pickMultipleImages(BuildContext context) async {
    await showImagePickerDialog(context);
  }

  /// Add image URL directly
  Future<void> addImageUrl(String imageUrl) async {
    await addImageFromUrl(imageUrl);
  }

  /// Remove image at specific index
  Future<void> removeImageAt(int index) async {
    if (index >= 0 && index < _imageManager.imageUrls.length) {
      final imageUrl = _imageManager.imageUrls[index];
      await removeImageAndCleanup(imageUrl);
    }
  }

  /// Set primary image (move to first position)
  void setPrimaryImage(String imageUrl) {
    moveImageToFirst(imageUrl);
  }

  /// Get ingredient controllers (for backward compatibility)
  List<TextEditingController> get ingredientControllers {
    return _state.ingredientsManager.controllers;
  }

  /// Get instruction controllers (for backward compatibility)
  List<TextEditingController> get instructionControllers {
    return _state.instructionsManager.controllers;
  }

  /// Get tag controllers (for backward compatibility)
  List<TextEditingController> get tagControllers {
    return _state.tagsManager.controllers;
  }

  /// Update ingredient at index
  void updateIngredient(int index, String value) {
    _state.ingredientsManager.updateAt(index, value);
    _syncToCollaborative();
  }

  /// Add new ingredient
  void addIngredient() {
    _state.ingredientsManager.add('');
    _syncToCollaborative();
  }

  /// Remove ingredient at index
  void removeIngredient(int index) {
    _state.ingredientsManager.removeAt(index);
    _syncToCollaborative();
  }

  /// Update instruction at index
  void updateInstruction(int index, String value) {
    _state.instructionsManager.updateAt(index, value);
    _syncToCollaborative();
  }

  /// Add new instruction
  void addInstruction() {
    _state.instructionsManager.add('');
    _syncToCollaborative();
  }

  /// Remove instruction at index
  void removeInstruction(int index) {
    _state.instructionsManager.removeAt(index);
    _syncToCollaborative();
  }

  /// Update tag at index
  void updateTag(int index, String value) {
    _state.tagsManager.updateAt(index, value);
    _syncToCollaborative();
  }

  /// Add new tag
  void addTag() {
    _state.tagsManager.add('');
    _syncToCollaborative();
  }

  /// Remove tag at index
  void removeTag(int index) {
    _state.tagsManager.removeAt(index);
    _syncToCollaborative();
  }

  /// Get edit mode (for backward compatibility)
  String? get editMode {
    return _permissionManager.editMode;
  }

  /// Get edit mode as enum
  EditMode? get editModeEnum {
    return _permissionManager.editModeEnum;
  }

  /// Check if in edit mode
  bool get isEditMode => canEdit;

  /// Get function getters (for backward compatibility)
  Function(String) get addImageUrlFunc => addImageFromUrl;
  Function(int) get removeImageAtFunc => (int index) => removeImageAt(index);
  Function(String) get setPrimaryImageFunc => (String url) => setPrimaryImage(url);
  Function(int, String) get updateIngredientFunc => (int index, String value) => updateIngredient(index, value);
  Function() get addIngredientFunc => () => addIngredient();
  Function(int) get removeIngredientFunc => (int index) => removeIngredient(index);
  Function(int, String) get updateInstructionFunc => (int index, String value) => updateInstruction(index, value);
  Function() get addInstructionFunc => () => addInstruction();
  Function(int) get removeInstructionFunc => (int index) => removeInstruction(index);
  Function(int, String) get updateTagFunc => (int index, String value) => updateTag(index, value);
  Function() get addTagFunc => () => addTag();
  Function(int) get removeTagFunc => (int index) => removeTag(index);

  // ===== COLLABORATIVE OPERATIONS (Delegate to collaborative manager) =====

  Future<void> enableCollaborativeMode() async {
    if (_state.originalRecipe == null) return;
    
    await _collaborativeManager.enableCollaborativeMode(_state.originalRecipe!);
  }

  Future<void> inviteUserToCollaboration(String userId, String userDisplayName, ResourcePermission permission) async {
    await _collaborativeManager.inviteUserToCollaboration(userId, userDisplayName, permission);
  }

  Future<void> removeUserFromCollaboration(String userId) async {
    await _collaborativeManager.removeUserFromCollaboration(userId);
  }

  Future<void> leaveCollaborativeMode() async {
    await _collaborativeManager.leaveCollaborativeMode();
  }

  // ===== PERMISSION OPERATIONS (Delegate to permission manager) =====

  Future<void> updateUserPermission(String userId, ResourcePermission permission) async {
    if (_state.originalRecipe == null) return;
    
    _permissionManager.updateUserPermission(_state.originalRecipe!.id, userId, permission);
  }

  Future<void> shareRecipeWithUser(String userId, ResourcePermission permission) async {
    if (_state.originalRecipe == null) return;
    
    _permissionManager.shareRecipeWithUser(_state.originalRecipe!.id, userId, permission);
  }

  bool canPerformAction(String action) {
    return _permissionManager.canPerformAction(action);
  }

  bool canEditField(String fieldName) {
    return _permissionManager.canEditField(fieldName);
  }

  // ===== INTERNAL COORDINATION AND STATE MANAGEMENT =====

  /// Establishes comprehensive manager listener coordination for reactive state management.
  /// 
  /// Sets up listener connections to all focused managers ensuring automatic UI notification
  /// and state synchronization across form state, collaborative editing, image management,
  /// and permission systems for comprehensive reactive state coordination.
  void _setupManagerListeners() {
    _state.addListener(_onStateChanged);
    _collaborativeManager.addListener(_onCollaborativeChanged);
    _imageManager.addListener(_onImageChanged);
    _permissionManager.addListener(_onPermissionChanged);
  }

  /// Handles form state changes with automatic UI notification and reactive coordination.
  /// 
  /// Provides seamless state synchronization from RecipeFormState ensuring
  /// all form state changes are immediately reflected in UI components
  /// for consistent user experience and real-time form updates.
  void _onStateChanged() {
    notifyListeners();
  }

  /// Handles collaborative state changes with automatic UI synchronization and participant updates.
  /// 
  /// Provides seamless collaborative state synchronization ensuring
  /// all collaborative changes are immediately reflected in UI components
  /// for real-time collaborative editing and participant awareness.
  void _onCollaborativeChanged() {
    notifyListeners();
  }

  /// Handles image management changes with automatic UI notification and visual updates.
  /// 
  /// Provides seamless image state synchronization ensuring
  /// all image changes are immediately reflected in UI components
  /// for real-time image management and visual coordination.
  void _onImageChanged() {
    notifyListeners();
  }

  /// Handles permission changes with automatic UI synchronization and access control updates.
  /// 
  /// Provides seamless permission state synchronization ensuring
  /// all permission changes are immediately reflected in UI components
  /// for real-time access control and feature availability.
  void _onPermissionChanged() {
    notifyListeners();
  }

  /// Loads initial permissions for recipe form initialization with comprehensive error handling.
  /// 
  /// [recipe] Recipe instance for permission validation and initialization
  /// 
  /// Performs asynchronous permission loading through RecipePermissionManager with
  /// comprehensive error handling and Swedish localized error messages
  /// for proper recipe form initialization and access control setup.
  Future<void> _loadInitialPermissions(Recipe recipe) async {
    await safeExecute(
      () async {
        _permissionManager.checkPermissions();
      },
      operationName: 'Load Initial Permissions',
      customErrorMessage: 'Fel vid laddning av permissions',
    );
  }

  /// Synchronizes form state to collaborative infrastructure for real-time updates.
  /// 
  /// Performs collaborative state synchronization when in collaborative mode,
  /// creating recipe from current state and updating Firebase for real-time
  /// collaborative editing and participant synchronization.
  void _syncToCollaborative() {
    if (isCollaborative && _state.originalRecipe != null) {
      final recipe = _state.createRecipe(recipeId: _state.originalRecipe!.id);
      _collaborativeManager.updateRecipeInFirebase(recipe);
    }
  }

  /// Synchronizes image URLs between image manager and form state with collaborative coordination.
  /// 
  /// Updates form state with current image URLs from RecipeImageManager
  /// and triggers collaborative synchronization for real-time image updates
  /// in collaborative editing scenarios.
  void _syncImageUrls() {
    _state.setImageUrls(_imageManager.imageUrls);
    _syncToCollaborative();
  }

  /// Performs comprehensive ViewModel disposal with manager cleanup and memory management.
  /// 
  /// Disposes all focused managers, removes listener connections, and performs complete resource cleanup
  /// to prevent memory leaks and ensure proper ViewModel lifecycle management
  /// in dynamic recipe form scenarios with ViewModel creation and disposal.
  @override
  void dispose() {
    _state.dispose();
    _collaborativeManager.dispose();
    _imageManager.dispose();
    _permissionManager.dispose();
    super.dispose();
  }
}