# Butlery Claude Code Hook System

## Overview

A robust, TypeScript-based hook system for automatically injecting relevant skills, validating architecture patterns, and maintaining code quality.

## System Architecture

```
.claude/
├── hooks/
│   ├── skill-injector.ts        (UserPromptSubmit - injects skill content)
│   ├── architecture-validator.ts (PostToolUse - blocks violations)
│   ├── quality-checks.ts         (Stop - analyze & format)
│   ├── package.json              (tsx dependency)
│   ├── tsconfig.json
│   └── shared/
│       ├── git-cache.ts          (shared git context cache)
│       ├── types.ts              (TypeScript interfaces)
│       └── logger.ts             (debug utilities)
├── skills/                       (12 skill directories)
├── skill-rules.json              (skill matching patterns)
└── settings.json                 (hook configuration)
```

## Hooks

### 1. skill-injector.ts (UserPromptSubmit)

**Purpose:** Auto-inject relevant skill documentation into Claude's context

**Triggers:**
- Keywords: "repository", "service", "viewmodel", "firebase", "testing", etc.
- Intent patterns: "create.*repository", "new.*service", etc.
- File patterns: Editing lib/repositories/, lib/services/, etc.

**Behavior:**
- Matches skills based on prompt and file context
- Sorts by priority (critical > high > medium)
- **Actually reads and injects SKILL.md file content** (not just paths)
- Non-blocking

**Performance:** ~50-150ms

**Example Output:**
```
🎯 BUTLERY ARCHITECTURE SKILLS - Auto-Injected
9 relevant skill(s) detected and injected into context:

1. [!] **butlery-architecture** [CRITICAL - REQUIRED]
   Location: .claude/skills/butlery-architecture/SKILL.md
   Matched: keyword:repository

📖 SKILL CONTENT:
[Full SKILL.md content follows...]
```

### 2. architecture-validator.ts (PostToolUse)

**Purpose:** Validate architecture patterns and block critical violations

**Critical Violations (BLOCKS with exit 1):**
- ❌ `FirebaseFirestore.instance` - must use injected repository
- ❌ `sl<T>()` - legacy pattern, must use `ServiceLocator.get<T>()`
- ❌ Direct Firebase access in non-repository files

**Style Warnings (non-blocking):**
- ⚠️ Files >500 LOC without facade pattern
- ⚠️ Manual `??` instead of `.orEmpty()` extensions

**Behavior:**
- Runs on Edit/Write operations
- Only checks Dart files (skips tests, DI config)
- Clear error messages with fix suggestions
- Blocks on critical violations

**Performance:** ~20-50ms

**Example Output (violation):**
```
❌ ARCHITECTURE VIOLATION DETECTED
File: lib/services/user_service.dart

🔴 CRITICAL: Direct FirebaseFirestore.instance usage detected
  Line: 42
  Pattern: FirebaseFirestore.instance

💡 FIX:
  Inject FirestoreRepository via constructor instead:
  MyService({required FirestoreRepository repository})

❌ Edit blocked. Please fix the violation above.
```

### 3. quality-checks.ts (Stop)

**Purpose:** Run automated code quality checks after Claude finishes

**Actions:**
- Runs `flutter analyze` on project
- Runs `dart format` on changed Dart files
- Outputs results for Claude to auto-fix

**Behavior:**
- Only runs if Dart files were modified
- Always exits 0 (non-blocking)
- Shows results to both user and Claude

**Performance:** ~2-5 seconds

**Example Output:**
```
═════════════════════════════════════════
🔍 Running Quality Checks
═════════════════════════════════════════

Running flutter analyze...
✓ No analysis issues found

Formatting 3 Dart file(s)...
  ✓ Formatted: lib/services/user_service.dart
  ✓ Formatted: lib/repositories/user_repository.dart
  ✓ Formatted: lib/viewmodels/user_viewmodel.dart

✓ Formatting complete
```

## Shared Utilities

### git-cache.ts

**Purpose:** Cache git operations to avoid redundancy

**Features:**
- Caches branch name and modified files
- 5-minute TTL (time-to-live)
- Writes to `.claude/cache/git-context.json`
- Shared across all hooks

**Benefit:** Reduces 4 git calls per prompt → 1 git call (~300-500ms saved)

### types.ts

TypeScript interfaces for type safety across all hooks.

### logger.ts

Debug logging utilities (enabled with `HOOK_DEBUG=1`).

## Performance

| Hook | Target | Actual |
|------|--------|--------|
| skill-injector | <200ms | ~50-150ms ✅ |
| architecture-validator | <100ms | ~20-50ms ✅ |
| quality-checks | <5s | ~2-5s ✅ |
| **Total overhead** | <500ms | ~70-200ms ✅ |

## Configuration

### settings.json

```json
{
  "hooks": {
    "UserPromptSubmit": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "npx tsx .claude/hooks/skill-injector.ts"
      }]
    }],
    "PostToolUse": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "npx tsx .claude/hooks/architecture-validator.ts"
      }]
    }],
    "Stop": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "npx tsx .claude/hooks/quality-checks.ts"
      }]
    }]
  }
}
```

## Testing

### Manual Testing

```bash
# Test skill injector
cd .claude/hooks
echo '{"prompt":"create repository"}' | npx tsx skill-injector.ts

# Test architecture validator
echo '{"tool_name":"Edit","tool_input":{"file_path":"test.dart"}}' | npx tsx architecture-validator.ts

# Test quality checks
npx tsx quality-checks.ts

# Enable debug mode
export HOOK_DEBUG=1
```

### Expected Behavior

1. **Skill Injection:** Mention "repository" in prompt → Skills auto-inject
2. **Architecture Validation:** Try to write `FirebaseFirestore.instance` → Blocked
3. **Quality Checks:** Write code → Auto-formatted and analyzed

## Troubleshooting

### Hook not executing

Check:
- `npm install` ran in `.claude/hooks/`
- TypeScript files have correct paths (PROJECT_ROOT)
- settings.json has hooks configured

### No skills injected

Check:
- `.claude/skill-rules.json` exists
- Prompt contains keywords from skill-rules.json
- Debug mode: `export HOOK_DEBUG=1`

### Architecture validation not blocking

Check:
- File is a Dart file (not test)
- Violation exists (e.g., `FirebaseFirestore.instance`)
- Hook exit code is 1 (blocks)

## Maintenance

### Adding New Skills

1. Create skill directory in `.claude/skills/`
2. Add SKILL.md file
3. Add entry to `.claude/skill-rules.json` with keywords/patterns

### Modifying Validation Rules

Edit `.claude/hooks/architecture-validator.ts` and add new checks to `validateArchitecture()`.

### Updating Dependencies

```bash
cd .claude/hooks
npm update
```

## Success Criteria

✅ Skills automatically injected with full content (not just paths)
✅ Critical violations blocked with clear messages
✅ Quality checks run automatically on stop
✅ No CRLF/line ending issues
✅ <500ms total hook overhead
✅ Single settings.json file
✅ Works on Windows/Mac/Linux

## Migration from Old System

The old Bash-based system has been completely replaced with this TypeScript system:

**Removed:**
- ❌ All .sh hook files
- ❌ settings.local.json
- ❌ Inline Python/Bash mix
- ❌ CRLF issues

**Benefits:**
- ✅ True skill content injection
- ✅ Type safety with TypeScript
- ✅ Shared git cache (4x fewer git calls)
- ✅ Cross-platform compatibility
- ✅ Better error handling
- ✅ Easier to maintain

---

**Last Updated:** November 2025
**Status:** ✅ Production Ready
**Performance:** 70-200ms overhead (target: <500ms)
**Architecture:** Pure TypeScript with Node.js runtime
