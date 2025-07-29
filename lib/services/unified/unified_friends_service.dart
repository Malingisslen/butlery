/// 🔍 AI INFO BLOCK:
/// Component: Unified Friends Service - Main facade for friend management (Phase 9 Refactored)
/// File: lib/services/unified/unified_friends_service.dart
/// Quick Guide: Clean facade coordinating focused modules with backward compatibility
/// Dependencies IN: FirestoreRepository, AuthRepository, Friend models
/// Dependencies OUT: Used by ViewModels for friend operations
/// Data flow: ViewModels -> UnifiedFriendsService (Facade) -> Focused Modules -> Firebase/Cache
/// State management: Delegated to FriendsStateManager with ChangeNotifier
/// Purpose: Maintain backward compatibility while providing clean modular architecture
/// Common issues: Real-time sync, offline support, permission handling
/// Test coverage: Unit tests for facade delegation and module coordination
/// Performance: Optimistic updates with Firebase sync and caching
/// Analytics: Friend activity, relationship metrics, social engagement
/// Code smells: None - follows facade pattern with single responsibility modules
/// Connected to: All friend-related ViewModels and social features
/// Used in phases: Phase 9 - Large File SRP Refactoring

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';

// Feature interfaces
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/services/unified/operations/friends_categories_operations.dart';
import 'package:butlery/services/unified/operations/friends_invitations_operations.dart';
import 'package:butlery/services/unified/operations/social_group_sharing_operations.dart';

// Focused modules (Phase 9 refactoring)
import 'package:butlery/services/unified/friends/friends_state_manager.dart';
import 'package:butlery/services/unified/friends/friends_service_coordinator.dart';
import 'package:butlery/services/unified/friends/friends_internal_operations.dart';
import 'package:butlery/services/unified/friends/friends_sync_service.dart';
import 'package:butlery/services/unified/friends/friends_presence_service.dart';
import 'package:butlery/services/unified/friends/friends_cache_service.dart';

/// Unified Friends Service - Main facade for friend management (Phase 9 Refactored)
/// 
/// This facade coordinates between focused single-responsibility modules:
/// - FriendsStateManager: Manages all state and notifications
/// - FriendsServiceCoordinator: Handles service initialization and callbacks
/// - FriendsInternalOperations: Provides internal methods for operations classes
/// - Feature operations: Handle specific business logic
/// 
/// Maintains 100% backward compatibility while providing clean modular architecture.
class UnifiedFriendsService extends ChangeNotifier {
  // Dependencies
  final FirestoreRepository _firestoreRepository;
  final AuthRepository _authRepository;
  
  // Focused modules (Phase 9 refactoring)
  late final FriendsStateManager _stateManager;
  late final FriendsServiceCoordinator _serviceCoordinator;
  late final FriendsInternalOperations _internalOps;
  
  // Feature interfaces
  late final FriendsManagementOperations _managementOps;
  late final FriendsCategoriesOperations _categoriesOps;
  late final FriendsInvitationsOperations _invitationsOps;
  late final SocialGroupSharingOperations _groupSharingOps;

  // Constructor
  UnifiedFriendsService({
    required FirestoreRepository firestoreRepository,
    required AuthRepository authRepository,
  })  : _firestoreRepository = firestoreRepository,
        _authRepository = authRepository {
    
    // Initialize focused modules
    _initializeModules();
    
    // Initialize feature interfaces
    _initializeFeatureInterfaces();
    
    AppLogger.info('✅ UnifiedFriendsService facade initialized with modular architecture');
  }

  // ===== GETTERS (Delegated to State Manager) =====

  List<UserProfile> get friends => _stateManager.friends;
  List<FriendRequest> get incomingRequests => _stateManager.incomingRequests;
  List<FriendRequest> get outgoingRequests => _stateManager.outgoingRequests;
  List<FriendCategory> get categoriesList => _stateManager.categories;
  List<GroupInvitation> get sentInvitations => _stateManager.sentInvitations;
  Set<String> get blockedUsers => _stateManager.blockedUsers;
  Map<String, Set<String>> get friendCategoryRelationships => _stateManager.friendCategoryRelationships;

  bool get isInitialized => _stateManager.isInitialized;
  bool get isLoading => _stateManager.isLoading;
  String? get error => _stateManager.error;
  bool get hasError => _stateManager.hasError;
  
  String? get currentUserId => sl<PermissionService>().currentUserId;
  FirebaseFirestore get firestore => _firestoreRepository.firestore;

  // ===== FEATURE INTERFACE GETTERS =====

  FriendsManagementOperations get management => _managementOps;
  FriendsCategoriesOperations get categories => _categoriesOps;
  FriendsInvitationsOperations get invitations => _invitationsOps;
  SocialGroupSharingOperations get groupSharing => _groupSharingOps;

  // ===== SERVICE GETTERS (Delegated to Service Coordinator) =====

  FriendsSyncService get sync => _serviceCoordinator.sync;
  FriendsPresenceService get presence => _serviceCoordinator.presence;
  FriendsCacheService get cache => _serviceCoordinator.cache;

  // ===== INITIALIZATION (Delegated to Service Coordinator) =====

  Future<void> initialize() async {
    try {
      AppLogger.info('🔄 Initializing UnifiedFriendsService facade...');
      await _serviceCoordinator.initialize();
      AppLogger.success('✅ UnifiedFriendsService facade initialized');
    } catch (e) {
      AppLogger.error('❌ Failed to initialize UnifiedFriendsService facade: $e');
      rethrow;
    }
  }

  // ===== PRIVATE INITIALIZATION METHODS =====

  void _initializeModules() {
    // Initialize state manager
    _stateManager = FriendsStateManager();
    
    // Initialize service coordinator
    _serviceCoordinator = FriendsServiceCoordinator(
      firestoreRepository: _firestoreRepository,
      authRepository: _authRepository,
      stateManager: _stateManager,
    );
    
    // Initialize internal operations
    _internalOps = FriendsInternalOperations(
      _stateManager,
      _serviceCoordinator.sync,
      _serviceCoordinator.cache,
    );
    
    // Forward state manager notifications to facade
    _stateManager.addListener(() {
      notifyListeners();
    });
    
    AppLogger.debug('Focused modules initialized');
  }

  void _initializeFeatureInterfaces() {
    _managementOps = FriendsManagementOperations(this);
    _categoriesOps = FriendsCategoriesOperations(this);
    _invitationsOps = FriendsInvitationsOperations(this);
    _groupSharingOps = SocialGroupSharingOperations(this);
    
    AppLogger.debug('Feature interfaces initialized');
  }

  // ===== STATE MANAGEMENT (Delegated to State Manager) =====
  // Note: State management is now handled by FriendsStateManager
  // All state operations are automatically coordinated through the service coordinator

  // ===== INTERNAL METHODS FOR OPERATIONS CLASSES (Delegated to Internal Operations) =====

  /// Internal getter for friends list (for operations classes)
  List<UserProfile> get friendsInternal => _internalOps.friendsInternal;

  /// Internal getter for categories list (for operations classes)
  List<FriendCategory> getAllCategoriesInternal() => _internalOps.getAllCategoriesInternal();

  /// Internal getter for sent invitations (for operations classes)
  List<GroupInvitation> getAllSentInvitationsInternal() => _internalOps.getAllSentInvitationsInternal();

  /// Internal getter for friend-category relationships (for operations classes)
  Map<String, Set<String>> get friendCategoryRelationshipsInternal => _stateManager.relationshipsInternal;

  /// Internal method to notify listeners (for operations classes)
  void notifyListenersInternal() => _internalOps.notifyListenersInternal();

  /// Internal method to get category by ID (for operations classes)
  FriendCategory? getCategoryByIdInternal(String categoryId) => _internalOps.getCategoryByIdInternal(categoryId);

  /// Internal method to add category (for operations classes)
  void addCategoryInternal(FriendCategory category) => _internalOps.addCategoryInternal(category);

  /// Internal method to update category (for operations classes)
  void updateCategoryInternal(String categoryId, FriendCategory category) => _internalOps.updateCategoryInternal(categoryId, category);

  /// Internal method to remove category (for operations classes)
  void removeCategoryInternal(String categoryId) => _internalOps.removeCategoryInternal(categoryId);

  /// Internal method to sync category to Firebase (for operations classes)
  Future<void> syncCategoryToFirebaseInternal(FriendCategory category) async => await _internalOps.syncCategoryToFirebaseInternal(category);

  /// Internal method to delete category from Firebase (for operations classes)
  Future<void> deleteCategoryFromFirebaseInternal(String categoryId) async => await _internalOps.deleteCategoryFromFirebaseInternal(categoryId);

  /// Internal method to add friend to category (for operations classes)
  void addFriendToCategoryInternal(String friendId, String categoryId) => _internalOps.addFriendToCategoryInternal(friendId, categoryId);

  /// Internal method to remove friend from category (for operations classes)
  void removeFriendFromCategoryInternal(String friendId, String categoryId) => _internalOps.removeFriendFromCategoryInternal(friendId, categoryId);

  /// Internal method to get friends in category (for operations classes)
  Set<String> getFriendsInCategoryInternal(String categoryId) => _internalOps.getFriendsInCategoryInternal(categoryId);

  /// Internal method to get categories for friend (for operations classes)
  Set<String> getCategoriesForFriendInternal(String friendId) => _internalOps.getCategoriesForFriendInternal(friendId);

  /// Internal method to add sent invitation (for operations classes)
  void addSentInvitationInternal(GroupInvitation invitation) => _internalOps.addSentInvitationInternal(invitation);

  /// Internal method to get sent invitation by ID (for operations classes)
  GroupInvitation? getSentInvitationByIdInternal(String invitationId) => _internalOps.getSentInvitationByIdInternal(invitationId);

  /// Internal method to update sent invitation (for operations classes)
  void updateSentInvitationInternal(String invitationId, GroupInvitation invitation) => _internalOps.updateSentInvitationInternal(invitationId, invitation);

  /// Internal method to send email invitation (for operations classes)
  Future<bool> sendEmailInvitationInternal({required String email, required GroupInvitation invitation}) async => await _internalOps.sendEmailInvitationInternal(email: email, invitation: invitation);

  /// Internal method to send SMS invitation (for operations classes)
  Future<bool> sendSMSInvitationInternal({required String phoneNumber, required GroupInvitation invitation}) async => await _internalOps.sendSMSInvitationInternal(phoneNumber: phoneNumber, invitation: invitation);

  /// Internal method to create invitation link (for operations classes)
  String createInvitationLinkInternal(String invitationId) => _internalOps.createInvitationLinkInternal(invitationId);

  /// Internal method to update invitation status (for operations classes)
  Future<void> updateInvitationStatusInternal(String invitationId, GroupInvitationStatus status) async => await _internalOps.updateInvitationStatusInternal(invitationId, status);

  /// Internal getter for current user display name (for operations classes)
  String? get currentUserDisplayName => _internalOps.getCurrentUserDisplayNameInternal();

  /// Internal method to refresh data (for operations classes)
  Future<void> refresh() async => await _serviceCoordinator.refresh();

  // ===== VIEWMODEL COMPATIBILITY METHODS (Delegated) =====

  /// Clear error state (for ViewModels)
  void clearError() => _serviceCoordinator.clearError();

  /// Get friends list (for ViewModels)
  List<UserProfile> get friendsList => friends;

  /// Get category by ID (for ViewModels)
  FriendCategory? getCategoryById(String categoryId) => _stateManager.getCategoryById(categoryId);

  /// Cancel sent invitation (for ViewModels)
  Future<bool> cancelSentInvitation(String invitationId) async => await invitations.cancelInvitation(invitationId);

  // ===== CLEANUP (Delegated to Service Coordinator) =====

  @override
  void dispose() {
    _serviceCoordinator.dispose();
    super.dispose();
  }
}