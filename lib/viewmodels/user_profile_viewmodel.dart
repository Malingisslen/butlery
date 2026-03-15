/// User profile ViewModel for form management, avatar upload, privacy settings, and real-time validation (Swedish).
/// ```dart
/// final vm = UserProfileViewModel(userService, storageService, imagePickerService);
/// vm.updateDisplayName('Erik');
/// await vm.uploadAvatar();
/// await vm.saveProfile();

// lib/viewmodels/user_profile_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// User profile ViewModel for profile form management, avatar uploads, validation, and privacy settings (MVVM).
class UserProfileViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final UserService _userService;
  final ImagePickerService _imagePickerService;
  final ImageUploadService _uploadService;

  // State
  String _displayName = '';
  String? _avatarUrl;
  bool _isSearchable = true;
  bool _allowEmailSearch = false;
  bool _isUploadingAvatar = false;
  bool _hasUnsavedChanges = false;
  String? _displayNameError;
  String? _operationError;

  UserProfileViewModel(
    this._userService,
    this._imagePickerService, {
    ImageUploadService? uploadService,
  }) : _uploadService =
            uploadService ?? ServiceLocator.get<ImageUploadService>() {
    _loadCurrentProfile();
    _userService.addListener(_onUserServiceChanged);
  }

  // Getters
  String get displayName => _displayName;
  String? get avatarUrl => _avatarUrl;
  bool get isSearchable => _isSearchable;
  bool get allowEmailSearch => _allowEmailSearch;
  bool get isLoading => _isUploadingAvatar;
  bool get isUploadingAvatar => _isUploadingAvatar;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  String? get displayNameError => _displayNameError;
  String? get error => _operationError ?? _displayNameError;
  bool get hasError => _operationError != null || _displayNameError != null;
  UserProfile? get currentProfile =>
      ServiceLocator.get<UserService>().currentUserProfile;
  bool get hasProfile => currentProfile != null;

  /// Form validation state for submission control
  /// for form submission enabling and comprehensive validation status.
  bool get isFormValid => _displayNameError == null && _displayName.isNotEmpty;

  /// Updates display name with comprehensive validation and change tracking.
  /// [value] New display name value for profile identification
  /// Performs automatic trimming, validation, change detection, and UI notification
  /// for seamless display name management with real-time feedback and form coordination.
  void updateDisplayName(String value) {
    _displayName = value.trim();
    _validateDisplayName();
    _checkForChanges();
    notifyListeners();
  }

  /// Updates searchability privacy preference with change tracking and state coordination.
  /// [value] New searchability preference for profile discovery control
  /// Controls whether user profile can be discovered by other users through search functionality,
  /// providing comprehensive privacy preference management with automatic change detection.
  void updateIsSearchable(bool value) {
    _isSearchable = value;
    _checkForChanges();
    notifyListeners();
  }

  /// Updates email search privacy preference with comprehensive privacy control.
  /// [value] New email search preference for email-based profile discovery control
  /// Controls whether user profile can be discovered through email lookup functionality,
  /// providing granular privacy control with automatic change detection and state management.
  void updateAllowEmailSearch(bool value) {
    _allowEmailSearch = value;
    _checkForChanges();
    notifyListeners();
  }

  /// Uploads new avatar image with comprehensive progress tracking and service coordination.
  /// Returns true if avatar upload succeeds, false if operation fails or user cancels.
  /// Manages complete avatar upload flow including image selection, processing, upload progress,
  /// and URL management with automatic change detection and comprehensive error handling.
  /// **Upload Process:**
  /// - Image selection from device gallery through ImagePickerService
  /// - Secure upload to cloud storage with user-specific path structure
  /// - URL retrieval and local state update with change tracking
  /// - Progress indication and error handling with user feedback
  /// **Usage Example:**
  /// ```dart
  /// final avatarUploaded = await profileViewModel.uploadAvatar();
  /// if (avatarUploaded) {
  ///   // Show success message and update UI
  /// } else {
  ///   // Handle upload failure or cancellation
  /// }
  /// ```
  Future<bool> uploadAvatar() async {
    AppLogger.debug('🖼️ VIEWMODEL: uploadAvatar called');
    _isUploadingAvatar = true;
    _operationError = null; // Clear any previous errors
    notifyListeners();

    try {
      AppLogger.debug('🖼️ VIEWMODEL: Starting avatar upload');

      // Pick image from gallery - do NOT use safeExecute here as it swallows errors
      AppLogger.debug('🖼️ VIEWMODEL: Calling image picker service');
      final imageFile =
          await _imagePickerService.pickImage(ImageSource.gallery);

      if (imageFile == null) {
        AppLogger.info('🖼️ VIEWMODEL: No image selected (user cancelled)');
        // User cancelled - not an error
        return false;
      }
      AppLogger.info('🖼️ VIEWMODEL: Image selected: ${imageFile.path}');

      // Get current user ID
      final userId = ServiceLocator.get<PermissionService>().currentUserId;
      if (userId == null) {
        _operationError = AppLocale.current.errorNoUserLoggedIn;
        throw Exception(_operationError);
      }

      // Read bytes from file (works on both mobile and web)
      final bytes = await imageFile.readAsBytes();

      // Upload avatar using bytes-based method (correct Storage path: users/{uid}/avatars/...)
      final result = await _uploadService.uploadImageFromBytes(
        bytes: bytes,
        userId: userId,
        fileName: imageFile.path.split('/').last,
        prefix: 'avatar',
      );

      if (result.success && result.url != null) {
        _avatarUrl = result.url;
        _checkForChanges();
        AppLogger.success('✅ Avatar uploaded with automatic retry support');
        return true;
      } else {
        _operationError =
            result.error ?? AppLocale.current.errorCouldNotUpdate('avatar');
        throw Exception(_operationError);
      }
    } catch (e, stackTrace) {
      AppLogger.error('🖼️ VIEWMODEL ERROR: Exception in uploadAvatar: $e');
      AppLogger.error('🖼️ VIEWMODEL ERROR: Stack trace: $stackTrace');
      _operationError ??= '${AppLocale.current.errorGeneric}: ${e.toString()}';
      return false;
    } finally {
      _isUploadingAvatar = false;
      notifyListeners();
    }
  }

  /// Removes current avatar with immediate state update and change tracking.
  /// Clears avatar URL from profile state and triggers change detection for unsaved changes management.
  /// Provides immediate avatar removal for user profile customization with automatic UI synchronization.
  void removeAvatar() {
    _avatarUrl = null;
    _checkForChanges();
    notifyListeners();
  }

  /// Saves profile changes with comprehensive validation and service coordination.
  /// Returns true if profile save succeeds, false if validation fails or save operation errors.
  /// Performs complete profile save flow including validation, availability checking, service coordination,
  /// and state management with comprehensive error handling and user feedback.
  /// **Save Process:**
  /// - Form validation including required fields and format checking
  /// - Display name availability verification for changed names
  /// - Service coordination for profile creation or update
  /// - State cleanup and change tracking reset upon success
  /// **Usage Example:**
  /// ```dart
  /// final saved = await profileViewModel.saveProfile();
  /// if (saved) {
  ///   // Navigate to profile view or show success
  /// } else {
  ///   // Display validation errors or save failure
  /// }
  /// ```
  Future<bool> saveProfile() async {
    if (!isFormValid) {
      _handleUserError(AppLocale.current.errorFillRequiredFieldsCorrectly);
      return false;
    }

    // Check if display name is available
    if (_hasDisplayNameChanged()) {
      final isAvailable =
          await _userService.isDisplayNameAvailable(_displayName);
      if (!isAvailable) {
        _displayNameError = AppLocale.current.errorNameAlreadyTaken;
        notifyListeners();
        return false;
      }
    }

    return await safeExecute(() async {
          final updatedProfile = await _userService.createOrUpdateProfile(
            displayName: _displayName,
            avatarUrl: _avatarUrl,
            isSearchable: _isSearchable,
            allowEmailSearch: _allowEmailSearch,
          );

          if (updatedProfile != null) {
            // CRITICAL: Update local state with fresh profile data to prevent stale comparisons
            _displayName = updatedProfile.displayName;
            _avatarUrl = updatedProfile.avatarUrl;
            _isSearchable = updatedProfile.isSearchable;
            _allowEmailSearch = updatedProfile.allowEmailSearch;
            _hasUnsavedChanges = false;
            AppLogger.success(
                '✅ Profil sparad - Settings: isSearchable=${updatedProfile.isSearchable}, allowEmailSearch=${updatedProfile.allowEmailSearch}');
            notifyListeners();
            return true;
          } else {
            throw Exception(_userService.error ??
                AppLocale.current.errorCouldNotUpdate('profil'));
          }
        }, operationName: 'Save profile') ??
        false;
  }

  /// Resets form to current profile values with comprehensive state cleanup.
  /// Reloads profile data from current user profile, clears unsaved changes flag,
  /// removes all validation errors, and synchronizes UI state for clean form reset.
  /// Essential for form cancellation and state restoration operations.
  void resetForm() {
    _loadCurrentProfile();
    _hasUnsavedChanges = false;
    clearError();
    _clearValidationErrors();
    notifyListeners();
  }

  /// Checks display name availability with real-time validation feedback.
  /// Returns true if display name is available, false if taken or validation fails.
  /// Performs real-time availability checking through UserService with automatic
  /// validation error management and immediate UI feedback for display name uniqueness.
  /// **Usage Example:**
  /// ```dart
  /// final isAvailable = await profileViewModel.checkDisplayNameAvailability();
  /// if (!isAvailable) {
  ///   // Display name taken, show error to user
  /// }
  /// ```
  Future<bool> checkDisplayNameAvailability() async {
    if (_displayName.isEmpty) return false;

    return await safeExecute(
          () async {
            final isAvailable =
                await _userService.isDisplayNameAvailable(_displayName);

            if (!isAvailable) {
              _displayNameError = AppLocale.current.errorNameAlreadyTaken;
            } else {
              _displayNameError = null;
            }

            notifyListeners();
            return isAvailable;
          },
          operationName: 'Check display name availability',
        ) ??
        false;
  }

  /// Clears all validation errors with comprehensive state cleanup and UI synchronization.
  /// Removes all field-specific validation errors and notifies UI components
  /// for clean error state management and user experience improvement.
  void clearError() {
    _clearValidationErrors();
    _operationError = null;
    notifyListeners();
  }

  /// Handles user error messages with logging and potential UI feedback coordination.
  /// [message] Error message for user notification and logging
  /// Provides centralized user error handling with logging capability,
  /// designed for extension with UI notification systems for comprehensive user feedback.
  void _handleUserError(String message) {
    // For now, just log - could be extended to show UI messages
    AppLogger.error('User error: $message');
  }

  /// Loads current profile data into form state with comprehensive default handling.
  /// Initializes form fields from existing user profile or sets appropriate defaults
  /// for new profile creation, ensuring consistent form state initialization
  /// and proper change tracking setup for profile management operations.
  void _loadCurrentProfile() {
    final profile = currentProfile;

    if (profile != null) {
      _displayName = profile.displayName;
      _avatarUrl = profile.avatarUrl;
      _isSearchable = profile.isSearchable;
      _allowEmailSearch = profile.allowEmailSearch;
      _hasUnsavedChanges = false;
    } else {
      // Set defaults for new profile - but preserve existing values if we have them
      // This prevents avatar loss during initialization race conditions
      if (_displayName.isEmpty) _displayName = '';
      // Don't reset avatarUrl to null if we already have one
      _isSearchable = _isSearchable; // Keep current value
      _allowEmailSearch = _allowEmailSearch; // Keep current value
      _hasUnsavedChanges = false;
    }
  }

  /// Validates display name format and requirements with comprehensive Swedish localized feedback.
  /// Performs complete display name validation including emptiness check, length requirements,
  /// and character format validation with Unicode support for international names.
  /// Provides immediate Swedish localized error feedback for optimal user experience.
  void _validateDisplayName() {
    if (_displayName.isEmpty) {
      _displayNameError = AppLocale.current.validationNameRequired;
    } else if (_displayName.length < 2) {
      _displayNameError = AppLocale.current.errorDisplayNameMinLength;
    } else if (_displayName.length > 50) {
      _displayNameError = AppLocale.current.errorDescriptionTooLong;
    } else if (!RegExp(r'^[\p{L}\p{N}\s\-_.]+$', unicode: true)
        .hasMatch(_displayName)) {
      _displayNameError = AppLocale.current.errorFillRequiredFieldsCorrectly;
    } else {
      _displayNameError = null;
    }
  }

  /// Detects form changes by comparing current form state with saved profile data.
  /// Performs comprehensive comparison between form fields and existing profile data
  /// to accurately track unsaved changes for user prompting and navigation control.
  /// Handles both new profile creation and existing profile editing scenarios.
  void _checkForChanges() {
    final profile = currentProfile;

    if (profile == null) {
      _hasUnsavedChanges = _displayName.isNotEmpty || _avatarUrl != null;
    } else {
      _hasUnsavedChanges = _displayName != profile.displayName ||
          _avatarUrl != profile.avatarUrl ||
          _isSearchable != profile.isSearchable ||
          _allowEmailSearch != profile.allowEmailSearch;
    }
  }

  /// Checks if display name has changed from saved profile for availability validation.
  /// Returns true if display name differs from saved profile, false otherwise.
  /// Used to determine when display name availability checking is required
  /// to avoid unnecessary validation calls during profile updates.
  bool _hasDisplayNameChanged() {
    final profile = currentProfile;
    return profile != null && _displayName != profile.displayName;
  }

  /// Handles reactive updates from UserService state changes with automatic UI synchronization.
  /// Provides seamless state synchronization between UserService and ViewModel ensuring
  /// all profile state changes are immediately reflected in UI components
  /// for consistent user experience and real-time profile status updates.
  void _onUserServiceChanged() {
    // Only reload profile data if there are no unsaved changes
    // This prevents overriding user's form input while preserving backend updates
    if (!_hasUnsavedChanges) {
      _loadCurrentProfile();
    }
    notifyListeners();
  }

  /// Clears all field validation errors for clean validation state management.
  /// Resets all validation error states to null for clean form validation state
  /// and proper error state cleanup during form operations and state transitions.
  void _clearValidationErrors() {
    _displayNameError = null;
  }

  /// Performs comprehensive ViewModel disposal with service listener cleanup and memory management.
  /// Removes UserService listener connections and performs complete resource cleanup
  /// to prevent memory leaks and ensure proper ViewModel lifecycle management
  /// in dynamic profile editing scenarios with ViewModel creation and disposal.
  @override
  void dispose() {
    _userService.removeListener(_onUserServiceChanged);
    super.dispose();
  }
}
