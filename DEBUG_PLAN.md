# Butlery - Test Plan

**Generated**: November 2025
**Last Updated**: December 2, 2025
**Purpose**: Comprehensive user journey testing with all features and service methods

---

## Journey 1: Authentication & Onboarding ✅ COMPLETE

### User Flow
1. User opens app for first time
2. User chooses to register or login
3. User completes registration with email/password
4. User profile is created automatically
5. User can reset password if forgotten
6. User can logout
7. User can delete account

### Test Steps
- [x] Open app without authentication → shows AuthView ✅ (2025-11-28)
- [ ] Register with valid email/password/displayName → account created
- [ ] Register with invalid email → shows error
- [ ] Register with weak password → shows error
- [x] Login with valid credentials → authenticated ✅ (2025-11-28)
- [x] Login with wrong password → shows error ✅ (2025-11-28)
- [ ] Login with non-existent email → shows error
- [x] Send password reset email → email sent ✅ (2025-11-28)
- [x] Logout → returns to AuthView ✅ (2025-11-28)
- [ ] Delete account → complete removal

### Features & Methods

**AuthService**
- `registerWithEmail(email, password, displayName)` - Create account
- `signInWithEmail(email, password)` - Login
- `signOut()` - Logout
- `logoutDueToInactivity()` - Session timeout logout
- `forceSignOut()` - Clear all credentials
- `sendPasswordResetEmail(email)` - Password recovery
- `deleteAccount()` - Account deletion
- `isAuthenticated` - Auth state check
- `currentUser` - Current Firebase user
- `currentUserId` - User ID getter

**UserService**
- `initialize()` - Set up auth state monitoring
- `createOrUpdateProfile(displayName, avatarUrl, isSearchable, allowEmailSearch)` - Profile management
- `getUserProfile(userId)` - Fetch profile with caching
- `getUserProfiles(userIds)` - Batch profile fetch
- `searchUsers(query)` - User search
- `updateOnlineStatus(isOnline)` - Presence update
- `updateProfileStats(friendsCount, publicRecipeCount)` - Stats update
- `isDisplayNameAvailable(displayName)` - Name availability check
- `updateFCMToken(token)` - Push notification token
- `updateNotificationSettings(enabled)` - Notification preferences
- `clearFCMToken()` - Remove push token

### Views
- `AuthView` - Login/Register screen

---

## Journey 2: Recipe Management ✅ COMPLETE

### User Flow
1. User views their recipe collection (MinaReceptView)
2. User creates recipe manually (SkrivSjalvReceptView)
3. User imports recipe from URL
4. User imports recipe from photo (OCR)
5. User imports recipe from social media
6. User edits existing recipe
7. User views recipe details
8. User shares recipe with friends
9. User deletes recipe

### Test Steps
- [x] View recipe list → shows collection ✅ (2025-11-28) - 20 recipes displayed
- [x] View recipe detail → shows full content ✅ (2025-11-28)
- [x] Create recipe manually → saves to Firebase ✅ (2025-11-28) - Bug fixed: text input scrambling
- [x] Edit recipe title → updates in Firebase ✅ (2025-11-28)
- [x] Edit recipe ingredients → updates in Firebase ✅ (2025-11-28) - Bug fixed: add items not working
- [x] Add images to recipe → uploads to Storage ✅ (2025-11-28) - Bug fixed: images disappearing
- [ ] Remove image from recipe → removes URL
- [x] Import recipe from valid URL → extracts content ✅ (2025-11-28) - Works but parser needs improvement
- [ ] Import recipe from invalid URL → shows error
- [x] Import recipe from photo → OCR extraction ✅ (2025-11-28) - Works but OCR needs improvement
- [ ] Share recipe with friend → creates share record
- [ ] Fork shared recipe → creates personal copy
- [x] Delete recipe → removes from Firebase ✅ (2025-11-28) - Bug fixed: navigation after delete

### Bugs Fixed (2025-11-28)
1. **Text input scrambling** - TextEditingController lifecycle issue in SkrivSjalvReceptView
2. **Images disappearing when editing** - Image URLs not synced to ImageManager in RecipeFormState
3. **Cannot add ingredients/instructions when editing** - Empty field not added at end when loading recipe
4. **Delete navigation bug** - popNavigation callback was empty stub in RecipeDetailActions

### Known Issues (Deferred)
- Parser improvements needed for URL and photo import (see docs/TODO_PARSER_IMPROVEMENTS.md)

### Features & Methods

**UnifiedRecipeService**
- `initialize()` - Service initialization
- `loadRecipes()` - Fetch user's recipes
- `getRecipeById(id)` - Single recipe fetch
- `createRecipe(recipe)` - Create new recipe
- `updateRecipe(recipe)` - Update existing recipe
- `deleteRecipe(id)` - Remove recipe
- `watchRecipes()` - Real-time recipe stream
- `searchRecipes(query)` - Search by title/ingredients
- `clearError()` - Error state reset

**UnifiedRecipeService.personal**
- `createRecipe(recipe)` - Personal recipe creation
- `updateRecipe(recipe)` - Personal recipe update
- `deleteRecipe(id)` - Personal recipe deletion
- `loadRecipes()` - Load personal recipes

**UnifiedRecipeService.social**
- `shareRecipeWithFriends(recipeId, friendIds)` - Friend sharing
- `shareRecipeWithGroup(recipeId, groupId)` - Group sharing
- `forkRecipe(recipeId)` - Create personal copy
- `getSharedRecipes()` - Recipes shared with user
- `getPublicRecipes()` - Discover public recipes

**UnifiedRecipeService.realtime**
- `startRealtimeSession(recipeId)` - Begin collaborative editing
- `stopRealtimeSession(recipeId)` - End collaborative editing
- `updateRecipeInFirebase(recipe)` - Real-time update
- `watchRecipe(recipeId)` - Live recipe stream
- `getActiveParticipants(recipeId)` - Current editors

**Import Services**
- `ImportManager.importFromUrl(url)` - URL recipe import
- `ImportManager.importFromPhoto(image)` - Photo import
- `ImportManager.importFromText(text)` - Text import
- `PhotoImportStrategy.extractRecipe(imageBytes)` - OCR extraction
- `UrlImportStrategy.extractRecipe(url)` - Web scraping

**OCRExtractionService**
- `extractTextFromImage(imageBytes)` - Vision API OCR
- `parseRecipeFromText(text)` - AI parsing
- `recordSuccess()` - Usage tracking
- `recordFailure()` - Error tracking

**StorageService**
- `uploadRecipeImage(file, recipeId)` - Image upload
- `deleteRecipeImage(url)` - Image deletion
- `getDownloadUrl(path)` - URL generation
- `isValidImageFile(file)` - File validation

### Views
- `MinaReceptView` - Recipe collection
- `RecipeDetailView` - Recipe detail
- `EditRecipeView` - Recipe editor
- `SkrivSjalvReceptView` - Manual recipe creation
- `LaggTillReceptView` - Add recipe menu
- `ImportViaUrlView` - URL import
- `PhotoImportView` - Photo import
- `FranSocialaMedierView` - Social media import

---

## Journey 3: Menu Planning 🔄 IN PROGRESS

### User Flow
1. User opens VeckomenyView (weekly menu tab)
2. User enters Swedish prompt (e.g., "3 middagar och 2 frukoster")
3. User generates menu → recipes categorized by meal type
4. User can regenerate individual sections
5. User saves menu with name and optional comment
6. User can share menu with friends during save
7. User loads previously saved menus
8. User exports menu ingredients to shopping list
9. User can native-share menu as text

### Test Steps

**Menu Generation**
- [ ] View empty menu state → shows prompt input + "Generera meny" button
- [ ] Enter Swedish prompt "3 middagar" → button enables
- [ ] Generate menu → shows recipes in "Middag" section
- [ ] Generate complex prompt "3 frukoster och 2 middagar" → creates multiple sections
- [ ] Regenerate single section → replaces only that section's recipes
- [ ] View recipe from menu → navigates to recipe detail
- [ ] Clear menu → returns to empty state

**Menu Persistence**
- [ ] Save menu → SaveMenuDialog opens with name/comment fields
- [ ] Save with valid name → menu saved to Firestore, success message
- [ ] Save with empty name → shows validation error
- [ ] Load menu → LoadMenuBottomSheet shows saved menus list
- [ ] Load saved menu → menu populates in view
- [ ] Delete saved menu → removes from list

**Menu Sharing**
- [ ] Native share → opens system share sheet with text format
- [ ] Social share with friends → UniversalShareDialog with friend selection
- [ ] Share with selected friends → creates share records in Firestore

**Collaborative Menu Editing** (NEW - 2025-12-01)
- [ ] Share menu with "Realtidsdelning" mode → creates RealtimeMenu in Firebase
- [ ] Friend receives invitation → shows in "Delat med mig"
- [ ] Friend accepts collaborative invitation → navigates to realtime menu view
- [ ] Both users can edit menu → changes sync in real-time
- [ ] Presence indicators → show who is currently editing

**Shopping Integration**
- [ ] Export to shopping list → shows list selector
- [ ] Select list and confirm → ingredients added to shopping list
- [ ] Navigate to shopping list → shows menu items

### Features & Methods

**MenuViewModel** (MVVM coordinator)
- `generateMenu(prompt)` - Generate menu from Swedish prompt
- `regenerateSection(sectionName)` - Regenerate single meal category
- `saveMenuWithNameAndComment(name, comment, friendIds)` - Save to Firestore
- `loadSavedMenu(menuKey)` - Load from Firestore
- `deleteSavedMenu(menuKey)` - Delete from Firestore
- `refreshSavedMenus()` - Reload saved menu list
- `clearMenu()` - Clear current menu state

**MenuStorage** (Firestore persistence)
- `saveMenu(menuName, comment, menu, lastPrompt, totalRecipeCount)` - Save menu
- `loadMenuByKey(menuKey)` - Load single menu
- `loadUserMenus()` - Load all user's menus
- `deleteMenuByKey(menuKey)` - Delete menu

**MenuSocialManager** (Social sharing)
- `shareMenuWithFriends(menuKey, friendIds, menuSnapshot, menuName, message)` - Share with friends
- `loadImportedMenus()` - Load menus shared with user

**MenuService** (NLP + generation)
- `generateMenuFromPrompt(prompt, recipes)` - Parse Swedish + select recipes
- Supports: "tre middagar", "3 frukoster och 2 luncher", complex syntax

**MenuGenerator** (Recipe selection)
- `generateMenuFromPrompt(prompt, recipes)` - Coordinate generation
- Random recipe selection per meal type category

### Views
- `VeckomenyView` - Main menu planner with prompt input
- `SaveMenuDialog` - Save dialog with name, comment, friend sharing
- `LoadMenuBottomSheet` - Saved menus list with load/delete

### Data Model
- Firestore `menus` collection: User-owned saved menus
- Firestore `sharedMenus` collection: Shared menu documents
- Firestore `userSharedMenus/{userId}/receivedMenus`: Incoming shares

---

## Journey 4: Shopping Lists

### User Flow
1. User views personal shopping list
2. User creates new shopping list
3. User adds items manually
4. User adds items from recipe
5. User checks off items as purchased
6. User creates collaborative list with friends
7. User manages list members
8. User exports list as text

### Test Steps
- [ ] View empty shopping list → shows empty state
- [ ] Create personal list → saves to Firebase
- [ ] Add item manually → appears in list
- [ ] Add items from recipe → batch import
- [ ] Check item → marks as completed
- [ ] Uncheck item → marks as pending
- [ ] Delete item → removes from list
- [ ] Create collaborative list → shares with members
- [ ] Add member to list → sends invitation
- [ ] Remove member from list → revokes access
- [ ] Real-time sync → see collaborator changes
- [ ] Export list → generates text format

### Features & Methods

**UnifiedShoppingService**
- `initialize()` - Service setup
- `loadLists()` - Fetch all lists
- `createPersonalList(name, items)` - Personal list creation
- `updateList(list)` - Update list
- `deleteList(listId)` - Remove list
- `setActiveList(listId)` - Select current list
- `exportListAsText(listId)` - Text export
- `lists` - All lists getter
- `personalLists` - Personal lists only
- `collaborativeLists` - Shared lists only
- `activeList` - Current list

**UnifiedShoppingService.personal**
- `createList(name)` - Create personal list
- `addItem(listId, item)` - Add single item
- `addItems(listId, items)` - Add multiple items
- `updateItem(listId, item)` - Update item
- `removeItem(listId, itemId)` - Delete item
- `toggleItemChecked(listId, itemId)` - Check/uncheck

**UnifiedShoppingService.collaborative**
- `createCollaborativeList(name, memberIds)` - Create shared list
- `addMember(listId, userId)` - Add collaborator
- `removeMember(listId, userId)` - Remove collaborator
- `leaveList(listId)` - Leave shared list
- `getMembers(listId)` - List collaborators

**UnifiedShoppingService.share**
- `shareListWithFriend(listId, friendId)` - Direct sharing
- `generateShareLink(listId)` - Create invite link
- `acceptShareInvitation(invitationId)` - Join shared list

### Views
- `UnifiedShoppingView` - Shopping list manager
- `CollaborativeShoppingView` - Shared list view
- `CreateSharedShoppingListView` - List creation

---

## Journey 5: Social & Friends

### User Flow
1. User searches for friends
2. User sends friend request
3. User accepts/rejects incoming requests
4. User views friend profile
5. User creates friend group/category
6. User blocks/unblocks user
7. User shares content with friends
8. User views shared content

### Test Steps
- [ ] Search for user by name → shows results
- [ ] Search for user by email → shows results (if allowed)
- [ ] Send friend request → creates pending request
- [ ] Cancel sent request → removes request
- [ ] Accept friend request → creates friendship
- [ ] Reject friend request → removes request
- [ ] View friend profile → shows public info
- [ ] Create friend category → saves category
- [ ] Add friend to category → updates relationships
- [ ] Block user → prevents interactions
- [ ] Unblock user → restores visibility
- [x] View shared recipes → shows SharedWithMeView ✅ (2025-12-02) Issue #014 fixed
- [x] Shared content loads automatically → no manual refresh needed ✅ (2025-12-02)
- [ ] Accept shared recipe → saves to collection

### Bugs Fixed (2025-12-02) - Issue #014

**Problem**: Shared content (menus, recipes) not visible to recipients in "Delat med mig" view.

**Root Causes & Fixes**:
1. **Firestore query blocked by security rules** - `whereIn` is a LIST operation blocked for non-owners
   - Fix: Replaced with individual `get()` calls in `base_shared_content_repository.dart:744-752`

2. **Race condition in ViewModel initialization** - Constructor called `_initialize()` before `currentUserId` was available
   - Fix: Removed auto-init from `BaseSharedContentViewModel` constructor
   - Fix: Updated `SharedContentCoordinatorViewModel.initialize()` to explicitly call `loadContent()` on each ViewModel

3. **Tab bar overflow on mobile** - Tab content too wide for screen
   - Fix: Added `isScrollable: true` to `SharedContentTabBar`

### Features & Methods

**UnifiedFriendsService**
- `initialize()` - Service setup
- `friends` - Friends list getter
- `incomingRequests` - Pending requests received
- `outgoingRequests` - Pending requests sent
- `categoriesList` - Friend categories
- `blockedUsers` - Blocked user IDs

**UnifiedFriendsService.management**
- `sendFriendRequest(userId, message)` - Send request
- `cancelFriendRequest(requestId)` - Cancel sent request
- `acceptFriendRequest(requestId)` - Accept request
- `rejectFriendRequest(requestId)` - Decline request
- `removeFriend(friendId)` - Unfriend
- `blockUser(userId)` - Block user
- `unblockUser(userId)` - Unblock user
- `isFriend(userId)` - Check friendship
- `isBlocked(userId)` - Check block status

**UnifiedFriendsService.categories**
- `createCategory(name, friendIds)` - Create category
- `updateCategory(categoryId, name, friendIds)` - Update category
- `deleteCategory(categoryId)` - Remove category
- `addFriendToCategory(friendId, categoryId)` - Assign friend
- `removeFriendFromCategory(friendId, categoryId)` - Unassign friend

**UnifiedFriendsService.invitations**
- `sendGroupInvitation(groupId, userId)` - Invite to group
- `acceptGroupInvitation(invitationId)` - Accept group invite
- `rejectGroupInvitation(invitationId)` - Decline group invite
- `cancelGroupInvitation(invitationId)` - Cancel sent invite

**UnifiedFriendsService.groupSharing**
- `shareRecipeWithGroup(recipeId, groupId)` - Share recipe
- `shareMenuWithGroup(menuId, groupId)` - Share menu
- `shareListWithGroup(listId, groupId)` - Share shopping list
- `getGroupSharedContent(groupId)` - Group's shared items

### Views
- `FriendsListView` - Friends management
- `FriendProfileView` - Friend details
- `FriendRequestsView` - Request management
- `SharedWithMeView` - Received shares
- `GroupDetailView` - Group management
- `AddMembersToGroupView` - Member addition
- `DiscoveryDashboardView` - Social discovery

---

## Journey 6: Messaging

### User Flow
1. User views conversations list
2. User starts direct message with friend
3. User creates group conversation
4. User sends text message
5. User sends recipe/menu/list share
6. User edits/deletes message
7. User pins/archives conversation
8. User mutes notifications

### Test Steps
- [ ] View conversations → shows list
- [ ] Start DM with friend → creates conversation
- [ ] Create group chat → creates group conversation
- [ ] Send text message → appears in chat
- [ ] Send recipe share → includes recipe card
- [ ] Edit sent message → updates content
- [ ] Delete message → removes from chat
- [ ] Pin conversation → moves to top
- [ ] Archive conversation → hides from list
- [ ] Mute conversation → disables notifications
- [ ] Typing indicator → shows when typing
- [ ] Read status → marks as read

### Features & Methods

**MessagingService**
- `getMyConversations()` - Stream of user's conversations
- `startDirectConversation(otherUserId, otherUserDisplayName)` - Start DM
- `createGroupConversation(participantIds, title)` - Create group
- `getConversation(conversationId)` - Get conversation details
- `getMessages(conversationId)` - Message stream

**MessagingService (sending operations)**
- `sendMessage(conversationId, content, type)` - Send message
- `sendRecipeShare(conversationId, recipeId)` - Share recipe
- `sendMenuShare(conversationId, menuId)` - Share menu
- `sendListShare(conversationId, listId)` - Share shopping list

**MessagingService (conversation actions)**
- `pinConversation(conversationId)` - Pin to top
- `unpinConversation(conversationId)` - Unpin
- `archiveConversation(conversationId)` - Archive
- `unarchiveConversation(conversationId)` - Restore
- `muteConversation(conversationId)` - Disable notifications
- `unmuteConversation(conversationId)` - Enable notifications
- `leaveConversation(conversationId)` - Leave group

**MessagingService (message management)**
- `editMessage(conversationId, messageId, newContent)` - Edit message
- `deleteMessage(conversationId, messageId)` - Delete message
- `markAsRead(conversationId)` - Mark conversation read
- `setTypingStatus(conversationId, isTyping)` - Typing indicator

**PresenceService**
- `setOnline()` - Set user online
- `setOffline()` - Set user offline
- `startTyping(conversationId)` - Start typing indicator
- `stopTyping(conversationId)` - Stop typing indicator
- `isTypingIn(conversationId)` - Check typing status
- `watchOnlineStatus(userId)` - Online status stream

### Views
- `ConversationsListView` - Conversation list
- `ChatViewFacade` - Chat interface
- `CreateGroupConversationView` - Group creation

---

## Journey 7: GDPR & Account

### User Flow
1. User manages consent preferences
2. User exports all personal data
3. User views privacy policy
4. User requests account deletion
5. User completes full account deletion

### Test Steps
- [ ] View consent settings → shows current consents
- [ ] Update consent preferences → saves to Firebase
- [ ] Revoke optional consents → updates records
- [ ] Export data → generates JSON file
- [ ] View exported data → contains all user data
- [ ] Request account deletion → confirms intent
- [ ] Complete deletion → removes all data

### Features & Methods

**ConsentService**
- `getUserConsent()` - Get current consent
- `saveConsent(purposes)` - Save consent choices
- `hasConsent(purpose)` - Check specific consent
- `needsConsentRenewal()` - Version change check
- `hasRequiredConsents()` - Minimum consents check
- `revokeOptionalConsents()` - Reset to defaults
- `getConsentHistory()` - Audit trail

**DataExportService**
- `exportUserData()` - Complete JSON export
- Includes: profile, recipes, friends, messages, shopping lists, menus, comments, ratings, activity, shared content, audit logs, consent records, notifications

**AccountDeletionService**
- `deleteUserAccount()` - Complete account removal
- `deleteUserContent(userId)` - Content deletion
- `deleteUserSocialData(userId)` - Social data deletion
- `deleteUserProfile(userId)` - Profile deletion

### Views
- `ConsentManagementView` - Consent settings
- `DataExportView` - Data export
- `PrivacyPolicyView` - Privacy information

---

## Journey 8: Offline & Sync

### User Flow
1. User loses network connection
2. User continues to view cached recipes
3. User makes changes while offline
4. User regains connection
5. Changes sync automatically
6. Conflicts are resolved

### Test Steps
- [ ] Go offline → app continues working
- [ ] View cached recipes → shows local data
- [ ] Create recipe offline → queues for sync
- [ ] Update recipe offline → queues for sync
- [ ] Go online → syncs pending changes
- [ ] Conflict resolution → handles merge conflicts
- [ ] Real-time updates resume → live sync active

### Features & Methods

**OfflineService**
- `initialize()` - Set up offline storage
- `setCurrentUser(userId)` - User context
- `queueOperation(operation)` - Queue for sync
- `syncPendingOperations()` - Process queue
- `getCachedRecipes()` - Local recipe data
- `getCachedShoppingLists()` - Local list data

**ConnectivityMonitoringService**
- `startMonitoring()` - Begin connection watch
- `stopMonitoring()` - Stop monitoring
- `isConnected` - Current status
- `connectionStream` - Status changes stream

**RealtimeSyncService**
- `addListener(callback)` - Register for updates
- `removeListener(callback)` - Unregister
- `watchResource(resourceId)` - Start watching
- `unwatchResource(resourceId)` - Stop watching
- `refreshAllResources()` - Force refresh
- `isResourceWatched(resourceId)` - Check watch status

**ConflictResolutionModule**
- `resolveConflict(local, remote)` - Merge strategy
- `detectConflict(local, remote)` - Conflict detection
- `getConflictResolutionStrategy()` - Current strategy

### Views
- Offline indicators in all views
- Sync status badges

---

## Permission & Security Testing

### Features & Methods

**PermissionService**
- `currentUserId` - Authenticated user
- `currentUser` - Firebase user
- `isOwner(ownerId)` - Ownership check
- `canViewRecipe(recipeId)` - View permission
- `canEditRecipe(recipeId)` - Edit permission
- `canInviteToRecipe(recipeId)` - Invite permission
- `isRecipeOwner(recipeId)` - Recipe ownership
- `canViewShoppingList(listId)` - List view permission
- `canEditShoppingList(listId)` - List edit permission
- `canManageShoppingList(listId)` - List admin permission
- `canDeleteShoppingList(listId)` - List delete permission
- `isShoppingListOwner(listId)` - List ownership
- `canEditMenu(menuId)` - Menu edit permission
- `isGroupAdmin(groupId)` - Group admin check
- `canDeleteGroup(groupId)` - Group delete permission
- `canInviteToGroup(groupId)` - Group invite permission
- `hasPermission(resourceId, permission)` - Generic check

---

## Analytics Testing

### Features & Methods

**AnalyticsService**
- `setConsentService(consentService)` - Link consent
- `logLogin(method)` - Track login
- `logSignUp(method)` - Track registration
- `logLogout()` - Track logout
- `logRecipeCreated(recipeId)` - Track recipe creation
- `logRecipeViewed(recipeId)` - Track recipe view
- `logRecipeShared(recipeId)` - Track recipe share
- `logMenuGenerated(prompt)` - Track AI menu
- `logEvent(name, parameters)` - Custom events
- `setUserProperty(name, value)` - User properties

---

## Service Summary

| Service | Methods | Category |
|---------|---------|----------|
| AuthService | 10 | Core |
| UserService | 15 | Core |
| UnifiedRecipeService | 25+ | Core |
| UnifiedMenuService | 15+ | Core |
| UnifiedShoppingService | 25+ | Core |
| UnifiedFriendsService | 30+ | Social |
| MessagingService | 20+ | Social |
| ConsentService | 7 | GDPR |
| DataExportService | 1 | GDPR |
| AccountDeletionService | 4 | GDPR |
| PermissionService | 18 | Security |
| AnalyticsService | 12 | Analytics |
| OfflineService | 6 | Infrastructure |
| PresenceService | 6 | Infrastructure |
| OCRExtractionService | 4 | Import |
| StorageService | 4 | Infrastructure |

---

## View Summary

| Category | Views |
|----------|-------|
| Auth | AuthView |
| Recipe | MinaReceptView, RecipeDetailView, EditRecipeView, SkrivSjalvReceptView, LaggTillReceptView |
| Import | ImportViaUrlView, PhotoImportView, FranSocialaMedierView, FileImportView |
| Menu | VeckomenyView, MenuPreviewView |
| Shopping | UnifiedShoppingView, CollaborativeShoppingView, CreateSharedShoppingListView |
| Social | FriendsListView, FriendProfileView, FriendRequestsView, SharedWithMeView, GroupDetailView, AddMembersToGroupView, DiscoveryDashboardView |
| Messaging | ConversationsListView, ChatViewFacade, CreateGroupConversationView |
| Account | ConsentManagementView, DataExportView, PrivacyPolicyView, UserProfileEditView |
