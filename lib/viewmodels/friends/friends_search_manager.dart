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
  bool _searchDegraded = false;
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

  /// True when the last search failed because the backend errored (an outage),
  /// as opposed to legitimately matching nobody (BUT-1442). The view shows a
  /// "search unavailable" notice for this state instead of the neutral
  /// "no users found" empty state.
  bool get searchDegraded => _searchDegraded;
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
      _searchDegraded = false;
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
      _searchDegraded = false;
      AppLogger.info(
        '🔍 Search for "$_searchQuery" returned ${_searchResults.length} results (from cache)',
      );
      _safeNotifyListeners();
      return;
    }

    _isSearching = true;
    _safeNotifyListeners();

    try {
      final result = await _friendsService.management.searchUsersResult(
        _searchQuery,
      );

      if (_isDisposed) return;

      _searchResults = result.hits;

      if (result.failed) {
        // BUT-1442: the search backend errored (an outage) — surface a
        // degraded notice instead of a neutral "no users found" state, and do
        // NOT cache the result, or a transient outage would poison this
        // query's cache until eviction.
        _searchDegraded = true;
        _searchError = AppLocale.current.socialSearchUnavailable;
        AppLogger.warning(
          '🔍 Search for "$_searchQuery" failed (backend unavailable)',
        );
      } else {
        _searchDegraded = false;
        _searchError = null;
        _cacheSearchResults(_searchQuery, result.hits);

        AppLogger.info(
          '🔍 Search for "$_searchQuery" returned ${result.hits.length} results',
        );

        // BUT-939: log only on actual network search (cache hits don't
        // qualify — they don't reflect user intent re-engaging the funnel).
        // tryGet so a missing analytics service can't break the search flow.
        ServiceLocator.tryGet<AnalyticsService>()?.social
            .logFriendSearchPerformed(
              queryLength: _searchQuery.length,
              resultCount: result.hits.length,
            );
      }
    } catch (e) {
      if (_isDisposed) return;

      _searchDegraded = true;
      _searchError = AppLocale.current.socialSearchUnavailable;
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
    _searchDegraded = false;
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    // Replace rather than clear() in place: a degraded/empty search assigns the
    // unmodifiable `const []` from SearchResult.failure (BUT-1442), and
    // clear()-ing that throws. Dropping the reference frees it just the same.
    _searchResults = [];
    _searchCache.clear();
    super.dispose();
  }
}
