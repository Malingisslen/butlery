// lib/services/offline/chat_image_queue_metadata.dart
//
// BUT-2294: what a queued chat image carries on its row. Kept apart from the
// completion so the chat code can build it without importing native-only
// database code (the web build).
library;

import 'dart:convert';

/// The conversation is needed after the message is gone from the server's
/// view: the rules refuse a read of a message that does not exist, so only the
/// conversation tells "never arrived" from "no longer a member".
Map<String, Object?> chatImageQueueMetadata({required String conversationId}) =>
    {'conversationId': conversationId};

String? chatImageConversationId(String? metadataJson) {
  if (metadataJson == null) return null;
  final decoded = jsonDecode(metadataJson);
  return decoded is Map ? decoded['conversationId'] as String? : null;
}
