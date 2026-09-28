/// P8-U04: hosts for the key screens that are not among the 53 rows.
library;

import 'package:flutter/material.dart';

import 'package:butlery/services/offline/queued_change.dart';
import 'package:butlery/views/more/more_view.dart';
import 'package:butlery/views/sync/sync_queue_view.dart';

import '../design_states/state_harness.dart';
import '../design_states/state_host.dart';

/// Mer, with a fixed avatar (MoreView.avatar is replaceable for this,
/// lib/views/more/more_view.dart:32-34) and two changes waiting.
final StateHost moreHost = StateHost(
  build: (ctx) async {
    ctx.env.queue.set(_changes());
    return const MoreView(avatar: SizedBox.square(dimension: 40));
  },
);

/// Väntar på synk with one change draining and one that needs the user.
final StateHost syncQueueHost = StateHost(
  build: (ctx) async {
    ctx.env.queue.set(_changes());
    return SyncQueueView(backTo: sv.moreTitle);
  },
);

/// A queue time fixed so the ages read the same on every run.
final goldenNow = DateTime(2026, 9, 24, 17, 30);

List<QueuedChange> _changes() => [
  QueuedChange(
    kind: QueuedChangeKind.recipe,
    id: 'q1',
    operation: QueuedOperation.update,
    queuedAt: goldenNow.subtract(const Duration(minutes: 12)),
    subject: 'Linsgryta med kokos',
  ),
  QueuedChange(
    kind: QueuedChangeKind.recipe,
    id: 'q2',
    operation: QueuedOperation.update,
    queuedAt: goldenNow.subtract(const Duration(hours: 3)),
    subject: 'Citronrisotto',
    needsUser: true,
    reason: QueuedChangeReason.permissionDenied,
  ),
];
