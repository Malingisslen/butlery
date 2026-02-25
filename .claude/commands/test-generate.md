# /test-generate - Generate Repository Tests

Generate comprehensive test files for Butlery repositories following established patterns.

## Usage

```
/test-generate <repository_name>
```

**Examples**: `/test-generate firebase_auth_repository`, `/test-generate firebase_shopping_repository`

## Workflow

1. **Read** the target repository: `lib/repositories/firebase/[repository].dart`
2. **Identify**: repo type (user-scoped vs global), collection path, model type, custom methods, permission approach
3. **Check** existing tests: `test/unit/repositories/[repository]_test.dart`
4. **Generate** using reference tests below as patterns (500-600 lines target)
5. **Run**: `dart format` then `flutter test test/unit/repositories/[repository]_test.dart`

## Reference Tests (copy patterns from these)

- `test/unit/repositories/firebase_shared_recipe_repository_test.dart` (519 lines)
- `test/unit/repositories/firebase_comments_repository_test.dart` (711 lines)
- `test/unit/repositories/firebase_user_repository_test.dart`

## Required Test Groups

1. **Permission Validation** (8-10 tests) - auth checks, ownership, cross-user rejection
2. **CRUD Operations** (6-8 tests) - create, read, update, delete, batch, list
3. **Edge Cases** (4-5 tests) - unauthenticated, empty collections, missing fields, non-existent IDs
4. **Feature-Specific** - social sharing, real-time, ratings, etc. based on repo

## Test Infrastructure

- `FakeFirebaseFirestore` for Firestore, `MockAuthRepository` for auth
- `BaseUnitTest.setupUnit()` in setUpAll, `BaseUnitTest.resetMocks()` in tearDown
- `TestServiceLocator.reset()` in tearDown
- Helper methods: `createTest[Model]()` factory + `seed[Model]()` for Firestore

## Priority Repositories

1. **firebase_auth_repository** - Core auth (sign in/out, tokens, password reset)
2. **base_shared_content_repository** - Base class for shared content (CRUD + permissions + members)
3. **firebase_shopping_repository** - Shopping lists (needs real Firestore tests, only mocks exist)
4. **firebase_social_recipe_repository** - Social sharing (partial tests, needs full permission coverage)
5. **collaborative_recipe_repository** - Real-time collab editing (mock tests only)
