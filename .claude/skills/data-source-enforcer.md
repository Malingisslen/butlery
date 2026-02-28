---
description: >
  CRITICAL: Prevents mixing UserService and PermissionService data sources.
  Use when accessing user data, settings, avatars, authentication state, or
  debugging 'settings not persisting' issues. UserService for profile data,
  PermissionService for auth checks only.
---

# Data Source Enforcer

> CRITICAL: Prevent mixing UserService and PermissionService.

## Grundregel

**Två tjänster, två olika syften:**

| Tjänst | Användning | Data |
|--------|------------|------|
| `UserService.currentUserProfile` | Komplett användardata | Settings, avatar, social, preferences |
| `PermissionService.currentUser` | Auth/permission checks | Endast uid, email, basic auth |

## Kritiska Fel

### ❌ Settings från PermissionService

```dart
// FEL - PermissionService har INTE settings
final darkMode = PermissionService.currentUser.settings.darkMode;
```

### ✅ Settings från UserService

```dart
// RÄTT - UserService har komplett profil
final darkMode = UserService.currentUserProfile.settings.darkMode;
```

---

### ❌ Permission-check med UserService

```dart
// ONÖDIGT - UserService är för tung för enkel auth-check
if (UserService.currentUserProfile != null) {
  // Laddar hela profilen bara för att kolla auth
}
```

### ✅ Permission-check med PermissionService

```dart
// RÄTT - Lätt auth-check
if (PermissionService.isAuthenticated) {
  // Snabb check utan att ladda profil
}
```

---

### ❌ Blanda i samma fil

```dart
class MyService {
  // FEL - Blandar datakällor
  Future<void> doSomething() async {
    final userId = PermissionService.currentUserId;
    final settings = UserService.currentUserProfile.settings; // Inkonsekvent
  }
}
```

### ✅ Konsekvent användning

```dart
class MyService {
  // RÄTT - Använd EN källa konsekvent
  Future<void> doSomething() async {
    final profile = UserService.currentUserProfile;
    final userId = profile.id;
    final settings = profile.settings;
  }
}
```

## Beslutstabell

| Behov | Använd |
|-------|--------|
| Visa användarnamn/avatar | `UserService` |
| Spara/läsa settings | `UserService` |
| Kontrollera om inloggad | `PermissionService` |
| Hämta userId för queries | `PermissionService` |
| Validera behörighet | `PermissionService` |
| Social features (vänner, grupper) | `UserService` |

## Konsekvens: Settings Sparas Inte

Om du blandar dessa:
1. Läser settings från `UserService`
2. Sparar settings via `PermissionService.currentUser`
3. Settings sparas ALDRIG (fel objekt)

## Varningssignaler

```dart
// Sök efter dessa mönster:
PermissionService.*settings    // FEL
PermissionService.*avatar      // FEL
PermissionService.*preferences // FEL
UserService.*isAuthenticated   // Onödigt tungt
```

