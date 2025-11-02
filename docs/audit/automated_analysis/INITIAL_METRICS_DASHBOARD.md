# Butlery Initial Metrics Dashboard

**Updated**: Analyzer rerun on current session (flutter analyze clean)

---

## Codebase Snapshot
- Total Dart files: 793
- Test files: 450 (˜56.7% test/code ratio)
- Estimated lines of Dart: ~102k
- Flutter / Dart versions: 3.35.1 / 3.9.0

## Static Analysis Status
| Metric | Value | Notes |
|--------|-------|-------|
| Total analyzer issues | 0 | Latest `flutter analyze` run clean |
| Critical errors | 0 | Previous realtime mismatch resolved |
| Warnings / info | 0 | No outstanding hints |

**Analyzer Update**: Historical Phase 0 runs surfaced 84 realtime module errors. Those call-site mismatches have been fixed; retain regression watch on realtime modules during future audits.

## Test Execution Snapshot
- Latest coverage run: failed immediately (UTF-8 decode error in `test/views/social/group_content_feed_view_test.dart`).
- Next steps: fix encoding or remove problematic byte-order mark; rerun `flutter test --coverage`.

## File Size Overview
- Files within =500-line guideline: 745 (˜93.9%).
- Files exceeding guideline: 48 (top offenders remain `recipe_image_manager.dart`, `editable_image_widget.dart`, `recipe_form_viewmodel.dart`).

## Coverage Pointers (unchanged)
- Services: ~96%
- ViewModels: ~87%
- Repositories: ~47%
- Views: ~26%
- Integration tests: 13 (target 30)

## Open Technical Risks (from Phase 0 instruments)
- 34 hardcoded secrets remain in repo (P0).
- 34 critical security vulnerabilities flagged by code intelligence.
- 58 suspected memory leaks from automated scanning.
- 729 performance findings still pending manual triage.
- UTF-8 coverage failure blocks fresh coverage numbers.

## Recommended Immediate Actions
1. Remove/rotate exposed secrets and reconfigure environment variables.
2. Investigate UTF-8 decode failure and rerun coverage.
3. Prioritize remediation of high-risk security findings.

---

_Note_: This dashboard supersedes the earlier Phase 0 export that listed 98 analyzer issues and 84 compilation failures. Use this document as the current baseline for ongoing audit phases.
