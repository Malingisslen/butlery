// BUT-920: the share gate recipes use, and the listener that opens the limit
// sheet when the server refuses a guest's import.

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/guest/guest_import_session.dart';
import 'package:butlery/widgets/guest/guest_account_sheet.dart';
import 'package:butlery/widgets/guest/guest_gate.dart';
import 'package:butlery/widgets/guest/guest_import_limit_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'guest_test_support.dart';

final _sv = AppLocalizationsSv();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(resetLocator);

  group('offerAccountIfGuest', () {
    Future<bool> tapShare(WidgetTester tester, {required bool guest}) async {
      registerAuth(FakeAuthService(FakeUser(isAnonymous: guest)));
      var stopped = false;
      await tester.pumpWidget(
        guestApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => stopped = offerAccountIfGuest(
                context,
                GuestAccountReason.share,
              ),
              child: const Text('dela'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('dela'));
      await tester.pumpAndSettle();
      return stopped;
    }

    testWidgets('a guest gets the share sheet and the share stops', (
      tester,
    ) async {
      expect(await tapShare(tester, guest: true), isTrue);
      expect(find.text(_sv.guestSheetShareTitle), findsOneWidget);
    });

    testWidgets('anyone else shares as before', (tester) async {
      expect(await tapShare(tester, guest: false), isFalse);
      expect(find.text(_sv.guestSheetShareTitle), findsNothing);
    });
  });

  group('GuestImportLimitListener', () {
    testWidgets('opens the limit sheet when the server refuses an import', (
      tester,
    ) async {
      registerAuth(FakeAuthService(FakeUser(isAnonymous: true)));
      final session = GuestImportSession(uid: () => 'uid-1');
      GetIt.instance.registerSingleton<GuestImportSession>(session);
      await tester.pumpWidget(
        guestApp(const GuestImportLimitListener(child: Text('importvyn'))),
      );
      expect(find.text(_sv.guestSheetImportLimitTitle), findsNothing);

      await tester.runAsync(session.recordLimitReached);
      await tester.pumpAndSettle();

      expect(find.text(_sv.guestSheetImportLimitTitle), findsOneWidget);
    });
  });
}
