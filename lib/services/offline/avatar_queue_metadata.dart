// lib/services/offline/avatar_queue_metadata.dart
//
// BUT-2294: what a queued profile picture carries on its row. Kept apart from
// the completion so the profile code can build it without importing
// native-only database code (the web build).
library;

import 'dart:convert';

/// The picture the user was looking at when they chose the new one, which the
/// completion compares with the profile's before it replaces it. Null is a
/// profile that had none.
Map<String, Object?> avatarQueueMetadata({required String? baseAvatarUrl}) => {
  'baseAvatarUrl': baseAvatarUrl,
};

/// The base picture of a row, or null when the row carries none to compare
/// with. Wrapped so a base of "no picture" is told from a row that is
/// unreadable.
({String? url})? avatarBaseUrl(String? metadataJson) {
  if (metadataJson == null) return null;
  final decoded = jsonDecode(metadataJson);
  if (decoded is! Map || !decoded.containsKey('baseAvatarUrl')) return null;
  final url = decoded['baseAvatarUrl'];
  return url is String || url == null ? (url: url as String?) : null;
}
