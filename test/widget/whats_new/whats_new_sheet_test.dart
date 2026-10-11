import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/whats_new/whats_new_catalog.dart';
import 'package:butlery/services/whats_new/whats_new_service.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/whats_new/whats_new_sheet.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

WhatsNewItem _item(String name, {String? route}) =>
    WhatsNewItem(title: (_) => 'T $name', body: (_) => 'B $name', route: route);

final _releases = [
  WhatsNewRelease(
    version: '1.4',
    items: [
      _item('foto', route: '/photo'),
      _item('plain'),
    ],
  ),
  WhatsNewRelease(version: '1.3', items: [_item('old')]),
];

Future<void> _open(WidgetTester tester, List<WhatsNewRelease> releases) async {
  await tester.pumpWidget(
    createLocalizedTestApp(
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Scaffold(body: Text('route ${settings.name}')),
      ),
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () => showWhatsNewSheet(context, releases),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  final sv = AppLocalizationsSv();

  testWidgets('renders the range eyebrow, heading and numbered items', (
    tester,
  ) async {
    await _open(tester, _releases);

    expect(find.text(sv.whatsNewVersionRange('1.3', '1.4')), findsOneWidget);
    expect(find.text(sv.whatsNewTitle), findsOneWidget);
    for (final name in ['foto', 'plain', 'old']) {
      expect(find.text('T $name'), findsOneWidget);
      expect(find.text('B $name'), findsOneWidget);
    }
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('a single release shows a single version eyebrow', (
    tester,
  ) async {
    await _open(tester, [_releases.first]);

    expect(find.text(sv.settingsAboutVersion('1.4')), findsOneWidget);
  });

  testWidgets('tapping a routed item closes the sheet and pushes the route', (
    tester,
  ) async {
    await _open(tester, _releases);

    await tester.tap(find.text('T foto'));
    await tester.pumpAndSettle();

    expect(find.text('route /photo'), findsOneWidget);
    expect(find.text(sv.whatsNewTitle), findsNothing);
  });

  testWidgets('an item without a route has no chevron or button semantics', (
    tester,
  ) async {
    await _open(tester, _releases);

    final routed = find.byKey(const ValueKey('whats-new-item-0'));
    final plain = find.byKey(const ValueKey('whats-new-item-1'));
    expect(
      find.descendant(of: routed, matching: find.byType(ButleryIcon)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: plain, matching: find.byType(ButleryIcon)),
      findsNothing,
    );
    expect(
      find.descendant(of: plain, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: routed,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.button == true,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the routed item meets the 48 dp touch target', (tester) async {
    await _open(tester, _releases);

    // Real items are taller than 48 dp anyway, so the floor itself is pinned.
    final floors = tester
        .widgetList<ConstrainedBox>(
          find.descendant(
            of: find.byKey(const ValueKey('whats-new-item-0')),
            matching: find.byType(ConstrainedBox),
          ),
        )
        .where((b) => b.constraints.minHeight >= 48);
    expect(floors, isNotEmpty);
  });

  testWidgets('the heading is a semantics header', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester, _releases);

    expect(
      tester.getSemantics(find.text(sv.whatsNewTitle)),
      matchesSemantics(label: sv.whatsNewTitle, isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('Toppen closes the sheet without navigating', (tester) async {
    await _open(tester, _releases);

    await tester.tap(find.text(sv.whatsNewDone));
    await tester.pumpAndSettle();

    expect(find.text(sv.whatsNewTitle), findsNothing);
    expect(find.textContaining('route '), findsNothing);
  });

  group('showWhatsNewIfDue', () {
    Future<void> pumpTrigger(WidgetTester tester, String version) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showWhatsNewIfDue(
                context,
                appVersion: version,
                catalog: _releases,
              ),
              child: const Text('start'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the sheet once after an update', (tester) async {
      SharedPreferences.setMockInitialValues({
        WhatsNewService.lastSeenKey: '1.2',
      });

      await pumpTrigger(tester, '1.4');
      expect(find.text(sv.whatsNewTitle), findsOneWidget);

      await tester.tap(find.text(sv.whatsNewDone));
      await tester.pumpAndSettle();
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      expect(find.text(sv.whatsNewTitle), findsNothing);
    });

    testWidgets('shows nothing on a first install', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await pumpTrigger(tester, '1.4');

      expect(find.text(sv.whatsNewTitle), findsNothing);
    });
  });
}
