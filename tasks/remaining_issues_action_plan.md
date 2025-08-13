# Specific Action Plan for Remaining 369 Issues

## Issue Breakdown
- **32 undefined_function** - Missing mock service/repository functions
- **29 uri_does_not_exist** - Imports pointing to moved/deleted files  
- **28 undefined_method** - Missing test helper methods
- **22 implements_non_class** - Trying to implement classes that don't exist
- **21 undefined_identifier** - References to non-existent factories/classes
- **10 undefined_named_parameter** - API changes in model constructors
- **6 non_type_as_type_argument** - Using undefined classes as types
- **6 argument_type_not_assignable** - Type mismatches in function calls

## Priority 1: Create Test Infrastructure File (Fixes ~60 issues)

### Create: `test/helpers/test_service_locator.dart`
```dart
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';

final testSl = GetIt.instance;

/// Setup test service locator - call in setUp()
void setupTestServiceLocator() {
  testSl.reset();
  registerFirebaseTestInstances();
}

/// Tear down test service locator - call in tearDown()
void tearDownTestServiceLocator() {
  testSl.reset();
}

/// Register Firebase test instances
void registerFirebaseTestInstances() {
  // Register fake Firebase instances
  testSl.registerSingleton<FirebaseFirestore>(FakeFirebaseFirestore());
  testSl.registerSingleton<FirebaseAuth>(MockFirebaseAuth());
  testSl.registerSingleton<FirebaseStorage>(MockFirebaseStorage());
}
```

### Add to base test files:
```dart
// In test/helpers/base_repository_test.dart
import 'test_service_locator.dart';

// In test/helpers/base_viewmodel_test.dart  
import 'test_service_locator.dart';
```

## Priority 2: Fix Import URIs (Fixes ~29 issues)

### Replace old imports with new unified services:
```dart
// OLD (doesn't exist)
import 'package:butlery/services/authentication_service.dart';
import 'package:butlery/services/recipe_service.dart';
import 'package:butlery/services/chat_service.dart';
import 'package:butlery/repositories/user_repository.dart';
import 'package:butlery/repositories/recipe_repository.dart';

// NEW (use unified services)
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/repositories/user/user_repository.dart';
import 'package:butlery/repositories/recipe/recipe_repository.dart';
```

### Remove references to deleted models:
```dart
// DELETE these imports entirely
import 'package:butlery/models/menu/menu_model.dart';  // Doesn't exist
import 'package:butlery/services/unified/modules/cache_strategy.dart'; // Moved
import 'package:butlery/services/unified/operations/search_operations.dart'; // Moved
```

## Priority 3: Create Service Mocks File (Fixes ~32 issues)

### Create: `test/helpers/mocks/service_mocks.dart`
```dart
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/social_service.dart';
import 'package:butlery/services/import_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/gemini_service.dart';
import 'package:butlery/services/collaboration_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/saved_recipes_service.dart';
import 'package:butlery/services/realtime_service.dart';

// Service Mocks
class MockAuthenticationService extends Mock implements AuthService {}
class MockRecipeService extends Mock implements UnifiedRecipeService {}
class MockSocialService extends Mock implements SocialService {}
class MockImportService extends Mock implements ImportService {}
class MockChatService extends Mock implements MessagingService {}
class MockGeminiService extends Mock implements GeminiService {}
class MockCollaborationService extends Mock implements CollaborationService {}
class MockShoppingListService extends Mock implements UnifiedShoppingService {}
class MockSavedRecipesService extends Mock implements SavedRecipesService {}
class MockRealtimeService extends Mock implements RealtimeService {}

// Create mock service factory functions
MockAuthenticationService createMockAuthService() => MockAuthenticationService();
MockRecipeService createMockRecipeService() => MockRecipeService();
// ... etc for all services
```

## Priority 4: Create Repository Mocks File (Fixes ~15 issues)

### Create: `test/helpers/mocks/repository_mocks.dart`
```dart
import 'package:mocktail/mocktail.dart';
import 'package:butlery/repositories/user/user_repository.dart';
import 'package:butlery/repositories/recipe/recipe_repository.dart';
import 'package:butlery/repositories/menu/menu_repository.dart';
import 'package:butlery/repositories/social/social_repository.dart';
import 'package:butlery/repositories/comment/comment_repository.dart';
import 'package:butlery/repositories/share/share_repository.dart';
import 'package:butlery/repositories/chat/chat_repository.dart';
import 'package:butlery/repositories/message/message_repository.dart';
import 'package:butlery/repositories/collaboration/collaboration_repository.dart';
import 'package:butlery/repositories/shopping/shopping_repository.dart';
import 'package:butlery/repositories/import/import_repository.dart';
import 'package:butlery/repositories/batch_import/batch_import_repository.dart';
import 'package:butlery/repositories/realtime/realtime_repository.dart';

// Repository Mocks
class MockUserRepository extends Mock implements UserRepository {}
class MockRecipeRepository extends Mock implements RecipeRepository {}
class MockMenuRepository extends Mock implements MenuRepository {}
class MockSocialRepository extends Mock implements SocialRepository {}
class MockCommentRepository extends Mock implements CommentRepository {}
class MockShareRepository extends Mock implements ShareRepository {}
class MockChatRepository extends Mock implements ChatRepository {}
class MockMessageRepository extends Mock implements MessageRepository {}
class MockCollaborationRepository extends Mock implements CollaborationRepository {}
class MockShoppingListRepository extends Mock implements ShoppingListRepository {}
class MockImportRepository extends Mock implements ImportRepository {}
class MockBatchImportRepository extends Mock implements BatchImportRepository {}
class MockRealtimeRepository extends Mock implements RealtimeRepository {}
```

## Priority 5: Fix Specific Code Issues

### 1. Fix `@mustCallSuper` annotation (2 issues)
```dart
// In test/helpers/base_repository_test.dart
import 'package:meta/meta.dart'; // Add this import

@mustCallSuper  // Now it will work
```

### 2. Fix Firestore type issues (5 issues)
```dart
// Add proper imports and type definitions
import 'package:cloud_firestore/cloud_firestore.dart';

// Use proper types
Query<Map<String, dynamic>> // Instead of just Query
WriteBatch // Will work with proper import
Transaction // Will work with proper import
```

### 3. Fix syntax error in base_viewmodel_test.dart (line 409)
```dart
// Find line 409 with: throw Exception('error')
// Change to proper syntax:
() => throw Exception('error')  // Wrong
() { throw Exception('error'); } // Correct
```

### 4. Fix undefined factories (21 issues)
```dart
// Create missing factories or remove references:
// - MenuModelFactory doesn't exist (use SharedMenuFactory)
// - UserFactory doesn't exist (use UserProfileFactory)
// - ImportManagerResultFactory doesn't exist (use ImportResult class)
// - BatchImportResultFactory doesn't exist
```

### 5. Fix shopping_list_view_example_test.dart (6 issues)
```dart
// Line 243: buildList() should be build()
UnifiedShoppingListFactory.build(count: 2) // Not buildList

// Line 269-291: Fix list access
final lists = [list1, list2]; // Create proper list
// Not: UnifiedShoppingListFactory.buildList(2) which returns single item
```

## Priority 6: Fix Model Parameter Issues (10 issues)

### Update model constructors:
```dart
// RecipeCore/RecipeUnified no longer has 'createdBy' parameter
// Remove these parameters from test data:
Recipe(
  // createdBy: 'user123', // REMOVE THIS
  userId: 'user123', // Use this instead
  ...
)
```

## Execution Order

1. **Create test_service_locator.dart** → Fixes 60+ issues immediately
2. **Fix all imports** → Fixes 29 URI issues
3. **Create service_mocks.dart** → Fixes 32 function issues  
4. **Create repository_mocks.dart** → Fixes 15 function issues
5. **Fix specific code issues** → Fixes remaining ~40 issues
6. **Run `dart fix --apply`** → Clean up any remaining warnings

## Expected Result
After implementing these specific fixes:
- Errors should drop from 180+ to under 50
- Most remaining issues will be info/warnings
- Test suite should be runnable

## Time Estimate
- Priority 1-2: 30 minutes
- Priority 3-4: 45 minutes  
- Priority 5-6: 30 minutes
- **Total: ~1.5-2 hours**