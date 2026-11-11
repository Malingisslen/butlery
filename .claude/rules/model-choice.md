# Model choice

Decided by Malin 2026-10-07. The rule is to spend Opus where a wrong call is expensive and
push reading down to cheaper models.

- **The coordinator leads** on Opus 5.5 at medium effort: it decides, plans and writes
  briefs where a mistake is costly. Do not move it to a smaller model.
- **Ordinary feature threads start on Sonnet 5.5** (Malin 2026-10-11). Opus 5.5 is kept for
  the areas listed below.
- **Reading goes to Haiku 5.5.** Code searches, CI and test logs, summaries, Linear
  lookups and reading old threads or long files go to `Explore` (Haiku) or an Agent call
  with `model: haiku`. Bring back the conclusion, not the dump. Large files (patches, CI logs, long threads) are
  never read directly by the main thread.
- **Clearly scoped everyday code goes to Sonnet 5.5.** UI and tests with a precise brief
  go to a Sonnet subagent at medium effort.
- **A small fix in one file with a precise brief goes to Haiku 5.5** (outside the Opus areas
  below), and a Sonnet or Opus agent reviews its diff before it is committed.
- **Security, GDPR, Firestore rules, Cloud Functions and plans stay on Opus.** Their
  agents pin `model: opus` so they never follow a smaller main model.
- **Fable as the main model only when Malin asks for it.**
- **Fable advises, as Malin's interpreter** (trial, Malin 2026-11-11; she decides on
  2026-11-18 whether it stays). Malin is not a developer. When she asks for something new
  or unclear, consult the advisor before any work starts and ask it four things: what she
  most likely means, what she has missed that a developer would know, which alternative
  or more creative solutions exist, and which control questions she should get. Put those
  questions to her as decision cards, at most three. Consult again before a plan is
  locked. Do not consult for a clearly described bug fix, a status question or a routine
  step, and never from a subagent or gate reviewer: each call re-reads the whole
  conversation at Fable's price.
- **Context:** past about 200k tokens, wrap up and hand over in a fresh thread, with
  what must survive written to memory. Run at most 3 parallel threads (Malin 2026-10-11); further threads queue until one
  finishes.
- **Reviews:** gate reviewers run one at a time on the final staged diff, only the
  specialists the files require. Never run several agents in parallel in one turn.

Each agent pins its own `model:` and `effort:` in its frontmatter; change the pin there,
not here.
