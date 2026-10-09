import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/notification_history_entry.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/views/notifications/notifications_view.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart';

/// BUT-2225: the inbox's bulk dismiss is class 1 (ui-conventions BUT-954).
/// The rows go at once, Ångra brings them back, and the delete is sent only
/// when the snackbar closes without Ångra.
void main() {
  late MockNotificationService service;

  NotificationHistoryEntry entry(String id, String title, int day) =>
      NotificationHistoryEntry(
        id: id,
        notificationId: 'notif-$id',
        category: 'social',
        type: 'comment',
        data: {'title': title},
        sentAt: DateTime(2026, 1, day),
      );

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() {
    service = MockNotificationService();
    when(
      () => service.getNotificationHistory(
        limit: any(named: 'limit'),
        before: any(named: 'before'),
      ),
    ).thenAnswer(
      (_) async => [entry('a', 'Första', 3), entry('b', 'Andra', 2)],
    );
    when(
      () => service.deleteHistoryNotifications(any()),
    ).thenAnswer((_) async => 1);
    if (GetIt.instance.isRegistered<NotificationService>()) {
      GetIt.instance.unregister<NotificationService>();
    }
    GetIt.instance.registerSingleton<NotificationService>(service);
  });

  tearDown(() {
    if (GetIt.instance.isRegistered<NotificationService>()) {
      GetIt.instance.unregister<NotificationService>();
    }
  });

  Future<void> dismissFirst(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const NotificationsView(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Första'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Avfärda'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('dismiss hides the row at once and deletes nothing yet', (
    tester,
  ) async {
    await dismissFirst(tester);

    expect(find.text('Första'), findsNothing);
    expect(find.text('Andra'), findsOneWidget);
    expect(find.text('Ångra'), findsOneWidget);
    verifyNever(() => service.deleteHistoryNotifications(any()));
  });

  testWidgets('Ångra brings the row back and nothing is deleted', (
    tester,
  ) async {
    await dismissFirst(tester);

    await tester.tap(find.text('Ångra'));
    await tester.pumpAndSettle(const Duration(seconds: 8));

    expect(find.text('Första'), findsOneWidget);
    verifyNever(() => service.deleteHistoryNotifications(any()));
  });

  testWidgets('without Ångra the delete is sent when the snackbar closes', (
    tester,
  ) async {
    await dismissFirst(tester);

    await tester.pumpAndSettle(const Duration(seconds: 8));

    expect(find.text('Första'), findsNothing);
    verify(() => service.deleteHistoryNotifications(['a'])).called(1);
  });
}
