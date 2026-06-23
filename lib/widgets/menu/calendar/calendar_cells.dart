/// Day-row cell widgets for the weekly-menu calendar view.
///
/// Extracted from `calendar_weekly_menu_widget.dart` (BUT-542). Provides:
/// - [DayCell] — one day's lunch / middag / övrigt row, plus its private
///   slot-cell sub-widgets.
///
/// All widgets stateless; navigation + slot-tap callbacks injected so the
/// orchestrator stays the only thing that knows about Provider/routing.
/// Week-nav header + overflow tray live in `calendar_header.dart`.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/widgets/menu/calendar/calendar_drag.dart';
import 'package:butlery/widgets/menu/menu_new_badge.dart';

const double _kSlotMinHeight = 80;

/// Brand-specific muted decorative icon color for assigned-slot icons.
/// Mapping to `onSurfaceVariant` would shift hue from green to neutral
/// grey. BUT-572 follow-up: candidate for `ButleryColors.iconMuted`.
const Color _kSlotIconColor = AppColors.greenMuted;

/// Shared border pattern for assigned lunch/middag/övrigt cells.
Border _accentedBorder(BuildContext context, Color left) {
  final outline = Theme.of(context).colorScheme.outlineVariant;
  return Border(
    left: BorderSide(color: left, width: 3),
    top: BorderSide(color: outline),
    right: BorderSide(color: outline),
    bottom: const BorderSide(color: AppColors.rustLight, width: 2),
  );
}

/// Small-caps slot label used at the top of every cell.
Text _slotLabel(String text, Color color) => Text(
  text.toUpperCase(),
  style: AppTextStyles.labelSmall.copyWith(
    fontSize: 8,
    letterSpacing: 1,
    color: color,
  ),
);

/// Callback fired when an empty slot is tapped — orchestrator owns the
/// recipe-picker dialog flow.
typedef SlotTapCallback = void Function(DayOfWeek day, MealSlot slot);

/// Callback fired when an assigned recipe cell is tapped — orchestrator
/// owns navigation routing.
typedef RecipeNavCallback = void Function(String recipeId);

class DayCell extends StatelessWidget {
  final WeeklyMenuPlanViewModel vm;
  final WeeklyMenuPlan plan;
  final DayOfWeek day;
  final bool isToday;
  final SlotTapCallback onTapEmptySlot;
  final RecipeNavCallback onTapRecipe;

  const DayCell({
    super.key,
    required this.vm,
    required this.plan,
    required this.day,
    required this.isToday,
    required this.onTapEmptySlot,
    required this.onTapRecipe,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppDimensions.spacingSm,
        start: AppDimensions.spacingMd,
        end: AppDimensions.spacingMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DayHeader(day: day, isToday: isToday),
          const SizedBox(height: AppDimensions.spacingXs),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SingleSlotCell(
                    vm: vm,
                    plan: plan,
                    day: day,
                    slot: MealSlot.lunch,
                    onTapEmptySlot: onTapEmptySlot,
                    onTapRecipe: onTapRecipe,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _SingleSlotCell(
                    vm: vm,
                    plan: plan,
                    day: day,
                    slot: MealSlot.middag,
                    onTapEmptySlot: onTapEmptySlot,
                    onTapRecipe: onTapRecipe,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 1,
                  child: _OvrigtCell(
                    vm: vm,
                    plan: plan,
                    day: day,
                    onTapEmptySlot: onTapEmptySlot,
                    onTapRecipe: onTapRecipe,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DayOfWeek day;
  final bool isToday;

  const _DayHeader({required this.day, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isToday ? cs.primary : cs.secondary,
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsetsDirectional.only(start: AppDimensions.spacingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            day.displayLabel.toUpperCase(),
            style: AppTextStyles.labelMedium.copyWith(
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: isToday ? cs.onPrimaryContainer : cs.onSurface,
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: AppDimensions.spacingSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: cs.primary.withValues(alpha: 0.12),
              child: Text(
                context.l10n.weeklyMenuTodayBadge,
                style: AppTextStyles.labelSmall.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SingleSlotCell extends StatelessWidget {
  final WeeklyMenuPlanViewModel vm;
  final WeeklyMenuPlan plan;
  final DayOfWeek day;
  final MealSlot slot;
  final SlotTapCallback onTapEmptySlot;
  final RecipeNavCallback onTapRecipe;

  const _SingleSlotCell({
    required this.vm,
    required this.plan,
    required this.day,
    required this.slot,
    required this.onTapEmptySlot,
    required this.onTapRecipe,
  });

  @override
  Widget build(BuildContext context) {
    final entry = plan.entryAt(day, slot);
    final inner = entry == null
        ? _EmptySlot(day: day, slot: slot, onTap: onTapEmptySlot)
        : _AssignedSlot(
            entry: entry,
            onTap: onTapRecipe,
            // BUT-1241: "NY" badge on entries from the latest generation.
            showNewBadge: vm.isRecentlyPlaced(entry.id),
            // BUT-1043: in multi-select mode, tap toggles selection.
            selectionMode: vm.selectionMode,
            isSelected: vm.isSelected(entry.id),
            onToggleSelection: vm.toggleSelection,
          );
    return wrapAsDropTarget(
      context: context,
      vm: vm,
      day: day,
      slot: slot,
      child: inner,
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final DayOfWeek day;
  final MealSlot slot;
  final SlotTapCallback onTap;

  const _EmptySlot({
    required this.day,
    required this.slot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // BUT-403: enum `name` (not displayLabel) keeps the identifier stable
    // across locale changes.
    final identifier = 'menu-slot-${day.name}-${slot.name}';
    return Semantics(
      identifier: identifier,
      button: true,
      label: slot.displayLabel,
      child: GestureDetector(
        key: ValueKey('test-$identifier'),
        onTap: () => onTap(day, slot),
        child: Container(
          constraints: const BoxConstraints(minHeight: _kSlotMinHeight),
          padding: const EdgeInsets.all(AppDimensions.spacing6),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: _slotLabel(
                  slot.displayLabel,
                  Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Center(
                child: Text(
                  '+',
                  style: TextStyle(
                    fontSize: 24,
                    color: AppColors.creamDarker,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignedSlot extends StatelessWidget {
  final WeeklyMenuPlanEntry entry;
  final RecipeNavCallback onTap;
  final bool showNewBadge;

  // BUT-1043: multi-select state. When [selectionMode] is on, tap toggles
  // selection instead of navigating, a checkbox overlay appears, and the
  // cell is no longer draggable (selection and drag must not collide).
  final bool selectionMode;
  final bool isSelected;
  final ValueChanged<String> onToggleSelection;

  const _AssignedSlot({
    required this.entry,
    required this.onTap,
    required this.onToggleSelection,
    this.showNewBadge = false,
    this.selectionMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = isSelected ? cs.secondary : cs.primary;
    final cell = Semantics(
      label: selectionMode
          ? context.l10n.a11yWeeklyMenuSelectEntry(entry.recipeTitle)
          : context.l10n.a11yMenuPlanRecipeOpen(entry.recipeTitle),
      button: true,
      selected: selectionMode ? isSelected : null,
      child: GestureDetector(
        onTap: () =>
            selectionMode ? onToggleSelection(entry.id) : onTap(entry.recipeId),
        child: Container(
          constraints: const BoxConstraints(minHeight: _kSlotMinHeight),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.secondaryContainer.withValues(alpha: 0.4)
                : Theme.of(context).cardColor,
            border: _accentedBorder(context, accent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (selectionMode)
                    Icon(
                      isSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 14,
                      color: cs.secondary,
                    ),
                  Expanded(
                    child: _slotLabel(
                      entry.slot.displayLabel,
                      cs.onPrimaryContainer,
                    ),
                  ),
                  if (showNewBadge) const MenuNewBadge(),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                height: 28,
                color: cs.surface,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.restaurant_outlined,
                  size: 18,
                  color: _kSlotIconColor,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  entry.recipeTitle.toLowerCase(),
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Drag is suppressed in selection mode so the two long-press/tap gestures
    // don't fight over the same cell.
    if (selectionMode) return cell;
    return wrapAsDraggable(
      context: context,
      payload: MovePayload(entry),
      child: cell,
    );
  }
}

class _OvrigtCell extends StatelessWidget {
  final WeeklyMenuPlanViewModel vm;
  final WeeklyMenuPlan plan;
  final DayOfWeek day;
  final SlotTapCallback onTapEmptySlot;
  final RecipeNavCallback onTapRecipe;

  const _OvrigtCell({
    required this.vm,
    required this.plan,
    required this.day,
    required this.onTapEmptySlot,
    required this.onTapRecipe,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = plan.entriesAt(day, MealSlot.ovrigt);
    final inner = entries.isEmpty
        ? _EmptySlot(
            day: day,
            slot: MealSlot.ovrigt,
            onTap: onTapEmptySlot,
          )
        : Container(
            constraints: const BoxConstraints(minHeight: _kSlotMinHeight),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              border: _accentedBorder(context, cs.secondary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _slotLabel(MealSlot.ovrigt.displayLabel, cs.secondary),
                const SizedBox(height: 2),
                for (final entry in entries) ...[
                  _OvrigtEntry(
                    entry: entry,
                    onTap: onTapRecipe,
                    showNewBadge: vm.isRecentlyPlaced(entry.id),
                    selectionMode: vm.selectionMode,
                    isSelected: vm.isSelected(entry.id),
                    onToggleSelection: vm.toggleSelection,
                  ),
                  const SizedBox(height: 3),
                ],
                Semantics(
                  label: context.l10n.a11yMenuPlanOvrigtAddMore(
                    day.displayLabel,
                  ),
                  button: true,
                  child: GestureDetector(
                    onTap: () => onTapEmptySlot(day, MealSlot.ovrigt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Text(
                        context.l10n.weeklyMenuOvrigtAddMore,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 9,
                          color: cs.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
    return wrapAsDropTarget(
      context: context,
      vm: vm,
      day: day,
      slot: MealSlot.ovrigt,
      child: inner,
    );
  }
}

class _OvrigtEntry extends StatelessWidget {
  final WeeklyMenuPlanEntry entry;
  final RecipeNavCallback onTap;
  final bool showNewBadge;

  // BUT-1043: see _AssignedSlot — in selection mode tap toggles selection
  // and the chip shows a checkbox; drag is suppressed.
  final bool selectionMode;
  final bool isSelected;
  final ValueChanged<String> onToggleSelection;

  const _OvrigtEntry({
    required this.entry,
    required this.onTap,
    required this.onToggleSelection,
    this.showNewBadge = false,
    this.selectionMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chip = Semantics(
      label: selectionMode
          ? context.l10n.a11yWeeklyMenuSelectEntry(entry.recipeTitle)
          : context.l10n.a11yMenuPlanRecipeOpen(entry.recipeTitle),
      button: true,
      selected: selectionMode ? isSelected : null,
      child: GestureDetector(
        onTap: () =>
            selectionMode ? onToggleSelection(entry.id) : onTap(entry.recipeId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.secondaryContainer.withValues(alpha: 0.4)
                : cs.surface,
            border: Border(
              left: BorderSide(color: cs.secondary, width: 2),
            ),
          ),
          child: Row(
            children: [
              if (selectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Icon(
                    isSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 12,
                    color: cs.secondary,
                  ),
                )
              else ...[
                Container(
                  width: 16,
                  height: 16,
                  color: cs.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.cake_outlined,
                    size: 11,
                    color: _kSlotIconColor,
                  ),
                ),
                const SizedBox(width: 3),
              ],
              Expanded(
                child: Text(
                  entry.recipeTitle.toLowerCase(),
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showNewBadge) const MenuNewBadge(),
            ],
          ),
        ),
      ),
    );
    if (selectionMode) return chip;
    return wrapAsDraggable(
      context: context,
      payload: MovePayload(entry),
      child: chip,
    );
  }
}
