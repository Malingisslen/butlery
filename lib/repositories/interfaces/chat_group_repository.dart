// lib/repositories/interfaces/chat_group_repository.dart

import 'package:butlery/models/messaging/chat_group.dart';

/// Chat groups: read from Firestore, written only by Cloud Functions.
///
/// The asymmetry is the design (BUT-1838). Membership decides who a minor can
/// be reached by, and `firestore.rules` cannot iterate a member list to check
/// that — so the write has to live somewhere that can, and the client is not
/// allowed to reach around it. Every mutating method here is a callable
/// invocation, not a Firestore write.
abstract class ChatGroupRepository {
  /// One group, or null when it does not exist.
  ///
  /// NOT null for a non-member: `firestore.rules` denies that read, so it
  /// arrives as a thrown `FirebaseException`, not an empty answer.
  Future<ChatGroup?> getGroup(String groupId);

  /// Live view of one group — the member list changes under you when someone is
  /// added or leaves.
  Stream<ChatGroup?> watchGroup(String groupId);

  /// Every group the signed-in user belongs to.
  Stream<List<ChatGroup>> watchMyGroups();

  /// Creates the group, its conversation and its roster in one server-side
  /// transaction. Returns the new group's id.
  ///
  /// Throws when someone in [memberIds] may not be added — the error carries
  /// `blockedUserIds` so the caller can say who, without saying why.
  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
  });

  /// Adds members. Admin-only, server-enforced. Returns the uids actually
  /// seated (already-present uids are not repeated).
  Future<List<String>> addMembers({
    required String groupId,
    required List<String> userIds,
  });

  /// Removes a member. Omit [userId] to leave the group yourself; removing
  /// anyone else requires admin rights, enforced server-side.
  Future<void> removeMember({required String groupId, String? userId});
}
