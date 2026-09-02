# testing-specialist — accumulated knowledge

Read as Step 0 of every testing task; update when you discover a pattern, find a helper, or
are corrected. `testing-specialist.md` holds the durable DO-WRITE/DO-NOT-WRITE rules, the
production→test path map, and Mock-vs-Fake. This file holds **principles only, edited in
place — never a log, and NOT append-only about itself.**

## How to update this file

- **PRINCIPLES only, 1-4 lines.** Earns its place only if a future run would act
  DIFFERENTLY because of it. Merge into the matching section; never append to the end.
- **The raw, dated record lives ONLY in `testing-specialist.knowledge.archive.md`** —
  append-only, one `### <date> — <title>` entry per incident, verbatim.
- **This file has drifted back three times (35K→432K 2026-07-24; 262K→112K 2026-08-09;
  162K→here 2026-08-17) the same way: not dated entries (never used here) but individual
  principles absorbing worked-example detail instead of citing the ticket and archiving the
  detail.** When adding an example, ask if the sentence stands without it; if yes, archive
  the example and cite the ticket.
- **Budget ~25,000 chars** — a smell, not the control; the rule above is. Every principle
  the pre-2026-08-17 file carried survives here, merged, or verbatim in the archive's
  2026-08-17 snapshot entry.
- **The real trigger is the Read tool, not char count** — past ~250,000 chars Step 0
  silently degrades to grepping. Next time this approaches that, SPLIT `Vacuity patterns`
  out rather than compress again; it's been the largest section twice running.

## When to consult the archive

Grep it when a principle here is too terse to act on and you need the worked example (test
code, failure output); an unfamiliar mocktail/Firestore-fake discrepancy not named below; an
emulator-lane setup failure (full runbooks live there); a ticket's or area's full review
history (grep the BUT-#### or area name); a principle citing "verified non-vacuous by X" and
you want the revert-probe that proved it; or this file itself reads too compressed — the
2026-08-17 entry holds the prior version of this whole file, byte-for-byte.

---

## Principles

### Re-review economics (re-reviewing "after automated fixes")
- **Confirm bytes actually MOVED before re-reviewing** — hash + `wc -l` per file, both ends
  of the round; mtime lies. When they DID move, isolate what changed since YOUR copy with
  `git cat-file -p <graded-blob> > scratch/old && diff -u --strip-trailing-cr scratch/old <f>`
  — NOT `git diff <blob> $(git hash-object <f>)`, which dies "bad object" (`hash-object`
  without `-w` writes nothing), and never a plain `diff`, which calls EVERY line changed when
  the blob is LF and the worktree CRLF. Diffing against HEAD instead buries the one
  hunk in the round's other work, and a mid-round fix makes stale-byte findings routine, not
  exceptional (BUT-1837: settled a claimed two-line strike in one call). **A tree that moves
  DURING the round is the same event and needs the same isolate-diff at VERDICT time** —
  BUT-1904 round 3 had 6 of 9 reviewed paths re-hash mid-review, a parallel session
  independently closing two of the findings being written; re-verify every finding against
  the CURRENT bytes before filing and say which copy the verdict is against. `git diff <path>` empty ≠ unmoved (staged shows only in `git
  diff HEAD`/`git show :<path>`). Hash a suite's runtime INPUT files too (a source-text
  guard reading `firestore.rules`), not just changed ones. **Write the hash TABLE into every
  round's archive entry, prose-only rounds included** — BUT-1904 round 8 recorded only "graded the
  worktree, index empty", so round 9 had to reach back two rounds and INFER which of five moved
  paths belonged to which round; the table is what makes the next round's attribution mechanical
  instead of inferential.
- **The brief is pinned to a hash and expires with it** — a `sed -n` printing different
  content at the same lines means re-Read and rebuild the mutant list; skip re-running
  mutants already measured on an unchanged hash.
- **The motion check is the map: moved PRODUCTION ∩ unmoved SUITES = unasserted by
  construction** — `git show :<path>` on such a file is a free pre-fix mutant.
- **Fix loop consumes Critical/High only** — an all-Low/Medium re-review never changes.
  Apply zero-risk test-only fixes yourself; never edit production in a review pass.
- **Re-run the MOTION CHECK against the fix report, not just against your own copy — a
  round's remedy routinely drags in production edits the report never mentions.** BUT-1904's
  fix round reported four test files; `--numstat` showed the shared predicate
  `isChatDuplicateCandidate` and a second suite had moved too (+414 where +88 was described).
  Diff EVERY path in the round, sort by whether it is production, and grade the unreported
  production edits FIRST: they arrive with no finding attached, so nothing has asked whether
  a test can see them. The recurring shape is a fix for finding N landing an unpinned
  behaviour change beside it.
- **"Duplicate test" is measurable**: mutate the guarded expression, delete only a strict
  subset kill set THROUGH THE SAME SEAM. Exceptions: reaches the sole fail-closed lookup via
  a different seam, or is another test's CONTROL. Grade two suites for one class by what
  only ONE holds — the tidy mirror suite is often the sweep; the "stale duplicate" can carry
  the security/a11y groups nobody rewrote. Never retire by path convention alone.
- **A live parallel session poisons a battery both ways**: their edits are FALSE KILLS in
  your run (attribute by test name vs mutant blast radius, re-hash before verdict); an
  identical md5 + fresh mtime is THEIR mutate-and-restore, and your `finally` can clobber
  their in-flight write — prefer a production-free `test/`-side probe beside a live session.
- **The tree moves DURING your round** — re-read before filing (a stale stack-trace line
  number is the cheapest tell); back up/restore your own probes in ONE Bash call.
- **A mutate→run→restore→mutate LOOP can be served the PREVIOUS mutant's kernel** — mutate
  and restore inside one second and `flutter test` reuses a stale incremental build, so the
  run reports failures belonging to the mutant before it. Tell: a red test the mutant cannot
  reach (a fixture that never enters the mutated branch). Never loop probes in one Bash call;
  run each in its own call and RE-RUN any surprising red alone before filing it (BUT-1897:
  two of four probe results were phantom, both reproduced clean on re-run). **The phantom
  arrives as a SUPERSET, on the mutant applied in the call right after a restore** — BUT-1971's
  M2 reported 2 reds, of which only 1 reproduced on a clean re-run, and a superset reads as
  "this mutant is broader than I predicted" rather than as an instrument fault, so the tell is
  the extra red belonging to the PREVIOUS mutant's kill set, not an unreachable fixture. Run
  each mutant TWICE in its own call and grade run B. **And do not trust a `mktemp`+`trap`
  restore, even one whose own md5 reads clean**: measured on BUT-1971, the restoring call
  printed the pre-mutation md5 and the NEXT call found the mutant still live on disk. Restore
  with `git show :<path> > tmp && cp tmp <path>` (deterministic, and it is the copy the parent
  commits) and verify with `git diff --numstat <path>` empty — never against a remembered hash.
- **A probe run over the SUITE YOU WROTE cannot support a "no other witness" claim** — that
  needs the suites found by `grep -rl '<mutated symbol>' test/`, which is a different set from
  the files you edited. BUT-1971's cross-language cap guard shipped a docstring saying raising
  `maxEditTrailRows` "leaves every suite green"; the probe had run only the new file, and
  `group_weekly_menu_plan_service_test.dart` reddens on ANY raise (its loop appends 55 rows and
  asserts the pruned-from-the-front id `first.entryId == 'e5'`, which is `e(55 − cap)`). A green probe on one suite is
  evidence about that suite only, and "no other witness" is the exact sentence shape the
  counterfactual lesson keeps catching.
- **When the question is only "is this line REACHED at all", coverage answers it with no
  `lib/` write** — `flutter test --coverage --coverage-path=<scratchpad>/lcov.info <suites>`,
  then `awk '/^SF:.*<file>/,/^end_of_record/' | grep '^DA:<line>,'`; a `0` is the finding.
  No backup, no restore, no parallel-session clobber, no auto-mode classifier, ~10s. Reach
  for a mutant only for the harder question ("does any test DISCRIMINATE this expression"),
  since a reached line can still be unasserted (BUT-1831: a private read seam's success arm
  read `DA:244,0` while its two failure arms were pinned). **The same report settles a
  widget test's non-vacuity when it turns on a COLLABORATOR's state the test cannot assert**
  — read the DA hit on the RHS LINE of an `&&`, which evaluates only when the LHS was true,
  so `DA:<rhs>,>0` proves the null-check passed (BUT-1908: a tap "through the real screen"
  discriminates the VM's gate only if the VM's own message list was populated first, and
  `DA:499,3` proved it against a suite that stays green either way).
  **Dart's lcov mis-attributes lines around an `await`, so on "did this test REACH the
  save" it can answer nothing** — the `await _service.save(...)` line carried no `DA:` record
  at all and a hit landed two lines past it, which reads as "reached AND its continuation
  ran", the opposite of the truth. The decisive probe there is TEST-side and needs no `lib/`
  write either: copy the suite to a scratch `_zz_probe_test.dart` beside it, insert
  `verify(() => mock.<seam>(any())).called(greaterThan(0))` in every case, run with
  `--plain-name`, delete. ~20s, settles all N cases in one run, immune to the
  parallel-session clobber a production mutant risks (BUT-1962, 2026-08-27).
- **"Only `dart format`" is provable, not assumed**: walk `git cat-file --batch-all-objects`,
  compare whitespace-stripped bytes blob-to-blob (not blob-to-disk — CRLF differs by one
  byte/line). The formatter can insert a trailing comma, so fall back to raw `diff` if a
  token-signature match misses a genuine format-only file.
- **"Staging — resolved" isn't resolved until `git show :<path>` diff is empty** — an index
  can sit behind graded bytes across rounds; close every round naming unstaged hunks.
  **When the BRIEF says a finding is "already applied", run `git diff --numstat` on the
  reviewed paths BEFORE grading, not at verdict time** — `Read` returns the WORKTREE and the
  parent commits the INDEX, so a repair can be real and still absent from what ships. Measured
  on BUT-1971's follow-up: 3 of 5 reviewed files were `MM`, and BOTH reported repairs (a
  vacuous test rewritten, a false comment corrected) lived only in the worktree while the index
  still held the exact defects the brief called fixed — plus two more the worktree had struck.
  The index copy of a struck sentence is a SECOND claim to grade, not a stale duplicate: here it
  was a wrong count ("from all five positions"; six sources) and a false capability ("the Art. 15
  probe can FIND the plan" — the export queries `memberPermissions`, and the rules deny a
  `contributorUserIds` query to every caller). Grade both copies and say which the verdict is against. Close
  the POSITIVE direction mechanically at verdict time: `git diff --numstat` every reviewed
  path (0 lines = index matches worktree) in one call, so the verdict names the copy the
  parent will commit. **A round whose remedy was "strike a false sentence" is the highest-risk
  shape for this**, because the verdict-time grep of the struck string answers "gone" from the
  worktree for every copy while the index still carries all of them — grep `git show :<path>`,
  never the worktree, for a reported strike (BUT-1909/1925: production doc + two suites all
  `MM`, feature code staged, the whole repair round not). **Two ways that check answers "clean" while proving nothing.** (1) A
  path-scoped git command run from the WRONG cwd prints nothing, byte-identical to "no
  differences" — every verification call gets an explicit `cd` and an echoed `pwd`, because
  this one fails SILENTLY into the reassuring answer. (2) `git status --porcelain` and `git
  diff` genuinely DISAGREE: status prints `MM` off a stale stat cache (mtime touched by a
  formatter/hook, content unchanged) while `git diff` is empty. Neither is the tiebreaker —
  compare `git ls-files -s <f>`'s blob to `git hash-object <f>`; `update-index --refresh`
  then makes status agree (BUT-1910).
- **An analyze finding contradicting the source you just read, or a suite passing against
  code analyze says can't compile, means re-md5sum BOTH files** — a timestamp-preserving
  restore can leave stale bytes running.
- **"Would the RULES allow this?" — just run it**: a throwaway `_zz_probe_*.ts` under `npx
  firebase emulators:exec --only firestore --project demo-test` names the rule line in ~90s;
  add a control arm.
- When a parallel session lands a test for the same guard, delete yours with a pointer
  comment. A measured claim in a comment is one command to verify — agreement across files
  often just means one was copied. **A reported REMOVAL or REWORD is verified by grepping the
  OLD STRING in the worktree AND `git show :<path>` AT VERDICT TIME, never by the motion
  check** — a file that moved for the round's OTHER edits passes every hash test with that one
  absent (twice measured: a false sentence outliving the production edit, and a two-repair
  round that landed the blocking fix and silently dropped the non-blocking reword, reported as
  done), and a parallel session can land the removal between two of your own greps: say which COPY the
  finding is against, since the parent commits the INDEX (BUT-1897). **Your OWN prior round's
  reported strike gets that grep too** — BUT-1904 round 1 wrote "struck, not reworded" about
  three false sentences and nothing was struck; they rode two more rounds because rounds 2 and
  3 re-read the DIFF, and a pre-existing block sits outside every hunk. Re-grep last round's
  quoted strings before opening a new round. **That grep answers
  "gone" whenever the surviving copy is a PARAPHRASE, not a duplicate** — BUT-1837's struck
  mechanism sentence lived a third time as a doc comment on a FIXTURE BUILDER inside the
  group, worded differently, so every literal grep and both blob hashes read clean; sweep the
  whole file by CONCEPT, and expect the copies in different syntactic roles (inline production
  comment, module-level doc comment, nested local-function doc comment) because a strike round
  sweeps the locations the FINDINGS named. **When the struck premise is a HARM claim, the two
  copies a `lib/`-scoped sweep cannot reach are the SUITE's `group(` header stating the same
  rationale, and a PRESUPPOSITION in a sibling method ("a wrong plan written now cannot be
  undone" presupposes one can be written) — grep `test/` for the harm wording in the same round,
  and re-read every sibling comment the strike did NOT touch for the harm smuggled in as a
  subordinate clause; the tell is one file answering the question two ways (BUT-1961, 2026-08-27).
  **That `test/` copy then rides into the NEXT ticket's batch, invisible to every
  diff-following sweep because the suite is CLEAN AT HEAD and in no commit at all** —
  BUT-1971 struck "the only live caller is the meal-poll close" from both `lib/` files and
  left the verbatim clause in `group_weekly_menu_plan_service_test.dart`'s test comment.
  Grep the struck string across `test/` as well as `lib/`, and grade an unstaged suite whose
  production file moved (2026-08-29).
  **The STOP rule for that sweep, or it never terminates: a sentence saying only what the code
  REFUSES ("the close path refuses on a failed read rather than saving over the week") asserts no
  outcome and is not a carrier — only a clause asserting what the write WOULD DO is.** Round 2 of
  BUT-1961 came back with the two named copies struck, the repaired header measured true, 17/17
  green, and the weakest remaining phrase deliberately left standing (2026-08-27). **Then grade the
  REPLACEMENT as a fresh claim** — a strike that swaps a measured count for a quantifier
  ("six call sites" → "from every list and detail surface") is unmeasured by construction, and
  the falsifier is usually an explicit exception in the same code (`assert(!readOnly, 'edit
  must be unreachable')`). The repair is to STRIKE the quantifier, never to re-measure it
  (BUT-1910). **The specific replacement that re-arms the seam is one supplying a missing
  ANTECEDENT**: told "`the five` has no antecedent", the round wrote `Each test below pins one
  operation, graded separately because the five that…` — a quantifier over the group's own
  contents, false the moment that group holds a leak test or a pre-existing-behaviour control,
  which BUT-1962's did (8 tests, 7 operations, 5 reordered). Put the head noun INSIDE the
  surviving noun phrase (`The five operations that mutated _plan…`) so the antecedent costs no
  quantifier (BUT-1962, 2026-08-27). **A test FILE HEADER scoping what the file covers ("tests cover the static
  helpers; cache behaviour is covered by <other file>") is the same insertion seam as a test
  COUNT, and the round's own new group is what falsifies it** — so re-read every header whose
  file gained a group, and resolve the cross-file pointer with one grep of the guarded CLASS
  name in the cited file: zero hits IS the finding, and a false coverage pointer is worse than
  a false count because it is the sentence a later run cites to skip writing the test
  (BUT-1909). **The same header also names the HELPERS the file uses, and the falsifier is
  usually IN THE SAME FILE** — a widget suite's header claimed "one `butleryGolden(...)`
  freezes the populated-with-overflow state" while its own golden group 1000 lines down opens
  "Does NOT use `butleryGolden`, because…" and pumps a fixture with no overflow. Two answers to
  one question, neither reddening, and a diff-following sweep never reaches either: grade a
  header against the file's GROUPS, and strike rather than re-scope (BUT-1962, 2026-08-28).
  **A header carries a SECOND claim beside its count — EXCLUSIVITY ("N invariants nothing else
  in the repo holds") — and the round's own NEW FILE falsifies that half, in a file the diff
  shows as barely touched.** BUT-1971 added `chat_action_handler_group_menu_test.dart` holding
  "keyed on the conversation id, NOT the groupId" at the CHAT entry point, which is verbatim
  invariant 2 of the pre-existing `group_menu_entry_button_test.dart` header, while that header
  also went from covering its 2 named invariants to 4 behaviours. Both halves die together;
  strike BOTH the numeral and the exclusivity rather than scoping to "at this entry point" — a
  twin entry point pinned in the same commit is a residual to record, and a scoped rewrite moves
  the next falsifier one entry point away (2026-08-29). **The strike round then repairs the file
  the FINDING named and leaves the identical claim in the file the ROUND ITSELF created, with
  the numeral INCREMENTED to match the test it just added** — measured the next round on the
  same pair: the sibling header lost "Two invariants nothing else in the repo holds" while the
  new file shipped "Three invariants that nothing else in the repo held", and the incremented
  count was ALREADY wrong (three listed invariants, four tests, one of them about another
  feature entirely). Sweep the CONCEPT across the round's ADDED files, never only its modified
  ones — `grep -rn "nothing else in the repo" test/ lib/` is the whole check — and read an
  incremented count as evidence the seam was re-armed, not repaired (2026-08-29).
  **The cross-file pointer that is NOT a count is a reciprocal LABEL pair** — a Dart
  comment naming a rules case (`W2`) while that rules file names the Dart test by its verbatim
  NAME. Resolve BOTH directions (label present in the cited file; test name grep-exact); a label
  survives an insert where a count dies, so this is the durable form and a rename is the better
  fix to REFUSE. Residual to state, never to repair: neither direction is test-enforced
  (BUT-1961, 2026-08-27). **A test's NAME and its COMMENT are TWO copies of one claim** — a finding that
  quotes the comment gets the comment repaired and leaves the name, two lines away, asserting
  the struck thing verbatim. Grep the concept across NAMES separately (`grep "^ *test('"`).
  **And grade every test the round ADDS against the names already in the file**: the new
  test's name is often the precise falsifier of an old one, which is how one file ended up
  holding `'the deepest amount the formatter emits still fits the field'` 46 lines above
  `'the formatter can emit more digits than the field accepts'` (BUT-1912, 2026-08-25).
  **A FILTER the round adds to production does the same to an unqualified `includes every X`
  name in a sibling group of the same suite** — BUT-1904's export drop left
  `'includes every message of a conversation the user participates in'` 550 lines below the new
  `"another participant's blocked row is dropped"`, both green, one false. The old test stays
  correct (its fixture has no such row); only the CONTRACT its name states died. Grep
  `grep "^ *test($" -A2` for `every|all|no ` whenever the round narrows what a method returns,
  and rename off what the fixture actually proves (2026-08-26).
  **The line that stops OVER-correcting: a quantifier over the CODE'S BEHAVIOUR is a
  CONTRACT, a quantifier over the TEST FILE'S CONTENTS is a COUNT.** `'no amount is ever
  written in exponent notation'` ranges over the function's output — adding a ninth fixture
  cannot falsify it, and the repo rule (state the rule, not the evidence) prefers it to a
  name scoped to its fixture list. `'only the X case discriminates'` ranges over the tests
  below it and dies to the next insert. Settle a superlative by WALKING THE BRANCHES, not by
  counting fixtures — and check the fixtures then defend the one branch that could falsify
  it (BUT-1912's eight include `1e21`/`1e30`/`maxFinite`, the only values reaching the
  expansion path whose dead `match == null` fallback is the sole `e`-emitting line).
  **Replacing a COUNT with the named test LITERALS is the right repair** — verify each literal
  against the test's own name verbatim — **but the repairing sentence routinely re-arms the
  seam it just disarmed**: "the three cases above" became "every case above it", a quantifier
  over the file's contents with the identical insertion seam, two lines above the clause
  explaining why counts have one. Strike the derived clause; the mechanism sentence beside it
  ("on the happy path it makes no difference") already carries it (BUT-1904, 2026-08-26).
  **A strike round that fixes the count the FINDING named leaves the FALSE one further down the
  same file** — grep every numeral quantifying tests/cases/denies across the WHOLE file, not the
  diff-adjacent region, because a review sweep follows the hunks: BUT-1904 struck an ACCURATE
  "the three cases above" at line 750 while "the four denies below" at 785 (8 deny tests, 9 deny
  assertions, 3 on the branch it controls) rode through five rounds untouched. Grade an
  ALLOW-control's "makes the N denies below mean something" against the branch it is a control
  FOR, then against the whole section — a numeral wrong under BOTH readings is the tell.
  **The strike's own JUSTIFICATION sentence is a fresh unmeasured claim, and provenance is the
  usual shape** — "this comment already lost one numeral that way" was false: both numerals the
  file had lost were CORRECT when struck, one for having an insertion seam and one for naming
  a suite total. Strike the count and stop; explaining why counts are avoided re-introduces a
  claim about the file's own history that nothing checks (BUT-1904, 2026-08-26).
  **Told NOT to re-point a false pointer, the next round writes its HISTORY instead, and that
  sentence fails the same way** — BUT-1904 round 6 replaced "case X pins it" with "two versions
  of that sentence have been false: one named a case that did not exist, one named a case that
  never reaches the branch". The mechanism half and the coverage figure verified; the history
  half did not — BOTH prior versions named cases that exist (one positional, pinning something
  else; one measured unreachable). Only the review ARCHIVE can settle such a sentence, so grade
  it there or strike it — and it is always strikeable, because the MECHANISM sentence beside it
  ("two stacked layers absorb each other, so no case here has a single-mutant kill set") is the
  whole warning and needs no history (2026-08-26). **The next mutation of that same reflex is a
  POSITIONAL DISTANCE — "twenty lines up", "twenty lines below" — and it is a derived value a
  human cannot type: measured 3 wrong of 4 carriers in one round (36-38 actual vs "twenty"),
  because the paragraph making the claim is itself being edited. It also survives the strike
  round, because a review sweep follows the CLAIM and the distance rides in the sentence
  explaining it.** Grep the whole repo for the distance phrase, not the claim — one round put it
  in an ADR twice, an auto-loading `lessons-digest.md` line and a `tasks/lessons.md` entry, all
  four the same edit. The durable pointer ("in the bullet about X") is already in the sentence;
  strike the number and stop. Same round, same class: a digest line QUOTING what a record "had
  already struck" quoted a string `git show HEAD:<record>` does not contain — a paraphrase of a
  neighbouring correction. Grep HEAD for any quoted strike before writing it (BUT-1904, 2026-08-26).
  **The terminal form is a repair sentence NAMING its own verification command** — "a clause
  `git show HEAD` shows byte-identical with a sentence inserted beside it" — which described a
  mid-round worktree state a LATER edit in the same round falsified: HEAD carried the clause, the
  worktree had replaced it, and the round's own `isNot(contains(<old clause>))` test plus a
  sibling reviewer's archive both said REWRITTEN. Two tells, either enough: the retraction
  contradicts a paragraph in its own file, and the named command FLIPS with the commit, so the
  illustration refutes itself once it lands. Run the quoted command yourself and diff HEAD against
  the WORKTREE, never against the state the sentence remembers; the repair is a strike, never a
  "was true at the time" qualifier (BUT-1904 round 8, 2026-08-26).
  **The same flip reaches a BINARY the commit replaces, where no grep can see it** — a golden
  test's comment saying "the committed reference … is 375x874" was measured against the PNG in
  HEAD while the same commit shipped a 375x967 one, so the sentence was false on arrival and its
  referent no longer existed. The claim is a DIMENSION, not a string, so every struck-string
  sweep reads clean. Measure any present-tense sentence about a committed artefact against the
  copy IN THE INDEX (`git show :<path>`), never HEAD, whenever the round touches that artefact
  (BUT-1982/1984 round 2, 2026-09-02).
  **Grade the STRIKE with cheap mechanical checks rather than by re-reading the diff**: grep the struck
  string (0 hits); grep the ORDINAL or pointer it CARRIED, since a provenance parenthetical usually
  takes a "the second X" with it and an orphaned ordinal reads as a dangling reference; and re-read
  the paragraphs the strike left ADJACENT, whose "this"/"that" antecedents used to resolve through
  the deleted text. Then grade the surviving paragraph now carrying the fact ALONE as a fresh
  claim. They came back clean at BUT-1904 round 9 and the nine-round chain ended there —
  rounds 1-8 each closed a sentence, none closed code after round 4 (2026-08-26).
  **A "two answers to one question" finding about a comment is settled by measuring each
  clause's REFERENT, never by reading the clauses against each other** — a motive clause and a
  disclaimer beside it contradict only if the sink and the helper behave as you assumed, and
  that assumption is the whole finding. BUT-1962: I filed a sanitizer "because" clause as
  contradicting its own "the chokepoint is the point, not the redaction" caveat; the three
  referents each measured the other way (native `_logToCrashlytics` hands the error OBJECT to
  `recordError` unmasked, so a throw-site mask is the only one a `StateError` ever gets; the
  permission exceptions really do mask inside `toString()`; and `maskConversationId` is an
  IDENTITY function on the group id this site passes, which is exactly what the caveat says).
  Every clause true, the caveat load-bearing, the finding wrong. WITHDRAW such a finding
  outright rather than re-file a narrowed version — a declined non-blocking finding coming
  back reworded is the correction chain the strike rule exists to stop (2026-08-28).
  **When the struck sentence is PINNED BY A SUITE, run the STRUCK TEXT ITSELF through that suite's
  matchers before grading the repair** — a `contains` on a sentence PREFIX beside an `isNot` on a
  RETIRED spelling both pass on the very clause just removed, so the production strike is
  revertible-green and the repair comment's "both directions now hold it" is false. Measured
  (BUT-1904, 2026-08-26): the pre-strike GDPR `data_minimisation` string passed all five matchers;
  only deleting the sentence outright reddened, which pins PRESENCE, never non-overclaim. The
  discriminator is an `isNot` on the STRUCK clause's OWN literal, and a ~40-line scratchpad Dart
  replica of the matchers settles the whole table with no `lib/` write. A prose pin cannot hold
  "does not overclaim" at all, so the sibling `reason:` naming that property is struck, not tested.
  **Read a file's OWN HEADER before grading any prose below it** — a header stating
  `this is a ROUTING rule, not a census, because a count would be wrong the week after`
  makes every later census in that file a defect BY THE FILE'S OWN TERMS. That is the
  cheapest strike argument there is: nothing to measure, the file already made it, and it
  also settles strike-vs-expand — expanding the list re-arms the trap the header names
  (BUT-1912, 2026-08-25).
- **A production edit in the round falsifies comments in files it never touched, in two
  recurring shapes.** (1) A param promoted DEFAULTED→REQUIRED kills every "delete this
  argument and it falls back to <default>" mutant sentence — the mutant is now a COMPILE
  ERROR, and the sentence asserts the fail-open default the round deliberately removed, so
  it licenses re-adding it; the surviving true mutant is "hardcode the value". Grep the
  removed default's NAME across `test/`. (2) A gate added at layer N makes every "only this
  layer can catch it" sentence false, and the disproof is the SIBLING layer's own passing
  test — grade the quantifier against the other gates, not against the layer it contrasts
  with. Both shipped in one batch beside a file stating the correct plural version, i.e. two
  answers to one question. A group header's "each test below asserts X" is the same defect
  once the group holds positive CONTROLS: strike the quantifier, never re-count (BUT-1908/1909).
  **(3) A DESIGN REVERSAL mid-batch, which is the worst of the three because the assertions
  stay GREEN and a PRIOR ROUND has usually graded the rationale sentence TRUE** — a rollback
  restoring state to the same object leaves every `same(x)` passing under both designs, so
  only the comments died. BUT-1962's "each had to be REORDERED" was graded true against the
  pre-reversal diff, survived on that sign-off, and then prescribed the exact ordering the
  reversal removed as a bug. A round's TRUE grading is valid only against the bytes it
  measured: when the round's own production shape changes, re-grade every sentence the
  earlier round cleared, and re-ask what the mutant is NOW (here: delete the rollback, not
  swap the order) rather than what it was. **The reversal can land DURING your round, and
  INDEX and WORKTREE can then hold OPPOSITE designs of one method while the suite is green on
  both** — measured on BUT-1962 (63/63 either way; a scratch pending-state probe passed on the
  index bytes and failed on the worktree ones). When the verdict-time isolate-diff shows a
  REVERSAL rather than an edit, refuse to grade "the change" as one object: say which COPY each
  finding is against, and treat a comment that flips false→true→false with nobody editing it as
  proof the batch is oscillating, not converging. **A reversal can also RESTORE the mutant an
  earlier round retired, so re-probe rather than inherit the fix report's "reverting reddens
  exactly N" — that figure measures the probe PATCH's scope, not the suite's.** BUT-1962's
  final persist-then-publish shape was reported as pinned by three entry-mutator tests; a
  two-method mutant showed `clearWeek` and `undoClearWeek` each redden on their own
  `same(<pre-save plan>)` assertion (2026-08-27). One `cp`-backed probe on ONE file, restored
  and md5-verified in the next call, settles it in ~90s. **A sentence a reversal falsified
  outlives the ticket that reversed it and rides into the NEXT one's staged commit** — the same
  "each had to be REORDERED" clause was still the group header at BUT-1975/1965, where the code
  publishes before the save by design, so it now prescribes reverting a decision the founder
  made. When a ticket reverses a design, grep the PRIOR ticket's graded comments as part of the
  new review, not only the new diff; the repair is a strike (2026-08-28).

### Project-specific test infrastructure (full detail in `testing-specialist.md`)
- Production ServiceLocator bridge: `production.ServiceLocator.initialize(DIContainer())`
  in `setUpAll`; both ServiceLocator classes share one `GetIt.instance`.
  `BaseUnitTest.setupUnitWithProductionLocator()` does both and works inside a GROUP-scoped
  `setUp` in a widget suite that otherwise never touches DI — pair it with
  `TestServiceLocator.reset()` + `prod.ServiceLocator.reset()` in that group's `tearDown` so
  no sibling group changes behaviour. Registering the household stack that way is what makes
  the presence row (`roster.length > 1`) and `showWhoIsHomeSheet`'s self-built
  `WhoIsEatingViewModel` reachable from a widget test; that VM resolves `CookEventRepository`
  in its CONSTRUCTOR even on the presence path, where it never calls it, and
  `test_service_locator.dart` does not register one (BUT-1982, 2026-09-02).
- **A widget test driving a real screen can be blocked by an unrelated RENDER assertion in a
  sibling branch of that same screen, and the right move is to satisfy the tested condition
  through a branch that does not reach it — then FILE the render defect.** BUT-1982's notice
  is gated on `hadMenu`, a WEEK-level condition, so putting the fixture's dish in `ovrigt`
  instead of lunch/middag keeps `hasEntries` true and avoids the filled-slot cell whose
  `Expanded` asserts under a presence row. Weakening the fixture to dodge a crash is only
  legitimate when the dodged branch is provably not what the test claims to prove.
- **`git stash` cannot attribute a failure when the worktree carries ANOTHER session's
  uncommitted work** — stashing your file reverts theirs too, so a suite that goes green
  reads as "I broke it" when the real cause is their staged-nowhere change. Remove your own
  additions IN PLACE (script it, assert each anchor is unique, keep the removed text in the
  scratchpad) and re-run; if it still fails, it is not yours. Same reason a probe RESTORE
  here cannot use `git show :<path>`: the index is HEAD and the fix under test is worktree-only
  — back up to the scratchpad and `diff` the restore (BUT-1972/1982, 2026-09-02).
- `MockUnifiedRecipeService.setRecipeState()` defaults `isInitialized: false` — pass it.
- Debounced VM: `fakeAsync` + `async.elapse(300ms)`; `executeDebounced` fires 3
  notifications. `test/views/` is journey-test territory (owned by `e2e-test-specialist`).
- **A repoint to `collectionGroup(...)` is HALF a fix** — needs a `fieldOverride` with
  `queryScope: COLLECTION_GROUP` or FAILED_PRECONDITIONs; `deploy --force` prunes anything
  absent from `firestore.indexes.json`. Suite needs three arms (override exists at group
  scope, exact set survives delete+add, source still spells the field). Register the npm
  `test:*` script in the same edit.
- **A `setUpAll(registerFallbackValue(...))` added with "the suite had none" is a MEASURED
  claim about the whole file, and the cheapest check is deleting it and re-running** — BUT-1962
  added one to `weekly_menu_plan_service_test.dart` under "nothing stubbed `save` before" while
  the file already held four `registerFallbackValue(_FakeWeeklyMenuPlan())` and four
  `repo.save(any())` stubs; the new group used no `any()` on a plan at all, so the line was dead
  and its reason false (46/46 green without it). Grep `registerFallbackValue` and the mocked
  method across the WHOLE file before writing the sentence (2026-08-27).
- Source-text assertion suites must strip comments first, or a bare `includes` stays green
  after the setting is deleted; probe non-vacuity with a STRING mutant, never a file mutant.
- **A TAUTOLOGICAL assertion is not automatically a coverage hole — grade the whole test
  before repairing it, and grade it ARITHMETICALLY.** `hasLength(<the constant>)` over N
  appends does compare the prune's bound to itself, but the sibling `first.entryId == 'e5'`
  in the same test is `e(N − cap)` and already reddened on EVERY cap change, so swapping in a
  literal added no kill and the repair's "previously a lowering was silent here" was false.
  Substituting the mutant value into the fixture's own arithmetic settles this in seconds and
  outranks a mutation probe, whose GREEN is only a hypothesis. Two companions: a
  cross-language DRIFT guard (`rules_numeric_bound_drift_test.dart`) pins EQUALITY between two
  copies, never the VALUE — only a suite asserting the number absolutely does that; and the
  moment such a guard lands, any "nothing ties these two copies / a lowering diverges
  silently" comment on the OTHER side goes false, so grep that concept in the same round
  (`firestore.rules` `groupMenuTrailWithinCap`, BUT-1971, 2026-08-30).
- **A stub must reproduce the production return's IDENTITY, not just its VALUE, whenever the
  code under test branches on `identical(...)`** — `GroupWeeklyMenuPlanService.removeEntry`
  returns the plan ITSELF when the id is missing, and a stub calling `copyWith`
  unconditionally hands back a fresh object, so `_edit`'s `identical(updated, current)`
  short-circuit never fires, the sequence counter advances, and a test written to pin the
  already-gone-row branch passes on the UNFIXED code (measured 34/34 both ways; with the
  mirroring stub the mutant gives 33 green + 1 red). The mutant reddening NOTHING is the
  vacuity showing itself. Read the production method's early-return line before writing any
  stub of it, and check which sibling stubs remove an id the fixture does not hold — only
  those are exposed (2026-08-29, BUT-1971).
  **A stub that correctly mirrors the identity return still silently drops the method's THROW
  arm, and that arm is usually pinned nowhere** — grade a hand-written stub against the
  callee's guard clauses as well as its early returns. `restoreEntry`'s `_requireEditor` was
  unpinned repo-wide the day it shipped, and so were the four sibling mutators' on the same
  class: the check is `grep -rn '<Service>(' test/` for suites constructing the REAL service
  (two here) and then the exception name inside them (zero) — N-of-N mock-only IS the finding,
  and it ranges over every method on the class, not just the round's new one. Confirm the gate
  WORKS with a scratch `_zz_probe_test.dart` rather than a `lib/` mutant: ~15s, no
  parallel-session clobber, and a green probe there proves the gate EXISTS, which is a
  different claim from pinned (BUT-1971, 2026-08-30).
- **A test asserting that a value SURVIVES a rebuild cannot tell "carried through" from
  "never rebuilt"** — deleting the whole swap branch of `moveEntry` leaves every
  `proposedBy`/`votedInBy` assertion on the swapped-aside dish green, because the occupant is
  then never passed through `copyWith` at all. The fixture REACHING the branch is a separate
  fact from the assertion DISCRIMINATING it, and hand-tracing the former is what makes the
  latter look settled. Pin the rebuild itself (`expect(after['e2']!.day, <the source's day>)`)
  beside the carry, or the test's own name is the only thing claiming the branch ran
  (BUT-1971, 2026-08-30).
- **A mocktail matcher goes vacuous only when a named arg's value stops equalling its
  DEFAULT** — `verifyNever` is the dangerous direction: a non-default named param can never
  match the omitted-param form, so the guard is UNFAILABLE. Spell every named param.
- A poll-until-condition loop discriminates only if the assertion sits AFTER it, polling the
  LAST observable step. `retry:true` owes a reachability read of `isCascadeEventExpired` as
  the handler's FIRST statement, or a deref above it escapes the bound.

### Coverage decisions
Codecov: 60% project / 70% new patches / 2% drop tolerance — floors, decided 55% project
(2026-07-11); don't file generic "raise coverage" tickets.
- **When a cleanup DELETES a pair of unsafe delegates and deliberately KEEPS one twin, the
  kept twin is the unpinned one** — the deleted side gets a retargeting round and the survivor
  gets a rationale sentence instead of a test, because its sole caller's suite stubs it on a
  mock service. `grep -rn '\.<method>(' test/` and ask whether ANY hit constructs the REAL
  service; N-of-N mock hits IS the finding. Close it with a PAIR (failure fallback + persisted
  passthrough) — the fallback assertion alone is satisfied by an "always empty" mutant
  (BUT-1948, `WeeklyMenuPlanService.getWeek`, 2026-08-28).
- **A method whose RETURN TYPE widens (`Future<void>`→`Future<bool>`) adds an observable with
  zero test hits by construction — every existing call site discards it, and the suite stays
  green under `return true`.** Grep the method in `test/` and read whether ANY call assigns the
  result: 8 of 8 discarding IS the finding. The sibling that IS pinned is what hides it —
  BUT-1962 gave `assignRecipe` and `clearWeek` a bool the same day; `assignRecipe`'s is held
  indirectly (`assignFromOverflow` prunes only on true), `clearWeek`'s gates a success snackbar
  and was held by nothing at any layer (2026-08-27). **The same grep answers for an UNCHANGED
  return value whose only assertions sit at a MOCK-service layer**: `copyWeek`'s copied-count
  drives a Swedish snackbar and is asserted in the viewmodel and widget suites against a stubbed
  service, while all four real-service calls `await` it and discard — so replacing the RETURN
  VALUE with `0`, the exact symptom the ticket was opened for, reddens nothing. (Gutting the
  whole body is a different mutant and does redden the save-refusal test.)
  (BUT-1962/1948, 2026-08-28). **When ONE change widens the return of TWIN methods, the round
  writes an end-to-end test for the branch the VIEW takes by DEFAULT and leaves the twin
  unpinned at every layer — and a comment claiming the pair is "pinned in the VM suite" is the
  tell, not the evidence.** BUT-1982 widened `setSlotPresence`/`setDayPresence`; the widget
  suite drives only "denna måltid", so gutting `setDayPresence` to always-true (its
  `_readFailed` guard included) ran 92/92 GREEN across the VM AND widget suites, while the
  slot twin reddens. The VM suite named in that comment `await`s both and asserts NEITHER
  return. Grade a widened return PER BRANCH of the caller's ternary, and resolve any "pinned
  in <other suite>" pointer with `grep -n '<method>' <that suite>` before believing it
  (2026-09-02). **The REPLACEMENT for that struck pointer then shipped a count silently
  qualified on a VERB**: "the VM suite's three call sites `await` the two methods and DISCARD
  the bool" — four call sites, one of them `unawaited(...)`, so the numeral is right only for
  the awaited subset the sentence does not name. Strike the numeral and state the property the
  grep settles ("no VM-suite call site asserts the returned bool"); a count repairing a false
  pointer is the same seam one round later (BUT-1982 round 2, 2026-09-02).
  **Round 3 then INVERTED the measurement while removing its numerals: an ASYMMETRIC measured
  fact ("gutting the day twin left the suite green while the slot twin reddened") must not be
  de-numeralised into a SYMMETRIC quantifier ("gutting either twin alone leaves the suite
  green") — the asymmetry WAS the finding, so the quantifier is not merely unmeasured, it is
  false in both readings (service-level and view-ternary), and it licenses deleting the very
  cases the round added.** Two mechanical tells, either enough, and neither needs a probe:
  the sentence contradicts its own preceding clause ("BOTH branches are driven"), and the
  file's untouched sibling comment 160 lines down still carries the true asymmetric wording,
  i.e. one file answering one question two ways. When a strike round targets a sentence whose
  content is a COMPARISON, strike the whole clause — the surviving mechanism sentence
  ("`_onTapPresence` picks between the two on a ternary") is the whole warning; a
  de-numeralised comparison keeps the shape and loses the direction (BUT-1982 round 3,
  2026-09-02).
- **Open a review by grepping each NEW TOKEN into a token→files table** (~30s). Zero files
  IS the finding; hits only in an extracted class's own suite means the composing line in
  the CALLER's suite is still unproven (BUT-1838: a `copyWith` carry, a DTO write asymmetry,
  a query filter — three sibling suites untouched).
  **A new GDPR EXPORT SECTION spans several seams and the round's suite lands only on the
  manager one** — the repository's Firestore PATH, the manager's shape, the bundle
  WIRING in `data_export_service.dart`, and its `data_minimisation` disclosure line. The manager suite fakes the repository, so the path
  is invisible to it (BUT-1697's wrong collection matched zero rows and dropped every
  shopping list), and no manager test sees the bundle map, so the section's whole reason for
  existing — export ⊇ erasure — is deletable-green (BUT-1732 wrote that warning into
  `data_export_service_test.dart` as a comment and the next section still shipped without
  it). Both lanes already exist: `firebase_data_export_repository_*_test.dart` (real repo on
  `FakeFirebaseFirestore`) and that suite's `should include all required sections`. One
  end-to-end there — seed the real subcollection plus a DECOY in the neighbour, assert the
  bundle key — kills both mutants at once. Measured on BUT-1957: repointing the collection
  left 86/86 green, deleting the bundle entry 40/40 (2026-09-02).
  **And a new section's failure envelope is pinned only by the file's parameterised `cases`
  table, never by a hand-written `completion(isA<Map>())`** — that matcher is satisfied by
  the raw-leak mutant `return {'error': e.toString()}`, i.e. by the exact defect (BUT-1760)
  the table exists to prevent; measured 39/39 green. Adding the row to the table is the
  whole repair, and it also grades the section PHRASE, which reaches the bundle as
  "Could not export &lt;phrase&gt;." — a snake_case key there is a user-visible defect the
  hand-written test cannot see (BUT-1957, 2026-09-02). **The seam a fix round still misses
  after the other three are closed is the section's `data_minimisation` sentence** — the
  Art. 12(1) disclosure that IS the mitigation for whatever the section decided to keep, so
  it dies with nothing red while the kept third-party data ships on. Every sibling section
  carrying that key has a presence pin (`content_`/`social_export_manager_test.dart`),
  because each was added after a round shipped a sentence promising a redaction that was not
  happening; a section disclosing rather than promising needs the same pin, asserted BESIDE
  the passthrough test so the disclosure and the disclosed field die together. Settle it by
  grep, not by probe — the key is additive, so no other assertion can see it (BUT-1957 r2).
  **That pin then COUPLES the wording, so grade the DISCLOSURE against the mechanism
  it describes in the same round.** A substring pin freezes the sentence, which is the
  point — a later correction reddens instead of drifting. It also survives TRANSLATION only
  by luck: the pair held when the section went Swedish->English because
  `'name of the person'` sits inside `'first name of the person'` exactly as `'namnet'` sat
  inside `'förnamnet'`, so the negative pin still carried the underclaim alone. A positive
  worded slightly differently would have made the negative redundant in silence. Re-probe
  per DIRECTION after translating a pinned sentence, and prefer the phrase that pins the
  CLAUSE that carries the disclosure (`who shared it`) over a word the rest of the sentence
  also satisfies (`shared`). The defect beside it is the
  production comment's HEADLINE clause overclaiming what the mechanism does ("NAME, not first
  name" above a correct description of a `firstName()` returning the first token of any
  multi-token name). It errs in the privacy-CONSERVATIVE direction, so nothing under-protects
  — but it is the sentence a later round quotes to argue a wider keep. Strike the headline,
  keep the mechanism (BUT-1957 r3, 2026-09-02).
  **`FakeFirebaseFirestore` honours `.orderBy(f, descending: true)` on a SUBCOLLECTION but
  RETURNS documents that lack `f`, even as the only document** (measured 2026-09-02); real
  Firestore drops them from the result entirely. So an ordered export read is testable for
  ROUTING and ORDER on this lane, and its missing-field hazard — the "erasable but not
  exportable" row an enumerating cascade still deletes — is invisible in both directions and
  belongs on the emulator lane or in a note beside the seed. **Hits with a healthy SPREAD can still be
  zero coverage of PERSISTENCE: sort the hits by whether any of them drives the model's
  serializer.** BUT-1971 added three persisted fields (`editTrail`, entry `proposedBy`/
  `votedInBy`) with four suites naming them — a service suite on in-memory `copyWith`, a mock-
  level service suite, a widget suite, and a GDPR export suite that seeds RAW MAPS — so
  `toFirestore`/`fromMap` were untouched and the whole feature could fail to persist with
  everything green. The `if (x.isNotEmpty)` guards mean the lines never even execute. The
  model suite holding the "preserves every field" round-trip is the file a feature round never
  opens, and its NAME is the quantifier the round falsified; close the gap rather than scope
  the name, and pin the OMITTED-when-empty half too, since that is a stated contract
  (2026-08-30). **A telemetry constant added in the same
  commit as the behaviour it measures is the token that reliably lands with zero hits** — the
  sibling SUCCESS event is pinned, its new FAILURE twin is not, and it is emitted from the
  very `catch` the change made reachable, so a later re-swallow silences it with nothing red
  (BUT-1962: `onboardingMenuSeedFailed`). **The test written to close that gap is the one
  that goes green without reaching the failure it names**: the event sits in a `catch`
  wrapping a whole block, so ANY throw inside emits it — and the throw that actually fires is
  usually an unstubbed collaborator EARLIER in the block (the sibling SUCCESS test stubs
  `readWeek`/`addEntry` LOCALLY, so the new test inherits none of them and mocktail's
  MissingStubError is caught by the same `catch`). The stubbed failure is then inert and the
  test name is fiction. Never grade such a test by reading it: `verify(() => mock.<seam>())`
  in a scratch `_zz_probe_test.dart` copy names the only call that happened in one run
  (measured: `All calls: readWeek(...)`, save never reached — BUT-1962, 2026-08-27). The
  repair is to stub the earlier seams and keep the `verify` in the committed test.
  **The other reliably-unpinned new token is a call added to satisfy a REPO RULE rather than a
  feature** — `logPermissionCheck` per `lib/repositories/CLAUDE.md`. It is unpinned twice over,
  and each half hides the other: no repository suite injects an `auditRepository`, so the mixin's
  `if (auditRepository != null)` branch never runs and no row is ever produced; and the deliberate
  `requireCurrentUserId()`-vs-caller-supplied-`userId` choice (the rules refuse a row whose uid is
  not the caller, and the mixin's `unawaited(...).catchError` swallows that refusal) collapses to
  one observable whenever the fixture's authed uid IS the passed one. Template one directory away:
  `firebase_activity_event_repository_test.dart` → `'records the granted permission check via the
  audit repository'`; the killer fixture must DIVERGE the two uids and assert the authed one
  (BUT-1962, both weekly-menu repositories, 2026-08-28).
  **When ONE change edits TWIN repositories, the test lands on the twin whose refusal branch is
  a TAUTOLOGY and the untested twin is the one with a real actor gate** — BUT-1981 moved the
  audit call into the refusal branch of both weekly-menu repos; the per-user gate's first
  conjunct compares the plan to itself (reachable only by MIS-KEYING) and got three tests, while
  the group gate's `entity.canEdit(userId)` refuses live callers and got none: `git show HEAD:`
  on the group file ran 35/35 GREEN, so deleting its audit call, logging grants again, or naming
  the caller-supplied uid are all invisible. Grade a paired diff PER FILE and run the HEAD-bytes
  probe on the file the round wrote no test for. Two claim shapes this settles: reverting
  audit-on-grant reddens the GRANTED test ONLY (the refusal test still sees exactly one row, so
  "reddens both" is false — measure each), and the suspected latent vacuity on the NEGATIVE
  `expect(rows, isEmpty)` — that an `unawaited` audit write not yet flushed satisfies it too —
  is MEASURED CLOSED for `FakeFirebaseFirestore`: a row written through the mixin's
  `unawaited(...)` is visible to the very next `.get()` with ZERO intervening awaits, so the
  negative assertion discriminates. Settle it with a scratch `_zz_probe_*_test.dart` calling the
  public `logPermissionCheck` directly (~15s, no `lib/` write) rather than by reasoning about
  microtask order. The cheaper argument needs no probe at all and generalises: a GRANTED/REFUSED
  pair built from ONE fixture helper over ONE fake proves its own wiring — the refusal case's
  row IS the evidence that the granted case's `isEmpty` is not measuring an unwired
  `auditRepository`. (BUT-1981, 2026-08-29.) **When a later round FLIPS the granted arm from
  `isEmpty` to a real row, the divergent-uid fixture does not transfer** — BUT-1971 restored the
  granted row and left the authed-vs-passed divergence on the REFUSAL case only, so
  `userId: actorId` on the NEW granted line is swappable for `userId: userId` with every suite
  green. Grade the `requireCurrentUserId()`-vs-caller-`userId` choice PER CALL SITE, never per
  method (2026-08-30).
- **A guard added to close a review finding gets its EXISTENCE pinned and its CONDITIONS
  not** — the round writes the test the finding described, so deleting the block reddens, while
  stripping every conjunct but the one the finding named stays green. Measured on BUT-1971's
  undo re-arm: `if (!ok && _weekStart == forWeek && _editSeq == seqBefore + 1 && !dishBack)`
  reduced to `if (!ok)` ran 36/36. Grade each conjunct for HARM before filing: the week check
  is analytically inert (the getter re-derives the doc id, so a stale arm can never surface),
  the dish-already-back check degrades to a no-op undo, and only the SEQUENCE conjunct carries
  a real hazard — it is the same straggler class the sibling `removeEntry` arm already has a
  test for, which is exactly why nobody wrote it for the undo. **The test that closes ONE
  conjunct discriminates only while the fixture leaves every OTHER conjunct SATISFIED, and
  that is usually an unremarked property of a stub nobody would defend** — the race test's
  `moveEntry` stub returns `entries: [e2]`, dropping the dish the undo had published, so
  `!dishBack` stays true and the sequence mutant reddens; a stub "corrected" to preserve the
  other entries would block the re-arm on `!dishBack` instead, the mutant would survive and
  the test would be over-determined with nothing red. Name the conjuncts the fixture is
  holding open in the test, or a later tidy vacuums it (BUT-1971, 2026-08-29).
  **The MIRROR case is worse and is the one to grep for: a guard closing ANOTHER gate's
  finding (security, GDPR, rules) arrives with NO pin at all, because no finding asked for a
  test and the round's test budget went to the findings that did.** BUT-1971's fix round
  answered my serializer finding with four model tests and, in the same round, added a
  roster intersection to `GroupWeeklyMenuPlanService.addEntry` for a GDPR
  erasability hazard — `DA:0` on every line of that method across all five menu suites,
  while the sibling `restoreEntry`'s identical `_requireEditor` gate got a test the same
  round, on the argument that a client-side gate nothing exercises is not a gate. The tell is
  a method DA:0 whose class siblings are pinned; the check is `grep -rn '\.<method>(' test/`
  for a call on the REAL service (mock-level hits do not reach it) plus `grep -rn
  '\.<method>(' lib/` to confirm a live caller exists, since a callerless seam owes nothing.
  Read the fix report for guards it mentions in passing as "also changed by the other
  gates" — that phrase is where the unpinned code is (2026-08-30).
  **The mirror's own mirror: a DETECTOR added beside a well-tested MUTATOR reads as covered
  because the suite EXECUTES it and asserts nothing about it.** BUT-1971 gave the deletion
  cascade three new `probeResidualData` legs (roster, `lastModifiedBy`, and an
  `admin.firestore.FieldPath("memberPermissions", uid)` ACL leg) beside a deleter using the
  same three handles; four emulator tests pin the DELETER, the cascade run calls the probe,
  and deleting any leg leaves every suite green because nothing asserts `gdprCompliant` or a
  logged row. A completeness signal is observable only through its FAILING state, so grep the
  result flag's own name (`gdprCompliant`: zero hits IS the finding) rather than trusting that
  the function ran. Same region, same cause, and the reason a log-payload redaction beside it
  owes no test of its own: the lane that could assert it does not exist, and building it is
  only worth it once the leg it labels is pinned (2026-08-30).
  **"Owes no test" turns on whether an ASSERTION LANE EXISTS, never on the change being
  small, structural or a mere wrapper — and the lane question is SETTLED BY RUNNING a scratch
  probe, not by predicting a deadlock.** BUT-1971 wrapped a modal sheet's list in
  `ListenableBuilder(listenable: vm)` and declined the test because staging it needed a
  `Completer` in the profile stub and a resolve mid-route. Measured: the VM fires
  `unawaited(_resolveNames(plan))`, so a held-open `Completer` neither blocks `loadWeek` nor
  hangs `pumpAndSettle`, and the case is ~35 lines on the suite's existing `pump`/`stubRead`
  helpers. The mutant is `listenable: Listenable.merge(const [])` — it compiles where deleting
  the wrapper does not — and it left the file 24/24 GREEN before the test, reddening exactly
  it after. Rule: when the suite already drives the real VM, already opens the surface and
  already stubs the seam, the lane exists and the wrapper owes the test; reserve "owes none"
  for a sink with no harness at all. A modal route is the recurring shape, because every
  sibling test resolves its names during load and taps afterwards, so the whole group agrees
  vacuously (2026-08-30).
  **The fix round then closes it on ONE field and extends the same guard to a SIBLING field in
  the same edit, and the report reads the one fixture as covering both** — "since your read, X
  is also intersected, so the first test's sibling assertions cover both fields" was false:
  `addEntry`'s `votedInBy` intersection got a killing fixture (an off-roster voter) while the
  `proposedBy` one beside it stayed deletable-green, because every real-service fixture passed
  an ON-ROSTER proposer or none. No probe is owed — the guarded and unguarded expressions
  evaluate to the same fixture literal, which is the analytic case. Grade a guard PER FIELD it
  was extended to, and grade the DERIVED writes beside it (a trail row's `subjectId`/`entryId`
  taken from the filtered value are pinned by nothing when only the entry's own field is
  asserted) (BUT-1971, 2026-08-30).
  **The same arithmetic grades a SET WIDENED OVER SEVERAL SOURCES — a name-lookup set fed by
  participants + proposers + voters — and only the source contributing a uid no OTHER source
  holds is pinned.** BUT-1971's `_resolveNames` gained two spreads: the voter one is
  discriminated (the fixture's voter sits off the roster, so deleting it renders the
  unknown-member mark where a name is asserted), while the proposer one is deletable-green in
  every fixture, because each proposer is also a participant, or also a voter, or has no
  profile to resolve. The killing fixture is a uid appearing in EXACTLY ONE source AND
  resolvable — which is the case the widening's own comment describes (a proposer who has
  since left the group). Build the fixture-uid × source table before grading such a widening;
  reading the spreads one by one makes all of them look covered. **And read the LOOKUP STUB
  first, because it can make the whole table moot**: `when(() => userService.getUserProfiles(
  any())).thenAnswer((_) async => [everyProfile])` ignores its ARGUMENT, so every profile lands
  in the name map whatever the set asked for and EVERY spread is deletable-green. The stub must
  filter on `invocation.positionalArguments.first` — that one line is what converts the table
  into kills (2026-08-30).
- **A claim about "the call sites" is measured over the CALLERS of the CHANGED METHOD, never
  over the one file the fix touched** — and `grep -rn '\.<method>(' lib/` is the whole check.
  Same commit, same class: a test comment quoting another suite's total ("all 304 of those
  tests") names a figure no reader can reproduce from any file and that the round's own new
  tests move. Strike the numeral rather than re-measure it.
  **The strike is only half the repair, because the claim comes back as a BARE QUANTIFIER over
  the same population and nothing about it looks like a count.** BUT-1962 struck "the six menu
  call sites, which all carry a Swedish errorPrefix" and shipped "the Swedish `errorPrefix`
  each ViewModel call site carries" two rounds later — same population, same falsifier, no
  number to notice. Two tells, either enough to file it: the sentence carries its own
  EXCEPTION CLAUSE ("not every caller is a ViewModel — the poll-close path…"), which is the
  author showing you they enumerated and stopped; and the falsifier ships in the SAME COMMIT
  (`OnboardingViewModel._seedSampleMenu` calls `save` inside a bare `try`, deliberately telling
  the user nothing — a hunk of that very diff). Re-run the caller grep against a
  bare "each/every X" exactly as against "the N X", and strike the quantifier, never repair it
  to "most" (BUT-1962, 2026-08-27).
  **Round five came back with the mirror move: the universal repaired into an EXISTENTIAL
  ("Callers differ — SOME carry no prefix"), which reads as a concession and is falsifiable
  the same way.** Measured false — 14 of 14 `executeAsyncVoid` sites that reach the changed
  `save` carry an `errorPrefix`, and every caller that carries none (poll-close, onboarding
  seed, the widget call sites) does not route through `executeAsyncVoid` at all, so the
  sentence's own preceding clause fixes the population it is false over. Run the caller grep
  against "some/not every/a few" too; the tell is unchanged (an exception clause naming ONE
  caller). And the strike round sweeps the files the FINDING named — here service + suite —
  leaving the SAME claim as a paraphrase one layer down (`firebase_…_repository.dart`: "reach
  the Swedish message its call sites already carry"), so grep the CONCEPT across every layer
  the changed method passes through, not the two files the report lists (BUT-1962, 2026-08-27).
  **The same caller grep decides whether an unpinned seam OWES a test at all, and run it
  BEFORE filing.** A VM pass-through whose arguments no test captures is a finding only if
  something calls it: `GroupWeeklyMenuViewModel.moveEntry`'s sole `lib/` hit was a
  same-named method on a DIFFERENT viewmodel, so an argument-swap mutant harms nobody and a
  test would pin a test lever. Reachability of a generic `catch` is the mirror question,
  answered by grepping `throw` in the CALLEE: the group menu service's non-permission
  throw (`StateError('Entry not found')`) lives in that callerless `moveEntry`, while its
  `removeEntry` returns the plan UNCHANGED for a missing id — so the arm is dead in
  production and its enum twin on the save path is what carries the behaviour. Grade a
  same-enum-different-site arm by its callee's throw surface, never by the enum
  (BUT-1971, 2026-08-29).
- When a fix SPLITS one write/event across destinations, or teaches a method a new
  side-field, grep every WRITER/reader's OWN SUITE (not `lib/`) — the list grows mid-round.
- **A figure measured OUTSIDE the repo (corpus gold, an eval sweep) has no test holding it,
  and manufacturing a fixture is worse than saying so plainly** — grep the marker's own FIELD
  NAME across `test/`; zero hits IS the answer, and the in-repo fixture corpus usually does
  not model the graded axis at all. The review a test cannot do is ARITHMETIC ACROSS THE
  COPIES: recompute every stated delta (before + added − relabelled) against the totals in
  each file quoting them; prose like "confirmed all 14, re-labelled one and added nine" can
  admit two readings whose splits differ while the total agrees. Grade a stated COUNTERFACTUAL
  the same way — "had the PAIR gone the other way it would read N" prices an UNMEASURED state
  when only ONE label was ever in play; the giveaway is the paragraph's own header saying
  "sensitive to ONE label". A `tools/` script with `main()` + private helpers is untestable
  by construction — an EXTRACTION ticket, not a missing test. But a hardcoded count in its own
  printed BANNER is neither: delete the literal and interpolate the runtime tally, which makes
  the drift class impossible instead of watched (a test would be a tautology afterwards). It
  misreports only on the arm that computes nothing — check for a short-circuited
  `if (flag && probe(x))` leaving the DEFAULT arm with no number to interpolate. **HOISTING
  that probe out of the short-circuit falsifies every doc sentence explaining why the default
  arm was safe ("never reads X") — grep the CONCEPT, not the field name; the clause that
  survives a sweep is the one spelling it in prose. A DATED `lessons.md` record is exempt only for FIGURES a later re-grade
  falsifies; a mechanism claim that was FALSE WHEN WRITTEN gets corrected there like
  anywhere else, or the batch ships two answers to one question.** A hoisted tally is
  population-independent, so
  `gateCounter == tally` holds ONLY on the gated arm — verify the OTHER arm's banner reads the
  tally, not the zero counter. **Then grep the file for the numbers the fix says it removed:
  "this file now contains NO count" survived a round as the stated justification for dropping
  the tool from a hand-carrier list, while a ticket-scoped historical count sat in its header.
  That count is legitimately exempt (anchored to a past grading, it cannot drift) — the defect
  is the unqualified absolute, so the fix is "no count of the CURRENT set", not a deletion.
  **That correction then becomes a STANDING INVARIANT THE SAME BATCH VIOLATES**: a later
  comment-only round re-typed the live tally (`fragment+tail`, the value the census class's
  own doc says to never type) into a NEW comment far from the promise. So re-grep the current-set VALUE, not the phrase, every round of a
  multi-round batch; the tell is a figure carrying no ticket and no date, since the carve-out
  saves an attributed-and-superseded figure and nothing else. Same round, same file: a
  comment advising "check X before quoting" while itself quoting an X derivable from nothing
  the tool prints — state the RULE and how you'd tell, never the current reading.
  **Deleting the stale figure is only HALF that repair: name what the run CANNOT print, or
  the next writer re-derives it and re-types it.** But grade an "unprintable" claim against
  EVERY printed artifact, not the two counters the sentence itself names: the ENTRY-scoped
  tally and the POPULATION-scoped page count genuinely fail to reconcile, yet a THIRD table
  (per-page movement deltas) settles half the claim — deltas sum to the tally, and an
  undercount cannot be masked because each page contributes at most once. Confirming the
  broad version on the named pair's merits alone is how one reviewer said "nothing printed
  can settle it" while another correctly found the table that does. An ENUMERATING doc ("four
  states, not three") is the same class of claim: a returning helper's list of named values
  + sentinel drops the PASS-THROUGH state (any other value returned VERBATIM), which is the
  state the sentinel exists to expose and the one a call site's `else { /* absent */ }`
  silently eats. Grade a private `tools/` helper's return contract by RUNNING a scratchpad
  replica of the function AND its caller's classification chain over the full input lattice
  (13 cases, ~30s) — reading is how the doc came out one state short.**
  **A new declaration inserted above a function silently RE-PARENTS the doc comment that sat
  there** — the const gets a doc describing the function, the function gets none, and the
  orphaned first line usually also states the return contract the new declaration just
  widened. `git show HEAD:<f> | grep -B6` every symbol the change ADDS. A guard for MALFORMED
  external input (unrecognised-enum counter + warning) is watched, not impossible, so the
  tautology argument above does NOT cover it; it owes no test because the helper is private
  AND reachable only through a `main()` resolving its data root from the ENVIRONMENT —
  subprocess-only, NOT "untestable by construction". Say that: the extraction is ~10 lines
  into `tools/corpus/`, where `test/corpus/corpus_multi_layout_test.dart` already builds a
  synthetic corpus in a temp dir and constructs `CorpusPaths(tmp)` directly. Probe BOTH
  disjuncts of a `v is! String || v.isEmpty` sentinel — a wrong-TYPE injection leaves the
  empty-string half deletable-green, and the guard's own comment names both shapes. A
  sentinel added to a returning helper changes NO count when it is chosen for values the old
  code already mapped to the same downstream branch — prove that by equality of the two
  return tables, not by a probe. Its discriminating evidence is then the new OBSERVABLE it
  unlocks (a WARNING naming the offending path), which HEAD cannot emit — never a count,
  because every count in sight moves at HEAD too. **A comment-only INSERT between two existing
  sentences inherits BOTH neighbours' references**: a bare "the nine" lands with no antecedent
  in that file, and the retraction it was pushed above ("wrong on both examples it named") now
  trails a pair the retraction never meant. Grade an insertion's SEAMS, not only its claims —
  and when two independently-derived figures collide numerically (9 band TAILS vs 9 gold
  TOKENS), the conflation lands in the carrier that never says what the first nine counts, even
  though the sibling file already carries the disambiguator. (BUT-1847)
- **A comment's POSITIONAL safety argument ("the token must be the very first thing in the
  string") is graded against every ITERATION of the loop that consumes it** — a head-parser
  that peels twice exempts slot 2 too, so the argument is falsified by the file's own
  neighbouring comment ("peeled TWICE, because V8 nests them"). Scratchpad replica over the
  input lattice, 30s; the remedy is a qualifier, not code. Grade a QUANTIFIER in the same
  file by the population it ranges over and by EXPOSURE — "most of this app's exception names
  sit in the 20-28 window" is 12/31 by name, ~62% weighted by throw site; the durable repair
  is the most-THROWN spelling with the measured pair (90 family sites of 168 constructions).
  One `grep -c` is NOT the verifier and saying so was itself the error repeated: the naive
  count reads 173, because it also catches switch-PATTERN arms (`PermissionDeniedException()
  =>` in `shopping_failure_message.dart`) and a substring sibling (`TagConfigValidationException`).
  Require a `throw|return|=>` prefix, and say "family" — 89 of the 90 are the base class and
  one is `StaleAccessControlBaseException`, whose own label is a different 31 characters.
  **Then check the repaired bound is PINNED, because a widened qualifier is a NEW claim with
  no test**: mutating the loop 2→4 left all 21 green while 2→1 reddened exactly one, so the
  suite pins "at least two slots" and nothing pins "at most two" — the exemption can silently
  grow to slot 3+. The killer fixture is a digit-free 20-28 LETTER token, capital-initial,
  in the slot just past the last legitimate label (BUT-1897).
- **A collection's DOCUMENT-ID SCHEME change (deterministic→auto-id) breaks every reader
  that addresses/dedupes by it, invisibly** — grade writers keyed on `doc(x)`, mergers doing
  `byId[doc.id]=doc` (silent double-render), and field-keyed cascades (can lose their
  address if spellings never matched).
- A cross-language literal contract (a CF-written marker Dart matches) is usually pinned
  consumer-side only — a doc comment claiming sync is not a test; grep for the enforcing one.
  **Pinned on BOTH sides is still not pinned ACROSS**: when each suite types the literal
  independently, a one-sided rename reddens only its OWN side, and the red test hands the
  author the new spelling, so the fix lands and the other language silently degrades (here
  to `genericFallback` — no crash, no red). Check whether the emitting test IMPORTS the
  constant or re-types it (re-typing is the stronger pin) and then say the residual is
  DIRECTIONAL. The repo's enforcing pattern already exists and is cheap: a Dart test that
  `File(...).readAsStringSync()` on the `.ts` and regex-extracts the literal —
  `tag_phase1_seafood_safety_test.dart` does it against `sync-ingredients-core.ts`
  (BUT-1929, 2026-08-27). **Until that pin is built, the residual belongs in a TICKET and the
  mirroring test's NAME must state only what it asserts** — `'the cap constant is 100'`, never
  `'the cap constant mirrors MAX_CHAT_GROUP_MEMBERS'`: a name claiming the cross-language
  mirror is the sentence a later run cites to skip building the pin, and the test cannot
  observe the other language at all. Grade such a one-literal test's KEEP separately: its kill
  set is usually a strict subset of the end-to-end sibling's (a `contains('100')` on the
  rendered string reddens on the same constant change), so it survives as the named anchor for
  the residual, not as coverage (BUT-1929/BUT-1960, 2026-08-27). **A SHARED user-facing
  message CONSTANT is the same shape inside ONE language**: every consumer test writes
  `find.text(kMessage)`, so the SYMBOL is pinned at N call sites and the STRING at none — it
  can become any non-empty text and all suites stay green. Grep the literal across `test/`;
  zero hits IS the finding, and the repair is one test typing it verbatim (BUT-1962,
  `weeklyPlanReadFailedMessage`, 2026-08-28). **The worst form has NO constant at all: a menu
  ACTION string typed twice, in the emitting `PopupMenuItem(value:)` and in the receiving
  `switch` arm, with a `default:` that only logs — a typo on either side degrades to a menu
  entry that does nothing, no crash, nothing red. Grep the literal in `lib/` (two hits, two
  files) and in `test/` (zero) before calling a menu wiring reviewed; the emitting side is
  pinned by one widget test that opens the real popup and asserts the callback received the
  literal (BUT-1971, `'weekly_menu'`, 2026-08-29). The CLOSING shape is one widget test that
  pumps the real app bar with its `onMenuAction` wired to the real handler and taps the item's
  visible label: both copies of the literal then die to a single mutant, and no test needs to
  type the literal at all. Scope that follow-up to the whole WIRING, not the
  literal: the emitting side also carries a VISIBILITY filter
  (`if (conversation?.groupId != null)`) and the receiving arm an ARGUMENT decision
  (`groupId: conversationId`, deliberately NOT `conversation.groupId`) — a follow-up written
  from the literal alone leaves both. Grade the item NON-BLOCKING when the worst mutant is a
  wrong-id READ: display-only, no data loss, no permission bypass, since the rules gate the
  wrong document too. A twin entry point pinned in the SAME commit does not reach this call
  site — record the residual rather than read it as covered.**
  **A GENERATED `app_localizations*.dart` carries no logic, so its only reviewable question is
  which new ARB strings a suite types VERBATIM — grep each new literal across `test/` and read
  the answer as a table, not a verdict.** The unpinned ones cluster predictably: strings on the
  arm of an enum→l10n `switch` whose ENUM is asserted at VM level (so the arm looks covered and
  the mapping is not — but the killing mutant is ONE-DIRECTIONAL, never a swap: measured on
  BUT-1971, swapping `undoUnavailable`↔`saveFailed` reddens the sibling arm's pinned literal
  (1 red), while repointing the unpinned arm alone ran 50/50 green. Write the finding as
  "repoint arm X", or the fix round proves the wrong mutant), plus tooltips, sheet titles and
  snackbar bodies whose test taps a DIFFERENT literal in the same widget (`commonUndo`'s
  "Ångra" pins the undo button while the message beside it is free). Measured 8 of 17 pinned on
  BUT-1971. Rewriting the generated file is never the repair; a literal in the consuming widget
  suite is. **When no UI path can reach the state that renders the arm, drive the VM DIRECTLY
  under a real pump — that is the pin, not a shortcut**: nothing on the group menu can raise
  `undoUnavailable` from a tap, because the snackbar offering "Ångra" exists only while the undo
  is armed, so `await vm.undoLastRemoval()` on an unarmed VM inside `testWidgets` is what closes
  it (2026-08-29).
- **A refusal that REPLACES a whole body ships an ESCAPE HATCH nobody asserts.** The natural
  refusal test is the pair "message shown" + "the thing it replaced is gone", and both are
  entailed by the same branch; the third observable — `StateWidget.error(onAction: _reload)` —
  is untouched, and deleting `onAction:` reddens nothing because the label resolves to null
  and the button simply stops rendering. Pin it as first-read-fails/second-answers plus a
  CALL COUNT, which also kills a no-op callback (BUT-1962 slot picker, 2026-08-28).
- **"X was REPOINTED" — run X's PRE-EXISTING suite even if the ticket omits it.** It's
  written against the retired behaviour and usually passes VACUOUSLY (seam uncalled, fixture
  unseeded) rather than failing. Rewrite with a fixture where old/new DISAGREE, seed the
  new, assert the retired seam unreached (BUT-1838: 6/6 red after, 0 before).
- A capped/OR'd flag over N sources needs its recall control rebuilt when a source is
  added/removed (BUT-1801 43/43 survived; BUT-1832 9/9) — grade any capped section by the
  below/at/over trio.
- A fan-out loop + accumulator is one untested input whenever every fixture is a singleton
  — close at the outer layer with 2-cut+1-retained via a capture recorder, never
  `verifyNever` beside a positive. Dead work (unread map, unused helper) reads as coverage —
  file a deletion ticket.
- Two branches sharing one guarded block need separate inputs; one variable at N call sites
  needs proof PER SITE (`any(named:)` survives mutants on the other sites). A comment naming
  two shapes one guard catches is two claims — the second is often unreachable-but-true;
  reachability is a producer question.
- **An optimistic-publish ROLLBACK is pinned only for the field the refusal test reads, and
  every OTHER field it restores is deletable-green whenever the fixture's collateral collection
  is EMPTY.** Measured on BUT-1975/1965: deleting the rollback assignments for
  `_overflow`, `_recentlyPlacedEntryIds`, `_preClearOverflow` and `placedCount` across three
  hand-rolled catch blocks left 65/65 green, because every refusal fixture seeded an empty
  overflow tray. `_plan` alone was held. Grade a rollback FIELD BY FIELD, seed each collateral
  collection NON-EMPTY and DIFFERENT from what the operation would leave, and check the
  RETRY-after-failure path — a lost re-armed snapshot is permanent data loss the failure test
  itself cannot see. The guard's release in a `finally` is a separate question and is usually
  pinned only INCIDENTALLY, by whichever test performs a second write after a failed one
  (2026-08-28).
- **Fixture-shape family**: the fixture's own shape answers for the code. An accumulator off
  `.first` hides its loop unless the first item is interior on every axis; enumerate every
  field production READS, override each independently. **Two DIFFERENT expressions that
  evaluate to the SAME fixture literal collapse into ONE observable and the swap mutant is
  analytically unkillable — no probe needed, just read the fixture** (BUT-1856: a group's
  `ownerId` and the signed-in uid were both `test_user_123`, so six cases could not see
  `ownerId: currentUserId`, which breaks the feature for every non-owner because the CF
  addresses the category by OWNER PATH). Recurring pairs: owner vs caller, creator vs
  current user, group id vs conversation id, `isGroup` vs `groupId != null`. **The carrier that
  outlives the round is a fixture BUILDER that DERIVES one member of the pair from the other**
  (`isGroup: groupId != null`): the collapse is then invisible at every call site, no test can
  ever see the swap, and it survives the very commit that fixes the production line — BUT-1971
  moved `_showConversationInfo` to `groupId != null` (per `Conversation`'s own doc that `isGroup`
  is an ordinary client field) while both new chat/menu entry suites' builders held the two
  equal. Read the BUILDER, not the fixtures. **The same arithmetic settles an assertion
  ENTAILED BY ITS NEIGHBOURS, with no probe: `expect` is fail-fast, so a line evaluates only
  when the lines above it passed, and when those pin BOTH operands it compares its kill set is
  EMPTY by construction** — `createdAt == <a Wednesday t>` plus `weekStartDate.weekday ==
  monday` makes a following `weekStartDate isNot createdAt` unfailable. It reads as extra
  discrimination and adds none; delete it rather than probe it (BUT-1961).
  **The commonest carrier is a LEAK test**: an exact-string `expect(shown, '<the Swedish
  message>')` pins both operands, so the `for (final leak in [...]) expect(shown,
  isNot(contains(leak)))` loop below it is unfailable by construction, and the comment beside
  it names a mutant the EQUALITY already kills. Keep the equality, delete the loop — that
  loop earns its place only where the assertion above it is a `contains`
  (BUT-1962, 2026-08-27).
  **Where the neighbour IS a `contains`, entailment turns on whether the positive's match set
  swallows the regression wording — and TRANSLATING the pair silently re-decides that.** The
  containment is a property of the two LANGUAGES' strings, not of the test's intent, so a
  pin that discriminated in Swedish can arrive redundant in English or vice versa, with the
  suite green either way. Re-probe per DIRECTION after any re-wording of a pinned sentence,
  and read WHICH assertion the runner names: a negative pin that fires LAST proves the
  positives above it stayed green under that same mutant, which is the entailment answer
  itself. Measured on the `data_minimisation` note: `contains('name of the person')` is
  satisfied by the underclaiming `'the first name of the person'`, exactly as `'namnet'` was
  by `'förnamnet'`, so `isNot(contains('first name'))` carries that mutant alone
  (BUT-1957, 2026-09-02).
  **The other carrier needs no neighbour at all: an assertion on a state channel the subject
  NEVER WRITES.** `expect(viewModel.error, isNull)` is unfailable when the VM never calls
  `setError` and never routes through an `execute*` helper that would — grep the whole class
  for `setError|execute|handleError`; zero hits IS the proof, no probe. It reads as pinning
  "no error surfaced to the user", and the sentence beside it is usually TRUE as behaviour
  while nothing measures it. Delete the line; never "strengthen" it onto another surface,
  because a subject with no error channel has none (BUT-1962, 2026-08-28).
  **The concurrency carrier is LAST-WRITER-WINS**: two in-flight edits whose trailing arms
  both write one field resolve in CREATION order, so a test asserting the final value is
  answered by the ordering and not by the guard it names — deleting the
  `_editSeq == seqBefore + 1` conjunct reddened exactly ONE of the two undo-arming tests, and
  it was not the one named after it. Grade a "the older edit does not win" test by asking
  which write lands LAST under both variants; the discriminating shape lets the NEWER edit
  finish first (gate only the first save, as the sibling test does) — and if that variant
  fails on production too, you have found the unconditional `? x : null` clobber beside it
  (BUT-1971, 2026-08-29).
  **The ROLE carrier is a fixture builder that hardcodes the PERMITTED role.** A widget-test
  `_plan()` pinned to `SharedListPermission.edit` cannot reach the viewer state, so every
  `if (vm.canEdit)` affordance guard and every viewer-only banner has zero widget coverage
  while the suite reads complete — deleting the guard on a per-dish delete button leaves the
  whole file green, and the VM-level refusal test does NOT substitute, because it proves the
  DATA is safe and says nothing about offering a control that can only fail. Parameterise the
  widget fixture by role the way the unit fixture already is, and diff the two builders'
  SIGNATURES when a unit suite and a widget suite share a subject: a parameter present in one
  and absent in the other names the untestable state (BUT-1971, 2026-08-29).
  **Splitting one fixture instant into two (clock `t` vs caller's `date`) kills the
  VALUE-swap mutant and leaves the DERIVATION mutant alive** — inside `withClock` a
  same-week `date` makes `weekStartOf(clock.now())` byte-identical to `weekStartOf(date)`,
  so what kills it is a SIBLING test running OUTSIDE the fixed clock and pinning the derived
  id against a literal week. Two mirror suites can therefore match on the guarded axis and
  differ on that one; grade a "do these mirror?" question per AXIS, and check the unfixed-
  clock siblings, not only the clock-pinned test (BUT-1961, 2026-08-27).
  **The mirror image is a REFUSAL+CONTROL pair whose non-vacuity needs no probe at all**: when
  both cases pump ONE fixture builder and differ only in a stub, the control's green proves the
  path reaches the observable, and the refusal case's green then proves the stubbed seam WAS
  called — had it not been, that case would behave like the control and be RED. Grade such a
  pair by reading the two `when(...)` lines; reach for coverage or a `verify` probe only when
  the two cases differ in more than the stub (BUT-1962 `_onClearWeek`, 2026-08-28).
- A repository suite where every fixture lives in ONE scope can't see its scoping `where` —
  and habitually leaves inherited CRUD (`read`, `readAll`, `watchAll`) untested though it
  skips every filter the finders apply.
- A defensive DECODE helper's null branch needs the ABSENCE mutated, not the value, plus a
  wrong-TYPE row. **A `x !== undefined` → `x` (truthiness) swap in a guard is a FOUR-state
  behaviour change that an "absent" fixture structurally cannot see** — measured on
  `isChatDuplicateCandidate` (BUT-1904): `undefined`/`"text"`/`"system"` agree under both
  spellings, while `null`, `""`, `0` and `false` flip from refused to admitted. The tell is a
  doc comment that grew from "an ABSENT type counts as text" to "ABSENT, null or empty" while
  the suite kept its one `undefined` case: an ENUMERATING doc with one member pinned. One
  fixture per member, or the swap is revertible-green. **Check the swap against HEAD before
  filing it as a new behaviour — an EXTRACTION is the usual carrier, and the extracted copy
  is often the REGRESSION.** BUT-1904 pulled the predicate out of an inline
  `if (type && type !== "text") return;` that had shipped for three months and rewrote it as
  `!== undefined`, so the "new" behaviour was the bug and the fix restored parity. `git show
  HEAD:<file>` on the ORIGINATING call site, never on the new function, which has no history. A deterministic composite id + body-vs-path check makes "stored==payload"
  checks TAUTOLOGIES — isolate the one conjunct that can still decide.
- **A fail-loud parser deriving ownership from the STORED BODY is protective on read, an
  Art. 17 defect on delete** — the forged row becomes the one doc its owner can't erase;
  decide erasure from the composite-id PATH, not the body.
- **Guard-chain subsumption, three directions**: BACKWARD (an earlier guard pinned by
  nothing because a later one refuses everything it does), FORWARD (fixture must clear
  every downstream refusal WITH SLACK, never at an exact tie), SIDEWAYS (a new guard can
  unpin an older filter downstream). **The commonest SIDEWAYS carrier is a conjunct added to
  ONE copy of a duplicated predicate**: the other copy's ABSENCE of it silently becomes
  load-bearing, and no fixture can see it because the shared fixture builder hardcodes the
  field the conjunct reads. BUT-1904 gave the export's `isOthersBlockedRow` a
  `content == ''` test while the chat's `_withoutOthersBlockedRows` kept type-only — a
  correct asymmetry (the export owes the row, the screen must hide it) whose harmonising
  mutant reddens nothing, since every `duplicateBlocked` fixture reaching the service
  hardcodes `content: ''`. A production comment saying "do not harmonise these" is the
  DOC half and never the pin. Repair: parameterise the fixture builder on the field the new
  conjunct reads, one case per side, each named after the asymmetry. Total subsumption = comment, never a test. Run "which
  mutants killed nothing" and its mirror once per file. **Two CONSTANTS in different classes
  can sit at that tie with nothing pinning the coupling** — a writer's widest output vs a
  reader's bound, where the bound's doc comment states the coupling as its rationale. Mutate
  EACH side by one; two zero-red probes is the finding. **Before stating the writer's MAX,
  sweep EVERY branch that emits** — I called `formatSwedishDecimal`/`maxFractionDigits` an
  exact 20/20 tie from a probe covering only the `toStringAsFixed` branch; the plain
  `toString()` branch emits 22, so the bound is NARROWER than the widest output, not equal to
  it. A reviewer's measured sentence gets copied verbatim into the test name and comment, so a
  partial sweep ships as a false claim in the commit it was reviewing (BUT-1912, 2026-08-25).
- A guard inside a loop has a POSITION (before/after the accumulator update); one above a
  pre-existing early-return is blind to every fixture that falls through — usually the
  worst leak (raw content unfiltered).
- **A dropdown widened to keep an off-vocabulary value needs FOUR fixtures**: off-list-
  untouched; pick-something-then-pick-back (only killer of keying the list off current vs
  stored selection); empty-stored; literal vocabulary pin (BUT-1858).
- **A fix that DELETES dead code is mutation-dead by construction** — reverting it restores
  behaviour identical to the fix, so no test can redden. Only the FORWARD direction is
  pinnable ("the field must not come back"); say that in the name, and never also assert the
  VALUE the deleted code could not produce — that half is a tautology (BUT-1873).
- **A `StyledInput` with `keyboardType: TextInputType.number` silently gets
  `FilteringTextInputFormatter.digitsOnly`**, so any `replaceAll(',', '.')` decimal parse
  below it is DEAD and "1,5" reaches the model as 15. A suite over a numeric field that never
  types a DECIMAL cannot see it — measured, shopping add/edit dialogs, 2026-08-17.
  **RUN the OLD formatter's regex before choosing the fixture that proves its replacement**:
  `allow(RegExp(r'^\d*\.?\d*'))` TRUNCATES at the comma ("1,5"→"1") because `^` makes
  `allMatches` yield one match at index 0 — it does NOT concatenate like `digitsOnly`
  ("1,5"→"15"). The two failures need OPPOSITE fixtures: truncation lands INSIDE any range the
  true value satisfies, so `expect(validate(), isTrue)` is satisfied by the pre-fix code.
  Assert the parsed VALUE, or set a bound BETWEEN the truncated prefix and the true value. The
  wrong mental model shipped as three comments AND as the fixture chosen from them (BUT-1920,
  2026-08-25).
- A flag selecting between two values is pinned by both arms over one fixture with
  observably different values — no production mutant needed. A nullable override deriving
  its default from a nullable payload owes a third arm: the EMPTY (non-null) payload.
- "Declines/falls back" needs `equals([input])`, not `hasLength` — catches truncation. A
  test named after an input must assert that input's VALUE.
- "X does NOT happen" needs proof the code reached where X could — "no write" can mean
  skipped OR identical values; count writes, positive control same test. **A refusal test
  written beside a new fail-closed guard is the standing carrier of this**: BUT-1939's
  placement case asserted `savedPlans isEmpty` after a failed read with NOTHING placed, so
  `hasPlacements` refused first and both save assertions held under every mutant — the
  discriminating lines were the `plan isNull` / error pair above them. Drive the refused
  ACTION to the point where it would write (place an item, seed an entry the mutator can
  find), and treat the guard's own SECOND copy (a `_readFailed` early-return duplicating a
  `_plan == null` guard) as deletable-green until a fixture clears the state the two spellings
  differ on. **"Drive the refused ACTION" is itself a claim, and the repair round is where it
  ships false**: the same failed read that armed the guard nulls the state the driving call
  needs, so `placeSelectedAt` before `confirm()` placed NOTHING (`DA:197,0`) while its comment
  said the save assertions now discriminate — they still don't; the error-message pair still
  carries the kill. Read the inserted call's OWN early-returns against the state the failure
  left, and never let a `thenReturn(<fresh instance>)` stub sit under a comment about an
  `identical(...)` short-circuit — the stub decides, so the fixture it names is inert.
  **The silent-return→throw rewrite is the same family seen from the other end**: when
  `await expectLater(call, throwsA(...))` is put ABOVE a surviving "nothing was written"
  assertion, that assertion is now UNREACHABLE whenever the throw is missing, so it no longer
  carries the missing-guard mutant — the `throwsA` does. What it still kills is the ORDERING
  mutant (write, THEN throw), and that is the only sentence a comment beside it may claim.
  Grade the matcher's discrimination from the TYPE LATTICE, not by running anything:
  `PermissionDeniedException implements Exception` while `StateError` is an `Error`, so the
  two branches' matchers are disjoint and a production swap reddens both tests. Attribute the
  denial to ONE conjunct: `save(plan)` passing `plan.userId` into
  `validateUpdatePermission(userId, id, entity)` makes `entity.userId == userId` a tautology,
  so the doc-ID prefix is the sole determinant — and on the group repo, a valid prefix leaves
  `canEdit` as the sole determinant only while the id-prefix guard above it stays silent
  (BUT-1962, 2026-08-27).
- **Grade a read-side guard against EVERY WRITER in the file, not the mutators the fix's
  tests exercise — and the sentence "every save site guards on null" IS the finding.**
  BUT-1939 nulled `_plan` on a failed read and pinned the entry mutators (all of which
  already had a null guard); `applyGeneratedMenu` rebuilds a plan from scratch
  (`existing: _plan` nullable) and saves unconditionally, so a failed read still upserted a
  generated week — over the WRONG week, because `currentWeekStart` falls back to `clock.now()`
  when `_plan` is null. The unguarded site is reliably the one that DERIVES its payload
  instead of mutating the loaded one; a ~90-line probe suite in the same dir settles it in
  ~30s with no `lib/` write. A test named "a later SUCCESSFUL read clears the refusal" that
  never re-runs the refused action leaves the RESET assignment unpinned in the same way.
  **Then refuse the aggregate probe the fix round offers back**: "neutralising every guard
  reddens exactly N" ranges over the SET and cannot see a per-site gap — mutate one site at a
  time. BUT-1939 shipped six guards, two reached by no fixture, and the unreached one with
  teeth was the one whose refusal branch returns BEFORE the state reset the other paths rely
  on (a selection from the previous week survives the failed re-read and retargets).
- **An OPTIMISTIC publish is pinned only where a test observes state while the write is still
  PENDING — count the `Completer`s, one per COPY of the publish, not one per method.** A test
  that awaits the call sees only the settled state, which a rollback makes identical to
  never-publishing, so the offline behaviour (write applies locally, future never completes)
  is unasserted however many refusal tests exist. `grep -n "Completer\|unawaited"` on the
  suite is the whole check. The probe is TEST-side and cheap (a scratch
  `_zz_probe_test.dart` asserting the pending state; PASSING proves the behaviour exists and
  nothing pins it). Its twin defect is the ROLLBACK of a collateral field (an overflow tray,
  a snapshot) whose fixture is empty in every refusal test, so restore and no-op are one
  observable — seed the collateral field through its real producer before grading the
  `catch`. Ask FIRST whether the publish is optimistic at all: the change this was learned
  on reverted to persist-then-publish before it shipped, so a reader grepping its symbols
  finds nothing (2026-08-27).
- A guard skipping a per-parent subcollection probe is unfailable when the probed doc
  doesn't exist — repair with a TRAP row at a path production never writes, spelled with
  production CONSTANTS (a literal drifts dead on a rename).
- **A write the RULES refuse is 100% green under mocks, and its TWINS stay refused — grep
  the file, not the ticket.** Every field the write touches: grep `firestore.rules` for a
  deny; each surviving twin owes a comment naming the rule LINE. A comment quoting a
  deny-list beside a round-trip assertion names TWO populations that legitimately differ —
  the RULE's key list and the SERIALIZER's emitted set — so "every one of those keys is
  re-sent" is a measured claim to check against the DTO, not a restatement. The keys a
  client never writes are pinned by an ABSENCE test at the serializer, and a module-level
  copy is a strict duplicate through the same function (BUT-1831: `groupId`/`memberSince`).
- A source-text guard pinning `keys().hasOnly([...])` has five vacuity seams: widest
  payload; complete writer set (forever); anchor sentinel checked against the NEXT match,
  not global uniqueness; blind to the `hasAll` mirror; can't see a SWAP (delete+add, count
  unchanged). Prove by neutralising the call and watching the WRONG-LIST message (BUT-1830).
- The client-side twin: an injected `Future<bool> Function(T)` stubbed true can't show what
  PRODUCTION binds actually rejects — resolve the argument to its terminal implementation,
  owed once per SPRINT (a feature can ship end-to-end while every write stays refused).
- A CF split into pure core + DI'd orchestrator ships the orchestrator untested — a `noop`
  verdict can't see "writes no second message"; the missing fixture is always the
  outsider-vs-member split the gate eats first.
- A guard replicated across sibling fields is tested on one field only — enumerate fields,
  one fixture per field per branch. **A multi-alternative REGEX is that same shape**: pin one
  fixture per alternative its own doc comment enumerates, or deleting a branch reddens
  nothing. BUT-1897's frame splitter named three stack spellings (`#0 `, V8 `at `,
  `fn@url:line:col`) and shipped with the V8 one — the majority browser — unpinned, because
  the two tests written were for the two spellings the ticket's prose talked about (closed
  2026-08-20). Grade the whole family in ONE cheap run: a scratchpad replica of the
  consuming function plus a MATRIX of full-regex × one-alternative-deleted variants over
  every fixture — no `lib/` write, so the auto-mode classifier never fires, and the
  alternative each fixture uniquely kills is read straight off the table. Two things only
  the matrix shows: an alternative can be killed by TWO fixtures (fine) or by NONE (the
  finding), and in a MASK-head/PRESERVE-frames splitter only the PRESERVE assertion pins the
  split — the privacy assertion beside it is satisfied under every split mutant (a
  no-match falls back to masking EVERYTHING), so it is a control against un-masking, not
  evidence the split works. `hasRequiredFields` checks presence+non-null ONLY, never
  TYPE — every shape check needs a companion `is! Map`/`is! List` row. **Same for a guard
  replicated across sibling CLASSES** (one masking call in six `toString()`s): mutate PER
  CLASS, because a class whose output is already safe for another reason is deletable-green
  — `ValidationException` prints `Value: <Type>` and its only masking-adjacent assertion is
  `isNot(contains('@'))`, which the type-description satisfies alone (BUT-1897). A stated
  red count must name its SCOPE: "removing the mask reddened 4" was true for ONE class and
  8 for the family, and the smaller number reads as "the other five are unpinned".
  **Same again for a repository's ONE-SHOT reader and its LIVE-STREAM twin** — byte-identical
  marking/merging branches in two methods, and the suite pins the one-shot half because it is
  the easier `await`; the stream is the path the open screen actually renders from. `lcov
  DA=0` on the stream's branch is the whole probe, ~35s, no `lib/` write (BUT-1908).
- **A source-scanning guard enforces its REGEX, not its TITLE — cite what it matches, never
  what it is called.** Grade it against the file's OWN PRE-CHANGE BYTES, which is a free
  corpus of the exact shape it exists to refuse: BUT-1904 added a guard scanning its suite
  for `^\s*assert\(await exists\(` after a delete→mark fix made every existence assertion
  true-by-construction, and run over `git show HEAD:<suite>` it matched 10 of the 15 real
  sites — missing exactly the 5 the author had hand-wrapped onto two lines. A one-line
  anchor cannot see a wrapped call, and a long `reason:` string is what wraps it, so the
  evaded form is the NORM in any suite with explanatory failure messages. Match the CALL
  (allow a newline after `assert(`) or scan a parsed form.
  `architecture_test.dart`'s "no raw user ids in AppLogger calls"
  matches `$userId`/`$uid` only, so `$conversationId` walks past it in 9+ `lib/` files while
  literally being two raw uids (`direct_<a>_<b>`). Before leaning on a guard as a
  contract, read its pattern and name the aliases of the guarded DATA that the pattern
  cannot see; a guard whose own doc comment lists "known gaps" is naming variables, and the
  gap that matters is usually a different NAME for the same secret (BUT-1897, 2026-08-20).
- **A comment naming WHICH test guards an ORDERING dependency is graded by performing the
  reorder, never by reading the suite — and the decoy is systematic**: a test pinning the same
  literal through the HELPER the mutated caller delegates to is invariant BY CONSTRUCTION, so
  it reads like the closest guard and can never redden. Route-check each candidate (does the
  fixture enter the mutated seam?), then check the surviving test's fixtures one by one — only
  the REALISTIC-length one usually straddles the swap. Swapping `maskIdentifiers`' two rules:
  5 red across 4 suites, all through `sanitizeForCrashlyticsForTesting`; both `direct_#<hash>`
  literal pins stayed green (BUT-1897, 2026-08-20). **The comment REPAIRING that attribution
  then failed on SCOPE, the same day**: "every test in this group calls the helper directly,
  never the chokepoint" named as its own counterexample a test 70 lines below — inside that
  same `group(`. Scope the sentence to the FIXTURE it sits beside, and `grep -n '^  group('`
  the counterexample's line before writing "in this group"; the guard-bearing test is the
  file's ONLY caller of the mutated seam, so it is always one grep away (BUT-1897, 2026-08-21).
  **A doc claiming two cases are mutually non-subsuming ("each has its own killing test;
  neither kills the other's") is a claim about a MATRIX, and reading pairs it one-to-one by
  eye.** Run mutants × tests in full: BUT-1904's placement pair measured
  P2(below-null-exit)=GREEN/RED, P3(inside-try)=RED/RED, catch-returns-input=RED/GREEN — so one
  case killed BOTH named moves and the other earned its place on a THIRD mutant the doc never
  names. Both tests were right, the sentence explaining why was false. A ~90-line scratchpad
  Dart replica of the one method settles it with no `lib/` write (2026-08-26).
  **A "pinned by the case named X" pointer is settled by a REACHABILITY probe on the branch the
  sentence is about, never by reading X's name — `--plain-name '<X>' --coverage` and a `DA:` read
  on a line inside that branch, ~15s.** The recurring trap is a behaviour implemented in TWO
  STACKED LAYERS that both fail the same way: a collaborator whose own catch returns a NEUTRAL
  value (`currentBlockedIds` → `const {}`) and a caller catch behind it. The case that LOOKS like
  the pin — the REAL collaborator over a throwing dependency — hands the caller that neutral
  value, so it never enters the caller's branch and is byte-identical, through production, to the
  empty-set CONTROL three tests above it; every single-point mutant of either layer is absorbed by
  the other, so its kill set is empty and only a two-point mutation reddens it. Measured
  (BUT-1904/1909): `DA:309,0` for the whole group, `DA:309,1` for one case in a DIFFERENT group.
  **My own round-3 repair wrote that false pointer** — a correction naming a case is as
  falsifiable as the count it replaced, and the repair is to STRIKE the pin clause, not to
  re-point it at the case the probe found (2026-08-26).
- The in-memory version DELETES data instead of failing to write it (a model field + N
  field-by-field rebuilds) — `copyWith` is the durable fix, it can't forget what it never
  enumerates; assert an UNTOUCHED member survives.
- Notification `when(...)` stubs are not coverage (the wrapper swallows everything incl.
  `MissingStubError`) — only `verify(...).called(n)` + `verifyNever` on the retained member.
- A test passing an OPTIONAL override bypasses the changed default branch — grep every call
  site. Worst case: a remote KILL SWITCH override present in every test by construction, so
  neither the real lookup nor the defaults entry runs anywhere.
- A defensive bound on an injected collaborator is mutation-dead when every fake answers
  immediately — `grep 'fakeAsync\|Completer\|TimeoutException'` zero hits IS the finding. A
  new conjunct beside an existing gate is born mutation-dead without a fixture passing the
  OLD gate and failing ONLY the new one. **A cache invalidated from a stream's LIFECYCLE has
  one limb per callback and they need opposite fixtures**: `onError` needs an OPEN controller
  you `addError` to, `onDone` needs one you CLOSE and then read through. `const Stream.empty()`
  proves neither — it completes before anything reads the cache again — so a suite split
  between empty streams and open controllers leaves `onDone` deletable-green while looking
  covered. Grade its production reachability at the REPOSITORY: a `currentUserId == null ?
  Stream.value({})` early return is a genuinely completing stream, so the limb is live
  (BUT-1909, `BlockedUserFilter`).
- The CONDITIONAL-IMPORT SEAM: `flutter test` compiles the native branch into every unit
  test, web stub into none — the shipping impl runs in zero tests if every test injects a
  fake through the `_testX` seam. Same for `Platform.isX`: guard and no-guard agree on every
  observable that doesn't count calls.
- A "no unit test can see this" comment is a claim — split the untestable PREMISE (rules
  denial) from the testable BEHAVIOUR (the catch is not).
- A COPY test stopping at the confirmation dialog pins the words, not the branch — the
  decision usually lives on a surface it never renders (both snackbars, title, body).
- `MaterialApp(routes:{...})` never reads `settings.arguments` — nav tests on it pin the
  SHAPE vacuously; push through `onGenerateRoute` mirroring the real decode.
- Two l10n keys with the SAME string make `find.text` unfalsifiable — grep the ARB for EXACT
  value equality, since `find.text` is whole-`Text.data` equality, never substring. So a
  message CONTAINING an action label as a trailing sentence never made the tap ambiguous, and
  "shortening it disambiguates the tap" is a false premise to accept or file (BUT-1831).
- "Returns null on X" needs a positive control in the same fixture — where every layer
  swallows to null, null is the NORMAL shape of denied/offline/deleted, so grep the suite
  for `async => null` on the loader; zero hits IS the finding.
- Last-wins/precedence tests need the LOSER asserted absent, with inputs where the wrong
  answer genuinely differs. A partition/drift-guard test from the SAME curated list the impl
  was written from cannot fail — probe with a real sibling name.
- Coalescing-across-calls: a fixture whose injected reader returns a CONSTANT can't see it —
  model the read, drive N calls on an advancing clock. A parameterised loop over failure
  codes proves one leg N times if the fixture starts EMPTY — need a fixture failing the fast
  path's own predicate.
- A predicate's SCOPE guard (suffix-not-substring) ships untested when the illustrating
  fixture sits outside its vocabulary — need the positive half PLUS the guarded shape.
- Round-trips must drive the REAL serializer, never `copyWith`; a DateTime sentinel needs
  zone normalisation checked via round trip.
- A two-sided guard (å/ä/ö boundaries) needs a discriminator PER SIDE and a recall control on
  tightening — classify by which side the diacritic sits, and print each candidate pattern
  over all three fixture histories (old-matched, new-matched, never-matched) before writing
  rationale. Boundary shape is decided by the
  CONSUMER, not tidiness — never harmonise two deliberately different guards in this repo.
- A hand-built narrow write payload needs BOTH the carried and omitted keys pinned — for the
  omission, drive a mutator that moves the excluded key as its OWNER.
- Firestore whole-number aggregates store as `int` — `as double?` throws and silently drops
  the row. A guard spanning TWO user-facing shapes ships pinned on one — the diff's own
  "accepted consequence" sentence usually names the unpinned shape.

### Helpers that exist (grep before writing a new one)
| Helper | Path |
|---|---|
| `setupUnit()`, `teardownUnit()`, `setupUnitWithProductionLocator()` | `test/test_support/base_unit_test.dart` |
| `TestTimestampProvider`, matchers | `test/test_support/timestamp_test_helper.dart` |
| `useEmulatorLane`, `firestoreForLane()`, `clearLane()`, `emulatorOnlySkip` | `test/test_support/emulator_lane.dart` |
| `butleryGolden(...)` | `test/widget/golden/golden_helper.dart` |
| `createLocalizedTestApp(...)` | `test/infrastructure/helpers/widget_test_app.dart` |
| All production mocks | `test/infrastructure/mocks/production_mocks.dart` |
| Typed mock factory | `test/infrastructure/factories/mock_factory.dart` |
| `MockMenuService` (NOT in production_mocks.dart) | `test/infrastructure/mocks/service_mocks.dart` |

**`RecipeFactory.build` has NO `tagResult`/`tagOverrides` param; `RecipeBuilder` does.** Every
tagging-gated render (`recipe.tagResult != null` guards the card's allergen/dietary rows) is
UNREACHABLE from a factory-built fixture, so a test written on the factory passes vacuously
rather than failing to compile — that is exactly how BUT-1780 shipped "fixed" with no badge
ever on screen. Use `RecipeBuilder().withTagResult(...)` for anything badge- or tag-related.

### FakeFirebaseFirestore vs emulator decision tree
| Behaviour under test | Use |
|---|---|
| Plain reads/writes/queries, `collectionGroup`+equality, `orderBy` on a present field | `FakeFirebaseFirestore()` in `setUp` |
| `FieldValue.increment`, `serverTimestamp` (usually), transactional writes, security rules | Emulator lane, or `firestore-rules-tester` |
| `GetOptions.source` | NOT testable — fake ignores `source`; real Firestore THROWS `unavailable` on a cache MISS instead of `exists:false`, so `if (!cached.exists) throw NotFound` is DEAD in production. Assert the outcome contract only. |
| `snapshot.metadata.isFromCache` | NOT reachable — fake answers every read `false`. `grep isFromCache <suite>` zero hits IS the finding. Stage via sealed-class mock on snapshot+metadata. |
| Read of a doc that may NOT EXIST, rules-guarded collection | NOT testable, and the fake's answer is the OPPOSITE of production's — a rule dereferencing `resource.data` denies a `get` on a missing doc. Test a "probe A, fall to B" helper with a ref whose `.get()` throws. |
| Service that wraps Firestore | Mock at the repository interface |
| Dotted-path `update({'core.x': v})`, `update()` on a MISSING doc | **Faithful.** Dotted keys write nested with siblings preserved; `FieldValue.delete()` on an absent key is a silent no-op, so seed the field first. `update()` on a missing doc throws and creates nothing — `expect(oldPathDoc.exists, isFalse)` is a PERMANENT PASS: documentation, not coverage. |
| A NULL-VALUED KEY via `set(..., merge: true)` (incl. `batch`) | **Faithful, `containsKey` is real coverage.** Key present, value null, siblings preserved; null OVERWRITES a stored map. So "writer must emit key even when null" is testable at module level (verified 2026-08-13). |
| Query PREDICATE SHAPE, incl. `where('<map>.<uid>', isNull: false)` | **Exact.** Build the REAL repository over the fake; dotted keys, `isNull`, `arrayContains` all work. `isNotEqualTo: null` adds NO condition in the real SDK and makes the fake THROW — never accept a comment claiming map-path keys unsupported. |
| A negative "gets nothing" test | Mutation value only when the SUT doesn't swallow errors — behind a catch-all `return []` it's a recall control, and the positive test is the whole guard. |
| A per-ROW transactional write (doc id == uid) | Transaction wrapper is deletable-green by construction — the suite really pins the DOC-ID DERIVATION. Keep the two-actor test as CONTROL; put the permission half in the rules lane. |
| `FakeFirebaseFirestore.runTransaction` | NO-OP PASSTHROUGH, never proves atomicity — handler runs once, `SetOptions` dropped, `timeout`/`maxAttempts` ignored. Use a bare read-modify-write; a truly interleaved test fails on the fake, passes in production. |
| `test/integration` | Nothing in CI passes `--dart-define=USE_EMULATOR=true` over it — every lane test skips everywhere, never coverage. `flutter test` is plugin-less; the lane needs an `integration_test` project. Ticket it, don't "just add the flag." |
| `serverTimestamp()` in `batch.set(..., merge:true)` | Trips the fake on some shapes — never a valid `skip:`. Fix: `FieldValueFactoryPlatform.instance = MockFieldValueFactoryPlatform();` in `setUp`. |
| `permission-denied` | Fake can't fire it — skip only when the branch is a bare `if (e.code=='permission-denied') return null;` above a rethrow, no side effects. |
| `orderBy` field | Seeded fixture must include every field the `orderBy` reads — the fake silently drops docs missing it. |
| `collectionGroup` | Safe on the fake for index-free `.limit(N).get()` with no `where()`, and (^4.1.0+1) for plain equality. |

### Conscious-skip taxonomy
- Static-method orchestrator: skip only when ALL hold — ≤3 calls, no injection seam, each in
  its own try/catch, no branching beyond the catches.
- Compiler-enforced sync contract (renamed l10n/analytics constant fails gen-l10n/analyze
  first); pure-nav affordance (route constant is compile-checked).
- Nth surface adopting an already-proven predicate: prove via `git diff --staged
  --name-only` — no new surface if the pure-logic file is absent.
- `SemanticsService.announce` in a fire-and-forget handler is skippable UNTIL the view gains
  a DI seam — dated, not permanent. A comment-only diff owes no test IF the claim is already
  pinned by a fail-loud spy — verify, don't trust. But a comment-only CORRECTION owes a grep
  of the CORRECTED SENTENCE across `test/`: a covering suite's group header quotes production
  prose, so the false claim has a third copy there and the batch ships two answers to one
  question (BUT-1883 — "an unhydrated poll makes `closePoll` resolve to the first option" was
  still live in `message_query_module_test.dart` after both `lib/` copies were fixed;
  `_resolveWinner` returns null at zero votes).
- **A mask-at-the-throw fix owes NO test when nothing observes the message**: the string is
  caught in-method and handed to `AppLogger.error` as the ERROR OBJECT (only the MESSAGE
  arg is sanitized), the user-visible text is a generic fallback, and asserting
  `isNot(contains(id))` on that fallback is the classic type-description vacuity. Say so;
  the durable pin is a source lint in `test/architecture/`, not a fixture (BUT-1897,
  `ConversationsViewModel.leaveGroup` + `MessageDeletionModule`). Check "no production
  caller" yourself — it decides the verdict — and note that a residual-throw branch above
  `batchDeleteDocs` is unreachable on `FakeFirebaseFirestore`, whose deletes always succeed.
  **The skip INVERTS once the throwing class's own `toString()` interpolates the message** —
  `recordError` sends `exception.toString()` and the object crosses unsanitized, so a fixture
  IS owed, not a lint. Read that `toString()` before citing this bullet (BUT-1915).
- **A "sole guard"/KNOWN-GAPS comment is a CLAIM until a test enters that exact branch** —
  verify against the model's SERIALIZER, never read a rules subcollection match or a
  cascade's defensive sweep as evidence the client writes it. A rationale citing a backend
  propagator/cascade is two greps (collection constant, then the query field) and both
  usually fail.
- **A SNACKBAR SEVERITY swap (`showError` → `showInfo`) owes no test AT THE CALL SITE, and the
  reason generalises to every static presentation helper**: every discriminator belongs to
  `SnackBarUtils`, not to the screen — the icon (`Icons.close` vs `Icons.info_outline`), the
  background (`cs.secondary` vs `cs.primary`) and the error variant's hardcoded `'OK'` dismiss
  action — so a call-site pin reddens on edits to a shared helper the screen does not own, which
  is the banned theme-value shape. What the user experiences ("told, not navigated") is already
  the existing test. If severity is a contract, it earns ONE test in
  `test/unit/core/utils/snackbar_utils_test.dart` asserting the two variants render observably
  differently — grep first: as of 2026-08-29 that file covers only `userFriendlyMessage`.
  SUPERSEDED 2026-08-29, same day, same ticket: this bullet ended by saying a first call-site
  pin is "worse than none", and BUT-1971 then shipped exactly that pin on `groupMenuNoGroups`
  (`Icons.info_outline`) at a second reviewer's request. The narrower rule survives and is the
  one to apply: what is banned is pinning a THEME TOKEN a screen does not own (a `ColorScheme`
  entry, an `AppDimensions` value), because a theme tweak moves it. An ICON IDENTITY is stable
  and does kill the swap, so that assertion stands. Do not cite this bullet to remove it.
- A pure removal of dead code owes no test when a repo-walking structural lint holds the
  invariant — verify the lint is byte-identical to HEAD and the pre-fix set had exactly ONE
  element.
- A behaviour-neutral respelling owes no test — earn that by MUTATION-COUNTING the existing
  suite, then fix the comment/header claim the respelling falsified. Before writing "the
  suite had nothing to say", grep `test/architecture/architecture_test.dart`: style bans
  (BUT-581 raw `?? ''`) ARE tests there, repo-walking source lints run in two CI workflows,
  with `tools/check_staged_arch_guards.sh` as the pre-commit twin. Behavioural suites cannot
  see a respelling by construction — that split is correct, not a gap. **Run that pre-commit
  twin FIRST when reviewing a recovered or never-reviewed patch** — ~1s, and it grades the
  axis vacuity analysis structurally cannot see: BUT-1912 ran six passes across three review
  agents and every one missed a raw `?? ''` the regex named instantly. Gates grade CLAIMS and
  whether a test can fail; lints grade CONVENTIONS. Neither covers the other, and treating a
  review pass as if it covered both is what left it there (2026-08-25).

### Vacuity patterns — the recurring ways a "passing" test proves nothing
The single most repeated finding across two months of review.
- **MASTER RULE: name every OTHER mechanism that could satisfy the assertion, then build the
  fixture where they DISAGREE. Every pattern below is an instance.**
- **A true/false PAIR over a new boolean pins the flag against HARDCODING and nothing else —
  the surviving mutant derives the flag from a SIBLING field the two fixtures happen to
  correlate with.** BUT-1983 flagged a failed shopping-list build (`result == null`,
  `itemCount: 0`) against a success (`itemCount: 5`); `shoppingFailed = itemCount == 0` runs
  41/41 GREEN and re-creates the exact conflation the ticket removed, because the generator
  returns `nothingToGenerate` — a NON-NULL success with `itemCount: 0` — from two live
  branches. Enumerate the callee's zero-valued SUCCESS constants (`grep -n 'static const'` on
  its result type) and add the third fixture where flag and sibling disagree; the diff's own
  new production comment usually states that case as the contract (2026-09-02).
- **A "resolves through the l10n key, not a literal" test whose BOTH sides resolve the SAME
  locale cannot kill a same-text revert.** BUT-1984 asserted
  `weeklyPlanReadFailedMessage == AppLocalizationsSv().weeklyPlanReadFailed`; restoring the
  symbol to `const String … = '<the Swedish text>'` ran 13/13 GREEN, which is the shape an
  actual revert takes — and in production that literal serves Swedish to an English user.
  Only the SIBLING literal pin dies to a reworded ARB entry, so the two tests do not split the
  way such a comment tends to claim. Pin routing by switching the accessor
  (`AppLocale.initialize(const Locale('en'))`, restored in `addTearDown`) and asserting the
  OTHER locale's text (2026-09-02).
- **An auth-gated `executeServiceOperation` wrapper hollows a raw-mock suite in BOTH
  directions, and REMOVING it is what un-vacuums them**: `_isAuthenticated()` calls
  `ServiceLocator.get<AuthRepository>()`, which THROWS in a file with no DI harness, so the
  method returns `defaultValue` having never touched the repository — every assertion about
  the repo's return value passed on the fallback (`expect(result.groupId, …)` needed `same(existing)`).
  And `safeExecute` catches EVERYTHING, so no `throwsA` test can pass while the wrapper is
  there: that is a free analytic non-vacuity proof for any fail-loud fix that strips one — no
  `lib/` mutation probe, no parallel-session risk (BUT-1928). **A redesign that KEEPS the
  wrapper and reports failure through a nullable-wrapper SENTINEL instead (`read ?? const
  Read(readFailed: true)`) leaves the hollowing in place AND leaves the sentinel's producer
  untested, because every consumer suite mocks the service that mints it** — grade the
  producer, not the consumer's branch, and settle it in one coverage run: `DA:0` on the lines
  inside the wrapped closure IS the finding (measured 2026-08-23, both group tests green
  without the repository ever being called). **The remedy is a harness, not a redesign**:
  `BaseUnitTest.setupUnitWithProductionLocator()` in `setUpAll` plus
  `(TestServiceLocator.get<AuthRepository>() as FakeAuthRepository).setAuthState(userId: …)`
  in `setUp` puts the pre-flight through, and the proof it worked is any arm asserting the
  SUCCESS value — a `same(existing)` plus `verify(repo.fetch…).called(1)` cannot pass on the
  fallback, so no mutation probe is owed (BUT-1928, closed 2026-08-23).
- **The same swallow falsifies ORDERING-SAFETY comments two files away.** "Do A before B, so
  if A fails B never runs" is FALSE whenever A's method wraps its write in
  `executeServiceOperation` — `safeExecute` returns `defaultValue` instead of rethrowing, so
  B runs on a failed A. Grade every "if X fails, Y stays open/unwritten" sentence by opening
  X's own method and asking whether anything can propagate out of it; usually only a guard
  that throws ABOVE the wrapper (a permission check, a new sentinel refusal) does. Strike the
  clause, file the behaviour gap separately (BUT-1928 review, `MessagingService.closePoll`).
- **A blanket `FlutterError.onError = (_) {}` near `matchesGoldenFile` makes every golden a
  PERMANENT PASS** — the comparator reports its verdict by THROWING, `runAsync` catches it,
  re-reports it as `library: 'Flutter test framework'` and returns `null`, and `null` is the
  matcher's word for "matched"; only the diff images in `failures/` tell you. The on-disk
  symptom is a golden whose DIMENSIONS disagree with the helper's pinned surface — nobody
  re-verified it because nothing could fail. Filter on `details.library == 'image resource
  service'` instead: it fails LOUD on an SDK rename and structurally cannot eat a verdict.
  Pinning the FILTER is not pinning the CALL SITE — an `@isTest` helper cannot be invoked from
  inside `testWidgets`, so the only durable guard is a source lint in `test/architecture/`,
  which must strip comments first because the fix's own doc comment quotes the banned literal.
  Grep `matchesGoldenFile` across `test/` before believing a helper-level fix is repo-wide
  (BUT-1931).
- Circular determinism (calling the same pure function twice, or deriving expected from the
  const under test) — pin the literal OUTPUT.
- Sibling-branch short-circuit, BOTH polarities: for `if(A) return true; if(B) return
  true;`, check no fixture satisfies a branch other than the named one. MIRROR (AND-chain +
  `findsNothing`): a negative test naming ONE conjunct needs every OTHER conjunct
  SATISFIED, or the conjunct it names is deletable-green — assert the premise in the test
  itself (BUT-1869 "badges off" ran on a fixture WITH badges, so `.isEmpty` withheld the
  marker and the flag was never exercised).
- Fake-default-same-as-expected: use a sentinel no real caller would pass.
- **DESERIALIZER-DEFAULT vacuity**: a save-retrieve test asserting the parser's own
  `defaultValue` is unfailable — missing doc, dropped write, empty map all answer the same.
  Tell: a "returns defaults" sibling test with a byte-identical assertion list.
- **Production twin**: a "must not OVERWRITE" fixture holding the value the code would write
  anyway. Widest instance: an untouched-save test over `copyWith(f: _selection)` — only
  picked≠stored can see a dropped `f:` argument (BUT-1858 test 7).
- A NULLABILITY WIDENING (`T x=d`→`T? x=d`) trades a compile guarantee for a test — trace the
  `??` chain to what the mutant does downstream (a dropped initialiser can store a SILENTLY
  DERIVED value, not "no value").
- A collection-SHAPE assertion instead of the skipped element's VALUE (a Map can't hold a
  dup key, so "appears once" can't distinguish skip-vs-overwrite).
- **A change-detector conjunct in an incremental list updater** (`!mapEquals(old.metadata,
  new.metadata)` beside `content`/`status`/`readAt` tests) is pinned ONLY by two emissions
  whose other compared fields are byte-identical — a realistic fixture varies content too and
  the conjunct is deletable-green. Its comment is the second claim: grade "this always
  differs" against EVERY producer of the map, because a sibling that SHALLOW-copies the outer
  map (`Map.from(metadata)..[k]=v`, the unhydrated/marker-only path) hands back the SAME
  nested instance and `mapEquals` answers TRUE there (BUT-1908).
- **A guard wrapping [spacer + a child that self-collapses to `SizedBox.shrink()`] is pinned
  ONLY by `find.byType(<ChildWidget>)`** — the child-CONTENT assertion (badge, row item) is
  vacuous, because deleting the guard rebuilds the child, which then draws nothing and leaves
  the dead spacer the ticket was about (BUT-1869, `CompactAllergenRow` on an empty pref set).
- **`Semantics(label:)` does NOT suppress a descendant `Text` — the two labels CONCATENATE
  into ONE node's label, parent first, `\n`-joined** (measured 2026-08-26 on the BUT-1904
  dismiss pill: `"<label>\nDu har redan skickat det här"`, one node, rect 363x48). Three
  consequences, all of which shipped as wrong sentences: `find.bySemanticsLabel(exactString)`
  returns 0 for that reason and NOT for any RepaintBoundary/rendered-tree reason (the RegExp
  form finds it); "this label is the ONLY thing a screen reader hears" is false, so a label
  restating the visible text ships a STUTTER; and the widget-property workaround
  (`widgetList<Semantics>().where(label non-empty)`) that the 0-hit provokes is strictly
  weaker — it cannot see `container`, `button`, the RECT or the merge. Assert
  `tester.getSemantics(<scoped finder>)` instead. `.claude/rules/ui-conventions.md` rule 5 was
  the origin of the belief and has been corrected in place (2026-08-26); BUT-1953 sweeps the
  labels written under it, which are not audited. **Re-measured 2026-08-30 over
  `Semantics(label:, button: true, child: InkWell(onTap:, child: Text))`: same outcome — ONE
  node, `label: "<parent>\n<child text>"`, `isButton`, `[focus, tap]`.** So the correct label
  for a tappable row naming its own content is the ACTION ALONE ("Visa vilka som röstade"),
  which is what avoids the stutter; the ARB description asserting the concatenation is a
  framework claim a `tester.getSemantics(find.text(<the row>))` line settles in one run, and
  an a11y label typed in `lib/` with zero `test/` hits is the usual state. **Assert the
  stutter by counting the CHILD SENTENCE inside `node.label`
  (`'<row text>'.allMatches(node.label).length == 1`), never the label's own words** — a
  word-count reads a restating label as "more words" and stays green, which is the first
  version BUT-1971 shipped; the occurrence count reddens at 2, and at 0 if the framework ever
  stops concatenating, so one line holds both halves (2026-08-30).
- **A vacuity POST-MORTEM comment ("this case was vacuous because X") is an unmeasured claim,
  and the file's own other assertions usually disprove it** — BUT-1904 blamed
  `find.byType(GestureDetector).first` picking up "a framework detector from the app
  scaffold", while two cases in the same file assert `find.byType(GestureDetector),
  findsNothing` UNSCOPED and pass (the framework uses `RawGestureDetector`; `byType` is
  exact-type). The real cause was the PRODUCTION bug — an expanding `Center` made the region
  768x584, so a `minHeight: 0` mutant cleared 48 on height it did not own. Re-derive the
  cause from the fix that killed it, not from the finder you changed at the same time.
- **A "renders identically for a foreign/other-user row" case is vacuous when its fixture
  omits the callback the real call site passes UNCONDITIONALLY** — measured (BUT-1904):
  `chat_message_stream` hands `onDismissBlocked` to EVERY row, and the blocked branch gates
  the × on the callback alone with no ownership check, so a foreign row does get the control
  and firing it deletes a message the viewer did not send. The suite could not see it because
  the not-mine fixture was the only one that left the callback out. Build the "should not
  occur" fixture with the PRODUCTION wiring, or the identity claim is about the harness.
- **`Semantics(label:, button:)` at `container: false` gets NO node** — the config is absorbed by
  the nearest node-forming ancestor (usually `RenderView`), so the label lands on a screen-sized
  node that owns every other control and takes their taps. `find.bySemanticsLabel` and
  `matchesSemantics` PASS under that mutant; only the node's RECT and its non-ADOPTION of a
  neighbouring labelled control discriminate, and only in a harness mirroring the REAL mount
  point. Labels are not a compatibility axis (`isCompatibleWith` reads actions/flags/role/value),
  so "a neighbouring `Text` conflicts and forces a node" is false (BUT-1837). **An assertion
  that is green under the mutant BY CONSTRUCTION is ZERO evidence about the harness it runs
  in, both directions** — so a probe spec must say which way each observation cuts, or the
  parent reads the converse as confirmation: "if `find.bySemanticsLabel` also reddens, '`_wrap`
  does not reproduce' is falsified" was returned as "it stayed green, so that half stands",
  when only varying the MOUNT POINT can settle it (BUT-1837 re-review). **`container` is NOT
  what that rect assertion discriminates once the child forms its own node** — a
  `GestureDetector` with `onTap` does, so `true`→`false` leaves `getSemantics(<that finder>)`
  returning the same rect, label and `isButton` (measured 2026-08-26, three-arm replica). What
  it DOES kill is HOISTING the `Semantics` above a wider ancestor: node 800x600 vs widget
  87x48, i.e. the BUT-1837 harm itself. Say which of the two a rect pin covers; a comment
  crediting it with `container` is false. A no-Semantics arm is the cheap third control (label
  falls back to the child `Text`, `isButton` false).
- **A control that DISABLES ITSELF after one tap makes every later negative-tap assertion in
  the same test unfailable** — the second `expect(fired, 1)` cannot fail because the widget is
  gone, whatever the hit region does. Measured (BUT-1904): moving the "beside the pill" probe
  point to the region's DEAD CENTRE left the case green. Order the negative tap FIRST and
  assert `fired, 0`, or the geometry precondition beside it is the only thing killing the
  widen-the-region mutant while the `reason:` string claims the tap did.
- **ONE parameter feeding TWO axes is pinned on the easy axis only** — a grid's `spacing`
  used between rows AND columns: deleting the between-COLUMN spacer left all six tests in
  the widget's own new suite green (measured, BUT-1911), because a short-last-row width
  comparison and a one-column case both move together under it. Enumerate the axes the
  parameter's own doc comment claims, one assertion each.
- A Fake with two branches answering the same success value, driven by one UI flag, eats a
  routing test whole — test the FAILURE arm. An enum-driven `defaults()` owes a
  KEY-SET-COMPLETENESS test — a forgotten member is DEAD, not "off by default."
- Negative-scope claims need a negative assertion against `toMap().keys`, not a render check.
- **"No write was issued" is the commonest untestable claim** — before/after can't tell
  skipped from identical-value. Count writes, positive control same test.
- `findsNothing` needs a co-asserted positive render. A widget whose only access control is
  an early-return is untested if every pump uses the same actor constant.
- **An ORDERING fix (resolve A before B) is mutation-dead whenever the suite INJECTS A** —
  the testable constructor param resolves A synchronously, hiding a reverted fire-and-forget
  order (BUT-1838: 11/14 files, revert left all 45 green).
- Inherited-authorization-discarded: no test sees it while the permission fake defaults
  true. Tell: tests changing `currentUserId` on one double, not the permission double.
- A flag-lifting aggregator owes an EXACT-SET assertion + absence control, not `contains`. A
  two-layer fix (N emitters + chokepoint) is tested only at the chokepoint — a control, not
  coverage; each emitter owes its own suite's test.
- Boundary tests must straddle the EXACT flip point (`==N` vs `N+1`); a calendar-day guard
  flips at MIDNIGHT, not a duration. **An "these two spellings agree" assertion
  (`f(nfd) == f(nfc)`, two casings, two separators) is the same rule wearing a disguise: it
  is vacuous unless the fixture straddles the threshold `f` actually tests.** BUT-1904 pinned
  "NFC and NFD sit on the same side of the 12-char chat floor" with a 14/15 pair — both over
  the floor, so deleting `.normalize("NFC")` keeps it green. The killer is an NFC length one
  BELOW the floor with one combining mark (`"hej då alla"`, 11 NFC / 12 NFD). Measure both
  spellings against the BOUND before writing the fixture, never against plausibility. `DateTime.utc(...)` fixtures can't assert zone
  normalisation — feed `Timestamp.fromDate(x).toDate()`.
- Any normalizer/sanitizer is the IDENTITY on an already-normal fixture, and realistic
  fixtures usually are — enumerate what the helper changes, plant one instance each. MIRROR:
  a "the masker LEFT X alone" assertion is vacuous unless X sits inside the domain the
  masker would otherwise change — a 16-char class name under a {20,28} identifier rule
  survives for an unrelated reason, making the whole test byte-identical under the mutant its
  own `reason:` line names (BUT-1897, `_scrubStack`). Compute the fixture against the
  guard's BOUNDS, not against plausibility.
- **Moving a mask INTO `toString()` silently subsumes every per-site mask assertion** — after
  the class masks, `isNot(contains(uid))` on the RENDERED string is held up by the class rule,
  so the throw site's own `.masked*` call is deletable-green. Measured (BUT-1897): dropping
  `.maskedUserId` from both `MessageMutationModule` throw sites left the suite GREEN. The only
  surviving discriminator was a shape production never mints (`direct_abc` — hashed by
  `maskConversationId`, untouched by `maskIdentifiers`' two-segment rule), which ties the test
  to a divergence `log_sanitizer.dart` itself calls incidental. Pin the exception FIELD
  (`ResourceNotFoundException.resourceId`) instead: it discriminates on the REAL id and cannot
  be satisfied by the class rule. **MIRROR, at a class that does NOT mask**: when `toString()`
  is `'Label(op): $message'`, asserting both `.message` and `.toString()` is ONE observable —
  the second is entailed by the first and cannot fail alone. The discriminator is the POSITIVE
  `contains('<first8>...')`, which also ROUTE-CHECKS: it reddens if an earlier guard (recipe's
  owner-first check) caught the fixture instead. Fixture uid must exceed 8 chars or
  `maskUserId` is the identity (BUT-1915). That positive also separates every SIBLING helper in
  the utility class (each mints a different shape, and `maskIdentifiers` is the IDENTITY on a
  human NAME — so a display name needs `maskedName` at the throw and no sink rule can rescue
  it). What it cannot see is a PARTIAL mask: `isNot(contains(<whole value>))` passes on ANY
  elision, so pin the TAIL token absent too — but FIRST read the masker's OWN suite: an
  exact-EQUALITY pin there (`maskUserId('abcdefghijk') == 'abcdefgh...'`) already kills every
  tail-leaking masker mutant, leaving the call-site tail pin to catch only a HAND-ROLLED mask
  at the throw. Demanding it symmetrically at every call site after that is symmetry theatre;
  say so and end the round. **Grade "the exception object reaches Crashlytics" against the
  SERVICE's own error handler, not only the ViewModel a comment names** — `_handleError`
  reached `AppLogger.error(msg, e)` with no VM in the chain, so the sink survives even where
  the named caller is dead, AND it interpolates `'$e'` into the MESSAGE arg, which DOES run
  `maskIdentifiers` while the object arg does not. Two routes, opposite answers: scope any
  "the masker never runs here" sentence to the OBJECT route or it is false. A duplicate-branch
  fixture built by calling the seating method TWICE is non-vacuous by construction when the
  seat is the branch's only route — a failed seat throws nothing and `fail()` inside the `try`
  dies on the cast, so it reddens rather than passing.
- **A round-trip over a `double` is bound by its fixture LIST, and Dart's own notation
  switches inside the domain** — `toString()` goes EXPONENTIAL below 1e-6 (so a
  format→retype invariant breaks: `1,5e-7` re-formats to `1,57`) and `round()` SATURATES at
  int64 rather than throwing, while `infinity` DOES throw `toInt`. Friendly fixtures
  (1.5, 0.5, 2.25) prove none of it; enumerate the NOTATION boundaries, not more nice
  numbers (BUT-1891). A comment naming the strategy an assertion beats is itself untested —
  measured, the caret fixture made "counted" and "length-delta" AGREE and only separated
  "naive"; the two differ only when a character is dropped AFTER the caret.
  **A "round trip" over a UI value is TWO seams, and the doc always blames the wrong one**:
  format→parse and format→FIELD→parse. Measured, `parseSwedishDecimal` reads `1e-7` back
  EXACTLY (`double.tryParse` takes exponent notation); what loses it is the input
  FORMATTER's character filter dropping `e`/`-` → `17`. So "the parser cannot read it" would
  send the fix to the component that works. Resolve which seam by grepping the CALLERS: if no
  production line pairs the two functions directly, the direct round trip is the path that
  does not exist and the field one is the contract (BUT-1912). **The field seam has a
  TRIGGER, and it is not opening the dialog**: `inputFormatters` run on KEYSTROKES only, so a
  controller seeded programmatically keeps `5e-7` verbatim and saves the right value —
  measured with a `TextField` probe, seeded `"5e-7"` survives the pump, one keystroke makes it
  `"571"`. A `typed()` helper models RETYPING, not seeding, so any sentence about "what comes
  out of the field" owes the qualifier or it overstates the blast radius. Corollary for
  the suite: the test modelling the REAL seam is the one whose fixture list must straddle the
  flip (1e-6 holds / 5e-7 breaks), and a test name stating an unqualified universal the
  production doc now DENIES is the two-answers-to-one-question split — the name and the doc
  sentence are one claim in two files and land in one edit.
- A measurement harness's failure mode is a confident number from a broken rig — demand a
  deliberately-broken POSITIVE CONTROL, not just "the engine produced something". Two rigs
  that read 0-diff for free: a `--output=none`/dry-run flag (the tool never writes the file
  you then diff), and leaving the ORIGINALS inside the directory the tool rewrites.
- A hand-rolled double MODELLING a write's effect (not applying its payload) is blind to
  field NAMES, and a migration IS a field name — union under `Object.keys(op.data)[0]`.
- "Returns null on permission denial" needs a positive control same fixture — where every
  layer swallows to null, it's the NORMAL shape; grep for `async => null` on the loader.
- A `??` wiring needs a fixture where the arms DISAGREE. "Does less work now" needs a
  discriminator (something only the naive path pulls in), not a convergence test. A chain
  gaining a MIDDLE arm (`parse(field) ?? existing ?? default`) is born unreachable whenever
  every fixture seeds a PARSEABLE field — the arm needs the field CLEARED, which no
  seeded-fixture test does, so a changed fallback ships with nothing to redden (BUT-1910).
- **An `inputFormatters:` line is mutation-dead until one fixture types a string the formatter
  CHANGES and the test reads the RENDERED text** — a comma/period-tolerant parser answers "4,5"
  and "4.5" alike and `initialValue` never runs formatters, so both the parse case and the seed
  case survive deleting it; the killer is a second separator ("1,5,5" → "1,55"). On an
  `initialValue`-seeded `TextFormField`, `.controller` is NULL — read the descendant
  `EditableText`'s controller, which also survives a later switch to a controller (BUT-1910).
- **"The old code did X" is a claim about a GIT REVISION — run the old expression over the
  new test's own fixture before believing it, `git show HEAD:<file>` then a scratchpad
  replica.** When it is false the "regression guard" is usually a CONTROL that is GREEN on
  the bug: BUT-1910's `,5` case cited a 1.0 fallback that never happened
  (`double.tryParse('.5')` is 0.5, so old and new agree), leaving 1 of 3 new cases able to
  discriminate. Grade a bug-fix suite by which cases fail at HEAD, not by which read as the
  headline. Corollary at a widget suite: a plain `test()` calling the pure helper pins NO
  wiring by construction — it renders nothing, so a comment saying it proves the field uses
  this parser is false, and the real discriminator is an input the two candidate parsers
  ANSWER DIFFERENTLY through the FIELD (empty → null vs `parseSwedishNumber`'s 1.0).
  **Same class, opposite direction: "without this setUp line every case would be GREEN,
  measuring nothing" is a claim about a REMOVAL — delete the line mentally down each test's
  own path before writing it.** A missing DI bridge or a `Fake` fixture inside a fail-open
  catch makes the UNFILTERED-asserting tests pass and the one test that asserts the FILTERED
  result go RED — which is how the author found it — so the sentence inverts the observable it
  was written from. An AUTH-PRE-FLIGHT harness (`setupUnitWithProductionLocator`) is the third
  carrier and inverts the same way: without it only the FAILURE arms pass, every `readFailed:
  false` / `same(existing)` / `verify(...).called(1)` arm reddens. The disproof is almost always
  IN THE SAME FILE — that success arm is why the harness exists — so grade a harness header
  against the file's own canary, and STRIKE rather than reword, since the true wording needs
  per-test tracing (BUT-1909, recurred in BUT-1928's own harness comments).
- A guard classifying OLD vs NEW mutation is untested when every fixture base is EMPTY or
  same LENGTH — need the MIXED case. Same for a re-found index after `await` (identical to
  stale when the collection has one element) and a field-exclusion decision (byte-identical
  round-trips hide it).
- A `continue`-style skip-list disagrees with its absence only when a skipped token shares a
  LINE with a matched one — if that's also where the real answer is lost, it's a design
  finding. (Scope guards, two-sided guards, narrow payloads: Coverage decisions holds them.)
- A PLACEMENT claim un-pinnable when wrong-placement is benign — say so, don't force a test.
  A signature-only narrowing opens no gap by construction — the question is whether the
  DISPATCHER calls the narrowed overload (2-arm replica, 10s).

### Fake/Mock idioms + the ServiceLocator/GetIt bridge
- `class X implements Y` with concrete bodies is a legitimate Fake; the mocktail ban is
  specifically a concrete `@override` on `extends Mock`. `extends <ConcreteClass>` with an
  override is a legitimate subclass SPY, not the banned pattern.
- **`verifyNever(() => mock.f(any()))` is UNFAILABLE against non-default NAMED args** —
  noSuchMethod fills omitted params with declared defaults, so `unit:null` never matches
  production's `unit:'st'`. Spell every named param as `any(named:'x')` (BUT-1858; positive
  `verify` unaffected).
  **The same default-filling makes a MULTI-`captureAny` verify non-vacuous for the
  "delete both new arguments" mutant, and it is measurable without touching `lib/`**: a call
  omitting them is captured as `[<default>, null]`, so `captured.whereType<String>().single`
  throws and the test reddens. Measured with a ~40-line scratchpad mocktail replica run under
  `dart --packages=<repo>/.dart_tool/package_config.json` (~5s, no repo write). The same probe
  settles the ORDER question: `.captured` follows the SOURCE order of the `captureAny` calls
  inside the `verify` closure, NOT the mocked method's signature order — reversing them in the
  closure reverses the list. So "mocktail's capture order is not the argument order" is FALSE
  as written and an index would be stable; identify by type if you like, but the sentence
  justifying it gets struck (BUT-1971, 2026-08-30).
- mocktail is LAST-REGISTERED-WINS — wildcard-then-specific `when` is a genuine repoint
  discriminator; reversing the lines silently duplicates the other test.
- When production adds a call to a NEW repository method, an existing `extends Fake` suite
  silently grades that leg's CATCH branch (noSuchMethod throws, swallowed) — grep the new
  method name across `test/`; zero overrides while production calls it IS the finding.
- A `-1` sentinel default on a Fake means two things and only one is self-proving — pick the
  arm, write the expectation, or it's just a recorder nobody reads.
- Lazy `tryGet` fields cache on construction — register fakes BEFORE constructing the SUT.
- `verify(f(captureAny()))` marks calls VERIFIED, so a later `verifyInOrder` over the same
  method fails "not found" over an all-verified list — capture THROUGH `verifyInOrder`
  instead. Fire-and-forget writes to `FakeFirebaseFirestore` need microtask draining, not a
  real-time wait.
- **The GetIt→DIContainer bridge gotcha (recurring: analytics, tag-overrides, correction-
  snapshot, import chokepoints)**: many singletons resolve via PRODUCTION `ServiceLocator`,
  not `TestServiceLocator` — a mock there is invisible. Fix:
  `prod.ServiceLocator.initialize(DIContainer())`, register into `GetIt.instance` after;
  tearDown unregisters+resets.
- A hand-rolled CF query double must be IMMUTABLE once `.where()` is called twice — a
  mutable `q` aliases both legs. A double keyed on flat `"col/id"` paths CANNOT represent a
  subcollection; give it a real `ref.collection()`.
- A new fire-and-forget telemetry call at a chokepoint ships with ZERO tests by default —
  add fires-once (happy) and fires-nothing (negative); trace the resolution chain, "no seam"
  is usually false. The test that matters passes NO injected seam.
- A funnel-attribution fix has two directions — an idempotent regenerate re-counts unchanged
  lines on rerun; assert the second run logs only the DELTA.
- A defaulted `String source='manual'` param is worse than silence — grep the CALLERS of the
  newly-tagged method, not the ticket's named path.
- A safety-critical method covered ONLY via a caller's `verify()` proves WIRING, never the
  CONTRACT — grep the method name at its own layer. Mirror: an opt-in param's tests can
  prove the contract while zero production callers pass it — demand a named entry point.
- A REQUIRED param moves the job from "is it wired" to "is the DECLARED value right" — test
  the UI's CHOICE of value and its rebase after a self-triggered change.

### Disposal & lifecycle guard idioms (BaseViewModel family)
- `BaseViewModel` already guards disposal twice — only test a subclass's OWN guard when it
  protects an observable effect no base guard blocks.
- Two quadrants: delegate disposed BY this VM → `returnsNormally`+`notified==0`; delegate is
  a SHARED SERVICE outliving the VM → `returnsNormally` is VACUOUS, assert the service's
  error SURVIVES disposal.
- A class with both local `_isDisposed` and inherited `isDisposed` must use the SAME flag
  its own callbacks use. `executeAsync` RETHROWS on failure — prove via a caller retrying
  only on THROW.
- `dispose()` clearing DATA (not just controllers) opens a use-after-dispose window for a
  still-running op — dispose mid-operation, assert the write still carries user data.
- A "disposes its children" test asserting only `returnsNormally` is vacuous — materialize
  the child, assert it's dead after (`addListener`→`throwsFlutterError`).
- A suite whose every stubbed stream is already COMPLETING pins no cancellation — use a
  `StreamController`, assert `hasListener` true-before/false-after.
- A throw-on-disposed guard inside a shared builder is safe only at callers that catch —
  `notifyListeners()` post-dispose is DEBUG-ONLY, so never conclude "unreachable" from a
  debug-mode trace. The MIRROR is the commoner comment defect: only the WRITE side asserts.
  `TextEditingController.text` resolves to `ValueNotifier.value`, a bare field read with no
  `debugAssertNotDisposed` (measured, Flutter 3.38.5), so "reads the controller on a disposed
  State → an assertion in debug" is false — the read is silent and the real harm is the work
  that follows it. Grade a disposal comment by which MEMBER it names (BUT-1831).
- A `manager.dispose()` fix's wiring half ships untested — delete the OWNER's `dispose()`
  line as a probe; if the suite stays green, the fix is deletable. The flip is the returned
  future THROWING instead of resolving null.
- A `Completer` whose `.future` is never awaited is dead plumbing — grep for `.future`. A
  polling loop returning a cached `_lastResult` drops the second caller's work.
- Any concurrency fix needs the second caller actually LAUNCHED (warm-up, gate on a
  `Completer`, launch B, settle) — assert `same(inFlight, queued)`, `queued==null`
  post-dispose, and exactly ONE persisted id from the overlapping pair.

### Contract pinning: selectors, ordering, equality, revert
- Every `field==expected` selector needs THREE pins: matched-key reused, unmarked-collision
  untouched, marked-for-different-key untouched+new created.
- `==`/`hashCode` need an equal pair AND a deliberately-unequal instance — watch `hashCode`
  hashing a collection by IDENTITY while `==` compares CONTENT.
- A numeric tuning constant is pinnable only in the direction that DELETES content — never
  manufacture a fixture just to satisfy a mutant.
- A colour pin is legitimate only when the row's semantics ARE the colour, and must name the
  theme TOKEN, not a raw hex — grep the hex across the theme's own fields too.
- `expect(x, isEmpty)` DOES discriminate `''` from `null` — matcher's body is `(item as
  dynamic).isEmpty`, so null throws NoSuchMethodError and the test goes red (as an error,
  not a clean mismatch). So an `isEmpty` pin on a nullable "cleared vs unchanged" field is
  real coverage, not vacuous; don't downgrade it to `equals('')` on suspicion (BUT-1874).
- `tester.widget<T>(find.byIcon(...))` throws StateError on "more than one," not a clean red
  — scope it. Ordering needs `verifyInOrder`, not call-count. Revert-to-start: mutate, THEN
  revert, then assert.
- A `void Function`→`Future<void> Function` fix is pinned PER CALL SITE — Dart drops the
  future behind a `void` param silently, so one dropped `await` is invisible unless the
  injected sink is made to FAIL.

### Import & correction-capture pipeline
- SSRF host-filtering and decompression-bomb caps are running invariants across every
  import surface. A CTA/UI test proves the LABEL, not the ACTION — assert wire-level
  dispatch separately.
- Correction-snapshot/parse-cache keys sharing a placeholder across unrelated imports
  silently collide — test two same-kind imports in sequence.
- A wizard rebuilding an editable buffer from a prior step loses edits on back-then-forward.
- **`\b` fixes are per-REGEX, not per-file** — the lefthook `swedish-boundary-guard` can't
  find `RegExp(r'\b'+unit+r'\b')` or an ASCII-token alternation wrapped in a literal `\b`;
  grep the raw escape yourself. Check for a diacritic FOLD first — folded text has no å/ä/ö
  left to open a boundary.
- A safety carve-out via `return null` grows a second, untested public entry point once one
  caller lacks the fallback. A "keep the row" carve-out needs the re-inserted string run
  through the CONSUMER's normalizer, asserting the resolved KEY, not list membership.
- A boundary repair inside a shared predicate changes behaviour at EVERY call site — some
  decide the OPPOSITE of the predicate's name; grep for compensating workarounds whose
  comments now assert the fixed bug as live.
- Rate-limit metering: enumerate ALL call sites of the limited op. A circuit-breaker over a
  parallel `Future.wait` must not discard already-materialized results mid-batch.
- A cross-copy "single source of truth" test must READ every copy — an unexported duplicate
  still drifts. Windows: `/c/tools/flutter/bin/flutter test <forward-slash-path>` via Bash
  works directly.

### GDPR / export section contract
- **Every section needs THREE proofs**: seeded (count present, PII round-trips verbatim);
  ownership-negative (another uid's doc absent); empty-safe (`total==0` AND
  `containsKey('error') isFalse`).
- **A FOURTH: JSON-ENCODABLE** — `expect(() => json.encode(section), returnsNormally)`. A
  raw `Timestamp` anywhere means NO FILE for the subject, uncatchable per-section. Drive via
  the REAL repository over `FakeFirebaseFirestore`. Pin the EXACT key set too.
- A refactor collapsing N redaction blocks into ONE loop over a literal field list moves the
  whole contract into THE LIST — a dropped name fails OPEN while the doc still claims
  removal (BUT-1838: `memberSince` had zero coverage).
- Before crediting a redaction, check that leg's QUERY against the WRITERS — a strip on a
  leg returning zero rows is dead code AND an Art. 15 gap.
- A GDPR rationale naming a Cloud Function is a claim about another language — grep
  `functions/src` before it ships or gets copied into `ACCEPTED_DEVIATIONS.md`.
- The bundle AGGREGATOR needs its own two tests: a flag nested in a list-of-maps needs a
  depth-bounded walk; the warnings lift must key on `error` as well as `error_code`.
- A derived message can't be worded from the failure case alone — `error_code` also marks
  PARTIAL success.
- A field added to an existing scrub/cascade ships untested because the suite LOOKS
  covering — audit the fixture's fields, add keys + a retained-field negative.
- A cascade deleting a PARENT does NOT delete subcollections, and its residual probe usually
  counts top-level docs only — grep rules for `match /<coll>/{id}/<sub>` and every client
  `.doc(x).collection(y)`.
- Redaction paths (FCM token→prefix+`[redacted]`) outrank another happy-path test. A
  two-query union+de-dup needs FOUR fixtures: sent-only, received-only, self (both legs
  match), foreign.
- Truncation flags need all THREE boundary points + a positive control per leg — the
  highest-value untested case in a multi-leg section is neither leg over cap but COMBINED
  over. `total_count` must equal the SHIPPED length, not the pre-trim fetch.
- The strongest forwarding assertion is one WHOLE-MAP equality on a per-method capture,
  derived from `getLimitForType` so a typo'd `type:` is caught too. A section's wiring line
  is deletable green unless a bundle-level test asserts `data['<section>']`.
- A section-root flag ORed over M reads while aggregating N>M record types asserts
  completeness for data never probed — count reads, not the ticket's list.
- When extracting a shared capped-read primitive, test it directly (size/trim/both
  boundaries/unknown-type/error); per-section tests then only prove wiring — grep the whole
  swept file for the old pattern (silent clipping in un-swept siblings is worse than the bug).

### Settings-hydration & sentinel-parameter template (recurring: BUT-1220, 674, 1322, 1610)
Any field persisted via a private settings sub-doc needs: hydration seeding the sub-doc
directly; a corrupt-value test ALSO asserting a sibling merged field survives (one
`copyWith` in one try/catch can abort the whole merge); a save-path test asserting the
settings doc has it and the public doc does NOT, plus a round trip; one test per
serialization surface. Sentinel params (`Object? field=_unset`) need both quadrants:
omit→preserved, explicit-null→cleared. Capture the forwarded ARGUMENT IDENTITY, not a
downstream no-op. An EMPTY-STRING sentinel (`''`=cleared, `null`=leave alone) is a contract
between TWO files: a widget test pinning what LEAVES the emitter is green forever if a
consumer later re-collapses `''` to "unchanged" — pin the consumer's own `x ?? current` line
in ITS suite, same edit (BUT-1874: emitter pinned, `ShoppingItemManagementModule` untouched).

### Age/maturity/consent gates
- A field moved client→CF-authoritative: invert the old round-trip into an ABSENCE
  assertion on every client-write surface.
- "Infra error" vs "explicit rejection" needs a TYPED discriminator flag on BOTH branches.
- "Must NOT re-fire on resume" needs `verifyNever` AND the positive downstream effect in the
  SAME test.
- A "never-throws" method's contract is proven by the user-facing error field staying null
  on EVERY failure branch.

### Menu & tagging domain
- Weighted-random selectors: assert WEIGHT MATH via a `@visibleForTesting debug*` hook,
  never the sampled outcome; unrated == 1★ value; ceilings via `closeTo` at extremes.
- Any feature persisting entity ids later intersected with a live collection needs a
  ZERO-INTERSECTION test — stale ids usually fail OPEN, dangerous for allergen safety.
- A "conservative fallback" is only conservative if the shared `defaults` const is a
  SUPERSET of the happy path — open it and check.
- A widen-not-replace fallback needs its PASSTHROUGH half asserted too, not just the added
  floor — a preserved field can be silently swapped for empty.
- Anchor/cursor guards need a fixture landing the two code paths on DIFFERENT days, or a
  single-recipe fixture hides the off-by-one.
- Feature-flag OFF paths are a systemic blind spot (`tryGet<T>() ?? true`) unless a fake
  flag service is explicitly registered false.
- Denormalized-projection tests: capture via `.captured.last`; cover NULL-CLAMP (last vote
  removed → null, not 0); prove EQUAL-WEIGHTING with ASYMMETRIC inputs.

### Firestore cost, index & cascade patterns
- A declared composite index needs its own assertion (fakes can't catch a missing one) —
  assert `queryScope` alongside field order.
- A merged/idempotent cascade `update()`ing a doc it assumes exists can throw NOT_FOUND and
  fail the whole batch — test the gating doc exists but the target does not.
- A dotted-path transactional `update` needs an UNRELATED sibling field asserted SURVIVING.
- A CF trusting a doc field for a security decision is only as strong as the Firestore RULE
  validating it on create.

### CF/TS-specific
- A new emulator-integration test needs wiring on THREE fronts: the granular
  `test:integration:*` script, the composite CI chain, and the workflow's `paths:` trigger —
  unit runners auto-discover `test:*` but EXCLUDE those prefixes.
- Order the existence assert BEFORE the first dereference of a possibly-missing doc.
- A fix swapping a hand-rolled throw for a shared enforcer ships deletable-green whenever
  the suite injects that enforcer as a seam, and the AUDIT ROW is unassertable if the logger
  bypasses the module's own test seam (`admin.firestore()` direct vs `__setFirestoreForTest`).
- A relational CONFIG pin stays green when both numbers move together — anchor one literal.
- A ts-node mutant removing the LAST use of an import doesn't compile (`TS6133`) and prints
  ZERO test lines, which reads as "the whole suite died" — keep the symbol used.
- A retired-collection RE-POINT is proven by seeding the RETIRED path as a trap in the SAME
  run, never by asserting the live path alone.
- **These hand-rolled emulator runners share ONE world across cases, in order, so a mutant's
  RED COUNT is inflated by state cascade and cannot attribute anything.** A downstream case's
  PRECONDITION assert reddens on the upstream case's damage, not on its own discrimination —
  measured on BUT-1904's sync suite, where "4 fail" and "2 fail" both included a case whose
  own before→after transition is INVARIANT under the mutant, and whose named guard
  (`currentLastMessage?.id !== messageId`) survived deletion with the whole suite green.
  Attribute per case, cheaply and with no repo write, by replicating the handler's decision
  branches in a scratchpad JS file and replaying the cases in order: reproducing the reported
  red counts exactly is what proves the replica, and the per-case split then reads straight
  off it. A guard that only skips WORK (a read, a redundant write) is invisible to a suite
  that asserts only the final value — it needs a fixture where the skipped work would land
  somewhere DIFFERENT, or it is untestable at that layer and owes a comment, not a test.

### Multi-select / bulk-action wiring
- VM tests + card tests can pass while the GLUE (snapshot/order/callback) is untested at
  widget level. Selection-guard tests need the owner's OWN tile, not all-strangers.
- Clear-on-cancel: assert the count returns to the ORIGINAL, not zero. Copy-paste id-field
  mismatches are invisible unless a fixture makes the fields DIFFER.
- Async error stubs: `thenAnswer((_) => Future<int>.error(...))` — never `thenThrow`.

### Extraction seams & duplicated-logic-across-surfaces
- Pure decisions locked in a DI-heavy widget → extract `@visibleForTesting static`, not a DI
  bridge. When the SAME behaviour is re-implemented in 2+ classes, demand a test PER COPY —
  copies WILL diverge silently.
- An OPT-IN parameter gating a SECURITY behaviour is OFF everywhere until a `lib/` caller
  passes it — grep the name in `lib/` and `test/` separately; "test-only hits" IS the finding.
- **LIVE-PATH CHECK, before writing any test for a bug fix**: grep the call chain from the
  view down to the write, confirm the fixed method is ON it — a fix on a parallel facade
  with no `lib/` callers ships nothing. A tested caller + a tested callee ≠ a tested seam.
- An optional nullable callback seam ("stays constructible in tests") is invisible when every
  harness omits it — grep the seam's name across `test/`; zero hits IS the finding. **Hits are
  not the answer either: split them by LAYER.** BUT-1904's `onDismissBlocked` had 6 hits, all
  in the widget's own suite constructing the widget directly, and none at the view that wires
  it — so deleting the two production lines that pass it (and the message id they pass) left
  every suite green with the feature simply absent from the app. A callback seam owes one test
  at the CALL SITE'S layer, and it is cheap whenever a suite already mounts that view.
- A new error/message seam is only as good as its READERS — a caller that awaits then shows
  success unconditionally means the message is never shown or cleared.
- Enumerate optimistic-rollback siblings by SHAPE (catch blocks restoring local state,
  `return false`), not the ticket's wording — a fix on the two named leaves the rest live.
- When a data-loss ticket ships root cause + safety gate, the gate gets tests and the root
  cause gets none — grep the root-cause CLASS across `test/`. The third untested layer is
  usually the VIEW's outcome→message branch: assert the INVARIANT, be CHANNEL-AGNOSTIC.
- A "reads live state, not the cache" contract is only tested if the fixture makes the two
  DIFFER — cached vs stored needs a tick PLUS an item the cache never saw.
- An atomicity fix is tested at the layer OWNING atomicity, unreachable on the fake — a
  transaction-runner typedef seam is legitimate for platform codes but seams out the
  RUNNER, not the transaction; pair with an emulator-lane test.
- A permission guard on ONE method of a pair must be checked on its sibling — a
  callback-based API is the EASIER bypass. An attribution-field fix's sweep must include
  MODEL FACTORIES (a factory copying a display name means the FIRST stamp differs in source).
- Converting a per-item write to a per-item TRANSACTION makes existing `Future.wait` fan-outs
  over the SAME document pathological — grep callers first.
- A shared cache reused by a STRICTER new reader launders the weakest writer's output —
  enumerate every writer into the cache.
- A `didChangeDependencies` retry on a widget that renders `SizedBox.shrink()` on failure is
  DEAD — the early return happens before any `Theme.of`, so only a REMOUNT recovers.

### One-off gotchas, Windows/runner notes, and the revert-probe technique
- An overflow probe MUST mount `AppTheme.lightTheme` — the bare `MaterialApp`'s smaller
  default typography can hide a real overflow. Pin with SYNTHETIC tall content, never real
  ARB copy (dies with the flag). `expect(takeException(), isNull)` is ALSO satisfied by a
  tile that rendered nothing, so co-assert the content under test is present — otherwise a
  regression in the flag that ADDS the content turns the geometry case green. **That
  co-assert must reach the DIMENSION the geometry depends on, not the container type**: when
  the subject is how a row WRAPS, `find.byType(<Row>)` is satisfied by a one-item row, so a
  narrowed `take(maxBadges)` measures a two-badge row under a four-badge fixture comment and
  all cases stay green — assert the CHILD COUNT (BUT-1911). A ladder that
  SKIPS cases per fixture (`cleanUpTo`) is honest only if the skipped ones are MEASURED
  (320dp really does overflow from 1.3x, BUT-1895); the residual is then un-pinned in the
  reverse direction, so a source comment claiming "both ends are covered" goes stale in
  silence the day someone retunes the factor. Register those cases as NAMED `skip:`, never a
  `continue` — `testWidgets`' skip takes no reason, so the reason and ticket go in the NAME,
  which the runner prints every run. Two residuals survive that: the co-assert closes only
  "the ADDED content vanished" (a tile fitting because something ELSE shrank still passes),
  and a named skip goes stale GREEN the day the residual is actually fixed.
  **A SCROLLABLE ancestor makes the whole class structurally unfailable** — inside a
  `SingleChildScrollView` the child gets unbounded height, so no content can overflow and
  `takeException(), isNull` is green at any size. It still kills a fixed-slice mutant
  (measured: 7 `Expanded` day rows reddened all three cases), so the tests are worth keeping
  — but a group NAMED "the week fits" then asserts something nothing measures, and it was
  FALSE: 210 logical px of the week sat off-screen at 360dp@2x and 320dp@2x, and a 14-dish
  fixture hid 1090px, all green. Read `ScrollableState.position.maxScrollExtent` before
  writing "fits" (a `> 0` there IS the finding), and strike the claim rather than re-scope it
  (BUT-1971, 2026-08-29).
- A page-size guard is only testable on a TALL surface (`tester.view.physicalSize =
  Size(800,14000)`, dpr 1.0) — a short surface auto-scrolls and hides item 0.
- `Semantics(label:)` on a tooltip'd button MERGES into one node — match with `RegExp`,
  bracket with `ensureSemantics()`/`handle.dispose()`.
- Real `.xlsx` stores text via shared-strings (`t="s"`), not `inlineStr`. A
  `TimeoutException` with 0 tests run is compile-bound (~12 min shared compile), not hung —
  split invocation per file.
- **THE PROBE LADDER, cheapest first**: (1) analytic — make the two sources DIFFERENT
  literals so a revert can't coincide with expected; (2) SCRATCHPAD replica via `dart.bat
  --packages=<repo>/.dart_tool/package_config.json` (no repo writes, immune to parallel
  sessions); (3) `test/`-side replica; (4) mutate the INJECTION, not `lib/`; (5) only then a
  real `lib/` revert.
- **Writing a mutant into `lib/`/`functions/src` is REFUSED by the auto-mode classifier
  (content-, not command-sensitive)** — the Edit applies silently and the NEXT run is
  refused. On a dirty file: `cp -p` first, restore via reverse Edit, `cmp`/md5 verify. On a
  clean file: Edit-mutate, restore with `git checkout --`, verify via `git status`/`diff
  --stat` (not md5 — CRLF on checkout differs).
- **Revert-probe mechanics**: copy to scratch, string-replace the fix OUT, confirm EXACTLY
  the expected tests go red, restore + `cmp`. Assert the search text occurs EXACTLY ONCE
  before writing — doubles as a tree-motion detector. Do the cycle in ONE Bash call, script
  reading OLD/NEW text from FILES; on Windows read/replace/WRITE IN BINARY.
- A WHOLE-CLASS replica scales this: copy class + suite to the SESSION SCRATCHPAD (not
  `test/`), rename, repoint the import — the only route when the `lib/` file is STAGED or
  edits are forbidden. Run the unmutated copy as control first.
- READ THE MUTATED LINE BACK before believing a red count — a shell heredoc can mangle
  backslashes silently. Write probes with the Write tool, raw Dart strings, never a bash
  heredoc. Never pipe a mutation driver into `head` (SIGPIPE kills its own cleanup).
- A probe file lives in scratch, not `test/` — a `// delete after` header is not a deletion
  (two outlived their round in 2026-08-12). Close every round with `git status --porcelain`.
- When the test reads a FILE PATH (registry lints, declared-index asserts), the mutant is a
  GIT REVISION — `git show HEAD:<path> > scratch/`, run the walk against both. The only
  probe available when the "fix" is a deletion.
- A deletion mutant inside a fluent chain doesn't compile — substitute an always-true
  equivalent (`.where('name', isNull:false)`).
- A generated file in a diff is verified by re-running its generator, byte-compared, with
  the output's mtime moving while inputs don't (a byte match proves nothing if the generator
  silently skipped files).
- A one-character change inside a string literal can't be reviewed from `git diff` — `od -c`
  or `git show HEAD:` it. Byte-form grep false-negatives under UTF-8: use the codepoint form
  `grep -nP '\x{F8FF}'`, a Python sweep, or `cat -A`.
- A new grep guard in `lefthook.yml` needs one path-handling probe — it renders
  `{staged_files}` REPO-RELATIVE, so an anchor past a `path:line:` prefix false-fails on a
  Windows absolute path (`C:/…` splits at the drive colon); anchor the LAST `:<digits>:`. A
  guard wired only pre-commit is bypassed by `LEFTHOOK_EXCLUDE` or a merge. **The ONE-FILE
  case is its own probe**: grep OMITS the filename when handed exactly one FILE, so a
  `path:line:` parser takes its malformed-input branch for every hit and the baseline is never
  consulted. An EXIT-CODE-ONLY fixture suite structurally cannot see that — the pre-existing
  "a named violating file IS refused" case expects exit 1 either way and passes for the wrong
  reason. Probe any guard fix by running the guard's OWN fixture suite against `git show
  HEAD:<script>`; identical pass counts IS the finding, and the killer fixture INVERTS the
  expected code (one named BASELINED file, exit 0). BUT-1904: 15/15 both sides, the 16th case
  red on HEAD with the exact error the blocked commit was blamed with.

### Firestore-rules `.ts` suites (emulator-gated)
- Every `&&` clause in an `allow` rule gets a failing test; every `cannotModify`/
  `hasRequiredFields` list needs a test PER FIELD.
- A failure-only update suite can be silently over-restrictive — pair denials with an
  `assertSucceeds` on a mutable field.
- The emulator persists docs ACROSS invocations — suffix create-test ids with a per-run
  `Date.now().toString(36)`, or a fixed-id create silently becomes an update.
- Hand-rolled `npx ts-node` runners against `127.0.0.1:8080` time out without the emulator
  running first; `npx tsc --noEmit` DOES typecheck `src/__tests__` — a free non-emulator
  check on a rules suite you can't run.
- **A client-side filter test on the fake says NOTHING about whether the SERVER accepts that
  query** — rules refuse a whole QUERY when any candidate doc fails the read rule. A
  membership-filtered read owes THREE assertions: filtered-ALLOW (SDK's own spelling, with a
  non-empty premise check); unfiltered-DENY (delta is only the missing `where()`); and
  filtered-ALLOW-but-empty for a member of nothing.
