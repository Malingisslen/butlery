// lib/services/offline/comment_queue_metadata.dart
//
// BUT-2294: what a queued comment carries on each photo row. Kept apart from
// the completion so the comment code can build it without importing
// native-only database code (the web build).
library;

/// What the comment is, kept on each of its rows when it is queued. The
/// recipe's name is for the queue's row label.
Map<String, Object?> commentQueueMetadata({
  required String recipeId,
  required String recipeName,
  required String text,
  String? parentCommentId,
}) => {
  'recipeId': recipeId,
  'recipeName': recipeName,
  'text': text,
  'parentCommentId': ?parentCommentId,
};
