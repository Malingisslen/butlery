import 'package:butlery/models/notification_history_entry.dart';
import 'package:butlery/viewmodels/notifications_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

/// Intent: prove the BUT-1080 multi-select dismiss behaviour on the inbox VM —
/// optimistic local removal scoped to the requested doc ids, listener
/// notification, no-op guards, and that the optimistic removal survives a
/// failed (fire-and-forget) backend delete. The security-scoped delete itself
/// is covered at the repo layer (deleteByIds); here we pin the VM contract that
/// sits above the already-tested service pass-through.
void main() {
  group('NotificationsViewModel.dismissSelected', () {
    late NotificationsViewModel viewModel;
    late MockNotificationService mockService;

    // Three entries whose doc `id` differs from `notificationId` on purpose:
    // dismissSelected must filter on `id`, not `notificationId`.
    NotificationHistoryEntry entry(String id) => NotificationHistoryEntry(
      id: id,
      notificationId: 'notif-$id',
      category: 'social',
      type: 'comment',
      data: const {},
      sentAt: DateTime(2026, 1, 1),
    );

    final seed = [entry('a'), entry('b'), entry('c')];

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      mockService = MockNotificationService();
      when(
        () => mockService.getNotificationHistory(
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer((_) async => List.of(seed));
      when(
        () => mockService.deleteHistoryNotifications(any()),
      ).thenAnswer((_) async => 0);

      viewModel = NotificationsViewModel(notificationService: mockService);
      await viewModel.loadHistory();
    });

    tearDown(() async {
      viewModel.dispose();
      BaseUnitTest.resetMocks();
    });

    test('removes only the selected entries, leaving the others', () async {
      final removed = await viewModel.dismissSelected({'a', 'c'});

      expect(removed, 2);
      expect(viewModel.entries.map((e) => e.id), ['b']);
    });

    test('forwards exactly the requested doc ids to the service', () async {
      await viewModel.dismissSelected({'a', 'b'});

      final captured =
          verify(
                () => mockService.deleteHistoryNotifications(captureAny()),
              ).captured.single
              as List<String>;
      expect(captured.toSet(), {'a', 'b'});
    });

    test('notifies listeners on optimistic removal', () async {
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      await viewModel.dismissSelected({'a'});

      expect(notifications, greaterThanOrEqualTo(1));
    });

    test(
      'optimistic removal stands even when the backend delete fails',
      () async {
        // `deleteHistoryNotifications` is async, so a real permission denial
        // surfaces as a *rejected future* (not a synchronous throw) — that is
        // the path the VM's `.catchError` is designed to swallow. Use a typed
        // Future<int>.error so the rejected future carries the same type
        // argument as production (mocktail's `async => throw` erases it to
        // Future<dynamic>, which trips Future.catchError's return-type check).
        when(
          () => mockService.deleteHistoryNotifications(any()),
        ).thenAnswer((_) => Future<int>.error(Exception('permission denied')));

        final removed = await viewModel.dismissSelected({'a'});

        // Fire-and-forget: the failure is swallowed and the entry stays removed
        // (a refresh would resurrect it, but the VM does not rollback by design).
        expect(removed, 1);
        expect(viewModel.entries.map((e) => e.id), ['b', 'c']);
      },
    );

    test('empty selection is a no-op — no service call, returns 0', () async {
      final removed = await viewModel.dismissSelected({});

      expect(removed, 0);
      expect(viewModel.entries.length, 3);
      verifyNever(() => mockService.deleteHistoryNotifications(any()));
    });

    test(
      'selection matching no loaded entry is a no-op — no service call',
      () async {
        // 'notif-a' is the notificationId of entry 'a'; dismissSelected keys on
        // the doc id, so passing a notificationId must match nothing.
        final removed = await viewModel.dismissSelected({'notif-a', 'zzz'});

        expect(removed, 0);
        expect(viewModel.entries.length, 3);
        verifyNever(() => mockService.deleteHistoryNotifications(any()));
      },
    );
  });
}
