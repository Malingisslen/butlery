/// Widget tests for AdaptiveSwitch + AdaptiveSwitchListTile.
///
/// Both widgets branch on `dart:io Platform.isIOS` (NOT
/// `defaultTargetPlatform`), so `debugDefaultTargetPlatformOverride` has no
/// effect. In the Flutter test environment the host is always
/// Windows/Linux/macOS, so the Cupertino branch is unreachable from a unit
/// widget test — we cover the Material branch (the path Android/web/desktop
/// users hit, which is the majority surface). The iOS Cupertino branch is
/// covered by manual QA on iOS hardware.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/input/adaptive_switch.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('AdaptiveSwitch — Material branch', () {
    testWidgets('renders a Material Switch with provided value=true',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveSwitch(value: true, onChanged: (_) {}),
      ));
      expect(find.byType(Switch), findsOneWidget);
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isTrue);
    });

    testWidgets('renders with value=false', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveSwitch(value: false, onChanged: (_) {}),
      ));
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isFalse);
    });

    testWidgets('onChanged fires with toggled value when tapped',
        (tester) async {
      bool? received;
      await tester.pumpWidget(_wrap(
        AdaptiveSwitch(
          value: false,
          onChanged: (v) => received = v,
        ),
      ));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(received, isTrue);
    });

    testWidgets('onChanged=null → switch is disabled (no callback)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveSwitch(value: false, onChanged: null),
      ));
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.onChanged, isNull);
    });

    testWidgets(
        'activeColor → activeThumbColor + activeTrackColor at 50% alpha',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveSwitch(
          value: true,
          onChanged: (_) {},
          activeColor: const Color(0xFF112233),
        ),
      ));
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.activeThumbColor, const Color(0xFF112233));
      expect(
        sw.activeTrackColor,
        const Color(0xFF112233).withValues(alpha: AppDimensions.opacityHalf),
      );
    });

    testWidgets('trackColor → inactiveTrackColor', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveSwitch(
          value: false,
          onChanged: (_) {},
          trackColor: Colors.grey,
        ),
      ));
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.inactiveTrackColor, Colors.grey);
    });

    testWidgets('thumbColor wraps in WidgetStateProperty.all', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveSwitch(
          value: true,
          onChanged: (_) {},
          thumbColor: Colors.red,
        ),
      ));
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.thumbColor, isNotNull);
      expect(sw.thumbColor!.resolve(<WidgetState>{}), Colors.red);
    });

    testWidgets('thumbColor=null → Switch.thumbColor is null', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveSwitch(value: true, onChanged: (_) {}),
      ));
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.thumbColor, isNull);
    });

    testWidgets('activeColor=null → activeTrackColor is null', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveSwitch(value: true, onChanged: (_) {}),
      ));
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.activeThumbColor, isNull);
      expect(sw.activeTrackColor, isNull);
    });
  });

  group('AdaptiveSwitchListTile — Material branch', () {
    testWidgets('renders a SwitchListTile with title and subtitle',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveSwitchListTile(
          value: false,
          onChanged: (_) {},
          title: const Text('Aviseringar'),
          subtitle: const Text('Få push-notiser'),
        ),
      ));
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.text('Aviseringar'), findsOneWidget);
      expect(find.text('Få push-notiser'), findsOneWidget);
    });

    testWidgets('renders a secondary leading widget', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveSwitchListTile(
          value: true,
          onChanged: (_) {},
          title: const Text('t'),
          secondary: const Icon(Icons.notifications),
        ),
      ));
      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });

    testWidgets('tile.value reflects prop', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveSwitchListTile(
          value: true,
          onChanged: (_) {},
          title: const Text('t'),
        ),
      ));
      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.value, isTrue);
    });

    testWidgets('onChanged callback fires with new value', (tester) async {
      bool? captured;
      await tester.pumpWidget(_wrap(
        AdaptiveSwitchListTile(
          value: false,
          onChanged: (v) => captured = v,
          title: const Text('t'),
        ),
      ));
      // SwitchListTile is tappable on the whole row.
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(captured, isTrue);
    });

    testWidgets('onChanged=null → tile is disabled', (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveSwitchListTile(
          value: false,
          onChanged: null,
          title: Text('t'),
        ),
      ));
      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.onChanged, isNull);
    });

    testWidgets('activeColor → activeThumbColor + activeTrackColor 50% alpha',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveSwitchListTile(
          value: true,
          onChanged: (_) {},
          title: const Text('t'),
          activeColor: const Color(0xFFAABBCC),
        ),
      ));
      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.activeThumbColor, const Color(0xFFAABBCC));
      expect(
        tile.activeTrackColor,
        const Color(0xFFAABBCC).withValues(alpha: AppDimensions.opacityHalf),
      );
    });

    testWidgets('contentPadding and dense are forwarded', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveSwitchListTile(
          value: true,
          onChanged: (_) {},
          title: const Text('t'),
          contentPadding: const EdgeInsets.all(11),
          dense: true,
        ),
      ));
      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.contentPadding, const EdgeInsets.all(11));
      expect(tile.dense, isTrue);
    });
  });

  // SKIP: iOS branch (CupertinoSwitch path) — `Platform.isIOS` cannot be
  // overridden via `debugDefaultTargetPlatformOverride` and the test host is
  // never iOS. Exercised by manual QA on iOS hardware.
}
