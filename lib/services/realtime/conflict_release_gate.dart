// lib/services/realtime/conflict_release_gate.dart
//
// P6-U08b: "Konflikt i kön — Behandlas som § 2, inte som fel.
// Konfliktbannern visas när kön töms, inte medan appen är offline."
// (produktregler.md:189; fas2/block288-uxfrysning.json
// TR::FLOW::08::ko::toms::konfliktbanner).
library;

import 'dart:async';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/realtime/realtime_types.dart';

/// Holds conflict notices until the offline queue has emptied and the device
/// is online, then lets them through in the order they came.
///
/// [settled] is asked afresh for each wait, so a new sign-in or a new
/// database is always the one read. While it reports true a notice passes
/// at once, which is the ordinary online case. A notice is never dropped:
/// if the stream fails or ends before it has said true, what is held is let
/// through (a notice shown early beats a notice never shown,
/// produktregler.md:109).
class ConflictReleaseGate {
  ConflictReleaseGate({
    required Stream<bool> Function() settled,
    required void Function(ConflictEvent event) release,
  }) : _settled = settled,
       _release = release;

  final Stream<bool> Function() _settled;
  final void Function(ConflictEvent event) _release;

  final List<ConflictEvent> _held = [];
  StreamSubscription<bool>? _watch;

  /// How many notices wait for the queue.
  int get heldCount => _held.length;

  /// Takes one notice: let through when the queue has emptied, held until
  /// then otherwise.
  void offer(ConflictEvent event) {
    _held.add(event);
    if (_watch != null) return;
    try {
      final watch = _settled().listen(
        (isSettled) {
          if (isSettled) _flush();
        },
        onError: (Object e) {
          AppLogger.warning('ConflictReleaseGate: queue state failed: $e');
          _flush();
        },
        onDone: _flush,
      );
      // A synchronous stream may already have let everything through.
      if (_held.isEmpty) {
        unawaited(watch.cancel());
      } else {
        _watch = watch;
      }
    } catch (e) {
      AppLogger.warning('ConflictReleaseGate: queue state unavailable: $e');
      _flush();
    }
  }

  void _flush() {
    final watch = _watch;
    _watch = null;
    unawaited(watch?.cancel());
    final held = List.of(_held);
    _held.clear();
    for (final event in held) {
      _release(event);
    }
  }

  /// Lets through what is held and stops watching.
  void dispose() => _flush();
}
