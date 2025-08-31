// lib/services/unified/unified_menu_service.dart

import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/repositories/interfaces/menu_collaboration_repository.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/firebase_service_mixin.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/services/menu_service.dart';

// Operations modules
import 'package:butlery/services/unified/operations/collaborative_menu_operations.dart';

/// Comprehensive unified menu service providing coordinated access to personal and collaborative menu functionality.
///
/// This service implements a sophisticated menu management system using modular architecture with focused components
/// for personal menu operations, collaborative menu planning, and social menu sharing features.
/// It provides a unified API surface that coordinates between specialized modules while maintaining clean separation
/// of concerns for maintainable and scalable menu management across all application features.
///
/// **Architecture Integration:**
/// - Extends [ChangeNotifier] for reactive UI updates with menu state changes across all modules
/// - Uses [ErrorHandlingMixin] for comprehensive error management and graceful degradation strategies
/// - Implements [FirebaseServiceMixin] for Firebase integration and authentication-aware operations
/// - Coordinates with MenuService for basic menu generation and management operations
///
/// **Modular Coordination Architecture:**
/// This service coordinates between focused modules with clear responsibilities:
/// - **[MenuService]**: Basic menu generation, natural language processing, and meal planning
/// - **[CollaborativeMenuOperations]**: Real-time collaborative menu planning and social features
///
/// **Unified API Benefits:**
/// - **Single Entry Point**: Unified interface for all menu operations reducing complexity for ViewModels
/// - **Coordinated Operations**: Seamless integration between personal and collaborative menu features
/// - **Clean Separation**: Each module handles specific concerns without cross-module business logic contamination
/// - **Reactive Updates**: Comprehensive state management with automatic UI updates across all menu operations
///
/// **What This Service Does NOT Contain:**
/// - Business logic implementation (delegated to specialized modules for focused responsibility)
/// - Direct Firebase operations (handled by modules and repository layers for proper abstraction)
/// - Authentication management (handled by FirebaseAuthRepository and authentication mixins)
///
/// **Usage Examples:**
/// ```dart
/// final menuService = UnifiedMenuService(firestore, authRepository);
/// await menuService.initialize();
///
/// // Personal menu operations
/// final menu = await menuService.generateMenuFromPrompt('tre frukoster och två middagar', recipes);
///
/// // Collaborative menu planning
/// await menuService.collaborative.enableMenuCollaboration(
///   menuId: menuId,
///   collaboratorIds: ['user1', 'user2'],
/// );
/// ```
class UnifiedMenuService extends ChangeNotifier 
    with ErrorHandlingMixin, FirebaseServiceMixin {
  final FirebaseFirestore _firestore;

  // Core services
  late final MenuService _menuService;
  
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

  UnifiedMenuService({
    FirebaseFirestore? firestore,
  })  : _firestore = firestore ?? FirebaseFirestore.instance {
    // Initialize core menu service immediately
    _menuService = MenuService();
    
    AppLogger.info(
        '✅ UnifiedMenuService created - collaborative operations will initialize on first use');
  }

  // ===== INITIALIZATION =====

  CollaborativeMenuOperations _initializeCollaborativeOperations() {
    AppLogger.debug('Initializing collaborative menu operations');
    return CollaborativeMenuOperations(
      this, 
      ServiceLocator.get<MenuCollaborationRepository>()
    );
  }

  // ===== PUBLIC API =====

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
  Future<void> _loadMenus() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        AppLogger.debug('No user ID available for loading menus');
        return;
      }

      // Load user's menus from Firestore
      final querySnapshot = await _firestore
          .collection('menus')
          .where('sharedByUserId', isEqualTo: userId)
          .get();

      _menus.clear();
      for (final doc in querySnapshot.docs) {
        try {
          final menu = SharedMenu.fromFirestore(doc.data(), doc.id);
          _menus.add(menu);
        } catch (e) {
          AppLogger.error('Error parsing menu ${doc.id}', e);
        }
      }

      AppLogger.info('Loaded ${_menus.length} menus');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Failed to load menus', e);
      throw Exception('Failed to load menus: $e');
    }
  }

  // ===== PUBLIC NOTIFICATION METHOD =====
  
  /// Trigger notification to listeners (for operations classes)
  void triggerNotification() {
    notifyListeners();
  }

  // ===== MENU GENERATION (Delegated to MenuService) =====

  /// Generate a menu from Swedish natural language prompt
  Future<Map<String, List<Recipe>>> generateMenuFromPrompt(
    String prompt,
    List<Recipe> availableRecipes,
  ) async {
    return await _menuService.generateMenuFromPrompt(prompt, availableRecipes);
  }

  // ===== BASIC MENU OPERATIONS =====

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

  // ===== GETTERS =====

  List<SharedMenu> get menus => List.unmodifiable(_menus);
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  // From FirebaseServiceMixin
  String? get currentUserId => ServiceLocator.get<PermissionService>().currentUserId;
  String? get currentUserDisplayName => ServiceLocator.get<PermissionService>().currentUserDisplayName;

  // ===== LIFECYCLE =====

  @override
  void dispose() {
    // Clean up any resources
    _menus.clear();
    super.dispose();
  }
}