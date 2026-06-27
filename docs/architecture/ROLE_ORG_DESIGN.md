# Virtual Role-Org — design & MVP spec

_Status: **design, not yet built** (2026-06-26). Companion to_
_`docs/architecture/ROLE_RESPONSIBILITY_MAP.md`, which is the dossier source this system operates over._

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
| **Trigger** | **Blast-radius tiered**, via the path→role router that already exists in the commit-gate hooks: full stakeholder panel on plans + changes to high-stakes paths (`firestore.rules`, `lib/services/{auth,llm,gdpr}`, payments, `functions/src/account`); a single stakeholder on medium changes; skip trivial/doc-only. |
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
   map as the freshness loop, so role selection stays honest to the role map). Blast-radius tiers:
   - `full-panel` — a plan, OR any **high-stakes path** (`firestore.rules`/`storage.rules`,
     `lib/services/{auth,security,llm,account}`, `lib/services/session_timeout`/`device_integrity`,
     `functions/src/{account,audit_logs,cleanup,llm}`, payments/subscription), OR ≥3 owning roles.
     Panel = path owners ∪ a **high-stakes core** (Security, Privacy/GDPR, Legal, Software Architect,
     Product Manager, FinOps) that always has veto-level standing on big changes.
   - `single` — 1–2 owning roles, no high-stakes path → just those owners.
   - `skip` — only trivial/doc paths that no role owns → no review.
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

1. **User safety & wellbeing** — physical safety (allergens!), protection of minors, no harm.
2. **Legal & privacy compliance** — GDPR, AI Act, consumer law, store policy. Non-negotiable where law
   is clear; *interpretive* calls escalate to Malin rather than being decided by rubric.
3. **Data integrity & security** — correctness of allergen/tag data, auth, Firestore rules, no data
   loss or leak.
4. **Correctness & reliability** — does what it claims, handles errors, doesn't regress.
5. **Cost** — $0-marginal bias; minimize Firebase/LLM spend (CLAUDE.md cost principles).
6. **Velocity / simplicity** — ship the smaller thing; avoid gold-plating.
7. **Aesthetics & polish** — design-system fidelity, delight.

Rationale: allergen safety is the product's core promise, so it outranks everything; legal/privacy
sits just under because violations are existential but some are interpretive (those go to Malin, not
the rubric). Cost beats velocity because this is a solo, $0-constrained project. Aesthetics last — it
matters, but never at the expense of the above.

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
