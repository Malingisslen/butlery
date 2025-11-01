/// Shared content model with multi-target distribution and engagement tracking.

// lib/models/shared_content.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Shared content model with multi-target distribution and engagement tracking.
class SharedContent {
  /// Unique identifier for this shared content instance.
  final String id;
  
  /// Type of content being shared for categorization and handling.
  final String contentType; // 'recipe', 'menu', 'shopping_list'
  
  /// Identifier of the actual content being shared.
  final String contentId;
  
  /// User identifier of the content owner who initiated sharing.
  final String ownerId;
  
  /// List of individual user IDs that the content is shared with.
  final List<String> sharedWithUserIds;
  
  /// List of group IDs that the content is shared with.
  final List<String> sharedWithGroupIds;
  
  /// Timestamp when the content was originally shared.
  final DateTime sharedAt;
  
  /// Flexible metadata container for content-specific sharing information.
  final Map<String, dynamic> metadata;
  
  /// Granular permissions controlling recipient capabilities.
  final SharingPermissions permissions;
  
  /// Tracking map of users who have viewed the shared content.
  final Map<String, DateTime> viewedBy;
  
  /// Tracking map of users who have accepted the shared content.
  final Map<String, DateTime> acceptedBy;
  
  /// Tracking map of users who have declined the shared content.
  final Map<String, DateTime> declinedBy;

  /// Creates a new shared content instance with all required sharing metadata.
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


  /// Creates a shared content instance from Firestore document data.
  factory SharedContent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SharedContent(
      id: doc.id,
      contentType: (data['contentType'] as String?).orEmpty(),
      contentId: (data['contentId'] as String?).orEmpty(),
      ownerId: (data['ownerId'] as String?).orEmpty(),
      sharedWithUserIds: List<String>.from((data['sharedWithUserIds'] as List?).orEmpty()),
      sharedWithGroupIds: List<String>.from((data['sharedWithGroupIds'] as List?).orEmpty()),
      sharedAt: (data['sharedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: Map<String, dynamic>.from((data['metadata'] as Map?).orEmpty()),
      permissions: SharingPermissions.fromMap((data['permissions'] as Map<String, dynamic>?).orEmpty()),
      viewedBy: _dateMapFromFirestore(data['viewedBy']),
      acceptedBy: _dateMapFromFirestore(data['acceptedBy']),
      declinedBy: _dateMapFromFirestore(data['declinedBy']),
    );
  }

  /// Converts the shared content to Firestore-compatible format for persistence.
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


  /// Converts Firestore timestamp map to DateTime map for engagement tracking.
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

  /// Converts DateTime map to Firestore timestamp map for persistence.
  static Map<String, Timestamp> _dateMapToFirestore(Map<String, DateTime> dates) {
    return dates.map((key, value) => MapEntry(key, Timestamp.fromDate(value)));
  }

  /// Creates a copy of this shared content with updated values.
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


  /// Gets the total number of recipients (users and groups combined).
  int get totalRecipients => sharedWithUserIds.length + sharedWithGroupIds.length;
  
  /// Gets the total number of users who have viewed the shared content.
  int get viewCount => viewedBy.length;
  
  /// Gets the total number of users who have accepted the shared content.
  int get acceptanceCount => acceptedBy.length;
  
  /// Gets the total number of users who have declined the shared content.
  int get declineCount => declinedBy.length;
  
  /// Calculates the acceptance rate as a percentage of total views.
  double get acceptanceRate {
    if (viewCount == 0) return 0.0;
    return (acceptanceCount / viewCount) * 100.0;
  }
  
  /// Checks if the specified user has viewed the shared content.
  bool hasUserViewed(String userId) => viewedBy.containsKey(userId);
  
  /// Checks if the specified user has accepted the shared content.
  bool hasUserAccepted(String userId) => acceptedBy.containsKey(userId);
  
  /// Checks if the specified user has declined the shared content.
  bool hasUserDeclined(String userId) => declinedBy.containsKey(userId);
}

/// Sharing permissions model with granular access control and expiration management.
class SharingPermissions {
  /// Permission to view the shared content.
  final bool canView;
  
  /// Permission to edit the shared content.
  final bool canEdit;
  
  /// Permission to reshare the content with others.
  final bool canReshare;
  
  /// Permission to comment on the shared content.
  final bool canComment;
  
  /// Optional expiration timestamp for time-limited sharing.
  final DateTime? expiresAt;

  /// Creates sharing permissions with customizable capability settings.
  SharingPermissions({
    this.canView = true,
    this.canEdit = false,
    this.canReshare = false,
    this.canComment = true,
    this.expiresAt,
  });

  /// Creates sharing permissions from Firestore data with proper type conversion.
  factory SharingPermissions.fromMap(Map<String, dynamic> map) {
    return SharingPermissions(
      canView: (map['canView'] as bool?).orTrue(),
      canEdit: (map['canEdit'] as bool?).orFalse(),
      canReshare: (map['canReshare'] as bool?).orFalse(),
      canComment: (map['canComment'] as bool?).orTrue(),
      expiresAt: map['expiresAt'] != null
          ? (map['expiresAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Converts sharing permissions to Firestore-compatible format.
  Map<String, dynamic> toMap() {
    return {
      'canView': canView,
      'canEdit': canEdit,
      'canReshare': canReshare,
      'canComment': canComment,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
    };
  }


  /// Checks if the permissions have expired and are no longer valid.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
  
  /// Checks if the permissions are currently valid and not expired.
  bool get isValid => !isExpired;
  
  /// Creates a copy of permissions with updated capability settings.
  SharingPermissions copyWith({
    bool? canView,
    bool? canEdit,
    bool? canReshare,
    bool? canComment,
    DateTime? expiresAt,
  }) {
    return SharingPermissions(
      canView: canView ?? this.canView,
      canEdit: canEdit ?? this.canEdit,
      canReshare: canReshare ?? this.canReshare,
      canComment: canComment ?? this.canComment,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }


  /// Creates read-only permissions for viewing and commenting only.
  static SharingPermissions readOnly({DateTime? expiresAt}) {
    return SharingPermissions(
      canView: true,
      canEdit: false,
      canReshare: false,
      canComment: true,
      expiresAt: expiresAt,
    );
  }
  
  /// Creates collaborative permissions for full content interaction.
  static SharingPermissions collaborative({DateTime? expiresAt}) {
    return SharingPermissions(
      canView: true,
      canEdit: true,
      canReshare: true,
      canComment: true,
      expiresAt: expiresAt,
    );
  }
  
  /// Creates view-only permissions with no interaction capabilities.
  static SharingPermissions viewOnly({DateTime? expiresAt}) {
    return SharingPermissions(
      canView: true,
      canEdit: false,
      canReshare: false,
      canComment: false,
      expiresAt: expiresAt,
    );
  }
}