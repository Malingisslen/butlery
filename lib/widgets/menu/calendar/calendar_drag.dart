/// Drag-drop payloads + helper wrappers for the weekly-menu calendar.
///
/// Extracted from `calendar_weekly_menu_widget.dart` (BUT-542) so the
/// orchestrator can stay focused on layout and the drag/drop machinery
/// has its own clearly-scoped surface.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';

const double _kDragFeedbackWidth = 110;

/// Sealed payload type for drag-and-drop in the calendar.
/// `MovePayload` carries an existing entry being relocated; `OverflowPayload`
/// carries a recipe being assigned from the overflow tray.
sealed class CalendarDragPayload {}

class MovePayload extends CalendarDragPayload {
  final WeeklyMenuPlanEntry entry;
  MovePayload(this.entry);
}

class OverflowPayload extends CalendarDragPayload {
  final Recipe recipe;
  OverflowPayload(this.recipe);
}

/// Wraps [child] as draggable. On web, uses a short delay (150ms) instead
/// of the default 500ms so click-and-drag feels responsive.
Widget wrapAsDraggable({
  required BuildContext context,
  required CalendarDragPayload payload,
  required Widget child,
}) {
  // Simple label feedback avoids layout issues (Expanded in overlay).
  final label = switch (payload) {
    MovePayload(:final entry) => entry.recipeTitle,
    OverflowPayload(:final recipe) => recipe.title,
  };
  final cs = Theme.of(context).colorScheme;
  final feedback = Material(
    elevation: 4,
    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
    child: Container(
      width: _kDragFeedbackWidth,
      padding: const EdgeInsets.all(AppDimensions.spacingS),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(color: cs.primary),
      ),
      child: Text(
        label.toLowerCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
  final ghost = Opacity(
    opacity: AppDimensions.opacityMediumLight,
    child: child,
  );

  return LongPressDraggable<CalendarDragPayload>(
    data: payload,
    delay: kIsWeb
        ? const Duration(milliseconds: 150)
        : const Duration(milliseconds: 500),
    onDragStarted: kIsWeb ? null : HapticFeedback.selectionClick,
    feedback: feedback,
    childWhenDragging: ghost,
    child: child,
  );
}

/// Wraps any cell in a `DragTarget` that accepts both move (existing entry
/// being relocated) and overflow (recipe being assigned from the overflow
/// tray) payloads.
Widget wrapAsDropTarget({
  required BuildContext context,
  required WeeklyMenuPlanViewModel vm,
  required DayOfWeek day,
  required MealSlot slot,
  required Widget child,
}) {
  return DragTarget<CalendarDragPayload>(
    onWillAcceptWithDetails: (details) {
      final p = details.data;
      // Don't accept self-drop on the same (day, slot).
      if (p is MovePayload && p.entry.day == day && p.entry.slot == slot) {
        return false;
      }
      return true;
    },
    onAcceptWithDetails: (details) async {
      HapticFeedback.lightImpact();
      final p = details.data;
      if (p is MovePayload) {
        await vm.moveEntry(
          entryId: p.entry.id,
          toDay: day,
          toSlot: slot,
        );
      } else if (p is OverflowPayload) {
        await vm.assignFromOverflow(
          recipe: p.recipe,
          day: day,
          slot: slot,
        );
      }
    },
    builder: (context, candidate, rejected) {
      if (candidate.isEmpty) return child;
      final cs = Theme.of(context).colorScheme;
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: cs.secondary, width: 2),
          color: cs.secondary.withValues(alpha: 0.06),
        ),
        child: child,
      );
    },
  );
}
