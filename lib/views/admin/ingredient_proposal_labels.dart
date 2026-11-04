import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/ingredient_column.dart';
import 'package:butlery/services/tagging/ingredient_change_validator.dart';

String ingredientColumnLabel(AppLocalizations l10n, IngredientColumn column) =>
    switch (column) {
      IngredientColumn.swedish => l10n.adminIngredientFieldSwedish,
      IngredientColumn.english => l10n.adminIngredientFieldEnglish,
      IngredientColumn.group => l10n.adminIngredientFieldGroup,
      IngredientColumn.properties => l10n.adminIngredientFieldProperties,
      IngredientColumn.aliasesSv => l10n.adminIngredientFieldAliasesSv,
      IngredientColumn.aliasesEn => l10n.adminIngredientFieldAliasesEn,
      IngredientColumn.searchTerms => l10n.adminIngredientFieldSearchTerms,
      IngredientColumn.notesSv => l10n.adminIngredientFieldNotesSv,
      IngredientColumn.notesEn => l10n.adminIngredientFieldNotesEn,
      IngredientColumn.seasonAvailability => l10n.adminIngredientFieldSeasons,
      IngredientColumn.typicalStorage => l10n.adminIngredientFieldStorage,
      IngredientColumn.typicalUnit => l10n.adminIngredientFieldUnit,
      IngredientColumn.priceCategory => l10n.adminIngredientFieldPriceCategory,
      IngredientColumn.avgPriceSek => l10n.adminIngredientFieldAvgPrice,
      IngredientColumn.carbonFootprintCategory =>
        l10n.adminIngredientFieldCarbon,
      IngredientColumn.status => l10n.adminIngredientFieldStatus,
    };

String ingredientIssueText(AppLocalizations l10n, IngredientFieldIssue issue) {
  final detail = issue.detail.orEmpty();
  return switch (issue.code) {
    IngredientIssueCode.tooLong => l10n.adminIssueTooLong(detail),
    IngredientIssueCode.controlCharacter => l10n.adminIssueControl,
    IngredientIssueCode.empty => l10n.adminIssueEmpty,
    IngredientIssueCode.unknownProperty => l10n.adminIssueUnknownProperty(
      detail,
    ),
    IngredientIssueCode.invalidGroup => l10n.adminIssueGroup,
    IngredientIssueCode.invalidStatus => l10n.adminIssueStatus,
    IngredientIssueCode.invalidPriceCategory => l10n.adminIssuePriceCategory,
    IngredientIssueCode.invalidCarbonCategory => l10n.adminIssueCarbon,
    IngredientIssueCode.separatorInElement => l10n.adminIssueSeparator(detail),
    IngredientIssueCode.tooManyElements => l10n.adminIssueTooMany(detail),
    IngredientIssueCode.invalidPrice => l10n.adminIssuePrice,
  };
}

/// Old/new values as one readable string; empty is spelled out so a cleared
/// field is visible.
String ingredientValueText(AppLocalizations l10n, Object? value) {
  final text = switch (value) {
    null => '',
    Iterable() => value.join(', '),
    _ => value.toString(),
  };
  return text.isEmpty ? l10n.adminProposalEmptyValue : text;
}

/// Plain-language reason a proposal ended as `conflict` or `rejected`; the
/// server writes a code, an unknown one reads as an invalid value.
String proposalReasonText(AppLocalizations l10n, String? reason) =>
    switch (reason) {
      'csv-mismatch' => l10n.adminProposalReasonCsvMismatch,
      'missing-row' => l10n.adminProposalReasonMissingRow,
      'no-change' => l10n.adminProposalReasonNoChange,
      'write-failed' => l10n.adminProposalReasonWriteFailed,
      _ => l10n.adminProposalReasonInvalid,
    };
