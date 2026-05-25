# Sprint Backlog

## Sprint: iter-65 — BUT-1061 HtmlSanitizer flag script tags — 2026-05-25 (Mon)

Theme: Security gate fix — `HtmlSanitizer.check()` only flags 3 critical patterns (data:text/html, null byte, >5MB). Raw `<script>` tags are silent-strip via `sanitize()`. RecipeParserService spends parse cycles + possibly LLM calls on injection content. P3 parsing/security.

### Step 0 — premise verification

- Ticket matches `lib/services/parsing/sanitizers/html_sanitizer.dart:55-111` (check method) and `:117-148` (sanitize). Comment on line 18-19 even acknowledges the gap: "<script> ... should NOT be checked here — they appear in normal HTML."
- `sanitize()` already correctly preserves `<script type="application/ld+json">` via `preserveWhen` (line 144-146). The same exemption applies to the new check() flag.
- Test at `test/unit/services/parsing/sanitizers/html_sanitizer_test.dart:569` explicitly pins the current "don't flag" behavior with reason "Script tags are stripped by sanitize(), not rejected by check()" — needs flipping.
- Classification: **fits** — implement as written.

### Design choices

- **Regex with negative lookahead**: `RegExp(r'<script\b(?![^>]*application/ld\+json)', caseSensitive: false)` flags `<script>` and `<script type="text/javascript">` but NOT `<script type="application/ld+json">`. Single-pass; no second regex needed.
- **Add to `_scriptPatterns` list** (same place as the existing `data:text/html` pattern). One regex, same severity (critical), same emit pattern.
- **Update comment on line 18-19** — the assertion that `<script>` "should NOT be checked" is now wrong; replace with the JSON-LD-exemption rationale.
- **Test changes**: flip the pin'd "should not flag script tags" → "flags non-JSON-LD script tags as critical". Add a sibling test that JSON-LD scripts are NOT flagged (allowed).

### Ship this sprint

- [ ] **A1. Flag non-JSON-LD `<script>` in check()** — `lib/services/parsing/sanitizers/html_sanitizer.dart:20-22`: add `<script\b(?![^>]*application/ld\+json)` regex to `_scriptPatterns`; update the comment on lines 17-19. (BUT-1061)
- [ ] **A2. Flip pin'd test + add JSON-LD-allowed test** — `test/.../html_sanitizer_test.dart:569`. (BUT-1061)

### Acceptance

- [ ] `flutter analyze` clean.
- [ ] `flutter test test/unit/services/parsing/sanitizers/html_sanitizer_test.dart` passes (flipped test + new JSON-LD test green).
- [ ] No regression in `sanitize()` behavior (still strips, still preserves JSON-LD).

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Close BUT-1061 with commit hash

---

## Archived iter-64 (commit `3f887621c`) — 2026-05-25 (Mon)

BUT-1059 P3 fix — sync try/catch couldn't catch async Crashlytics futures. Extracted `_safeCrashlytics` helper, applied to 7 sites across 2 files, removed now-obsolete test scaffold. +69 / −102. 26/26 unified_menu tests pass. BUT-1083 filed for logger_test.dart gap.
