/// Centralized fallback value registration for Mocktail
///
/// This file contains all registerFallbackValue() calls needed for Mocktail's
/// any() matcher to work with custom types. All fallback values are registered
/// in a single place to avoid duplication and ensure consistency.
library;

// ignore_for_file: subtype_of_sealed_class, override_on_non_overriding_member

import 'dart:io';
import 'dart:typed_data';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as firebase_mocks;

// Model imports
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/notification_preferences.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/shared_content.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/social/activity_feed_item.dart';
import 'package:butlery/models/social/reaction_type.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';

// Service type imports
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/models/recommendation.dart';
import 'package:butlery/services/realtime/realtime_types.dart';

// Repository type imports
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/repositories/interfaces/connectivity_repository.dart';

// Test factories
import '../factories/recipe_factory.dart';
import '../factories/user_profile_factory.dart';
import '../factories/shopping_list_factory.dart';

// Test mocks
import 'production_mocks.dart';

// ============= FAKE CLASSES FOR FALLBACK VALUES =============

/// Fake DocumentReference for Firestore testing
class FakeDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  @override
  String get id => 'fake-doc-id';

  @override
  CollectionReference<Map<String, dynamic>> get parent =>
      throw UnimplementedError();

  @override
  String get path => 'fake/path';

  @override
  FirebaseFirestore get firestore => throw UnimplementedError();
}

/// Fake FieldPath for Firestore queries
class FakeFieldPath extends Fake implements FieldPath {
  @override
  List<String> get components => ['fake'];
}

/// Fake FieldValue for Firestore operations
class FakeFieldValue extends Fake implements FieldValue {}

/// Fake GetOptions for Firestore reads
class FakeGetOptions extends Fake implements GetOptions {
  @override
  Source get source => Source.cache;
}

/// Fake SetOptions for Firestore writes
class FakeSetOptions extends Fake implements SetOptions {
  @override
  bool? get merge => false;

  @override
  List<FieldPath>? get mergeFields => null;
}

/// Fake Timestamp for Firestore timestamps
class FakeTimestamp extends Fake implements Timestamp {
  @override
  DateTime toDate() => DateTime.now();

  @override
  int get seconds => 0;

  @override
  int get nanoseconds => 0;
}

/// Fake File for file operations
class FakeFile extends Fake implements File {
  @override
  String get path => '/fake/path';
}

/// Fake FriendRequest for social features
class FakeFriendRequest extends Fake implements FriendRequest {
  @override
  String get id => 'fake-request';

  @override
  String get fromUserId => 'fake-from';

  @override
  String get toUserId => 'fake-to';

  @override
  DateTime get sentAt => DateTime.now();

  @override
  FriendRequestStatus get status => FriendRequestStatus.pending;

  @override
  String? get message => null;

  @override
  DateTime? get respondedAt => null;
}

/// Fake FriendCategory for social organization
class FakeFriendCategory extends Fake implements FriendCategory {
  @override
  String get id => 'fake-category';

  @override
  String get name => 'Fake Category';

  @override
  String? get description => null;

  @override
  String? get emoji => null;

  @override
  List<String> get memberIds => [];

  @override
  int get friendCount => 0;

  @override
  DateTime get createdAt => DateTime.now();

  @override
  DateTime get updatedAt => DateTime.now();
}

/// Fake SharedContent for sharing features
class FakeSharedContent extends Fake implements SharedContent {
  @override
  String get id => 'fake-shared';

  @override
  String get recipeId => 'fake-recipe';

  @override
  String get sharedById => 'fake-user';

  @override
  List<String> get sharedWithIds => [];

  @override
  DateTime get sharedAt => DateTime.now();

  @override
  String? get message => null;

  @override
  bool get isPublic => false;

  @override
  Map<String, dynamic> get metadata => {};
}

/// Fake SharedRecipe for social sharing
class FakeSharedRecipe extends Fake implements SharedRecipe {}

/// Fake SharedMenu for menu sharing
class FakeSharedMenu extends Fake implements SharedMenu {}

/// Fake Conversation for messaging
class FakeConversation extends Fake implements Conversation {
  @override
  String get id => 'fake-conversation';

  @override
  List<String> get participantIds => [];

  @override
  DateTime get createdAt => DateTime.now();

  @override
  DateTime get updatedAt => DateTime.now();

  @override
  bool get isGroup => false;

  @override
  String? get title => null;

  @override
  Message? get lastMessage => null;

  @override
  Map<String, DateTime> get lastReadTimestamps => {};

  @override
  Map<String, String> get participantDisplayNames => {};

  @override
  Map<String, String?> get participantAvatarUrls => {};

  @override
  Map<String, dynamic>? get metadata => null;
}

/// Fake Message for messaging
class FakeMessage extends Fake implements Message {
  @override
  String get id => 'fake-message';

  @override
  String get conversationId => 'fake-conversation';

  @override
  String get senderId => 'fake-sender';

  @override
  MessageType get type => MessageType.text;

  @override
  String get content => 'Fake message';

  @override
  DateTime get sentAt => DateTime.now();

  @override
  MessageStatus get status => MessageStatus.sent;

  @override
  Map<String, DateTime>? get readBy => null;

  @override
  Map<String, dynamic>? get metadata => null;

  @override
  bool get isEdited => false;

  @override
  DateTime? get editedAt => null;
}

/// Fake Recipe for recipe operations
class FakeRecipe extends Fake implements Recipe {
  @override
  String get id => 'fake-recipe';

  @override
  String get title => 'Fake Recipe';

  @override
  String get description => 'Fake description';

  @override
  String get createdBy => 'fake-user';

  @override
  DateTime get createdAt => DateTime.now();

  @override
  DateTime get updatedAt => DateTime.now();
}

/// Register all fallback values for Mocktail
///
/// This function should be called once in setUpAll() in tests that use Mocktail.
/// It registers all custom types that might be used with any() matcher.
void registerAllFallbackValues() {
  // ===== Firestore Types =====
  registerFallbackValue(FakeDocumentReference());
  registerFallbackValue(FakeFieldPath());
  registerFallbackValue(FieldPath.documentId);
  registerFallbackValue(FakeFieldValue());
  registerFallbackValue(FieldValue.serverTimestamp());
  registerFallbackValue(FieldValue.increment(1));
  registerFallbackValue(FieldValue.increment(-1));
  registerFallbackValue(FakeGetOptions());
  registerFallbackValue(const GetOptions(source: Source.server));
  registerFallbackValue(FakeSetOptions());
  registerFallbackValue(SetOptions(merge: true));
  registerFallbackValue(FakeTimestamp());
  registerFallbackValue(FakeFieldPath());
  registerFallbackValue(FieldPath.documentId);

  // ===== Firebase Auth Types =====
  registerFallbackValue(firebase_mocks.MockUser());

  // ===== File System Types =====
  registerFallbackValue(FakeFile());
  registerFallbackValue(File(''));
  registerFallbackValue(FakeXFile(name: 'test.jpg', path: '/test/path'));
  registerFallbackValue(Uint8List(0));

  // ===== Model Types - Using Factories =====
  registerFallbackValue(RecipeFactory.build());
  registerFallbackValue(UserProfileFactory.build());
  registerFallbackValue(ShoppingListFactory.build());
  registerFallbackValue(ShoppingListFactory.buildItem());

  // ===== Model Types - Using Fakes =====
  registerFallbackValue(FakeFriendRequest());
  registerFallbackValue(FakeFriendCategory());
  registerFallbackValue(FakeSharedContent());
  registerFallbackValue(FakeSharedRecipe());
  registerFallbackValue(FakeSharedMenu());
  registerFallbackValue(FakeConversation());
  registerFallbackValue(FakeMessage());
  registerFallbackValue(FakeRecipe());

  // ===== Conversation Types =====
  registerFallbackValue(Conversation.direct(
    user1Id: 'user1',
    user1DisplayName: 'User 1',
    user2Id: 'user2',
    user2DisplayName: 'User 2',
  ));

  // ===== Message Types =====
  registerFallbackValue(Message.text(
    conversationId: 'fake-conversation',
    senderId: 'fake-sender',
    senderDisplayName: 'Fake Sender',
    content: 'Fake message',
  ));

  // ===== Activity Types =====
  registerFallbackValue(ActivityFeedItem.create(
    userId: 'fake-user',
    userDisplayName: 'Fake User',
    type: ActivityType.recipeCreated,
    targetId: 'fake-target',
    targetType: 'recipe',
    targetTitle: 'Fake Recipe',
  ));

  // ===== Operation Results =====
  registerFallbackValue(RecipeOperationResult.success('test'));

  // ===== Notification Types =====
  registerFallbackValue(NotificationPreferences.defaults());

  // ===== Enum Values =====
  registerFallbackValue(FriendRequestStatus.pending);
  registerFallbackValue(GroupInvitationStatus.pending);
  registerFallbackValue(ActivityType.recipeCreated);
  registerFallbackValue(MessageStatus.sent);
  registerFallbackValue(MessageType.text);
  registerFallbackValue(NotificationCategory.social);
  registerFallbackValue(NotificationType.immediate);
  registerFallbackValue(ReactionType.like);
  registerFallbackValue(ImportSourceType.text);
  registerFallbackValue(RecipeType.personal);
  registerFallbackValue(FeedbackType.like);
  registerFallbackValue(RecommendationType.similarToShared);
  registerFallbackValue(SyncErrorType.unknown);
  registerFallbackValue(ConnectionQuality.good);
  registerFallbackValue(RealtimeResourceType.recipe);

  // ===== Collections =====
  registerFallbackValue(<String, dynamic>{});
  registerFallbackValue(<String, Object>{});
  registerFallbackValue(<Recipe>[]);

  // ===== Date/Time Types =====
  registerFallbackValue(DateTime.now());
  registerFallbackValue(const Duration(seconds: 1));
}
