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
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/views/family/family_widgets.dart';
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
/// owns navigation routing. [presentServings] (BUT-1613) is the number of
/// members home for this meal when the lunch/middag slot has an explicit,
/// non-empty presence selection — carried through so cooking mode can open
/// pre-scaled to who's home. Null for övrigt, solo accounts, and unset/empty
/// presence (→ cooking mode falls back to its household default).
typedef RecipeNavCallback =
    void Function(String recipeId, {int? presentServings});

/// BUT-1611: fired when a lunch/middag cell's presence faces are tapped —
/// orchestrator owns the "vem är hemma?" sheet + persistence + notice flow.
typedef PresenceTapCallback = void Function(DayOfWeek day, MealSlot slot);

class DayCell extends StatelessWidget {
  final WeeklyMenuPlanViewModel vm;
  final WeeklyMenuPlan plan;
  final DayOfWeek day;
  final bool isToday;
  final SlotTapCallback onTapEmptySlot;
  final RecipeNavCallback onTapRecipe;

  /// BUT-1611: household roster for the present-diner faces. Empty for a solo
  /// account, which hides the presence row entirely.
  final List<HouseholdRosterMember> roster;
  final PresenceTapCallback onTapPresence;

  const DayCell({
    super.key,
    required this.vm,
    required this.plan,
    required this.day,
    required this.isToday,
    required this.onTapEmptySlot,
    required this.onTapRecipe,
    required this.roster,
    required this.onTapPresence,
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
                    roster: roster,
                    onTapPresence: onTapPresence,
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
                    roster: roster,
                    onTapPresence: onTapPresence,
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
  final List<HouseholdRosterMember> roster;
  final PresenceTapCallback onTapPresence;

  const _SingleSlotCell({
    required this.vm,
    required this.plan,
    required this.day,
    required this.slot,
    required this.onTapEmptySlot,
    required this.onTapRecipe,
    required this.roster,
    required this.onTapPresence,
  });

  @override
  Widget build(BuildContext context) {
    final entry = plan.entryAt(day, slot);
    final inner = entry == null
        ? _EmptySlot(day: day, slot: slot, onTap: onTapEmptySlot)
        : _AssignedSlot(
            entry: entry,
            onTap: onTapRecipe,
            // BUT-1613: the number present for this meal (roster-filtered so it
            // matches the portion count shown on the presence row), or null
            // when there's no explicit non-empty selection — carried into the
            // tap so cooking mode opens pre-scaled to who's home.
            presentServings: _presentServings(),
            // BUT-1241: "NY" badge on entries from the latest generation.
            showNewBadge: vm.isRecentlyPlaced(entry.id),
            // BUT-1043: in multi-select mode, tap toggles selection.
            selectionMode: vm.selectionMode,
            isSelected: vm.isSelected(entry.id),
            onToggleSelection: vm.toggleSelection,
          );
    final cell = wrapAsDropTarget(
      context: context,
      vm: vm,
      day: day,
      slot: slot,
      child: inner,
    );
    // BUT-1611: presence lives per meal — a dedicated faces row below the slot,
    // its own tap target so the dish area keeps navigate/add. Hidden for a solo
    // account (roster ≤ 1), and suppressed during multi-select to avoid two tap
    // meanings on one cell. Faces show even on an empty slot so presence can be
    // set before a dish exists. Presence drives display, portions and the
    // who's-eating record only — never menu generation (that would under-filter
    // allergens; see BUT-1625).
    if (roster.length <= 1 || vm.selectionMode) return cell;
    // BUT-1991: `cell` must be a FLEX child here. As a plain child of this
    // Column it was handed an unbounded main-axis constraint, and the dish
    // cell's own `Expanded` then had nothing finite to divide — which is why
    // this threw only for a household with family: the roster-1 path returns
    // above and never builds this wrapper at all. Expanded also says what the
    // layout means, that the dish takes the height the presence row leaves.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: cell),
        _SlotPresenceRow(
          roster: roster,
          presentIds: plan.presentMemberIdsFor(day, slot),
          onTap: () => onTapPresence(day, slot),
          semanticsLabel: context.l10n.a11yMenuSlotPresence(
            slot.displayLabel,
            day.displayLabel,
          ),
        ),
      ],
    );
  }

  /// BUT-1613: members present for this meal, roster-filtered so it matches the
  /// portion count shown on the presence row. Null when solo (roster ≤ 1), no
  /// selection, or nobody home — cooking mode then uses its household default.
  int? _presentServings() {
    if (roster.length <= 1) return null;
    final presentIds = plan.presentMemberIdsFor(day, slot);
    if (presentIds == null || presentIds.isEmpty) return null;
    final count = roster.where((m) => presentIds.contains(m.memberId)).length;
    return count > 0 ? count : null;
  }
}

/// BUT-1611: the per-slot present-diner faces row. Shows the faces of whoever
/// is home for this meal (all of them when the slot has no explicit selection
/// = everyone), plus a portion count = number present (B's "portionssiffran"
/// graft — cook for who's actually there). Tapping opens the presence sheet.
class _SlotPresenceRow extends StatelessWidget {
  final List<HouseholdRosterMember> roster;
  final List<String>? presentIds;
  final VoidCallback onTap;
  final String semanticsLabel;

  const _SlotPresenceRow({
    required this.roster,
    required this.presentIds,
    required this.onTap,
    required this.semanticsLabel,
  });

  static const int _maxFaces = 4;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // null selection = everyone home (the default); an explicit list is honored
    // exactly, including an empty "nobody home".
    final present = presentIds == null
        ? roster
        : roster.where((m) => presentIds!.contains(m.memberId)).toList();
    final shown = present.take(_maxFaces).toList();
    final overflow = present.length - shown.length;

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              bottom: BorderSide(color: cs.outlineVariant),
              left: BorderSide(color: cs.outlineVariant),
              right: BorderSide(color: cs.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              if (present.isEmpty)
                Text(
                  context.l10n.menuPresenceNobody,
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 8,
                    color: cs.outline,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                for (var i = 0; i < shown.length; i++)
                  Padding(
                    padding: EdgeInsetsDirectional.only(start: i == 0 ? 0 : 2),
                    child: FamilyAvatar(
                      name: shown[i].displayName,
                      color: parseAvatarColor(shown[i].avatarColor),
                      size: 16,
                    ),
                  ),
              if (overflow > 0)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 3),
                  child: Text(
                    '+$overflow',
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 9,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const Spacer(),
              if (present.isNotEmpty)
                Text(
                  context.l10n.menuPresencePortions(present.length),
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 8,
                    color: cs.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              Icon(Icons.expand_more, size: 12, color: cs.outline),
            ],
          ),
        ),
      ),
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

  /// BUT-1613: members home for this meal, forwarded into the recipe tap so
  /// cooking mode opens pre-scaled. Null → cooking mode's household default.
  final int? presentServings;

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
    this.presentServings,
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
        onTap: () => selectionMode
            ? onToggleSelection(entry.id)
            : onTap(entry.recipeId, presentServings: presentServings),
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
                  padding: const EdgeInsetsDirectional.only(end: 3),
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
