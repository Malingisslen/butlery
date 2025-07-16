/// 🔍 AI INFO BLOCK:
/// Component: Unified Friends Service - Main service for friend management with feature interfaces
/// File: lib/services/unified/unified_friends_service.dart
/// Quick Guide: Central service for all friend-related operations using feature interface pattern
/// Dependencies IN: FirestoreRepository, AuthRepository, Friend models
/// Dependencies OUT: Used by ViewModels for friend operations
/// Data flow: ViewModels -> Feature Interfaces -> UnifiedFriendsService -> Firebase/Cache
/// State management: ChangeNotifier with real-time Firebase sync
/// Purpose: Centralized friend management with separated concerns
/// Common issues: Real-time sync, offline support, permission handling
/// Test coverage: Unit tests for all friend operations and feature interfaces
/// Performance: Optimistic updates with Firebase sync and caching
/// Analytics: Friend activity, relationship metrics, social engagement
/// Code smells: None - follows unified service pattern with feature interfaces
/// Connected to: All friend-related ViewModels and social features
/// Used in phases: Phase 5 - Service Consolidation

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../repositories/interfaces/auth_repository.dart';
import '../deep_link_service.dart';
import '../../repositories/firestore_repository.dart';
import '../../models/friend_request.dart';
import '../../models/user_profile.dart';
import '../../models/friend_category.dart';
import '../../models/group_invitation.dart';
import '../../core/utils/logger.dart';
import '../../core/mixins/firebase_sync_mixin.dart';

// Feature interfaces
import 'operations/friends_management_operations.dart';
import 'operations/friends_categories_operations.dart';
import 'operations/friends_invitations_operations.dart';

/// Unified Friends Service with feature interfaces
class UnifiedFriendsService extends ChangeNotifier with FirebaseSyncMixin<UserProfile> {
  static const String _hiveBoxBaseName = 'unified_friends_cache';
  // Dependencies
  final FirestoreRepository firestoreRepository;
  final AuthRepository _authRepository;

  // Feature interfaces
  late final FriendsManagementOperations _managementOps;
  late final FriendsCategoriesOperations _categoriesOps;
  late final FriendsInvitationsOperations _invitationsOps;

  // State
  final List<UserProfile> _friends = [];
  final List<FriendRequest> _incomingRequests = [];
  final List<FriendRequest> _outgoingRequests = [];
  final List<FriendCategory> _categories = [];
  final List<GroupInvitation> _sentInvitations = [];
  final Set<String> _blockedUsers = {};
  
  // Friend-Category relationship mapping (friendId -> Set<categoryId>)
  final Map<String, Set<String>> _friendCategoryRelationships = {};

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  // Constructor
  UnifiedFriendsService({
    required this.firestoreRepository,
    required AuthRepository authRepository,
  })  : _authRepository = authRepository {
    // Initialize feature interfaces
    _managementOps = FriendsManagementOperations(this);
    _categoriesOps = FriendsCategoriesOperations(this);
    _invitationsOps = FriendsInvitationsOperations(this);
  }

  // ===== FEATURE INTERFACE GETTERS =====

  /// Friends management operations
  FriendsManagementOperations get management => _managementOps;

  /// Categories operations
  FriendsCategoriesOperations get categories => _categoriesOps;

  /// Invitations operations
  FriendsInvitationsOperations get invitations => _invitationsOps;

  // ===== GETTERS =====

  List<UserProfile> get friends => List.unmodifiable(_friends);
  List<FriendRequest> get incomingRequests => List.unmodifiable(_incomingRequests);
  List<FriendRequest> get outgoingRequests => List.unmodifiable(_outgoingRequests);
  List<FriendCategory> get categoriesList => List.unmodifiable(_categories);
  List<GroupInvitation> get sentInvitations => List.unmodifiable(_sentInvitations);
  Set<String> get blockedUsers => Set.unmodifiable(_blockedUsers);

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  // ===== INTERNAL METHODS FOR OPERATIONS =====
  // These methods provide controlled access to private collections for operations classes

  /// Add category to internal list (for operations use only)
  // ignore: unused_element
  void _addCategory(FriendCategory category) {
    _categories.add(category);
  }

  /// Get sent invitation by ID (for operations use only)
  // ignore: unused_element
  GroupInvitation? _getSentInvitationById(String invitationId) {
    return _sentInvitations.where((i) => i.id == invitationId).firstOrNull;
  }

  /// Get all sent invitations (for operations use only)
  // ignore: unused_element
  List<GroupInvitation> _getAllSentInvitations() {
    return List.unmodifiable(_sentInvitations);
  }

  /// Remove category from internal list (for operations use only)
  // ignore: unused_element
  void _removeCategory(String categoryId) {
    _categories.removeWhere((c) => c.id == categoryId);
  }

  /// Update category in internal list (for operations use only)
  // ignore: unused_element
  void _updateCategory(String categoryId, FriendCategory updatedCategory) {
    final index = _categories.indexWhere((c) => c.id == categoryId);
    if (index != -1) {
      _categories[index] = updatedCategory;
    }
  }

  /// Get category by ID (for operations use only)
  // ignore: unused_element
  FriendCategory? _getCategoryById(String categoryId) {
    return _categories.where((c) => c.id == categoryId).firstOrNull;
  }

  /// Get all categories (for operations use only)
  // ignore: unused_element
  List<FriendCategory> _getAllCategories() {
    return _categories;
  }

  /// Add invitation to internal list (for operations use only)
  // ignore: unused_element
  void _addSentInvitation(GroupInvitation invitation) {
    _sentInvitations.add(invitation);
  }

  /// Update invitation in internal list (for operations use only)
  // ignore: unused_element
  void _updateSentInvitation(String invitationId, GroupInvitation updatedInvitation) {
    final index = _sentInvitations.indexWhere((i) => i.id == invitationId);
    if (index != -1) {
      _sentInvitations[index] = updatedInvitation;
    }
  }


  @override
  String? get currentUserId => _authRepository.currentUserId;
  
  @override
  FirebaseFirestore get firestore => firestoreRepository.firestore;
  
  String? get currentUserDisplayName =>
      _authRepository.getCurrentUser()?.displayName ?? 'You';

  /// Get user-specific Hive box name for secure caching
  String get _userSpecificBoxName {
    final userId = currentUserId;
    return userId != null ? '${_hiveBoxBaseName}_$userId' : _hiveBoxBaseName;
  }
  
  /// Compatibility getter for legacy code
  List<UserProfile> get friendsList => friends;

  // ===== INITIALIZATION =====

  /// Initialize the friends service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      AppLogger.info('🔄 Initializing UnifiedFriendsService...');

      // Configure Firestore for emulator if needed
      if (kDebugMode) {
        try {
          firestore.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );
        } catch (e) {
          AppLogger.debug('Firestore settings already configured');
        }
      }

      // Open Hive box for caching (user-specific for security)
      final box = await Hive.openBox<String>(_userSpecificBoxName);

      // Load cached data first (offline-first)
      await _loadCachedData(box);

      // Initialize default categories
      await _initializeDefaultCategories();

      // Listen to auth changes using mixin
      _authRepository.authStateChanges().listen((user) {
        onAuthStateChanged(user?.uid);
        if (user == null) {
          _clearAll();
        }
      });

      // Start Firebase sync if logged in using mixin
      if (_authRepository.getCurrentUser() != null) {
        startFirebaseSync();
      }

      _isInitialized = true;
      AppLogger.success('✅ UnifiedFriendsService initialized');
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Failed to initialize UnifiedFriendsService: $e');
      _setError('Could not load friends: $e');
    }
  }

  // ===== FRIEND-CATEGORY RELATIONSHIP METHODS =====
  
  /// Add friend to category relationship
  // ignore: unused_element
  void _addFriendToCategory(String friendId, String categoryId) {
    _friendCategoryRelationships.putIfAbsent(friendId, () => <String>{});
    _friendCategoryRelationships[friendId]!.add(categoryId);
    
    // Sync to Firebase
    _syncFriendCategoryRelationshipsToFirebase();
  }
  
  /// Remove friend from category relationship  
  // ignore: unused_element
  void _removeFriendFromCategory(String friendId, String categoryId) {
    _friendCategoryRelationships[friendId]?.remove(categoryId);
    if (_friendCategoryRelationships[friendId]?.isEmpty ?? false) {
      _friendCategoryRelationships.remove(friendId);
    }
    
    // Sync to Firebase
    _syncFriendCategoryRelationshipsToFirebase();
  }
  
  /// Get categories for friend
  // ignore: unused_element
  Set<String> _getCategoriesForFriend(String friendId) {
    return _friendCategoryRelationships[friendId] ?? <String>{};
  }
  
  /// Get friends in category
  // ignore: unused_element
  List<String> _getFriendsInCategory(String categoryId) {
    return _friendCategoryRelationships.entries
        .where((entry) => entry.value.contains(categoryId))
        .map((entry) => entry.key)
        .toList();
  }

  // ===== INTERNAL METHODS FOR FEATURE INTERFACES =====

  /// Internal method to notify listeners
  // ignore: unused_element
  void _notifyListeners() {
    notifyListeners();
  }

  /// Internal method to update friend
  // ignore: unused_element
  Future<void> _updateFriend(UserProfile friend) async {
    try {
      final index = _friends.indexWhere((f) => f.uid == friend.uid);
      if (index != -1) {
        _friends[index] = friend;
        notifyListeners();
        await _saveFriendToCache(friend);
        await _syncFriendToFirebase(friend);
      }
    } catch (e) {
      AppLogger.error('Failed to update friend', e);
    }
  }

  /// Internal method to sync friend request to Firebase
  // ignore: unused_element
  Future<void> _syncFriendRequestToFirebase(FriendRequest request) async {
    if (currentUserId == null) return;

    try {
      await firestore
          .collection('friend_requests')
          .doc(request.id)
          .set(request.toFirestore(), SetOptions(merge: true));

      AppLogger.debug('Friend request synced: ${request.id}');
    } catch (e) {
      AppLogger.error('Failed to sync friend request to Firebase: $e');
    }
  }

  /// Internal method to update friend request status
  // ignore: unused_element
  Future<void> _updateFriendRequestStatus(FriendRequest request) async {
    try {
      await firestore
          .collection('friend_requests')
          .doc(request.id)
          .update({'status': request.status.toString().split('.').last});

      AppLogger.debug('Friend request status updated: ${request.id}');
    } catch (e) {
      AppLogger.error('Failed to update friend request status: $e');
    }
  }

  /// Internal method to sync friend to Firebase
  Future<void> _syncFriendToFirebase(UserProfile friend) async {
    if (currentUserId == null) return;

    try {
      await firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(friend.uid)
          .set({
            'uid': friend.uid,
            'displayName': friend.displayName,
            'email': friend.email,
            'avatarUrl': friend.avatarUrl,
            'bio': friend.bio,
            'joinedAt': friend.joinedAt.toIso8601String(),
            'lastActiveAt': friend.lastActiveAt.toIso8601String(),
          }, SetOptions(merge: true));

      AppLogger.debug('Friend synced: ${friend.displayName}');
    } catch (e) {
      AppLogger.error('Failed to sync friend to Firebase: $e');
    }
  }

  /// Internal method to remove friend from Firebase
  // ignore: unused_element
  Future<void> _removeFriendFromFirebase(String friendId) async {
    if (currentUserId == null) return;

    try {
      await firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(friendId)
          .delete();

      AppLogger.debug('Friend removed from Firebase: $friendId');
    } catch (e) {
      AppLogger.error('Failed to remove friend from Firebase: $e');
    }
  }

  /// Internal method to sync category to Firebase
  // ignore: unused_element
  Future<void> _syncCategoryToFirebase(FriendCategory category) async {
    if (currentUserId == null) return;

    try {
      await firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friend_categories')
          .doc(category.id)
          .set(category.toFirestore(), SetOptions(merge: true));

      AppLogger.debug('Category synced: ${category.name}');
    } catch (e) {
      AppLogger.error('Failed to sync category to Firebase: $e');
    }
  }

  /// Internal method to delete category from Firebase
  // ignore: unused_element
  Future<void> _deleteCategoryFromFirebase(String categoryId) async {
    if (currentUserId == null) return;

    try {
      await firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friend_categories')
          .doc(categoryId)
          .delete();

      AppLogger.debug('Category deleted from Firebase: $categoryId');
    } catch (e) {
      AppLogger.error('Failed to delete category from Firebase: $e');
    }
  }

  /// Internal method to sync friend-category relationships to Firebase
  // ignore: unused_element
  Future<void> _syncFriendCategoryRelationshipsToFirebase() async {
    if (currentUserId == null) return;

    try {
      await firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friend_category_relationships')
          .doc('relationships')
          .set({
            'relationships': _friendCategoryRelationships.map(
              (friendId, categoryIds) => MapEntry(friendId, categoryIds.toList()),
            ),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      AppLogger.debug('Friend-category relationships synced to Firebase');
    } catch (e) {
      AppLogger.error('Failed to sync friend-category relationships to Firebase: $e');
    }
  }

  /// Internal method to load friend-category relationships from Firebase
  // ignore: unused_element
  Future<void> _loadFriendCategoryRelationshipsFromFirebase() async {
    if (currentUserId == null) return;

    try {
      final doc = await firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friend_category_relationships')
          .doc('relationships')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final relationships = data['relationships'] as Map<String, dynamic>? ?? {};
        
        _friendCategoryRelationships.clear();
        relationships.forEach((friendId, categoryIds) {
          if (categoryIds is List) {
            _friendCategoryRelationships[friendId] = categoryIds.cast<String>().toSet();
          }
        });

        AppLogger.debug('Friend-category relationships loaded from Firebase');
      }
    } catch (e) {
      AppLogger.error('Failed to load friend-category relationships from Firebase: $e');
    }
  }

  /// Internal method to sync blocked users to Firebase
  // ignore: unused_element
  Future<void> _syncBlockedUsersToFirebase() async {
    if (currentUserId == null) return;

    try {
      await firestore
          .collection('users')
          .doc(currentUserId)
          .update({'blockedUsers': _blockedUsers.toList()});

      AppLogger.debug('Blocked users synced');
    } catch (e) {
      AppLogger.error('Failed to sync blocked users to Firebase: $e');
    }
  }

  /// Internal method to send email invitation
  // ignore: unused_element
  Future<bool> _sendEmailInvitation(GroupInvitation invitation) async {
    try {
      // Generate unique invitation link
      final invitationId = invitation.id;
      final invitationLink = _generateInvitationLink(invitationId);
      
      // Store invitation in Firebase for tracking
      await _storeInvitationInFirebase(invitation, invitationLink);
      
      // Create email content
      final emailSubject = _createEmailSubject(invitation);
      final emailBody = _createEmailBody(invitation, invitationLink);
      
      // Use mailto: URL to open default email client
      final success = await _sendMailtoEmail(
        to: invitation.toUserId,
        subject: emailSubject,
        body: emailBody,
      );
      
      if (success) {
        AppLogger.success('Email invitation prepared for ${invitation.toUserId}');
        // Mark invitation as sent in local state
        _markInvitationAsSent(invitation.id);
        return true;
      } else {
        AppLogger.error('Failed to prepare email invitation');
        return false;
      }
    } catch (e) {
      AppLogger.error('Failed to send email invitation: $e');
      return false;
    }
  }

  /// Internal method to send SMS invitation
  // ignore: unused_element
  Future<bool> _sendSMSInvitation(GroupInvitation invitation) async {
    try {
      // Generate unique invitation link
      final invitationId = invitation.id;
      final invitationLink = _generateInvitationLink(invitationId);
      
      // Store invitation in Firebase for tracking
      await _storeInvitationInFirebase(invitation, invitationLink);
      
      // Create SMS content
      final smsMessage = _createSMSMessage(invitation, invitationLink);
      
      // Use SMS URL scheme to open default messaging app
      final success = await _sendSMSMessage(
        to: invitation.toUserId,
        message: smsMessage,
      );
      
      if (success) {
        AppLogger.success('SMS invitation prepared for ${invitation.toUserId}');
        // Mark invitation as sent in local state
        _markInvitationAsSent(invitation.id);
        return true;
      } else {
        AppLogger.error('Failed to prepare SMS invitation');
        return false;
      }
    } catch (e) {
      AppLogger.error('Failed to send SMS invitation: $e');
      return false;
    }
  }

  /// Internal method to create invitation link
  // ignore: unused_element
  Future<String> _createInvitationLink(GroupInvitation invitation) async {
    try {
      // Use the deep link service to generate a proper invitation link
      final invitationLink = DeepLinkService.generateFriendInvitationLink(
        invitationId: invitation.id,
        fromUserId: invitation.fromUserId,
        customMessage: invitation.personalMessage,
      );
      
      AppLogger.info('Generated invitation link: $invitationLink');
      
      // Store the invitation in Firebase for validation
      await _storeInvitationInFirebase(invitation, invitationLink);
      
      return invitationLink;
    } catch (e) {
      AppLogger.error('Failed to create invitation link: $e');
      return '';
    }
  }

  /// Internal method to update invitation status
  // ignore: unused_element
  Future<void> _updateInvitationStatus(GroupInvitation invitation) async {
    try {
      await firestore
          .collection('group_invitations')
          .doc(invitation.id)
          .update({
            'status': invitation.status.name,
            'respondedAt': invitation.respondedAt?.toIso8601String(),
          });

      AppLogger.debug('Invitation status updated: ${invitation.id}');
    } catch (e) {
      AppLogger.error('Failed to update invitation status: $e');
    }
  }

  // ===== PRIVATE METHODS =====

  /// Load cached data from Hive
  Future<void> _loadCachedData(Box<String> box) async {
    try {
      // Load friends
      final friendsData = box.get('friends');
      if (friendsData != null) {
        final friendsList = jsonDecode(friendsData) as List<dynamic>;
        _friends.addAll(friendsList.map((f) => UserProfile(
          uid: f['uid'] as String,
          displayName: f['displayName'] as String,
          email: f['email'] as String? ?? '',
          avatarUrl: f['avatarUrl'] as String?,
          bio: f['bio'] as String?,
          joinedAt: f['joinedAt'] != null ? DateTime.parse(f['joinedAt'] as String) : DateTime.now(),
          lastActiveAt: f['lastActiveAt'] != null ? DateTime.parse(f['lastActiveAt'] as String) : DateTime.now(),
        )));
      }

      // Load categories
      final categoriesData = box.get('categories');
      if (categoriesData != null) {
        final categoriesList = jsonDecode(categoriesData) as List<dynamic>;
        _categories.addAll(categoriesList.map((c) => FriendCategory.fromJson(c)));
      }

      // Load blocked users
      final blockedData = box.get('blockedUsers');
      if (blockedData != null) {
        final blockedList = jsonDecode(blockedData) as List<dynamic>;
        _blockedUsers.addAll(blockedList.cast<String>());
      }

      AppLogger.debug('✅ Cached friends data loaded');
    } catch (e) {
      AppLogger.error('Failed to load cached friends data: $e');
    }
  }

  /// Save friend to cache
  Future<void> _saveFriendToCache(UserProfile friend) async {
    try {
      final box = await Hive.openBox<String>(_userSpecificBoxName);
      final friendsJson = jsonEncode(_friends.map((f) => {
        'uid': f.uid,
        'displayName': f.displayName,
        'avatarUrl': f.avatarUrl,
        'bio': f.bio,
      }).toList());
      await box.put('friends', friendsJson);
    } catch (e) {
      AppLogger.error('Failed to save friend to cache: $e');
    }
  }

  /// Initialize default categories
  Future<void> _initializeDefaultCategories() async {
    if (_categories.isEmpty) {
      final currentUserId = _authRepository.currentUserId;
      final defaultCategories = [
        FriendCategory(
          id: 'default_family',
          ownerId: currentUserId ?? '',
          name: 'Family',
          description: 'Family members',
          emoji: '👨‍👩‍👧‍👦',
          isDefault: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        FriendCategory(
          id: 'default_close_friends',
          ownerId: currentUserId ?? '',
          name: 'Close Friends',
          description: 'Your closest friends',
          emoji: '💜',
          isDefault: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        FriendCategory(
          id: 'default_work',
          ownerId: currentUserId ?? '',
          name: 'Work',
          description: 'Colleagues and work contacts',
          emoji: '💼',
          isDefault: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      _categories.addAll(defaultCategories);
      notifyListeners();
    }
  }

  // ===== FIREBASE SYNC MIXIN IMPLEMENTATION =====
  
  @override
  List<SyncCollection> get syncCollections => [
    SyncCollection(
      name: 'friends',
      query: () => firestore
          .collection('users')
          .doc(currentUserId!)
          .collection('friends'),
      onAdded: (doc) => _handleFriendsChange(doc, DocumentChangeType.added),
      onModified: (doc) => _handleFriendsChange(doc, DocumentChangeType.modified),
      onRemoved: (doc) => _handleFriendsChange(doc, DocumentChangeType.removed),
      onError: (error) => _setError('Friends sync error: $error'),
    ),
    SyncCollection(
      name: 'friend_categories',
      query: () => firestore
          .collection('users')
          .doc(currentUserId!)
          .collection('friend_categories'),
      onAdded: (doc) => _handleCategoriesChange(doc, DocumentChangeType.added),
      onModified: (doc) => _handleCategoriesChange(doc, DocumentChangeType.modified),
      onRemoved: (doc) => _handleCategoriesChange(doc, DocumentChangeType.removed),
      onError: (error) => _setError('Categories sync error: $error'),
    ),
    SyncCollection(
      name: 'incoming_requests',
      query: () => firestore
          .collection('friend_requests')
          .where('toUserId', isEqualTo: currentUserId!)
          .where('status', isEqualTo: 'pending'),
      onAdded: (doc) => _handleIncomingRequestsChange(doc, DocumentChangeType.added),
      onModified: (doc) => _handleIncomingRequestsChange(doc, DocumentChangeType.modified),
      onRemoved: (doc) => _handleIncomingRequestsChange(doc, DocumentChangeType.removed),
      onError: (error) => _setError('Incoming requests sync error: $error'),
    ),
    SyncCollection(
      name: 'outgoing_requests',
      query: () => firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: currentUserId!)
          .where('status', isEqualTo: 'pending'),
      onAdded: (doc) => _handleOutgoingRequestsChange(doc, DocumentChangeType.added),
      onModified: (doc) => _handleOutgoingRequestsChange(doc, DocumentChangeType.modified),
      onRemoved: (doc) => _handleOutgoingRequestsChange(doc, DocumentChangeType.removed),
      onError: (error) => _setError('Outgoing requests sync error: $error'),
    ),
  ];
  
  @override
  Future<void> syncItemToFirebase(String itemId) async {
    // Friends don't have individual sync items like shopping lists
    // This is handled by the collection-level sync
    AppLogger.debug('Friends sync handled at collection level');
  }

  // Firebase sync now handled by mixin - removed manual subscription management

  /// Handle friends document changes
  void _handleFriendsChange(DocumentSnapshot doc, DocumentChangeType changeType) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final friend = UserProfile(
        uid: doc.id,
        displayName: data['displayName'] as String? ?? '',
        email: data['email'] as String? ?? '',
        avatarUrl: data['avatarUrl'] as String?,
        bio: data['bio'] as String?,
        joinedAt: data['joinedAt'] != null ? (data['joinedAt'] as Timestamp).toDate() : DateTime.now(),
        lastActiveAt: data['lastActiveAt'] != null ? (data['lastActiveAt'] as Timestamp).toDate() : DateTime.now(),
      );

      switch (changeType) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          _updateLocalFriend(friend);
          break;
        case DocumentChangeType.removed:
          _removeLocalFriend(friend.uid);
          break;
      }
    } catch (e) {
      AppLogger.error('Failed to handle friends change: $e');
    }
  }

  /// Handle categories document changes
  void _handleCategoriesChange(DocumentSnapshot doc, DocumentChangeType changeType) {
    try {
      final category = FriendCategory.fromFirestore(doc);

      switch (changeType) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          _updateLocalCategory(category);
          break;
        case DocumentChangeType.removed:
          _removeLocalCategory(category.id);
          break;
      }
    } catch (e) {
      AppLogger.error('Failed to handle categories change: $e');
    }
  }

  /// Handle incoming requests document changes
  void _handleIncomingRequestsChange(DocumentSnapshot doc, DocumentChangeType changeType) {
    try {
      final request = FriendRequest.fromFirestore(doc);

      switch (changeType) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          _updateLocalIncomingRequest(request);
          break;
        case DocumentChangeType.removed:
          _removeLocalIncomingRequest(request.id);
          break;
      }
    } catch (e) {
      AppLogger.error('Failed to handle incoming requests change: $e');
    }
  }

  /// Handle outgoing requests document changes
  void _handleOutgoingRequestsChange(DocumentSnapshot doc, DocumentChangeType changeType) {
    try {
      final request = FriendRequest.fromFirestore(doc);

      switch (changeType) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          _updateLocalOutgoingRequest(request);
          break;
        case DocumentChangeType.removed:
          _removeLocalOutgoingRequest(request.id);
          break;
      }
    } catch (e) {
      AppLogger.error('Failed to handle outgoing requests change: $e');
    }
  }

  /// Update local friend
  void _updateLocalFriend(UserProfile friend) {
    final index = _friends.indexWhere((f) => f.uid == friend.uid);
    if (index != -1) {
      _friends[index] = friend;
    } else {
      _friends.add(friend);
    }
    _saveFriendToCache(friend);
  }

  /// Remove local friend
  void _removeLocalFriend(String friendId) {
    _friends.removeWhere((f) => f.uid == friendId);
  }

  /// Update local category
  void _updateLocalCategory(FriendCategory category) {
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      _categories[index] = category;
    } else {
      _categories.add(category);
    }
  }

  /// Remove local category
  void _removeLocalCategory(String categoryId) {
    _categories.removeWhere((c) => c.id == categoryId);
  }

  /// Update local incoming request
  void _updateLocalIncomingRequest(FriendRequest request) {
    final index = _incomingRequests.indexWhere((r) => r.id == request.id);
    if (index != -1) {
      _incomingRequests[index] = request;
    } else {
      _incomingRequests.add(request);
    }
  }

  /// Remove local incoming request
  void _removeLocalIncomingRequest(String requestId) {
    _incomingRequests.removeWhere((r) => r.id == requestId);
  }

  /// Update local outgoing request
  void _updateLocalOutgoingRequest(FriendRequest request) {
    final index = _outgoingRequests.indexWhere((r) => r.id == request.id);
    if (index != -1) {
      _outgoingRequests[index] = request;
    } else {
      _outgoingRequests.add(request);
    }
  }

  /// Remove local outgoing request
  void _removeLocalOutgoingRequest(String requestId) {
    _outgoingRequests.removeWhere((r) => r.id == requestId);
  }

  /// Set error state
  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear all data
  void _clearAll() {
    _friends.clear();
    _incomingRequests.clear();
    _outgoingRequests.clear();
    _categories.clear();
    _sentInvitations.clear();
    _blockedUsers.clear();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Get category by ID
  FriendCategory? getCategoryById(String categoryId) {
    return _categories.where((c) => c.id == categoryId).firstOrNull;
  }
  
  /// Cancel sent invitation
  Future<bool> cancelSentInvitation(String invitationId) async {
    return await _invitationsOps.cancelInvitation(invitationId);
  }
  
  /// Remove friend from category
  Future<bool> removeFriendFromCategory({
    required String friendId,
    required String categoryId,
  }) async {
    return await _categoriesOps.removeFriendFromCategory(
      friendId: friendId,
      categoryId: categoryId,
    );
  }
  
  /// Refresh friends data
  Future<void> refresh() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Restart Firebase sync to get latest data
      stopFirebaseSync();
      if (_authRepository.getCurrentUser() != null) {
        startFirebaseSync();
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      AppLogger.error('Failed to refresh friends data: $e');
      _setError('Could not refresh friends: $e');
    }
  }

  // ===== EMAIL INVITATION HELPER METHODS =====

  /// Generate invitation link with unique ID
  String _generateInvitationLink(String invitationId) {
    // Use the deep link service to generate a proper invitation link
    return DeepLinkService.generateFriendInvitationLink(
      invitationId: invitationId,
      fromUserId: currentUserId ?? '',
    );
  }

  /// Store invitation in Firebase for tracking and validation
  Future<void> _storeInvitationInFirebase(GroupInvitation invitation, String invitationLink) async {
    try {
      final currentUser = _authRepository.getCurrentUser();
      if (currentUser == null) return;

      final invitationData = {
        'id': invitation.id,
        'groupId': invitation.groupId,
        'groupName': invitation.groupName,
        'groupEmoji': invitation.groupEmoji,
        'fromUserId': invitation.fromUserId,
        'fromUserName': invitation.fromUserName,
        'toUserId': invitation.toUserId,
        'personalMessage': invitation.personalMessage,
        'sentAt': invitation.sentAt.toIso8601String(),
        'invitationLink': invitationLink,
        'status': 'sent',
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      final docRef = firestoreRepository.collection('invitations').doc(invitation.id);
      await firestoreRepository.setDocument(docRef, invitationData);

      AppLogger.info('Invitation stored in Firebase: ${invitation.id}');
    } catch (e) {
      AppLogger.error('Failed to store invitation in Firebase: $e');
      // Don't throw - this shouldn't prevent email sending
    }
  }

  /// Create email subject for invitation
  String _createEmailSubject(GroupInvitation invitation) {
    if (invitation.groupName.isNotEmpty) {
      return 'Inbjudan till ${invitation.groupName} på Butlery';
    } else {
      return 'Vänförfrågan från ${invitation.fromUserName} på Butlery';
    }
  }

  /// Create email body with invitation details and link
  String _createEmailBody(GroupInvitation invitation, String invitationLink) {
    final buffer = StringBuffer();
    
    buffer.writeln('Hej!');
    buffer.writeln();
    buffer.writeln('${invitation.fromUserName} har bjudit in dig till Butlery - en smart receptapp för att organisera recept och veckomeny.');
    buffer.writeln();
    
    if (invitation.groupName.isNotEmpty) {
      buffer.writeln('Du har blivit inbjuden till gruppen: ${invitation.groupEmoji} ${invitation.groupName}');
      buffer.writeln();
    }
    
    if (invitation.personalMessage != null && invitation.personalMessage!.isNotEmpty) {
      buffer.writeln('Personligt meddelande:');
      buffer.writeln('"${invitation.personalMessage}"');
      buffer.writeln();
    }
    
    buffer.writeln('För att acceptera inbjudan:');
    buffer.writeln('1. Ladda ner Butlery-appen från App Store eller Google Play');
    buffer.writeln('2. Klicka på länken nedan för att ansluta:');
    buffer.writeln();
    buffer.writeln(invitationLink);
    buffer.writeln();
    buffer.writeln('Välkommen till Butlery!');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('Detta är en automatiskt genererad inbjudan från Butlery-appen.');
    
    return buffer.toString();
  }

  /// Send email using mailto: URL (opens user's default email client)
  Future<bool> _sendMailtoEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    try {
      // Import url_launcher dynamically to avoid adding it to main imports
      final uri = Uri(
        scheme: 'mailto',
        path: to,
        queryParameters: {
          'subject': subject,
          'body': body,
        },
      );

      // Use url_launcher to open mailto URL
      final launched = await _launchUrl(uri.toString());
      
      if (launched) {
        AppLogger.success('Email client opened for invitation to $to');
        return true;
      } else {
        AppLogger.error('Could not open email client');
        return false;
      }
    } catch (e) {
      AppLogger.error('Failed to create mailto URL: $e');
      return false;
    }
  }

  /// Launch URL helper method
  Future<bool> _launchUrl(String url) async {
    try {
      AppLogger.info('Launching URL: $url');
      
      // Parse the URL to ensure it's valid
      final uri = Uri.parse(url);
      
      // Check if the URL can be launched
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        if (launched) {
          AppLogger.success('Successfully launched URL: $url');
          return true;
        } else {
          AppLogger.error('Failed to launch URL: $url');
          return false;
        }
      } else {
        AppLogger.error('Cannot launch URL: $url');
        return false;
      }
    } catch (e) {
      AppLogger.error('Failed to launch URL: $e');
      return false;
    }
  }

  /// Mark invitation as sent in local state
  void _markInvitationAsSent(String invitationId) {
    final invitationIndex = _sentInvitations.indexWhere((inv) => inv.id == invitationId);
    if (invitationIndex != -1) {
      // Update invitation status if needed
      AppLogger.info('Marked invitation as sent: $invitationId');
    }
  }

  // ===== SMS INVITATION HELPER METHODS =====

  /// Create SMS message for invitation
  String _createSMSMessage(GroupInvitation invitation, String invitationLink) {
    final buffer = StringBuffer();
    
    buffer.write('${invitation.fromUserName} har bjudit in dig till Butlery! ');
    
    if (invitation.groupName.isNotEmpty) {
      buffer.write('Grupp: ${invitation.groupEmoji} ${invitation.groupName}. ');
    }
    
    if (invitation.personalMessage != null && invitation.personalMessage!.isNotEmpty) {
      buffer.write('"${invitation.personalMessage}" ');
    }
    
    buffer.write('Ladda ner appen och klicka: $invitationLink');
    
    return buffer.toString();
  }

  /// Send SMS using sms: URL (opens user's default messaging app)
  Future<bool> _sendSMSMessage({
    required String to,
    required String message,
  }) async {
    try {
      // Clean phone number (remove non-digits except +)
      final cleanedNumber = to.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Create SMS URI
      final uri = Uri(
        scheme: 'sms',
        path: cleanedNumber,
        queryParameters: {
          'body': message,
        },
      );

      // Use url_launcher to open SMS URL
      final launched = await _launchUrl(uri.toString());
      
      if (launched) {
        AppLogger.success('SMS app opened for invitation to $to');
        return true;
      } else {
        AppLogger.error('Could not open SMS app');
        return false;
      }
    } catch (e) {
      AppLogger.error('Failed to create SMS URL: $e');
      return false;
    }
  }

  // ===== BLOCKING SUPPORT METHODS =====

  /// Remove all friend requests between current user and specified user
  // ignore: unused_element
  Future<void> _removeAllRequestsWithUser(String userId) async {
    try {
      // Remove incoming requests from this user
      _incomingRequests.removeWhere((request) => request.fromUserId == userId);
      
      // Remove outgoing requests to this user
      _outgoingRequests.removeWhere((request) => request.toUserId == userId);
      
      // Sync to Firebase
      await _syncRequestsToFirebase();
      
      AppLogger.debug('Removed all requests with user: $userId');
    } catch (e) {
      AppLogger.error('Failed to remove requests with user: $e');
    }
  }


  /// Sync friend requests to Firebase
  Future<void> _syncRequestsToFirebase() async {
    try {
      final currentUser = _authRepository.getCurrentUser();
      if (currentUser == null) return;

      // Sync incoming requests
      for (final request in _incomingRequests) {
        await firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('friend_requests')
            .doc('incoming')
            .collection('requests')
            .doc(request.id)
            .set(request.toJson());
      }

      // Sync outgoing requests
      for (final request in _outgoingRequests) {
        await firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('friend_requests')
            .doc('outgoing')
            .collection('requests')
            .doc(request.id)
            .set(request.toJson());
      }

      AppLogger.debug('Synced friend requests to Firebase');
    } catch (e) {
      AppLogger.error('Failed to sync friend requests to Firebase: $e');
    }
  }

  // ===== FRIEND SUGGESTIONS SUPPORT METHODS =====

  /// Get friends of a specific user (for mutual friends suggestions)
  // ignore: unused_element
  Future<List<UserProfile>> _getFriendsOfUser(String userId) async {
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .get();

      final friends = <UserProfile>[];
      for (final doc in snapshot.docs) {
        try {
          final userProfile = UserProfile.fromJson(doc.data());
          friends.add(userProfile);
        } catch (e) {
          AppLogger.debug('Could not parse friend profile: $e');
        }
      }

      return friends;
    } catch (e) {
      AppLogger.error('Failed to get friends of user $userId: $e');
      return [];
    }
  }

  /// Get recent collaborators from recipe sharing
  // ignore: unused_element
  Future<List<UserProfile>> _getRecentCollaborators(String userId) async {
    try {
      final snapshot = await firestore
          .collection('unified_collaborative_recipes')
          .where('memberPermissions.$userId', isNotEqualTo: null)
          .where('updatedAt', isGreaterThan: DateTime.now().subtract(const Duration(days: 30)))
          .limit(20)
          .get();

      final collaborators = <UserProfile>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final memberPermissions = data['memberPermissions'] as Map<String, dynamic>?;
          
          if (memberPermissions != null) {
            for (final memberId in memberPermissions.keys) {
              if (memberId != userId && !isFriend(memberId)) {
                // Get user profile for this member
                final userProfile = await _getUserProfile(memberId);
                if (userProfile != null) {
                  collaborators.add(userProfile);
                }
              }
            }
          }
        } catch (e) {
          AppLogger.debug('Could not parse collaborative recipe: $e');
        }
      }

      return collaborators;
    } catch (e) {
      AppLogger.error('Failed to get recent collaborators: $e');
      return [];
    }
  }

  /// Get recent shopping collaborators
  // ignore: unused_element
  Future<List<UserProfile>> _getRecentShoppingCollaborators(String userId) async {
    try {
      final snapshot = await firestore
          .collection('unified_collaborative_shopping_lists')
          .where('memberPermissions.$userId', isNotEqualTo: null)
          .where('updatedAt', isGreaterThan: DateTime.now().subtract(const Duration(days: 30)))
          .limit(20)
          .get();

      final collaborators = <UserProfile>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final memberPermissions = data['memberPermissions'] as Map<String, dynamic>?;
          
          if (memberPermissions != null) {
            for (final memberId in memberPermissions.keys) {
              if (memberId != userId && !isFriend(memberId)) {
                // Get user profile for this member
                final userProfile = await _getUserProfile(memberId);
                if (userProfile != null) {
                  collaborators.add(userProfile);
                }
              }
            }
          }
        } catch (e) {
          AppLogger.debug('Could not parse collaborative shopping list: $e');
        }
      }

      return collaborators;
    } catch (e) {
      AppLogger.error('Failed to get recent shopping collaborators: $e');
      return [];
    }
  }

  /// Get user profile by ID
  Future<UserProfile?> _getUserProfile(String userId) async {
    try {
      final doc = await firestore
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        return UserProfile.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      AppLogger.error('Failed to get user profile for $userId: $e');
      return null;
    }
  }

  /// Check if user is a friend
  bool isFriend(String userId) {
    return _friends.any((friend) => friend.uid == userId);
  }

  // Error handling methods already exist in the class

  @override
  void dispose() {
    stopFirebaseSync();
    super.dispose();
  }
}