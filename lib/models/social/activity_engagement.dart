// lib/models/social/activity_engagement.dart

/// Activity engagement metrics for social interactions (likes, comments, shares, views).
class ActivityEngagement {
  /// Number of likes/reactions on this activity
  final int likes;

  /// Number of comments on this activity
  final int comments;

  /// Number of shares of this activity
  final int shares;

  /// Number of views of this activity
  final int views;

  const ActivityEngagement({
    required this.likes,
    required this.comments,
    required this.shares,
    required this.views,
  });

  /// Create empty engagement metrics
  factory ActivityEngagement.empty() {
    return const ActivityEngagement(
      likes: 0,
      comments: 0,
      shares: 0,
      views: 0,
    );
  }

  /// Create from Firestore data
  factory ActivityEngagement.fromFirestore(Map<String, dynamic> data) {
    return ActivityEngagement(
      likes: data['likes'] as int? ?? 0,
      comments: data['comments'] as int? ?? 0,
      shares: data['shares'] as int? ?? 0,
      views: data['views'] as int? ?? 0,
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'views': views,
    };
  }

  /// Convert to JSON format
  Map<String, dynamic> toJson() {
    return {
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'views': views,
    };
  }

  /// Create from JSON format
  factory ActivityEngagement.fromJson(Map<String, dynamic> json) {
    return ActivityEngagement(
      likes: json['likes'] as int? ?? 0,
      comments: json['comments'] as int? ?? 0,
      shares: json['shares'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
    );
  }

  /// Get total engagement count
  int get totalEngagement => likes + comments + shares;

  /// Check if activity has any engagement
  bool get hasEngagement => totalEngagement > 0;

  /// Create copy with updated metrics
  ActivityEngagement copyWith({
    int? likes,
    int? comments,
    int? shares,
    int? views,
  }) {
    return ActivityEngagement(
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      views: views ?? this.views,
    );
  }
}
