/// Firebase Firestore Data Transfer Object for comprehensive message model serialization and deserialization.
/// This DTO provides sophisticated bidirectional conversion between Message domain models and Firebase
/// Firestore document format, with specialized handling for both standalone message documents and nested
/// message data within conversation objects. It ensures data integrity, type safety, and optimal
/// performance for real-time messaging operations with comprehensive status tracking and metadata support.
/// **Architecture Integration:**
/// - Provides clean separation between domain models and Firebase storage format
/// - Handles both document-level and nested map-level serialization for flexible usage
/// - Manages Firebase Timestamp conversions for accurate temporal data representation
/// - Integrates with MessageType and MessageStatus enums for type-safe status management
/// - Optimizes Firestore document structure for efficient queries and real-time updates
/// **Message Serialization Features:**
/// - **Dual Format Support**: Handles both Firestore documents and nested map representations
/// - **Status Tracking**: Comprehensive message status management (sent, delivered, read)
/// - **Temporal Precision**: Accurate timestamp handling for sent, delivered, read, and edit times
/// - **Metadata Handling**: Flexible metadata support for extensible message features
/// - **Reply Threading**: Support for message threading with reply-to relationships
/// - **Edit History**: Message editing support with edit timestamps and status tracking
/// **Performance and Safety:**
/// - **Type Safety**: Comprehensive enum handling with safe fallback values
/// - **Null Safety**: Robust nullable field handling throughout conversion process
/// - **Server Timestamps**: Automatic server timestamp generation for consistency
/// - **Efficient Queries**: Optimized data structure for Firestore indexing and real-time streams

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/messaging/message.dart';

// MessageStatus is already available through message.dart import
/// Firebase DTO for message data serialization with comprehensive status tracking and metadata support.
/// This static utility class provides sophisticated bidirectional conversion between Message domain
/// models and Firebase Firestore storage formats. It supports both standalone document serialization
/// and nested map format for use within conversation objects, ensuring optimal performance and
/// data integrity across all messaging operations.
/// **Conversion Capabilities:**
/// - **Document Conversion**: Direct Firestore document to Message model transformation
/// - **Nested Map Handling**: Flexible map-based conversion for embedded message data
/// - **Status Management**: Comprehensive message status tracking with enum safety
/// - **Temporal Accuracy**: Precise timestamp handling for all message lifecycle events
/// - **Threading Support**: Message reply relationships with proper referential integrity
/// **Usage Examples:**
/// ```dart
/// // Convert Firestore document to Message
/// final message = MessageDto.fromFirestore(documentSnapshot);
/// // Convert nested map data (e.g., from conversation.lastMessage)
/// final lastMessage = MessageDto.fromMap(conversationData['lastMessage']);
/// // Serialize message for Firestore storage
/// final firestoreData = MessageDto.toFirestore(message);
/// await firestore.collection('messages').doc(id).set(firestoreData);
/// ```
class MessageDto {
  /// Converts a Firestore document snapshot to a Message domain model.
  /// Provides direct conversion from Firestore document format to Message model by
  /// delegating to the map-based conversion method with the document ID extracted.
  /// [doc] The Firestore document snapshot containing message data
  /// Returns a fully populated [Message] model with document ID properly set
  static Message fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return fromMap(data, documentId: doc.id);
  }

  /// Converts a map of message data to a Message domain model.
  /// Performs comprehensive deserialization of message data including status tracking,
  /// timestamp conversion, metadata handling, and reply threading. Provides safe enum
  /// conversion with fallback values and robust nullable field handling.
  /// [data] The map containing message data from Firestore or nested structures
  /// [documentId] Optional document ID when converting from nested data
  /// Returns a fully populated [Message] model with all fields properly converted
  /// **Conversion Features:**
  /// - Message type and status enums with safe fallback handling
  /// - Comprehensive timestamp conversion for all temporal fields
  /// - Sender information including display name and avatar URL
  /// - Reply-to relationships for message threading support
  /// - Edit history tracking with edit timestamps and status
  /// - Flexible metadata preservation for extensible message features
  static Message fromMap(Map<String, dynamic> data, {String? documentId}) {
    return Message(
      id: documentId ?? data['id'] as String,
      conversationId: data['conversationId'] as String,
      senderId: data['senderId'] as String,
      senderDisplayName: data['senderDisplayName'] as String,
      senderAvatarUrl: data['senderAvatarUrl'] as String?,
      content: data['content'] as String,
      type: MessageType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => MessageStatus.sent,
      ),
      sentAt: (data['sentAt'] as Timestamp).toDate(),
      deliveredAt: data['deliveredAt'] != null
          ? (data['deliveredAt'] as Timestamp).toDate()
          : null,
      readAt: data['readAt'] != null
          ? (data['readAt'] as Timestamp).toDate()
          : null,
      metadata: data['metadata'] as Map<String, dynamic>?,
      replyToMessageId: data['replyToMessageId'] as String?,
      isEdited: data['isEdited'] as bool? ?? false,
      editedAt: data['editedAt'] != null
          ? (data['editedAt'] as Timestamp).toDate()
          : null,
      reactions: _parseReactions(data['reactions']),
    );
  }

  /// Parse reactions map from Firestore data.
  /// Converts Map<String, dynamic> where values are lists into Map<String, List<String>>.
  static Map<String, List<String>> _parseReactions(dynamic raw) {
    if (raw == null) return const {};
    if (raw is! Map) return const {};
    final result = <String, List<String>>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is List) {
        result[key] = value.map((e) => e.toString()).toList();
      }
    }
    return result;
  }

  /// Convert Message model to Firestore document
  static Map<String, dynamic> toFirestore(Message message) {
    return {
      'conversationId': message.conversationId,
      'senderId': message.senderId,
      'senderDisplayName': message.senderDisplayName,
      'senderAvatarUrl': message.senderAvatarUrl,
      'content': message.content,
      'type': message.type.name,
      'status': message.status.name,
      'sentAt': Timestamp.fromDate(message.sentAt),
      'deliveredAt': message.deliveredAt != null
          ? Timestamp.fromDate(message.deliveredAt!)
          : null,
      'readAt':
          message.readAt != null ? Timestamp.fromDate(message.readAt!) : null,
      'metadata': message.metadata,
      'replyToMessageId': message.replyToMessageId,
      'isEdited': message.isEdited,
      'editedAt': message.editedAt != null
          ? Timestamp.fromDate(message.editedAt!)
          : null,
      if (message.reactions.isNotEmpty) 'reactions': message.reactions,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convert Message model to Map (for nested message data)
  static Map<String, dynamic> toMap(Message message) {
    return {
      'id': message.id,
      'conversationId': message.conversationId,
      'senderId': message.senderId,
      'senderDisplayName': message.senderDisplayName,
      'senderAvatarUrl': message.senderAvatarUrl,
      'content': message.content,
      'type': message.type.name,
      'status': message.status.name,
      'sentAt': Timestamp.fromDate(message.sentAt),
      'deliveredAt': message.deliveredAt != null
          ? Timestamp.fromDate(message.deliveredAt!)
          : null,
      'readAt':
          message.readAt != null ? Timestamp.fromDate(message.readAt!) : null,
      'metadata': message.metadata,
      'replyToMessageId': message.replyToMessageId,
      'isEdited': message.isEdited,
      'editedAt': message.editedAt != null
          ? Timestamp.fromDate(message.editedAt!)
          : null,
      if (message.reactions.isNotEmpty) 'reactions': message.reactions,
    };
  }
}
