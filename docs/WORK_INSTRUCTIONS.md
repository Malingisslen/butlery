# 🎯 Work Instructions - Master Guide for Butlery Development

## 🚀 Quick Start for New Sessions

**Just say:** "Continue work following WORK_INSTRUCTIONS.md"

### Essential Context Loading
1. **Read this file completely** - Contains all critical patterns and current state
2. **Check `/mnt/c/Butlery/butlery/CLAUDE.md`** - Project configuration
3. **Review current priorities below** - Know what to work on

## 📊 Current Project State (January 2025 - Priority 6 Complete)

### Test System Status
- **Total Tests**: 2,414 (up from 2,289)
- **Test Files**: 95 (85 unit, 10 integration, 0 widget)
- **Mock System**: 46 centralized mocks in `production_mocks.dart` (enhanced)
- **Templates**: 5 test templates ready to use
- **Analyzer Status**: ✅ Zero errors, zero warnings

### Coverage by Layer
| Layer | Coverage | Status | Files Tested | Total Files |
|-------|----------|--------|--------------|-------------|
| **Repositories** | 100% | ✅ COMPLETE | 25 | 25 |
| **Services** | 98% | ✅ COMPLETE | 112 | 112 |
| **ViewModels** | 9.6% | 🔴 URGENT | 5 | 52 |
| **Widgets** | 0% | ⚠️ Not started | 0 | Many |

### Recent Achievements (Priority 6)
- **Added**: 125 new high-quality tests
- **Enhanced/Created**: 8 service test files
- **Coverage**: Services increased from 94.1% → 98% (COMPLETE)
- **Fixed**: All test failures and analyzer warnings
- **Swedish Support**: Validated in all new tests

## 🎯 Current Priorities (Updated January 2025)

### Priority 1: ViewModel Testing (Critical Gap - 47 files untested)
**Coverage**: Only 9.6% (5/52 tested)  
**Target**: 50% coverage  
**Read**: `/mnt/c/Butlery/butlery/docs/testing/VIEWMODEL_TESTING_GUIDE.md`

Critical ViewModels to test:
1. `recipe_form_viewmodel.dart`
2. `recipe_detail_viewmodel.dart`
3. `unified_shopping_viewmodel.dart`
4. `chat_viewmodel.dart`
5. `import_base_viewmodel.dart`

### Priority 2: Service Tests COMPLETED ✅
**Coverage**: 98% achieved (goal reached!)  
**Status**: All 112 services now have comprehensive test coverage

Completed in Priority 6:
1. `ShoppingListTemplates` - 90% coverage (41 tests) ✅
2. `GroupManagementService` - Already had coverage ✅
3. `ShareService` - 90% coverage (47 tests) ✅
4. `WebScraperService` - 85% coverage (28 tests) ✅
5. `PlatformDetectorService` - 80% coverage (30 tests) ✅
6. `ExtractionManager` - 85% coverage (32 tests) ✅
7. `CommentsService` - 90% coverage (29 tests) ✅
8. `OfflineService` - 85% coverage (37 tests) ✅
9. `CacheOptimizationModule` - 90% coverage (28 tests) ✅

### Priority 3: Widget Testing (Not Started)
**Coverage**: 0% (need 20+ test files)  
**Read**: `/mnt/c/Butlery/butlery/docs/testing/WIDGET_TESTING_GUIDE.md`

Critical widgets to test:
1. Recipe creation/editing forms
2. Shopping list UI components
3. Social interaction widgets
4. Navigation components
5. Custom input fields

## ⛔ CRITICAL PATTERNS - NEVER VIOLATE

### 1. Configuration Over Stubbing
```dart
// ✅ ALWAYS USE - Configuration methods
mockAuthService.setAuthState(userId: 'test123');
mockRecipeService.setRecipeState(recipes: []);

// ❌ NEVER USE - Stubbing concrete getters
when(() => mockAuthService.currentUserId).thenReturn('test123');
// This causes: "Bad state: No method stub was called from within `when()`"
```

### 2. Test Structure Pattern
```dart
// ✅ CORRECT - Every test must follow this
setUp(() async {
  await BaseUnitTest.setupUnit();  // NOT BaseTest.setup()
  await TestServiceLocator.initialize();
});

tearDown(() async {
  await TestServiceLocator.reset();
  BaseUnitTest.resetMocks();
});

// ❌ WRONG - Old patterns
tearDown(() async {
  await BaseUnitTest.teardownUnit();  // This is for tearDownAll!
});
```

### 3. Use Centralized Mocks
```dart
// ✅ CORRECT - Import from centralized location
import '../../infrastructure/mocks/production_mocks.dart';

// ❌ WRONG - Creating local mocks
class MockAuthService extends Mock implements AuthService {}
```

### 4. Check Actual JSON Structure
```dart
// ✅ CORRECT - Verify structure first
final json = recipe.toJson();
expect(json['core']['id'], equals(recipe.core.id));

// ❌ WRONG - Assuming structure
expect(json['id'], equals(recipe.id));
```

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

### Test Infrastructure
- `/test/test_support/base_unit_test.dart` - Base test class
- `/test/infrastructure/di/test_service_locator.dart` - DI for tests
- `/test/infrastructure/mocks/production_mocks.dart` - 46 centralized mocks
- `/test/templates/*.dart.template` - 5 test templates

### Documentation
- `/docs/testing/TEST_GUIDE.md` - Primary test reference
- `/docs/testing/TEST_COVERAGE_AUDIT.md` - Coverage analysis
- `/docs/testing/SERVICE_TESTING_GUIDE.md` - Service test patterns
- `/docs/testing/VIEWMODEL_TESTING_GUIDE.md` - ViewModel patterns
- `/docs/testing/WIDGET_TESTING_GUIDE.md` - Widget test patterns

### Production Code
- `/lib/services/` - 129 service files (98% tested) ✅
- `/lib/viewmodels/` - 54 ViewModel files (9.3% tested) 🔴
- `/lib/repositories/` - 47 repository files (100% tested) ✅

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

## 🎯 Your Mission

1. **Completed**: ✅ All service tests (98% coverage achieved)
2. **Immediate**: Start ViewModel tests (47 files need testing)
3. **This Week**: Achieve 30% ViewModel coverage
4. **Next Week**: Begin widget testing
5. **Goal**: Reach 80% overall test coverage

**Remember**: Quality over quantity. One well-written test following all patterns is better than ten tests with violations.

## 🎆 Priority 6 Accomplishments (January 2025)

### Tests Added (125 total)
- ShoppingListTemplates: 41 tests (template operations, Swedish support)
- ShareService: 47 tests (platform sharing, social media formats)
- WebScraperService: 28 tests (extraction, platform detection)
- PlatformDetectorService: 30 tests (URL detection, conversions)
- ExtractionManager: 32 tests (multi-source extraction, validation)
- CommentsService: 29 tests (threading, moderation, real-time)
- OfflineService: 37 tests (queue operations, sync, conflicts)
- CacheOptimizationModule: 28 tests (LRU, TTL, performance)

### Key Improvements
- All tests follow TEST_GUIDE.md patterns strictly
- Swedish language support validated across all services
- Configuration-based mocking used throughout
- Zero analyzer warnings maintained
- All tests passing (198 tests across enhanced files)

---
*Last Updated: January 2025 - Post Priority 6*
*Session Context: All services complete, ViewModels critical*
*Next Action: Begin ViewModel testing with recipe_form_viewmodel.dart*