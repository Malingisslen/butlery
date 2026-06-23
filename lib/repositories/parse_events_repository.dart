import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/admin/parse_event.dart';

/// Result of a parse-events drill-down query: the events plus whether the cap
/// was hit (so the UI can say "showing the first N").
class ParseEventsPage {
  final List<ParseEvent> events;
  final bool truncated;
  const ParseEventsPage({required this.events, required this.truncated});

  static const empty = ParseEventsPage(events: [], truncated: false);
}

/// Admin-only, read-only repository for parse-event drill-down. Reads the
/// `parse_events` collection (admin-gated in firestore.rules). No writes —
/// events are written server-side by `logParseEvent`.
///
/// Lightweight admin-repo pattern (cf. SiteConfigRepository): direct Firestore,
/// no PermissionValidationMixin; admin read gated by `isAdmin()` in the rules.
class ParseEventsRepository {
  final FirebaseFirestore _firestore;

  /// Cap per drill-down. Equality-on-domain is auto-indexed; we sort by time in
  /// Dart to avoid needing a composite index. `truncated` flags when hit.
  static const int _cap = 200;

  ParseEventsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Recent parse events for [domain], newest first. [failuresOnly] keeps just
  /// the failed attempts (the usual "why does this site fail" view).
  Future<ParseEventsPage> getByDomain(
    String domain, {
    bool failuresOnly = false,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('parse_events')
          .where('domain', isEqualTo: domain)
          .limit(_cap)
          .get();
      var events = snapshot.docs
          .map((doc) => ParseEvent.fromFirestore(doc.data()))
          .toList();
      if (failuresOnly) {
        events = events.where((e) => !e.success).toList();
      }
      // Newest first; nulls (no timestamp) sort last.
      events.sort((a, b) {
        final at = a.timestamp?.millisecondsSinceEpoch ?? 0;
        final bt = b.timestamp?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at);
      });
      return ParseEventsPage(
        events: events,
        truncated: snapshot.docs.length >= _cap,
      );
    } catch (e) {
      AppLogger.warning('ParseEventsRepository: failed for $domain: $e');
      return ParseEventsPage.empty;
    }
  }
}
