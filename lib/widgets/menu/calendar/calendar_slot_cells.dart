/// The cells of the week table: an empty place, a dish, and the Övrigt cell.
///
/// Drawn after the sketch (Skarmar v12 del 1 #veckomeny, approved picture
/// 21-veckomeny-v2-1): an empty place is a bare plus, a dish is a bordered
/// 8 dp cell with its name and the marks of [calendar_markers.dart] in the
/// corner. Who is home is not drawn as faces
/// here (B-40); it opens from a tap on the cell.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/menu/calendar/calendar_drag.dart';
import 'package:butlery/widgets/menu/calendar/calendar_markers.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';

/// Callback fired when an empty slot is tapped — orchestrator owns the
/// recipe-picker dialog flow.
typedef SlotTapCallback = void Function(DayOfWeek day, MealSlot slot);

/// Callback fired when a dish is opened — orchestrator owns navigation
/// routing. [presentServings] is the number of members home for this meal when
/// the lunch/middag slot has an explicit, non-empty presence selection, so
/// cooking mode can open pre-scaled to who is home. Null for övrigt, solo
/// accounts and unset or empty presence.
typedef RecipeNavCallback =
    void Function(String recipeId, {int? presentServings});

/// Callback fired when a meal's presence is asked for.
typedef PresenceTapCallback = void Function(DayOfWeek day, MealSlot slot);

/// The place a cell has to stay tappable: B-03.
const double kCalendarCellMinHeight = AppDimensions.minTouchTarget;

/// The width a week grid gives each cell, for the text in it to be sized
/// against. The grid sits in an `IntrinsicHeight`, which cannot host a
/// `LayoutBuilder`, so it measures once outside it and passes the width down.
class CalendarCellWidth extends InheritedWidget {
  const CalendarCellWidth({
    super.key,
    required this.width,
    required super.child,
  });

  final double width;

  static double? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CalendarCellWidth>()?.width;

  @override
  bool updateShouldNotify(CalendarCellWidth old) => width != old.width;
}

/// What a cell's frame takes of its width: padding and the thicker edge.
const double kCalendarCellChrome =
    AppDimensions.space8 * 2 + AppDimensions.borderWidthOutlinedEdge * 2;

/// What every cell of the table shares: the border, the radius and the chosen
/// state. A cell never draws its own frame.
class CalendarCellFrame extends StatelessWidget {
  const CalendarCellFrame({
    super.key,
    required this.child,
    this.selected = false,
    this.fillWhenSelected = true,
  });

  final Widget child;
  final bool selected;

  /// A cell that sits under an ink press keeps its fill off, or the fill
  /// would cover the press; the border alone then marks it chosen.
  final bool fillWhenSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ButleryOutlinedBox(
      color: selected && fillWhenSelected ? cs.surfaceContainerHighest : null,
      borderColor: selected ? cs.onSurface : cs.outlineVariant,
      borderWidth: selected ? 1.5 : 1,
      radius: AppDimensions.radiusControl,
      padding: const EdgeInsets.all(AppDimensions.space8),
      constraints: const BoxConstraints(minHeight: kCalendarCellMinHeight),
      child: child,
    );
  }
}

/// A place with no dish: a plus the whole cell answers to.
class CalendarEmptyCell extends StatelessWidget {
  const CalendarEmptyCell({
    super.key,
    required this.day,
    required this.slot,
    required this.onTap,
    this.onLongPress,
  });

  final DayOfWeek day;
  final MealSlot slot;
  final SlotTapCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    // BUT-403: enum `name` (not displayLabel) keeps the identifier stable
    // across locale changes.
    final identifier = 'menu-slot-${day.name}-${slot.name}';
    return Semantics(
      identifier: identifier,
      button: true,
      label: context.l10n.a11yWeeklyMenuAddDish(
        slot.displayLabel,
        day.displayLabel,
      ),
      excludeSemantics: true,
      onTap: () => onTap(day, slot),
      child: Material(
        type: MaterialType.transparency,
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            key: ValueKey('test-$identifier'),
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
            onTap: () => onTap(day, slot),
            onLongPress: onLongPress,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kCalendarCellMinHeight,
              ),
              child: Center(
                child: ButleryIcon(
                  ButleryIcons.plus,
                  size: AppDimensions.iconSizeM,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the corner of a dish cell says.
class CalendarCellMarks {
  const CalendarCellMarks({
    this.isNew = false,
    this.allergenUnsafe = false,
    this.presentCount,
    this.placementOrder,
  });

  final bool isNew;
  final bool allergenUnsafe;

  /// How many are home; null when it is everyone.
  final int? presentCount;

  /// 1-based order of the automatic placement, or null.
  final int? placementOrder;

  /// Room the corner takes from the first line of the name. The dot overlays
  /// the line instead: it is the one mark that does not push the name aside.
  /// The widths are approximations of each mark's painted width, not derived
  /// from the text scale.
  double get reservedWidth =>
      (allergenUnsafe ? 18.0 : 0) +
      (presentCount != null ? 28.0 : 0) +
      (placementOrder != null ? 14.0 : 0);
}

/// A dish in a lunch or middag place, or the one dish of an Övrigt place.
class CalendarDishCell extends StatelessWidget {
  const CalendarDishCell({
    super.key,
    required this.title,
    required this.marks,
    required this.semanticsLabel,
    required this.onTap,
    this.semanticsValue,
    this.extraCount = 0,
    this.selectionMode = false,
    this.selected = false,
    this.dragPayload,
    this.maxTitleLines,
  });

  final String title;
  final CalendarCellMarks marks;
  final String semanticsLabel;
  final String? semanticsValue;

  /// Dishes beyond the first in an Övrigt place, written "+N" after the name.
  final int extraCount;

  /// Caps the name with an ellipsis; null lets a long name grow the cell.
  final int? maxTitleLines;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;

  /// Drag is suppressed in selection mode so the two gestures do not fight
  /// over one cell, and for a place that holds more than one dish.
  final CalendarDragPayload? dragPayload;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = AppTextStyles.calendarCell.copyWith(
      color: cs.onSurface,
      height: 1.15,
    );
    final cellWidth = CalendarCellWidth.maybeOf(context);
    final name = WholeWordText(
      extraCount > 0 ? '$title +$extraCount' : title,
      style: style,
      maxLines: maxTitleLines,
      width: cellWidth == null
          ? null
          : cellWidth - kCalendarCellChrome - marks.reservedWidth,
    );
    final corner = <Widget>[
      if (marks.placementOrder != null)
        PlacementOrderNumber(order: marks.placementOrder!),
      if (marks.allergenUnsafe) const CalendarAllergenMark(),
      if (marks.presentCount != null)
        CalendarPresenceMark(count: marks.presentCount!),
      if (marks.isNew) const CalendarNewDot(),
    ];
    final cell = Semantics(
      label: semanticsLabel,
      value: semanticsValue,
      button: true,
      selected: selectionMode ? selected : null,
      child: Material(
        type: MaterialType.transparency,
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
            onTap: onTap,
            child: CalendarCellFrame(
              selected: selected,
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: selectionMode ? 0 : marks.reservedWidth,
                    ),
                    child: name,
                  ),
                  PositionedDirectional(
                    top: 0,
                    end: 0,
                    child: selectionMode
                        ? ButleryIcon(
                            selected
                                ? ButleryIcons.checkSquare
                                : ButleryIcons.square,
                            size: AppDimensions.iconSize14,
                            color: cs.secondary,
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: AppDimensions.space4,
                            children: corner,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final payload = dragPayload;
    if (selectionMode || payload == null) return cell;
    return wrapAsDraggable(context: context, payload: payload, child: cell);
  }
}
