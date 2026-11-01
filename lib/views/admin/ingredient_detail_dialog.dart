import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/ingredient_review_viewmodel.dart';
import 'package:butlery/views/admin/ingredient_copy.dart';
import 'package:butlery/views/admin/ingredient_labels.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

Future<void> showIngredientDetail(
  BuildContext context,
  IngredientReviewViewModel vm,
  IngredientData ingredient,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: _Detail(vm: vm, ingredient: ingredient),
      ),
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.vm, required this.ingredient});

  final IngredientReviewViewModel vm;
  final IngredientData ingredient;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final i = ingredient;
    final preview = vm.previewOf(i);
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(i.swedish, style: AppTextStyles.headlineSmall),
          Align(
            alignment: Alignment.centerRight,
            child: ButleryTextButton(
              label: l10n.adminCopyForClaude,
              icon: ButleryIcons.copy,
              onPressed: () => copyIngredientForClaude(context, vm, i),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _field(
                  l10n.adminIngredientsAllergens,
                  preview == null
                      ? l10n.adminIngredientsNoTagConfig
                      : _list(l10n, preview.allergenKeys),
                ),
                _field(
                  l10n.adminIngredientsBrokenDiets,
                  preview == null
                      ? l10n.adminIngredientsNoTagConfig
                      : _list(l10n, preview.brokenDietKeys.map(vm.dietLabel)),
                ),
                _field(l10n.adminIngredientFieldId, i.id),
                _field(l10n.adminIngredientFieldSwedish, i.swedish),
                _field(l10n.adminIngredientFieldEnglish, i.english),
                _field(l10n.adminIngredientFieldGroup, i.group),
                _field(
                  l10n.adminIngredientFieldStatus,
                  '${ingredientStatusLabel(l10n, i.status)} (${i.status})',
                ),
                _field(
                  l10n.adminIngredientFieldProperties,
                  _list(l10n, i.properties.toList()..sort()),
                ),
                _field(
                  l10n.adminIngredientFieldAliasesSv,
                  _list(l10n, i.aliasesSv),
                ),
                _field(
                  l10n.adminIngredientFieldAliasesEn,
                  _list(l10n, i.aliasesEn),
                ),
                _field(
                  l10n.adminIngredientFieldSearchTerms,
                  _list(l10n, i.searchTerms),
                ),
                _field(
                  l10n.adminIngredientFieldLearnedAliases,
                  _list(l10n, i.learnedAliasesSv),
                ),
                _field(
                  l10n.adminIngredientFieldSeasons,
                  _list(l10n, i.seasonAvailability),
                ),
                _field(
                  l10n.adminIngredientFieldPriceCategory,
                  _text(i.priceCategory),
                ),
                _field(
                  l10n.adminIngredientFieldAvgPrice,
                  _text(i.avgPriceSek?.toString()),
                ),
                _field(
                  l10n.adminIngredientFieldCarbon,
                  _text(i.carbonFootprintCategory),
                ),
                _field(l10n.adminIngredientFieldNotesSv, _text(i.notesSv)),
                _field(l10n.adminIngredientFieldNotesEn, _text(i.notesEn)),
                _field(
                  l10n.adminIngredientFieldStorage,
                  _text(i.typicalStorage),
                ),
                _field(l10n.adminIngredientFieldUnit, _text(i.typicalUnit)),
                _field(
                  l10n.adminIngredientFieldCompound,
                  i.isCompoundName
                      ? l10n.adminIngredientYes
                      : l10n.adminIngredientNo,
                ),
                _field(
                  l10n.adminIngredientFieldCreated,
                  _text(i.createdAt?.toIso8601String()),
                ),
                _field(
                  l10n.adminIngredientFieldUpdated,
                  _text(i.updatedAt?.toIso8601String()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _text(String? v) => (v == null || v.isEmpty) ? '—' : v;

  static String _list(AppLocalizations l10n, Iterable<String> items) =>
      items.isEmpty ? l10n.adminIngredientsNone : items.join(', ');

  static Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppDimensions.space4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
          child: Text(label, style: AppTextStyles.labelMedium),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}
