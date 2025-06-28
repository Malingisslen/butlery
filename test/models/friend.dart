// lib/models/friend.dart

/// 🔍 AI INFO BLOCK:
/// Component: Friend Model
/// File: models/friend.dart
/// Quick Guide: Datamodell för vänner i social delning
/// Dependencies IN: None
/// Dependencies OUT: FriendsService, social features
/// Data flow: Model för vän-data
/// State management: Immutable data class
/// Purpose: Representerar en vän för delning
/// Common issues: N/A
/// Test coverage: Via service tests
/// Performance: ⚡ Lightweight model
/// Analytics: N/A
/// Code smells: ✅ Clean data model
/// Connected to: FriendsService, ShoppingListShareDialog
/// Used in phases: Social features

class Friend {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final DateTime? lastActive;
  final bool isOnline;

  Friend({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.lastActive,
    this.isOnline = false,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      photoUrl: json['photoUrl'] as String?,
      lastActive: json['lastActive'] != null
          ? DateTime.parse(json['lastActive'] as String)
          : null,
      isOnline: json['isOnline'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'lastActive': lastActive?.toIso8601String(),
      'isOnline': isOnline,
    };
  }

  Friend copyWith({
    String? id,
    String? name,
    String? email,
    String? photoUrl,
    DateTime? lastActive,
    bool? isOnline,
  }) {
    return Friend(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      lastActive: lastActive ?? this.lastActive,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Friend && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Friend(id: $id, name: $name, email: $email)';
}
