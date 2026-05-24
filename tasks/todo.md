# Sprint Backlog

## Sprint: iter-54 — BUT-922 wire SourceArtefact in 3 remaining paths — 2026-05-24 (Sun)

Theme: BUT-922 model already shipped (iter 14 BUT-1045 enum + class). YouTube + TikTok pipelines already wire `SourceArtefact` on success. Remaining: URL, text-paste, photo-OCR paths. Plan-fil FÖRST.

### Step 0 — premise verification (significant rescope)

Ticket says: "After photo import, raw OCR text is not stored on the saved recipe (`recipe_unified.dart` has no `ocrText` / `sourceArtefact`)". Verified 2026-05-24:

- `lib/models/recipe/source_artefact.dart` — `SourceArtefactType { url, youtubeTranscript, tiktokCaption, textPaste, photoOcr }` enum + `SourceArtefact{type, payload, fetchedAt}` class **already exists** (BUT-1045 iter 14).
- `RecipeCore.sourceArtefact: SourceArtefact?` already threaded through 6 serialization sites + `Recipe.copyWith` (BUT-1045).
- `lib/services/import/pipelines/tiktok_pipeline.dart:206` wires `SourceArtefactType.tiktokCaption` on success.
- `lib/services/import/youtube/youtube_import_strategy.dart` wires `SourceArtefactType.youtubeTranscript`.

**Remaining gap**: 3 of 5 enum values (`url`, `textPaste`, `photoOcr`) have no callsite wiring. The model is ready; the import strategies still drop the artefact.

### Design choices

- **URL path** (`url_import_strategy.dart`): wire `SourceArtefactType.url` with `payload = url` at the 3 success sites (lines 229, 253, 351). Captures the source URL as the payload (re-extract = re-fetch URL).
- **Text-paste path** (`text_import_strategy.dart`): wire `SourceArtefactType.textPaste` with `payload = original-input-text`. The strategy is `import(String text)` so passing the input through to the recipe is cheap.
- **Photo-OCR path** (`photo_import_strategy.dart`): wire `SourceArtefactType.photoOcr` with `payload = ocr-output-text`. Note: raw image bytes intentionally NOT stored — model docstring already calls this out ("the OCR result is the practical re-extract source").
- **UI affordances deferred**: "View source" + "Re-extract from source" UX is not autonomous-safe — needs UX placement decisions. File follow-up.

### Ship this sprint

- [ ] **A1. url_import_strategy.dart** — wire SourceArtefact at 3 sites (lines 229, 253, 351).
- [ ] **A2. text_import_strategy.dart** — wire at the recipe-construction site.
- [ ] **A3. photo_import_strategy.dart** — wire at the success path.
- [ ] **A4. Follow-up ticket** — UI "View source" + "Re-extract" affordances.

### Acceptance

- [ ] `flutter analyze` clean.
- [ ] Recipes imported via URL/text/photo paths persist `sourceArtefact` with correct enum + payload.
- [ ] `flutter test test/unit/models/recipe_unified_test.dart` + any source-artefact tests still pass.

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Stäng BUT-922 i Linear → Done with "service layer done; UI in follow-up" comment
- [ ] File BUT-XXXX for UI affordances

---

## Archived iter-53 (commit `88a63e2c4`) — 2026-05-24 (Sun)

BUT-704 partial — 3 ARB @meta placeholder blocks (en + sv parallel). Rescoped after Step 0 found 750/753 placeholder-strings already had metadata. BUT-704 → Done. BUT-1067 filed for ~3000 description-coverage backfill.
