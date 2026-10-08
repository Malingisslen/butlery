// lib/services/offline/sync_queue_reader_web.dart
//
// P4-U19: the web has no offline queue (app_database_stub_web.dart), so the
// "Väntar på synk" view is always empty there and no action has anything to
// act on.
library;

import 'package:butlery/core/storage/drift/app_database_stub_web.dart';
import 'package:butlery/services/offline/queued_change.dart';

/// Nothing waits on the web.
Stream<List<QueuedChange>> watchQueuedChanges(AppDatabase db, String userId) =>
    Stream.value(const []);

/// Nothing to retry on the web.
Future<void> retryQueuedChange(AppDatabase db, QueuedChange change) async {}

/// Nothing to discard on the web.
Future<({String recipeId, bool recipeDeleted})?> discardQueuedChange(
  AppDatabase db,
  String userId,
  QueuedChange change,
) async => null;

/// Nothing to copy on the web.
Future<String> saveQueuedChangeAsCopy(
  AppDatabase db,
  String userId,
  QueuedChange change, {
  String? newId,
  String Function(String title)? copyTitle,
}) async => throw UnsupportedError('The web has no offline queue');

/// Nothing to shrink on the web.
Future<void> retrySmallerQueuedChange(
  AppDatabase db,
  String userId,
  QueuedChange change,
) async => throw UnsupportedError('The web has no offline queue');
