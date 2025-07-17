// lib/viewmodels/user_profile_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_profile.dart';
import '../services/user_service.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../services/image_picker_service.dart';
import '../core/utils/logger.dart';
import '../core/injection.dart';
import '../core/mixins/state_notifier_mixin.dart';
import '../core/mixins/async_operation_mixin.dart';


class UserProfileViewModel extends ChangeNotifier with StateNotifierMixin, AsyncOperationMixin {
  final UserService _userService;
  final StorageService _storageService;
  final ImagePickerService _imagePickerService;

  // Form state
  String _displayName = '';
  String _bio = '';
  String? _avatarUrl;
  bool _isSearchable = true;
  bool _allowEmailSearch = false;

  // UI state
  bool _isUploadingAvatar = false;
  bool _hasUnsavedChanges = false;

  // Validation state
  String? _displayNameError;
  String? _bioError;

  UserProfileViewModel(
    this._userService,
    this._storageService,
    this._imagePickerService,
  ) {
    _loadCurrentProfile();
    _userService.addListener(_onUserServiceChanged);
  }

  // ===== GETTERS =====

  String get displayName => _displayName;
  String get bio => _bio;
  String? get avatarUrl => _avatarUrl;
  bool get isSearchable => _isSearchable;
  bool get allowEmailSearch => _allowEmailSearch;

  @override
  bool get isLoading => super.isLoading || _isUploadingAvatar;
  bool get isUploadingAvatar => _isUploadingAvatar;
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  String? get displayNameError => _displayNameError;
  String? get bioError => _bioError;

  UserProfile? get currentProfile => sl<PermissionService>().currentUser;
  bool get hasProfile => currentProfile != null;

  // Validation
  bool get isFormValid =>
      _displayNameError == null && _bioError == null && _displayName.isNotEmpty;

  // ===== ACTIONS =====

  /// Update display name
  void updateDisplayName(String value) {
    _displayName = value.trim();
    _validateDisplayName();
    _checkForChanges();
    notifyListeners();
  }

  /// Update bio
  void updateBio(String value) {
    _bio = value.trim();
    _validateBio();
    _checkForChanges();
    notifyListeners();
  }

  /// Update privacy settings
  void updateIsSearchable(bool value) {
    _isSearchable = value;
    _checkForChanges();
    notifyListeners();
  }

  void updateAllowEmailSearch(bool value) {
    _allowEmailSearch = value;
    _checkForChanges();
    notifyListeners();
  }

  /// Upload new avatar
  Future<bool> uploadAvatar() async {
    try {
      _isUploadingAvatar = true;
      clearError();
      notifyListeners();

      // Pick image från gallery
      final imageFile =
          await _imagePickerService.pickImage(ImageSource.gallery);

      if (imageFile == null) {
        _isUploadingAvatar = false;
        notifyListeners();
        return false;
      }

      // Get current user ID
      final userId = sl<PermissionService>().currentUserId;
      if (userId == null) {
        setError('Ingen användare inloggad');
        return false;
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
        notifyListeners();
        return true;
      } else {
        setError('Kunde inte ladda upp avatar');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ Kunde inte ladda upp avatar: $e');
      setError('Kunde inte ladda upp avatar: $e');
      return false;
    } finally {
      _isUploadingAvatar = false;
      notifyListeners();
    }
  }

  /// Remove current avatar
  void removeAvatar() {
    _avatarUrl = null;
    _checkForChanges();
    notifyListeners();
  }

  /// Save profile changes
  Future<bool> saveProfile() async {
    if (!isFormValid) {
      setError('Fyll i alla obligatoriska fält korrekt');
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

    return await saveData(() async {
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
    });
  }

  /// Reset form to current profile values
  void resetForm() {
    _loadCurrentProfile();
    _hasUnsavedChanges = false;
    clearError();
    _clearValidationErrors();
    notifyListeners();
  }

  /// Check display name availability
  Future<bool> checkDisplayNameAvailability() async {
    if (_displayName.isEmpty) return false;

    try {
      final isAvailable =
          await _userService.isDisplayNameAvailable(_displayName);

      if (!isAvailable) {
        _displayNameError = 'Detta namn är redan taget';
      } else {
        _displayNameError = null;
      }

      notifyListeners();
      return isAvailable;
    } catch (e) {
      AppLogger.error('❌ Kunde inte kontrollera namn-tillgänglighet: $e');
      return false;
    }
  }

  /// Clear all errors
  @override
  void clearError() {
    setError('');
    _clearValidationErrors();
    notifyListeners();
  }

  // ===== PRIVATE METHODS =====

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

  void _validateBio() {
    if (_bio.length > 150) {
      _bioError = 'Beskrivningen får vara max 150 tecken';
    } else {
      _bioError = null;
    }
  }

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

  bool _hasDisplayNameChanged() {
    final profile = currentProfile;
    return profile != null && _displayName != profile.displayName;
  }

  void _onUserServiceChanged() {
    notifyListeners();
  }


  void _clearValidationErrors() {
    _displayNameError = null;
    _bioError = null;
  }

  @override
  void dispose() {
    _userService.removeListener(_onUserServiceChanged);
    super.dispose();
  }
}
