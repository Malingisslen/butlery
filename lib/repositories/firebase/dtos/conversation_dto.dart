/// Firebase Firestore Data Transfer Object for comprehensive conversation model serialization and deserialization.
/// This DTO provides sophisticated bidirectional conversion between Conversation domain models and
/// Firebase Firestore document format, ensuring data integrity, type safety, and optimal performance
/// for real-time messaging operations. It handles complex nested data structures, timestamp conversions,
/// and nullable field management for robust messaging system integration.
/// **Architecture Integration:**
/// - Provides clean separation between domain models and Firebase storage format
/// - Integrates with [MessageDto] for nested message serialization within conversations
/// - Handles Firebase Timestamp conversions for accurate temporal data management
/// - Ensures type safety with comprehensive null handling and data validation
/// - Optimizes Firestore document structure for efficient queries and real-time updates
/// **Data Conversion Features:**
/// - **Bidirectional Mapping**: Seamless conversion between Conversation models and Firestore documents
/// - **Nested Message Handling**: Integrates with MessageDto for last message serialization
/// - **Timestamp Management**: Precise Firebase Timestamp handling for temporal accuracy
/// - **Participant Data**: Comprehensive participant information including names and avatars
/// - **Read Receipt Tracking**: Sophisticated last read timestamp management for all participants
/// - **Metadata Support**: Flexible metadata handling for extensible conversation features
/// **Type Safety and Validation:**
/// - **Null Safety**: Comprehensive nullable field handling with safe defaults
/// - **Collection Safety**: Safe conversion of dynamic collections with type validation
/// - **Data Integrity**: Maintains data consistency across conversion operations
/// - **Performance Optimization**: Efficient serialization minimizing Firestore read/write costs

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/repositories/firebase/dtos/message_dto.dart';

/// Firebase DTO for conversation data serialization with comprehensive type safety and performance optimization.
/// This static utility class provides sophisticated bidirectional conversion between Conversation
/// domain models and Firebase Firestore document format. It ensures data integrity through
/// comprehensive type checking and null safety while optimizing for Firestore performance.
/// **Conversion Features:**
/// - **Type-Safe Deserialization**: Robust conversion from Firestore documents to Conversation models
/// - **Nested Object Handling**: Seamless integration with MessageDto for complex message data
/// - **Timestamp Precision**: Accurate Firebase Timestamp to DateTime conversion for temporal data
/// - **Participant Management**: Comprehensive handling of participant data including avatars and names
/// - **Performance Optimization**: Efficient serialization patterns minimizing Firestore overhead
/// **Usage Examples:**
/// ```dart
/// // Deserialize from Firestore
/// final conversation = ConversationDto.fromFirestore(docSnapshot);
/// // Serialize for Firestore storage
/// final firestoreData = ConversationDto.toFirestore(conversation);
/// await firestore.collection('conversations').doc(id).set(firestoreData);
/// ```
class ConversationDto {
  /// Converts a Firestore document snapshot to a Conversation domain model.
  /// Performs comprehensive deserialization of conversation data including participant information,
  /// last message details, read receipt timestamps, and metadata. Handles nullable fields safely
  /// and ensures type safety throughout the conversion process.
  /// [doc] The Firestore document snapshot containing conversation data
  /// Returns a fully populated [Conversation] model with all nested data properly converted
  /// **Data Handling:**
  /// - Participant IDs converted to strongly-typed string list
  /// - Display names and avatar URLs safely cast to appropriate map types
  /// - Last message deserialized using MessageDto for consistency
  /// - Timestamps converted from Firestore Timestamp to DateTime objects
  /// - Metadata preserved as flexible key-value pairs for extensibility
  static Conversation fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    String? currentUserId,
  }) {
    final data = doc.data()!;

    // Extract per-user settings from denormalized map
    Map<String, dynamic>? perUserSettings;
    if (currentUserId != null) {
      final allSettings = data['perUserSettings'] as Map<String, dynamic>?;
      perUserSettings = allSettings?[currentUserId] as Map<String, dynamic>?;
    }

    return Conversation(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantDisplayNames:
          Map<String, String>.from(data['participantDisplayNames'] ?? {}),
      participantAvatarUrls:
          Map<String, String?>.from(data['participantAvatarUrls'] ?? {}),
      lastMessage: data['lastMessage'] != null
          ? MessageDto.fromMap(data['lastMessage'] as Map<String, dynamic>)
          : null,
      lastReadTimestamps: (data['lastReadTimestamps'] as Map<String, dynamic>?)
              ?.map(
            (key, value) => MapEntry(key,
                SerializationUtils.parseDateTimeValue(value) ?? clock.now()),
          ) ??
          {},
      createdAt: SerializationUtils.parseDateTimeValue(data['createdAt']) ??
          clock.now(),
      updatedAt: SerializationUtils.parseDateTimeValue(data['updatedAt']) ??
          clock.now(),
      title: data['title'] as String?,
      isGroup: data['isGroup'] as bool? ?? false,
      metadata: data['metadata'] as Map<String, dynamic>?,
      isArchived: perUserSettings?['isArchived'] as bool? ?? false,
      isPinned: perUserSettings?['isPinned'] as bool? ?? false,
      isMuted: perUserSettings?['isMuted'] as bool? ?? false,
      archivedAt:
          SerializationUtils.parseDateTimeValue(perUserSettings?['archivedAt']),
      pinnedAt:
          SerializationUtils.parseDateTimeValue(perUserSettings?['pinnedAt']),
    );
  }

  /// Converts a Conversation domain model to Firestore document format.
  /// Performs comprehensive serialization of conversation data for optimal Firestore storage,
  /// including proper timestamp conversion, nested message serialization, and participant data
  /// formatting. Ensures all data types are Firestore-compatible while maintaining data integrity.
  /// [conversation] The Conversation model to serialize for Firestore storage
  /// Returns a Firestore-compatible map with all data properly formatted for storage
  /// **Serialization Features:**
  /// - DateTime objects converted to Firebase Timestamp for accurate temporal storage
  /// - Last message serialized using MessageDto for consistent nested object handling
  /// - Participant data preserved with proper type safety for names and avatar URLs
  /// - Read timestamps converted to Firestore Timestamp format for efficient querying
  /// - Metadata maintained as flexible document structure for future extensibility
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
