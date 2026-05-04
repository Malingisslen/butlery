import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared TTL plumbing for presence repositories (BUT-477).
///
/// `recipePresence` and `shoppingPresence` both write per-doc `expiresAt`
/// timestamps so a stale row from a crashed client gets evicted by Firestore's
/// TTL policy. Heartbeat refresh runs at half the TTL window so a single
/// missed tick does not flicker the indicator.
class PresenceTtl {
  PresenceTtl._();

  /// TTL window. Heartbeat refresh interval is `ttl / 2`.
  static const Duration ttl = Duration(seconds: 60);

  /// `expiresAt` timestamp for a fresh write — `now + ttl`.
  static Timestamp computeExpiresAt() {
    return Timestamp.fromDate(clock.now().toUtc().add(ttl));
  }

  /// Drop rows whose `expiresAt` is in the past. Rows missing the field are
  /// kept (legacy data written before BUT-477 — TTL policy will catch them).
  static List<Map<String, dynamic>> filterStaleRows(
    Iterable<Map<String, dynamic>> rows,
  ) {
    final now = clock.now().toUtc();
    return rows.where((row) {
      final raw = row['expiresAt'];
      if (raw is! Timestamp) return true;
      return raw.toDate().toUtc().isAfter(now);
    }).toList(growable: false);
  }
}
