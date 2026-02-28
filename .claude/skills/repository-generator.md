---
description: >
  Generates Firebase repository boilerplate with BaseFirebaseRepository,
  permission validators, and DI registration. Use when creating new
  repositories (user-scoped, global, or subcollection variants).
---

# Repository Generator

> Generate new Firebase repositories with correct patterns.

## Generera Repository

När du skapar en ny repository, använd detta mönster:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/repositories/mixins/user_scoped_firebase_repository.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

class Firebase{Entity}Repository extends BaseFirebaseRepository<{Entity}>
    with StreamManagementMixin, UserScopedFirebaseRepository<{Entity}>
    implements {Entity}Repository {

  Firebase{Entity}Repository({
    FirebaseFirestore? firestore,
    required AuthRepository authRepository,
    FirebaseAuditRepository? auditRepository,
  }) : super(
    firestore: firestore,
    authRepository: authRepository,
    auditRepository: auditRepository,
  );

  @override
  String get collectionName => '{entities}'; // plural, lowercase

  @override
  {Entity} fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return {Entity}.fromFirestore(doc);
  }

  @override
  Map<String, dynamic> toFirestore({Entity} entity) {
    return entity.toFirestore();
  }

  @override
  String getId({Entity} entity) => entity.id;

  // Permission validation - REQUIRED
  @override
  Future<bool> validateCreatePermission(String userId, {Entity} entity) async {
    return entity.ownerId == userId;
  }

  @override
  Future<bool> validateReadPermission(String userId, String resourceId, {Entity}? entity) async {
    if (entity == null) return false;
    return entity.ownerId == userId;
  }

  @override
  Future<bool> validateUpdatePermission(String userId, String resourceId, {Entity} entity) async {
    return entity.ownerId == userId;
  }

  @override
  Future<bool> validateDeletePermission(String userId, String resourceId) async {
    final entity = await getById(resourceId);
    return entity?.ownerId == userId;
  }
}
```

## Varianter

### User-Scoped (vanligast)
```dart
// Collection: users/{userId}/{entities}
with UserScopedFirebaseRepository<{Entity}>
```

### Global Collection
```dart
// Collection: {entities} (root level)
// Ta bort UserScopedFirebaseRepository mixin
```

### Subcollection
```dart
// Collection: {parents}/{parentId}/{entities}
CollectionReference<Map<String, dynamic>> getSubcollection(String parentId) {
  return firestore.collection('{parents}').doc(parentId).collection('{entities}');
}
```

## Checklista

- [ ] Extends `BaseFirebaseRepository<T>`
- [ ] Implements interface (`{Entity}Repository`)
- [ ] `StreamManagementMixin` för realtime
- [ ] `UserScopedFirebaseRepository` för user-scoped data
- [ ] Alla 4 permission validators implementerade
- [ ] `collectionName` korrekt (plural, lowercase)
- [ ] Constructor tar `AuthRepository` + optional `FirebaseAuditRepository`

## Registrera i DI

```dart
// I rätt module (ContentModule, SocialModule, etc.)
container.registerSingleton<{Entity}Repository>(
  Firebase{Entity}Repository(
    authRepository: container.get<AuthRepository>(),
    auditRepository: container.get<FirebaseAuditRepository>(),
  ),
);
```

## Nyckelfilar

- `lib/repositories/firebase/base_firebase_repository.dart`
- `lib/repositories/mixins/user_scoped_firebase_repository.dart`
- `lib/repositories/mixins/permission_validation_mixin.dart`
