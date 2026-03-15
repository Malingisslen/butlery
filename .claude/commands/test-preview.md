# Manual Testing via Chrome MCP

Continue manual testing of the Butlery app using Chrome MCP.

## Setup

1. Read the manual test log: `docs/testing/MANUAL_TEST_LOG.md`
2. Note the current progress (status line at top), open bugs, and which phases have pending tests
3. Ensure the app is running in Chrome (`flutter run -d chrome`) before testing

## Testing Priority

Work through tests in this priority order:

### Priority 1: Fix Open Bugs
Check the **Open Bugs** section in the test log:
- Try to reproduce each open bug via Chrome MCP
- If you can fix it, fix it, run `flutter analyze`, and verify the fix via Chrome MCP
- Update the bug entry in `MANUAL_TEST_LOG.md` with fix details and FIXED status
- If no open bugs exist, skip to Priority 2

### Priority 2: Resume Pending Tests
Look at the test summary table and find the first phase with incomplete tests, prioritizing by:
1. P0 phases first, then P1, P2, P3
2. Within same priority, earlier phase number first

For each pending test:
1. Execute the test steps via Chrome MCP
2. Take screenshots to verify UI state
3. Mark the test as Pass/Fail in the log
4. If a test fails, file a new bug in the Bug Tracker section with:
   - Bug ID (next sequential BUG-XXX)
   - Error details, platform, trigger steps
   - Root cause analysis if possible
   - Severity (Critical/High/Medium/Low)

## Test Execution Rules

- **User A**: malin.gisslen1@gmail.com / Test1234
- **User B** (multi-user/social tests): test.testsson2@gmail.com / TestPass123! — log out User A first, then log in as User B to verify
- **After each bug fix**: Run `flutter analyze` before marking as fixed
- **Known Flutter Web limitations**: CanvasKit hit-testing issues with some buttons — document when automation fails but real clicks would work
- **Auto-verify**: Screenshot and verify after code changes

## Updating the Test Log

After each test or bug fix, update `docs/testing/MANUAL_TEST_LOG.md`:
- Update the test status table (Pending → Pass/Fail)
- Update the summary counts at the top
- Add session notes at the bottom with today's date
- For bug fixes: move bug from Open to Fixed, add fix details

## Session Note Format

```markdown
**Session XX - YYYY-MM-DD (via Chrome MCP):**
- **Test results:**
  - TEST-ID (description): PASS/FAIL - details
- **Bugs fixed:**
  - BUG-XXX: description of fix
- **Updated Progress:** X/N tests (Y passed, Z failed), **N open bugs**
```

Start by reading the full test log, then report what you plan to test this session before beginning.
