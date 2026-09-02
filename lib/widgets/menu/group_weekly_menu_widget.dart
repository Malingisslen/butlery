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
        SnackBarUtils.showError(context, text);
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
          padding: const EdgeInsetsDirectional.only(
            start: AppDimensions.spacingM,
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
              padding: const EdgeInsetsDirectional.only(
                end: AppDimensions.spacingXs,
              ),
              child: _Face(initials: _initials(participant)),
            ),
          if (rest > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: AppDimensions.spacingS,
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
                                  _provenance(context, vm, entry),
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

/// "Föreslagen av Malin · framröstad av 3" under a dish (BUT-1971).
///
/// Draws NOTHING when the dish carries no provenance — no row, no "unknown".
/// Every dish that predates the feature is in that state, and a guessed name is
/// worse than a missing one.
///
/// The proposer gets a NAME and the voters get a COUNT because one name is what
/// fits this row; the face row above already carries who is in the group.
Widget _provenance(
  BuildContext context,
  GroupWeeklyMenuViewModel vm,
  WeeklyMenuPlanEntry entry,
) {
  final theme = Theme.of(context);
  final parts = <String>[];

  final proposer = entry.proposedBy;
  if (proposer != null) {
    // A uid is never rendered. An unresolved profile drops the half it names
    // rather than the whole row — the vote count is still true.
    final name = vm.displayNameFor(proposer);
    if (name != null && name.trim().isNotEmpty) {
      parts.add(context.l10n.groupMenuProposedBy(name));
    }
  }
  if (entry.votedInBy.isNotEmpty) {
    parts.add(context.l10n.groupMenuVotedInBy(entry.votedInBy.length));
  }
  if (parts.isEmpty) return const SizedBox.shrink();

  final label = Text(
    parts.join(' · '),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );

  // The row shows a COUNT because only one name fits it (BUT-1906 measured the
  // width). The names live one tap away — which is the whole point: Malin's
  // Art. 15 decision to export other members' voter uids rests on the app
  // actually showing them, and until this sheet existed it did not.
  if (entry.votedInBy.isEmpty) return label;

  return Semantics(
    label: context.l10n.a11yShowVoters,
    button: true,
    child: InkWell(
      onTap: () => _showVoters(context, vm, entry),
      // The visible row is one line of `bodySmall`, well under the minimum
      // touch target. Not wrapped in `TappableWrapper`: its `Center` would
      // re-centre the row in a layout that is deliberately left-aligned. A
      // control that is hard to hit shows no names, and the Art. 15 decision
      // to export other members' voter uids rests on the app showing them.
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppDimensions.minTouchTarget,
        ),
        child: Align(alignment: Alignment.centerLeft, child: label),
      ),
    ),
  );
}

void _showVoters(
  BuildContext context,
  GroupWeeklyMenuViewModel vm,
  WeeklyMenuPlanEntry entry,
) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingM),
            child: Text(
              sheetContext.l10n.groupMenuVotersTitle,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
          ),
          // Scrollable, not a bare column: a modal sheet is bounded to a
          // fraction of the viewport, so a fixed list clips — and a clipped
          // list here would mean the bigger the group, the fewer voters the app
          // actually shows, which is the one direction the Art. 15 decision
          // resting on this sheet cannot afford.
          // Listens to the viewmodel: the sheet is a separate route, so without
          // this a name that resolves after it opens stays "Okänd medlem" for
          // the life of the sheet — and the Art. 15 decision to export other
          // members' voter uids rests on this list showing their names.
          Flexible(
            child: ListenableBuilder(
              listenable: vm,
              builder: (_, _) => ListView.builder(
                shrinkWrap: true,
                itemCount: entry.votedInBy.length,
                itemBuilder: (_, index) {
                  final voter = entry.votedInBy[index];
                  final name = vm.displayNameFor(voter);
                  return ListTile(
                    key: ValueKey(voter),
                    leading: const Icon(Icons.how_to_vote_outlined),
                    // A uid is never rendered, here either — and a blank display
                    // name falls back the same way the face row does.
                    title: Text(
                      name == null || name.trim().isEmpty
                          ? sheetContext.l10n.groupMenuUnknownVoter
                          : name,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
