/// Manages friend selection state for bulk operations
/// Extracted from FriendsViewModel for Single Responsibility compliance.
/// Handles multi-friend selection for group creation and bulk operations.

import 'package:flutter/foundation.dart';
import 'package:butlery/core/mixins/disposal_guard_mixin.dart';
import 'package:butlery/models/user_profile.dart';

class FriendsSelectionManager extends ChangeNotifier with DisposalGuardMixin {
  final Set<String> _selectedFriendIds = {};

  Set<String> get selectedFriendIds => Set.unmodifiable(_selectedFriendIds);
  bool get hasSelectedFriends => _selectedFriendIds.isNotEmpty;
  int get selectedFriendsCount => _selectedFriendIds.length;

  /// Toggles friend selection state
  void toggleFriendSelection(String friendId) {
    if (isDisposed) return;

    if (_selectedFriendIds.contains(friendId)) {
      _selectedFriendIds.remove(friendId);
    } else {
      _selectedFriendIds.add(friendId);
    }
    notifyListeners();
  }

  /// Selects all friends
  void selectAllFriends(List<UserProfile> allFriends) {
    if (isDisposed) return;

    _selectedFriendIds.clear();
    _selectedFriendIds.addAll(allFriends.map((f) => f.uid));
    notifyListeners();
  }

  /// Clears all selections
  void clearSelection() {
    if (isDisposed) return;

    _selectedFriendIds.clear();
    notifyListeners();
  }

  /// Removes a friend from selection (useful when friend is removed)
  void removeFromSelection(String friendId) {
    if (isDisposed) return;

    if (_selectedFriendIds.remove(friendId)) {
      notifyListeners();
    }
  }

  /// Gets selected friends as UserProfile objects
  List<UserProfile> getSelectedFriends(List<UserProfile> allFriends) {
    return allFriends.where((f) => _selectedFriendIds.contains(f.uid)).toList();
  }

  @override
  void dispose() {
    // First, so the guard is up before the cleanup below runs.
    super.dispose();
    _selectedFriendIds.clear();
  }
}
