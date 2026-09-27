/// P8-U01: the rules can fail. Controls for the colour set and for the
/// LOADING and OFFLINE rules, so a rule that stopped seeing anything would
/// not pass the 53 states by being blind.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/indicators/plate_line.dart';

import 'state_harness.dart';
import 'state_rules.dart';

Widget _page(Widget body, {Brightness mode = Brightness.light}) => stateApp(
  mode: mode,
  home: Scaffold(body: body),
);

void main() {
  group('the allowed colours', () {
    final light = AllowedColours.forMode(Brightness.light);
    final dark = AllowedColours.forMode(Brightness.dark);

    test('a token, a ladder alpha and transparent pass; a Material grey '
        'does not', () {
      expect(light.allows(const Color(0xFF24382C)), isTrue);
      expect(light.allows(const Color(0x9924382C)), isTrue, reason: '0.6');
      expect(light.allows(const Color(0x00123456)), isTrue);
      expect(light.allows(const Color(0xFF616161)), isFalse);
      expect(light.allows(const Color(0xB324382C)), isFalse, reason: '0.7');
    });

    test('dark mode refuses a light-only value and keeps the palette', () {
      // text.body light #37453A is not a dark value.
      expect(dark.allows(const Color(0xFF37453A)), isFalse);
      expect(dark.allows(const Color(0xFFF5F4ED)), isTrue);
      // palette.saffron is one value in both modes.
      expect(dark.allows(const Color(0xFFCE7C1E)), isTrue);
    });
  });

  group('the rules on a pumped tree', () {
    testWidgets('LOADING: a spinner is found, a plate line with text passes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _page(const Center(child: CircularProgressIndicator())),
      );
      expect(
        loadingRule(earlyCheck: const []).map((v) => v.code),
        containsAll(['SPINNER', 'NO_PLATE_LINE', 'NO_LOADING_TEXT']),
      );
      await tester.pumpWidget(
        _page(const Column(children: [PlateLine(), Text('Hämtar …')])),
      );
      expect(loadingRule(earlyCheck: const []), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('OFFLINE: a missing banner and a filled one are found', (
      tester,
    ) async {
      await tester.pumpWidget(_page(const Text('Veckans inköp')));
      expect(
        offlineRule(tester, Brightness.light).map((v) => v.code),
        contains('NO_OFFLINE_BANNER'),
      );
      await tester.pumpWidget(
        _page(
          Column(
            children: [
              ColoredBox(
                color: const Color(0xFFE6EAD9),
                child: Text(sv.indicatorOfflineMode),
              ),
              const Text('Veckans inköp'),
            ],
          ),
        ),
      );
      expect(
        offlineRule(tester, Brightness.light).map((v) => v.code),
        isNot(contains('NO_OFFLINE_BANNER')),
      );
      await tester.pumpWidget(
        _page(
          Column(
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFFE6EAD9)),
                child: Text(sv.indicatorOfflineMode),
              ),
              const Text('Veckans inköp'),
            ],
          ),
        ),
      );
      expect(
        offlineRule(tester, Brightness.light).map((v) => v.code),
        contains('BANNER_FILL'),
      );
    });

    testWidgets('two saffron buttons are counted', (tester) async {
      const saffron = Color(0xFFCE7C1E);
      final style = FilledButton.styleFrom(backgroundColor: saffron);
      await tester.pumpWidget(
        _page(
          Column(
            children: [
              FilledButton(
                onPressed: () {},
                style: style,
                child: const Text('A'),
              ),
              FilledButton(
                onPressed: () {},
                style: style,
                child: const Text('B'),
              ),
            ],
          ),
        ),
      );
      expect(saffronButtonCount(Brightness.light), 2);
    });
  });
}
