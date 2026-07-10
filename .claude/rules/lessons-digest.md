# Lessons Digest (auto-loaded)

One line per lesson in `tasks/lessons.md` — this digest loads every session so the
corrections are always in force; the full entries (Trigger/Rule/Example) are the deep
reference. **Sync contract (CLAUDE.md rule #9):** every new lesson gets its one-liner
appended here in the same edit. A Stop-hook tripwire (`knowledge-freshness`, workflow-guards plugin) warns
when the counts drift apart.

## Workflow

- A gate's block message may only name remedies that SHIP with the gate (same plugin / inlined procedure) — test the message from every repo the gate is installed in.
- An audit agent's claim about a tool's OUTPUT FORMAT is a guess until reproduced — run the real tool and test the regex against a real line before "fixing" a parser.
- Feedback right after a deliverable may target the TOOL/process, not the one artifact — disambiguate "fix this output" vs "improve the capability" before acting.
- A multi-part agreed initiative gets ONE written plan before any slice ships — chat scrollback is not a backlog.
- Every proposed improvement must name its mechanical trigger; upgrading an optional command is convenience, not infrastructure.
- Never prune a young system for inactivity — the observation window must exceed its natural cycle (tune now; keep/cut only after 2–3 cycles).
- Epic breakdown: query the epic's CHILDREN + statuses first; the epic body is a stale snapshot.
- Scan dedup runs against CURRENT code + recorded decided-nos — a closed same-name ticket may be a regression; refile it.
- Don't hand the user judgment/labor you can derive yourself; defer only product intent, irreversible actions, or external facts.
- Never conclude "backlog drained" from a sample — full-backlog classification first (gated via `.claude/state/backlog-scan.json`).
- Wrap side-effect ship agents in try/catch; verify from git ground truth; salvage crashed runs instead of re-running.
- Sprint Phase-1 plan-write to `tasks/todo.md` is non-optional — even mid-streak, even for trivial tickets.
- Bash `cd` persists across calls — use absolute paths.
- Verify a ticket's premise with a Step-0 code read before implementing; live code trumps ticket text.
- Verify Edits actually landed (`git diff`) before committing — never trust the commit-message claim.
- Stop-hook errors: fix only files THIS session touched; ignore parallel sessions' errors.
- Workflow `args` can arrive as a STRING — guard/parse booleans like dryRun before trusting them.
- Umbrella "apply the deferred notes" tickets must carry the content inline or link an immutable source.
- "Unreferenced" must be proven against the WHOLE repo, never a hand-picked subset.
- Eval input must match PRODUCTION input, not the cheapest-to-label input.
- Run arch gates locally before committing UI widgets.
- Touch review markers in a SEPARATE Bash call before `git commit` — never inline in the same call.
- Slow CI jobs (Build Validation, Run Tests): verify via `gh run list` — the 15-min watcher expires first.
- `docs/analysis/runs/` was deleted by explicit decision — don't recreate it; citations are inlined.
- An iOS-native pin's staleness needs the iOS Build Validation gate to prove — a changelog read is not enough.
- When the user asks for a new mode, deliver ONE mode — no "normal + extra", no spare variants.
- Staging doesn't survive parallel sessions — pathspec-commit in one call and re-verify the index after any gate block.
- "Map the workflows" means full coverage against a stated universe — never silently curate a sample.
- Data-writing Cloud Functions get the xhigh multi-agent review BEFORE commit — the single-specialist gate is necessary but not sufficient.
- When citing a deterministic tool's verdict (router tier, gate, test), RUN it and paste output — never assert what it would say.
- Port per-repo configs from the RETIRED implementation's real paths/semantics — structurally different machinery keeps its native hook + opts out of the shared one.

## Testing

- Red CI on an unrelated test = suspect a pre-existing flake; fix the flake at root (seed the RNG) — never rerun-until-green.
- `architecture_test.dart` guards are NOT in `dart analyze` — analyze-clean ≠ CI-green for `lib/widgets/`.
- Adding a named param to a mocked service silently un-matches every old mocktail stub — update the stubs.
- cloud_firestore's FieldValue caches the platform factory statically — fake batches can throw subtype errors.
- A new source file can land as a git binary blob — verify `file` says "text" before committing.
- Lexicon-dependent tests: assert the premise, and watch NFC vs NFD normalization on å/ä/ö.
- real-time-guard matches the literal `DateTime.now()` even inside comments.
- After changing a class's constructor, run its EXISTING test suites — not just the new test you wrote.
- A parallel-sprint's own "verified/done" is a claim, not a fact — on any salvage, verify from git, run the workflow /code-review (cross-file) on the staged diff BEFORE the specialist gates, then re-review the fixes; here it caught 8 bugs (incl. cross-file integration regressions) the per-ticket adversarial verify + file-scoped specialists both missed.

## Firebase

- Firestore `sum()`/`average()` with a filter on a DIFFERENT field needs a COMPOSITE index (filter field first, aggregated field included); `count()` doesn't. In-memory fakes can't catch it — assert the declared index config in a test.
