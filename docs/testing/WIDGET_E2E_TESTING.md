# Widget and E2E Testing Guide - Butlery Application

**Comprehensive guide for widget testing and end-to-end testing patterns in the Butlery Flutter application.**

**Last Updated**: January 2025

---

## Table of Contents

- [Widget Testing](#widget-testing)
  - [Widget Test Structure](#widget-test-structure)
  - [Widget Test Categories](#widget-test-categories)
  - [Common Widget Testing Patterns](#common-widget-testing-patterns)
  - [Widget Testing Checklist](#widget-testing-checklist)
- [E2E Testing](#e2e-testing)
  - [The E2E Firebase Challenge](#the-e2e-firebase-challenge)
  - [Three-Tier E2E Solution](#three-tier-e2e-solution)
  - [E2E Test Patterns](#e2e-test-patterns)
- [Related Documentation](#related-documentation)

---

## Widget Testing

Widget tests verify that UI components render correctly, respond to user interactions, and handle different states appropriately.

**Current Status**: 149 widget test files in `/test/widget/`

**Purpose**: Test UI rendering and user interactions without launching the full app.

---

### Widget Test Structure

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import '../../test_support/base_widget_test.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  group('WidgetName', () {
    late MockViewModel mockViewModel;

    setUp(() async {
      await BaseWidgetTest.setupWidget();
      await TestServiceLocator.initialize();

      mockViewModel = MockViewModel();
      // Configure initial state
      mockViewModel.setViewModelState(
        isLoading: false,
        data: [],
      );
    });

    tearDown() async {
      await TestServiceLocator.reset();
      BaseWidgetTest.resetMocks();
    });

    Widget createTestWidget({Widget? child}) {
      return MaterialApp(
        home: ChangeNotifierProvider<ViewModel>.value(
          value: mockViewModel,
          child: child ?? WidgetUnderTest(),
        ),
      );
    }

    // Test cases follow...
  });
}
```

---

### Widget Test Categories

#### 1. Initial Rendering

Test that widgets display correctly with various data states.

```dart
group('Initial Rendering', () {
  testWidgets('should display correctly with data', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(
      data: [Item(title: 'Test Item')],
    );

    // Act
    await tester.pumpWidget(createTestWidget());

    // Assert
    expect(find.text('Test Item'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('should show empty state', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(data: []);

    // Act
    await tester.pumpWidget(createTestWidget());

    // Assert
    expect(find.text('No items found'), findsOneWidget);
    expect(find.byIcon(Icons.inbox), findsOneWidget);
  });
});
```

---

#### 2. Loading States

Test that loading indicators display correctly during async operations.

```dart
group('Loading States', () {
  testWidgets('should show loading indicator', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(isLoading: true);

    // Act
    await tester.pumpWidget(createTestWidget());

    // Assert
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Test Item'), findsNothing);
  });

  testWidgets('should hide loading when complete', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(isLoading: true);
    await tester.pumpWidget(createTestWidget());

    // Act
    mockViewModel.setViewModelState(
      isLoading: false,
      data: [Item()],
    );
    await tester.pump();

    // Assert
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
});
```

---

#### 3. User Interactions

Test that widgets respond correctly to user input.

```dart
group('User Interactions', () {
  testWidgets('should handle tap on item', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(
      data: [Item(id: '123', title: 'Tap Me')],
    );

    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('Tap Me'));
    await tester.pump();

    // Assert
    verify(() => mockViewModel.onItemTap('123')).called(1);
  });

  testWidgets('should submit form on button press', (tester) async {
    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.enterText(find.byType(TextField), 'Test Input');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // Assert
    verify(() => mockViewModel.submitForm('Test Input')).called(1);
  });
});
```

---

#### 4. Error States

Test that error messages display correctly.

```dart
group('Error States', () {
  testWidgets('should display error message', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(
      hasError: true,
      errorMessage: 'Network error occurred',
    );

    // Act
    await tester.pumpWidget(createTestWidget());

    // Assert
    expect(find.text('Network error occurred'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);
  });

  testWidgets('should show retry button on error', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(hasError: true);

    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('Retry'));

    // Assert
    verify(() => mockViewModel.retry()).called(1);
  });
});
```

---

#### 5. Form Validation

Test form validation logic in widgets.

```dart
group('Form Validation', () {
  testWidgets('should show validation errors', (tester) async {
    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('Submit'));
    await tester.pump();

    // Assert
    expect(find.text('Title is required'), findsOneWidget);
  });

  testWidgets('should enable submit when valid', (tester) async {
    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.enterText(
      find.byKey(Key('title_field')),
      'Valid Title',
    );
    await tester.pump();

    // Assert
    final submitButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(submitButton.onPressed, isNotNull);
  });
});
```

---

### Common Widget Testing Patterns

#### Testing Scrollable Content

```dart
testWidgets('should scroll to load more items', (tester) async {
  // Arrange
  mockViewModel.setViewModelState(
    data: List.generate(20, (i) => Item(id: '$i')),
  );

  // Act
  await tester.pumpWidget(createTestWidget());
  await tester.drag(find.byType(ListView), Offset(0, -500));
  await tester.pump();

  // Assert
  verify(() => mockViewModel.loadMore()).called(1);
});
```

---

#### Testing Animations

```dart
testWidgets('should animate on state change', (tester) async {
  // Act
  await tester.pumpWidget(createTestWidget());
  mockViewModel.triggerAnimation();

  // Pump frames for animation
  await tester.pump();
  await tester.pump(Duration(milliseconds: 500));

  // Assert
  final opacity = tester.widget<AnimatedOpacity>(
    find.byType(AnimatedOpacity),
  );
  expect(opacity.opacity, equals(1.0));
});
```

---

#### Testing Dialogs

```dart
testWidgets('should show confirmation dialog', (tester) async {
  // Act
  await tester.pumpWidget(createTestWidget());
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();

  // Assert
  expect(find.text('Are you sure?'), findsOneWidget);
  expect(find.text('Cancel'), findsOneWidget);
  expect(find.text('Confirm'), findsOneWidget);
});
```

---

#### Testing Navigation

```dart
testWidgets('should navigate to detail screen', (tester) async {
  // Arrange
  final navigatorKey = GlobalKey<NavigatorState>();

  // Act
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: WidgetUnderTest(),
      routes: {
        '/detail': (_) => DetailScreen(),
      },
    ),
  );
  await tester.tap(find.text('View Details'));
  await tester.pumpAndSettle();

  // Assert
  expect(find.byType(DetailScreen), findsOneWidget);
});
```

---

### Widget Testing Checklist

**Per Widget**:
- [ ] Renders correctly with valid data
- [ ] Handles empty state appropriately
- [ ] Shows loading state when loading
- [ ] Displays errors clearly
- [ ] Responds to taps correctly
- [ ] Validates input if applicable
- [ ] Accessible with semantic labels
- [ ] Responsive to different screen sizes

**Per Screen**:
- [ ] Navigation works between screens
- [ ] State preserved on navigation
- [ ] Dialogs display correctly
- [ ] Keyboard handling for forms
- [ ] Scroll behavior correct
- [ ] Pull to refresh if applicable

---

## E2E Testing

E2E tests verify complete user journeys but face unique challenges with Firebase apps. Our solution uses a **three-tier E2E testing system**.

---

### The E2E Firebase Challenge

Standard E2E tests fail with Firebase apps because:
- `main()` initializes Firebase with production config
- Tests have no Firebase credentials/project
- Platform channels fail in test environment

**Error Example**:
```
PlatformException(channel-error, Unable to establish connection on channel:
"dev.flutter.pigeon.firebase_core_platform_interface.FirebaseCoreHostApi.initializeCore".)
```

**Solution**: Use separate entry points for different E2E test tiers.

---

### Three-Tier E2E Solution

#### Tier 1: Mock E2E Tests (60% of E2E) - Fastest

**Purpose**: Critical user journeys without Firebase dependencies

**Approach**: Full app with mock Firebase services

**Use Cases**: UI flows, navigation, form validation, local state

```dart
// lib/main_e2e_mock.dart
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Skip Firebase initialization completely
  await _initializeE2EMockSystem();

  runApp(const ButleryApp());
}

// test/e2e/flows/authentication_flow_mock_test.dart
testWidgets('complete registration UI flow', (tester) async {
  // Test pure UI/UX journey without Firebase
  await E2ETestRunner.runMockApp();
  await tester.pumpAndSettle();

  // Complete registration form flow
  await _completeRegistrationForm(tester);
  expect(find.byType(MainApp), findsOneWidget);
});
```

**Advantages**:
- No Firebase setup required
- Fastest execution
- Test pure UI/UX flows
- No network dependencies

**Disadvantages**:
- Cannot test real Firebase operations
- Mocked data may not reflect production

---

#### Tier 2: Emulator E2E Tests (35% of E2E) - Firebase Operations

**Purpose**: Firebase-dependent user journeys

**Approach**: Full app with Firebase emulator

**Use Cases**: Authentication, data persistence, real-time features

```dart
// lib/main_e2e_emulator.dart
Future<void> main() async {
  await Firebase.initializeApp();

  // Connect to Firebase emulators
  await _connectToE2EEmulators();
  await _initializeModularSystem();

  runApp(const ButleryApp());
}

// test/e2e/flows/authentication_flow_emulator_test.dart
testWidgets('complete authentication with Firebase', (tester) async {
  // Test with real Firebase Auth operations
  await E2ETestRunner.runEmulatorApp();
  await tester.pumpAndSettle();

  // Real Firebase user creation
  await _performRealRegistration(tester);

  // Verify Firebase state
  final user = FirebaseAuth.instance.currentUser;
  expect(user, isNotNull);
});
```

**Advantages**:
- Tests real Firebase operations
- Tests real-time features
- Tests authentication flows
- No production data risk

**Disadvantages**:
- Requires emulator setup
- Slower than mock tests
- More complex setup

---

#### Tier 3: Staging E2E Tests (5% of E2E) - Production-Like

**Purpose**: Production-like critical paths

**Approach**: Real Firebase staging project

**Use Cases**: Production integrations, payment flows, external services

```dart
// lib/main_e2e_staging.dart
Future<void> main() async {
  await Firebase.initializeApp(
    options: StagingFirebaseOptions.currentPlatform, // Staging project
  );

  await _initializeModularSystem();
  runApp(const ButleryApp());
}
```

**Advantages**:
- Production-like environment
- Tests external integrations
- Tests payment flows
- High confidence

**Disadvantages**:
- Slowest execution
- Requires staging environment
- May incur costs

---

### E2E Test Patterns

#### Pattern 1: Authentication Journey (Mock)

```dart
testWidgets('registration form validation and UI flow', (tester) async {
  await MockE2ETest.runMockApp();

  // Test UI/UX without Firebase dependency
  await tester.pumpWidget(createE2EApp(config: E2EConfig.mock));
  await tester.pumpAndSettle();

  // Navigate to registration
  await tester.tap(find.text('Skapa konto'));
  await tester.pumpAndSettle();

  // Test form validation
  await tester.tap(find.byKey(Key('submit_button')));
  await tester.pumpAndSettle();
  expect(find.textContaining('obligatorisk'), findsAtLeastNWidgets(1));

  // Fill valid form
  await tester.enterText(find.byKey(Key('name_field')), 'Test User');
  await tester.enterText(find.byKey(Key('email_field')), 'test@example.com');
  await tester.enterText(find.byKey(Key('password_field')), 'password123');

  // Submit form
  await tester.tap(find.byKey(Key('submit_button')));
  await tester.pumpAndSettle();

  // Should navigate to main app (mocked success)
  expect(find.byType(AuthView), findsNothing);
});
```

---

#### Pattern 2: Authentication Journey (Emulator)

```dart
testWidgets('complete Firebase authentication flow', (tester) async {
  await EmulatorE2ETest.runEmulatorApp();

  await tester.pumpWidget(createE2EApp(config: E2EConfig.emulator));
  await tester.pumpAndSettle();

  // Complete real Firebase registration
  await _performRealRegistrationFlow(tester);

  // Verify real Firebase user created
  final user = FirebaseAuth.instance.currentUser;
  expect(user, isNotNull);
  expect(user!.email, equals('e2etest@example.com'));

  // Verify user document created in Firestore
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  expect(userDoc.exists, isTrue);
});
```

---

#### Pattern 3: Complete User Journey

```dart
testWidgets('recipe creation to sharing journey', (tester) async {
  await EmulatorE2ETest.runEmulatorApp();

  // Create authenticated user
  final user = await FirebaseTestHelper.createE2ETestUser(
    email: 'chef@example.com',
    password: 'password123',
    displayName: 'Chef User',
  );

  await tester.pumpWidget(createE2EApp(config: E2EConfig.emulator));
  await tester.pumpAndSettle();

  // Navigate to recipe creation
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();

  // Create complete recipe
  await _createRecipe(tester, 'E2E Test Recipe');

  // Share recipe
  await _shareRecipe(tester);

  // Verify recipe exists in Firebase
  final recipeDocs = await FirebaseFirestore.instance
      .collection('recipes')
      .where('userId', isEqualTo: user.uid)
      .get();
  expect(recipeDocs.docs.length, equals(1));
  expect(recipeDocs.docs.first.data()['title'], equals('E2E Test Recipe'));
});
```

---

## Related Documentation

- **[TESTING_COMPLETE_GUIDE.md](./TESTING_COMPLETE_GUIDE.md)** - Complete testing guide
- **[INTEGRATION_TESTING.md](./INTEGRATION_TESTING.md)** - Integration testing patterns
- **[FIREBASE_TESTING_PATTERNS.md](./FIREBASE_TESTING_PATTERNS.md)** - Firebase-specific patterns
- **[TESTING_DASHBOARD.md](./TESTING_DASHBOARD.md)** - Current test coverage and priorities

---

**Last Updated**: January 2025
**Maintained By**: Butlery Development Team
