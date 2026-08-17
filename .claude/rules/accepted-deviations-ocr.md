---
paths:
  - "lib/services/import/**"
  - "lib/services/ocr/**"
  - "tools/corpus_split_eval.dart"
---

# Accepted Deviations — OCR, import and page splitting

Decided calls for this area, split out of `.claude/rules/accepted-deviations.md` on
2026-08-17 so they load when you open the code they govern rather than in every
session. **Do not propose them again and do not file review findings against them.**
Full rationale per entry: `docs/architecture/ACCEPTED_DEVIATIONS.md`.

A new deviation in this area is appended HERE and in that document, in the same edit.

- **TRIMMING a trailing orphan heading is BUILT at a 120-character budget; the
  120-200 band is MEASURED AND DECLINED.** `withoutOrphanTail` cuts a page at its last
  detected heading when under 120 characters follow it, applied by `ImportManager`
  BEFORE `split` — **since 2026-08-12 through `withoutFrameNoise`
  (`frame_trim.dart`), which takes this rule's decision (`orphanTailCutRow`) and
  the leading rule's from the UNTOUCHED page and cuts once; this rule's decision
  and therefore every figure below is unchanged by that, which is why the shape
  was chosen** — so `MultiRecipeSplitter` keeps its "never hands back a single
  SHORTENED block" contract (it does drop furniture when it splits; that is a separate
  promise on `split`) and the eval arm can still measure. Shipped figures over 181 gold pages,
  on top of the edge crop, from `corpus_split_eval.dart --trim`: 10 pages trimmed,
  precision 66.64 -> 66.77 %, recall 91.54 -> 91.52 %, right block counts unchanged
  at 139 (fixed 0, broke 0 — the arm prints the split, so "unchanged" is not a
  masked swap). The arm also prints WHICH ten pages, with each heading and its
  character count, so `orphan_tail.dart`'s list is checkable by command.
  **RECALL IS BIASED AGAINST THIS RULE (BUT-1818):** the gold records frame-cut half
  recipes as complete ones (14 of 242 graded, of which 11 bias recall — both FLOORS, not
  counts, since an unfound fragment only makes the trim look worse), so retained
  debris scores as a hit and the
  trim is penalised for doing its job. **RE-MEASURED 2026-08-09 (BUT-1818): the cost is
  ZERO.** 14 gold entries were graded against their photographs and marked `frameCut`;
  `--no-frame-cut` drops the 11 `fragment` ones — never the 3 `tail` ones, which are real
  recipes and whose removal would only cost a page — and over the SAME 181 pages the trim
  then scores 91.59 -> 91.59 %, with block counts moving 139 -> 144 BETWEEN THE TWO GOLDS
  (the trim itself moves them 144 -> 144) as SIX pages gained
  and ONE lost — the arm prints the per-page movement, because the lost one is the
  informative case (the splitter made 3 blocks of a 1-recipe page and the biased gold
  called that right). The table's `91.54 -> 91.52` keeps the bias
  and is an upper bound. A zero-ingredient gold entry is NOT a defect signal, and no text
  screen reproduces the 14 — each was opened as an image.
  **Dark until the geometry flag is on:** with
  `enable_layout_recipe_split` false — the code default — no layout reaches the
  splitter, so `withoutOrphanTail` returns its input untouched and nothing is cut.
  Do not read "BUILT" as "live for every user".
  **The 120-200 band was designed as a third outcome (show it unticked in the picker)
  and then declined by its own gate.** Every tail in that band carries READABLE CONTENT
  under the heading — a whole small recipe (`Chokladkräm`), an intro paragraph
  (`Annas hurtbullar`), the start of the next recipe (`Inlagd sill`, `Mixade vitaminer`),
  a tip section with its own list (`I stället för sås`). Below 120 there is only
  frame-cut debris. The budget is a PROXY for exactly that, so the band stays off and
  the UI half (`uncertainIndices` through the viewmodel to the picker, an ARB string, a
  widget test) was never built.
  **CORRECTED 2026-08-09 — the verdict stands, the stated reason was wrong.** The
  2026-08-08 reading was done on the bare TEXT and called those two "subheadings inside
  a recipe"; re-read against the PHOTOGRAPHS, `Chokladkräm` is a complete little recipe
  and `I stället för sås` is a new section's display heading. The same text-only pass
  mis-graded the SHIPPED window too (reported 8 of 10; Malin objected; all ten opened as
  images are 10 of 10 CORRECT, and two are the back-cover blurb of a different book
  lying behind the cookbook). Never re-judge either set from the text — open the images.
  Do not raise the budget above 120 without re-reading those nine that way; the corpus
  measurement at 200 shows the cost — recall 91.33 %, one page lost. That row has NOT
  been re-measured against the corrected gold and is the most bias-exposed figure in this
  entry; do not cite it as a clean cost when re-opening the band.
  Re-open the band the day the picker can MERGE two blocks (BUT-1817): a wrong guess
  becomes undoable and the trade changes. PROXY — Windows offline OCR, not ML Kit.
  BUT-1816, 2026-08-08, corrected 2026-08-09

- **Letting a SINGLE surviving layout block stand, instead of falling back to the text
  rules, is MEASURED AND DECLINED — do not build it.** `MultiRecipeSplitter._splitByLayout`
  ends on `if (blocks.length < 2) return null`, so a page whose orphan trailing heading was
  correctly discarded still falls through to the text rules, which put it back. Relaxing
  that to accept one block is SAFE while the discard budget stays under ~120 characters
  (single pages 122/133, spreads 16/48, 39 lost — all identical to today) and BREAKS at the
  live 200-char budget (spreads 15/48, 40 lost, one page broken). It is also worth nothing:
  gold-token recall unchanged at 91.56 %, precision 66.26 -> 66.27 %, **four tokens across
  181 pages**. **CORRECTED 2026-08-08, same day:** that last figure is right but its
  generalisation was wrong. The entry originally read "the corpus does not contain the case
  in measurable quantity" — it does. 19 of 247 captures END their import on a next-recipe
  heading (`Inlagd sill`, `Mandelforell`, `Annas hurtbullar`), and ALL 19 reach the import
  because the layout path declined. This gate is simply not the one that declines: 14 of the
  19 bail on `flat.length < 2` and only **2** on the single-block rule. So the verdict
  below stands for THIS gate and says nothing about the symptom — see the trim entry.
  Re-derive with a mutation probe on that one line, reading the BLOCK counts off
  `corpus_split_eval.dart --layout` and the TOKEN figures off `--edge-crop`. (That arm also
  prints the paired block report, because it implies `--layout`; `--layout` alone prints no
  tokens.) PROXY figures — Windows offline OCR, not ML Kit. BUT-1816, 2026-08-08

- **Column ordering for on-device OCR is MEASURED AND DECLINED — do not build it.**
  A sorter putting the left column before the right rewrites two of every three corpus
  pages (116 of 181), including single-recipe pages that already work, and buys 139
  correct block counts against 138, the same COUNT of recipes never emitted (39), 5 fixed and
  4 broken. One page, which is noise. A per-line height-vs-width fit (deskew), proposed
  separately and not by the plan, scores strictly worse: 136/181, 42 lost, 0 fixed, 2
  broken. **All PROXY figures — Windows offline OCR, not ML Kit**, so they say what the
  algorithm does, not what the phone does. ML Kit's own block grouping is still
  UNMEASURED: the plan hoped it made a sorter unnecessary, and this does not refute that;
  it makes it moot, because the sorter does not pay either way. Consequence: the corpus
  page the feature was designed against still does not split, recorded as a passing
  known-miss test in `heading_detector_test`, not tidied away. Note the interleaving is
  REAL in that engine — 49 of its 134 two-column pages (37 %) come out of capture
  out-of-order — so the case for re-opening is a device measurement showing ML Kit behaves
  the same AND a bigger gain than one page. An engineering call under the plan's ⑦
  ("check it against real geometry before writing a line"), reported to Malin in the
  2026-08-07 session summary; no founder override sought or given. 2026-08-07

- **The free on-device OCR tier ships ON despite losing the measured comparison** — the
  corrected eval (harness preprocessing like production) scores on-device 96.1 vs the paid
  chain 96.6 over 39 verified recipes across 21 pages, so the plan's "at least as good" gate
  is NOT met — and on a LARGER corpus the gap widened (0.3 -> 0.5) rather than averaging out,
  across three consecutive runs.
  **Malin's explicit call, 2026-08-03:** half a point is not worth paying per image for. Do NOT flip `enable_on_device_ocr` off citing the
  gate — the gate was overridden knowingly, and the paid chain still runs behind the tier for
  anything it reads poorly. Revisit if a larger corpus shows a real gap. 2026-08-03

