/// Model representing a user block relationship.
/// Stored in the `blocks` collection with composite-key documents (`{blockerId}_{blockedId}`).

import 'package:butlery/core/utils/serialization_utils.dart';

class BlockRecord {
  final String id;
  final String blockerId;
  final String blockedId;
  final DateTime blockedAt;

  BlockRecord({
    required this.id,
    required this.blockerId,
    required this.blockedId,
    required this.blockedAt,
  });

  /// Generate composite document ID for a block relationship
  static String compositeId(String blockerId, String blockedId) =>
      '${blockerId}_$blockedId';

  factory BlockRecord.create({
    required String blockerId,
    required String blockedId,
  }) {
    return BlockRecord(
      id: compositeId(blockerId, blockedId),
      blockerId: blockerId,
      blockedId: blockedId,
      blockedAt: DateTime.now(),
    );
  }

  factory BlockRecord.fromFirestore(Map<String, dynamic> data, String docId) {
    return BlockRecord(
      id: docId,
      blockerId: SerializationUtils.safeString(data, 'blockerId'),
      blockedId: SerializationUtils.safeString(data, 'blockedId'),
      blockedAt: SerializationUtils.safeRequiredDateTime(data, 'blockedAt'),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'blockerId': blockerId,
      'blockedId': blockedId,
      'blockedAt': blockedAt.toIso8601String(),
    };
  }
}
