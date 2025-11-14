# Claude Code Hook & Skill System Requirements

## System Goals

Build a robust hook and skill system for the Butlery Flutter/Firebase project that:
1. **Auto-activates relevant skills** based on user prompts and file context
2. **Validates architecture patterns** before code changes
3. **Provides just-in-time guidance** without being intrusive
4. **Works reliably on Windows** with minimal dependencies

## Core Requirements

### 1. Skill Auto-Injection System

**Goal:** When user mentions topics like "repository", "firebase", "testing", etc., automatically inject relevant skill documentation into Claude's context.

**Current Skills (12 total):**
- butlery-architecture
- code-deduplication-utilities
- dependency-injection-patterns
- firebase-repository-patterns
- flutter-widget-guidelines
- gdpr-compliance
- navigation-routing
- offline-first-patterns
- performance-optimization
- realtime-collaboration
- state-management-patterns
- testing-patterns

**Skill Matching Logic:**
- **Keywords**: Simple word matching (e.g., "repository" triggers firebase-repository-patterns)
- **Intent patterns**: Regex patterns for phrases (e.g., "create.*repository")
- **File path patterns**: If editing lib/repositories/*.dart, trigger repository skills
- **Priority levels**: critical > high > medium

**Expected Behavior:**
- Skills MUST be actually injected (content, not just paths)
- Multiple skills can activate simultaneously
- Non-intrusive - should enhance, not block

### 2. Architecture Validation Hooks

**Goal:** Prevent critical architecture violations before code is written.

**Critical Violations (MUST BLOCK):**
1. ❌ `FirebaseFirestore.instance` - must use injected repository
2. ❌ `sl<T>()` - legacy pattern, must use `ServiceLocator.get<T>()`
3. ❌ Direct Firebase access in non-repository files

**Style Warnings (WARN but don't block):**
1. ⚠️ Files >500 LOC without facade pattern
2. ⚠️ Manual null coalescing instead of `.orEmpty()` extensions
3. ⚠️ Manual try-catch instead of BaseService/ErrorHandlingMixin

**Expected Behavior:**
- Check edited Dart files before Write/Edit completes
- Clear error messages with fix suggestions
- Session-aware (don't nag repeatedly)

### 3. Development Quality Hooks

**Goal:** Maintain code quality automatically.

**On Stop Event (after Claude finishes):**
1. Run `flutter analyze` - show issues to Claude for auto-fix
2. Run `dart format` on changed files - auto-format code

**Expected Behavior:**
- Non-blocking to user workflow
- Results shown to Claude for automatic fixes
- Fast execution (<5 seconds total)

## Technical Constraints

### Must Work On
- ✅ Windows 10/11
- ✅ Git Bash / WSL / PowerShell environments
- ✅ VS Code Claude extension

### Dependencies Available
- ✅ Git
- ✅ Python 3.x (usually available)
- ✅ Flutter/Dart toolchain
- ✅ Node.js/npm (optional)

### Performance Targets
- Skill activation: <200ms
- Architecture validation: <100ms
- Total hook overhead: <500ms per prompt

## Known Pain Points to Avoid

### Previous System Issues
1. ❌ **Line ending hell**: CRLF vs LF caused bash failures
2. ❌ **Bash + Python mix**: Fragile inline heredoc patterns
3. ❌ **Git redundancy**: Same `git diff` ran 4 times per prompt
4. ❌ **No actual injection**: Skills were listed but not read
5. ❌ **Settings drift**: Two config files (settings.json, settings.local.json)

### Design Principles for New System
1. ✅ **Single runtime**: Pick ONE (Node.js recommended - already available, cross-platform)
2. ✅ **Single config file**: No split configurations
3. ✅ **Shared cache**: Git operations done once, cached for all hooks
4. ✅ **True injection**: Skill content must be in context, not just referenced
5. ✅ **Clear separation**: Don't mix infrastructure docs with project history

## Proposed Architecture

### Option A: Pure TypeScript/Node.js
- All hooks in TypeScript
- Uses fs, path modules for file operations
- Runs via `npx tsx hook.ts`
- **Pros**: Type safety, easier to maintain, no line ending issues
- **Cons**: Requires Node.js

### Option B: Pure Python
- All hooks in Python
- Uses pathlib, json modules
- Runs via `python hook.py`
- **Pros**: Python usually available, good JSON handling
- **Cons**: Windows PATH issues

### Option C: Native JSON Config (No Scripts)
- Use Claude Code's native capabilities only
- Minimal/no external scripts
- **Pros**: No dependencies, no failures
- **Cons**: Limited functionality, can't do validation

**Recommendation: Option A (TypeScript)** - Best balance of capability and reliability

## File Structure

```
.claude/
├── settings.json (single source of truth)
├── skill-rules.json (skill activation config)
├── hooks/
│   ├── skill-injector.ts (reads skills, injects content)
│   ├── architecture-validator.ts (checks patterns, blocks violations)
│   ├── quality-checks.ts (analyze, format)
│   └── package.json (tsx dependency)
└── skills/
    ├── butlery-architecture/SKILL.md
    ├── dependency-injection-patterns/SKILL.md
    └── ... (12 skills total)
```

## Success Criteria

✅ User mentions "create repository" → firebase-repository-patterns skill content appears in Claude's context
✅ Claude tries to write `FirebaseFirestore.instance` → Blocked with clear error
✅ Claude writes code → Auto-formatted and analyzed before returning to user
✅ No CRLF/LF issues, no bash failures
✅ <500ms total overhead
✅ Single settings.json, no drift

## Migration from Old System

**Clean up (delete):**
- ❌ All .sh hook files
- ❌ settings.local.json
- ❌ skill-rules-enhanced.json, skill-rules.json.backup
- ❌ Old backup directory

**Keep:**
- ✅ skill-rules.json (skill definitions)
- ✅ Skills directory (12 SKILL.md files)
- ✅ Concept of priorities and patterns

**Build fresh:**
- ✅ New TypeScript hooks
- ✅ Consolidated settings.json
- ✅ Git cache system
- ✅ True skill injection
