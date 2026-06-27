# Virtual Role-Org — design & MVP spec

_Status: **BUILT & operating** (last updated 2026-06-27). World-watch, the dossier-freshness loop,_
_Phase-2 stakeholder review, and the measurement layer are all live on `main`, $0/interactive._
_Companion to `docs/architecture/ROLE_RESPONSIBILITY_MAP.md` (the dossier source this system operates over)._

> **Keep this doc current — nothing automates it.** The dossier-freshness loop tracks the role *map*
> against code, NOT this design doc against the system's build state. So when you add or change a
> subsystem (a skill/hook/layer), update the status line above and the relevant section here in the
> same change. This doc drifted once (the measurement layer shipped before it was documented) — this
> note is the guard.

## What this is

The role map gives Butlery 28 notional roles, each with what it owns in the code (+ verified
watch-items) and a **world-model** (what to monitor externally, cadence, authority, sources). This
doc specifies how to turn those static dossiers into a **working virtual organisation**: workers that
get picked for relevant tasks, review plans from their own stake, deliberate toward the best
whole-system answer, and stay current with the outside world despite an LLM's fixed knowledge cutoff.

Directed solo (Malin directs; Claude builds), so "the org" is rules + agents + dossiers, not people.

## The constitution (decided)

| Dimension | Decision |
|---|---|
| **Deliberation** | Parallel **blind critique → synthesis**, capped rounds. No round-robin chatroom (research shows it drifts via sycophancy and inflates cost). |
| **Authority** | **Hybrid.** The synthesizer reconciles; if it detects an *unresolved high-stakes* conflict it escalates to Malin; otherwise a "CTO/Chief-Architect" agent rules using a written priority order. **Every disagreement is filed as an ADR** regardless of who decided. |
| **Trigger** | **Experts always ON by default** (Malin's directive 2026-06-27 — see "Default posture" below), **blast-radius tiered** via the path→role router (`tools/stakeholder_router.py`): `/linear` stamps the owning stakeholder on every ticket at creation (interactive build is `/sprint-execute --pick`, which reviews before building); `/sprint-execute` runs the panel on every ticket before building it (Phase 1.4). The router bounds cost — full panel on high-stakes paths (`firestore.rules`, `lib/services/{auth,llm,gdpr}`, payments, `functions/src/account`), a single stakeholder on medium changes, skip trivial/doc-only. Opt-out is explicit per-run (`--no-review`). The `PreToolUse(ExitPlanMode)` hook still *suggests* the panel for ad-hoc plans outside those commands. |
| **World-watch alerts** | **Tiered by role** — `flag-only` → digest; `auto-ticket` → Linear ticket (hard-deadline/ship-breaking roles); `escalate-human` → Malin (anything interpretive, i.e. all legal/privacy). |
| **World-watch cadence** | **Volatility-matched** — weekly (high churn: Apple/Play policy, CVEs, Claude Code releases), monthly (law, pricing, most tooling), quarterly (slow drift). Per-role cadence already stored in the dossiers. |
| **Dossier freshness (vs code)** | **Hooks + periodic re-sweep** — a `PostToolUse` hook stamps a role's dossier stale when its owned paths change; a scheduled pass re-audits only stale ones. |
| **Cost** | **$0 marginal.** Runs on **interactive Max only** (see below). No paid API, no metered automation. |

### Cost constraint — why interactive-only

As of the 2026-06-15 billing change, Max splits: **interactive** Claude Code (Malin at the terminal)
is flat-rate/unmetered; **automated/headless** use (GitHub Actions, scheduled `claude -p`, SDK) draws a
*separate* monthly automation credit (~$100/mo on Max 5x) and then bills at API rates. Headless also
carries silent OAuth-token expiry (~1yr, no auto-refresh) and an unwritten fair-use ToS for unattended
subscription use. **For a hard $0 constraint, the org never runs unattended.** It runs *inside Malin's
own sessions* (which happen most days), which is free, needs no secrets, and keeps a human present when
tickets are filed — removing the unattended-hallucination risk entirely.

### Default posture (updated 2026-06-27): experts always on

Malin's directive: *"I want the right specialist to check the right ticket from the beginning, and the
experts to always be on unless I explicitly state otherwise. The project is complex enough that we
always need to be careful and weigh tradeoffs."* This supersedes the earlier opt-in framing (where the
panel was only *suggested*). The new default:

- **`/linear`** assigns the owning stakeholder to every ticket at creation (`## Stakeholders` line);
  interactive build moved to `/sprint-execute --pick` (which runs the panel before building).
- **`/sprint-execute`** routes every candidate at selection and runs the blind panel before building
  each ticket (Phase 1.4) — conditions fold into the acceptance criteria and become binding.
- **Opt-out is explicit and per-run** (`--no-review`, or "skip the panel"). Caution is the baseline;
  lowering it is a deliberate, visible choice logged in the run report.

**Cost reconciliation:** the $0/interactive principle holds for the common case — a `/loop
/sprint-execute` running inside Malin's own session is flat-rate Max, so "always on" is free there. The
router's `skip`/`single`/`full-panel` tiers keep even a metered *headless* run proportional (most
tickets are `single` = one cheap critique; the full panel is reserved for high-stakes paths). **Non-halt
rule:** in the autonomous loop the panel is advisory and never blocks — an unresolved high-stakes
conflict parks the ticket in **In Review** with an ADR + a push notification (escalate-human becomes a
parked ticket, not a live `AskUserQuestion`, which would halt the loop). The interactive `/linear
backlog` path *can* escalate live.

## MVP — session-triggered world-watch for Legal · Release-Compliance · Security

The smallest valuable slice: horizon-scanning for the three highest-stakes roles, $0, no deliberation
machinery required.

**The three roles & their params (from the dossiers):**

| Role | Cadence | Authority | Watches (source allowlist in the map) |
|---|---|---|---|
| Security Architect | weekly | auto-ticket | GitHub Advisory (pub ecosystem) Atom, freeRASP releases Atom, GCP/Firebase security bulletins, OWASP MASVS/MASTG |
| Release / App-Store Compliance | weekly | auto-ticket | Apple App Review `/news/upcoming-requirements`, Google Play policy announcements |
| Legal Counsel | monthly | escalate-human | IMY (Swedish DPA) news, EDPB, Konsumentverket / Marknadsföringslagen |

**The loop (runs in-session when a scan is due):**

1. **Due-check.** On session start (hook) or via a durable scheduled task, read the state file and ask:
   for each of the 3 roles, is `now − lastScan ≥ cadence`? If none due, stay silent.
2. **Cheap poll.** For a due role, fetch its source feeds/changelogs (prefer the RSS/Atom/`/whats-new`
   endpoints already captured in the map — CI/fetch-friendly).
3. **Diff vs snapshot.** Compare against the last stored snapshot; emit **only deltas**. (This is the
   cost/noise lever and makes a skipped window self-healing — the next session covers the gap.)
4. **Impact-check.** A delta matters only if it plausibly touches our code/decisions (cross-reference
   the role's owned paths + watch-items in the dossier).
5. **Route by authority.** `auto-ticket` (Security, Release) → file a Linear ticket. `escalate-human`
   (Legal) → file a Linear ticket **labelled for Malin's review**. Always cite the source URL + the
   quoted change; never assert law/policy without a link.
6. **Update state.** Write new snapshot + `lastScan` date; commit the state file.

**Artifacts to build:**
- `docs/org/world-watch/state.json` (committed) — per-role `lastScan` + last source snapshot.
- A `/world-watch` skill — the loop above, also manually invokable.
- A `SessionStart` hook **or** `CronCreate durable:true` entry that runs the due-check each session.
- Linear integration for ticket filing (auto-ticket vs review-labelled).

**Why this validates the idea cheaply:** it proves the freshness loop end-to-end (sources → diff →
impact → tiered Linear output) on the roles where a missed change hurts most, with zero cost and zero
unattended risk, before any investment in the deliberation/router machinery.

## Phase 2 — stakeholder review (BUILT 2026-06-27)

The deliberation system, built to the constitution above. **Advisory only — it never auto-merges
or auto-acts; Malin decides whether to proceed.** $0/interactive like the rest of the org.

**Pipeline** (`/stakeholder-review <plan|fileset>`):

1. **Router** (`tools/stakeholder_router.py`, reuses `docs/org/role-paths.json` — same ownership
   map as the freshness loop, so role selection stays honest to the role map). Routes by **blast
   radius, not "is it a plan"** — a plan is reviewed at the tier its *files* warrant, so mid-risk
   plans get the cheap focused tier instead of always convening the (expensive) full panel:
   - `full-panel` — **high-stakes paths only** (`firestore.rules`/`storage.rules`,
     `lib/services/{auth,security,llm,account}`, `session_timeout`/`device_integrity`,
     `functions/src/{account,audit_logs,cleanup,llm}`, payments/subscription). Panel = path owners
     ∪ a **high-stakes core** (Security, Privacy/GDPR, Legal, Software Architect, Product Manager,
     FinOps) with veto-level standing. _Owner-COUNT does not trigger the full panel_ — one theme
     file is co-owned by several design roles, and that is not a broad blast radius.
   - `single` — a mid-risk change with no high-stakes path → a **focused review by the direct
     owner(s) only** (1..N, no core). This is the default for most plans; reserve the full panel
     for where it pays for itself (≈0.6M tokens, validated 2026-06-27).
   - `skip` — only trivial/doc paths that no role owns → no review.

   **Trigger gating (the money-pit guard).** Inside `/linear` and `/sprint-execute` the panel is
   **on by default** (see "Default posture") — the router runs every time and decides depth. For
   **ad-hoc plans outside those commands**, the `PreToolUse(ExitPlanMode)` hook
   (`suggest-stakeholder-review.sh`) scans the *finished plan text* for high-stakes signals
   (security rules, GDPR/personal-data, auth, Cloud Functions, moderation, destructive-data ops,
   payments, allergens, LLM) and **suggests** `/stakeholder-review` — non-blocking. Routine plans
   (a CSS tweak, a copy fix) get silence either way: the router's `skip` tier and the hook's
   signal-scan both fall through. Each critic is scoped to the plan's blast-radius files (not free
   repo exploration) to keep token cost proportional — this is what makes "always on" affordable.
2. **Parallel blind critique** — one subagent per seated role, each given ONLY its own dossier
   (mandate + watch-items + world-model) and the plan; **none sees the others' critiques**. Each
   returns: position (`approve` / `approve-with-conditions` / `block`), top risks from its stake,
   must-haves, and a cost/effort note. No round-robin chat (it drifts via sycophancy + inflates cost).
3. **Synthesis** — a synthesizer reconciles the critiques into ONE recommendation, surfacing
   agreements, conditions, and genuine conflicts.
4. **Hybrid tiebreak:**
   - An **unresolved high-stakes conflict** → escalate to Malin (`AskUserQuestion`) with the tradeoff
     + each role's stake laid out. She decides.
   - Any other conflict → the **Chief-Architect (CTO) agent** decides by the written priority order below.
5. **ADR** — every disagreement (resolved or escalated) is recorded as a dated, append-only file under
   `docs/org/adr/`: the stakes, the decision, who decided. The org remembers its own arguments.

### The priority order (CTO tiebreak rubric)

When stakeholders conflict and it isn't escalated to Malin, the Chief-Architect agent breaks the tie
by this order — **higher beats lower**. This is the org's politics made explicit and revisable; change
it here, in the open.

1. **User safety & trust** — physical safety; **allergen-data correctness is the product** and
   outranks everything (the verdict a user trusts their health to); protection of minors; no harm.
2. **Legal & privacy** — GDPR, AI Act, consumer law, store policy. **Always escalates to Malin** —
   legal/privacy is never decided by the rubric (a compliance breach is existential for an EU
   consumer app, and most calls are interpretive).
3. **Data integrity & security** — correctness of allergen/tag data, auth, Firestore rules, no data
   loss or leak.
4. **Correctness & accessibility** — does what it claims, handles errors, doesn't regress; meets
   WCAG 2.1 AA / EAA obligations (accessibility is compliance-adjacent, not polish).
5. **Cost ceiling** — $0-marginal bias; minimize Firebase/LLM spend (CLAUDE.md cost principles).
6. **Velocity & simplicity** — ship the smaller thing; avoid gold-plating.
7. **Aesthetics & polish** — design-system fidelity, delight.

Two load-bearing choices (keep these): **legal sits ABOVE security** (#2 > #3) — a compliance breach
is existential, whereas most security bugs are fixable defects; and **cost sits BELOW correctness**
(#5 < #4) — don't ship a wrong result to save money, and don't gold-plate past the cap. Allergen-data
correctness is Butlery's "the verdict is your product" and is pinned at #1. Aesthetics last — it
matters, but never at the expense of the above.

## Measurement & tuning (BUILT 2026-06-27)

The role-org grades itself from its own evidence — no metrics pipeline, $0/interactive.

- **Event log** — `docs/org/metrics/events.jsonl` (append-only) + `log_event.py` (stamps `ts`,
  fails open). Skills/hooks log one line per real action; schema in `docs/org/metrics/README.md`.
- **Instrumented the two gaps the artifacts can't show** — `/stakeholder-review` logs each review
  (so clean `approve` outcomes that leave **no ADR** are captured = the rubber-stamp rate), and the
  `ExitPlanMode` suggest-hook logs each trigger firing (calibration). World-watch/freshness are
  already covered by `state.json` + markers, so they're documented-optional.
- **`/org-retro` skill** — reads events + ADRs + `state.json` + markers and scores: Phase-2 value &
  rubber-stamp rate, trigger calibration, world-watch signal-to-noise + source health, freshness
  accuracy (did a review catch a *dossier* error?), and cost/review. Plus a manual **false-negative
  spot-check** (the one thing logs can't show). Modes: `shakedown` (~days) and `full` (~weeks).
- **Self-clearing reminder** — `org-retro-due-check.sh` (SessionStart) nudges to run `/org-retro`
  once a window passes (`shakedown` @4d, `full` @28d, from `retro-schedule.json`); survives the
  ephemeral container unlike a session cron. A retro counts as done when its `{type:retro,mode}`
  event lands, which clears the nudge. First shakedown surfaces ~2026-07-01.

## Phase 2+ (future, not built)

- **Widen world-watch** from 3 roles to all world-facing roles once the loop is trusted.
- **Scheduled dossier re-sweep** — a periodic pass over stale markers (the per-edit stamping +
  `/refresh-dossiers` are built; an automatic cadence is not).

## Open items

- Linear label taxonomy for `escalate-human` review tickets — currently reusing the `need-malin`
  lane label; revisit if escalations need their own dimension.
- Source allowlist gaps flagged by verification (2 EU/ETSI URLs need a manual re-confirm on an
  unblocked network; see the map's source caveat). EDPB RSS retired in its 2026-06-22 redesign →
  now polled via the news page + IMY secondhand.

## Resolved (was open)

- ~~`SessionStart`-hook vs durable-cron for the due-check~~ → SessionStart hook (`world-watch-due-check.sh`).
- ~~The CTO-agent's written priority order~~ → drafted above (Phase 2 build, 2026-06-27).
- ~~Dossier freshness loop~~ → BUILT (stale-stamp hook + `/refresh-dossiers`).
