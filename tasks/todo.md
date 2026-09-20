# Sprint 2026-09-20 runda 4 (sprint-execute, /loop, unattended)

Two shopping tickets, both written with the fix already specified by the reviewer who
filed them. Step-0 confirms both premises on current main (the files moved since the
tickets were written; the code did not).

**Learned last round, applied here:** before dispatching any reviewer, grep the whole
fileset for sentences that ENUMERATE what this change removes — "ONLY", "the two methods
above", "this class still does", "until then" — and strike them in the same edit. Six
review rounds last batch were spent one sentence at a time.

- [!] BUT-1890 [Tier B] WITHDRAWN mid-run — built, then pulled after measurement — the add-item dialog's `_CategorySuggester` is a second,
  stale copy of `IngredientCategorizer`. Measured wrong answers: Rostbiff → dairy,
  Ostbågar → dairy, Kokosmjölk → dairy, Diskborste → drinks, Vitlökspulver → fruit_veg.
  Route it through the maintained engine and delete the private map.
  - AC1 (diff): the five measured names get the right category, proven by a running test.
  - AC2 (diff): the private keyword map is gone.
  - AC3 (diff): `IngredientCategorizer.categorize` returns `other`, never null, and the
    dialog relies on null to leave the field alone — the delegation must not stamp `other`
    onto every unrecognised item.
  - AC4 (diff): the comment and the test-suite header that describe the duplicate are
    removed in the same change, plus any other sentence this deletion falsifies.
- [x] BUT-1892 [Tier A] build — a cleared shopping-item note is stored as `''` rather than
  `null`, and `notes: result.note ?? ''` is sent on EVERY save, so rows drift to `''` over
  time and "cleared" stops being distinguishable from "never had one".
  - AC1 (diff): a cleared note is stored as `null`.
  - AC2 (diff): editing another field on an item with no note leaves `note` untouched.
  - AC3 (diff): the existing `an empty note CLEARS the stored note` test is rewritten to the
    new signal and stays mutation-sensitive.
  - AC4 (diff): `personal_shopping_operations.dart`'s twin `?? item.note` follows, or the
    fix covers only one of the two list types.

## Needs you (Tier D)
- none this run.

## Deviation log
- [needs-human] BUT-1890: the plan said route the suggester and delete the duplicate. Built and probed, then WITHDRAWN when the code-reviewer gate ran `IngredientCategorizer.categorize` over the deleted map's vocabulary and found most of those names now answer `other`, i.e. lose their suggestion — in buckets the engine already has, not just the ones I had measured. Replacing behaviour that works with something I picked is Malin's call, so the code is unshipped and BUT-2127 carries the measured table and three options.
- [deviation] BUT-1892's plan named two write paths as if both were live. Measured: `PersonalShoppingOperations.updateItem` has no `lib/` caller; the twin fix is symmetry. Said so in the commit body rather than letting the claim stand.
- [discovery] `ShoppingListGenerator` writes `note: ''` on every recipe-generated row (`grep -rn "note: ''" lib`) — a second producer the ticket did not know about. Noted on BUT-1892, not fixed here.
- [deviation] Five comment clauses this change falsified were struck across four gate rounds. The pre-dispatch grep the round-3 lesson prescribes caught none of them, because they were sentences the REVIEWERS' own findings falsified, not ones the code deletion did.
