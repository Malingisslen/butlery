# ADR-002: sqlcipher_flutter_libs migration plan (BUT-789)

**Status:** Decision artifact — execution deferred to a future sprint.

## Context

`sqlcipher_flutter_libs ^0.6.8` is a single-crate dependency that ships
SQLCipher (encrypted SQLite) native libraries for Android/iOS so Drift can
open an encrypted database. It is unmaintained — no commits in 18+ months,
upstream Flutter SDK bumps risk silent breakage, and security patches in
sqlite3/SQLCipher don't reach us via this package.

`MASTER-wave1.md` finding **CRIT-DEP1** flagged it as the highest-risk
end-of-life direct dependency.

## Blast-radius audit (verified 2026-05-06)

The encrypted database is consumed via Drift. Direct touches:

| File | Role |
| ---- | ---- |
| `lib/core/storage/drift/app_database.dart` | Imports `sqlcipher_flutter_libs`, calls `applyWorkaroundToOpenSqlCipherOnOldAndroidVersions()` and `open.overrideFor(android, openCipherOnAndroid)`. Sets `PRAGMA key` literal at connection-open. |
| `pubspec.yaml` line 44 | `sqlcipher_flutter_libs: ^0.6.8` |
| `pubspec.yaml` line 93 | `sqlite3: ^2.9.4` (transitively used by the above) |

Indirect surface (everything reading/writing through Drift):

- All DAOs under `lib/core/storage/drift/daos/` (cache, parse-cache, json-cache).
- All Drift tables under `lib/core/storage/drift/tables/`.

The encryption-key derivation lives in `_getDatabaseEncryptionKey()` (same
file, lines ~176-195): read from `flutter_secure_storage` if present,
otherwise generate a 256-bit base64Url-encoded random key and persist it.
The key never leaves the device. Cipher format is SQLCipher's default
(AES-256-CBC + HMAC-SHA1, page-level encryption).

## Options considered

### Option A — `sqlite3 ^3.x` + manual cipher PRAGMA wrapper

Replace `sqlcipher_flutter_libs` with the maintained `sqlite3_flutter_libs`,
ship SQLCipher's native `libsqlcipher.so` ourselves (or use
`sqlite3_flutter_libs`'s built-in cipher support if/when added). Keep the
existing `PRAGMA key = '...'` pattern.

- **Pros:** smallest API delta — Drift's `NativeDatabase` continues working;
  the `setup:` callback retains the same shape.
- **Cons:** we now own the native-binary distribution problem
  (`libsqlcipher.so` per Android ABI; iOS's static linking matters less).
  Build-system work to replicate what `sqlcipher_flutter_libs` did
  internally. No clean "drop a `^3.x` dep and you're done" path exists.
- **KDF compatibility:** if the same SQLCipher version is shipped, the
  on-disk format is bit-identical → no migration of existing user data
  needed. **This is the single biggest reason to favor this option** —
  sidesteps the data-loss risk inherent to a substrate change.

### Option B — `drift` with a different encrypted backend

Recent `drift` versions support `drift_sqflite` (no encryption) and a few
encrypted backends via community packages. None are well-maintained either
(`drift_sqlite_flutter_libs` doesn't exist; the canonical encryption story
is still SQLCipher).

- **Pros:** zero, as far as the audit found.
- **Cons:** trades one unmaintained package for another. Skip.

### Option C — drop encryption

Delete `sqlcipher_flutter_libs`, switch to plain `sqlite3_flutter_libs`,
remove the `PRAGMA key` setup. Threat model: an attacker with physical
device access (rooted Android, jailbroken iOS, lost device with the screen
unlocked) gains read access to every cached recipe, message preview, parse
correction, and OCR fragment.

- **Pros:** simplest possible migration. One pubspec swap, drop the setup
  callback, drop the `_getDatabaseEncryptionKey` plumbing.
- **Cons:** the encrypted DB exists specifically because we made the
  judgement that an attacker with physical access SHOULDN'T immediately get
  every cached message snippet. Reversing that judgement needs explicit
  user buy-in. Pre-launch and pre-store-submission, the actual exposure is
  tiny (no real users), but post-launch this becomes a regression.

## Decision

**Tentative direction: Option A** (sqlite3 + ship SQLCipher native libs
ourselves), because the on-disk-format compatibility means zero user-facing
migration. However, the execution work — bundling `libsqlcipher.so` per ABI,
verifying `cipher_version` still loads, smoking on real devices — is real
and merits its own sprint.

**Action this sprint:** none (this ADR). Execution sprint follow-up:
implementation + on-device smoke + a single-release rollback window.

## Migration cycle plan (when executed)

1. Add `sqlite3_flutter_libs` (or replacement) alongside `sqlcipher_flutter_libs`.
2. Bundle SQLCipher native libs (Android: `.so` per ABI, iOS: link statically).
3. Switch the `open.overrideFor(...)` to point at the new lib.
4. Verify `PRAGMA cipher_version` returns non-empty on real Android + iOS
   devices (the existing assertion in `_openConnection`).
5. Ship one release with both deps for rollback safety; observe
   crash/init failure rates.
6. In the next release, remove `sqlcipher_flutter_libs` from pubspec and
   delete the `applyWorkaroundToOpenSqlCipherOnOldAndroidVersions()` call.

## Rollback strategy

Existing on-disk databases are SQLCipher format. If the new substrate fails
to open them, the user sees a `StateError` from the existing
`cipher_version` assertion (the database would otherwise have opened
unencrypted — that's the whole point of the assertion). Recovery: revert
the release; the previous build can re-open the same on-disk file because
the format hasn't changed. **No data loss risk under Option A.**

If we ever pursue Option C (drop encryption), rollback is impossible —
plaintext writes can't be re-encrypted into an existing user's DB. That
amplifies the pre-execution review burden.

## Trigger conditions for execution

- Any Flutter SDK bump that breaks the build because of a transitive `sqlcipher_flutter_libs` constraint (the canonical "we have to do this now" signal).
- A published CVE in SQLCipher we'd want a patched binary for.
- A green-light decision on whether physical-device threat model still
  applies (post-launch, more real data → answer is "yes, keep encryption").

## Out of scope

- Re-evaluating the encryption-key derivation (`_getDatabaseEncryptionKey`).
  The current scheme reads from `flutter_secure_storage` and generates
  fresh on first run — fine, doesn't change with substrate.
- The `dart_test.yaml` 30s budget (BUT-775) — separate concern.

## Bump history

| Date | Decision |
| ---- | -------- |
| 2026-05-06 | ADR drafted (Option A tentative). Execution deferred pending one of the trigger conditions above. |
