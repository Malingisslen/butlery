// lib/services/offline/sync_queue_source.dart
//
// P4-U19: what the "Väntar på synk" view and the top-bar queue indicator
// read. "Mer → Väntar på synk: antal poster, vad de rör, ålder, och de
// permanenta felen först. Nås även från köindikatorn i toppfältet."
// (produktregler.md:190). The queue itself is schema 3 (P5-U35): both queues,
// one count (AppDatabase.watchQueueCounts).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/storage/drift/queue_counts.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/offline/queued_change.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/offline/sync_queue_reader.dart'
    if (dart.library.html) 'package:butlery/services/offline/sync_queue_reader_web.dart';

export 'package:butlery/core/storage/drift/queue_counts.dart';
export 'package:butlery/services/offline/queued_change.dart';

/// Reads and acts on the signed-in user's offline queue.
abstract class SyncQueueSource {
  const SyncQueueSource();

  /// Replaces the source every widget resolves, for tests.
  @visibleForTesting
  static SyncQueueSource? debugOverride;

  /// The source the app uses: the offline database of the signed-in user.
  static SyncQueueSource resolve() =>
      debugOverride ?? const OfflineSyncQueueSource();

  /// The counts, live. Both queues, one number (AppDatabase.watchQueueCounts).
  Stream<QueueCounts> watchCounts();

  /// Every waiting change, live.
  Stream<QueueSnapshot> watchChanges();

  /// Whether the device is online right now.
  bool get isOnline;

  /// Whether the queue has emptied and the device is online, live: true
  /// when nothing is left for the queue to send by itself. Permanent
  /// failures do not count, since they never leave without the user.
  /// Conflict notices wait for this (produktregler.md:189, "Konfliktbannern
  /// visas när kön töms, inte medan appen är offline").
  Stream<bool> watchSettled() =>
      watchCounts().map((c) => c.draining == 0 && isOnline).distinct();

  /// Sends the queue now. Resolves when the attempt is over.
  Future<void> syncNow();

  /// "Försök igen" on a permanent failure: it goes back into the queue.
  Future<void> retry(QueuedChange change);

  /// "Släng ändringen": only ever called after the user chose it and let the
  /// 7 s Ångra window close (produktregler.md:132).
  Future<void> discard(QueuedChange change);

  /// "Spara som kopia" (produktregler.md:188): the recipe's content on the
  /// device becomes a new recipe of the user's own, queued to be saved, and
  /// the failure leaves the queue. Only for [QueuedChange.canSaveAsCopy].
  /// The copy's title is [copyTitle] of the original's (Q6-14 = C).
  Future<void> saveAsCopy(
    QueuedChange change, {
    required String Function(String title) copyTitle,
  });

  /// "Försök mindre" (Skarmar v12 del 4 #synkko): a too-large image is sent
  /// again as a smaller copy. Only for [QueuedChange.canTrySmaller].
  Future<void> trySmaller(QueuedChange change);
}

/// The signed-in user's queue in the offline database. Everything fails
/// closed to "nothing waits" when the offline store is not ready or nobody is
/// signed in, so the indicator and the view never invent a number.
///
/// The user is the one the auth repository has signed in, the same source
/// the sync manager sends the queue for (OfflineSyncManager reads
/// `AuthRepository.currentUserId`).
class OfflineSyncQueueSource extends SyncQueueSource {
  const OfflineSyncQueueSource({this.offlineService, this.authRepository});

  /// The offline store, for tests. The app resolves it from the locator.
  final OfflineService? offlineService;

  /// Who is signed in, for tests. The app resolves it from the locator.
  final AuthRepository? authRepository;

  ({OfflineService offline, String userId})? _signedIn() {
    try {
      final service =
          offlineService ??
          (ServiceLocator.isRegistered<OfflineService>()
              ? ServiceLocator.get<OfflineService>()
              : null);
      if (service == null || !service.isInitialized) return null;
      final auth =
          authRepository ??
          (ServiceLocator.isRegistered<AuthRepository>()
              ? ServiceLocator.get<AuthRepository>()
              : null);
      final userId = auth?.currentUserId;
      if (userId == null || userId.isEmpty) return null;
      return (offline: service, userId: userId);
    } catch (e) {
      AppLogger.warning('SyncQueueSource: offline service unavailable: $e');
      return null;
    }
  }

  @override
  Stream<QueueCounts> watchCounts() {
    final signedIn = _signedIn();
    if (signedIn == null) return Stream.value(QueueCounts.empty);
    try {
      return signedIn.offline.database.watchQueueCounts(signedIn.userId);
    } catch (e) {
      AppLogger.warning('SyncQueueSource: counts unavailable: $e');
      return Stream.value(QueueCounts.empty);
    }
  }

  @override
  Stream<QueueSnapshot> watchChanges() {
    final signedIn = _signedIn();
    if (signedIn == null) return Stream.value(QueueSnapshot.empty);
    try {
      return watchQueuedChanges(
        signedIn.offline.database,
        signedIn.userId,
      ).map(QueueSnapshot.new);
    } catch (e) {
      AppLogger.warning('SyncQueueSource: queue unavailable: $e');
      return Stream.value(QueueSnapshot.empty);
    }
  }

  @override
  bool get isOnline => _signedIn()?.offline.isOnline ?? true;

  /// As [SyncQueueSource.watchSettled], and also re-read when the device
  /// goes on- or offline (OfflineService notifies on connectivity changes),
  /// so an empty queue is released on reconnect.
  @override
  Stream<bool> watchSettled() {
    final signedIn = _signedIn();
    if (signedIn == null) return Stream.value(true);
    final offline = signedIn.offline;
    StreamSubscription<QueueCounts>? counts;
    int? draining;
    late final StreamController<bool> controller;
    void emit() {
      final n = draining;
      if (n != null && !controller.isClosed) {
        controller.add(n == 0 && offline.isOnline);
      }
    }

    controller = StreamController<bool>(
      onListen: () {
        offline.addListener(emit);
        counts = watchCounts().listen(
          (c) {
            draining = c.draining;
            emit();
          },
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        offline.removeListener(emit);
        await counts?.cancel();
      },
    );
    return controller.stream.distinct();
  }

  @override
  Future<void> syncNow() async {
    final signedIn = _signedIn();
    if (signedIn == null) return;
    await signedIn.offline.syncNow();
  }

  @override
  Future<void> retry(QueuedChange change) async {
    final signedIn = _signedIn();
    if (signedIn == null) return;
    final offline = signedIn.offline;
    await retryQueuedChange(offline.database, change);
    await offline.refreshSyncState();
    if (offline.isOnline) unawaited(offline.syncNow());
  }

  @override
  Future<void> saveAsCopy(
    QueuedChange change, {
    required String Function(String title) copyTitle,
  }) async {
    final signedIn = _signedIn();
    if (signedIn == null) return;
    final offline = signedIn.offline;
    await saveQueuedChangeAsCopy(
      offline.database,
      signedIn.userId,
      change,
      copyTitle: copyTitle,
    );
    await offline.refreshSyncState();
    if (offline.isOnline) unawaited(offline.syncNow());
  }

  @override
  Future<void> trySmaller(QueuedChange change) async {
    final signedIn = _signedIn();
    if (signedIn == null) return;
    final offline = signedIn.offline;
    await retrySmallerQueuedChange(offline.database, signedIn.userId, change);
    await offline.refreshSyncState();
    if (offline.isOnline) unawaited(offline.syncNow());
  }

  @override
  Future<void> discard(QueuedChange change) async {
    final signedIn = _signedIn();
    if (signedIn == null) return;
    final recipeId = await discardQueuedChange(
      signedIn.offline.database,
      signedIn.userId,
      change,
    );
    await signedIn.offline.refreshSyncState();
    if (recipeId != null) signedIn.offline.announceRecipeLeftQueue(recipeId);
  }
}
