# Golden Test Strategy Guide 📸

## Overview
This guide helps developers choose the right golden testing approach based on what they're testing. We use two configurations: lightweight (fast) and full (comprehensive).

## Quick Decision Tree 🌳

```
Is your test purely visual (no service dependencies)?
├─ YES → Use Lightweight Golden Tests
└─ NO → Does it need real service behavior?
    ├─ YES → Use Full Integration Golden Tests
    └─ NO → Can you mock the dependencies?
        ├─ YES → Use Lightweight with Mocks
        └─ NO → Use Full Integration Golden Tests
```

## Approach Comparison

| Aspect | Lightweight (`configureGoldenTests()`) | Full (`configureTests()`) |
|--------|----------------------------------------|---------------------------|
| **Setup Time** | ~100ms ✅ | ~2-5 seconds ⚠️ |
| **Reliability** | Very High ✅ | Medium (can timeout) ⚠️ |
| **Service Coverage** | None ❌ | Full ✅ |
| **Network Images** | Must avoid ❌ | Can handle ✅ |
| **State Management** | Basic only ⚠️ | Full integration ✅ |
| **CI/CD Friendly** | Excellent ✅ | Good with timeouts ⚠️ |

## When to Use Lightweight Golden Tests 🚀

### ✅ Perfect For:

#### 1. **Pure UI Components**
```dart
// ✅ GOOD: Button variations
testGoldens('button styles', (tester) async {
  configureGoldenTests();
  // Test different button states, sizes, themes
});

// ✅ GOOD: Card layouts
testGoldens('recipe card layouts', (tester) async {
  configureGoldenTests();
  // Test with mock data, no images
});
```

#### 2. **Theme Testing**
```dart
// ✅ GOOD: Theme variations
testGoldens('dark/light theme comparison', (tester) async {
  configureGoldenTests();
  // Test color schemes, typography, spacing
});
```

#### 3. **Responsive Layouts**
```dart
// ✅ GOOD: Different screen sizes
testGoldens('responsive grid layouts', (tester) async {
  configureGoldenTests();
  // Test phone, tablet, desktop layouts
});
```

#### 4. **Static Animations**
```dart
// ✅ GOOD: Animation keyframes
testGoldens('loading animation frames', (tester) async {
  configureGoldenTests();
  // Capture animation at specific points
});
```

#### 5. **Typography & Spacing**
```dart
// ✅ GOOD: Text scaling
testGoldens('text accessibility scaling', (tester) async {
  configureGoldenTests();
  // Test 0.8x to 2.0x text scaling
});
```

### ❌ Avoid Lightweight For:
- Widgets that fetch data on mount
- Authentication-dependent UI
- Real-time features
- Network image galleries
- Error states from API calls

## When to Use Full Integration Golden Tests 🔧

### ✅ Perfect For:

#### 1. **Critical User Flows**
```dart
// ✅ GOOD: Complete user journey
testGoldens('recipe creation flow', (tester) async {
  configureTests(); // Full setup needed
  
  // Test the entire flow with real services
  await tester.pumpWidget(RecipeCreationFlow());
  await tester.enterText(find.byKey('title'), 'My Recipe');
  // ... complete flow with service calls
});
```

#### 2. **Service-Dependent UI States**
```dart
// ✅ GOOD: Loading/error states
testGoldens('data loading states', (tester) async {
  configureTests();
  
  // Test real loading → success → error flows
  when(() => mockService.fetchData())
    .thenAnswer((_) async {
      await Future.delayed(Duration(seconds: 1));
      throw Exception('Network error');
    });
});
```

#### 3. **Authentication UI**
```dart
// ✅ GOOD: Auth-dependent rendering
testGoldens('authenticated vs guest UI', (tester) async {
  configureTests();
  
  // Test UI differences based on auth state
  when(() => mockAuth.currentUser).thenReturn(testUser);
  // vs
  when(() => mockAuth.currentUser).thenReturn(null);
});
```

#### 4. **Real-time Features**
```dart
// ✅ GOOD: Live updates
testGoldens('chat message updates', (tester) async {
  configureTests();
  
  // Test real-time message rendering
  streamController.add(newMessage);
  await tester.pump();
});
```

### ⚠️ Use With Caution For:
- Simple components (overkill)
- CI/CD pipelines (timeout risk)
- Frequently changing UI (maintenance burden)

## Hybrid Strategies 🎯

### 1. **Mock Image Provider**
```dart
// For widgets with images in lightweight tests
class GoldenTestImageProvider {
  static Widget mockImage({
    required String url,
    double? width,
    double? height,
  }) {
    return Container(
      width: width ?? 100,
      height: height ?? 100,
      color: Colors.grey[300],
      child: Center(
        child: Icon(Icons.image, color: Colors.grey[600]),
      ),
    );
  }
}

// Usage in test
testGoldens('recipe card with mock images', (tester) async {
  configureGoldenTests();
  
  // Override image builder
  final recipe = Recipe(
    imageBuilder: (url) => GoldenTestImageProvider.mockImage(url: url),
  );
});
```

### 2. **Selective Service Mocking**
```dart
// Initialize only what you need
void configureSelectiveTests() {
  setUpAll(() async {
    await loadAppFonts();
    // Only initialize specific services
    TestServiceLocator.initializeOnly([
      AuthService,
      ThemeService,
    ]);
  });
}
```

### 3. **Progressive Enhancement**
```dart
// Start lightweight, add complexity as needed
group('RecipeCard Golden Tests', () {
  // Level 1: Pure visual
  testGoldens('basic appearance', (tester) async {
    configureGoldenTests();
    // Test static appearance
  });
  
  // Level 2: With state
  testGoldens('interactive states', (tester) async {
    configureGoldenTests();
    // Test hover, pressed, selected states
  });
  
  // Level 3: With services (only if critical)
  testGoldens('live data integration', (tester) async {
    configureTests();
    // Test with real service data
  }, skip: !isIntegrationTestRun); // Skip in normal test runs
});
```

## Best Practices 📋

### 1. **Name Tests Clearly**
```dart
// ✅ GOOD: Clear about what's being tested
'button_styles_all_variants.png'
'recipe_card_no_images_light_theme.png'
'auth_flow_complete_journey.png'

// ❌ BAD: Ambiguous names
'test1.png'
'widget.png'
```

### 2. **Document Image Dependencies**
```dart
testGoldens('gallery view', (tester) async {
  configureGoldenTests();
  
  // NOTE: Using placeholder containers instead of real images
  // to avoid network calls in golden tests.
  // See integration tests for image loading behavior.
});
```

### 3. **Separate Test Files**
```
test/golden/
├── components/        # Lightweight tests
│   ├── buttons/
│   ├── cards/
│   └── inputs/
├── integration/       # Full setup tests
│   ├── auth_flow/
│   ├── data_loading/
│   └── real_time/
└── themes/           # Lightweight tests
```

### 4. **CI/CD Configuration**
```yaml
# .github/workflows/tests.yml
jobs:
  golden-tests-lightweight:
    timeout-minutes: 5
    run: flutter test test/golden/components test/golden/themes
    
  golden-tests-integration:
    timeout-minutes: 15
    run: flutter test test/golden/integration
    if: github.event_name == 'pull_request' # Only on PRs
```

## Migration Checklist ✅

When updating existing golden tests:

1. **Identify dependencies**
   - [ ] Uses ServiceLocator? → Consider full setup
   - [ ] Has network images? → Use mocks or avoid
   - [ ] Needs auth state? → Consider full setup
   - [ ] Pure UI only? → Use lightweight

2. **Update configuration**
   ```dart
   // From:
   setUpAll(() async {
     await loadAppFonts();
   });
   
   // To (lightweight):
   configureGoldenTests();
   
   // Or to (full):
   configureTests();
   ```

3. **Handle images**
   ```dart
   // From:
   imageUrls: ['https://example.com/image.jpg']
   
   // To:
   imageUrls: [] // No images
   // OR
   imageWidget: GoldenTestImageProvider.mockImage()
   ```

4. **Test and verify**
   - [ ] Run with --update-goldens
   - [ ] Verify visual output is acceptable
   - [ ] Check execution time
   - [ ] Update documentation

## Summary 📝

- **Use Lightweight (80% of tests)**: Fast, reliable, perfect for pure UI
- **Use Full Setup (20% of tests)**: When you need real service behavior
- **Document your choice**: Help future maintainers understand why
- **Monitor performance**: If tests slow down, reconsider approach

Remember: The goal is fast, reliable tests that catch real issues. Choose the simplest approach that meets your testing needs.