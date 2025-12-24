/// Manager handling user profile operations for social interactions.

import 'package:flutter/foundation.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/utils/logger.dart';

class SocialProfileManager extends ChangeNotifier {
  final UnifiedFriendsService _friendsService;
  final UserService _userService;

  List<UserProfile> _friends = [];
  UserProfile? _currentUser;

  SocialProfileManager(this._friendsService, this._userService);

  List<UserProfile> get friends => _friends;
  UserProfile? get currentUser => _currentUser;

  Future<void> initialize() async {
    try {
      _currentUser = _userService.currentUserProfile;
      _friends = _friendsService.friends;

      AppLogger.info(
          'SocialProfileManager initialized - User: ${_currentUser?.displayName ?? "Not logged in"}, Friends: ${_friends.length}');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Failed to initialize SocialProfileManager: $e');
    }
  }

  String getAuthorDisplayName(String authorId) {
    if (authorId == _currentUser?.uid) {
      return _currentUser?.displayName ?? 'Du';
    }

    try {
      final friend = _friends.firstWhere((f) => f.uid == authorId);
      return friend.displayName;
    } catch (e) {
      return 'Okänd användare';
    }
  }

  String? getAuthorAvatarUrl(String authorId) {
    if (authorId == _currentUser?.uid) {
      return _currentUser?.avatarUrl;
    }

    try {
      final friend = _friends.firstWhere((f) => f.uid == authorId);
      return friend.avatarUrl;
    } catch (e) {
      return null;
    }
  }
}
