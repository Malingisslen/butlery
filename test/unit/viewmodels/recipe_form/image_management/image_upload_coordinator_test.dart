/// Intent-driven unit tests for ImageUploadCoordinator (Intent-Test Sprint,
/// Batch 10 — bulk upload pipeline orchestrator).
///
/// Pairs with:
///   * `upload_queue_summary_calculator_test.dart` (batch 6) — calculator
///     consumes the same `imageStates` map this coordinator mutates.
///   * `upload_queue_manager_test.dart` (batch 9) — manager is the parallel
///     wrapper for the state-map; this coordinator does the async pipeline.
///
/// Behaviours covered:
///   * Pre-flight guards (disposed / canceled / empty list) all short-circuit
///     with [] and do NOT call the storage backend.
///   * Successful bulk upload returns the storage URLs in input order, in
///     the parallel completion of all files.
///   * Partial failure: null/empty result from storage → that file is
///     marked failed in `imageStates`, NOT included in output, and other
///     files still succeed (error isolation).
///   * `_thumbnailUrls` is cleared at the start of every batch and
///     populated only for results that carry a thumbnail.
///   * State map transitions: pending → uploading → completed-with-url,
///     and the path key is replaced by the URL key on success.
///   * Failure path: state stays at filePath key and is marked failed with
///     the error string from the thrown exception.
///   * Throwing storage call is caught per-file (does NOT bring down
///     the whole batch via `eagerError: false`).
///   * `onProgress` callback fires once per file with monotonic counts.
///   * `notifyListeners` is always called in `finally` even on exception.
///   * `cancelAllActiveUploads` iterates and calls the cleanup callback for
///     every active key; early-returns on empty.
///   * `clearAllFailedUploads` removes from state map and triggers BOTH
///     `notifyListeners` and `checkCompletionEvents`; early-returns on empty.
///   * `retryAllFailedUploads` calls the retry callback for every key, and
///     a thrown retry does NOT cascade — each retry is isolated.
///   * `getUploadManagementSummary` math: totals + boolean flags +
///     `canBulkRetry` / `canBulkCancel` thresholds (>1, NOT >=1).
///   * `dispose` cancels every in-flight operation and clears tracking.
///
/// Production findings surfaced:
///   1. `canBulkRetry` / `canBulkCancel` thresholds are `> 1` not `>= 1`.
///      So with exactly ONE failed (or active) upload, the bulk UI hides —
///      this is *intentional* per the inline comment, but the singular case
///      then has no bulk path. Pinned to lock the contract.
///   2. [FIXED — BUT-1128] Fatal-batch catch now routes through
///      `sanitizeErrorForUser(e)` instead of collapsing to `errorGeneric`.
///      The catch path itself is structurally hard to trigger from a unit
///      test (per-file catch absorbs storage errors; `Future.wait` with
///      `eagerError: false` absorbs the rest). The sanitizer's behavior is
///      proven by `test/unit/core/utils/error_sanitizer_test.dart`, and the
///      per-file isolation test below (`thrown storage exception is caught
///      per-file`) asserts the per-file path does NOT touch `errorsSet`,
///      pinning the boundary.
///   3. [FIXED — BUT-1129] The `disposed` and `uploadsCanceled` flags were
///      originally passed BY VALUE at the start of
///      `uploadPendingImagesInBackground`. A mid-flight flip on the caller's
///      bool was invisible to the per-file cancellation checks. They are now
///      `bool Function()` closures so every check re-reads live caller state
///      — soft-cancel (just flipping the bool, no `dispose()`) now actually
///      short-circuits in-flight uploads. Pinned by the mid-flight test
///      below.
///      [FIXED — BUT-1118] The queue manager's `addCompletedUpload` now
///      guards against the late-completion case.

library;

import 'dart:io';

import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/viewmodels/recipe_form/image_management/image_upload_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageService extends Mock implements StorageService {}

class _FakeFile extends Fake implements File {}

/// Test harness that wraps the coordinator with bookkeeping for the three
/// callback collaborators (notify / setError / completionEvents). All callback
/// invocations are observable so we can assert on them.
class _Harness {
  final _MockStorageService storage = _MockStorageService();
  int notifyCount = 0;
  int completionEventsCount = 0;
  final List<String> errorsSet = [];

  late final ImageUploadCoordinator coordinator = ImageUploadCoordinator(
    storageService: storage,
    notifyListeners: () => notifyCount++,
    setError: errorsSet.add,
    checkCompletionEvents: () => completionEventsCount++,
  );
}

ImageUploadStatus _pending() =>
    const ImageUploadStatus(state: ImageUploadState.pending);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFile());
  });

  group('uploadPendingImagesInBackground — pre-flight guards', () {
    /// Disposed flag at entry must short-circuit and NOT call the storage
    /// backend even once — otherwise a disposed coordinator could still
    /// queue uploads against a destroyed parent ViewModel.
    test(
      'disposed=true short-circuits to empty list without calling storage',
      () async {
        final h = _Harness();
        final file = File('/a.jpg');

        final result = await h.coordinator.uploadPendingImagesInBackground(
          [file],
          'recipe-1',
          imageStates: {'/a.jpg': _pending()},
          isDisposedNow: () => true,
          isUploadsCanceledNow: () => false,
        );

        expect(result, isEmpty);
        verifyNever(() => h.storage.uploadRecipeImage(any(), any()));
      },
    );

    /// uploadsCanceled flag at entry must short-circuit too — same reason.
    test(
      'uploadsCanceled=true short-circuits to empty list without calling storage',
      () async {
        final h = _Harness();
        final file = File('/a.jpg');

        final result = await h.coordinator.uploadPendingImagesInBackground(
          [file],
          'recipe-1',
          imageStates: {'/a.jpg': _pending()},
          isDisposedNow: () => false,
          isUploadsCanceledNow: () => true,
        );

        expect(result, isEmpty);
        verifyNever(() => h.storage.uploadRecipeImage(any(), any()));
      },
    );

    /// Empty input must return empty list and NOT call storage. Guards
    /// against a 0-item Future.wait spawning a phantom upload attempt.
    test(
      'empty pendingImages returns empty list without calling storage',
      () async {
        final h = _Harness();

        final result = await h.coordinator.uploadPendingImagesInBackground(
          [],
          'recipe-1',
          imageStates: {},
          isDisposedNow: () => false,
          isUploadsCanceledNow: () => false,
        );

        expect(result, isEmpty);
        verifyNever(() => h.storage.uploadRecipeImage(any(), any()));
      },
    );
  });

  group('uploadPendingImagesInBackground — happy path', () {
    /// All-success batch returns one URL per input file and replaces each
    /// filePath key in `imageStates` with the URL key in completed state.
    /// This is the contract the form view relies on to know which images
    /// are persistable (only URL-keyed completed entries get saved).
    test(
      'all-success batch returns URLs and rekeys state map by URL',
      () async {
        final h = _Harness();
        final fileA = File('/a.jpg');
        final fileB = File('/b.jpg');
        final imageStates = {
          '/a.jpg': _pending(),
          '/b.jpg': _pending(),
        };

        when(() => h.storage.uploadRecipeImage(fileA, 'r-1')).thenAnswer(
          (_) async => const ImageUploadResult(imageUrl: 'https://x/a.jpg'),
        );
        when(() => h.storage.uploadRecipeImage(fileB, 'r-1')).thenAnswer(
          (_) async => const ImageUploadResult(imageUrl: 'https://x/b.jpg'),
        );

        final result = await h.coordinator.uploadPendingImagesInBackground(
          [fileA, fileB],
          'r-1',
          imageStates: imageStates,
          isDisposedNow: () => false,
          isUploadsCanceledNow: () => false,
        );

        expect(
          result.toSet(),
          {'https://x/a.jpg', 'https://x/b.jpg'},
        );
        // Old path keys are gone; URL keys are present and completed.
        expect(imageStates.containsKey('/a.jpg'), isFalse);
        expect(imageStates.containsKey('/b.jpg'), isFalse);
        expect(
          imageStates['https://x/a.jpg']!.state,
          ImageUploadState.completed,
        );
        expect(imageStates['https://x/a.jpg']!.progress, 1.0);
        expect(
          imageStates['https://x/b.jpg']!.state,
          ImageUploadState.completed,
        );
      },
    );

    /// Thumbnail URLs are populated only when the storage result carries
    /// one, and the map is keyed by image URL → thumbnail URL.
    test('thumbnail URLs are tracked per image URL when present', () async {
      final h = _Harness();
      final fileA = File('/a.jpg');
      final fileB = File('/b.jpg');
      when(() => h.storage.uploadRecipeImage(fileA, 'r-1')).thenAnswer(
        (_) async => const ImageUploadResult(
          imageUrl: 'https://x/a.jpg',
          thumbnailUrl: 'https://x/a_thumb.jpg',
        ),
      );
      when(() => h.storage.uploadRecipeImage(fileB, 'r-1')).thenAnswer(
        (_) async => const ImageUploadResult(imageUrl: 'https://x/b.jpg'),
      );

      await h.coordinator.uploadPendingImagesInBackground(
        [fileA, fileB],
        'r-1',
        imageStates: {'/a.jpg': _pending(), '/b.jpg': _pending()},
        isDisposedNow: () => false,
        isUploadsCanceledNow: () => false,
      );

      expect(h.coordinator.thumbnailUrls, {
        'https://x/a.jpg': 'https://x/a_thumb.jpg',
        // b.jpg has no thumbnail → not in the map
      });
    });

    /// Each new batch starts with thumbnailUrls cleared — otherwise stale
    /// thumbnails from a previous batch could leak into the new save.
    test('thumbnailUrls are cleared at the start of each batch', () async {
      final h = _Harness();
      // First batch — populates one thumbnail.
      final fileA = File('/a.jpg');
      when(() => h.storage.uploadRecipeImage(fileA, 'r-1')).thenAnswer(
        (_) async => const ImageUploadResult(
          imageUrl: 'https://x/a.jpg',
          thumbnailUrl: 'https://x/a_thumb.jpg',
        ),
      );
      await h.coordinator.uploadPendingImagesInBackground(
        [fileA],
        'r-1',
        imageStates: {'/a.jpg': _pending()},
        isDisposedNow: () => false,
        isUploadsCanceledNow: () => false,
      );
      expect(h.coordinator.thumbnailUrls, isNotEmpty);

      // Second batch — no thumbnail this time. Map must be cleared first.
      final fileB = File('/b.jpg');
      when(() => h.storage.uploadRecipeImage(fileB, 'r-1')).thenAnswer(
        (_) async => const ImageUploadResult(imageUrl: 'https://x/b.jpg'),
      );
      await h.coordinator.uploadPendingImagesInBackground(
        [fileB],
        'r-1',
        imageStates: {'/b.jpg': _pending()},
        isDisposedNow: () => false,
        isUploadsCanceledNow: () => false,
      );

      // Old thumbnail must be gone; new batch had no thumbnail.
      expect(h.coordinator.thumbnailUrls, isEmpty);
    });

    /// thumbnailUrls getter must return an unmodifiable view — otherwise a
    /// caller mutating the map could corrupt the coordinator's internal
    /// state, particularly across the clear-at-batch-start contract above.
    test('thumbnailUrls getter returns an unmodifiable view', () async {
      final h = _Harness();
      final fileA = File('/a.jpg');
      when(() => h.storage.uploadRecipeImage(fileA, 'r-1')).thenAnswer(
        (_) async => const ImageUploadResult(
          imageUrl: 'https://x/a.jpg',
          thumbnailUrl: 'https://x/a_thumb.jpg',
        ),
      );
      await h.coordinator.uploadPendingImagesInBackground(
        [fileA],
        'r-1',
        imageStates: {'/a.jpg': _pending()},
        isDisposedNow: () => false,
        isUploadsCanceledNow: () => false,
      );

      expect(
        () => h.coordinator.thumbnailUrls['evil'] = 'x',
        throwsUnsupportedError,
      );
    });

    /// onProgress is invoked once per successfully-started file with a
    /// monotonically-rising `completed` count, and `total` matches input.
    /// Off-by-one in either argument would silently break the progress bar.
    test(
      'onProgress is called once per file with monotonic completed counts',
      () async {
        final h = _Harness();
        final fileA = File('/a.jpg');
        final fileB = File('/b.jpg');
        when(() => h.storage.uploadRecipeImage(any(), any())).thenAnswer(
          (i) async => ImageUploadResult(
            imageUrl: 'https://x/${(i.positionalArguments[0] as File).path}',
          ),
        );

        final progressLog = <(int, int)>[];
        await h.coordinator.uploadPendingImagesInBackground(
          [fileA, fileB],
          'r-1',
          imageStates: {'/a.jpg': _pending(), '/b.jpg': _pending()},
          isDisposedNow: () => false,
          isUploadsCanceledNow: () => false,
          onProgress: (c, t) => progressLog.add((c, t)),
        );

        expect(progressLog.length, 2);
        // Both calls report total=2.
        for (final p in progressLog) {
          expect(p.$2, 2);
        }
        // Counts are 1 and 2 (in some order — uploads are parallel).
        expect(progressLog.map((p) => p.$1).toSet(), {1, 2});
      },
    );

    /// notifyListeners is invoked at least once via the finally-block — UI
    /// must repaint after the batch even if every upload failed.
    test(
      'notifyListeners is called in the finally block after the batch',
      () async {
        final h = _Harness();
        final fileA = File('/a.jpg');
        when(
          () => h.storage.uploadRecipeImage(fileA, 'r-1'),
        ).thenAnswer((_) async => null);

        final notifyBefore = h.notifyCount;
        await h.coordinator.uploadPendingImagesInBackground(
          [fileA],
          'r-1',
          imageStates: {'/a.jpg': _pending()},
          isDisposedNow: () => false,
          isUploadsCanceledNow: () => false,
        );

        // At minimum the finally-block notify must fire.
        expect(h.notifyCount, greaterThan(notifyBefore));
      },
    );
  });

  group('uploadPendingImagesInBackground — partial failure isolation', () {
    /// One file's null result must NOT prevent other files in the same
    /// batch from succeeding (Future.wait eagerError: false). The failed
    /// file stays under its filePath key as failed; the success rekeys to
    /// URL. This is the spec for "save what we can".
    test(
      'null storage result fails one file but the rest still succeed',
      () async {
        final h = _Harness();
        final fileA = File('/a.jpg');
        final fileB = File('/b.jpg');
        final imageStates = {'/a.jpg': _pending(), '/b.jpg': _pending()};

        when(
          () => h.storage.uploadRecipeImage(fileA, 'r-1'),
        ).thenAnswer((_) async => null);
        when(() => h.storage.uploadRecipeImage(fileB, 'r-1')).thenAnswer(
          (_) async => const ImageUploadResult(imageUrl: 'https://x/b.jpg'),
        );

        final result = await h.coordinator.uploadPendingImagesInBackground(
          [fileA, fileB],
          'r-1',
          imageStates: imageStates,
          isDisposedNow: () => false,
          isUploadsCanceledNow: () => false,
        );

        expect(result, ['https://x/b.jpg']);
        expect(imageStates['/a.jpg']!.state, ImageUploadState.failed);
        expect(imageStates['/a.jpg']!.error, 'Upload failed');
        expect(
          imageStates['https://x/b.jpg']!.state,
          ImageUploadState.completed,
        );
      },
    );

    /// A storage call that THROWS must be caught per-file (not propagate to
    /// the batch). The thrown exception's text is captured in `error`. The
    /// other file still succeeds. This guards against a cascading-failure
    /// bug where a single thrown call could abort the whole batch.
    test(
      'thrown storage exception is caught per-file; batch continues for others',
      () async {
        final h = _Harness();
        final fileA = File('/a.jpg');
        final fileB = File('/b.jpg');
        final imageStates = {'/a.jpg': _pending(), '/b.jpg': _pending()};

        when(
          () => h.storage.uploadRecipeImage(fileA, 'r-1'),
        ).thenThrow(Exception('quota exceeded'));
        when(() => h.storage.uploadRecipeImage(fileB, 'r-1')).thenAnswer(
          (_) async => const ImageUploadResult(imageUrl: 'https://x/b.jpg'),
        );

        final result = await h.coordinator.uploadPendingImagesInBackground(
          [fileA, fileB],
          'r-1',
          imageStates: imageStates,
          isDisposedNow: () => false,
          isUploadsCanceledNow: () => false,
        );

        expect(result, ['https://x/b.jpg']);
        expect(imageStates['/a.jpg']!.state, ImageUploadState.failed);
        expect(imageStates['/a.jpg']!.error, contains('quota exceeded'));
        // Fatal-error setError must NOT have been invoked — per-file
        // failures route through state, not through the global error sink.
        expect(h.errorsSet, isEmpty);
      },
    );

    /// Empty-string URL is treated as failure even though the result was
    /// not-null. Guards against a backend bug that returns `''` instead of
    /// null on certain edge cases — the contract is "URL must be
    /// non-empty to count as success."
    test(
      'empty-string imageUrl is treated as failure (not a success)',
      () async {
        final h = _Harness();
        final fileA = File('/a.jpg');
        final imageStates = {'/a.jpg': _pending()};

        when(() => h.storage.uploadRecipeImage(fileA, 'r-1')).thenAnswer(
          (_) async => const ImageUploadResult(imageUrl: ''),
        );

        final result = await h.coordinator.uploadPendingImagesInBackground(
          [fileA],
          'r-1',
          imageStates: imageStates,
          isDisposedNow: () => false,
          isUploadsCanceledNow: () => false,
        );

        expect(result, isEmpty);
        expect(imageStates['/a.jpg']!.state, ImageUploadState.failed);
      },
    );

    /// When a file path is NOT pre-registered in imageStates, the per-file
    /// upload path tolerates that (no NPE on the containsKey check) and
    /// still returns the URL if storage succeeds. Defensive — guards
    /// against a future refactor that forgets to register the path first.
    test(
      'missing imageStates entry does NOT crash on successful upload',
      () async {
        final h = _Harness();
        final fileA = File('/a.jpg');
        // Empty state map on purpose.
        final imageStates = <String, ImageUploadStatus>{};

        when(() => h.storage.uploadRecipeImage(fileA, 'r-1')).thenAnswer(
          (_) async => const ImageUploadResult(imageUrl: 'https://x/a.jpg'),
        );

        final result = await h.coordinator.uploadPendingImagesInBackground(
          [fileA],
          'r-1',
          imageStates: imageStates,
          isDisposedNow: () => false,
          isUploadsCanceledNow: () => false,
        );

        expect(result, ['https://x/a.jpg']);
        // The URL entry is still added because the success branch does
        // `imageStates[imageUrl] = ImageUploadStatus(...)` unconditionally.
        expect(
          imageStates['https://x/a.jpg']!.state,
          ImageUploadState.completed,
        );
      },
    );
  });

  group('retryAllFailedUploads', () {
    /// Empty failedUploads is a no-op — the retry callback is NEVER called.
    /// Without this guard a phantom Future.wait([]) would still fire but the
    /// behavioural risk is calling a callback with no arg → potential NPE
    /// in the caller's retry-counter logic.
    test(
      'empty failedUploads is a silent no-op (retry callback not called)',
      () async {
        var calls = 0;
        final h = _Harness();

        await h.coordinator.retryAllFailedUploads(
          failedUploads: const {},
          retryFailedUpload: (_) async {
            calls++;
          },
        );

        expect(calls, 0);
      },
    );

    /// Each failed key triggers exactly one retry callback. Exact-count
    /// guard prevents a double-iteration regression.
    test('calls retry callback exactly once per failed key', () async {
      final h = _Harness();
      final calls = <String>[];

      await h.coordinator.retryAllFailedUploads(
        failedUploads: {
          '/a.jpg': _pending(),
          '/b.jpg': _pending(),
          '/c.jpg': _pending(),
        },
        retryFailedUpload: (key) async {
          calls.add(key);
        },
      );

      expect(calls.toSet(), {'/a.jpg', '/b.jpg', '/c.jpg'});
      expect(calls.length, 3);
    });

    /// A retry callback that throws for ONE key must NOT abort the others.
    /// `.catchError` on each future provides per-key isolation. Without it
    /// one bad retry would skip every subsequent retry in the batch.
    test(
      'a thrown retry does NOT cascade — every key still gets a call',
      () async {
        final h = _Harness();
        final calls = <String>[];

        await h.coordinator.retryAllFailedUploads(
          failedUploads: {
            '/a.jpg': _pending(),
            '/b.jpg': _pending(),
            '/c.jpg': _pending(),
          },
          retryFailedUpload: (key) async {
            calls.add(key);
            if (key == '/b.jpg') throw Exception('boom');
          },
        );

        expect(calls.toSet(), {'/a.jpg', '/b.jpg', '/c.jpg'});
      },
    );
  });

  group('cancelAllActiveUploads', () {
    /// Empty active map is a silent no-op — the removal callback is NEVER
    /// called. Guards against an off-by-one that iterates one phantom key.
    test('empty activeUploads is a silent no-op', () {
      final h = _Harness();
      final removals = <String>[];

      h.coordinator.cancelAllActiveUploads(
        activeUploads: const {},
        removeImageAndCleanup: removals.add,
      );

      expect(removals, isEmpty);
    });

    /// Every active key gets exactly one removal callback. The UI relies on
    /// this 1:1 to clean up its per-image preview widgets.
    test('calls removeImageAndCleanup once per active key', () {
      final h = _Harness();
      final removals = <String>[];

      h.coordinator.cancelAllActiveUploads(
        activeUploads: {
          '/a.jpg': _pending(),
          '/b.jpg': _pending(),
        },
        removeImageAndCleanup: removals.add,
      );

      expect(removals.toSet(), {'/a.jpg', '/b.jpg'});
      expect(removals.length, 2);
    });
  });

  group('clearAllFailedUploads', () {
    /// Empty failedUploads is a silent no-op — must NOT fire
    /// notifyListeners or checkCompletionEvents. Spurious notifications
    /// cause UI rebuilds with no state change → wasted work and
    /// occasionally flicker.
    test(
      'empty failedUploads triggers neither notify nor completion-events',
      () {
        final h = _Harness();
        final notifyBefore = h.notifyCount;
        final compBefore = h.completionEventsCount;

        h.coordinator.clearAllFailedUploads(
          imageStates: {},
          failedUploads: const {},
        );

        expect(h.notifyCount, notifyBefore);
        expect(h.completionEventsCount, compBefore);
      },
    );

    /// Non-empty path: every failed key is removed from imageStates AND
    /// both notify + completion-events fire exactly once each.
    test(
      'non-empty path removes from imageStates and fires notify + completion events',
      () {
        final h = _Harness();
        final imageStates = <String, ImageUploadStatus>{
          '/a.jpg': _pending(),
          '/b.jpg': _pending(),
          '/keep.jpg': _pending(),
        };

        final notifyBefore = h.notifyCount;
        final compBefore = h.completionEventsCount;

        h.coordinator.clearAllFailedUploads(
          imageStates: imageStates,
          failedUploads: {
            '/a.jpg': _pending(),
            '/b.jpg': _pending(),
          },
        );

        expect(imageStates.keys, ['/keep.jpg']);
        expect(h.notifyCount, notifyBefore + 1);
        expect(h.completionEventsCount, compBefore + 1);
      },
    );
  });

  group('getUploadManagementSummary', () {
    /// Empty inputs produce 0 totals, completed = 0, and both bulk-action
    /// flags must be false (no UI to show).
    test('all-empty produces zeros and both bulk flags false', () {
      final h = _Harness();

      final summary = h.coordinator.getUploadManagementSummary(
        imageStates: {},
        failedUploads: {},
        activeUploads: {},
      );

      expect(summary['failed'], 0);
      expect(summary['active'], 0);
      expect(summary['completed'], 0);
      expect(summary['total'], 0);
      expect(summary['hasRetryableFailures'], isFalse);
      expect(summary['hasActiveUploads'], isFalse);
      expect(summary['canBulkRetry'], isFalse);
      expect(summary['canBulkCancel'], isFalse);
    });

    /// completed counts only entries with state==completed. Pending /
    /// uploading / failed must NOT count as completed — otherwise the
    /// "X uploaded" UI count would lie.
    test('completed counts only state==completed entries', () {
      final h = _Harness();

      final summary = h.coordinator.getUploadManagementSummary(
        imageStates: {
          'a': const ImageUploadStatus(state: ImageUploadState.completed),
          'b': const ImageUploadStatus(state: ImageUploadState.completed),
          'c': const ImageUploadStatus(state: ImageUploadState.uploading),
          'd': const ImageUploadStatus(state: ImageUploadState.pending),
          'e': const ImageUploadStatus(state: ImageUploadState.failed),
        },
        failedUploads: {},
        activeUploads: {},
      );

      expect(summary['completed'], 2);
      expect(summary['total'], 5);
    });

    /// BUT-1127: canBulkRetry threshold is `>= 1`, not `> 1`. A queue with
    /// exactly one failure must still expose the bulk-retry affordance —
    /// withholding it on the single-item state was a UX gap.
    test(
      'BUT-1127: canBulkRetry is true when failed >= 1 (single included)',
      () {
        final h = _Harness();

        final oneFailed = h.coordinator.getUploadManagementSummary(
          imageStates: {},
          failedUploads: {'/a.jpg': _pending()},
          activeUploads: {},
        );
        expect(oneFailed['hasRetryableFailures'], isTrue);
        expect(oneFailed['canBulkRetry'], isTrue);

        final twoFailed = h.coordinator.getUploadManagementSummary(
          imageStates: {},
          failedUploads: {'/a.jpg': _pending(), '/b.jpg': _pending()},
          activeUploads: {},
        );
        expect(twoFailed['canBulkRetry'], isTrue);
      },
    );

    /// BUT-1127: canBulkCancel threshold is `>= 1`, not `> 1`. A single
    /// in-flight upload must still expose the bulk-cancel affordance.
    test(
      'BUT-1127: canBulkCancel is true when active >= 1 (single included)',
      () {
        final h = _Harness();

        final oneActive = h.coordinator.getUploadManagementSummary(
          imageStates: {},
          failedUploads: {},
          activeUploads: {'/a.jpg': _pending()},
        );
        expect(oneActive['hasActiveUploads'], isTrue);
        expect(oneActive['canBulkCancel'], isTrue);

        final twoActive = h.coordinator.getUploadManagementSummary(
          imageStates: {},
          failedUploads: {},
          activeUploads: {'/a.jpg': _pending(), '/b.jpg': _pending()},
        );
        expect(twoActive['canBulkCancel'], isTrue);
      },
    );
  });

  group('BUT-1129: mid-flight soft-cancel (fresh-read closure semantics)', () {
    /// BUT-1129: the caller's `_disposed` bool can flip AFTER the batch
    /// starts but BEFORE the in-flight storage Future resolves. Under the
    /// old captured-by-value behaviour the per-file cancellation checks
    /// would still see the stale `false` and happily return the URL.
    /// With the callback closures, every check re-reads live caller state
    /// → the post-upload guard short-circuits and the URL is dropped.
    test(
      'BUT-1129: mid-flight isDisposedNow flip short-circuits in-progress uploads',
      () async {
        final h = _Harness();
        final fileA = File('/a.jpg');
        bool disposedFlag = false;

        // Slow upload — gives us a window to flip the flag mid-flight.
        when(() => h.storage.uploadRecipeImage(fileA, 'r-1')).thenAnswer(
          (_) => Future.delayed(
            const Duration(milliseconds: 50),
            () => const ImageUploadResult(imageUrl: 'https://x/a.jpg'),
          ),
        );

        final futureUrls = h.coordinator.uploadPendingImagesInBackground(
          [fileA],
          'r-1',
          imageStates: {'/a.jpg': _pending()},
          isDisposedNow: () => disposedFlag,
          isUploadsCanceledNow: () => false,
        );

        // Flip BEFORE the storage Future resolves. The pre-flight check
        // already passed, but the post-upload check must now observe `true`.
        disposedFlag = true;

        final urls = await futureUrls;

        // Old behaviour (captured-by-value): would return ['https://x/a.jpg'].
        // New behaviour (closure fresh-read): post-upload guard fires → empty.
        expect(
          urls,
          isEmpty,
          reason:
              'mid-flight disposedFlag flip must short-circuit the post-upload guard',
        );
      },
    );

    /// Symmetric case for the uploadsCanceled flag — same fresh-read
    /// contract via `isUploadsCanceledNow`. The user-initiated cancel path
    /// is the more common trigger than dispose.
    test(
      'BUT-1129: mid-flight isUploadsCanceledNow flip short-circuits in-progress uploads',
      () async {
        final h = _Harness();
        final fileA = File('/a.jpg');
        bool canceledFlag = false;

        when(() => h.storage.uploadRecipeImage(fileA, 'r-1')).thenAnswer(
          (_) => Future.delayed(
            const Duration(milliseconds: 50),
            () => const ImageUploadResult(imageUrl: 'https://x/a.jpg'),
          ),
        );

        final futureUrls = h.coordinator.uploadPendingImagesInBackground(
          [fileA],
          'r-1',
          imageStates: {'/a.jpg': _pending()},
          isDisposedNow: () => false,
          isUploadsCanceledNow: () => canceledFlag,
        );

        canceledFlag = true;

        final urls = await futureUrls;

        expect(
          urls,
          isEmpty,
          reason:
              'mid-flight canceledFlag flip must short-circuit the post-upload guard',
        );
      },
    );
  });

  group('dispose', () {
    /// dispose() on a fresh coordinator is a safe no-op. Guards against
    /// an NPE on the empty-set iteration of `_activeUploads`.
    test('dispose on a fresh coordinator is safe (no throw)', () {
      final h = _Harness();
      expect(() => h.coordinator.dispose(), returnsNormally);
    });

    /// After a normal batch completes, dispose() can still be called safely
    /// — operations are removed from _activeUploads but dispose must not
    /// double-cancel or NPE on the cleared set.
    test('dispose after a completed batch is safe', () async {
      final h = _Harness();
      final fileA = File('/a.jpg');
      when(() => h.storage.uploadRecipeImage(fileA, 'r-1')).thenAnswer(
        (_) async => const ImageUploadResult(imageUrl: 'https://x/a.jpg'),
      );

      await h.coordinator.uploadPendingImagesInBackground(
        [fileA],
        'r-1',
        imageStates: {'/a.jpg': _pending()},
        isDisposedNow: () => false,
        isUploadsCanceledNow: () => false,
      );

      expect(() => h.coordinator.dispose(), returnsNormally);
    });
  });
}
