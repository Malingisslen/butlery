# 🎯 Work Instructions - Current Session Guide

## 🚀 Quick Start for New Sessions

**Just say:** "Continue testing ViewModels starting with recipe_form_viewmodel.dart"

> **📊 For current coverage and priorities: [/docs/testing/TESTING_DASHBOARD.md](/docs/testing/TESTING_DASHBOARD.md)**  
> **⚡ For test patterns: [/docs/testing/TEST_PATTERNS_QUICK_REFERENCE.md](/docs/testing/TEST_PATTERNS_QUICK_REFERENCE.md)**

## 📊 Current Session State (January 2025)

### What's Complete ✅
- **Repositories**: 100% coverage (25/25 tested)
- **Services**: 93.7% coverage (118/126 tested) 
- **Documentation**: Consolidated into TESTING_DASHBOARD.md

### What's Next 🎯
- **ViewModels**: Only 9.6% coverage (5/52 tested) - **CRITICAL GAP**
- Start with: `recipe_form_viewmodel.dart`
- Use template: `/test/templates/viewmodel_test_template.dart.template`

### Recent Achievements (This Session)
- Created TESTING_DASHBOARD.md as single source of truth
- Created TEST_PATTERNS_QUICK_REFERENCE.md for essential patterns
- Removed documentation duplication across 8 files
- Clarified actual coverage: Services 93.7%, not conflicting 31-98%

## ⛔ CRITICAL PATTERNS

See [TEST_PATTERNS_QUICK_REFERENCE.md](/docs/testing/TEST_PATTERNS_QUICK_REFERENCE.md) for all patterns.

**The Golden Rule**: NEVER stub concrete getters - use configuration methods!

## 🛠️ Development Workflow

### For Every Task:
1. **Think** - Use ultrathink to analyze the problem deeply
2. **Verify** - Check existing code structure before changes
3. **Implement** - Follow established patterns exactly
4. **Test** - Run tests to verify
5. **Document** - Update docs if patterns change

### Commands You'll Use:
```bash
# ALWAYS use Windows Flutter in WSL
cmd.exe /c "flutter analyze"                    # Check for issues
cmd.exe /c "flutter test"                       # Run all tests
cmd.exe /c "flutter test test/unit/services/"   # Run service tests
cmd.exe /c "flutter test path/to/specific_test.dart"  # Run one test
```

## 📁 Key File Locations

### Essential References
- **Coverage & Priorities**: `/docs/testing/TESTING_DASHBOARD.md`
- **Pattern Quick Ref**: `/docs/testing/TEST_PATTERNS_QUICK_REFERENCE.md`
- **Templates**: `/test/templates/viewmodel_test_template.dart.template`
- **Mocks**: `/test/infrastructure/mocks/production_mocks.dart` (46 mocks)

## 🔍 Debugging Test Failures

When a test fails, check in this order:

1. **Stubbing violation?**
   - Error: "Bad state: No method stub was called from within `when()`"
   - Fix: Use configuration method instead

2. **Async method not stubbed?**
   - Error: "Null is not a subtype of Future"
   - Fix: Add `.thenAnswer((_) async => result)`

3. **JSON structure wrong?**
   - Error: Assertion failures on JSON fields
   - Fix: Check production `toJson()`/`fromJson()` methods

4. **Mock not registered?**
   - Error: "No service registered for type"
   - Fix: Register in TestServiceLocator

5. **Firebase/Integration issue?**
   - Error: Platform exceptions in integration tests
   - Fix: These are known issues, focus on unit tests

## 🎓 Key Lessons Learned

1. **Never stub concrete implementations** - Always use configuration methods
2. **Check production code first** - Don't assume structure or behavior
3. **Centralize everything** - Mocks, patterns, fallback values
4. **Test in layers** - Repository → Service → ViewModel → Widget
5. **Fix systematically** - One pattern fix can resolve many tests

## 📋 Test Creation Checklist

When creating a new test:
- [ ] Use appropriate template from `/test/templates/`
- [ ] Import from `test_support/base_unit_test.dart`
- [ ] Use `BaseUnitTest.setupUnit()` in setUp
- [ ] Use configuration methods for mocks
- [ ] Include proper tearDown with reset
- [ ] Follow AAA pattern with comments
- [ ] Verify against production code structure
- [ ] Run analyzer before committing

## 🚦 Success Criteria

You're successful when:
- ✅ All tests pass (0 failures)
- ✅ Flutter analyzer shows 0 issues
- ✅ Coverage increases after each session
- ✅ No duplicate mocks created
- ✅ All patterns consistently followed

## 💡 Pro Tips

1. **Batch similar fixes** - If one test has a pattern issue, others likely do too
2. **Read error messages carefully** - They usually point to the exact problem
3. **Use test templates** - They have all the correct patterns built in
4. **Check existing tests** - They show working patterns
5. **Document pattern changes** - If you find a better way, update the guides

---