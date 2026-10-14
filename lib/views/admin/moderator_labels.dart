import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/feedback_entry.dart';
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
