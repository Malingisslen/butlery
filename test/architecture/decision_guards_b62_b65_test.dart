// Guards for the design decisions B-62 to B-64 (kept as test names): field
// and button height, the round avatar steps and the dark profile header. See decision_guards_b56_b61_test.

import 'dart:io';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:flutter_test/flutter_test.dart';

String _source(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is gone; update the guard');
  return file
      .readAsStringSync()
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//[^\n]*'), '');
}

void main() {
  group('B-62 fält och knappar är 40 px men träffytan är 48 dp', () {
    test('måtten är de beslutade', () {
      expect(AppDimensions.controlVisualHeight, 40);
      expect(AppDimensions.fieldVisualPaddingY, 8);
      expect(AppDimensions.fieldTapPad, 4);
    });

    test('den ritade höjden plus träffytan når golvet i B-03', () {
      expect(
        AppDimensions.controlVisualHeight + 2 * AppDimensions.fieldTapPad,
        greaterThanOrEqualTo(AppDimensions.minTouchTarget),
      );
    });

    test('knappar och fält läser höjden ur AppDimensions', () {
      // One read per button theme (elevated, filled, outlined, text and the
      // hero style), so a single button drifting to its own height is caught.
      expect(
        'AppDimensions.controlVisualHeight'
            .allMatches(_source('lib/theme/components/button_themes.dart'))
            .length,
        5,
        reason: 'B-62: en knapp ritar inte längre med det delade måttet',
      );
      expect(
        'AppDimensions.fieldVisualPaddingY'
            .allMatches(_source('lib/theme/components/input_themes.dart'))
            .length,
        1,
        reason: 'B-62: fältet ritar inte längre med det delade måttet',
      );
    });
  });

  group('B-63 personer är runda AvatarCircle i tre steg', () {
    test('stegen är 26, 32 och 56 px', () {
      expect(
        [for (final s in AvatarCircleSize.values) s.pixels],
        [26, 32, 56],
      );
      expect(AvatarCircleSize.values.map((s) => s.name), [
        'inline',
        'row',
        'header',
      ]);
    });
  });

  group('B-64 vännens och den publika profilen har ett mörkt huvud', () {
    test('båda vyerna ritar huvudet med ProfileHeader', () {
      for (final path in const [
        'lib/views/social/friend_profile_view.dart',
        'lib/views/social/public_profile_view.dart',
      ]) {
        expect(
          _source(path).contains('ProfileHeader('),
          isTrue,
          reason: 'B-64: $path ritar inte längre det delade huvudet',
        );
      }
    });

    test('huvudet är ett ink-band med den stora avataren', () {
      final code = _source('lib/widgets/social/profile_header.dart');
      expect(code.contains('color: cs.primary'), isTrue);
      expect(code.contains('AvatarCircleSize.header'), isTrue);
      expect(code.contains('AvatarCircleTone.onInk'), isTrue);
    });
  });
}
