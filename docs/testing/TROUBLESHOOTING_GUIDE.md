# Flutter Testing Troubleshooting Guide

This guide helps you resolve common issues when working with the Butlery testing infrastructure.

## Table of Contents

1. [Common Test Failures](#common-test-failures)
2. [Flutter Test Command Issues](#flutter-test-command-issues)
3. [Mock and Stub Issues](#mock-and-stub-issues)
4. [Integration Test Problems](#integration-test-problems)
5. [Golden Test Issues](#golden-test-issues)
6. [Firebase Testing Issues](#firebase-testing-issues)
7. [Platform-Specific Issues](#platform-specific-issues)
8. [Performance and Timeout Issues](#performance-and-timeout-issues)
9. [CI/CD Pipeline Issues](#cicd-pipeline-issues)
10. [Advanced Debugging Techniques](#advanced-debugging-techniques)

## Common Test Failures

### 1. "No MaterialLocalizations found" Error

**Problem**: Tests fail with `No MaterialLocalizations found` error.

**Solution**:
```dart
// Wrap your widget with MaterialApp or use materialAppWrapper
await tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('en', 'US'),
      Locale('sv', 'SE'),
    ],
    home: YourWidget(),
  ),
);

// Or use the helper:
await tester.pumpWidget(
  materialAppWrapper()(YourWidget()),
);
```

### 2. "setState() or markNeedsBuild() called during build" Error

**Problem**: Test throws error about setState being called during build.

**Solution**:
```dart
// Use addPostFrameCallback to defer state changes
WidgetsBinding.instance.addPostFrameCallback((_) {
  setState(() {
    // Your state change
  });
});

// In tests, ensure proper pump cycles
await tester.pump(); // Allow frame to complete
await tester.pump(); // Process post-frame callbacks
```

### 3. "The finder found X widgets instead of 1" Error

**Problem**: Finder matches multiple widgets when expecting one.

**Solution**:
```dart
// Be more specific with your finders
find.byKey(const Key('specific-widget-key'))
find.ancestor(
  of: find.text('Child'),
  matching: find.byType(Container),
)
find.descendant(
  of: find.byType(ListView),
  matching: find.text('Item').first,
)
```

## Flutter Test Command Issues

### 1. Tests Not Running in WSL

**Problem**: Flutter tests fail in WSL environment.

**Solution**:
```bash
# Use Windows Flutter via cmd.exe
cmd.exe /c "flutter test"

# For specific tests
cmd.exe /c "flutter test test/unit/recipe_service_test.dart"

# With coverage
cmd.exe /c "flutter test --coverage"
```

### 2. "Dart SDK not found" Error

**Problem**: Flutter can't find Dart SDK.

**Solution**:
```bash
# Update Flutter
cmd.exe /c "flutter upgrade"

# Clean and get packages
cmd.exe /c "flutter clean"
cmd.exe /c "flutter pub get"
```

## Mock and Stub Issues

### 1. "type 'Null' is not a subtype of type 'Future<X>'" Error

**Problem**: Mock method returns null instead of expected Future.

**Solution**:
```dart
// Always specify return values for async methods
when(() => mockService.getData())
  .thenAnswer((_) async => YourData());

// For void futures
when(() => mockService.doSomething())
  .thenAnswer((_) async {});
```

### 2. Sealed Class Mocking Issues

**Problem**: Can't mock Firebase classes like DocumentReference.

**Solution**:
```dart
// Create test doubles instead of mocks
class FakeDocumentReference implements DocumentReference<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic>? _data;

  FakeDocumentReference(this._id, [this._data]);

  @override
  String get id => _id;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get() async {
    return FakeDocumentSnapshot(_id, _data);
  }
  
  // Implement other required methods
}
```

### 3. Provider Not Found in Widget Tree

**Problem**: Tests fail with "Could not find Provider<X>".

**Solution**:
```dart
// Wrap with necessary providers
await tester.pumpWidget(
  MultiProvider(
    providers: [
      Provider<YourService>(create: (_) => mockService),
      ChangeNotifierProvider(create: (_) => YourViewModel()),
    ],
    child: MaterialApp(home: YourWidget()),
  ),
);

// Or use providerWrapper helper
await tester.pumpWidget(
  providerWrapper(
    overrides: [
      Provider<YourService>.value(value: mockService),
    ],
  )(YourWidget()),
);
```

## Integration Test Problems

### 1. Patrol Tests Not Finding Widgets

**Problem**: Patrol's $ selector can't find widgets.

**Solution**:
```dart
// Ensure app is fully loaded
await $.pumpAndSettle();

// Use native finders if needed
await $.tester.tap(find.byKey(const Key('my-key')));
await $.pumpAndSettle();

// Wait for specific conditions
await $.waitUntilVisible(find.text('Loading complete'));
```

### 2. Integration Tests Timing Out

**Problem**: Tests timeout before completion.

**Solution**:
```dart
// Increase timeout in patrol_test
patrolTest(
  'long running test',
  timeout: const Timeout(Duration(minutes: 5)),
  ($) async {
    // Test code
  },
);

// Add explicit waits
await $.pump(const Duration(seconds: 2));
```

## Golden Test Issues

### 1. Golden Files Not Matching

**Problem**: Golden tests fail with pixel differences.

**Solution**:
```bash
# Update golden files
cmd.exe /c "flutter test --update-goldens"

# For specific test
cmd.exe /c "flutter test --update-goldens test/golden/my_test.dart"
```

### 2. Fonts Not Loading in Golden Tests

**Problem**: Text appears as squares in golden tests.

**Solution**:
```dart
// In setUpAll
setUpAll(() async {
  await loadAppFonts();
});

// Ensure font files are included in pubspec.yaml
flutter:
  fonts:
    - family: Roboto
      fonts:
        - asset: fonts/Roboto-Regular.ttf
```

### 3. Platform Differences in Golden Tests

**Problem**: Golden tests pass locally but fail in CI.

**Solution**:
```dart
// Use platform-specific golden files
await expectLater(
  find.byType(MyWidget),
  matchesGoldenFile('goldens/my_widget_${Platform.operatingSystem}.png'),
);

// Or skip on certain platforms
testGoldens(
  'my golden test',
  skip: Platform.isWindows,
  (tester) async {
    // Test code
  },
);
```

## Firebase Testing Issues

### 1. Firebase Not Initialized

**Problem**: Tests fail with "Firebase not initialized".

**Solution**:
```dart
setUpAll(() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'test-key',
      appId: 'test-app',
      messagingSenderId: 'test-sender',
      projectId: 'test-project',
    ),
  );
});
```

### 2. Firestore Security Rules Failing

**Problem**: Tests fail due to security rules.

**Solution**:
```dart
// Use Firebase Emulator with open rules for testing
await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
await FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);

// Or use admin SDK in tests
// This bypasses security rules
```

### 3. Firebase Emulator Connection Issues

**Problem**: Can't connect to Firebase Emulator.

**Solution**:
```bash
# Start emulators first
firebase emulators:start --only firestore,auth

# In another terminal, run tests
cmd.exe /c "flutter test"
```

## Platform-Specific Issues

### 1. Platform Channel Tests Failing

**Problem**: MethodChannel calls fail in tests.

**Solution**:
```dart
// Mock platform channels
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
  .setMockMethodCallHandler(
    const MethodChannel('com.example/channel'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'getPlatformVersion') {
        return '1.0.0';
      }
      return null;
    },
  );
```

### 2. Platform-Specific Widgets Not Rendering

**Problem**: iOS/Android specific widgets don't appear.

**Solution**:
```dart
// Set target platform
debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

// Clean up in tearDown
tearDown(() {
  debugDefaultTargetPlatformOverride = null;
});
```

## Performance and Timeout Issues

### 1. Tests Running Slowly

**Problem**: Test suite takes too long to execute.

**Solution**:
```dart
// Run tests in parallel
// In dart_test.yaml:
test_on: "vm"
paths:
  - test/unit
  - test/widget
concurrency: 4

// Optimize setUp/tearDown
// Use setUpAll for expensive operations
setUpAll(() async {
  // Initialize once
});

// Share mocks between tests
late MockService sharedMock;
setUpAll(() {
  sharedMock = MockService();
});
```

### 2. Flaky Tests

**Problem**: Tests pass/fail inconsistently.

**Solution**:
```dart
// Add explicit waits
await tester.pumpAndSettle();

// Wait for specific conditions
await tester.pumpUntil(
  find.text('Loaded'),
  timeout: const Duration(seconds: 5),
);

// Use retry for network-dependent tests
@Retry(3)
test('flaky network test', () async {
  // Test code
});
```

## CI/CD Pipeline Issues

### 1. Tests Pass Locally but Fail in CI

**Problem**: Different behavior in CI environment.

**Solution**:
```yaml
# In GitHub Actions, match local environment
- name: Run tests
  run: |
    flutter test --coverage
    flutter test --machine > test-results.json
  env:
    FLUTTER_TEST_PLATFORM: linux
```

### 2. Coverage Reports Not Generated

**Problem**: Code coverage missing or incomplete.

**Solution**:
```bash
# Generate coverage
cmd.exe /c "flutter test --coverage"

# Convert to lcov format
cmd.exe /c "flutter pub run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib"
```

## Advanced Debugging Techniques

### 1. Widget Tree Inspection

```dart
// Print widget tree
debugDumpApp();

// Print render tree
debugDumpRenderTree();

// Print specific widget info
final widget = tester.widget<Container>(find.byType(Container));
print('Container properties: ${widget.toString()}');
```

### 2. Test Timeline Debugging

```dart
// Enable timeline in tests
await tester.runAsync(() async {
  Timeline.startSync('Test Operation');
  // Your async operation
  Timeline.finishSync();
});

// Get timeline events
final Timeline timeline = await tester.binding.watchPerformance(() async {
  // Your test code
});
```

### 3. Mock Verification Debugging

```dart
// Verify specific calls
verify(() => mockService.method(
  argThat(predicate((arg) {
    print('Argument received: $arg');
    return arg.property == expectedValue;
  })),
)).called(1);

// Check all interactions
verifyNoMoreInteractions(mockService);
```

### 4. Async Operation Debugging

```dart
// Track async operations
await tester.runAsync(() async {
  print('Starting async operation');
  await Future.delayed(const Duration(seconds: 1));
  print('Async operation complete');
});

// Ensure all microtasks complete
await tester.idle();
```

## Best Practices for Avoiding Issues

1. **Always use keys for important widgets**
   ```dart
   Container(key: const Key('important-container'))
   ```

2. **Dispose resources properly**
   ```dart
   tearDown(() {
     controller.dispose();
     subscription.cancel();
   });
   ```

3. **Use const constructors in tests**
   ```dart
   const testWidget = MyWidget();
   ```

4. **Mock time-dependent operations**
   ```dart
   await tester.pump(const Duration(seconds: 1));
   ```

5. **Test error cases explicitly**
   ```dart
   when(() => mock.method()).thenThrow(Exception('Test error'));
   ```

## Getting Help

If you encounter issues not covered here:

1. Check Flutter test output carefully - error messages often contain hints
2. Run with verbose flag: `flutter test -v`
3. Search Flutter GitHub issues
4. Ask in Flutter Discord #testing channel
5. Create minimal reproduction and file issue

Remember: Good tests are deterministic, fast, and independent. If a test is flaky, it's usually pointing to a real issue in either the test or the code being tested.