/// Intent-driven unit tests for UploadQueueManager (Intent-Test Sprint,
/// Batch 9 — pure-state queue coordinator).
///
/// SCOPE NOTE: Despite the sprint brief's mention of "async upload queue,
/// concurrency limits, retry semantics, cancellation mid-upload", the actual
/// production class is a **pure synchronous `Map<String, ImageUploadStatus>`
/// wrapper**. It owns no Futures, no Isolates, no Timers, no concurrency
/// gate, no retry execution, no in-flight HTTP. Async behaviour (parallelism,
/// retry backoff, cancellation) lives in the call sites (ImageUploadService
/// + UploadRetryManager) and is covered by their respective test files.
/// Writing fake "concurrency limit" tests here would be testing a behaviour
/// the file does not own — a per-Intent-Gate Rule 3 violation. So the tests
/// below pin the state-contract this file actually does own.
///
/// Pairs with `test/unit/viewmodels/recipe_form/image_management/
/// upload_queue_summary_calculator_test.dart` (batch 6) — the calculator
/// reads the same per-status fields this manager writes, so the
/// state-machine invariants pinned here back-stop the calculator's input
/// shape.
///
/// Behaviours covered:
///   * Construction defaults — empty queue, isEmpty/isNotEmpty agreement
///   * addUpload — happy path, pending state, retry budget, duplicate-no-op
///   * addCompletedUpload — overwrites silently (intentional?), sets
///     progress=1.0 and state=completed
///   * updateStatus — happy path, no-op on missing key (no insert)
///   * updateProgress — copyWith semantics, no-op on missing key, no NPE
///   * removeUpload — returns the removed status (or null), decrements size
///   * clearAll — wipes everything, idempotent
///   * removeByState — only matching state purged, others untouched
///   * Filter getters — pending / active (uploading+retrying) / completed /
///     failed / retriableFailed / cancelled / valid / persistableUrls
///     return the correct partitions and don't double-count
///   * allUploads is unmodifiable (defensive copy contract)
///   * getSummary — totals add up, completionRate rounding, hasActive flag,
///     hasRetryable flag
///   * getAnalytics — overallProgress arithmetic, average speed ignores
///     non-active and null-speed entries
///
/// Production findings surfaced (NOT fixed here — see report):
///   1. `addCompletedUpload` SILENTLY overwrites any existing entry, while
///      `addUpload` warns + no-ops on duplicate. The asymmetry can erase
///      a pending or in-flight upload status if a completion lands for a
///      path that was re-queued (rare but plausible during retry races).
///   2. `getSummary`'s `'uploading'` key counts `activeUploads.length`,
///      which includes both `ImageUploadState.uploading` and
///      `ImageUploadState.retrying`. UI keys named `uploading` therefore
///      include retries — could surprise summary consumers.
///   3. `updateStatus(path, newStatus)` does NOT merge with the existing
///      entry — it replaces wholesale. Callers must remember to carry the
///      `file:` field through every status transition, or `validUploads`
///      / display logic will silently stop showing the entry. There's no
///      type-system guard for this. In practice the call sites
///      (ImageUploadService) use `currentStatus.copyWith(...)` to build
///      the next status, which preserves file — but the API surface here
///      doesn't enforce that pattern.
library;

import 'dart:io';

import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/services/upload/upload_queue_manager.dart';
import 'package:flutter_test/flutter_test.dart';

File _f(String path) => File(path);

ImageUploadStatus _statusWith({
  required ImageUploadState state,
  double progress = 0.0,
  String? url,
  File? file,
  String? error,
  int retryAttempts = 0,
  int maxRetryAttempts = 3,
  double? uploadSpeedBytesPerSecond,
}) {
  return ImageUploadStatus(
    state: state,
    progress: progress,
    url: url,
    file: file,
    error: error,
    retryAttempts: retryAttempts,
    maxRetryAttempts: maxRetryAttempts,
    uploadSpeedBytesPerSecond: uploadSpeedBytesPerSecond,
  );
}

void main() {
  late UploadQueueManager mgr;

  setUp(() {
    mgr = UploadQueueManager();
  });

  group('Construction defaults', () {
    /// A fresh manager owns no uploads and reports empty consistently across
    /// all three size-related getters.
    test('fresh queue is empty and consistent', () {
      expect(mgr.queueSize, 0);
      expect(mgr.isEmpty, isTrue);
      expect(mgr.isNotEmpty, isFalse);
      expect(mgr.allUploads, isEmpty);
    });
  });

  group('addUpload', () {
    /// addUpload records a pending status for the given path with the
    /// caller-supplied retry budget — not the default — so retry policy
    /// is plumbed correctly through to UploadRetryManager later.
    test('inserts pending status with caller-supplied retry budget', () {
      mgr.addUpload(
          filePath: '/a.jpg', file: _f('/a.jpg'), maxRetryAttempts: 7);

      final status = mgr.getStatus('/a.jpg');
      expect(status, isNotNull);
      expect(status!.state, ImageUploadState.pending);
      expect(status.maxRetryAttempts, 7);
      expect(status.file?.path, '/a.jpg');
      expect(mgr.queueSize, 1);
    });

    /// Duplicate addUpload is a silent no-op — re-adding the same path
    /// must NOT reset retry counters or overwrite an in-progress upload.
    /// A regression here (e.g. unconditional assignment) would zero an
    /// uploading-state entry mid-flight.
    test('duplicate addUpload is a no-op and preserves existing status', () {
      mgr.addUpload(filePath: '/a.jpg', file: _f('/a.jpg'));
      mgr.updateStatus(
        '/a.jpg',
        _statusWith(state: ImageUploadState.uploading, progress: 0.5),
      );

      mgr.addUpload(filePath: '/a.jpg', file: _f('/a.jpg'));

      expect(mgr.queueSize, 1);
      final status = mgr.getStatus('/a.jpg')!;
      expect(status.state, ImageUploadState.uploading);
      expect(status.progress, 0.5);
    });

    /// Default retry budget is 3 — pinned because UploadRetryManager
    /// reads `maxRetryAttempts` from this field to gate canRetry.
    test('default maxRetryAttempts is 3 when not specified', () {
      mgr.addUpload(filePath: '/a.jpg', file: _f('/a.jpg'));
      expect(mgr.getStatus('/a.jpg')!.maxRetryAttempts, 3);
    });
  });

  group('addCompletedUpload', () {
    /// Adding a pre-completed upload (e.g. an already-uploaded URL being
    /// re-attached on form re-open) records it as completed with full
    /// progress and the persistable URL.
    test('records completed state with progress=1.0 and url set', () {
      mgr.addCompletedUpload(filePath: '/img.jpg', url: 'https://x/y.jpg');

      final status = mgr.getStatus('/img.jpg')!;
      expect(status.state, ImageUploadState.completed);
      expect(status.progress, 1.0);
      expect(status.url, 'https://x/y.jpg');
      expect(mgr.persistableUrls, ['https://x/y.jpg']);
    });

    /// FINDING #1: addCompletedUpload silently overwrites an existing
    /// entry, unlike addUpload which warns+no-ops. This test PINS the
    /// current behaviour so any intentional change shows up as a test
    /// failure rather than slipping in silently.
    test(
        'asymmetry-with-addUpload: silently overwrites existing entry (pinning current behaviour)',
        () {
      mgr.addUpload(filePath: '/x.jpg', file: _f('/x.jpg'));
      mgr.updateStatus(
        '/x.jpg',
        _statusWith(state: ImageUploadState.uploading, progress: 0.4),
      );

      mgr.addCompletedUpload(filePath: '/x.jpg', url: 'https://x/x.jpg');

      // The previously-uploading entry has been erased — the file handle
      // is gone, the progress jumped to 1.0, and the state is completed.
      final status = mgr.getStatus('/x.jpg')!;
      expect(status.state, ImageUploadState.completed);
      expect(status.file, isNull);
      expect(status.progress, 1.0);
      expect(status.url, 'https://x/x.jpg');
    });
  });

  group('updateStatus', () {
    /// Updating an existing entry replaces its status entirely.
    test('replaces existing status with the new one', () {
      mgr.addUpload(filePath: '/a.jpg', file: _f('/a.jpg'));
      final next = _statusWith(
        state: ImageUploadState.failed,
        error: 'boom',
        retryAttempts: 1,
      );

      mgr.updateStatus('/a.jpg', next);

      expect(mgr.getStatus('/a.jpg'), same(next));
    });

    /// Updating a non-existent key is a no-op — it must NOT insert,
    /// otherwise updateStatus could resurrect uploads removed by
    /// cancellation/clearAll.
    test('updateStatus on missing key does not insert', () {
      mgr.updateStatus(
        '/ghost.jpg',
        _statusWith(state: ImageUploadState.uploading),
      );

      expect(mgr.containsUpload('/ghost.jpg'), isFalse);
      expect(mgr.queueSize, 0);
    });
  });

  group('updateProgress', () {
    /// updateProgress mutates only the named fields via copyWith — the
    /// state and other fields are preserved.
    test('updates progress fields while preserving state', () {
      mgr.addUpload(filePath: '/a.jpg', file: _f('/a.jpg'));
      mgr.updateStatus(
        '/a.jpg',
        _statusWith(state: ImageUploadState.uploading),
      );

      mgr.updateProgress(
        filePath: '/a.jpg',
        progress: 0.7,
        bytesTransferred: 700,
        totalBytes: 1000,
        uploadSpeed: 1024.0,
        estimatedTimeRemaining: const Duration(seconds: 2),
      );

      final status = mgr.getStatus('/a.jpg')!;
      expect(status.state, ImageUploadState.uploading); // preserved
      expect(status.progress, 0.7);
      expect(status.bytesTransferred, 700);
      expect(status.totalBytes, 1000);
      expect(status.uploadSpeedBytesPerSecond, 1024.0);
      expect(status.estimatedTimeRemaining, const Duration(seconds: 2));
    });

    /// updateProgress on a non-existent path must NOT throw and must NOT
    /// insert — guarded against late-arriving progress callbacks from
    /// uploads that were cancelled or removed.
    test('updateProgress on missing key is a silent no-op (no NPE)', () {
      expect(
        () => mgr.updateProgress(filePath: '/ghost.jpg', progress: 0.5),
        returnsNormally,
      );
      expect(mgr.containsUpload('/ghost.jpg'), isFalse);
    });
  });

  group('removeUpload / clearAll / removeByState', () {
    /// removeUpload returns the removed status (useful for callers that
    /// want to inspect what was discarded) and decrements queueSize.
    test('removeUpload returns the removed status and shrinks the queue', () {
      mgr.addUpload(filePath: '/a.jpg', file: _f('/a.jpg'));
      mgr.addUpload(filePath: '/b.jpg', file: _f('/b.jpg'));

      final removed = mgr.removeUpload('/a.jpg');

      expect(removed, isNotNull);
      expect(removed!.state, ImageUploadState.pending);
      expect(mgr.queueSize, 1);
      expect(mgr.containsUpload('/a.jpg'), isFalse);
      expect(mgr.containsUpload('/b.jpg'), isTrue);
    });

    /// removeUpload on missing key returns null and is otherwise a no-op.
    test('removeUpload on missing key returns null', () {
      expect(mgr.removeUpload('/ghost.jpg'), isNull);
    });

    /// clearAll empties the queue; calling it twice is harmless.
    test('clearAll empties the queue and is idempotent', () {
      mgr.addUpload(filePath: '/a.jpg', file: _f('/a.jpg'));
      mgr.addUpload(filePath: '/b.jpg', file: _f('/b.jpg'));

      mgr.clearAll();
      expect(mgr.isEmpty, isTrue);
      mgr.clearAll();
      expect(mgr.isEmpty, isTrue);
    });

    /// removeByState purges only entries in the matching state — others
    /// untouched. A bug that compared on the wrong enum or used `!=`
    /// would erase the wrong slice; this test would catch it.
    test('removeByState purges only the matching state', () {
      mgr.addUpload(filePath: '/pending.jpg', file: _f('/pending.jpg'));
      mgr.addUpload(filePath: '/uploading.jpg', file: _f('/uploading.jpg'));
      mgr.updateStatus(
        '/uploading.jpg',
        _statusWith(state: ImageUploadState.uploading),
      );
      mgr.addUpload(filePath: '/failed.jpg', file: _f('/failed.jpg'));
      mgr.updateStatus(
        '/failed.jpg',
        _statusWith(state: ImageUploadState.failed, error: 'x'),
      );

      mgr.removeByState(ImageUploadState.failed);

      expect(mgr.containsUpload('/failed.jpg'), isFalse);
      expect(mgr.containsUpload('/pending.jpg'), isTrue);
      expect(mgr.containsUpload('/uploading.jpg'), isTrue);
      expect(mgr.queueSize, 2);
    });

    /// removeByState on an empty-bucket state does nothing.
    test('removeByState with no matches leaves queue untouched', () {
      mgr.addUpload(filePath: '/a.jpg', file: _f('/a.jpg'));
      mgr.removeByState(ImageUploadState.completed);
      expect(mgr.queueSize, 1);
    });
  });

  group('allUploads — defensive copy', () {
    /// The exposed map view must reject mutation — otherwise external
    /// callers could corrupt internal state behind the manager's back.
    test('allUploads is unmodifiable', () {
      mgr.addUpload(filePath: '/a.jpg', file: _f('/a.jpg'));
      final view = mgr.allUploads;

      expect(() => view.remove('/a.jpg'), throwsUnsupportedError);
      expect(
        () => view['/b.jpg'] =
            _statusWith(state: ImageUploadState.pending, file: _f('/b.jpg')),
        throwsUnsupportedError,
      );
    });
  });

  group('State-bucket filters', () {
    setUp(() {
      // Seed: one of each state, plus an extra retrying entry so the
      // activeUploads union test is non-trivial.
      mgr.addUpload(filePath: '/pending.jpg', file: _f('/pending.jpg'));

      mgr.addUpload(filePath: '/uploading.jpg', file: _f('/uploading.jpg'));
      mgr.updateStatus(
        '/uploading.jpg',
        _statusWith(state: ImageUploadState.uploading, progress: 0.3),
      );

      mgr.addUpload(filePath: '/retrying.jpg', file: _f('/retrying.jpg'));
      mgr.updateStatus(
        '/retrying.jpg',
        _statusWith(
          state: ImageUploadState.retrying,
          error: 'temp',
          retryAttempts: 1,
        ),
      );

      mgr.addCompletedUpload(
        filePath: '/done.jpg',
        url: 'https://x/done.jpg',
      );

      mgr.addUpload(
          filePath: '/failed-retriable.jpg', file: _f('/failed-retriable.jpg'));
      mgr.updateStatus(
        '/failed-retriable.jpg',
        _statusWith(
          state: ImageUploadState.failed,
          error: 'net',
          retryAttempts: 1,
          maxRetryAttempts: 3,
        ),
      );

      mgr.addUpload(
          filePath: '/failed-exhausted.jpg', file: _f('/failed-exhausted.jpg'));
      mgr.updateStatus(
        '/failed-exhausted.jpg',
        _statusWith(
          state: ImageUploadState.failed,
          error: 'net',
          retryAttempts: 3,
          maxRetryAttempts: 3,
        ),
      );

      mgr.addUpload(filePath: '/cancelled.jpg', file: _f('/cancelled.jpg'));
      mgr.updateStatus(
        '/cancelled.jpg',
        _statusWith(state: ImageUploadState.cancelled),
      );
    });

    /// pendingUploads returns only the truly-pending entries (not failed,
    /// not retrying, not cancelled).
    test('pendingUploads contains only pending state', () {
      expect(mgr.pendingUploads.keys, ['/pending.jpg']);
    });

    /// activeUploads is the UNION of uploading + retrying — the rest
    /// of the codebase relies on this union to know "is anything in
    /// flight?". A regression that drops retrying would mis-report
    /// the queue as idle during the retry-pause window.
    test('activeUploads = uploading ∪ retrying (and nothing else)', () {
      final active = mgr.activeUploads.keys.toSet();
      expect(
        active,
        equals({'/uploading.jpg', '/retrying.jpg'}),
      );
    });

    /// completedUploads — just the completed state bucket.
    test('completedUploads contains only completed state', () {
      expect(mgr.completedUploads.keys, ['/done.jpg']);
    });

    /// failedUploads — both retriable and exhausted failures.
    test('failedUploads contains every failed entry (regardless of canRetry)',
        () {
      expect(
        mgr.failedUploads.keys.toSet(),
        equals({'/failed-retriable.jpg', '/failed-exhausted.jpg'}),
      );
    });

    /// retriableFailedUploads filters by both state==failed AND canRetry.
    /// The exhausted entry (retryAttempts == maxRetryAttempts) MUST be
    /// excluded — otherwise the retry loop would loop forever.
    test('retriableFailedUploads excludes exhausted-retry entries', () {
      expect(
        mgr.retriableFailedUploads.keys,
        ['/failed-retriable.jpg'],
      );
    });

    /// cancelledUploads — just the cancelled bucket.
    test('cancelledUploads contains only cancelled state', () {
      expect(mgr.cancelledUploads.keys, ['/cancelled.jpg']);
    });

    /// validUploads filters on `isDisplayable` (file != null || url != null).
    /// Entries created via addUpload (file set) and addCompletedUpload (url
    /// set) are displayable; the test below uses a separate fixture because
    /// the shared seed transitions some entries through updateStatus, which
    /// (see finding #3) replaces the status wholesale and drops the file.
    test('validUploads includes file-bearing and url-bearing entries', () {
      final fresh = UploadQueueManager();
      fresh.addUpload(filePath: '/withFile.jpg', file: _f('/withFile.jpg'));
      fresh.addCompletedUpload(filePath: '/withUrl.jpg', url: 'https://x/y');

      expect(
        fresh.validUploads.keys.toSet(),
        equals({'/withFile.jpg', '/withUrl.jpg'}),
      );
    });

    /// validUploads excludes entries with neither file nor url — defends
    /// against a status replaced via updateStatus that dropped both fields
    /// (finding #3 above). Without this filter the UI would render an
    /// empty card for the entry.
    test('validUploads excludes entries with neither file nor url', () {
      mgr.updateStatus(
        '/pending.jpg',
        _statusWith(state: ImageUploadState.pending), // no file, no url
      );
      expect(mgr.validUploads.containsKey('/pending.jpg'), isFalse);
    });

    /// persistableUrls returns ONLY completed-with-url entries — pending
    /// or in-flight uploads (no url yet) must not appear, otherwise the
    /// recipe save would persist empty/invalid URLs.
    test('persistableUrls returns only completed-with-url entries', () {
      expect(mgr.persistableUrls, ['https://x/done.jpg']);
    });
  });

  group('getSummary', () {
    /// On an empty queue every counter is 0 and completionRate is 0
    /// (NOT NaN — division-by-zero guard).
    test('empty queue gives zero counters and 0 completionRate (no NaN)', () {
      final s = mgr.getSummary();
      expect(s['pending'], 0);
      expect(s['uploading'], 0);
      expect(s['active'], 0);
      expect(s['completed'], 0);
      expect(s['failed'], 0);
      expect(s['total'], 0);
      expect(s['hasActive'], isFalse);
      expect(s['hasRetryable'], isFalse);
      expect(s['completionRate'], 0);
    });

    /// completionRate is an integer percentage = round(completed/total*100).
    /// 1 of 3 completed → 33; 2 of 3 → 67. Pin the rounding direction.
    test('completionRate uses integer percentage rounding (1/3 → 33)', () {
      mgr.addUpload(filePath: '/a.jpg', file: _f('/a.jpg'));
      mgr.addUpload(filePath: '/b.jpg', file: _f('/b.jpg'));
      mgr.addCompletedUpload(filePath: '/c.jpg', url: 'u');

      expect(mgr.getSummary()['completionRate'], 33);
    });

    /// hasActive flips to true the moment any upload enters uploading
    /// OR retrying — guards the UI "spinning indicator" condition.
    test('hasActive is true when retrying-only (no uploading)', () {
      mgr.addUpload(filePath: '/a.jpg', file: _f('/a.jpg'));
      mgr.updateStatus(
        '/a.jpg',
        _statusWith(
          state: ImageUploadState.retrying,
          error: 'x',
          retryAttempts: 1,
        ),
      );
      expect(mgr.getSummary()['hasActive'], isTrue);
    });

    /// hasRetryable is true only when there's at least one
    /// canRetry-failed entry — exhausted failures must NOT trigger it.
    test('hasRetryable is false when all failures are exhausted', () {
      mgr.addUpload(filePath: '/a.jpg', file: _f('/a.jpg'));
      mgr.updateStatus(
        '/a.jpg',
        _statusWith(
          state: ImageUploadState.failed,
          error: 'x',
          retryAttempts: 3,
          maxRetryAttempts: 3,
        ),
      );
      final s = mgr.getSummary();
      expect(s['failed'], 1);
      expect(s['hasRetryable'], isFalse);
    });

    /// FINDING #2 pin: the 'uploading' summary key actually reports
    /// activeUploads.length — which includes the `retrying` state — so
    /// a queue of 1 uploading + 1 retrying reports `uploading: 2`,
    /// not 1. This documents current behaviour for downstream consumers.
    test('uploading-key includes retrying entries (current behaviour pinned)',
        () {
      mgr.addUpload(filePath: '/a.jpg', file: _f('/a.jpg'));
      mgr.updateStatus(
        '/a.jpg',
        _statusWith(state: ImageUploadState.uploading),
      );
      mgr.addUpload(filePath: '/b.jpg', file: _f('/b.jpg'));
      mgr.updateStatus(
        '/b.jpg',
        _statusWith(
          state: ImageUploadState.retrying,
          error: 'x',
          retryAttempts: 1,
        ),
      );

      final s = mgr.getSummary();
      expect(s['uploading'], 2);
      expect(s['active'], 2);
    });
  });

  group('getAnalytics', () {
    /// On an empty queue overallProgress is 0.0 (NOT NaN) — division
    /// guard mirrors getSummary's completionRate guard.
    test('empty queue gives 0.0 overallProgress (no NaN)', () {
      final a = mgr.getAnalytics();
      expect(a['overallProgress'], 0.0);
      expect(a['overallProgressPercentage'], 0);
      expect(a['averageSpeedBytesPerSecond'], 0.0);
      expect(a['averageSpeedMBPerSecond'], 0.0);
    });

    /// overallProgress = mean of every entry's progress field. Mixing a
    /// completed (1.0) and a half-done uploading (0.5) entry yields 0.75.
    /// A bug that summed without dividing would return 1.5 — caught.
    test('overallProgress is the arithmetic mean across the queue', () {
      mgr.addCompletedUpload(filePath: '/done.jpg', url: 'u');
      mgr.addUpload(filePath: '/half.jpg', file: _f('/half.jpg'));
      mgr.updateStatus(
        '/half.jpg',
        _statusWith(state: ImageUploadState.uploading, progress: 0.5),
      );

      final a = mgr.getAnalytics();
      expect(a['overallProgress'], closeTo(0.75, 1e-9));
      expect(a['overallProgressPercentage'], 75);
    });

    /// averageSpeed averages ONLY across active entries with a non-null
    /// speed reading. A null-speed active entry and a non-active entry
    /// with a speed both must be excluded.
    test('averageSpeed only averages active entries with non-null speed', () {
      // Active, with speed → included.
      mgr.addUpload(filePath: '/a.jpg', file: _f('/a.jpg'));
      mgr.updateStatus(
        '/a.jpg',
        _statusWith(
          state: ImageUploadState.uploading,
          uploadSpeedBytesPerSecond: 1024.0,
        ),
      );
      // Active, no speed yet → excluded (would divide by inflated count).
      mgr.addUpload(filePath: '/b.jpg', file: _f('/b.jpg'));
      mgr.updateStatus(
        '/b.jpg',
        _statusWith(state: ImageUploadState.uploading),
      );
      // Non-active (completed), with speed → excluded.
      mgr.addUpload(filePath: '/c.jpg', file: _f('/c.jpg'));
      mgr.updateStatus(
        '/c.jpg',
        _statusWith(
          state: ImageUploadState.completed,
          uploadSpeedBytesPerSecond: 99999.0,
        ),
      );

      final a = mgr.getAnalytics();
      expect(a['averageSpeedBytesPerSecond'], 1024.0);
      expect(
        a['averageSpeedMBPerSecond'],
        closeTo(1024.0 / (1024 * 1024), 1e-12),
      );
    });

    /// getAnalytics inherits every key from getSummary (it spreads
    /// `...summary`) — a regression where the spread is dropped would
    /// break UI consumers that read both layers from one call.
    test('analytics spreads in every summary key', () {
      mgr.addUpload(filePath: '/a.jpg', file: _f('/a.jpg'));
      final a = mgr.getAnalytics();
      expect(a.containsKey('pending'), isTrue);
      expect(a.containsKey('uploading'), isTrue);
      expect(a.containsKey('active'), isTrue);
      expect(a.containsKey('completed'), isTrue);
      expect(a.containsKey('failed'), isTrue);
      expect(a.containsKey('total'), isTrue);
      expect(a.containsKey('hasActive'), isTrue);
      expect(a.containsKey('hasRetryable'), isTrue);
      expect(a.containsKey('completionRate'), isTrue);
    });
  });
}
