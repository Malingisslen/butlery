// BUT-950: the pending-deletion screen's logic.
import 'dart:async';

import 'package:butlery/models/account/retained_record.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/account/pending_retention_notice_store.dart';
import 'package:butlery/viewmodels/account/pending_deletion_viewmodel.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockService extends Mock implements AccountDeletionService {}

class _MockProfile extends Mock implements ProfileViewModel {}

void main() {
  late _MockService service;
  late _MockProfile profile;
  late PendingRetentionNoticeStore store;
  late PendingDeletionViewModel viewModel;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = _MockService();
    profile = _MockProfile();
    store = PendingRetentionNoticeStore();
    viewModel = PendingDeletionViewModel(
      accountDeletionService: service,
      profileViewModel: profile,
      noticeStore: store,
    );
  });

  tearDown(() {
    if (!viewModel.isDisposed) viewModel.dispose();
  });

  group('undo', () {
    test('returns the service status and is busy only while it runs', () async {
      final gate = Completer<DeletionScheduleResult>();
      when(
        () => service.cancelScheduledDeletion(),
      ).thenAnswer((_) => gate.future);

      final pending = viewModel.undo();
      expect(viewModel.isLoading, isTrue);

      gate.complete(const DeletionScheduleResult(DeletionScheduleStatus.ok));
      expect(await pending, DeletionScheduleStatus.ok);
      expect(viewModel.isLoading, isFalse);
    });

    test('passes a deletion that already started through unchanged', () async {
      when(() => service.cancelScheduledDeletion()).thenAnswer(
        (_) async => const DeletionScheduleResult(
          DeletionScheduleStatus.deletionInProgress,
        ),
      );
      expect(await viewModel.undo(), DeletionScheduleStatus.deletionInProgress);
    });

    test('a second tap while busy does not call the server again', () async {
      final gate = Completer<DeletionScheduleResult>();
      when(
        () => service.cancelScheduledDeletion(),
      ).thenAnswer((_) => gate.future);

      final first = viewModel.undo();
      expect(await viewModel.undo(), DeletionScheduleStatus.failed);
      gate.complete(const DeletionScheduleResult(DeletionScheduleStatus.ok));
      await first;

      verify(() => service.cancelScheduledDeletion()).called(1);
    });
  });

  group('deleteNow', () {
    test('sends an empty reason so the stored one is used', () async {
      when(
        () => profile.deleteAccount(reason: any(named: 'reason')),
      ).thenAnswer(
        (_) async =>
            const AccountDeletionOutcome(success: true, accountDeleted: true),
      );

      final outcome = await viewModel.deleteNow();

      expect(outcome!.isComplete, isTrue);
      verify(() => profile.deleteAccount(reason: '')).called(1);
      expect(viewModel.isLoading, isFalse);
    });

    test('an ordinary deletion stores no retention notice', () async {
      when(
        () => profile.deleteAccount(reason: any(named: 'reason')),
      ).thenAnswer(
        (_) async =>
            const AccountDeletionOutcome(success: true, accountDeleted: true),
      );
      await viewModel.deleteNow();
      expect(await store.read(), isNull);
    });

    test('a deletion that kept records stores the notice for the sign-in '
        'screen, because this screen is replaced by the sign-out', () async {
      when(
        () => profile.deleteAccount(reason: any(named: 'reason')),
      ).thenAnswer(
        (_) async => AccountDeletionOutcome(
          success: true,
          accountDeleted: true,
          retained: [
            RetainedRecord(
              resourceType: RetainedRecord.ownReportResource,
              legalBasis: 'GDPR Art. 17(3)(b)',
              holdUntil: DateTime.utc(2999, 6, 1),
            ),
          ],
        ),
      );

      await viewModel.deleteNow();

      final stored = await store.read();
      expect(stored, isNotNull);
      expect(stored!.ownReportKept, isTrue);
      expect(stored.reviewKept, isFalse);
      expect(stored.holdUntil, DateTime.utc(2999, 6, 1));
    });

    test(
      'a review and a filed report are folded into one stored notice',
      () async {
        when(
          () => profile.deleteAccount(reason: any(named: 'reason')),
        ).thenAnswer(
          (_) async => AccountDeletionOutcome(
            success: true,
            accountDeleted: true,
            retained: [
              RetainedRecord(
                resourceType: 'user_moderation',
                legalBasis: 'GDPR Art. 17(3)(e)',
                holdUntil: DateTime.utc(2999, 3, 11),
                provisional: true,
              ),
              RetainedRecord(
                resourceType: RetainedRecord.ownReportResource,
                legalBasis: 'GDPR Art. 17(3)(b)',
                holdUntil: DateTime.utc(2999, 6, 1),
              ),
            ],
          ),
        );

        await viewModel.deleteNow();

        final stored = await store.read();
        expect(stored!.reviewKept, isTrue);
        expect(stored.ownReportKept, isTrue);
        expect(stored.provisional, isTrue);
        expect(stored.holdUntil, DateTime.utc(2999, 6, 1));
      },
    );

    test('the notice is stored even when the screen is already gone', () async {
      // The sign-out inside the deletion replaces the screen and disposes this
      // view model before the outcome comes back.
      final gate = Completer<AccountDeletionOutcome>();
      when(
        () => profile.deleteAccount(reason: any(named: 'reason')),
      ).thenAnswer((_) => gate.future);

      final pending = viewModel.deleteNow();
      viewModel.dispose();
      expect(await store.read(), isNull);

      gate.complete(
        AccountDeletionOutcome(
          success: true,
          accountDeleted: true,
          retained: [
            RetainedRecord(
              resourceType: RetainedRecord.ownReportResource,
              legalBasis: 'GDPR Art. 17(3)(b)',
              holdUntil: DateTime.utc(2999, 6, 1),
            ),
          ],
        ),
      );
      await pending;

      expect((await store.read())?.ownReportKept, isTrue);
    });

    test('a throwing deletion returns null and is no longer busy', () async {
      when(
        () => profile.deleteAccount(reason: any(named: 'reason')),
      ).thenThrow(Exception('boom'));
      expect(await viewModel.deleteNow(), isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test(
      'a stale sign-in is handed back for the caller to re-authenticate',
      () async {
        when(
          () => profile.deleteAccount(reason: any(named: 'reason')),
        ).thenAnswer(
          (_) async => const AccountDeletionOutcome(
            success: false,
            requiresReauth: true,
          ),
        );
        final outcome = await viewModel.deleteNow();
        expect(outcome!.requiresReauth, isTrue);
        expect(await store.read(), isNull);
      },
    );
  });
}
