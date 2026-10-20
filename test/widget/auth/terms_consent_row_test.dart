// The terms box ignored clicks on the web while its words
// worked, because the box is drawn outside the screen-reader node and a
// screen-sized tap node from the app shell took the click.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/app/session_activity_detector.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/auth/terms_consent_row.dart';

Future<List<bool>> _pump(
  WidgetTester tester, {
  bool accepted = false,
  bool inAppShell = false,
}) async {
  final seen = <bool>[];
  Widget row = Padding(
    padding: const EdgeInsets.all(16),
    child: TermsConsentRow(accepted: accepted, onChanged: seen.add),
  );
  if (inAppShell) {
    row = SessionActivityDetector(onActivity: () {}, child: row);
  }
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      theme: AppTheme.lightTheme,
      home: Scaffold(body: row),
    ),
  );
  return seen;
}

void main() {
  testWidgets('a tap on the drawn box toggles once', (tester) async {
    final seen = await _pump(tester);

    await tester.tap(find.byType(Checkbox));

    expect(seen, [true]);
  });

  testWidgets('a tap on the opening words toggles once', (tester) async {
    final seen = await _pump(tester, accepted: true);

    final row = tester.getRect(find.byType(TermsConsentRow));
    await tester.tapAt(row.topLeft + const Offset(40, 24));

    expect(seen, [false]);
  });

  testWidgets('no node with a tap action covers the box in the app shell', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, inAppShell: true);

    final box = tester.getCenter(find.byType(Checkbox));
    final covering = <String>[];
    void walk(SemanticsNode node, Matrix4 parent) {
      final transform = node.transform;
      final toGlobal = transform == null ? parent : parent * transform;
      final rect = MatrixUtils.transformRect(toGlobal, node.rect);
      final data = node.getSemanticsData();
      if (rect.contains(box) && data.hasAction(SemanticsAction.tap)) {
        covering.add('$rect ${data.label}');
      }
      node.visitChildren((child) {
        walk(child, toGlobal);
        return true;
      });
    }

    var root = tester.getSemantics(find.byType(TermsConsentRow));
    while (root.parent != null) {
      root = root.parent!;
    }
    walk(root, Matrix4.identity());

    // The web browser hands a click to the element on top at that point; a
    // tappable node here would be that element, and the box would never see it.
    expect(covering, isEmpty);
    handle.dispose();
  });
}
