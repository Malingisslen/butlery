# Module Structure - 7 Application Modules

Detailed breakdown of Butlery's 7 domain-driven DI modules with complete service listings and dependencies.

## Overview

Butlery's DI is organized into 7 modules following clean architecture principles:
- **Domain-driven boundaries**: Each module represents a domain area
- **Hierarchical dependencies**: Modules only depend on modules above
- **Clear separation**: Infrastructure → Domain → Application → Presentation
- **Lazy loading**: Feature modules load on demand

## Module Hierarchy

```
Layer 1 (Foundation):
  └─ Core Module

Layer 2 (Content):
  └─ Content Module
       (depends on: Core)

Layer 3 (Social):
  ├─ Social Module
  │    (depends on: Core, Content)
  └─ Messaging Module
       (depends on: Core, Social)

Layer 4 (Collaboration):
  └─ Collaboration Module
       (depends on: Core, Content, Social)

Layer 5 (Performance):
  └─ Performance Module
       (depends on: Core, Content)

Layer 6 (Presentation):
  └─ UI Module
       (depends on: All modules)
```

## 1. Core Module

**File**: `lib/core/di/modules/core_module.dart`

**Purpose**: Foundational infrastructure layer - authentication, storage, logging

**Registration Type**: Eager singletons (needed at startup)

**Dependencies**: None (foundation layer, no dependencies)

### Services Registered

#### Infrastructure Services

```dart
// Firestore database access
container.registerSingleton<FirestoreRepository>(
  FirebaseFirestoreRepository(),
);

// Firebase Authentication
container.registerSingleton<AuthRepository>(
  FirebaseAuthRepository(),
);

// Firebase Storage
container.registerSingleton<StorageRepository>(
  FirebaseStorageRepository(
    storage: FirebaseStorage.instance,
  ),
);
```

#### Utility Services

```dart
// Logging infrastructure
container.registerSingleton<Logger>(
  Logger(),
);

// Analytics tracking
container.registerSingleton<AnalyticsService>(
  FirebaseAnalyticsService(),
);

// Network connectivity monitoring
container.registerSingleton<ConnectivityService>(
  ConnectivityService(),
);

// Permission management
container.registerSingleton<PermissionService>(
  PermissionService(
    authRepository: container<AuthRepository>(),
  ),
);
```

**Total Services**: 7
**Load Time**: Immediate (app startup)

---

## 2. Content Module

**File**: `lib/core/di/modules/content_module.dart`

**Purpose**: Content management - recipes, menus, import/export

**Registration Type**: Lazy singletons

**Dependencies**: Core Module (auth, firestore, storage)

### Services Registered

#### Repository Layer

```dart
// Personal recipe repository
container.registerLazySingleton<RecipeRepository>(
  () => FirebaseRecipeRepository(
    firestore: container<FirestoreRepository>(),
    authRepository: container<AuthRepository>(),
  ),
);

// Personal menu repository
container.registerLazySingleton<MenuRepository>(
  () => FirebaseMenuRepository(
    firestore: container<FirestoreRepository>(),
    authRepository: container<AuthRepository>(),
  ),
);
```

#### Service Layer

```dart
// Unified recipe service (personal + social operations)
container.registerLazySingleton<UnifiedRecipeService>(
  () => UnifiedRecipeService(
    personalRepository: container<RecipeRepository>(),
    authRepository: container<AuthRepository>(),
    logger: container<Logger>(),
  ),
);

// Unified menu service
container.registerLazySingleton<UnifiedMenuService>(
  () => UnifiedMenuService(
    menuRepository: container<MenuRepository>(),
    authRepository: container<AuthRepository>(),
  ),
);

// User profile service
container.registerLazySingleton<UserService>(
  () => UserService(
    userRepository: container<UserRepository>(),
    authRepository: container<AuthRepository>(),
  ),
);
```

#### Import Services

```dart
// Photo import (OCR, AI extraction)
container.registerLazySingleton<PhotoImportService>(
  () => PhotoImportService(
    ocrService: container<OCRExtractionService>(),
    imagePickerService: container<ImagePickerService>(),
  ),
);

// OCR text extraction
container.registerLazySingleton<OCRExtractionService>(
  () => OCRExtractionService(),
);

// Social media import (Instagram, web URLs)
container.registerLazySingleton<SocialMediaExtractor>(
  () => SocialMediaExtractor(),
);

// Image picker service
container.registerLazySingleton<ImagePickerService>(
  () => ImagePickerService(),
);
```

**Total Services**: 11
**Load Time**: On first access (lazy)

---

## 3. Social Module

**File**: `lib/core/di/modules/social_module.dart`

**Purpose**: Social features - friends, sharing, comments, ratings

**Registration Type**: Lazy singletons

**Dependencies**: Core + Content Modules

### Services Registered

#### Repository Layer

```dart
// Friends repository
container.registerLazySingleton<FriendsRepository>(
  () => FirebaseFriendsRepository(
    firestore: container<FirestoreRepository>(),
    authRepository: container<AuthRepository>(),
  ),
);

// Social recipe repository (shared recipes)
container.registerLazySingleton<SocialRecipeRepository>(
  () => FirebaseSocialRecipeRepository(
    firestore: container<FirestoreRepository>(),
    authRepository: container<AuthRepository>(),
  ),
);

// Comments repository
container.registerLazySingleton<CommentsRepository>(
  () => FirebaseCommentsRepository(
    firestore: container<FirestoreRepository>(),
    authRepository: container<AuthRepository>(),
  ),
);

// Ratings repository
container.registerLazySingleton<RatingsRepository>(
  () => FirebaseRatingsRepository(
    firestore: container<FirestoreRepository>(),
    authRepository: container<AuthRepository>(),
  ),
);
```

#### Service Layer

```dart
// Unified friends service
container.registerLazySingleton<UnifiedFriendsService>(
  () => UnifiedFriendsService(
    friendsRepository: container<FriendsRepository>(),
    userService: container<UserService>(),
  ),
);

// Social recipe service
container.registerLazySingleton<SocialRecipeService>(
  () => SocialRecipeService(
    repository: container<SocialRecipeRepository>(),
    userService: container<UserService>(),
    permissionService: container<PermissionService>(),
  ),
);

// Recipe discovery (explore public recipes)
container.registerLazySingleton<RecipeDiscoveryService>(
  () => RecipeDiscoveryService(
    socialRepository: container<SocialRecipeRepository>(),
  ),
);

// Recipe sharing manager
container.registerLazySingleton<RecipeSharingManager>(
  () => RecipeSharingManager(
    socialRepository: container<SocialRecipeRepository>(),
    friendsService: container<UnifiedFriendsService>(),
  ),
);
```

**Total Services**: 12
**Load Time**: On first access (lazy)

---

## 4. Messaging Module

**File**: `lib/core/di/modules/messaging_module.dart`

**Purpose**: Messaging and push notifications (FCM)

**Registration Type**: Lazy singletons

**Dependencies**: Core + Social Modules

### Services Registered

#### Repository Layer

```dart
// Messaging repository (chat messages)
container.registerLazySingleton<MessagingRepository>(
  () => FirebaseMessagingRepository(
    firestore: container<FirestoreRepository>(),
    authRepository: container<AuthRepository>(),
  ),
);

// Notifications repository (FCM tokens, settings)
container.registerLazySingleton<NotificationsRepository>(
  () => FirebaseNotificationsRepository(
    firestore: container<FirestoreRepository>(),
    authRepository: container<AuthRepository>(),
  ),
);
```

#### Service Layer

```dart
// Messaging service (chat functionality)
container.registerLazySingleton<MessagingService>(
  () => MessagingService(
    repository: container<MessagingRepository>(),
    userService: container<UserService>(),
  ),
);

// FCM service (push notifications)
container.registerLazySingleton<FCMService>(
  () => FCMService(
    notificationsRepository: container<NotificationsRepository>(),
  ),
);

// Messaging media service (send images in chat)
container.registerLazySingleton<MessagingMediaService>(
  () => MessagingMediaService(
    storageRepository: container<StorageRepository>(),
  ),
);
```

**Total Services**: 5
**Load Time**: On first access (lazy)

---

## 5. Collaboration Module

**File**: `lib/core/di/modules/collaboration_module.dart`

**Purpose**: Real-time collaboration - shopping lists, realtime recipes/menus

**Registration Type**: Lazy singletons

**Dependencies**: Core + Content + Social Modules

### Services Registered

#### Repository Layer

```dart
// Shopping list repository
container.registerLazySingleton<ShoppingRepository>(
  () => FirebaseShoppingRepository(
    firestore: container<FirestoreRepository>(),
    authRepository: container<AuthRepository>(),
  ),
);

// Collaborative recipe repository
container.registerLazySingleton<CollaborativeRecipeRepository>(
  () => FirebaseCollaborativeRecipeRepository(
    firestore: container<FirestoreRepository>(),
    authRepository: container<AuthRepository>(),
  ),
);

// Shared menu repository
container.registerLazySingleton<SharedMenuRepository>(
  () => FirebaseSharedMenuRepository(
    firestore: container<FirestoreRepository>(),
    authRepository: container<AuthRepository>(),
  ),
);
```

#### Service Layer

```dart
// Unified shopping service (personal + shared lists)
container.registerLazySingleton<UnifiedShoppingService>(
  () => UnifiedShoppingService(
    shoppingRepository: container<ShoppingRepository>(),
    userService: container<UserService>(),
  ),
);

// Realtime recipe service (collaborative editing)
container.registerLazySingleton<RealtimeRecipeService>(
  () => RealtimeRecipeService(
    repository: container<CollaborativeRecipeRepository>(),
    permissionService: container<PermissionService>(),
  ),
);

// Realtime menu service
container.registerLazySingleton<RealtimeMenuService>(
  () => RealtimeMenuService(
    repository: container<SharedMenuRepository>(),
  ),
);

// Group shared content service
container.registerLazySingleton<GroupSharedContentService>(
  () => GroupSharedContentService(
    recipeRepository: container<SocialRecipeRepository>(),
    menuRepository: container<SharedMenuRepository>(),
  ),
);

// Presence service (online/offline status)
container.registerLazySingleton<PresenceService>(
  () => PresenceService(
    firestore: container<FirestoreRepository>(),
    authRepository: container<AuthRepository>(),
  ),
);
```

**Total Services**: 11
**Load Time**: On first access (lazy)

---

## 6. Performance Module

**File**: `lib/core/di/modules/performance_module.dart`

**Purpose**: Performance optimization - caching, startup, monitoring

**Registration Type**: Lazy singletons

**Dependencies**: Core + Content Modules

### Services Registered

```dart
// Cache optimization service
container.registerLazySingleton<CacheOptimizationService>(
  () => CacheOptimizationService(),
);

// Startup optimization service
container.registerLazySingleton<StartupOptimizationService>(
  () => StartupOptimizationService(),
);

// Performance monitoring service
container.registerLazySingleton<PerformanceMonitoringService>(
  () => PerformanceMonitoringService(
    logger: container<Logger>(),
  ),
);

// Recipe data repair service (fix broken data)
container.registerLazySingleton<RecipeDataRepairService>(
  () => RecipeDataRepairService(
    recipeRepository: container<RecipeRepository>(),
  ),
);
```

**Total Services**: 4
**Load Time**: On first access (lazy)

---

## 7. UI Module

**File**: `lib/core/di/modules/ui_module.dart`

**Purpose**: ViewModels, navigation, UI state management

**Registration Type**: Factory (new instance per access)

**Dependencies**: All other modules

### Services Registered

#### ViewModels (Factory Pattern)

```dart
// Recipe ViewModels
container.registerFactory<RecipeViewModel>(
  () => RecipeViewModel(
    service: container<UnifiedRecipeService>(),
  ),
);

container.registerFactory<RecipeDetailViewModel>(
  () => RecipeDetailViewModel(
    service: container<UnifiedRecipeService>(),
    socialService: container<SocialRecipeService>(),
  ),
);

// Menu ViewModels
container.registerFactory<MenuViewModel>(
  () => MenuViewModel(
    service: container<UnifiedMenuService>(),
  ),
);

// Shopping ViewModels
container.registerFactory<UnifiedShoppingViewModel>(
  () => UnifiedShoppingViewModel(
    service: container<UnifiedShoppingService>(),
  ),
);

// Social ViewModels
container.registerFactory<FriendsViewModel>(
  () => FriendsViewModel(
    service: container<UnifiedFriendsService>(),
  ),
);

// ... additional ViewModels
```

**Total Services**: 20-30 ViewModels
**Load Time**: On widget creation (factory)

---

## Module Dependencies Matrix

| Module | Depends On |
|--------|------------|
| Core | None |
| Content | Core |
| Social | Core, Content |
| Messaging | Core, Social |
| Collaboration | Core, Content, Social |
| Performance | Core, Content |
| UI | All modules |

**Rule**: Modules can only depend on modules listed in "Depends On" column.

---

## Module Loading Strategy

### Eager Loading (Core Module Only)

**When**: App startup (main.dart)
**Modules**: Core Module
**Services**: 7 services (Auth, Firestore, Storage, Logger, etc.)
**Time**: ~50-100ms

**Why eager**:
- Needed immediately for app initialization
- Lightweight services (no heavy I/O)
- No circular dependency risks

### Lazy Loading (All Other Modules)

**When**: On first access
**Modules**: Content, Social, Messaging, Collaboration, Performance
**Services**: 40-50 services total
**Time**: ~10-20ms per module

**Why lazy**:
- Reduces startup time
- Prevents circular dependency issues
- Only loads features when needed
- Modules depend on each other (lazy prevents init-time circular refs)

### Per-Request (UI Module)

**When**: On widget creation
**Modules**: UI Module
**Services**: ViewModels (20-30 factory registrations)
**Time**: <1ms per ViewModel creation

**Why factory**:
- ViewModels need fresh state per screen
- Disposable (each screen gets independent instance)
- Prevents state leakage between screens

---

## Adding New Services to Modules

### Step 1: Choose Correct Module

**Guidelines**:
- Infrastructure/auth/storage → Core Module
- Content CRUD (recipes, menus) → Content Module
- Friends/sharing/comments → Social Module
- Chat/notifications → Messaging Module
- Real-time/shopping → Collaboration Module
- Cache/optimization → Performance Module
- ViewModels → UI Module

### Step 2: Register in Module File

```dart
// Example: Adding new service to Content Module
void registerContentModule(GetIt container) {
  // ... existing registrations

  // Add new service
  container.registerLazySingleton<NewContentService>(
    () => NewContentService(
      repository: container<SomeRepository>(),
      // Inject dependencies from same or lower-level modules
    ),
  );
}
```

### Step 3: Update Dependencies

**If new service needs services from higher-level modules**:
- ❌ Don't do this - creates upward dependency
- ✅ Refactor: Move service to higher-level module OR extract shared logic

**Example**:
```dart
// ❌ WRONG - Content Module depending on Social Module
container.registerLazySingleton<RecipeService>(
  () => RecipeService(
    friendsService: container<FriendsService>(), // FriendsService is in Social Module!
  ),
);

// ✅ RIGHT - Move to Social Module or use events/callbacks
container.registerLazySingleton<SocialRecipeService>(
  () => SocialRecipeService(
    friendsService: container<FriendsService>(), // OK - both in Social Module
  ),
);
```

---

## Testing Module Structure

### Test Service Locator Mirrors Production

**Structure**: TestServiceLocator provides same 7-module structure for tests

```dart
class TestServiceLocator {
  static Future<void> setup() async {
    final container = GetIt.instance;

    // Same module structure as production
    registerCoreModule(container); // Real infrastructure
    registerContentModule(container); // With mocks
    registerSocialModule(container); // With mocks
    // ... etc
  }

  static void registerMock<T extends Object>(T mock) {
    // Replace production service with mock
    GetIt.instance.unregister<T>();
    GetIt.instance.registerSingleton<T>(mock);
  }
}
```

### Mocking Services by Module

```dart
setUp() {
  // Mock Core Module services
  TestServiceLocator.registerMock<AuthRepository>(mockAuthRepo);

  // Mock Content Module services
  TestServiceLocator.registerMock<RecipeRepository>(mockRecipeRepo);

  // Get service under test (dependencies auto-injected)
  service = ServiceLocator.get<RecipeService>();
}
```

---

## Best Practices

1. **Choose correct module** - Follow domain boundaries
2. **Respect hierarchy** - Only depend on lower-level modules
3. **Use lazy singletons** - For most services (prevents circular deps)
4. **Use factory for ViewModels** - Fresh state per screen
5. **Avoid cross-module dependencies** - Keep modules independent
6. **Test module structure** - Mirror production structure in tests

## Anti-Patterns

**1. Upward Dependencies** (🔥 HIGH):
```dart
// ❌ WRONG - Core Module depending on Content Module
registerCoreModule(GetIt container) {
  container.registerSingleton<AuthService>(
    AuthService(
      recipeService: container<RecipeService>(), // RecipeService is in Content Module!
    ),
  );
}
```

**2. Circular Module Dependencies** (🔥 HIGH):
```dart
// ❌ WRONG - Social depends on Messaging, Messaging depends on Social
// Creates circular dependency at module level
```

**3. Wrong Module Placement** (⚠️):
```dart
// ❌ WRONG - Placing ViewModel in Content Module
registerContentModule(GetIt container) {
  container.registerLazySingleton<RecipeViewModel>(...); // Should be in UI Module
}
```

---

## Related Resources

- [registration-patterns.md](registration-patterns.md) - Singleton vs lazy vs factory
- [service-access-patterns.md](service-access-patterns.md) - Constructor vs ServiceLocator
- [testing-with-di.md](testing-with-di.md) - Testing with DI

---

**Impact**: 50-60 services organized across 7 modules
**Benefit**: Clean architecture, clear dependencies, easy testing
**Complexity**: Managed complexity via modular boundaries
