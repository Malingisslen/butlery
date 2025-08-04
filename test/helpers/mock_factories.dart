import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe/recipe_factory.dart' as rf;
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/conversation.dart';
// MessageStatus is exported from message.dart
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/friend.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:faker/faker.dart';

final faker = Faker();

/// Factory for creating mock recipes
class RecipeFactory {
  static int _idCounter = 1;

  static Recipe build({
    String? id,
    String? title,
    String? description,
    String? userId,
    List<String>? ingredients,
    List<String>? instructions,
    int? timeMinutes,
    int? portions,
    String? category,
    List<String>? tags,
    String? imageUrl,
    List<String>? imageUrls,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final recipeId = id ?? 'recipe_${_idCounter++}';

    // Create a personal recipe using the factory method
    return rf.RecipeFactory.createPersonal(
      title: title ?? faker.food.dish(),
      description: description ?? faker.lorem.sentence(),
      ingredients: ingredients ??
          List.generate(
            faker.randomGenerator.integer(5, min: 2),
            (_) => faker.randomGenerator.element([
              '2 ägg',
              '1 dl mjölk',
              '2 dl mjöl',
              '1 tsk salt',
              '2 msk smör',
              '3 dl vatten',
              '1 lök',
              '2 vitlöksklyftor',
              '1 kg potatis'
            ]),
          ),
      instructions: instructions ??
          List.generate(
            faker.randomGenerator.integer(8, min: 3),
            (_) => faker.lorem.sentence(),
          ),
      mealType: category ??
          faker.randomGenerator
              .element(['Frukost', 'Lunch', 'Middag', 'Dessert', 'Mellanmål']),
      timeMinutes: timeMinutes ?? faker.randomGenerator.integer(120, min: 15),
      portions: portions ?? faker.randomGenerator.integer(8, min: 1),
      tags: tags ??
          faker.randomGenerator
              .amount(
                (_) => faker.randomGenerator.element([
                  'vegetarisk',
                  'vegansk',
                  'glutenfri',
                  'laktosfri',
                  'snabb',
                  'enkel'
                ]),
                faker.randomGenerator.integer(4, min: 1),
              )
              .toList(),
      imageUrls: imageUrls ??
          (imageUrl != null
              ? [imageUrl]
              : ['https://example.com/recipe_$recipeId.jpg']),
      createdBy: userId ?? 'test_user',
    );
  }

  static List<Recipe> buildList(int count) {
    return List.generate(count, (_) => build());
  }

  static Recipe empty() {
    return rf.RecipeFactory.createPersonal(
      title: '',
      description: '',
      ingredients: [],
      instructions: [],
      mealType: 'Middag',
      createdBy: 'test_user',
    );
  }
}

/// Factory for creating mock user profiles
class UserProfileFactory {
  static int _idCounter = 1;

  static UserProfile build({
    String? uid,
    String? displayName,
    String? email,
    String? bio,
    String? avatarUrl,
    bool? isSearchable,
    bool? allowEmailSearch,
    int? publicRecipeCount,
    int? friendsCount,
    DateTime? joinedAt,
    DateTime? lastActiveAt,
    bool? isOnline,
    String? fcmToken,
    DateTime? fcmTokenUpdatedAt,
    bool? notificationsEnabled,
  }) {
    final now = DateTime.now();
    return UserProfile(
      uid: uid ?? 'user_${_idCounter++}',
      displayName: displayName ?? faker.person.name(),
      email: email ?? faker.internet.email(),
      bio: bio ?? faker.lorem.sentence(),
      avatarUrl: avatarUrl ?? 'https://example.com/avatar_$_idCounter.jpg',
      isSearchable: isSearchable ?? true,
      allowEmailSearch: allowEmailSearch ?? false,
      publicRecipeCount: publicRecipeCount ?? faker.randomGenerator.integer(50),
      friendsCount: friendsCount ?? faker.randomGenerator.integer(100),
      joinedAt: joinedAt ??
          now.subtract(Duration(days: faker.randomGenerator.integer(365))),
      lastActiveAt: lastActiveAt ?? now,
      isOnline: isOnline ?? faker.randomGenerator.boolean(),
      fcmToken: fcmToken,
      fcmTokenUpdatedAt: fcmTokenUpdatedAt,
      notificationsEnabled: notificationsEnabled ?? true,
    );
  }
}

/// Factory for creating mock shared menus
class SharedMenuFactory {
  static int _idCounter = 1;

  static SharedMenu build({
    String? id,
    String? sharedByUserId,
    String? sharedByDisplayName,
    List<String>? sharedToUserIds,
    DateTime? sharedAt,
    String? shareMessage,
    String? menuTitle,
    Map<String, List<Recipe>>? menuSnapshot,
    List<String>? viewedByUserIds,
    List<String>? importedByUserIds,
    List<String>? dismissedByUserIds,
    bool? allowCollaboration,
  }) {
    return SharedMenu(
      id: id ?? 'shared_menu_${_idCounter++}',
      sharedByUserId: sharedByUserId ?? 'test_user',
      sharedByDisplayName: sharedByDisplayName ?? faker.person.name(),
      sharedToUserIds: sharedToUserIds ?? ['friend_1', 'friend_2'],
      sharedAt: sharedAt ?? DateTime.now(),
      shareMessage: shareMessage ?? faker.lorem.sentence(),
      menuTitle: menuTitle ?? 'Veckomeny v.${DateTime.now().weekday}',
      menuSnapshot: menuSnapshot ??
          {
            'Måndag': [RecipeFactory.build()],
            'Tisdag': [RecipeFactory.build()],
            'Onsdag': [RecipeFactory.build()],
          },
      viewedByUserIds: viewedByUserIds ?? [],
      importedByUserIds: importedByUserIds ?? [],
      dismissedByUserIds: dismissedByUserIds ?? [],
      allowCollaboration: allowCollaboration ?? false,
    );
  }

  static SharedMenu empty() {
    return SharedMenu(
      id: 'empty_menu',
      sharedByUserId: 'test_user',
      sharedByDisplayName: 'Test User',
      sharedToUserIds: [],
      menuTitle: 'Empty Menu',
      menuSnapshot: {},
    );
  }
}

/// Factory for creating mock shopping lists
class ShoppingListFactory {
  static int _idCounter = 1;

  static UnifiedShoppingList build({
    String? id,
    String? name,
    String? userId,
    String? userDisplayName,
    List<UnifiedShoppingItem>? items,
    ListType? type,
    Map<String, SharedListPermission>? memberPermissions,
    String? description,
    bool? allowGuestEditing,
    bool? autoRemoveCompleted,
  }) {
    final listId = id ?? 'shopping_list_${_idCounter++}';
    final ownerId = userId ?? 'test_user';

    // Create some default items if none provided
    final defaultItems = items ??
        List.generate(
          faker.randomGenerator.integer(5, min: 0),
          (index) => UnifiedShoppingItem(
            id: 'item_${listId}_$index',
            name: faker.randomGenerator.element([
              'Mjölk',
              'Ägg',
              'Mjöl',
              'Smör',
              'Salt',
              'Socker',
              'Potatis',
              'Lök',
              'Tomater',
              'Gurka',
              'Ost',
              'Bröd',
              'Kaffe',
              'Te',
              'Juice'
            ]),
            amount: faker.randomGenerator.integer(3, min: 1).toDouble(),
            unit: faker.randomGenerator.element(['st', 'kg', 'l', 'dl', 'msk']),
            category: faker.randomGenerator
                .element(['Mejeri', 'Grönsaker', 'Skafferi', 'Bröd', 'Dryck']),
            bought: faker.randomGenerator.boolean(),
            addedByUserId: ownerId,
            addedByDisplayName: userDisplayName ?? faker.person.name(),
            addedAt: DateTime.now()
                .subtract(Duration(hours: faker.randomGenerator.integer(24))),
          ),
        );

    return UnifiedShoppingList(
      id: listId,
      name: name ?? 'Shopping List ${_idCounter - 1}',
      ownerId: ownerId,
      ownerDisplayName: userDisplayName ?? faker.person.name(),
      items: defaultItems,
      type: type ?? ListType.personal,
      memberPermissions: memberPermissions ?? {},
      description: description,
      allowGuestEditing: allowGuestEditing ?? false,
      autoRemoveCompleted: autoRemoveCompleted ?? false,
    );
  }

  static List<UnifiedShoppingList> buildList(int count) {
    return List.generate(count, (_) => build());
  }
}

/// Factory for creating mock conversations
class ConversationFactory {
  static int _idCounter = 1;

  static Conversation build({
    String? id,
    List<String>? participantIds,
    Map<String, String>? participantDisplayNames,
    Map<String, String?>? participantAvatarUrls,
    Message? lastMessage,
    Map<String, DateTime>? lastReadTimestamps,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? title,
    bool? isGroup,
  }) {
    final now = DateTime.now();
    final defaultParticipantIds = ['user1', 'user2'];
    final finalParticipantIds = participantIds ?? defaultParticipantIds;

    return Conversation(
      id: id ?? 'conversation_${_idCounter++}',
      participantIds: finalParticipantIds,
      participantDisplayNames: participantDisplayNames ??
          {for (var pid in finalParticipantIds) pid: faker.person.name()},
      participantAvatarUrls: participantAvatarUrls ??
          {
            for (var pid in finalParticipantIds)
              pid: 'https://example.com/avatar_$pid.jpg'
          },
      lastMessage: lastMessage,
      lastReadTimestamps:
          lastReadTimestamps ?? {for (var pid in finalParticipantIds) pid: now},
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      title: title,
      isGroup: isGroup ?? false,
    );
  }

  static Conversation empty() {
    return Conversation(
      id: 'empty_conversation',
      participantIds: [],
      participantDisplayNames: {},
      participantAvatarUrls: {},
      lastMessage: null,
      lastReadTimestamps: {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      title: null,
      isGroup: false,
    );
  }
}

/// Factory for creating mock messages
class MessageFactory {
  static int _idCounter = 1;

  static Message build({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderDisplayName,
    String? senderAvatarUrl,
    String? text,
    MessageType? type,
    MessageStatus? status,
    String? sharedRecipeId,
    String? sharedMenuId,
    String? sharedShoppingListId,
    String? replyToMessageId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEdited,
  }) {
    final now = DateTime.now();

    return Message(
      id: id ?? 'message_${_idCounter++}',
      conversationId: conversationId ?? 'conversation_1',
      senderId: senderId ?? 'user_1',
      senderDisplayName: senderDisplayName ?? faker.person.name(),
      senderAvatarUrl: senderAvatarUrl ?? 'https://example.com/avatar.jpg',
      content: text ?? faker.lorem.sentence(),
      type: type ?? MessageType.text,
      status: status ?? MessageStatus.sent,
      metadata: sharedRecipeId != null ? {'recipeId': sharedRecipeId} :
                sharedMenuId != null ? {'menuId': sharedMenuId} :
                sharedShoppingListId != null ? {'shoppingListId': sharedShoppingListId} : null,
      replyToMessageId: replyToMessageId,  
      sentAt: createdAt ?? now,
      isEdited: isEdited ?? false,
    );
  }

  static Message empty() {
    return Message(
      id: 'empty_message',
      conversationId: 'empty_conversation',
      senderId: 'empty_user',
      senderDisplayName: '',
      senderAvatarUrl: null,
      content: '',
      type: MessageType.text,
      status: MessageStatus.sent,
      metadata: null,
      replyToMessageId: null,
      sentAt: DateTime.now(),
      isEdited: false,
    );
  }
}

/// Factory for creating mock friends
class FriendFactory {
  static int _idCounter = 1;

  static Friend build({
    String? id,
    String? userId,
    String? name,
    String? email,
    String? profileImageUrl,
    DateTime? friendsSince,
    bool? isFavorite,
    List<String>? categories,
  }) {
    return Friend(
      id: id ?? 'friend_${_idCounter++}',
      name: name ?? faker.person.name(),
      email: email ?? faker.internet.email(),
    );
  }

  static Friend empty() {
    return Friend(
      id: 'empty_friend',
      name: '',
      email: '',
    );
  }
}

/// Factory for creating mock friend requests
class FriendRequestFactory {
  static int _idCounter = 1;

  static FriendRequest build({
    String? id,
    String? fromUserId,
    String? toUserId,
    FriendRequestStatus? status,
    String? message,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();

    return FriendRequest(
      id: id ?? 'friend_request_${_idCounter++}',
      fromUserId: fromUserId ?? 'from_user_$_idCounter',
      toUserId: toUserId ?? 'to_user_$_idCounter',
      status: status ?? FriendRequestStatus.pending,
      message: message ?? faker.lorem.sentence(),
      sentAt: createdAt ?? now,
    );
  }

  static FriendRequest empty() {
    return FriendRequest(
      id: 'empty_request',
      fromUserId: 'empty_from',
      toUserId: 'empty_to',
      status: FriendRequestStatus.pending,
      message: null,
      sentAt: DateTime.now(),
    );
  }
}

/// Factory for creating mock shopping lists
class UnifiedShoppingListFactory {
  static int _idCounter = 1;

  static UnifiedShoppingList build({
    String? id,
    String? name,
    String? ownerId,
    String? ownerDisplayName,
    List<UnifiedShoppingItem>? items,
    ListType? type,
    Map<String, SharedListPermission>? memberPermissions,
    String? description,
    bool? allowGuestEditing,
    bool? autoRemoveCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    final listId = id ?? 'shopping_list_${_idCounter++}';

    return UnifiedShoppingList(
      id: listId,
      name: name ?? 'Shopping List $_idCounter',
      ownerId: ownerId ?? 'owner_user',
      ownerDisplayName: ownerDisplayName ?? faker.person.name(),
      items: items ?? [],
      type: type ?? ListType.personal,
      memberPermissions: memberPermissions ?? {},
      description: description,
      allowGuestEditing: allowGuestEditing ?? false,
      autoRemoveCompleted: autoRemoveCompleted ?? false,
      createdAt: createdAt ?? now,
      // updatedAt removed from model
    );
  }

  static UnifiedShoppingList empty() {
    return UnifiedShoppingList(
      id: 'empty_list',
      name: 'Empty List',
      ownerId: 'empty_owner',
      ownerDisplayName: '',
      items: [],
      type: ListType.personal,
      memberPermissions: {},
      description: null,
      allowGuestEditing: false,
      autoRemoveCompleted: false,
      createdAt: DateTime.now(),
      // updatedAt removed from model
    );
  }
}

/// Factory for creating mock shopping items
class UnifiedShoppingItemFactory {
  static int _idCounter = 1;

  static UnifiedShoppingItem build({
    String? id,
    String? name,
    double? amount,
    String? unit,
    String? category,
    bool? bought,
    String? addedByUserId,
    String? addedByDisplayName,
    DateTime? addedAt,
    // boughtBy fields removed from model
    String? note,
  }) {
    final now = DateTime.now();

    return UnifiedShoppingItem(
      id: id ?? 'item_${_idCounter++}',
      name: name ?? faker.food.cuisine(),
      amount: amount ?? faker.randomGenerator.integer(5, min: 1).toDouble(),
      unit: unit ?? 'st',
      category: category ?? 'Övrigt',
      bought: bought ?? false,
      addedByUserId: addedByUserId ?? 'user_1',
      addedByDisplayName: addedByDisplayName ?? faker.person.name(),
      addedAt: addedAt ?? now,
      // boughtBy fields removed
      // boughtAt removed from model
      note: note,
    );
  }

  static UnifiedShoppingItem empty() {
    return UnifiedShoppingItem(
      id: 'empty_item',
      name: '',
      amount: 1,
      unit: 'st',
      category: 'Övrigt',
      bought: false,
      addedByUserId: 'empty_user',
      addedByDisplayName: '',
      addedAt: DateTime.now(),
      // boughtBy fields removed
      // boughtAt removed from model
      note: null,
    );
  }
}

/// Factory for creating mock friend categories
class FriendCategoryFactory {
  static int _idCounter = 1;

  static FriendCategory build({
    String? id,
    String? name,
    String? description,
    String? emoji,
    List<String>? friendUserIds,
    String? ownerId,
    int? sortOrder,
    bool? isDefault,
  }) {
    return FriendCategory(
      id: id ?? 'category_${_idCounter++}',
      name: name ?? faker.lorem.word(),
      ownerId: ownerId ?? 'test_user',
      description: description,
      emoji: emoji,
      friendUserIds: friendUserIds ?? [],
      sortOrder: sortOrder ?? 0,
      isDefault: isDefault ?? false,
    );
  }
}

/// Factory for creating mock group invitations
class GroupInvitationFactory {
  static int _idCounter = 1;

  static GroupInvitation build({
    String? id,
    String? groupId,
    String? groupName,
    String? invitedBy,
    String? invitedByName,
    String? invitedUserId,
    GroupInvitationStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();

    return GroupInvitation(
      id: id ?? 'invitation_${_idCounter++}',
      groupId: groupId ?? 'group_$_idCounter',
      groupName: groupName ?? faker.company.name(),
      fromUserId: invitedBy ?? 'inviter_user',
      fromUserName: invitedByName ?? faker.person.name(),
      groupEmoji: '🍳',
      toUserId: invitedUserId ?? 'invited_user',
      status: status ?? GroupInvitationStatus.pending,
      sentAt: createdAt ?? now,
    );
  }
}

/// Factory for creating mock shared recipes
class SharedRecipeFactory {
  static int _idCounter = 1;

  static SharedRecipe build({
    String? id,
    String? originalRecipeId,
    Recipe? recipeSnapshot,
    String? sharedByUserId,
    String? sharedByDisplayName,
    List<String>? sharedToUserIds,
    DateTime? sharedAt,
    String? shareMessage,
    ShareScope? scope,
    bool? allowImport,
    bool? allowCollaboration,
    int? viewCount,
    int? importCount,
    List<String>? viewedByUserIds,
    List<String>? importedByUserIds,
    List<String>? dismissedByUserIds,
  }) {
    final recipeId = id ?? 'shared_recipe_${_idCounter++}';
    final now = DateTime.now();
    final recipe = recipeSnapshot ?? RecipeFactory.build(id: 'recipe_$recipeId');

    return SharedRecipe(
      id: recipeId,
      originalRecipeId: originalRecipeId ?? recipe.id,
      sharedByUserId: sharedByUserId ?? 'test_user',
      sharedByDisplayName: sharedByDisplayName ?? faker.person.name(),
      sharedToUserIds: sharedToUserIds ?? ['friend_1', 'friend_2'],
      sharedAt: sharedAt ?? now,
      shareMessage: shareMessage ?? faker.lorem.sentence(),
      scope: scope ?? ShareScope.individual,
      allowImport: allowImport ?? true,
      allowCollaboration: allowCollaboration ?? false,
      viewCount: viewCount ?? 0,
      importCount: importCount ?? 0,
      viewedByUserIds: viewedByUserIds ?? [],
      importedByUserIds: importedByUserIds ?? [],
      dismissedByUserIds: dismissedByUserIds ?? [],
      recipeSnapshot: recipe,
    );
  }

  static SharedRecipe empty() {
    final recipe = RecipeFactory.empty();
    return SharedRecipe(
      id: 'empty_shared_recipe',
      originalRecipeId: recipe.id,
      sharedByUserId: 'test_user',
      sharedByDisplayName: 'Test User',
      sharedToUserIds: [],
      sharedAt: DateTime.now(),
      shareMessage: '',
      scope: ShareScope.individual,
      allowImport: false,
      allowCollaboration: false,
      viewCount: 0,
      importCount: 0,
      viewedByUserIds: [],
      importedByUserIds: [],
      dismissedByUserIds: [],
      recipeSnapshot: recipe,
    );
  }
}
