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
