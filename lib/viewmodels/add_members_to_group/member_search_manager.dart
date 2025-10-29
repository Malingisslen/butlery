/// Manager handling friend search and filtering operations for group member addition.

import 'package:flutter/foundation.dart';
import 'package:butlery/models/user_profile.dart';

/// Manages friend search functionality including query handling and result filtering.
class MemberSearchManager extends ChangeNotifier {
  List<UserProfile> _availableFriends = [];
  List<UserProfile> _filteredFriends = [];
  String _searchQuery = '';

  MemberSearchManager();

  List<UserProfile> get filteredFriends => List.unmodifiable(_filteredFriends);
  String get searchQuery => _searchQuery;
  bool get hasSearchQuery => _searchQuery.isNotEmpty;
  int get filteredFriendsCount => _filteredFriends.length;

  void setAvailableFriends(List<UserProfile> friends) {
    _availableFriends = friends;
    _applySearchFilter();
    notifyListeners();
  }

  void updateSearch(String query) {
    _searchQuery = query.trim().toLowerCase();
    _applySearchFilter();
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _applySearchFilter();
    notifyListeners();
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredFriends = List.from(_availableFriends);
    } else {
      _filteredFriends = _availableFriends
          .where((friend) =>
              friend.displayName.toLowerCase().contains(_searchQuery))
          .toList();
    }
  }
}
