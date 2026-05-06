# GitHub Actions: SHA pinning policy

**Status:** active (BUT-790).
**Last reviewed:** 2026-05-06.

## Why

Tag references like `subosito/flutter-action@v2` re-resolve at every run to
whatever commit currently lives at that tag. A maintainer (or attacker who
gains push access) can force-update a tag to point at a malicious commit,
and CI will silently use it the next time it runs. Real-world precedent:
the `tj-actions/changed-files` supply-chain attack in 2024 used exactly
this technique.

Pinning to a 40-char commit SHA freezes the action to the bytes we audited.

## Scope

This policy applies to the **high-blast-radius** actions only. Each one runs
with sufficient privileges to inject malware, fake test results, or exfiltrate
secrets:

| Action | Blast radius |
| --- | --- |
| `subosito/flutter-action` | Installs the Flutter SDK — could swap binaries. |
| `aquasecurity/trivy-action` | Security scanner — could fake green results. |
| `codecov/codecov-action` | Uploads coverage — could exfiltrate file contents. |
| `trufflesecurity/trufflehog` | Secret scanner — runs on the full checkout. |

Out of scope:

- `actions/*` (official GitHub-org actions) — tag-pinned. Trust boundary is
  GitHub itself.
- `google/osv-scanner-action`, `github/codeql-action`, `actions/setup-node`,
  `actions/setup-java` — pinned to major tag, mid-trust.

The guard `tools/check_action_pinning.sh` enforces the high-blast-radius set.

## Bump cadence

Quarterly review on the first business day of Jan / Apr / Jul / Oct.

For each action in scope:

1. Check the project's release notes since the pinned version.
2. Resolve the new tag's dereferenced SHA:

   ```bash
   git ls-remote https://github.com/<owner>/<repo>.git "refs/tags/<tag>^{}"
   ```

3. Update the `uses: <owner>/<repo>@<sha> # <tag>` line in every workflow.
4. Update this doc's "Last reviewed" date.

## Format

Every pinned reference uses this exact pattern so the guard regex stays simple:

```yaml
uses: subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2 # v2.23.0 — BUT-790 SHA-pin
```

- 40 lowercase hex chars before the comment.
- Tag (with `v` prefix) for human readability after the `#`.
- BUT-790 reference makes the rationale traceable.

## Current pins (2026-05-06)

| Action | SHA | Tag |
| --- | --- | --- |
| `subosito/flutter-action` | `1a449444c387b1966244ae4d4f8c696479add0b2` | v2.23.0 |
| `aquasecurity/trivy-action` | `ed142fd0673e97e23eac54620cfb913e5ce36c25` | v0.36.0 |
| `codecov/codecov-action` | `b9fd7d16f6d7d1b5d2bec1a2887e65ceed900238` | v4.6.0 |
| `trufflesecurity/trufflehog` | `17456f8c7d042d8c82c9a8ca9e937231f9f42e26` | v3.95.2 |
