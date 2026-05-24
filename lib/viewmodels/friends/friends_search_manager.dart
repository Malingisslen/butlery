/// Manages user search functionality for friend discovery
/// Extracted from FriendsViewModel for Single Responsibility compliance.
/// Handles search queries, result management, and validation.
/// Performance optimizations:
/// - Debounced search (300ms) to prevent excessive network requests
/// - Search result caching (last 10 queries)

import 'package:flutter/foundation.dart';
import 'package:butlery/core/mixins/debounce_mixin.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/l10n/app_locale.dart';

class FriendsSearchManager extends ChangeNotifier with DebounceMixin {
  final UnifiedFriendsService _friendsService;

  String _searchQuery = '';
  List<UserProfile> _searchResults = [];
  String? _searchError;
  bool _isSearching = false;
  bool _isDisposed = false;

  static const Duration _debounceDuration = Duration(milliseconds: 300);
  final Map<String, List<UserProfile>> _searchCache = {};
  static const int _maxCacheSize = 10;

  FriendsSearchManager({required UnifiedFriendsService friendsService})
      : _friendsService = friendsService;

  String get searchQuery => _searchQuery;
  List<UserProfile> get searchResults => List.unmodifiable(_searchResults);
  String? get searchError => _searchError;
  bool get isSearching => _isSearching;
  bool get hasSearchResults => _searchResults.isNotEmpty;
  bool get hasSearchQuery => _searchQuery.isNotEmpty;

  /// Updates search query with validation and executes debounced search
  Future<void> updateSearch(String query) async {
    if (_isDisposed) return;

    _searchQuery = query.trim();

    if (_searchQuery.isEmpty) {
      cancelDebounce('search');
      _clearSearch();
      _safeNotifyListeners();
      return;
    }

    if (_searchQuery.length < 2) {
      cancelDebounce('search');
      _searchResults = [];
      _searchError = AppLocale.current.errorFillRequiredFields;
      _safeNotifyListeners();
      return;
    }

    debounce('search', _debounceDuration, _performSearch);
  }

  /// Clears search state completely
  void clearSearch() {
    if (_isDisposed) return;
    _clearSearch();
    _safeNotifyListeners();
  }

  Future<void> _performSearch() async {
    if (_isDisposed || _searchQuery.isEmpty) return;

    // Check cache first
    if (_searchCache.containsKey(_searchQuery)) {
      _searchResults = _searchCache[_searchQuery]!;
      _searchError = null;
      AppLogger.info(
          '🔍 Search for "$_searchQuery" returned ${_searchResults.length} results (from cache)');
      _safeNotifyListeners();
      return;
    }

    _isSearching = true;
    _safeNotifyListeners();

    try {
      final results =
          await _friendsService.management.searchUsers(_searchQuery);

      if (_isDisposed) return;

      _searchResults = results;
      _searchError = null;

      // Cache the results
      _cacheSearchResults(_searchQuery, results);

      AppLogger.info(
          '🔍 Search for "$_searchQuery" returned ${_searchResults.length} results');

      // BUT-939: log only on actual network search (cache hits don't
      // qualify — they don't reflect user intent re-engaging the funnel).
      // tryGet so a missing analytics service can't break the search flow.
      ServiceLocator.tryGet<AnalyticsService>()
          ?.social
          .logFriendSearchPerformed(
            queryLength: _searchQuery.length,
            resultCount: results.length,
          );
    } catch (e) {
      if (_isDisposed) return;

      _searchError = AppLocale.current.errorGeneric;
      AppLogger.error('Search failed: $e');
    } finally {
      _isSearching = false;
      _safeNotifyListeners();
    }
  }

  void _cacheSearchResults(String query, List<UserProfile> results) {
    // Limit cache size
    if (_searchCache.length >= _maxCacheSize) {
      final firstKey = _searchCache.keys.first;
      _searchCache.remove(firstKey);
    }
    _searchCache[query] = results;
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
    _searchCache.clear();
    super.dispose();
  }
}
