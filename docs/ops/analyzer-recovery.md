# Analyzer recovery — when `dart analyze` is the problem, not the code

Named by the Stop check and the lefthook analyze gate when they fail, so it arrives
with the trigger instead of loading in every session.

**Read this when:** the analyze gate times out, the Stop check reports findings that
look wrong, or output is truncated right after `Analyzing butlery...` with nothing
listed. Otherwise the findings are real — fix the code.

## 0. Is it a false positive?

A block whose message truncates after `Analyzing butlery...` with **no findings listed**,
while this session touched no `.dart` files, is the analysis server crashing — not a
finding. Confirm with one fresh `dart analyze`. If that is clean, say so and continue;
do not "fix" anything.

## 1. Check free memory FIRST

```powershell
Get-CimInstance Win32_OperatingSystem   # → FreePhysicalMemory
```

The analysis server needs roughly 2 GB of headroom. The usual thief is several parallel
Claude sessions plus the Claude desktop app, each in the ~2 GB class — on 2026-07-16 this
machine had 1.2 GB free of 15.8. Close idle sessions and the desktop app.

**No cache surgery helps a starved server.** If memory is the problem, stop here.

## 2. Zombie processes

Tiny idle `flutter_tester.exe` processes are dead test runners holding the gate open:

```bash
taskkill //F //IM flutter_tester.exe
```

Retry the commit once.

## 3. Two analyzers contending

A lefthook analyze **timeout** (exit 124) while a standalone `dart analyze` runs clean is
contention with VS Code's live analyzer, not findings. Also check for a running
"Continuous dart analyze" monitor (fresh `/tmp/analyze*` mtimes mean it is active) and
stop it.

```bash
taskkill //F //IM dart.exe    # immediately before retrying the commit
```

Do not reach for `LEFTHOOK_EXCLUDE` here — the diff contains `.dart` files, so the gate
is the right gate; it is the second analyzer that is wrong.

A saturated process table crashes the analysis server and blocks `fork`. Restart rather
than retry.

## 4. Corrupted `.dartServer` cache

**VS Code does NOT need to be closed** (proven 2026-07-16, BUT-1622):

```bash
taskkill //F //IM dart.exe
rm -rf "%LOCALAPPDATA%\.dartServer"    # immediately after, same breath
```

The close-VS-Code-first route **fails** — the analyzer respawns and re-locks within
seconds of any scripted delete. The old stale cache deletes fine; the only survivors are
temp files owned by the instantly-respawned *new* analyzer, which is the desired end
state, not a failure.

Verify: `dart analyze` clean, and the cache directory small and freshly recreated.

## 5. Committing through it

Run a gated commit in the **foreground** with a long tool timeout (up to 600000 ms). A
backgrounded gated commit races the Stop hook's own `dart analyze`, and under two-session
load the process table saturates: the commit dies with fork failures and leaves a stale
`.git/index.lock`. Keeping the turn active means no competing analyze fires.

Use `git commit -- <pathspec>` — it is immune to the other session's staged index.

A lock with **no** live `git`/lefthook process is stale; remove it. A lock with a live
process is not — wait.

## 6. The only legitimate bypass

`LEFTHOOK_EXCLUDE=analyze git commit …` is legitimate only when **both** are true:

1. a standalone `dart analyze` ran clean just now, and
2. the staged diff contains no `.dart` files.

State both facts in the commit body. Every other gate still runs. `LEFTHOOK=0` (all gates
off) is never the answer, and `--no-verify` is refused by the commit gate outright.
