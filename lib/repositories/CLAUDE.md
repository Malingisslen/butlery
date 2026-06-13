# Repositories Layer

Every Firebase repository must follow this structure:

```dart
class FirebaseXxxRepository extends BaseFirebaseRepository<Model>
    with UserScopedFirebaseRepository<Model>  // if user-scoped collection
    implements XxxRepository {                // always the interface
```

## Required implementations
- `String get collectionName`
- `T fromFirestore(DocumentSnapshot doc)` / `Map<String, dynamic> toFirestore(T entity)`
- `String getId(T entity)`
- All 4 permission methods: `validateCreatePermission`, `validateReadPermission`, `validateUpdatePermission`, `validateDeletePermission`

## Rules
- Interface goes in `repositories/interfaces/`, implementation in `repositories/firebase/`
- Never use `FirebaseFirestore.instance` — use the `firestore` protected getter from base class
- Never access `FirebaseAuth.instance.currentUser` — use `requireCurrentUserId()` from base class
- User-scoped data must mix in `UserScopedFirebaseRepository<T>` (routes to `/users/{uid}/collection`)
- Register as the interface type in DI, not the implementation
- For bulk ops, mix in `BatchOperationsFirebaseRepository<T>` (respects 500-op batch limit)
- Every custom permission check must call `logPermissionCheck()` for audit trail

## schemaVersion convention (BUT-648)

Six core models — `UserProfile`, `RecipeCore`, `WeeklyMenuPlan`, `UnifiedShoppingList`, `PersonalTag`, `SharedMenu` — carry a `final int schemaVersion` field (default 1). When reading from Firestore, use `data['schemaVersion'] as int? ?? 1` so existing docs without the field are treated as v1 (lazy-compat: no backfill needed). When writing, always include `'schemaVersion': schemaVersion` in `toFirestore()`/`toJson()`. Increment the version constant and add a migration branch in `fromMap` only when a breaking schema change ships. Do not build a migration-dispatch framework until a real v2 exists (YAGNI).
