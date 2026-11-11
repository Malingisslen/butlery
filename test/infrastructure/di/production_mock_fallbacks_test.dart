import 'dart:io';

import 'package:butlery/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tools/test_mock_fallbacks.dart';
import 'test_service_locator.dart';

void main() {
  test('the generated fallback mocks match the production DI modules', () {
    final current = File(outputPath).readAsStringSync();
    expect(
      current,
      formatted(buildFallbackFile('.')),
      reason:
          'A service was added to or removed from lib/core/di. Run: '
          'dart run tools/test_mock_fallbacks.dart',
    );
  });

  test('a hand-written fake wins over the generated fallback', () async {
    await TestServiceLocator.initialize();
    addTearDown(TestServiceLocator.reset);
    expect(
      TestServiceLocator.get<AuthService>().runtimeType.toString(),
      isNot(startsWith('_M')),
    );
  });
}
