// lib/repositories/firebase/modules/conversation_participant_module.dart

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/messaging/conversation_participant.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

/// Module for managing conversation participants using subcollections.
///
/// Writes `conversations/{id}/participants/{userId}`.
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

  /// Add a participant to a conversation's participants subcollection.
  Future<void> addParticipant({
    required String conversationId,
    required String participantId,
    required String displayName,
    String? avatarUrl,
    ParticipantRole role = ParticipantRole.member,
  }) async {
    if (!_isEnabled) return;

    final batch = firestore.batch();

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

    await batch.commit();
    AppLogger.debug(
      'Added participant $participantId to conversation ${conversationId.maskedConversationId} (subcollection)',
    );
  }

  /// Add multiple participants to a conversation.
  Future<void> addParticipants({
    required String conversationId,
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

    final participantRef = firestore
        .collection(FirestoreCollections.conversations)
        .doc(conversationId)
        .collection(FirestoreCollections.participants)
        .doc(participantId);

    batch.delete(participantRef);

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

    final participantRef = firestore
        .collection(FirestoreCollections.conversations)
        .doc(conversationId)
        .collection(FirestoreCollections.participants)
        .doc(participantId);

    batch.update(participantRef, {
      'lastReadAt': Timestamp.fromDate(now),
    });

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
