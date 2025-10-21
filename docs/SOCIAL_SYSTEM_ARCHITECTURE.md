# Butlery Social Interaction System - Comprehensive Architecture Documentation

## Executive Summary

The Butlery Flutter app implements a sophisticated social interaction system enabling collaborative cooking and community engagement. Built on MVVM + Repository pattern with comprehensive Firebase integration, the system manages friend relationships, content sharing, social interactions, and real-time collaboration with 132+ social-related files organized around clean architecture principles.

---

## 1. SOCIAL MODULE DI STRUCTURE

### Location
`/home/user/butlery/lib/core/di/modules/social_module.dart`

### Module Configuration

```
SocialModule (Priority: 20)
├── Dependencies: [CoreModule, ContentModule]
├── Provides: 12 primary services
└── Lifecycle: Configuration → Initialize → HealthCheck
```

### Registered Services

#### Core Social Services
1. **UserRepository** → FirebaseUserRepository
   - Manages user profiles and social metadata
   - Integration point for user data in social contexts

2. **UserService**
   - Provides current user profile and settings
   - Acts as data source for UserProfile objects

3. **FriendsRepository** → FirebaseFriendsRepository (Facade)
   - Facade pattern coordinating 4 specialized repositories:
     - FriendRequestRepository: Request lifecycle
     - FriendRelationshipRepository: Mutual friendships
     - FriendCategoryRepository: Friend groups
     - GroupInvitationRepository: Group invitations

4. **UnifiedFriendsService**
   - High-level friend management coordinator
   - Real-time synchronization with Firebase
   - Manages friend state through FriendsStateManager

#### Comment & Rating Services
5. **CommentsRepository** → FirebaseCommentsRepository
   - Threaded recipe comment management
   - Like/unlike functionality
   - Performance optimized with 50-comment load limit

6. **RatingsRepository** → FirebaseRatingsRepository
   - User recipe ratings system
   - Aggregated rating statistics

#### Social Sharing Services
7. **SocialRecipeRepository** → FirebaseSocialRecipeRepository
   - Manages shared recipes
   - Status tracking (viewed, imported, dismissed)

8. **SocialRecipeService** (Lazy Singleton)
   - High-level recipe sharing coordination
   - Depends on: UnifiedRecipeService, UserService, PermissionService

9. **SocialSharingRepository** → FirebaseSocialSharingRepository
   - General sharing operations
   - Multi-content-type support (recipes, menus, shopping lists)

#### Connectivity & Deep Link Services
10. **DeepLinkRepository** → FirebaseDeepLinkRepository
11. **DeepLinkService**
12. **ConnectivityRepository** → FirebaseConnectivityRepository
13. **ConnectivityMonitoringService**

#### Operations
14. **SocialMenuOperations**
    - Menu-specific social operations
    - Group sharing coordination

### Initialization Flow

```
1. CoreModule.configure()
   ↓
2. SocialModule.configure()
   - Registers all repositories (singletons)
   - Registers lazy singletons for complex services
   ↓
3. SocialModule.initialize()
   - Initialize UserService
   - Initialize UnifiedFriendsService
   - Setup real-time listeners
   ↓
4. SocialModule.healthCheck()
   - Validate all 12 services accessible
   - Check HealthCheckable services
```

---

## 2. CORE SOCIAL FEATURES

### A. Friend Management

#### Friend Models
```
Friend (Simple)
├── id
├── name
└── email

FriendRequest
├── id, fromUserId, toUserId
├── status: FriendRequestStatus (pending|accepted|rejected|cancelled|expired)
├── sentAt, respondedAt
├── message (optional)
├── isExpired: bool (7-day timeout)
├── Lifecycle methods: accept(), reject(), cancel()
└── Convenience: timeAgoText, isPending, isCompleted

FriendCategory
├── id, ownerId, name
├── description, emoji
├── friendUserIds (member list)
├── createdAt, updatedAt, sortOrder
├── isDefault: bool
├── Methods: addFriend(), removeFriend(), updateMetadata()
├── Getters: friendCount, isEmpty, displayName, summary
└── DefaultFriendCategories: Familj, Vänner, Grannar, Jobbet, Matgrupp
```

#### Friend Management Operations

**FriendsManagementOperations**
```
sendFriendRequest(recipientId, message?)
├── Validation: Input validation, permission checks
├── Duplicate prevention: Check existing requests
├── Notification: Send friend request notification
└── Firebase: Write to friend_requests collection

acceptFriendRequest(requestId)
├── Status update: pending → accepted
├── Relationship creation: Bidirectional friendship
├── Notification: Send acceptance notification
└── Timeline: Record respondedAt timestamp

rejectFriendRequest(requestId)
├── Status update: pending → rejected
└── Cleanup: Remove request document

removeFriend(friendId)
├── Relationship cleanup: Remove both directions
├── Category cleanup: Remove from all categories
└── Content cleanup: Handle shared content permissions

searchUsers(query)
├── Full-text search on public_profiles
├── Mutual friend detection
├── Filtering: Exclude existing friends, blocked users
└── Performance: Cached results with debouncing

blockUser(userId)
├── Relationship blocking
├── Notification disabling
└── Content access restriction

unblockUser(userId)
└── Restore normal relationship state
```

### B. Content Sharing (Multi-Type)

#### Shared Content Models

**SharedRecipe**
```
extends BaseSharedContentModel<Recipe>
├── originalRecipeId: String
├── recipeSnapshot: Recipe (complete snapshot at share time)
├── scope: ShareScope (individual|multiple|friends)
├── allowImport: bool
├── allowCollaboration: bool
├── importAttributionUserId: String? (who imported)
└── Status tracking (via mixin):
    ├── viewedByUserIds: List<String>
    ├── importedByUserIds: List<String>
    ├── dismissedByUserIds: List<String>
    └── engagedByUserIds: List<String>
```

**SharedMenu**
```
Similar to SharedRecipe but for menus
├── menuSnapshot: Menu (complete menu structure)
├── recipeIds: List<String> (recipes in menu)
└── Bulk recipe sharing support
```

**SharedShoppingList**
```
Collaborative shopping list sharing
├── listSnapshot: ShoppingList
├── collaborators: List<String> (bidirectional users)
└── Real-time sync on updates
```

**SharingPermissions**
```
Granular access control
├── canView: bool (default: true)
├── canEdit: bool (default: false)
├── canReshare: bool (default: false)
├── canComment: bool (default: true)
├── expiresAt: DateTime? (optional expiration)
└── Convenience methods:
    ├── readOnly(): View + Comment only
    ├── collaborative(): Full access
    └── viewOnly(): View only
```

#### Sharing Operations

**Social Sharing Workflow**
```
1. User initiates share from content detail view
2. Universal share dialog opens
3. Share mode selection: Friend, Group, or List
4. Recipient selection with preview
5. Permission selection
6. Optional message
7. Execute share:
   ├── Create SharedContent document
   ├── Update recipient status
   ├── Send notifications
   └── Sync across devices
```

**SocialGroupSharingOperations**
```
shareContentToGroup(groupId, content)
├── Validate group membership
├── Resolve group members
├── Create multiple SharedContent docs
└── Notify all group members

bulkShareContentToGroups(groupIds, contentList)
├── Progress tracking
├── Batch Firebase writes
├── Error recovery
└── Notification batching

resolveGroupMemberProfiles(groupId)
├── Fetch group members
├── Get public profiles
└── Return UserProfile list
```

### C. Social Interactions (Comments & Likes)

#### Recipe Comment Model

```
RecipeComment
├── id, recipeId
├── authorId, authorDisplayName, authorAvatarUrl
├── text: String (main comment content)
├── createdAt, editedAt: DateTime
├── likedByUserIds: List<String>
├── parentCommentId: String? (for threading)
├── replyCount: int (cached)
├── isDeleted: bool (soft delete)
│
├── Convenience methods:
│ ├── addLike(userId): Add with duplicate prevention
│ ├── removeLike(userId): Remove with existence check
│ ├── edit(newText): Update with editedAt timestamp
│ ├── delete(): Soft delete with Swedish message
│ └── timeAgoText: Swedish time format (Nu, 5 min sedan, etc.)
│
└── Getters:
  ├── likeCount: int
  ├── isEdited: bool
  ├── isTopLevel: bool
  ├── hasReplies: bool
  ├── isLikedBy(userId): bool
  └── canBeEditedBy(userId): bool
```

#### Comment Management

**FirebaseCommentsRepository**
```
getCommentsForRecipe(recipeId)
├── Query: parentCommentId == null (top-level only)
├── Sort: orderBy createdAt ascending
├── Limit: 50 comments max (performance)
└── Return: List<RecipeComment>

addComment(recipeId, userId, content, parentCommentId?)
├── Validation: Content length 1-1000 chars
├── Create: RecipeComment.create()
├── Persist: Save to recipe_comments collection
├── Update: Increment parent replyCount if threaded
└── Return: Created comment

toggleCommentLike(commentId, userId)
├── Check: Is userId in likedByUserIds?
├── If yes: removeLike()
├── If no: addLike()
└── Persist: Update likedByUserIds list

getCommentsStream(recipeId)
├── Real-time listener on recipe_comments
├── Filter: parentCommentId == null
├── Sort: By createdAt ascending
└── Return: Stream<List<RecipeComment>>
```

### D. User Profiles & Social Data

#### Social Profile Features

**UserProfile (from UserService)**
```
├── uid: String (primary identifier)
├── displayName: String
├── email: String
├── photoUrl: String? (avatar)
├── isSearchable: bool (privacy setting)
├── profileCompleteness: double (0-1)
├── preferences: Map<String, dynamic>
│ ├── notifications.enabled: bool
│ ├── social.visibility: private|friends|public
│ └── sharing.allowByDefault: bool
│
└── Social enrichment:
  ├── friendCount: int (from service)
  ├── mutualFriends: List<String> (from operations)
  └── lastSeen: DateTime? (from presence tracking)
```

**Profile Visibility & Discovery**
```
public_profiles collection (read by all authenticated users)
├── Anyone can read any profile (for user search)
├── Profile owners can update their own
├── isSearchable flag controls discoverability
└── Used for friend search, group member discovery
```

---

## 3. DATA FLOW ARCHITECTURE

### A. Complete Request/Response Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE LAYER                     │
│ (Views, Widgets, UI Components)                                 │
│                                                                  │
│ FriendsListView → [Friend List, Groups Tab, Requests Tab]      │
│ SharedWithMeView → [Shared Recipes, Menus]                     │
│ RecipeDetailView → [Comments, Likes]                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER (ViewModels)               │
│ (MVVM ChangeNotifier Pattern)                                   │
│                                                                  │
│ FriendsViewModel                                                 │
│ ├── State: _friends, _incomingRequests, _searchResults        │
│ ├── Methods: sendFriendRequest(), acceptRequest()             │
│ └── Listeners: NotifyListeners on state changes               │
│                                                                 │
│ SharedContentViewModel                                          │
│ ├── State: _sharedRecipes, _sharedMenus, _isLoading           │
│ ├── Methods: getSharedRecipes(), importRecipe()              │
│ └── Streams: Real-time updates                                │
│                                                                 │
│ SocialRecipeViewModel                                           │
│ ├── State: _comments, _isCommentLoading                       │
│ ├── Methods: addComment(), likeComment(), deleteComment()    │
│ └── Engagement: Comment and like tracking                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    BUSINESS LOGIC LAYER (Services)               │
│ (Unified Services + Operations)                                │
│                                                                  │
│ UnifiedFriendsService (1338 lines, comprehensive facade)       │
│ ├── FriendsStateManager (state management)                     │
│ ├── FriendsManagementOperations (CRUD, search, blocking)      │
│ ├── FriendsCategoriesOperations (group management)            │
│ ├── FriendsInvitationsOperations (request lifecycle)          │
│ └── SocialGroupSharingOperations (group content sharing)      │
│                                                                 │
│ SocialRecipeService                                            │
│ ├── Recipe sharing coordination                               │
│ ├── Import management                                         │
│ └── Engagement tracking                                       │
│                                                                 │
│ UserService                                                    │
│ ├── Current user profile management                           │
│ ├── Profile updates and caching                               │
│ └── Privacy settings                                          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   DATA ACCESS LAYER (Repositories)               │
│ (Firebase Firestore Implementation + Facades)                  │
│                                                                  │
│ FirebaseFriendsRepository (Facade with 4 sub-repos)           │
│ ├── FriendRequestRepository                                    │
│ ├── FriendRelationshipRepository                              │
│ ├── FriendCategoryRepository                                  │
│ └── GroupInvitationRepository                                 │
│                                                                 │
│ FirebaseCommentsRepository                                    │
│ ├── CRUD: addComment(), getCommentsForRecipe()              │
│ ├── Engagement: toggleCommentLike()                         │
│ └── Streams: getCommentsStream()                            │
│                                                                 │
│ FirebaseSharedRecipeRepository                               │
│ ├── Sharing: createSharedRecipe(), getSharedRecipes()       │
│ ├── Status: markAsViewed(), markAsImported()               │
│ └── Lifecycle: dismissSharedRecipe()                        │
│                                                                 │
│ FirebaseSocialSharingRepository                              │
│ ├── Multi-type sharing (recipes, menus, lists)             │
│ ├── Batch operations                                        │
│ └── Real-time sync                                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              CLOUD BACKEND (Firebase Firestore)                 │
│                                                                  │
│ Collections:                                                    │
│ ├── friend_requests/                                           │
│ ├── public_profiles/                                           │
│ ├── shared_recipes/                                            │
│ ├── shared_menus/                                              │
│ ├── shared_shopping_lists/                                     │
│ ├── recipe_comments/                                           │
│ ├── group_invitations/                                         │
│ └── users/{userId}/friendCategories/                          │
│                                                                 │
│ Subcollections:                                                │
│ ├── realtime_recipes/{recipeId}/presence/                    │
│ ├── conversations/{convId}/messages/                         │
│ └── recipe_comments/{commentId}/likes/ (optional)            │
└─────────────────────────────────────────────────────────────────┘
```

### B. Specific Data Flow Examples

#### Example 1: Send Friend Request
```
FriendsListView
  ↓
FriendsViewModel.sendFriendRequest(userId, message)
  ↓
UnifiedFriendsService.sendFriendRequest(userId, message)
  ↓
FriendsManagementOperations.sendFriendRequest()
  ├── Validate input + current user
  ├── Check if request already exists
  ├── Create FriendRequest object
  └── Call repository.sendFriendRequest()
  ↓
FirebaseFriendsRepository
  ├── Delegate to FriendRequestRepository.sendFriendRequest()
  ├── Write to friend_requests/{requestId}
  ├── Update sender's outgoing requests
  ├── Update recipient's incoming requests
  ├── Emit real-time updates via streams
  └── Return success/failure
  ↓
FriendsStateManager (notifyListeners)
  ↓
FriendsListView re-renders with updated state
  ↓
Notification sent to recipient (via NotificationService)
```

#### Example 2: Import Shared Recipe
```
SharedWithMeView (shows shared recipe card)
  ↓
User taps "Import" button
  ↓
SharedContentViewModel.importSharedRecipe(sharedRecipeId)
  ├── Validate: User has permission to import
  ├── Fetch original recipe from recipeId
  ├── Create copy in user's personal recipes
  ├── Mark as imported in SharedContent
  └── Return success/failure
  ↓
Service flow:
├── SocialRecipeService.importSharedRecipe()
├── UnifiedRecipeService.createRecipe() [creates personal copy]
├── FirebaseSharedRecipeRepository.markAsImported()
└── Update importedByUserIds list
  ↓
Firebase:
├── Create /users/{userId}/recipes/{recipeId} (personal copy)
└── Update /shared_recipes/{sharedId}.importedByUserIds
  ↓
SharedContentViewModel updates UI
  └── Show "Imported successfully" + hide import button
```

#### Example 3: Add Comment with Threading
```
RecipeDetailView (comment input field)
  ↓
User enters comment text
  ↓
SocialRecipeViewModel.addComment(text, recipeId, parentCommentId?)
  ├── Create RecipeComment object
  ├── Set parentCommentId if reply
  └── Call repository.addComment()
  ↓
FirebaseCommentsRepository.addComment()
  ├── Validate content (1-1000 chars)
  ├── Write to /recipe_comments/{commentId}
  ├── If parentCommentId: increment parent.replyCount
  └── Return created comment
  ↓
Repository stream listener detects new comment
  ↓
SocialRecipeViewModel receives update via stream
  ├── Add to _comments list
  ├── Increment parent replyCount if threaded
  └── notifyListeners()
  ↓
RecipeDetailView re-renders
  └── New comment appears in list with Swedish timeago

User can then:
├── Like comment: toggleCommentLike()
├── Edit comment: editComment() [if author]
└── Delete comment: deleteComment() [if author + soft delete]
```

---

## 4. KEY COMPONENTS DEEP DIVE

### A. UnifiedFriendsService (1338 lines)

**Facade Pattern Implementation**

```
UnifiedFriendsService (Main Facade)
├── FriendsStateManager
│ ├── _friends: List<UserProfile>
│ ├── _incomingRequests: List<FriendRequest>
│ ├── _outgoingRequests: List<FriendRequest>
│ ├── _categories: List<FriendCategory>
│ ├── _sentInvitations: List<GroupInvitation>
│ ├── _receivedInvitations: List<GroupInvitation>
│ └── Real-time listeners for all collections
│
├── Operations Modules:
│ ├── FriendsManagementOperations
│ │ ├── sendFriendRequest()
│ │ ├── acceptFriendRequest()
│ │ ├── rejectFriendRequest()
│ │ ├── removeFriend()
│ │ ├── searchUsers()
│ │ ├── blockUser()
│ │ └── getMutualFriends()
│ │
│ ├── FriendsCategoriesOperations
│ │ ├── createCategory()
│ │ ├── deleteCategory()
│ │ ├── assignFriendsToCategory()
│ │ ├── removeFriendsFromCategory()
│ │ ├── getCategoryUsageStats()
│ │ └── createDefaultCategories()
│ │
│ ├── FriendsInvitationsOperations
│ │ ├── sendGroupInvitation()
│ │ ├── acceptGroupInvitation()
│ │ ├── rejectGroupInvitation()
│ │ └── getInvitationStatus()
│ │
│ └── SocialGroupSharingOperations
│   ├── shareContentToGroup()
│   ├── bulkShareContentToGroups()
│   ├── resolveGroupMemberProfiles()
│   └── getContentSharedToGroup()
│
└── Public API:
  ├── initialize(): Load all friend data and setup listeners
  ├── getFriends(): Get current friend list
  ├── getIncomingRequests(): Get pending requests
  ├── watchFriendActivity(): Real-time updates stream
  └── Delegates all specific operations to sub-modules
```

**Initialization Flow**
```
FriendsViewModel initialization
  ↓
UnifiedFriendsService.initialize()
  ├── Load friends list (parallel)
  ├── Load incoming requests
  ├── Load outgoing requests
  ├── Load friend categories
  ├── Load group invitations
  └── Setup real-time listeners on all collections
  ↓
FriendsStateManager now contains complete state
  ↓
Listeners emit updates on any collection changes
  ↓
FriendsViewModel receives updates via streams
```

### B. Social Repositories (Facade Pattern)

**FirebaseFriendsRepository (Facade)**
```
Extends: BaseFirebaseRepository<UserProfile>
Implements: FriendsRepository

Architecture:
├── Delegates to 4 specialized repositories:
│ ├── FriendRequestRepository
│ ├── FriendRelationshipRepository
│ ├── FriendCategoryRepository
│ └── GroupInvitationRepository
│
└── Benefits:
  ├── Single Responsibility: Each repo handles one concern
  ├── Maintainability: Easier to test and modify
  ├── Reusability: Sub-repos can be used independently
  └── Clarity: Clear separation of concerns
```

**FirebaseSharedRecipeRepository**
```
Extends: BaseSharedContentRepository<SharedRecipe>
Implements: SocialRecipeRepository

CRUD Operations:
├── createSharedRecipe(recipe)
├── getSharedRecipesForUser(userId)
├── updateSharedRecipe(recipe)
├── deleteSharedRecipe(recipeId)
└── getSharedRecipesStream(userId)

Status Management:
├── markAsViewed(recipeId, userId)
├── markAsImported(recipeId, userId)
├── markAsDismissed(recipeId, userId)
└── unmarkAsDismissed(recipeId, userId)

Permission Validation:
├── canViewSharedRecipe(recipeId, userId)
├── canImportSharedRecipe(recipeId, userId)
└── validateRecipientAccess()

Query Operations:
├── getRecipesSharedByUser(userId)
├── getRecipesSharedToUser(userId)
└── getSharedRecipesByDateRange(startDate, endDate)
```

---

## 5. FIREBASE DATA STRUCTURE & SECURITY RULES

### A. Collection Schema

#### friend_requests/
```firestore
{
  id: string (auto-generated),
  fromUserId: string,
  toUserId: string,
  status: "pending" | "accepted" | "rejected" | "cancelled" | "expired",
  sentAt: timestamp,
  respondedAt: timestamp | null,
  message: string | null,
  
  Security Rules:
  ├── read: if user is fromUserId OR toUserId
  ├── create: if user is fromUserId AND status == "pending"
  ├── update: if user is toUserId (recipient accepts/rejects)
  └── delete: if user is fromUserId OR toUserId
}
```

#### public_profiles/
```firestore
{
  uid: string (document ID = user ID),
  displayName: string,
  email: string,
  photoUrl: string | null,
  isSearchable: boolean,
  
  Security Rules:
  ├── read: if authenticated (anyone can search)
  ├── create: if user is owner AND has required fields
  ├── update: if user is owner
  └── delete: if user is owner
}
```

#### shared_recipes/
```firestore
{
  id: string (auto-generated),
  originalRecipeId: string,
  sharedByUserId: string,
  sharedByDisplayName: string,
  sharedToUserIds: [string],
  recipeSnapshot: Recipe,
  shareMessage: string | null,
  sharedAt: timestamp,
  scope: "individual" | "multiple" | "friends",
  allowImport: boolean,
  allowCollaboration: boolean,
  
  Status Tracking:
  ├── viewedByUserIds: [string],
  ├── importedByUserIds: [string],
  ├── dismissedByUserIds: [string],
  └── engagedByUserIds: [string],
  
  Security Rules:
  ├── read: if user is sharedByUserId OR in sharedToUserIds
  ├── create: if user is sharedByUserId
  ├── update: if user is sharedByUserId
  └── delete: if user is sharedByUserId OR in sharedToUserIds
}
```

#### users/{userId}/friendCategories/
```firestore
{
  id: string (auto-generated),
  ownerId: string,
  name: string,
  description: string | null,
  emoji: string | null,
  friendUserIds: [string],
  createdAt: timestamp,
  updatedAt: timestamp,
  sortOrder: number,
  isDefault: boolean,
  
  Security Rules:
  └── read/write: if user is owner (ownerId)
}
```

#### recipe_comments/
```firestore
{
  id: string (auto-generated),
  recipeId: string,
  authorId: string,
  authorDisplayName: string,
  authorAvatarUrl: string | null,
  text: string,
  createdAt: timestamp,
  editedAt: timestamp | null,
  likedByUserIds: [string],
  parentCommentId: string | null,
  replyCount: number,
  isDeleted: boolean,
  
  Security Rules:
  ├── read: if authenticated
  ├── create: if user is userId AND content size 1-1000
  ├── update: if user is userId AND content size 1-1000
  └── delete: if user is userId
}
```

#### conversations/{conversationId}/
```firestore
{
  id: string (auto-generated),
  participantIds: [string],
  createdAt: timestamp,
  lastMessageAt: timestamp,
  
  Subcollection: messages/
  {
    id: string (auto-generated),
    senderId: string,
    content: string,
    timestamp: timestamp,
    readBy: {string: timestamp}
  }
  
  Security Rules (Conversation):
  ├── read: if user in participantIds
  ├── create: if user in participantIds AND has required fields
  ├── update: if user in participantIds
  └── delete: if user in participantIds
  
  Security Rules (Messages):
  ├── read: if user in conversation.participantIds
  ├── create: if user is senderId AND in participantIds
  ├── update: if user is senderId
  └── delete: if user is senderId
}
```

#### shared_shopping_lists/
```firestore
{
  id: string (auto-generated),
  sharedByUserId: string,
  sharedToUserIds: [string],
  listSnapshot: ShoppingList,
  sharedAt: timestamp,
  permissions: SharingPermissions,
  
  Real-time Collaboration:
  ├── Participants can edit items
  ├── Changes sync immediately to all users
  └── Presence tracking via subcollection
  
  Security Rules:
  ├── read: if user is sharedByUserId OR in sharedToUserIds
  ├── create: if user is sharedByUserId AND in sharedToUserIds
  ├── update: if user is sharedByUserId OR in sharedToUserIds
  └── delete: if user is sharedByUserId
}
```

### B. Security Rules Architecture

```firestore
rules_version = '2';
service cloud.firestore {
  // Helper functions
  function isAuthenticated() {
    return request.auth != null;
  }
  
  function isOwner(userId) {
    return isAuthenticated() && request.auth.uid == userId;
  }
  
  function isInList(field) {
    return isAuthenticated() && request.auth.uid in resource.data[field];
  }
  
  function hasRequiredFields(fields) {
    return request.resource.data.keys().hasAll(fields);
  }
  
  // Collection-specific rules
  match /friend_requests/{requestId} {
    allow read: if isAuthenticated() && (
      request.auth.uid == resource.data.fromUserId ||
      request.auth.uid == resource.data.toUserId
    );
    
    allow create: if isOwner(request.resource.data.fromUserId)
      && request.resource.data.status == 'pending'
      && hasRequiredFields(['fromUserId', 'toUserId', 'status', 'sentAt']);
    
    allow update: if request.auth.uid == resource.data.toUserId
      && request.resource.data.status in ['accepted', 'rejected'];
    
    allow delete: if isAuthenticated() && (
      request.auth.uid == resource.data.fromUserId ||
      request.auth.uid == resource.data.toUserId
    );
  }
  
  match /shared_recipes/{shareId} {
    allow read: if isAuthenticated() && (
      request.auth.uid == resource.data.sharedByUserId ||
      request.auth.uid in resource.data.sharedToUserIds
    );
    
    allow create: if isOwner(request.resource.data.sharedByUserId)
      && request.resource.data.sharedToUserIds is list
      && hasRequiredFields(['sharedByUserId', 'sharedToUserIds', 'recipeSnapshot', 'sharedAt']);
    
    allow update: if request.auth.uid == resource.data.sharedByUserId;
    
    allow delete: if isAuthenticated() && (
      request.auth.uid == resource.data.sharedByUserId ||
      request.auth.uid in resource.data.sharedToUserIds
    );
  }
}
```

---

## 6. INTEGRATION POINTS

### A. Messaging Module Integration

```
MessagingModule (Separate DI Module)
│
├── NotificationService
│ ├── Sends friend request notifications
│ ├── Sends message notifications
│ ├── Sends shared content notifications
│ └── Sends comment notifications
│
└── ChatService / ConversationService
  ├── Direct messaging between friends
  ├── Group conversations
  └── Real-time message sync
```

**Social-Messaging Integration Points**

```
1. Friend Request Notification
   FriendsManagementOperations.sendFriendRequest()
   ↓
   → NotificationService.sendFriendRequestNotification()
   ↓
   Recipient receives push notification

2. Message Creation
   UserA sends message to UserB
   ↓
   → ConversationService.sendMessage()
   ├── Create message in Firestore
   ├── Update lastMessageAt
   └── Send notification to UserB

3. Shared Content Notification
   ShareRecipeDialog → Share executed
   ↓
   → NotificationService.sendSharedContentNotification()
   ↓
   Recipients receive "Friend shared recipe" notification

4. Comment Notification
   User adds comment on friend's recipe
   ↓
   → RecipeCommentNotificationService
   ├── Check if recipe owner subscribed
   ├── Get recipe owner ID
   └── Send notification
```

### B. Collaboration Module Integration

```
CollaborationModule
│
├── RealtimeRecipeService
│ ├── Collaborative recipe editing
│ ├── Multi-user real-time updates
│ └── Presence tracking
│
└── RealtimeShoppingService
  ├── Collaborative shopping lists
  ├── Item-level updates
  └── Real-time synchronization
```

**Social-Collaboration Integration Points**

```
1. Collaborative Recipe Editing
   User A shares recipe with edit permissions
   ↓
   User B receives shared recipe with allowCollaboration: true
   ↓
   Both users can edit recipe simultaneously
   ├── Changes sync via realtime_recipes collection
   ├── Presence tracking shows active editors
   └── Conflict resolution via last-write-wins

2. Collaborative Shopping List
   User A creates shopping list
   ↓
   User A adds collaborators (User B, User C)
   ↓
   All users can edit items in real-time
   ├── Item additions/completions sync immediately
   ├── Presence shows who's editing
   └── Changes persisted to shared_shopping_lists
```

### C. Content Module Integration

```
ContentModule
│
├── RecipeService (UnifiedRecipeService)
│ ├── Personal recipe management
│ ├── Recipe creation/editing
│ └── Recipe queries
│
└── MenuService (MenuService)
  ├── Menu management
  ├── Menu organization
  └── Menu queries
```

**Social-Content Integration Points**

```
1. Share Recipe Flow
   RecipeDetailView
   ↓
   → Share dialog (universal share)
   ├── Get recipe from RecipeService
   ├── Create SharedRecipe wrapper
   ├── Send to specified recipients
   └── Original recipe remains in personal collection

2. Import Shared Recipe
   SharedWithMeView
   ↓
   → User taps "Import"
   ├── Fetch SharedRecipe from SocialRecipeService
   ├── Get originalRecipeId and recipeSnapshot
   ├── Call RecipeService.createRecipe() [creates copy]
   ├── Mark as imported in SharedRecipe
   └── Add to personal recipes collection

3. Menu Sharing
   MenuDetailView
   ↓
   → Share menu
   ├── Get menu from MenuService
   ├── Create SharedMenu wrapper
   ├── Include all recipes in snapshot
   └── Share to recipients
```

### D. Notification Integration

**Notification Types for Social**

```
NotificationTypes
├── FRIEND_REQUEST
│ ├── Title: "Friend request from {name}"
│ ├── Body: "{message}" or "Would like to be your friend"
│ └── Action: openFriendRequestsView()
│
├── FRIEND_REQUEST_ACCEPTED
│ ├── Title: "{name} accepted your friend request"
│ └── Action: openFriendsListView()
│
├── RECIPE_SHARED
│ ├── Title: "{name} shared a recipe with you"
│ ├── Body: "{recipe_title}"
│ └── Action: openSharedRecipeDetail()
│
├── COMMENT_ADDED
│ ├── Title: "{name} commented on your recipe"
│ ├── Body: "{comment_preview}"
│ └── Action: openRecipeComments()
│
├── COMMENT_LIKED
│ ├── Title: "{name} liked your comment"
│ └── Action: openRecipeComments()
│
└── MESSAGE_RECEIVED
  ├── Title: "{name} sent you a message"
  ├── Body: "{message_preview}"
  └── Action: openConversation()
```

---

## 7. VIEWMODEL LAYER

### A. FriendsViewModel

```dart
class FriendsViewModel extends ChangeNotifier {
  final UnifiedFriendsService _friendsService;
  final UserService _userService;
  
  // State
  List<UserProfile> _friends = [];
  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> _outgoingRequests = [];
  List<FriendCategory> _categories = [];
  List<UserProfile> _searchResults = [];
  FriendshipStatus _friendshipStatus = FriendshipStatus.none;
  
  // Lifecycle
  bool _isDisposed = false;
  Timer? _debounceTimer;
  
  // Public API
  Future<bool> sendFriendRequest(String userId, {String? message})
  Future<bool> acceptFriendRequest(String requestId)
  Future<bool> rejectFriendRequest(String requestId)
  Future<bool> removeFriend(String friendId)
  Future<void> updateSearch(String query)
  FriendshipStatus getFriendshipStatus(String userId)
  List<UserProfile> getSelectedFriends()
  String getDisplayNameForUser(String userId)
  String? getProfilePictureUrlForUser(String userId)
}
```

### B. SharedContentViewModel

```dart
class SharedContentViewModel extends ChangeNotifier {
  // State
  List<SharedRecipe> _sharedRecipes = [];
  List<SharedMenu> _sharedMenus = [];
  String? _error;
  bool _isLoading = false;
  
  // Public API
  Future<void> loadSharedContent()
  Future<bool> importSharedRecipe(String sharedRecipeId)
  Future<bool> dismissSharedRecipe(String sharedRecipeId)
  Future<void> markAsViewed(String sharedRecipeId)
  List<SharedRecipe> getSharedRecipesFromFriend(String friendId)
}
```

### C. SocialRecipeViewModel

```dart
class SocialRecipeViewModel extends ChangeNotifier {
  // State
  List<RecipeComment> _comments = [];
  Map<String, int> _likeCountMap = {};
  bool _isCommentLoading = false;
  
  // Public API
  Future<void> loadComments(String recipeId)
  Future<bool> addComment(String recipeId, String text, {String? parentId})
  Future<bool> likeComment(String commentId)
  Future<bool> unlikeComment(String commentId)
  Future<bool> editComment(String commentId, String newText)
  Future<bool> deleteComment(String commentId)
  int getCommentLikeCount(String commentId)
  Stream<List<RecipeComment>> getCommentsStream(String recipeId)
}
```

---

## 8. VIEW LAYER COMPONENTS

### A. Main Social Views

```
FriendsListView
├── FriendsTab
│ ├── Friend list with status
│ ├── Friend search
│ └── Friend actions (remove, block)
│
├── GroupsTab
│ ├── Friend categories list
│ ├── Group creation
│ └── Group member management
│
├── RequestsTab
│ ├── Incoming requests with preview
│ ├── Outgoing requests status
│ └── Quick accept/reject actions
│
└── SearchTab
  ├── User search results
  ├── Mutual friend count
  └── Quick add button

SharedWithMeView
├── SharedContentAppBar
├── SharedContentSearchBar
├── SharedContentTabBar (Recipes | Menus)
└── SharedContentLists
  ├── SharedRecipeCard
  │ ├── Recipe preview
  │ ├── Shared by info
  │ ├── Import button
  │ └── Shared message
  │
  └── SharedMenuCard
    ├── Menu preview
    ├── Recipe count
    ├── Shared by info
    └── Import button

RecipeDetailView
├── Recipe content
├── RecipeDetailComments component
│ ├── Comment list
│ ├── Comment input
│ ├── Threaded replies
│ └── Like button
│
└── Share button → UniversalShareDialog
```

### B. Share Dialog Components

```
UniversalShareDialog
├── Header: Choose how to share
├── ModeSelection
│ ├── Share with friend
│ ├── Share with group
│ └── Share with list
│
├── TargetSelection
│ ├── Friend picker (search + list)
│ ├── Group picker (with member preview)
│ └── List picker
│
├── PermissionSelection
│ ├── View only
│ ├── View + Comment
│ └── Full collaboration
│
├── MessageInput (optional)
│ └── Custom share message
│
└── ShareButton
  └── Execute sharing operation
```

---

## 9. CACHING & OPTIMIZATION STRATEGIES

### A. Friend Caching

```
UnifiedFriendsService
├── In-memory cache:
│ ├── _friends (List<UserProfile>)
│ ├── _categories (List<FriendCategory>)
│ └── _requests (List<FriendRequest>)
│
└── Cache invalidation:
  ├── On initialize(): Full load
  ├── On real-time listener update: Incremental update
  ├── On manual refresh: Full reload
  └── Manual cache clear when logging out
```

### B. Comment Loading Optimization

```
FirebaseCommentsRepository.getCommentsForRecipe()
├── Limit: 50 top-level comments max
├── Sort: By createdAt ascending (oldest first)
├── Filter: parentCommentId == null (top-level only)
└── Pagination: Load more on scroll

Real-time streaming:
├── Listen on recipe_comments where recipeId == recipeId
├── Filter: parentCommentId == null
├── Updates: New comments added to stream
└── Performance: Efficient batch updates
```

### C. Shared Content Optimization

```
SharedContentViewModel
├── Load only user's shared recipes on init
├── Apply filters: viewed/not viewed, recipes/menus
├── Search: Client-side filtering on loaded data
├── Lazy load: Fetch friend details on demand
└── Cache: Store in ViewModel during session
```

---

## 10. ERROR HANDLING & VALIDATION

### A. Permission Validation

```
All social operations validate:
├── User authentication: isAuthenticated()
├── Resource ownership: isOwner(userId)
├── Access permissions: isInList(field)
├── Required fields: hasRequiredFields()
└── Business logic: Specific operation validation

Example: sendFriendRequest()
├── Validate user is authenticated
├── Validate recipient exists
├── Check no existing request
├── Check users not already friends
├── Check recipient not blocked
└── Create request
```

### B. Content Validation

```
Comment validation:
├── Length: 1-1000 characters
├── Not empty or whitespace only
├── No injection attempts detected
└── Author validation: Must be current user

Recipe share validation:
├── Original recipe exists
├── Recipients are valid users
├── Permissions are reasonable
└── Share message under limit
```

### C. Error Recovery

```
Real-time sync failures:
├── Automatic retry with exponential backoff
├── Optimistic UI updates (rollback on error)
├── Show user error messages
└── Log for analytics

Network disconnection:
├── Cache recent operations
├── Queue operations locally
├── Sync on reconnection
└── Notify user of pending changes
```

---

## 11. PERFORMANCE METRICS

```
Social System Performance Targets:

Friend Operations:
├── Load friends list: < 500ms
├── Send friend request: < 300ms
├── Accept request: < 300ms
├── Search users: < 200ms (debounced)
└── Search result limit: 50 users

Comment Operations:
├── Load comments (50): < 300ms
├── Add comment: < 200ms
├── Like/unlike: < 150ms
├── Comment stream latency: < 1s
└── Load limit: 50 top-level comments

Sharing Operations:
├── Load shared recipes: < 500ms
├── Import recipe: < 400ms
├── Share recipe: < 300ms
└── Bulk share (10 items): < 2s

Real-time Updates:
├── Presence sync: < 1s
├── Message delivery: < 2s
├── Comment updates: < 1.5s
└── Typing indicators: < 500ms
```

---

## 12. ARCHITECTURE PRINCIPLES & PATTERNS

### A. Design Patterns Applied

```
1. Facade Pattern
   └── FirebaseFriendsRepository wraps 4 sub-repositories
   └── UnifiedFriendsService wraps 4 operations modules
   
2. Repository Pattern
   └── All data access through repositories
   └── Dependency injection for easy testing
   
3. MVVM (Model-View-ViewModel)
   └── Clear separation: Views → ViewModels → Services
   └── Reactive updates via ChangeNotifier
   
4. Coordinator Pattern
   └── SocialRecipeCoordinator delegates to focused services
   
5. Streaming Pattern
   └── Real-time updates via Firestore listeners
   └── Stream-based reactive updates
   
6. Service Locator Pattern
   └── ServiceLocator.get<T>() for service access
   └── Dependency injection at app bootstrap
```

### B. Single Responsibility Principle

```
Each class has one reason to change:

FriendRequest
├── Responsibility: Model friend request data
└── Changes: If friend request structure changes

FriendsManagementOperations
├── Responsibility: Manage friend lifecycle
└── Changes: If friend management logic changes

FriendsViewModel
├── Responsibility: Present friend management UI
└── Changes: If UI requirements change

FirebaseFriendsRepository
├── Responsibility: Persist/retrieve friend data
└── Changes: If Firebase implementation changes
```

### C. Clean Architecture Layers

```
Presentation Layer (Views & ViewModels)
├── Responsibility: Display UI + handle user input
├── Dependency: On Services (unidirectional)
└── Testing: Easy to test with mock services

Business Logic Layer (Services & Operations)
├── Responsibility: Implement business rules
├── Dependency: On Repositories (unidirectional)
└── Testing: Easy to test with mock repositories

Data Access Layer (Repositories)
├── Responsibility: Persist/retrieve data
├── Dependency: On Firebase/local storage
└── Testing: Easy to test with mock Firebase

Domain Models (Models)
├── Responsibility: Represent business concepts
├── Dependency: None (pure data objects)
└── Testing: No external dependencies
```

---

## 13. SUMMARY TABLE

| Component | Location | Purpose | Key Methods |
|-----------|----------|---------|------------|
| **Models** | lib/models/ | Data structures | FriendRequest, SharedRecipe, RecipeComment |
| **Repositories** | lib/repositories/firebase/ | Data persistence | Create, read, update, delete operations |
| **Services** | lib/services/unified/ | Business logic | Friend management, sharing coordination |
| **Operations** | lib/services/unified/operations/ | Specialized operations | Specific feature implementations |
| **ViewModels** | lib/viewmodels/ | Presentation logic | State management, user interaction handling |
| **Views** | lib/views/social/ | UI rendering | Friend list, shared content display |
| **DI Module** | lib/core/di/modules/ | Dependency injection | Service registration & initialization |
| **Firebase** | firestore.rules | Backend rules | Data validation & security |

---

## 14. GETTING STARTED GUIDE

### For New Feature Development

```
1. Define the model
   └── Add to lib/models/

2. Create repository interface
   └── Add to lib/repositories/interfaces/

3. Implement Firebase repository
   └── Add to lib/repositories/firebase/

4. Create service layer
   └── Add to lib/services/unified/

5. Create ViewModel
   └── Add to lib/viewmodels/

6. Create Views/Widgets
   └── Add to lib/views/

7. Update DI Module
   └── Register in lib/core/di/modules/social_module.dart

8. Add Firebase security rules
   └── Update firestore.rules

9. Write tests
   └── Add to test/unit/
```

### For Bug Fixes

```
1. Reproduce issue with logging
   └── Add AppLogger.debug() at key points

2. Trace data flow
   └── View → ViewModel → Service → Repository → Firebase

3. Check Firebase security rules
   └── Verify permission for operation

4. Validate model assumptions
   └── Check data structure matches expectations

5. Test with mock data
   └── Use test fixtures to reproduce

6. Add regression test
   └── Prevent recurrence
```

---

## 15. TESTING STRATEGY

### Unit Tests by Layer

```
Model Tests (test/unit/models/)
├── FriendRequest lifecycle
├── SharedRecipe serialization
└── RecipeComment threading

Repository Tests (test/unit/repositories/)
├── Firebase CRUD operations
├── Query builders
└── Permission validation

Service Tests (test/unit/services/)
├── UnifiedFriendsService operations
├── SocialRecipeService sharing
└── Error handling

ViewModel Tests (test/unit/viewmodels/)
├── State management
├── Business logic coordination
└── Stream subscriptions
```

### Integration Tests

```
End-to-end social flows:
├── Send and accept friend request
├── Share recipe and import
├── Add and like comments
└── Bulk group sharing
```

---

## 16. KNOWN LIMITATIONS & FUTURE WORK

### Current Limitations

```
1. Comment threading only 2 levels (top-level + replies)
2. No pagination for large friend lists (but 50-comment limit)
3. No friend request expiration enforced server-side
4. No moderation system for inappropriate comments
5. Limited to 1000-character comments

Future Enhancements:
├── Unlimited nested comment threading
├── Full-text search on user profiles
├── Friend recommendation engine
├── Social feed aggregation
├── Advanced group permissions
└── Comment moderation system
```

---

This comprehensive documentation covers all major aspects of the Butlery social interaction system, from architecture and data flow to specific implementation details and integration points. The system is built on clean architecture principles with clear separation of concerns, comprehensive data validation, and real-time synchronization capabilities.

