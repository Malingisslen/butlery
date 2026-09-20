# Sprint 2026-09-20 runda 3 (sprint-execute, /loop, unattended)

Three weekly-menu bugs opened by BUT-1975's removal of the write lock, all in the same
viewmodel. Step-0 read confirms each premise on current main, and that `_publishThenSave`
(the optimistic publish-then-save helper BUT-1975 introduced) already exists and is what the
first two should use rather than a new lock.

Router (`lib/viewmodels/menu/weekly_menu_plan_viewmodel.dart
lib/services/menu/weekly_menu_plan_service.dart lib/widgets/menu/menu_placement_footer.dart`):
paste the raw output beside the batch before dispatch.

- [ ] BUT-1988 [Tier C] build — two quick "who's home" taps must both survive.
  Today `setSlotPresence`/`setDayPresence` are read-modify-write in the SERVICE: it re-reads
  the week, merges one cell and saves the whole plan, so two taps that read the same week
  lose one. Fix in BUT-1975's shape: expose the service's pure merge, compute the updated
  plan from `_plan` in the viewmodel, and publish it through `_publishThenSave`, which
  releases at publish (not at ack) and rolls back on refusal. The merge stays in ONE place —
  duplicating it in the viewmodel was explicitly out of scope in BUT-1975.
  - AC1 (diff): two presence writes on different cells, the second starting before the first
    save completes, leave BOTH selections set.
  - AC2 (diff): the existing test "a pending PRESENCE save does not refuse a calendar edit"
    stays green — no new shared lock.
  - AC3 (diff): a refused presence save restores the previous selection, and only when the
    plan on screen is still the one that was published.
- [ ] BUT-1987 [Tier B] build — a second tap on "Placera automatiskt" must not be a silent
  no-op. Take option 1 from the ticket (disable the button while the distribution is in
  flight); do NOT call `setError` in the refusal branch — that was tried under BUT-1975 and
  replaced the whole calendar with an error panel.
  - AC1 (diff): the viewmodel exposes the in-flight state and notifies when it changes.
  - AC2 (diff): the footer's action is disabled while it is true; a widget test pins it.
  - AC3 (diff): the refusal branch still sets no error.
- [ ] BUT-1986 [Tier A] build — offline, the same overflow chip can be placed twice because
  the tray is pruned only after the save acks. Prune optimistically and put the chip back if
  the save is refused, matching how `_plan` itself is treated.
  - AC1 (diff): a second drop of the same chip while the first save is unacked does not add a
    second entry.
  - AC2 (diff): a refused save puts the chip back in the tray (the tray is in-memory only and
    nothing repopulates it).

## Needs you (Tier D)
- none this run.

## Deviation log
