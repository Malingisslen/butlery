/// Manages friend selection state for bulk operations
/// Extracted from FriendsViewModel for Single Responsibility compliance.
/// Handles multi-friend selection for group creation and bulk operations.

import 'package:flutter/foundation.dart';
import 'package:butlery/models/user_profile.dart';

class FriendsSelectionManager extends ChangeNotifier {
  // ===== STATE =====
  final Set<String> _selectedFriendIds = {};
  bool _isDisposed = false;

  // ===== GETTERS =====
  Set<String> get selectedFriendIds => Set.unmodifiable(_selectedFriendIds);
  bool get hasSelectedFriends => _selectedFriendIds.isNotEmpty;
  int get selectedFriendsCount => _selectedFriendIds.length;

  /// Toggles friend selection state
  void toggleFriendSelection(String friendId) {
    if (_isDisposed) return;

    if (_selectedFriendIds.contains(friendId)) {
      _selectedFriendIds.remove(friendId);
    } else {
      _selectedFriendIds.add(friendId);
    }
    _safeNotifyListeners();
  }

  /// Selects all friends
  void selectAllFriends(List<UserProfile> allFriends) {
    if (_isDisposed) return;

    _selectedFriendIds.clear();
    _selectedFriendIds.addAll(allFriends.map((f) => f.uid));
    _safeNotifyListeners();
  }

  /// Clears all selections
  void clearSelection() {
    if (_isDisposed) return;

    _selectedFriendIds.clear();
    _safeNotifyListeners();
  }

  /// Removes a friend from selection (useful when friend is removed)
  void removeFromSelection(String friendId) {
    if (_isDisposed) return;

    if (_selectedFriendIds.remove(friendId)) {
      _safeNotifyListeners();
    }
  }

  /// Gets selected friends as UserProfile objects
  List<UserProfile> getSelectedFriends(List<UserProfile> allFriends) {
    return allFriends.where((f) => _selectedFriendIds.contains(f.uid)).toList();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _selectedFriendIds.clear();
    super.dispose();
  }
}
