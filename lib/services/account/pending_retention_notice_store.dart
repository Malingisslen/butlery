import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/utils/logger.dart';

/// The Art. 12(4) notice, held on this device until it has been read.
///
/// The notice is owed the moment an account deletion lawfully keeps moderation
/// evidence. There is no second channel — email infrastructure does not exist
/// (BUT-417). This store carries it to the signed-out screen, and it is cleared
/// when it has been acknowledged.
///
/// **Deliberately NOT a `BaseService`** — pure local storage, no Firebase, no
/// async service lifecycle. Same category as the documented non-adopters in
/// `lib/services/CLAUDE.md`, where it is listed.
///
/// **It carries no identifier.** No uid, no email, no name, no `resourceType`,
/// no `legalBasis`. The dialog's text is in the app. That is
/// what makes `shared_preferences` the right store rather than
/// `flutter_secure_storage`, whose extra failure modes on Android would fall on
/// exactly the delivery this exists to protect. Anything added here later needs
/// the same scrutiny as a new server field.
///
/// The price of that choice, named rather than left to be discovered: the file
/// is plaintext and unauthenticated-writable, so on a rooted device or through
/// an ADB backup it is a **forgeable trigger for a legal-sounding notice**. No
/// data leaves, and nothing beyond a Close button acts on it. Secure storage
/// would not stop a rooted device either. OWASP MASVS-STORAGE scopes at-rest
/// protection by security relevance rather than by PII alone, which is why this
/// paragraph exists at all.
class PendingRetentionNoticeStore {
  static const String _key = 'pending_retention_notice';

  /// How long an unacknowledged notice keeps coming back when the server sent
  /// no outer-cap date.
  ///
  /// With a date, the record dies when the hold does — past that there is
  /// nothing left to tell anyone about. Without one it would otherwise never
  /// expire, and somebody who never taps Close would meet it on every launch
  /// for the life of the install.
  static const Duration fallbackLifetime = Duration(days: 30);

  final ValueNotifier<int> _writes = ValueNotifier(0);

  /// Whether this process wrote the notice: the person who just deleted their
  /// account on this device, rather than a record left by an earlier run.
  ///
  /// Deliberately PROCESS-scoped and never persisted: after a restart the
  /// person in front of the screen may be someone else.
  bool get writtenInThisProcess => _writes.value > 0;

  /// Notifies after each successful [write] in this process.
  ///
  /// The write lands after the deletion's own sign-out has put the signed-out
  /// screen up, so `PendingNoticeGate` may already have read an empty store and
  /// has to hear about the write.
  Listenable get writes => _writes;

  /// Persist the notice. Best-effort: a storage failure is logged and
  /// swallowed.
  ///
  /// It must never throw into the deletion flow, which has already erased the
  /// account by the time this runs.
  Future<void> write({
    required DateTime? holdUntil,
    required bool provisional,
    bool reviewKept = true,
    bool ownReportKept = false,
    DateTime? now,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'holdUntil': holdUntil?.toIso8601String(),
          'provisional': provisional,
          'reviewKept': reviewKept,
          'ownReportKept': ownReportKept,
          'writtenAt': (now ?? DateTime.now()).toIso8601String(),
        }),
      );
      _writes.value++;
    } catch (e) {
      AppLogger.error('Could not persist the retention notice', e);
    }
  }

  /// The stored notice, or null when there is nothing to show.
  ///
  /// Returns null for an expired record and for one that cannot be parsed.
  /// Unreadable content is treated as absent rather than as an error: the only
  /// consumer is a gate on the sign-in screen, and there is nothing useful it
  /// could do with a throw except fail to draw the screen.
  Future<PendingRetentionNotice?> read({DateTime? now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      final writtenAt = DateTime.parse(map['writtenAt'] as String);
      final holdUntilRaw = map['holdUntil'] as String?;
      final holdUntil = holdUntilRaw == null
          ? null
          : DateTime.parse(holdUntilRaw);

      final expiresAt = holdUntil ?? writtenAt.add(fallbackLifetime);
      if (!(now ?? DateTime.now()).isBefore(expiresAt)) return null;

      return PendingRetentionNotice(
        holdUntil: holdUntil,
        provisional: map['provisional'] as bool? ?? false,
        // A record written before these fields existed was always a review.
        reviewKept: map['reviewKept'] as bool? ?? true,
        ownReportKept: map['ownReportKept'] as bool? ?? false,
      );
    } catch (e) {
      AppLogger.error('Could not read the retention notice', e);
      return null;
    }
  }

  /// Forget the notice. Best-effort, for the reason [write] is.
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      AppLogger.error('Could not clear the retention notice', e);
    }
  }
}

/// A notice waiting to be read on this device.
class PendingRetentionNotice {
  const PendingRetentionNotice({
    required this.holdUntil,
    required this.provisional,
    this.reviewKept = true,
    this.ownReportKept = false,
  });

  /// When the hold lifts at the latest. Absent when the server sent no
  /// parsable date — the notice then says less rather than naming a date
  /// nobody measured.
  final DateTime? holdUntil;

  /// Whether the hold was placed without the predicate being answered, which
  /// hedges the notice's "what" line (BUT-2047).
  final bool provisional;

  /// A review of content the person was reported for was kept.
  final bool reviewKept;

  /// A report the person filed was kept.
  final bool ownReportKept;
}
