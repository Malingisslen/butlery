import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('ButleryCheckbox', () {
    testWidgets('draws the token box on a 48 dp touch target', (tester) async {
      await _pump(tester, ButleryCheckbox(value: false, onChanged: (_) {}));

      expect(tester.getSize(find.byType(ButleryCheckbox)).width, 48);
      expect(tester.getSize(find.byType(ButleryCheckbox)).height, 48);
      // Material's 18 dp box is scaled to the token's 24 dp.
      expect(tester.getSize(find.byType(Checkbox)), const Size(24, 24));
    });

    testWidgets('a tap on the box toggles once', (tester) async {
      final seen = <bool>[];
      await _pump(tester, ButleryCheckbox(value: false, onChanged: seen.add));

      await tester.tap(find.byType(Checkbox));
      expect(seen, [true]);
    });

    testWidgets('a tap in the padding beside the box toggles once', (
      tester,
    ) async {
      final seen = <bool>[];
      await _pump(tester, ButleryCheckbox(value: true, onChanged: seen.add));

      final rect = tester.getRect(find.byType(ButleryCheckbox));
      await tester.tapAt(rect.bottomLeft + const Offset(3, -3));
      expect(seen, [false]);
    });

    testWidgets('without onChanged it does not toggle', (tester) async {
      await _pump(tester, const ButleryCheckbox(value: false, onChanged: null));

      await tester.tap(find.byType(Checkbox), warnIfMissed: false);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    });
  });

  group('ButleryCheckboxTile', () {
    testWidgets('a tap on the row toggles once and reads as one checked stop', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final seen = <bool>[];
      await _pump(
        tester,
        ButleryCheckboxTile(
          value: true,
          onChanged: seen.add,
          title: const Text('Anna'),
        ),
      );

      await tester.tap(find.text('Anna'));
      expect(seen, [false]);
      expect(
        tester.getSemantics(find.byType(ButleryCheckboxTile)),
        matchesSemantics(
          label: 'Anna',
          hasCheckedState: true,
          isButton: true,
          hasSelectedState: true,
          isChecked: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('the box ends the row by default and leads with boxFirst', (
      tester,
    ) async {
      await _pump(
        tester,
        ButleryCheckboxTile(
          value: false,
          onChanged: (_) {},
          title: const Text('Anna'),
        ),
      );
      expect(
        tester.getCenter(find.byType(ButleryCheckbox)).dx,
        greaterThan(tester.getCenter(find.text('Anna')).dx),
      );

      await _pump(
        tester,
        ButleryCheckboxTile(
          value: false,
          onChanged: (_) {},
          title: const Text('Anna'),
          boxFirst: true,
        ),
      );
      expect(
        tester.getCenter(find.byType(ButleryCheckbox)).dx,
        lessThan(tester.getCenter(find.text('Anna')).dx),
      );
    });

    testWidgets('without onChanged the row does not toggle', (tester) async {
      await _pump(
        tester,
        const ButleryCheckboxTile(
          value: false,
          onChanged: null,
          title: Text('Anna'),
        ),
      );

      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.enabled, isFalse);
      expect(tile.onTap, isNull);
    });
  });
}
