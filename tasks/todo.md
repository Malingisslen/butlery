# Sprint Backlog

## Sprint: iter-50 — BUT-919 persist group-creation form draft — 2026-05-24 (Sun)

Theme: Fourth application of draft-persistence pattern. JSON-payload variant — first multi-field form in the series. Plan-fil FÖRST per discipline.

### Step 0 — premise verification

- BUT-919 ticket valid: `lib/widgets/social/groups/create_group_dialog.dart:27-117` — name/description/emoji/selectedFriendIds all in-memory via `_CreateGroupDialogState`.
- Two consumers exist: `CreateGroupDialog` (StatefulWidget — own state, not VM-backed) and `CreateGroupViewModel` (parallel path, less wired). The dialog is the actively-used surface (`friends_list_view.dart` opens it via `SocialGroupComponents.showCreateGroupDialog`). Targeting the dialog.
- Pattern variant: this is a **multi-field form** — name + description + emoji + friend IDs Set. Serialize as JSON map, not single string.

### Design choices

- **Storage shape**: single SharedPreferences key `group_creation_draft_v1`, value = `jsonEncode({'name': ..., 'description': ..., 'emoji': ..., 'friendIds': [...]})`.
- **No persist when `preSelectedMembers` passed**: external callers (e.g. "create group from these friends" flow) pre-seed selection. Honor the caller's intent — fresh form, don't load saved.
- **Clear on successful create**: when `Navigator.pop(createdCategory)` happens with non-null result, drop the draft. Don't clear on cancel — user may want to resume.
- **Eager save on each field change**: name/description via `onChanged`, emoji via `onEmojiSelected`, friends via `_onFriendSelectionChanged`. Each calls `_saveDraft()` which re-serializes the whole map (no per-field key proliferation).
- **Load triggers setState** to reflect controllers + selection state. Use a `_isInitialized` flag to avoid re-loading on rebuild.

### Ship this sprint

- [ ] **A1. BUT-919** — Persist group-creation form draft.
  - Add `_draftPrefsKey = 'group_creation_draft_v1'` const + 3 helpers (`_loadDraft`, `_saveDraft`, `_clearDraft`).
  - `initState`: if `widget.preSelectedMembers == null` → post-frame async load.
  - `_loadDraft`: parse JSON, set `_nameController.text`, `_descriptionController.text`, `_selectedEmoji`, `_selectedFriendIds`. setState to reflect. Friends list reconstruction will be lazy (resolution to UserProfile happens via `_selectedFriendIds`-driven UI; `_selectedFriends` repopulates on next selection change OR via friends-service lookup if time permits — simpler: store IDs only, re-resolve on demand from FriendsService).
  - Wire all 4 mutators (`_nameController` listener via `addListener`, `_descriptionController` listener, `setState`-blocks for emoji + friend selection) to call `_saveDraft()`.
  - `_createGroup` success path (after `Navigator.pop(createdCategory)`): `await _clearDraft()`.
  - Dispose: controller-only.

### Acceptance

- [ ] User fills name + selects 8 friends → backgrounds app → returns to dialog → all data restored.
- [ ] User completes create → dialog opens again later → blank form.
- [ ] User cancels dialog without create → opens dialog again → draft restored.
- [ ] Caller passes `preSelectedMembers` → draft NOT loaded (pre-selection wins).

### Post-Sprint Steps

- [ ] `flutter analyze` clean
- [ ] Commit + push
- [ ] Stäng BUT-919 i Linear → Done

---

## Archived iter-49 (commit `feb2622ba`) — 2026-05-24 (Sun)

BUT-911 URL-import draft persist (3rd application of pattern). Single global key `url_import_draft_v1`. +80 / -25. BUT-911 → Done.
