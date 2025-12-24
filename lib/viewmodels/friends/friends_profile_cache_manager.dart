/// Manages user profile caching for friend request participants
/// Extracted from FriendsViewModel for Single Responsibility compliance.
/// Handles profile loading, caching, and display name/avatar resolution.

import 'package:flutter/foundation.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/utils/logger.dart';

class FriendsProfileCacheManager extends ChangeNotifier {
  final UserService _userService;

  // ===== STATE =====
  final Map<String, UserProfile> _requestUserProfiles = {};
  bool _isLoadingUserProfiles = false;
  bool _isDisposed = false;

  FriendsProfileCacheManager({required UserService userService})
      : _userService = userService;

  // ===== GETTERS =====
  bool get isLoadingUserProfiles => _isLoadingUserProfiles;

  UserProfile? getUserProfile(String userId) => _requestUserProfiles[userId];

  /// Loads user profiles for all users in friend requests
  Future<void> loadUserProfilesForRequests({
    required List<FriendRequest> incomingRequests,
    required List<FriendRequest> sentRequests,
  }) async {
    if (_isDisposed) return;

    _isLoadingUserProfiles = true;
    _safeNotifyListeners();

    try {
      // Collect unique user IDs
      final userIds = <String>{};
      for (final request in incomingRequests) {
        userIds.add(request.fromUserId);
      }
      for (final request in sentRequests) {
        userIds.add(request.toUserId);
      }

      // Filter uncached users
      final uncachedUserIds = userIds
          .where((userId) => !_requestUserProfiles.containsKey(userId))
          .toList();

      if (uncachedUserIds.isNotEmpty) {
        AppLogger.info(
            '👥 Loading ${uncachedUserIds.length} user profiles for requests');

        final profiles = await _userService.getUserProfiles(uncachedUserIds);

        if (_isDisposed) return;

        // Update cache
        for (final profile in profiles) {
          _requestUserProfiles[profile.uid] = profile;
        }

        AppLogger.success(
            '✅ ${profiles.length}/${uncachedUserIds.length} user profiles loaded');

        // Log missing profiles
        final loadedIds = profiles.map((p) => p.uid).toSet();
        final missingIds =
            uncachedUserIds.where((id) => !loadedIds.contains(id));
        if (missingIds.isNotEmpty) {
          AppLogger.warning(
              '⚠️ Could not load profiles for: ${missingIds.join(', ')}');
        }
      }
    } catch (e) {
      AppLogger.error('Failed to load user profiles: $e');
    } finally {
      if (!_isDisposed) {
        _isLoadingUserProfiles = false;
        _safeNotifyListeners();
      }
    }
  }

  /// Clears the profile cache (useful for refresh)
  void clearCache() {
    if (_isDisposed) return;
    _requestUserProfiles.clear();
    AppLogger.info('🗑️ User profile cache cleared');
  }

  /// Gets display name with loading fallback
  String getDisplayNameForUser(String userId) {
    final profile = getUserProfile(userId);
    return profile?.displayName ?? 'Laddar...';
  }

  /// Gets profile picture URL
  String? getProfilePictureUrlForUser(String userId) {
    final profile = getUserProfile(userId);
    return profile?.avatarUrl;
  }

  /// Gets avatar URL (alias for profile picture)
  String? getAvatarUrlForUser(String userId) {
    return getProfilePictureUrlForUser(userId);
  }

  /// Checks if user is online
  bool isUserOnline(String userId) {
    final profile = getUserProfile(userId);
    return profile?.isOnline ?? false;
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _requestUserProfiles.clear();
    super.dispose();
  }
}
