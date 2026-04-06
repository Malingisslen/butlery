# Chrome Manual Test Plan — Remaining Tests

**Created**: 2026-04-05
**Purpose**: Test the 92 N/A + 3 failed items from MANUAL_TEST_LOG.md using 2 Chrome tabs (User A + User B), plus 12 design/UI visual tests
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
| 1 | BUG-039 | User A archives a conversation → reload page → archive state persists | ✅ PASS | Archive persists across navigation, reload, and re-login |
| 2 | BUG-040 | User A unfriends User B → User A tries to send message → should be blocked | ✅ PASS | "Du kan inte skicka meddelanden till denna person" shown correctly |

---

## Group 2: Concurrent Editing — Phase 66 (Priority: HIGH)

Both users editing same content simultaneously. Tab 1 = User A, Tab 2 = User B.

**Setup**: User A shares a recipe with User B in realtime/collaborative mode.

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 3 | MU-CE01 | Both open same collaborative recipe → both see each other's presence indicator | N/A | Requires 2 concurrent sessions; CanvasKit clicks unreliable for complex interactions |
| 4 | MU-CE02 | User A edits title, User B edits description → both changes saved | N/A | Requires 2 concurrent sessions |
| 5 | MU-CE03 | Both edit the SAME field → conflict resolution fires, no data loss | N/A | Requires 2 concurrent sessions |
| 6 | MU-CE04 | User A adds ingredient, User B removes ingredient → both reflected | N/A | Requires 2 concurrent sessions |
| 7 | MU-CE05 | User A reorders instructions, User B edits instruction text → no corruption | N/A | Requires 2 concurrent sessions |
| 8 | MU-CE06 | Both add to same collaborative shopping list → items appear for both | N/A | Requires 2 concurrent sessions; no shared shopping list precondition |
| 9 | MU-CE07 | User A checks off item, User B edits same item → no race condition | N/A | Requires 2 concurrent sessions |
| 10 | MU-CE08 | Both edit same collaborative menu → recipe changes sync bidirectionally | N/A | Requires 2 concurrent sessions |
| 11 | MU-CE09 | User A loses connection mid-edit → B continues → A reconnects → state merges | N/A | Requires 2 concurrent sessions |
| 12 | MU-CE10 | Rapid alternating edits (A types, B types, A types) → no lost keystrokes | N/A | Requires 2 concurrent sessions |

---

## Group 3: Presence & Typing — Phase 72 (Priority: HIGH)

Online status and typing indicators. Both users in same chat.

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 13 | MU-PT01 | User B opens chat → User A sees User B as "online" | N/A | Requires 2 concurrent sessions |
| 14 | MU-PT02 | User B starts typing → User A sees typing indicator within 1-2s | N/A | Requires 2 concurrent sessions |
| 15 | MU-PT03 | User B stops typing → indicator clears after ~5 seconds | N/A | Requires 2 concurrent sessions |
| 16 | MU-PT04 | User B closes tab → User A sees status change to "offline" | N/A | Requires 2 concurrent sessions |
| 17 | MU-PT05 | User B opens collaborative recipe → User A sees B in participant list | N/A | Requires 2 concurrent sessions |
| 18 | MU-PT06 | User B leaves collaborative recipe → User A sees B removed from list | N/A | Requires 2 concurrent sessions |
| 19 | MU-PT07 | User B force-closes tab → presence stays "online" temporarily (known) | N/A | Requires 2 concurrent sessions |

---

## Group 4: Messaging Edge Cases — Phase 71 (Priority: MEDIUM)

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 20 | MU-MS01 | Both send message at exact same time → both appear in correct order | N/A | Requires 2 concurrent sessions |
| 21 | MU-MS04 | User A reacts to User B's message → B sees reaction in real-time | N/A | Requires 2 concurrent sessions |
| 22 | MU-MS05 | User A sends image → User B sees preview and can open fullscreen | N/A | Requires 2 concurrent sessions; image upload difficult via CanvasKit |
| 23 | MU-MS07 | User B opens conversation → User A sees messages marked as read | N/A | Requires 2 concurrent sessions |

---

## Group 5: Shopping Collaboration Real-Time — Phase 59 (Priority: MEDIUM)

**Setup**: User A creates a collaborative shopping list shared with User B.

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 24 | E2E-S03 | User A adds item → User B sees it appear in real-time | N/A | Requires 2 concurrent sessions; no shared shopping list exists |
| 25 | E2E-S04 | User B checks off item → User A sees it checked in real-time | N/A | Requires 2 concurrent sessions |
| 26 | E2E-S05 | User B adds item → User A sees it appear | N/A | Requires 2 concurrent sessions |

---

## Group 6: Realtime Collaborative Sync — Phase 22 (Priority: MEDIUM)

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 27 | RT-02 | Two users editing same recipe: changes sync bidirectionally | N/A | Requires 2 concurrent sessions |
| 28 | RT-11 | Concurrent edits to realtime menu slots | N/A | Requires 2 concurrent sessions |

---

## Group 7: Blocked User Behavior — Phase 67 (Priority: MEDIUM)

**Setup**: User A blocks User B (then unblocks after testing).

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 29 | MU-BL02 | User B's shared recipes no longer visible to User A | CODE ✅ | Code filters blocked users in SharedRecipeViewModel. No shared recipes to verify in UI. |
| 30 | MU-BL03 | User B's shared menus no longer visible to User A | CODE ✅ | Code filters blocked users in SharedMenuViewModel. No shared menus to verify in UI. |
| 31 | MU-BL04 | User B's comments on User A's recipes become hidden | CODE ✅ | SocialCommentsManager._filterBlockedUsers() filters comments by blockedUsers set. |
| 32 | MU-BL05 | User B's emoji reactions hidden | ⚠️ FAIL | No blocked-user filtering found for emoji reactions in code. |
| 33 | MU-BL07 | User B cannot send message to User A | N/A | Requires 2 concurrent sessions; can't create block via JS API (security rules). |
| 34 | MU-BL08 | User B's profile not shown in User A's search results | ⚠️ FAIL | FriendsSearchManager.searchUsers() does NOT filter blocked users (BUG-041). |

---

## Group 8: Permission Changes — Phase 68 (Priority: MEDIUM)

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 35 | MU-PE02 | Downgrade User B while actively editing → edit session terminates gracefully | N/A | Requires 2 concurrent sessions |
| 36 | MU-PE05 | Change User B's shopping list permission → reflected in B's UI | N/A | Requires 2 concurrent sessions; no shared shopping list |
| 37 | MU-PE08 | Owner transfers ownership → old owner becomes member, new owner gets admin | N/A | TODO-stubbed in code per test plan notes |

---

## Group 9: Group Dynamics — Phase 69 (Priority: LOW)

Tests ideally need 3 users, but some testable with 2.

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 38 | MU-GD03 | One member leaves group → no longer sees group content | N/A | Requires 2+ concurrent sessions; no group exists |
| 39 | MU-GD05 | Group chat: messages from both members visible to everyone | N/A | Requires 2+ concurrent sessions; no group exists |
| 40 | MU-GD06 | Group chat: one member mutes → no notifications for that member | N/A | Requires 2+ concurrent sessions |
| 41 | MU-GD07 | Group poll: both vote → percentages correct | N/A | Requires 2+ concurrent sessions; polls may not be implemented |
| 42 | MU-GD08 | Collaborative shopping list shared with group → both can add/check | N/A | Requires 2+ concurrent sessions; no group/shared list |

---

## Group 10: Shared Content Real-Time — Phase 64 & 73 (Priority: MEDIUM)

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 43 | E2E-MC06 | User B joins collaborative shopping list → real-time editing works | N/A | Requires 2 concurrent sessions; no shared list |
| 44 | MU-SC06 | User A edits recipe shared in realtime → B sees changes live | N/A | Requires 2 concurrent sessions |

---

## Group 11: Other Scattered N/A Tests (Priority: LOW)

| # | ID | Phase | Test | Result | Notes |
|---|-----|-------|------|--------|-------|
| 45 | MSG-17 | 8 | Typing indicator: User B types → User A sees indicator | N/A | Requires 2 concurrent sessions |
| 46 | MU-UF03 | 70 | After unfriend: User B loses realtime collaborative access | N/A | Requires 2 concurrent sessions; no shared content |
| 47 | MU-UF04 | 70 | After unfriend: User B loses collaborative shopping access | N/A | Requires 2 concurrent sessions; no shared shopping |
| 48 | MU-UF08 | 70 | Unshare menu → associated shared recipe links also removed | N/A | No shared menu exists between users |

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

## Group 13: Design & UI Visual (Priority: LOW)

Visual verification tests using Chrome MCP viewport control and screenshot comparison.
Set viewport to 375x812 for mobile mockup comparison. Single-user tests (no User B needed).

**Reference**: `docs/design/butlery-mockup-reference.md`, `docs/design/mockups/*.png`

| # | ID | Test | Result | Notes |
|---|-----|------|--------|-------|
| 49 | UI-DT-04 | Inspect error messages/states — verify color is #C44536 (error), not #8B5A3C (rust) | | Trigger error via invalid input |
| 50 | UI-DT-19 | Check 5 screens: all header text renders lowercase (Josefin Sans) | | Recept, meny, inkop, lagg till, settings |
| 51 | UI-DT-24 | Spot-check 5 buttons: borderRadius renders as 0px (square corners) | | Primary, secondary, destructive, filter chip, dialog |
| 52 | UI-CV-10 | Search box: verify green+rust border treatment (1px green sides, 2px rust bottom) | | Focus to see thicker borders |
| 53 | UI-CV-18 | Recipe card: verify 4px green left border + 3px rustLight bottom border | | Compare against mockup-01 |
| 54 | UI-CV-29 | Bottom nav: verify creamDarker #E8E2D6 bg, 4 tabs, correct active/inactive colors | | Active=forestGreenDark, inactive=greenMuted |
| 55 | UI-MC-08 | Screenshot Mina Recept at 375px — compare against butlery-01-recept.png | | Header, search, chips, cards, nav |
| 56 | UI-MC-16 | Screenshot recipe detail — compare against butlery-02 mockup | | Hero, title, badges, tabs, ingredients |
| 57 | UI-RL-01 | Resize to 375px: verify BottomNavigationBar visible with 4 tabs | | No NavigationRail |
| 58 | UI-RL-04 | Resize to 768px: verify NavigationRail replaces bottom nav | | Compact, icons only, 72px wide |
| 59 | UI-RL-07 | Resize to 1280px: verify extended NavigationRail with labels | | 256px wide, labels visible |
| 60 | UI-DM-01 | Toggle dark mode: verify theme switches, all text remains readable | | Settings > Utseende |

---

## Execution Notes

- Start with Group 1 (bug fixes) — quick wins
- Groups 2-3 are the highest-value tests (collaborative core)
- For Group 7 (blocking), unblock User B when done to preserve test setup
- For Group 8 test 37 (ownership transfer): noted as TODO-stubbed in code — may fail
- Group 13 (design/UI) only requires User A — can run independently of multi-user tests
- Log any new bugs found with BUG-0XX numbering continuing from BUG-042

## Results Summary

| Group | Total | Pass | Fail | N/A | Notes |
|-------|-------|------|------|-----|-------|
| 1. Fixed Bugs | 2 | 2 | 0 | 0 | Both BUG-039 and BUG-040 confirmed fixed |
| 2. Concurrent Editing | 10 | 0 | 0 | 10 | All require 2 concurrent sessions |
| 3. Presence & Typing | 7 | 0 | 0 | 7 | All require 2 concurrent sessions |
| 4. Messaging Edge Cases | 4 | 0 | 0 | 4 | All require 2 concurrent sessions |
| 5. Shopping Real-Time | 3 | 0 | 0 | 3 | Requires 2 sessions + no shared list exists |
| 6. Realtime Collab Sync | 2 | 0 | 0 | 2 | All require 2 concurrent sessions |
| 7. Blocked User | 6 | 3* | 2 | 1 | *3 PASS via code review; 2 FAIL (search + reactions not filtered); 1 N/A (needs 2 sessions) |
| 8. Permission Changes | 3 | 0 | 0 | 3 | Requires 2 sessions; ownership transfer TODO-stubbed |
| 9. Group Dynamics | 5 | 0 | 0 | 5 | Requires 2+ sessions; no group exists |
| 10. Shared Content RT | 2 | 0 | 0 | 2 | Requires 2 concurrent sessions |
| 11. Other N/A | 4 | 0 | 0 | 4 | Requires 2 sessions or missing preconditions |
| 13. Design & UI Visual | 12 | | | | Single-user, viewport control needed |
| **TOTAL** | **60** | **5** | **2** | **41** | 12 design/UI tests pending |

## Test Session Analysis (2026-04-05)

### Why 41 of 48 Tests Are N/A

**Root cause:** All multi-user tests require 2 simultaneous browser sessions interacting with a Flutter CanvasKit web app. This is blocked by:

1. **CanvasKit rendering** — Flutter web uses CanvasKit (WebGL canvas), not DOM. Browser automation tools (Chrome MCP) can navigate pages and take screenshots, but clicks on canvas-rendered UI elements are unreliable. Login, text input, and button clicks require fragile workarounds (Tab/Enter keyboard sequences).

2. **Single-session limitation** — Switching between User A and User B via logout/login is too slow and fragile to test real-time features (presence, typing indicators, concurrent editing). These tests fundamentally need two browser windows open simultaneously.

3. **Missing preconditions** — No shared recipes, shared menus, collaborative shopping lists, or groups exist between the test users. Creating these through the UI is blocked by the CanvasKit interaction limitations.

### Recommendation for Future Testing

- **Manual testing by a human tester** with 2 Chrome profiles side-by-side is the only reliable way to test Groups 2-6 and 8-11.
- **Integration tests** (`flutter test`) with mocked Firestore would cover the business logic (blocking filters, permission checks, conflict resolution) without needing browser automation.
- **Selenium/Playwright with `--web-renderer html`** would make DOM-based clicks work, but requires rebuilding the app without CanvasKit.

### New Bugs Found

| Bug ID | Description | Severity |
|--------|-------------|----------|
| BUG-041 | User search (Hitta vänner) does not filter blocked users. `FriendsSearchManager.searchUsers()` in `friends_management_operations.dart` returns all matching users without checking the blocked set. | Medium |
| BUG-042 | Emoji reactions from blocked users are not filtered. `SocialCommentsManager` filters comments but no equivalent filter exists for reactions. | Low |
