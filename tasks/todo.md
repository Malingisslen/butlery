# Sprint Backlog

## Sprint: high-priority backlog drain — 2026-05-19 (Tu)

Theme: 7-ticket batch drawn from current Backlog after confirming the 2026-05-08 sprint shipped (commit c5e53cb53). Mix of 1 Urgent + 6 High, clustered by area. Skipped: ops-only tickets (BUT-760 App Check, BUT-731 Apple cert), legal/doc tickets (BUT-811), and BUT-784 (LLM golden-set needs its own focused sprint).

### Step 0 results

- **BUT-812** — pending → all 5 sub-fixes actionable. INFRA13 already done (retention-days: 14 in build-validation.yml lines 226, 262); IPA upload doesn't exist by design (BUT-447 deferral).
- **BUT-787** — premise gone. BUT-836 already shipped Phase 1 (factory hardening + arch-test for `data[...] as DateTime|Timestamp` in `lib/models/`); Phase 2 is BUT-841 (Low).
- **BUT-798** — scope expanded ~4× (126 sites across 95 files vs 34 in original audit). Re-scoped in Linear with Phase 1-4 follow-up plan.
- **BUT-805** — 5 sites in current code (not 7). Image-cache part fits this sprint; PERF5 isolate offload deferred.
- **BUT-806** — HIGH-TS3 premise gone (ContentType.fromWire already handles retired values); HIGH-TS4 needs legal/PM input on App Check consent gating.
- **BUT-822** — Firebase MCP enabled fetching production model bytes; hashes computed and populated locally.
- **BUT-782** — confirmed real (660 lines + 30+ test sites). Too big to bundle safely; deferred to focused single-item sprint.

### Agent A: infra + verify
- [x] **A1. BUT-812** — dep-audit concurrency added; lefthook regex extended (Stripe sk_live/sk_test, Slack xoxb-, Slack webhook URLs); 5× `actions/checkout@v4 → @v6` (dep-audit ×3, sbom, firestore-rules); setup.sh/.ps1 Flutter `3.32.4 → 3.35.1`; INFRA13 already shipped.
- [~] **A2. BUT-787** — obsolete; BUT-836 (commit c5e53cb53) covered Phase 1 + arch-test; BUT-841 holds Phase 2 sweep at Low priority.

### Agent B: flutter-developer — UI migrations
- [!] **B1. BUT-798** — DEFERRED. Step 0 found 126 sites across 95 files (4× the audit's 34). Re-scoped Linear body lists Phase 1–4 sub-tickets to file as follow-ups.
- [x] **B2. BUT-805 (image part)** — 5 `Image.network` sites migrated to `CachedNetworkImage` with `FirebaseUrlUtils.stableCacheKey` + placeholder/errorWidget. Arch-test guard added with `// arch-allow: Image.network` escape hatch.

### Agent C: firebase-backend-security — security/rules
- [!] **C1. BUT-806 (code part)** — DEFERRED. HIGH-TS3 premise gone (graceful filtering already implemented); HIGH-TS4 needs legal input. Re-scoped Linear body captures findings.
- [x] **C2. BUT-822** — Production ONNX hashes computed via Firebase MCP + sha256sum. Populated both `kExpectedNerModelHashes[1]` and `kExpectedLineClassifierModelHashes[1]` in `_expected_model_hashes.dart`. BUT-827 hash-format guard will now do real work.

### Agent D: backend refactor
- [!] **D1. BUT-782** — DEFERRED. 660-line static class + 30+ test sites; full refactor is single-sprint scope. Linear ticket reverted to Todo with re-scoped plan for next sprint.

### Tier-2 agent reviews
- [x] code-reviewer — full Dart diff. Verdict: clean.
- [x] testing-specialist — staged `lib/**/*.dart` + arch-test. Verdict: clean.
- [skip] firebase-backend-security — no `lib/repositories/` or `functions/src/` (excl tests) staged.
- [skip] firestore-rules-tester — `firestore.rules` not touched.

### Post-Sprint Steps
- [x] `dart analyze --fatal-infos` — clean.
- [x] Tier-2 markers written (code-review, testing-review).
- [ ] File follow-ups: BUT-XXX (BUT-798 Phase 1), BUT-XXX (BUT-805 PERF5 isolate offload), BUT-XXX (BUT-806 legal review).
- [ ] Commit (inline), push.
- [ ] Linear close: BUT-812, BUT-787, BUT-805, BUT-806, BUT-822 (shipped or premise gone). BUT-798 + BUT-782 stay open with re-scoped bodies.

### Known follow-ups (will be filed in Linear before commit)

- BUT-798 Phase 1 follow-up — centered full-screen `CircularProgressIndicator` → `StateWidget.loading` in `lib/views/` (~25 sites).
- BUT-805 PERF5 follow-up — isolate offload for parser/CRF/OCR hot paths (~3-4h, needs profiling).
- BUT-806 legal-review follow-up — App Check consent gating + full data-processors enumeration in privacy policy (blocked on legal review opening up).

---

## Archived prior sprint (completed in commit c5e53cb53)

test-gap closure + tech-debt sweeps — 2026-05-08 (F) — BUT-832/827/815/816/836/837/831 done.

## Archived earlier sprint (completed in commit fd9c8ea17 + bed18c4cd + aef8968c7)

analytics caller-wiring + backend correctness sweeps — 2026-05-07 (Th) — BUT-833/834/830/824/826 done; BUT-787/783 deferred → BUT-836/837 filed.
