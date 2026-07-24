# Which documents earn a place in this repo

Named by the doc-taxonomy check when a new `.md`/`.html` is written, and by `/docs-sweep`
when the whole repo is audited. The short version stays in `.claude/rules/code-style.md`;
this is the full rubric.

## The principle

Docs that explain what the code does are debt: delete them and spend the saved effort on
making the code self-explanatory — names, structure, targeted WHY comments.

## The six classes

A committed doc may exist ONLY as one of these:

1. **Decision record** — alternatives considered, why X over Y, dated calls.
   (`.claude/rules/accepted-deviations.md`, `docs/architecture/ACCEPTED_DEVIATIONS.md`,
   the rationales in `ACCEPTED_LARGE_FILES.md`.)
2. **Glossary / domain language** — meaning the code cannot express.
3. **Navigation pointer** — THIN link-chains forming the roads a session navigates by
   (the workflow map, `RECIPE_PIPELINE.md`). Thin is load-bearing: a nav doc that
   re-explains the code gets condensed.
4. **Operating instructions** — CLAUDE.md, `.claude/rules/`, skills, agent
   `*.knowledge.md`, runbooks like `docs/ops/analyzer-recovery.md`.
5. **Machine-consumed data** — files read by CI, hooks, or scripts.
6. **For-Malin docs** — plain-language, explicitly for the founder.

## The auto-reachability test

An exception class grants the right to exist; reachability makes it findable. A doc needs
**both**. Before writing one, ask: will a future session read this on its own — because a
rule, an agent knowledge file, a slash command, a gate message, or a code comment points
at it — or is it explicitly for Malin? If neither, don't create it.

"Felt thorough to write" is not a reason. Write-only docs (analysis reports, audit
verdicts, status snapshots) rot and get deleted later.

## Rules that follow

- Scratch space for the current task lives in `tasks/` and is disposable — delete plans
  once implemented, debug docs when resolved.
- Prefer updating an existing doc of the same class over creating a new one.
- No V1/V2 copies — update in place. No per-directory READMEs.
- `/docs-sweep` audits the whole repo against this taxonomy; run it when docs feel stale.
