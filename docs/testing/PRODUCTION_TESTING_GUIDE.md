# 🧪 Production Testing Guide - Butlery App

**Purpose**: Systematic testing of all production features to identify bugs and non-working functionality  
**Last Updated**: January 2025  
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

#### 1.1 Authentication System
- [ ] User registration with email
- [ ] Login with email/password
- [ ] Password reset flow
- [ ] Logout functionality
- [ ] Session persistence
- [ ] Auto-login on app restart
- [ ] Account deletion

#### 1.2 Recipe Management
- [ ] Create new recipe manually
- [ ] Edit existing recipe
- [ ] Delete recipe
- [ ] View recipe details
- [x] Recipe image upload ✅
- [ ] Ingredient management
- [ ] Instructions editing
- [ ] Portion scaling
- [ ] Recipe categorization
- [ ] Recipe search

#### 1.3 Import Features
- [ ] URL import from recipe websites
- [ ] Photo import with text extraction
- [ ] Manual text import
- [ ] Archive/backup import
- [ ] Social media import
- [ ] Import history
- [ ] Import error handling

### Phase 2: Social Features (Priority 2)

#### 2.1 Friends System
- [ ] Send friend requests
- [ ] Accept/reject requests
- [ ] View friends list
- [ ] Remove friends
- [ ] Block/unblock users
- [ ] Friend categories
- [ ] Friend search

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

### Week 1: Core Features
**Day 1-2**: Authentication & User Management
- Test all auth flows
- Document any issues with login/signup
- Verify session management

**Day 3-4**: Recipe CRUD & Import
- Test recipe creation/editing
- Test all import methods
- Verify data persistence

**Day 5**: Documentation & Review
- Update BUG_TRACKER.md
- Update FEATURE_STATUS.md
- Prioritize findings

### Week 2: Social & Collaborative
**Day 1-2**: Friends & Groups
- Test social connections
- Verify group functionality
- Test permissions

**Day 3-4**: Sharing & Collaboration
- Test recipe sharing
- Test collaborative features
- Verify real-time sync

**Day 5**: Integration Testing
- Test feature interactions
- Document integration issues
- Update tracking documents

### Week 3: Advanced Features
**Day 1-2**: Menu & Shopping
- Test menu planning
- Test shopping lists
- Verify generation features

**Day 3-4**: Messaging & Notifications
- Test communication features
- Verify notification delivery
- Test offline behavior

**Day 5**: Final Report
- Generate comprehensive report
- Create fix roadmap
- Prioritize improvements

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