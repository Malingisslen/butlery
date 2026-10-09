import 'package:butlery/models/notification_history_entry.dart';
import 'package:butlery/viewmodels/notifications_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

/// Intent: prove the BUT-2225 dismiss contract on the inbox VM. Selected
/// entries disappear at once, nothing is deleted until the Ångra window
/// closes, Ångra puts them back in order, and a reload inside the window does
/// not bring them back.
void main() {
  group('NotificationsViewModel dismiss with Ångra', () {
    late NotificationsViewModel viewModel;
    late MockNotificationService mockService;

    // Three entries whose doc `id` differs from `notificationId` on purpose:
    // hiding must filter on `id`, not `notificationId`. Newest first, as
    // the inbox orders them.
    NotificationHistoryEntry entry(String id, int day) =>
        NotificationHistoryEntry(
          id: id,
          notificationId: 'notif-$id',
          category: 'social',
          type: 'comment',
          data: const {},
          sentAt: DateTime(2026, 1, day),
        );

    final seed = [entry('a', 3), entry('b', 2), entry('c', 1)];

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

    test('hides only the selected entries, leaving the others', () {
      final hidden = viewModel.hideSelected({'a', 'c'});

      expect(hidden.map((e) => e.id), ['a', 'c']);
      expect(viewModel.entries.map((e) => e.id), ['b']);
    });

    // BUT-2225: nothing is deleted while Ångra can still bring it back.
    test('hiding sends no delete until the dismiss is committed', () async {
      final hidden = viewModel.hideSelected({'a', 'b'});
      verifyNever(() => mockService.deleteHistoryNotifications(any()));

      await viewModel.commitDismiss(hidden);

      final captured =
          verify(
                () => mockService.deleteHistoryNotifications(captureAny()),
              ).captured.single
              as List<String>;
      expect(captured.toSet(), {'a', 'b'});
    });

    test('undo puts the hidden entries back newest first, no delete', () {
      final hidden = viewModel.hideSelected({'a', 'c'});

      viewModel.undoDismiss(hidden);

      expect(viewModel.entries.map((e) => e.id), ['a', 'b', 'c']);
      verifyNever(() => mockService.deleteHistoryNotifications(any()));
    });

    test('a reload inside the Ångra window does not bring them back', () async {
      viewModel.hideSelected({'a'});

      await viewModel.refresh();

      expect(viewModel.entries.map((e) => e.id), ['b', 'c']);
    });

    test('after an undo, a reload shows the entries again', () async {
      final hidden = viewModel.hideSelected({'a'});
      viewModel.undoDismiss(hidden);

      await viewModel.refresh();

      expect(viewModel.entries.map((e) => e.id), ['a', 'b', 'c']);
    });

    test('notifies listeners when hiding', () {
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.hideSelected({'a'});

      expect(notifications, greaterThanOrEqualTo(1));
    });

    test('a failed delete is swallowed and the entry stays hidden', () async {
      // `deleteHistoryNotifications` is async, so a real permission denial
      // surfaces as a rejected future. Use a typed Future<int>.error so it
      // carries the same type argument as production.
      when(
        () => mockService.deleteHistoryNotifications(any()),
      ).thenAnswer((_) => Future<int>.error(Exception('permission denied')));

      final hidden = viewModel.hideSelected({'a'});
      await viewModel.commitDismiss(hidden);

      expect(viewModel.entries.map((e) => e.id), ['b', 'c']);
    });

    test('empty selection is a no-op', () {
      final hidden = viewModel.hideSelected({});

      expect(hidden, isEmpty);
      expect(viewModel.entries.length, 3);
    });

    test('selection matching no loaded entry is a no-op', () {
      // 'notif-a' is the notificationId of entry 'a'; hiding keys on the doc
      // id, so passing a notificationId must match nothing.
      final hidden = viewModel.hideSelected({'notif-a', 'zzz'});

      expect(hidden, isEmpty);
      expect(viewModel.entries.length, 3);
    });
  });
}
