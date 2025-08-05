# Butlery Testing Guidelines 📚

This document consolidates all testing patterns, solutions, and best practices established during the test infrastructure overhaul.

## Table of Contents
1. [Quick Start](#quick-start)
2. [Test Configuration](#test-configuration)
3. [Golden Tests](#golden-tests)
4. [Firebase Testing](#firebase-testing)
5. [Accessibility Testing](#accessibility-testing)
6. [Common Issues & Solutions](#common-issues--solutions)
7. [Test Organization](#test-organization)

---

## Quick Start

### Running Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/features/auth/auth_test.dart

# Update golden files
flutter test --update-goldens

# Run with coverage
flutter test --coverage
```

### Writing New Tests
```dart
import 'package:flutter_test/flutter_test.dart';
import '../test_configuration.dart';

void main() {
  configureTests(); // Always start with this
  
  group('My Feature Tests', () {
    test('should do something', () async {
      // Your test here
    });
  });
}
```

---

## Test Configuration

### Full Configuration (Integration/Widget Tests)
Use for tests that need ServiceLocator, Firebase, or other services:

```dart
void main() {
  configureTests(); // Full setup with all services
  
  testWidgets('integration test', (tester) async {
    // Has access to all mocked services
  });
}
```

### Lightweight Configuration (Golden Tests)
Use for visual regression tests to avoid timeouts:

```dart
import '../golden_test_configuration.dart';

void main() {
  configureGoldenTests(); // Only loads fonts
  
  testGoldens('visual test', (tester) async {
    // Faster execution, no service dependencies
  });
}
```

---

## Golden Tests

### Strategy Guide
**Use Lightweight Golden Tests (80%) for:**
- Pure UI components
- Theme testing
- Responsive layouts
- Static animations

**Use Full Setup Golden Tests (20%) for:**
- Service-dependent UI states
- Authentication flows
- Real-time features

### Avoiding Timeouts
```dart
// ❌ BAD: Network images cause timeouts
RecipeFactory.build(
  imageUrls: ['https://example.com/image.jpg']
)

// ✅ GOOD: No network requests
RecipeFactory.build(
  imageUrls: [] // Empty array
)
```

### Golden File Management
```bash
# Generate/update golden files
flutter test --update-goldens

# Golden files are stored in:
# - test/golden/goldens/
# - test/golden/components/goldens/
# - test/golden/screens/goldens/
```

---

## Firebase Testing

### Test Modes
```dart
// 1. Mock Mode (default, fastest)
await FirebaseTestSetup.initialize(mode: FirebaseTestMode.mocks);

// 2. Emulator Mode (integration testing)
await FirebaseTestSetup.initialize(mode: FirebaseTestMode.emulators);

// 3. Test Project Mode (real Firebase)
await FirebaseTestSetup.initialize(mode: FirebaseTestMode.testProject);
```

### Firebase Mock Patterns
```dart
// Prevent sync issues in tests
when(() => mockAuthRepository.currentUser).thenReturn(null);

// Mock Firestore data
when(() => mockFirestore.collection('recipes')).thenReturn(mockCollection);
```

---

## Accessibility Testing

### Requirements
- **Touch Targets**: Minimum 48x48 dp
- **Text Labels**: All form fields must have labels
- **Semantic Labels**: Images and icons need descriptions
- **Color Contrast**: WCAG 2.1 compliance

### Implementation
```dart
// Ensure touch target size
IconButton(
  constraints: const BoxConstraints(
    minWidth: 48,
    minHeight: 48,
  ),
  // ...
)

// Add form field keys
TextFormField(
  key: const Key('email_field'),
  // ...
)
```

---

## Common Issues & Solutions

### Issue: "ServiceLocator not initialized"
**Solution**: Ensure `configureTests()` is called in your test's `main()` function.

### Issue: "RecipeRepository is not registered"
**Solution**: This is handled automatically by `setupTestGetIt()` in the test configuration.

### Issue: Golden test timeouts
**Solution**: Use `configureGoldenTests()` instead of `configureTests()` and avoid network images.

### Issue: "HttpClient" warning in tests
**Note**: This is informational - Flutter blocks network requests in tests for reliability.

---

## Test Organization

### Directory Structure
```
test/
├── test_configuration.dart         # Global test setup
├── golden_test_configuration.dart  # Golden test setup
├── helpers/                        # Test utilities
│   ├── test_service_locator.dart
│   ├── mock_factories.dart
│   └── firebase_test_setup.dart
├── features/                       # Feature tests
│   ├── auth/
│   ├── recipes/
│   └── messaging/
├── golden/                         # Visual tests
│   ├── components/
│   ├── screens/
│   └── themes/
└── integration/                    # E2E tests
```

### Test Naming Conventions
- Unit tests: `{class_name}_test.dart`
- Widget tests: `{widget_name}_widget_test.dart`
- Golden tests: `{component_name}_golden_test.dart`
- Integration tests: `{feature}_integration_test.dart`

### Tags (dart_test.yaml)
- `golden`: Visual regression tests
- `integration`: Integration tests (5m timeout)
- `performance`: Performance tests (10m timeout)
- `network`: Tests requiring network
- `skip`: Broken tests to skip

---

## Best Practices

1. **Always use test configuration**
   - `configureTests()` for regular tests
   - `configureGoldenTests()` for visual tests

2. **Mock external dependencies**
   - Use `TestServiceLocator` for consistent mocks
   - Avoid real network calls

3. **Keep tests isolated**
   - Each test should set up its own state
   - Use `setUp()` and `tearDown()` properly

4. **Write descriptive test names**
   - Describe what is being tested
   - Include expected behavior

5. **Document complex test scenarios**
   - Add comments explaining test setup
   - Document any workarounds

---

## Resources

- [Flutter Testing Documentation](https://flutter.dev/docs/testing)
- [Golden Toolkit Documentation](https://pub.dev/packages/golden_toolkit)
- [Mocktail Documentation](https://pub.dev/packages/mocktail)
- `test/TODO_test_system.md` - Roadmap for test improvements