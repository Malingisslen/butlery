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
import 'package:butlery/viewmodels/menu/meal_allergen_scope.dart';
import 'package:butlery/viewmodels/menu/menu_placement_viewmodel.dart';
import 'package:butlery/views/menu_placement/placement_widgets.dart';
import 'package:butlery/widgets/common/bold_names_text.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/menu/calendar/week_range_label.dart';

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
      allergenScope: MealAllergenScope.resolveFromLocator,
      allergenScopeOn: MealAllergenScope.isOnFromLocator,
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        if (vm.hasPlacements) {
          final shouldPop = await _showDiscardDialog(context) ?? false;
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        } else {
          Navigator.of(context).pop();
        }
      },
      // A subpage of the week menu (Komponentark v1:71-78; Skarmar v12 del 2
      // #placera draws the back arrow, the title and the "2 av 5 rätter
      // placerade" pill).
      child: ButleryPage.undersida(
        title: context.l10n.menuPlacementTitle,
        backTo: context.l10n.menuWeek,
        showTabBar: false,
        width: PageWidth.wide,
        actions: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space8,
                vertical: AppDimensions.space4,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: cs.onSurface),
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              ),
              child: Text(
                context.l10n.menuPlacementProgress(
                  vm.placedCount,
                  vm.totalCount,
                ),
                style: AppTextStyles.labelSmall.copyWith(
                  color: cs.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
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
                  : StateWidget.loading(
                      message: context.l10n.loadingWeeklyMenu,
                    ))
            : _buildBody(context, vm),
      ),
    );
  }

  /// Confirms before discarding an in-progress placement session — the view
  /// holds placements in memory until "Klar", so popping otherwise loses them
  /// silently (BUT-954 hard-destructive: unsaved user work, no undo path).
  Future<bool?> _showDiscardDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.recipeUnsavedChangesTitle),
        content: Text(context.l10n.confirmUnsavedChanges),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.recipeContinueEditing,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.recipeLeaveWithoutSaving,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, MenuPlacementViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeekNavRow(vm: vm),
        _HintBanner(vm: vm),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical: AppDimensions.space8,
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
      SnackBarUtils.showFailure(
        context,
        what: vm.error ?? context.l10n.errorUnexpected,
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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space8),
      child: Row(
        children: [
          // ÄNDRA-redo sessions pin the week the auto layout landed on —
          // navigating would duplicate the menu across two weeks.
          if (vm.canNavigateWeeks)
            IconButton(
              icon: const ButleryIcon(ButleryIcons.chevronLeft),
              tooltip: context.l10n.slotPickerPreviousWeek,
              onPressed: vm.isLoading ? null : vm.previousWeek,
            )
          else
            const SizedBox(width: AppDimensions.space8),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: context.l10n.weeklyMenuWeekTitle(
                      IsoWeekUtils.isoWeekNumber(vm.weekStart),
                    ),
                    style: AppTextStyles.titleBold.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                  TextSpan(
                    text: '  ${formatWeekRange(context, vm.weekStart)}',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (vm.canNavigateWeeks)
            IconButton(
              icon: const ButleryIcon(ButleryIcons.chevronRight),
              tooltip: context.l10n.slotPickerNextWeek,
              onPressed: vm.isLoading ? null : vm.nextWeek,
            ),
        ],
      ),
    );
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
    final style = AppTextStyles.bodySmall.copyWith(
      color: cs.onSecondaryContainer,
    );
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space8,
      ),
      padding: const EdgeInsets.all(AppDimensions.space12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Text.rich(
        TextSpan(
          style: style,
          children: boldNameSpans(
            text,
            [
              ?selected?.recipe.title,
            ],
            AppTextStyles.bodySmallBold.copyWith(
              color: cs.onSecondaryContainer,
            ),
          ),
        ),
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
          // text.primary (onSurface): ink on light, paper on dark. cs.primary
          // is ink in both modes and would vanish on the dark surface.
          border: Border(top: BorderSide(color: cs.onSurface, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.space16,
          AppDimensions.space8,
          AppDimensions.space16,
          AppDimensions.space16,
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
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 112),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: AppDimensions.space8,
                  runSpacing: AppDimensions.space8,
                  children: [
                    for (var i = 0; i < vm.items.length; i++)
                      PlacementTrayCard(vm: vm, index: i),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ActionButtons.outlinedButton(
                    context,
                    label: context.l10n.menuPlacementAutoRest,
                    icon: ButleryIcons.shuffle,
                    onPressed: vm.allPlaced || vm.isLoading ? null : onAutoRest,
                  ),
                ),
                const SizedBox(width: AppDimensions.space8),
                Expanded(
                  flex: 2,
                  // "Klar" is the placement's one saffron action (Skarmar
                  // v12 del 2 #placera; Komponentark v1:843-844).
                  child: HeroButton(
                    key: const ValueKey('menu-placement-done'),
                    label: context.l10n.commonDone,
                    expand: true,
                    busy: vm.isLoading,
                    onPressed: vm.hasPlacements ? onConfirm : null,
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
