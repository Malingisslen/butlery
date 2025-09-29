# 🧪 Production Testing Guide - Butlery App

**Purpose**: Systematic testing of all production features to identify bugs and non-working functionality  
**Last Updated**: August 31, 2025  
**Status**: Active Testing Phase

## 📋 Quick Reference

- **Bug Tracker**: [BUG_TRACKER.md](./BUG_TRACKER.md)
- **Feature Status**: [FEATURE_STATUS.md](./FEATURE_STATUS.md)
- **Test Results**: [PRODUCTION_TEST_RESULTS.md](./PRODUCTION_TEST_RESULTS.md)

## 🎯 Testing Objectives

1. **Identify all bugs** in production code
2. **Document non-working features** with severity levels
3. **Verify feature completion** against requirements
4. **Create fix roadmap** based on priority

## 🛠️ Testing Environment Setup

### Running the App for Testing
```bash
# Run on connected device/emulator
cmd.exe /c "flutter run"

# Run with verbose logging
cmd.exe /c "flutter run -v"

# Run specific platform
cmd.exe /c "flutter run -d chrome"    # Web
cmd.exe /c "flutter run -d android"   # Android
```

## 📊 Testing Methodology

### 1. Feature Testing Approach
For each feature area:
- **Happy Path**: Normal expected usage
- **Edge Cases**: Boundary conditions
- **Error Cases**: Invalid inputs, network failures
- **Permissions**: Unauthorized access attempts
- **Performance**: Large datasets, slow networks

### 2. Bug Classification

| Severity | Description | Example |
|----------|-------------|---------|
| **🔴 Critical** | App crashes, data loss, security issues | Login completely broken |
| **🟠 High** | Major feature broken, blocks user flow | Cannot create recipes |
| **🟡 Medium** | Feature partially works, has workaround | Import works but loses formatting |
| **🟢 Low** | Minor issues, cosmetic problems | Text alignment issues |

### 3. Testing Checklist Template

```markdown
## Feature: [Feature Name]
**Tester**: [Name]
**Date**: [Date]
**Version**: [App Version]

### Test Cases
- [ ] Happy path scenario
- [ ] Empty/null data handling
- [ ] Large data sets (100+ items)
- [ ] Network disconnection
- [ ] Permission denied scenarios
- [ ] Concurrent user actions
- [ ] Cross-platform consistency

### Results
- **Working**: ✅/❌
- **Issues Found**: [Count]
- **Critical Bugs**: [List bug IDs]
```

## 🔍 Feature Areas to Test

### Phase 1: Core Features (Priority 1)

#### 1.1 Authentication System ✅ COMPLETE
- [x] User registration with email ✅
- [x] Login with email/password ✅
- [x] Password reset flow ✅
- [x] Logout functionality ✅
- [x] Session persistence ✅
- [x] Auto-login on app restart ✅
- [x] Account deletion ✅

#### 1.2 Recipe Management ✅ CORE COMPLETE
- [x] Create new recipe manually ✅
- [x] Edit existing recipe ✅
- [x] Delete recipe ✅
- [x] View recipe details ✅
- [x] Recipe image upload ✅
- [x] Ingredient management ✅
- [x] Instructions editing ✅
- [x] Portion scaling ✅
- [x] Recipe categorization ✅
- [x] Recipe search ⚠️ (UI overflow issue but functional)

#### 1.3 Import Features ✅ MOSTLY COMPLETE
- [x] URL import from recipe websites ✅
- [x] Photo import with text extraction ✅
- [x] Manual text import ⚠️ (minor parser improvements needed)
- [ ] Archive/backup import ❓ Not tested
- [ ] Social media import ❓ Not tested
- [ ] Import history ❓ Not tested
- [x] Import error handling ✅

### Phase 2: Social Features (Priority 2)

#### 2.1 Friends System ❌ BLOCKED BY BUG-042
- [ ] Send friend requests ❌ (BUG-042 - High priority blocker)
- [ ] Accept/reject requests 🚫 (Blocked by BUG-042)
- [ ] View friends list 🚫 (Blocked by BUG-042)
- [ ] Remove friends 🚫 (Blocked by BUG-042)
- [ ] Block/unblock users ❓ Not tested
- [ ] Friend categories ❓ Not tested
- [x] Friend search ⚠️ (finds users but persistent error message)

#### 2.2 Groups
- [ ] Create group
- [ ] Edit group details
- [ ] Add/remove members
- [ ] Group permissions
- [ ] Delete group
- [ ] Leave group
- [ ] Group invitations

#### 2.3 Sharing
- [ ] Share recipe with friends
- [ ] Share to groups
- [ ] Public sharing links
- [ ] Share permissions
- [ ] Receive shared content
- [ ] Share history

### Phase 3: Collaborative Features (Priority 3)

#### 3.1 Shopping Lists
- [ ] Create shopping list
- [ ] Add items manually
- [ ] Generate from recipes
- [ ] Generate from menu
- [ ] Check off items
- [ ] Delete items
- [ ] Share lists
- [ ] Collaborative editing
- [ ] List templates

#### 3.2 Menu Planning
- [ ] Create weekly menu
- [ ] Add recipes to days
- [ ] Generate shopping list
- [ ] Save menu template
- [ ] Load menu template
- [ ] Share menu
- [ ] Collaborative planning

#### 3.3 Real-time Features
- [ ] Live recipe editing
- [ ] Presence indicators
- [ ] Conflict resolution
- [ ] Real-time sync
- [ ] Offline mode
- [ ] Sync on reconnection

### Phase 4: Communication (Priority 4)

#### 4.1 Comments & Ratings
- [ ] Add comment to recipe
- [ ] Edit own comment
- [ ] Delete own comment
- [ ] Rate recipe (1-5 stars)
- [ ] Update rating
- [ ] Like/unlike comments
- [ ] Comment notifications

#### 4.2 Messaging
- [ ] Start conversation
- [ ] Send message
- [ ] Receive message
- [ ] Delete conversation
- [ ] Message notifications
- [ ] Typing indicators
- [ ] Read receipts

#### 4.3 Notifications
- [ ] Push notifications
- [ ] In-app notifications
- [ ] Notification settings
- [ ] Clear notifications
- [ ] Notification history

## 📝 Bug Reporting Format

When you find a bug, document it in [BUG_TRACKER.md](./BUG_TRACKER.md) using this format:

```markdown
## BUG-[NUMBER]: [Short Description]

**Severity**: Critical/High/Medium/Low
**Feature Area**: [e.g., Recipe Import]
**View**: [e.g., ImportViaUrlView]
**ViewModel**: [e.g., UrlImportViewModel]

### Steps to Reproduce
1. Navigate to [screen]
2. Perform [action]
3. Observe [result]

### Expected Behavior
[What should happen]

### Actual Behavior
[What actually happens]

### Error Details
```
[Any error messages or stack traces]
```

### Screenshots
[If applicable]

### Workaround
[If available]

### Environment
- Platform: [iOS/Android/Web]
- Flutter Version: [version]
- Device: [device model]

### Fix Status
- [ ] Not Started
- [ ] In Progress
- [ ] Fixed
- [ ] Verified
```

## 🚀 Testing Execution Plan

### ✅ Phase 1 COMPLETED: Core Features
**✅ Authentication & User Management** - 100% Complete
- ✅ All auth flows tested and working
- ✅ All authentication bugs fixed (BUG-001 through BUG-015)
- ✅ Session management verified

**✅ Recipe CRUD & Import** - 85% Complete
- ✅ Recipe creation/editing fully functional
- ✅ URL and Photo import fully restored
- ✅ Data persistence verified
- ⚠️ Minor UI bugs remain (non-blocking)

**📋 Current Priority**: Fix BUG-042 (Friend requests) to unblock social features

### 🔄 Phase 2 CURRENT: Social & Collaborative
**🚫 Friends System** - BLOCKED by BUG-042
- ❌ Cannot send friend requests (high priority fix needed)
- ✅ Friend search infrastructure working
- ⏸️ All other friend features blocked until BUG-042 resolved

**❓ Groups & Sharing** - Ready for Testing
- ⏳ Groups functionality untested but likely working
- ⏳ Recipe sharing ready for testing
- ⏳ Collaborative features need verification

**📋 Next Actions**: Fix BUG-042 then proceed with social feature testing

### ⏳ Phase 3 FUTURE: Advanced Features
**Shopping Lists & Menu Planning** - Ready for Testing
- ⏳ Infrastructure appears complete
- ⏳ Generation features need verification
- 📋 High priority after social features working

**Communication Features** - Ready for Testing  
- ⏳ Messaging system infrastructure complete
- ⏳ Notification delivery needs testing
- ⏳ FCM integration needs verification

**🎯 Success Criteria Updated**: 
1. ✅ Core features (Auth + Recipes + Import) - ACHIEVED
2. 🔄 Social features (blocked by BUG-042)
3. ⏳ Advanced features (shopping, messaging)

## 🎨 UI/UX Testing Points

### Visual Consistency
- [ ] Theme consistency across screens
- [ ] Responsive layout on different screen sizes
- [ ] Dark mode support (if applicable)
- [ ] Loading states
- [ ] Error states
- [ ] Empty states

### Navigation
- [ ] Back button behavior
- [ ] Deep linking
- [ ] Tab navigation
- [ ] Drawer navigation
- [ ] Route transitions

### Accessibility
- [ ] Screen reader support
- [ ] Touch target sizes
- [ ] Color contrast
- [ ] Font scaling
- [ ] Keyboard navigation (web)

## 📱 Platform-Specific Testing

### Android
- [ ] Back button handling
- [ ] App lifecycle management
- [ ] Permission requests
- [ ] Deep linking
- [ ] Push notifications

### iOS
- [ ] Swipe gestures
- [ ] Safe area handling
- [ ] Permission requests
- [ ] Push notifications
- [ ] App Store guidelines compliance

### Web
- [ ] Browser compatibility
- [ ] Responsive design
- [ ] Keyboard shortcuts
- [ ] URL routing
- [ ] PWA features

## 🛒 Shopping List Member Management Testing

### Overview
Comprehensive testing of collaborative shopping list features, including member management, permission systems, and real-time synchronization.

### Test Environment Requirements
- **Minimum 2 test users** for collaboration testing
- **Firebase Firestore** access for data verification
- **Real-time testing** for permission changes

### Member Management Dialog Testing

#### Test Case 1: Access Member Management
**Prerequisites**: User must be admin of a collaborative shopping list

1. Navigate to shopping list view
2. Select collaborative list (shows "Delad" indicator)
3. Tap sharing status dialog/button
4. Tap "Hantera delning" button
5. **Expected**: Member management dialog opens showing current members

**Verification Points**:
- Dialog displays all current members
- Admin users have admin badge/indicator
- Current user permissions are visible
- Friend search functionality is available

#### Test Case 2: Permission Changes
**Prerequisites**: Admin user with collaborative list having multiple members

1. Open member management dialog
2. Select a member with "edit" permission
3. Change permission to "view" via dropdown
4. Tap update/save
5. **Expected**: Success message appears
6. Close dialog and reopen
7. **Expected**: Permission change persists

**Verification Points**:
- Local UI updates immediately
- Firebase persistence confirmed on reopen
- No error messages or failed operations
- Member can no longer edit when tested with their account

#### Test Case 3: Member Removal
**Prerequisites**: Admin user with collaborative list having removable members

1. Open member management dialog
2. Locate member to remove (not list owner)
3. Tap remove/delete button for member
4. Confirm removal in confirmation dialog
5. **Expected**: Member removed from list
6. Verify member no longer has access to list

**Verification Points**:
- Member disappears from member list immediately
- Removed member can no longer access the collaborative list
- Firebase memberPermissions updated correctly
- No orphaned data or broken references

#### Test Case 4: Friend Addition
**Prerequisites**: Admin user with friends who aren't members of current list

1. Open member management dialog
2. Use friend search functionality
3. Search for friend not currently a member
4. Select friend from search results
5. Choose permission level (view/edit/admin)
6. Add friend to collaborative list
7. **Expected**: Friend added with correct permissions

**Verification Points**:
- Friend search works correctly
- Only non-member friends appear in search
- Permission selection works
- Friend receives access to collaborative list immediately
- Added friend appears in member list

### Real-time Synchronization Testing

#### Test Case 5: Multi-User Permission Testing
**Prerequisites**: 2 active users with access to same collaborative list

**User A (Admin)**:
1. Open member management dialog
2. Change User B's permission from "edit" to "view"
3. Save changes

**User B (Member)**:
1. Attempt to add item to shopping list
2. **Expected**: Permission denied or UI prevents action
3. Verify UI reflects new permission level

**Verification Points**:
- Permission changes reflect immediately or within seconds
- User B cannot perform admin/edit actions after downgrade
- UI adapts to new permission level
- No error messages for legitimate actions

### Error Handling Testing

#### Test Case 6: Network Failure Scenarios
1. Start permission change operation
2. Disconnect from internet mid-operation
3. **Expected**: Appropriate error message
4. Reconnect to internet
5. Retry operation
6. **Expected**: Operation completes successfully

#### Test Case 7: Invalid State Recovery
1. Force-close app during member management operation
2. Reopen app and navigate to collaborative list
3. **Expected**: Data integrity maintained
4. No corrupted member permissions
5. No missing or duplicate members

### Code Quality Verification

#### Test Case 8: Flutter Analyze Compliance
```bash
# Verify zero analyze issues
cmd.exe /c "flutter analyze"
# Expected: "No issues found!"
```

**Verification Points**:
- Zero const constructor warnings
- No deprecated API usage
- No BuildContext async gaps
- No debug print statements in production
- Proper error handling patterns

## 🔧 Debugging Tools

### Logging
```dart
// Enable verbose logging
import 'package:flutter/foundation.dart';
if (kDebugMode) {
  print('Debug: $message');
}
```

### Network Monitoring
- Use Chrome DevTools Network tab
- Check Firestore operations in Firebase Console
- Monitor API calls in Flutter Inspector

### Performance
```bash
# Profile mode for performance testing
cmd.exe /c "flutter run --profile"

# Check widget rebuilds
cmd.exe /c "flutter run --track-widget-creation"
```

## 📈 Progress Tracking

Update daily in [PRODUCTION_TEST_RESULTS.md](./PRODUCTION_TEST_RESULTS.md):

| Date | Feature Area | Tests Run | Bugs Found | Status |
|------|-------------|-----------|------------|--------|
| [Date] | [Area] | [Count] | [Count] | ✅/🔄/❌ |

## 🎯 Success Criteria

Testing is complete when:
1. ✅ All feature areas tested
2. ✅ All bugs documented with reproduction steps
3. ✅ Feature completion status verified
4. ✅ Fix roadmap created with priorities
5. ✅ Critical bugs have workarounds documented
6. ✅ Test results summarized in final report

## 🔗 Related Documents

- [BUG_TRACKER.md](./BUG_TRACKER.md) - All bugs found
- [FEATURE_STATUS.md](./FEATURE_STATUS.md) - Feature completion matrix
- [PRODUCTION_TEST_RESULTS.md](./PRODUCTION_TEST_RESULTS.md) - Daily test results
- [FIX_ROADMAP.md](./FIX_ROADMAP.md) - Prioritized fix plan