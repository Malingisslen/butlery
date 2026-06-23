/// BUT-1241: grid + tray-card widgets for the manual placement mode.
///
/// Deliberately separate from `calendar_cells.dart` — those cells carry
/// drag-drop machinery and the live-plan ViewModel; placement cells are a
/// simpler tap-to-place state machine (eligible / occupied / dimmed) over
/// the in-memory working plan.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/menu_placement_viewmodel.dart';
import 'package:butlery/widgets/menu/menu_new_badge.dart';

const double _kCellMinHeight = 56;
const double _kDayColumnWidth = 44;

/// 7×3 week grid rendering the working plan with placement affordances.
class PlacementGrid extends StatelessWidget {
  final MenuPlacementViewModel vm;

  const PlacementGrid({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: _kDayColumnWidth),
            for (final slot in MealSlot.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    slot.displayLabel.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (final day in DayOfWeek.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: _kDayColumnWidth,
                    child: Center(
                      child: Text(
                        day.displayLabel,
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  for (final slot in MealSlot.values) ...[
                    Expanded(
                      child: _PlacementCell(vm: vm, day: day, slot: slot),
                    ),
                    if (slot != MealSlot.ovrigt) const SizedBox(width: 4),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PlacementCell extends StatelessWidget {
  final MenuPlacementViewModel vm;
  final DayOfWeek day;
  final MealSlot slot;

  const _PlacementCell({
    required this.vm,
    required this.day,
    required this.slot,
  });

  @override
  Widget build(BuildContext context) {
    final plan = vm.plan;
    if (plan == null) return const SizedBox.shrink();
    final entries = plan.entriesAt(day, slot);
    final eligible = vm.isEligible(day, slot);
    final hasSelection = vm.selectedItem != null;

    if (slot.isMulti) {
      return _buildOvrigt(context, entries, eligible, hasSelection);
    }
    if (entries.isNotEmpty) {
      return _OccupiedCell(vm: vm, entry: entries.first, dimmed: hasSelection);
    }
    if (eligible) {
      return _EligibleCell(vm: vm, day: day, slot: slot);
    }
    return _NeutralEmptyCell(dimmed: hasSelection);
  }

  Widget _buildOvrigt(
    BuildContext context,
    List<WeeklyMenuPlanEntry> entries,
    bool eligible,
    bool hasSelection,
  ) {
    final dimOthers = hasSelection && !eligible;
    return Opacity(
      opacity: dimOthers ? 0.35 : 1,
      child: Container(
        constraints: const BoxConstraints(minHeight: _kCellMinHeight),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in entries) ...[
              _OvrigtEntryChip(vm: vm, entry: entry),
              const SizedBox(height: 3),
            ],
            if (eligible)
              Expanded(
                child: _EligibleCell(vm: vm, day: day, slot: slot),
              ),
          ],
        ),
      ),
    );
  }
}

/// Highlighted target for the selected tray item.
class _EligibleCell extends StatelessWidget {
  final MenuPlacementViewModel vm;
  final DayOfWeek day;
  final MealSlot slot;

  const _EligibleCell({
    required this.vm,
    required this.day,
    required this.slot,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.a11yPlacementCell(
        day.displayLabel,
        slot.displayLabel,
      ),
      button: true,
      child: InkWell(
        onTap: () => vm.placeSelectedAt(day),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: _kCellMinHeight - 8,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.5),
            border: Border.all(color: cs.primary, width: 2),
          ),
          child: Text(
            context.l10n.menuPlacementPlaceHere,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// Occupied lunch/middag cell. Session placements get the NY badge and tap
/// to un-place; pre-existing entries are inert here.
class _OccupiedCell extends StatelessWidget {
  final MenuPlacementViewModel vm;
  final WeeklyMenuPlanEntry entry;
  final bool dimmed;

  const _OccupiedCell({
    required this.vm,
    required this.entry,
    required this.dimmed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSession = vm.isSessionEntry(entry.id);
    final cell = Container(
      constraints: const BoxConstraints(minHeight: _kCellMinHeight),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        border: Border.all(
          color: isSession ? cs.primary : cs.outlineVariant,
          width: isSession ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSession)
            const Align(
              alignment: Alignment.topRight,
              child: MenuNewBadge(),
            ),
          Expanded(
            child: Text(
              entry.recipeTitle.toLowerCase(),
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    if (!isSession) {
      return Opacity(opacity: dimmed ? 0.35 : 1, child: cell);
    }
    return Semantics(
      label: context.l10n.a11yPlacementRemoveEntry(entry.recipeTitle),
      button: true,
      child: InkWell(
        onTap: () => vm.unplaceEntry(entry.id),
        child: cell,
      ),
    );
  }
}

/// Stacked entry chip inside the övrigt column.
class _OvrigtEntryChip extends StatelessWidget {
  final MenuPlacementViewModel vm;
  final WeeklyMenuPlanEntry entry;

  const _OvrigtEntryChip({required this.vm, required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSession = vm.isSessionEntry(entry.id);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          left: BorderSide(
            color: isSession ? cs.primary : cs.secondary,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              entry.recipeTitle.toLowerCase(),
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isSession) const MenuNewBadge(),
        ],
      ),
    );
    if (!isSession) return chip;
    return Semantics(
      label: context.l10n.a11yPlacementRemoveEntry(entry.recipeTitle),
      button: true,
      child: InkWell(
        onTap: () => vm.unplaceEntry(entry.id),
        child: chip,
      ),
    );
  }
}

class _NeutralEmptyCell extends StatelessWidget {
  final bool dimmed;

  const _NeutralEmptyCell({required this.dimmed});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.35 : 1,
      child: Container(
        constraints: const BoxConstraints(minHeight: _kCellMinHeight),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
      ),
    );
  }
}

/// One recipe card in the bottom tray. Tap to select (unplaced) or
/// un-place (placed).
class PlacementTrayCard extends StatelessWidget {
  final MenuPlacementViewModel vm;
  final int index;

  const PlacementTrayCard({super.key, required this.vm, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = vm.items[index];
    final isSelected = vm.selectedIndex == index;
    return Semantics(
      label: context.l10n.a11yPlacementTrayCard(item.recipe.title),
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: () => vm.tapItem(index),
        child: Opacity(
          opacity: item.isPlaced ? 0.45 : 1,
          child: Container(
            width: 132,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? cs.primaryContainer.withValues(alpha: 0.6)
                  : cs.surface,
              border: Border.all(
                color: isSelected ? cs.primary : cs.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.slot.displayLabel.toUpperCase(),
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 8,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: cs.secondary,
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Text(
                    item.recipe.title,
                    style: AppTextStyles.labelSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: item.isPlaced
                          ? TextDecoration.lineThrough
                          : null,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
