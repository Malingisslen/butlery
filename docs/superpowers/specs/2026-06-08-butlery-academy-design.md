# Butlery Academy — Design Spec

**Date:** 2026-06-08
**Owner:** Malin (solo founder)
**Purpose:** Onboard a coding *beginner* (Malin's husband) to become a second developer on Butlery, working through Claude Code — ship-capable, not just oriented.

## Goal & audience

- **Success state:** he can take a Linear ticket, drive Claude Code, review the diff, get past the commit gates, and push to main — independently.
- **Starting point:** beginner coder (reads simple code, follows logic, hasn't built anything large). Native Swedish reader.
- **Implication:** lean on Claude-Code-as-pair. Teach *directing Claude*, *reading/reviewing output*, and *trusting the guardrails* over memorizing theory. The map + safety nets come first so gates and agents aren't scary.

## Chosen approach — Hybrid (C)

Interactive HTML "academy" as the **map + lasting reference**, where every module ends in a **hands-on exercise against the real repo**, culminating in shipping a real ticket. Rejected: pure HTML course (A — reading doesn't make you ship-capable) and pure apprenticeship (B — no lasting artifact, needs Malin present).

## Deliverable

- **Single self-contained HTML file**: `docs/onboarding/butlery-academy.html` (embedded CSS + JS, no build, no server — double-click to open).
- **Interactivity:** `localStorage` progress tracking + per-module completion checkboxes (resumable); copy buttons on every example prompt/snippet; collapsible architecture diagram; mini-quiz checkpoints; glossary.
- **Look:** matches Butlery's design language — cream / forestGreen / rust palette, **square corners everywhere** (no rounded edges), lowercase headings vibe. Verified against the design-system findings in the dossier.
- **Language:** Swedish prose; English technical terms kept as-is (ServiceLocator, ViewModel, hook, commit, repository...).

## Content source of truth

`docs/onboarding/butlery-academy-dossier.md` — produced by a verified multi-agent deep-dive (14 agents, ~1.26M tokens) of the codebase + Claude Code setup. A skeptical critic agent verified every file path and gate instruction against the real repo; 2 factual corrections + 3 coverage gaps were applied. **The HTML must not introduce any path or claim not present in the dossier.**

### 13 modules / 3 parts

**Del 1 — Claude Code & din setup:** 1) Vad är Claude Code & vibe coding · 2) Komma igång · 3) Skyddsnäten: skills/agenter/hooks · 4) När det blockar: commit-gates, markers, plan mode, lessons.md · 5) Dirigera Claude bra

**Del 2 — Butlery-appen (kartan):** 6) Vad är Butlery · 7) Arkitekturen (Views→ViewModels→Services→Repositories→Firebase) · 8) Feature-kartan · 9) Firebase & datalagret · 10) Säkerhet · 11) Konventionerna (svenska strängar, fyrkantig design, 500-rader, mixins)

**Del 3 — Shippa på riktigt:** 12) Din första ticket — BUT-677 (uppvärmning) → BUT-722 (capstone), steg för steg · 13) Fusklapp & ordlista

## Capstone tickets (reserved)

- **BUT-677** (warm-up) — Swedish marketing copy for desktop/web differentiator. Pure copy, lowest blast radius.
- **BUT-722** (capstone) — "What's New" release-notes sheet. Small new service + modal + ARB key; additive, real-feature win.
- Both **assigned to Malin + labeled `onboarding-reserved`** (orange) in Linear so they're not auto-picked.

## Required implementation tasks (beyond writing the HTML)

1. **Exclude `onboarding-reserved` from the sprint loop.** `sprint-execute` / `sprint-execute-parallel` ticket selection must skip this label, otherwise the reservation is only a human-readable signal. (Verify whether they already skip assigned tickets; add the label filter regardless.)
2. Build a **look-and-feel prototype first** (design shell + 1–2 filled modules), preview via the HTML preview workflow, get Malin's sign-off, *then* fill all 13 modules from the dossier.

## Non-goals

- Not a Flutter/Dart tutorial from zero — teaches enough stack to direct Claude, not CS fundamentals.
- Not auto-updating — it's a snapshot; a "last reviewed" date in the footer flags staleness.
- No backend/server; no analytics on the page.
