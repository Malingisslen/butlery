import 'package:meta/meta.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';
import 'package:butlery/repositories/firebase/friends/friend_category_repository.dart';
import 'package:butlery/services/unified/friends/friends_state_manager.dart';
import 'package:butlery/services/unified/friends/friends_internal_operations.dart';
import 'package:butlery/services/unified/friends/friends_firebase_sync.dart';

/// The `*Internal` methods the operations classes are handed as tear-offs.
/// A mixin rather than a separate object, so the methods stay on the service
/// itself and test doubles that stub them still match.
mixin FriendsInternalPort {
  late final FriendsStateManager _stateManager;
  late final FriendsInternalOperations _internalOps;
  late final FriendsFirebaseSyncOperations _firebaseSyncOps;
  late final FirebaseFriendsRepository _friendsRepository;
  late final FriendCategoryRepository _categoryRepository;

  /// Called once by the service after it has built its modules; the fields
  /// above point at the same instances the service holds.
  @protected
  void bindFriendsInternalPort({
    required FriendsStateManager stateManager,
    required FriendsInternalOperations internalOps,
    required FriendsFirebaseSyncOperations firebaseSyncOps,
    required FirebaseFriendsRepository friendsRepository,
    required FriendCategoryRepository categoryRepository,
  }) {
    _stateManager = stateManager;
    _internalOps = internalOps;
    _firebaseSyncOps = firebaseSyncOps;
    _friendsRepository = friendsRepository;
    _categoryRepository = categoryRepository;
  }

  /// Internal getter for friends list (for operations classes)
  List<UserProfile> get friendsInternal => _internalOps.friendsInternal;

  /// Internal getter for categories list (for operations classes)
  List<FriendCategory> getAllCategoriesInternal() =>
      _internalOps.getAllCategoriesInternal();

  /// Internal getter for sent invitations (for operations classes)
  List<GroupInvitation> getAllSentInvitationsInternal() =>
      _internalOps.getAllSentInvitationsInternal();

  /// Internal getter for friend-category relationships (for operations classes)
  Map<String, Set<String>> get friendCategoryRelationshipsInternal =>
      _stateManager.relationshipsInternal;

  /// Internal method to notify listeners (for operations classes)
  void notifyListenersInternal() => _internalOps.notifyListenersInternal();

  /// Internal method to get category by ID (for operations classes)
  FriendCategory? getCategoryByIdInternal(String categoryId) =>
      _internalOps.getCategoryByIdInternal(categoryId);

  /// Internal method to add category (for operations classes)
  void addCategoryInternal(FriendCategory category) =>
      _internalOps.addCategoryInternal(category);

  /// Internal method to update category (for operations classes)
  void updateCategoryInternal(String categoryId, FriendCategory category) =>
      _internalOps.updateCategoryInternal(categoryId, category);

  /// Internal method to remove category (for operations classes)
  void removeCategoryInternal(String categoryId) =>
      _internalOps.removeCategoryInternal(categoryId);

  /// Internal method to sync category to Firebase (for operations classes)
  Future<void> syncCategoryToFirebaseInternal(
    FriendCategory category, {
    FriendCategory? previous,
  }) async => await _internalOps.syncCategoryToFirebaseInternal(
    category,
    previous: previous,
  );

  /// Internal method to delete category from Firebase (for operations classes)
  Future<void> deleteCategoryFromFirebaseInternal(String categoryId) async =>
      await _internalOps.deleteCategoryFromFirebaseInternal(categoryId);

  /// Internal method to add friend to category (for operations classes)
  void addFriendToCategoryInternal(String friendId, String categoryId) =>
      _internalOps.addFriendToCategoryInternal(friendId, categoryId);

  /// Internal method to remove friend from category (for operations classes)
  void removeFriendFromCategoryInternal(String friendId, String categoryId) =>
      _internalOps.removeFriendFromCategoryInternal(friendId, categoryId);

  /// Internal method to get friends in category (for operations classes)
  Set<String> getFriendsInCategoryInternal(String categoryId) =>
      _internalOps.getFriendsInCategoryInternal(categoryId);

  /// Internal method to get categories for friend (for operations classes)
  Set<String> getCategoriesForFriendInternal(String friendId) =>
      _internalOps.getCategoriesForFriendInternal(friendId);

  /// Internal method to add sent invitation (for operations classes)
  void addSentInvitationInternal(GroupInvitation invitation) =>
      _internalOps.addSentInvitationInternal(invitation);

  /// Internal method to get sent invitation by ID (for operations classes)
  GroupInvitation? getSentInvitationByIdInternal(String invitationId) =>
      _internalOps.getSentInvitationByIdInternal(invitationId);

  /// Internal method to update sent invitation (for operations classes)
  void updateSentInvitationInternal(
    String invitationId,
    GroupInvitation invitation,
  ) => _internalOps.updateSentInvitationInternal(invitationId, invitation);

  /// Internal method to send email invitation (for operations classes)
  Future<bool> sendEmailInvitationInternal({
    required String email,
    required GroupInvitation invitation,
  }) async => await _internalOps.sendEmailInvitationInternal(
    email: email,
    invitation: invitation,
  );

  /// Internal method to send SMS invitation (for operations classes)
  Future<bool> sendSMSInvitationInternal({
    required String phoneNumber,
    required GroupInvitation invitation,
  }) async => await _internalOps.sendSMSInvitationInternal(
    phoneNumber: phoneNumber,
    invitation: invitation,
  );

  /// Internal method to create invitation link (for operations classes)
  Future<String> createInvitationLinkInternal(String invitationId) =>
      _internalOps.createInvitationLinkInternal(invitationId);

  /// Internal method to update invitation status (for operations classes)
  Future<void> updateInvitationStatusInternal(
    String invitationId,
    GroupInvitationStatus status,
  ) async =>
      await _internalOps.updateInvitationStatusInternal(invitationId, status);

  /// Internal method to get received group invitations (for operations classes)
  List<GroupInvitation> getReceivedGroupInvitationsInternal(String userId) =>
      _internalOps.getReceivedGroupInvitationsInternal(userId);

  /// Internal getter for friends repository (for operations classes to save invitations)
  FirebaseFriendsRepository get friendsRepositoryInternal => _friendsRepository;

  /// Internal getter for category repository (for operations classes to fetch groups)
  FriendCategoryRepository get friendsCategoryRepositoryInternal =>
      _categoryRepository;

  /// Internal getter for current user display name (for operations classes)
  String? get currentUserDisplayName =>
      _internalOps.getCurrentUserDisplayNameInternal();

  /// Internal method to add outgoing friend request
  void addOutgoingRequestInternal(FriendRequest request) {
    _stateManager.addOutgoingRequest(request);
    AppLogger.debug(
      '✅ Added outgoing request to ${request.toUserId.maskedUserId} via state manager',
    );
  }

  /// Internal method to remove outgoing friend request
  void removeOutgoingRequestInternal(String requestId) {
    _stateManager.removeOutgoingRequest(requestId);
    AppLogger.debug('✅ Removed outgoing request $requestId via state manager');
  }

  /// Internal method to add incoming friend request
  void addIncomingRequestInternal(FriendRequest request) {
    _stateManager.addIncomingRequest(request);
    AppLogger.debug(
      '✅ Added incoming request from ${request.fromUserId.maskedUserId} via state manager',
    );
  }

  /// Internal method to remove incoming friend request
  void removeIncomingRequestInternal(String requestId) {
    _stateManager.removeIncomingRequest(requestId);
    AppLogger.debug('✅ Removed incoming request $requestId via state manager');
  }

  /// Internal method to add friend
  void addFriendInternal(UserProfile friend) {
    _stateManager.addFriend(friend);
    AppLogger.debug(
      '✅ Added friend ${friend.displayName.maskedName} via state manager',
    );
  }

  /// Internal method to remove friend
  void removeFriendInternal(String friendId) {
    _stateManager.removeFriend(friendId);
    AppLogger.debug(
      '✅ Removed friend ${friendId.maskedUserId} via state manager',
    );
  }

  /// Internal method to seed the blocked-users state — used by tests and
  /// by internal operations that have already persisted the block but need
  /// the in-memory roster to reflect it. Mirrors addFriendInternal.
  void addBlockedUserInternal(String userId) {
    _stateManager.addBlockedUser(userId);
  }

  /// Sync friend request to Firebase
  Future<void> syncFriendRequestToFirebase(FriendRequest request) async =>
      await _firebaseSyncOps.syncFriendRequestToFirebase(request);

  /// Update friend request status in Firebase
  Future<void> updateFriendRequestStatus(FriendRequest request) async =>
      await _firebaseSyncOps.updateFriendRequestStatus(request);

  /// Sync friend to Firebase
  /// WARNING: Do not use for friend request acceptance.
  /// Use FriendRelationshipRepository.addMutualFriends() instead, which properly handles
  /// atomic operations, counter updates, and consistent field structures.
  /// This method uses different field names and doesn't update friendsCount.
  Future<void> syncFriendToFirebase(UserProfile friend) async =>
      await _firebaseSyncOps.syncFriendToFirebase(friend);

  /// Remove friend from Firebase
  Future<void> removeFriendFromFirebase(String friendId) async =>
      await _firebaseSyncOps.removeFriendFromFirebase(friendId);
}
