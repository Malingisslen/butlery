import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';

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
    return ContextualTimeFormatter.standard(sharedAt);
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
      'sharedByUserId': SerializationUtils.safeString(data, 'sharedByUserId'),
      'sharedByDisplayName': SerializationUtils.safeString(
        data,
        'sharedByDisplayName',
      ),
      'sharedAt': SerializationUtils.parseRequiredDateTimeValue(
        data['sharedAt'],
      ),
      'shareMessage': SerializationUtils.safeNullableString(
        data,
        'shareMessage',
      ),
      'viewCount': SerializationUtils.safeInt(data, 'viewCount'),
      'engagementCount': SerializationUtils.safeInt(data, 'engagementCount'),
      'dismissalCount': SerializationUtils.safeInt(data, 'dismissalCount'),
    };
  }

  static Map<String, dynamic> parseCommonFieldsFromJson(
    Map<String, dynamic> json,
  ) {
    return {
      'id': SerializationUtils.safeString(json, 'id'),
      'sharedByUserId': SerializationUtils.safeString(json, 'sharedByUserId'),
      'sharedByDisplayName': SerializationUtils.safeString(
        json,
        'sharedByDisplayName',
      ),
      'sharedAt': SerializationUtils.safeRequiredDateTime(json, 'sharedAt'),
      'shareMessage': SerializationUtils.safeNullableString(
        json,
        'shareMessage',
      ),
      'viewCount': SerializationUtils.safeInt(json, 'viewCount'),
      'engagementCount': SerializationUtils.safeInt(json, 'engagementCount'),
      'dismissalCount': SerializationUtils.safeInt(json, 'dismissalCount'),
    };
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
