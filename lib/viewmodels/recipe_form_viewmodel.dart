/// Recipe form ViewModel with state management, collaborative editing, and image handling.
/// Manages recipe creation/editing through focused managers:
/// - RecipeFormState: Form state and validation
/// - RecipeCollaborativeManager: Real-time collaborative editing
/// - RecipeImageManager: Multi-image upload and ordering
/// - RecipePermissionManager: Role-based access control

// lib/viewmodels/recipe_form_viewmodel.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/live_editor.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/errors/unified_error_coordinator.dart';
import 'package:butlery/core/form/form_fields_manager.dart';

// Import upload models for image upload status and notifications
import 'package:butlery/services/upload/upload_models.dart';

// Import focused managers
import 'package:butlery/viewmodels/recipe_form/recipe_form_state.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_collaborative_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_image_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_auto_save_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_permission_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_persistence_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_form_coordinator.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_backward_compatibility_mixin.dart';

// ===== FOCUSED MANAGER ARCHITECTURE =====

/// Coordinator for recipe form operations with delegation to specialized managers.
class RecipeFormViewModel extends ChangeNotifier
    with
        ErrorHandlingMixin,
        ErrorCoordinatorMixin,
        RecipeBackwardCompatibilityMixin {
  final UnifiedRecipeService _recipeService;

  bool _disposed = false;
  bool get disposed => _disposed;

  late final RecipeFormState _state;
  late final RecipeCollaborativeManager _collaborativeManager;
  late final RecipeImageManager _imageManager;
  late final RecipePermissionManager _permissionManager;
  late final RecipePersistenceManager _persistenceManager;
  late final RecipeFormCoordinator _coordinator;
  late final UnifiedErrorCoordinator _errorCoordinator;

  @override
  RecipeFormState get state => _state;

  @override
  RecipeImageManager get imageManager => _imageManager;

  @override
  RecipePermissionManager get permissionManager => _permissionManager;

  @override
  RecipePersistenceManager get persistenceManager => _persistenceManager;

  @override
  RecipeFormCoordinator get coordinator => _coordinator;

  RecipeFormViewModel({
    UnifiedRecipeService? recipeService,
    Recipe? initialRecipe,
    bool isTemplate = false,
  }) : _recipeService =
            recipeService ?? ServiceLocator.get<UnifiedRecipeService>() {
    _state =
        RecipeFormState(initialRecipe: initialRecipe, isTemplate: isTemplate);
    _collaborativeManager = RecipeCollaborativeManager();
    _imageManager = RecipeImageManager();
    _permissionManager = RecipePermissionManager();

    _persistenceManager = RecipePersistenceManager(
      recipeService: _recipeService,
      state: _state,
      imageManager: _imageManager,
      collaborativeManager: _collaborativeManager,
      permissionManager: _permissionManager,
    );

    // Initialize coordinator
    _coordinator = RecipeFormCoordinator(
      state: _state,
      imageManager: _imageManager,
      collaborativeManager: _collaborativeManager,
      permissionManager: _permissionManager,
      parentNotify: notifyListeners,
    );

    // CRITICAL FIX: Initialize unified error coordinator
    _errorCoordinator = UnifiedErrorCoordinator();
    initializeErrorCoordinator(_errorCoordinator, 'RecipeFormViewModel');

    // Set up listeners through coordinator
    _coordinator.setupManagerListeners();

    // Initialize error coordination for all managers
    _initializeManagerErrorCoordination();

    // Load permissions and images if editing existing recipe
    if (initialRecipe != null && !isTemplate) {
      _coordinator.loadInitialPermissions(initialRecipe);

      // CRITICAL FIX: Sync existing image URLs to ImageManager
      // The state loads imageUrls, but the ImageManager needs them too
      // since viewModel.imageUrls returns _imageManager.imageUrls
      if (initialRecipe.imageUrls.isNotEmpty) {
        _imageManager.setUploadedImageUrls(initialRecipe.imageUrls);
      }
    }
  }

  // ===== FORM STATE ACCESSORS (DELEGATE TO SPECIALIZED MANAGERS) =====

  /// Original recipe data for editing mode and change comparison functionality.
  /// Delegates to RecipeFormState for original recipe access enabling
  /// edit mode initialization and unsaved changes detection.
  Recipe? get originalRecipe => _state.originalRecipe;

  /// Save operation state for UI progress indication and interaction control.
  /// Provides real-time save status for loading indicators and user interaction
  /// management during recipe save operations and form submission.
  bool get isSaving => _state.isSaving;

  /// Fork operation in progress.
  bool get isForking => _state.isForking;

  /// Current error message.
  String? get error => _state.error;

  /// Error state indicator.
  bool get hasError => _state.hasError;

  /// Edit mode for existing recipe vs creation mode.
  bool get isEditing => _state.isEditing;

  /// Form validation state.
  bool get isValid => _state.isValid;

  /// CRITICAL FIX: Unsaved changes detection with comprehensive null safety
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

  /// Recipe title.
  String get title => _state.title;

  /// Recipe description.
  String get description => _state.description;

  /// Meal type (e.g., "Middag", "Lunch").
  String get mealType => _state.mealType;

  /// Portion count.
  int? get portions => _state.portions;

  /// Cooking time in minutes.
  int? get timeMinutes => _state.timeMinutes;

  /// Recipe rating (0-5).
  double? get rating => _state.rating;

  /// Image URLs (pending + uploaded).
  List<String> get imageUrls => _imageManager.imageUrls;

  /// Source URL for attribution.
  String? get sourceUrl => _state.sourceUrl;

  /// Ingredient list.
  List<String> get ingredients => _state.ingredients;

  /// Instruction list.
  List<String> get instructions => _state.instructions;

  /// Tag list.
  List<String> get tags => _state.tags;

  // ===== SPECIALIZED MANAGER ACCESSORS =====

  /// Dynamic ingredients manager.
  FormFieldsManager get ingredientsManager => _state.ingredientsManager;

  /// Dynamic instructions manager.
  FormFieldsManager get instructionsManager => _state.instructionsManager;

  /// Dynamic tags manager.
  FormFieldsManager get tagsManager => _state.tagsManager;

  // ===== COLLABORATIVE EDITING ACCESSORS =====

  /// Collaborative mode active.
  @override
  bool get isCollaborative => _collaborativeManager.isCollaborative;

  /// Firebase connection status.
  bool get isConnectedToFirebase => _collaborativeManager.isConnectedToFirebase;

  /// Connection status text (Swedish).
  String get connectionStatusText => _collaborativeManager.connectionStatusText;

  /// Active collaborative participants.
  List<UserProfile> get collaborativeParticipants =>
      _collaborativeManager.collaborativeParticipants;

  /// Currently active editors.
  List<LiveEditor> get liveEditors => _collaborativeManager.liveEditors;

  // ===== IMAGE MANAGEMENT ACCESSORS =====

  /// Image upload operation state for UI progress indication and interaction control.
  /// Indicates active image upload operation for progress display
  /// and user interaction management during image processing operations.
  bool get isUploadingImage => _imageManager.isUploadingImage;

  /// Image upload error message for user feedback and error handling.
  /// Provides localized error messages from image upload operations
  /// for user display and comprehensive error state management.
  String? get imageUploadError => _imageManager.imageUploadError;

  /// Image upload error state indicator for UI conditional rendering and error handling.
  /// Indicates presence of image upload errors for UI error display decisions
  /// and error state management throughout image operations.
  bool get hasImageUploadError => _imageManager.hasImageUploadError;

  /// Image addition capability indicator for UI control and limit enforcement.
  /// Indicates whether additional images can be added based on image limits
  /// enabling UI control state and image limit enforcement.
  bool get canAddMoreImages => _imageManager.canAddMoreImages;

  // ===== ENHANCED UPLOAD PROGRESS TRACKING =====

  /// Individual image upload statuses for detailed progress visualization and error handling.
  /// Provides comprehensive upload status information for each image including progress percentages,
  /// error states, retry counts, and upload speeds for advanced UI progress indication.
  Map<String, ImageUploadStatus> get imageUploadStatuses =>
      _imageManager.imageUploadStatuses;

  /// Upload queue summary for overall upload progress display and user feedback.
  /// Provides aggregated upload queue information including active upload counts,
  /// overall progress percentage, and localized status text for comprehensive upload management.
  Map<String, dynamic> get uploadQueueSummary =>
      _imageManager.uploadQueueSummary;

  /// Upload queue status text for banner display and user progress indication.
  /// Returns Swedish localized status text describing current upload queue state
  /// for banner display and user progress feedback during image upload operations.
  String? get uploadQueueStatusText {
    final summary = uploadQueueSummary;
    return summary['statusText'] as String?;
  }

  /// Overall upload progress percentage for progress bars and completion indication.
  /// Returns aggregated upload progress as percentage (0-100) for overall progress
  /// bar display and upload completion status indication.
  int get uploadProgressPercentage {
    final summary = uploadQueueSummary;
    return summary['progressPercentage'] as int;
  }

  /// Active upload indicator for UI state management and interaction control.
  /// Indicates whether any uploads are currently active (pending, uploading, or retrying)
  /// for UI state management and user interaction control during active operations.
  bool get hasActiveUploads {
    final summary = uploadQueueSummary;
    return summary['hasActivity'] as bool;
  }

  /// Failed upload count for error indication and recovery action display.
  /// Returns count of failed uploads for error state indication and
  /// recovery action button display in the user interface.
  int get failedUploadsCount {
    final summary = uploadQueueSummary;
    return summary['failed'] as int;
  }

  /// Individual image upload progress for specific image progress indicators.
  /// [pathOrUrl] File path or URL identifier for the image
  /// Returns upload progress (0.0 to 1.0) for specific image enabling
  /// individual image progress indicator display and detailed status tracking.
  double getImageUploadProgress(String pathOrUrl) =>
      _imageManager.getUploadProgress(pathOrUrl);

  /// Individual image upload status for detailed progress and error information.
  /// [pathOrUrl] File path or URL identifier for the image
  /// Returns complete ImageUploadStatus for specific image including progress,
  /// error details, retry information, and speed metrics for advanced UI display.
  ImageUploadStatus? getImageUploadStatus(String pathOrUrl) =>
      _imageManager.imageUploadStatuses[pathOrUrl];

  /// Retry failed upload with exponential backoff and comprehensive error handling.
  /// [pathOrUrl] File path or URL identifier for the failed image
  /// Initiates retry sequence for failed upload with exponential backoff delay,
  /// error classification, and comprehensive retry management for improved upload resilience.
  Future<void> retryImageUpload(String pathOrUrl) async {
    await _imageManager.retryFailedUpload(pathOrUrl);
  }

  /// Cancel specific image upload with state cleanup and user feedback.
  /// [pathOrUrl] File path or URL identifier for the image to cancel
  /// Cancels individual image upload and removes from upload queue with proper
  /// state cleanup and user feedback for granular upload management control.
  Future<void> cancelImageUpload(String pathOrUrl) async {
    await _imageManager.removeImageAndCleanup(pathOrUrl);
  }

  // ===== BULK UPLOAD MANAGEMENT =====

  /// Retry all failed uploads with comprehensive error handling and user feedback.
  /// Performs bulk retry operation for all retryable failed uploads
  /// with individual error handling and comprehensive progress tracking.
  Future<void> retryAllFailedUploads() async {
    await _imageManager.retryAllFailedUploads();
  }

  /// Cancel all active uploads with state cleanup and user feedback.
  /// Cancels all currently active uploads with comprehensive state cleanup
  /// for enhanced upload queue management and user control.
  void cancelAllActiveUploads() {
    _imageManager.cancelAllActiveUploads();
  }

  /// Clear all failed uploads from state for clean queue management.
  /// Removes all failed uploads from tracking state for clean upload queue
  /// management and enhanced user experience.
  void clearAllFailedUploads() {
    _imageManager.clearAllFailedUploads();
  }

  /// Upload management summary for bulk operation UI and user feedback.
  /// Provides comprehensive upload management information including failed,
  /// active, and completed counts for bulk operation UI and management controls.
  Map<String, dynamic> get uploadManagementSummary =>
      _imageManager.uploadManagementSummary;

  /// Check if bulk retry operation is available and beneficial.
  /// Indicates whether bulk retry controls should be shown for enhanced
  /// upload management and user experience.
  bool get canBulkRetry =>
      uploadManagementSummary['canBulkRetry'] as bool? ?? false;

  /// Check if bulk cancel operation is available for active uploads.
  /// Indicates whether bulk cancel controls should be shown for active
  /// upload management and enhanced user control.
  bool get canBulkCancel =>
      uploadManagementSummary['canBulkCancel'] as bool? ?? false;

  /// Check if there are failed uploads that can be cleared.
  /// Indicates whether clear failed uploads control should be shown
  /// for enhanced queue management and user experience.
  bool get hasRetryableFailures => _imageManager.hasRetryableFailures;

  // ===== BACKGROUND NOTIFICATION SYSTEM =====

  /// Stream of upload notification events for UI subscription and feedback.
  /// Provides real-time upload events including completion, failures, progress milestones,
  /// and queue state changes for enhanced user feedback and notification system integration.
  static Stream<UploadNotificationEvent> get uploadNotificationStream =>
      RecipeImageManager.notificationStream;

  // ===== PERMISSION SYSTEM ACCESSORS =====

  /// Edit permission for form modification and content management functionality.
  /// Indicates whether user has edit permission for recipe form modification
  /// enabling comprehensive form editing and content management capabilities.
  bool get canEdit => _permissionManager.canEdit;

  /// View permission for recipe form display and content access functionality.
  /// Indicates whether user has view permission for recipe form display
  /// enabling content access and form viewing capabilities.
  bool get canView => _permissionManager.canView;

  /// Share permission for collaborative features and recipe distribution functionality.
  /// Indicates whether user has share permission for collaborative sharing
  /// enabling recipe distribution and collaborative feature access.
  bool get canShare => _permissionManager.canShare;

  /// Invite permission for collaborative member management and invitation functionality.
  /// Indicates whether user has invite permission for collaborative invitations
  /// enabling member management and collaborative team building.
  bool get canInvite => _permissionManager.canInvite;

  /// Delete permission for recipe removal and cleanup operations.
  /// Indicates whether user has delete permission for recipe removal
  /// enabling comprehensive recipe management and cleanup functionality.
  bool get canDelete => _permissionManager.canDelete;

  /// Owner status for administrative functions and comprehensive recipe management.
  /// Indicates whether user is recipe owner enabling administrative functions
  /// and comprehensive recipe management capabilities.
  bool get isOwner => _permissionManager.isOwner;

  /// Permission availability indicator for UI conditional rendering and feature enabling.
  /// Indicates whether user has any permissions for UI conditional display
  /// and feature availability throughout recipe form functionality.
  bool get hasPermissions => _permissionManager.hasPermissions;

  // ===== FORM CONFIGURATION CONSTANTS =====

  /// Available meal types for Swedish localized meal categorization and selection.
  /// Provides comprehensive meal type options with Swedish localization
  /// for recipe categorization and meal planning functionality.
  static const List<String> mealTypes = RecipeFormState.mealTypes;

  /// Maximum image limit for performance optimization and storage management.
  /// Defines maximum number of images per recipe for performance optimization
  /// and storage resource management throughout image operations.
  static const int maxImages = RecipeFormState.maxImages;

  // ===== RECIPE MANAGEMENT OPERATIONS =====

  /// Saves recipe with atomic coordination through persistence manager.
  /// Delegates to RecipePersistenceManager for comprehensive save coordination including:
  /// - Atomic save operation locking
  /// - Image upload completion coordination
  /// - Auto-save conflict prevention
  /// - Collaborative state synchronization
  /// Returns saved Recipe instance if successful, null if validation fails or save errors occur.
  Future<Recipe?> saveRecipe() async {
    return await _persistenceManager.saveRecipe(
      isCollaborative: isCollaborative,
      onNotify: _coordinator.safeNotifyParent,
    );
  }

  /// Forks recipe creating independent copy through persistence manager.
  /// Delegates to RecipePersistenceManager for complete fork coordination including:
  /// - Recipe data duplication with new unique identifier
  /// - Service-coordinated recipe creation with error handling
  /// - Auto-save draft cleanup for consistency
  /// Returns forked Recipe instance if successful, null if operation fails.
  Future<Recipe?> forkRecipe() async {
    return await _persistenceManager.forkRecipe();
  }

  /// Deletes recipe through persistence manager with cleanup coordination.
  /// Delegates to RecipePersistenceManager for complete deletion including:
  /// - Permission validation for delete operation authorization
  /// - Service-coordinated recipe deletion with error handling
  /// - Collaborative state cleanup and participant notification
  /// - Image and resource cleanup for complete removal
  /// Returns true if deletion succeeds, false if operation fails or permission denied.
  Future<bool> deleteRecipe() async {
    return await _persistenceManager.deleteRecipe(
      isCollaborative: isCollaborative,
    );
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
  /// Returns list of DraftMetadata for recent drafts that can be restored.
  /// Provides draft information including creation time, modification time,
  /// title preview, and content significance for optimal user experience.
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
  /// [draftId] Unique identifier for the draft to restore
  /// Returns true if draft was successfully loaded and form state restored,
  /// false if draft loading failed or draft data was corrupted.
  /// Performs complete form state restoration including all field types.
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
        _coordinator.syncToCollaborative(isCollaborative: isCollaborative);
      }
      return success;
    } catch (e) {
      AppLogger.error('Error loading draft in ViewModel: $e');
      return false;
    }
  }

  /// Serialize current form data for analysis and feedback
  /// Returns Map containing all current form field values for
  /// content analysis, field counting, and user feedback purposes.
  /// Used primarily for providing detailed restoration feedback.
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
  /// [title] New recipe title for form state and collaborative updates
  /// Delegates to RecipeFormState for title management with automatic collaborative
  /// synchronization for real-time updates in collaborative editing mode.
  void setTitle(String title) {
    _state.setTitle(title);
    _coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  /// Updates recipe description with comprehensive state management and collaborative coordination.
  /// [description] New recipe description for detailed content management
  /// Performs description update with automatic collaborative synchronization
  /// enabling real-time content updates in collaborative editing scenarios.
  void setDescription(String description) {
    _state.setDescription(description);
    _coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  /// Updates meal type selection with Swedish localization and collaborative synchronization.
  /// [mealType] New meal type for recipe categorization and meal planning
  /// Manages meal type update with automatic collaborative synchronization
  /// for consistent categorization in collaborative editing mode.
  void setMealType(String mealType) {
    _state.setMealType(mealType);
    _coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  /// Updates portion count with nullable support and collaborative coordination.
  /// [portions] New portion count for serving size management
  /// Handles portion update with automatic collaborative synchronization
  /// supporting nullable values for optional portion information.
  void setPortions(int? portions) {
    _state.setPortions(portions);
    _coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  /// Updates cooking time with nullable support and collaborative synchronization.
  /// [timeMinutes] New cooking time in minutes for meal planning
  /// Manages time update with automatic collaborative synchronization
  /// supporting nullable values for optional timing information.
  void setTimeMinutes(int? timeMinutes) {
    _state.setTimeMinutes(timeMinutes);
    _coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  /// Updates recipe rating with nullable support and collaborative coordination.
  /// [rating] New recipe rating for quality assessment
  /// Handles rating update with automatic collaborative synchronization
  /// supporting nullable values for unrated recipes.
  void setRating(double? rating) {
    _state.setRating(rating);
    _coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  /// Updates source URL with nullable support and collaborative synchronization.
  /// [sourceUrl] New source URL for recipe attribution and external linking
  /// Manages source URL update with automatic collaborative synchronization
  /// supporting nullable values for original recipes without external sources.
  void setSourceUrl(String? sourceUrl) {
    _state.setSourceUrl(sourceUrl);
    _coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  // ===== BACKWARD COMPATIBILITY SUPPORT =====

  /// Sets portions from double value with automatic conversion for backward compatibility.
  /// [portions] Double portion value for automatic integer conversion
  /// Provides backward compatibility for existing code using double values
  /// with automatic conversion to integer for consistent portion management.
  void setPortionsFromDouble(double? portions) {
    setPortions(portions?.toInt());
  }

  /// Sets cooking time from double value with automatic conversion for backward compatibility.
  /// [timeMinutes] Double time value for automatic integer conversion
  /// Provides backward compatibility for existing code using double values
  /// with automatic conversion to integer for consistent time management.
  void setTimeMinutesFromDouble(double? timeMinutes) {
    setTimeMinutes(timeMinutes?.toInt());
  }

  // ===== COMPREHENSIVE IMAGE MANAGEMENT OPERATIONS =====

  /// Displays image picker dialog with comprehensive selection options and upload coordination.
  /// [context] BuildContext for dialog display and UI coordination
  /// Delegates to RecipeImageManager for image selection dialog with automatic
  /// image URL synchronization and collaborative state management.
  @override
  Future<void> showImagePickerDialog(BuildContext context) async {
    AppLogger.info('🎯 VIEWMODEL: showImagePickerDialog called');
    final recipeId = _state.originalRecipe?.id ??
        'temp_${DateTime.now().millisecondsSinceEpoch}';
    AppLogger.info('🎯 VIEWMODEL: Using recipeId for image upload: $recipeId');
    await _imageManager.showImagePickerDialog(context, recipeId: recipeId);
    AppLogger.info(
        '🎯 VIEWMODEL: _imageManager.showImagePickerDialog completed');
    // Use post-frame callback to prevent setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLogger.info(
          '🎯 VIEWMODEL: Running _syncImageUrls in post-frame callback');
      _coordinator.syncImageUrls(isCollaborative: isCollaborative);
    });
  }

  /// Adds image from URL with validation and comprehensive state synchronization.
  /// [imageUrl] Image URL for addition to recipe image collection
  /// Performs image URL addition through RecipeImageManager with automatic
  /// state synchronization and collaborative coordination.
  @override
  Future<void> addImageFromUrl(String imageUrl) async {
    await _imageManager.addImageFromUrl(imageUrl);
    _coordinator.syncImageUrls(isCollaborative: isCollaborative);
  }

  /// Uploads image from file with comprehensive processing and storage coordination.
  /// [imageFile] XFile instance for image upload and processing
  /// Performs image file upload through RecipeImageManager with automatic
  /// recipe ID generation and comprehensive state synchronization.
  Future<void> uploadImageFromFile(XFile imageFile) async {
    final recipeId = _state.originalRecipe?.id ??
        'temp_${DateTime.now().millisecondsSinceEpoch}';
    await _imageManager.uploadImageFromFile(imageFile, recipeId);
    _coordinator.syncImageUrls(isCollaborative: isCollaborative);
  }

  /// Removes image with comprehensive cleanup and storage management.
  /// [imageUrl] Image URL for removal and cleanup operations
  /// Delegates to RecipeImageManager for image removal with automatic
  /// cleanup, storage management, and state synchronization.
  @override
  Future<void> removeImageAndCleanup(String imageUrl) async {
    await _imageManager.removeImageAndCleanup(imageUrl);
    _coordinator.syncImageUrls(isCollaborative: isCollaborative);
  }

  /// Moves image to first position for primary image designation and visual hierarchy.
  /// [imageUrl] Image URL for primary position assignment
  /// Performs image reordering through RecipeImageManager with automatic
  /// state synchronization and collaborative coordination.
  @override
  void moveImageToFirst(String imageUrl) {
    _imageManager.moveImageToFirst(imageUrl);
    _coordinator.syncImageUrls(isCollaborative: isCollaborative);
  }

  /// Reorders images with comprehensive position management and state coordination.
  /// [oldIndex] Current image position for reordering operation
  /// [newIndex] Target image position for reordering coordination
  /// Delegates to RecipeImageManager for image reordering with automatic
  /// state synchronization and collaborative updates.
  void reorderImages(int oldIndex, int newIndex) {
    _imageManager.reorderImages(oldIndex, newIndex);
    _coordinator.syncImageUrls(isCollaborative: isCollaborative);
  }

  // ===== COLLABORATIVE OPERATIONS (Delegate to collaborative manager) =====

  Future<void> enableCollaborativeMode() async {
    if (_state.originalRecipe == null) return;

    await _collaborativeManager.enableCollaborativeMode(_state.originalRecipe!);
  }

  Future<void> inviteUserToCollaboration(String userId, String userDisplayName,
      ResourcePermission permission) async {
    await _collaborativeManager.inviteUserToCollaboration(
        userId, userDisplayName, permission);
  }

  Future<void> removeUserFromCollaboration(String userId) async {
    await _collaborativeManager.removeUserFromCollaboration(userId);
  }

  Future<void> leaveCollaborativeMode() async {
    await _collaborativeManager.leaveCollaborativeMode();
  }

  // ===== PERMISSION OPERATIONS (Delegate to permission manager) =====

  Future<void> updateUserPermission(
      String userId, ResourcePermission permission) async {
    if (_state.originalRecipe == null) return;

    _permissionManager.updateUserPermission(
        _state.originalRecipe!.id, userId, permission);
  }

  Future<void> shareRecipeWithUser(
      String userId, ResourcePermission permission) async {
    if (_state.originalRecipe == null) return;

    _permissionManager.shareRecipeWithUser(
        _state.originalRecipe!.id, userId, permission);
  }

  bool canPerformAction(String action) {
    return _permissionManager.canPerformAction(action);
  }

  bool canEditField(String fieldName) {
    return _permissionManager.canEditField(fieldName);
  }

  // ===== INTERNAL COORDINATION AND STATE MANAGEMENT =====

  /// Establishes comprehensive manager listener coordination for reactive state management.
  /// Sets up listener connections to all focused managers ensuring automatic UI notification
  /// and state synchronization across form state, collaborative editing, image management,
  /// and permission systems for comprehensive reactive state coordination.

  /// Performs comprehensive ViewModel disposal with manager cleanup and memory management.
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

    AppLogger.info(
        'RecipeFormViewModel with unified error coordination disposed');
    super.dispose();
  }
}
