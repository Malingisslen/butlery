# Auth smoke

**Intent:** the Swedish auth screen renders, toggles to Register mode, and
accepts form input. Proof that first-run users can see the entry point and
start a registration. Does NOT submit — submission is a separate journey.

## Steps

1. **Navigate** to `http://localhost:8088/` (dev server port — 8080 is the
   Firestore emulator). Assert: the page loads without a Flutter engine
   crash (`preview_console_logs` shows no `Uncaught` errors in the last
   5 entries).

2. **Wait** for the auth screen. Assert via `preview_snapshot`: the text
   "butlery" is present (brand wordmark in the header), and an input with
   key `email_field` (translates to attribute `flt-semantics-identifier` or
   a `<flutter-view>` child — accept any matcher that confirms an email
   input is rendered).

3. **Click** the Register-mode toggle. The button reads "Skapa konto" in
   Swedish. There are two candidates in the DOM in Login mode: the primary
   submit button (gets disabled in Login mode, says "Logga in") and the
   bottom toggle OutlinedButton (says "Skapa konto"). Click the
   OutlinedButton variant by finding the element whose text is exactly
   "Skapa konto" AND whose parent is not the primary/filled button.
   Assert: the screen now shows a name field (key `name_field`).

4. **Fill** the name field with "Smoke Test". Assert: the input value
   persists after a `preview_snapshot` pump.

5. **Fill** the email field with `smoke+<epoch-ms>@butlery.test`. Use
   `Date.now()` via `preview_eval` to get a unique suffix. Assert: the
   entered email appears in the snapshot.

6. **Fill** the password field with "SmokeTest123!". Assert: the password
   input has received input (displayed as dots but the framework should
   report a non-empty value). If the password snapshot is obscured, skip
   this assertion — the visual at step 7 is sufficient evidence.

7. **Screenshot** the final state with `preview_screenshot`. Save as
   `/tmp/smoke/auth-final-<ts>.png`. This is the pass artifact.

## Teardown

None. Leaving the entered form values in place is fine — the next run
uses a fresh email suffix.

## Expected runtime

Under 15 seconds once the dev server is warm.

## Known fragility

- Flutter web's CanvasKit renderer sometimes fails to hit-test buttons that
  are visually present. If step 3 click doesn't fire, retry once with
  `preview_eval` to dispatch the click on the underlying semantic node
  rather than the pixel coordinates. Document the retry in the report.
- The "butlery" wordmark assertion in step 2 is intentionally lenient —
  the brand text may be rendered as an SVG or Canvas glyph rather than
  DOM text. Accept either `find.text` or an equivalent semantic label.
