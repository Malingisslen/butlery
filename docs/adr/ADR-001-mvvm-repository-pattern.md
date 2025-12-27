# ADR-001: Use MVVM + Repository Pattern

**Status**: Accepted
**Date**: 2024-Q3 (Retroactive documentation 2025-11-17)
**Deciders**: Core development team
**Technical Story**: Initial architecture design for Butlery recipe management app

---

## Context

Butlery is a comprehensive recipe management and meal planning Flutter application with Firebase backend. The application requires:

- **Clean separation of concerns** between UI, business logic, and data access
- **Testability** at every layer (UI components, business logic, data access)
- **Scalability** to support 60+ views, 60+ ViewModels, 150+ services, 30+ repositories
- **Maintainability** for a growing codebase (669 Dart files)
- **Firebase integration** with proper abstraction layer
- **Social features** (friends, messaging, collaboration) requiring complex state management
- **Real-time updates** from Firebase Firestore
- **Offline support** with local caching

**Key Constraints**:
- Flutter framework (widget-based UI)
- Firebase as backend platform (Firestore, Auth, Storage, FCM)
- Team familiar with object-oriented patterns
- Need for rapid feature development while maintaining quality

---

## Decision

**We will implement MVVM (Model-View-ViewModel) pattern combined with Repository Pattern as a 4-layer architecture:**

```
┌──────────┐  observes   ┌──────────────┐  uses   ┌────────────┐
│   View   │ ──────────▶ │  ViewModel   │ ──────▶ │  Service   │
└──────────┘             └──────────────┘         └────────────┘
(Widgets)                (ChangeNotifier)                │ uses
                                                   ┌─────▼──────┐
                                                   │ Repository │
                                                   └────────────┘
                                                         │ implements
                                                   ┌─────▼──────┐
                                                   │  Firebase  │
                                                   └────────────┘
```

**Layer Responsibilities**:

1. **View Layer (60 files)**:
   - Flutter widgets (Stateless/StatefulWidget)
   - UI rendering and user interactions
   - Observes ViewModel state via Provider
   - **No business logic**, **no direct service access**

2. **ViewModel Layer (60 files)**:
   - State management with ChangeNotifier
   - UI state (loading, error, data)
   - Coordinates service calls
   - Input validation and formatting
   - **No direct Firebase access**, **no direct repository access**

3. **Service Layer (150 files)**:
   - Business logic orchestration
   - Multi-repository coordination
   - Complex workflows (e.g., account deletion across 14 collections)
   - Caching and offline strategies
   - **No UI concerns**, **uses repositories for data access**

4. **Repository Layer (30 files)**:
   - Firebase Firestore CRUD operations
   - Permission validation and security
   - Audit logging (GDPR compliance)
   - Real-time streams
   - **Single responsibility per repository** (RecipeRepository, UserRepository, etc.)

---

## Alternatives Considered

### 1. **MVC (Model-View-Controller)**
- ❌ **Rejected**: Controllers become bloated "god objects" in Flutter
- ❌ No clear separation between UI logic and business logic
- ❌ Difficult to test UI state independently
- ❌ Not idiomatic for reactive Flutter development

### 2. **Redux (Unidirectional Data Flow)**
- ❌ **Rejected**: Excessive boilerplate for actions, reducers, middleware
- ❌ Steep learning curve for team
- ❌ Overkill for most screens (many have simple local state)
- ⚠️ Better for apps with complex shared state (not our primary use case)

### 3. **BLoC (Business Logic Component)**
- ❌ **Rejected**: Requires extensive stream management
- ❌ More complex than needed for our use cases
- ❌ Steeper learning curve
- ⚠️ Excellent for complex event-driven workflows (but adds complexity we don't need)

### 4. **Clean Architecture (Uncle Bob's 5 layers)**
- ❌ **Rejected**: Too many layers for Flutter mobile app
- ❌ Excessive abstraction (Use Cases, Entities, Gateways, etc.)
- ❌ Slower development velocity
- ⚠️ Good for large enterprise apps, but overkill for our scope

### 5. **Repository Pattern Only (No ViewModel)**
- ❌ **Rejected**: Views directly access services
- ❌ No clear place for UI state management
- ❌ Difficult to test UI logic
- ❌ Violates separation of concerns

---

## Consequences

### Positive

✅ **Excellent Testability**:
- Each layer can be unit tested independently
- ViewModels testable without widgets (445 tests, 66.5% coverage)
- Services testable with mocked repositories
- Repositories testable with FakeFirestore

✅ **Clear Separation of Concerns**:
- Views: Pure UI rendering
- ViewModels: UI state management
- Services: Business logic
- Repositories: Data access
- Single Responsibility Principle enforced

✅ **Scalability**:
- Successfully scaled to 60 ViewModels, 150 services, 30 repositories
- Easy to add new features (add ViewModel → Service → Repository)
- No architectural bottlenecks

✅ **Maintainability**:
- Easy to locate bugs (clear layer responsibility)
- Simple to refactor (change one layer without affecting others)
- New developers onboard quickly

✅ **Firebase Abstraction**:
- Repository layer isolates Firebase dependency
- Easy to switch to different backend (theoretically)
- Prevents Firebase coupling throughout codebase

✅ **Reactive UI**:
- ViewModels notify Views of state changes automatically
- Provider pattern integrates seamlessly
- Minimal boilerplate compared to Redux/BLoC

✅ **Offline Support**:
- Service layer handles caching logic
- Repository layer manages Firestore offline persistence
- Clear separation of concerns for offline strategies

### Negative

⚠️ **Learning Curve**:
- Developers must understand 4-layer architecture
- Easy to violate boundaries (Views calling Services directly)
- Requires discipline and code review

⚠️ **More Files**:
- 60 ViewModels + 150 Services + 30 Repositories = 240+ files for logic
- Can feel verbose for simple CRUD screens
- Directory structure must be well-organized

⚠️ **Provider Boilerplate**:
- Each ViewModel needs Provider registration
- Dependency injection setup required (mitigated with GetIt - see ADR-002)

⚠️ **Potential Over-Engineering**:
- Simple screens (Settings, About) might not need full ViewModel
- Some screens could be StatefulWidgets with local state
- Trade-off: Consistency vs. pragmatism

⚠️ **Service Layer Complexity**:
- Some services coordinate 5-10 repositories (e.g., AccountDeletionService)
- Risk of service bloat (mitigated with 500-line limit - see ADR-005)

---

## Implementation Guidelines

1. **Views MUST**:
   - Only call ViewModel methods
   - Use Provider to access ViewModels
   - Never access Services or Repositories directly

2. **ViewModels MUST**:
   - Extend ChangeNotifier
   - Use Services for business logic
   - Never access Repositories directly
   - Stay under 500 lines (see ADR-005)

3. **Services MUST**:
   - Use Repositories for data access
   - Coordinate multi-repository operations
   - Never access Firebase directly (use repositories)

4. **Repositories MUST**:
   - Handle only one data type (Recipe, User, etc.)
   - Implement security validation
   - Include audit logging for GDPR

---

## References

- **Project Guidelines**: [CLAUDE.md](../../CLAUDE.md)
- **External**: [Microsoft MVVM Documentation](https://learn.microsoft.com/en-us/xamarin/xamarin-forms/enterprise-application-patterns/mvvm)
- **External**: [Flutter Architecture Samples](https://github.com/brianegan/flutter_architecture_samples)

---

## Related ADRs

- [ADR-002: Use GetIt for Dependency Injection](ADR-002-getit-dependency-injection.md) - How we wire up ViewModels and Services
- [ADR-003: Use Firebase as Backend Platform](ADR-003-firebase-backend-platform.md) - Why Repository layer connects to Firebase
- [ADR-005: Enforce 500-Line File Size Limit](ADR-005-500-line-file-limit.md) - Prevents bloated ViewModels and Services
