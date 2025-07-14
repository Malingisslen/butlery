// lib/services/social_recipe_service.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../repositories/interfaces/social_recipe_repository.dart';
import '../services/user_service.dart';
import '../services/recipe_service.dart';

import '../models/recipe.dart';
import '../models/recipe_comment.dart';
import '../models/shared_recipe.dart';
import '../models/shared_menu.dart';
import '../models/user_profile.dart';

import '../core/utils/logger.dart';
import '../core/error/error_handler.dart';

class SocialRecipeService extends ChangeNotifier {
  final SocialRecipeRepository _repository;
  final UserService _userService;
  final RecipeService _recipeService;

  // State
  List<SharedRecipe> _sharedWithMe = [];
  List<SharedMenu> _menusSharedWithMe = [];
  final Map<String, List<RecipeComment>> _recipeComments = {};
  bool _isLoading = false;
  bool _hasLoadedContent = false;
  String? _error;

  // Constants
  static const int _commentsLimit = 50;
  static const int _sharedRecipesLimit = 20;

  SocialRecipeService({
    required SocialRecipeRepository repository,
    required UserService userService,
    required RecipeService recipeService,
  })  : _repository = repository,
        _userService = userService,
        _recipeService = recipeService;

  // ===== GETTERS =====

  List<SharedRecipe> get sharedWithMe => List.unmodifiable(_sharedWithMe);
  List<SharedMenu> get menusSharedWithMe =>
      List.unmodifiable(_menusSharedWithMe);

  /// ✅ FIXAT: Getters för UserAvatar notification badge
  List<SharedRecipe> get recipesSharedWithMe {
    final currentUserId = _repository.currentUser?.uid;
    if (currentUserId == null) return [];
    return _sharedWithMe;
  }

  bool get isLoading => _isLoading;
  bool get hasLoadedContent => _hasLoadedContent;
  String? get error => _error;
  bool get hasError => _error != null;
  String? get currentUserId => _repository.currentUser?.uid;

  /// 🆕 Get visible (non-dismissed) shared recipes för användaren
  List<SharedRecipe> getVisibleSharedRecipes(String userId) {
    return _sharedWithMe
        .where((recipe) => recipe.shouldBeShownTo(userId))
        .toList();
  }

  /// 🆕 Public method för att markera recept som läst (används av ViewModel)
  Future<void> markSharedRecipeAsViewed(String recipeId, String userId) async {
    try {
      await _sharedRecipesRef.doc(recipeId).update({
        'viewCount': FieldValue.increment(1),
        'viewedByUserIds': FieldValue.arrayUnion([userId]),
        'lastViewedAt':
            FieldValue.serverTimestamp(), // Lägg till timestamp utanför array
      });

      // Update local cache
      final index = _sharedWithMe.indexWhere((recipe) => recipe.id == recipeId);
      if (index >= 0) {
        _sharedWithMe[index] = _sharedWithMe[index].markViewedBy(userId);
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Failed to mark shared recipe as viewed', e);
      rethrow;
    }
  }

  /// 🆕 Public method för att markera meny som läst (används av ViewModel)
  Future<void> markSharedMenuAsViewed(String menuId, String userId) async {
    try {
      await _sharedMenusRef.doc(menuId).update({
        'viewCount': FieldValue.increment(1),
        'viewedByUserIds': FieldValue.arrayUnion([userId]),
        'lastViewedAt':
            FieldValue.serverTimestamp(), // Lägg till timestamp utanför array
      });

      // Update local cache
      final index = _menusSharedWithMe.indexWhere((menu) => menu.id == menuId);
      if (index >= 0) {
        _menusSharedWithMe[index] =
            _menusSharedWithMe[index].markViewedBy(userId);
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Failed to mark shared menu as viewed', e);
      rethrow;
    }
  }

  /// Firestore references
  CollectionReference get _sharedRecipesRef =>
      _repository.sharedRecipesRef;

  CollectionReference get _sharedMenusRef =>
      _repository.sharedMenusRef;

  CollectionReference get _recipeCommentsRef =>
      _repository.recipeCommentsRef;

  /// Initialize service
  Future<void> initialize() async {
    AppLogger.info('🔄 Initialiserar SocialRecipeService...');

    _repository.authStateChanges().listen((user) {
      if (user != null) {
        // 🚀 PERFORMANCE FIX: Delayed loading to prevent startup frame skipping
        Future.delayed(const Duration(milliseconds: 1000), () {
          _loadSharedContent();
        });
      } else {
        _clearAll();
      }
    });

    // Note: No immediate loading here - auth listener will handle current user
    AppLogger.info('🚀 SocialRecipeService initialized with delayed content loading via auth listener');
  }

  // ==================== 🆕 SHOPPING SHARE METOD ====================

  /// 🆕 Generic method för att dela content med vänner
  /// Används av ShoppingShareViewModel för att dela inköpslistor
  Future<bool> shareContent({
    required String friendId,
    required String contentType,
    required Map<String, dynamic> contentData,
  }) async {
    final currentUser = _userService.currentUserProfile;
    if (currentUser == null) {
      _setError('Du måste vara inloggad för att dela innehåll');
      return false;
    }

    try {
      debugPrint('🔄 Delar $contentType med vän: $friendId');

      // Skapa delat innehåll med metadata
      final sharedContentId = DateTime.now().millisecondsSinceEpoch.toString();
      final sharedContent = {
        'id': sharedContentId,
        'type': contentType,
        'sharedByUserId': currentUser.uid,
        'sharedByDisplayName': currentUser.displayName,
        'sharedToUserId': friendId,
        'contentData': contentData,
        'sharedAt': FieldValue.serverTimestamp(),
        'viewedAt': null,
        'viewCount': 0,
        'dismissed': false,
      };

      // Spara i Firestore under shared_content collection
      await _repository.sharedContentRef
          .doc(sharedContentId)
          .set(sharedContent);

      debugPrint('✅ Innehåll delat framgångsrikt med $friendId');
      return true;
    } catch (e) {
      debugPrint('❌ Misslyckades med att dela innehåll: $e');
      _setError('Kunde inte dela innehåll: $e');
      return false;
    }
  }

  // ==================== BEFINTLIGA METODER (FORTSÄTTER SOM INNAN) ====================

  /// Share recipe to friends
  Future<bool> shareRecipeToFriends({
    required Recipe recipe,
    required List<String> friendUserIds,
    String? message,
    bool allowCollaboration = false, // ✅ NY: Kollaborationsinställning
  }) async {
    final currentUser = _userService.currentUserProfile;
    if (currentUser == null) {
      _setError('Du måste vara inloggad för att dela recept');
      return false;
    }

    if (friendUserIds.isEmpty) {
      _setError('Välj minst en vän att dela med');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      // Create shared recipe med kollaborationsinställning
      final sharedRecipe = SharedRecipe.create(
        originalRecipeId: recipe.id,
        sharedByUserId: currentUser.uid,
        sharedByDisplayName: currentUser.displayName,
        sharedToUserIds: friendUserIds,
        shareMessage: message,
        scope: friendUserIds.length == 1
            ? ShareScope.individual
            : ShareScope.multiple,
        recipeSnapshot: recipe,
        allowCollaboration:
            allowCollaboration, // ✅ UPPDATERAT: Skicka collaboration flag
      );

      // Save to Firestore
      await _sharedRecipesRef
          .doc(sharedRecipe.id)
          .set(sharedRecipe.toFirestore());

      // ✅ FÖRBÄTTRAD: Mer detaljerad loggning
      final collaborationType =
          allowCollaboration ? 'kollaborativt' : 'läsbart';
      AppLogger.success(
        '✅ Recept "${recipe.title}" delat som $collaborationType med ${friendUserIds.length} vänner',
      );

      // Send notifications to recipients
      await _sendRecipeShareNotifications(sharedRecipe);

      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte dela recept', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Share menu to friends
  Future<bool> shareMenuToFriends({
    required Map<String, List<Recipe>> menu,
    required List<String> friendUserIds,
    String? message,
    String? customTitle,
    bool allowCollaboration =
        false, // ✅ NY: Kollaborationsinställning för menyer
  }) async {
    final currentUser = _userService.currentUserProfile;
    if (currentUser == null) {
      _setError('Du måste vara inloggad för att dela menyer');
      return false;
    }

    if (friendUserIds.isEmpty) {
      _setError('Välj minst en vän att dela med');
      return false;
    }

    if (menu.isEmpty) {
      _setError('Menyn är tom');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      final menuTitle = customTitle ?? '${currentUser.displayName}s veckomeny';

      // Create shared menu
      final sharedMenu = SharedMenu.create(
        sharedByUserId: currentUser.uid,
        sharedByDisplayName: currentUser.displayName,
        sharedToUserIds: friendUserIds,
        shareMessage: message,
        menuTitle: menuTitle,
        menuSnapshot: menu,
        allowCollaboration:
            allowCollaboration, // ✅ UPPDATERAT: Skicka collaboration flag
      );

      // Save to Firestore
      await _sharedMenusRef.doc(sharedMenu.id).set(sharedMenu.toFirestore());

      // ✅ FÖRBÄTTRAD: Mer detaljerad loggning
      final collaborationType = allowCollaboration ? 'kollaborativ' : 'läsbar';
      AppLogger.success(
        '✅ Meny "$menuTitle" delad som $collaborationType med ${friendUserIds.length} vänner',
      );

      // Send notifications to recipients
      await _sendMenuShareNotifications(sharedMenu);

      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte dela meny', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 🆕 Dismiss shared recipe from user's list (hide utan att påverka andra)
  Future<bool> dismissSharedRecipe(String sharedRecipeId) async {
    final userId = currentUserId;
    if (userId == null) {
      _setError('Du måste vara inloggad för att dölja recept');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      // Update Firestore med dismiss tracking
      await _sharedRecipesRef.doc(sharedRecipeId).update({
        'dismissedByUserIds': FieldValue.arrayUnion([userId]),
      });

      // Update local cache
      final index =
          _sharedWithMe.indexWhere((recipe) => recipe.id == sharedRecipeId);
      if (index >= 0) {
        _sharedWithMe[index] = _sharedWithMe[index].markDismissedBy(userId);
        notifyListeners();
      }

      AppLogger.success('✅ Recept dolt från din lista');
      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte dölja recept', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 🆕 Dismiss shared menu from user's list (hide utan att påverka andra)
  Future<bool> dismissSharedMenu(String sharedMenuId) async {
    final userId = currentUserId;
    if (userId == null) {
      _setError('Du måste vara inloggad för att dölja menyer');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      // Update Firestore med dismiss tracking
      await _sharedMenusRef.doc(sharedMenuId).update({
        'dismissedByUserIds': FieldValue.arrayUnion([userId]),
      });

      // Update local cache
      final index =
          _menusSharedWithMe.indexWhere((menu) => menu.id == sharedMenuId);
      if (index >= 0) {
        _menusSharedWithMe[index] =
            _menusSharedWithMe[index].markDismissedBy(userId);
        notifyListeners();
      }

      AppLogger.success('✅ Meny dold från din lista');
      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte dölja meny', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 🆕 Un-dismiss shared recipe (återställ till användarens lista)
  Future<bool> undismissSharedRecipe(String sharedRecipeId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      await _sharedRecipesRef.doc(sharedRecipeId).update({
        'dismissedByUserIds': FieldValue.arrayRemove([userId]),
      });

      // Update local cache
      final index =
          _sharedWithMe.indexWhere((recipe) => recipe.id == sharedRecipeId);
      if (index >= 0) {
        _sharedWithMe[index] = _sharedWithMe[index].undismissBy(userId);
        notifyListeners();
      }

      return true;
    } catch (e) {
      AppLogger.error('Kunde inte återställa recept', e);
      return false;
    }
  }

  /// 🆕 Un-dismiss shared menu (återställ till användarens lista)
  Future<bool> undismissSharedMenu(String sharedMenuId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      await _sharedMenusRef.doc(sharedMenuId).update({
        'dismissedByUserIds': FieldValue.arrayRemove([userId]),
      });

      // Update local cache
      final index =
          _menusSharedWithMe.indexWhere((menu) => menu.id == sharedMenuId);
      if (index >= 0) {
        _menusSharedWithMe[index] =
            _menusSharedWithMe[index].undismissBy(userId);
        notifyListeners();
      }

      return true;
    } catch (e) {
      AppLogger.error('Kunde inte återställa meny', e);
      return false;
    }
  }

  /// Import shared recipe to user's collection
  Future<bool> importSharedRecipe(String sharedRecipeId) async {
    final userId = currentUserId;
    if (userId == null) {
      _setError('Du måste vara inloggad för att importera recept');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      // Get shared recipe
      final sharedDoc = await _sharedRecipesRef.doc(sharedRecipeId).get();
      if (!sharedDoc.exists) {
        _setError('Delat recept hittades inte');
        return false;
      }

      final sharedRecipe = SharedRecipe.fromFirestore(sharedDoc);

      // Check permissions
      if (!sharedRecipe.canBeViewedBy(userId)) {
        _setError('Du har inte behörighet att se detta recept');
        return false;
      }

      if (!sharedRecipe.allowImport) {
        _setError('Detta recept kan inte importeras');
        return false;
      }

      // Create imported recipe with attribution
      final importedRecipe = sharedRecipe.createImportRecipe(
        newOwnerId: userId,
      );

      // Add to user's collection
      final result = await _recipeService.addRecipe(importedRecipe);

      if (result.isSuccess) {
        // Mark as imported
        await _markSharedRecipeAsImported(sharedRecipeId, userId);

        AppLogger.success('✅ Recept "${importedRecipe.title}" importerat');
        return true;
      } else {
        _setError(result.message);
        return false;
      }
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte importera recept', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Import shared menu to user's collection (alla recept från menyn)
  Future<bool> importSharedMenu(String sharedMenuId) async {
    final userId = currentUserId;
    if (userId == null) {
      _setError('Du måste vara inloggad för att importera menyer');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      AppLogger.info('🔄 Importerar delad meny: $sharedMenuId');

      // Get shared menu
      final sharedDoc = await _sharedMenusRef.doc(sharedMenuId).get();
      if (!sharedDoc.exists) {
        _setError('Delad meny hittades inte');
        return false;
      }

      final sharedMenu = SharedMenu.fromFirestore(sharedDoc);

      // Check permissions
      if (!sharedMenu.canBeViewedBy(userId)) {
        _setError('Du har inte behörighet att se denna meny');
        return false;
      }

      if (!sharedMenu.allowImport) {
        _setError('Denna meny kan inte importeras');
        return false;
      }

      // Import alla recept från menyn
      int successCount = 0;
      int totalRecipes = sharedMenu.totalRecipeCount;
      final List<String> failedRecipes = [];

      AppLogger.info(
          '📦 Importerar $totalRecipes recept från meny "${sharedMenu.menuTitle}"');

      // Gå igenom alla dagar och recept
      for (final dayEntry in sharedMenu.menuSnapshot.entries) {
        final dayName = dayEntry.key;
        final recipes = dayEntry.value;

        AppLogger.info('📅 Importerar ${recipes.length} recept från $dayName');

        for (final recipe in recipes) {
          try {
            // Skapa importerat recept med attribution
            final importedRecipe = _createImportedRecipeFromMenu(
              originalRecipe: recipe,
              menuTitle: sharedMenu.menuTitle,
              sharedByName: sharedMenu.sharedByDisplayName,
              dayName: dayName,
              newOwnerId: userId,
            );

            // Lägg till i användarens samling
            final result = await _recipeService.addRecipe(importedRecipe);

            if (result.isSuccess) {
              successCount++;
              AppLogger.info('✅ Importerat: ${recipe.title} från $dayName');
            } else {
              failedRecipes.add('${recipe.title} ($dayName)');
              AppLogger.warning(
                  '⚠️ Misslyckades: ${recipe.title} - ${result.message}');
            }
          } catch (e) {
            failedRecipes.add('${recipe.title} ($dayName)');
            AppLogger.error('❌ Fel vid import av ${recipe.title}', e);
          }
        }
      }

      // Markera menyn som importerad
      if (successCount > 0) {
        await _markSharedMenuAsImported(sharedMenuId, userId);
      }

      // Rapportera resultat
      if (successCount == totalRecipes) {
        AppLogger.success(
            '🎉 Alla $totalRecipes recept från "${sharedMenu.menuTitle}" importerade!');
      } else if (successCount > 0) {
        AppLogger.success(
            '✅ $successCount av $totalRecipes recept importerade från "${sharedMenu.menuTitle}"');
        if (failedRecipes.isNotEmpty) {
          AppLogger.warning('⚠️ Misslyckades med: ${failedRecipes.join(", ")}');
        }
      } else {
        _setError('Kunde inte importera några recept från menyn');
        return false;
      }

      return successCount > 0;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte importera meny', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// ✅ NY: Hämta recept-ID:n som redan delats med en specifik vän
  Future<Set<String>> getRecipesSharedWithFriend(String friendUserId) async {
    final currentUserId = _authRepository.currentUserId;
    if (currentUserId == null) return {};

    try {
      AppLogger.info(
          '🔍 Kollar vilka recept som redan delats med vän: $friendUserId');

      // Sök efter recept som vi redan delat med denna vän
      final query = await _repository.sharedRecipesRef
          .where('sharedByUserId', isEqualTo: currentUserId)
          .where('sharedToUserIds', arrayContains: friendUserId)
          .get();

      // Returnera set med originalRecipeId för snabb lookup
      final sharedRecipeIds = query.docs
          .map((doc) => SharedRecipe.fromFirestore(doc).originalRecipeId)
          .toSet();

      AppLogger.info(
          '✅ Hittade ${sharedRecipeIds.length} redan delade recept med $friendUserId');
      return sharedRecipeIds;
    } catch (e) {
      AppLogger.error(
          'Kunde inte hämta delade recept för vän $friendUserId', e);
      return {};
    }
  }

  /// ✅ NY: Kontrollera om ett specifikt recept redan delats med en vän
  Future<bool> isRecipeAlreadySharedWith(
      String recipeId, String friendUserId) async {
    final sharedRecipeIds = await getRecipesSharedWithFriend(friendUserId);
    return sharedRecipeIds.contains(recipeId);
  }

  /// ✅ NY: Kontrollera om ett specifikt recept är delat av användaren
  /// Används av CollaborativeStatusViewModel för att visa kollaborativ status
  Future<bool> isRecipeSharedByUser(String recipeId, String userId) async {
    try {
      AppLogger.info(
          '🔍 Kollar om recept $recipeId är delat av användare $userId');

      // Sök efter recept som användaren har delat
      final query = await _sharedRecipesRef
          .where('originalRecipeId', isEqualTo: recipeId)
          .where('sharedByUserId', isEqualTo: userId)
          .limit(1)
          .get();

      final isShared = query.docs.isNotEmpty;

      if (isShared) {
        AppLogger.info('✅ Recept $recipeId är delat av användaren');
      } else {
        AppLogger.info('ℹ️ Recept $recipeId är INTE delat av användaren');
      }

      return isShared;
    } catch (e) {
      AppLogger.error(
          'Kunde inte kolla delningsstatus för recept $recipeId', e);
      return false; // Safe fallback
    }
  }

  /// ✅ NY: Kontrollera om en specifik meny är delad av användaren
  /// Används av CollaborativeStatusViewModel för meny collaborative detection
  Future<bool> isMenuSharedByUser(String menuId, String userId) async {
    try {
      AppLogger.info('🔍 Kollar om meny $menuId är delad av användare $userId');

      // Sök efter meny som användaren har delat
      final query = await _sharedMenusRef
          .where('menuId', isEqualTo: menuId)
          .where('sharedByUserId', isEqualTo: userId)
          .limit(1)
          .get();

      final isShared = query.docs.isNotEmpty;

      if (isShared) {
        AppLogger.info('✅ Meny $menuId är delad av användaren');
      } else {
        AppLogger.info('ℹ️ Meny $menuId är INTE delad av användaren');
      }

      return isShared;
    } catch (e) {
      AppLogger.error('Kunde inte kolla delningsstatus för meny $menuId', e);
      return false; // Safe fallback
    }
  }

  /// Helper: Skapa importerat recept med meny-attribution
  Recipe _createImportedRecipeFromMenu({
    required Recipe originalRecipe,
    required String menuTitle,
    required String sharedByName,
    required String dayName,
    required String newOwnerId,
  }) {
    final now = DateTime.now();

    // Lägg till meny-kontext i beskrivningen
    final menuAttribution = 'Från "$menuTitle" av $sharedByName ($dayName)';
    final description = originalRecipe.description.isEmpty
        ? menuAttribution
        : '${originalRecipe.description}\n\n--- $menuAttribution ---';

    return Recipe(
      id: '', // Ny ID kommer skapas vid sparning
      title: originalRecipe.title,
      description: description,
      ingredients: List.from(originalRecipe.ingredients),
      instructions: List.from(originalRecipe.instructions),
      imageUrls: List.from(originalRecipe.imageUrls),
      mealType: originalRecipe.mealType,
      portions: originalRecipe.portions,
      timeMinutes: originalRecipe.timeMinutes,
      rating: null, // Nollställ rating för importerat recept
      tags: [...?originalRecipe.tags, 'från-meny', 'importerat'],
      sourceUrl: 'Delad meny: $menuTitle',
      createdAt: now,
      updatedAt: now,
      lastCookedAt: null, // Nollställ cooking history
    );
  }

  /// Send recipe share notifications
  Future<void> _sendRecipeShareNotifications(SharedRecipe sharedRecipe) async {
    try {
      AppLogger.info(
          '📢 Skickar notifieringar för recept-delning till ${sharedRecipe.sharedToUserIds.length} mottagare');

      // För framtiden: Implementera push notifications här
      // Detta kan använda Firebase Cloud Messaging (FCM)
      // För nu loggar vi bara att notifikationer skulle skickas

      for (final recipientId in sharedRecipe.sharedToUserIds) {
        AppLogger.info(
            '📱 Notifikation: ${sharedRecipe.sharedByDisplayName} delade "${sharedRecipe.recipeSnapshot.title}" med $recipientId');
      }

      AppLogger.success('✅ Notifieringar skickade för recept-delning');
    } catch (e) {
      AppLogger.warning(
          '⚠️ Kunde inte skicka notifieringar för recept-delning: $e');
      // Misslyckas tyst - delningen fungerar fortfarande
    }
  }

  /// Send menu share notifications
  Future<void> _sendMenuShareNotifications(SharedMenu sharedMenu) async {
    try {
      AppLogger.info(
          '📢 Skickar notifieringar för meny-delning till ${sharedMenu.sharedToUserIds.length} mottagare');

      // För framtiden: Implementera push notifications här
      // Detta kan använda Firebase Cloud Messaging (FCM)

      for (final recipientId in sharedMenu.sharedToUserIds) {
        AppLogger.info(
            '📱 Notifikation: ${sharedMenu.sharedByDisplayName} delade "${sharedMenu.menuTitle}" med $recipientId');
      }

      AppLogger.success('✅ Notifieringar skickade för meny-delning');
    } catch (e) {
      AppLogger.warning(
          '⚠️ Kunde inte skicka notifieringar för meny-delning: $e');
      // Misslyckas tyst - delningen fungerar fortfarande
    }
  }

  /// Get comments for a recipe
  Future<List<RecipeComment>> getRecipeComments(String recipeId) async {
    // Check cache first
    if (_recipeComments.containsKey(recipeId)) {
      return _recipeComments[recipeId]!;
    }

    try {
      final query = await _recipeCommentsRef
          .where('recipeId', isEqualTo: recipeId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(_commentsLimit)
          .get();

      final comments =
          query.docs.map((doc) => RecipeComment.fromFirestore(doc)).toList();

      _recipeComments[recipeId] = comments;
      return comments;
    } catch (e) {
      AppLogger.error('Kunde inte hämta kommentarer för recept $recipeId', e);
      return [];
    }
  }

  /// Add comment to recipe
  Future<bool> addComment({
    required String recipeId,
    required String text,
    String? parentCommentId,
  }) async {
    final currentUser = _userService.currentUserProfile;
    if (currentUser == null) {
      _setError('Du måste vara inloggad för att kommentera');
      return false;
    }

    if (text.trim().isEmpty) {
      _setError('Kommentaren kan inte vara tom');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      final comment = RecipeComment.create(
        recipeId: recipeId,
        authorId: currentUser.uid,
        authorDisplayName: currentUser.displayName,
        authorAvatarUrl: currentUser.avatarUrl,
        text: text.trim(),
        parentCommentId: parentCommentId,
      );

      // Save comment
      await _recipeCommentsRef.doc(comment.id).set(comment.toFirestore());

      // Update reply count if this is a reply
      if (parentCommentId != null) {
        await _recipeCommentsRef.doc(parentCommentId).update({
          'replyCount': FieldValue.increment(1),
        });
      }

      // Add to cache
      if (_recipeComments.containsKey(recipeId)) {
        _recipeComments[recipeId]!.insert(0, comment);
        notifyListeners();
      }

      AppLogger.success('✅ Kommentar tillagd');
      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte lägga till kommentar', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Edit comment
  Future<bool> editComment(String commentId, String newText) async {
    final userId = currentUserId;
    if (userId == null) {
      _setError('Du måste vara inloggad för att redigera kommentarer');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      // Get current comment
      final commentDoc = await _recipeCommentsRef.doc(commentId).get();
      if (!commentDoc.exists) {
        _setError('Kommentaren hittades inte');
        return false;
      }

      final comment = RecipeComment.fromFirestore(commentDoc);

      // Check permissions
      if (!comment.canBeEditedBy(userId)) {
        _setError('Du kan inte redigera denna kommentar');
        return false;
      }

      // Update comment
      final editedComment = comment.edit(newText.trim());
      await _recipeCommentsRef
          .doc(commentId)
          .update(editedComment.toFirestore());

      // Update cache
      final recipeComments = _recipeComments[comment.recipeId];
      if (recipeComments != null) {
        final index = recipeComments.indexWhere((c) => c.id == commentId);
        if (index >= 0) {
          recipeComments[index] = editedComment;
          notifyListeners();
        }
      }

      AppLogger.success('✅ Kommentar redigerad');
      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte redigera kommentar', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete comment
  Future<bool> deleteComment(String commentId) async {
    final userId = currentUserId;
    if (userId == null) {
      _setError('Du måste vara inloggad för att ta bort kommentarer');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      // Get current comment
      final commentDoc = await _recipeCommentsRef.doc(commentId).get();
      if (!commentDoc.exists) {
        _setError('Kommentaren hittades inte');
        return false;
      }

      final comment = RecipeComment.fromFirestore(commentDoc);

      // Check permissions
      if (!comment.canBeEditedBy(userId)) {
        _setError('Du kan inte ta bort denna kommentar');
        return false;
      }

      // Soft delete comment
      final deletedComment = comment.delete();
      await _recipeCommentsRef
          .doc(commentId)
          .update(deletedComment.toFirestore());

      // Update cache
      final recipeComments = _recipeComments[comment.recipeId];
      if (recipeComments != null) {
        final index = recipeComments.indexWhere((c) => c.id == commentId);
        if (index >= 0) {
          recipeComments[index] = deletedComment;
          notifyListeners();
        }
      }

      AppLogger.success('✅ Kommentar borttagen');
      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      AppLogger.error('Kunde inte ta bort kommentar', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Toggle like on comment
  Future<bool> toggleCommentLike(String commentId) async {
    final userId = currentUserId;
    if (userId == null) {
      _setError('Du måste vara inloggad för att gilla kommentarer');
      return false;
    }

    try {
      // Get current comment
      final commentDoc = await _recipeCommentsRef.doc(commentId).get();
      if (!commentDoc.exists) {
        _setError('Kommentaren hittades inte');
        return false;
      }

      final comment = RecipeComment.fromFirestore(commentDoc);
      final isLiked = comment.isLikedBy(userId);

      // Toggle like
      final updatedComment =
          isLiked ? comment.removeLike(userId) : comment.addLike(userId);

      await _recipeCommentsRef.doc(commentId).update({
        'likedByUserIds': updatedComment.likedByUserIds,
      });

      // Update cache
      final recipeComments = _recipeComments[comment.recipeId];
      if (recipeComments != null) {
        final index = recipeComments.indexWhere((c) => c.id == commentId);
        if (index >= 0) {
          recipeComments[index] = updatedComment;
          notifyListeners();
        }
      }

      return true;
    } catch (e) {
      AppLogger.error('Kunde inte gilla kommentar', e);
      return false;
    }
  }

  Future<void> _loadSharedContent() async {
    final userId = currentUserId;
    if (userId == null) {
      AppLogger.warning(
          '⚠️ Ingen användare inloggad - hoppar över shared content loading');
      return;
    }

    // 🚀 PERFORMANCE FIX: Prevent concurrent loading
    if (_isLoading) {
      AppLogger.info('⏳ Shared content already loading - skipping duplicate request');
      return;
    }

    _isLoading = true;
    AppLogger.info('🔄 Laddar delat innehåll för användare: $userId');

    try {
      // Load shared recipes with comprehensive error handling
      await _loadSharedRecipes(userId);

      // Load shared menus with comprehensive error handling
      await _loadSharedMenus(userId);

      AppLogger.success(
        '📤 Shared content loading komplett: ${_sharedWithMe.length} recept, ${_menusSharedWithMe.length} menyer',
      );

      _hasLoadedContent = true; // 🚀 Mark content as loaded
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Generellt fel vid laddning av delat innehåll', e);
      // Säkerställ att vi har tomma listor så UI inte kraschar
      _sharedWithMe = [];
      _menusSharedWithMe = [];
      _hasLoadedContent = true; // 🚀 Mark as attempted even on error
      notifyListeners();
    } finally {
      _isLoading = false; // 🚀 Always reset loading state
    }
  }

  /// Load shared recipes med robust error handling
  Future<void> _loadSharedRecipes(String userId) async {
    try {
      AppLogger.info('🔄 Laddar delade recept...');

      final recipesQuery = await _sharedRecipesRef
          .where('sharedToUserIds', arrayContains: userId)
          .orderBy('sharedAt', descending: true)
          .limit(_sharedRecipesLimit)
          .get();

      _sharedWithMe = recipesQuery.docs
          .map((doc) => SharedRecipe.fromFirestore(doc))
          .toList();

      AppLogger.success('✅ Laddade ${_sharedWithMe.length} delade recept');
    } catch (e) {
      AppLogger.error('❌ Kunde inte ladda delade recept', e);

      if (e.toString().contains('requires an index')) {
        AppLogger.warning('🔥 FIRESTORE INDEX SAKNAS för shared_recipes!');
        AppLogger.warning('💡 Gå till Firebase Console → Firestore → Indexes');
        AppLogger.warning('💡 Eller klicka på länken i error-meddelandet ovan');
        AppLogger.warning(
            '💡 Index fält: sharedToUserIds (Array), sharedAt (Descending)');
      }

      // Sätt tom lista så appen inte kraschar
      _sharedWithMe = [];
    }
  }

  /// Load shared menus med robust error handling
  Future<void> _loadSharedMenus(String userId) async {
    try {
      AppLogger.info('🔄 Laddar delade menyer...');

      final menusQuery = await _sharedMenusRef
          .where('sharedToUserIds', arrayContains: userId)
          .orderBy('sharedAt', descending: true)
          .limit(_sharedRecipesLimit)
          .get();

      _menusSharedWithMe =
          menusQuery.docs.map((doc) => SharedMenu.fromFirestore(doc)).toList();

      AppLogger.success('✅ Laddade ${_menusSharedWithMe.length} delade menyer');
    } catch (e) {
      AppLogger.error('❌ Kunde inte ladda delade menyer', e);

      if (e.toString().contains('requires an index')) {
        AppLogger.warning('🔥 FIRESTORE INDEX SAKNAS för shared_menus!');
        AppLogger.warning('💡 Gå till Firebase Console → Firestore → Indexes');
        AppLogger.warning('💡 Eller klicka på länken i error-meddelandet ovan');
        AppLogger.warning(
            '💡 Index fält: sharedToUserIds (Array), sharedAt (Descending)');
      }

      // Sätt tom lista så appen inte kraschar
      _menusSharedWithMe = [];
    }
  }

  Future<void> _markSharedRecipeAsImported(
    String sharedRecipeId,
    String userId,
  ) async {
    try {
      await _sharedRecipesRef.doc(sharedRecipeId).update({
        'importCount': FieldValue.increment(1),
        'importedByUserIds': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      AppLogger.warning('Kunde inte markera som importerat: $e');
    }
  }

  /// Helper: Markera shared menu som importerad
  Future<void> _markSharedMenuAsImported(
      String sharedMenuId, String userId) async {
    try {
      await _sharedMenusRef.doc(sharedMenuId).update({
        'importCount': FieldValue.increment(1),
        'importedByUserIds': FieldValue.arrayUnion([userId]),
      });
      AppLogger.info('📝 Markerat meny som importerad av $userId');
    } catch (e) {
      AppLogger.warning('Kunde inte markera meny som importerad: $e');
    }
  }

  void _clearAll() {
    _sharedWithMe.clear();
    _menusSharedWithMe.clear();
    _recipeComments.clear();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Refresh all data
  Future<void> refresh() async {
    await _loadSharedContent();
  }

  /// 🚀 Force immediate loading for notification badges (bypasses delayed loading)
  Future<void> loadImmediately() async {
    await _loadSharedContent();
  }

  // ===== ENHANCED PARTICIPANT LOADING =====
  // 👇 LÄGG TILL DENNA KOD HÄR 👇

  /// 👥 Hämta alla deltagare för ett kollaborativt recept
  Future<List<UserProfile>> getRecipeParticipants(String recipeId) async {
    try {
      final participants = <UserProfile>[];
      final userIds = <String>{};

      // Samla alla user IDs från shared recipes
      final sharedRecipes = _sharedWithMe
          .where((recipe) => recipe.originalRecipeId == recipeId)
          .toList();

      for (final sharedRecipe in sharedRecipes) {
        userIds.add(sharedRecipe.sharedByUserId);
        userIds.addAll(sharedRecipe.sharedToUserIds);
      }

      // Hämta UserProfile för alla deltagare
      for (final userId in userIds) {
        try {
          final userProfile = await _userService.getUserProfile(userId);
          if (userProfile != null) {
            participants.add(userProfile);
          }
        } catch (e) {
          debugPrint('Could not load participant $userId: $e');
        }
      }

      AppLogger.info(
          '👥 Found ${participants.length} participants for recipe $recipeId');
      return participants;
    } catch (e) {
      AppLogger.error('Error loading recipe participants: $e', e);
      return [];
    }
  }

  /// 👥 Hämta alla deltagare för en kollaborativ meny
  Future<List<UserProfile>> getMenuParticipants(String menuId) async {
    try {
      final participants = <UserProfile>[];
      final userIds = <String>{};

      // Samla alla user IDs från shared menus
      final sharedMenus =
          _menusSharedWithMe.where((menu) => menu.id == menuId).toList();

      for (final sharedMenu in sharedMenus) {
        userIds.add(sharedMenu.sharedByUserId);
        userIds.addAll(sharedMenu.sharedToUserIds);
      }

      // Hämta UserProfile för alla deltagare
      for (final userId in userIds) {
        try {
          final userProfile = await _userService.getUserProfile(userId);
          if (userProfile != null) {
            participants.add(userProfile);
          }
        } catch (e) {
          debugPrint('Could not load participant $userId: $e');
        }
      }

      AppLogger.info(
          '👥 Found ${participants.length} participants for menu $menuId');
      return participants;
    } catch (e) {
      AppLogger.error('Error loading menu participants: $e', e);
      return [];
    }
  }

  /// 👥 Hämta alla deltagare för en kollaborativ inköpslista (framtida)
  Future<List<UserProfile>> getShoppingListParticipants(String listId) async {
    try {
      // Implementeras när collaborative shopping lists är klart
      AppLogger.info(
          'Shopping list participants not yet implemented for $listId');
      return [];
    } catch (e) {
      AppLogger.error('Error loading shopping list participants: $e', e);
      return [];
    }
  }

  /// 🔍 Kontrollera om inköpslista är kollaborativ (framtida)
  Future<bool> isShoppingListSharedByUser(String listId, String userId) async {
    try {
      // Implementeras när collaborative shopping lists är klart
      AppLogger.info('Shopping list sharing not yet implemented for $listId');
      return false;
    } catch (e) {
      AppLogger.error(
          'Error checking shopping list collaborative status: $e', e);
      return false;
    }
  }

  /// 🧪 ENDAST FÖR TESTING: Skapa test SharedRecipe
  void createTestSharedRecipe(String recipeId) {
    final currentUserId = _authRepository.currentUserId;
    if (currentUserId == null) return;

    final testSharedRecipe = SharedRecipe(
      id: 'test-shared-${DateTime.now().millisecondsSinceEpoch}',
      originalRecipeId: recipeId,
      sharedByUserId: currentUserId,
      sharedByDisplayName: 'Test User',
      sharedToUserIds: ['friend1', 'friend2'],
      shareMessage: 'Test delning',
      scope: ShareScope.multiple,
      recipeSnapshot: Recipe(
        id: recipeId,
        title: 'Test Recipe',
        description: 'Test beskrivning',
        ingredients: ['Test ingrediens'],
        instructions: ['Test instruktion'],
        imageUrls: [],
        mealType: 'Middag',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      sharedAt: DateTime.now(),
      viewCount: 0,
      importCount: 0,
      allowImport: true,
      viewedByUserIds: [],
      importedByUserIds: [],
      dismissedByUserIds: [],
    );

    _sharedWithMe.add(testSharedRecipe);
    notifyListeners();

    debugPrint('🧪 Created test shared recipe for $recipeId');
    debugPrint('🧪 Total shared recipes now: ${_sharedWithMe.length}');
  }
}
