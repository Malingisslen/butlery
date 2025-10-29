/// Manages user search functionality for friend discovery
///
/// Extracted from FriendsViewModel for Single Responsibility compliance.
/// Handles search queries, result management, and validation.

import 'package:flutter/foundation.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/utils/logger.dart';

class FriendsSearchManager extends ChangeNotifier {
  final UnifiedFriendsService _friendsService;

  // ===== STATE =====
  String _searchQuery = '';
  List<UserProfile> _searchResults = [];
  String? _searchError;
  bool _isDisposed = false;

  FriendsSearchManager({required UnifiedFriendsService friendsService})
      : _friendsService = friendsService;

  // ===== GETTERS =====
  String get searchQuery => _searchQuery;
  List<UserProfile> get searchResults => List.unmodifiable(_searchResults);
  String? get searchError => _searchError;
  bool get hasSearchResults => _searchResults.isNotEmpty;
  bool get hasSearchQuery => _searchQuery.isNotEmpty;

  /// Updates search query with validation and executes search
  Future<void> updateSearch(String query) async {
    if (_isDisposed) return;

    _searchQuery = query.trim();

    if (_searchQuery.isEmpty) {
      _clearSearch();
      _safeNotifyListeners();
      return;
    }

    if (_searchQuery.length < 2) {
      _searchResults = [];
      _searchError = 'Skriv minst 2 tecken för att söka';
      _safeNotifyListeners();
      return;
    }

    await _performSearch();
  }

  /// Clears search state completely
  void clearSearch() {
    if (_isDisposed) return;
    _clearSearch();
    _safeNotifyListeners();
  }

  // ===== PRIVATE METHODS =====
  Future<void> _performSearch() async {
    if (_isDisposed || _searchQuery.isEmpty) return;

    try {
      final results = await _friendsService.management.searchUsers(_searchQuery);

      if (_isDisposed) return;

      _searchResults = results;
      _searchError = null;

      AppLogger.info('🔍 Search for "$_searchQuery" returned ${_searchResults.length} results');
      _safeNotifyListeners();
    } catch (e) {
      if (_isDisposed) return;

      _searchError = 'Sökningen misslyckades';
      AppLogger.error('Search failed: $e');
      _safeNotifyListeners();
    }
  }

  void _clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _searchError = null;
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchResults.clear();
    super.dispose();
  }
}
