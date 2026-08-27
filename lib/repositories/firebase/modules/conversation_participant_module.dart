// lib/repositories/firebase/modules/conversation_participant_module.dart

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/messaging/conversation_participant.dart';
import 'package:butlery/models/messaging/conversation_membership.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

/// Module for managing conversation participants using subcollections.
///
/// Uses two-way indexing for efficient queries:
/// 1. `conversations/{id}/participants/{userId}` - Get participants for a conversation
/// 2. `users/{userId}/conversationMemberships/{conversationId}` - Get conversations for a user
///
/// This replaces `arrayContains` queries with direct subcollection queries,
/// scaling better for:
/// - Large group conversations (100+ participants)
/// - Users with many conversations
/// - Independent participant metadata updates
class ConversationParticipantModule {
  final FirebaseFirestore firestore;
  final FeatureFlagService featureFlags;

  ConversationParticipantModule({
    required this.firestore,
    required this.featureFlags,
  });

  bool get _isEnabled =>
      featureFlags.isEnabled(FeatureFlags.enableSubcollectionParticipants);

  int get _maxInlineParticipants =>
      featureFlags.getInt(FeatureFlags.maxInlineParticipants);

  /// Add a participant to a conversation using subcollections.
  /// Creates entries in both the conversation's participants subcollection
  /// and the user's conversationMemberships subcollection.
  Future<void> addParticipant({
    required String conversationId,
    required String conversationTitle,
    required bool isGroup,
    required String participantId,
    required String displayName,
    String? avatarUrl,
    ParticipantRole role = ParticipantRole.member,
  }) async {
    if (!_isEnabled) return;

    final batch = firestore.batch();

    // 1. Add to conversation's participants subcollection
    final participant = ConversationParticipant.create(
      conversationId: conversationId,
      participantId: participantId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      role: role,
    );

    final participantRef = firestore
        .collection(FirestoreCollections.conversations)
        .doc(conversationId)
        .collection(FirestoreCollections.participants)
        .doc(participantId);

    batch.set(participantRef, participant.toFirestore());

    // 2. Add to user's conversationMemberships subcollection (inverse index)
    final membership = ConversationMembership.create(
      conversationId: conversationId,
      conversationTitle: conversationTitle,
      isGroup: isGroup,
    );

    final membershipRef = firestore
        .collection(FirestoreCollections.users)
        .doc(participantId)
        .collection(FirestoreCollections.userConversationMemberships)
        .doc(conversationId);

    batch.set(membershipRef, membership.toFirestore());

    await batch.commit();
    AppLogger.debug(
      'Added participant $participantId to conversation ${conversationId.maskedConversationId} (subcollection)',
    );
  }

  /// Add multiple participants to a conversation.
  Future<void> addParticipants({
    required String conversationId,
    required String conversationTitle,
    required bool isGroup,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
    String? ownerId,
  }) async {
    if (!_isEnabled) return;

    final batch = firestore.batch();

    for (final entry in participantDisplayNames.entries) {
      final participantId = entry.key;
      final displayName = entry.value;
      final avatarUrl = participantAvatarUrls[participantId];
      final role = participantId == ownerId
          ? ParticipantRole.owner
          : ParticipantRole.member;

      // 1. Add to conversation's participants subcollection
      final participant = ConversationParticipant.create(
        conversationId: conversationId,
        participantId: participantId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        role: role,
      );

      final participantRef = firestore
          .collection(FirestoreCollections.conversations)
          .doc(conversationId)
          .collection(FirestoreCollections.participants)
          .doc(participantId);

      batch.set(participantRef, participant.toFirestore());

      // 2. Add to user's conversationMemberships subcollection
      final membership = ConversationMembership.create(
        conversationId: conversationId,
        conversationTitle: conversationTitle,
        isGroup: isGroup,
      );

      final membershipRef = firestore
          .collection(FirestoreCollections.users)
          .doc(participantId)
          .collection(FirestoreCollections.userConversationMemberships)
          .doc(conversationId);

      batch.set(membershipRef, membership.toFirestore());
    }

    await batch.commit();
    AppLogger.debug(
      'Added ${participantDisplayNames.length} participants to conversation ${conversationId.maskedConversationId} (subcollection)',
    );
  }

  /// Remove a participant from a conversation.
  Future<void> removeParticipant({
    required String conversationId,
    required String participantId,
  }) async {
    if (!_isEnabled) return;

    final batch = firestore.batch();

    // 1. Remove from conversation's participants subcollection
    final participantRef = firestore
        .collection(FirestoreCollections.conversations)
        .doc(conversationId)
        .collection(FirestoreCollections.participants)
        .doc(participantId);

    batch.delete(participantRef);

    // 2. Remove from user's conversationMemberships subcollection
    final membershipRef = firestore
        .collection(FirestoreCollections.users)
        .doc(participantId)
        .collection(FirestoreCollections.userConversationMemberships)
        .doc(conversationId);

    batch.delete(membershipRef);

    await batch.commit();
    AppLogger.debug(
      'Removed participant $participantId from conversation ${conversationId.maskedConversationId} (subcollection)',
    );
  }

  /// Update participant's last read timestamp.
  Future<void> updateLastRead({
    required String conversationId,
    required String participantId,
  }) async {
    if (!_isEnabled) return;

    final now = clock.now().toUtc();
    final batch = firestore.batch();

    // 1. Update in participants subcollection
    final participantRef = firestore
        .collection(FirestoreCollections.conversations)
        .doc(conversationId)
        .collection(FirestoreCollections.participants)
        .doc(participantId);

    batch.update(participantRef, {
      'lastReadAt': Timestamp.fromDate(now),
    });

    // 2. Update hasUnread in membership
    final membershipRef = firestore
        .collection(FirestoreCollections.users)
        .doc(participantId)
        .collection(FirestoreCollections.userConversationMemberships)
        .doc(conversationId);

    batch.update(membershipRef, {
      'hasUnread': false,
    });

    await batch.commit();
  }

  /// Update conversation activity for all participants.
  Future<void> updateConversationActivity({
    required String conversationId,
    required String senderId,
    required List<String> participantIds,
  }) async {
    if (!_isEnabled) return;

    final now = clock.now().toUtc();
    final batch = firestore.batch();

    for (final participantId in participantIds) {
      final membershipRef = firestore
          .collection(FirestoreCollections.users)
          .doc(participantId)
          .collection(FirestoreCollections.userConversationMemberships)
          .doc(conversationId);

      batch.update(membershipRef, {
        'lastActivityAt': Timestamp.fromDate(now),
        // Mark as unread for everyone except sender
        if (participantId != senderId) 'hasUnread': true,
      });
    }

    await batch.commit();
  }

  /// Get all participants for a conversation.
  Future<List<ConversationParticipant>> getParticipants(
    String conversationId,
  ) async {
    if (!_isEnabled) return [];

    final snapshot = await firestore
        .collection(FirestoreCollections.conversations)
        .doc(conversationId)
        .collection(FirestoreCollections.participants)
        .get();

    return snapshot.docs
        .map((doc) => ConversationParticipant.fromFirestore(doc))
        .toList();
  }

  /// Stream participants for a conversation.
  Stream<List<ConversationParticipant>> watchParticipants(
    String conversationId,
  ) {
    if (!_isEnabled) return const Stream.empty();

    return firestore
        .collection(FirestoreCollections.conversations)
        .doc(conversationId)
        .collection(FirestoreCollections.participants)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ConversationParticipant.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get conversation memberships for a user (inverse index query).
  Future<List<ConversationMembership>> getUserMemberships(String userId) async {
    if (!_isEnabled) return [];

    final snapshot = await firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userConversationMemberships)
        .orderBy('lastActivityAt', descending: true)
        .limit(50)
        .get();

    return snapshot.docs
        .map((doc) => ConversationMembership.fromFirestore(doc))
        .toList();
  }

  /// Stream conversation memberships for a user.
  Stream<List<ConversationMembership>> watchUserMemberships(String userId) {
    if (!_isEnabled) return const Stream.empty();

    return firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userConversationMemberships)
        .where('isArchived', isEqualTo: false)
        .orderBy('lastActivityAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ConversationMembership.fromFirestore(doc))
              .toList(),
        );
  }

  /// Check if a user is a participant in a conversation.
  Future<bool> isParticipant({
    required String conversationId,
    required String userId,
  }) async {
    if (!_isEnabled) return false;

    final doc = await firestore
        .collection(FirestoreCollections.conversations)
        .doc(conversationId)
        .collection(FirestoreCollections.participants)
        .doc(userId)
        .get();

    return doc.exists;
  }

  /// Migrate an existing conversation's participants to subcollections.
  /// Called when a conversation exceeds maxInlineParticipants.
  Future<void> migrateToSubcollection({
    required String conversationId,
    required String conversationTitle,
    required bool isGroup,
    required List<String> participantIds,
    required Map<String, String> displayNames,
    required Map<String, String?> avatarUrls,
    required Map<String, DateTime> lastReadTimestamps,
    String? ownerId,
  }) async {
    if (!_isEnabled) return;

    final batch = firestore.batch();

    for (final participantId in participantIds) {
      final displayName = displayNames[participantId] ?? 'Unknown';
      final avatarUrl = avatarUrls[participantId];
      final lastRead = lastReadTimestamps[participantId] ?? clock.now().toUtc();
      final role = participantId == ownerId
          ? ParticipantRole.owner
          : ParticipantRole.member;

      // Create participant entry
      final participant = ConversationParticipant(
        conversationId: conversationId,
        participantId: participantId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        joinedAt: clock.now().toUtc(), // Approximate
        lastReadAt: lastRead,
        role: role,
      );

      final participantRef = firestore
          .collection(FirestoreCollections.conversations)
          .doc(conversationId)
          .collection(FirestoreCollections.participants)
          .doc(participantId);

      batch.set(participantRef, participant.toFirestore());

      // Create membership entry
      final membership = ConversationMembership(
        conversationId: conversationId,
        conversationTitle: conversationTitle,
        isGroup: isGroup,
        lastActivityAt: clock.now().toUtc(),
        joinedAt: clock.now().toUtc(), // Approximate
      );

      final membershipRef = firestore
          .collection(FirestoreCollections.users)
          .doc(participantId)
          .collection(FirestoreCollections.userConversationMemberships)
          .doc(conversationId);

      batch.set(membershipRef, membership.toFirestore());
    }

    // Mark conversation as migrated
    final conversationRef = firestore
        .collection(FirestoreCollections.conversations)
        .doc(conversationId);
    batch.update(conversationRef, {
      'usesSubcollectionParticipants': true,
    });

    await batch.commit();
    AppLogger.info(
      'Migrated conversation ${conversationId.maskedConversationId} to subcollection participants',
    );
  }

  /// Check if should use subcollection based on participant count.
  bool shouldUseSubcollection(int participantCount) {
    return _isEnabled && participantCount > _maxInlineParticipants;
  }
}
