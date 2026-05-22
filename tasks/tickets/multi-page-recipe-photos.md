# Linear Ticket Draft — Multi-Page Recipe Photo Import

> Ready to paste into Linear. Linear MCP was not connected during the session this draft was prepared in, so the ticket has not been created there yet. Drop the body into a new Triage ticket with the metadata listed below.

---

**Title:** Add multi-page recipe import (2–5 photos → one recipe)

**Labels:** `idea`, `recipe`, `import`, `parsing`

**Priority:** Medium

**State:** Triage

---

## Opportunity

Many cookbook recipes span two pages — ingredients on one side, method on the other — and magazine recipes occasionally run three or more pages. Today, photo import only accepts a single image, so users either lose half the recipe or import twice and manually paste text in the editor. This friction pushes users away from photo import for exactly the recipes most worth digitising.

## Current State (verified 2026-05-22)

Single-image only, by design:

- Capture: `lib/viewmodels/photo_import_viewmodel.dart:510` sets `_imageBytes = bytes`, replacing any previous image.
- View: `lib/views/photo_import_view.dart` shows one `ImagePreviewCard` with "Choose New Image" (not "Add Another").
- Strategy: `lib/services/import/photo_import_strategy.dart:110` accepts a single `imageBytes` parameter.
- Cloud Function: `functions/src/llm/ocr-recipe-image.ts:42` — `OcrRecipeImageRequest` takes singular `imageBase64`/`imageUrl`.
- Half-built infra: `lib/services/image_picker_service.dart:225` already implements `pickMultipleImages(maxImages: 5)` but is wired to nothing.

Workaround today: import page 1 → save → import page 2 → manually copy/paste text in the editor → delete the leftover recipe.

## Proposed Improvement

### Capture UX

- Single-page flow stays identical — no upfront mode toggle.
- After the first image is selected, surface an **"Add another page"** button.
- When N≥2, replace the single big preview with a horizontal **thumbnail strip** labeled "Page 1, Page 2, …". Each thumbnail supports: tap → fullscreen, replace, delete, drag-to-reorder.
- **Hard cap at 5 pages** (matches existing `pickMultipleImages(maxImages: 5)`). Hide the add button at cap.
- Submit button label switches to "Extract recipe from N pages" when N≥2.

### Extraction (low-cost path — chosen because we minimise running costs)

**Zero new Cloud Function endpoints.** Reuse `ocrRecipeImage` and the existing recipe-extraction LLM call unchanged. Client-side orchestration only.

In `photo_import_strategy.dart`:

1. Fan out **N parallel calls** to existing `ocrRecipeImage`, one per page.
2. As results arrive, render per-page progress in the UI.
3. After all succeed (or user accepts partial), concatenate OCR text in page order:
   ```
   Page 1:
   <ocr text>

   Page 2:
   <ocr text>
   ```
4. Feed the combined text to the existing recipe-extraction LLM call — unchanged.

Cross-page references (e.g. "spice mix from page 1" referenced from page 2) are preserved because the extraction step sees all pages at once.

### Failure handling

- Per-page OCR failure shows a **retry button on just that page**; other pages stay green.
- User can choose "Extract from successful pages only" if one page is unsalvageable.
- Cancel button per in-flight OCR.

### Storage

Persist all N source images alongside the recipe, mirroring today's single-image storage pattern with a page suffix (exact path to be confirmed against the storage convention in `photo_import_strategy.dart`).

## Files Likely Affected

- `lib/views/photo_import_view.dart` — thumbnail strip, add-page button, per-page progress UI
- `lib/viewmodels/photo_import_viewmodel.dart` — list of pages instead of single image (⚠️ already 703 lines, may force facade extraction — see Risks)
- `lib/services/import/photo_import_strategy.dart` — parallel OCR fan-out + text concatenation
- `lib/services/image_picker_service.dart` — possibly a per-page single-shot API for retake/replace
- Tests under `test/viewmodels/`, `test/services/import/`, `test/views/`

## Acceptance Criteria

- [ ] Single-page import flow is unchanged for users who only take one photo.
- [ ] After the first photo, an "Add another page" button is visible and adds up to 5 pages total.
- [ ] Pages display as a thumbnail strip with page numbers when N≥2.
- [ ] Per-page actions work: delete, replace, drag-to-reorder. Reorder persists into LLM input order.
- [ ] Submit triggers parallel OCR with per-page progress visible to the user.
- [ ] Per-page OCR failure surfaces a retry button on that page only without affecting others.
- [ ] User can extract from successful pages only when one page is unsalvageable.
- [ ] On all OCRs succeeding, combined text is fed to existing recipe-extraction LLM; resulting recipe opens in the standard editor.
- [ ] All N source images are stored alongside the recipe.
- [ ] No new Cloud Function endpoints.
- [ ] Existing single-page photo-import tests still pass.

## Effort vs Impact

- **Impact (high):** Removes the biggest unblocked friction in photo import. Cookbook and magazine recipes — the highest-value content for digitising — become first-class.
- **Effort (medium):** Pure client-side feature. Zero backend changes, zero new LLM endpoints. Complexity concentrated in page-list UI (reorder, retake, per-page progress) and corresponding ViewModel state.
- **Cost ceiling:** N× current OCR per import (max 5×). Recipe-extraction LLM call cost unchanged. No prompt-caching opportunity lost vs. today's flow.

## Risks

- `photo_import_viewmodel.dart` is already 703 lines (over the project's 500-line ceiling per `CLAUDE.md`). Adding multi-page state will likely require a facade extraction (e.g. `MultiPageImageManager`) — scope this at start, not late.
- Page order matters for LLM concatenation — must be preserved across reorder + delete. Cover with a test.
- One slow OCR page can hold up the whole import. Mitigation: parallel calls + per-page progress + cancel.
- Pages with no recipe content (user adds a blank or unrelated shot) will produce empty/garbage OCR. The combined-text extraction will likely cope, but add a defensive empty-OCR check before sending to the extraction LLM.

## Out of Scope

- Single multi-image Gemini call on the backend (deferred — the chosen path keeps backend untouched and per-page parallel/resilient).
- More than 5 pages.
- Merging already-saved recipes.
- Auto-detection of where one recipe ends and the next begins.
- Page rotation / cropping beyond what the existing single-image picker provides.

## Design Decisions (already made)

| Decision | Choice | Rationale |
|---|---|---|
| Extraction strategy | Per-page OCR + concatenated text extraction | Lowest running cost path, zero backend changes, per-page resilience, reuses existing endpoints |
| Capture entry | "Add another page" button after first photo | No upfront decision for single-page users (the common case) |
| Page cap | Hard cap at 5 | Matches existing `pickMultipleImages` default; covers virtually all real-world cookbook recipes |
