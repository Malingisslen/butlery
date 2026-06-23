/// Social recipe sharing service for collaborative cooking and meal planning.
/// Manages recipe/menu sharing, importing, dismissal, and participant tracking.
///
/// ## Notification contract (BUT-1135)
///
/// This service intentionally does NOT extend [ChangeNotifier] and does NOT
/// call `notifyListeners()`. All callers use the **read-after-await** pattern:
///
/// ```dart
/// await socialRecipeService.initialize();   // or refresh()
/// final recipes = socialRecipeService.sharedRecipes;  // synchronous read
/// ```
///
/// Audited callers (2026-05-29):
/// - [CollaborativeStatusViewModel] — calls `await` methods, reads result directly.
/// - `CollaborativeParticipantsWidgets` — stateful widget, awaits then calls `setState`.
/// - [MinaReceptView] — calls `refresh()` via a delegated ViewModel; doesn't listen.
///
/// If a future caller needs reactive binding (e.g. a Provider listening to
/// state changes without an explicit `await`), add `with ChangeNotifier` and
/// call `notifyListeners()` after every state mutation, then remove this comment.

import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';
import 'package:butlery/repositories/firebase/firebase_social_request_repository.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/error_sanitizer.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/social/modules/social_participant_resolver_module.dart';
import 'package:butlery/services/social/modules/recipe_share_request_module.dart';

class SocialRecipeService with StreamManagementMixin, ErrorHandlingMixin {
  final UserService _userService;
  final UnifiedRecipeService _recipeService;
  final PermissionService _permissionService;
  final FirebaseSharedRecipeRepository _sharedRecipeRepository;
  final FirebaseSharedMenuRepository _sharedMenuRepository;
  final FirebaseSocialRequestRepository _socialRequestRepository;

  /// Resolved lazily to avoid cross-module dependency ordering issues
  /// (UnifiedShoppingService lives in CollaborationModule)
  UnifiedShoppingService? get _shoppingService =>
      ServiceLocator.tryGet<UnifiedShoppingService>();

  // Modules
  late final SocialParticipantResolverModule _participantResolver;
  late final RecipeShareRequestModule _recipeShareRequestModule;

  // State
  List<SharedRecipe> _sharedRecipes = [];
  List<SharedMenu> _sharedMenus = [];
  bool _isLoading = false;
  String? _error;

  SocialRecipeService({
    required UserService userService,
    required UnifiedRecipeService recipeService,
    required PermissionService permissionService,
    required FirebaseSharedRecipeRepository sharedRecipeRepository,
    required FirebaseSharedMenuRepository sharedMenuRepository,
    required FirebaseSocialRequestRepository socialRequestRepository,
  }) : _userService = userService,
       _recipeService = recipeService,
       _permissionService = permissionService,
       _sharedRecipeRepository = sharedRecipeRepository,
       _sharedMenuRepository = sharedMenuRepository,
       _socialRequestRepository = socialRequestRepository {
    _participantResolver = SocialParticipantResolverModule(
      userService: _userService,
      getSharedRecipes: () => _sharedRecipes,
      getSharedMenus: () => _sharedMenus,
      sharedRecipeRepository: _sharedRecipeRepository,
      sharedMenuRepository: _sharedMenuRepository,
      getShoppingService: () => _shoppingService,
    );
    _recipeShareRequestModule = RecipeShareRequestModule(
      socialRequestRepository: _socialRequestRepository,
      permissionService: _permissionService,
      userService: _userService,
    );
  }

  // Getters
  List<SharedRecipe> get sharedRecipes => List.unmodifiable(_sharedRecipes);
  List<SharedMenu> get sharedMenus => List.unmodifiable(_sharedMenus);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  // For compatibility with old code
  List<SharedRecipe> get sharedWithMe => sharedRecipes;

  /// Clears `_error` at the entry-point of every public mutator. UI banners
  /// gated on [hasError] stay stale until the next initialize() otherwise — a
  /// successful retry after a failure should visibly clear the banner.
  /// (BUT-1087)
  void _resetError() {
    _error = null;
  }

  /// Captures the sanitized error message into [_error] and logs the raw
  /// cause. Replaces the previous inconsistency where only dismiss* methods
  /// populated [_error] and every other catch block silently logged.
  /// (BUT-1087)
  void _captureAndLog(String message, Object e) {
    AppLogger.error(message, e);
    _error = sanitizeErrorForUser(e);
  }

  /// Initialize the service and load shared content
  Future<void> initialize() async {
    try {
      _isLoading = true;
      _error = null;

      await _loadSharedContent();
      AppLogger.info('✅ SocialRecipeService initialized');
    } catch (e) {
      _captureAndLog('Failed to initialize SocialRecipeService', e);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _loadSharedContent() async {
    if (!_permissionService.isAuthenticated) return;
    final currentUserId = _permissionService.currentUserId!;

    // Load into locals first; only commit on success. A transient failure
    // (network blip, permission hiccup) must NOT blank the inbox by
    // overwriting last-good data with empty lists. Rethrow so the caller's
    // error handling (initialize/refresh) can populate _error → UI banner.
    final recipes = await _sharedRecipeRepository.getSharedRecipesForUser(
      currentUserId,
    );
    final menus = await _sharedMenuRepository.getSharedMenusForUser(
      currentUserId,
    );
    _sharedRecipes = recipes;
    _sharedMenus = menus;
  }

  /// Reloads shared content, mirroring [initialize]'s loading/error lifecycle
  /// so a failed refresh surfaces via [hasError] instead of silently blanking
  /// the inbox. (BUT-1087)
  Future<void> refresh() async {
    try {
      _isLoading = true;
      _resetError();
      await _loadSharedContent();
    } catch (e) {
      _captureAndLog('Failed to refresh shared content', e);
    } finally {
      _isLoading = false;
    }
  }

  // Get visible shared recipes (already filtered by repository - no dismissed items)
  /// Note (Issue #014): Repository queries already filter out dismissed items using
  /// subcollection-based shouldShowToUser() checks. No additional filtering needed.
  List<SharedRecipe> getVisibleSharedRecipes(String currentUserId) {
    return _sharedRecipes;
  }

  // Get visible shared menus (already filtered by repository - no dismissed items)
  /// Note (Issue #014): Repository queries already filter out dismissed items using
  /// subcollection-based shouldShowToUser() checks. No additional filtering needed.
  List<SharedMenu> getVisibleSharedMenus(String currentUserId) {
    return _sharedMenus;
  }

  // Mark shared recipe as viewed
  /// Note (Issue #014): Repository handles status tracking in subcollections.
  /// Local state update removed - status now managed server-side only.
  Future<bool> markSharedRecipeAsViewed(String recipeId, String userId) async {
    _resetError();
    try {
      await _sharedRecipeRepository.markAsViewed(recipeId, userId);
      // Status tracking now handled by repository subcollections (Issue #014)
      // Optionally refresh to get updated viewCount, or rely on next load
      return true;
    } catch (e) {
      _captureAndLog('Failed to mark recipe as viewed', e);
      return false;
    }
  }

  // Mark shared menu as viewed
  /// Note (Issue #014): Repository handles status tracking in subcollections.
  /// Local state update removed - status now managed server-side only.
  Future<bool> markSharedMenuAsViewed(String menuId, String userId) async {
    _resetError();
    try {
      await _sharedMenuRepository.markAsViewed(menuId, userId);
      // Status tracking now handled by repository subcollections (Issue #014)
      // Optionally refresh to get updated viewCount, or rely on next load
      return true;
    } catch (e) {
      _captureAndLog('Failed to mark menu as viewed', e);
      return false;
    }
  }

  /// Import shared recipe into user's personal collection
  Future<bool> importSharedRecipe(String recipeId) async {
    _resetError();
    try {
      final sharedRecipe = _sharedRecipes
          .where((r) => r.id == recipeId)
          .firstOrNull;
      if (sharedRecipe == null) return false;

      // Use contentSnapshot which handles V1 (full snapshot) or V2 (minimal from metadata)
      final recipeToImport = sharedRecipe.contentSnapshot;

      // Create a personal recipe from the shared one
      final success = await _recipeService.personal.createRecipe(
        title: recipeToImport.title,
        description: recipeToImport.description,
        ingredients: recipeToImport.ingredients,
        instructions: recipeToImport.instructions,
        imageUrls: recipeToImport.imageUrls,
        mealType: recipeToImport.mealType,
        portions: recipeToImport.portions,
        timeMinutes: recipeToImport.timeMinutes,
        personalTagIds:
            [], // Clear sender's personalTagIds — UUIDs are meaningless in recipient's account
        rating: recipeToImport.rating,
      );

      if (success != null) {
        // Mark as imported
        if (_permissionService.isAuthenticated) {
          await _sharedRecipeRepository.markAsImportedOrJoined(
            recipeId,
            _permissionService.currentUserId!,
          );
        } else {
          // BUT-1086: user signed out during the createRecipe await. The
          // recipe IS saved but the share couldn't be flagged as imported.
          // Surface this so UI can show a refresh prompt; the function
          // still returns true because the primary write succeeded.
          AppLogger.warning(
            '⚠️ Sign-out detected mid-import — share status not updated for $recipeId',
          );
          _error = AppLocale.current.errorImportPartialReSignIn;
        }
        AppLogger.success('Recipe imported successfully');
        return true;
      }
      return false;
    } catch (e) {
      _captureAndLog('Failed to import shared recipe', e);
      return false;
    }
  }

  // Import shared menu
  Future<bool> importSharedMenu(String menuId) async {
    _resetError();
    try {
      final sharedMenu = _sharedMenus.where((m) => m.id == menuId).firstOrNull;
      if (sharedMenu == null) return false;

      int successCount = 0;
      int totalCount = 0;
      for (final entry in sharedMenu.menuSnapshot.entries) {
        for (final recipe in entry.value) {
          totalCount++;
          try {
            final success = await _recipeService.personal.createRecipe(
              title: recipe.title,
              description: recipe.description,
              ingredients: recipe.ingredients,
              instructions: recipe.instructions,
              imageUrls: recipe.imageUrls,
              mealType: recipe.mealType,
              portions: recipe.portions,
              timeMinutes: recipe.timeMinutes,
              personalTagIds: recipe.personalTagIds,
              rating: recipe.rating,
            );
            if (success != null) successCount++;
          } catch (e) {
            AppLogger.error('Failed to import recipe "${recipe.id}"', e);
          }
        }
      }

      if (successCount == 0) return false;

      if (_permissionService.isAuthenticated) {
        await _sharedMenuRepository.markAsImportedOrJoined(
          menuId,
          _permissionService.currentUserId!,
        );
      } else {
        // BUT-1086: user signed out during the createRecipe awaits. At least
        // one recipe IS saved but the share couldn't be flagged as imported.
        // Mirror importSharedRecipe: surface a re-sign-in prompt so the user
        // knows the menu was only partially imported. Still returns true
        // because the primary writes succeeded.
        AppLogger.warning(
          '⚠️ Sign-out detected mid-import — share status not updated for menu $menuId',
        );
        _error = AppLocale.current.errorImportPartialReSignIn;
      }
      AppLogger.success('Menu imported: $successCount/$totalCount recipes');
      return true;
    } catch (e) {
      _captureAndLog('Failed to import shared menu', e);
      return false;
    }
  }

  // Dismiss shared recipe
  Future<bool> dismissSharedRecipe(String recipeId) async {
    _resetError();
    try {
      if (!_permissionService.isAuthenticated) {
        _error = AppLocale.current.errorAuthentication;
        return false;
      }
      await _sharedRecipeRepository.markAsDismissed(
        recipeId,
        _permissionService.currentUserId!,
      );
      AppLogger.info('Recipe dismissed');
      return true;
    } catch (e) {
      _captureAndLog('Failed to dismiss shared recipe', e);
      return false;
    }
  }

  // Dismiss shared menu
  Future<bool> dismissSharedMenu(String menuId) async {
    _resetError();
    try {
      if (!_permissionService.isAuthenticated) {
        _error = AppLocale.current.errorAuthentication;
        return false;
      }
      await _sharedMenuRepository.markAsDismissed(
        menuId,
        _permissionService.currentUserId!,
      );
      AppLogger.info('Menu dismissed');
      return true;
    } catch (e) {
      _captureAndLog('Failed to dismiss shared menu', e);
      return false;
    }
  }

  // Undismiss shared recipe
  Future<bool> undismissSharedRecipe(String recipeId) async {
    _resetError();
    try {
      if (!_permissionService.isAuthenticated) {
        AppLogger.error('User not authenticated');
        return false;
      }
      await _sharedRecipeRepository.undismiss(
        recipeId,
        _permissionService.currentUserId!,
      );
      AppLogger.info('Recipe restored');
      return true;
    } catch (e) {
      _captureAndLog('Failed to restore shared recipe', e);
      return false;
    }
  }

  // Undismiss shared menu
  Future<bool> undismissSharedMenu(String menuId) async {
    _resetError();
    try {
      if (!_permissionService.isAuthenticated) {
        AppLogger.error('User not authenticated');
        return false;
      }
      await _sharedMenuRepository.undismiss(
        menuId,
        _permissionService.currentUserId!,
      );
      AppLogger.info('Menu restored');
      return true;
    } catch (e) {
      _captureAndLog('Failed to restore shared menu', e);
      return false;
    }
  }

  // For compatibility with old test code
  void createTestSharedRecipe(String recipeId) {
    // This is a no-op for the real implementation
    AppLogger.info(
      'createTestSharedRecipe called - ignoring in real implementation',
    );
  }

  /// Compatibility getters for legacy code
  List<SharedRecipe> get recipesSharedWithMe => sharedRecipes;
  List<SharedMenu> get menusSharedWithMe => sharedMenus;

  /// Check if recipe is shared by user
  Future<bool> isRecipeSharedByUser(String recipeId, String userId) async {
    try {
      final recipe = _sharedRecipes.where((r) => r.id == recipeId).firstOrNull;
      return recipe != null && recipe.sharedByUserId == userId;
    } catch (e) {
      AppLogger.error('Failed to check if recipe is shared', e);
      return false;
    }
  }

  /// Check if menu is shared by user
  Future<bool> isMenuSharedByUser(String menuId, String userId) async {
    try {
      final menu = _sharedMenus.where((m) => m.id == menuId).firstOrNull;
      return menu != null && menu.sharedByUserId == userId;
    } catch (e) {
      AppLogger.error('Failed to check if menu is shared', e);
      return false;
    }
  }

  /// Check if shopping list is shared by user
  Future<bool> isShoppingListSharedByUser(String listId, String userId) async {
    try {
      final shoppingService = _shoppingService;
      if (shoppingService == null) {
        AppLogger.warning(
          'Shopping service not available - cannot check sharing status',
        );
        return false;
      }

      final collaborativeLists = shoppingService.collaborative.getAllLists();
      final list = collaborativeLists.where((l) => l.id == listId).firstOrNull;

      if (list == null) {
        AppLogger.debug('Shopping list $listId not found');
        return false;
      }

      // List is shared if:
      // 1. The user is the owner AND
      // 2. The list has at least one member (shared with someone)
      final isOwner = list.ownerId == userId;
      final hasMembers = list.memberPermissions.isNotEmpty;

      return isOwner && hasMembers;
    } catch (e) {
      AppLogger.error('Failed to check if shopping list is shared', e);
      return false;
    }
  }

  Future<List<UserProfile>> getRecipeParticipants(String recipeId) =>
      _participantResolver.getRecipeParticipants(recipeId);

  Future<List<UserProfile>> getMenuParticipants(String menuId) =>
      _participantResolver.getMenuParticipants(menuId);

  Future<List<UserProfile>> getShoppingListParticipants(String listId) =>
      _participantResolver.getShoppingListParticipants(listId);

  Future<bool> requestRecipeShare({
    required String ownerId,
    required String recipeId,
    required String recipeTitle,
  }) => _recipeShareRequestModule.requestRecipeShare(
    ownerId: ownerId,
    recipeId: recipeId,
    recipeTitle: recipeTitle,
  );

  Future<bool> acceptRecipeShareRequest(SocialRequest request) =>
      _recipeShareRequestModule.acceptRecipeShareRequest(request);

  void dispose() {
    disposeStreamResources();
  }
}
