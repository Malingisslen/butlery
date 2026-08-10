# Architectural Decision: firebase_storage_repository.dart Exclusion from BaseFirebaseRepository

**Date**: 2025-01-15
**Status**: Accepted
**Context**: Issue #017 - BaseFirebaseRepository adoption gaps

## Decision

`firebase_storage_repository.dart` is **NOT applicable** for BaseFirebaseRepository migration and is **excluded** from Issue #017 scope.

## Rationale

### 1. **Different Firebase Service: Storage vs. Firestore**

BaseFirebaseRepository is designed for **Cloud Firestore** (document database), while firebase_storage_repository uses **Firebase Storage** (file storage service).

**Fundamental Differences:**

| Aspect | Cloud Firestore | Firebase Storage |
|--------|----------------|------------------|
| **Data Type** | Structured documents (JSON) | Binary files (images, videos, PDFs) |
| **Operations** | CRUD on documents | Upload/download/delete files |
| **Access Pattern** | Query-based retrieval | URL-based file access |
| **SDK** | `cloud_firestore` package | `firebase_storage` package |
| **Data Model** | Collections → Documents → Fields | Buckets → Paths → Files |

### 2. **Storage-Specific Operations**

Firebase Storage repositories implement **file operations** rather than document operations:

**Typical Operations:**
```dart
// Upload file
Future<String> uploadFile(File file, String path);

// Download file
Future<Uint8List> downloadFile(String path);

// Get download URL
Future<String> getDownloadURL(String path);

// Delete file
Future<void> deleteFile(String path);

// Get file metadata
Future<FullMetadata> getMetadata(String path);
```

These operations **do not map** to BaseFirebaseRepository's CRUD model:
- No `create(T entity)` - Files are uploaded with binary data
- No `read(String id)` - Files are retrieved as bytes or URLs
- No `update(T entity)` - Files are replaced entirely, not updated
- No `delete(String id)` - Similar, but operates on file paths not document IDs

### 3. **No Entity Serialization Required**

BaseFirebaseRepository assumes:
```dart
abstract class BaseFirebaseRepository<T> {
  T fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc);
  Map<String, dynamic> toFirestore(T entity);
}
```

Firebase Storage works with **raw binary data**, not structured entities:
```dart
// No fromFirestore/toFirestore - working with bytes instead
await storageRef.putData(bytes);
final bytes = await storageRef.getData();
```

### 4. **Different Permission Model**

**Firestore Security Rules** (BaseFirebaseRepository context):
```javascript
match /recipes/{recipeId} {
  allow read, write: if request.auth != null &&
                        resource.data.ownerId == request.auth.uid;
}
```

**Storage Security Rules** (firebase_storage_repository context):
```javascript
match /users/{userId}/images/{imageId} {
  allow read, write: if request.auth != null &&
                        request.auth.uid == userId;
}
```

Permission validation happens at the **Firebase Rules level** for storage, not in the repository code like BaseFirebaseRepository.

## Current Architecture

```dart
class FirebaseStorageRepository {
  final FirebaseStorage _storage;

  // File upload operations
  Future<String> uploadRecipeImage(String recipeId, File image) async {
    final path = 'recipes/$recipeId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child(path);
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  // File deletion operations
  Future<void> deleteFile(String path) async {
    await _storage.ref().child(path).delete();
  }
}
```

## Recommended Pattern for Storage Repositories

Instead of BaseFirebaseRepository, storage repositories should follow a **BaseStorageRepository** pattern:

```dart
abstract class BaseStorageRepository {
  FirebaseStorage get storage;

  Future<String> upload(String path, dynamic data);
  Future<void> delete(String path);
  Future<String> getDownloadURL(String path);
  Future<FullMetadata> getMetadata(String path);
}
```

This pattern:
- ✅ Handles binary data operations
- ✅ Manages file paths instead of document IDs
- ✅ Provides download URLs for file access
- ✅ Implements storage-specific operations (metadata, versioning)
- ✅ Works with Firebase Storage security rules

## Conclusion

firebase_storage_repository.dart operates on a **completely different Firebase service** with fundamentally different:
- Data types (files vs. documents)
- Operations (upload/download vs. CRUD)
- Access patterns (URLs vs. queries)
- Permission models (Storage Rules vs. Firestore Rules)

**Attempting to force it into BaseFirebaseRepository would be an anti-pattern** that adds complexity without benefit.

## Related Files

- [lib/repositories/firebase/firebase_storage_repository.dart](../../lib/repositories/firebase/firebase_storage_repository.dart) - Storage repository (if exists)
- [lib/repositories/firebase/base_firebase_repository.dart](../../lib/repositories/firebase/base_firebase_repository.dart) - Firestore repository pattern

## References

- **Issue #017**: BaseFirebaseRepository adoption gaps
- **Firebase Storage Documentation**: https://firebase.google.com/docs/storage
- **Cloud Firestore Documentation**: https://firebase.google.com/docs/firestore
- **Firebase Security Rules**: Different rule syntax for Storage vs. Firestore
