// lib/services/unified/friends/friends_state_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';
import 'package:butlery/repositories/firebase/friends/friend_category_repository.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/core/utils/logger.dart';

/// Consolidated friends state manager handling all friend-related state with real-time synchronization
class FriendsStateManager extends ChangeNotifier {
  final FirebaseFriendsRepository _repository;
  final FriendCategoryRepository _categoryRepository;

  // Internal state
  List<UserProfile> _friends = [];
  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> _outgoingRequests = [];
  List<FriendCategory> _categories = [];
  List<GroupInvitation> _sentInvitations = [];
  List<GroupInvitation> _receivedInvitations = [];
  final Set<String> _blockedUsers = <String>{};
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  StreamSubscription? _incomingRequestsSubscription;
  StreamSubscription? _sentRequestsSubscription;
  StreamSubscription? _groupInvitationsSubscription;
  StreamSubscription? _categoriesSubscription;

  FriendsStateManager({
    required FirebaseFriendsRepository repository,
    required FriendCategoryRepository categoryRepository,
  }) : _repository = repository,
       _categoryRepository = categoryRepository;

  List<UserProfile> get friends => List.unmodifiable(_friends);
  List<FriendRequest> get incomingRequests => List.unmodifiable(_incomingRequests);
  List<FriendRequest> get outgoingRequests => List.unmodifiable(_outgoingRequests);
  List<FriendCategory> get categories => List.unmodifiable(_categories);
  List<GroupInvitation> get sentInvitations => List.unmodifiable(_sentInvitations);
  List<GroupInvitation> get receivedInvitations => List.unmodifiable(_receivedInvitations);
  Set<String> get blockedUsers => Set.unmodifiable(_blockedUsers);
  Map<String, Set<String>> get friendCategoryRelationships => <String, Set<String>>{};

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final currentUserId = _repository.currentUserId;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      await Future.wait([
        _loadFriends(currentUserId),
        _loadFriendRequests(),
        _loadCategories(currentUserId),
        _loadGroupInvitations(currentUserId),
      ]);

      _setupRealtimeListeners(currentUserId);

      _isInitialized = true;
      _isLoading = false;

    } catch (e, stackTrace) {
      _error = 'Failed to load friends data: $e';
      _isLoading = false;
      AppLogger.error('❌ Failed to initialize FriendsStateManager: $e', stackTrace);
    }

    notifyListeners();
  }

  Future<void> _loadFriends(String userId) async {
    try {
      final friendIds = await _repository.fetchFriendIds(userId);

      if (friendIds.isNotEmpty) {
        final filteredFriendIds = friendIds.where((id) => id != userId).toList();

        if (filteredFriendIds.isNotEmpty) {
          final friendProfiles = await _repository.fetchFriendProfiles(filteredFriendIds);
          _friends = friendProfiles;
          } else {
          _friends = [];
        }
      } else {
        _friends = [];
      }
    } catch (e) {
      AppLogger.warning('Failed to load friends: $e');
      _friends = [];
    }
  }

  Future<void> _loadFriendRequests() async {
    try {
      final incomingFuture = _repository.getIncomingRequests();
      final outgoingFuture = _repository.getSentRequests();

      final results = await Future.wait([incomingFuture, outgoingFuture]);

      _incomingRequests = results[0];
      _outgoingRequests = results[1];

      AppLogger.debug('Loaded ${_incomingRequests.length} incoming requests, ${_outgoingRequests.length} outgoing requests');
    } catch (e) {
      AppLogger.warning('Failed to load friend requests: $e');
      _incomingRequests = [];
      _outgoingRequests = [];
    }
  }

  Future<void> _loadCategories(String userId) async {
    try {
      _categories = await _categoryRepository.fetchCategories(userId);
      AppLogger.debug('Loaded ${_categories.length} categories using FriendCategoryRepository');
    } catch (e) {
      AppLogger.warning('Failed to load categories: $e');
      _categories = [];
    }
  }

  Future<void> _loadGroupInvitations(String userId) async {
    try {
      final receivedInvitations = await _repository.fetchReceivedInvitations(userId);
      _receivedInvitations = receivedInvitations;

      final sentInvitations = await _repository.fetchSentInvitations(userId);
      _sentInvitations = sentInvitations;
    } catch (e) {
      _receivedInvitations = [];
      _sentInvitations = [];
    }
  }

  void clearAllData() {

    _incomingRequestsSubscription?.cancel();
    _sentRequestsSubscription?.cancel();
    _groupInvitationsSubscription?.cancel();
    _categoriesSubscription?.cancel();

    _incomingRequestsSubscription = null;
    _sentRequestsSubscription = null;
    _groupInvitationsSubscription = null;
    _categoriesSubscription = null;

    _friends.clear();
    _incomingRequests.clear();
    _outgoingRequests.clear();
    _categories.clear();
    _sentInvitations.clear();
    _receivedInvitations.clear();
    _blockedUsers.clear();

    _isInitialized = false;
    _isLoading = false;
    _error = null;

    notifyListeners();
  }

  void _setupRealtimeListeners(String userId) {
    try {
      _incomingRequestsSubscription?.cancel();
      _sentRequestsSubscription?.cancel();
      _groupInvitationsSubscription?.cancel();
      _categoriesSubscription?.cancel();
      AppLogger.debug('🧹 Cancelled existing real-time listeners before setting up new ones');

      _incomingRequestsSubscription = _repository.incomingRequestsStream(userId).listen(
        (requests) {
          _incomingRequests = requests;
          AppLogger.debug('Real-time update: ${_incomingRequests.length} incoming requests');
          notifyListeners();
        },
        onError: (e) {
          AppLogger.warning('Incoming requests stream error: $e');
        },
      );

      _sentRequestsSubscription = _repository.sentRequestsStream(userId).listen(
        (requests) {
          _outgoingRequests = requests;
          AppLogger.debug('Real-time update: ${_outgoingRequests.length} outgoing requests');
          notifyListeners();
        },
        onError: (e) {
          AppLogger.warning('Sent requests stream error: $e');
        },
      );

      _groupInvitationsSubscription = _repository.receivedInvitationsStream(userId).listen(
        (invitations) {
          _receivedInvitations = invitations;
          notifyListeners();
        },
        onError: (e) {
          AppLogger.warning('Group invitations stream error: $e');
        },
      );

      _categoriesSubscription = _categoryRepository.categoriesStream(userId).listen(
        (categories) {
          _categories = categories;
          AppLogger.debug('Real-time update: ${_categories.length} categories');
          notifyListeners();
        },
        onError: (e) {
          AppLogger.warning('Categories stream error: $e');
        },
      );

    } catch (e) {
      AppLogger.warning('Failed to setup real-time listeners: $e');
    }
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (!_isInitialized) {
      await initialize();
      return;
    }

    final currentUserId = _repository.currentUserId;
    if (currentUserId == null) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadFriends(currentUserId),
        _loadFriendRequests(),
        _loadCategories(currentUserId),
        _loadGroupInvitations(currentUserId),
      ]);

      _isLoading = false;
    } catch (e) {
      _error = 'Failed to refresh friends data: $e';
      _isLoading = false;
      AppLogger.error('❌ Failed to refresh friends data: $e');
    }

    notifyListeners();
  }

  Map<String, Set<String>> get relationshipsInternal => <String, Set<String>>{};
  dynamic getCategoryById(String categoryId) {
    return _categories.where((c) => c.id == categoryId).firstOrNull;
  }

  void addFriend(UserProfile friend) {
    if (!_friends.any((f) => f.uid == friend.uid)) {
      _friends.add(friend);
      AppLogger.debug('Added friend to state: ${friend.displayName} (${friend.uid})');
      notifyListeners();
    }
  }

  void removeFriend(String friendId) {
    final initialLength = _friends.length;
    _friends.removeWhere((f) => f.uid == friendId);
    if (_friends.length < initialLength) {
      AppLogger.debug('Removed friend from state: $friendId');
      notifyListeners();
    }
  }

  void addIncomingRequest(FriendRequest request) {
    if (!_incomingRequests.any((r) => r.id == request.id)) {
      _incomingRequests.add(request);
      AppLogger.debug('Added incoming request to state: ${request.id}');
      notifyListeners();
    }
  }

  void removeIncomingRequest(String requestId) {
    final initialLength = _incomingRequests.length;
    _incomingRequests.removeWhere((r) => r.id == requestId);
    if (_incomingRequests.length < initialLength) {
      AppLogger.debug('Removed incoming request from state: $requestId');
      notifyListeners();
    }
  }

  void addOutgoingRequest(FriendRequest request) {
    if (!_outgoingRequests.any((r) => r.id == request.id)) {
      _outgoingRequests.add(request);
      AppLogger.debug('Added outgoing request to state: ${request.id}');
      notifyListeners();
    }
  }

  void removeOutgoingRequest(String requestId) {
    final initialLength = _outgoingRequests.length;
    _outgoingRequests.removeWhere((r) => r.id == requestId);
    if (_outgoingRequests.length < initialLength) {
      AppLogger.debug('Removed outgoing request from state: $requestId');
      notifyListeners();
    }
  }

  void addBlockedUser(String userId) {
    if (_blockedUsers.add(userId)) {
      AppLogger.debug('Added blocked user to state: $userId');
      notifyListeners();
    }
  }

  void removeBlockedUser(String userId) {
    if (_blockedUsers.remove(userId)) {
      AppLogger.debug('Removed blocked user from state: $userId');
      notifyListeners();
    }
  }

  void addCategory(FriendCategory category) {
    if (!_categories.any((c) => c.id == category.id)) {
      _categories.add(category);
      AppLogger.debug('Added category to state: ${category.name}');
      notifyListeners();
    }
  }

  void updateCategory(String categoryId, FriendCategory category) {
    final index = _categories.indexWhere((c) => c.id == categoryId);
    if (index != -1) {
      _categories[index] = category;
      AppLogger.debug('Updated category in state: ${category.name}');
      notifyListeners();
    }
  }

  void removeCategory(String categoryId) {
    final initialLength = _categories.length;
    _categories.removeWhere((c) => c.id == categoryId);
    if (_categories.length < initialLength) {
      AppLogger.debug('Removed category from state: $categoryId');
      notifyListeners();
    }
  }

  void addSentInvitation(GroupInvitation invitation) {
    if (!_sentInvitations.any((i) => i.id == invitation.id)) {
      _sentInvitations.add(invitation);
      AppLogger.debug('Added sent invitation to state: ${invitation.id}');
      notifyListeners();
    }
  }

  void updateSentInvitation(String invitationId, GroupInvitation invitation) {
    final index = _sentInvitations.indexWhere((i) => i.id == invitationId);
    if (index != -1) {
      _sentInvitations[index] = invitation;
      AppLogger.debug('Updated sent invitation in state: $invitationId');
      notifyListeners();
    }
  }

  void removeSentInvitation(String invitationId) {
    final initialLength = _sentInvitations.length;
    _sentInvitations.removeWhere((i) => i.id == invitationId);
    if (_sentInvitations.length < initialLength) {
      AppLogger.debug('Removed sent invitation from state: $invitationId');
      notifyListeners();
    }
  }

  void addReceivedInvitation(GroupInvitation invitation) {
    if (!_receivedInvitations.any((i) => i.id == invitation.id)) {
      _receivedInvitations.add(invitation);
      AppLogger.debug('Added received invitation to state: ${invitation.id}');
      notifyListeners();
    }
  }

  void updateReceivedInvitation(String invitationId, GroupInvitation invitation) {
    final index = _receivedInvitations.indexWhere((i) => i.id == invitationId);
    if (index != -1) {
      _receivedInvitations[index] = invitation;
      AppLogger.debug('Updated received invitation in state: $invitationId');
      notifyListeners();
    }
  }

  void removeReceivedInvitation(String invitationId) {
    final initialLength = _receivedInvitations.length;
    _receivedInvitations.removeWhere((i) => i.id == invitationId);
    if (_receivedInvitations.length < initialLength) {
      AppLogger.debug('Removed received invitation from state: $invitationId');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _incomingRequestsSubscription?.cancel();
    _sentRequestsSubscription?.cancel();
    _groupInvitationsSubscription?.cancel();
    _categoriesSubscription?.cancel();

    _incomingRequestsSubscription = null;
    _sentRequestsSubscription = null;
    _groupInvitationsSubscription = null;
    _categoriesSubscription = null;

    AppLogger.debug('FriendsStateManager disposed - cleaned up ${_friends.length} friends data');
    super.dispose();
  }
}
