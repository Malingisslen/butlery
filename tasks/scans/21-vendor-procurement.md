# Scan — Role 21: Vendor / Procurement Manager

Lens: dependency health, vendor lock-in, version pinning, LLM/model version
management, supply-chain risk. Two passes. Verified against live manifests
(`pubspec.yaml`, `functions/package.json`, `firebase.json`) and
`flutter pub outdated` (run 2026-06-27).

---

## NEW FINDINGS

### N1 — Deploy-gate npm audit only blocks on CRITICAL, lets HIGH CVEs ship
- **Type:** dependency / supply-chain
- **Lane:** autonomous, backend, security, tech-debt
- **Where:** `firebase.json` line 6 — predeploy step
  `npm --prefix functions audit --audit-level=critical`
- **Finding:** The Cloud Functions deploy gate fails only on **critical**
  advisories. A HIGH-severity CVE in any function dependency (or transitive,
  e.g. `protobufjs`, `@google-cloud/vertexai`'s tree) passes the gate silently
  and ships to production. For a backend that fronts Vertex AI billing and
  holds the rate-limit / kill-switch logic, HIGH is well inside the threat
  model. Industry-standard CI gate is `--audit-level=high`.
- **Action:** Lower the deploy-gate threshold to `--audit-level=high`. If a
  known unfixable HIGH transitive forces noise, suppress that specific advisory
  rather than blanket-raising the floor back to critical.
- **Verified:** file read; not in `_scan_dedup_titles.txt`, `linear-tracker.json`
  (BUT-434/435 are pub-side), `accepted-deviations.md`, or
  `dependency_watch_list.md`. Genuinely new.

---

## ALREADY-TRACKED (verified present, NOT re-filed)

- **sqlcipher_flutter_libs `0.6.8` → `0.7.0+eol`** — `flutter pub outdated`
  now publishes the upgrade target with an explicit **`+eol`** (end-of-life)
  build suffix. The substrate migration is already tracked: dedup line 13
  ("Execute sqlcipher → sqlite3 migration per ADR-002, BUT-789 follow-on",
  deferred). The `+eol` marker raises urgency but the action is the same
  ticket — noted here so the migration owner knows upstream now flags EOL.
- **Firebase suite minor drift** (firebase_core 4.7→4.11, auth 6.4→6.5,
  cloud_firestore 6.3→6.6, messaging 16.2→16.4, etc.) — covered by **BUT-1367**
  (Refresh Firebase suite + re-test stale iOS pins, IN-PROGRESS).
- **device_info_plus / connectivity_plus pins** (12.3 / 7.0 held; 13.x / 7.2
  available) — deliberate pins documented in `pubspec.yaml` + `dependabot.yml`
  (speculative iOS-26 API gambit); re-test owned by BUT-1367.
- **build_runner 2.7.1 → 2.15.0 / drift 2.29 → 2.34** — held in lockstep;
  covered by dedup line 12 (build_resolvers/build_runner_core migration) and
  pubspec BUT-820/BUT-554 notes.
- **app_links 6.4 → 7.x major** — Dependabot ignores majors by policy; pin
  origin is the BUT-434 receive_intent replacement (tracker). No action.
- **Algolia vendor lock-in / credentials via `String.fromEnvironment`** —
  `search_module.dart` 162-163, `algolia_search_repository.dart`. Standing
  dossier watch-item (Evidence cited in ROLE_RESPONSIBILITY_MAP §21); SDK is
  migration-ready (pubspec comment: Meilisearch/Typesense). Not new.
- **LLM model pin `gemini-2.5-flash-lite`** — pinned + runbook'd
  (`llm-versions.md`, `gemini-client.ts` 815). Pricing TODO(BUT-1187) is
  cost-telemetry-only and already ticketed. Pin discipline is healthy.
- **Pre-1.0 caret deps** (intl, rxdart, html, firebase_app_check,
  firebase_performance) and **dormancy watch** (timeago, html_unescape) —
  all in `dependency_watch_list.md`, quarterly cadence. Not new.

## Coverage notes
- **Dependabot coverage is complete**: pub + npm + github-actions ecosystems
  all configured (`.github/dependabot.yml`), weekly, grouped, majors ignored
  by design. No coverage gap to file.
- **No known-CVE direct dep** found outside the audited Firebase/plus-plugin
  pins already documented. functions deps pinned exact (vertexai 1.12.0,
  firebase-admin 13.8.0, firebase-functions 7.2.5) with `protobufjs`/
  `fast-xml-builder` overrides for transitive hardening — good hygiene.

---

COVERAGE: pubspec.yaml, functions/package.json, firebase.json,
gemini-client.ts, rate_limiter.ts (incl. recently-modified files),
search_module.dart, algolia_search_repository.dart, llm-versions.md,
dependabot.yml, `flutter pub outdated`. 1 NEW finding (N1: npm audit deploy
gate at critical-only, should be high). All other version drift / lock-in /
pin items map to existing tickets (BUT-1367, BUT-789, BUT-820, BUT-434) or
standing watch-lists; nothing else new.
