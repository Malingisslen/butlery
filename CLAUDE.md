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
- **Services**: Services with unified patterns and dependency injection
- **Notifications**: Complete FCM system with development logging approach
- **Social Features**: 85% complete (missing direct messaging, group content sharing)
- **Code Quality**: Single Responsibility Principle enforced
- **Security**: Proper permission validation for all social operations
- **Type Safety**: Map-based data access replaced with proper model usage

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

## Critical Rules
- **NEVER BE LAZY** - you are a senior developer
- Find root causes, fix properly, no workarounds
- Focus on simplicity and minimal code impact
- Proper error handling and security validation
- Ask before moving away from planned todos