/// The group's weekly menu, rendered (BUT-1971).
library;

import 'dart:async';

import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/distinct_initials.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/menu/group_weekly_menu_viewmodel.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/menu/calendar/calendar_header.dart';
import 'package:butlery/widgets/menu/calendar/calendar_slot_cells.dart';
import 'package:butlery/widgets/menu/calendar/calendar_week_grid.dart';
import 'package:butlery/widgets/menu/calendar/week_range_label.dart';
import 'package:butlery/widgets/menu/group_menu_dish_sheet.dart';

/// Renders whatever [GroupWeeklyMenuViewModel] sits above it.
///
/// Split from `GroupWeeklyMenuView` the same way the personal calendar is: the
/// view owns the provider, the widget owns the pixels, and the widget can be
/// driven straight from a viewmodel in a test.
class GroupWeeklyMenuWidget extends StatefulWidget {
  final String groupName;
  final VoidCallback? onStartPoll;

  const GroupWeeklyMenuWidget({
    super.key,
    required this.groupName,
    this.onStartPoll,
  });

  @override
  State<GroupWeeklyMenuWidget> createState() => _GroupWeeklyMenuWidgetState();
}

class _GroupWeeklyMenuWidgetState extends State<GroupWeeklyMenuWidget> {
  GroupMenuEditProblem? _shownNotice;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GroupWeeklyMenuViewModel>();
    _surfaceEditNotice(vm);

    return Scaffold(
      // A subpage (Komponentark v1:71-78): the group's week is opened from
      // the group chat, so the back arrow returns there.
      appBar: ButleryTopBar.undersida(title: widget.groupName),
      body: SafeArea(child: _body(context, vm)),
    );
  }

  /// An edit failure is a passing notice, never a screen.
  void _surfaceEditNotice(GroupWeeklyMenuViewModel vm) {
    final notice = vm.editNotice;
    if (notice == GroupMenuEditProblem.none || notice == _shownNotice) {
      if (notice == GroupMenuEditProblem.none) _shownNotice = null;
      return;
    }
    _shownNotice = notice;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final text = _noticeText(context, notice);
      // Only a failed undo carries an action. The dish is still held in memory
      // but the snackbar that offered "Ångra" is gone, so without this the user
      // has a rescued dish and no way to reach it.
      if (notice == GroupMenuEditProblem.undoFailed) {
        SnackBarUtils.showErrorWithRetry(
          context,
          text,
          onRetry: () => unawaited(vm.undoLastRemoval()),
        );
      } else {
        SnackBarUtils.showFailure(context, what: text);
      }
      vm.clearEditNotice();
    });
  }

  String _noticeText(BuildContext context, GroupMenuEditProblem problem) {
    switch (problem) {
      case GroupMenuEditProblem.notAnEditor:
        return context.l10n.groupMenuViewerNotice;
      case GroupMenuEditProblem.undoUnavailable:
        return context.l10n.groupMenuUndoUnavailable;
      case GroupMenuEditProblem.saveFailed:
        return context.l10n.groupMenuSaveFailed;
      // Its own sentence, not the save's: this is the one notice here that
      // carries a retry button, and `groupMenuSaveFailed` already ends in
      // "Försök igen", so sharing it printed the phrase twice.
      case GroupMenuEditProblem.undoFailed:
        return context.l10n.groupMenuUndoFailed;
      // P6-U05: why the edit controls just went away.
      case GroupMenuEditProblem.roleLowered:
        return context.l10n.roleLoweredGroupMenu;
      case GroupMenuEditProblem.none:
        // Filtered out by the caller; never rendered.
        return '';
    }
  }

  Widget _body(BuildContext context, GroupWeeklyMenuViewModel vm) {
    switch (vm.failure) {
      case GroupMenuFailure.permissionDenied:
        // Deliberately no action: there is nothing to retry, and a button that
        // can never succeed teaches the user that buttons do nothing.
        return StateWidget.error(message: context.l10n.groupMenuNotAMember);
      case GroupMenuFailure.transient:
        return StateWidget.error(
          message: context.l10n.groupMenuLoadFailed,
          actionLabel: context.l10n.commonRetry,
          onAction: () => vm.loadWeek(vm.weekStart),
        );
      case GroupMenuFailure.none:
        break;
    }

    if (vm.isLoading) {
      // The plate line says what it fetches (produktregler.md:163, :304).
      return StateWidget.loading(message: context.l10n.loadingWeeklyMenu);
    }

    final now = clock.now();
    final todayIndex = vm.weekStart == IsoWeekUtils.weekStartOf(now)
        ? now.weekday - 1
        : -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WeekNavHeader(
          title: context.l10n.weeklyMenuWeekTitle(
            IsoWeekUtils.isoWeekNumber(vm.weekStart),
          ),
          range: formatWeekRange(context, vm.weekStart),
          onPrev: vm.goToPreviousWeek,
          onNext: vm.goToNextWeek,
        ),
        _FaceRow(vm: vm),
        // Only once a plan document exists: a week nobody has planned yet has
        // `plan == null`, so `canEdit` is false and the banner would tell an
        // admin they may not edit — directly above the prompt asking them to
        // start a poll.
        if (vm.plan != null && !vm.canEdit)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical: AppDimensions.space4,
            ),
            child: Text(
              context.l10n.groupMenuViewerNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: vm.isEmptyWeek
              ? _emptyWeek(context)
              : SingleChildScrollView(
                  padding: AppDimensions.responsiveContentPadding(context),
                  child: CalendarWeekGrid(
                    weekStart: vm.weekStart,
                    todayIndex: todayIndex,
                    cellBuilder: (context, day, slot) =>
                        _cell(context, vm, day, slot),
                  ),
                ),
        ),
      ],
    );
  }

  /// A place in the week: the dish's name, or a plus that starts a poll when
  /// the group can. The week is filled by polls, not by picking a dish here.
  Widget _cell(
    BuildContext context,
    GroupWeeklyMenuViewModel vm,
    DayOfWeek day,
    MealSlot slot,
  ) {
    final entries = [
      for (final e in vm.entriesFor(day))
        if (e.slot == slot) e,
    ];
    final l10n = context.l10n;
    if (entries.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      final plus = SizedBox(
        height: kCalendarCellMinHeight,
        child: Center(
          child: ButleryIcon(
            ButleryIcons.plus,
            size: AppDimensions.iconSizeM,
            color: cs.onSurfaceVariant,
          ),
        ),
      );
      final start = widget.onStartPoll;
      if (start == null) return const SizedBox(height: kCalendarCellMinHeight);
      return Semantics(
        button: true,
        label: l10n.groupMenuEmptyAction,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: PressFill(
            surface: PressSurface.base,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
              onTap: start,
              child: plus,
            ),
          ),
        ),
      );
    }
    return CalendarDishCell(
      title: entries.first.recipeTitle,
      extraCount: entries.length - 1,
      marks: const CalendarCellMarks(),
      semanticsLabel: l10n.a11yGroupMenuDishDetails,
      onTap: () => showGroupDishSheet(
        context: context,
        vm: vm,
        day: day,
        slot: slot,
        onRemove: _remove,
      ),
    );
  }

  Widget _emptyWeek(BuildContext context) {
    return StateWidget.empty(
      title: context.l10n.groupMenuEmptyTitle,
      subtitle: context.l10n.groupMenuEmptyBody,
      icon: ButleryIcons.vote,
      actionLabel: widget.onStartPoll == null
          ? null
          : context.l10n.groupMenuEmptyAction,
      onAction: widget.onStartPoll,
    );
  }

  /// Class-1 destructive per `.claude/rules/ui-conventions.md`: no dialog, but
  /// an undo.
  Future<void> _remove(String entryId) async {
    final vm = context.read<GroupWeeklyMenuViewModel>();
    final ok = await vm.removeEntry(entryId);
    if (!mounted || !ok) return;
    if (!vm.canUndoRemoval) {
      SnackBarUtils.showSuccess(context, context.l10n.groupMenuDishRemoved);
      return;
    }
    SnackBarUtils.showUndo(
      context,
      context.l10n.groupMenuDishRemoved,
      onUndo: () => unawaited(vm.undoLastRemoval()),
    );
  }
}

class _FaceRow extends StatelessWidget {
  final GroupWeeklyMenuViewModel vm;

  const _FaceRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    final participants = vm.participants;
    if (participants.isEmpty) return const SizedBox.shrink();

    const maxFaces = 3;
    final shown = participants.take(maxFaces).toList();
    final rest = participants.length - shown.length;
    // Over every participant, not just the faces shown, so a hidden member
    // still counts as a collision.
    final initials = _initials(participants);

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.space8),
      child: Row(
        children: [
          for (var i = 0; i < shown.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: AppDimensions.space4,
              ),
              child: _Face(initials: initials[i]),
            ),
          if (rest > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: AppDimensions.space4,
              ),
              child: _Face(initials: '+$rest'),
            ),
          // Flexible so the member count ellipsizes instead of widening the
          // row past the screen.
          Flexible(
            child: Text(
              context.l10n.shareGroupMembersCount(participants.length),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// A uid is never shown. Until the profile resolves — or if it cannot be
  /// read at all — the face carries a neutral mark instead.
  List<String> _initials(List<GroupMenuParticipant> participants) {
    final names = [
      for (final p in participants)
        vm.displayNameFor(p.userId).orEmptyTrimmed(),
    ];
    final initials = distinctInitials(names);
    return [
      for (var i = 0; i < names.length; i++)
        names[i].isEmpty ? '·' : initials[i],
    ];
  }
}

class _Face extends StatelessWidget {
  final String initials;

  const _Face({required this.initials});

  @override
  Widget build(BuildContext context) {
    return AvatarCircle(glyph: initials, size: AvatarCircleSize.inline);
  }
}
