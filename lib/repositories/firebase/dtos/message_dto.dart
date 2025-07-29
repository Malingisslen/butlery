// lib/repositories/firebase/dtos/message_dto.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/message_type.dart';

/// Data Transfer Object for Firebase conversion of Message models
class MessageDto {
  /// Convert Firestore document to Message model
  static Message fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return fromMap(data, documentId: doc.id);
  }

  /// Convert Map to Message model (for nested message data)
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
    );
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
      'deliveredAt': message.deliveredAt != null ? Timestamp.fromDate(message.deliveredAt!) : null,
      'readAt': message.readAt != null ? Timestamp.fromDate(message.readAt!) : null,
      'metadata': message.metadata,
      'replyToMessageId': message.replyToMessageId,
      'isEdited': message.isEdited,
      'editedAt': message.editedAt != null ? Timestamp.fromDate(message.editedAt!) : null,
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
      'deliveredAt': message.deliveredAt != null ? Timestamp.fromDate(message.deliveredAt!) : null,
      'readAt': message.readAt != null ? Timestamp.fromDate(message.readAt!) : null,
      'metadata': message.metadata,
      'replyToMessageId': message.replyToMessageId,
      'isEdited': message.isEdited,
      'editedAt': message.editedAt != null ? Timestamp.fromDate(message.editedAt!) : null,
    };
  }
}