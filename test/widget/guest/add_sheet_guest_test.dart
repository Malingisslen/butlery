// BUT-920: the add sheet for a guest. The quota line, the "Räknas som en
// import" subtitles, a fresh import id per import, and the limit sheet at zero.

import 'dart:async';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/guest/guest_import_session.dart';
import 'package:butlery/widgets/common/navigation/add_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'guest_test_support.dart';

final _sv = AppLocalizationsSv();

class _Pushes extends NavigatorObserver {
  final pushed = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route.settings.name);
  }
}

// A guest's choice waits for the stored count to be read.
class _SlowSession extends GuestImportSession {
  _SlowSession() : super(uid: () => 'uid-1');

  final gate = Completer<void>();

  @override
  Future<void> load() => gate.future;
}

void main() {
  tearDown(resetLocator);

  Future<GuestImportSession> register({
    required bool guest,
    int used = 0,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (used > 0)
        'guest_imports_used_uid-1': [for (var i = 0; i < used; i++) 'id$i'],
    });
    registerAuth(FakeAuthService(FakeUser(isAnonymous: guest)));
    final session = GuestImportSession(uid: () => 'uid-1');
    GetIt.instance.registerSingleton<GuestImportSession>(session);
    return session;
  }

  Future<void> open(WidgetTester tester, {NavigatorObserver? observer}) async {
    late BuildContext context;
    await tester.pumpWidget(
      guestApp(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
        observer: observer,
      ),
    );
    showButleryAddSheet(context);
    await tester.pumpAndSettle();
  }

  Finder tile(String identifier) =>
      find.byKey(ValueKey('test-add-sheet-$identifier'));

  testWidgets('a guest sees what is left and which tiles count', (
    tester,
  ) async {
    await register(guest: true, used: 1);
    await open(tester);

    expect(find.text('2 av 3 importer kvar som gäst'), findsOneWidget);
    expect(find.text(_sv.guestCountsAsImport), findsNWidgets(2));
    for (final id in ['btn-import-url', 'btn-photo-import']) {
      expect(
        find.descendant(
          of: tile(id),
          matching: find.text(_sv.guestCountsAsImport),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('someone who is not a guest sees none of it', (tester) async {
    await register(guest: false, used: 1);
    await open(tester);

    expect(find.textContaining('importer kvar'), findsNothing);
    expect(find.text(_sv.guestCountsAsImport), findsNothing);
  });

  testWidgets('choosing link import starts a new import and opens the '
      'view', (tester) async {
    final session = await register(guest: true);
    final pushes = _Pushes();
    await open(tester, observer: pushes);
    final before = session.currentId;

    await tester.tap(tile('btn-import-url'));
    await tester.pumpAndSettle();

    expect(session.currentId, isNot(before));
    expect(pushes.pushed, contains(Routes.smartImport));
  });

  for (final id in ['btn-import-url', 'btn-photo-import']) {
    testWidgets('$id with no imports left opens the limit sheet instead of '
        'the view', (tester) async {
      await register(guest: true, used: 3);
      await open(tester);
      expect(find.text('0 av 3 importer kvar som gäst'), findsOneWidget);

      await tester.tap(tile(id));
      await tester.pumpAndSettle();

      expect(find.text(_sv.guestSheetImportLimitTitle), findsOneWidget);
      expect(find.text('pushed'), findsNothing);
    });
  }

  testWidgets('manual entry is open to a guest with no imports left', (
    tester,
  ) async {
    await register(guest: true, used: 3);
    await open(tester);

    await tester.tap(tile('btn-write-manually'));
    await tester.pumpAndSettle();

    expect(find.text(_sv.guestSheetImportLimitTitle), findsNothing);
    expect(find.text('pushed'), findsOneWidget);
  });

  testWidgets('photo import as a guest starts a new import and opens the '
      'view', (tester) async {
    final session = await register(guest: true);
    final pushes = _Pushes();
    await open(tester, observer: pushes);
    final before = session.currentId;

    await tester.tap(tile('btn-photo-import'));
    await tester.pumpAndSettle();

    expect(session.currentId, isNot(before));
    expect(pushes.pushed, contains(Routes.photoImport));
    expect(pushes.pushed, isNot(contains(Routes.smartImport)));
  });

  testWidgets('tapping link import twice while the count is still being read '
      'opens the view once', (tester) async {
    SharedPreferences.setMockInitialValues({});
    registerAuth(FakeAuthService(FakeUser(isAnonymous: true)));
    final session = _SlowSession();
    GetIt.instance.registerSingleton<GuestImportSession>(session);
    final pushes = _Pushes();
    await open(tester, observer: pushes);

    await tester.tap(tile('btn-import-url'));
    await tester.pump();
    await tester.tap(tile('btn-import-url'), warnIfMissed: false);
    await tester.pump();
    session.gate.complete();
    await tester.pumpAndSettle();

    expect(pushes.pushed.where((r) => r == Routes.smartImport), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('someone who is not a guest is never stopped by a used-up '
      'count', (tester) async {
    await register(guest: false, used: 3);
    final pushes = _Pushes();
    await open(tester, observer: pushes);

    await tester.tap(tile('btn-import-url'));
    await tester.pumpAndSettle();

    expect(find.text(_sv.guestSheetImportLimitTitle), findsNothing);
    expect(pushes.pushed, contains(Routes.smartImport));
  });
}
