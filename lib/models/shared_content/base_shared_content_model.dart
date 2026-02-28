import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/time_ago_formatter.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Abstract base class for all shared content models providing common functionality.
abstract class BaseSharedContentModel<TContent> {
  final String id;
  final String sharedByUserId;
  final String sharedByDisplayName;
  final DateTime sharedAt;
  final String? shareMessage;

  /// Status counts (user lists stored in Firestore subcollections per Issue #014).
  final int viewCount;
  final int engagementCount;
  final int dismissalCount;

  const BaseSharedContentModel({
    required this.id,
    required this.sharedByUserId,
    required this.sharedByDisplayName,
    required this.sharedAt,
    this.shareMessage,
    this.viewCount = 0,
    this.engagementCount = 0,
    this.dismissalCount = 0,
  });

  String get contentTypeName;
  TContent get contentSnapshot;
  String getContentTitle();
  String getContentDescription();

  /// Create a copy with updated status counts. Status checking handled by repository layer.
  BaseSharedContentModel<TContent> copyWithStatus({
    int? viewCount,
    int? engagementCount,
    int? dismissalCount,
  });

  double get conversionRate {
    if (viewCount == 0) return 0.0;
    return (engagementCount / viewCount) * 100.0;
  }

  /// Localized text for how long ago the content was shared.
  String get timeAgoText {
    return TimeAgoFormatter.standard(sharedAt);
  }

  /// Common Firestore fields for all content types.
  Map<String, dynamic> getCommonFirestoreFields() {
    return {
      'sharedByUserId': sharedByUserId,
      'sharedByDisplayName': sharedByDisplayName,
      'sharedAt': AppTimestamp.fromDateTime(sharedAt).toFirestore(),
      'shareMessage': shareMessage,
      'viewCount': viewCount,
      'engagementCount': engagementCount,
      'dismissalCount': dismissalCount,
    };
  }

  /// Common JSON fields for caching.
  Map<String, dynamic> getCommonJsonFields() {
    return {
      'id': id,
      'sharedByUserId': sharedByUserId,
      'sharedByDisplayName': sharedByDisplayName,
      'sharedAt': sharedAt.toIso8601String(),
      'shareMessage': shareMessage,
      'viewCount': viewCount,
      'engagementCount': engagementCount,
      'dismissalCount': dismissalCount,
    };
  }

  static Map<String, dynamic> parseCommonFieldsFromFirestore(
    Map<String, dynamic> data,
  ) {
    return {
      'sharedByUserId': (data['sharedByUserId'] as String?).orEmpty(),
      'sharedByDisplayName': (data['sharedByDisplayName'] as String?).orEmpty(),
      'sharedAt': parseTimestamp(data['sharedAt']) ?? DateTime.now(),
      'shareMessage': data['shareMessage'] as String?,
      'viewCount': data['viewCount'] as int? ?? 0,
      'engagementCount': data['engagementCount'] as int? ?? 0,
      'dismissalCount': data['dismissalCount'] as int? ?? 0,
    };
  }

  static Map<String, dynamic> parseCommonFieldsFromJson(
    Map<String, dynamic> json,
  ) {
    return {
      'id': json['id'] as String,
      'sharedByUserId': (json['sharedByUserId'] as String?).orEmpty(),
      'sharedByDisplayName': (json['sharedByDisplayName'] as String?).orEmpty(),
      'sharedAt': DateTime.parse(json['sharedAt'] as String),
      'shareMessage': json['shareMessage'] as String?,
      'viewCount': json['viewCount'] as int? ?? 0,
      'engagementCount': json['engagementCount'] as int? ?? 0,
      'dismissalCount': json['dismissalCount'] as int? ?? 0,
    };
  }

  /// Robust timestamp parsing supporting multiple formats.
  static DateTime? parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    try {
      if (timestamp is DateTime) {
        return timestamp;
      } else if (timestamp is Map) {
        // Handle raw timestamp data from Firestore
        final seconds = timestamp['seconds'] as int?;
        final nanoseconds = timestamp['nanoseconds'] as int? ?? 0;
        if (seconds != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + nanoseconds ~/ 1000000,
          );
        }
      } else if (timestamp is int) {
        // Handle milliseconds since epoch
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        // Handle ISO string format
        return DateTime.parse(timestamp);
      } else if (timestamp.runtimeType.toString() == 'Timestamp') {
        // Handle Firestore Timestamp objects
        try {
          return (timestamp as dynamic).toDate() as DateTime;
        } catch (e) {
          return DateTime.now();
        }
      }

      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  @override
  String toString() {
    return '$contentTypeName(id: $id, title: ${getContentTitle()}, sharedBy: $sharedByDisplayName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BaseSharedContentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
