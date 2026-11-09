import 'package:butlery/models/social/content_report.dart';

/// The ready-made reasons a moderator picks when closing a report. The keys
/// are the wire values the server validates; the text lives in l10n.
enum ModerationMotivation {
  removedCopyright('removed_copyright', ModeratorDecision.contentRemoved),
  removedSpam('removed_spam', ModeratorDecision.contentRemoved),
  removedAbuse('removed_abuse', ModeratorDecision.contentRemoved),
  removedHarassment('removed_harassment', ModeratorDecision.contentRemoved),
  removedOther('removed_other', ModeratorDecision.contentRemoved),
  hiddenRules('hidden_rules', ModeratorDecision.profileHidden),
  hiddenSpam('hidden_spam', ModeratorDecision.profileHidden),
  keptNoBreach('kept_no_breach', ModeratorDecision.noAction),
  keptAlreadyGone('kept_already_gone', ModeratorDecision.noAction),
  keptUnclear('kept_unclear', ModeratorDecision.noAction),
  misattributionNameRemoved('misattribution_name_removed', null),
  removedAutomatedImage('removed_automated_image', null)
  ;

  const ModerationMotivation(this.wireName, this.decision);

  final String wireName;

  /// Null for the keys the server sets itself (misattribution, automatic image
  /// removal); they are never a moderator's choice.
  final ModeratorDecision? decision;

  static ModerationMotivation? fromWire(String? value) {
    for (final m in values) {
      if (m.wireName == value) return m;
    }
    return null;
  }

  /// The keys a moderator may pick for [decision], in display order.
  static List<ModerationMotivation> choicesFor(ModeratorDecision decision) => [
    for (final m in values)
      if (m.decision == decision) m,
  ];

  /// The server falls back to this key for a missing or invalid one.
  static ModerationMotivation defaultFor(ModeratorDecision decision) =>
      switch (decision) {
        ModeratorDecision.contentRemoved => removedOther,
        ModeratorDecision.profileHidden => hiddenRules,
        ModeratorDecision.noAction => keptNoBreach,
      };
}
