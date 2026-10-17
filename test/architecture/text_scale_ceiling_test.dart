// B-170 (refines B-164): the app-wide text-scale ceiling is 200 %, read from
// one constant at both places that clamp the root MediaQuery.

import 'dart:io';

import 'package:butlery/core/utils/accessibility_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the ceiling is 200 % and the root clamps read it, not a literal', () {
    expect(AccessibilityUtils.maxTextScale, 2.0);
    for (final path in [
      'lib/app/butlery_app.dart',
      'lib/widgets/maintenance_mode_blocker.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(
        src,
        contains('maxScaleFactor: AccessibilityUtils.maxTextScale'),
        reason: '$path no longer clamps to the shared ceiling',
      );
    }
  });
}
