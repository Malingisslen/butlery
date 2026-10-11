import 'package:intl/intl.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/moderation_motivation.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/widgets/social/report_reason_labels.dart';

String motivationText(AppLocalizations l10n, ModerationMotivation m) =>
    switch (m) {
      ModerationMotivation.removedCopyright => l10n.motivationRemovedCopyright,
      ModerationMotivation.removedSpam => l10n.motivationRemovedSpam,
      ModerationMotivation.removedAbuse => l10n.motivationRemovedAbuse,
      ModerationMotivation.removedHarassment =>
        l10n.motivationRemovedHarassment,
      ModerationMotivation.removedOther => l10n.motivationRemovedOther,
      ModerationMotivation.hiddenRules => l10n.motivationHiddenRules,
      ModerationMotivation.hiddenSpam => l10n.motivationHiddenSpam,
      ModerationMotivation.keptNoBreach => l10n.motivationKeptNoBreach,
      ModerationMotivation.keptAlreadyGone => l10n.motivationKeptAlreadyGone,
      ModerationMotivation.keptUnclear => l10n.motivationKeptUnclear,
      ModerationMotivation.misattributionNameRemoved =>
        l10n.motivationMisattributionNameRemoved,
    };

String decisionHeadline(AppLocalizations l10n, ModeratorDecision d) =>
    switch (d) {
      ModeratorDecision.contentRemoved => l10n.decisionHeadlineContentRemoved,
      ModeratorDecision.profileHidden => l10n.decisionHeadlineProfileHidden,
      ModeratorDecision.noAction => l10n.decisionHeadlineNoAction,
    };

/// "Ditt recept" for the owner, "Ett recept" for the reporter.
String decisionSubject(
  AppLocalizations l10n,
  ContentType type, {
  required bool owner,
}) {
  final who = owner ? 'owner' : 'reporter';
  return switch (type) {
    ContentType.recipe => l10n.decisionSubjectRecipe(who),
    ContentType.comment => l10n.decisionSubjectComment(who),
    ContentType.message => l10n.decisionSubjectMessage(who),
    ContentType.profile => l10n.decisionSubjectProfile(who),
    ContentType.cookSnap => l10n.decisionSubjectCookSnap(who),
    ContentType.group => l10n.decisionSubjectGroup(who),
    ContentType.menuDish => l10n.decisionSubjectMenuDish(who),
  };
}

/// The reason label folded into a sentence, so lower case.
String reasonInSentence(AppLocalizations l10n, String storedReason) =>
    reportReasonDisplay(l10n, storedReason).toLowerCase();

String appealFailureText(AppLocalizations l10n, AppealFailure f) => switch (f) {
  AppealFailure.windowClosed => l10n.appealErrorWindowClosed,
  AppealFailure.alreadyAppealed => l10n.appealErrorExists,
  AppealFailure.notAllowed => l10n.appealErrorNotAllowed,
  AppealFailure.notFound => l10n.appealErrorNotFound,
  AppealFailure.invalidText => l10n.appealErrorInvalidText(
    ModerationAppealsService.minTextLength,
    ModerationAppealsService.maxTextLength,
  ),
  AppealFailure.other => l10n.appealErrorGeneric,
};

/// A date without a time, in the app language.
String formatDecisionDate(AppLocalizations l10n, DateTime date) =>
    DateFormat.yMMMd(l10n.localeName).format(date.toLocal());
