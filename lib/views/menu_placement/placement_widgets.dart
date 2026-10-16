/// BUT-1241: grid widgets for the manual placement mode.
///
/// The week is the shared [CalendarWeekGrid]; only the cells differ from the
/// calendar's. Placement cells are a simpler tap-to-place state machine
/// (free / occupied / not for the chosen dish) over the in-memory working
/// plan, drawn after the approved picture 78-menu-placement: a free place is
/// a dashed frame with a plus, a placed dish a bordered cell.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/menu_placement_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/menu/calendar/calendar_slot_cells.dart';
import 'package:butlery/widgets/menu/calendar/calendar_week_grid.dart';
import 'package:butlery/widgets/menu/calendar/dashed_outline.dart';
import 'package:butlery/widgets/menu/menu_new_badge.dart';

export 'package:butlery/views/menu_placement/placement_tray_card.dart';

/// 7×3 week grid rendering the working plan with placement affordances.
class PlacementGrid extends StatelessWidget {
  final MenuPlacementViewModel vm;

  const PlacementGrid({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final now = clock.now();
    final todayIndex = vm.weekStart == IsoWeekUtils.weekStartOf(now)
        ? now.weekday - 1
        : -1;
    return CalendarWeekGrid(
      weekStart: vm.weekStart,
      todayIndex: todayIndex,
      cellBuilder: (context, day, slot) =>
          _PlacementCell(vm: vm, day: day, slot: slot),
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
    final dimmed = vm.selectedItem != null;
    if (entries.isEmpty) {
      return _FreeCell(vm: vm, day: day, slot: slot, eligible: eligible);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.space4,
      children: [
        for (final entry in entries)
          _PlacedDish(
            vm: vm,
            entry: entry,
            off: dimmed && !vm.isSessionEntry(entry.id),
          ),
        // Övrigt takes more than one dish.
        if (slot.isMulti && eligible)
          _FreeCell(vm: vm, day: day, slot: slot, eligible: true),
      ],
    );
  }
}

/// A place with no dish yet: a dashed frame and a plus, tappable while the
/// chosen dish belongs in it.
class _FreeCell extends StatelessWidget {
  final MenuPlacementViewModel vm;
  final DayOfWeek day;
  final MealSlot slot;
  final bool eligible;

  const _FreeCell({
    required this.vm,
    required this.day,
    required this.slot,
    required this.eligible,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final plus = ExcludeSemantics(
      child: ButleryIcon(
        ButleryIcons.plus,
        size: AppDimensions.iconSizeM,
        color: eligible
            ? cs.onSurface
            : AppModeColors.textDisabled(cs.brightness),
      ),
    );
    final box = Container(
      constraints: const BoxConstraints(minHeight: kCalendarCellMinHeight),
      alignment: Alignment.center,
      foregroundDecoration: DashedOutline(color: cs.outlineVariant),
      child: plus,
    );
    if (!eligible) return box;
    return Semantics(
      label: context.l10n.a11yPlacementCell(
        day.displayLabel,
        slot.displayLabel,
      ),
      button: true,
      excludeSemantics: true,
      onTap: () => vm.placeSelectedAt(day),
      child: Material(
        type: MaterialType.transparency,
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
            onTap: () => vm.placeSelectedAt(day),
            child: box,
          ),
        ),
      ),
    );
  }
}

/// A placed dish in its own bordered cell. This session's dish has the
/// text.primary border and the NY mark and un-places on tap; one that was
/// there already is inert here.
class _PlacedDish extends StatelessWidget {
  final MenuPlacementViewModel vm;
  final WeeklyMenuPlanEntry entry;

  /// Whether the cell cannot take the chosen dish (title drawn disabled).
  final bool off;

  const _PlacedDish({required this.vm, required this.entry, this.off = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSession = vm.isSessionEntry(entry.id);
    final cellWidth = CalendarCellWidth.maybeOf(context);
    final badgeWidth = isSession
        ? widestWord(
                context,
                [context.l10n.weeklyMenuNewBadge],
                AppTextStyles.overline,
              ) +
              AppDimensions.badgePadding.horizontal
        : 0.0;
    final frame = CalendarCellFrame(
      selected: isSession,
      fillWhenSelected: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: WholeWordText(
              entry.recipeTitle,
              width: cellWidth == null
                  ? null
                  : cellWidth - kCalendarCellChrome - badgeWidth,
              style: AppTextStyles.bodySmall.copyWith(
                height: 1.15,
                color: off
                    ? AppModeColors.textDisabled(cs.brightness)
                    : cs.onSurface,
              ),
            ),
          ),
          if (isSession) const MenuNewBadge(),
        ],
      ),
    );
    if (!isSession) return frame;
    return Semantics(
      label: context.l10n.a11yPlacementRemoveEntry,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
            onTap: () => vm.unplaceEntry(entry.id),
            child: frame,
          ),
        ),
      ),
    );
  }
}
