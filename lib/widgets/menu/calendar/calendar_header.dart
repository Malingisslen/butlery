/// Week navigation header + overflow tray for the weekly-menu calendar.
///
/// Extracted from `calendar_cells.dart` (BUT-542) to keep that file under
/// the 500-line ceiling. Both widgets are stateless and agnostic to the
/// orchestrator's Provider/routing concerns — nav callbacks + overflow
/// payload are injected.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart'
    show WeeklyMenuOverflowReason;
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/feedback/partial_outcome.dart';
import 'package:butlery/widgets/menu/calendar/calendar_drag.dart';

class WeekNavHeader extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  /// Optional "Rensa veckan" callback. When provided, a trash icon button
  /// is shown on the trailing side so the user can clear the visible week.
  final VoidCallback? onClearWeek;

  /// BUT-1043: optional "Kopiera denna vecka → nästa vecka" callback. Shown
  /// as a copy icon when the visible week has entries to copy forward.
  final VoidCallback? onCopyWeek;

  /// BUT-1043: optional "Välj flera att flytta" callback that opens
  /// multi-select mode. Shown when there are entries to select+move.
  final VoidCallback? onSelectMode;

  const WeekNavHeader({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
    this.onClearWeek,
    this.onCopyWeek,
    this.onSelectMode,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            color: cs.onPrimaryContainer,
            onPressed: onPrev,
            tooltip: context.l10n.weeklyMenuPrevWeek,
          ),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.titleSmall.copyWith(
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (onSelectMode != null)
            IconButton(
              icon: const Icon(Icons.checklist_outlined),
              color: cs.onPrimaryContainer,
              onPressed: onSelectMode,
              tooltip: context.l10n.weeklyMenuSelectAction,
            ),
          if (onCopyWeek != null)
            IconButton(
              icon: const Icon(Icons.copy_all_outlined),
              color: cs.onPrimaryContainer,
              onPressed: onCopyWeek,
              tooltip: context.l10n.weeklyMenuCopyToNextAction,
            ),
          if (onClearWeek != null)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              color: cs.onPrimaryContainer,
              onPressed: onClearWeek,
              tooltip: context.l10n.weeklyMenuClearWeekAction,
            ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: cs.onPrimaryContainer,
            onPressed: onNext,
            tooltip: context.l10n.weeklyMenuNextWeek,
          ),
        ],
      ),
    );
  }
}

/// BUT-1043: action bar shown while multi-select mode is active. Renders the
/// live selection count plus "Flytta" and a cancel affordance. Stateless —
/// the orchestrator owns the move-picker flow and cancel callback.
class SelectionActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onMove;
  final VoidCallback onCancel;

  const SelectionActionBar({
    super.key,
    required this.selectedCount,
    required this.onMove,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        border: Border(
          bottom: BorderSide(color: cs.onSurface, width: 2),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            color: cs.onPrimaryContainer,
            onPressed: onCancel,
            tooltip: context.l10n.commonCancel,
          ),
          Expanded(
            child: Text(
              context.l10n.weeklyMenuSelectionCount(selectedCount),
              style: AppTextStyles.titleSmall.copyWith(
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: selectedCount > 0 ? onMove : null,
            icon: const Icon(Icons.drive_file_move_outline),
            label: Text(context.l10n.weeklyMenuMoveSelectionAction),
            style: TextButton.styleFrom(
              foregroundColor: cs.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// P5-U23: the tray of recipes that did not fit (produktregler.md:1123-1127,
/// § 22.6; drawn in Skarmar v12 etapp 11 breda vyer:233-242, #vmbdelvis, and
/// etapp 2:681-686, #veckooverflow).
///
/// It is a partial outcome of a bulk placement, so it takes the shared I-29
/// form ([PartialOutcome]: surface.raised with a warning edge,
/// produktregler.md:905-909, which names "massmenyläggning"). It
/// - counts in recipes: "2 av 5 rätter placerade" (produktregler.md:206);
/// - says why the rest did not fit (produktregler.md:1125) and that it stays
///   until placed ("ett arbetsförråd, inte en notis");
/// - names each recipe as written, never re-cased (produktregler.md:892: "De
///   recept som inte får plats namnges");
/// - offers next week as a choice in the tray (produktregler.md:1127), which
///   makes a snackbar "next week" action unnecessary. The week menu has none.
///
/// The chips stay draggable into the week, as before (OverflowPayload).
class OverflowTray extends StatelessWidget {
  final List<Recipe> overflow;

  /// How many of [totalCount] have a place.
  final int placedCount;

  /// How many recipes the placement was given.
  final int totalCount;

  /// Why the rest did not fit. Null for a tray whose reason is unknown.
  final WeeklyMenuOverflowReason? reason;

  /// "Lägg i vecka N". Null hides it (no reason, or the two-week limit).
  final VoidCallback? onPlaceInNextWeek;

  const OverflowTray({
    super.key,
    required this.overflow,
    required this.placedCount,
    required this.totalCount,
    this.reason,
    this.onPlaceInNextWeek,
  });

  /// Key of the "Lägg i vecka N" action.
  static const Key nextWeekKey = ValueKey('overflow-tray-next-week');

  /// Key of the chip for the recipe with [recipeId].
  static Key chipKey(String recipeId) => ValueKey('overflow-chip-$recipeId');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final why = reason;
    final offersNext = onPlaceInNextWeek != null && why != null;
    final nextWeek = why == null
        ? null
        : IsoWeekUtils.isoWeekNumber(why.nextWeekStart);
    final message = [
      if (why != null)
        l.weeklyMenuOverflowReason(IsoWeekUtils.isoWeekNumber(why.weekStart)),
      if (why != null && why.pastDaysSkipped) l.weeklyMenuOverflowPastDays,
      if (offersNext)
        l.weeklyMenuOverflowKeepOrNextWeek(nextWeek!)
      else
        l.weeklyMenuOverflowKeep,
    ].join(' ');
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: PartialOutcome(
        title: l.weeklyMenuOverflowPlacedCount(placedCount, totalCount),
        message: message,
        actions: [
          if (offersNext)
            Semantics(
              container: true,
              label: l.weeklyMenuOverflowNextWeekA11y(
                overflow.length,
                nextWeek!,
              ),
              button: true,
              onTap: onPlaceInNextWeek,
              excludeSemantics: true,
              child: OutlinedButton(
                key: nextWeekKey,
                onPressed: onPlaceInNextWeek,
                child: Text(l.weeklyMenuOverflowNextWeekAction(nextWeek)),
              ),
            ),
        ],
        child: Wrap(
          spacing: AppDimensions.spacingTight,
          runSpacing: AppDimensions.spacingTight,
          children: [
            for (final recipe in overflow)
              _OverflowChip(key: chipKey(recipe.id), recipe: recipe),
          ],
        ),
      ),
    );
  }
}

/// One recipe in the tray: its title as written, with a drag handle
/// (Skarmar v12 etapp 11:237-239: 48 px high, 1 px border, 12.5/600).
///
/// Colours, both modes from the theme: surface.base (`colorScheme.surface`,
/// #F5F4ED light, #17251D dark), border.control (`colorScheme.outline`,
/// #7D897C light, paper 35 % dark), text.primary (`onSurface`) and the handle
/// in text.secondary (`onSurfaceVariant`). The drawing's dark chip is ink
/// #24382C; the delivered theme has no surface role for that on
/// surface.raised, so the chip uses surface.base (interpretation).
class _OverflowChip extends StatelessWidget {
  final Recipe recipe;

  const _OverflowChip({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chip = Container(
      constraints: const BoxConstraints(
        minHeight: AppDimensions.minTouchTarget,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMs),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.drag_indicator,
            size: AppDimensions.iconSizeS,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Flexible(
            child: Text(
              recipe.title,
              style: AppTextStyles.labelMedium.copyWith(color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
    return wrapAsDraggable(
      context: context,
      payload: OverflowPayload(recipe),
      child: chip,
    );
  }
}
