import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:butlery/core/utils/serialization_utils.dart';

/// A shared personal tag snapshot for cross-user tag sharing.
///
/// Stored in top-level `shared_personal_tags` collection.
/// Contains a point-in-time snapshot of a personal tag including
/// its rules and matching recipe IDs at share time.
@immutable
class SharedPersonalTag {
  final String id;
  final String tagName;
  final String? tagDescription;
  final String sharedByUserId;
  final String sharedByDisplayName;
  final DateTime sharedAt;
  final List<String> matchingRecipeIds;
  final List<Map<String, dynamic>> tagRules;

  const SharedPersonalTag({
    required this.id,
    required this.tagName,
    this.tagDescription,
    required this.sharedByUserId,
    required this.sharedByDisplayName,
    required this.sharedAt,
    this.matchingRecipeIds = const [],
    this.tagRules = const [],
  });

  /// Creates a new shared tag with generated ID.
  factory SharedPersonalTag.create({
    required String tagName,
    String? tagDescription,
    required String sharedByUserId,
    required String sharedByDisplayName,
    List<String> matchingRecipeIds = const [],
    List<Map<String, dynamic>> tagRules = const [],
  }) {
    return SharedPersonalTag(
      id: const Uuid().v4(),
      tagName: tagName,
      tagDescription: tagDescription,
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedAt: DateTime.now(),
      matchingRecipeIds: matchingRecipeIds,
      tagRules: tagRules,
    );
  }

  factory SharedPersonalTag.fromMap(String id, Map<String, dynamic> data) {
    return SharedPersonalTag(
      id: id,
      tagName: SerializationUtils.safeString(data, 'tagName', defaultValue: ''),
      tagDescription: SerializationUtils.safeNullableString(
        data,
        'tagDescription',
      ),
      sharedByUserId: SerializationUtils.safeString(
        data,
        'sharedByUserId',
        defaultValue: '',
      ),
      sharedByDisplayName: SerializationUtils.safeString(
        data,
        'sharedByDisplayName',
        defaultValue: '',
      ),
      sharedAt: SerializationUtils.safeRequiredDateTime(
        data,
        'sharedAt',
        defaultValue: DateTime.now(),
      ),
      matchingRecipeIds: SerializationUtils.safeStringList(
        data,
        'matchingRecipeIds',
      ),
      tagRules: _parseRules(data['tagRules']),
    );
  }

  static List<Map<String, dynamic>> _parseRules(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];
    return value.whereType<Map<String, dynamic>>().toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'tagName': tagName,
      if (tagDescription != null) 'tagDescription': tagDescription,
      'sharedByUserId': sharedByUserId,
      'sharedByDisplayName': sharedByDisplayName,
      'sharedAt': Timestamp.fromDate(sharedAt),
      'matchingRecipeIds': matchingRecipeIds,
      if (tagRules.isNotEmpty) 'tagRules': tagRules,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedPersonalTag &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SharedPersonalTag(id: $id, tagName: $tagName, by: $sharedByDisplayName)';
}
