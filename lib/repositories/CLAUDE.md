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
