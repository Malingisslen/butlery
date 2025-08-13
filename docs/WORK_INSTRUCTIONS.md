# 🎯 Work Instructions for Test System Development

## Quick Start for New Sessions
1. Read **CLAUDE.md** for project configuration
2. Read **TEST_ARCHITECTURE.md** sections:
   - "Current Test System Status" 
   - "Key Implementation Rules"
   - "Critical Lessons Learned"
3. Check **TEST_GUIDE.md** "Current Status" section

## Core Working Principles

### 🧠 Ultrathink Mode
Always use deep analytical thinking for all decisions. Think through problems completely before implementing.

### ✅ Development Cycle
For every change:
1. **Verify** production code structure first
2. **Implement** following gold standard patterns  
3. **Analyze** - Run `cmd.exe /c "flutter analyze"`
4. **Test** - Run `cmd.exe /c "flutter test"`
5. **Document** if patterns change

### 🔍 Never Assume
- Always check production JSON structure
- Always verify method signatures
- Always check existing mock implementations
- Always read actual serialization code

## ⛔ CRITICAL: Never Use These Patterns
**These patterns are COMPLETELY BANNED from our codebase:**

### 1. **NEVER stub concrete methods/getters**
```dart
// ⛔ BANNED - Will cause "Bad state: No method stub was called from within `when()`"
when(() => mockService.currentUserId).thenReturn('test123');
when(() => mockService.recipes).thenReturn([]);
when(() => mockService.isAuthenticated).thenReturn(true);
when(() => mockService.addListener(any())).thenReturn(null);
when(() => mockService.removeListener(any())).thenReturn(null);

// ✅ ONLY ALLOWED - Configuration methods
mockService.setAuthState(userId: 'test123');
mockService.setRecipeState(recipes: []);
```

### 2. **NEVER use TestContext**
```dart
// ⛔ BANNED - TestContext has been removed
TestContext.arrange(() => {});

// ✅ ONLY ALLOWED - Simple AAA comments
// Arrange
// Act
// Assert
```

### 3. **NEVER create local mocks**
```dart
// ⛔ BANNED - Creates duplication and inconsistency
class MockAuthService extends Mock implements AuthService {}

// ✅ ONLY ALLOWED - Use centralized mocks
import 'package:test/infrastructure/mocks/production_mocks.dart';
final mock = MockAuthService(); // From production_mocks.dart
```

### 4. **NEVER assume JSON structure**
```dart
// ⛔ BANNED - Assuming flat structure
expect(json['id'], equals(recipe.id));

// ✅ ONLY ALLOWED - Verify actual structure first
expect(json['core']['id'], equals(recipe.core.id));
```

### 5. **NEVER use BaseTest.setup()**
```dart
// ⛔ BANNED - Old pattern
await BaseTest.setup();

// ✅ ONLY ALLOWED - Standardized pattern
await BaseUnitTest.setupUnit();
```

**Breaking these rules = immediate test failure. No exceptions.**
**If you see these patterns, STOP and fix them immediately.**

### 🏗️ Gold Standard Rules
1. **Configuration over Stubbing**
   ```dart
   // ✅ CORRECT
   mock.setAuthState(userId: 'test123');
   
   // ❌ WRONG  
   when(() => mock.currentUserId).thenReturn('test123');
   ```

2. **Centralized Mocks**
   - Check `production_mocks.dart` first
   - Never duplicate mock definitions
   - If mock exists in 2+ files → centralize it

3. **AAA Pattern**
   ```dart
   // Arrange
   // Act  
   // Assert
   ```

4. **Service Locator Pattern**
   ```dart
   final service = ServiceLocator.get<ServiceType>();
   ```

### 🐛 Debugging Failing Tests
When tests fail, check in order:
1. Is it a stubbing violation? → Use configuration method
2. Is async method not stubbed? → Add `.thenAnswer((_) async => ...)`
3. Is JSON structure wrong? → Check production `toJson()`/`fromJson()`
4. Is mock missing? → Check if it needs to be registered in TestServiceLocator

### 📊 Current Status & Priorities
**Repository Layer: 100% Complete ✅**
- All 24 repositories tested and all tests passing

**Next Priorities:**
1. **Services (27.9% coverage)** - Critical gap, focus on core services
2. **ViewModels (9.3% coverage)** - Urgent attention needed
See **TEST_GUIDE.md** "Next Priority" section for specific tasks.

### 🔧 Key Commands
```bash
# Windows Flutter via WSL
cmd.exe /c "flutter analyze"
cmd.exe /c "flutter test"
cmd.exe /c "flutter test test/unit/services/specific_test.dart"
```

### 📚 Documentation References
- **TEST_ARCHITECTURE.md** - Complete test system design
- **TEST_GUIDE.md** - Quick reference and patterns
- **CLAUDE.md** - Project configuration and rules
- **production_mocks.dart** - Available centralized mocks

## One-Line Prompt
When continuing work, just say:
> "Continue work following WORK_INSTRUCTIONS.md"

This ensures consistent, high-quality test development following all established patterns.