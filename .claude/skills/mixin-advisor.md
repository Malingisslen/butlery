# Mixin Advisor

> Föreslå rätt mixin-kombination baserat på service/repository-typ.

## Mixin-kombinationer

### Services

| Typ | Mixins | Exempel |
|-----|--------|---------|
| Enkel service | `ErrorHandlingMixin` | AnalyticsService |
| Firebase service | `ErrorHandlingMixin, FirebaseServiceMixin` | UserService |
| Realtime service | `ErrorHandlingMixin, StreamManagementMixin` | RealtimeSyncService |
| Base service | `extends BaseService` (inkluderar ErrorHandling) | ImageUploadService |

### Repositories

| Typ | Mixins | Exempel |
|-----|--------|---------|
| Firebase CRUD | `BaseFirebaseRepository<T>` + `PermissionValidationMixin` | Alla repositories |
| User-scoped | + `UserScopedFirebaseRepository<T>` | FirebaseRecipeRepository |
| Med streaming | + `StreamManagementMixin` | FirebaseRecipeRepository |
| Metadata | `BaseEngagementRepository` / `BaseDismissalRepository` | Engagement repos |

### ViewModels

| Typ | Mixins | Exempel |
|-----|--------|---------|
| Enkel | `ChangeNotifier` + `ErrorHandlingMixin` | SimpleViewModel |
| Async ops | + `AsyncOperationMixin` | SmartImportViewModel |
| Komplex | + `ErrorCoordinatorMixin` | RecipeFormViewModel |
| State notify | + `StateNotifierMixin` | FormViewModel |

## Beslutstabell

### Service

```
Behöver async error handling?
  → ErrorHandlingMixin (ALLTID, 100% adoption)

Använder Firebase direkt?
  → + FirebaseServiceMixin

Har streams/subscriptions?
  → + StreamManagementMixin

Vill ha lifecycle hooks?
  → extends BaseService
```

### Repository

```
Firebase CRUD?
  → extends BaseFirebaseRepository<T>

User-specifik data?
  → + UserScopedFirebaseRepository<T>

Real-time listeners?
  → + StreamManagementMixin
```

### ViewModel

```
UI state?
  → extends ChangeNotifier

Async operations?
  → + ErrorHandlingMixin

Loading/error states?
  → + AsyncOperationMixin

Flera koordinerade ops?
  → + ErrorCoordinatorMixin

>300 rader?
  → Delegera till managers
```

## Exempel: Ny Service

```dart
// Fråga: Vad gör servicen?

// 1. Enkel business logic
class CalculationService with ErrorHandlingMixin { }

// 2. Firebase + error handling
class DataService extends BaseService with FirebaseServiceMixin { }

// 3. Realtime subscriptions
class LiveService extends BaseService
    with StreamManagementMixin, FirebaseServiceMixin { }
```

## Exempel: Ny Repository

```dart
// Standard user-scoped repository
class FirebaseXRepository extends BaseFirebaseRepository<X>
    with StreamManagementMixin, UserScopedFirebaseRepository<X>
    implements XRepository { }

// Global collection (ingen user-scoping)
class FirebaseGlobalRepository extends BaseFirebaseRepository<X>
    with StreamManagementMixin
    implements XRepository { }
```

## Varningssignaler

| Om du ser... | Föreslå |
|--------------|---------|
| Service utan ErrorHandlingMixin | Lägg till (100% adoption krävs) |
| Repository utan StreamManagement | Lägg till för realtime |
| ViewModel >300 rader | Delegera till managers |
| Manuell try/catch överallt | Använd safeExecute() |

## Nyckelfilar

- `lib/core/mixins/error_handling_mixin.dart`
- `lib/core/mixins/stream_management_mixin.dart`
- `lib/core/mixins/firebase_service_mixin.dart`
- `lib/repositories/mixins/user_scoped_firebase_repository.dart`
