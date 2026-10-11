// BUT-920: the guest band and the allergy card show for an anonymous user
// only, follow the auth state, and the card stays gone once dealt with.

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/widgets/guest/guest_allergy_card.dart';
import 'package:butlery/widgets/guest/guest_band.dart';
import 'package:butlery/widgets/guest/guest_hem_intro.dart';
import 'package:butlery/widgets/guest/guest_upgrade_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'guest_test_support.dart';

class _CountingLauncher extends GuestUpgradeLauncher {
  int launched = 0;

  @override
  void launch(BuildContext context) => launched++;
}

class _Pushes extends NavigatorObserver {
  final pushed = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route.settings.name);
  }
}

final _sv = AppLocalizationsSv();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(resetLocator);

  group('guest band', () {
    testWidgets('is drawn for an anonymous user', (tester) async {
      registerAuth(FakeAuthService(FakeUser(isAnonymous: true)));
      await tester.pumpWidget(guestApp(const GuestBand()));

      expect(find.text(_sv.guestBandLabel), findsOneWidget);
      expect(find.text(_sv.guestCreateAccount), findsOneWidget);
    });

    testWidgets('is not drawn for a signed-in user', (tester) async {
      registerAuth(FakeAuthService(FakeUser(isAnonymous: false)));
      await tester.pumpWidget(guestApp(const GuestBand()));

      expect(find.text(_sv.guestBandLabel), findsNothing);
      expect(find.text(_sv.guestCreateAccount), findsNothing);
    });

    testWidgets('is not drawn when nobody is signed in or no auth service '
        'exists', (tester) async {
      await tester.pumpWidget(guestApp(const GuestBand()));
      expect(find.text(_sv.guestBandLabel), findsNothing);

      await resetLocator();
      registerAuth(FakeAuthService(null));
      await tester.pumpWidget(guestApp(const GuestBand(key: Key('again'))));
      expect(find.text(_sv.guestBandLabel), findsNothing);
    });

    testWidgets('follows the auth state', (tester) async {
      final auth = FakeAuthService(FakeUser(isAnonymous: true));
      registerAuth(auth);
      await tester.pumpWidget(guestApp(const GuestBand()));
      expect(find.text(_sv.guestBandLabel), findsOneWidget);

      auth.signInAs(FakeUser(isAnonymous: false));
      await tester.pump();

      expect(find.text(_sv.guestBandLabel), findsNothing);
    });

    testWidgets('"Skapa konto" calls the launcher, the label does not, '
        'and the action is 48 high', (tester) async {
      registerAuth(FakeAuthService(FakeUser(isAnonymous: true)));
      final launcher = _CountingLauncher();
      await tester.pumpWidget(guestApp(GuestBand(launcher: launcher)));

      expect(
        tester.getSize(find.byKey(GuestBand.actionKey)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.text(_sv.guestBandLabel));
      await tester.pump();
      expect(launcher.launched, 0);

      await tester.tap(find.byKey(GuestBand.actionKey));
      await tester.pump();
      expect(launcher.launched, 1);
    });
  });

  group('allergy card', () {
    Future<void> pumpIntro(WidgetTester tester, {_Pushes? pushes}) async {
      await tester.pumpWidget(
        guestApp(const GuestHemIntro(), observer: pushes),
      );
      await tester.pump();
    }

    testWidgets('is drawn under the band for a guest', (tester) async {
      registerAuth(FakeAuthService(FakeUser(isAnonymous: true)));
      await pumpIntro(tester);

      expect(find.text(_sv.guestAllergyTitle), findsOneWidget);
      expect(find.text(_sv.guestAllergyBody), findsOneWidget);
      expect(find.text(_sv.guestAllergyAction), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(GuestBand)).dy,
        lessThan(tester.getTopLeft(find.byType(GuestAllergyCard)).dy),
      );
    });

    testWidgets('is not drawn for a signed-in user', (tester) async {
      registerAuth(FakeAuthService(FakeUser(isAnonymous: false)));
      await pumpIntro(tester);

      expect(find.text(_sv.guestAllergyTitle), findsNothing);
      expect(find.text(_sv.guestBandLabel), findsNothing);
    });

    testWidgets('closing it hides it for good', (tester) async {
      registerAuth(FakeAuthService(FakeUser(isAnonymous: true)));
      await pumpIntro(tester);

      await tester.tap(find.byKey(GuestAllergyCard.closeKey));
      await tester.pump();
      expect(find.text(_sv.guestAllergyTitle), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await pumpIntro(tester);
      expect(find.text(_sv.guestAllergyTitle), findsNothing);
      expect(find.text(_sv.guestBandLabel), findsOneWidget);
    });

    testWidgets('"Ställ in" opens the allergen settings and hides it for '
        'good', (tester) async {
      registerAuth(FakeAuthService(FakeUser(isAnonymous: true)));
      final pushes = _Pushes();
      await pumpIntro(tester, pushes: pushes);

      await tester.tap(find.byKey(GuestAllergyCard.actionKey));
      await tester.pumpAndSettle();

      expect(pushes.pushed, contains(Routes.settingsAllergens));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('guest_allergy_card_done_uid-1'), isTrue);

      await tester.pumpWidget(const SizedBox());
      await pumpIntro(tester);
      expect(find.text(_sv.guestAllergyTitle), findsNothing);
    });

    testWidgets('another guest on the device meets it again', (tester) async {
      SharedPreferences.setMockInitialValues({
        'guest_allergy_card_done_someone-else': true,
      });
      registerAuth(FakeAuthService(FakeUser(isAnonymous: true)));
      await pumpIntro(tester);

      expect(find.text(_sv.guestAllergyTitle), findsOneWidget);
    });
  });
}
