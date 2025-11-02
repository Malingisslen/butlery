# Skills Index

**Status**: ✅ All 12 Skills Complete (January 2025)

Quick navigation and relationship guide for Butlery's Claude Code skills system.

---

## Quick Navigation

### Foundation Skills
**Core architectural patterns for all development**

| Skill | Purpose | Resources | When to Use |
|-------|---------|-----------|-------------|
| [butlery-architecture](butlery-architecture/SKILL.md) | MVVM + Repository pattern | 5 files | Creating any service, repository, or ViewModel |
| [testing-patterns](testing-patterns/SKILL.md) | Test strategies for all layers | 6 files | Writing tests for any component |
| [firebase-repository-patterns](firebase-repository-patterns/SKILL.md) | BaseFirebaseRepository usage | 3 files | Creating or modifying repositories |

### State & UI Skills
**Patterns for ViewModels and widget development**

| Skill | Purpose | Resources | When to Use |
|-------|---------|-----------|-------------|
| [state-management-patterns](state-management-patterns/SKILL.md) | ChangeNotifier, AsyncOperationMixin | 4 files | Managing ViewModel state |
| [flutter-widget-guidelines](flutter-widget-guidelines/SKILL.md) | Widget composition, LoadingStateBuilder | 4 files | Building UI components |

### Utility Skills
**Code deduplication and standardization**

| Skill | Purpose | Resources | When to Use |
|-------|---------|-----------|-------------|
| [code-deduplication-utilities](code-deduplication-utilities/SKILL.md) | SerializationUtils, extensions, validation | 5 files | Parsing Firestore, error handling, validation |

### Infrastructure Skills
**Advanced patterns and compliance**

| Skill | Purpose | Resources | When to Use |
|-------|---------|-----------|-------------|
| [dependency-injection-patterns](dependency-injection-patterns/SKILL.md) | 7-module DI system | 4 files | Service access, DI setup, testing |
| [gdpr-compliance](gdpr-compliance/SKILL.md) | Articles 7/15/17/30 compliance | 4 files | Consent, data export, deletion, audit logging |
| [realtime-collaboration](realtime-collaboration/SKILL.md) | Real-time services, presence | 5 files | Collaborative features, real-time sync |
| [offline-first-patterns](offline-first-patterns/SKILL.md) | Offline architecture, caching | 5 files | Offline support, sync mechanisms |

### Reference Skills
**Quick reference guides**

| Skill | Purpose | Resources | When to Use |
|-------|---------|-----------|-------------|
| [navigation-routing](navigation-routing/SKILL.md) | Navigation patterns | 1 file | Routing, deep linking, guards |
| [performance-optimization](performance-optimization/SKILL.md) | Performance best practices | 1 file | Optimizing widgets, lists, images |

---

## Skills by Use Case

### Creating New Components

**New Repository**:
1. [firebase-repository-patterns](firebase-repository-patterns/SKILL.md) - Implementation patterns
2. [butlery-architecture](butlery-architecture/SKILL.md) - Architecture context
3. [testing-patterns](testing-patterns/SKILL.md) - Repository testing

**New Service**:
1. [butlery-architecture](butlery-architecture/SKILL.md) - BaseService patterns
2. [code-deduplication-utilities](code-deduplication-utilities/SKILL.md) - ErrorHandlingMixin
3. [dependency-injection-patterns](dependency-injection-patterns/SKILL.md) - DI registration
4. [testing-patterns](testing-patterns/SKILL.md) - Service testing

**New ViewModel**:
1. [state-management-patterns](state-management-patterns/SKILL.md) - State patterns
2. [butlery-architecture](butlery-architecture/SKILL.md) - MVVM architecture
3. [dependency-injection-patterns](dependency-injection-patterns/SKILL.md) - DI registration
4. [testing-patterns](testing-patterns/SKILL.md) - ViewModel testing

**New UI Component**:
1. [flutter-widget-guidelines](flutter-widget-guidelines/SKILL.md) - Widget patterns
2. [state-management-patterns](state-management-patterns/SKILL.md) - Using ViewModels
3. [performance-optimization](performance-optimization/SKILL.md) - Optimization

### Implementing Features

**GDPR Compliance**:
1. [gdpr-compliance](gdpr-compliance/SKILL.md) - All compliance patterns
2. [firebase-repository-patterns](firebase-repository-patterns/SKILL.md) - Audit logging
3. [testing-patterns](testing-patterns/SKILL.md) - Compliance testing

**Real-Time Collaboration**:
1. [realtime-collaboration](realtime-collaboration/SKILL.md) - Real-time patterns
2. [firebase-repository-patterns](firebase-repository-patterns/SKILL.md) - Firestore streams
3. [offline-first-patterns](offline-first-patterns/SKILL.md) - Conflict resolution

**Offline Support**:
1. [offline-first-patterns](offline-first-patterns/SKILL.md) - Offline architecture
2. [realtime-collaboration](realtime-collaboration/SKILL.md) - Sync patterns
3. [firebase-repository-patterns](firebase-repository-patterns/SKILL.md) - Data operations

### Code Quality

**Reducing Boilerplate**:
1. [code-deduplication-utilities](code-deduplication-utilities/SKILL.md) - All utilities
2. [state-management-patterns](state-management-patterns/SKILL.md) - AsyncOperationMixin
3. [butlery-architecture](butlery-architecture/SKILL.md) - BaseService/BaseRepository

**Testing**:
1. [testing-patterns](testing-patterns/SKILL.md) - All test patterns
2. [dependency-injection-patterns](dependency-injection-patterns/SKILL.md) - TestServiceLocator
3. Specific layer skill for implementation details

**Performance**:
1. [performance-optimization](performance-optimization/SKILL.md) - Best practices
2. [flutter-widget-guidelines](flutter-widget-guidelines/SKILL.md) - Widget optimization
3. [offline-first-patterns](offline-first-patterns/SKILL.md) - Caching

---

## Skill Relationships

### Architecture Flow
```
butlery-architecture (MVVM foundation)
    ├─→ firebase-repository-patterns (Data layer)
    ├─→ state-management-patterns (ViewModel layer)
    ├─→ flutter-widget-guidelines (View layer)
    └─→ dependency-injection-patterns (DI system)
```

### Testing Flow
```
testing-patterns (Test strategies)
    ├─→ butlery-architecture (What to test)
    ├─→ firebase-repository-patterns (Repository tests)
    ├─→ state-management-patterns (ViewModel tests)
    └─→ flutter-widget-guidelines (Widget tests)
```

### Utility Flow
```
code-deduplication-utilities (Utilities)
    ├─→ butlery-architecture (BaseService uses ErrorHandlingMixin)
    ├─→ state-management-patterns (AsyncOperationMixin)
    └─→ firebase-repository-patterns (SerializationUtils)
```

### Feature Flow
```
Feature Implementation
    ├─→ butlery-architecture (Overall structure)
    ├─→ firebase-repository-patterns (Data access)
    ├─→ state-management-patterns (State management)
    ├─→ flutter-widget-guidelines (UI)
    ├─→ dependency-injection-patterns (Wire everything)
    ├─→ testing-patterns (Verify everything)
    └─→ Optional:
        ├─→ gdpr-compliance (If handling personal data)
        ├─→ realtime-collaboration (If collaborative)
        ├─→ offline-first-patterns (If offline support)
        └─→ navigation-routing (If new routes)
```

---

## Skill Dependency Matrix

| Skill | Depends On | Used By |
|-------|------------|---------|
| **butlery-architecture** | - | All skills |
| **testing-patterns** | butlery-architecture | All skills (for testing) |
| **firebase-repository-patterns** | butlery-architecture | Services, ViewModels |
| **state-management-patterns** | butlery-architecture | Views, testing-patterns |
| **flutter-widget-guidelines** | state-management-patterns | - |
| **code-deduplication-utilities** | - | butlery-architecture, firebase-repository-patterns |
| **dependency-injection-patterns** | butlery-architecture | All layers |
| **gdpr-compliance** | firebase-repository-patterns | Services handling personal data |
| **realtime-collaboration** | firebase-repository-patterns | Real-time features |
| **offline-first-patterns** | firebase-repository-patterns | Offline features |
| **navigation-routing** | flutter-widget-guidelines | Navigation implementation |
| **performance-optimization** | flutter-widget-guidelines | Performance-critical code |

---

## Skills by Complexity

### Beginner-Friendly
**Start here if new to Butlery patterns**

1. [navigation-routing](navigation-routing/SKILL.md) - Standard Flutter patterns (1 file)
2. [performance-optimization](performance-optimization/SKILL.md) - Best practices (1 file)
3. [flutter-widget-guidelines](flutter-widget-guidelines/SKILL.md) - Widget patterns (5 files)

### Intermediate
**Core development patterns**

4. [firebase-repository-patterns](firebase-repository-patterns/SKILL.md) - Repository pattern (4 files)
5. [state-management-patterns](state-management-patterns/SKILL.md) - State management (5 files)
6. [testing-patterns](testing-patterns/SKILL.md) - Testing strategies (7 files)
7. [code-deduplication-utilities](code-deduplication-utilities/SKILL.md) - Utilities (6 files)

### Advanced
**Complex architectural patterns**

8. [butlery-architecture](butlery-architecture/SKILL.md) - Full MVVM architecture (6 files)
9. [dependency-injection-patterns](dependency-injection-patterns/SKILL.md) - DI system (5 files)
10. [gdpr-compliance](gdpr-compliance/SKILL.md) - GDPR compliance (5 files)
11. [realtime-collaboration](realtime-collaboration/SKILL.md) - Real-time patterns (6 files)
12. [offline-first-patterns](offline-first-patterns/SKILL.md) - Offline architecture (6 files)

---

## Learning Paths

### Path 1: Full-Stack Feature Development
**Goal**: Build a complete feature from repository to UI

1. [butlery-architecture](butlery-architecture/SKILL.md) - Understand MVVM layers
2. [firebase-repository-patterns](firebase-repository-patterns/SKILL.md) - Create repository
3. [butlery-architecture](butlery-architecture/SKILL.md) - Create service (BaseService)
4. [state-management-patterns](state-management-patterns/SKILL.md) - Create ViewModel
5. [flutter-widget-guidelines](flutter-widget-guidelines/SKILL.md) - Build UI
6. [dependency-injection-patterns](dependency-injection-patterns/SKILL.md) - Wire DI
7. [testing-patterns](testing-patterns/SKILL.md) - Write tests

### Path 2: Testing Specialist
**Goal**: Comprehensive testing knowledge

1. [testing-patterns](testing-patterns/SKILL.md) - Overall test strategy
2. [firebase-repository-patterns](firebase-repository-patterns/SKILL.md) - Repository testing
3. [state-management-patterns](state-management-patterns/SKILL.md) - ViewModel testing
4. [flutter-widget-guidelines](flutter-widget-guidelines/SKILL.md) - Widget testing
5. [dependency-injection-patterns](dependency-injection-patterns/SKILL.md) - TestServiceLocator
6. [gdpr-compliance](gdpr-compliance/SKILL.md) - Compliance testing

### Path 3: Code Quality & Migration
**Goal**: Reduce boilerplate and improve code quality

1. [code-deduplication-utilities](code-deduplication-utilities/SKILL.md) - All utilities
2. [butlery-architecture](butlery-architecture/SKILL.md) - BaseService migration
3. [firebase-repository-patterns](firebase-repository-patterns/SKILL.md) - SerializationUtils
4. [state-management-patterns](state-management-patterns/SKILL.md) - AsyncOperationMixin
5. [testing-patterns](testing-patterns/SKILL.md) - Test migrated code

### Path 4: Advanced Features
**Goal**: GDPR, real-time, offline support

1. [butlery-architecture](butlery-architecture/SKILL.md) - Architecture foundation
2. [firebase-repository-patterns](firebase-repository-patterns/SKILL.md) - Advanced patterns
3. [gdpr-compliance](gdpr-compliance/SKILL.md) - GDPR compliance
4. [realtime-collaboration](realtime-collaboration/SKILL.md) - Real-time features
5. [offline-first-patterns](offline-first-patterns/SKILL.md) - Offline support
6. [testing-patterns](testing-patterns/SKILL.md) - Integration testing

---

## Skills by File Count

**Comprehensive Skills** (5-7 resource files):
- testing-patterns (7 files)
- realtime-collaboration (6 files)
- offline-first-patterns (6 files)
- butlery-architecture (6 files)
- code-deduplication-utilities (6 files)

**Moderate Skills** (3-5 resource files):
- state-management-patterns (5 files)
- dependency-injection-patterns (5 files)
- gdpr-compliance (5 files)
- flutter-widget-guidelines (5 files)
- firebase-repository-patterns (4 files)

**Reference Skills** (1 file):
- navigation-routing (1 file)
- performance-optimization (1 file)

---

## Quick Lookup by Keyword

### A-D
- **Architecture** → [butlery-architecture](butlery-architecture/SKILL.md)
- **AsyncOperationMixin** → [state-management-patterns](state-management-patterns/SKILL.md), [code-deduplication-utilities](code-deduplication-utilities/SKILL.md)
- **Audit Logging** → [gdpr-compliance](gdpr-compliance/SKILL.md), [firebase-repository-patterns](firebase-repository-patterns/SKILL.md)
- **BaseFirebaseRepository** → [firebase-repository-patterns](firebase-repository-patterns/SKILL.md)
- **BaseService** → [butlery-architecture](butlery-architecture/SKILL.md), [code-deduplication-utilities](code-deduplication-utilities/SKILL.md)
- **Caching** → [offline-first-patterns](offline-first-patterns/SKILL.md), [performance-optimization](performance-optimization/SKILL.md)
- **ChangeNotifier** → [state-management-patterns](state-management-patterns/SKILL.md)
- **Consent** → [gdpr-compliance](gdpr-compliance/SKILL.md)
- **Conflict Resolution** → [realtime-collaboration](realtime-collaboration/SKILL.md), [offline-first-patterns](offline-first-patterns/SKILL.md)
- **Data Export** → [gdpr-compliance](gdpr-compliance/SKILL.md)
- **Deep Linking** → [navigation-routing](navigation-routing/SKILL.md)
- **Dependency Injection** → [dependency-injection-patterns](dependency-injection-patterns/SKILL.md), [butlery-architecture](butlery-architecture/SKILL.md)

### E-M
- **ErrorHandlingMixin** → [code-deduplication-utilities](code-deduplication-utilities/SKILL.md), [butlery-architecture](butlery-architecture/SKILL.md)
- **Extensions** → [code-deduplication-utilities](code-deduplication-utilities/SKILL.md)
- **FakeFirebaseFirestore** → [testing-patterns](testing-patterns/SKILL.md)
- **Firestore** → [firebase-repository-patterns](firebase-repository-patterns/SKILL.md)
- **GDPR** → [gdpr-compliance](gdpr-compliance/SKILL.md)
- **Integration Testing** → [testing-patterns](testing-patterns/SKILL.md)
- **LoadingStateBuilder** → [flutter-widget-guidelines](flutter-widget-guidelines/SKILL.md)
- **MVVM** → [butlery-architecture](butlery-architecture/SKILL.md)

### N-S
- **Navigation** → [navigation-routing](navigation-routing/SKILL.md)
- **Offline** → [offline-first-patterns](offline-first-patterns/SKILL.md)
- **OfflineService** → [offline-first-patterns](offline-first-patterns/SKILL.md)
- **Performance** → [performance-optimization](performance-optimization/SKILL.md)
- **Permission Validation** → [firebase-repository-patterns](firebase-repository-patterns/SKILL.md)
- **Presence Tracking** → [realtime-collaboration](realtime-collaboration/SKILL.md)
- **Provider** → [state-management-patterns](state-management-patterns/SKILL.md)
- **Real-time** → [realtime-collaboration](realtime-collaboration/SKILL.md)
- **Repository Pattern** → [firebase-repository-patterns](firebase-repository-patterns/SKILL.md), [butlery-architecture](butlery-architecture/SKILL.md)
- **SerializationUtils** → [code-deduplication-utilities](code-deduplication-utilities/SKILL.md)
- **Service Pattern** → [butlery-architecture](butlery-architecture/SKILL.md)
- **ServiceLocator** → [dependency-injection-patterns](dependency-injection-patterns/SKILL.md)
- **StateWidget** → [flutter-widget-guidelines](flutter-widget-guidelines/SKILL.md)
- **Streams** → [firebase-repository-patterns](firebase-repository-patterns/SKILL.md), [realtime-collaboration](realtime-collaboration/SKILL.md)
- **Sync** → [offline-first-patterns](offline-first-patterns/SKILL.md), [realtime-collaboration](realtime-collaboration/SKILL.md)

### T-Z
- **Testing** → [testing-patterns](testing-patterns/SKILL.md)
- **TestServiceLocator** → [dependency-injection-patterns](dependency-injection-patterns/SKILL.md), [testing-patterns](testing-patterns/SKILL.md)
- **Validation** → [code-deduplication-utilities](code-deduplication-utilities/SKILL.md)
- **ValidationUtils** → [code-deduplication-utilities](code-deduplication-utilities/SKILL.md)
- **ViewModel** → [state-management-patterns](state-management-patterns/SKILL.md), [butlery-architecture](butlery-architecture/SKILL.md)
- **Widget** → [flutter-widget-guidelines](flutter-widget-guidelines/SKILL.md)

---

## Total Documentation

| Category | Skills | Files | Approx. Lines |
|----------|--------|-------|---------------|
| Foundation | 3 | 17 | ~8,500 |
| State & UI | 2 | 10 | ~5,000 |
| Utility | 1 | 6 | ~3,500 |
| Infrastructure | 4 | 19 | ~10,000 |
| Reference | 2 | 2 | ~700 |
| **Total** | **12** | **54** | **~27,700** |

Plus 27 additional resource files in comprehensive skills = **81 total markdown files**.

---

## How to Use This Index

### Finding a Skill
1. **By category** - Use Quick Navigation tables
2. **By use case** - Check "Skills by Use Case" section
3. **By keyword** - Use Quick Lookup section
4. **By complexity** - Check "Skills by Complexity" section

### Learning a Pattern
1. **Choose learning path** - See "Learning Paths" section
2. **Follow dependencies** - Check "Skill Relationships" diagram
3. **Start with SKILL.md** - Get overview
4. **Dive into resources** - For detailed implementation

### Building a Feature
1. **Identify requirements** - What layers needed?
2. **Check use case** - Find relevant skill combination
3. **Follow flow** - See "Feature Flow" diagram
4. **Reference related skills** - Each skill links to complementary skills

---

## Maintenance

**Adding New Skills**:
1. Create skill directory in `.claude/skills/`
2. Add to this index in appropriate category
3. Update Quick Navigation table
4. Add to Quick Lookup by keyword
5. Update Total Documentation table

**Updating Skills**:
- Update file counts if resource files added/removed
- Update line counts if significant changes
- Add new keywords to Quick Lookup
- Update learning paths if new patterns introduced

---

**Created**: 2025-01-31
**Last Updated**: 2025-01-31
**Status**: ✅ Complete Index for All 12 Skills
**Maintained By**: Butlery Development Team
