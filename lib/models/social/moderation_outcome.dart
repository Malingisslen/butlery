import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/moderation_motivation.dart';

/// Which side of a report the caller is on when appealing.
enum AppealRole {
  reporter('reporter'),
  owner('owner')
  ;

  const AppealRole(this.wireName);
  final String wireName;

  static AppealRole? fromWire(String? value) {
    for (final r in values) {
      if (r.wireName == value) return r;
    }
    return null;
  }
}

enum AppealStatus {
  open('open'),
  upheld('upheld'),
  reversed('reversed')
  ;

  const AppealStatus(this.wireName);
  final String wireName;

  static AppealStatus? fromWire(String? value) {
    for (final s in values) {
      if (s.wireName == value) return s;
    }
    return null;
  }
}

class ModerationAppeal {
  const ModerationAppeal({
    required this.status,
    required this.text,
    this.submittedAt,
    this.answeredAt,
  });

  final AppealStatus status;
  final String text;
  final DateTime? submittedAt;
  final DateTime? answeredAt;

  static ModerationAppeal? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final status = AppealStatus.fromWire(_str(raw['status']));
    if (status == null) return null;
    return ModerationAppeal(
      status: status,
      text: _str(raw['text']).orEmpty(),
      submittedAt: _date(raw['submittedAt']),
      answeredAt: _date(raw['answeredAt']),
    );
  }
}

/// What was decided on one closed report, as the server returns it to the
/// reporter (`getMyReportOutcomes`) or the content owner
/// (`getMyContentDecisions`, which also names [contentType] and [reason]).
class ModerationOutcome {
  const ModerationOutcome({
    required this.reportId,
    required this.decision,
    this.motivationKey,
    this.decidedAt,
    this.appealDeadline,
    this.appeal,
    this.contentType,
    this.reason,
    this.revised = false,
    this.appealable = true,
  });

  final String reportId;
  final ModeratorDecision decision;

  /// Kept as the raw key; an unknown one still renders as no motivation.
  final String? motivationKey;
  final DateTime? decidedAt;
  final DateTime? appealDeadline;
  final ModerationAppeal? appeal;
  final ContentType? contentType;
  final String? reason;

  /// The decision was changed when the case was reopened.
  final bool revised;

  /// False when the server would refuse an appeal whatever the deadline:
  /// the case is reopened, or the owner's decision is no action.
  final bool appealable;

  ModerationMotivation? get motivation =>
      ModerationMotivation.fromWire(motivationKey);

  bool canAppeal(DateTime now) =>
      appealable &&
      appeal == null &&
      (appealDeadline == null || !now.isAfter(appealDeadline!));

  ModerationOutcome withAppeal(ModerationAppeal appeal) => ModerationOutcome(
    reportId: reportId,
    decision: decision,
    motivationKey: motivationKey,
    decidedAt: decidedAt,
    appealDeadline: appealDeadline,
    appeal: appeal,
    contentType: contentType,
    reason: reason,
    revised: revised,
    appealable: appealable,
  );

  /// Null for a row without a usable id or decision.
  static ModerationOutcome? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = _str(raw['reportId']);
    final decision = ModeratorDecision.fromWire(_str(raw['decision']));
    if (id == null || id.isEmpty || decision == null) return null;
    final type = _str(raw['contentType']);
    return ModerationOutcome(
      reportId: id,
      decision: decision,
      motivationKey: _str(raw['motivation']),
      decidedAt: _date(raw['decidedAt']),
      appealDeadline: _date(raw['appealDeadline']),
      appeal: ModerationAppeal.fromMap(raw['appeal']),
      contentType: type == null ? null : ContentType.fromWire(type),
      reason: _str(raw['reason']),
      revised: raw['revised'] == true,
      // A server older than BUT-1528 does not send it.
      appealable: raw['appealable'] != false,
    );
  }
}

/// One row of the moderator's `listOpenAppeals`.
class OpenAppeal {
  const OpenAppeal({
    required this.appealId,
    required this.reportId,
    required this.role,
    required this.decision,
    required this.text,
    this.contentType,
    this.contentId,
    this.reason,
    this.decidedAt,
    this.createdAt,
  });

  final String appealId;
  final String reportId;
  final AppealRole role;
  final ModeratorDecision decision;
  final String text;
  final ContentType? contentType;
  final String? contentId;
  final String? reason;
  final DateTime? decidedAt;
  final DateTime? createdAt;

  static OpenAppeal? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = _str(raw['appealId']);
    final reportId = _str(raw['reportId']);
    final role = AppealRole.fromWire(_str(raw['role']));
    final decision = ModeratorDecision.fromWire(_str(raw['decision']));
    if (id == null ||
        id.isEmpty ||
        reportId == null ||
        role == null ||
        decision == null) {
      return null;
    }
    final type = _str(raw['contentType']);
    return OpenAppeal(
      appealId: id,
      reportId: reportId,
      role: role,
      decision: decision,
      text: _str(raw['text']).orEmpty(),
      contentType: type == null ? null : ContentType.fromWire(type),
      contentId: _str(raw['contentId']),
      reason: _str(raw['reason']),
      decidedAt: _date(raw['decidedAt']),
      createdAt: _date(raw['createdAt']),
    );
  }
}

String? _str(Object? v) => v is String ? v : null;

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
