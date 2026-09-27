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

  /// Sends the queue now. Resolves when the attempt is over.
  Future<void> syncNow();

  /// "Försök igen" on a permanent failure: it goes back into the queue.
  Future<void> retry(QueuedChange change);

  /// "Släng ändringen": only ever called after the user chose it.
  Future<void> discard(QueuedChange change);
}

/// The signed-in user's queue in the offline database. Everything fails
/// closed to "nothing waits" when the offline store is not ready, so the
/// indicator and the view never invent a number.
class OfflineSyncQueueSource extends SyncQueueSource {
  const OfflineSyncQueueSource();

  OfflineService? _offline() {
    try {
      if (!ServiceLocator.isRegistered<OfflineService>()) return null;
      final service = ServiceLocator.get<OfflineService>();
      return service.isInitialized && service.currentUserId != null
          ? service
          : null;
    } catch (e) {
      AppLogger.warning('SyncQueueSource: offline service unavailable: $e');
      return null;
    }
  }

  @override
  Stream<QueueCounts> watchCounts() {
    final offline = _offline();
    if (offline == null) return Stream.value(QueueCounts.empty);
    try {
      return offline.database.watchQueueCounts(offline.currentUserId!);
    } catch (e) {
      AppLogger.warning('SyncQueueSource: counts unavailable: $e');
      return Stream.value(QueueCounts.empty);
    }
  }

  @override
  Stream<QueueSnapshot> watchChanges() {
    final offline = _offline();
    if (offline == null) return Stream.value(QueueSnapshot.empty);
    try {
      return watchQueuedChanges(
        offline.database,
        offline.currentUserId!,
      ).map(QueueSnapshot.new);
    } catch (e) {
      AppLogger.warning('SyncQueueSource: queue unavailable: $e');
      return Stream.value(QueueSnapshot.empty);
    }
  }

  @override
  bool get isOnline => _offline()?.isOnline ?? true;

  @override
  Future<void> syncNow() async {
    final offline = _offline();
    if (offline == null) return;
    await offline.syncNow();
  }

  @override
  Future<void> retry(QueuedChange change) async {
    final offline = _offline();
    if (offline == null) return;
    await retryQueuedChange(offline.database, change);
    await offline.refreshSyncState();
    if (offline.isOnline) unawaited(offline.syncNow());
  }

  @override
  Future<void> discard(QueuedChange change) async {
    final offline = _offline();
    if (offline == null) return;
    await discardQueuedChange(
      offline.database,
      offline.currentUserId!,
      change,
    );
    await offline.refreshSyncState();
  }
}
