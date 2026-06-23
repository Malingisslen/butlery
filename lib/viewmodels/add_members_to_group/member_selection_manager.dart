/// Manager handling friend selection operations for group member addition.

import 'package:flutter/foundation.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/utils/logger.dart';

/// Manages friend selection state and bulk selection operations.
class MemberSelectionManager extends ChangeNotifier {
  final Set<String> _selectedFriendIds = {};
  final List<UserProfile> Function() _getFilteredFriends;

  MemberSelectionManager(this._getFilteredFriends);

  Set<String> get selectedFriendIds => Set.unmodifiable(_selectedFriendIds);
  int get selectedCount => _selectedFriendIds.length;
  bool get hasSelectedFriends => _selectedFriendIds.isNotEmpty;

  List<UserProfile> get selectedFriends {
    final filtered = _getFilteredFriends();
    return filtered
        .where((friend) => _selectedFriendIds.contains(friend.uid))
        .toList();
  }

  void toggleFriendSelection(String friendId) {
    if (_selectedFriendIds.contains(friendId)) {
      _selectedFriendIds.remove(friendId);
      AppLogger.info('❌ Avmarkerad vän: $friendId');
    } else {
      _selectedFriendIds.add(friendId);
      AppLogger.info('✅ Markerad vän: $friendId');
    }
    notifyListeners();
  }

  bool isFriendSelected(String friendId) {
    return _selectedFriendIds.contains(friendId);
  }

  void selectAllVisible() {
    _selectedFriendIds.clear();
    final filtered = _getFilteredFriends();
    _selectedFriendIds.addAll(filtered.map((f) => f.uid));
    AppLogger.info(
      '✅ Markerade alla synliga vänner (${_selectedFriendIds.length})',
    );
    notifyListeners();
  }

  void clearAllSelections() {
    _selectedFriendIds.clear();
    AppLogger.info('❌ Rensade alla val');
    notifyListeners();
  }

  void clearSelectionsForUsers(Set<String> userIds) {
    _selectedFriendIds.removeAll(userIds);
    notifyListeners();
  }
}
