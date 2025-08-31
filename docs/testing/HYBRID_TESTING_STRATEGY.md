# Hybrid Testing Strategy - Executive Summary

> **📚 For implementation details, see: [FIREBASE_TESTING_GUIDE.md](./FIREBASE_TESTING_GUIDE.md)**  
> **📊 For current status, see: [TESTING_DASHBOARD.md](./TESTING_DASHBOARD.md)**

## The Strategy: 80/15/5 Distribution

### 🟢 Unit Tests (80% of tests)
- **Purpose**: Business logic, calculations, state management
- **Approach**: Mock at repository level, never mock Firebase directly
- **Speed**: Fast, no external dependencies
- **Location**: `/test/unit/`

### 🟡 Integration Tests (15% of tests)  
- **Purpose**: Firebase FieldValue operations, complex queries, batch operations
- **Approach**: Use Firebase emulator for realistic behavior
- **Speed**: Slower, requires emulator
- **Location**: `/test/integration/`

### 🔴 E2E Tests (5% of tests)
- **Purpose**: Critical user journeys, authentication flows
- **Approach**: Full application with real or emulated services
- **Speed**: Slowest, full environment
- **Location**: `/test/e2e/`

## Key Decision: Unit vs Integration

**Use Unit Tests when:**
- Testing business logic
- Testing data transformations  
- Testing service coordination
- Testing error handling

**Use Integration Tests when:**
- Using `FieldValue.serverTimestamp()`
- Using `FieldValue.increment()` 
- Using `FieldValue.arrayUnion()`
- Testing complex queries with dynamic fields
- Testing batch operations or transactions

## The Problem We Solve

Firebase FieldValue operations are server-side constructs that execute on Firebase servers, not in client code. They cannot be mocked with traditional frameworks, causing test failures.

## The Solution

1. **Unit tests mock at repository level** - Test business logic without Firebase
2. **Integration tests use Firebase emulator** - Test actual Firebase operations
3. **Clear separation of concerns** - Each test type has a specific purpose

## Quick Commands

```bash
# Unit tests only (fast)
cmd.exe /c "flutter test --exclude-tags integration"

# Integration tests (requires emulator)
firebase emulators:start
cmd.exe /c "flutter test --tags integration"

# All tests
cmd.exe /c "flutter test"
```

## Benefits

- ✅ Fast feedback from unit tests
- ✅ Reliable Firebase operation testing
- ✅ Clear test organization
- ✅ No more flaky Firebase mocks
- ✅ Comprehensive coverage

---
*For detailed patterns, examples, and helper utilities, see [FIREBASE_TESTING_GUIDE.md](./FIREBASE_TESTING_GUIDE.md)*