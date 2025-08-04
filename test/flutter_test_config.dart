import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

/// Global test configuration for Flutter tests including golden test setup
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Set up test environment
  TestWidgetsFlutterBinding.ensureInitialized();

  // Configure golden toolkit
  await loadAppFonts();

  // Run tests
  return testMain();
}
