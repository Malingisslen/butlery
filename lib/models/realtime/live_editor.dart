// lib/models/realtime/live_editor.dart

/// Represents a live editor currently editing a collaborative resource
class LiveEditor {
  final String userId;
  final String displayName;
  final DateTime lastSeen;
  final String? currentField; // Which field they're currently editing
  final bool isActive;

  LiveEditor({
    required this.userId,
    required this.displayName,
    required this.lastSeen,
    this.currentField,
    this.isActive = true,
  });

  factory LiveEditor.fromFirestore(Map<String, dynamic> data) {
    return LiveEditor(
      userId: data['userId'] as String,
      displayName: data['displayName'] as String,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(data['lastSeen'] as int),
      currentField: data['currentField'] as String?,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'displayName': displayName,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'currentField': currentField,
      'isActive': isActive,
    };
  }

  LiveEditor copyWith({
    String? userId,
    String? displayName,
    DateTime? lastSeen,
    String? currentField,
    bool? isActive,
  }) {
    return LiveEditor(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      lastSeen: lastSeen ?? this.lastSeen,
      currentField: currentField ?? this.currentField,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LiveEditor && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() {
    return 'LiveEditor(userId: $userId, displayName: $displayName, isActive: $isActive)';
  }
}