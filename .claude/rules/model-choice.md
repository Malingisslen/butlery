# Model choice

Decided by Malin 2026-10-07. The rule is to spend Opus where a wrong call is expensive and
push reading down to cheaper models.

- **The main session leads** on Opus 5.5 at medium effort: it decides, plans and writes
  code where a mistake is costly. Do not move it to a smaller model.
- **Reading goes to Haiku 5.5.** Code searches, CI and test logs, summaries, Linear
  lookups and reading old threads or long files go to `Explore` (Haiku) or an Agent call
  with `model: haiku`. Bring back the conclusion, not the dump.
- **Clearly scoped everyday code goes to Sonnet 5.5.** UI, tests and small fixes with a
  precise brief go to a Sonnet subagent at medium effort.
- **Security, GDPR, Firestore rules, Cloud Functions and plans stay on Opus.** Their
  agents pin `model: opus` so they never follow a smaller main model.
- **Fable only when Malin asks for it.**
- **Context:** past about 200k tokens, wrap up and hand over in a fresh thread, with
  what must survive written to memory. Run at most 3–4 parallel threads.

Each agent pins its own `model:` and `effort:` in its frontmatter; change the pin there,
not here.
