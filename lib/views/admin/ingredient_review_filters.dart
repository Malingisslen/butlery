import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/admin/ingredient_review_viewmodel.dart';
import 'package:butlery/views/admin/ingredient_labels.dart';
import 'package:butlery/views/admin/widgets/admin_stat_card.dart';
import 'package:butlery/widgets/common/chips/butlery_action_chip.dart';
import 'package:butlery/widgets/common/chips/butlery_filter_chip.dart';
import 'package:butlery/widgets/common/input/styled_input.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';

/// Counters per status bucket, computed over all ingredients and unaffected by
/// the filters below.
class IngredientCounters extends StatelessWidget {
  const IngredientCounters({super.key, required this.vm});

  final IngredientReviewViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: AppDimensions.space8,
      runSpacing: AppDimensions.space8,
      children: [
        for (final bucket in IngredientStatusBucket.all)
          AdminStatCard(
            key: ValueKey('counter-$bucket'),
            label: ingredientStatusLabel(l10n, bucket),
            value: '${vm.statusCounts[bucket] ?? 0}',
          ),
      ],
    );
  }
}

class IngredientFilterBar extends StatefulWidget {
  const IngredientFilterBar({super.key, required this.vm});

  final IngredientReviewViewModel vm;

  @override
  State<IngredientFilterBar> createState() => _IngredientFilterBarState();
}

class _IngredientFilterBarState extends State<IngredientFilterBar> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = widget.vm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StyledInput.text(
          controller: _search,
          hint: l10n.adminIngredientsSearchHint,
          semanticLabel: l10n.adminIngredientsSearchHint,
          onChanged: vm.setQuery,
        ),
        const SizedBox(height: AppDimensions.space8),
        Wrap(
          spacing: AppDimensions.space8,
          runSpacing: AppDimensions.space8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ButleryChoiceChip(
              label: l10n.adminIngredientsFilterAll,
              selected: vm.statusFilter == null,
              onSelected: (_) => vm.setStatusFilter(null),
            ),
            for (final bucket in IngredientStatusBucket.all)
              ButleryChoiceChip(
                key: ValueKey('status-$bucket'),
                label: ingredientStatusLabel(l10n, bucket),
                selected: vm.statusFilter == bucket,
                onSelected: (_) => vm.setStatusFilter(bucket),
              ),
            ButleryFilterChip(
              key: const ValueKey('filter-missing-price'),
              label: l10n.adminIngredientsFilterMissingPrice,
              selected: vm.missingPriceOnly,
              onSelected: vm.setMissingPriceOnly,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space8),
        Wrap(
          spacing: AppDimensions.space16,
          runSpacing: AppDimensions.space8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Dropdown(
              key: const ValueKey('filter-group'),
              label: l10n.adminIngredientsFilterGroup,
              value: vm.groupFilter,
              allLabel: l10n.adminIngredientsFilterAll,
              options: [for (final g in vm.groups) (g, g)],
              onChanged: vm.setGroupFilter,
            ),
            if (vm.hasTagConfig)
              _Dropdown(
                key: const ValueKey('filter-allergen'),
                label: l10n.adminIngredientsFilterAllergen,
                value: vm.allergenFilter,
                allLabel: l10n.adminIngredientsFilterAll,
                options: [
                  (
                    IngredientReviewViewModel.noAllergenFilter,
                    l10n.adminIngredientsFilterNoAllergen,
                  ),
                  for (final key in vm.allergenKeys) (key, key),
                ],
                onChanged: vm.setAllergenFilter,
              ),
          ],
        ),
      ],
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    super.key,
    required this.label,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final String allLabel;
  final List<(String, String)> options;
  final ValueChanged<String?> onChanged;

  // ButleryDropdown has no null option, so "all" is an empty-string value.
  static const _all = '';

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: AppDimensions.space8),
        SizedBox(
          width: 200,
          child: ButleryDropdown<String>(
            dense: true,
            semanticLabel: label,
            value: value ?? _all,
            onChanged: (v) => onChanged(v == _all ? null : v),
            options: [
              ButleryDropdownOption<String>(value: _all, label: allLabel),
              for (final (v, text) in options)
                ButleryDropdownOption<String>(value: v, label: text),
            ],
          ),
        ),
      ],
    );
  }
}
