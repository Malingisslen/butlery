/// BUT-1241: manual placement mode ("placera i veckan").
///
/// Full-screen flow opened from the lista-result footer ("Jag placerar
/// själv") or the post-auto-placement ÄNDRA snackbar action. The user taps
/// a recipe in the bottom tray, then taps an eligible day cell to place it.
/// Everything is in-memory until "Klar" persists one batched save; popping
/// the view discards the session.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/menu_placement_viewmodel.dart';
import 'package:butlery/views/menu_placement/placement_widgets.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';
import 'package:butlery/widgets/common/state_widget.dart';

class MenuPlacementView extends StatefulWidget {
  /// Generated menu (`Map<mealType, List<Recipe>>`) to place.
  final Map<String, List<Recipe>> generated;

  /// ISO week the session starts on.
  final DateTime weekStart;

  /// Constraint trace from generation — threads day pins into auto-rest.
  final ParsedMenuRequest? parsedRequest;

  /// ÄNDRA path: the saved plan already contains the auto layout being
  /// redone, so the working week starts empty (week navigation disabled).
  final bool startFromEmptyWeek;

  const MenuPlacementView({
    super.key,
    required this.generated,
    required this.weekStart,
    this.parsedRequest,
    this.startFromEmptyWeek = false,
  });

  @override
  State<MenuPlacementView> createState() => _MenuPlacementViewState();
}

class _MenuPlacementViewState extends State<MenuPlacementView> {
  late final MenuPlacementViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = MenuPlacementViewModel(
      service: ServiceLocator.get<WeeklyMenuPlanService>(),
      generated: widget.generated,
      weekStart: widget.weekStart,
      parsedRequest: widget.parsedRequest,
      startFromEmptyWeek: widget.startFromEmptyWeek,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _vm.init();
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MenuPlacementViewModel>.value(
      value: _vm,
      child: const _MenuPlacementViewContent(),
    );
  }
}

class _MenuPlacementViewContent extends StatelessWidget {
  const _MenuPlacementViewContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MenuPlacementViewModel>();
    final cs = Theme.of(context).colorScheme;
    return BaseScaffold(
      title: context.l10n.menuPlacementTitle,
      actions: [
        Center(
          child: Container(
            margin:
                const EdgeInsetsDirectional.only(end: AppDimensions.spacingMd),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: cs.onPrimary.withValues(alpha: 0.4)),
            ),
            child: Text(
              context.l10n.menuPlacementProgress(vm.placedCount, vm.totalCount),
              style: AppTextStyles.labelSmall.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
      body: vm.plan == null
          ? (vm.hasError
              ? StateWidget.error(
                  message: vm.error ?? context.l10n.errorUnexpected,
                  onAction: vm.init,
                )
              : StateWidget.loading())
          : _buildBody(context, vm),
    );
  }

  Widget _buildBody(BuildContext context, MenuPlacementViewModel vm) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: LayoutComponents.valueFor(
            context: context,
            mobile: double.infinity,
            tablet: 900,
            desktop: 1200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WeekNavRow(vm: vm),
            _HintBanner(vm: vm),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingMd,
                  vertical: AppDimensions.spacingSm,
                ),
                child: PlacementGrid(vm: vm),
              ),
            ),
            PlacementTray(
              vm: vm,
              onAutoRest: () => _onAutoRest(context, vm),
              onConfirm: () => _onConfirm(context, vm),
            ),
          ],
        ),
      ),
    );
  }

  void _onAutoRest(BuildContext context, MenuPlacementViewModel vm) {
    final overflow = vm.placeRemainingAutomatically();
    if (overflow > 0 && context.mounted) {
      SnackBarUtils.showWarning(
        context,
        context.l10n.menuPlacementOverflow(overflow),
      );
    }
  }

  Future<void> _onConfirm(
    BuildContext context,
    MenuPlacementViewModel vm,
  ) async {
    // The button is disabled at zero placements; this guard keeps the
    // "null = save failed" mapping below honest if that ever changes.
    if (!vm.hasPlacements) return;
    final result = await vm.confirm();
    if (!context.mounted) return;
    if (result == null) {
      SnackBarUtils.showError(
        context,
        vm.error ?? context.l10n.errorUnexpected,
      );
      return;
    }
    Navigator.of(context).pop(result);
  }
}

class _WeekNavRow extends StatelessWidget {
  final MenuPlacementViewModel vm;

  const _WeekNavRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ÄNDRA-redo sessions pin the week the auto layout landed on —
          // navigating would duplicate the menu across two weeks.
          if (vm.canNavigateWeeks)
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: context.l10n.slotPickerPreviousWeek,
              onPressed: vm.isLoading ? null : vm.previousWeek,
            ),
          Text(
            _formatWeekLabel(context, vm.weekStart),
            style: AppTextStyles.titleSmall,
          ),
          if (vm.canNavigateWeeks)
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: context.l10n.slotPickerNextWeek,
              onPressed: vm.isLoading ? null : vm.nextWeek,
            ),
        ],
      ),
    );
  }

  String _formatWeekLabel(BuildContext context, DateTime weekStart) {
    return context.l10n
        .slotPickerWeekLabel(IsoWeekUtils.isoWeekNumber(weekStart));
  }
}

class _HintBanner extends StatelessWidget {
  final MenuPlacementViewModel vm;

  const _HintBanner({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = vm.selectedItem;
    final text = selected == null
        ? context.l10n.menuPlacementHintSelect
        : context.l10n.menuPlacementHint(selected.recipe.title);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        border: Border(left: BorderSide(color: cs.primary, width: 3)),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

/// Tray with the placeable recipe cards plus the auto-rest / confirm
/// actions. Split from the grid file to keep both under the size limit.
class PlacementTray extends StatelessWidget {
  final MenuPlacementViewModel vm;
  final VoidCallback onAutoRest;
  final VoidCallback onConfirm;

  const PlacementTray({
    super.key,
    required this.vm,
    required this.onAutoRest,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final remaining = vm.totalCount - vm.placedCount;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border(top: BorderSide(color: cs.primary, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.spacingMd,
          AppDimensions.spacingSm,
          AppDimensions.spacingMd,
          AppDimensions.spacingMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.menuPlacementTrayLabel(remaining).toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(
                letterSpacing: 1,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: vm.items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppDimensions.spacingSm),
                itemBuilder: (context, index) =>
                    PlacementTrayCard(vm: vm, index: index),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ActionButtons.outlinedButton(
                    context,
                    label: context.l10n.menuPlacementAutoRest,
                    icon: Icons.shuffle,
                    onPressed: vm.allPlaced || vm.isLoading ? null : onAutoRest,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  flex: 2,
                  child: ActionButtons.primaryButton(
                    context,
                    label: context.l10n.commonDone,
                    onPressed:
                        !vm.hasPlacements || vm.isLoading ? null : onConfirm,
                    isLoading: vm.isLoading,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
