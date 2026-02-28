---
description: >
  CRITICAL: Prevents mixing UserService and PermissionService data sources.
  Use when accessing user data, settings, avatars, authentication state, or
  debugging 'settings not persisting' issues. UserService for profile data,
  PermissionService for auth checks only.
---

# Data Source Enforcer

> CRITICAL: Prevent mixing UserService and PermissionService.

## Core Rule

**Two services, two different purposes:**

| Service | Access Pattern | Data |
|---------|---------------|------|
| `userService.currentUserProfile` | Complete user data | Settings, avatar, social, preferences |
| `permissionService.currentUserId` | Auth/permission checks | uid, email, basic auth only |

Both accessed via `ServiceLocator.get<T>()`:

```dart
final userService = ServiceLocator.get<UserService>();
final permissionService = ServiceLocator.get<PermissionService>();
```

## Critical Errors

### ❌ Settings from PermissionService

```dart
// WRONG - PermissionService does NOT have settings
final permService = ServiceLocator.get<PermissionService>();
final settings = permService.currentUser.settings.darkMode;
```

### ✅ Settings from UserService

```dart
// CORRECT - UserService has the complete profile
final userService = ServiceLocator.get<UserService>();
final darkMode = userService.currentUserProfile?.settings.darkMode;
```

---

### ❌ Auth check via UserService

```dart
// WASTEFUL - loads entire profile just to check auth
final userService = ServiceLocator.get<UserService>();
if (userService.currentUserProfile != null) { ... }
```

### ✅ Auth check via PermissionService

```dart
// CORRECT - lightweight auth check
final permService = ServiceLocator.get<PermissionService>();
final userId = permService.currentUserId;
if (userId != null) { ... }
```

---

### ❌ Mixing in the same class

```dart
class MyService {
  // WRONG - mixes data sources inconsistently
  Future<void> doSomething() async {
    final userId = ServiceLocator.get<PermissionService>().currentUserId;
    final settings = ServiceLocator.get<UserService>().currentUserProfile?.settings;
  }
}
```

### ✅ Consistent usage

```dart
class MyService {
  // CORRECT - use ONE source consistently per concern
  Future<void> doSomething() async {
    final userService = ServiceLocator.get<UserService>();
    final profile = userService.currentUserProfile;
    final userId = profile?.id;
    final settings = profile?.settings;
  }
}
```

## Decision Table

| Need | Use |
|------|-----|
| Display username/avatar | `UserService.currentUserProfile` |
| Save/read settings | `UserService.currentUserProfile` |
| Check if authenticated | `PermissionService.currentUserId` |
| Get userId for queries | `PermissionService.currentUserId` |
| Validate permissions | `PermissionService` |
| Social features (friends, groups) | `UserService` |

## Consequence: Settings Not Persisting

If you mix these:
1. Read settings from `UserService`
2. Save settings via `PermissionService.currentUser`
3. Settings are NEVER saved (wrong object)

## Warning Signals

```dart
// Search for these patterns:
permissionService.*settings    // WRONG
permissionService.*avatar      // WRONG
permissionService.*preferences // WRONG
```
