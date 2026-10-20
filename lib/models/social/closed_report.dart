import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';

/// Who made a decision, from the signed-in moderator's point of view.
enum DecisionMaker {
  self('self'),
  other('other'),
  auto('auto')
  ;

  const DecisionMaker(this.wireName);
  final String wireName;

  /// An unknown value reads as [auto]: it names nobody.
  static DecisionMaker fromWire(Object? value) {
    for (final m in values) {
      if (m.wireName == value) return m;
    }
    return DecisionMaker.auto;
  }
}

/// Why a closed report cannot be reopened (`reopenBlock`, and the message of
/// the `reopenReport` refusal).
enum ReopenBlock {
  reportGone('report_gone'),
  notClosed('not_closed'),
  appealed('appealed'),
  reporterErased('reporter_erased'),
  ownerErased('owner_erased'),
  noDecision('no_decision')
  ;

  const ReopenBlock(this.wireName);
  final String wireName;

  static ReopenBlock? fromWire(Object? value) {
    for (final b in values) {
      if (b.wireName == value) return b;
    }
    return null;
  }
}

/// One decision on a report: the current one, or an earlier round's.
class PastDecision {
  const PastDecision({
    required this.decision,
    required this.moderator,
    this.rule,
    this.decidedAt,
  });

  final ModeratorDecision decision;

  /// A report reason key such as `harassment`.
  final String? rule;
  final DateTime? decidedAt;
  final DecisionMaker moderator;

  static PastDecision? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final decision = ModeratorDecision.fromWire(_str(raw['decision']));
    if (decision == null) return null;
    final at = raw['decidedAt'];
    return PastDecision(
      decision: decision,
      rule: _str(raw['rule']),
      decidedAt: at is String ? DateTime.tryParse(at) : null,
      moderator: DecisionMaker.fromWire(raw['moderator']),
    );
  }
}

/// One row of the moderator's `listClosedReports`.
class ClosedReport extends PastDecision {
  const ClosedReport({
    required this.reportId,
    required super.decision,
    required super.moderator,
    super.rule,
    super.decidedAt,
    this.contentType,
    this.revision = 0,
    this.history = const [],
    this.appealed = false,
    this.reopenBlock,
  });

  final String reportId;
  final ContentType? contentType;
  final int revision;

  /// Earlier decisions, oldest first.
  final List<PastDecision> history;
  final bool appealed;

  /// Null when the report can be reopened.
  final ReopenBlock? reopenBlock;

  bool get wasRevised => history.isNotEmpty;

  ClosedReport withReopenBlock(ReopenBlock block) => ClosedReport(
    reportId: reportId,
    decision: decision,
    moderator: moderator,
    rule: rule,
    decidedAt: decidedAt,
    contentType: contentType,
    revision: revision,
    history: history,
    appealed: appealed || block == ReopenBlock.appealed,
    reopenBlock: block,
  );

  /// Null for a row without a usable id or decision.
  static ClosedReport? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = _str(raw['reportId']);
    final base = PastDecision.fromMap(raw);
    if (id == null || id.isEmpty || base == null) return null;
    final type = _str(raw['contentType']);
    final history = raw['history'];
    final revision = raw['revision'];
    return ClosedReport(
      reportId: id,
      decision: base.decision,
      moderator: base.moderator,
      rule: base.rule,
      decidedAt: base.decidedAt,
      contentType: type == null ? null : ContentType.fromWire(type),
      revision: revision is num ? revision.toInt() : 0,
      history: history is List
          ? [for (final e in history) ?PastDecision.fromMap(e)]
          : const [],
      appealed: raw['appealed'] == true,
      reopenBlock: ReopenBlock.fromWire(raw['reopenBlock']),
    );
  }
}

/// One page of `listClosedReports`.
class ClosedReportsPage {
  const ClosedReportsPage({required this.reports, this.nextCursor});

  final List<ClosedReport> reports;

  /// Null on the last page.
  final String? nextCursor;
}

String? _str(Object? v) => v is String ? v : null;
