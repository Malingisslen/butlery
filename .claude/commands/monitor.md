---
description: Start background monitors — CI status, Firebase errors, test streaming, dart analyze
argument-hint: <ci [sha]|firebase|test [path]|analyze|status|stop [id]>
---

Start or manage background monitors that stream events into the conversation using the Monitor tool.

## Automation

These monitors start automatically — you rarely need to run them manually:
- **analyze** — auto-starts on every session (via SessionStart hook)
- **firebase** — auto-starts after any `firebase deploy` or `npm run deploy` (via PostToolUse hook)
- **ci** — auto-starts after push in `/sprint-execute` and `/commit`
- **test** — auto-starts between agent batches in `/sprint-execute`

Use `/monitor` manually when you want to start one outside those flows, or to check status / stop a running monitor.

## No Arguments — Show Help

If `$ARGUMENTS` is empty, display this table and stop:

| Command | Watches | Duration | Auto? |
|---|---|---|---|
| `/monitor ci [sha]` | GitHub Actions workflows for a commit | Until all complete (~5 min) | After push |
| `/monitor firebase` | Firebase Functions error/warning logs | Session-length | After deploy |
| `/monitor test [path]` | Flutter test results | Until tests finish | In sprint-execute |
| `/monitor analyze` | dart analyze on modified files | Session-length | On session start |
| `/monitor status` | List active monitors | — | — |
| `/monitor stop <id>` | Stop a running monitor | — | — |

## `ci [sha]`

Watch GitHub Actions CI for a commit.

1. Resolve SHA: if an argument follows `ci`, use it. Otherwise `git rev-parse HEAD`.
2. Get short SHA: first 7 chars.
3. Start Monitor:
   - command: `bash .claude/hooks/monitors/ci-watcher.sh <FULL_SHA>`
   - persistent: false
   - timeout_ms: 900000
   - description: "CI status for <short-sha>"
4. Say: "Watching CI for `<short-sha>`. Results will stream in."

## `firebase`

Watch Firebase Functions for errors and warnings.

1. Start Monitor:
   - command: `bash .claude/hooks/monitors/firebase-errors.sh`
   - persistent: true
   - timeout_ms: 3600000
   - description: "Firebase Functions errors"
2. Say: "Watching Firebase logs. Errors/warnings will appear as notifications."

## `test [path]`

Run flutter tests in background, stream results.

1. Resolve path: if arguments follow `test`, use them. Otherwise use `test/unit test/widget`.
2. Start Monitor:
   - command: `bash .claude/hooks/monitors/test-streamer.sh <path>`
   - persistent: false
   - timeout_ms: 600000
   - description: "Tests: <path>"
3. Say: "Running tests in background. Results will stream in."

## `analyze`

Continuous dart analyze on modified files.

1. Start Monitor:
   - command: `bash .claude/hooks/monitors/analyze-watcher.sh`
   - persistent: true
   - timeout_ms: 3600000
   - description: "Continuous dart analyze"
2. Say: "Watching dart analyze. Notifications fire when issue count changes."

## `status`

List all active monitors (use TaskList or similar) with their descriptions. Do not start any new monitors.

## `stop`

Stop a running monitor by description or ID. Use TaskStop on the matching monitor.
