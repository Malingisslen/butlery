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
///   String getContentTitle(SharedRecipe content) => content.recipeSnapshot.title;
/// }
/// ```

// lib/viewmodels/shared_content/base_shared_content_viewmodel.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/permission_service.dart';

/// Abstract base ViewModel for shared content management.
/// Provides common patterns for loading, filtering, state management,
/// and operations while allowing content-specific customization.
abstract class BaseSharedContentViewModel<TContent> extends ChangeNotifier {
  /// Content collection loaded from repositories
  List<TContent> _content = [];

  /// Search query for filtering content
  String _searchQuery = '';

  /// Loading state indicator
  bool _isLoading = false;

  /// Error message, null if no error
  String? _error;

  /// Import/operation in progress indicator (global)
  bool _isOperating = false;

  /// Per-item operation state for individual loading spinners
  /// Bug fix: Prevents loading spinner showing on all items when importing one
  final Set<String> _operatingItemIds = {};

  /// Pagination state
  bool _isLoadingMore = false;
  bool _hasMoreContent = true;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 25;

  /// Show imported content filter (default: false = hide imported for cleaner inbox)
  bool _showImported = false;
  BaseSharedContentViewModel() {
    AppLogger.info('${contentTypeName}ViewModel initialized');
    // Don't auto-initialize - coordinator will trigger when ready
    // This prevents race condition where currentUserId is null at constructor time
  }

  /// Content type name for logging (e.g., 'recipe', 'menu', 'shopping_list')
  String get contentTypeName;

  /// Load content from repository/service (initial load)
  Future<List<TContent>> loadContentFromRepository();

  /// Load content with pagination support
  /// [limit] Number of items to load (default: 25)
  /// [startAfter] Document to start after for pagination
  Future<List<TContent>> loadContentWithPagination({
    int limit = 25,
    DocumentSnapshot? startAfter,
  });

  /// Get the last document snapshot from the latest query
  /// Used for pagination cursor
  DocumentSnapshot? getLastDocumentFromContent(List<TContent> content);

  /// Get display title from content for logging/UI
  String getContentTitle(TContent content);

  /// Check if content matches search query
  bool contentMatchesSearch(TContent content, String searchQuery);

  /// Get current user ID for operations
  String? get currentUserId =>
      ServiceLocator.get<PermissionService>().currentUserId;

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

  /// Filtered content based on search query
  List<TContent> get filteredContent {
    if (_searchQuery.isEmpty) return content;
    return _content
        .where((item) => contentMatchesSearch(item, _searchQuery))
        .toList();
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
        '🔄 Loading $contentTypeName content (page 1, limit: $_pageSize)...');
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

      // Update pagination state
      _lastDocument = getLastDocumentFromContent(loadedContent);
      _hasMoreContent = loadedContent.length >= _pageSize;

      _clearError();
      AppLogger.success(
          '✅ Loaded ${_content.length} $contentTypeName(s) (hasMore: $_hasMoreContent)');
    } catch (e) {
      _setError('Failed to load $contentTypeName content: $e');
      AppLogger.error('Failed to load $contentTypeName content: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load more content (pagination)
  Future<void> loadMoreContent() async {
    // Don't load if already loading or no more content
    if (_isLoadingMore || !_hasMoreContent || _lastDocument == null) {
      AppLogger.info(
          '⏭️ Skipping load more: isLoadingMore=$_isLoadingMore, hasMore=$_hasMoreContent, lastDoc=${_lastDocument != null}');
      return;
    }

    AppLogger.info(
        '🔄 Loading more $contentTypeName content (limit: $_pageSize)...');
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

      // Update pagination state
      _lastDocument = getLastDocumentFromContent(loadedContent);
      _hasMoreContent = loadedContent.length >= _pageSize;

      _clearError();
      AppLogger.success(
          '✅ Loaded ${loadedContent.length} more $contentTypeName(s) (total: ${_content.length}, hasMore: $_hasMoreContent)');
    } catch (e) {
      _setError('Failed to load more $contentTypeName: $e');
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

  /// Update search query and notify listeners
  void updateSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
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
    AppLogger.info('➕ Added $contentTypeName: ${getContentTitle(content)}');
    notifyListeners();
  }

  /// Remove content from local collection
  void removeContent(TContent content) {
    if (_content.remove(content)) {
      AppLogger.info('➖ Removed $contentTypeName: ${getContentTitle(content)}');
      notifyListeners();
    }
  }

  /// Update content in local collection
  void updateContent(TContent oldContent, TContent newContent) {
    final index = _content.indexOf(oldContent);
    if (index != -1) {
      _content[index] = newContent;
      AppLogger.info(
          '🔄 Updated $contentTypeName: ${getContentTitle(newContent)}');
      notifyListeners();
    }
  }

  /// Replace entire content collection
  void replaceContent(List<TContent> newContent) {
    _content = List.from(newContent);
    AppLogger.info(
        '🔄 Replaced $contentTypeName collection with ${_content.length} items');
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
      _setError('$operationName failed: $e');
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

  @override
  void dispose() {
    AppLogger.info('Disposing ${contentTypeName}ViewModel');
    super.dispose();
  }
}
