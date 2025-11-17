# ADR-004: Organize DI into 7 Domain Modules

**Status**: Accepted
**Date**: 2024-Q3 (Retroactive documentation 2025-11-17)
**Deciders**: Core development team
**Technical Story**: Need to organize 240+ DI registrations (ViewModels + Services + Repositories)

---

## Context

Butlery's GetIt dependency injection (see ADR-002) manages 240+ registrations:
- **60+ ViewModels**
- **150+ Services**
- **30+ Repositories**

**Challenges with Single Module**:
- **Maintainability**: 240 registrations in one file = 1,000+ lines of registration code
- **Circular Dependencies**: Risk of initialization deadlocks when all services register together
- **Build Time**: Large single file slows IDE and compilation
- **Navigation**: Difficult to find specific service registration
- **Team Collaboration**: Merge conflicts when multiple developers edit same DI file

**Requirements**:
- **Clear Organization**: Easy to locate service registrations
- **Prevent Circular Dependencies**: Module boundaries enforce initialization order
- **Lazy Loading**: Modules initialized on-demand
- **Domain Cohesion**: Related services grouped together
- **Scalability**: Support growth to 500+ registrations

---

## Decision

**We will organize GetIt registrations into 7 domain-focused modules:**

```
lib/core/di/modules/
├── core_module.dart          # 🏗️  Infrastructure (Auth, Storage, Firestore, Analytics)
├── content_module.dart       # 📝  Recipes, Menus, Import
├── social_module.dart        # 👥  Friends, Sharing, Comments, Ratings
├── messaging_module.dart     # 💬  Chat, Conversations, Notifications
├── collaboration_module.dart # 🤝  Real-time editing, Shopping lists
├── performance_module.dart   # ⚡  Caching, Startup optimization, Monitoring
└── ui_module.dart            # 🎨  ViewModels, Navigation, UI state
```

**Module Initialization Order**:
```
1. Core Module (eager - must initialize first)
   ↓
2-6. Feature Modules (lazy - initialize on first access)
   ↓
7. UI Module (lazy - ViewModels access feature modules)
```

**ApplicationBootstrap** orchestrates the initialization:
```dart
await ApplicationBootstrap.initialize();
// Core module initialized immediately
// Other modules lazy-load when services accessed
```

---

## Module Responsibilities

### 1. **Core Module** (`core_module.dart`)
**Purpose**: Essential infrastructure required at app startup

**Registrations** (~30):
- Firebase services (Auth, Firestore, Storage, Analytics)
- Repositories (AuthRepository, FirestoreRepository, StorageRepository)
- Utilities (Logger, NetworkService, ConnectivityService)
- Base services (UserService, PermissionService, OfflineService)

**Initialization**: **Eager singletons** (created at startup)

**Why First?**:
- AuthRepository needed for all other repositories (permission checks)
- FirestoreRepository needed for all data access
- Core utilities needed throughout app

---

### 2. **Content Module** (`content_module.dart`)
**Purpose**: Recipe and menu management (core app features)

**Registrations** (~50):
- UnifiedRecipeService, RecipeRepository
- UnifiedMenuService, MenuRepository
- Import services (URLImportService, PhotoImportService, TextImportService)
- Recipe parsers, content extraction
- Search services

**Dependencies**: Core Module only

**Why Separate?**:
- Recipe/menu features are cohesive domain
- Can be developed/tested independently
- No dependencies on social features

---

### 3. **Social Module** (`social_module.dart`)
**Purpose**: Friend connections, sharing, social interactions

**Registrations** (~40):
- UnifiedFriendsService, FriendRequestRepository
- SocialRecipeService, SocialMenuService
- CommentService, RatingService, ShareService
- Group management services
- Friend search and discovery

**Dependencies**: Core Module + Content Module

**Why Separate?**:
- Social features optional (app works without them)
- Separate from core recipe functionality
- Can enable/disable based on user consent

---

### 4. **Messaging Module** (`messaging_module.dart`)
**Purpose**: Real-time messaging and conversations

**Registrations** (~25):
- MessagingService, ConversationRepository
- MessageRepository, NotificationService
- FCM integration, Push notification handling
- Typing indicators, read receipts

**Dependencies**: Core Module + Social Module

**Why Separate?**:
- Messaging is distinct feature
- Heavy FCM dependencies
- Can be disabled for privacy

---

### 5. **Collaboration Module** (`collaboration_module.dart`)
**Purpose**: Real-time collaborative features

**Registrations** (~30):
- UnifiedShoppingService, ShoppingRepository
- Realtime recipe editing services
- Collaborative list management
- Permission coordination
- Optimistic update managers

**Dependencies**: Core Module + Content Module + Social Module

**Why Separate?**:
- Collaboration requires multiple other modules
- Complex real-time synchronization
- High Firestore usage (cost optimization)

---

### 6. **Performance Module** (`performance_module.dart`)
**Purpose**: Optimization, caching, monitoring

**Registrations** (~20):
- CacheService (in-memory caching)
- StartupOptimizationService
- PerformanceMonitoringService
- Image compression services
- Preloading strategies

**Dependencies**: Core Module

**Why Separate?**:
- Cross-cutting concerns
- Can be enabled/disabled for debugging
- Performance tuning independent of features

---

### 7. **UI Module** (`ui_module.dart`)
**Purpose**: ViewModels and UI-specific state

**Registrations** (~60):
- All ViewModels (RecipeViewModel, MenuViewModel, etc.)
- Navigation services
- Theme management
- UI-specific utilities

**Dependencies**: ALL modules (ViewModels access feature services)

**Why Last?**:
- ViewModels depend on all services
- Prevents circular dependencies (ViewModels are leaf nodes)
- Lazy initialization (ViewModels created when views open)

---

## Alternatives Considered

### 1. **Single Module (All Registrations in One File)**
- ❌ **Rejected**: 240+ registrations = 1,200+ lines
- ❌ Unmaintainable
- ❌ Merge conflict nightmare
- ❌ Difficult to navigate
- **Verdict**: Does not scale

### 2. **Layer-Based Modules (Repository/Service/ViewModel)**
```
- repository_module.dart (30 repositories)
- service_module.dart (150 services)
- viewmodel_module.dart (60 ViewModels)
```
- ❌ **Rejected**: No domain cohesion
- ❌ Difficult to understand feature dependencies
- ❌ Can't lazy-load by feature
- ⚠️ Technically correct, but not practical
- **Verdict**: Technically clean but poor developer experience

### 3. **Feature-Based Modules (One Per Feature)**
```
- recipe_module.dart (Recipe + RecipeViewModel + RecipeRepository)
- menu_module.dart (Menu + MenuViewModel + MenuRepository)
- friends_module.dart (Friends + FriendsViewModel + FriendsRepository)
... (50+ modules)
```
- ❌ **Rejected**: Too many modules (50+ files)
- ❌ Many modules would have 2-3 registrations (overhead)
- ❌ Circular dependencies between features
- ⚠️ Good for very large apps (1M+ LOC)
- **Verdict**: Over-engineering for current scale

### 4. **3 Modules (Core/Feature/UI)**
```
- core_module.dart (Core infrastructure)
- feature_module.dart (All features: recipes, social, messaging, collaboration)
- ui_module.dart (All ViewModels)
```
- ❌ **Rejected**: Feature module too large (220+ registrations)
- ❌ No domain boundaries
- ❌ Difficult to understand dependencies
- ⚠️ Simpler than 7 modules, but loses organization benefits
- **Verdict**: Not enough separation

### 5. **10+ Fine-Grained Modules**
```
- core_module, auth_module, storage_module, firestore_module
- recipe_module, menu_module, import_module
- friends_module, share_module, comment_module, rating_module
- messaging_module, notification_module
... (15+ modules)
```
- ❌ **Rejected**: Too granular
- ❌ Difficult to remember which service is in which module
- ❌ More boilerplate than benefit
- **Verdict**: Over-engineering

---

## Consequences

### Positive

✅ **Clear Organization**:
- Easy to find service registrations (7 modules vs 1)
- Domain cohesion (related services together)
- Intuitive naming (Social Module = social features)

✅ **Prevents Circular Dependencies**:
- Module initialization order enforces dependency graph
- Core Module has no dependencies
- UI Module depends on all others (leaf node)
- Clear dependency flow

✅ **Lazy Loading**:
- Feature modules initialize on first access
- Faster app startup (don't initialize all 150 services)
- Memory efficient (unused modules never initialized)

✅ **Maintainability**:
- Smaller files (150-300 lines per module)
- Easier to review and update
- Fewer merge conflicts (team works on different modules)

✅ **Testability**:
- Can test modules independently
- Mock entire modules for integration tests
- Clear module boundaries

✅ **Scalability**:
- Easy to add new services (add to appropriate module)
- Can split modules if they grow too large
- Supports growth to 500+ registrations

### Negative

⚠️ **7 Files Instead of 1**:
- More navigation between files
- Must remember which module contains which service
- **Mitigation**: Clear naming and documentation in DI_SYSTEM.md

⚠️ **Module Dependency Complexity**:
- Must understand dependency graph (which module depends on what)
- Risk of circular dependencies between modules
- **Mitigation**: Clear initialization order documented
- **Mitigation**: ApplicationBootstrap enforces correct order

⚠️ **Potential for Wrong Module Assignment**:
- Developers might register service in wrong module
- Example: Registering social service in Content Module
- **Mitigation**: Code review enforces correct placement
- **Mitigation**: Module purpose documented

⚠️ **Boilerplate for Module Setup**:
- Each module needs initialization method
- ApplicationBootstrap must call all modules
- **Mitigation**: One-time cost, well-documented pattern

---

## Implementation Guidelines

### 1. Module Structure

```dart
// lib/core/di/modules/content_module.dart
class ContentModule {
  static void initialize(GetIt container) {
    // Repositories
    container.registerLazySingleton<RecipeRepository>(
      () => FirebaseRecipeRepository(
        firestore: container<FirestoreRepository>(),
        auth: container<AuthRepository>(),
      ),
    );

    // Services
    container.registerLazySingleton<UnifiedRecipeService>(
      () => UnifiedRecipeService(
        repository: container<RecipeRepository>(),
        userService: container<UserService>(),
      ),
    );
  }
}
```

### 2. ApplicationBootstrap

```dart
class ApplicationBootstrap {
  static Future<void> initialize() async {
    final container = ServiceLocator.instance;

    // 1. Core Module (eager - must be first)
    CoreModule.initialize(container);

    // 2-6. Feature Modules (lazy - order doesn't matter)
    ContentModule.initialize(container);
    SocialModule.initialize(container);
    MessagingModule.initialize(container);
    CollaborationModule.initialize(container);
    PerformanceModule.initialize(container);

    // 7. UI Module (lazy - must be last)
    UIModule.initialize(container);
  }
}
```

### 3. Service Placement Rules

**Core Module**:
- Infrastructure (Auth, Storage, Firestore, Analytics)
- Base utilities (Logger, Network, Connectivity)
- Services with **NO feature dependencies**

**Feature Modules (Content/Social/Messaging/Collaboration)**:
- Domain-specific services and repositories
- Feature-specific workflows
- Services that depend on Core Module

**Performance Module**:
- Cross-cutting concerns (Caching, Monitoring)
- Optimization services

**UI Module**:
- ALL ViewModels
- Navigation services
- UI-specific state management

---

## References

- **Implementation Guide**: [docs/architecture/DI_SYSTEM.md](../architecture/DI_SYSTEM.md)
- **GetIt Decision**: [ADR-002: Use GetIt for Dependency Injection](ADR-002-getit-dependency-injection.md)
- **MVVM Architecture**: [ADR-001: Use MVVM + Repository Pattern](ADR-001-mvvm-repository-pattern.md)

---

## Related ADRs

- [ADR-002: Use GetIt for Dependency Injection](ADR-002-getit-dependency-injection.md) - Foundation for modular DI
- [ADR-001: Use MVVM + Repository Pattern](ADR-001-mvvm-repository-pattern.md) - Architecture that modules support
- [ADR-003: Use Firebase as Backend Platform](ADR-003-firebase-backend-platform.md) - Core Module registers Firebase services
