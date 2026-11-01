import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/tag_rules_viewmodel.dart';
import 'package:butlery/views/admin/widgets/admin_tab_header.dart';
import 'package:butlery/widgets/admin/admin_table.dart';
import 'package:butlery/widgets/common/buttons/app_icon_button.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Admin-only "Taggregler" tab: the allergen and diet rules, read-only.
class TagRulesView extends StatefulWidget {
  const TagRulesView({super.key, this.viewModel});

  final TagRulesViewModel? viewModel;

  @override
  State<TagRulesView> createState() => _TagRulesViewState();
}

class _TagRulesViewState extends State<TagRulesView> {
  late final TagRulesViewModel _vm = widget.viewModel ?? TagRulesViewModel();

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final allergens = _vm.allergens;
        final diets = _vm.diets;
        return AdminTabPage(
          title: l10n.adminTagRulesTitle,
          actions: [
            AppIconButton(
              icon: ButleryIcons.refreshCw,
              semanticLabel: l10n.adminRefresh,
              onPressed: _vm.refresh,
            ),
          ],
          body: allergens == null || diets == null
              ? StateWidget.error(message: l10n.adminTagRulesLoadFailed)
              : ListView(
                  padding: const EdgeInsets.all(AppDimensions.space16),
                  children: [
                    Text(
                      l10n.adminTagRulesAllergens,
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppDimensions.space8),
                    AdminTable(
                      columns: [
                        AdminTableColumn(
                          label: l10n.adminIngredientFieldSwedish,
                          flex: 3,
                        ),
                        AdminTableColumn(
                          label: l10n.adminTagRulesTriggers,
                          flex: 6,
                        ),
                        AdminTableColumn(
                          label: l10n.adminTagRulesEuAllergen,
                          flex: 2,
                        ),
                      ],
                      rows: [
                        for (final a in allergens)
                          AdminTableRow(
                            cells: [
                              a.key,
                              _join(
                                l10n.adminIngredientsNone,
                                a.triggerProperties,
                              ),
                              a.isEuAllergen
                                  ? l10n.adminIngredientYes
                                  : l10n.adminIngredientNo,
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.space24),
                    Text(
                      l10n.adminTagRulesDiets,
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppDimensions.space8),
                    AdminTable(
                      columns: [
                        AdminTableColumn(
                          label: l10n.adminIngredientFieldSwedish,
                          flex: 3,
                        ),
                        AdminTableColumn(
                          label: l10n.adminTagRulesExcluded,
                          flex: 5,
                        ),
                        AdminTableColumn(
                          label: l10n.adminTagRulesRequired,
                          flex: 3,
                        ),
                      ],
                      rows: [
                        for (final d in diets)
                          AdminTableRow(
                            cells: [
                              d.getTag('sv'),
                              _join(
                                l10n.adminIngredientsNone,
                                d.excludedProperties,
                              ),
                              _join(
                                l10n.adminIngredientsNone,
                                d.requiredProperties,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }

  static String _join(String none, List<String> items) =>
      items.isEmpty ? none : items.join(', ');
}
