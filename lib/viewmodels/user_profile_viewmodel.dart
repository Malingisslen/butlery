/// User profile ViewModel for form management, avatar upload, privacy settings, and real-time validation (Swedish).
/// Uses dual-profile pattern: _originalProfile (snapshot) + _editedProfile (working copy).

// lib/viewmodels/user_profile_viewmodel.dart

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/offline/avatar_queue_metadata.dart';
import 'package:butlery/services/offline/queue_retry_policy.dart'
    show queueErrorCode;
import 'package:butlery/services/offline/queued_change.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/services/tagging/config/cuisine_config.dart';

/// User profile ViewModel for profile form management, avatar uploads, validation, and privacy settings (MVVM).
class UserProfileViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final UserService _userService;
  final ImagePickerService _imagePickerService;
  final ImageUploadService _uploadService;
  final OfflineService? Function() _offlineService;

  static const maxCuisineAffinities = 5;
  static const maxBioLength = 160;

  // Dual-profile state: original snapshot vs working copy
  UserProfile? _originalProfile;
  UserProfile? _editedProfile;

  // UI-only state (not part of UserProfile model)
  bool _isUploadingAvatar = false;
  bool _isSaving = false;
  String? _displayNameError;
  String? _operationError;

  UserProfileViewModel(
    this._userService,
    this._imagePickerService, {
    ImageUploadService? uploadService,
    OfflineService? Function()? offlineService,
  }) : _uploadService =
           uploadService ?? ServiceLocator.get<ImageUploadService>(),
       _offlineService =
           offlineService ?? (() => ServiceLocator.tryGet<OfflineService>()) {
    _loadCurrentProfile();
    _userService.addListener(_onUserServiceChanged);
  }

  // Getters — delegate to _editedProfile
  String get displayName => (_editedProfile?.displayName).orEmpty();
  String? get avatarUrl => _editedProfile?.avatarUrl;
  bool get isSearchable => _editedProfile?.isSearchable ?? true;
  bool get allowEmailSearch => _editedProfile?.allowEmailSearch ?? false;
  bool get showOnlineStatus => _editedProfile?.showOnlineStatus ?? true;
  bool get shareActivityToFeed => _editedProfile?.shareActivityToFeed ?? true;

  /// BUT-1220: per-event-type toggle state. Absent entry = enabled, so a
  /// missing map reads as "all on" for the four broadcastable event types.
  bool isActivityEventTypeEnabled(ActivityEventType type) =>
      _editedProfile?.isActivityEventTypeEnabled(type.name) ?? true;
  bool get isLoading => _isUploadingAvatar;
  bool get isUploadingAvatar => _isUploadingAvatar;

  /// BUT-1459: save round-trip in flight. Hoisted here so every save entry
  /// point (profile-edit, household-size, …) shares one in-flight source of
  /// truth instead of each re-implementing a local double-tap guard.
  /// Deliberately NOT folded into [isLoading] — that drives the avatar-upload
  /// spinner, and widening it would spin unrelated UI during a profile save.
  bool get isSaving => _isSaving;
  String? get displayNameError => _displayNameError;
  String? get error => _operationError ?? _displayNameError;
  bool get hasError => _operationError != null || _displayNameError != null;
  CookingSkillLevel? get cookingSkillLevel => _editedProfile?.cookingSkillLevel;
  List<String> get cuisineAffinities =>
      List.unmodifiable(_editedProfile?.cuisineAffinities ?? []);
  String get bio => (_editedProfile?.bio).orEmpty();

  /// BUT-1322: household-size default (null = each recipe's own portions).
  int? get householdSize => _editedProfile?.householdSize;
  UserProfile? get currentProfile =>
      ServiceLocator.get<UserService>().currentUserProfile;
  bool get hasProfile => currentProfile != null;

  /// Change detection via field-by-field comparison (UserProfile.== only checks uid)
  bool get hasUnsavedChanges {
    if (_pendingAvatarPath != null) return true;
    if (_originalProfile == null && _editedProfile == null) return false;
    if (_originalProfile == null && _editedProfile != null) {
      // New profile scenario — has changes if any meaningful field is set.
      // householdSize matters here: the Settings > Hushållsstorlek screen's
      // ONLY control is householdSize, and it gates Save on hasUnsavedChanges —
      // without this a household change on a not-yet-loaded profile (first run /
      // offline) would leave Save permanently disabled (BUT-1594 review).
      return displayName.isNotEmpty ||
          avatarUrl != null ||
          cookingSkillLevel != null ||
          cuisineAffinities.isNotEmpty ||
          householdSize != null ||
          bio.isNotEmpty;
    }
    if (_originalProfile == null || _editedProfile == null) return false;
    return !_profileFieldsEqual(_originalProfile!, _editedProfile!);
  }

  /// Form validation state for submission control
  bool get isFormValid => _displayNameError == null && displayName.isNotEmpty;

  void updateDisplayName(String value) {
    final trimmed = value.trim();
    _editedProfile = _editedProfile?.copyWith(displayName: trimmed);
    _validateDisplayName();
    notifyListeners();
  }

  /// True for a compliant 15–17-year-old (server-authoritative, written only by
  /// `verifySignupAge`). Drives which searchability write path applies.
  bool get isMinor => _editedProfile?.isMinor ?? false;

  void updateIsSearchable(bool value) {
    _editedProfile = _editedProfile?.copyWith(isSearchable: value);
    notifyListeners();
  }

  /// BUT-1629: set search discoverability, routing a MINOR through the
  /// server-side opt-in instead of the ordinary profile save.
  ///
  /// A minor's client write of `isSearchable:true` is denied by firestore.rules
  /// and independently zeroed by [UserProfile.toFirestore], so the ordinary
  /// save can never make them discoverable — deliberately, since a tampered
  /// client must not be able to. The `setProfileSearchability` callable is the
  /// audited exception, and this is the only place the app calls it.
  ///
  /// Unlike the adult path (a local edit persisted by Save) this takes effect
  /// immediately, because the write is the callable itself. Returns false and
  /// sets [error] if the call fails, so the caller can tell the user — a
  /// privacy control that fails silently is the failure that matters here.
  Future<bool> setSearchableOptIn(bool value) async {
    if (!isMinor) {
      updateIsSearchable(value);
      return true;
    }
    // Serialised against a save in flight: both write isSearchable, and the
    // save re-asserts the value that was persisted when it started — letting
    // them interleave could re-enable discoverability right after a
    // deliberate opt-out. The view disables the toggle while [isSaving] too;
    // this is the backstop for any other caller.
    if (_isSaving) return false;

    final stored = await _userService.setMinorSearchable(value);
    if (stored == null) {
      _operationError =
          _userService.error ??
          AppLocale.current.errorCouldNotUpdateSearchability;
      notifyListeners();
      return false;
    }

    // Trust the server's answer over the requested one, and sync BOTH
    // profiles: the value is already persisted, so it must not linger as an
    // unsaved change that a later Save would try to write again.
    _originalProfile = _originalProfile?.copyWith(isSearchable: stored);
    _editedProfile = _editedProfile?.copyWith(isSearchable: stored);
    _operationError = stored == value
        ? null
        : AppLocale.current.errorCouldNotUpdateSearchability;
    notifyListeners();
    return stored == value;
  }

  /// BUT-2221: off by default.
  bool get showNameOnSharedDishes =>
      _editedProfile?.showNameOnSharedDishes ?? false;

  /// BUT-2221: takes effect at once on its own write path, not on Save.
  Future<bool> setShowNameOnSharedDishes(bool value) async {
    if (isMinor) return false;
    final ok = await _userService.setShowNameOnSharedDishes(value);
    _operationError = ok
        ? null
        : _userService.error ?? AppLocale.current.errorCouldNotSaveDishCredit;
    if (ok) {
      _originalProfile = _originalProfile?.copyWith(
        showNameOnSharedDishes: value,
      );
      _editedProfile = _editedProfile?.copyWith(showNameOnSharedDishes: value);
    }
    notifyListeners();
    return ok;
  }

  bool get newRecipesShowOnProfile =>
      _editedProfile?.newRecipesShowOnProfile ?? false;

  /// Takes effect at once on its own write path, not on Save.
  Future<bool> setNewRecipesShowOnProfile(bool value) async {
    if (isMinor) return false;
    final ok = await _userService.setNewRecipesShowOnProfile(value);
    _operationError = ok
        ? null
        : _userService.error ??
              AppLocale.current.errorCouldNotSaveNewRecipesPublic;
    if (ok) {
      _originalProfile = _originalProfile?.copyWith(
        newRecipesShowOnProfile: value,
      );
      _editedProfile = _editedProfile?.copyWith(
        newRecipesShowOnProfile: value,
      );
    }
    notifyListeners();
    return ok;
  }

  void updateAllowEmailSearch(bool value) {
    _editedProfile = _editedProfile?.copyWith(allowEmailSearch: value);
    notifyListeners();
  }

  void updateShowOnlineStatus(bool value) {
    // BUT-912: turning visibility off also clears the live dot on save, so the
    // user disappears immediately rather than only on their next presence beat.
    _editedProfile = value
        ? _editedProfile?.copyWith(showOnlineStatus: true)
        : _editedProfile?.copyWith(showOnlineStatus: false, isOnline: false);
    notifyListeners();
  }

  void updateShareActivityToFeed(bool value) {
    _editedProfile = _editedProfile?.copyWith(shareActivityToFeed: value);
    notifyListeners();
  }

  /// BUT-1220: set one per-event-type toggle. Stored explicitly (true or false)
  /// so a deliberate "on" is distinguishable from the absent-key default; this
  /// keeps the map readable and avoids surprising re-enables after a toggle off.
  void updateActivityEventType(ActivityEventType type, bool enabled) {
    final current = Map<String, bool>.from(
      _editedProfile?.activityFeedEventTypes ?? {},
    );
    current[type.name] = enabled;
    _editedProfile = _editedProfile?.copyWith(activityFeedEventTypes: current);
    notifyListeners();
  }

  void updateCookingSkillLevel(CookingSkillLevel? value) {
    _editedProfile = _editedProfile?.copyWith(cookingSkillLevel: value);
    notifyListeners();
  }

  /// Toggle a cuisine in the affinities list. Enforces max 5 constraint.
  /// Returns false if the cuisine was not added because the limit was reached.
  bool toggleCuisineAffinity(String cuisine) {
    if (!CuisineConfig.allTags.contains(cuisine)) return false;

    final current = List<String>.from(_editedProfile?.cuisineAffinities ?? []);

    if (current.contains(cuisine)) {
      current.remove(cuisine);
    } else {
      if (current.length >= maxCuisineAffinities) return false;
      current.add(cuisine);
    }

    _editedProfile = _editedProfile?.copyWith(
      cuisineAffinities: current.isEmpty ? null : current,
    );
    notifyListeners();
    return true;
  }

  /// BUT-1322 (review): true only after the user deliberately changed the
  /// household size THIS editing session. saveProfile passes the field to the
  /// service only then — an in-memory null is ambiguous (cleared vs a degraded
  /// settings-doc read), so an untouched save must not write it at all or it
  /// would silently wipe the stored setting.
  bool _householdSizeEdited = false;

  /// True only after the user chose or removed the picture THIS editing
  /// session; an untouched save leaves the stored picture alone, so a stale
  /// copy in memory can never overwrite a newer one.
  bool _avatarEdited = false;

  /// BUT-2294: a picture chosen without a connection. It is queued on the
  /// device when the form is saved; until then the stored picture is unchanged
  /// and the form only previews this one.
  String? _pendingAvatarPath;
  String? get pendingAvatarPath => _pendingAvatarPath;

  /// Whether the last successful save left a picture waiting for a connection.
  bool get avatarWaitsForConnection => _avatarQueuedBySave;
  bool _avatarQueuedBySave = false;

  /// BUT-1322: set the household-size default. Null clears back to "recipe
  /// default"; out-of-range values are ignored (the stepper clamps too, this
  /// guards programmatic callers).
  void updateHouseholdSize(int? value) {
    if (value != null &&
        (value < UserProfile.minHouseholdSize ||
            value > UserProfile.maxHouseholdSize)) {
      return;
    }
    _householdSizeEdited = true;
    _editedProfile = _editedProfile?.copyWith(householdSize: value);
    notifyListeners();
  }

  void updateBio(String value) {
    var trimmed = value.trim();
    if (trimmed.length > maxBioLength) {
      trimmed = trimmed.substring(0, maxBioLength);
    }
    _editedProfile = _editedProfile?.copyWith(
      bio: trimmed.isEmpty ? null : trimmed,
    );
    notifyListeners();
  }

  /// Uploads new avatar image with progress tracking and service coordination.
  /// Returns true if avatar upload succeeds, false if operation fails or user cancels.
  Future<bool> uploadAvatar() async {
    AppLogger.debug('VIEWMODEL: uploadAvatar called');
    _isUploadingAvatar = true;
    _operationError = null;
    notifyListeners();

    try {
      AppLogger.debug('VIEWMODEL: Starting avatar upload');

      AppLogger.debug('VIEWMODEL: Calling image picker service');
      final imageFile = await _imagePickerService.pickImage(
        ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );

      if (imageFile == null) {
        AppLogger.info('VIEWMODEL: No image selected (user cancelled)');
        return false;
      }
      AppLogger.info('VIEWMODEL: Image selected: ${imageFile.path}');

      final userId = ServiceLocator.get<PermissionService>().currentUserId;
      if (userId == null) {
        _operationError = AppLocale.current.errorNoUserLoggedIn;
        throw Exception(_operationError);
      }

      if (_mustQueueAvatar) return _keepForLater(imageFile.path);

      final bytes = await imageFile.readAsBytes();

      final result = await _uploadService.uploadImageFromBytes(
        bytes: bytes,
        userId: userId,
        fileName: imageFile.path.split('/').last,
        prefix: 'avatar',
      );

      if (!result.success && _mustQueueAvatar) {
        return _keepForLater(imageFile.path);
      }
      if (result.success && result.url != null) {
        _editedProfile = _editedProfile?.copyWith(avatarUrl: result.url);
        _avatarEdited = true;
        _pendingAvatarPath = null;
        AppLogger.success('Avatar uploaded with automatic retry support');
        return true;
      } else {
        _operationError =
            result.error ?? AppLocale.current.errorCouldNotUpdate('avatar');
        throw Exception(_operationError);
      }
    } catch (e) {
      AppLogger.error('Avatar upload failed', e);
      _operationError ??= AppLocale.current.errorGeneric;
      return false;
    } finally {
      _isUploadingAvatar = false;
      notifyListeners();
    }
  }

  /// BUT-2294: without a connection a picture cannot go up.
  bool get _mustQueueAvatar {
    final offline = _offlineService();
    return offline != null && !offline.isOnline && offline.isQueueReady;
  }

  /// Holds the chosen picture for [saveProfile] to queue. The stored picture
  /// stays what the profile has, and is not written by that save.
  bool _keepForLater(String path) {
    _pendingAvatarPath = path;
    _editedProfile = _editedProfile?.copyWith(
      avatarUrl: _originalProfile?.avatarUrl,
    );
    _avatarEdited = false;
    return true;
  }

  void removeAvatar() {
    _editedProfile = _editedProfile?.copyWith(avatarUrl: null);
    _avatarEdited = true;
    _pendingAvatarPath = null;
    notifyListeners();
  }

  /// Saves profile changes with validation and service coordination.
  /// Returns true if profile save succeeds, false if validation fails or save operation errors.
  ///
  /// BUT-1459: re-entrant calls are rejected while a save is in flight, so a
  /// double-tap can never fire two concurrent writes — callers no longer need
  /// their own guard, they just read [isSaving] to disable the button.
  Future<bool> saveProfile() async {
    if (_isSaving) return false;
    _isSaving = true;
    notifyListeners();
    try {
      return await _performSave();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> _performSave() async {
    if (!isFormValid) {
      _handleUserError(AppLocale.current.errorFillRequiredFieldsCorrectly);
      return false;
    }

    // Check if display name is available
    if (_hasDisplayNameChanged()) {
      final isAvailable = await _userService.isDisplayNameAvailable(
        displayName,
      );
      if (!isAvailable) {
        _displayNameError = AppLocale.current.errorNameAlreadyTaken;
        notifyListeners();
        return false;
      }
    }

    final edited = _editedProfile;
    if (edited == null) return false;

    // BUT-1322: captured before the save syncs _originalProfile, so the
    // set/changed analytics below compares against the persisted value.
    final previousHouseholdSize = _originalProfile?.householdSize;
    final pendingAvatar = _pendingAvatarPath;
    // What the form showed, which it keeps while there are unsaved changes.
    final baseAvatarUrl = _originalProfile?.avatarUrl;
    _avatarQueuedBySave = false;

    return await safeExecute(() async {
          final updatedProfile = await _userService.createOrUpdateProfile(
            displayName: edited.displayName,
            avatarUrl: _avatarEdited
                ? edited.avatarUrl
                : UserService.avatarUntouched,
            isSearchable: edited.isSearchable,
            allowEmailSearch: edited.allowEmailSearch,
            cookingSkillLevel: edited.cookingSkillLevel,
            cuisineAffinities: edited.cuisineAffinities?.isEmpty == true
                ? null
                : edited.cuisineAffinities,
            bio: edited.bio?.isEmpty == true ? null : edited.bio,
            showOnlineStatus: edited.showOnlineStatus,
            shareActivityToFeed: edited.shareActivityToFeed,
            activityFeedEventTypes: edited.activityFeedEventTypes,
            // BUT-1322 (review): pass the field ONLY when the user edited it
            // this session. An untouched save must send the sentinel, or a
            // degraded settings-doc read (in-memory null) followed by any
            // unrelated profile save would silently wipe the stored setting.
            householdSize: _householdSizeEdited
                ? edited.householdSize
                : UserService.householdSizeUntouched,
          ); // BUT-906/BUT-1220: persist the master opt-out + per-type toggles

          if (updatedProfile != null) {
            if (_householdSizeEdited &&
                previousHouseholdSize != updatedProfile.householdSize) {
              _logHouseholdSizeChanged(
                previousHouseholdSize,
                updatedProfile.householdSize,
              );
            }
            _householdSizeEdited = false;
            _avatarEdited = false;
            if (pendingAvatar != null) {
              final queued = await _queueAvatar(pendingAvatar, baseAvatarUrl);
              _originalProfile = updatedProfile;
              _editedProfile = updatedProfile;
              if (!queued) {
                _operationError = AppLocale.current.profileAvatarQueueFailed;
                notifyListeners();
                return false;
              }
              _pendingAvatarPath = null;
              _avatarQueuedBySave = true;
            }
            // Sync both profiles to the fresh server response
            _originalProfile = updatedProfile;
            _editedProfile = updatedProfile;
            // BUT-1629: the save serialized isSearchable:false for an opted-in
            // minor (toFirestore chokepoint) and UserService re-asserted it
            // through the callable. The returned profile always carries the
            // server's real answer, so we only have to report a failed
            // re-assert — the toggle already renders the truth.
            if (edited.isMinor &&
                edited.isSearchable &&
                !updatedProfile.isSearchable) {
              _operationError =
                  AppLocale.current.errorCouldNotUpdateSearchability;
            }
            AppLogger.success(
              'Profil sparad - Settings: isSearchable=${updatedProfile.isSearchable}, allowEmailSearch=${updatedProfile.allowEmailSearch}',
            );
            notifyListeners();
            return true;
          } else {
            throw Exception(
              _userService.error ??
                  AppLocale.current.errorCouldNotUpdate('profil'),
            );
          }
        }, operationName: 'Save profile') ??
        false;
  }

  /// The picture chosen without a connection becomes one waiting row, in place
  /// of any earlier one. False when it could not be kept on the device.
  Future<bool> _queueAvatar(String path, String? baseAvatarUrl) async {
    final offline = _offlineService();
    final userId = ServiceLocator.get<PermissionService>().currentUserId;
    if (offline == null || !offline.isQueueReady || userId == null) {
      return false;
    }
    try {
      await offline.userStorage.queueImageGroupForUser(
        imagePaths: [path],
        entityType: avatarEntityType,
        entityId: userId,
        userId: userId,
        targetPath: 'users/$userId/avatars',
        metadata: avatarQueueMetadata(baseAvatarUrl: baseAvatarUrl),
        replaceWaiting: true,
      );
      await offline.refreshSyncState();
      return true;
    } catch (e) {
      // The error is not passed on: a file error's path holds the uid.
      AppLogger.error(
        'Could not queue the profile picture: ${queueErrorCode(e)}',
      );
      return false;
    }
  }

  void resetForm() {
    _editedProfile = _originalProfile;
    _avatarEdited = false;
    _pendingAvatarPath = null;
    clearError();
    _clearValidationErrors();
    notifyListeners();
  }

  /// Checks display name availability with real-time validation feedback.
  Future<bool> checkDisplayNameAvailability() async {
    if (displayName.isEmpty) return false;

    return await safeExecute(
          () async {
            final isAvailable = await _userService.isDisplayNameAvailable(
              displayName,
            );

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

  void clearError() {
    _clearValidationErrors();
    _operationError = null;
    notifyListeners();
  }

  void _handleUserError(String message) {
    AppLogger.error('User error: $message');
  }

  /// BUT-1322 (binding monetization condition): set/changed telemetry for the
  /// household-size preference. Best-effort — a missing or failing analytics
  /// service must never fail the profile save.
  void _logHouseholdSizeChanged(int? previous, int? next) {
    try {
      ServiceLocator.tryGet<AnalyticsService>()
          ?.logHouseholdSizeChanged(previousSize: previous, newSize: next)
          .catchError((Object _) {});
    } catch (_) {}
  }

  /// Loads current profile data into both original and edited state.
  void _loadCurrentProfile() {
    final profile = currentProfile;

    if (profile != null) {
      _originalProfile = profile;
      _editedProfile = profile;
      _avatarEdited = false;
      _pendingAvatarPath = null;
    } else {
      // No profile yet — create a minimal editable shell preserving any existing edits.
      // This prevents avatar loss during initialization race conditions.
      if (_editedProfile == null) {
        final now = clock.now();
        _editedProfile = UserProfile(
          uid: '',
          displayName: '',
          email: '',
          joinedAt: now,
          lastActiveAt: now,
        );
      }
      // _originalProfile stays null to signal "new profile" for change detection
    }
  }

  void _validateDisplayName() {
    final name = displayName;
    if (name.isEmpty) {
      _displayNameError = AppLocale.current.validationNameRequired;
    } else if (name.length < 2) {
      _displayNameError = AppLocale.current.errorDisplayNameMinLength;
    } else if (name.length > 50) {
      _displayNameError = AppLocale.current.errorDescriptionTooLong;
    } else if (!RegExp(
      r'^[\p{L}\p{N}\s\-_.]+$',
      unicode: true,
    ).hasMatch(name)) {
      _displayNameError = AppLocale.current.errorFillRequiredFieldsCorrectly;
    } else {
      _displayNameError = null;
    }
  }

  /// Field-by-field comparison of the editable profile fields.
  /// UserProfile.== only checks uid, so we need this for change detection.
  bool _profileFieldsEqual(UserProfile a, UserProfile b) {
    return a.displayName == b.displayName &&
        a.avatarUrl == b.avatarUrl &&
        a.isSearchable == b.isSearchable &&
        a.allowEmailSearch == b.allowEmailSearch &&
        a.cookingSkillLevel == b.cookingSkillLevel &&
        listEquals(a.cuisineAffinities ?? [], b.cuisineAffinities ?? []) &&
        a.bio.orEmpty() == b.bio.orEmpty() &&
        a.showOnlineStatus == b.showOnlineStatus &&
        a.shareActivityToFeed == b.shareActivityToFeed &&
        a.householdSize == b.householdSize &&
        mapEquals(a.activityFeedEventTypes, b.activityFeedEventTypes);
  }

  bool _hasDisplayNameChanged() {
    if (_originalProfile == null) return false;
    return displayName != _originalProfile!.displayName;
  }

  /// Reactive sync from UserService — only reloads if no unsaved edits
  void _onUserServiceChanged() {
    if (!hasUnsavedChanges) {
      _loadCurrentProfile();
    }
    notifyListeners();
  }

  void _clearValidationErrors() {
    _displayNameError = null;
  }

  @override
  void dispose() {
    _userService.removeListener(_onUserServiceChanged);
    super.dispose();
  }
}
