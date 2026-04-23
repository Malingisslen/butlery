import 'package:uuid/uuid.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

const Duration kPingDefaultTtl = Duration(minutes: 10);
const int kPingMaxMessageLength = 100;

enum PingType {
  nudge,
  timerAlert,
  helpMe;

  // Safe fallback keeps older clients forward-compatible with future types.
  static PingType fromString(String? value) {
    if (value == null) return PingType.nudge;
    return SerializationUtils.safeEnumByName(
      PingType.values,
      value,
      PingType.nudge,
    );
  }
}

/// A single ping event. Immutable domain model — mutations go through
/// `PingService.acknowledge()` which writes directly to Firestore.
class Ping {
  final String id;
  final String groupId;
  final String fromUserId;

  /// Target user — null means broadcast to whole group.
  final String? toUserId;

  final PingType type;

  /// Optional free-text message. Capped at [kPingMaxMessageLength].
  final String? message;

  final DateTime createdAt;

  /// Auto-expiry. Defaults to `createdAt + kPingDefaultTtl`.
  final DateTime expiresAt;

  final bool acknowledged;

  Ping({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    this.toUserId,
    required this.type,
    this.message,
    required this.createdAt,
    DateTime? expiresAt,
    this.acknowledged = false,
  }) : expiresAt = expiresAt ?? createdAt.add(kPingDefaultTtl);

  /// Factory with auto-generated UUID + current timestamp.
  factory Ping.create({
    required String groupId,
    required String fromUserId,
    String? toUserId,
    required PingType type,
    String? message,
    DateTime? expiresAt,
  }) {
    final now = DateTime.now();
    return Ping(
      id: const Uuid().v4(),
      groupId: groupId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      type: type,
      message: _truncateMessage(message),
      createdAt: now,
      expiresAt: expiresAt ?? now.add(kPingDefaultTtl),
      acknowledged: false,
    );
  }

  /// Copy with overrides — used by `acknowledge()` path.
  Ping copyWith({
    bool? acknowledged,
  }) {
    return Ping(
      id: id,
      groupId: groupId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      type: type,
      message: message,
      createdAt: createdAt,
      expiresAt: expiresAt,
      acknowledged: acknowledged ?? this.acknowledged,
    );
  }

  /// Serialize for Firestore. `createdAt`/`expiresAt` become `Timestamp` so
  /// rule-side queries (e.g. rate-limit count over last hour) can compare.
  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'type': type.name,
      'message': message,
      'createdAt': AppTimestamp.fromDateTime(createdAt).toFirestore(),
      'expiresAt': AppTimestamp.fromDateTime(expiresAt).toFirestore(),
      'acknowledged': acknowledged,
    };
  }

  /// Deserialize from Firestore — tolerant to missing/malformed fields.
  factory Ping.fromMap(String id, Map<String, dynamic> data) {
    final createdAt =
        SerializationUtils.safeDateTime(data, 'createdAt') ?? DateTime.now();
    return Ping(
      id: id,
      groupId: SerializationUtils.safeString(data, 'groupId'),
      fromUserId: SerializationUtils.safeString(data, 'fromUserId'),
      toUserId: SerializationUtils.safeNullableString(data, 'toUserId'),
      type: PingType.fromString(
        SerializationUtils.safeNullableString(data, 'type'),
      ),
      message: SerializationUtils.safeNullableString(data, 'message'),
      createdAt: createdAt,
      expiresAt: SerializationUtils.safeDateTime(data, 'expiresAt') ??
          createdAt.add(kPingDefaultTtl),
      acknowledged: SerializationUtils.safeBool(data, 'acknowledged',
          defaultValue: false),
    );
  }

  /// True when the ping has passed its expiry. Clients should hide expired
  /// pings from the in-app feed even if Cloud Functions hasn't cleaned them
  /// up yet.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// True when this is a broadcast ping (toUserId == null).
  bool get isBroadcast => toUserId == null;

  static String? _truncateMessage(String? message) {
    if (message == null) return null;
    if (message.length <= kPingMaxMessageLength) return message;
    return message.substring(0, kPingMaxMessageLength);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Ping && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Ping(id: $id, group: $groupId, from: $fromUserId, to: $toUserId, type: ${type.name}, ack: $acknowledged)';
}
