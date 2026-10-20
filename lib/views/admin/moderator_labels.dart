import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/models/social/closed_report.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/widgets/social/report_reason_labels.dart';

String moderatorContentTypeLabel(AppLocalizations l10n, ContentType type) =>
    switch (type) {
      ContentType.recipe => l10n.moderatorContentTypeRecipe,
      ContentType.comment => l10n.moderatorContentTypeComment,
      ContentType.message => l10n.moderatorContentTypeMessage,
      ContentType.profile => l10n.moderatorContentTypeProfile,
      ContentType.cookSnap => l10n.moderatorContentTypeCookSnap,
      ContentType.group => l10n.moderatorContentTypeGroup,
      ContentType.menuDish => l10n.moderatorContentTypeMenuDish,
    };

/// Reports saved before reasons had ids hold their label as text; the one
/// that was an English word gets today's label instead of being shown raw.
String moderatorReasonLabel(AppLocalizations l10n, String storedReason) =>
    storedReason == 'inappropriate'
    ? l10n.reportReasonInappropriate
    : reportReasonDisplay(l10n, storedReason);

String feedbackCategoryLabel(
  AppLocalizations l10n,
  FeedbackCategory category,
) => switch (category) {
  FeedbackCategory.bug => l10n.feedbackCategoryBug,
  FeedbackCategory.featureRequest => l10n.feedbackCategoryFeatureRequest,
  FeedbackCategory.general => l10n.feedbackCategoryGeneral,
};

String moderatorDecisionLabel(AppLocalizations l10n, ModeratorDecision d) =>
    switch (d) {
      ModeratorDecision.contentRemoved => l10n.moderatorDecisionContentRemoved,
      ModeratorDecision.profileHidden => l10n.moderatorDecisionProfileHidden,
      ModeratorDecision.noAction => l10n.moderatorDecisionNoAction,
    };

String decisionMakerLabel(AppLocalizations l10n, DecisionMaker m) =>
    switch (m) {
      DecisionMaker.self => l10n.moderatorByYou,
      DecisionMaker.other => l10n.moderatorByOther,
      DecisionMaker.auto => l10n.moderatorByAuto,
    };

String reopenBlockText(AppLocalizations l10n, ReopenBlock b) => switch (b) {
  ReopenBlock.appealed => l10n.moderatorReopenBlockAppealed,
  ReopenBlock.reportGone => l10n.moderatorReopenBlockGone,
  ReopenBlock.notClosed => l10n.moderatorReopenBlockNotClosed,
  ReopenBlock.reporterErased => l10n.moderatorReopenBlockReporterErased,
  ReopenBlock.ownerErased => l10n.moderatorReopenBlockOwnerErased,
  ReopenBlock.noDecision => l10n.moderatorReopenBlockNoDecision,
};

/// "Trakasserier · Profil · 18 okt 14:02 · Du": the rule, what it applied to,
/// when and by whom. [type] is left out when the row names none.
String pastDecisionLine(
  AppLocalizations l10n,
  PastDecision d, {
  ContentType? type,
}) => [
  if (d.rule != null) moderatorReasonLabel(l10n, d.rule!),
  if (type != null) moderatorContentTypeLabel(l10n, type),
  if (d.decidedAt != null)
    ContextualTimeFormatter.dateTime(
      d.decidedAt!.toLocal(),
      localeName: l10n.localeName,
    ),
  decisionMakerLabel(l10n, d.moderator),
].join(' · ');
