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
import 'package:butlery/models/tagging/tag_overrides.dart';
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

// Import for feedback loop
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';

// Import for tagging validation preview
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';

/// Coordinator for recipe form operations with delegation to specialized managers.
class RecipeFormViewModel extends ChangeNotifier
    with
        ErrorHandlingMixin,
        ErrorCoordinatorMixin,
        RecipeBackwardCompatibilityMixin,
        WidgetsBindingObserver {
  final UnifiedRecipeService _recipeService;

  bool _disposed = false;
  bool get disposed => _disposed;

  // Tagging validation state
  List<String> _unknownIngredients = [];
  bool _isCheckingIngredients = false;
  double? _ingredientCoverage;

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

    // Register lifecycle observer for auto-save on app background/kill
    WidgetsBinding.instance.addObserver(this);

    // Feedback loop: Retrieve original ParsedRecipe for imported recipes
    // This enables diff calculation when user saves, capturing corrections
    // as training data for parser improvement.
    if (initialRecipe?.sourceUrl != null && isTemplate) {
      final cache = ServiceLocator.tryGet<ParsedRecipeCache>();
      if (cache != null) {
        final parsed = cache.retrieve(initialRecipe!.sourceUrl!);
        if (parsed != null) {
          _state.setOriginalParsedRecipe(parsed);
          AppLogger.debug(
            '📊 Retrieved ParsedRecipe for feedback loop: ${initialRecipe.sourceUrl}',
          );
        }
      }
    }
  }

  Recipe? get originalRecipe => _state.originalRecipe;

  /// Gets current recipe with form values for tag editing.
  /// Returns original recipe with current tagOverrides applied, or null if creating new.
  Recipe? get recipe {
    final original = originalRecipe;
    if (original == null) return null;
    return original.copyWith(tagOverrides: _state.tagOverrides);
  }

  bool get isSaving => _state.isSaving;
  bool get isForking => _state.isForking;
  String? get error => _state.error;
  bool get hasError => _state.hasError;
  bool get isEditing => _state.isEditing;
  bool get isValid => _state.isValid;
  bool get isAutoSaving => _state.isAutoSaving;
  bool get hasRecentAutoSave => _state.hasRecentAutoSave;

  /// CRITICAL: Detects unsaved changes to prevent data loss on navigation.
  bool get hasUnsavedChanges {
    if (!isEditing || originalRecipe == null) return false;

    final original = originalRecipe!;

    return title != original.title ||
        description != original.description ||
        mealType != original.mealType ||
        portions != original.portions ||
        timeMinutes != original.timeMinutes ||
        rating != original.rating ||
        sourceUrl != original.sourceUrl ||
        !_listEquals(ingredients, original.ingredients) ||
        !_listEquals(instructions, original.instructions) ||
        !_listEquals(tags, original.personalTagIds) ||
        !_listEquals(_imageManager.validImageUrls, original.imageUrls);
  }

  bool _listEquals<T>(List<T>? list1, List<T>? list2) {
    if (list1 == null && list2 == null) return true;
    if (list1 == null || list2 == null) return false;
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  String get title => _state.title;
  String get description => _state.description;
  String get mealType => _state.mealType;
  int? get portions => _state.portions;
  int? get timeMinutes => _state.timeMinutes;
  double? get rating => _state.rating;
  List<String> get imageUrls => _imageManager.imageUrls;
  String? get sourceUrl => _state.sourceUrl;
  List<String> get ingredients => _state.ingredients;
  List<String> get instructions => _state.instructions;
  List<String> get tags => _state.tags;

  // Parse quality for imported recipes (null when not an import)
  bool get needsReview => _state.originalParsedRecipe?.needsReview ?? false;
  double? get parseQuality => _state.originalParsedRecipe?.overallQuality;
  List<String> get fieldsNeedingImprovement =>
      _state.originalParsedRecipe?.fieldsNeedingImprovement ?? [];

  FormFieldsManager get ingredientsManager => _state.ingredientsManager;
  FormFieldsManager get instructionsManager => _state.instructionsManager;
  FormFieldsManager get tagsManager => _state.tagsManager;

  @override
  bool get isCollaborative => _collaborativeManager.isCollaborative;
  bool get isConnectedToFirebase => _collaborativeManager.isConnectedToFirebase;
  String get connectionStatusText => _collaborativeManager.connectionStatusText;
  List<UserProfile> get collaborativeParticipants =>
      _collaborativeManager.collaborativeParticipants;
  List<LiveEditor> get liveEditors => _collaborativeManager.liveEditors;

  bool get isUploadingImage => _imageManager.isUploadingImage;
  String? get imageUploadError => _imageManager.imageUploadError;
  bool get hasImageUploadError => _imageManager.hasImageUploadError;
  bool get canAddMoreImages => _imageManager.canAddMoreImages;
  Map<String, ImageUploadStatus> get imageUploadStatuses =>
      _imageManager.imageUploadStatuses;
  Map<String, dynamic> get uploadQueueSummary =>
      _imageManager.uploadQueueSummary;

  String? get uploadQueueStatusText {
    final summary = uploadQueueSummary;
    return summary['statusText'] as String?;
  }

  int get uploadProgressPercentage {
    final summary = uploadQueueSummary;
    return summary['progressPercentage'] as int;
  }

  bool get hasActiveUploads {
    final summary = uploadQueueSummary;
    return summary['hasActivity'] as bool;
  }

  int get failedUploadsCount {
    final summary = uploadQueueSummary;
    return summary['failed'] as int;
  }

  // Tagging validation getters
  List<String> get unknownIngredients => List.unmodifiable(_unknownIngredients);
  bool get hasUnknownIngredients => _unknownIngredients.isNotEmpty;
  bool get isCheckingIngredients => _isCheckingIngredients;
  double? get ingredientCoverage => _ingredientCoverage;

  double getImageUploadProgress(String pathOrUrl) =>
      _imageManager.getUploadProgress(pathOrUrl);

  ImageUploadStatus? getImageUploadStatus(String pathOrUrl) =>
      _imageManager.imageUploadStatuses[pathOrUrl];

  Future<void> retryImageUpload(String pathOrUrl) async {
    await _imageManager.retryFailedUpload(pathOrUrl);
  }

  Future<void> cancelImageUpload(String pathOrUrl) async {
    await _imageManager.removeImageAndCleanup(pathOrUrl);
  }

  Future<void> retryAllFailedUploads() async {
    await _imageManager.retryAllFailedUploads();
  }

  void cancelAllActiveUploads() {
    _imageManager.cancelAllActiveUploads();
  }

  void clearAllFailedUploads() {
    _imageManager.clearAllFailedUploads();
  }

  Map<String, dynamic> get uploadManagementSummary =>
      _imageManager.uploadManagementSummary;

  bool get canBulkRetry =>
      uploadManagementSummary['canBulkRetry'] as bool? ?? false;

  bool get canBulkCancel =>
      uploadManagementSummary['canBulkCancel'] as bool? ?? false;

  bool get hasRetryableFailures => _imageManager.hasRetryableFailures;

  static Stream<UploadNotificationEvent> get uploadNotificationStream =>
      RecipeImageManager.notificationStream;

  bool get canEdit => _permissionManager.canEdit;
  bool get canView => _permissionManager.canView;
  bool get canShare => _permissionManager.canShare;

  bool get canInvite => _permissionManager.canInvite;
  bool get canDelete => _permissionManager.canDelete;
  bool get isOwner => _permissionManager.isOwner;
  bool get hasPermissions => _permissionManager.hasPermissions;

  static const List<String> mealTypes = RecipeFormState.mealTypes;
  static const int maxImages = RecipeFormState.maxImages;

  bool get isFirstRecipe => _persistenceManager.isFirstRecipe;

  Future<Recipe?> saveRecipe() async {
    return await _persistenceManager.saveRecipe(
      isCollaborative: isCollaborative,
      onNotify: _coordinator.safeNotifyParent,
    );
  }

  Future<Recipe?> forkRecipe() async {
    return await _persistenceManager.forkRecipe();
  }

  Future<bool> deleteRecipe() async {
    return await _persistenceManager.deleteRecipe(
      isCollaborative: isCollaborative,
    );
  }

  void _onStateError() {
    if (_disposed) return;
    if (_state.hasError) {
      reportError(
        source: ErrorSource.formValidation,
        message: _state.error!,
        severity: ErrorSeverity.medium,
      );
    }
  }

  void _onImageError() {
    if (_disposed) return;
    if (_imageManager.hasImageUploadError) {
      reportError(
        source: ErrorSource.imageUpload,
        message: _imageManager.imageUploadError!,
        severity: ErrorSeverity.high,
        actions: [ErrorRecoveryAction.retry, ErrorRecoveryAction.ignore],
      );
    }
  }

  void _initializeManagerErrorCoordination() {
    _state.addListener(_onStateError);
    _imageManager.addListener(_onImageError);
  }

  UnifiedErrorCoordinator get errorCoordinator => _errorCoordinator;

  Future<List<DraftMetadata>> getAvailableDrafts() async {
    return await _state.getAvailableDrafts();
  }

  Future<bool> loadFromDraft(String draftId) async {
    try {
      final success = await _state.loadFromDraft(draftId);
      if (success) {
        _coordinator.syncToCollaborative(isCollaborative: isCollaborative);
      }
      return success;
    } catch (e) {
      AppLogger.error('Error loading draft in ViewModel: $e');
      return false;
    }
  }

  Map<String, dynamic> serializeCurrentFormData() {
    return _state.serializeFormData();
  }

  void setTitle(String title) {
    _state.setTitle(title);
    _coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  void setDescription(String description) {
    _state.setDescription(description);
    _coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  void setMealType(String mealType) {
    _state.setMealType(mealType);
    _coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  void setPortions(int? portions) {
    _state.setPortions(portions);
    _coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  void setTimeMinutes(int? timeMinutes) {
    _state.setTimeMinutes(timeMinutes);
    _coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  void setRating(double? rating) {
    _state.setRating(rating);
    _coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  void setSourceUrl(String? sourceUrl) {
    _state.setSourceUrl(sourceUrl);
    _coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  void setTagOverrides(TagOverrides overrides) {
    _state.setTagOverrides(overrides);
    _coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  /// Sets personal tag names from PersonalTagSelector.
  void setPersonalTagNames(List<String> tagNames) {
    _state.setPersonalTagNames(tagNames);
    _coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  void setPortionsFromDouble(double? portions) {
    setPortions(portions?.toInt());
  }

  void setTimeMinutesFromDouble(double? timeMinutes) {
    setTimeMinutes(timeMinutes?.toInt());
  }

  @override
  Future<void> showImagePickerDialog(BuildContext context) async {
    AppLogger.info('VIEWMODEL: showImagePickerDialog called');
    final recipeId = _state.originalRecipe?.id ??
        'temp_${DateTime.now().millisecondsSinceEpoch}';
    AppLogger.info('VIEWMODEL: Using recipeId for image upload: $recipeId');
    await _imageManager.showImagePickerDialog(context, recipeId: recipeId);
    AppLogger.info('VIEWMODEL: _imageManager.showImagePickerDialog completed');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLogger.info(
          'VIEWMODEL: Running _syncImageUrls in post-frame callback');
      _coordinator.syncImageUrls(isCollaborative: isCollaborative);
    });
  }

  @override
  Future<void> addImageFromUrl(String imageUrl) async {
    await _imageManager.addImageFromUrl(imageUrl);
    _coordinator.syncImageUrls(isCollaborative: isCollaborative);
  }

  Future<void> uploadImageFromFile(XFile imageFile) async {
    final recipeId = _state.originalRecipe?.id ??
        'temp_${DateTime.now().millisecondsSinceEpoch}';
    await _imageManager.uploadImageFromFile(imageFile, recipeId);
    _coordinator.syncImageUrls(isCollaborative: isCollaborative);
  }

  @override
  Future<void> removeImageAndCleanup(String imageUrl) async {
    await _imageManager.removeImageAndCleanup(imageUrl);
    _coordinator.syncImageUrls(isCollaborative: isCollaborative);
  }

  @override
  void moveImageToFirst(String imageUrl) {
    _imageManager.moveImageToFirst(imageUrl);
    _coordinator.syncImageUrls(isCollaborative: isCollaborative);
  }

  void reorderImages(int oldIndex, int newIndex) {
    _imageManager.reorderImages(oldIndex, newIndex);
    _coordinator.syncImageUrls(isCollaborative: isCollaborative);
  }

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

  /// Checks if ingredients are recognized by the tagging system.
  ///
  /// This provides a preview of which ingredients will be used for
  /// automatic tagging, helping users understand potential tagging gaps.
  ///
  /// Returns the list of unrecognized ingredients.
  Future<List<String>> checkIngredientRecognition() async {
    if (_disposed) return [];

    _isCheckingIngredients = true;
    notifyListeners();

    try {
      final lookupService = ServiceLocator.get<IngredientLookupService>();
      final ingredientList =
          _state.ingredients.where((i) => i.trim().isNotEmpty).toList();

      if (ingredientList.isEmpty) {
        _unknownIngredients = [];
        _ingredientCoverage = null;
        return [];
      }

      final result = await lookupService.lookupIngredients(ingredientList);

      _unknownIngredients = result.unmatched;
      _ingredientCoverage = result.coverage;

      return _unknownIngredients;
    } catch (e) {
      AppLogger.warning(
        'Failed to check ingredient recognition: $e',
        'RecipeFormViewModel',
      );
      return [];
    } finally {
      _isCheckingIngredients = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  /// Clears the ingredient recognition check results.
  void clearIngredientCheck() {
    _unknownIngredients = [];
    _ingredientCoverage = null;
    _isCheckingIngredients = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _state.flushAutoSave();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    clearComponentErrors();

    // Remove error coordination listeners before disposing managers
    _state.removeListener(_onStateError);
    _imageManager.removeListener(_onImageError);

    // CRITICAL: Cancel uploads FIRST to prevent race condition crashes
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
