import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/widgets/common/swipe_hint_banner.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

/// BUT-982: the recipe-list swipe hint teaches the hidden swipe-to-edit/delete
/// gesture, shown once per device. These pin the contract that matters: it
/// shows on first use, hides once the seen-flag is set, and dismissing both
/// hides it AND persists the flag (so it never returns).
void main() {
  Widget app() => createLocalizedTestApp(child: const SwipeHintBanner());

  group('SwipeHintBanner (BUT-982)', () {
    testWidgets('renders on first use (no seen flag)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.swipe), findsOneWidget);
    });

    testWidgets('does not render once the seen flag is set', (tester) async {
      SharedPreferences.setMockInitialValues({SwipeHintBanner.seenKey: true});
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.swipe), findsNothing);
    });

    testWidgets('dismiss hides the banner and persists the seen flag',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.swipe), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.swipe), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SwipeHintBanner.seenKey), isTrue);
    });
  });
}
