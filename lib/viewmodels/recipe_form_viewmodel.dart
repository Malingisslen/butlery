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
import 'package:butlery/core/errors/unified_error_coordinator.dart';

// Import focused managers
import 'package:butlery/viewmodels/recipe_form/recipe_form_state.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_collaborative_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_image_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_auto_save_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_permission_manager.dart';

// ===== FOCUSED MANAGER ARCHITECTURE =====

/// Comprehensive recipe form ViewModel providing advanced recipe creation and editing through focused manager architecture.
///
/// Serves as the main coordinator for all recipe form operations, delegating to specialized managers
/// for form state, collaborative editing, image management, and permission control while maintaining
/// clean MVVM architecture separation between recipe form business logic and UI presentation concerns.
class RecipeFormViewModel extends ChangeNotifier with ErrorHandlingMixin, ErrorCoordinatorMixin {
  final UnifiedRecipeService _recipeService;
  // final AnalyticsService _analyticsService; // Currently unused
  final _uuid = const Uuid();

  // ===== DISPOSAL TRACKING =====
  bool _disposed = false;
  bool get disposed => _disposed;

  // CRITICAL FIX: Notification coordination to prevent cascading loops
  bool _isNotifying = false;
  Timer? _notificationDebounceTimer;
  
  // CRITICAL FIX: Atomic save operation coordination
  bool _isSaveInProgress = false;
  final Map<String, Completer<Recipe?>> _pendingSaveOperations = {};
  Recipe? _lastSaveResult;
  
  String? _currentSaveOperationId;

  // ===== FOCUSED MANAGER ARCHITECTURE =====
  
  /// Form state manager for comprehensive recipe data and validation coordination.
  late final RecipeFormState _state;
  
  /// Collaborative editing manager for real-time synchronization and participant management.
  late final RecipeCollaborativeManager _collaborativeManager;
  
  /// Image management system for multi-image upload, ordering, and storage coordination.
  late final RecipeImageManager _imageManager;
  
  /// Permission management system for access control and collaborative sharing.
  late final RecipePermissionManager _permissionManager;
  
  // CRITICAL FIX: Unified error coordination for consistent error handling
  late final UnifiedErrorCoordinator _errorCoordinator;

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

    // CRITICAL FIX: Initialize unified error coordinator
    _errorCoordinator = UnifiedErrorCoordinator();
    initializeErrorCoordinator(_errorCoordinator, 'RecipeFormViewModel');
    
    // Set up listeners
    _setupManagerListeners();
    
    // Initialize error coordination for all managers
    _initializeManagerErrorCoordination();

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
  
  /// CRITICAL FIX: Unsaved changes detection with comprehensive null safety
  /// 
  /// Compares current form state with original recipe data to detect modifications
  /// requiring user confirmation before navigation or form abandonment.
  /// Essential for preventing data loss and providing proper user experience.
  bool get hasUnsavedChanges {
    if (!isEditing || originalRecipe == null) return false;
    
    final original = originalRecipe!;
    
    // CRITICAL FIX: Safe comparison with null checking for all fields
    return title != original.title ||
           description != original.description ||
           mealType != original.mealType ||
           portions != original.portions ||
           timeMinutes != original.timeMinutes ||
           rating != original.rating ||
           sourceUrl != original.sourceUrl ||
           !_listEquals(ingredients, original.ingredients) ||
           !_listEquals(instructions, original.instructions) ||
           !_listEquals(tags, original.tags) ||
           !_listEquals(_imageManager.validImageUrls, original.imageUrls);
  }
  
  /// CRITICAL FIX: Helper method to compare two lists for equality with null safety
  bool _listEquals<T>(List<T>? list1, List<T>? list2) {
    // Handle null cases first - prevents null pointer exceptions
    if (list1 == null && list2 == null) return true;
    if (list1 == null || list2 == null) return false;
    
    // Handle length differences
    if (list1.length != list2.length) return false;
    
    // Compare elements safely
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
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
  /// Returns complete list including pending file paths for immediate UI preview
  /// and uploaded Firebase URLs for comprehensive image display coordination.
  List<String> get imageUrls => _imageManager.imageUrls;
  
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

  // ===== ENHANCED UPLOAD PROGRESS TRACKING =====
  
  /// Individual image upload statuses for detailed progress visualization and error handling.
  /// 
  /// Provides comprehensive upload status information for each image including progress percentages,
  /// error states, retry counts, and upload speeds for advanced UI progress indication.
  Map<String, ImageUploadStatus> get imageUploadStatuses => _imageManager.imageUploadStatuses;
  
  /// Upload queue summary for overall upload progress display and user feedback.
  /// 
  /// Provides aggregated upload queue information including active upload counts,
  /// overall progress percentage, and localized status text for comprehensive upload management.
  Map<String, dynamic> get uploadQueueSummary => _imageManager.uploadQueueSummary;
  
  /// Upload queue status text for banner display and user progress indication.
  /// 
  /// Returns Swedish localized status text describing current upload queue state
  /// for banner display and user progress feedback during image upload operations.
  String? get uploadQueueStatusText {
    final summary = uploadQueueSummary;
    return summary['statusText'] as String?;
  }
  
  /// Overall upload progress percentage for progress bars and completion indication.
  /// 
  /// Returns aggregated upload progress as percentage (0-100) for overall progress
  /// bar display and upload completion status indication.
  int get uploadProgressPercentage {
    final summary = uploadQueueSummary;
    return summary['progressPercentage'] as int;
  }
  
  /// Active upload indicator for UI state management and interaction control.
  /// 
  /// Indicates whether any uploads are currently active (pending, uploading, or retrying)
  /// for UI state management and user interaction control during active operations.
  bool get hasActiveUploads {
    final summary = uploadQueueSummary;
    return summary['hasActivity'] as bool;
  }
  
  /// Failed upload count for error indication and recovery action display.
  /// 
  /// Returns count of failed uploads for error state indication and
  /// recovery action button display in the user interface.
  int get failedUploadsCount {
    final summary = uploadQueueSummary;
    return summary['failed'] as int;
  }
  
  /// Individual image upload progress for specific image progress indicators.
  /// 
  /// [pathOrUrl] File path or URL identifier for the image
  /// 
  /// Returns upload progress (0.0 to 1.0) for specific image enabling
  /// individual image progress indicator display and detailed status tracking.
  double getImageUploadProgress(String pathOrUrl) => _imageManager.getUploadProgress(pathOrUrl);
  
  /// Individual image upload status for detailed progress and error information.
  /// 
  /// [pathOrUrl] File path or URL identifier for the image
  /// 
  /// Returns complete ImageUploadStatus for specific image including progress,
  /// error details, retry information, and speed metrics for advanced UI display.
  ImageUploadStatus? getImageUploadStatus(String pathOrUrl) => _imageManager.imageUploadStatuses[pathOrUrl];
  
  /// Retry failed upload with exponential backoff and comprehensive error handling.
  /// 
  /// [pathOrUrl] File path or URL identifier for the failed image
  /// 
  /// Initiates retry sequence for failed upload with exponential backoff delay,
  /// error classification, and comprehensive retry management for improved upload resilience.
  Future<void> retryImageUpload(String pathOrUrl) async {
    await _imageManager.retryFailedUpload(pathOrUrl);
  }
  
  /// Cancel specific image upload with state cleanup and user feedback.
  /// 
  /// [pathOrUrl] File path or URL identifier for the image to cancel
  /// 
  /// Cancels individual image upload and removes from upload queue with proper
  /// state cleanup and user feedback for granular upload management control.
  Future<void> cancelImageUpload(String pathOrUrl) async {
    await _imageManager.removeImageAndCleanup(pathOrUrl);
  }
  
  // ===== BULK UPLOAD MANAGEMENT =====
  
  /// Retry all failed uploads with comprehensive error handling and user feedback.
  /// 
  /// Performs bulk retry operation for all retryable failed uploads
  /// with individual error handling and comprehensive progress tracking.
  Future<void> retryAllFailedUploads() async {
    await _imageManager.retryAllFailedUploads();
  }
  
  /// Cancel all active uploads with state cleanup and user feedback.
  /// 
  /// Cancels all currently active uploads with comprehensive state cleanup
  /// for enhanced upload queue management and user control.
  void cancelAllActiveUploads() {
    _imageManager.cancelAllActiveUploads();
  }
  
  /// Clear all failed uploads from state for clean queue management.
  /// 
  /// Removes all failed uploads from tracking state for clean upload queue
  /// management and enhanced user experience.
  void clearAllFailedUploads() {
    _imageManager.clearAllFailedUploads();
  }
  
  /// Upload management summary for bulk operation UI and user feedback.
  /// 
  /// Provides comprehensive upload management information including failed,
  /// active, and completed counts for bulk operation UI and management controls.
  Map<String, dynamic> get uploadManagementSummary => _imageManager.uploadManagementSummary;
  
  /// Check if bulk retry operation is available and beneficial.
  /// 
  /// Indicates whether bulk retry controls should be shown for enhanced
  /// upload management and user experience.
  bool get canBulkRetry => uploadManagementSummary['canBulkRetry'] as bool? ?? false;
  
  /// Check if bulk cancel operation is available for active uploads.
  /// 
  /// Indicates whether bulk cancel controls should be shown for active
  /// upload management and enhanced user control.
  bool get canBulkCancel => uploadManagementSummary['canBulkCancel'] as bool? ?? false;
  
  /// Check if there are failed uploads that can be cleared.
  /// 
  /// Indicates whether clear failed uploads control should be shown
  /// for enhanced queue management and user experience.
  bool get hasRetryableFailures => _imageManager.hasRetryableFailures;

  // ===== BACKGROUND NOTIFICATION SYSTEM =====
  
  /// Stream of upload notification events for UI subscription and feedback.
  /// 
  /// Provides real-time upload events including completion, failures, progress milestones,
  /// and queue state changes for enhanced user feedback and notification system integration.
  static Stream<UploadNotificationEvent> get uploadNotificationStream => 
      RecipeImageManager.notificationStream;

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

  // ===== ATOMIC SAVE COORDINATION HELPERS =====
  
  /// Complete all pending save operations with the given result
  void _completePendingSaveOperations(Recipe? result) {
    for (final completer in _pendingSaveOperations.values) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }
    _pendingSaveOperations.clear();
  }
  
  /// Safe notification that respects disposal state and coordination locks
  void _safeNotifyListeners() {
    if (_disposed || _isNotifying) return;
    
    _isNotifying = true;
    try {
      notifyListeners();
    } catch (e) {
      AppLogger.debug('Notification skipped due to disposal: $e');
    } finally {
      _isNotifying = false;
    }
  }

  // ===== RECIPE MANAGEMENT OPERATIONS =====

  /// CRITICAL FIX: Atomic save operation with comprehensive race condition protection and image consistency.
  /// 
  /// Returns saved Recipe instance if successful, null if validation fails or save errors occur.
  /// Implements atomic save coordination ensuring:
  /// - Single concurrent save operation per recipe
  /// - Image upload completion before final recipe persistence
  /// - Auto-save conflict prevention and coordination
  /// - State consistency throughout save operation
  /// - Comprehensive disposal protection
  /// 
  /// **Atomic Save Process:**
  /// - Save operation locking to prevent concurrent saves
  /// - Image upload completion coordination for consistency
  /// - Form validation with comprehensive field checking
  /// - Permission validation for save operation authorization
  /// - Service-coordinated recipe persistence with atomic state management
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
    // CRITICAL FIX: Prevent disposal-related race conditions
    if (_disposed) {
      AppLogger.warning('⚠️ Save operation prevented - ViewModel disposed');
      return null;
    }
    
    // CRITICAL FIX: Prevent concurrent save operations
    if (_isSaveInProgress) {
      AppLogger.warning('⚠️ Save operation already in progress - queuing request');
      final operationId = _uuid.v4();
      final completer = Completer<Recipe?>();
      _pendingSaveOperations[operationId] = completer;
      
      // Wait for current save to complete, then return same result
      try {
        await Future.doWhile(() async {
          if (_disposed) return false;
          if (!_isSaveInProgress) return false;
          await Future.delayed(const Duration(milliseconds: 100));
          return true;
        });
        
        // Return the result of the completed save operation
        final result = _lastSaveResult;
        _pendingSaveOperations.remove(operationId);
        completer.complete(result);
        return result;
      } catch (e) {
        _pendingSaveOperations.remove(operationId);
        completer.completeError(e);
        rethrow;
      }
    }
    
    // CRITICAL FIX: Check if auto-save is in progress and wait for it
    if (_state.isAutoSaving) {
      AppLogger.info('⏳ Waiting for auto-save to complete before manual save...');
      await Future.doWhile(() async {
        if (_disposed) return false;
        if (!_state.isAutoSaving) return false;
        await Future.delayed(const Duration(milliseconds: 50));
        return true;
      });
    }
    
    if (!_state.isValid) {
      _state.setError('Fyll i alla obligatoriska fält');
      return null;
    }

    if (!canEdit) {
      _state.setError('Du har inte behörighet att spara detta recept');
      return null;
    }

    // CRITICAL FIX: Set atomic save lock
    _isSaveInProgress = true;
    _currentSaveOperationId = _uuid.v4();
    AppLogger.info('🔒 Starting atomic save operation: $_currentSaveOperationId');
    
    _state.setSaving(true);
    _state.clearError();

    try {
      final result = await safeExecute<Recipe>(
        () async {
          // CRITICAL FIX: Prevent disposal during save operation
          if (_disposed) {
            throw Exception('Save operation cancelled - ViewModel disposed');
          }
          
          // Create recipe ID for both metadata and image uploads
          final recipeId = _state.isEditing ? _state.originalRecipe!.id : _uuid.v4();
          
          // Update image manager with actual recipe ID
          _imageManager.setActualRecipeId(recipeId);
          
          AppLogger.info('🚀 Starting atomic recipe save process for: $recipeId');
          
          // CRITICAL FIX: Atomic image upload coordination for consistency
          if (_imageManager.pendingImages.isNotEmpty) {
            AppLogger.info('📤 Waiting for ${_imageManager.pendingImages.length} images to upload before save...');
            
            try {
              // CRITICAL FIX: Wait for all images to upload before saving recipe
              await _imageManager.uploadPendingImagesInBackground(
                recipeId,
                onProgress: (completed, total) {
                  AppLogger.info('📈 Upload progress: $completed/$total');
                  // CRITICAL FIX: Disposal-safe progress updates
                  _safeNotifyListeners();
                },
              );
              
              // CRITICAL FIX: Verify upload completion before proceeding
              if (_imageManager.pendingImages.isNotEmpty) {
                throw Exception('Image upload incomplete - cannot save recipe');
              }
              
              AppLogger.info('✅ All images uploaded successfully, proceeding with recipe save');
            } catch (e) {
              AppLogger.error('❌ Image upload failed during recipe save: $e');
              throw Exception('Failed to upload images: $e');
            }
          }
          
          // CRITICAL FIX: Final disposal check before recipe persistence
          if (_disposed) {
            throw Exception('Save operation cancelled - ViewModel disposed during image upload');
          }
          
          // CRITICAL FIX: Create recipe with atomic image URL consistency
          // Use only uploaded Firebase URLs to ensure image consistency
          final validImageUrls = _imageManager.validImageUrls;
          AppLogger.info('📝 Creating recipe with ${validImageUrls.length} validated image URLs');
          
          final recipe = _state.createRecipe(
            recipeId: recipeId,
            imageUrls: validImageUrls, // Only use validated Firebase URLs
          );

          // CRITICAL FIX: Atomic recipe persistence with state consistency
          Recipe savedRecipe;
          if (_state.isEditing) {
            AppLogger.info('📝 Updating existing recipe: $recipeId');
            final result = await _recipeService.personal.updateUnifiedRecipe(recipe);
            if (result.isSuccess) {
              savedRecipe = recipe;
            } else {
              throw Exception(result.message ?? 'Failed to update recipe');
            }
          } else {
            AppLogger.info('📝 Creating new recipe: $recipeId');
            final result = await _recipeService.personal.addUnifiedRecipe(recipe);
            if (result.isSuccess) {
              savedRecipe = recipe;
            } else {
              throw Exception(result.message ?? 'Failed to create recipe');
            }
          }

          // CRITICAL FIX: Final disposal check after persistence
          if (_disposed) {
            AppLogger.warning('⚠️ Save completed but ViewModel disposed - skipping state updates');
            return savedRecipe; // Return saved recipe even if state updates are skipped
          }
          
          AppLogger.info('✅ Recipe saved atomically with ${savedRecipe.imageUrls.length} images: ${savedRecipe.id}');

          // CRITICAL FIX: Atomic collaborative state update
          if (isCollaborative && !_disposed) {
            try {
              await _collaborativeManager.updateRecipeInFirebase(savedRecipe);
              AppLogger.info('🔄 Collaborative state updated for recipe: ${savedRecipe.id}');
            } catch (e) {
              AppLogger.error('❌ Failed to update collaborative state: $e');
              // Don't fail the entire save operation for collaborative update issues
            }
          }

          return savedRecipe;
        },
        operationName: 'Save Recipe',
        customErrorMessage: null, // Handle error with custom logic below
      );
      
      // CRITICAL FIX: Store result for pending operations
      _lastSaveResult = result;
      
      // Check if safeExecute returned null (indicating an error)
      if (result == null) {
        if (!_disposed) {
          _state.setError('Kunde inte spara recept');
        }
      } else {
        // CRITICAL FIX: Safe state updates after successful save
        if (!_disposed) {
          // Clear auto-save draft after successful save
          _state.clearCurrentDraft();
          AppLogger.info('✅ Save operation completed successfully: ${result.id}');
        }
      }
      
      // CRITICAL FIX: Complete any pending save operations
      _completePendingSaveOperations(result);
      
      return result;
    } catch (e) {
      AppLogger.error('❌ Atomic save operation failed: $e');
      
      // CRITICAL FIX: Safe error handling with disposal protection
      if (!_disposed) {
        _state.setError('Kunde inte spara recept: $e');
      }
      
      // CRITICAL FIX: Complete pending operations with error
      _completePendingSaveOperations(null);
      
      return null;
    } finally {
      // CRITICAL FIX: Always release atomic save lock
      _isSaveInProgress = false;
      _currentSaveOperationId = null;
      
      // CRITICAL FIX: Safe state cleanup
      if (!_disposed) {
        _state.setSaving(false);
      }
      
      AppLogger.info('🔓 Atomic save operation completed and lock released');
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
      final result = await safeExecute<Recipe>(
        () async {
          // Skapa nytt recept från state
          final newRecipe = _state.createRecipe(recipeId: _uuid.v4());
          
          // Spara som nytt recipe
          final saveResult = await _recipeService.personal.addUnifiedRecipe(newRecipe);
          if (!saveResult.isSuccess) {
            throw Exception(saveResult.message ?? 'Failed to fork recipe');
          }
          final savedRecipe = newRecipe;
          
          // _analyticsService.trackRecipeForked(_state.originalRecipe!.id, savedRecipe.id);
          AppLogger.info('Recept forkat: ${savedRecipe.id}');
          
          return savedRecipe;
        },
        operationName: 'Fork Recipe',
        customErrorMessage: null, // Handle error with custom logic below
      );
      
      // Check if safeExecute returned null (indicating an error)
      if (result == null) {
        _state.setError('Kunde inte forka recept');
      } else {
        // CRITICAL: Clear auto-save draft after successful fork operation
        // This ensures consistency with saveRecipe() behavior and prevents
        // orphaned drafts from confusing users with recovery prompts
        if (!_disposed) {
          _state.clearCurrentDraft();
        }
      }
      
      return result;
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
  
  // ===== ERROR COORDINATION METHODS =====
  
  /// Initialize error coordination for all managers
  void _initializeManagerErrorCoordination() {
    // Listen to form state errors
    _state.addListener(() {
      if (_state.hasError) {
        reportError(
          source: ErrorSource.formValidation,
          message: _state.error!,
          severity: ErrorSeverity.medium,
        );
      }
    });
    
    // Listen to image manager errors  
    _imageManager.addListener(() {
      if (_imageManager.hasImageUploadError) {
        reportError(
          source: ErrorSource.imageUpload,
          message: _imageManager.imageUploadError!,
          severity: ErrorSeverity.high,
          actions: [ErrorRecoveryAction.retry, ErrorRecoveryAction.ignore],
        );
      }
    });
  }
  
  /// Get unified error coordinator for UI integration
  UnifiedErrorCoordinator get errorCoordinator => _errorCoordinator;
  

  // ===== DRAFT RECOVERY OPERATIONS =====
  
  /// Get available drafts for recovery with comprehensive metadata
  /// 
  /// Returns list of DraftMetadata for recent drafts that can be restored.
  /// Provides draft information including creation time, modification time, 
  /// title preview, and content significance for optimal user experience.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final availableDrafts = await recipeFormViewModel.getAvailableDrafts();
  /// if (availableDrafts.isNotEmpty) {
  ///   // Show draft recovery dialog
  /// }
  /// ```
  Future<List<DraftMetadata>> getAvailableDrafts() async {
    return await _state.getAvailableDrafts();
  }
  
  /// Load form state from auto-saved draft with comprehensive restoration
  /// 
  /// [draftId] Unique identifier for the draft to restore
  /// 
  /// Returns true if draft was successfully loaded and form state restored,
  /// false if draft loading failed or draft data was corrupted.
  /// Performs complete form state restoration including all field types.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final success = await recipeFormViewModel.loadFromDraft(draftId);
  /// if (success) {
  ///   // Show success feedback
  /// } else {
  ///   // Show error message
  /// }
  /// ```
  Future<bool> loadFromDraft(String draftId) async {
    try {
      final success = await _state.loadFromDraft(draftId);
      if (success) {
        // Sync with collaborative and image managers after restoration
        _syncToCollaborative();
      }
      return success;
    } catch (e) {
      AppLogger.error('Error loading draft in ViewModel: $e');
      return false;
    }
  }
  
  /// Serialize current form data for analysis and feedback
  /// 
  /// Returns Map containing all current form field values for
  /// content analysis, field counting, and user feedback purposes.
  /// Used primarily for providing detailed restoration feedback.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final formData = recipeFormViewModel.serializeCurrentFormData();
  /// final fieldCount = _countRestoredFields(formData);
  /// ```
  Map<String, dynamic> serializeCurrentFormData() {
    return _state.serializeFormData();
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
    AppLogger.info('🎯 VIEWMODEL: showImagePickerDialog called');
    final recipeId = _state.originalRecipe?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
    AppLogger.info('🎯 VIEWMODEL: Using recipeId for image upload: $recipeId');
    await _imageManager.showImagePickerDialog(context, recipeId: recipeId);
    AppLogger.info('🎯 VIEWMODEL: _imageManager.showImagePickerDialog completed');
    // Use post-frame callback to prevent setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLogger.info('🎯 VIEWMODEL: Running _syncImageUrls in post-frame callback');
      _syncImageUrls();
    });
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
    AppLogger.info('🎯 VIEWMODEL: pickAndUploadImage called');
    await showImagePickerDialog(context);
  }

  /// Pick single image from camera (direct, no dialog)
  Future<void> pickImageFromCamera(BuildContext context) async {
    AppLogger.info('🎯 VIEWMODEL: pickImageFromCamera called');
    final recipeId = _state.originalRecipe?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
    await _imageManager.pickImageFromCamera(context, recipeId: recipeId);
    _syncImageUrls();
  }

  /// Pick single image from gallery (direct, no dialog)
  Future<void> pickImageFromGallery(BuildContext context) async {
    AppLogger.info('🎯 VIEWMODEL: pickImageFromGallery called');
    final recipeId = _state.originalRecipe?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
    await _imageManager.pickImageFromGallery(context, recipeId: recipeId);
    _syncImageUrls();
  }

  /// Pick multiple images from gallery (direct, no dialog)
  Future<void> pickMultipleImagesFromGallery(BuildContext context) async {
    AppLogger.info('🎯 VIEWMODEL: pickMultipleImagesFromGallery called');
    final recipeId = _state.originalRecipe?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
    await _imageManager.pickMultipleImagesFromGallery(context, recipeId: recipeId);
    _syncImageUrls();
  }

  /// Legacy method - Pick multiple images (shows dialog)
  Future<void> pickMultipleImages(BuildContext context) async {
    AppLogger.info('🎯 VIEWMODEL: pickMultipleImages called');
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
    debugPrint('🎯 VIEWMODEL_DEBUG: ingredientControllers called');
    final controllers = _state.ingredientsManager.controllers;
    debugPrint('🎯 VIEWMODEL_DEBUG: ingredientControllers returning ${controllers.length} controllers');
    return controllers;
  }

  /// Get instruction controllers (for backward compatibility)
  List<TextEditingController> get instructionControllers {
    debugPrint('🎯 VIEWMODEL_DEBUG: instructionControllers called');
    final controllers = _state.instructionsManager.controllers;
    debugPrint('🎯 VIEWMODEL_DEBUG: instructionControllers returning ${controllers.length} controllers');
    return controllers;
  }

  /// Get tag controllers (for backward compatibility)
  List<TextEditingController> get tagControllers {
    debugPrint('🎯 VIEWMODEL_DEBUG: tagControllers called');
    final controllers = _state.tagsManager.controllers;
    debugPrint('🎯 VIEWMODEL_DEBUG: tagControllers returning ${controllers.length} controllers');
    return controllers;
  }

  /// Update ingredient at index
  void updateIngredient(int index, String value) {
    _state.ingredientsManager.updateAt(index, value);
    _syncToCollaborative();
  }

  /// Add new ingredient
  void addIngredient() {
    _state.ingredientsManager.add('');
    notifyListeners();
    _syncToCollaborative();
  }

  /// Remove ingredient at index
  void removeIngredient(int index) {
    _state.ingredientsManager.removeAt(index);
    notifyListeners();
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
    notifyListeners();
    _syncToCollaborative();
  }

  /// Remove instruction at index
  void removeInstruction(int index) {
    _state.instructionsManager.removeAt(index);
    notifyListeners();
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
    notifyListeners();
    _syncToCollaborative();
  }

  /// Remove tag at index
  void removeTag(int index) {
    _state.tagsManager.removeAt(index);
    notifyListeners();
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

  /// CRITICAL FIX: Coordinated notification system to prevent cascading loops
  void _coordinatedNotifyListeners() {
    // Prevent notification loops with debouncing
    if (_isNotifying) {
      return; // Skip if already in a notification cycle
    }
    
    _notificationDebounceTimer?.cancel();
    _notificationDebounceTimer = Timer(const Duration(milliseconds: 50), () {
      if (!_disposed && !_isNotifying) {
        _isNotifying = true;
        try {
          notifyListeners();
        } finally {
          _isNotifying = false;
        }
      }
    });
  }

  /// Handles form state changes with automatic UI notification and reactive coordination.
  /// 
  /// Provides seamless state synchronization from RecipeFormState ensuring
  /// all form state changes are immediately reflected in UI components
  /// for consistent user experience and real-time form updates.
  void _onStateChanged() {
    _coordinatedNotifyListeners();
  }

  /// Handles collaborative state changes with automatic UI synchronization and participant updates.
  /// 
  /// Provides seamless collaborative state synchronization ensuring
  /// all collaborative changes are immediately reflected in UI components
  /// for real-time collaborative editing and participant awareness.
  void _onCollaborativeChanged() {
    _coordinatedNotifyListeners();
  }

  /// Handles image management changes with automatic UI notification and visual updates.
  /// 
  /// Provides seamless image state synchronization ensuring
  /// all image changes are immediately reflected in UI components
  /// for real-time image management and visual coordination.
  void _onImageChanged() {
    _coordinatedNotifyListeners();
  }

  /// Handles permission changes with automatic UI synchronization and access control updates.
  /// 
  /// Provides seamless permission state synchronization ensuring
  /// all permission changes are immediately reflected in UI components
  /// for real-time access control and feature availability.
  void _onPermissionChanged() {
    _coordinatedNotifyListeners();
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
        _permissionManager.setRecipeId(recipe.id);
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
  /// Updates form state with ONLY valid Firebase URLs from RecipeImageManager
  /// (filters out file paths to prevent invalid URLs from being persisted)
  /// and triggers collaborative synchronization for real-time image updates
  /// in collaborative editing scenarios.
  void _syncImageUrls() {
    // RACE CONDITION GUARD: Prevent sync during save operations to avoid autosave conflicts
    if (_isSaveInProgress || _state.isSaving || _state.isForking) {
      // Skip sync during save operations to prevent race conditions
      return;
    }
    
    // ULTRATHINK FIX: Only sync valid URLs for persistence, not file paths
    // This prevents recipes from being saved with invalid local file paths
    _state.setImageUrls(_imageManager.validImageUrls, skipAutoSave: _state.isAutoSaving);
    _syncToCollaborative();
  }


  /// Performs comprehensive ViewModel disposal with manager cleanup and memory management.
  /// 
  /// Disposes all focused managers, removes listener connections, and performs complete resource cleanup
  /// to prevent memory leaks and ensure proper ViewModel lifecycle management
  /// in dynamic recipe form scenarios with ViewModel creation and disposal.
  @override
  void dispose() {
    _disposed = true;
    
    // CRITICAL FIX: Clear component errors from unified coordinator
    clearComponentErrors();
    
    // CRITICAL FIX: Cancel all active uploads FIRST to prevent race condition crashes
    _imageManager.cancelAllUploads();
    
    // Dispose managers
    _state.dispose();
    _collaborativeManager.dispose();
    _imageManager.dispose();
    _permissionManager.dispose();
    
    // Dispose error coordinator
    _errorCoordinator.dispose();
    
    AppLogger.info('RecipeFormViewModel with unified error coordination disposed');
    super.dispose();
  }
}