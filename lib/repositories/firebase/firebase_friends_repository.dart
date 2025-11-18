// lib/repositories/firebase/firebase_friends_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';

// Import focused repositories
import 'package:butlery/repositories/firebase/friends/friend_request_repository.dart';
import 'package:butlery/repositories/firebase/friends/friend_relationship_repository.dart';
import 'package:butlery/repositories/firebase/friends/friend_category_repository.dart';
import 'package:butlery/repositories/firebase/friends/group_invitation_repository.dart';

/// Firebase Firestore implementation for comprehensive social friendship management.
/// This repository implements the [FriendsRepository] interface using a sophisticated
/// facade pattern that delegates to four specialized repositories, providing complete
/// social relationship management while maintaining clean separation of concerns and
/// backward compatibility.
/// **Facade Architecture:**
/// Uses the facade pattern to coordinate four focused repositories, eliminating the
/// complexity of a monolithic friends repository while providing a unified interface:
/// - **FriendRequestRepository**: Manages friend request lifecycle and operations
/// - **FriendRelationshipRepository**: Handles mutual friendship management and profiles
/// - **FriendCategoryRepository**: Organizes friends into custom categories and groups
/// - **GroupInvitationRepository**: Manages group invitations and cleanup operations
/// **Social Relationship Features:**
/// - **Friend Requests**: Complete request lifecycle (send, accept, reject, cancel)
/// - **Mutual Friendships**: Bidirectional relationship management with consistency
/// - **Friend Categories**: Custom organization and grouping of friend connections
/// - **Group Invitations**: Social group invitation system with expiration handling
/// - **Profile Integration**: Seamless integration with user profiles and social data
/// - **Real-time Streams**: Live updates for social activities and relationship changes
/// **Data Consistency:**
/// Ensures complex social relationships remain synchronized across multiple collections
/// and operations. Handles concurrent social operations gracefully while maintaining
/// referential integrity between friend requests, relationships, and categories.
/// **Performance Optimization:**
/// - **Focused Queries**: Each repository optimizes queries for its specific domain
/// - **Batch Operations**: Efficient bulk operations for friend management
/// - **Stream Management**: Optimized real-time subscriptions for social activities
/// - **Statistics Aggregation**: Comprehensive social statistics from all repositories
/// **Privacy and Security:**
/// Implements comprehensive authorization checks across all social operations,
/// respects user privacy settings, and provides audit logging for social interactions.
/// **Usage Examples:**
/// ```dart
/// final friendsRepo = FirebaseFriendsRepository(
///   authRepository: ServiceLocator.get<AuthRepository>(),
/// );
/// // Send and manage friend requests
/// await friendsRepo.sendFriendRequest(targetUserId, 
///   message: 'Let\\'s connect!');
/// // Accept request and create mutual friendship
/// await friendsRepo.acceptFriendRequest(requestId);
/// // Organize friends into categories
/// final familyCategory = FriendCategory(
///   name: 'Family',
///   memberIds: familyFriendIds,
/// );
/// await friendsRepo.saveCategory(userId, familyCategory);
/// // Real-time social updates
/// friendsRepo.incomingRequestsStream(userId).listen((requests) {
///   updateFriendRequestsUI(requests);
/// });
/// ```
class FirebaseFriendsRepository extends BaseFirebaseRepository<UserProfile>
    implements FriendsRepository {
  
  // Focused repositories
  late final FriendRequestRepository _friendRequestRepo;
  late final FriendRelationshipRepository _friendRelationshipRepo;
  late final FriendCategoryRepository _friendCategoryRepo;
  late final GroupInvitationRepository _groupInvitationRepo;

  FirebaseFriendsRepository({
    super.firestore,
    AuthRepository? authRepository,
    super.auditRepository,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        ) {
    // Initialize focused repositories
    _friendRequestRepo = FriendRequestRepository(
      firestore: firestore,
      authRepository: this.authRepository,
    );
    _friendRelationshipRepo = FriendRelationshipRepository(
      firestore: firestore,
      authRepository: this.authRepository,
    );
    _friendCategoryRepo = FriendCategoryRepository(
      firestore: firestore,
      authRepository: this.authRepository,
    );
    _groupInvitationRepo = GroupInvitationRepository(
      firestore: firestore,
      authRepository: this.authRepository,
    );
  }

  // ===== BASE CLASS IMPLEMENTATION =====

  @override
  String get collectionName => 'public_profiles';

  @override
  UserProfile fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      UserProfile.fromMap(doc.id, doc.data() ?? {});

  @override
  Map<String, dynamic> toFirestore(UserProfile entity) => entity.toFirestore();

  @override
  String getId(UserProfile entity) => entity.uid;

  // ===== PERMISSION VALIDATION IMPLEMENTATION =====

  @override
  Future<bool> validateCreatePermission(String userId, UserProfile entity) async {
    // Users can only create their own friend relationships
    return userId == entity.uid;
  }

  @override
  Future<bool> validateReadPermission(String userId, String resourceId, UserProfile? entity) async {
    // Users can read profiles of their friends
    // This is validated at a higher level (friend relationship must exist)
    return true;
  }

  @override
  Future<bool> validateUpdatePermission(String userId, String resourceId, UserProfile entity) async {
    // Users can only update their own profile in the context of friendships
    return userId == entity.uid;
  }

  @override
  Future<bool> validateDeletePermission(String userId, String resourceId) async {
    // Users can only delete their own friend relationships
    return userId == resourceId;
  }

  // ===== FRIEND REQUEST OPERATIONS (Delegate to FriendRequestRepository) =====

  /// Send a new friend request.
  Future<void> sendRequest(FriendRequest request) async {
    return await _friendRequestRepo.sendRequest(request);
  }

  @override
  Future<bool> sendFriendRequest(String toUserId, {String? message}) async {
    return await _friendRequestRepo.sendFriendRequest(toUserId, message: message);
  }

  /// Update an existing friend request document.
  Future<void> updateRequest(FriendRequest request) async {
    return await _friendRequestRepo.updateRequest(request);
  }

  @override
  Future<bool> acceptFriendRequest(String requestId) async {
    final success = await _friendRequestRepo.acceptFriendRequest(requestId);
    
    // If request was accepted, also add mutual friends
    if (success) {
      final request = await _friendRequestRepo.fetchRequest(requestId);
      if (request != null) {
        await _friendRelationshipRepo.addMutualFriends(request.fromUserId, request.toUserId);
      }
    }
    
    return success;
  }

  @override
  Future<bool> rejectFriendRequest(String requestId) async {
    return await _friendRequestRepo.rejectFriendRequest(requestId);
  }

  @override
  Future<bool> cancelFriendRequest(String requestId) async {
    return await _friendRequestRepo.cancelFriendRequest(requestId);
  }

  /// Fetch a friend request by id.
  Future<FriendRequest?> fetchRequest(String requestId) async {
    return await _friendRequestRepo.fetchRequest(requestId);
  }

  @override
  Future<bool> requestExists(String fromUserId, String toUserId) async {
    return await _friendRequestRepo.requestExists(fromUserId, toUserId);
  }

  @override
  Future<List<FriendRequest>> getIncomingRequests() async {
    return await _friendRequestRepo.getIncomingRequests();
  }

  @override
  Future<List<FriendRequest>> getSentRequests() async {
    return await _friendRequestRepo.getSentRequests();
  }

  /// Stream incoming friend requests for the current user.
  Stream<List<FriendRequest>> incomingRequestsStream(String userId) {
    return _friendRequestRepo.incomingRequestsStream(userId);
  }

  /// Stream sent friend requests for the current user.
  Stream<List<FriendRequest>> sentRequestsStream(String userId) {
    return _friendRequestRepo.sentRequestsStream(userId);
  }

  // ===== FRIEND RELATIONSHIP OPERATIONS (Delegate to FriendRelationshipRepository) =====

  @override
  Future<bool> areFriends(String userId1, String userId2) async {
    return await _friendRelationshipRepo.areFriends(userId1, userId2);
  }

  @override
  Future<void> addMutualFriends(String userId1, String userId2) async {
    return await _friendRelationshipRepo.addMutualFriends(userId1, userId2);
  }

  @override
  Future<void> removeMutualFriends(String userId1, String userId2) async {
    return await _friendRelationshipRepo.removeMutualFriends(userId1, userId2);
  }

  @override
  Future<bool> removeFriend(String friendUserId) async {
    return await _friendRelationshipRepo.removeFriend(friendUserId);
  }

  @override
  Future<List<String>> fetchFriendIds(String userId) async {
    return await _friendRelationshipRepo.fetchFriendIds(userId);
  }

  @override
  Future<List<UserProfile>> fetchFriendProfiles(List<String> userIds) async {
    return await _friendRelationshipRepo.fetchFriendProfiles(userIds);
  }

  // ===== FRIEND CATEGORY OPERATIONS (Delegate to FriendCategoryRepository) =====

  @override
  Future<void> saveCategory(String userId, FriendCategory category) async {
    return await _friendCategoryRepo.saveCategory(userId, category);
  }

  @override
  Future<void> updateCategory(
      String userId, String categoryId, Map<String, dynamic> data) async {
    return await _friendCategoryRepo.updateCategory(userId, categoryId, data);
  }

  @override
  Future<void> deleteCategory(String userId, String categoryId) async {
    return await _friendCategoryRepo.deleteCategory(userId, categoryId);
  }

  @override
  Future<List<FriendCategory>> fetchCategories(String userId) async {
    return await _friendCategoryRepo.fetchCategories(userId);
  }

  @override
  Future<void> createCategoryForUser(String userId, FriendCategory category) async {
    return await _friendCategoryRepo.createCategoryForUser(userId, category);
  }

  @override
  Future<void> updateCategoryMembers(
      String userId, String categoryId, List<String> memberIds) async {
    return await _friendCategoryRepo.updateCategoryMembers(userId, categoryId, memberIds);
  }

  @override
  Future<FriendCategory?> getCategory(String userId, String categoryId) async {
    return await _friendCategoryRepo.getCategory(userId, categoryId);
  }

  // ===== GROUP INVITATION OPERATIONS (Delegate to GroupInvitationRepository) =====

  @override
  Stream<List<GroupInvitation>> receivedInvitationsStream(String userId) {
    return _groupInvitationRepo.receivedInvitationsStream(userId);
  }

  @override
  Stream<List<GroupInvitation>> sentInvitationsStream(String userId) {
    return _groupInvitationRepo.sentInvitationsStream(userId);
  }

  @override
  Future<GroupInvitation?> getInvitation(String invitationId) async {
    return await _groupInvitationRepo.getInvitation(invitationId);
  }

  @override
  Future<void> saveInvitation(GroupInvitation invitation) async {
    return await _groupInvitationRepo.saveInvitation(invitation);
  }

  @override
  Future<void> updateInvitation(
      String invitationId, Map<String, dynamic> data) async {
    return await _groupInvitationRepo.updateInvitation(invitationId, data);
  }

  /// Fetch received invitations for a user (one-time fetch)
  Future<List<GroupInvitation>> fetchReceivedInvitations(String userId) async {
    final stream = _groupInvitationRepo.receivedInvitationsStream(userId);
    return await stream.first;
  }

  /// Fetch sent invitations for a user (one-time fetch)
  Future<List<GroupInvitation>> fetchSentInvitations(String userId) async {
    final stream = _groupInvitationRepo.sentInvitationsStream(userId);
    return await stream.first;
  }

  @override
  Future<List<DocumentReference<Map<String, dynamic>>>> expiredInvitations(
      DateTime now) async {
    return await _groupInvitationRepo.expiredInvitations(now);
  }

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> oldInvitations(
      String userId, DateTime cutoffDate) async {
    return await _groupInvitationRepo.oldInvitations(userId, cutoffDate);
  }

  @override
  Future<void> deleteDocuments(
      List<DocumentReference<Map<String, dynamic>>> refs) async {
    return await _groupInvitationRepo.deleteDocuments(refs);
  }

  @override
  Future<void> updateDocuments(
      List<DocumentReference<Map<String, dynamic>>> refs,
      Map<String, dynamic> data) async {
    return await _groupInvitationRepo.updateDocuments(refs, data);
  }

  @override
  Future<bool> hasPendingInvitation(String groupId, String toUserId) async {
    return await _groupInvitationRepo.hasPendingInvitation(groupId, toUserId);
  }

  // ===== ADDITIONAL UTILITY METHODS (Delegate to appropriate repositories) =====

  /// Get comprehensive friend statistics.
  Future<Map<String, dynamic>> getComprehensiveFriendStatistics(String userId) async {
    final friendStats = await _friendRelationshipRepo.getFriendStatistics(userId);
    final requestStats = await _friendRequestRepo.getRequestStatistics(userId);
    final categoryStats = await _friendCategoryRepo.getCategoryStatistics(userId);
    final invitationStats = await _groupInvitationRepo.getInvitationStatistics(userId);

    return {
      'friends': friendStats,
      'requests': requestStats,
      'categories': categoryStats,
      'invitations': invitationStats,
    };
  }

  /// Get friends with profiles for a user.
  Future<List<UserProfile>> getFriendsWithProfiles(String userId) async {
    return await _friendRelationshipRepo.getFriendsWithProfiles(userId);
  }

  /// Get mutual friends between two users.
  Future<List<String>> getMutualFriends(String userId1, String userId2) async {
    return await _friendRelationshipRepo.getMutualFriends(userId1, userId2);
  }

  /// Stream friend profiles for real-time updates.
  Stream<List<UserProfile>> friendProfilesStream(String userId) {
    return _friendRelationshipRepo.friendProfilesStream(userId);
  }

  /// Stream categories for real-time updates.
  Stream<List<FriendCategory>> categoriesStream(String userId) {
    return _friendCategoryRepo.categoriesStream(userId);
  }

  /// Add a friend to a category.
  Future<void> addFriendToCategory(String userId, String categoryId, String friendId) async {
    return await _friendCategoryRepo.addFriendToCategory(userId, categoryId, friendId);
  }

  /// Remove a friend from a category.
  Future<void> removeFriendFromCategory(String userId, String categoryId, String friendId) async {
    return await _friendCategoryRepo.removeFriendFromCategory(userId, categoryId, friendId);
  }

  /// Accept a group invitation.
  Future<bool> acceptInvitation(String invitationId) async {
    return await _groupInvitationRepo.acceptInvitation(invitationId);
  }

  /// Reject a group invitation.
  Future<bool> rejectInvitation(String invitationId) async {
    return await _groupInvitationRepo.rejectInvitation(invitationId);
  }

  /// Search friends by name.
  Future<List<UserProfile>> searchFriends(String userId, String query) async {
    return await _friendRelationshipRepo.searchFriends(userId, query);
  }

  /// Search categories by name.
  Future<List<FriendCategory>> searchCategories(String userId, String query) async {
    return await _friendCategoryRepo.searchCategories(userId, query);
  }
}