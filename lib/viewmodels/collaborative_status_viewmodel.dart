/// lib/viewmodels/collaborative_status_viewmodel.dart


import 'package:flutter/widgets.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';

/// 🎯 Content type enum för type safety
enum CollaborativeContentType {
  recipe,
  menu,
  shoppingList,
}

/// 📊 Status result class för rik data
class CollaborativeStatus {
  final bool isCollaborative;
  final List<UserProfile> participants;
  final DateTime? lastChecked;
  final String? error;

  const CollaborativeStatus({
    required this.isCollaborative,
    this.participants = const [],
    this.lastChecked,
    this.error,
  });

  CollaborativeStatus.loading()
      : isCollaborative = false,
        participants = const [],
        lastChecked = null,
        error = null;

  CollaborativeStatus.error(String errorMessage)
      : isCollaborative = false,
        participants = const [],
        lastChecked = DateTime.now(),
        error = errorMessage;

  bool get isLoading => lastChecked == null && error == null;
  bool get hasError => error != null;
  bool get isValid => lastChecked != null && error == null;
}

/// 🤝 Enhanced Collaborative Status ViewModel
///
/// Skalbar system för att hantera kollaborativ status över alla content-typer
/// med robust caching, batch operations och comprehensive error handling
class CollaborativeStatusViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final SocialRecipeService _socialRecipeService;

  // ===== LIFECYCLE MANAGEMENT =====
  
  /// Flag to track if ViewModel has been disposed
  bool _isDisposed = false;

  // ===== GENERIC CACHING SYSTEM =====

  /// Universal cache för alla content types
  final Map<String, CollaborativeStatus> _statusCache = {};

  /// Set av keys som håller på att checkas
  final Set<String> _checkingKeys = {};

  /// Cache TTL (5 minuter för collaborative status)
  static const Duration _cacheTtl = Duration(minutes: 5);

  // ===== CONSTRUCTOR =====

  CollaborativeStatusViewModel({
    SocialRecipeService? socialRecipeService,
  })  : _socialRecipeService = socialRecipeService ?? sl<SocialRecipeService>();

  // ===== PUBLIC GETTERS =====

  String? get currentUserId => sl<PermissionService>().currentUserId;

  // ===== SAFE NOTIFICATION HELPER =====
  
  /// Safely notify listeners only if not disposed
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Hämta cached status för content
  CollaborativeStatus? getCachedStatus(
      String contentId, CollaborativeContentType type) {
    final key = _buildCacheKey(contentId, type);
    final cached = _statusCache[key];

    if (cached == null) return null;

    // Kontrollera cache validity
    if (cached.isValid && cached.lastChecked != null) {
      final age = DateTime.now().difference(cached.lastChecked!);
      if (age > _cacheTtl) {
        _statusCache.remove(key);
        return null;
      }
    }

    return cached;
  }

  // ===== RECIPE COLLABORATIVE STATUS =====

  /// 🍳 Hämta kollaborativ status för recept (modern API)
  CollaborativeStatus getRecipeCollaborativeStatus(
      String recipeId, Recipe? recipe) {
    final cached = getCachedStatus(recipeId, CollaborativeContentType.recipe);
    if (cached != null) return cached;

    // Starta async check i bakgrunden
    _checkContentStatusAsync(recipeId, CollaborativeContentType.recipe);

    // Returnera intelligent fallback medan vi väntar
    final metadataResult = _analyzeRecipeMetadata(recipe);
    return CollaborativeStatus(
      isCollaborative: metadataResult,
      lastChecked: null, // Indikerar att detta är fallback
    );
  }

  /// Legacy support för boolean API (för bakåtkompatibilitet)
  bool getRecipeCollaborativeStatusLegacy(String recipeId, Recipe? recipe) {
    return getRecipeCollaborativeStatus(recipeId, recipe).isCollaborative;
  }

  // ===== MENU COLLABORATIVE STATUS =====

  /// 📅 Hämta kollaborativ status för meny
  CollaborativeStatus getMenuCollaborativeStatus(
      String menuId, Map<String, List<Recipe>>? menuData) {
    final cached = getCachedStatus(menuId, CollaborativeContentType.menu);
    if (cached != null) return cached;

    _checkContentStatusAsync(menuId, CollaborativeContentType.menu);

    final metadataResult = _analyzeMenuMetadata(menuData);
    return CollaborativeStatus(
      isCollaborative: metadataResult,
      lastChecked: null,
    );
  }

  /// Legacy support för boolean API
  bool getMenuCollaborativeStatusLegacy(
      String menuId, Map<String, List<Recipe>>? menuData) {
    return getMenuCollaborativeStatus(menuId, menuData).isCollaborative;
  }

  // ===== SHOPPING LIST COLLABORATIVE STATUS =====

  /// 🛒 Hämta kollaborativ status för inköpslista
  CollaborativeStatus getShoppingListCollaborativeStatus(String listId) {
    final cached =
        getCachedStatus(listId, CollaborativeContentType.shoppingList);
    if (cached != null) return cached;

    _checkContentStatusAsync(listId, CollaborativeContentType.shoppingList);

    // Ingen metadata-analys för shopping lists än
    return const CollaborativeStatus(
      isCollaborative: false,
      lastChecked: null,
    );
  }

  // ===== UNIVERSAL ASYNC CHECKING =====

  /// 🔄 Universal async check för alla content types
  Future<void> _checkContentStatusAsync(
      String contentId, CollaborativeContentType type) async {
    final userId = currentUserId;
    if (userId == null) return;

    final key = _buildCacheKey(contentId, type);
    if (_checkingKeys.contains(key)) return;

    _checkingKeys.add(key);

    // Sätt loading state
    _statusCache[key] = CollaborativeStatus.loading();
    
    // Defer notification to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _safeNotifyListeners();
    });

    try {
      AppLogger.info(
          '🔍 Async check: ${type.name} $contentId collaborative status');

      // Anropa rätt service-metod baserat på type
      late bool isShared;
      late List<UserProfile> participants;

      switch (type) {
        case CollaborativeContentType.recipe:
          isShared = await _socialRecipeService.isRecipeSharedByUser(
              contentId, userId);
          if (isShared) {
            participants =
                await _socialRecipeService.getRecipeParticipants(contentId);
          } else {
            participants = [];
          }
          break;

        case CollaborativeContentType.menu:
          isShared =
              await _socialRecipeService.isMenuSharedByUser(contentId, userId);
          if (isShared) {
            participants =
                await _socialRecipeService.getMenuParticipants(contentId);
          } else {
            participants = [];
          }
          break;

        case CollaborativeContentType.shoppingList:
          isShared = await _socialRecipeService.isShoppingListSharedByUser(
              contentId, userId);
          if (isShared) {
            participants = await _socialRecipeService
                .getShoppingListParticipants(contentId);
          } else {
            participants = [];
          }
          break;
      }

      // Uppdatera cache med resultat
      _statusCache[key] = CollaborativeStatus(
        isCollaborative: isShared,
        participants: participants,
        lastChecked: DateTime.now(),
      );

      // Defer notification to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _safeNotifyListeners();
      });

      AppLogger.info(
          '✅ ${type.name} $contentId status cached: $isShared (${participants.length} participants)');
    } catch (e) {
      AppLogger.error(
          '❌ Failed ${type.name} collaborative check for $contentId', e);

      _statusCache[key] = CollaborativeStatus.error(e.toString());
      
      // Defer notification to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _safeNotifyListeners();
      });
    } finally {
      _checkingKeys.remove(key);
    }
  }

  // ===== METADATA ANALYSIS =====

  /// 📋 Analysera recept metadata för collaborative indicators
  bool _analyzeRecipeMetadata(Recipe? recipe) {
    if (recipe == null) return false;

    // Source URL patterns
    if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) {
      final url = recipe.sourceUrl!.toLowerCase();
      if (url.contains('shared_recipe_id=') ||
          url.contains('collaborative=true') ||
          url.contains('shared_with=') ||
          url.contains('delad meny:')) {
        return true;
      }
    }

    // Title/description patterns
    final title = recipe.title.toLowerCase();
    final description = recipe.description.toLowerCase();

    if (title.contains('(delad)') ||
        title.contains('(shared)') ||
        description.contains('delat med') ||
        description.contains('shared with') ||
        description.contains('från "') ||
        description.contains('--- från')) {
      return true;
    }

    // Tags analysis
    final tags = recipe.tags ?? [];
    if (tags.any((tag) =>
        tag.toLowerCase().contains('delad') ||
        tag.toLowerCase().contains('shared') ||
        tag.toLowerCase().contains('från-meny') ||
        tag.toLowerCase().contains('importerat'))) {
      return true;
    }

    return false;
  }

  /// 📋 Analysera meny metadata
  bool _analyzeMenuMetadata(Map<String, List<Recipe>>? menuData) {
    if (menuData == null || menuData.isEmpty) return false;

    // Kolla om någon av recepten i menyn är kollaborativ
    for (final dayRecipes in menuData.values) {
      for (final recipe in dayRecipes) {
        if (_analyzeRecipeMetadata(recipe)) {
          return true;
        }
      }
    }

    return false;
  }

  // ===== BATCH OPERATIONS =====

  /// 🚀 Batch check för mixed content types
  Future<void> batchCheckContent({
    List<String>? recipeIds,
    List<String>? menuIds,
    List<String>? shoppingListIds,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    // Samla alla uncached IDs
    final recipesToCheck = recipeIds
            ?.where((id) =>
                getCachedStatus(id, CollaborativeContentType.recipe) == null)
            .toList() ??
        [];

    final menusToCheck = menuIds
            ?.where((id) =>
                getCachedStatus(id, CollaborativeContentType.menu) == null)
            .toList() ??
        [];

    final shoppingToCheck = shoppingListIds
            ?.where((id) =>
                getCachedStatus(id, CollaborativeContentType.shoppingList) ==
                null)
            .toList() ??
        [];

    if (recipesToCheck.isEmpty &&
        menusToCheck.isEmpty &&
        shoppingToCheck.isEmpty) {
      return;
    }

    AppLogger.info('🚀 Batch checking: ${recipesToCheck.length} recipes, '
        '${menusToCheck.length} menus, ${shoppingToCheck.length} shopping lists');

    // Parallell processing för alla content types
    final futures = <Future<void>>[];

    // Recept
    for (final recipeId in recipesToCheck) {
      futures.add(
          _checkContentStatusAsync(recipeId, CollaborativeContentType.recipe));
    }

    // Menyer
    for (final menuId in menusToCheck) {
      futures
          .add(_checkContentStatusAsync(menuId, CollaborativeContentType.menu));
    }

    // Inköpslistor
    for (final listId in shoppingToCheck) {
      futures.add(_checkContentStatusAsync(
          listId, CollaborativeContentType.shoppingList));
    }

    // Vänta på alla checks
    await Future.wait(futures);
  }

  // ===== CACHE MANAGEMENT =====

  /// 🧹 Invalidate specific content
  void invalidateContent(String contentId, CollaborativeContentType type) {
    final key = _buildCacheKey(contentId, type);
    _statusCache.remove(key);
    
    // Defer notification to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _safeNotifyListeners();
    });
    
    AppLogger.info('🗑️ Invalidated cache för ${type.name} $contentId');
  }

  /// Legacy methods för bakåtkompatibilitet
  void invalidateRecipeStatus(String recipeId) =>
      invalidateContent(recipeId, CollaborativeContentType.recipe);

  void invalidateMenuStatus(String menuId) =>
      invalidateContent(menuId, CollaborativeContentType.menu);

  /// 🧹 Rensa ALL cache
  void clearAllCache() {
    _statusCache.clear();
    _checkingKeys.clear();
    
    // Defer notification to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _safeNotifyListeners();
    });
    
    AppLogger.info('🗑️ Cleared all collaborative status cache');
  }

  /// 🔧 Cache key builder
  String _buildCacheKey(String contentId, CollaborativeContentType type) {
    return '${type.name}:$contentId';
  }

  /// 📊 Enhanced debug info
  Map<String, dynamic> get debugInfo => {
        'totalCacheSize': _statusCache.length,
        'activeChecks': _checkingKeys.length,
        'currentUserId': currentUserId,
        'cacheByType': {
          for (final type in CollaborativeContentType.values)
            type.name: _statusCache.keys
                .where((key) => key.startsWith('${type.name}:'))
                .length,
        },
        'cacheTtlMinutes': _cacheTtl.inMinutes,
      };

  @override
  void dispose() {
    _isDisposed = true;
    clearAllCache();
    super.dispose();
  }
}
