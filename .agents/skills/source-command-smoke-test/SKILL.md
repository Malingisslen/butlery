---
name: "source-command-smoke-test"
description: "Migrated source command `smoke-test`"
---

# source-command-smoke-test

Use this skill when the user asks to run the migrated source command `smoke-test`.

## Command Template

# Smoke test via Chrome MCP

Human-in-the-loop E2E smoke test. Replaces Patrol (broken on Windows, see
BUT-395). Drives the running Flutter web app through a scripted journey,
screenshots each checkpoint, reports pass/fail.

## Arguments

- No args: runs the full suite (every file in `test/smoke/journeys/`).
- `/smoke-test auth`: runs only `test/smoke/journeys/auth.md`.
- `/smoke-test --list`: prints available journey names and stops.

## Prerequisites check (run before journey)

In parallel:

1. `cd C:/Butlery/butlery && netstat -ano | grep -E "LISTENING.*:(8080|9099|9199)" | head`
   — check if Firebase emulators already listen on auth/firestore/storage.
2. `preview_list` — check if a Flutter web dev server is already running.

If emulators are not up:
- Start with `run_in_background: true`: `export PATH="/c/Program Files/Android/Android Studio/jbr/bin:/c/Users/malla/AppData/Roaming/npm:$PATH" && firebase emulators:start --only auth,firestore,storage --project butlery-emulator-test`
- Wait with Monitor: `until curl -sf http://localhost:9099 && curl -sf http://localhost:8080; do sleep 3; done`

If no dev server is up:
- `preview_start` with command `flutter run -d chrome --web-port 8088 --dart-define=USE_EMULATOR=true`
  (use port 8088 — 8080 is taken by Firestore emulator)

## Execution protocol

For each journey file (plain-English `.md` with numbered steps):

1. Read the file. The user-facing intent is the **Intent** line; the
   automation instructions live under **Steps**.
2. Walk steps top-to-bottom. Each step is: an action (navigate / click /
   fill / wait) followed by an assertion.
3. After the action, use `preview_snapshot` (DOM) or `preview_inspect` (CSS)
   for the assertion — NOT `preview_screenshot` unless the step says so
   explicitly. Screenshots are for the final pass/fail report, not for
   verifying individual steps (too slow, no structural info).
4. On any assertion failure, STOP the journey. Screenshot the failure state.
   Report the step that broke + actual vs expected.
5. At end of journey, screenshot the final state with `preview_screenshot`.

## Pass/fail reporting

Each journey produces one line in the final report:

```
✓ auth — 7/7 steps passed (screenshot: /tmp/smoke/auth-final-<ts>.png)
✗ recipe-create — failed at step 4: expected #recipe-title-input, got null
  (screenshot: /tmp/smoke/recipe-create-fail-<ts>.png)
```

If ALL journeys pass, report:
```
Smoke test: PASS — N/N journeys green (took Xm Ys).
```

If ANY journey fails, report:
```
Smoke test: FAIL — X/N journeys passed, Y failed.
  [list failures with screenshot paths]
```

## Teardown

After reporting, leave the Firebase emulator + dev server running unless
the user says to stop — a follow-up `/smoke-test` will reuse them. To
explicitly clean up: kill the Firebase process + `preview_stop`.

## What this is NOT

- Not a unit test — don't use it to replace `flutter test`.
- Not a deep E2E — only covers happy paths defined in journey files.
- Not Android/iOS — Flutter web only. Platform-specific bugs need the
  cross-platform CI matrix (BUT-396) or a physical device.
- Not unattended — runs only when invoked; not wired to CI.

## Finding widgets via Semantics (BUT-403)

Flutter web's CanvasKit renderer draws everything into one `<flutter-view>`
canvas, so plain CSS selectors (`#foo`, `.bar`) match nothing. Widgets must
be located via the **browser a11y tree**, which Flutter populates with
`<flt-semantics>` nodes once the semantics tree is built.

The app force-enables semantics at startup on web (see
`SemanticsBinding.instance.ensureSemantics()` in `lib/main.dart`), so the
tree is ready from the first frame — no placeholder click needed. Every
widget with a `Semantics(identifier: ...)` wrapper shows up as an
`<flt-semantics>` node with matching `id` / `aria-label` attributes.

If a journey ever sees empty selector results on load, confirm semantics is
actually on: `document.querySelector('flt-semantics') !== null`. If it's
missing, the `DISABLE_FORCE_SEMANTICS` dart-define may have been set, or
the force-enable call was removed — re-check `main.dart`.

**Query pattern — preview_eval:**

```js
// In a preview_eval call, query the a11y tree:
const el =
    document.querySelector('[aria-label="btn-mark-cooked"]')
 || document.querySelector('flt-semantics[id*="mark-cooked"]');
el?.click();
```

### Identifier naming scheme

| Pattern | Example | Where |
|---|---|---|
| `nav-{route}` | `nav-/veckomeny` | Bottom nav / drawer items |
| `btn-{action}` | `btn-mark-cooked`, `btn-save-recipe`, `btn-import-url`, `btn-add-shopping-item`, `btn-generate-menu`, `btn-share-recipe`, `btn-quick-save` | Primary CTAs |
| `recipe-card-{index}` | `recipe-card-0` | Recipe list / grid cells |
| `item-toggle-{index}` | `item-toggle-3` | Shopping list rows (0-based, global order) |
| `menu-slot-{weekday}-{mealtype}` | `menu-slot-monday-lunch` | Weekly menu calendar cells |

Identifiers use enum `name`s (English) so they stay stable when the
Swedish display labels change. When adding new CTAs, always add both:

```dart
Semantics(
  identifier: 'btn-foo',      // browser a11y hook
  button: true,
  label: context.l10n.fooLabel, // screen reader text
  child: ElevatedButton(
    key: const ValueKey('test-view-foo'), // Flutter widget-test hook
    onPressed: ...,
    child: Text(context.l10n.fooLabel),
  ),
)
```

The `ValueKey` is for `find.byKey(...)` inside Flutter widget tests, which
is a separate discovery mechanism from Semantics. Keep both.

### Known limitations

- Overlay-positioned children (`PopupMenuItem`, dialogs) mount outside the
  main tree. Query them only after the parent is tapped; rely on the
  tree settling (1-2 `preview_snapshot` calls) before asserting.

## Adding journeys

Create `test/smoke/journeys/<name>.md` with the template:

```markdown
# <Journey name>

**Intent:** one-line description of what user value this proves.

## Steps

1. **Navigate** to `/route` → assert `<selector>` visible with text "X".
2. **Click** `<selector>` → assert `<next selector>` visible.
3. **Fill** `<selector>` with "value" → assert input persists.
4. ...

## Teardown (optional)

Per-journey cleanup. Skip if none needed.
```
