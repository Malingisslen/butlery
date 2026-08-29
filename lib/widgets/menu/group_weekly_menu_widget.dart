/// The group's weekly menu, rendered (BUT-1971).
///
/// Direction A from the design round Malin picked on 2026-08-29: the whole week
/// as a dense row list, empty days visible as empty. Face row on top, week
/// arrows at the bottom. `_weekList` documents what happens when the rows stop
/// fitting.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/menu/group_weekly_menu_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';

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
      appBar: AppBar(title: Text(widget.groupName)),
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
      SnackBarUtils.showError(context, _noticeText(context, notice));
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
      return StateWidget.loading(message: context.l10n.loadingGeneric);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // In the body, not the app bar: an AppBar's toolbar height does not
        // follow the text scaler, so a subtitle inside it has a fixed box to
        // grow in.
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimensions.spacingM,
            top: AppDimensions.spacingS,
          ),
          child: Text(
            _weekLabel(context, vm.weekStart),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        _FaceRow(vm: vm),
        // Only once a plan document exists: a week nobody has planned yet has
        // `plan == null`, so `canEdit` is false and the banner would tell an
        // admin they may not edit — directly above the prompt asking them to
        // start a poll.
        if (vm.plan != null && !vm.canEdit)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingM,
              vertical: AppDimensions.spacingXs,
            ),
            child: Text(
              context.l10n.groupMenuViewerNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: vm.isEmptyWeek ? _emptyWeek(context) : _weekList(context, vm),
        ),
        _WeekArrows(vm: vm),
      ],
    );
  }

  Widget _emptyWeek(BuildContext context) {
    return StateWidget.empty(
      title: context.l10n.groupMenuEmptyTitle,
      subtitle: context.l10n.groupMenuEmptyBody,
      icon: Icons.how_to_vote_outlined,
      actionLabel: widget.onStartPoll == null
          ? null
          : context.l10n.groupMenuEmptyAction,
      onAction: widget.onStartPoll,
    );
  }

  /// The whole week, one row per day.
  ///
  /// Rows size to their content rather than taking seven `Expanded` slices, and
  /// the column scrolls when the content does not fit. The `no overflow at
  /// small sizes` group holds the sizes where a fixed-slice layout clips
  /// instead, and carries the measurement.
  Widget _weekList(BuildContext context, GroupWeeklyMenuViewModel vm) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final day in DayOfWeek.values)
            _DayRow(vm: vm, day: day, onRemove: _remove),
        ],
      ),
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
    SnackBarUtils.showSuccessWithAction(
      context,
      context.l10n.groupMenuDishRemoved,
      actionLabel: context.l10n.commonUndo,
      onAction: () => unawaited(vm.undoLastRemoval()),
      duration: const Duration(seconds: 7),
    );
  }

  String _weekLabel(BuildContext context, DateTime weekStart) {
    final end = weekStart.add(const Duration(days: 6));
    // The month name comes from the active locale, not a hardcoded Swedish
    // list: a localized frame around untranslated content is the same defect
    // as a Swedish string in the ViewModel.
    final locale = Localizations.localeOf(context).toString();
    final month = DateFormat.MMMM(locale).format(end);
    return context.l10n.groupMenuWeekRange(
      IsoWeekUtils.isoWeekNumber(weekStart),
      '${weekStart.day}–${end.day} $month',
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

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
      child: Row(
        children: [
          for (final participant in shown)
            Padding(
              padding: const EdgeInsets.only(right: AppDimensions.spacingXs),
              child: _Face(initials: _initials(participant)),
            ),
          if (rest > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppDimensions.spacingS),
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
  String _initials(GroupMenuParticipant participant) {
    final name = vm.displayNameFor(participant.userId);
    if (name == null || name.trim().isEmpty) return '·';
    final parts = name.trim().split(RegExp(r'\s+'));
    // Grapheme-wise: `substring(0, 1)` cuts an emoji or other astral character
    // in half and renders half a code unit.
    final first = parts.first.characters.first.toUpperCase();
    if (parts.length == 1) return first;
    return first + parts.last.characters.first.toUpperCase();
  }
}

class _Face extends StatelessWidget {
  final String initials;

  const _Face({required this.initials});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 14,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final GroupWeeklyMenuViewModel vm;
  final DayOfWeek day;
  final Future<void> Function(String entryId) onRemove;

  const _DayRow({
    required this.vm,
    required this.day,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final entries = vm.entriesFor(day);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingM,
        vertical: AppDimensions.spacingXs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              day.displayLabel.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Text(
                    context.l10n.groupMenuNoDish,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Every dish carries its OWN delete control.
                      for (final entry in entries)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.recipeTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  Text(
                                    entry.slot.displayLabel,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (vm.canEdit)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                tooltip: MaterialLocalizations.of(
                                  context,
                                ).deleteButtonTooltip,
                                onPressed: () => onRemove(entry.id),
                              ),
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _WeekArrows extends StatelessWidget {
  final GroupWeeklyMenuViewModel vm;

  const _WeekArrows({required this.vm});

  @override
  Widget build(BuildContext context) {
    final previous = vm.weekStart.subtract(const Duration(days: 7));
    final next = vm.weekStart.add(const Duration(days: 7));

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: AppDimensions.spacingXs,
      ),
      // Both halves are Expanded so the labels ellipsize instead of forcing the
      // row wider than the screen.
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: vm.goToPreviousWeek,
                icon: const Icon(Icons.chevron_left),
                label: Text(
                  context.l10n.groupMenuWeekShort(
                    IsoWeekUtils.isoWeekNumber(previous),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: vm.goToNextWeek,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        context.l10n.groupMenuWeekShort(
                          IsoWeekUtils.isoWeekNumber(next),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
