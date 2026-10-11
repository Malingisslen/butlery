// BUT-920: Mer for a guest. The profile row gives way to the guest band, the
// rows that need an account say so and open the sheet instead of a page, and
// Konto & säkerhet says Gäst but still leads where it did.

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/views/more/more_view.dart';
import 'package:butlery/widgets/guest/guest_band.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../guest/guest_test_support.dart';
import '../sync/fake_sync_queue_source.dart';

final _sv = AppLocalizationsSv();

class _Pushes extends NavigatorObserver {
  final pushed = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route.settings.name);
  }
}

const _needAccount = {
  Routes.messages,
  Routes.friends,
  Routes.shared,
  Routes.settingsFamily,
};

void main() {
  setUp(() => SyncQueueSource.debugOverride = FakeSyncQueueSource());

  tearDown(() async {
    SyncQueueSource.debugOverride = null;
    await resetLocator();
  });

  Future<_Pushes> pump(WidgetTester tester, {required bool guest}) async {
    tester.view.physicalSize = const Size(412, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    registerAuth(FakeAuthService(FakeUser(isAnonymous: guest)));
    final pushes = _Pushes();
    await tester.pumpWidget(
      guestApp(const MoreView(), observer: pushes),
    );
    await tester.pump();
    return pushes;
  }

  Finder valueIn(String route, String text) => find.descendant(
    of: find.byKey(MoreView.rowKey(route)),
    matching: find.text(text),
  );

  testWidgets('a guest sees the band in place of the profile row', (
    tester,
  ) async {
    await pump(tester, guest: true);

    expect(find.byType(GuestBand), findsOneWidget);
    expect(find.byKey(MoreView.rowKey(Routes.profileEdit)), findsNothing);
  });

  testWidgets('a signed-in user keeps the profile row and sees no guest '
      'text', (tester) async {
    await pump(tester, guest: false);

    expect(find.byType(GuestBand), findsNothing);
    expect(find.byKey(MoreView.rowKey(Routes.profileEdit)), findsOneWidget);
    expect(find.text(_sv.guestRequiresAccount), findsNothing);
    expect(find.text(_sv.guestAccountValue), findsNothing);
  });

  for (final route in _needAccount) {
    testWidgets('$route says "Kräver konto" and opens the sheet', (
      tester,
    ) async {
      final pushes = await pump(tester, guest: true);
      pushes.pushed.clear();
      expect(valueIn(route, _sv.guestRequiresAccount), findsOneWidget);

      await tester.tap(find.byKey(MoreView.rowKey(route)));
      await tester.pumpAndSettle();

      expect(find.text(_sv.guestSheetTogetherTitle), findsOneWidget);
      expect(pushes.pushed, isNot(contains(route)));
    });
  }

  testWidgets('Konto & säkerhet says Gäst and still opens the account page', (
    tester,
  ) async {
    final pushes = await pump(tester, guest: true);
    pushes.pushed.clear();
    expect(
      valueIn(Routes.settingsAccount, _sv.guestAccountValue),
      findsOneWidget,
    );

    await tester.tap(find.byKey(MoreView.rowKey(Routes.settingsAccount)));
    await tester.pumpAndSettle();

    expect(pushes.pushed, [Routes.settingsAccount]);
  });

  testWidgets('rows that need no account are untouched for a guest', (
    tester,
  ) async {
    final pushes = await pump(tester, guest: true);
    pushes.pushed.clear();

    await tester.tap(find.byKey(MoreView.rowKey(Routes.settingsAllergens)));
    await tester.pumpAndSettle();

    expect(pushes.pushed, [Routes.settingsAllergens]);
  });
}
