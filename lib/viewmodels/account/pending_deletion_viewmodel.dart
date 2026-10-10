// lib/viewmodels/account/pending_deletion_viewmodel.dart

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/account/pending_retention_notice_store.dart';
import 'package:butlery/models/account/retained_record.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';

/// Drives the screen a signed-in user sees while the account is scheduled for
/// deletion (BUT-950): undo the deletion, or skip the grace period.
class PendingDeletionViewModel extends BaseViewModel {
  PendingDeletionViewModel({
    required AccountDeletionService accountDeletionService,
    required ProfileViewModel profileViewModel,
    required PendingRetentionNoticeStore noticeStore,
  }) : _accountDeletionService = accountDeletionService,
       _profileViewModel = profileViewModel,
       _noticeStore = noticeStore;

  final AccountDeletionService _accountDeletionService;
  final ProfileViewModel _profileViewModel;
  final PendingRetentionNoticeStore _noticeStore;

  /// Cancels the scheduled deletion. The service refreshes the token, so on
  /// [DeletionScheduleStatus.ok] the claim is gone and the app can open.
  Future<DeletionScheduleStatus> undo() async {
    if (isLoading || isDisposed) return DeletionScheduleStatus.failed;
    setLoading(true);
    try {
      final result = await _accountDeletionService.cancelScheduledDeletion();
      return result.status;
    } finally {
      setLoading(false);
    }
  }

  /// Deletes the account now, with no grace period. The reason sent is empty,
  /// so the server uses the one stored when the deletion was scheduled.
  ///
  /// Returns null when the call threw, which leaves the account standing.
  Future<AccountDeletionOutcome?> deleteNow() async {
    if (isLoading || isDisposed) return null;
    setLoading(true);
    try {
      final outcome = await _profileViewModel.deleteAccount(reason: '');
      if (outcome.owesRetentionNotice) {
        // The sign-out inside the deletion has already replaced this screen,
        // so the notice goes to the sign-in screen's gate through the store.
        final facts = RetentionNoticeFacts.from(outcome.retained);
        await _noticeStore.write(
          holdUntil: facts.holdUntil,
          provisional: facts.provisional,
          reviewKept: facts.reviewKept,
          ownReportKept: facts.ownReportKept,
        );
      }
      return outcome;
    } catch (e) {
      AppLogger.error('Immediate deletion from the pending screen failed', e);
      return null;
    } finally {
      setLoading(false);
    }
  }
}
