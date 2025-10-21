# Claude Code Project Configuration

## Flutter Commands (Windows Environment)
**Environment**: Running Flutter directly on Windows via VS Code

**Examples:**
- Analysis: `flutter analyze`
- Run: `flutter run`
- **Clean Run**: `flutter_run_clean.bat` (filters system noise, to be created if needed)
- **Tests**: `flutter test test/unit/file_test.dart` (use forward slashes for consistency)

**PATH RULES:**
- **ALWAYS** use forward slashes in test paths: `test/unit/file_test.dart` ✅
- Backslashes work but forward slashes are preferred for consistency: `test\unit\file_test.dart` (works but avoid)
- **PREFERRED**: Use `./run_tests_safely.sh` script for batch testing

## Architecture & Standards
- **Pattern**: MVVM + Repository Pattern (Views → ViewModels → Services → Repositories → Firebase)
- **File Size Limit**: 500 lines max (use facade pattern for larger files)
- **Dependency Injection**: Modular DI system with domain-driven modules (see below)
- **Notifications**: Complete FCM system with development logging approach
- **Social Features**: 90% infrastructure implemented (social views and services exist, need verification)
- **Test Infrastructure**: See `/docs/testing/TESTING_DASHBOARD.md` for current status
- **Test Patterns**: See `/docs/testing/TEST_PATTERNS_QUICK_REFERENCE.md` for essential patterns
- **Code Quality**: Single Responsibility Principle enforced
- **Security**: Comprehensive permission validation system implemented:
  - PermissionValidationMixin for all Firebase repositories
  - Authorization checks on all CRUD operations
  - Audit logging for security events
  - Ownership validation and role-based access control
- **Type Safety**: Map-based data access replaced with proper model usage
- **Flutter Color Syntax**: Use `withValues(alpha: 0.8)` instead of deprecated `withOpacity(0.8)`
- **Data Source Architecture**: CRITICAL - ViewModels must connect to correct services:
  - Use `UserService.currentUserProfile` for complete user data (settings, avatar, social features)
  - Use `PermissionService.currentUser` only for basic auth/permission checks
  - **Never mix data sources** - leads to settings not persisting and UI inconsistencies

### Dependency Injection System
**Architecture**: Clean modular DI with GetIt service locator
- **5 Domain Modules**: Core, Content, Social, Messaging, Collaboration
- **Bootstrap Pattern**: ApplicationBootstrap orchestrates initialization
- **Service Access**: Use `ServiceLocator.get<T>()` for all service access
- **NO LEGACY CODE**: The old `sl<T>()` pattern has been completely removed

**Module Structure:**
```dart
// Import for service access
import 'package:butlery/core/providers/application_provider.dart';

// Get services using
final service = ServiceLocator.get<UnifiedRecipeService>();
```

**Domain Modules:**
1. **Core Module** (`lib/core/di/modules/core_module.dart`): Auth, Storage, Analytics
2. **Content Module** (`lib/core/di/modules/content_module.dart`): Recipes, Menus, Import
3. **Social Module** (`lib/core/di/modules/social_module.dart`): Friends, Sharing, Comments
4. **Messaging Module** (`lib/core/di/modules/messaging_module.dart`): Chat, Notifications
5. **Collaboration Module** (`lib/core/di/modules/collaboration_module.dart`): Realtime, Shopping

**Main.dart Structure:**
```dart
// Clean bootstrap initialization
await ApplicationBootstrap.initialize();
// Followed by widget bindings and app startup
```

### Code Intelligence Platform (`tools/code_intelligence_platform.dart`)
- **Multi-Dimensional Analysis**: Security (30%), Performance (25%), Architecture (20%), Quality (15%)
- **Reality-Based Scoring**: Uses weakest link principle - no inflated metrics
- **Predictive Intelligence**: Bug hotspots and maintenance burden forecasting
- **Actionable Remediation**: Specific fix suggestions with effort estimates
- **Flutter Intelligence**: State management, widget optimization, lifecycle analysis
- **Run Command**: `dart tools/code_intelligence_platform.dart`

## Test System Guidelines
- **Complete Guide**: See `/docs/testing/TEST_GUIDE.md`
- **Quick Patterns**: See `/docs/testing/TEST_PATTERNS_QUICK_REFERENCE.md`
- **Current Status**: See `/docs/testing/TESTING_DASHBOARD.md`
- **Templates**: Use `/test/templates/` for consistent test creation

## Workflow Instructions

### Assume multiple Claude Code sessions running in parallel

### 📋 General Development Workflow
**Before starting:**
1. Think through problem, read codebase and `/docs` documentation
2. Write detailed plan to `tasks/todo.md` with checkable todo items
3. **MUST verify plan with user before beginning work**

**While working:**
1. Work through todos, marking complete as you go
2. Give high-level explanations understandable for vibecoder
3. **DO NOT BE LAZY** - find root causes, no temporary fixes
4. Make simplest possible changes, minimal code impact
5. **CRITICAL: Always update corresponding tests when changing production code**
   - When modifying services: Update service tests in `test/unit/services/`
   - When modifying viewmodels: Update viewmodel tests in `test/unit/viewmodels/`
   - When modifying models: Update model tests in `test/unit/models/`
   - When modifying repositories: Update repository tests in `test/unit/repositories/`
   - Run `flutter test` before completing any production code changes
6. **DEBUGGING METHODOLOGY**: Use systematic approach for production issues:
   - Step 1: Add comprehensive logging to trace data flow (repositories → services → viewmodels)
   - Step 2: Test with multiple users to verify data persistence vs caching issues
   - Step 3: Map all sources of truth and verify correct service connections
   - **Always check ViewModels are connected to correct services** - common cause of UI inconsistencies
7. Ask questions before deviating from todos

**When finished:**
1. Add review section to `todo.md` with summary of changes
2. Update relevant documentation in `/docs` and `CLAUDE.md`
3. **Run targeted analysis**: `flutter analyze lib/path/to/changed_file.dart` on files you modified
   - **NEVER run full `flutter analyze`** when working in parallel sessions
   - Only analyze files you changed or files directly affected by your changes
   - Prevents conflicts with issues being fixed by other Claude Code instances
   - If unclear about scope, ask user before running analysis
4. Verify implementations match documentation claims

## Critical Rules
- **NEVER BE LAZY** - you are a senior developer
- Find root causes, fix properly, no workarounds
- Focus on simplicity and minimal code impact
- Proper error handling and security validation
- Ask before moving away from planned todos