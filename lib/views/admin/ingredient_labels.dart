import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/viewmodels/admin/ingredient_review_viewmodel.dart';

String ingredientStatusLabel(AppLocalizations l10n, String status) {
  return switch (IngredientStatusBucket.of(status)) {
    IngredientStatusBucket.draft => l10n.adminIngredientStatusDraft,
    IngredientStatusBucket.validated => l10n.adminIngredientStatusValidated,
    IngredientStatusBucket.verified => l10n.adminIngredientStatusVerified,
    IngredientStatusBucket.needsReview => l10n.adminIngredientStatusNeedsReview,
    _ => l10n.adminIngredientStatusOther,
  };
}
