// lib/models/group_invitation.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../core/mixins/json_serializable_mixin.dart';


enum GroupInvitationStatus {
  pending, // Väntande inbjudan
  accepted, // Accepterad
  rejected, // Avvisad
  expired, // Utgången
  cancelled // Avbruten av avsändare
}

class GroupInvitation with JsonSerializableMixin {
  final String id;
  final String groupId; // Vilken grupp
  final String groupName; // Gruppnamn (cached för UI)
  final String groupEmoji; // Gruppemoji (cached för UI)
  final String fromUserId; // Vem som bjöd in
  final String fromUserName; // Avsändarens namn (cached för UI)
  final String toUserId; // Vem som blev inbjuden
  final GroupInvitationStatus status;
  final DateTime sentAt;
  final DateTime? respondedAt;
  final String? personalMessage; // Personligt meddelande
  final DateTime expiresAt; // När inbjudan går ut

  GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.groupEmoji,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    this.status = GroupInvitationStatus.pending,
    DateTime? sentAt,
    this.respondedAt,
    this.personalMessage,
    DateTime? expiresAt,
  })  : sentAt = sentAt ?? DateTime.now(),
        expiresAt = expiresAt ?? DateTime.now().add(const Duration(days: 7));

  /// Factory constructor med auto-genererat ID
  factory GroupInvitation.create({
    required String groupId,
    required String groupName,
    required String groupEmoji,
    required String fromUserId,
    required String fromUserName,
    required String toUserId,
    String? personalMessage,
  }) {
    return GroupInvitation(
      id: const Uuid().v4(),
      groupId: groupId,
      groupName: groupName,
      groupEmoji: groupEmoji,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      toUserId: toUserId,
      personalMessage: personalMessage,
    );
  }

  /// Skapa kopia med uppdaterad status
  GroupInvitation copyWith({
    GroupInvitationStatus? status,
    DateTime? respondedAt,
  }) {
    return GroupInvitation(
      id: id,
      groupId: groupId,
      groupName: groupName,
      groupEmoji: groupEmoji,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      toUserId: toUserId,
      status: status ?? this.status,
      sentAt: sentAt,
      respondedAt: respondedAt ?? this.respondedAt,
      personalMessage: personalMessage,
      expiresAt: expiresAt,
    );
  }

  /// Acceptera inbjudan
  GroupInvitation accept() {
    return copyWith(
      status: GroupInvitationStatus.accepted,
      respondedAt: DateTime.now(),
    );
  }

  /// Avvisa inbjudan
  GroupInvitation reject() {
    return copyWith(
      status: GroupInvitationStatus.rejected,
      respondedAt: DateTime.now(),
    );
  }

  /// Avbryt inbjudan (endast avsändare)
  GroupInvitation cancel() {
    return copyWith(
      status: GroupInvitationStatus.cancelled,
      respondedAt: DateTime.now(),
    );
  }

  // Status checkers
  bool get isPending => status == GroupInvitationStatus.pending && !isExpired;
  bool get isAccepted => status == GroupInvitationStatus.accepted;
  bool get isRejected => status == GroupInvitationStatus.rejected;
  bool get isCancelled => status == GroupInvitationStatus.cancelled;
  bool get isCompleted => respondedAt != null;
  bool get isExpired =>
      DateTime.now().isAfter(expiresAt) ||
      status == GroupInvitationStatus.expired;

  /// Få hur länge sedan inbjudan skickades
  String get timeAgoText {
    final now = DateTime.now();
    final difference = now.difference(sentAt);

    if (difference.inMinutes < 1) {
      return 'Nu';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min sedan';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} tim sedan';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dagar sedan';
    } else {
      return '${(difference.inDays / 7).floor()} veckor sedan';
    }
  }

  /// Få hur lång tid kvar till utgång
  String get expiresInText {
    if (isExpired) return 'Utgången';

    final now = DateTime.now();
    final difference = expiresAt.difference(now);

    if (difference.inDays > 1) {
      return '${difference.inDays} dagar kvar';
    } else if (difference.inHours > 1) {
      return '${difference.inHours} timmar kvar';
    } else if (difference.inMinutes > 1) {
      return '${difference.inMinutes} minuter kvar';
    } else {
      return 'Går ut snart';
    }
  }

  /// UI-text för notifikation
  String get notificationText {
    if (personalMessage?.isNotEmpty == true) {
      return '$fromUserName bjöd in dig till gruppen $groupEmoji $groupName: "$personalMessage"';
    } else {
      return '$fromUserName bjöd in dig till gruppen $groupEmoji $groupName';
    }
  }

  /// Kort UI-text för notifikationslista
  String get shortNotificationText {
    return '$fromUserName → $groupEmoji $groupName';
  }

  /// Status-färg för UI
  String get statusColorName {
    switch (status) {
      case GroupInvitationStatus.pending:
        return isExpired ? 'warning' : 'primary';
      case GroupInvitationStatus.accepted:
        return 'success';
      case GroupInvitationStatus.rejected:
      case GroupInvitationStatus.cancelled:
        return 'error';
      case GroupInvitationStatus.expired:
        return 'warning';
    }
  }

  /// Status-text för UI
  String get statusText {
    switch (status) {
      case GroupInvitationStatus.pending:
        return isExpired ? 'Utgången' : 'Väntande';
      case GroupInvitationStatus.accepted:
        return 'Accepterad';
      case GroupInvitationStatus.rejected:
        return 'Avvisad';
      case GroupInvitationStatus.cancelled:
        return 'Avbruten';
      case GroupInvitationStatus.expired:
        return 'Utgången';
    }
  }

  /// Konvertera till Firestore-format
  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'groupEmoji': groupEmoji,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'status': status.name,
      'sentAt': Timestamp.fromDate(sentAt),
      'respondedAt':
          respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'personalMessage': personalMessage,
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  /// Skapa från Firestore-dokument
  factory GroupInvitation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return GroupInvitation(
      id: doc.id,
      groupId: data['groupId'] as String,
      groupName: data['groupName'] as String,
      groupEmoji: data['groupEmoji'] as String? ?? '👥',
      fromUserId: data['fromUserId'] as String,
      fromUserName: data['fromUserName'] as String,
      toUserId: data['toUserId'] as String,
      status: GroupInvitationStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => GroupInvitationStatus.pending,
      ),
      sentAt: (data['sentAt'] as Timestamp).toDate(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
      personalMessage: data['personalMessage'] as String?,
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
    );
  }

  /// JSON-serialisering för caching
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'groupName': groupName,
      'groupEmoji': groupEmoji,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'status': status.name,
      'sentAt': serializeDateTime(sentAt),
      'respondedAt': serializeDateTime(respondedAt),
      'personalMessage': personalMessage,
      'expiresAt': serializeDateTime(expiresAt),
    };
  }

  factory GroupInvitation.fromJson(Map<String, dynamic> json) {
    return GroupInvitation(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      groupName: json['groupName'] as String,
      groupEmoji: json['groupEmoji'] as String,
      fromUserId: json['fromUserId'] as String,
      fromUserName: json['fromUserName'] as String,
      toUserId: json['toUserId'] as String,
      status: GroupInvitationStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => GroupInvitationStatus.pending,
      ),
      sentAt: GroupInvitation._deserializeDateTime(json['sentAt']) ?? DateTime.now(),
      respondedAt: GroupInvitation._deserializeDateTime(json['respondedAt']),
      personalMessage: json['personalMessage'] as String?,
      expiresAt: GroupInvitation._deserializeDateTime(json['expiresAt']) ?? DateTime.now(),
    );
  }

  /// Helper method for deserializing DateTime from JSON
  static DateTime? _deserializeDateTime(dynamic value) {
    if (value is String) return DateTime.parse(value);
    if (value is Timestamp) return value.toDate();
    return null;
  }

  @override
  String toString() {
    return 'GroupInvitation(id: $id, group: $groupName, from: $fromUserName, to: $toUserId, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroupInvitation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
