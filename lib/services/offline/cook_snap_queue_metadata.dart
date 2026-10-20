// lib/services/offline/cook_snap_queue_metadata.dart
//
// BUT-2294: what a queued cook snap carries on each photo row. Kept apart from
// the completion so the cook snap service can build it without importing
// native-only database code (the web build).
library;

import 'package:butlery/models/cook_snap.dart';

/// What the snap is, kept on each of its rows when it is queued.
Map<String, Object?> cookSnapQueueMetadata({
  required String recipeId,
  required String recipeAuthorId,
  required String recipeName,
  required CookSnapVisibility visibility,
  String? caption,
}) => {
  'recipeId': recipeId,
  'recipeAuthorId': recipeAuthorId,
  'recipeName': recipeName,
  'visibility': visibility.name,
  'caption': ?caption,
};
