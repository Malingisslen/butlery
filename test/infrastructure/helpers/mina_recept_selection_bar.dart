// A bar around the shared selection builders, so tests can drive their
// buttons and kebab. No screen draws this bar; Hem draws the same builders in
// its library header row.

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/views/mina_recept/selection_app_bar.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';

PreferredSizeWidget buildMinaReceptSelectionAppBar(
  BuildContext context,
  RecipeListViewModel viewModel, {
  String? secondaryLine,
}) {
  return ButleryTopBar.rot(
    title: context.l10n.bulkSelectedCount(viewModel.selectedCount),
    titleStyle: const TextStyle(
      fontFeatures: [FontFeature.tabularFigures()],
    ),
    secondaryLine: secondaryLine,
    secondaryLineIsLive: false,
    leading: buildMinaReceptSelectionCancel(context, viewModel),
    actions: buildMinaReceptSelectionActions(context, viewModel),
  );
}
