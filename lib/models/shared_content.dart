// lib/models/shared_content.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing shared content in the social platform
class SharedContent {
  final String id;
  final String contentType; // 'recipe', 'menu', 'shopping_list'
  final String contentId;
  final String ownerId;
  final List<String> sharedWithUserIds;
  final List<String> sharedWithGroupIds;
  final DateTime sharedAt;
  final Map<String, dynamic> metadata;
  final SharingPermissions permissions;
  final Map<String, DateTime> viewedBy;
  final Map<String, DateTime> acceptedBy;
  final Map<String, DateTime> declinedBy;

  SharedContent({
    required this.id,
    required this.contentType,
    required this.contentId,
    required this.ownerId,
    required this.sharedWithUserIds,
    required this.sharedWithGroupIds,
    required this.sharedAt,
    required this.metadata,
    required this.permissions,
    Map<String, DateTime>? viewedBy,
    Map<String, DateTime>? acceptedBy,
    Map<String, DateTime>? declinedBy,
  }) : viewedBy = viewedBy ?? {},
       acceptedBy = acceptedBy ?? {},
       declinedBy = declinedBy ?? {};

  factory SharedContent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SharedContent(
      id: doc.id,
      contentType: data['contentType'] ?? '',
      contentId: data['contentId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      sharedWithUserIds: List<String>.from(data['sharedWithUserIds'] ?? []),
      sharedWithGroupIds: List<String>.from(data['sharedWithGroupIds'] ?? []),
      sharedAt: (data['sharedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      permissions: SharingPermissions.fromMap(data['permissions'] ?? {}),
      viewedBy: _dateMapFromFirestore(data['viewedBy']),
      acceptedBy: _dateMapFromFirestore(data['acceptedBy']),
      declinedBy: _dateMapFromFirestore(data['declinedBy']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'contentType': contentType,
      'contentId': contentId,
      'ownerId': ownerId,
      'sharedWithUserIds': sharedWithUserIds,
      'sharedWithGroupIds': sharedWithGroupIds,
      'sharedAt': Timestamp.fromDate(sharedAt),
      'metadata': metadata,
      'permissions': permissions.toMap(),
      'viewedBy': _dateMapToFirestore(viewedBy),
      'acceptedBy': _dateMapToFirestore(acceptedBy),
      'declinedBy': _dateMapToFirestore(declinedBy),
    };
  }

  static Map<String, DateTime> _dateMapFromFirestore(dynamic data) {
    if (data == null || data is! Map) return {};
    
    final result = <String, DateTime>{};
    data.forEach((key, value) {
      if (value is Timestamp) {
        result[key] = value.toDate();
      }
    });
    return result;
  }

  static Map<String, Timestamp> _dateMapToFirestore(Map<String, DateTime> dates) {
    return dates.map((key, value) => MapEntry(key, Timestamp.fromDate(value)));
  }

  SharedContent copyWith({
    String? id,
    String? contentType,
    String? contentId,
    String? ownerId,
    List<String>? sharedWithUserIds,
    List<String>? sharedWithGroupIds,
    DateTime? sharedAt,
    Map<String, dynamic>? metadata,
    SharingPermissions? permissions,
    Map<String, DateTime>? viewedBy,
    Map<String, DateTime>? acceptedBy,
    Map<String, DateTime>? declinedBy,
  }) {
    return SharedContent(
      id: id ?? this.id,
      contentType: contentType ?? this.contentType,
      contentId: contentId ?? this.contentId,
      ownerId: ownerId ?? this.ownerId,
      sharedWithUserIds: sharedWithUserIds ?? this.sharedWithUserIds,
      sharedWithGroupIds: sharedWithGroupIds ?? this.sharedWithGroupIds,
      sharedAt: sharedAt ?? this.sharedAt,
      metadata: metadata ?? this.metadata,
      permissions: permissions ?? this.permissions,
      viewedBy: viewedBy ?? this.viewedBy,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      declinedBy: declinedBy ?? this.declinedBy,
    );
  }
}

/// Permissions for shared content
class SharingPermissions {
  final bool canView;
  final bool canEdit;
  final bool canReshare;
  final bool canComment;
  final DateTime? expiresAt;

  SharingPermissions({
    this.canView = true,
    this.canEdit = false,
    this.canReshare = false,
    this.canComment = true,
    this.expiresAt,
  });

  factory SharingPermissions.fromMap(Map<String, dynamic> map) {
    return SharingPermissions(
      canView: map['canView'] ?? true,
      canEdit: map['canEdit'] ?? false,
      canReshare: map['canReshare'] ?? false,
      canComment: map['canComment'] ?? true,
      expiresAt: map['expiresAt'] != null
          ? (map['expiresAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'canView': canView,
      'canEdit': canEdit,
      'canReshare': canReshare,
      'canComment': canComment,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}