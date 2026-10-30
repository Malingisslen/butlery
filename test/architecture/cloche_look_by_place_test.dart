import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The cloche has three looks and each has its own places (the table in
// .claude/rules/design-system.md, "The cloche"). A view does not pick a look:
// it uses the place's component. This test lists where each component may be
// constructed, so a fourth place has to be a decision, not a drive-by.

const _brandDir = 'lib/widgets/common/brand/';

final _places = <String, ({RegExp pattern, Set<String> allowedPrefixes})>{
  'ButleryClocheMark (outline mark on the green plate)': (
    pattern: RegExp(r'\bButleryClocheMark\s*\('),
    allowedPrefixes: {'lib/views/onboarding/'},
  ),
  'ButleryLockup (filled glyph with the wordmark)': (
    pattern: RegExp(r'\bButleryLockup\s*\('),
    allowedPrefixes: {'lib/widgets/auth/auth_surface.dart'},
  ),
  'StartSplash (the animated start screen)': (
    pattern: RegExp(r'\bStartSplash\s*\('),
    allowedPrefixes: {'lib/app/auth/auth_wrapper.dart'},
  ),
};

List<String> _libFiles() => [
  for (final e in Directory('lib').listSync(recursive: true))
    if (e is File && e.path.endsWith('.dart')) e.path.replaceAll(r'\', '/'),
];

void main() {
  final files = _libFiles();

  for (final entry in _places.entries) {
    test('${entry.key} is only built in its places', () {
      final found = <String>[];
      for (final path in files) {
        if (path.startsWith(_brandDir)) continue;
        if (entry.value.pattern.hasMatch(File(path).readAsStringSync())) {
          found.add(path);
        }
      }
      expect(found, isNotEmpty, reason: 'the component is no longer used');
      for (final path in found) {
        expect(
          entry.value.allowedPrefixes.any(path.startsWith),
          isTrue,
          reason:
              '$path builds ${entry.key}; its places are '
              '${entry.value.allowedPrefixes.join(', ')}',
        );
      }
    });
  }
}
