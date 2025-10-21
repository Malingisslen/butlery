# Butlery Social System - Quick Reference Guide

## File Locations

### Key Files
- **Social Module DI**: `lib/core/di/modules/social_module.dart`
- **Models**: `lib/models/` (friend.dart, friend_request.dart, shared_recipe.dart, recipe_comment.dart, etc.)
- **Repositories**: `lib/repositories/firebase/` (firebase_friends_repository.dart, firebase_shared_recipe_repository.dart, etc.)
- **Services**: `lib/services/unified/` (unified_friends_service.dart, social_recipe_service.dart)
- **Operations**: `lib/services/unified/operations/` (friends_management_operations.dart, social_group_sharing_operations.dart, etc.)
- **ViewModels**: `lib/viewmodels/` (friends_viewmodel.dart, shared_content_viewmodel.dart, social_recipe_viewmodel.dart)
- **Views**: `lib/views/social/` (friends_list_view.dart, shared_with_me_view.dart)
- **Firebase Rules**: `firestore.rules`

## Core Data Models

### FriendRequest
```dart
FriendRequest.create(
  fromUserId: userId,
  toUserId: targetUserId,
  message: 'Optional personal message'
)
// Methods: accept(), reject(), cancel()
// Status: pending|accepted|rejected|cancelled|expired
// Auto-expires: 7 days
```

### SharedRecipe
```dart
SharedRecipe.create(
  originalRecipeId: recipeId,
  sharedByUserId: userId,
  sharedByDisplayName: 'Name',
  sharedToUserIds: [userId1, userId2],
  shareMessage: 'Check this out!',
  recipeSnapshot: originalRecipe,
  allowImport: true,
  allowCollaboration: false
)
// Status tracking: viewedByUserIds, importedByUserIds, dismissedByUserIds
```

### RecipeComment
```dart
RecipeComment.create(
  recipeId: recipeId,
  authorId: userId,
  authorDisplayName: 'Author Name',
  text: 'Comment text',
  parentCommentId: null  // For top-level, set to parentId for replies
)
// Methods: addLike(userId), removeLike(userId), edit(text), delete()
// Threaded: Two-level (top-level + replies)
```

### FriendCategory
```dart
FriendCategory.create(
  ownerId: userId,
  name: 'Familj',
  emoji: '👨‍👩‍👧‍👦',
  friendUserIds: [user1, user2, user3]
)
// Default categories: Familj, Vänner, Grannar, Jobbet, Matgrupp
```

## Service Access Pattern

```dart
// In ViewModels or Views, use ServiceLocator pattern:
final friendsService = ServiceLocator.get<UnifiedFriendsService>();
final userService = ServiceLocator.get<UserService>();
final recipeService = ServiceLocator.get<UnifiedRecipeService>();

// Initialize on first use:
await friendsService.initialize();
```

## Common Operations

### Send Friend Request
```dart
await friendsService.sendFriendRequest(
  recipientId,
  message: 'Optional message'
);
// Triggers: FriendsManagementOperations.sendFriendRequest()
// Result: Creates friend_requests doc + sends notification
```

### Accept Friend Request
```dart
await friendsService.acceptFriendRequest(requestId);
// Triggers: Creates bidirectional friendship
// Result: Updates friend_requests status to 'accepted'
```

### Share Recipe
```dart
await socialRecipeService.shareRecipeToFriends(
  recipeId,
  ['friend1Id', 'friend2Id'],
  message: 'You should try this!'
);
// Creates: shared_recipes document
// Marks: recipients in sharedToUserIds
```

### Import Shared Recipe
```dart
await socialRecipeService.importSharedRecipe(sharedRecipeId);
// Creates: Copy in user's personal recipes
// Updates: shared_recipes.importedByUserIds
```

### Add Comment
```dart
await commentsRepository.addComment(
  recipeId: recipeId,
  userId: currentUserId,
  content: 'Great recipe!',
  parentCommentId: null  // For reply, use parent comment ID
);
// Creates: recipe_comments document
// If threaded: Increments parent replyCount
```

### Like Comment
```dart
await commentsRepository.toggleCommentLike(commentId, userId);
// Adds/removes userId from comment.likedByUserIds
```

## Data Flow Patterns

### Friend Request Flow
```
UI (FriendsListView)
  ↓
ViewModel (FriendsViewModel.sendFriendRequest)
  ↓
Service (UnifiedFriendsService)
  ↓
Operations (FriendsManagementOperations)
  ↓
Repository (FirebaseFriendsRepository → FriendRequestRepository)
  ↓
Firebase (friend_requests/{id})
  ↓
Notification + Real-time Update
```

### Share Recipe Flow
```
UI (ShareDialog)
  ↓
ViewModel (SharedContentViewModel)
  ↓
Service (SocialRecipeService)
  ↓
Repository (FirebaseSharedRecipeRepository)
  ↓
Firebase (shared_recipes/{id})
  ↓
Notification + UpdateUI
```

## Firebase Collections Reference

| Collection | Purpose | Security | Notes |
|-----------|---------|----------|-------|
| `friend_requests/` | Friend requests | Sender/Recipient only | Auto-expires in 7 days |
| `public_profiles/` | User profiles | All authenticated can read | Used for user search |
| `shared_recipes/` | Shared recipes | Sender + Recipients | Snapshot included |
| `shared_menus/` | Shared menus | Sender + Recipients | Bulk recipe sharing |
| `shared_shopping_lists/` | Shared lists | Sender + Recipients | Real-time collab |
| `recipe_comments/` | Comments | All authenticated can read | Threaded (top-level + replies) |
| `users/{userId}/friendCategories/` | Friend groups | Owner only | Custom organization |
| `group_invitations/` | Group invites | Sender/Recipient only | Similar to friend requests |
| `conversations/` | Messaging | Participants only | With subcollection `messages/` |

## Firebase Security Rules Essentials

```firestore
// Key helper functions in firestore.rules

function isAuthenticated() {
  return request.auth != null;
}

function isOwner(userId) {
  return isAuthenticated() && request.auth.uid == userId;
}

function isInList(field) {
  return isAuthenticated() && request.auth.uid in resource.data[field];
}

// Example: Read shared recipe if you created it or received it
allow read: if isAuthenticated() && (
  request.auth.uid == resource.data.sharedByUserId ||
  request.auth.uid in resource.data.sharedToUserIds
);
```

## ViewModels API

### FriendsViewModel
```dart
sendFriendRequest(userId, message?) → Future<bool>
acceptFriendRequest(requestId) → Future<bool>
rejectFriendRequest(requestId) → Future<bool>
removeFriend(friendId) → Future<bool>
updateSearch(query) → Future<void>
getFriendshipStatus(userId) → FriendshipStatus
getDisplayNameForUser(userId) → String
getSelectedFriends() → List<UserProfile>
```

### SharedContentViewModel
```dart
loadSharedContent() → Future<void>
importSharedRecipe(sharedRecipeId) → Future<bool>
dismissSharedRecipe(sharedRecipeId) → Future<bool>
markAsViewed(sharedRecipeId) → Future<void>
getSharedRecipesFromFriend(friendId) → List<SharedRecipe>
```

### SocialRecipeViewModel
```dart
loadComments(recipeId) → Future<void>
addComment(recipeId, text, parentId?) → Future<bool>
likeComment(commentId) → Future<bool>
unlikeComment(commentId) → Future<bool>
editComment(commentId, newText) → Future<bool>
deleteComment(commentId) → Future<bool>
getCommentLikeCount(commentId) → int
```

## FriendshipStatus Enum

```dart
enum FriendshipStatus {
  none,              // No relationship
  friends,           // Active friendship
  requestSent,       // Outgoing request pending
  requestReceived,   // Incoming request pending
  blocked,           // User is blocked
}
```

## Real-time Streams

```dart
// Friend activity
friendsService.watchFriendActivity() → Stream<dynamic>

// Comments
commentsRepository.getCommentsStream(recipeId) → Stream<List<RecipeComment>>

// Shared recipes
sharedRecipeRepo.getSharedRecipesStream(userId) → Stream<List<SharedRecipe>>

// Incoming friend requests
friendsRepository.incomingRequestsStream(userId) → Stream<List<FriendRequest>>
```

## Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Friend not appearing | Not loaded from Firebase | Call `await friendsService.initialize()` |
| Shared recipe not visible | Wrong sharedToUserIds | Verify recipient ID is in list |
| Comment not appearing | Real-time listener delayed | Check Firebase listener registration |
| Permission denied | User not in access list | Verify Firebase security rules |
| Comment edit failed | User not author | Check `comment.authorId == currentUserId` |

## Development Workflow

### Adding New Social Feature

1. Create model in `lib/models/`
2. Create repository interface in `lib/repositories/interfaces/`
3. Implement Firebase repository in `lib/repositories/firebase/`
4. Add service methods in `lib/services/unified/`
5. Create operations module if needed
6. Add ViewModel methods in `lib/viewmodels/`
7. Create UI components in `lib/views/`
8. Update Firebase security rules in `firestore.rules`
9. Register in `lib/core/di/modules/social_module.dart`
10. Write tests in `test/unit/`

### Testing Social Features

```dart
// Test pattern
setUp() {
  final mockRepository = MockSocialRepository();
  final service = SocialService(repository: mockRepository);
}

test('send friend request', () async {
  expect(
    await service.sendFriendRequest('userId'),
    equals(true)
  );
});
```

## Performance Tips

1. **Limit Comment Loads**: Max 50 top-level comments per query
2. **Debounce Search**: Don't query on every keystroke
3. **Cache Friend Lists**: Store in ViewModel during session
4. **Use Pagination**: Load more items on scroll
5. **Batch Operations**: Combine multiple updates
6. **Avoid N+1**: Fetch related data in bulk

## Notifications Integration

Social events trigger notifications:
- Friend request received
- Friend request accepted
- Recipe shared
- Comment added
- Comment liked

Integration with `NotificationService` (MessagingModule)

## Troubleshooting

### No friends showing
- Check: User initialized friends service
- Check: Firebase `public_profiles` collection has users
- Check: Friend relationships actually exist in Firebase

### Shared recipes not visible
- Check: User in `sharedToUserIds` list
- Check: SharedRecipe document exists in Firebase
- Check: User has read permission per security rules

### Comments not updating
- Check: Real-time listener is active
- Check: Firebase comment stream is working
- Check: User authenticated

### Notifications not received
- Check: NotificationService initialized
- Check: User subscribed to notification topic
- Check: Firebase Cloud Messaging configured

---

For detailed information, see: `/home/user/butlery/docs/SOCIAL_SYSTEM_ARCHITECTURE.md`
