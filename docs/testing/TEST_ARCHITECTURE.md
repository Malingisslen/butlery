# 🏆 Gold Standard Test Architecture

## Overview
This test system implements industry best practices for Flutter testing, providing a maintainable, scalable, and developer-friendly testing infrastructure for the Butlery application.

## 📐 Architecture Principles

### Test Pyramid Distribution
- **60% Unit Tests**: Business logic, models, services, repositories
- **30% Widget Tests**: UI components, screens, interactions
- **10% Integration Tests**: Critical user journeys, E2E flows

### Key Patterns
1. **AAA Pattern**: Arrange, Act, Assert for all tests
2. **Builder Pattern**: Flexible test data creation
3. **Configuration over Stubbing**: State management via setters
4. **DI Pattern Matching**: Mirrors production ServiceLocator

## 📁 Directory Structure

```
test/
├── infrastructure/          # Test foundation (NEW)
│   ├── base/               # Base test classes
│   │   ├── base_test.dart
│   │   ├── base_unit_test.dart
│   │   ├── base_widget_test.dart
│   │   └── base_integration_test.dart
│   ├── di/                 # Dependency injection
│   │   └── test_service_locator.dart
│   ├── factories/          # Mock and data factories
│   │   ├── mock_factory.dart
│   │   └── test_data_builders.dart
│   └── extensions/         # Test extensions
├── unit/                   # Unit tests (60%)
│   ├── models/
│   ├── services/
│   ├── repositories/
│   ├── viewmodels/
│   └── utils/
├── widget/                 # Widget tests (30%)
│   ├── screens/
│   ├── components/
│   └── dialogs/
├── integration/            # Integration tests (10%)
│   ├── features/
│   ├── api/
│   ├── e2e/
│   └── repositories/       # Complex Firebase query tests (see note below)
├── fixtures/               # Test data files
│   ├── json/
│   └── models/
├── golden/                 # Visual regression
│   └── screenshots/
└── mocks/                  # Mock implementations
    ├── generated/
    └── manual/
```

## 🛠️ Core Components

### 1. Base Test Classes

#### BaseTest
Foundation for all tests, provides:
- Service locator initialization
- Common setup/teardown
- Mock registration helpers

```dart
class MyTest {
  setUp(() async {
    await BaseTest.setup();
  });
  
  tearDown(() async {
    await BaseTest.teardown();
  });
}
```

#### BaseUnitTest
Extends BaseTest with unit test specifics:
- AAA pattern support via clear comments
- Automatic mock reset between tests
- Verification helpers

```dart
test('should do something', () async {
  await BaseUnitTest.setupUnit();
  
  // Arrange
  final mock = MockService();
  mock.setServiceState(data: testData);
  
  // Act
  final result = await service.doSomething();
  
  // Assert
  expect(result, isNotNull);
});
```

#### BaseWidgetTest
Widget test infrastructure:
- Automatic widget wrapping
- Theme injection
- Swedish locale defaults
- Interaction helpers

```dart
BaseWidgetTest.testWidget(
  'renders correctly',
  (tester, context) async {
    await context.pumpWidget(MyWidget());
    expect(find.text('Hello'), findsOneWidget);
  },
);
```

#### BaseIntegrationTest
Full app testing:
- Journey step execution
- Navigation tracking
- Screenshot capabilities

```dart
BaseIntegrationTest.testUserJourney(
  'Complete recipe creation',
  [
    CommonJourneySteps.login(),
    CommonJourneySteps.navigateTo('Recipes', '/recipes'),
    CommonJourneySteps.tapButton('Create Recipe'),
    // ... more steps
  ],
);
```

### 2. Test Service Locator

Mirrors production `ServiceLocator.get<T>()` pattern:

```dart
// In production
final authService = ServiceLocator.get<AuthService>();

// In tests (identical pattern)
final authService = ServiceLocator.get<AuthService>();
```

Features:
- Automatic mock registration
- Test scenario configurations
- State management between tests

### 3. Mock Factory

Centralized mock creation with configuration pattern:

```dart
final authService = MockFactory.createAuthService(
  isAuthenticated: true,
  userId: 'test_user_123',
);

final recipeService = MockFactory.createUnifiedRecipeService(
  personalRecipes: [recipe1, recipe2],
  isInitialized: true,
);
```

**Key Pattern**: Configuration over stubbing
```dart
// ✅ GOOD - Use configuration
mock.setAuthState(isAuthenticated: true);

// ❌ BAD - Don't stub concrete getters
when(() => mock.isAuthenticated).thenReturn(true);
```

### 4. Test Data Builders

Builder pattern with Swedish defaults:

```dart
// Basic usage
final recipe = RecipeBuilder()
  .withTitle('My Recipe')
  .withTime(30)
  .asFavorite()
  .build();

// Swedish defaults
final breakfast = RecipeBuilder()
  .asSwedishBreakfast()  // Havregrynsgröt
  .build();

final dinner = RecipeBuilder()
  .asSwedishDinner()      // Laxpudding
  .build();

final fika = RecipeBuilder()
  .asSwedishFika()        // Kanelbullar
  .build();
```

Multiple object creation:
```dart
final recipes = RecipeBuilder()
  .withCategory('Lunch')
  .buildMany(5);  // Creates 5 recipes with unique IDs
```

## 🎯 Usage Examples

### Unit Test Example

```dart
void main() {
  group('RecipeService', () {
    late RecipeService service;
    late MockRecipeRepository mockRepo;
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      mockRepo = ServiceLocator.get<RecipeRepository>();
      service = RecipeService(repository: mockRepo);
    });
    
    tearDown(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    test('creates recipe successfully', () async {
      // Arrange
      final recipe = RecipeBuilder()
        .withTitle('Test Recipe')
        .build();
      mockRepo.setRecipes([recipe]);
      
      // Act
      final result = await service.createRecipe(recipe);
      
      // Assert
      expect(result, isNotNull);
      expect(result.id, isNotEmpty);
    });
  });
}
```

### Widget Test Example

```dart
void main() {
  BaseWidgetTest.groupWidget('RecipeCard', () {
    BaseWidgetTest.testWidget(
      'displays recipe information',
      (tester, context) async {
        // Arrange
        final recipe = RecipeBuilder()
          .withTitle('Köttbullar')
          .withTime(45)
          .build();
        
        // Act
        await context.pumpWidget(
          RecipeCard(recipe: recipe),
        );
        
        // Assert
        expect(find.text('Köttbullar'), findsOneWidget);
        expect(find.text('45 min'), findsOneWidget);
      },
    );
  });
}
```

### Integration Test Example

```dart
void main() {
  BaseIntegrationTest.groupIntegration('Recipe Creation Flow', () {
    BaseIntegrationTest.testUserJourney(
      'user creates and shares recipe',
      [
        JourneyStep(
          description: 'User logs in',
          execute: (tester, context) async {
            await context.performLogin(
              email: 'test@example.com',
              password: 'password123',
            );
          },
        ),
        JourneyStep(
          description: 'Navigate to recipes',
          execute: (tester, context) async {
            await tester.tap(find.byIcon(Icons.restaurant_menu));
            await tester.pumpAndSettle();
          },
        ),
        JourneyStep(
          description: 'Create new recipe',
          execute: (tester, context) async {
            await tester.tap(find.byIcon(Icons.add));
            await tester.pumpAndSettle();
            
            await tester.enterText(
              find.byKey(Key('recipe_title')),
              'Pannkakor',
            );
            
            await tester.tap(find.text('Save'));
            await tester.pumpAndSettle();
          },
        ),
      ],
    );
  });
}
```

## 🔧 Configuration

### Test Scenarios
Quick configurations for common scenarios:

```dart
// Configure for authenticated user
TestServiceLocator.configureForScenario(TestScenario.authenticated);

// Configure for offline mode
TestServiceLocator.configureForScenario(TestScenario.offline);

// Configure for error testing
TestServiceLocator.configureForScenario(TestScenario.error);
```

### Custom Mock Registration
Override default mocks for specific tests:

```dart
setUp(() async {
  await TestServiceLocator.initialize();
  
  // Override with custom mock
  final customAuthService = MockAuthService();
  customAuthService.setAuthState(/* custom state */);
  TestServiceLocator.registerMock(customAuthService);
});
```

## 📊 Coverage Goals

| Component | Target | Priority |
|-----------|--------|----------|
| Models | 100% | High |
| Services | 90% | High |
| Repositories | 90% | High |
| ViewModels | 85% | High |
| Utilities | 100% | Medium |
| UI Components | 80% | Medium |
| Screens | 70% | Low |
| Integration | Critical paths | High |

## ✅ Best Practices

### DO:
- ✅ Use builder pattern for test data
- ✅ Configure mocks via setter methods
- ✅ Follow AAA pattern
- ✅ Test behavior, not implementation
- ✅ Use Swedish test data for realism
- ✅ Keep tests independent
- ✅ Use descriptive test names

### DON'T:
- ❌ Stub concrete getters on mocks
- ❌ Use real Firebase services
- ❌ Create interdependent tests
- ❌ Test private methods
- ❌ Use magic numbers/strings
- ❌ Ignore flaky tests
- ❌ Mix test concerns

## 🚀 Getting Started

1. **Initialize test environment**:
```dart
await TestServiceLocator.initialize();
```

2. **Create test data**:
```dart
final recipe = RecipeBuilder().asSwedishDinner().build();
final user = UserBuilder().asSwedishUser().build();
```

3. **Get mocked services**:
```dart
final authService = ServiceLocator.get<AuthService>();
```

4. **Write test using base classes**:
```dart
BaseUnitTest.testUnit('my test', (context) async {
  // Your test here
});
```

## 🔍 Troubleshooting

### Common Issues

**Issue**: "TestServiceLocator not initialized"
```dart
// Solution: Add to setUp()
await TestServiceLocator.initialize();
```

**Issue**: Mock not resetting between tests
```dart
// Solution: Use BaseUnitTest which handles this
BaseUnitTest.setupUnit(); // Automatically resets mocks
```

**Issue**: Widget test needs providers
```dart
// Solution: Use wrapWithProviders
await context.pumpWithProviders(
  MyWidget(),
  providers: [/* your providers */],
);
```

## 📈 Metrics

- **Test Execution**: <5 minutes for full suite
- **Coverage**: 90%+ for critical paths
- **Reliability**: 0 flaky tests
- **Maintainability**: Clear patterns, easy to add tests

## 🚨 Critical Lessons Learned

### Infrastructure Issues to Avoid

1. **Never place base classes in test paths**
   - Files in `test/` without `main()` cause compilation errors
   - Always use `test/infrastructure/helpers/` for utilities

2. **Delete legacy test files completely**
   - Old backups in `test/legacy_archive/` break compilation
   - Remove completely: `rm -rf test/legacy_archive`

### JSON & Serialization

1. **Always check production JSON structure first**
   ```dart
   // ❌ WRONG - Assuming flat structure
   expect(exportedData.first['id'], equals(recipe.id));
   
   // ✅ CORRECT - Recipe has nested 'core' structure
   expect(exportedData.first['core']['id'], equals(recipe.core.id));
   ```

2. **Never assume toJson/fromJson formats**
   - Always read the actual serialization code
   - Check for nested structures like `core`, `socialData`, etc.

### Async & Mock Patterns

1. **Always stub ALL async methods**
   ```dart
   // ❌ Forgetting causes: Null is not a subtype of Future<List>
   when(() => mock.getAllKeys()).thenAnswer((_) async => <String>[]);
   when(() => mock.delete(any())).thenAnswer((_) async => true);
   ```

2. **Account for multiple method calls**
   ```dart
   // Check production code for all call sites
   // Constructor might call once, method might call again
   verify(() => mock.setUser(any())).called(2); // Not 1!
   ```

3. **Avoid delays in tests**
   ```dart
   // ❌ BAD
   await Future.delayed(Duration(seconds: 2));
   
   // ✅ GOOD - Only for stream events
   await Future.delayed(Duration(milliseconds: 100));
   ```

## 🔧 Quick Reference

### Commands
```bash
# Run tests (Windows Flutter via WSL)
cmd.exe /c "flutter test"
cmd.exe /c "flutter test test/unit/services/auth_service_test.dart"
cmd.exe /c "flutter analyze"

# Check for issues
ls test/legacy_archive 2>/dev/null && echo "⚠️ Delete legacy!" || echo "✅ Clean"
```

### Golden Rules
1. **"Always check production code first"**
2. **"Stub everything async"**
3. **"Use configuration over stubbing"**
4. **"Zero analyzer issues always"**
5. **"Never use TestContext - use simple AAA comments"**

## 📊 Current Test System Status (December 2024)

### ✅ Completed Refactoring
- **100% Stubbing Violations Fixed**: All tests now use configuration methods instead of stubbing concrete getters
- **Centralized Mock System**: 24 production mocks in `production_mocks.dart`
- **Test Infrastructure Complete**: Base classes, factories, and service locator fully implemented
- **AAA Pattern Standardized**: All tests use simple comment markers (// Arrange, // Act, // Assert)
- **Configuration Pattern Established**: All mocks use setter methods for state management

### 🎯 Mock System Architecture

#### Production Mocks (production_mocks.dart)
Currently contains 24 centralized mocks including:
- Core services (Auth, Recipe, User, Permission)
- ViewModels (Auth, Recipe, Friends)
- Repositories (Auth, Recipe, User, Shared)
- Managers (Import, Menu, Comments)
- Storage (JsonCache, Hive boxes)

#### Mock Usage Pattern
```dart
// ✅ CORRECT - Configuration methods for state
mockAuthService.setAuthState(
  userId: 'test_123',
  isAuthenticated: true,
  user: MockFactory.createMockUser()
);

// ❌ WRONG - Never stub concrete getters
when(() => mockAuthService.currentUserId).thenReturn('test_123');
```

### 📈 Test Metrics
- **Unit Tests**: 200+ passing tests
- **Stubbing Violations**: 0 (down from 46)
- **Centralized Mocks**: 26 (eliminated all duplicates)
- **Test Files Updated**: 25+ files refactored to gold standard
- **Duplicate Mocks Removed**: 100% complete

### ✅ Completed Mock Centralization
1. **MockPersonalRecipeOperations** - Centralized (removed 5 duplicates)
2. **MockDIContainer** - Centralized (removed 10 duplicates)
3. **MockUnifiedFriendsService** - Already centralized (removed remaining duplicates)

### 🔄 Remaining Work

#### Critical Test Coverage Gaps (In True Dependency Order)
1. **Repositories**: Now 7 of 52 tested (87% gap!) - **CRITICAL PRIORITY**
   - Data layer is the true foundation - everything depends on it
   - Existing: auth, recipe, shopping, user, collaborative, firestore, **base_firebase** repositories
   - Missing: 45 repository tests for Firebase and interface implementations
   - Progress: Added FirestoreRepository and BaseFirebaseRepository tests (core foundations)
2. **Services**: 36 of 46 tested (22% gap) - SECOND PRIORITY
   - Business logic layer depends on repositories
   - Missing: 10 service tests need to be identified and added
3. **ViewModels**: Only 5 of 52 tested (90% gap!) - THIRD PRIORITY
   - Missing: ChatViewModel, RecipeFormViewModel, RecipeDetailViewModel, and 44 others
   - Easier to test once repository and service mocks are comprehensive

#### Following Test Pyramid and True Dependency Order
1. **Complete Unit Tests Bottom-Up** (currently ~20% overall coverage)
   - First: Add 47 missing Repository tests (data layer)
   - Then: Add 10 missing Service tests (business logic)
   - Finally: Add 47 missing ViewModel tests (orchestration)
2. **Then Widget Tests** (0% coverage)
   - RecipeCard, AuthScreen components
3. **Finally Integration Tests** (0% coverage)
   - Auth flow, Recipe CRUD flow
   - **CRITICAL**: Complex Firebase queries (see Integration Test Requirements below)
4. **External Library Mocks** (Firebase, SharedPreferences, ImagePicker)

#### Proposed Mock Organization
```
test/infrastructure/mocks/
├── production_mocks.dart    # Core app services (existing)
├── external_mocks.dart      # Platform/third-party mocks
├── firebase_mocks.dart      # Firebase-specific mocks
├── operations_mocks.dart    # Operations interfaces
└── import_mocks.dart        # Import strategy mocks
```

### 🔑 Key Implementation Rules

1. **Service Access Pattern**
   ```dart
   // Production & Test use identical pattern
   final service = ServiceLocator.get<UnifiedRecipeService>();
   ```

2. **Mock Configuration Pattern**
   ```dart
   // All mocks support configuration methods
   mockService.setRecipeState(
     recipes: [recipe1, recipe2],
     isLoading: false,
     error: null
   );
   ```

3. **Test Setup Pattern**
   ```dart
   setUp(() async {
     await BaseUnitTest.setupUnit();
     await TestServiceLocator.initialize();
   });
   ```

## ⚠️ Integration Test Requirements

### Critical Repository Tests Requiring Real Firebase/Emulator
Based on expert analysis from Gemini AI, the following tests **MUST** be implemented as integration tests rather than unit tests with mocks. Skipping tests due to mock limitations is **NOT industry gold standard**.

#### firebase_shopping_repository Integration Tests
Location: `test/integration/repositories/firebase_shopping_repository_integration_test.dart`

**Tests Currently Skipped (MUST IMPLEMENT):**
1. **personalListsStream()** 
   - Issue: FakeFirebaseFirestore cannot handle `orderBy('updatedAt', descending: true)` with streams
   - Requirement: Test real-time streaming with proper ordering

2. **collaborativeListsStream()**
   - Issue: Cannot handle dynamic field paths like `'memberPermissions.$uid'` with `orderBy` clauses
   - Requirement: Test complex compound queries with dynamic fields

3. **readAll()**
   - Issue: Cannot properly combine results from multiple collections with complex queries
   - Requirement: Test merging personal and collaborative lists with proper sorting

### Implementation Strategy
1. **Local Development**: Use Firebase Emulator Suite
   ```bash
   firebase emulators:start --only firestore
   ```

2. **CI/CD**: Use dedicated Firebase test project with:
   - Isolated test data
   - Automatic cleanup after test runs
   - Cost management through emulator usage

3. **Test Structure**:
   ```dart
   group('Firebase Shopping Repository Integration', () {
     setUpAll(() => initializeFirebaseEmulator());
     setUp(() => seedTestData());
     tearDown(() => cleanupTestData());
     
     test('streams collaborative lists with complex queries', () async {
       // Real Firebase queries with actual data
     });
   });
   ```

### Why This Matters
- **Risk Mitigation**: Untested complex queries are regression-prone
- **Production Confidence**: These queries are critical for app functionality
- **Industry Standard**: Integration tests for database interactions are expected

### Timeline
- Priority: HIGH
- Implementation: When reaching integration test phase
- Estimated effort: 8-12 hours for complete implementation

## 🎓 Further Reading

- [Flutter Testing Documentation](https://flutter.dev/docs/testing)
- [Mocktail Package](https://pub.dev/packages/mocktail)
- [GetIt Service Locator](https://pub.dev/packages/get_it)
- [Builder Pattern](https://refactoring.guru/design-patterns/builder)
- [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)