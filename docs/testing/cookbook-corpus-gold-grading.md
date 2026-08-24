# How the cookbook corpus gold is graded against the photographs

The corpus (`butlery-corpus/`, outside the repo — `BUTLERY_CORPUS_DIR`) stores, per page,
a photograph, the OCR text taken from it, and a hand-corrected `gold.json`. Every eval arm
in `tools/corpus_split_eval.dart` and `tools/corpus_eval.dart` scores against that gold, so
a systematic error in the gold becomes a systematic error in every figure quoted from those
arms — including figures already written into `docs/architecture/ACCEPTED_DEVIATIONS.md` and
into `lib/services/import/layout/orphan_tail.dart`.

**This file exists because two successive gradings inherited the same blindness: both read
TEXT.** The first (BUT-1818, 2026-08-09) hand-graded what a word-shape screen surfaced. The
second (BUT-1847, 2026-08-19) opened all 181 pages as images and found nine more. Anyone
re-grading must read this first, or they will re-derive the same floor and call it a count.

## The unit of grading

One `gold.json` ENTRY, not one page. A page holds one entry (flat layout) or several
(`recipe-NN/` layout), and a single photograph can carry a complete recipe and a sliver of
the next one side by side.

## The rubric

`gold.json` may carry a `frameCut` field with two values. It is absent when the entry is
sound.

**`fragment`** — the entry should never have been emitted as a recipe at all. It exists only
because a heading appeared: the capture holds NEITHER the ingredient block NOR the bulk of the
method — the exact complement of `tail` below — or holds a column sliced lengthwise so every
line breaks mid-word. Its tokens are debris. (Stated as the complement on purpose: an earlier
draft said "no more than the opening line or two", a line count that its own worked example
below, at three lines, contradicted.)

**`tail`** — the entry has the recipe's SUBSTANCE and is missing only its ending. Concretely:
the capture holds the ingredient block (or, in an inline-format book, the bulk of the method),
and the frame, the page edge or the book's own page break took what follows.

The operational test behind both:

> Does dropping this entry from the gold remove BIAS, or only remove a page?
> Removing bias → `fragment`. Removing a page → `tail`.

`--no-frame-cut` drops `fragment` and keeps `tail`. `corpus_split_eval.dart`'s file header
states that rule; the REASONING for it — that dropping a `tail` removes no bias, and what an
earlier 181 → 178 draft cost — is in the comment on `dropFrameCut` in `main()`.

**The tiebreak, and why it is not "how the transcription reads".** Two entries can sit at the
same character count and the same distance from the page foot, and the deciding question is
whether the capture holds enough of the recipe to be one. `Inlagd sill` (159 characters under
the heading, no ingredient block, three lines of a method that runs several more) and
`Mixade vitaminer` (166 characters over four rows — two of intro, two of method) are
that pair, and they get the SAME label — `fragment` — because the same test decides them.

The trap is that their gold TEXT reads differently: `Inlagd sill`'s cut happened to land after
a full stop, so its transcription looks like clean finished prose, while `Mixade vitaminer`'s
landed mid-word. That difference is an accident of where the frame fell, not a property of the
recipe, and labelling from it is the same text-shaped mistake this whole file exists to retire.
`Inlagd sill` was read as a `tail` on this pass's first look for exactly that reason, and
settled as a `fragment` on the criterion above.

**That call is load-bearing, so its cost is stated rather than buried.** `--no-frame-cut` drops
fragments, so the choice moves the headline figure: the 200-character budget costs **9** real
gold tokens with `Inlagd sill` a fragment and **23** with it a tail. Both are non-zero and both
lose a right block count, so the verdict on the band survives either way — but a third grading
that flips the pair moves the number, which is why the criterion is written down and why the
pair is named. Mislabelling in the other direction is the more expensive error: calling a
genuine `tail` a `fragment` deletes real recipe text from the gold and makes a trim look free
that is not.

## The procedure

1. **Open the page as an image.** Never grade from `ocr.txt`, from `draft.json`, or from the
   gold's own wording.
2. **Match every gold entry on that page to what the photograph shows** — the title, the
   ingredient block, where the method stops.
3. **Suspect an edge cut? Crop the original at FULL resolution and look again.** A
   downscaled view (1600 px long side on a 3000×4000 capture) renders a dark page edge or a
   gutter shadow as a clean cut. On 2026-08-19 `Pernillas festfisk` read as sliced at 1600 px
   and was intact at full resolution; the page's own `ocr.txt` carried the full line, which
   is the cheapest cross-check available.
4. **Corroborate with the gold text — as a hint, never as the verdict.** A gold whose lines
   end mid-word, whose title is truncated (`Annas fisks`, `Den gl`, `Mästerkockens f`), or that
   ends in `...` is frame-cut. Clean text that simply stops at the page's last sentence is
   short, but whether it is a `tail` or a `fragment` is decided by the rubric above, not by
   the punctuation.
5. **Write the field, and write down why.**

## Four things that are NOT a frame cut

- **A zero-ingredient entry.** `Fisk i ugn` and `Koka piggvar` are complete recipes that
  genuinely carry no ingredient list. A word-shape screen flags 89 such false positives
  (`deg`, `cm`, `bär`). Do not re-derive the frame-cut set from any text screen.
- **A finger over the text.** `Nässlor för frysen` is occluded by the photographer's thumb,
  yet its gold is complete — so the gold is not short and nothing is marked. (It is the
  opposite defect: the gold holds tokens the OCR can never see.)
- **A continuation that is still in frame.** Most spreads photograph both pages, so a method
  running from one column into the next page's column is fully captured. Check the whole
  frame before calling an entry short.
- **A new section's display heading at the page foot.** That is what the orphan-tail trim
  removes; it is not a gold defect.

## The third class: gold that EXCEEDS the capture

Neither `fragment` nor `tail`, and deliberately unmarked, because no flag consumes it:
an entry whose gold is complete while the photograph shows only part of it. `Pikant puré
från Peru` (`potatisratter/PXL_20260602_192724758`) carries its full method although the
capture shows that column sliced lengthwise. This biases recall AGAINST the parser — the
denominator holds tokens no OCR could return. It is recorded here so the next measurement
knows the direction, and it is not a `frameCut` value: adding one would silently change
what `--no-frame-cut` drops.

## What the 2026-08-19 grading covered, and what it found

All **181 pages** carrying gold, all **242 verified entries**, each page opened as an image,
with full-resolution crops wherever an edge was in doubt.

| | before (BUT-1818) | after (BUT-1847) |
|---|---|---|
| `fragment` | 11 | **13** |
| `tail` | 3 | **10** |
| total marked | 14 | **23**, on 20 pages |

**All 14 pre-existing labels were confirmed unchanged**, and nine entries were added: two
`fragment` and seven `tail`. The two fragments are `Annas fisks`
(`blandat-svart/PXL_20260803_204323606/recipe-02`) — the facing page's recipe, sliced
lengthwise, whose gold records a truncated title, 14 of its 15 ingredient lines broken mid-word
and 21 of its 24 instruction lines — and `Inlagd sill`, the borderline case the rubric section
above decides and prices.

**A text screen would have found nine of the twenty-three — thirteen at its most generous.**
The predicate matters and is stated so the figure stays re-derivable, because a screen written
slightly differently gives a different answer: flag an entry when **at least 40 % of its
instruction lines end without one of `.` `!` `?` `:` `)` `…`**. Re-run over the finished
grading that recovers **9 of 23, with 0 false positives**; adding a second rule for an explicit
trailing `...` takes it to **13 of 23**, still with none. (Testing the LAST instruction alone,
rather than 40 % of all of them, scores differently and picks up `potatisratter` entries that
legitimately end `Lämpliga tillbehör: Grönsallad` — so "a text screen" is not one instrument.)
Ten of the twenty-three are invisible to either variant, their gold being clean, well-punctuated
prose that simply stops. That is why "14" was a floor, and why any future count taken from text
alone is one too.

**Five of the seven new `tail`s are not camera cuts at all** — four in `potatisratter`, plus
`Igelkottstårta` (`blandat-svart/PXL_20260803_204954922/recipe-02`, a tårt book photographed
into the `blandat-svart` slug, so do not go looking for a slug of its own) — but the BOOK's own
page break: a recipe that starts at the foot of one page and
finishes on a page the photograph does not include. An entirely different mechanism from the
frame cuts that dominate `blandat-svart`, and the one no screen aimed at broken words can see,
since the gold ends on a clean full stop. The other two (`Avocadosoppa`,
`Provençalska kotletter`) are ordinary bottom-of-frame cuts.

Two structural facts worth keeping, both measured rather than assumed:

- The 13 fragments sit on **10 pages, and no page is all-fragment** — every one keeps at least
  one unmarked entry, so `--no-frame-cut` never drops a whole page out of the population. That
  invariant is what makes the biased and de-biased columns one population; check it after any
  re-grade.
- Exactly **one** fragment (`Mandelforell`) sits on a page the shipped 120 budget actually
  trims, so twelve of the thirteen bias the recall LEVEL and the block counts rather than the
  trim's own before/after delta.

## Re-running the figures after a re-grade

The default arm reads `frameCut` only to tally the census it prints, never to scope the
population — so every biased FIGURE keeps reproducing, while both banners' fragment/tail counts
move with the grading. Only `--no-frame-cut` changes what is scored. Both arms:

    dart run tools/corpus_split_eval.dart --trim
    dart run tools/corpus_split_eval.dart --trim --no-frame-cut

The character budget's other rows still need `_tailBudget` in
`lib/services/import/layout/orphan_tail.dart` edited and the arm re-run — restore the shipped
value afterwards.

**FIVE files carry these figures by hand, and a re-grade must update all five or they drift.**
Naming only two of them is exactly how a stale sentence survived inside the BUT-1847 batch
itself:

1. `lib/services/import/layout/orphan_tail.dart` — both budget tables and the comparison table
2. `docs/architecture/ACCEPTED_DEVIATIONS.md` — the BUT-1816/1818/1847 entry
3. `.claude/rules/accepted-deviations-ocr.md` — the always-on summary, which auto-loads for any
   session that opens `lib/services/import/**` and is therefore the worst copy to leave stale
4. `lib/services/feature_flags/feature_flag_service.dart` — the flag's own comment
5. **this file** — the rubric section above states both labels of the borderline pair and both
   prices (9 and 23) in undated present tense, so a re-grade that flips the pair falsifies it

**`tools/corpus_split_eval.dart` used to be a sixth carrier and is no longer, but only because
the numbers were removed from it rather than maintained.** Its two banner strings had the
counts typed in, so a re-grade made the tool misreport its own input; they now COUNT the
markings while the gold loads and interpolate what they found (`_FrameCutCensus`). Its
COMMENTS carried six more typed figures — five inline and one in the file header, two of which
were ALREADY stale (they still read 14 and 11, BUT-1818's numbers) — and those were de-numbered
rather than updated: they now state the rule ("no page is all-fragment; the printed page count
is the guard", "a net block-count gain is a masked swap") instead of a count that a re-grade
falsifies. The file now carries no count of the CURRENT set, which is the form of "not a carrier" worth
claiming. The figures still in it are BUT-1818's — its 14, and its three `tail` entries — each
attributed to that ticket and marked superseded where it stands, so no re-grade can falsify
either. (An earlier draft said "no grading count at all", and a later one named only the 14;
reviewers greped both out of the file. An absolute one word too strong costs a round each
time.) Prefer both
moves to a checklist entry wherever a figure can be computed or simply dropped: a checklist
entry has to be remembered, and this batch is a record of what happens when one is not.

**A sixth copy lives OUTSIDE version control and no checklist item can reach it:**
`butlery-corpus/GRADING.md`, the short pointer sitting where the grading actually happens. It
names the last full grading and its date. Update it in the same pass, or the corpus-side reader
gets a number the repo has already retired.

`tasks/lessons.md` and `.claude/rules/lessons-digest.md` are deliberately NOT on the list
either. The lesson is a dated record of what was true on 2026-08-19, and a record that gets
edited to match today stops being one; the digest states a past DELTA (14 -> 23), which stays
true after any later re-grade. **That exemption covers figures a re-grade falsifies and nothing
else** — a claim that was simply WRONG when written still gets corrected there like anywhere
else, which is how both files were repaired in this very batch after I first argued they were
frozen.

And re-run any review that was reading those files: a verdict describes the bytes it saw, so
editing the gold underneath one silently invalidates it.
