// lib/services/unified/friends/friends_state_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';
import 'package:butlery/repositories/firebase/friends/friend_category_repository.dart';
import 'package:butlery/repositories/firebase/firebase_block_repository.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

/// Consolidated friends state manager handling all friend-related state with real-time synchronization
class FriendsStateManager extends ChangeNotifier {
  final FirebaseFriendsRepository _repository;
  final FriendCategoryRepository _categoryRepository;
  final FirebaseBlockRepository _blockRepository;

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
  StreamSubscription? _memberCategoriesSubscription; // BUG-018 FIX
  StreamSubscription? _friendsSubscription;

  StreamSubscription? _blockedUsersSubscription;

  FriendsStateManager({
    required FirebaseFriendsRepository repository,
    required FriendCategoryRepository categoryRepository,
    required FirebaseBlockRepository blockRepository,
  })  : _repository = repository,
        _categoryRepository = categoryRepository,
        _blockRepository = blockRepository;

  List<UserProfile> get friends => List.unmodifiable(_friends);
  List<FriendRequest> get incomingRequests =>
      List.unmodifiable(_incomingRequests);
  List<FriendRequest> get outgoingRequests =>
      List.unmodifiable(_outgoingRequests);
  List<FriendCategory> get categories => List.unmodifiable(_categories);
  List<GroupInvitation> get sentInvitations =>
      List.unmodifiable(_sentInvitations);
  List<GroupInvitation> get receivedInvitations =>
      List.unmodifiable(_receivedInvitations);
  Set<String> get blockedUsers => Set.unmodifiable(_blockedUsers);
  Map<String, Set<String>> get friendCategoryRelationships =>
      <String, Set<String>>{};

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
        _loadBlockedUsers(currentUserId),
      ]);

      _setupRealtimeListeners(currentUserId);

      _isInitialized = true;
      _isLoading = false;
    } catch (e, stackTrace) {
      _error = 'Failed to load friends data: $e';
      _isLoading = false;
      AppLogger.error(
          '❌ Failed to initialize FriendsStateManager: $e', stackTrace);
    }

    notifyListeners();
  }

  Future<void> _loadFriends(String userId) async {
    try {
      final friendIds = await _repository.fetchFriendIds(userId);

      if (friendIds.isNotEmpty) {
        final filteredFriendIds =
            friendIds.where((id) => id != userId).toList();

        if (filteredFriendIds.isNotEmpty) {
          final friendProfiles =
              await _repository.fetchFriendProfiles(filteredFriendIds);
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

      AppLogger.debug(
          'Loaded ${_incomingRequests.length} incoming requests, ${_outgoingRequests.length} outgoing requests');
    } catch (e) {
      AppLogger.warning('Failed to load friend requests: $e');
      _incomingRequests = [];
      _outgoingRequests = [];
    }
  }

  Future<void> _loadCategories(String userId) async {
    try {
      // BUG-018 FIX: Use fetchMemberCategories to get ALL categories where user
      // is a member (across all users' collections), not just categories they own
      _categories = await _categoryRepository.fetchMemberCategories(userId);
      AppLogger.debug(
          'Loaded ${_categories.length} member categories (BUG-018 fix)');
    } catch (e) {
      AppLogger.warning('Failed to load categories: $e');
      _categories = [];
    }
  }

  Future<void> _loadGroupInvitations(String userId) async {
    try {
      final receivedInvitations =
          await _repository.fetchReceivedInvitations(userId);
      _receivedInvitations = receivedInvitations;

      final sentInvitations = await _repository.fetchSentInvitations(userId);
      _sentInvitations = sentInvitations;
    } catch (e) {
      _receivedInvitations = [];
      _sentInvitations = [];
    }
  }

  Future<void> _loadBlockedUsers(String userId) async {
    try {
      final blocked = await _blockRepository.getBlockedUserIds();
      _blockedUsers
        ..clear()
        ..addAll(blocked);
      AppLogger.debug(
          'Loaded ${_blockedUsers.length} blocked users from blocks collection');
    } catch (e) {
      AppLogger.warning('Failed to load blocked users: $e');
    }
  }

  void clearAllData() {
    _incomingRequestsSubscription?.cancel();
    _sentRequestsSubscription?.cancel();
    _groupInvitationsSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _memberCategoriesSubscription?.cancel(); // BUG-018 FIX
    _friendsSubscription?.cancel();
    _blockedUsersSubscription?.cancel();

    _incomingRequestsSubscription = null;
    _sentRequestsSubscription = null;
    _groupInvitationsSubscription = null;
    _categoriesSubscription = null;
    _memberCategoriesSubscription = null; // BUG-018 FIX
    _friendsSubscription = null;
    _blockedUsersSubscription = null;

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
      _memberCategoriesSubscription?.cancel(); // BUG-018 FIX
      _friendsSubscription?.cancel();
      _blockedUsersSubscription?.cancel();
      AppLogger.debug(
          '🧹 Cancelled existing real-time listeners before setting up new ones');

      _incomingRequestsSubscription =
          _repository.incomingRequestsStream(userId).listen(
        (requests) {
          _incomingRequests = requests;
          AppLogger.debug(
              'Real-time update: ${_incomingRequests.length} incoming requests');
          notifyListeners();
        },
        onError: (e) {
          AppLogger.warning('Incoming requests stream error: $e');
        },
      );

      _sentRequestsSubscription = _repository.sentRequestsStream(userId).listen(
        (requests) {
          _outgoingRequests = requests;
          AppLogger.debug(
              'Real-time update: ${_outgoingRequests.length} outgoing requests');
          notifyListeners();
        },
        onError: (e) {
          AppLogger.warning('Sent requests stream error: $e');
        },
      );

      // BUG-017 FIX: Use helper method with retry support for Firestore assertion errors
      _setupGroupInvitationsStream(userId);

      // BUG-018 FIX: Use retry-capable method for categories stream
      _setupCategoriesStream(userId);

      // BUG-011 fix: Add real-time stream for friends list
      // This ensures User A sees User B in friends list immediately when User B accepts
      _friendsSubscription = _repository.friendProfilesStream(userId).listen(
        (friendProfiles) {
          _friends = friendProfiles;
          AppLogger.debug('Real-time update: ${_friends.length} friends');
          notifyListeners();
        },
        onError: (e) {
          AppLogger.warning('Friends stream error: $e');
        },
      );

      _blockedUsersSubscription = _blockRepository.watchBlockedUserIds().listen(
        (blockedIds) {
          _blockedUsers
            ..clear()
            ..addAll(blockedIds);
          AppLogger.debug(
              'Real-time update: ${_blockedUsers.length} blocked users');
          notifyListeners();
        },
        onError: (e) {
          AppLogger.warning('Blocked users stream error: $e');
        },
      );
    } catch (e) {
      AppLogger.warning('Failed to setup real-time listeners: $e');
    }
  }

  /// BUG-017 FIX: Separate method for setting up invitation stream with retry support
  /// Limited to 3 retries to prevent infinite retry loops
  void _setupGroupInvitationsStream(String userId, {int retryCount = 0}) {
    const maxRetries = 3;
    _groupInvitationsSubscription?.cancel();
    _groupInvitationsSubscription =
        _repository.receivedInvitationsStream(userId).listen(
      (invitations) {
        _receivedInvitations = invitations;
        AppLogger.debug(
            'Real-time update: ${invitations.length} received invitations');
        notifyListeners();
      },
      onError: (e) {
        final errorString = e.toString();
        // BUG-017 FIX: Handle Firestore SDK assertion errors with limited retries
        if (errorString.contains('INTERNAL ASSERTION') ||
            errorString.contains('Unexpected state')) {
          if (retryCount < maxRetries) {
            AppLogger.warning(
                '⚠️ Firestore assertion in invitations stream, retry ${retryCount + 1}/$maxRetries...');
            _groupInvitationsSubscription?.cancel();
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_isInitialized) {
                _setupGroupInvitationsStream(userId,
                    retryCount: retryCount + 1);
              }
            });
          } else {
            AppLogger.error(
                '❌ Max retries exceeded for invitations stream after $maxRetries attempts');
          }
        } else {
          AppLogger.warning('Group invitations stream error: $e');
        }
      },
    );
  }

  /// BUG-018 FIX: Separate method for setting up categories stream with retry support
  /// Limited to 3 retries to prevent infinite retry loops
  ///
  /// Uses TWO streams and merges results:
  /// 1. categoriesStream(userId) - categories the user OWNS
  /// 2. memberCategoriesStream(userId) - categories where user is a MEMBER (not owner)
  void _setupCategoriesStream(String userId, {int retryCount = 0}) {
    const maxRetries = 3;
    _categoriesSubscription?.cancel();

    // BUG-018 FIX: Pre-populate from existing _categories to avoid race condition
    // When refresh() calls _loadCategories first, the streams may fire with stale
    // data before both have updated. Pre-populating ensures we don't lose data
    // when only one stream fires initially after a refresh.
    List<FriendCategory> ownedCategories =
        _categories.where((cat) => cat.ownerId == userId).toList();
    List<FriendCategory> memberCategories =
        _categories.where((cat) => cat.ownerId != userId).toList();

    void mergeAndNotify() {
      // Combine both lists, avoiding duplicates by ID
      final allCategories = <String, FriendCategory>{};
      for (final cat in ownedCategories) {
        allCategories[cat.id] = cat;
      }
      for (final cat in memberCategories) {
        allCategories[cat.id] = cat;
      }
      _categories = allCategories.values.toList();
      AppLogger.debug(
          'Real-time update: ${_categories.length} categories (${ownedCategories.length} owned + ${memberCategories.length} member, BUG-018 fix)');
      notifyListeners();
    }

    // Stream 1: Categories user OWNS
    _categoriesSubscription =
        _categoryRepository.categoriesStream(userId).listen(
      (categories) {
        ownedCategories = categories;
        mergeAndNotify();
      },
      onError: (e) {
        final errorString = e.toString();
        if (errorString.contains('INTERNAL ASSERTION') ||
            errorString.contains('Unexpected state')) {
          if (retryCount < maxRetries) {
            AppLogger.warning(
                '⚠️ Firestore assertion in owned categories stream, retry ${retryCount + 1}/$maxRetries...');
            _categoriesSubscription?.cancel();
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_isInitialized) {
                _setupCategoriesStream(userId, retryCount: retryCount + 1);
              }
            });
          } else {
            AppLogger.error(
                '❌ Max retries exceeded for owned categories stream after $maxRetries attempts');
          }
        } else {
          AppLogger.warning('Owned categories stream error: $e');
        }
      },
    );

    // Stream 2: Categories where user is a MEMBER (not owner) - BUG-018 FIX
    _memberCategoriesSubscription?.cancel();
    _memberCategoriesSubscription =
        _categoryRepository.memberCategoriesStream(userId).listen(
      (categories) {
        memberCategories = categories;
        mergeAndNotify();
      },
      onError: (e) {
        AppLogger.warning('Member categories stream error: $e');
      },
    );
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
      AppLogger.debug(
          'Added friend to state: ${friend.displayName} (${friend.uid})');
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
      AppLogger.debug('Added blocked user to state: ${userId.maskedUserId}');
      notifyListeners();
    }
  }

  void removeBlockedUser(String userId) {
    if (_blockedUsers.remove(userId)) {
      AppLogger.debug('Removed blocked user from state: ${userId.maskedUserId}');
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

  void updateReceivedInvitation(
      String invitationId, GroupInvitation invitation) {
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
    _memberCategoriesSubscription?.cancel(); // BUG-018 FIX
    _friendsSubscription?.cancel();

    _incomingRequestsSubscription = null;
    _sentRequestsSubscription = null;
    _groupInvitationsSubscription = null;
    _categoriesSubscription = null;
    _memberCategoriesSubscription = null; // BUG-018 FIX
    _friendsSubscription = null;

    AppLogger.debug(
        'FriendsStateManager disposed - cleaned up ${_friends.length} friends data');
    super.dispose();
  }
}
