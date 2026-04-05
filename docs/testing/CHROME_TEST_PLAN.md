# Chrome Manual Test Plan — Remaining Tests

**Created**: 2026-04-05
**Purpose**: Test the 92 N/A + 3 failed items from MANUAL_TEST_LOG.md using 2 Chrome tabs (User A + User B)
**Credentials**: User A: malin.gisslen1@gmail.com / Test1234 | User B: test.testsson2@gmail.com / TestPass123!

## Pre-Flight

- [ ] App running in Chrome (`flutter run -d chrome`)
- [ ] Tab 1: User A logged in
- [ ] Tab 2: User B logged in (incognito or separate profile)
- [ ] Both users are friends
- [ ] At least 1 collaborative recipe exists between them

---

## Group 1: Re-Verify Fixed Bugs (Priority: HIGH)

These failed during original testing but bugs were fixed. Confirm fixes work.

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 1 | BUG-039 | User A archives a conversation → reload page → archive state persists | | |
| 2 | BUG-040 | User A unfriends User B → User A tries to send message → should be blocked | | |

---

## Group 2: Concurrent Editing — Phase 66 (Priority: HIGH)

Both users editing same content simultaneously. Tab 1 = User A, Tab 2 = User B.

**Setup**: User A shares a recipe with User B in realtime/collaborative mode.

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 3 | MU-CE01 | Both open same collaborative recipe → both see each other's presence indicator | | |
| 4 | MU-CE02 | User A edits title, User B edits description → both changes saved | | |
| 5 | MU-CE03 | Both edit the SAME field → conflict resolution fires, no data loss | | |
| 6 | MU-CE04 | User A adds ingredient, User B removes ingredient → both reflected | | |
| 7 | MU-CE05 | User A reorders instructions, User B edits instruction text → no corruption | | |
| 8 | MU-CE06 | Both add to same collaborative shopping list → items appear for both | | |
| 9 | MU-CE07 | User A checks off item, User B edits same item → no race condition | | |
| 10 | MU-CE08 | Both edit same collaborative menu → recipe changes sync bidirectionally | | |
| 11 | MU-CE09 | User A loses connection mid-edit → B continues → A reconnects → state merges | | |
| 12 | MU-CE10 | Rapid alternating edits (A types, B types, A types) → no lost keystrokes | | |

---

## Group 3: Presence & Typing — Phase 72 (Priority: HIGH)

Online status and typing indicators. Both users in same chat.

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 13 | MU-PT01 | User B opens chat → User A sees User B as "online" | | |
| 14 | MU-PT02 | User B starts typing → User A sees typing indicator within 1-2s | | |
| 15 | MU-PT03 | User B stops typing → indicator clears after ~5 seconds | | |
| 16 | MU-PT04 | User B closes tab → User A sees status change to "offline" | | |
| 17 | MU-PT05 | User B opens collaborative recipe → User A sees B in participant list | | |
| 18 | MU-PT06 | User B leaves collaborative recipe → User A sees B removed from list | | |
| 19 | MU-PT07 | User B force-closes tab → presence stays "online" temporarily (known) | | |

---

## Group 4: Messaging Edge Cases — Phase 71 (Priority: MEDIUM)

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 20 | MU-MS01 | Both send message at exact same time → both appear in correct order | | |
| 21 | MU-MS04 | User A reacts to User B's message → B sees reaction in real-time | | |
| 22 | MU-MS05 | User A sends image → User B sees preview and can open fullscreen | | |
| 23 | MU-MS07 | User B opens conversation → User A sees messages marked as read | | |

---

## Group 5: Shopping Collaboration Real-Time — Phase 59 (Priority: MEDIUM)

**Setup**: User A creates a collaborative shopping list shared with User B.

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 24 | E2E-S03 | User A adds item → User B sees it appear in real-time | | |
| 25 | E2E-S04 | User B checks off item → User A sees it checked in real-time | | |
| 26 | E2E-S05 | User B adds item → User A sees it appear | | |

---

## Group 6: Realtime Collaborative Sync — Phase 22 (Priority: MEDIUM)

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 27 | RT-02 | Two users editing same recipe: changes sync bidirectionally | | |
| 28 | RT-11 | Concurrent edits to realtime menu slots | | |

---

## Group 7: Blocked User Behavior — Phase 67 (Priority: MEDIUM)

**Setup**: User A blocks User B (then unblocks after testing).

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 29 | MU-BL02 | User B's shared recipes no longer visible to User A | | |
| 30 | MU-BL03 | User B's shared menus no longer visible to User A | | |
| 31 | MU-BL04 | User B's comments on User A's recipes become hidden | | |
| 32 | MU-BL05 | User B's emoji reactions hidden | | |
| 33 | MU-BL07 | User B cannot send message to User A | | |
| 34 | MU-BL08 | User B's profile not shown in User A's search results | | |

---

## Group 8: Permission Changes — Phase 68 (Priority: MEDIUM)

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 35 | MU-PE02 | Downgrade User B while actively editing → edit session terminates gracefully | | |
| 36 | MU-PE05 | Change User B's shopping list permission → reflected in B's UI | | |
| 37 | MU-PE08 | Owner transfers ownership → old owner becomes member, new owner gets admin | | |

---

## Group 9: Group Dynamics — Phase 69 (Priority: LOW)

Tests ideally need 3 users, but some testable with 2.

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 38 | MU-GD03 | One member leaves group → no longer sees group content | | |
| 39 | MU-GD05 | Group chat: messages from both members visible to everyone | | |
| 40 | MU-GD06 | Group chat: one member mutes → no notifications for that member | | |
| 41 | MU-GD07 | Group poll: both vote → percentages correct | | |
| 42 | MU-GD08 | Collaborative shopping list shared with group → both can add/check | | |

---

## Group 10: Shared Content Real-Time — Phase 64 & 73 (Priority: MEDIUM)

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 43 | E2E-MC06 | User B joins collaborative shopping list → real-time editing works | | |
| 44 | MU-SC06 | User A edits recipe shared in realtime → B sees changes live | | |

---

## Group 11: Other Scattered N/A Tests (Priority: LOW)

| # | ID | Phase | Test | Result | Notes |
|---|-----|-------|------|--------|-------|
| 45 | MSG-17 | 8 | Typing indicator: User B types → User A sees indicator | | |
| 46 | MU-UF03 | 70 | After unfriend: User B loses realtime collaborative access | | |
| 47 | MU-UF04 | 70 | After unfriend: User B loses collaborative shopping access | | |
| 48 | MU-UF08 | 70 | Unshare menu → associated shared recipe links also removed | | |

---

## Group 12: Web-Only N/A — NOT TESTABLE in Chrome

These remain N/A due to platform limitations, not session count:

| ID | Reason |
|----|--------|
| AUTH-08 | MFA settings — post-beta feature |
| REC-18/19 | Image upload not automatable on web |
| IMP-05/06/07/08 | File upload / photo import N/A on web |
| A11Y-06 | Keyboard nav — CanvasKit limitation |
| ONB-11 | Landscape layout N/A on web viewport |
| GDPR-07 | Share sheet N/A on web |
| GDPR-15 | Blocked user content visibility (code gap, not session issue) |
| SESS-06 | App backgrounded — N/A on web |
| BAK-01 | Export to file — Android/iOS only |
| BAK-07 | Overwrite option — not implemented |
| DL-07 | Expired link — not wired in code |
| REACT-07 | Reactions on shared content — not implemented |
| MOD-06/07 | Rate limiting / content filter — not implemented |
| AIFL-02/03/04/05 | Feature flag UI gates — not implemented |
| E2E-I01 | URL import CORS — web limitation (BUG-037) |
| E2E-I03 | Unknown ingredient dialog — not wired to save flow |
| E2E-FH02 | URL import CORS — same as above |
| E2E-A06/A07 | Account deletion — would destroy test account |
| SCM-04/05/06/07/08 | Audit log, parsing correction, re-consent — not implemented |
| OFF-10 | Queued changes count — no UI |
| LANG-06 | timeago hardcoded 'sv' |
| FPROF-07 | Block not in profile UI |

---

## Execution Notes

- Start with Group 1 (bug fixes) — quick wins
- Groups 2-3 are the highest-value tests (collaborative core)
- For Group 7 (blocking), unblock User B when done to preserve test setup
- For Group 8 test 37 (ownership transfer): noted as TODO-stubbed in code — may fail
- Log any new bugs found with BUG-0XX numbering continuing from BUG-040

## Results Summary

| Group | Total | Pass | Fail | N/A | Notes |
|-------|-------|------|------|-----|-------|
| 1. Fixed Bugs | 2 | | | | |
| 2. Concurrent Editing | 10 | | | | |
| 3. Presence & Typing | 7 | | | | |
| 4. Messaging Edge Cases | 4 | | | | |
| 5. Shopping Real-Time | 3 | | | | |
| 6. Realtime Collab Sync | 2 | | | | |
| 7. Blocked User | 6 | | | | |
| 8. Permission Changes | 3 | | | | |
| 9. Group Dynamics | 5 | | | | |
| 10. Shared Content RT | 2 | | | | |
| 11. Other N/A | 4 | | | | |
| **TOTAL** | **48** | | | | |
