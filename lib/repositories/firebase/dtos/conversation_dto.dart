// lib/repositories/firebase/dtos/conversation_dto.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/repositories/firebase/dtos/message_dto.dart';

/// Data Transfer Object for Firebase conversion of Conversation models
class ConversationDto {
  /// Convert Firestore document to Conversation model
  static Conversation fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    
    return Conversation(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantDisplayNames: Map<String, String>.from(data['participantDisplayNames'] ?? {}),
      participantAvatarUrls: Map<String, String?>.from(data['participantAvatarUrls'] ?? {}),
      lastMessage: data['lastMessage'] != null 
          ? MessageDto.fromMap(data['lastMessage'] as Map<String, dynamic>)
          : null,
      lastReadTimestamps: (data['lastReadTimestamps'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, (value as Timestamp).toDate()),
      ) ?? {},
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      title: data['title'] as String?,
      isGroup: data['isGroup'] as bool? ?? false,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert Conversation model to Firestore document
  static Map<String, dynamic> toFirestore(Conversation conversation) {
    return {
      'participantIds': conversation.participantIds,
      'participantDisplayNames': conversation.participantDisplayNames,
      'participantAvatarUrls': conversation.participantAvatarUrls,
      'lastMessage': conversation.lastMessage != null 
          ? MessageDto.toMap(conversation.lastMessage!) 
          : null,
      'lastReadTimestamps': conversation.lastReadTimestamps.map(
        (key, value) => MapEntry(key, Timestamp.fromDate(value)),
      ),
      'createdAt': Timestamp.fromDate(conversation.createdAt),
      'updatedAt': Timestamp.fromDate(conversation.updatedAt),
      'title': conversation.title,
      'isGroup': conversation.isGroup,
      'metadata': conversation.metadata,
    };
  }
}