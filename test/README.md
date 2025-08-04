# Butlery Testing System Documentation

## 📋 Table of Contents

1. [Overview](#overview)
2. [Testing Philosophy](#testing-philosophy)
3. [Test Architecture](#test-architecture)
4. [Running Tests](#running-tests)
5. [Writing Tests](#writing-tests)
6. [Test Types](#test-types)
7. [Mocking Strategy](#mocking-strategy)
8. [CI/CD Pipeline](#cicd-pipeline)
9. [Coverage Requirements](#coverage-requirements)
10. [Best Practices](#best-practices)
11. [Troubleshooting](#troubleshooting)
12. [Advanced Patterns](#advanced-patterns)

## Overview

The Butlery testing system is a comprehensive, production-ready implementation that follows 2025 Flutter testing best practices. It achieves 90%+ code coverage through multiple testing layers: unit tests, widget tests, integration tests, golden tests, and accessibility tests.

### Implementation Status

✅ **Completed Features:**
- Full test architecture with feature-based organization
- Unit tests for all major features (Auth, Meal Planning, Messaging, Social)
- Widget tests for UI components and user interactions
- Integration tests for complete user flows using Patrol
- Mock factories for generating test data with Swedish localization
- Firebase testing infrastructure with dual-mode support (emulators & mocks)
- Comprehensive test helpers with advanced utilities
- Security rule tests for Firebase access control
- Performance benchmarks and golden tests with Alchemist
- Mutation testing setup for test quality verification
- Zero analyzer errors, warnings, or info messages

### Key Features

- **Mocktail-based mocking** (preferred over Mockito)
- **Cost-effective Firebase testing** with official mock packages
- **Patrol framework** for robust integration testing
- **Alchemist** for visual regression testing
- **WCAG 2.1 Level AA** accessibility compliance
- **Parallel test execution** in CI/CD
- **Automated coverage enforcement**
- **Comprehensive test helpers** for all testing scenarios
- **Firebase emulator support** with automatic host detection

## Testing Philosophy

### Core Principles

1. **Test Pyramid**: More unit tests, fewer integration tests, minimal E2E tests
2. **Fast Feedback**: Tests should run quickly and provide immediate feedback
3. **Isolation**: Each test should be independent and not affect others
4. **Clarity**: Test names should clearly describe what is being tested
5. **Maintainability**: Tests should be easy to update as code evolves

### What We Test

- **Business Logic**: All services, repositories, and ViewModels
- **UI Components**: Widget behavior, state management, and user interactions
- **Integration Points**: API calls, database operations, navigation flows
- **Visual Consistency**: Component appearance across themes and devices
- **Accessibility**: Screen reader support, touch targets, keyboard navigation
- **Performance**: App startup time, scrolling performance, memory usage
- **Security**: Firebase rules, permission checks, data access control

## Test Architecture

```
test/
├── features/                    # Feature-based test organization
│   ├── auth/                   # Authentication tests ✅
│   │   ├── unit/               # AuthService, AuthViewModel tests
│   │   ├── widget/             # LoginForm, SignUpForm tests
│   │   └── integration/        # Complete auth flow tests
│   ├── meal_planning/          # Meal planning tests ✅
│   │   ├── unit/               # MealPlanService tests
│   │   ├── widget/             # MealPlanCalendar, MealPlanCard tests
│   │   └── integration/        # Meal planning flow tests
│   ├── messaging/              # Messaging tests ✅
│   │   ├── unit/               # ChatService, NotificationService tests
│   │   ├── widget/             # ChatScreen, MessageBubble tests
│   │   └── integration/        # Messaging flow tests
│   ├── social/                 # Social features tests ✅
│   │   ├── unit/               # SocialService, FriendService tests
│   │   ├── widget/             # FriendsList, ActivityFeed tests
│   │   └── integration/        # Social interaction tests
│   ├── recipes/                # Recipe management tests ✅
│   └── shopping/               # Shopping list tests ✅
├── helpers/                     # Shared test utilities ✅
│   ├── test_helpers.dart       # Comprehensive test utilities
│   ├── mock_factories.dart     # Test data generators with Swedish locale
│   ├── test_service_locator.dart # Complete mock service infrastructure
│   ├── firebase_test_helper.dart # Basic Firebase mocking setup
│   ├── firebase_emulator_helper.dart # Advanced emulator & mock support
│   └── hive_test_helper.dart   # Local storage mocking
├── golden/                      # Visual regression tests ✅
│   ├── components/             # Component golden tests with Alchemist
│   ├── screens/                # Screen golden tests
│   └── golden_test_config.dart # Alchemist configuration
├── accessibility/               # Accessibility tests ✅
├── performance/                 # Performance benchmarks ✅
├── security/                    # Security rule tests ✅
├── mutation/                    # Mutation testing setup ✅
├── mocks/                      # Shared mock implementations ✅
└── flutter_test_config.dart    # Global test configuration with Alchemist

integration_test/               # E2E tests (separate directory) ✅
├── features/                   # Feature integration tests
├── helpers/                    # Integration test utilities
└── app_test.dart              # Entry point for all integration tests
```

## Running Tests

### Quick Start

```bash
# Run all tests
flutter test

# Run specific test type
flutter test test/features/recipes/unit/
flutter test test/features/recipes/widget/
flutter test --tags=golden test/golden/

# Run with coverage
flutter test --coverage

# Run integration tests
flutter test integration_test/app_test.dart

# Run with Patrol
patrol test --target integration_test/app_test.dart

# Update golden files with Alchemist
flutter test --update-goldens test/golden/
```

### Test Commands

| Command | Description |
|---------|-------------|
| `flutter test` | Run all unit and widget tests |
| `flutter test --coverage` | Generate coverage report |
| `flutter test --update-goldens` | Update golden test baselines |
| `UPDATE_GOLDENS=true flutter test` | Update Alchemist goldens |
| `patrol test` | Run integration tests with Patrol |
| `flutter test --tags=accessibility` | Run accessibility tests |
| `flutter test --reporter expanded` | Detailed test output |

### Coverage Analysis

```bash
# Generate HTML coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Check coverage percentage
flutter pub global activate coverage
flutter pub global run coverage:format_coverage \
  --lcov \
  --in=coverage \
  --out=coverage/lcov.info \
  --report-on=lib
```

## Writing Tests

### Unit Test Example

```dart
void main() {
  group('UnifiedRecipeService', () {
    late UnifiedRecipeService sut; // System Under Test
    late MockRecipeRepository mockRepository;
    
    setUp(() {
      TestServiceLocator.initialize();
      mockRepository = TestServiceLocator.mockRecipeRepository;
      sut = UnifiedRecipeService();
    });
    
    tearDown(() {
      TestServiceLocator.reset();
    });
    
    group('createRecipe', () {
      test('should create recipe with valid data', () async {
        // Given
        final recipe = RecipeFactory.build();
        when(() => mockRepository.create(any()))
            .thenAnswer((_) async => recipe);
        
        // When
        final result = await sut.createRecipe(recipe);
        
        // Then
        expect(result, equals(recipe));
        verify(() => mockRepository.create(recipe)).called(1);
      });
    });
  });
}
```

### Widget Test Example

```dart
testWidgets('displays recipe information correctly', (tester) async {
  // Given
  final recipe = RecipeFactory.build(
    title: 'Köttbullar med gräddsås',
    timeMinutes: 30,
  );
  
  // When
  await tester.pumpWidget(
    createTestableWidget(
      child: RecipeCard(
        recipe: recipe,
        onTap: (_) {},
      ),
    ),
  );
  
  // Then
  expect(find.text('Köttbullar med gräddsås'), findsOneWidget);
  expect(find.text('30 min'), findsOneWidget);
});
```

### Golden Test Example with Alchemist

```dart
void main() {
  group('RecipeCard Golden Tests', () {
    goldenTest(
      'renders correctly across themes',
      fileName: 'recipe_card',
      builder: () => GoldenTestGroup(
        children: [
          GoldenTestScenario(
            name: 'Basic Recipe',
            child: RecipeCard(
              recipe: RecipeFactory.build(),
              onTap: (_) {},
            ),
          ),
        ],
      ),
    );
  });
}
```

### Integration Test Example

```dart
patrolTest(
  'User can create and view a recipe',
  ($) async {
    await app.main();
    await $.pumpAndSettle();
    
    // Login
    await $.tap(find.text('Logga in'));
    await $.enterText(find.byKey(Key('email_field')), 'test@example.com');
    await $.enterText(find.byKey(Key('password_field')), 'password123');
    await $.tap(find.text('Logga in'));
    await $.pumpAndSettle();
    
    // Create recipe
    await $.tap(find.byIcon(Icons.add));
    await $.pumpAndSettle();
    // ... continue test
  },
);
```

## Test Types

### 1. Unit Tests

- **Purpose**: Test individual functions, classes, and business logic
- **Location**: `test/features/*/unit/`
- **Coverage Target**: 95%+
- **Key Areas**: Services, repositories, ViewModels, utilities

### 2. Widget Tests

- **Purpose**: Test UI components in isolation
- **Location**: `test/features/*/widget/`
- **Coverage Target**: 90%+
- **Key Areas**: Custom widgets, forms, dialogs, navigation

### 3. Integration Tests

- **Purpose**: Test complete user flows and feature interactions
- **Location**: `integration_test/`
- **Framework**: Patrol
- **Key Scenarios**: Authentication, CRUD operations, offline sync

### 4. Golden Tests

- **Purpose**: Visual regression testing
- **Location**: `test/golden/`
- **Framework**: Alchemist
- **Configuration**: `flutter_test_config.dart`
- **Update Command**: `UPDATE_GOLDENS=true flutter test`

### 5. Accessibility Tests

- **Purpose**: Ensure WCAG 2.1 compliance
- **Location**: `test/accessibility/`
- **Key Areas**: Touch targets, screen readers, contrast, keyboard nav

### 6. Performance Tests

- **Purpose**: Benchmark app performance
- **Location**: `test/performance/`
- **Metrics**: Startup time, frame rate, memory usage

### 7. Mutation Tests

- **Purpose**: Verify test quality by mutating code
- **Location**: `test/mutation/`
- **Framework**: Custom mutation testing setup
- **Goal**: Ensure tests catch code changes

## Mocking Strategy

### Test Service Locator

```dart
// Initialize test environment
TestServiceLocator.initialize();

// Access mocks
final mockRecipeService = TestServiceLocator.mockRecipeService;
final mockAuthService = TestServiceLocator.mockAuthService;

// Configure mock behavior
TestServiceLocator.configureRecipeService(
  recipes: [testRecipe1, testRecipe2],
  isLoading: false,
);

// Reset between tests
TestServiceLocator.reset();
```

### Firebase Testing

```dart
// For unit tests - use mocks
await FirebaseEmulatorHelper.initializeWithMocks(
  initialUser: MockUser(
    uid: 'test123',
    email: 'test@example.com',
  ),
);

// For integration tests - use emulators
await FirebaseEmulatorHelper.initializeWithEmulators(
  useAuthEmulator: true,
  useFirestoreEmulator: true,
);

// Access Firebase services
final firestore = FirebaseEmulatorHelper.firestore;
final auth = FirebaseEmulatorHelper.auth;

// Clean up
await FirebaseEmulatorHelper.reset();
```

### Test Data Factories

```dart
// Generate test data with Swedish localization
final recipe = RecipeFactory.build(
  title: 'Köttbullar',
  servings: 4,
);

final shoppingList = ShoppingListFactory.build(
  name: 'Veckans inköp',
);

final user = UserProfileFactory.build(
  displayName: 'Anna Andersson',
);

// Generate lists
final recipes = RecipeFactory.buildList(10);
```

## CI/CD Pipeline

### Pipeline Overview

1. **Code Quality** - Linting, formatting, static analysis
2. **Unit Tests** - Run on stable and beta Flutter
3. **Integration Tests** - Run on iOS simulators
4. **Golden Tests** - Visual regression checks
5. **Performance Tests** - Run on main branch only
6. **Build** - Create artifacts for all platforms
7. **Deploy** - Firebase hosting (main branch)

### Optimization Strategies

- **Dependency Caching**: 50-70% time reduction
- **Parallel Execution**: Tests run concurrently
- **Matrix Testing**: Multiple Flutter versions
- **Conditional Jobs**: Skip unnecessary steps

## Coverage Requirements

### Enforcement Levels

| Test Type | Required Coverage |
|-----------|------------------|
| Business Logic | 95% |
| UI Components | 90% |
| Utilities | 100% |
| Overall | 90% |

### Exclusions

- Generated code (`*.g.dart`)
- Firebase configuration
- Main entry points
- Pure UI constants

## Best Practices

### 1. Test Naming

```dart
// Good: Descriptive and specific
test('should return error when network is unavailable during recipe creation', () {});

// Bad: Vague and unclear
test('test recipe error', () {});
```

### 2. Test Organization

- Group related tests using `group()`
- Use `setUp()` and `tearDown()` for common initialization
- Keep tests focused on one behavior
- Use descriptive variable names

### 3. Async Testing

```dart
// Always await async operations
await tester.pumpAndSettle();

// Use runAsync for complex async operations
await tester.runAsync(() async {
  await someAsyncOperation();
});
```

### 4. Mock Usage

```dart
// Setup default behavior in setUp
when(() => mock.method()).thenReturn(value);

// Verify interactions
verify(() => mock.method()).called(1);
verifyNever(() => mock.otherMethod());
```

### 5. Test Helpers

```dart
// Use comprehensive test helpers
await pumpWidgetWithSetup(tester, widget);
await GestureTestHelper.performSwipe(tester, finder);
await AnimationTestHelper.skipToEndOfAnimation(tester, duration);
NavigationTestHelper.expectNavigatedTo('/home');
```

## Troubleshooting

### Common Issues

#### 1. Flaky Tests

**Problem**: Tests pass/fail inconsistently
**Solution**: 
- Add proper waits: `pumpAndSettle()`
- Mock time-dependent operations
- Use `runAsync` for complex async operations

#### 2. Golden Test Failures

**Problem**: Golden tests fail on CI
**Solution**:
- Use Alchemist for consistent rendering
- Update goldens with `UPDATE_GOLDENS=true`
- Check font loading and image assets

#### 3. Coverage Gaps

**Problem**: Coverage below threshold
**Solution**:
- Run coverage report locally
- Focus on untested branches
- Add edge case tests

#### 4. Slow Tests

**Problem**: Test suite takes too long
**Solution**:
- Use `TestServiceLocator` for faster setup
- Avoid real network calls
- Parallelize independent tests

### Debug Commands

```bash
# Run single test with verbose output
flutter test --name "test name" -v

# Run with debugging enabled
flutter test --start-paused

# Check for test conflicts
flutter test --test-randomize-ordering-seed random
```

## Advanced Patterns

### 1. Parameterized Tests

```dart
final testCases = [
  (input: 'pasta', expected: 3),
  (input: 'chicken', expected: 5),
  (input: 'vegan', expected: 2),
];

for (final testCase in testCases) {
  test('search returns ${testCase.expected} results for "${testCase.input}"', () async {
    final results = await sut.search(testCase.input);
    expect(results.length, equals(testCase.expected));
  });
}
```

### 2. Custom Matchers

```dart
Matcher hasSemantics({
  String? label,
  bool? isButton,
}) => predicate<SemanticsNode>((node) {
  if (label != null && node.label != label) return false;
  if (isButton != null && node.hasFlag(SemanticsFlag.isButton) != isButton) return false;
  return true;
});
```

### 3. Platform-Specific Tests

```dart
PlatformTestHelper.testOnAllPlatforms(
  'renders correctly on all platforms',
  (tester, platform) async {
    debugDefaultTargetPlatformOverride = platform;
    await tester.pumpWidget(MyWidget());
    // Test platform-specific behavior
  },
);
```

### 4. Property-Based Tests

```dart
import 'package:glados/glados.dart';

Glados2().test('recipe always has valid portions', (
  int portions,
) {
  final recipe = RecipeFactory.build(portions: portions.abs() + 1);
  expect(recipe.portions, greaterThan(0));
});
```

### 5. Mutation Testing

```dart
// Run mutation tests to verify test quality
dart test/mutation/run_mutation_tests.dart

// Example mutation test
test('detects arithmetic mutations', () {
  int calculate(int a, int b) => a + b; // Will be mutated to -, *, /
  expect(calculate(2, 3), equals(5)); // Must catch mutations
});
```

## Recent Improvements (2025)

### 1. **Alchemist Integration**
- Replaced standard golden testing with Alchemist
- Added `flutter_test_config.dart` for global configuration
- Consistent golden rendering across platforms
- Easy updates with `UPDATE_GOLDENS=true`

### 2. **Enhanced Test Helpers**
- **Platform Testing**: Test on all platforms easily
- **Animation Helpers**: Test animations at specific points
- **Gesture Helpers**: Swipe, long press, double tap
- **Navigation Helpers**: GoRouter testing support
- **Focus Helpers**: Test focus management
- **Error Helpers**: Test error handling
- **Lifecycle Helpers**: Setup/teardown management

### 3. **Comprehensive Firebase Emulator Helper**
- **Dual-mode support**: Emulators for integration, mocks for unit tests
- **Platform detection**: Automatic host configuration
- **Full emulator management**: Init, clear, status checks
- **Test data generators**: Recipes, users, messages
- **Network control**: Enable/disable for offline testing
- **Complete reset**: Clean state between tests

### 4. **Zero Linting Issues**
- All errors fixed
- All warnings resolved
- All info messages addressed
- Consistent code style throughout

## Contributing

When adding new features:

1. Write tests first (TDD approach)
2. Ensure all test types are covered
3. Update test documentation
4. Verify CI passes locally
5. Check coverage meets requirements
6. Use existing test helpers and patterns

## Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Mocktail Documentation](https://pub.dev/packages/mocktail)
- [Patrol Documentation](https://patrol.leancode.co/)
- [Alchemist Documentation](https://pub.dev/packages/alchemist)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Glados Property Testing](https://pub.dev/packages/glados)

---

*Last updated: 2025*
*Maintainer: Butlery Development Team*
*Testing System Version: 2.0*