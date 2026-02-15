// lib/services/unified/unified_menu_service.dart

import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/repositories/interfaces/menu_collaboration_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/firebase_service_mixin.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';

// Operations modules
import 'package:butlery/services/unified/operations/collaborative_menu_operations.dart';

/// Result of importing a shared menu.
/// Indicates whether the import joined a collaborative session or created a local copy.
class MenuImportResult {
  /// The ID of the imported or joined menu.
  final String menuId;

  /// Whether this is a collaborative realtime menu (true) or a local copy (false).
  final bool isCollaborative;

  const MenuImportResult({
    required this.menuId,
    required this.isCollaborative,
  });
}

/// Comprehensive unified menu service providing coordinated access to personal and collaborative menu functionality.
/// This service implements a sophisticated menu management system using modular architecture with focused components
/// for personal menu operations, collaborative menu planning, and social menu sharing features.
/// It provides a unified API surface that coordinates between specialized modules while maintaining clean separation
/// of concerns for maintainable and scalable menu management across all application features.
/// **Architecture Integration:**
/// - Extends [ChangeNotifier] for reactive UI updates with menu state changes across all modules
/// - Uses [ErrorHandlingMixin] for comprehensive error management and graceful degradation strategies
/// - Implements [FirebaseServiceMixin] for Firebase integration and authentication-aware operations
/// - Coordinates with MenuService for basic menu generation and management operations
/// **Modular Coordination Architecture:**
/// This service coordinates between focused modules with clear responsibilities:
/// - **[MenuService]**: Basic menu generation, natural language processing, and meal planning
/// - **[CollaborativeMenuOperations]**: Real-time collaborative menu planning and social features
/// **Unified API Benefits:**
/// - **Single Entry Point**: Unified interface for all menu operations reducing complexity for ViewModels
/// - **Coordinated Operations**: Seamless integration between personal and collaborative menu features
/// - **Clean Separation**: Each module handles specific concerns without cross-module business logic contamination
/// - **Reactive Updates**: Comprehensive state management with automatic UI updates across all menu operations
/// **What This Service Does NOT Contain:**
/// - Business logic implementation (delegated to specialized modules for focused responsibility)
/// - Direct Firebase operations (handled by modules and repository layers for proper abstraction)
/// - Authentication management (handled by FirebaseAuthRepository and authentication mixins)
/// **Usage Examples:**
/// ```dart
/// final menuService = UnifiedMenuService(firestore, authRepository);
/// await menuService.initialize();
/// // Personal menu operations
/// final menu = await menuService.generateMenuFromPrompt('tre frukoster och två middagar', recipes);
/// // Collaborative menu planning
/// await menuService.collaborative.enableMenuCollaboration(
///   menuId: menuId,
///   collaboratorIds: ['user1', 'user2'],
/// );
/// ```
class UnifiedMenuService extends ChangeNotifier
    with ErrorHandlingMixin, FirebaseServiceMixin {
  final FirebaseFirestore _firestore;
  final FirestoreRepository _firestoreRepository;

  // Core services
  late final MenuService _menuService;
  late final FirebaseSharedMenuRepository _sharedMenuRepository;

  // Operations modules
  CollaborativeMenuOperations? _collaborative;

  /// Get collaborative operations with lazy initialization
  CollaborativeMenuOperations get collaborative {
    return _collaborative ??= _initializeCollaborativeOperations();
  }

  // State
  final List<SharedMenu> _menus = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  /// Get all menus (read-only)
  List<SharedMenu> get menus => List.unmodifiable(_menus);

  UnifiedMenuService({
    FirestoreRepository? firestoreRepository,
  })  : _firestoreRepository =
            firestoreRepository ?? ServiceLocator.get<FirestoreRepository>(),
        _firestore =
            (firestoreRepository ?? ServiceLocator.get<FirestoreRepository>())
                .firestore {
    // Initialize core menu service immediately
    _menuService = MenuService();

    // Initialize SharedMenu repository
    _sharedMenuRepository = FirebaseSharedMenuRepository();

    AppLogger.info(
        '✅ UnifiedMenuService created - collaborative operations will initialize on first use');
  }
  @override
  FirestoreRepository get firestoreRepository => _firestoreRepository;
  CollaborativeMenuOperations _initializeCollaborativeOperations() {
    AppLogger.debug('Initializing collaborative menu operations');
    return CollaborativeMenuOperations(
        this, ServiceLocator.get<MenuCollaborationRepository>());
  }

  /// Initialize the unified menu service
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.debug('UnifiedMenuService already initialized');
      return;
    }

    await safeExecute(() async {
      _isLoading = true;
      notifyListeners();

      try {
        // Load existing menus
        await _loadMenus();

        _isInitialized = true;
        AppLogger.success('✅ UnifiedMenuService initialization complete');
      } catch (e) {
        _error = 'Failed to initialize menu service: $e';
        AppLogger.error('Failed to initialize UnifiedMenuService', e);
        rethrow;
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  /// Load menus from Firebase
  /// Includes both user-owned menus and collaborative menus the user has joined
  Future<void> _loadMenus() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        AppLogger.debug('No user ID available for loading menus');
        return;
      }

      _menus.clear();

      // Load user's own menus from Firestore
      final querySnapshot = await _firestore
          .collection('menus')
          .where('sharedByUserId', isEqualTo: userId)
          .get();

      for (final doc in querySnapshot.docs) {
        try {
          final menu = SharedMenu.fromFirestore(doc.data(), doc.id);
          _menus.add(menu);
        } catch (e) {
          AppLogger.error('Error parsing menu ${doc.id}', e);
        }
      }

      // Also load collaborative menus where user is a participant
      // Bug fix: Without this, collaborative menus the user joined don't appear in saved menus
      try {
        final realtimeMenusSnapshot = await _firestore
            .collection('realtime_menus')
            .where('participantIds', arrayContains: userId)
            .get();

        for (final doc in realtimeMenusSnapshot.docs) {
          try {
            final data = doc.data();
            // Convert realtime menu to SharedMenu for display
            // Skip if user is the owner (already loaded in menus collection)
            if (data['ownerId'] != userId) {
              final menuSnapshotData =
                  data['menuSnapshot'] as Map<String, dynamic>?;
              if (menuSnapshotData != null) {
                final menu = SharedMenu(
                  id: doc.id,
                  menuSnapshot: _parseMenuSnapshot(menuSnapshotData),
                  menuTitle: menuSnapshotData['title'] as String? ??
                      AppLocale.current.labelCollaborativeMenu,
                  sharedByUserId: data['ownerId'] as String? ?? '',
                  sharedByDisplayName:
                      data['ownerDisplayName'] as String? ?? '?',
                  sharedAt: (data['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                  allowCollaboration: true,
                  realtimeMenuId: doc.id,
                );
                _menus.add(menu);
              }
            }
          } catch (e) {
            AppLogger.error('Error parsing realtime menu ${doc.id}', e);
          }
        }
      } catch (e) {
        AppLogger.warning('Could not load collaborative menus: $e');
        // Non-critical - continue with owned menus
      }

      AppLogger.info('Loaded ${_menus.length} menus (including collaborative)');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Failed to load menus', e);
      throw Exception('Failed to load menus: $e');
    }
  }

  /// Parse menu snapshot from Firestore data
  Map<String, List<Recipe>> _parseMenuSnapshot(
      Map<String, dynamic> menuSnapshot) {
    final result = <String, List<Recipe>>{};
    final categories =
        menuSnapshot['categories'] as Map<String, dynamic>? ?? {};

    for (final entry in categories.entries) {
      final recipes = <Recipe>[];
      final recipeList = entry.value as List<dynamic>? ?? [];
      for (final recipeData in recipeList) {
        try {
          if (recipeData is Map<String, dynamic>) {
            recipes.add(Recipe.fromJson(recipeData));
          }
        } catch (e) {
          AppLogger.warning('Error parsing recipe in menu snapshot: $e');
        }
      }
      result[entry.key] = recipes;
    }
    return result;
  }

  /// Refresh menus from Firebase (bypasses initialization guard)
  Future<void> refresh() async {
    await safeExecute(() async {
      _isLoading = true;
      notifyListeners();

      try {
        await _loadMenus();
        AppLogger.success('✅ Menus refreshed successfully');
      } catch (e) {
        _error = 'Failed to refresh menus: $e';
        AppLogger.error('Failed to refresh menus', e);
        rethrow;
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  /// Trigger notification to listeners (for operations classes)
  void triggerNotification() {
    notifyListeners();
  }

  /// Generate a menu from Swedish natural language prompt
  Future<Map<String, List<Recipe>>> generateMenuFromPrompt(
    String prompt,
    List<Recipe> availableRecipes,
  ) async {
    return await _menuService.generateMenuFromPrompt(prompt, availableRecipes);
  }

  /// Create a new menu
  Future<String?> createMenu({
    required String name,
    String? description,
    Map<String, List<Recipe>>? initialRecipes,
  }) async {
    return await safeExecute(() async {
      final userId = currentUserId;
      final userDisplayName = currentUserDisplayName;

      if (userId == null || userDisplayName == null) {
        AppLogger.error('Cannot create menu: User not authenticated');
        throw Exception('User not authenticated');
      }

      final menu = SharedMenu.create(
        sharedByUserId: userId,
        sharedByDisplayName: userDisplayName,
        sharedToUserIds: [],
        shareMessage: description,
        menuTitle: name,
        menuSnapshot: initialRecipes ?? {},
      );

      final menuData = menu.toFirestore();
      final docRef = await _firestore.collection('menus').add(menuData);
      final createdMenu = SharedMenu.fromFirestore(menuData, docRef.id);
      _menus.add(createdMenu);
      notifyListeners();

      AppLogger.success('Created menu: ${docRef.id}');
      return docRef.id;
    });
  }

  /// Update an existing menu
  Future<bool> updateMenu(SharedMenu menu) async {
    final result = await safeExecute(() async {
      try {
        final menuData = menu.toFirestore();
        await _firestore.collection('menus').doc(menu.id).update(menuData);

        final index = _menus.indexWhere((m) => m.id == menu.id);
        if (index != -1) {
          _menus[index] = menu;
          notifyListeners();
        }

        AppLogger.success('Updated menu: ${menu.id}');
        return true;
      } catch (e) {
        AppLogger.error('Failed to update menu', e);
        return false;
      }
    });
    return result ?? false;
  }

  /// Delete a menu
  Future<bool> deleteMenu(String menuId) async {
    final result = await safeExecute(() async {
      try {
        await _firestore.collection('menus').doc(menuId).delete();
        _menus.removeWhere((m) => m.id == menuId);
        notifyListeners();

        AppLogger.success('Deleted menu: $menuId');
        return true;
      } catch (e) {
        AppLogger.error('Failed to delete menu', e);
        return false;
      }
    });
    return result ?? false;
  }

  /// Get menu by ID
  SharedMenu? getMenuById(String menuId) {
    return _menus.where((m) => m.id == menuId).firstOrNull;
  }

  /// Create menu invitation using SharedMenu model for universal invitation system
  Future<String?> createMenuInvitation({
    required String menuTitle,
    required Map<String, List<Recipe>> menuSnapshot,
    required List<String> inviteeUserIds,
    String? message,
    bool allowCollaboration = false,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      AppLogger.error('Cannot create menu invitation: No authenticated user');
      return null;
    }

    final result = await safeExecute<String?>(() async {
      try {
        AppLogger.info(
            '🔍🔍🔍 DEBUG SHARE ENTRY: createMenuInvitation called with "$menuTitle" for ${inviteeUserIds.length} users');
        AppLogger.info(
            '📨 Creating menu invitation "$menuTitle" for ${inviteeUserIds.length} users');

        // Get current user's display name
        final userService = ServiceLocator.get<UserService>();
        final currentUserProfile = userService.currentUserProfile;
        if (currentUserProfile == null) {
          AppLogger.error(
              'Cannot get current user profile for menu invitation');
          return null;
        }

        // If collaboration is enabled, create a RealtimeMenu first
        String? realtimeMenuId;
        if (allowCollaboration) {
          AppLogger.info('🔄 Creating RealtimeMenu for collaborative editing');
          final realtimeMenuService = ServiceLocator.get<RealtimeMenuService>();
          final realtimeMenu = await realtimeMenuService.createRealtimeMenu(
            menuTitle: menuTitle,
            menuSnapshot: menuSnapshot,
            editorUserIds: inviteeUserIds,
          );
          realtimeMenuId = realtimeMenu.id;
          AppLogger.success(
              '✅ RealtimeMenu created: $realtimeMenuId with ${inviteeUserIds.length} editors');
        }

        // Create SharedMenu invitation
        final sharedMenu = SharedMenu.create(
          sharedByUserId: userId,
          sharedByDisplayName: currentUserProfile.displayName,
          sharedToUserIds: inviteeUserIds,
          shareMessage: message,
          menuTitle: menuTitle,
          menuSnapshot: menuSnapshot,
          allowCollaboration: allowCollaboration,
          realtimeMenuId: realtimeMenuId,
        );

        // Save invitation to Firebase
        // Note (Issue #014): Pass recipientIds separately since arrays removed from model
        final invitationId = await _sharedMenuRepository.createSharedMenu(
          sharedMenu,
          recipientIds: inviteeUserIds,
        );

        AppLogger.success(
            '✅ Menu invitation created successfully: $invitationId');
        AppLogger.info(
            '📥 Recipients will see invitation in "Delat med mig" view');

        return invitationId;
      } catch (e) {
        AppLogger.error('Failed to create menu invitation: $e');
        return null;
      }
    });

    return result;
  }

  /// Share menu with friends using invitation system
  Future<bool> shareMenuWithFriends({
    required String menuTitle,
    required Map<String, List<Recipe>> menuSnapshot,
    required List<String> friendIds,
    String? message,
    bool allowCollaboration = false,
  }) async {
    final invitationId = await createMenuInvitation(
      menuTitle: menuTitle,
      menuSnapshot: menuSnapshot,
      inviteeUserIds: friendIds,
      message: message,
      allowCollaboration: allowCollaboration,
    );

    return invitationId != null;
  }

  /// Get menu invitations received by current user
  Future<List<SharedMenu>> getReceivedMenuInvitations() async {
    final userId = currentUserId;
    if (userId == null) {
      AppLogger.warning(
          'Cannot get received menu invitations: No authenticated user');
      return [];
    }

    final result = await safeExecute<List<SharedMenu>>(() async {
      try {
        AppLogger.info('📥 Getting received menu invitations for user $userId');
        return await _sharedMenuRepository.getSharedMenusForUser(userId);
      } catch (e) {
        AppLogger.error('Failed to get received menu invitations: $e');
        return <SharedMenu>[];
      }
    });

    return result ?? [];
  }

  /// Import shared menu or join collaborative session.
  /// Returns a tuple-like result: (menuId, isCollaborative)
  /// - For collaborative menus: returns (realtimeMenuId, true)
  /// - For regular menus: returns (importedMenuId, false)
  Future<MenuImportResult?> importSharedMenu({
    required String sharedMenuId,
    String? newTitle,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      AppLogger.error('Cannot import menu: No authenticated user');
      return null;
    }

    final result = await safeExecute<MenuImportResult?>(() async {
      try {
        AppLogger.info('📥 Importing shared menu $sharedMenuId');

        // Get shared menu
        final sharedMenu =
            await _sharedMenuRepository.getSharedMenu(sharedMenuId);
        if (sharedMenu == null) {
          AppLogger.error('Shared menu not found: $sharedMenuId');
          return null;
        }

        // Check if this is a collaborative menu with a realtime session
        if (sharedMenu.realtimeMenuId != null) {
          AppLogger.info(
              '📡 Joining collaborative menu: ${sharedMenu.realtimeMenuId}');
          // Mark as accepted/imported in SharedMenu
          await _sharedMenuRepository.markAsImported(sharedMenuId, userId);
          AppLogger.success(
              '✅ Joined collaborative menu session: ${sharedMenu.realtimeMenuId}');
          // Return the realtime menu ID - caller should navigate to collaborative view
          return MenuImportResult(
            menuId: sharedMenu.realtimeMenuId!,
            isCollaborative: true,
          );
        }

        // Regular import: create a copy with attribution
        final menuTitle = newTitle ?? '${sharedMenu.menuTitle} (Importerad)';
        final attributedMenu =
            Map<String, List<Recipe>>.from(sharedMenu.menuSnapshot);

        // Add attribution to menu description or first recipe
        if (attributedMenu.isNotEmpty) {
          final firstCategory = attributedMenu.keys.first;
          final recipes = attributedMenu[firstCategory]!;
          if (recipes.isNotEmpty) {
            final firstRecipe = recipes[0];
            final attributionText = AppLocale.current
                .menuAttributionText(sharedMenu.sharedByDisplayName);
            final attributedRecipe = firstRecipe.copyWith(
              description: firstRecipe.description.isEmpty
                  ? attributionText
                  : '${firstRecipe.description}\n\n$attributionText',
            );
            attributedMenu[firstCategory] = [
              attributedRecipe,
              ...recipes.skip(1)
            ];
          }
        }

        // Create new menu with imported data
        final importedMenuId = await createMenu(
          name: menuTitle,
          initialRecipes: attributedMenu,
        );

        if (importedMenuId == null) {
          AppLogger.error('Failed to create imported menu');
          return null;
        }

        // Mark as imported in SharedMenu
        await _sharedMenuRepository.markAsImported(sharedMenuId, userId);

        AppLogger.success('✅ Menu imported successfully with attribution');
        return MenuImportResult(
          menuId: importedMenuId,
          isCollaborative: false,
        );
      } catch (e) {
        AppLogger.error('Failed to import shared menu: $e');
        return null;
      }
    });

    return result;
  }

  /// Dismiss shared menu from user's list
  Future<bool> dismissSharedMenu(String sharedMenuId) async {
    final userId = currentUserId;
    if (userId == null) {
      AppLogger.error('Cannot dismiss menu: No authenticated user');
      return false;
    }

    final result = await safeExecute<bool>(() async {
      try {
        AppLogger.info('🗑️ Dismissing shared menu $sharedMenuId');
        await _sharedMenuRepository.markAsDismissed(sharedMenuId, userId);
        AppLogger.success('✅ Shared menu dismissed');
        return true;
      } catch (e) {
        AppLogger.error('Failed to dismiss shared menu: $e');
        return false;
      }
    });

    return result ?? false;
  }

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  // From FirebaseServiceMixin
  String? get currentUserId =>
      ServiceLocator.get<PermissionService>().currentUserId;
  String? get currentUserDisplayName =>
      ServiceLocator.get<PermissionService>().currentUserDisplayName;
  @override
  void dispose() {
    // Clean up any resources
    _menus.clear();
    super.dispose();
  }
}
