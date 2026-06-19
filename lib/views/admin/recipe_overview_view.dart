import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/admin/recipe_stats.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/recipe_overview_viewmodel.dart';
import 'package:butlery/views/admin/widgets/admin_stat_card.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Admin-only recipe-overview tab: total recipe count + breakdown by import
/// method (URL / photo / text / social / manual). Pre-launch most recipes lack
/// the source-artefact field and count as "manual".
class RecipeOverviewView extends StatefulWidget {
  const RecipeOverviewView({super.key});

  @override
  State<RecipeOverviewView> createState() => _RecipeOverviewViewState();
}

class _RecipeOverviewViewState extends State<RecipeOverviewView> {
  late final RecipeOverviewViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = RecipeOverviewViewModel();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RecipeOverviewViewModel>.value(
      value: _vm,
      child: const _RecipeOverviewContent(),
    );
  }
}

class _RecipeOverviewContent extends StatelessWidget {
  const _RecipeOverviewContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecipeOverviewViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.adminRecipesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.adminRefresh,
            onPressed: vm.isLoading ? null : vm.refresh,
          ),
        ],
      ),
      body: _body(context, vm),
    );
  }

  Widget _body(BuildContext context, RecipeOverviewViewModel vm) {
    final l10n = context.l10n;
    if (vm.isLoading && vm.total == 0) {
      return StateWidget.loading();
    }
    if (vm.error != null && vm.total == 0) {
      return StateWidget.error(message: vm.error!, onAction: vm.refresh);
    }
    if (vm.total == 0) {
      return StateWidget.empty(
        title: l10n.adminRecipesEmpty,
        icon: Icons.restaurant_menu,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Wrap(
            spacing: AppDimensions.spacingSm,
            runSpacing: AppDimensions.spacingSm,
            children: [
              AdminStatCard(
                label: l10n.adminRecipesTotal,
                value: '${vm.total}',
              ),
              AdminStatCard(
                label: l10n.adminRecipesImported,
                value: '${vm.imported}',
              ),
              AdminStatCard(
                label: l10n.adminRecipesManual,
                value: '${vm.manual}',
              ),
            ],
          ),
        ),
        const _HeaderRow(),
        Expanded(
          child: ListView.separated(
            itemCount: RecipeOverviewViewModel.methodOrder.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final method = RecipeOverviewViewModel.methodOrder[i];
              return _MethodRow(method: method, count: vm.countOf(method));
            },
          ),
        ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(l10n.adminRecipesColMethod, style: _h),
          ),
          Expanded(
            flex: 2,
            child: Text(l10n.adminRecipesColCount,
                style: _h, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  static final TextStyle _h = AppTextStyles.metadataEmphasized;
}

class _MethodRow extends StatelessWidget {
  final RecipeImportMethod method;
  final int count;
  const _MethodRow({required this.method, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              _methodLabel(context, method),
              style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('$count',
                style: AppTextStyles.bodyMedium, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  String _methodLabel(BuildContext context, RecipeImportMethod method) {
    final l10n = context.l10n;
    switch (method) {
      case RecipeImportMethod.url:
        return l10n.adminRecipesMethodUrl;
      case RecipeImportMethod.photo:
        return l10n.adminRecipesMethodPhoto;
      case RecipeImportMethod.textPaste:
        return l10n.adminRecipesMethodText;
      case RecipeImportMethod.social:
        return l10n.adminRecipesMethodSocial;
      case RecipeImportMethod.manual:
        return l10n.adminRecipesMethodManual;
    }
  }
}
