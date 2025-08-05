/// Lightweight test configuration specifically for golden tests.
///
/// Golden tests need minimal setup and should avoid heavy initialization
/// that can cause timeouts or interfere with visual testing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

/// Configure golden tests with minimal setup.
///
/// Call this instead of configureTests() in golden test files:
/// ```dart
/// void main() {
///   configureGoldenTests();
///   
///   testGoldens('my golden test', (tester) async {
///     // Your golden test here
///   });
/// }
/// ```
void configureGoldenTests() {
  setUpAll(() async {
    // Only load fonts for golden tests
    await loadAppFonts();
  });
}

/// Helper to precache network images for golden tests.
///
/// This prevents HTTP requests during golden tests which cause timeouts.
/// Call this in setUpAll() if your widgets use network images.
Future<void> precacheTestImages(WidgetTester tester, List<String> imageUrls) async {
  for (final url in imageUrls) {
    await tester.runAsync(() async {
      final image = NetworkImage(url);
      await precacheImage(image, tester.element(find.byType(MaterialApp)));
    });
  }
}