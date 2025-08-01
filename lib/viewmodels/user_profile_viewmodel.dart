/// Comprehensive user profile ViewModel providing advanced profile management and state coordination for Flutter applications.
///
/// This module implements sophisticated user profile management following Single Responsibility Principle,
/// handling all aspects of profile presentation layer including form validation, avatar management, privacy settings,
/// and comprehensive state synchronization. It provides complete user profile infrastructure while
/// maintaining clean separation from UI rendering, data persistence, and business logic implementation.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles user profile presentation layer concerns:
/// - **Profile Form Management**: Complete form state management with comprehensive validation and change tracking
/// - **Avatar Management Excellence**: Advanced image upload, processing, and URL management with service coordination
/// - **Privacy Settings Control**: Comprehensive privacy preference management with searchability and email discovery settings
/// - **Validation Intelligence**: Sophisticated input validation with Swedish localization and real-time feedback
/// - **Service Integration**: Seamless coordination with UserService, StorageService, and ImagePickerService
///
/// **What This Module Does NOT Handle:**
/// - Actual profile data persistence (handled by UserService and Firestore)
/// - Image processing and storage operations (handled by StorageService and cloud storage)
/// - UI rendering and widget creation (handled by UserProfileView and profile UI components)
/// - Authentication and user session management (handled by AuthService and authentication flow)
///
/// **User Profile ViewModel Features:**
/// - **Advanced Form Management**: Complete profile form with real-time validation and change detection
/// - **Avatar Upload Intelligence**: Comprehensive image selection, upload, and management with progress tracking
/// - **Privacy Control Excellence**: Advanced privacy settings with searchability and email discovery preferences
/// - **Swedish Localization**: Complete Swedish language support for validation messages and user feedback
/// - **Real-time Validation**: Sophisticated input validation with immediate feedback and availability checking
///
/// **Usage Examples:**
/// ```dart
/// // Initialize profile ViewModel
/// final profileViewModel = UserProfileViewModel(
///   userService,
///   storageService,
///   imagePickerService,
/// );
/// 
/// // Update profile information with validation
/// profileViewModel.updateDisplayName('Erik Svensson');
/// profileViewModel.updateBio('Passionerad matlagare från Stockholm');
/// 
/// // Upload avatar with progress tracking
/// final avatarUploaded = await profileViewModel.uploadAvatar();
/// if (avatarUploaded) {
///   // Show success message
/// }
/// 
/// // Configure privacy settings
/// profileViewModel.updateIsSearchable(true);
/// profileViewModel.updateAllowEmailSearch(false);
/// 
/// // Save profile with validation
/// final saved = await profileViewModel.saveProfile();
/// if (saved) {
///   // Navigate to profile view
/// } else {
///   // Display validation errors
/// }
/// 
/// // Check display name availability
/// final isAvailable = await profileViewModel.checkDisplayNameAvailability();
/// 
/// // Form state monitoring
/// if (profileViewModel.hasUnsavedChanges) {
///   // Show save prompt
/// }
/// ```

// lib/viewmodels/user_profile_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';

/// Comprehensive user profile ViewModel providing advanced profile management and state coordination for Flutter applications.
///
/// Serves as the presentation layer coordinator for all user profile operations, providing reactive form management,
/// comprehensive validation, avatar upload capabilities, and privacy settings control while maintaining clean MVVM architecture
/// separation between profile business logic and UI presentation concerns.
class UserProfileViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final UserService _userService;
  final StorageService _storageService;
  final ImagePickerService _imagePickerService;

  // ===== PROFILE FORM STATE MANAGEMENT =====

  /// User's display name for profile identification and social features.
  String _displayName = '';

  /// User's biographical description for profile personalization and social discovery.
  String _bio = '';

  /// User's avatar image URL for profile visual representation and social features.
  String? _avatarUrl;

  /// User's searchability preference controlling profile discovery by other users.
  bool _isSearchable = true;

  /// User's email search preference controlling discoverability through email lookup.
  bool _allowEmailSearch = false;

  // ===== UI STATE COORDINATION =====

  /// Avatar upload operation state for UI progress indication and interaction control.
  bool _isUploadingAvatar = false;

  /// Form change tracking state for unsaved changes detection and user prompting.
  bool _hasUnsavedChanges = false;

  // ===== VALIDATION STATE MANAGEMENT =====

  /// Display name validation error for real-time user feedback and form validation.
  String? _displayNameError;

  /// Bio validation error for character limit enforcement and user guidance.
  String? _bioError;

  UserProfileViewModel(
    this._userService,
    this._storageService,
    this._imagePickerService,
  ) {
    _loadCurrentProfile();
    _userService.addListener(_onUserServiceChanged);
  }

  // ===== PROFILE FORM ACCESSORS =====

  /// Current display name value for UI binding and form coordination.
  /// 
  /// Provides real-time access to display name input for UI synchronization
  /// and form validation during user profile editing operations.
  String get displayName => _displayName;

  /// Current bio value for UI binding and profile description management.
  /// 
  /// Provides access to biographical description for UI display and form management
  /// during user profile customization and social profile creation.
  String get bio => _bio;

  /// Current avatar URL for image display and profile visual representation.
  /// 
  /// Provides access to avatar image URL for profile image display and avatar management
  /// during profile editing and visual profile customization.
  String? get avatarUrl => _avatarUrl;

  /// Current searchability preference for privacy control and profile discovery.
  /// 
  /// Controls whether user profile can be discovered by other users through search functionality
  /// and social features, providing comprehensive privacy preference management.
  bool get isSearchable => _isSearchable;

  /// Current email search preference for privacy control and discoverability management.
  /// 
  /// Controls whether user profile can be discovered through email lookup functionality,
  /// providing granular privacy control over email-based profile discovery.
  bool get allowEmailSearch => _allowEmailSearch;

  // ===== UI STATE ACCESSORS =====

  /// Loading state indicator for UI progress display and interaction control.
  /// 
  /// Indicates active operations requiring loading indicators and user interaction disabling
  /// during profile operations like avatar upload and profile saving.
  bool get isLoading => _isUploadingAvatar;

  /// Avatar upload state for specific upload progress indication and UI coordination.
  /// 
  /// Provides specific avatar upload progress state for targeted UI feedback
  /// and upload operation tracking during image selection and processing.
  bool get isUploadingAvatar => _isUploadingAvatar;

  /// Form change detection state for unsaved changes prompting and navigation control.
  /// 
  /// Indicates whether profile form has unsaved changes requiring user confirmation
  /// before navigation or form reset to prevent data loss.
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  // ===== VALIDATION STATE ACCESSORS =====

  /// Display name validation error for UI error display and form validation feedback.
  /// 
  /// Provides localized validation error message for display name field
  /// enabling real-time validation feedback and user guidance.
  String? get displayNameError => _displayNameError;

  /// Bio validation error for UI error display and character limit feedback.
  /// 
  /// Provides localized validation error message for bio field
  /// enabling character limit enforcement and user validation guidance.
  String? get bioError => _bioError;

  /// Combined validation error for general error display and form validation status.
  /// 
  /// Provides first available validation error for general error display
  /// and comprehensive form validation status checking.
  String? get error => _displayNameError ?? _bioError;

  /// Combined error state for form validation and UI error state management.
  /// 
  /// Indicates presence of any validation errors for form submission control
  /// and error state UI rendering decisions.
  bool get hasError => _displayNameError != null || _bioError != null;

  // ===== PROFILE STATE ACCESSORS =====

  /// Current user profile from service layer for form initialization and comparison.
  /// 
  /// Provides access to current user profile data for form population
  /// and change detection during profile editing operations.
  UserProfile? get currentProfile => ServiceLocator.get<PermissionService>().currentUser;

  /// Profile existence check for UI conditional rendering and flow control.
  /// 
  /// Indicates whether user has existing profile for UI conditional display
  /// and profile creation versus editing flow determination.
  bool get hasProfile => currentProfile != null;

  // ===== FORM VALIDATION STATE =====

  /// Complete form validation state for submission control and UI enabling.
  /// 
  /// Combines all validation requirements including error state and required field completion
  /// for form submission enabling and comprehensive validation status.
  bool get isFormValid =>
      _displayNameError == null && _bioError == null && _displayName.isNotEmpty;

  // ===== PROFILE FORM ACTIONS =====

  /// Updates display name with comprehensive validation and change tracking.
  /// 
  /// [value] New display name value for profile identification
  /// 
  /// Performs automatic trimming, validation, change detection, and UI notification
  /// for seamless display name management with real-time feedback and form coordination.
  void updateDisplayName(String value) {
    _displayName = value.trim();
    _validateDisplayName();
    _checkForChanges();
    notifyListeners();
  }

  /// Updates biographical description with validation and change tracking.
  /// 
  /// [value] New biographical description for profile personalization
  /// 
  /// Performs automatic trimming, character limit validation, change detection, and UI notification
  /// for comprehensive bio management with real-time validation feedback.
  void updateBio(String value) {
    _bio = value.trim();
    _validateBio();
    _checkForChanges();
    notifyListeners();
  }

  /// Updates searchability privacy preference with change tracking and state coordination.
  /// 
  /// [value] New searchability preference for profile discovery control
  /// 
  /// Controls whether user profile can be discovered by other users through search functionality,
  /// providing comprehensive privacy preference management with automatic change detection.
  void updateIsSearchable(bool value) {
    _isSearchable = value;
    _checkForChanges();
    notifyListeners();
  }

  /// Updates email search privacy preference with comprehensive privacy control.
  /// 
  /// [value] New email search preference for email-based profile discovery control
  /// 
  /// Controls whether user profile can be discovered through email lookup functionality,
  /// providing granular privacy control with automatic change detection and state management.
  void updateAllowEmailSearch(bool value) {
    _allowEmailSearch = value;
    _checkForChanges();
    notifyListeners();
  }

  // ===== AVATAR MANAGEMENT OPERATIONS =====

  /// Uploads new avatar image with comprehensive progress tracking and service coordination.
  /// 
  /// Returns true if avatar upload succeeds, false if operation fails or user cancels.
  /// Manages complete avatar upload flow including image selection, processing, upload progress,
  /// and URL management with automatic change detection and comprehensive error handling.
  /// 
  /// **Upload Process:**
  /// - Image selection from device gallery through ImagePickerService
  /// - Secure upload to cloud storage with user-specific path structure
  /// - URL retrieval and local state update with change tracking
  /// - Progress indication and error handling with user feedback
  /// 
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
    _isUploadingAvatar = true;
    notifyListeners();
    
    try {
      final result = await safeExecute(
        () async {
          // Pick image från gallery
          final imageFile =
              await _imagePickerService.pickImage(ImageSource.gallery);

          if (imageFile == null) {
            return false;
          }

          // Get current user ID
          final userId = ServiceLocator.get<PermissionService>().currentUserId;
          if (userId == null) {
            throw Exception('Ingen användare inloggad');
          }

          // Upload med path som inkluderar userId för säkerhet
          final uploadUrl = await _storageService.uploadImageFile(
            imageFile,
            userId,
          );

          if (uploadUrl != null) {
            _avatarUrl = uploadUrl;
            _checkForChanges();
            AppLogger.success('✅ Avatar uploaded');
            return true;
          } else {
            throw Exception('Kunde inte ladda upp avatar');
          }
        },
        operationName: 'Upload avatar',
      );
      
      return result ?? false;
    } finally {
      _isUploadingAvatar = false;
      notifyListeners();
    }
  }

  /// Removes current avatar with immediate state update and change tracking.
  /// 
  /// Clears avatar URL from profile state and triggers change detection for unsaved changes management.
  /// Provides immediate avatar removal for user profile customization with automatic UI synchronization.
  void removeAvatar() {
    _avatarUrl = null;
    _checkForChanges();
    notifyListeners();
  }

  // ===== PROFILE PERSISTENCE OPERATIONS =====

  /// Saves profile changes with comprehensive validation and service coordination.
  /// 
  /// Returns true if profile save succeeds, false if validation fails or save operation errors.
  /// Performs complete profile save flow including validation, availability checking, service coordination,
  /// and state management with comprehensive error handling and user feedback.
  /// 
  /// **Save Process:**
  /// - Form validation including required fields and format checking
  /// - Display name availability verification for changed names
  /// - Service coordination for profile creation or update
  /// - State cleanup and change tracking reset upon success
  /// 
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
      _handleUserError('Fyll i alla obligatoriska fält korrekt');
      return false;
    }

    // Check if display name is available
    if (_hasDisplayNameChanged()) {
      final isAvailable =
          await _userService.isDisplayNameAvailable(_displayName);
      if (!isAvailable) {
        _displayNameError = 'Detta namn är redan taget';
        notifyListeners();
        return false;
      }
    }

    return await safeExecute(() async {
      final updatedProfile = await _userService.createOrUpdateProfile(
        displayName: _displayName,
        bio: _bio.isEmpty ? null : _bio,
        avatarUrl: _avatarUrl,
        isSearchable: _isSearchable,
        allowEmailSearch: _allowEmailSearch,
      );

      if (updatedProfile != null) {
        _hasUnsavedChanges = false;
        AppLogger.success('✅ Profil sparad');
        notifyListeners();
        return true;
      } else {
        throw Exception(_userService.error ?? 'Kunde inte spara profil');
      }
    }, operationName: 'Save profile') ?? false;
  }

  /// Resets form to current profile values with comprehensive state cleanup.
  /// 
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
  /// 
  /// Returns true if display name is available, false if taken or validation fails.
  /// Performs real-time availability checking through UserService with automatic
  /// validation error management and immediate UI feedback for display name uniqueness.
  /// 
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
          _displayNameError = 'Detta namn är redan taget';
        } else {
          _displayNameError = null;
        }

        notifyListeners();
        return isAvailable;
      },
      operationName: 'Check display name availability',
    ) ?? false;
  }

  /// Clears all validation errors with comprehensive state cleanup and UI synchronization.
  /// 
  /// Removes all field-specific validation errors and notifies UI components
  /// for clean error state management and user experience improvement.
  void clearError() {
    _clearValidationErrors();
    notifyListeners();
  }
  
  // ===== ERROR HANDLING =====

  /// Handles user error messages with logging and potential UI feedback coordination.
  /// 
  /// [message] Error message for user notification and logging
  /// 
  /// Provides centralized user error handling with logging capability,
  /// designed for extension with UI notification systems for comprehensive user feedback.
  void _handleUserError(String message) {
    // For now, just log - could be extended to show UI messages
    AppLogger.error('User error: $message');
  }

  // ===== PRIVATE PROFILE MANAGEMENT METHODS =====

  /// Loads current profile data into form state with comprehensive default handling.
  /// 
  /// Initializes form fields from existing user profile or sets appropriate defaults
  /// for new profile creation, ensuring consistent form state initialization
  /// and proper change tracking setup for profile management operations.
  void _loadCurrentProfile() {
    final profile = currentProfile;
    if (profile != null) {
      _displayName = profile.displayName;
      _bio = profile.bio ?? '';
      _avatarUrl = profile.avatarUrl;
      _isSearchable = profile.isSearchable;
      _allowEmailSearch = profile.allowEmailSearch;
      _hasUnsavedChanges = false;
    } else {
      // Set defaults for new profile
      _displayName = '';
      _bio = '';
      _avatarUrl = null;
      _isSearchable = true;
      _allowEmailSearch = false;
      _hasUnsavedChanges = false;
    }
  }

  // ===== ADVANCED VALIDATION METHODS =====

  /// Validates display name format and requirements with comprehensive Swedish localized feedback.
  /// 
  /// Performs complete display name validation including emptiness check, length requirements,
  /// and character format validation with Unicode support for international names.
  /// Provides immediate Swedish localized error feedback for optimal user experience.
  void _validateDisplayName() {
    if (_displayName.isEmpty) {
      _displayNameError = 'Namn krävs';
    } else if (_displayName.length < 2) {
      _displayNameError = 'Namnet måste vara minst 2 tecken';
    } else if (_displayName.length > 50) {
      _displayNameError = 'Namnet får vara max 50 tecken';
    } else if (!RegExp(r'^[\p{L}\p{N}\s\-_.]+$', unicode: true).hasMatch(_displayName)) {
      _displayNameError = 'Namnet innehåller ogiltiga tecken';
    } else {
      _displayNameError = null;
    }
  }

  /// Validates bio length requirements with character limit enforcement and Swedish feedback.
  /// 
  /// Enforces bio character limit with Swedish localized error messages
  /// for optimal user guidance and profile description management.
  void _validateBio() {
    if (_bio.length > 150) {
      _bioError = 'Beskrivningen får vara max 150 tecken';
    } else {
      _bioError = null;
    }
  }

  // ===== CHANGE DETECTION AND STATE MANAGEMENT =====

  /// Detects form changes by comparing current form state with saved profile data.
  /// 
  /// Performs comprehensive comparison between form fields and existing profile data
  /// to accurately track unsaved changes for user prompting and navigation control.
  /// Handles both new profile creation and existing profile editing scenarios.
  void _checkForChanges() {
    final profile = currentProfile;
    if (profile == null) {
      _hasUnsavedChanges =
          _displayName.isNotEmpty || _bio.isNotEmpty || _avatarUrl != null;
    } else {
      _hasUnsavedChanges = _displayName != profile.displayName ||
          _bio != (profile.bio ?? '') ||
          _avatarUrl != profile.avatarUrl ||
          _isSearchable != profile.isSearchable ||
          _allowEmailSearch != profile.allowEmailSearch;
    }
  }

  /// Checks if display name has changed from saved profile for availability validation.
  /// 
  /// Returns true if display name differs from saved profile, false otherwise.
  /// Used to determine when display name availability checking is required
  /// to avoid unnecessary validation calls during profile updates.
  bool _hasDisplayNameChanged() {
    final profile = currentProfile;
    return profile != null && _displayName != profile.displayName;
  }

  /// Handles reactive updates from UserService state changes with automatic UI synchronization.
  /// 
  /// Provides seamless state synchronization between UserService and ViewModel ensuring
  /// all profile state changes are immediately reflected in UI components
  /// for consistent user experience and real-time profile status updates.
  void _onUserServiceChanged() {
    notifyListeners();
  }

  /// Clears all field validation errors for clean validation state management.
  /// 
  /// Resets all validation error states to null for clean form validation state
  /// and proper error state cleanup during form operations and state transitions.
  void _clearValidationErrors() {
    _displayNameError = null;
    _bioError = null;
  }

  /// Performs comprehensive ViewModel disposal with service listener cleanup and memory management.
  /// 
  /// Removes UserService listener connections and performs complete resource cleanup
  /// to prevent memory leaks and ensure proper ViewModel lifecycle management
  /// in dynamic profile editing scenarios with ViewModel creation and disposal.
  @override
  void dispose() {
    _userService.removeListener(_onUserServiceChanged);
    super.dispose();
  }
}
