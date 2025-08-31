# 🧪 Production Testing Suite - Butlery App

## Overview
This directory contains all production testing materials for systematically testing the Butlery app and identifying bugs.

## Quick Start

### 1. Run the test script
```bash
./run_production_tests.sh
```

### 2. Follow test scenarios
Start with `scenarios/TS-001_authentication.md` and work through each scenario systematically.

### 3. Document bugs
Any bugs found should be immediately documented in `/docs/testing/BUG_TRACKER.md`

### 4. Update feature status
After testing each feature, update `/docs/testing/FEATURE_STATUS.md`

## Directory Structure

```
test/production/
├── README.md                    # This file
├── run_production_tests.sh      # Test runner script
├── scenarios/                   # Test scenarios
│   ├── test_scenario_template.md
│   └── TS-001_authentication.md
├── screenshots/                 # Test screenshots
├── test_data/                  # Sample data for testing
└── logs/                       # Test execution logs
```

## Documentation

### Main Testing Documents
- **[Production Testing Guide](../../docs/testing/PRODUCTION_TESTING_GUIDE.md)** - Complete testing methodology
- **[Bug Tracker](../../docs/testing/BUG_TRACKER.md)** - Central bug repository
- **[Feature Status](../../docs/testing/FEATURE_STATUS.md)** - Feature completion matrix
- **[Test Results](../../docs/testing/PRODUCTION_TEST_RESULTS.md)** - Daily test progress
- **[Fix Roadmap](../../docs/testing/FIX_ROADMAP.md)** - Prioritized fix plan

## Testing Priority

### Phase 1: Core Features (Days 1-2)
1. **Authentication** (TS-001) ✅ Scenario created
2. Recipe CRUD
3. Import features

### Phase 2: Social Features (Days 3-4)
4. Friends system
5. Groups
6. Sharing
7. Comments & Ratings

### Phase 3: Collaborative Features (Days 5-6)
8. Shopping lists
9. Menu planning
10. Real-time features

### Phase 4: Communication (Day 7)
11. Messaging
12. Notifications

## How to Test

### For Each Feature:
1. **Read the test scenario** in `scenarios/`
2. **Run the app** using `cmd.exe /c "flutter run"`
3. **Execute each test case** systematically
4. **Document results** in the scenario file
5. **Log any bugs** in Bug Tracker with:
   - Clear reproduction steps
   - Screenshots (save to `screenshots/`)
   - Error logs (save to `logs/`)
6. **Update Feature Status** document

### Bug Severity Guidelines

- **🔴 Critical**: App crashes, data loss, security issues
- **🟠 High**: Major feature broken, no workaround
- **🟡 Medium**: Feature partially works, has workaround
- **🟢 Low**: Minor issues, cosmetic problems

## Test Data

### Test Accounts
```
Email: testuser@test.com
Password: Test123!@#

Email: testuser2@test.com
Password: Test123!@#
```

### Sample Recipe URLs for Import Testing
```
https://www.allrecipes.com/[recipe]
https://www.foodnetwork.com/recipes/[recipe]
https://www.bbcgoodfood.com/recipes/[recipe]
https://www.seriouseats.com/recipes/[recipe]
https://tasty.co/recipe/[recipe]
```

## Commands Reference

### Run the app
```bash
cmd.exe /c "flutter run"
```

### Run with verbose logging
```bash
cmd.exe /c "flutter run -v"
```

### Check for issues
```bash
cmd.exe /c "flutter analyze"
```

### Run unit tests
```bash
cmd.exe /c "flutter test"
```

### Build for testing
```bash
cmd.exe /c "flutter build apk --debug"
```

## Tips for Effective Testing

1. **Clear app data** between test sessions for clean state
2. **Test on multiple devices** if possible
3. **Test with different network conditions** (WiFi, cellular, offline)
4. **Take screenshots** of any UI issues
5. **Save error logs** for debugging
6. **Test both happy path and edge cases**
7. **Verify data persistence** after app restart
8. **Check for memory leaks** in long sessions
9. **Test permissions** and security boundaries
10. **Document everything** immediately

## Progress Tracking

Update daily in the tracking documents:
- Bugs found today: `/docs/testing/BUG_TRACKER.md`
- Features tested: `/docs/testing/FEATURE_STATUS.md`
- Test results: `/docs/testing/PRODUCTION_TEST_RESULTS.md`

## Contact

For questions about testing:
- Review `/docs/testing/PRODUCTION_TESTING_GUIDE.md`
- Check existing bugs in Bug Tracker
- Document new findings immediately

---

**Remember**: The goal is to find and document ALL bugs and non-working features so they can be fixed before production release.