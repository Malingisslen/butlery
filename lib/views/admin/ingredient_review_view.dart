import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/ingredient_review_viewmodel.dart';
import 'package:butlery/views/admin/ingredient_copy.dart';
import 'package:butlery/views/admin/ingredient_detail_dialog.dart';
import 'package:butlery/views/admin/ingredient_labels.dart';
import 'package:butlery/views/admin/ingredient_review_filters.dart';
import 'package:butlery/views/admin/widgets/admin_tab_header.dart';
import 'package:butlery/widgets/common/buttons/app_icon_button.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/status_pill.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Admin-only "Ingredienser" tab: a read-only review of the ingredient
/// database and what the tagger derives from each row.
class IngredientReviewView extends StatefulWidget {
  const IngredientReviewView({super.key, this.viewModel});

  /// Injected by tests; the tab builds its own otherwise.
  final IngredientReviewViewModel? viewModel;

  @override
  State<IngredientReviewView> createState() => _IngredientReviewViewState();
}

class _IngredientReviewViewState extends State<IngredientReviewView> {
  late final IngredientReviewViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = widget.viewModel ?? IngredientReviewViewModel();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<IngredientReviewViewModel>.value(
      value: _vm,
      child: const _Content(),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<IngredientReviewViewModel>();
    final l10n = context.l10n;
    return AdminTabPage(
      title: l10n.adminIngredientsTitle,
      actions: [
        AppIconButton(
          icon: ButleryIcons.refreshCw,
          semanticLabel: l10n.adminRefresh,
          onPressed: vm.isLoading ? null : vm.load,
        ),
      ],
      body: _body(context, vm),
    );
  }

  Widget _body(BuildContext context, IngredientReviewViewModel vm) {
    final l10n = context.l10n;
    if (vm.isLoading && vm.totalCount == 0) {
      return StateWidget.loading(message: l10n.adminIngredientsLoading);
    }
    if (vm.error != null || vm.totalCount == 0) {
      return StateWidget.error(
        message: vm.error ?? l10n.adminIngredientsLoadFailed,
        actionLabel: l10n.adminRefresh,
        onAction: vm.load,
      );
    }
    final list = vm.ingredients;
    return Column(
      children: [
        Flexible(
          flex: 0,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SyncedLine(vm: vm),
                const SizedBox(height: AppDimensions.space8),
                IngredientCounters(vm: vm),
                const SizedBox(height: AppDimensions.space16),
                IngredientFilterBar(vm: vm),
                if (!vm.hasTagConfig)
                  Padding(
                    padding: const EdgeInsets.only(top: AppDimensions.space8),
                    child: Text(
                      l10n.adminIngredientsNoTagConfig,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: AppDimensions.space8),
                Text(l10n.adminIngredientsShownOf(list.length, vm.totalCount)),
              ],
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? StateWidget.empty(title: l10n.adminIngredientsNoMatches)
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) => IngredientRow(
                    key: ValueKey(list[i].id),
                    ingredient: list[i],
                    vm: vm,
                  ),
                ),
        ),
      ],
    );
  }
}

class _SyncedLine extends StatelessWidget {
  const _SyncedLine({required this.vm});

  final IngredientReviewViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = vm.lastSynced?.toLocal();
    final text = d == null
        ? l10n.adminIngredientsLastSyncedUnknown
        : l10n.adminIngredientsLastSynced(
            '${d.year}-${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}',
          );
    return Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class IngredientRow extends StatelessWidget {
  const IngredientRow({super.key, required this.ingredient, required this.vm});

  final IngredientData ingredient;
  final IngredientReviewViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final allergens = vm.previewOf(ingredient)?.allergenKeys;
    return InkWell(
      onTap: () => showIngredientDetail(context, vm, ingredient),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space8,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ingredient.swedish, style: AppTextStyles.titleSmall),
                  Text(
                    '${ingredient.id} · ${ingredient.group}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  if (allergens != null && allergens.isNotEmpty)
                    Text(
                      '${l10n.adminIngredientsAllergens}: '
                      '${allergens.join(', ')}',
                      style: AppTextStyles.bodySmall,
                    ),
                ],
              ),
            ),
            StatusPill(
              label: ingredientStatusLabel(l10n, ingredient.status),
            ),
            AppIconButton(
              icon: ButleryIcons.copy,
              semanticLabel: l10n.adminCopyForClaude,
              onPressed: () => copyIngredientForClaude(context, vm, ingredient),
            ),
          ],
        ),
      ),
    );
  }
}
