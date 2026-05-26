# Sprint Backlog

## Sprint: iter-78 — Import regex hardening + Upload status bugs — 2026-05-26 (Tue)

Theme: Seven P3 Bug tickets from intent-test sprint batches 5–10, all "ticket-then-flip" shape. Two coherent batches: Agent A (4 import-regex bugs) + Agent B (3 upload-status bugs). Same proven pattern as iter-76/77.

### Ship this sprint

#### Agent A — Imports: case-sensitivity + host-anchoring (regex hardening)

- [x] **A1. TikTokPipeline: add `caseSensitive: false` to 4 patterns** — `lib/services/import/pipelines/tiktok_pipeline.dart:56-65`. (BUT-1092)
- [x] **A2. Flip tiktok pinning test** — `test/unit/services/import/pipelines/tiktok_pipeline_test.dart`. `isFalse` → `isTrue` on mixed-case host case. (BUT-1092)
- [x] **A3. InstagramPipeline: add `caseSensitive: false` to 4 patterns** — `lib/services/import/pipelines/instagram_pipeline.dart:22-26`. (BUT-1113)
- [x] **A4. Flip instagram pinning test** — `test/unit/services/import/pipelines/instagram_pipeline_test.dart`. Mixed-case host PINNED→passes. (BUT-1113)
- [x] **A5. YouTubeTranscriptService: add `caseSensitive: false` to 6 video-ID patterns** — `lib/services/import/youtube/youtube_transcript_service.dart:20-32`. (BUT-1116)
- [x] **A6. Flip youtube_import_strategy_test sibling-hunt assertion** — `test/unit/services/import/youtube/youtube_import_strategy_test.dart`. (BUT-1116)
- [x] **A7. YouTubeTranscriptService: anchor host regex (typosquat fix)** — `lib/services/import/youtube/youtube_transcript_service.dart:20-32`. Add `^https?://(?:www\.|m\.)?` prefix to youtube.com patterns, `^https?://` to youtu.be. Keep bare-ID pattern unchanged. (BUT-1091)
- [x] **A8. Flip youtube_transcript_service_test CHARACTERIZATION** — `test/unit/services/import/youtube/youtube_transcript_service_test.dart`. `equals(_vid)` → `isNull` for typosquat cases. (BUT-1091)

#### Agent B — Upload status bugs

- [x] **B1. UploadQueueManager.addCompletedUpload: add containsKey guard** — `lib/services/upload/upload_queue_manager.dart:58-69`. Mirror `addUpload` warning+no-op shape. (BUT-1118)
- [x] **B2. Flip upload_queue_manager_test "asymmetry" pinning test** — `test/unit/services/upload/upload_queue_manager_test.dart:168-186`. Assert pre-existing entry is PRESERVED (state == uploading, progress == 0.4) and warning is logged. (BUT-1118)
- [x] **B3. ImageUploadCoordinator: replace errorGeneric with sanitizeErrorForUser(e)** — `lib/viewmodels/recipe_form/image_management/image_upload_coordinator.dart:120-123`. Import `error_sanitizer.dart` if needed. (BUT-1128)
- [x] **B4. Add image_upload_coordinator fatal-batch test** — `test/unit/viewmodels/recipe_form/image_management/image_upload_coordinator_test.dart`. New test in "fatal-batch" group: when storage throws a typed exception (e.g. FormatException with message), assert errorsSet contains a sanitised message (NOT "Ett fel uppstod"). (BUT-1128)
- [x] **B5. UploadQueueSummaryCalculator: thread cancelled through + add all-cancelled branch** — `lib/viewmodels/recipe_form/image_management/upload_queue_summary_calculator.dart`. Add `cancelled` param to `getEnhancedQueueStatusText` (positional, after total). Call site at line 123 passes `cancelled`. Branch before final `else`: `if (cancelled > 0 && active == 0 && pending == 0 && failed == 0 && completed == 0) return l.uploadStatusAllCancelled(cancelled);`. Add l10n key `uploadStatusAllCancelled` to `app_sv.arb` + `app_en.arb` + `@meta`. (BUT-1102)
- [x] **B6. Update upload_queue_summary_calculator_test all-cancelled pin** — `test/unit/viewmodels/recipe_form/image_management/upload_queue_summary_calculator_test.dart:445-450`. Assert text contains '2' and the Swedish/English "alla avbrutna" substring (or just non-empty + cancelled count). Update positional args to include `cancelled`. (BUT-1102)

### Step 0 — premise verification (done)

- **BUT-1092** verified: `tiktok_pipeline.dart:56-65` — 4 `RegExp` lack `caseSensitive: false`. `_isTikTokUrl` lowercases for substring check, then matches original-case `url` against case-sensitive regex.
- **BUT-1113** verified: `instagram_pipeline.dart:21-26` — same shape as BUT-1092, 4 patterns.
- **BUT-1116** verified: `youtube_transcript_service.dart:20-32` — 6 patterns, all case-sensitive.
- **BUT-1091** verified: `youtube_transcript_service.dart:22-30` — no host anchoring; `iyoutube.com/watch?v=...` would match.
- **BUT-1118** verified: `upload_queue_manager.dart:58-69` — unconditional `_queue[key] = ...`. Note ticket says `_uploads` but file uses `_queue` (cosmetic).
- **BUT-1128** verified: `image_upload_coordinator.dart:120-123` — `_setError(AppLocale.current.errorGeneric)`. `sanitizeErrorForUser` exists in `lib/core/utils/error_sanitizer.dart`.
- **BUT-1102** verified: `upload_queue_summary_calculator.dart:155-157` — final `else` returns `''`. Function signature does NOT take `cancelled` — needs threading.

### ★ Risky-ticket plan — BUT-1091 ──────────────────
Classification: **fits** (security label on a regex-validation gate — caution warranted but mechanical)
Files: `lib/services/import/youtube/youtube_transcript_service.dart` (5 regex prefix additions) + test (typosquat assertion flips).
Blast radius: `isYouTubeUrl` becomes stricter. Any legitimate URL caller (share-sheet, paste, channel-watch) MUST start with `http(s)://(www.|m.)?youtube.com` or `http(s)://youtu.be`. Verified: production callers all originate from URL-import flows where the source is already a full URL. The bare-ID pattern is preserved for direct ID entry.
Rollback: revert the prefix additions; no schema or data effect.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

### Acceptance

- [x] `flutter analyze --fatal-infos` clean.
- [x] Each touched test file passes.
- [x] `flutter gen-l10n` succeeded after BUT-1102 ARB additions.

### Post-Sprint Steps

- [ ] Run code-reviewer + testing-specialist agents per Tier-2 gate.
- [ ] Commit + push.
- [ ] Close BUT-1092, BUT-1113, BUT-1116, BUT-1091, BUT-1118, BUT-1128, BUT-1102 in Linear.

---

## Archived iter-77 (commit `7b2d25b35` — BUT-1085 + BUT-1090) — 2026-05-25 (Mon)

Both P2 High social-bug fixes shipped via ticket-then-flip. Acceptance met. BUT-1086 stays open (deferred — needs product decision).
