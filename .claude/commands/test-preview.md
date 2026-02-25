# Manual Testing via Preview

Continue manual testing of the Butlery app using the embedded browser preview.

## Setup

1. Read the manual test log: `docs/testing/MANUAL_TEST_LOG.md`

## Testing Priority

Work through tests in this priority order:

### Priority 1: Fix Open Bugs
Check the **Open Bugs** section in the test log. Currently open bugs need investigation and fixing:
- Try to reproduce each open bug in the preview browser
- If you can fix it, fix it, run `flutter analyze`, and verify the fix in the preview
- Update the bug entry in `MANUAL_TEST_LOG.md` with fix details and FIXED status

### Priority 2: Resume Pending Tests (by phase order)
Look at the test summary table and find phases with incomplete tests. For each pending test:
1. Execute the test steps in the preview browser
2. Take screenshots to verify UI state
3. Mark the test as Pass/Fail in the log
4. If a test fails, file a new bug in the Bug Tracker section with:
   - Bug ID (next sequential BUG-XXX)
   - Error details, platform, trigger steps
   - Root cause analysis if possible
   - Severity (Critical/High/Medium/Low)

### Priority 3: Phase 17 Import Tagging Verification
This phase has 0/32 tests completed and verifies the automatic tagging pipeline accuracy.

## Test Execution Rules

- **User A**: malin.gisslen1@gmail.com / test123
- **User B** (E2E social tests, Phase 16): test.testsson2@gmail.com / TestPass123! — log out User A first, then log in as User B to verify
- **After each bug fix**: Run `flutter analyze` before marking as fixed
- **Known Flutter Web limitations**: CanvasKit hit-testing issues with some buttons — document when automation fails but real clicks would work
- **Auto-verify**: Screenshot and verify after your code changes

## Updating the Test Log

After each test or bug fix, update `docs/testing/MANUAL_TEST_LOG.md`:
- Update the test status table (Pending → Pass/Fail)
- Update the summary counts at the top
- Add session notes at the bottom with today's date
- For bug fixes: move bug from Open to Fixed, add fix details

## Session Note Format

```markdown
**Session XX - YYYY-MM-DD (description via Preview):**
- **Test results:**
  - TEST-ID (description): PASS/FAIL - details
- **Bugs fixed:**
  - BUG-XXX: description of fix
- **Updated Progress:** X/538 tests (Y passed, Z failed), **N open bugs**
```

Start by reading the full test log, then report what you plan to test this session before beginning.
