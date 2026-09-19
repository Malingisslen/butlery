# firestore-rules-tester — chapter: prose-claims

  **A comment bounding that oracle by calling the id "unguessable"/"random" is a claim about
  EVERY MINTING PATH, and a collection usually has more than one** — group conversation ids
  are a Firestore auto-id from `createChatGroupWithDeps` AND a
  `sha256(ownerId:categoryId)[:20]` digest from `ensureCategoryChat`, so "group ids are
  random" is false for the second while the SAFETY conclusion still holds (the digest eats a
  v4 UUID). Grep every caller that supplies a doc id before passing such a sentence, and
  strike the mechanism word rather than rewording it — the operative clause is which ids an
  attacker can CONSTRUCT from what they already hold.
  **Naming WHO an existence oracle discloses to is an exhaustive quantifier over every way a
  uid falls OUT of a denormalised membership snapshot, and a join-shaped answer covers half
  of them.** `group_weekly_menu_plans.memberPermissions` is seeded from
  `conversation.participantIds` at first build and never re-synced, so LATE JOINERS miss the
  older weeks — and DEPARTED members miss every week planned after they left, since
  `removeChatGroupMember` edits no plan and `deleteGroupMenuPlans` fires only when the group
  EMPTIES. Both still hold the id. Enumerate the snapshot's writers and its non-writers
  (removal paths, cascades) before passing any "it discloses to X" sentence; when the true
  set needs measuring, STRIKE the enumeration and keep the direction plus the decision line
  (BUT-1971, 2026-08-29 — fifth wrong wording of one sentence, each round fixing the last).
- **A reachability claim about a rule spreads to EVERY file that touches the feature — rules comment, test comment, ADR,
  deviation entry, widget comment — so a finding filed against one is only part-fixed, and
  each review round tends to surface one more carrier: BUT-1831's rules-side sentence was
  struck while the identical claim rode into the same commit at test C7B, and BUT-1904's
  survived four rounds, the last carrier sitting in `firestore.rules` directly above the
  rule it misdescribed. Sweep by grepping the CLAIM's own keywords repo-wide, never by
  fixing the copy you happened to notice.** Grep the test file for the claim's keywords whenever a rules comment is
  corrected, and the reverse. **The nearest carrier is inside the SAME paragraph you just
  repaired**: a struck universal ("the write side denies a blocked caller") came back four
  lines below its own retraction, as "what that person may DO is cut", in the very entry whose
  new residual says not to read it that way — so a decision record can contradict itself within
  one bullet. After striking a claim, re-read the WHOLE entry to its end, not the sentence you
  replaced (BUT-2054, 2026-09-09). **And re-read the SURVIVOR standalone: a strike can delete
  the clause that SCOPED a neighbouring sentence, promoting a sentence that was true of the
  file's OLD state into a false claim about its current one.** Measured on
  `household_allergen_shares` (2026-09-16): "widening `duration.value(10, 'm')` to an hour
  reddens nothing" was true before the window cases existed, and the strike of the sentence
  that scoped it to that state left it standing as an unqualified claim the very cases in the
  paragraph below it refute (60m reddens two). The hazard is created BY the correction, so a
  second strike is the fix — never a replacement measurement. **Split that sweep by TENSE
  AND DATE, not by paragraph: an explicitly dated clause ("as of <date>, X") is a claim
  about a PAST state and a change cannot falsify it, while the same mechanism clause in the
  PRESENT tense ("the CF NOW deletes X") is exactly what a removal breaks.** Measured on
  BUT-1850, where one comment block held both and only the "now" clause had to go; note
  that strike NARROWED the surviving claim, the safe direction, unlike the broadening case
  above. Verify such a survivor by opening the function it asserts about: a claim about a
  Cloud Function is not readable from the trigger file when the write is staged by a helper
  (`stageMemberRemoval`), and a helper DEFINED in that file can have no call site in it
  (`tryClearRoster`). **Sweep it by STRIKE-AND-POINT, never by writing the
  correction into both files** — the copy names the canonical site ("the account lives at
  the rule itself; do not restate it here") and makes no claim of its own, so there is one
  thing to re-measure instead of two that drift. **Sweep the keywords, not the comment
  syntax: a co-carrier hides in a TEST NAME, which no `//`-anchored grep reaches** — the
  group-menu integration suite still names `participantUserIds` as a field "so Firestore
  rules can enforce per-user access" after the rules-side sentence saying so was struck
  (BUT-1971, 2026-08-30). **And the test for a false GATING claim is not "does any limb
  READ field X" but "does any limb DECIDE ACCESS on X"** — `participantUserIds` and
  `participants` both appear in that block, in `hasRequiredFields` and in the update's
  `affectedKeys().hasAny([...])` guard, so a presence grep answers YES while the gating
  claim is still false; membership is tested only against `memberPermissions`, and
  `participants[].permission` is read nowhere. Verify the pointer RESOLVES FOR EVERY SYMBOL THE SENTENCE RANGES OVER: open the
  named limb/test and confirm it carries the account for each one. A rules-suite header
  saying "the constructor half is pinned in Dart by <test>" after describing BOTH
  `WeeklyMenuPlan.empty` and `GroupWeeklyMenuPlan.empty` held for the personal one only.
  Resolve a pointer per symbol, or you have replaced a false claim with a
  dangling one — and read the SYMBOL that account names, not only its conclusion: a class can
  carry the very case the account says it lacks, on a DIFFERENT switch (ADR-0009 credited
  `ChatActionHandler` with no `'menu'` case; `handleAttachment` has one, and the dead switch
  is `handleMessageAction`). **And scope the claim to the AFFORDANCE it was measured on: "no screen
  reaches this delete" was measured on the per-row long-press menu and is false for the RULE,
  because a BULK path — `deleteConversation` -> `deleteAllMessages` — reaches the same rows
  through the same client verb.** Enumerate every client caller of the verb before passing a
  reachability sentence; a bulk caller filters on the actor, never on the state the comment is
  about. Then check whether the UI RENDERS that caller at all: the tile is gated on
  `groupId == null`, so in a group chat neither path exists — a correction that stopped at
  "the bulk path reaches it" was itself false, and that was the fifth round on one sentence
  (BUT-1904, 2026-08-26).
### Rule parity, comments, and their claims
- **A comment saying a rule uses "the same test as" a sibling rule is a parity claim —
  measure it on EVERY verb, never read it.** A parent rule and its subcollection are two
  separate rules; a "same membership test" claim can hold for `read` and silently drop a
  cutoff the parent alone carries (BUT-1838's `memberSince`), leaking on `create` too.
  Enumerate every conjunct on the parent and check which the child actually inherited.
  **The same "every verb" discipline binds a ROLE claim, and DELETE is the verb it drops.**
  A test comment reading "this is the action the two roles are discriminated on; every other
  write is open to both alike" was refuted by `allow delete: … == 'admin'` in the same block
  and by a sibling deny test forty lines below it, in the same commit. Before writing a
  quantifier over roles, read create, update AND delete; a role gate is usually spelled
  `in ['edit','admin']` on the write limbs and `== 'admin'` on delete, which reads as one
  rule and is two.
- **Deleting a limb falsifies every DECISION RECORD that cites it, and the nearest carrier is
  an entry from the SAME TICKET shipped hours earlier.** BUT-1716 step 3 removed
  `shared_content/{id}/items` while step 1's entry — in the same two files the commit edits —
  still argued an Art. 15 question from "a path their own client may read
  (`allow read: hasSharedAccess(...)`)", and named residuals from an `items` update limb and
  an `items` delete limb that no longer exist. Grep the deleted limb's HELPER NAME and the
  deleted METHOD names across both deviation mirrors before calling a removal complete; the
  repair is a dated SUPERSESSION quoting each mirror's own wording (they hard-wrap
  differently), never a strike.
- **`.claude/rules/accepted-deviations.md` and `docs/architecture/ACCEPTED_DEVIATIONS.md` are
  called mirrors and are not byte-identical, so a "Retired verbatim" quote can be verbatim for
  ONE of them and absent from the other.** Found on BUT-2038: the superseding entry quoted the
  `docs/` wording into BOTH files, so in the always-on `.claude/` copy the supersession greped
  to nothing while the sentence it retired stood on undisturbed. Verify a supersession by
  locating the ORIGINAL sentence in the same file and reading it, not by counting a literal
  fragment: both mirrors hard-wrap, so the original wraps mid-phrase while the quote is
  written unwrapped and a literal grep matches only the quote. Measured on BUT-2038's own
  supersession, which is correct and counts 1 in `.claude/`. Expect each file to retire its
  OWN wording.
- **A test comment is bound to its test by POSITION only, so the test a review ASKS you to
  insert is what detaches it** — the fix for a stacked-comment finding put a new `test(` in
  between a null-case paragraph and the null-case test, leaving the paragraph heading a
  cap-binding test and the null test bare (BUT-1971, 2026-08-30). After inserting a test,
  re-read the comment ABOVE and the test BELOW the insertion point as one unit; the repair is
  a MOVE (directly readable, no measuring), never a rewrite.
- **Never state a suite TOTAL ("32/32") in a comment — it goes stale the day a test is
  added.** Name which tests move, by comment ID, instead.
- A rules comment asserting what a Cloud Function does with the document is a claim
  about another file's boolean — read that line, don't infer it from the comment
  (`enforceGroupMinorMembership`'s `isGroup` computation, BUT-1838). Same for a
  **"kept in sync with `<symbol>`" comment: it makes TWO claims — the symbol exists at
  that path, and the VALUES actually agree.** Fixing only the NAME (a comment-drift
  sweep's natural instinct) can leave a false sync claim standing, so read the literal on
  both sides and grep for OTHER mirrors the comment doesn't name — `isAccountMatured()`'s
  60 min has three (`kAccountMaturityWindow`, `kAccountMaturityWindowMs`, the rule).
  **A comment naming a DRIFT GUARD instead ("the two are compared by `<test>`") makes a
  third claim: that the guard extracts THIS literal and not an adjacent one.** Verify by
  replicating the guard's own extraction (its regex, over the same comment-stripped text)
  and printing what it captured plus how many other copies of the number exist — reading the
  regex is not verification. Then check the guard RUNS in CI (`test.yml` runs `flutter test
  test/unit`), or the pointer names a guard nothing fires. Such a comment carries a
  cross-language PATH that a rename breaks silently, so the fix for that Low is a
  RECIPROCAL pointer — the Dart constant's docstring naming the guard, as
  `GroupWeeklyMenuPlan.maxContributorUserIds`/`maxEditTrailRows` now do — not a caveat
  (BUT-1971, 2026-08-31).
  **And a drift guard's stated failure mode ("raise the Dart constant and the server denies
  the write") assumes the constant has a PRODUCTION READER — grep it before passing that
  sentence.** `maxEditTrailRows` is pruned to by the service; `maxContributorUserIds` is read
  by nothing but the guard itself, so raising it changes no write and denies nothing. The
  guard still earns its place (it keeps the numbers together for the day a prune arrives);
  what goes false is the causal clause, which gets STRUCK, not reworded (BUT-1971, 2026-08-31).
- **A sentence claiming a NEW check GAINS a capability is a claim about what the OLD check
  did in the SAME state — measure both arms, not just the one the fix was written for.**
  BUT-1917 moved a Cloud Function's orphan check from `users/{uid}` to Auth and wrote "the
  weekly pass now finds it, which it could not before" beside the residual it left. False:
  the account cascade DELETES `users/{uid}`, so for an erased account the old spelling
  answered "gone" identically — the gain belongs to the profile-delete case, a different
  residual, and got attached to this one. Second refutation from the same probe: the pass
  short-circuits on `stored === expected` BEFORE the owner check, so an orphan whose list is
  empty is never visited under either spelling. Both arms are cheap; the sentence is not.
- A decision record or comment quoting mutation-probe figures inherits their staleness
  at one remove — re-run every quoted mutant against the CURRENT file before trusting a
  written figure; arithmetic on an old run is not measurement. **The likeliest invalidator
  is the SAME round's own repair**: a suite comment justifying `clearFirestore()` with "a
  second run went 14/17, L1 sees extra rows" measured the file as it stood BEFORE the
  fixture was moved onto its own principal — after the move the stale-run failure set is
  the two ALLOWED creates alone (15/17) and the list case passes, because the extra rows
  now carry a uid its filter excludes (measured, BUT-2028). Re-run any number written
  beside a fixture you also changed, or strike it.
- **A paragraph a diff merely REWRAPS ships as new text and gets judged as new.** Two
  inherited sentences rode a rewrap into BUT-1831: one claimed a squat closed by
  `directIdBinds` was "allowed today", the other described a Cloud Function's guard that
  had moved to another collection (`onDocumentCreated` on `conversations` ->
  `onDocumentWritten` on `chat_groups`) a ticket earlier. Re-verify every sentence a diff
  touches, including the ones it did not intend to change — and note that a stale "this
  hole is OPEN" claim is often refutable by passing tests in the SAME file, which is the
  cheapest disproof available. Struck, never reworded: a truer count needs measuring.

