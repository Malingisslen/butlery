// lib/models/invitations/realtime_invitation.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../realtime/realtime_resource.dart';
import 'invitation_target.dart';


/// Status för inbjudningar
enum RealtimeInvitationStatus {
  /// Väntande svar
  pending,

  /// Accepterad
  accepted,

  /// Avvisad
  rejected,

  /// Utgången (automatiskt)
  expired,

  /// Avbruten av avsändare
  cancelled,
}

/// Inbjudan till att delta i en realtidsresurs
class RealtimeInvitation {
  /// Unik ID för inbjudan
  final String id;

  /// Typ av resurs som bjuds in till
  final RealtimeResourceType resourceType;

  /// ID för resursen som bjuds in till
  final String resourceId;

  /// Titel på resursen (cached för UI)
  final String resourceTitle;

  /// Vem som skickade inbjudan
  final String fromUserId;

  /// Namn på avsändaren (cached för UI)
  final String fromUserDisplayName;

  /// Vem som ska få inbjudan (kan vara person eller grupp)
  final InvitationTarget target;

  /// Status för inbjudan
  final RealtimeInvitationStatus status;

  /// När inbjudan skickades
  final DateTime sentAt;

  /// När inbjudan besvarades (om den är besvarad)
  final DateTime? respondedAt;

  /// När inbjudan går ut
  final DateTime expiresAt;

  /// Personligt meddelande från avsändaren
  final String? message;

  /// Behörighet som deltagaren kommer få vid accept
  final String permissionLevel; // 'editor' eller 'viewer'

  /// Extra metadata
  final Map<String, dynamic> metadata;

  RealtimeInvitation({
    String? id,
    required this.resourceType,
    required this.resourceId,
    required this.resourceTitle,
    required this.fromUserId,
    required this.fromUserDisplayName,
    required this.target,
    this.status = RealtimeInvitationStatus.pending,
    DateTime? sentAt,
    this.respondedAt,
    DateTime? expiresAt,
    this.message,
    this.permissionLevel = 'editor',
    this.metadata = const {},
  })  : id = id ?? const Uuid().v4(),
        sentAt = sentAt ?? DateTime.now(),
        expiresAt = expiresAt ?? DateTime.now().add(const Duration(days: 7));

  /// Factory constructor för att skapa ny inbjudan
  factory RealtimeInvitation.create({
    required RealtimeResourceType resourceType,
    required String resourceId,
    required String resourceTitle,
    required String fromUserId,
    required String fromUserDisplayName,
    required InvitationTarget target,
    String? message,
    String permissionLevel = 'editor',
    Duration? expiresIn,
  }) {
    return RealtimeInvitation(
      resourceType: resourceType,
      resourceId: resourceId,
      resourceTitle: resourceTitle,
      fromUserId: fromUserId,
      fromUserDisplayName: fromUserDisplayName,
      target: target,
      message: message,
      permissionLevel: permissionLevel,
      expiresAt: DateTime.now().add(expiresIn ?? const Duration(days: 7)),
    );
  }

  // ===== STATUS CHECKS =====

  /// Är inbjudan väntande?
  bool get isPending =>
      status == RealtimeInvitationStatus.pending && !isExpired;

  /// Är inbjudan accepterad?
  bool get isAccepted => status == RealtimeInvitationStatus.accepted;

  /// Är inbjudan avvisad?
  bool get isRejected => status == RealtimeInvitationStatus.rejected;

  /// Är inbjudan avbruten?
  bool get isCancelled => status == RealtimeInvitationStatus.cancelled;

  /// Är inbjudan utgången?
  bool get isExpired {
    return DateTime.now().isAfter(expiresAt) ||
        status == RealtimeInvitationStatus.expired;
  }

  /// Är inbjudan besvarad (accepted, rejected, eller expired)?
  bool get isResponded => respondedAt != null;

  /// Kan inbjudan fortfarande besvaras?
  bool get canRespond => isPending;

  // ===== TIME HELPERS =====

  /// Hur länge sedan inbjudan skickades
  String get timeAgoText {
    final duration = DateTime.now().difference(sentAt);

    if (duration.inMinutes < 1) {
      return 'Nu';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes} min sedan';
    } else if (duration.inDays < 1) {
      return '${duration.inHours} tim sedan';
    } else if (duration.inDays < 7) {
      return '${duration.inDays} dagar sedan';
    } else {
      return '${(duration.inDays / 7).floor()} veckor sedan';
    }
  }

  /// Hur lång tid kvar till utgång
  String get expiresInText {
    if (isExpired) return 'Utgången';

    final duration = expiresAt.difference(DateTime.now());

    if (duration.inDays > 1) {
      return '${duration.inDays} dagar kvar';
    } else if (duration.inHours > 1) {
      return '${duration.inHours} timmar kvar';
    } else if (duration.inMinutes > 1) {
      return '${duration.inMinutes} minuter kvar';
    } else {
      return 'Går ut snart';
    }
  }

  /// Kontrollera om inbjudan går ut snart (inom 24 timmar)
  bool get expiresSoon {
    final timeLeft = expiresAt.difference(DateTime.now());
    return timeLeft.inHours < 24;
  }

  // ===== UI HELPERS =====

  /// Titel för notifikation
  String get notificationTitle {
    switch (resourceType) {
      case RealtimeResourceType.recipe:
        return 'Inbjudan till recept';
      case RealtimeResourceType.menu:
        return 'Inbjudan till meny';
      case RealtimeResourceType.shoppingList:
        return 'Inbjudan till inköpslista';
    }
  }

  /// Beskrivning för notifikation
  String get notificationDescription {
    final prefix = target.isGroup
        ? '$fromUserDisplayName bjöd in gruppen "${target.displayName}"'
        : '$fromUserDisplayName bjöd in dig';

    final suffix = 'till gemensam ${_getResourceTypeName()}: "$resourceTitle"';

    return '$prefix $suffix';
  }

  /// Kort beskrivning för lista
  String get shortDescription {
    return '${_getResourceTypeName().capitalizeFirst()}: $resourceTitle';
  }

  String _getResourceTypeName() {
    switch (resourceType) {
      case RealtimeResourceType.recipe:
        return 'recept';
      case RealtimeResourceType.menu:
        return 'meny';
      case RealtimeResourceType.shoppingList:
        return 'inköpslista';
    }
  }

  /// Ikon för resursen
  String get resourceIcon {
    switch (resourceType) {
      case RealtimeResourceType.recipe:
        return '🍳';
      case RealtimeResourceType.menu:
        return '📋';
      case RealtimeResourceType.shoppingList:
        return '🛒';
    }
  }

  /// Statusikon
  String get statusIcon {
    switch (status) {
      case RealtimeInvitationStatus.pending:
        return isExpired ? '⏰' : '⏳';
      case RealtimeInvitationStatus.accepted:
        return '✅';
      case RealtimeInvitationStatus.rejected:
        return '❌';
      case RealtimeInvitationStatus.expired:
        return '⏰';
      case RealtimeInvitationStatus.cancelled:
        return '🚫';
    }
  }

  /// Statustext
  String get statusText {
    switch (status) {
      case RealtimeInvitationStatus.pending:
        return isExpired ? 'Utgången' : 'Väntande';
      case RealtimeInvitationStatus.accepted:
        return 'Accepterad';
      case RealtimeInvitationStatus.rejected:
        return 'Avvisad';
      case RealtimeInvitationStatus.expired:
        return 'Utgången';
      case RealtimeInvitationStatus.cancelled:
        return 'Avbruten';
    }
  }

  // ===== STATE CHANGES =====

  /// Acceptera inbjudan
  RealtimeInvitation accept() {
    return copyWith(
      status: RealtimeInvitationStatus.accepted,
      respondedAt: DateTime.now(),
    );
  }

  /// Avvisa inbjudan
  RealtimeInvitation reject() {
    return copyWith(
      status: RealtimeInvitationStatus.rejected,
      respondedAt: DateTime.now(),
    );
  }

  /// Avbryt inbjudan (endast avsändare)
  RealtimeInvitation cancel() {
    return copyWith(
      status: RealtimeInvitationStatus.cancelled,
      respondedAt: DateTime.now(),
    );
  }

  /// Markera som utgången
  RealtimeInvitation expire() {
    return copyWith(
      status: RealtimeInvitationStatus.expired,
      respondedAt: DateTime.now(),
    );
  }

  // ===== COPY WITH =====

  RealtimeInvitation copyWith({
    String? resourceTitle,
    RealtimeInvitationStatus? status,
    DateTime? respondedAt,
    DateTime? expiresAt,
    String? message,
    String? permissionLevel,
    Map<String, dynamic>? metadata,
  }) {
    return RealtimeInvitation(
      id: id,
      resourceType: resourceType,
      resourceId: resourceId,
      resourceTitle: resourceTitle ?? this.resourceTitle,
      fromUserId: fromUserId,
      fromUserDisplayName: fromUserDisplayName,
      target: target,
      status: status ?? this.status,
      sentAt: sentAt,
      respondedAt: respondedAt ?? this.respondedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      message: message ?? this.message,
      permissionLevel: permissionLevel ?? this.permissionLevel,
      metadata: metadata ?? this.metadata,
    );
  }

  // ===== SERIALIZATION =====

  /// Konvertera till Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'resourceType': resourceType.value,
      'resourceId': resourceId,
      'resourceTitle': resourceTitle,
      'fromUserId': fromUserId,
      'fromUserDisplayName': fromUserDisplayName,
      'target': target.toFirestore(),
      'status': status.name,
      'sentAt': Timestamp.fromDate(sentAt),
      'respondedAt':
          respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'message': message,
      'permissionLevel': permissionLevel,
      'metadata': metadata,
    };
  }

  /// Skapa från Firestore
  factory RealtimeInvitation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return RealtimeInvitation(
      id: doc.id,
      resourceType: RealtimeResourceType.fromString(
        data['resourceType'] as String? ?? 'recipe',
      ),
      resourceId: data['resourceId'] as String,
      resourceTitle: data['resourceTitle'] as String? ?? '',
      fromUserId: data['fromUserId'] as String,
      fromUserDisplayName: data['fromUserDisplayName'] as String? ?? '',
      target: InvitationTarget.fromFirestore(
        data['target'] as Map<String, dynamic>,
      ),
      status: RealtimeInvitationStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => RealtimeInvitationStatus.pending,
      ),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 7)),
      message: data['message'] as String?,
      permissionLevel: data['permissionLevel'] as String? ?? 'editor',
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  /// JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'resourceType': resourceType.value,
      'resourceId': resourceId,
      'resourceTitle': resourceTitle,
      'fromUserId': fromUserId,
      'fromUserDisplayName': fromUserDisplayName,
      'target': target.toJson(),
      'status': status.name,
      'sentAt': sentAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'message': message,
      'permissionLevel': permissionLevel,
      'metadata': metadata,
    };
  }

  factory RealtimeInvitation.fromJson(Map<String, dynamic> json) {
    return RealtimeInvitation(
      id: json['id'] as String,
      resourceType: RealtimeResourceType.fromString(
        json['resourceType'] as String? ?? 'recipe',
      ),
      resourceId: json['resourceId'] as String,
      resourceTitle: json['resourceTitle'] as String? ?? '',
      fromUserId: json['fromUserId'] as String,
      fromUserDisplayName: json['fromUserDisplayName'] as String? ?? '',
      target: InvitationTarget.fromJson(
        json['target'] as Map<String, dynamic>,
      ),
      status: RealtimeInvitationStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => RealtimeInvitationStatus.pending,
      ),
      sentAt: DateTime.parse(json['sentAt'] as String),
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'] as String)
          : null,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      message: json['message'] as String?,
      permissionLevel: json['permissionLevel'] as String? ?? 'editor',
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  @override
  String toString() {
    return 'RealtimeInvitation('
        'id: $id, '
        'resource: $resourceType/$resourceId, '
        'from: $fromUserDisplayName, '
        'to: ${target.displayName}, '
        'status: $status'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RealtimeInvitation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Extension för att lägga till capitalize-funktionalitet
extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
