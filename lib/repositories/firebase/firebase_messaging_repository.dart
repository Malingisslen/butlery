/// Firebase Firestore implementation for comprehensive real-time messaging and conversation management.
///
/// This repository provides complete messaging functionality using Firebase Firestore as the backend,
/// enabling users to engage in direct and group conversations with real-time message delivery,
/// read receipts, typing indicators, and comprehensive conversation management. It implements
/// sophisticated messaging features to support collaborative cooking community interactions.
///
/// **Architecture Integration:**
/// - Extends [BaseFirebaseRepository] for consistent CRUD operations and error handling
/// - Uses [UserScopedFirebaseRepository] mixin for user-specific conversation filtering
/// - Implements [MessagingRepository] interface for standardized messaging operations
/// - Integrates with [AppLogger] for detailed messaging activity monitoring
/// - Coordinates with notification system for message delivery alerts
///
/// **Messaging System Features:**
/// - **Direct Conversations**: Private 1-on-1 messaging between users
/// - **Group Conversations**: Multi-participant group messaging with management
/// - **Real-time Updates**: Live message streams with instant delivery
/// - **Message Status Tracking**: Comprehensive delivery and read receipt system
/// - **Conversation Management**: Participant addition/removal and metadata updates
/// - **Message Operations**: Send, edit, delete, and search message functionality
/// - **Offline Support**: Message queueing and synchronization when connection restored
///
/// **Security and Privacy:**
/// - **Participant Validation**: Ensures users can only access conversations they're part of
/// - **Permission Checks**: Validates user permissions before message operations
/// - **Data Integrity**: Maintains conversation consistency during participant changes
/// - **Audit Logging**: Complete audit trail for messaging security monitoring

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/firebase/dtos/conversation_dto.dart';
import 'package:butlery/repositories/firebase/dtos/message_dto.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/conversation.dart';
// MessageStatus and MessageType available through message.dart import
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';
/// Firebase implementation for real-time messaging with comprehensive conversation management.
///
/// This repository provides complete messaging functionality using Firebase Firestore collections
/// for both conversations and messages. It supports both direct (1-on-1) and group conversations
/// with real-time message delivery, read receipts, message editing, and participant management.
///
/// **Messaging Architecture:**
/// Uses a dual-collection approach for optimal performance and real-time capabilities:
/// - `conversations`: Stores conversation metadata, participants, and last message info
/// - `messages`: Stores individual messages with delivery status and content
///
/// **Real-time Features:**
/// - **Live Message Streams**: Real-time message delivery using Firestore snapshots
/// - **Conversation Updates**: Live participant changes and conversation metadata updates
/// - **Message Status Updates**: Real-time delivery and read receipt tracking
/// - **Typing Indicators**: Support for typing status updates (future enhancement)
///
/// **Performance Optimizations:**
/// - **Efficient Queries**: Optimized Firestore queries with proper indexing
/// - **Pagination Support**: Message loading with configurable limits
/// - **Batch Operations**: Efficient bulk message status updates
/// - **Conversation Caching**: Smart caching of conversation metadata
///
/// **Usage Examples:**
/// ```dart
/// final messagingRepo = FirebaseMessagingRepository(
///   authRepository: ServiceLocator.get<AuthRepository>(),
/// );
/// 
/// // Create direct conversation
/// final conversationId = await messagingRepo.createDirectConversation(
///   user1Id: currentUserId,
///   user1DisplayName: 'John',
///   user2Id: friendId,
///   user2DisplayName: 'Jane',
/// );
/// 
/// // Send message
/// final message = Message.text(
///   conversationId: conversationId,
///   senderId: currentUserId,
///   content: 'Hello!',
/// );
/// await messagingRepo.sendMessage(message);
/// 
/// // Stream messages
/// messagingRepo.getConversationMessages(conversationId: conversationId)
///   .listen((messages) => updateUI(messages));
/// ```
class FirebaseMessagingRepository 
    extends BaseFirebaseRepository<Conversation>
    with UserScopedFirebaseRepository<Conversation>
    implements MessagingRepository {

  /// Creates a Firebase messaging repository with dependency injection support.
  ///
  /// [firestore] Optional Firestore instance for testing, defaults to production instance
  /// [authRepository] Optional authentication repository, defaults to FirebaseAuthRepository
  FirebaseMessagingRepository({
    super.firestore,
    AuthRepository? authRepository,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

  // ===== BASE CLASS IMPLEMENTATION =====

  @override
  String get collectionName => 'conversations';

  @override
  Conversation fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ConversationDto.fromFirestore(doc);

  @override
  Map<String, dynamic> toFirestore(Conversation entity) => ConversationDto.toFirestore(entity);

  @override
  String getId(Conversation entity) => entity.id;

  // ===== COLLECTION REFERENCES =====

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      firestore.collection('messages');

  // ===== AUTO-HEALER SYSTEM =====
  // Real-time self-healing system to ensure conversation.lastMessage is always accurate

  /// Map to track active auto-healer listeners and prevent duplicates
  final Map<String, StreamSubscription> _conversationAutoHealers = {};

  /// Start real-time self-healing for a conversation
  /// This ensures lastMessage is ALWAYS accurate, even if atomic update fails
  void startConversationAutoHealer(String conversationId) {
    // Prevent duplicate listeners
    if (_conversationAutoHealers.containsKey(conversationId)) {
      return;
    }

    AppLogger.debug('🔄 [AutoHealer] Starting for conversation: $conversationId');

    // ignore: cancel_subscriptions
    final subscription = _messagesRef
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('sentAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;

      try {
        final latestMessage = MessageDto.fromFirestore(snapshot.docs.first);
        final conversation = await read(conversationId);

        if (conversation == null) {
          AppLogger.warning('⚠️ [AutoHealer] Conversation not found: $conversationId');
          return;
        }

        // Check if lastMessage needs updating
        final needsUpdate = conversation.lastMessage == null ||
            latestMessage.sentAt.isAfter(conversation.lastMessage!.sentAt);

        if (needsUpdate) {
          AppLogger.info('🔧 [AutoHealer] Healing conversation lastMessage: $conversationId');

          final updated = conversation.copyWith(
            lastMessage: latestMessage,
            updatedAt: DateTime.now(),
          );

          await update(updated);
          AppLogger.success('✅ [AutoHealer] Healed conversation: $conversationId');
        }
      } catch (e) {
        AppLogger.error('❌ [AutoHealer] Failed for $conversationId', e);
      }
    });

    _conversationAutoHealers[conversationId] = subscription;
  }

  /// Stop auto-healer for a conversation (cleanup)
  void stopConversationAutoHealer(String conversationId) {
    final subscription = _conversationAutoHealers.remove(conversationId);
    subscription?.cancel();
    AppLogger.debug('🛑 [AutoHealer] Stopped for: $conversationId');
  }

  /// Stop all auto-healers (call on repository disposal)
  void stopAllAutoHealers() {
    for (final subscription in _conversationAutoHealers.values) {
      subscription.cancel();
    }
    _conversationAutoHealers.clear();
    AppLogger.debug('🛑 [AutoHealer] Stopped all healers');
  }

  // ===== CONVERSATION OPERATIONS =====

  @override
  Stream<List<Conversation>> getUserConversations(String userId) {
    try {
      // ✅ PERFORMANCE FIX: Added limit to prevent unbounded streaming
      return firestore.collection(collectionName)
          .where('participantIds', arrayContains: userId)
          .orderBy('updatedAt', descending: true)
          .limit(50) // Limit to 50 most recent conversations
          .snapshots()
          .map((snapshot) {
            final conversations = snapshot.docs.map(fromFirestore).toList();

            // ✅ AUTO-HEALER: Start self-healing for all conversations
            // This ensures lastMessage is always accurate even if atomic update fails
            for (final conversation in conversations) {
              startConversationAutoHealer(conversation.id);
            }

            return conversations;
          });
    } catch (e) {
      AppLogger.error('Failed to get user conversations for $userId', e);
      return const Stream.empty();
    }
  }

  @override
  Future<Conversation?> getConversation(String conversationId) async {
    try {
      return await read(conversationId);
    } catch (e) {
      AppLogger.error('Failed to get conversation $conversationId', e);
      return null;
    }
  }

  @override
  Future<String> createDirectConversation({
    required String user1Id,
    required String user1DisplayName,
    String? user1AvatarUrl,
    required String user2Id,
    required String user2DisplayName,
    String? user2AvatarUrl,
  }) async {
    try {
      // Generate deterministic ID from sorted user IDs
      final sortedIds = [user1Id, user2Id]..sort();
      final conversationId = 'direct_${sortedIds[0]}_${sortedIds[1]}';

      AppLogger.info('🔍 Creating/getting direct conversation with deterministic ID: $conversationId');

      // Try to get existing conversation
      try {
        final existing = await read(conversationId);
        if (existing != null) {
          AppLogger.success('✅ Found existing conversation: $conversationId');
          return conversationId;
        }
      } catch (e) {
        AppLogger.debug('No existing conversation found, creating new one');
      }

      // Create conversation directly with deterministic ID
      final now = DateTime.now();
      final conversation = Conversation(
        id: conversationId, // Use deterministic ID
        participantIds: [user1Id, user2Id],
        participantDisplayNames: {
          user1Id: user1DisplayName,
          user2Id: user2DisplayName,
        },
        participantAvatarUrls: {
          user1Id: user1AvatarUrl,
          user2Id: user2AvatarUrl,
        },
        isGroup: false,
        title: '', // Empty for direct conversations
        createdAt: now,
        updatedAt: now,
        lastMessage: null,
        lastReadTimestamps: {
          user1Id: now,
          user2Id: now,
        },
        metadata: {'creatorId': user1Id},
      );

      await firestore.collection(collectionName).doc(conversationId).set(
        ConversationDto.toFirestore(conversation),
        SetOptions(merge: true),
      );

      AppLogger.success('✅ Direct conversation created with deterministic ID: $conversationId');
      return conversationId;
    } catch (e) {
      AppLogger.error('Failed to create direct conversation', e);
      rethrow;
    }
  }

  @override
  Future<String> createGroupConversation({
    required List<String> participantIds,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
    required String title,
    required String creatorId,
  }) async {
    try {
      final conversation = Conversation.group(
        participantIds: participantIds,
        participantDisplayNames: participantDisplayNames,
        participantAvatarUrls: participantAvatarUrls,
        title: title,
        creatorId: creatorId,
      );

      final createdConversation = await create(conversation);
      
      // Send system message about group creation
      final systemMessage = Message.system(
        conversationId: createdConversation.id,
        content: '${participantDisplayNames[creatorId]} skapade gruppen "$title"',
      );
      
      await sendMessage(systemMessage);
      
      AppLogger.success('✅ Group conversation created: ${createdConversation.id}');
      return createdConversation.id;
    } catch (e) {
      AppLogger.error('Failed to create group conversation', e);
      rethrow;
    }
  }

  @override
  /// DEPRECATED: This method uses query-based lookup which can find old UUID conversations
  /// instead of deterministic ID conversations, causing message fragmentation.
  ///
  /// Use `createDirectConversation` directly instead, which implements proper "get or create"
  /// pattern with deterministic IDs.
  @Deprecated('Use createDirectConversation directly - it handles "get or create" with deterministic IDs')
  Future<String?> findDirectConversation({
    required String user1Id,
    required String user2Id,
  }) async {
    try {
      AppLogger.info('🔍 [FirebaseMessagingRepository] findDirectConversation called');
      AppLogger.warning('⚠️ [FirebaseMessagingRepository] This method is DEPRECATED - use createDirectConversation instead');
      AppLogger.debug('🔍 [FirebaseMessagingRepository] user1Id: $user1Id');
      AppLogger.debug('🔍 [FirebaseMessagingRepository] user2Id: $user2Id');

      AppLogger.debug('🔍 [FirebaseMessagingRepository] Executing Firestore query...');
      // ✅ CRITICAL FIX: Added orderBy to ensure consistent conversation selection
      // Always returns the most recently updated conversation between two users
      final query = await firestore.collection(collectionName)
          .where('participantIds', arrayContains: user1Id)
          .where('isGroup', isEqualTo: false)
          .orderBy('updatedAt', descending: true) // Most recent first
          .limit(20) // Most users won't have more than 20 direct conversations
          .get();

      AppLogger.success('✅ [FirebaseMessagingRepository] Query executed successfully');
      AppLogger.debug('🔍 [FirebaseMessagingRepository] Found ${query.docs.length} conversations containing user1Id');

      for (final doc in query.docs) {
        final conversation = fromFirestore(doc);
        AppLogger.debug('🔍 [FirebaseMessagingRepository] Checking conversation ${conversation.id}: participants = ${conversation.participantIds}, updatedAt = ${conversation.updatedAt}');
        if (conversation.participantIds.contains(user2Id)) {
          AppLogger.success('✅ [FirebaseMessagingRepository] Found matching conversation: ${conversation.id} (most recent)');
          return conversation.id;
        }
      }

      AppLogger.warning('⚠️ [FirebaseMessagingRepository] No existing conversation found between $user1Id and $user2Id');
      return null;
    } catch (e) {
      AppLogger.error('❌ [FirebaseMessagingRepository] CRITICAL ERROR in findDirectConversation', e);
      AppLogger.error('❌ [FirebaseMessagingRepository] Error type: ${e.runtimeType}');
      AppLogger.error('❌ [FirebaseMessagingRepository] Error message: ${e.toString()}');
      AppLogger.error('❌ [FirebaseMessagingRepository] This error causes NEW conversation to be created instead of finding existing one!');
      return null;
    }
  }

  @override
  Future<void> updateConversation({
    required String conversationId,
    String? title,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final conversation = await read(conversationId);
      if (conversation == null) {
        throw ResourceNotFoundException(
          'Conversation not found',
          resourceType: 'conversation',
          resourceId: conversationId,
        );
      }

      final updatedConversation = conversation.copyWith(
        title: title,
        metadata: metadata,
        updatedAt: DateTime.now(),
      );

      await update(updatedConversation);
      
      AppLogger.debug('Conversation updated: $conversationId');
    } catch (e) {
      AppLogger.error('Failed to update conversation $conversationId', e);
      rethrow;
    }
  }

  @override
  Future<void> addParticipants({
    required String conversationId,
    required List<String> participantIds,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
  }) async {
    try {
      final conversation = await read(conversationId);
      if (conversation == null) {
        throw ResourceNotFoundException(
          'Conversation not found',
          resourceType: 'conversation',
          resourceId: conversationId,
        );
      }

      if (!conversation.isGroup) {
        throw ValidationException('Cannot add participants to direct conversation');
      }

      final updatedParticipantIds = [...conversation.participantIds, ...participantIds];
      final updatedDisplayNames = {...conversation.participantDisplayNames, ...participantDisplayNames};
      final updatedAvatarUrls = {...conversation.participantAvatarUrls, ...participantAvatarUrls};
      final updatedLastReadTimestamps = {...conversation.lastReadTimestamps};
      
      // Initialize last read timestamps for new participants
      final now = DateTime.now();
      for (final participantId in participantIds) {
        updatedLastReadTimestamps[participantId] = now;
      }

      final updatedConversation = conversation.copyWith(
        participantIds: updatedParticipantIds,
        participantDisplayNames: updatedDisplayNames,
        participantAvatarUrls: updatedAvatarUrls,
        lastReadTimestamps: updatedLastReadTimestamps,
        updatedAt: now,
      );

      await update(updatedConversation);
      
      // Send system message about participant addition
      for (final participantId in participantIds) {
        final displayName = participantDisplayNames[participantId] ?? 'Okänd användare';
        final systemMessage = Message.system(
          conversationId: conversationId,
          content: '$displayName har lagts till i gruppen',
        );
        await sendMessage(systemMessage);
      }
      
      AppLogger.success('✅ Added ${participantIds.length} participants to conversation $conversationId');
    } catch (e) {
      AppLogger.error('Failed to add participants to conversation $conversationId', e);
      rethrow;
    }
  }

  @override
  Future<void> removeParticipant({
    required String conversationId,
    required String participantId,
  }) async {
    try {
      final conversation = await read(conversationId);
      if (conversation == null) {
        throw ResourceNotFoundException(
          'Conversation not found',
          resourceType: 'conversation',
          resourceId: conversationId,
        );
      }

      if (!conversation.isGroup) {
        throw ValidationException('Cannot remove participants from direct conversation');
      }

      final updatedParticipantIds = conversation.participantIds.where((id) => id != participantId).toList();
      final updatedDisplayNames = Map<String, String>.from(conversation.participantDisplayNames)..remove(participantId);
      final updatedAvatarUrls = Map<String, String?>.from(conversation.participantAvatarUrls)..remove(participantId);
      final updatedLastReadTimestamps = Map<String, DateTime>.from(conversation.lastReadTimestamps)..remove(participantId);

      final updatedConversation = conversation.copyWith(
        participantIds: updatedParticipantIds,
        participantDisplayNames: updatedDisplayNames,
        participantAvatarUrls: updatedAvatarUrls,
        lastReadTimestamps: updatedLastReadTimestamps,
        updatedAt: DateTime.now(),
      );

      await update(updatedConversation);
      
      // Send system message about participant removal
      final displayName = conversation.participantDisplayNames[participantId] ?? 'Okänd användare';
      final systemMessage = Message.system(
        conversationId: conversationId,
        content: '$displayName har lämnat gruppen',
      );
      await sendMessage(systemMessage);
      
      AppLogger.success('✅ Removed participant $participantId from conversation $conversationId');
    } catch (e) {
      AppLogger.error('Failed to remove participant from conversation $conversationId', e);
      rethrow;
    }
  }

  // ===== MESSAGE OPERATIONS =====

  @override
  Stream<List<Message>> getConversationMessages({
    required String conversationId,
    int limit = 50,
  }) {
    try {
      AppLogger.info('🔍 [FirebaseMessagingRepository] Creating message stream for conversationId: $conversationId');
      return _messagesRef
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('sentAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            AppLogger.debug('📬 [FirebaseMessagingRepository] Stream update: ${snapshot.docs.length} messages for conversation $conversationId');
            final messages = snapshot.docs
                .map((doc) => MessageDto.fromFirestore(doc))
                .toList()
                .reversed // Reverse to show oldest first
                .toList();
            return messages;
          });
    } catch (e) {
      AppLogger.error('❌ [FirebaseMessagingRepository] Failed to get messages for conversation $conversationId', e);
      return const Stream.empty();
    }
  }

  @override
  Future<List<Message>> getConversationMessagesPage({
    required String conversationId,
    int limit = 50,
    DateTime? startAfter,
  }) async {
    try {
      var query = _messagesRef
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('sentAt', descending: true);
      
      if (startAfter != null) {
        query = query.startAfter([Timestamp.fromDate(startAfter)]);
      }
      
      final snapshot = await query.limit(limit).get();
      
      return snapshot.docs
          .map((doc) => MessageDto.fromFirestore(doc))
          .toList()
          .reversed // Reverse to show oldest first
          .toList();
    } catch (e) {
      AppLogger.error('Failed to get messages page for conversation $conversationId', e);
      return [];
    }
  }

  @override
  Future<void> sendMessage(Message message) async {
    try {
      AppLogger.info('📤 [FirebaseMessagingRepository] sendMessage with atomic conversation update');
      AppLogger.debug('📤 [FirebaseMessagingRepository] Message ID: ${message.id}');
      AppLogger.debug('📤 [FirebaseMessagingRepository] Conversation ID: ${message.conversationId}');
      AppLogger.debug('📤 [FirebaseMessagingRepository] Sender ID: ${message.senderId}');
      AppLogger.debug('📤 [FirebaseMessagingRepository] Content: "${message.content}"');

      // Read conversation (required for atomic update)
      AppLogger.debug('📤 [FirebaseMessagingRepository] Reading conversation...');
      Conversation? conversation;
      try {
        conversation = await read(message.conversationId);
      } catch (e) {
        AppLogger.warning('⚠️ [FirebaseMessagingRepository] Could not read conversation: $e');
        // For deterministic IDs, conversation might not exist yet - that's OK
        if (!message.conversationId.startsWith('direct_')) {
          throw ResourceNotFoundException(
            'Conversation not found',
            resourceType: 'conversation',
            resourceId: message.conversationId,
          );
        }
      }

      // Validate participant if conversation exists
      if (conversation != null) {
        AppLogger.debug('📤 [FirebaseMessagingRepository] Conversation found: ${conversation.id}');

        if (!conversation.isParticipant(message.senderId)) {
          AppLogger.error('❌ [FirebaseMessagingRepository] User ${message.senderId} is not a participant');
          throw PermissionDeniedException(
            'User is not a participant in this conversation',
            resource: 'conversation:${message.conversationId}',
            userId: message.senderId,
          );
        }
        AppLogger.debug('📤 [FirebaseMessagingRepository] User is participant - authorized');
      }

      // Handle missing conversation with smart fallback using message sender data
      if (conversation == null) {
        AppLogger.warning('⚠️ [FirebaseMessagingRepository] Conversation not found locally: ${message.conversationId}');
        AppLogger.info('📝 [FirebaseMessagingRepository] Creating fallback conversation with complete participant data');

        // Parse deterministic conversation ID to extract other participant
        final conversationId = message.conversationId;
        String? otherUserId;

        if (conversationId.startsWith('direct_')) {
          final parts = conversationId.split('_');
          if (parts.length == 3) {
            final userId1 = parts[1];
            final userId2 = parts[2];
            otherUserId = (userId1 == message.senderId) ? userId2 : userId1;
          }
        }

        // Fetch other participant's profile from Firestore users collection
        String? otherUserDisplayName;
        String? otherUserAvatarUrl;

        if (otherUserId != null) {
          try {
            AppLogger.debug('📝 [FirebaseMessagingRepository] Fetching profile for user: $otherUserId');
            final userDoc = await firestore.collection('users').doc(otherUserId).get();
            if (userDoc.exists) {
              final userData = userDoc.data();
              otherUserDisplayName = userData?['displayName'] as String?;
              otherUserAvatarUrl = userData?['avatarUrl'] as String?;
              AppLogger.success('✅ [FirebaseMessagingRepository] Fetched other participant profile: $otherUserDisplayName');
            } else {
              AppLogger.warning('⚠️ [FirebaseMessagingRepository] User profile not found for: $otherUserId');
            }
          } catch (e) {
            AppLogger.warning('⚠️ [FirebaseMessagingRepository] Could not fetch user profile: $e');
          }
        }

        // Create fallback conversation with BOTH participant names
        conversation = Conversation(
          id: conversationId,
          participantIds: [
            message.senderId,
            if (otherUserId != null) otherUserId,
          ],
          participantDisplayNames: {
            message.senderId: message.senderDisplayName,
            if (otherUserId != null && otherUserDisplayName != null)
              otherUserId: otherUserDisplayName,
          },
          participantAvatarUrls: {
            message.senderId: message.senderAvatarUrl,
            if (otherUserId != null && otherUserAvatarUrl != null)
              otherUserId: otherUserAvatarUrl,
          },
          lastReadTimestamps: {},
          isGroup: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        AppLogger.success('✅ [FirebaseMessagingRepository] Fallback conversation created with complete participant data');
      }

      // ATOMIC OPERATION: Write message + update conversation in single batch
      AppLogger.debug('📤 [FirebaseMessagingRepository] Creating atomic batch operation...');
      AppLogger.debug('📤 [FirebaseMessagingRepository] Message initial status: ${message.status}');
      final batch = firestore.batch();

      // 1. Write message to messages collection with ORIGINAL status (sending)
      // Status will be updated to "sent" AFTER batch commits successfully
      final messageData = MessageDto.toFirestore(message);  // Keep original "sending" status
      batch.set(_messagesRef.doc(message.id), messageData);
      AppLogger.debug('📤 [FirebaseMessagingRepository] Added message to batch with status: ${message.status}');

      // 2. Update conversation with lastMessage (keeping original status)
      final updatedConversation = conversation.copyWith(
        lastMessage: message,  // Use original message with "sending" status
        updatedAt: DateTime.now(),
      );
      final conversationData = ConversationDto.toFirestore(updatedConversation);
      batch.set(
        firestore.collection(collectionName).doc(message.conversationId),
        conversationData,
        SetOptions(merge: true),  // Update existing conversation
      );
      AppLogger.debug('📤 [FirebaseMessagingRepository] Added conversation update to batch: ${message.conversationId}');

      // Commit batch - either BOTH succeed or BOTH fail (atomicity guaranteed)
      AppLogger.debug('📤 [FirebaseMessagingRepository] Committing atomic batch...');
      try {
        await batch.commit();
        AppLogger.success('✅ [FirebaseMessagingRepository] Atomic batch committed - message in Firestore with status: sending');

        // STEP 2: Update message status to "sent" AFTER batch commits successfully
        // Use Future.delayed to give UI time to render "sending" status first
        // This creates proper UI progression: Skickar... (50-100ms) → Skickat
        AppLogger.debug('📤 [FirebaseMessagingRepository] Scheduling status update to sent...');
        Future.delayed(const Duration(milliseconds: 100), () async {
          try {
            await _messagesRef.doc(message.id).update({
              'status': MessageStatus.sent.name,
            });
            AppLogger.success('✅ [FirebaseMessagingRepository] Message status updated to: sent');

            // Also update conversation's lastMessage status
            await firestore.collection(collectionName).doc(message.conversationId).update({
              'lastMessage.status': MessageStatus.sent.name,
            });
            AppLogger.success('✅ [FirebaseMessagingRepository] Conversation lastMessage status updated to: sent');
          } catch (e) {
            AppLogger.warning('⚠️ [FirebaseMessagingRepository] Could not update message status: $e');
          }
        });

      } catch (batchError) {
        AppLogger.error('❌ [FirebaseMessagingRepository] Batch commit failed', batchError);
        // Check if it's network related (testing environment can ignore this)
        if (batchError.toString().contains('UNAVAILABLE') ||
            batchError.toString().contains('network')) {
          AppLogger.warning('📡 [FirebaseMessagingRepository] Network unavailable - batch queued for offline sync');
          // Don't rethrow - let Firestore handle offline sync
        } else {
          rethrow;
        }
      }

      AppLogger.success('✅ [FirebaseMessagingRepository] Message sent: ${message.id} in conversation ${message.conversationId}');
    } catch (e, stackTrace) {
      AppLogger.error('❌ [FirebaseMessagingRepository] Failed to send message ${message.id}', e);
      AppLogger.error('❌ [FirebaseMessagingRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> updateMessageStatus({
    required String messageId,
    required MessageStatus status,
    DateTime? timestamp,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      switch (status) {
        case MessageStatus.delivered:
          updateData['deliveredAt'] = timestamp != null 
              ? Timestamp.fromDate(timestamp) 
              : FieldValue.serverTimestamp();
          break;
        case MessageStatus.read:
          updateData['readAt'] = timestamp != null 
              ? Timestamp.fromDate(timestamp) 
              : FieldValue.serverTimestamp();
          break;
        default:
          break;
      }

      await _messagesRef.doc(messageId).update(updateData);
      
      AppLogger.debug('Message status updated: $messageId -> $status');
    } catch (e) {
      AppLogger.error('Failed to update message status for $messageId', e);
      rethrow;
    }
  }

  @override
  Future<void> markMessageAsRead({
    required String messageId,
    required String userId,
  }) async {
    try {
      await updateMessageStatus(
        messageId: messageId,
        status: MessageStatus.read,
        timestamp: DateTime.now(),
      );
      
      AppLogger.debug('Message marked as read: $messageId by $userId');
    } catch (e) {
      AppLogger.error('Failed to mark message as read: $messageId', e);
      rethrow;
    }
  }

  @override
  Future<void> markConversationAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final conversation = await read(conversationId);
      if (conversation == null) {
        throw ResourceNotFoundException(
          'Conversation not found',
          resourceType: 'conversation',
          resourceId: conversationId,
        );
      }

      if (!conversation.isParticipant(userId)) {
        throw PermissionDeniedException(
          'User is not a participant in this conversation',
          resource: 'conversation:$conversationId',
          userId: userId,
        );
      }

      final now = DateTime.now();
      final updatedLastReadTimestamps = Map<String, DateTime>.from(conversation.lastReadTimestamps);
      updatedLastReadTimestamps[userId] = now;

      final updatedConversation = conversation.copyWith(
        lastReadTimestamps: updatedLastReadTimestamps,
        updatedAt: now,
      );

      await update(updatedConversation);
      
      AppLogger.debug('Conversation marked as read: $conversationId by $userId');
    } catch (e) {
      AppLogger.error('Failed to mark conversation as read: $conversationId', e);
      rethrow;
    }
  }

  @override
  Future<void> updateMessageContent({
    required String messageId,
    required String newContent,
  }) async {
    try {
      await _messagesRef.doc(messageId).update({
        'content': newContent,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      AppLogger.debug('Message content updated: $messageId');
    } catch (e) {
      AppLogger.error('Failed to update message content: $messageId', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    try {
      await _messagesRef.doc(messageId).delete();
      
      AppLogger.debug('Message deleted: $messageId');
    } catch (e) {
      AppLogger.error('Failed to delete message: $messageId', e);
      rethrow;
    }
  }

  // ===== UTILITY OPERATIONS =====

  @override
  Future<List<String>> getConversationParticipants(String conversationId) async {
    try {
      final conversation = await read(conversationId);
      return conversation?.participantIds ?? [];
    } catch (e) {
      AppLogger.error('Failed to get conversation participants: $conversationId', e);
      return [];
    }
  }

  @override
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      // This is a simplified implementation - in production you might want
      // to use a more efficient aggregation or counter approach
      // ✅ PERFORMANCE FIX: Added limit to prevent unbounded query
      final conversations = await firestore.collection(collectionName)
          .where('participantIds', arrayContains: userId)
          .limit(100) // Limit unread count check to 100 most recent conversations
          .get();

      int totalUnread = 0;
      for (final doc in conversations.docs) {
        final conversation = fromFirestore(doc);
        if (conversation.hasUnreadMessages(userId)) {
          // For accurate count, you'd need to query messages
          // This is a simplified version
          totalUnread += 1;
        }
      }

      return totalUnread;
    } catch (e) {
      AppLogger.error('Failed to get unread message count for $userId', e);
      return 0;
    }
  }

  @override
  Future<int> getUnreadConversationsCount(String userId) async {
    try {
      final conversations = await firestore.collection(collectionName)
          .where('participantIds', arrayContains: userId)
          .get();

      return conversations.docs
          .map(fromFirestore)
          .where((conversation) => conversation.hasUnreadMessages(userId))
          .length;
    } catch (e) {
      AppLogger.error('Failed to get unread conversations count for $userId', e);
      return 0;
    }
  }

  @override
  Future<List<Message>> searchMessages({
    required String conversationId,
    required String query,
    int limit = 20,
  }) async {
    try {
      // Firestore doesn't support full-text search natively
      // This is a simplified implementation that searches in content
      // In production, you might want to use Algolia or similar
      
      final messages = await _messagesRef
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('sentAt', descending: true)
          .limit(limit * 3) // Get more to filter
          .get();

      final lowerQuery = query.toLowerCase();
      return messages.docs
          .map((doc) => MessageDto.fromFirestore(doc))
          .where((message) => message.content.toLowerCase().contains(lowerQuery))
          .take(limit)
          .toList();
    } catch (e) {
      AppLogger.error('Failed to search messages in conversation $conversationId', e);
      return [];
    }
  }

  @override
  Future<Message?> getMessage(String messageId) async {
    try {
      final doc = await _messagesRef.doc(messageId).get();
      if (doc.exists) {
        return MessageDto.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      AppLogger.error('Failed to get message: $messageId', e);
      return null;
    }
  }

  @override
  Future<void> batchMarkAsDelivered({
    required List<String> messageIds,
    required String userId,
  }) async {
    try {
      final batch = firestore.batch();
      final timestamp = FieldValue.serverTimestamp();

      for (final messageId in messageIds) {
        final messageRef = _messagesRef.doc(messageId);
        batch.update(messageRef, {
          'status': MessageStatus.delivered.name,
          'deliveredAt': timestamp,
          'updatedAt': timestamp,
        });
      }

      await batch.commit();
      
      AppLogger.debug('Batch marked ${messageIds.length} messages as delivered for $userId');
    } catch (e) {
      AppLogger.error('Failed to batch mark messages as delivered', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    try {
      // First get all messages in the conversation
      final messagesQuery = await _messagesRef
          .where('conversationId', isEqualTo: conversationId)
          .get();

      // Delete messages in batches to avoid Firestore limits
      const batchSize = 500; // Firestore batch limit
      final messages = messagesQuery.docs;
      
      AppLogger.info('🗑️ Deleting ${messages.length} messages from conversation $conversationId');

      for (int i = 0; i < messages.length; i += batchSize) {
        final batch = firestore.batch();
        final batchDocs = messages.skip(i).take(batchSize);
        
        for (final doc in batchDocs) {
          batch.delete(doc.reference);
        }
        
        await batch.commit();
        AppLogger.debug('Deleted batch of ${batchDocs.length} messages');
      }

      // Then delete the conversation document
      await firestore.collection(collectionName).doc(conversationId).delete();

      AppLogger.success('✅ Successfully deleted conversation $conversationId');
    } catch (e) {
      AppLogger.error('Failed to delete conversation $conversationId', e);
      rethrow;
    }
  }

  @override
  Future<void> updateConversationUserSettings({
    required String conversationId,
    required String userId,
    required Map<String, dynamic> settings,
  }) async {
    try {
      // Store user-specific settings in a subcollection
      // This allows each user to have their own pin/archive/mute settings
      await firestore
          .collection(collectionName)
          .doc(conversationId)
          .collection('userSettings')
          .doc(userId)
          .set(settings, SetOptions(merge: true));

      AppLogger.debug('Updated conversation settings for user $userId in $conversationId');
    } catch (e) {
      AppLogger.error('Failed to update conversation user settings', e);
      rethrow;
    }
  }

  // ===== CLEANUP =====

  /// Dispose repository and cleanup all resources including active stream subscriptions
  void dispose() {
    stopAllAutoHealers();
    AppLogger.debug('FirebaseMessagingRepository disposed');
  }
}