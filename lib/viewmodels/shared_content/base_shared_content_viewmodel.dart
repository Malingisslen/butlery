/// Base class for shared content ViewModels providing common patterns and functionality.
/// This abstract base class implements the Template Method pattern for shared content
/// ViewModels, providing consistent state management, error handling, and common
/// operations while allowing specialized ViewModels to customize content-specific logic.
/// **Design Pattern**: Template Method + Strategy
/// **Responsibility**: Common ViewModel patterns for all shared content types
/// **Abstraction Level**: ViewModels coordinate between UI and Services/Repositories
/// **Key Features:**
/// - **Consistent State Management**: Loading, error, and operation states
/// - **Template Method Pattern**: Common algorithms with customizable steps
/// - **Error Handling**: Standardized error management across content types
/// - **Logging Integration**: Consistent logging patterns for debugging
/// - **Change Notification**: Proper Flutter ChangeNotifier integration
/// **Usage Example:**
/// ```dart
/// class SharedRecipeViewModel extends BaseSharedContentViewModel<SharedRecipe> {
///   @override
///   String get contentTypeName => 'recipe';
///   @override
///   Future<List<SharedRecipe>> loadContentFromRepository() async {
///     return await _sharedRecipeRepository.getSharedRecipesForUser(currentUserId);
///   }
///   @override
///   String getContentTitle(SharedRecipe content) => content.recipeTitle;
/// }
/// ```

// lib/viewmodels/shared_content/base_shared_content_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/core/utils/error_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

/// Abstract base ViewModel for shared content management.
/// Provides common patterns for loading, filtering, state management,
/// and operations while allowing content-specific customization.
///
/// **Deliberate exception to the `extends BaseViewModel` convention**
/// (lib/viewmodels/CLAUDE.md): this family extends [ChangeNotifier] directly
/// because it hand-rolls a richer state surface than BaseViewModel offers —
/// per-item operating state ([_operatingItemIds]), cursor pagination, a
/// memoized filtered-content cache, and a show-imported filter. Re-homing
/// onto BaseViewModel's single isLoading/error pair would lose those.
/// The one thing BaseViewModel gives for free that we MUST preserve is the
/// post-dispose [notifyListeners] guard — replicated below via [_isDisposed].
abstract class BaseSharedContentViewModel<TContent> extends ChangeNotifier {
  /// Content collection loaded from repositories
  List<TContent> _content = [];

  /// Search query for filtering content
  String _searchQuery = '';

  /// Cached filtered content — invalidated when _content or _searchQuery changes
  List<TContent>? _filteredContentCache;

  /// Loading state indicator
  bool _isLoading = false;

  /// Error message, null if no error
  String? _error;

  /// Disposed flag — async work (loadContent, loadMoreContent, markAsViewed,
  /// executeOperation) can complete after the widget is gone. This guards
  /// every notifyListeners against the post-dispose "used after disposed"
  /// crash. Mirrors BaseViewModel's override; this family stays on
  /// ChangeNotifier directly (see class header) but must not lose the guard.
  bool _isDisposed = false;

  /// Whether this ViewModel has been disposed. Subclasses should check this
  /// before any post-await state mutation.
  bool get isDisposed => _isDisposed;

  /// Import/operation in progress indicator (global)
  bool _isOperating = false;

  /// Per-item operation state for individual loading spinners
  /// Bug fix: Prevents loading spinner showing on all items when importing one
  final Set<String> _operatingItemIds = {};

  /// Pagination state
  bool _isLoadingMore = false;
  bool _hasMoreContent = true;
  Object? _lastDocument;
  static const int _pageSize = 25;

  /// Show imported content filter (default: false = hide imported for cleaner inbox)
  bool _showImported = false;

  /// Blocked-user set from UnifiedFriendsService (optional dependency).
  final UnifiedFriendsService? _friendsService;

  /// Permission service for the current-user lookup. Injectable for tests
  /// (BUT-1075); defaults to the production locator so callers are unchanged.
  final PermissionService _permissionService;

  /// Users blocked by the current user. Content from these users should be filtered out.
  Set<String> get blockedUsers => _friendsService?.blockedUsers ?? {};

  /// BUT-1075: [permissionService] and [friendsService] are injectable so
  /// shared-content VM tests no longer need the production-locator bridge just
  /// to resolve these two collaborators. Both default to `ServiceLocator`
  /// resolution, so production construction is unchanged. Mirrors
  /// `FriendsViewModel`. PermissionService resolves the singleton reference at
  /// construction (it is registered well before any VM is built); only
  /// `currentUserId` reads from it lazily, preserving the prior timing.
  BaseSharedContentViewModel({
    PermissionService? permissionService,
    UnifiedFriendsService? friendsService,
  }) : _permissionService =
           permissionService ?? ServiceLocator.get<PermissionService>(),
       _friendsService =
           friendsService ?? ServiceLocator.tryGet<UnifiedFriendsService>() {
    AppLogger.info('${contentTypeName}ViewModel initialized');
    // Don't auto-initialize - coordinator will trigger when ready
    // This prevents race condition where currentUserId is null at constructor time
  }

  /// Content type name for logging (e.g., 'recipe', 'menu', 'shopping_list')
  String get contentTypeName;

  /// Whether this ViewModel supports cursor-based pagination.
  /// Subclasses that implement real pagination must override this to true.
  /// [loadMoreContent] throws [UnsupportedError] when false, ensuring callers
  /// discover the missing implementation at runtime rather than silently
  /// receiving duplicate or empty results.
  bool get supportsPagination => false;

  /// Load content from repository/service (initial load)
  Future<List<TContent>> loadContentFromRepository();

  /// Load content with pagination support
  /// [limit] Number of items to load (default: 25)
  /// [startAfter] Document to start after for pagination
  Future<List<TContent>> loadContentWithPagination({
    int limit = 25,
    Object? startAfter,
  });

  /// Get the last document from the latest query, used as pagination cursor.
  /// Opaque to the viewmodel layer - the repository interprets the actual type.
  Object? getLastDocumentFromContent(List<TContent> content);

  /// Get display title from content for logging/UI
  String getContentTitle(TContent content);

  /// Check if content matches search query
  bool contentMatchesSearch(TContent content, String searchQuery);

  /// Get current user ID for operations
  String? get currentUserId => _permissionService.currentUserId;

  /// Current search query
  String get searchQuery => _searchQuery;

  /// Loading state
  bool get isLoading => _isLoading;

  /// Error state
  String? get error => _error;

  /// Has error flag
  bool get hasError => _error != null;

  /// Operation in progress state (global - true if any item is operating)
  bool get isOperating => _isOperating || _operatingItemIds.isNotEmpty;

  /// Check if a specific item is being operated on
  /// Use this for per-item loading spinners
  bool isItemOperating(String itemId) => _operatingItemIds.contains(itemId);

  /// Set operating state for a specific item
  /// Use this when importing/operating on individual items
  void setItemOperating(String itemId, bool operating) {
    if (operating) {
      _operatingItemIds.add(itemId);
    } else {
      _operatingItemIds.remove(itemId);
    }
    notifyListeners();
  }

  /// All loaded content
  List<TContent> get content => List.unmodifiable(_content);

  /// Filtered content based on search query (memoized)
  List<TContent> get filteredContent {
    if (_filteredContentCache != null) return _filteredContentCache!;
    if (_searchQuery.isEmpty) {
      _filteredContentCache = content;
    } else {
      _filteredContentCache = _content
          .where((item) => contentMatchesSearch(item, _searchQuery))
          .toList();
    }
    return _filteredContentCache!;
  }

  /// Content count
  int get totalCount => _content.length;

  /// Filtered content count
  int get filteredCount => filteredContent.length;

  /// Has any content
  bool get hasContent => _content.isNotEmpty;

  /// Has filtered content
  bool get hasFilteredContent => filteredContent.isNotEmpty;

  /// Loading more content (pagination)
  bool get isLoadingMore => _isLoadingMore;

  /// Has more content to load
  bool get hasMoreContent => _hasMoreContent;

  /// Show imported content filter state
  bool get showImported => _showImported;

  /// Set show imported filter and notify listeners
  void setShowImported(bool value) {
    if (_showImported != value) {
      _showImported = value;
      AppLogger.info('🔄 $contentTypeName showImported set to: $value');
      notifyListeners();
    }
  }

  /// Load initial content from repository with pagination
  Future<void> loadContent() async {
    AppLogger.info(
      '🔄 Loading $contentTypeName content (page 1, limit: $_pageSize)...',
    );
    _setLoading(true);

    try {
      // Reset pagination state for fresh load
      _lastDocument = null;
      _hasMoreContent = true;

      // Load first page
      final loadedContent = await loadContentWithPagination(
        limit: _pageSize,
        startAfter: null,
      );

      _content = loadedContent;
      _invalidateFilteredCache();

      // Update pagination state
      _lastDocument = getLastDocumentFromContent(loadedContent);
      _hasMoreContent = loadedContent.length >= _pageSize;

      _clearError();
      AppLogger.success(
        '✅ Loaded ${_content.length} $contentTypeName(s) (hasMore: $_hasMoreContent)',
      );
    } catch (e) {
      _setError(sanitizeErrorForUser(e));
      AppLogger.error('Failed to load $contentTypeName content: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load more content (pagination)
  Future<void> loadMoreContent() async {
    if (!supportsPagination) {
      throw UnsupportedError(
        '$contentTypeName ViewModel does not support pagination. '
        'Override supportsPagination to return true and implement '
        'loadContentWithPagination with a real cursor.',
      );
    }

    // Don't load if already loading or no more content
    if (_isLoadingMore || !_hasMoreContent || _lastDocument == null) {
      AppLogger.info(
        '⏭️ Skipping load more: isLoadingMore=$_isLoadingMore, hasMore=$_hasMoreContent, lastDoc=${_lastDocument != null}',
      );
      return;
    }

    AppLogger.info(
      '🔄 Loading more $contentTypeName content (limit: $_pageSize)...',
    );
    _isLoadingMore = true;
    notifyListeners();

    try {
      // Load next page
      final loadedContent = await loadContentWithPagination(
        limit: _pageSize,
        startAfter: _lastDocument,
      );

      // Append to existing content
      _content.addAll(loadedContent);
      _invalidateFilteredCache();

      // Update pagination state
      _lastDocument = getLastDocumentFromContent(loadedContent);
      _hasMoreContent = loadedContent.length >= _pageSize;

      _clearError();
      AppLogger.success(
        '✅ Loaded ${loadedContent.length} more $contentTypeName(s) (total: ${_content.length}, hasMore: $_hasMoreContent)',
      );
    } catch (e) {
      _setError(sanitizeErrorForUser(e));
      AppLogger.error('Failed to load more $contentTypeName: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Refresh content from repository
  Future<void> refreshContent() async {
    AppLogger.info('🔄 Refreshing $contentTypeName content...');
    await loadContent();
  }

  /// Invalidate the filtered content cache
  void _invalidateFilteredCache() {
    _filteredContentCache = null;
  }

  /// Update search query and notify listeners
  void updateSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _invalidateFilteredCache();
      AppLogger.info('🔍 Updated search query for $contentTypeName: "$query"');
      notifyListeners();
    }
  }

  /// Clear search query
  void clearSearch() {
    updateSearchQuery('');
  }

  /// Set loading state and notify listeners
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Set operating state and notify listeners
  void _setOperating(bool operating) {
    if (_isOperating != operating) {
      _isOperating = operating;
      notifyListeners();
    }
  }

  /// Set error message and notify listeners
  void _setError(String errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }

  /// Clear error state and notify listeners
  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// Add content to local collection
  void addContent(TContent content) {
    _content.add(content);
    _invalidateFilteredCache();
    AppLogger.info('➕ Added $contentTypeName: ${getContentTitle(content)}');
    notifyListeners();
  }

  /// Remove content from local collection
  void removeContent(TContent content) {
    if (_content.remove(content)) {
      _invalidateFilteredCache();
      AppLogger.info('➖ Removed $contentTypeName: ${getContentTitle(content)}');
      notifyListeners();
    }
  }

  /// Update content in local collection
  void updateContent(TContent oldContent, TContent newContent) {
    final index = _content.indexOf(oldContent);
    if (index != -1) {
      _content[index] = newContent;
      _invalidateFilteredCache();
      AppLogger.info(
        '🔄 Updated $contentTypeName: ${getContentTitle(newContent)}',
      );
      notifyListeners();
    }
  }

  /// Replace entire content collection
  void replaceContent(List<TContent> newContent) {
    _content = List.from(newContent);
    _invalidateFilteredCache();
    AppLogger.info(
      '🔄 Replaced $contentTypeName collection with ${_content.length} items',
    );
    notifyListeners();
  }

  /// Execute operation with loading state and error handling
  Future<T?> executeOperation<T>(
    String operationName,
    Future<T?> Function() operation, {
    bool useOperatingState = true,
  }) async {
    AppLogger.info('🔄 Starting $operationName for $contentTypeName...');

    if (useOperatingState) {
      _setOperating(true);
    } else {
      _setLoading(true);
    }

    try {
      final result = await operation();
      _clearError();
      AppLogger.success('✅ $operationName completed successfully');
      return result;
    } catch (e) {
      _setError(sanitizeErrorForUser(e));
      AppLogger.error('❌ $operationName failed: $e');
      return null;
    } finally {
      if (useOperatingState) {
        _setOperating(false);
      } else {
        _setLoading(false);
      }
    }
  }

  /// Guarded so async continuations that fire after [dispose] (in-flight
  /// coordinator calls in loadContent / loadMoreContent / markAsViewed /
  /// executeOperation) become no-ops instead of throwing "A
  /// ChangeNotifier was used after being disposed." Mirrors the guard
  /// BaseViewModel provides; this family intentionally stays on
  /// ChangeNotifier (see class header).
  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    AppLogger.info('Disposing ${contentTypeName}ViewModel');
    _isDisposed = true;
    super.dispose();
  }
}
