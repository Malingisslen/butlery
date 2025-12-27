// lib/models/shared_content_member.dart

import 'package:butlery/core/utils/serialization_utils.dart';

/// Denormalized member info stored in content/{id}/members subcollection.
/// Stores user display info to avoid N+1 queries when listing participants.
///
/// This model addresses V1-QP-001 by caching user display info at share time,
/// allowing participant lists to be rendered without additional user lookups.
class SharedContentMember {
  /// User ID of the member
  final String userId;

  /// Display name at time of sharing (denormalized)
  final String displayName;

  /// Avatar URL at time of sharing (denormalized, may be null)
  final String? avatarUrl;

  /// When this member was added
  final DateTime addedAt;

  /// User ID who added this member
  final String addedBy;

  /// Role of this member (viewer, editor, admin)
  final String role;

  /// Whether this member has viewed the content
  final bool hasViewed;

  const SharedContentMember({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.addedAt,
    required this.addedBy,
    this.role = 'viewer',
    this.hasViewed = false,
  });

  /// Create from Firestore document
  factory SharedContentMember.fromFirestore(Map<String, dynamic> data) {
    return SharedContentMember(
      userId: SerializationUtils.safeString(data, 'userId'),
      displayName: SerializationUtils.safeString(data, 'displayName',
          defaultValue: 'Användare'),
      avatarUrl: SerializationUtils.safeNullableString(data, 'avatarUrl'),
      addedAt:
          SerializationUtils.safeDateTime(data, 'addedAt') ?? DateTime.now(),
      addedBy: SerializationUtils.safeString(data, 'addedBy'),
      role: SerializationUtils.safeString(data, 'role', defaultValue: 'viewer'),
      hasViewed: SerializationUtils.safeBool(data, 'hasViewed'),
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'addedAt': addedAt.millisecondsSinceEpoch,
      'addedBy': addedBy,
      'role': role,
      'hasViewed': hasViewed,
    };
  }

  /// Get initials for avatar fallback
  String get initials {
    if (displayName.isEmpty) return '?';

    final words = displayName.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      final word = words[0];
      return word.length >= 2
          ? '${word[0]}${word[1]}'.toUpperCase()
          : word[0].toUpperCase();
    } else {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
  }

  SharedContentMember copyWith({
    String? displayName,
    String? avatarUrl,
    String? role,
    bool? hasViewed,
  }) {
    return SharedContentMember(
      userId: userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      addedAt: addedAt,
      addedBy: addedBy,
      role: role ?? this.role,
      hasViewed: hasViewed ?? this.hasViewed,
    );
  }

  @override
  String toString() {
    return 'SharedContentMember(userId: $userId, displayName: $displayName, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SharedContentMember && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;
}
