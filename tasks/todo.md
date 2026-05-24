# Sprint Backlog

## Sprint: iter-55 — BUT-899 unit-converter negative-quantity consistency — 2026-05-24 (Sun)

Theme: Trivial bug fix. Apply `.abs() >=` consistency across all conversion branches. Plan-fil FÖRST per discipline.

### Step 0 — premise verification

- `lib/utils/text/unit_converter.dart:162-166` — `g` branch uses `quantity.abs() >= 1000` (verified line 163).
- All other branches (`ml`, `cl`, `dl`, `mg`, `krm`, `tsk`, `msk`) use plain `quantity >= N` — so a negative quantity short-circuits at every comparison and falls through to the "no conversion" return. Asymmetry confirmed.
- Per ticket: "Apply `.abs()` consistently across all unit-conversion branches" — the simplest, most defensive fix. Rejecting at entry (alternative) would require touching callers; abs-everywhere is internal-only.

### Design choices

- **Just match the `g` branch pattern**: use `quantity.abs() >= N` in every threshold comparison. Output keeps the original sign (since `quantity / N` preserves it).
- **Don't reject negatives at entry**: per ticket alternative wasn't preferred (would propagate up to validator-land which is BUT-444 territory).
- **Mass branch g/abs() comment**: keep it as the canonical example. Add an inline note that this is now the consistent pattern.

### Ship this sprint

- [ ] **A1. BUT-899** — Add `.abs()` to 8 threshold checks across ml/cl/dl/mg/krm/tsk/msk branches in `unit_converter.dart`.
- [ ] **A2. Test** — Add one unit test asserting `-500 ml` → `-0.5 l` (parallel to existing `-500 g` → `-0.5 kg` if it exists; otherwise pin both).

### Acceptance

- [ ] All conversion branches treat sign symmetrically.
- [ ] New test passes; existing tests unchanged.
- [ ] `flutter analyze` clean.

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Stäng BUT-899 i Linear → Done

---

## Archived iter-54 (commit `22e0e067f`) — 2026-05-24 (Sun)

BUT-922 source-artefact wiring on 3 remaining import strategies (url, textPaste, photoOcr). +77 / -27. BUT-922 → Done. BUT-1079 filed för UI affordances.
