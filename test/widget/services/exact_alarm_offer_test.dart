// Decision D1 (Malin 2026-10-29): the first timer started while exact alarms
// are off offers the "Alarm och påminnelser" setting, once per device.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/notifications/local_timer_notification_service.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _FakeExactAlarms implements ExactAlarmAccess {
  _FakeExactAlarms({required this.isAllowed});

  bool isAllowed;
  int openCalls = 0;

  @override
  Future<bool> allowed() async => isAllowed;

  @override
  Future<void> openSetting() async => openCalls++;
}

void main() {
  final sv = AppLocalizationsSv();

  late _FakeExactAlarms access;
  late LocalTimerNotificationService service;
  late BuildContext context;

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // The offer awaits the dialog, so the call is started and pumped, not awaited.
  Future<void> offer(WidgetTester tester) async {
    unawaited(service.offerExactAlarmsOnce(context));
    await tester.pumpAndSettle();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    access = _FakeExactAlarms(isAllowed: false);
    service = LocalTimerNotificationService(
      plugin: _MockPlugin(),
      isMobileOverride: () => true,
      exactAlarms: access,
    );
  });

  testWidgets('exact alarms off, never shown: offers the setting and opens it '
      'on "Öppna inställningar"', (tester) async {
    await pumpHost(tester);
    await offer(tester);

    expect(find.text(sv.timerExactAlarmTitle), findsOneWidget);

    await tester.tap(find.text(sv.permOpenSettings));
    await tester.pumpAndSettle();

    expect(access.openCalls, 1);
    expect(find.text(sv.timerExactAlarmTitle), findsNothing);
  });

  testWidgets('a second call never shows the offer again', (tester) async {
    await pumpHost(tester);
    await offer(tester);
    await tester.tap(find.text(sv.permNotNow));
    await tester.pumpAndSettle();

    await offer(tester);

    expect(find.text(sv.timerExactAlarmTitle), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(LocalTimerNotificationService.exactAlarmOfferShownKey),
      isTrue,
    );
  });

  testWidgets('exact alarms allowed: no dialog and the flag stays unset', (
    tester,
  ) async {
    access.isAllowed = true;
    await pumpHost(tester);

    await offer(tester);

    expect(find.text(sv.timerExactAlarmTitle), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.containsKey(LocalTimerNotificationService.exactAlarmOfferShownKey),
      isFalse,
    );
  });

  testWidgets('"Inte nu" does not open the setting', (tester) async {
    await pumpHost(tester);
    await offer(tester);

    await tester.tap(find.text(sv.permNotNow));
    await tester.pumpAndSettle();

    expect(access.openCalls, 0);
    expect(find.text(sv.timerExactAlarmTitle), findsNothing);
  });
}
