# Sprint Backlog

## Sprint: route butlery://import deep links to Smart Import — 2026-06-28

Single clean Tier-A bug fix (deep-link guard logic; acquisition funnel). Dart-only.

### Agent A: deep-link host guard (direct) — Stakeholders: Growth/ASO, Information Architect
- [x] **A1. Whitelist `import` in the custom-scheme host guard** `[Tier A]` (BUT-1411)
  - Step 0: CONFIRMED. The web share target builds `butlery://import?url=<enc>` (deep_link_handler.dart:60,68),
    Uri.parse → host='import'. The host guard (:114-118) returns early for any butlery:// host except
    butlery.app — so host='import' is dropped BEFORE the import branch (:140-142), which already handles
    `host=='import'` but is unreachable. Net: shared-URL deep links (the web Share-Target acquisition
    loop) are silently dropped. `_handleImportLink` (:312) routes to Routes.smartImport with the url arg.
  - Files: `lib/core/bootstrap/handlers/deep_link_handler.dart` + new handler test.
  - Acceptance: the guard recognises `import` (extract a testable static `isBlockedCustomSchemeHost`
    predicate: blocks unknown butlery:// hosts, allows butlery.app + import + host-less + non-butlery
    schemes) · butlery://import?url=... now reaches the import branch → Navigator pushNamed smartImport
    with the url arg (the branch already does this; guard was the sole blocker) · a unit test pins the
    predicate (import allowed, evil-host blocked, butlery.app allowed) · analyze clean.

### Post-Sprint Steps
- [ ] dart analyze + run handler test · Phase 2.7 verifier · code-reviewer + testing-specialist · commit · push · Done

---

## Recent shipped (this session): BUT-1412 (31a184e09), BUT-1435 (c89a6f488), BUT-1405 (2a041d5b8), BUT-1407 (ac9ffb80d), BUT-1425 (2293bf051), BUT-1401 (077212635), BUT-1428 (412efb5ed), BUT-1406+1436 (0b42c9280), BUT-1414 (39bffed2c), BUT-1415 (3c83cbb10), BUT-1397+1394 (fac80964e), BUT-1390/1391/1393 (08e04be29), BUT-1386 (07fa820d0, In Review).
