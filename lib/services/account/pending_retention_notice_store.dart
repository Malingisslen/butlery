import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/utils/logger.dart';

/// The Art. 12(4) notice, held on this device until it has been read.
///
/// The notice is owed the moment an account deletion lawfully keeps moderation
/// evidence, and it has exactly one moment to be shown: after the account is
/// gone and before the sign-out navigation. There is no second channel — email
/// infrastructure does not exist (BUT-417) — so if the app is killed,
/// backgrounded or the context dies in that second, the person never receives
/// it. This store is what survives that: written before the dialog, read on the
/// signed-out screen at next launch, cleared when it has been acknowledged.
///
/// **Deliberately NOT a `BaseService`** — pure local storage, no Firebase, no
/// async service lifecycle. Same category as the documented non-adopters in
/// `lib/services/CLAUDE.md`, where it is listed.
///
/// **It carries no identifier.** No uid, no email, no name, no `resourceType`,
/// no `legalBasis` — only the outer-cap date, whether the hold was provisional,
/// and when the record was written. The dialog's text is in the app. That is
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

  bool _deliveredLiveInThisProcess = false;

  /// Whether the live dialog has already delivered the notice in THIS process.
  ///
  /// The arbiter between the two readers of one record, and it exists because
  /// they are otherwise independent: the record stays on disk while the live
  /// dialog is up (it is cleared only after the person closes it), and the
  /// sign-out that dialog follows rebuilds the signed-out tree — so
  /// `PendingNoticeGate` can mount, read a record that is still there, and
  /// stack a second notice on top of one that is working. The cost of that is
  /// not the duplicate dialog but the measurement: `retention_notice_recovered`
  /// means "the live dialog never delivered", and without this it would fire
  /// hardest on the runs where it did.
  ///
  /// Deliberately PROCESS-scoped and never persisted. If the app dies before
  /// the person reads the notice, the flag dies with it and the record on disk
  /// is delivered at next launch — which is the entire point of the record.
  bool get deliveredLiveInThisProcess => _deliveredLiveInThisProcess;

  /// Claim delivery for the live dialog.
  ///
  /// Called BEFORE [write], not merely before the dialog: `setString` publishes
  /// to `shared_preferences`' in-process cache before its future completes, and
  /// [read] hits that same cache — so between the write and a later claim the
  /// record is readable and unclaimed, which is the whole window this exists to
  /// close.
  void markDeliveredLive() => _deliveredLiveInThisProcess = true;

  /// Give the claim back when the live dialog turns out not to be showable —
  /// the context died during the write.
  ///
  /// Without this, claiming early would suppress the gate for the rest of the
  /// process on exactly the run where the gate is the only delivery left.
  void releaseLiveClaim() => _deliveredLiveInThisProcess = false;

  /// Persist the notice. Best-effort: a storage failure is logged and
  /// swallowed.
  ///
  /// It must never throw into the deletion flow. The live dialog is about to be
  /// shown from memory and does not depend on this; the record is the fallback
  /// for the run where that dialog never happens, so a failure here may cost the
  /// fallback and must not also cost the notice.
  Future<void> write({
    required DateTime? holdUntil,
    required bool provisional,
    DateTime? now,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'holdUntil': holdUntil?.toIso8601String(),
          'provisional': provisional,
          'writtenAt': (now ?? DateTime.now()).toIso8601String(),
        }),
      );
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
  });

  /// When the hold lifts at the latest. Absent when the server sent no
  /// parsable date — the notice then says less rather than naming a date
  /// nobody measured.
  final DateTime? holdUntil;

  /// Whether the hold was placed without the predicate being answered, which
  /// hedges the notice's "what" line (BUT-2047).
  final bool provisional;
}
