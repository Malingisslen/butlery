# Sprint Backlog

## Sprint: iter-60 — BUT-952 mark-all-as-read service primitive + overflow action — 2026-05-24 (Sun)

Theme: Bulk-mark notifications as read. Sub-fix 1 of 2 from ticket (overflow + service); sub-fix 2 (long-press selection mode) deferred — UX. Plan-fil FÖRST.

### Step 0 — premise verification

- Ticket cites `notifications_viewmodel.dart:68 markAsOpened()` as single-id only — confirmed (line 68-86, single notificationId).
- No `markAllAsOpened` on `NotificationHistoryRepository` interface (line 17 has only single `markNotificationOpened`).
- `notifications_view.dart` overflow location — need to check.

### Design choices

- **Repo primitive**: add `markAllAsOpenedForUser(String userId)` to `NotificationHistoryRepository` + Firebase impl. Batched WriteBatch with `where('userId', isEqualTo: userId).where('opened', isEqualTo: false)` query, ~500-doc chunks via existing `firestore_batch_utils`.
- **Service-layer pass-through**: `NotificationService.markAllHistoryNotificationsOpened()` → delegates to repo.
- **VM method**: `notifications_viewmodel.markAllAsOpened()` does optimistic local update on `_entries` + fire-and-forget service call.
- **Overflow action**: add to notifications_view app-bar overflow.
- **Skip dialog**: low-stakes mark-as-read (vs delete) — no confirmation needed; matches "mark all read" UX in other apps.
- **Skip "Dismiss" sub-fix + long-press selection mode**: ticket calls out as separate concern (UX for selection mode). File follow-up.
- **l10n**: new `notificationsMarkAllRead` (sv + en).

### Ship this sprint

- [ ] **A1. Repo interface + impl**: `markAllAsOpenedForUser(String userId)` — batched update.
- [ ] **A2. Service**: `markAllHistoryNotificationsOpened()` pass-through.
- [ ] **A3. VM**: `markAllAsOpened()` — optimistic + service call.
- [ ] **A4. View**: overflow `PopupMenuButton` action in `notifications_view.dart`.
- [ ] **A5. ARB**: `notificationsMarkAllRead`.
- [ ] **A6. gen-l10n**.
- [ ] **A7. Follow-up**: file BUT-XXXX for long-press selection mode + dismiss action.

### Acceptance

- [ ] Tap overflow → "Mark all as read" → all unread → read with single batched write.
- [ ] Local list updates immediately (optimistic).
- [ ] `flutter analyze` clean.

### Post-Sprint Steps

- [ ] Commit + push (firebase-backend-security gate may trigger on repo change)
- [ ] Stäng BUT-952 i Linear → Done (partial: bulk-read done, long-press selection in follow-up)

---

## Archived iter-59 (commit `a891ee724`) — 2026-05-24 (Sun)

BUT-937 cook-snap delete undo. Snackbar pattern mirror nr 3 (after BUT-932 + BUT-943). +69 / -19. BUT-937 → Done.
