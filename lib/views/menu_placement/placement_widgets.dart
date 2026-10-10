/// BUT-1241: grid widgets for the manual placement mode.
///
/// Deliberately separate from `calendar_cells.dart` — those cells carry
/// drag-drop machinery and the live-plan ViewModel; placement cells are a
/// simpler tap-to-place state machine (eligible / occupied / dimmed) over
/// the in-memory working plan.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/menu_placement_viewmodel.dart';
import 'package:butlery/widgets/menu/menu_new_badge.dart';
import 'package:butlery/widgets/common/press_fill.dart';

export 'package:butlery/views/menu_placement/placement_tray_card.dart';

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
    final brightness = Theme.of(context).brightness;
    return Container(
      constraints: const BoxConstraints(minHeight: _kCellMinHeight),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: dimOthers
            ? AppModeColors.surfaceDisabled(brightness)
            : Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in entries) ...[
            _OvrigtEntryChip(vm: vm, entry: entry, disabled: dimOthers),
            const SizedBox(height: 3),
          ],
          if (eligible)
            Expanded(
              child: _EligibleCell(vm: vm, day: day, slot: slot),
            ),
        ],
      ),
    );
  }
}

// Interpretation (Q-P7-14): a cell that cannot take the chosen dish while
// a dish is chosen is drawn disabled, surface.disabled with text.disabled
// (tokens.json:120-123, :198), never faded to 35 %: opacity is never a
// state (tokens.json:41), and the drawings show no 35 % dimming.
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
      child: Material(
        type: MaterialType.transparency,
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
            onTap: () => vm.placeSelectedAt(day),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: _kCellMinHeight - 8,
              ),
              alignment: Alignment.center,
              // Skarmar v12 del 2 #placera draws a free cell, also while a
              // dish is chosen ("Kikärtscurry vald"), as a 1.5 px dashed
              // border.subtle outline with an 8 px radius, no fill and
              // text.secondary text. outlineVariant and onSurfaceVariant carry
              // border.subtle and text.secondary in both schemes.
              foregroundDecoration: _DashedOutline(color: cs.outlineVariant),
              child: ExcludeSemantics(
                child: Text(
                  context.l10n.menuPlacementPlaceHere,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.overline.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The free cell's dashed 1.5 px outline with an 8 px radius (#placera).
class _DashedOutline extends Decoration {
  const _DashedOutline({required this.color});

  final Color color;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DashedOutlinePainter(color);
}

class _DashedOutlinePainter extends BoxPainter {
  _DashedOutlinePainter(this.color);

  final Color color;

  static const double _width = 1.5;
  static const double _dash = 4;
  static const double _gap = 3;
  static const Radius _radius = Radius.circular(8);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = (offset & size).deflate(_width / 2);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, _radius));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + _dash),
          paint,
        );
        distance += _dash + _gap;
      }
    }
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
    final off = dimmed && !isSession;
    final cell = Container(
      constraints: const BoxConstraints(minHeight: _kCellMinHeight),
      padding: const EdgeInsets.all(4),
      // #placera draws a placed dish on surface.raised with a 1 px
      // border.control (Skarmar v12 del 2); this session's dish gets the
      // 1.5 px text.primary border. primaryContainer, outline and onSurface
      // carry those tokens in both schemes. A cell that cannot take the
      // chosen dish keeps surface.raised and draws its title in
      // text.disabled.onRaised, the pair tokens.json:198-201 measures
      // (3.19 light / 3.96 dark, floor 3 at :543). surface.disabled is a
      // surface for empty cells only, never under text (tokens.json:557).
      decoration: BoxDecoration(
        border: Border.all(
          color: isSession ? cs.onSurface : cs.outline,
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
              style: AppTextStyles.calendarCell.copyWith(
                height: 1.15,
                color: off ? AppModeColors.textDisabled(cs.brightness) : null,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    return _unplaceable(
      context,
      vm: vm,
      entry: entry,
      isSession: isSession,
      surface: PressSurface.raised,
      filled: Ink(color: cs.primaryContainer, child: cell),
    );
  }
}

/// Stacked entry chip inside the övrigt column.
class _OvrigtEntryChip extends StatelessWidget {
  final MenuPlacementViewModel vm;
  final WeeklyMenuPlanEntry entry;

  /// Whether the column cannot take the chosen dish (drawn disabled).
  final bool disabled;

  const _OvrigtEntryChip({
    required this.vm,
    required this.entry,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSession = vm.isSessionEntry(entry.id);
    final off = disabled && !isSession;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        // Paper under text in both states; an unavailable chip only turns
        // its title to text.disabled.onRaised (3.55:1 on paper), never
        // surface.disabled under text.
        border: Border(
          left: BorderSide(
            color: isSession ? cs.onSurface : cs.secondary,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              entry.recipeTitle.toLowerCase(),
              style: AppTextStyles.calendarCell.copyWith(
                height: 1.1,
                color: off ? AppModeColors.textDisabled(cs.brightness) : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isSession) const MenuNewBadge(),
        ],
      ),
    );
    return _unplaceable(
      context,
      vm: vm,
      entry: entry,
      isSession: isSession,
      surface: PressSurface.base,
      filled: Ink(color: cs.surface, child: chip),
    );
  }
}

/// A placed dish: this session's dish un-places on tap. The fill paints on
/// the ink layer, beneath the press, and the border box stays above it.
Widget _unplaceable(
  BuildContext context, {
  required MenuPlacementViewModel vm,
  required WeeklyMenuPlanEntry entry,
  required bool isSession,
  required PressSurface surface,
  required Widget filled,
}) {
  if (!isSession) {
    return Material(type: MaterialType.transparency, child: filled);
  }
  return Semantics(
    label: context.l10n.a11yPlacementRemoveEntry,
    button: true,
    child: Material(
      type: MaterialType.transparency,
      child: PressFill(
        surface: surface,
        child: InkWell(onTap: () => vm.unplaceEntry(entry.id), child: filled),
      ),
    ),
  );
}

class _NeutralEmptyCell extends StatelessWidget {
  final bool dimmed;

  const _NeutralEmptyCell({required this.dimmed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: _kCellMinHeight),
      decoration: BoxDecoration(
        color: dimmed
            ? AppModeColors.surfaceDisabled(theme.brightness)
            : theme.cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
    );
  }
}
