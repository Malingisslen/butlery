# Claude Code Project Configuration

## Flutter Commands (WSL Environment)
**CRITICAL: ALWAYS use Windows Flutter via cmd.exe**
cmd.exe /c "flutter COMMAND"

**Examples:**
- Analysis: `cmd.exe /c "flutter analyze"`
- Run: `cmd.exe /c "flutter run"`

**Why:** WSL line ending issues, project in Windows filesystem `/mnt/c/Butlery/butlery`

## Architecture & Standards
- **Pattern**: MVVM + Repository Pattern (Views → ViewModels → Services → Repositories → Firebase)
- **File Size Limit**: 500 lines max (use facade pattern for larger files)
- **Dependency Injection**: Modular DI system with domain-driven modules (see below)
- **Notifications**: Complete FCM system with development logging approach
- **Social Features**: 90% infrastructure implemented (social views and services exist, need verification)
- **Code Quality**: Single Responsibility Principle enforced
- **Security**: Comprehensive permission validation system implemented:
  - PermissionValidationMixin for all Firebase repositories
  - Authorization checks on all CRUD operations
  - Audit logging for security events
  - Ownership validation and role-based access control
- **Type Safety**: Map-based data access replaced with proper model usage
- **Flutter Color Syntax**: Use `withValues(alpha: 0.8)` instead of deprecated `withOpacity(0.8)`

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
- **Run Command**: `cmd.exe /c "dart tools/code_intelligence_platform.dart"`

## Workflow Instructions
**Before starting:**
1. Think through problem, read codebase and `/docs` documentation
2. Write detailed plan to `tasks/todo.md` with checkable todo items
3. **MUST verify plan with user before beginning work**

**While working:**
1. Work through todos, marking complete as you go
2. Give high-level explanations understandable for vibecoder
3. **DO NOT BE LAZY** - find root causes, no temporary fixes
4. Make simplest possible changes, minimal code impact
5. Ask questions before deviating from todos

**When finished:**
1. Add review section to `todo.md` with summary of changes
2. Update relevant documentation in `/docs` and `CLAUDE.md`
3. Run `cmd.exe /c "flutter analyze"` to check for issues
4. Verify implementations match documentation claims

## Critical Rules
- **NEVER BE LAZY** - you are a senior developer
- Find root causes, fix properly, no workarounds
- Focus on simplicity and minimal code impact
- Proper error handling and security validation
- Ask before moving away from planned todos