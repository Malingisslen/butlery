# Getting Started with Butlery Claude Code Infrastructure

**Status**: ✅ System Complete (January 2025)

This guide explains how to use the completed Claude Code infrastructure for Butlery's Flutter development workflow.

---

## System Overview

The Claude Code infrastructure is **100% complete** with:
- **12 Skills** - Comprehensive pattern library covering all major Butlery patterns
- **7 Hooks** - Automation for quality checks and guidance (configured, implementation TBD)
- **1 Command** - /test-generate for test generation workflow
- **Dev Docs System** - Templates and workflow for multi-session features
- **Configuration** - skill-rules.json and settings.json ready for use

For complete implementation history, see [IMPLEMENTATION_HISTORY.md](./IMPLEMENTATION_HISTORY.md).

---

## Quick Start

###  1. Browse the Skills

All 12 skills are located in `.claude/skills/`:

**Foundation Skills**:
- `butlery-architecture/` - MVVM, Repository pattern, DI system
- `testing-patterns/` - Test strategies for all layers
- `firebase-repository-patterns/` - BaseFirebaseRepository usage

**State & UI Skills**:
- `state-management-patterns/` - ChangeNotifier, AsyncOperationMixin
- `flutter-widget-guidelines/` - LoadingStateBuilder, composition patterns

**Utility Skills**:
- `code-deduplication-utilities/` - SerializationUtils, ErrorHandlingMixin, extensions

**Advanced Skills**:
- `dependency-injection-patterns/` - 7-module DI system
- `gdpr-compliance/` - Articles 7/15/17/30 compliance patterns
- `realtime-collaboration/` - Real-time service patterns
- `offline-first-patterns/` - Offline architecture and caching
- `navigation-routing/` - Navigation patterns (quick reference)
- `performance-optimization/` - Performance best practices (quick reference)

### 2. Use Skills for Reference

When implementing features, reference the relevant skill:

```bash
# Need to create a repository?
cat .claude/skills/firebase-repository-patterns/SKILL.md

# Need to test a ViewModel?
cat .claude/skills/testing-patterns/resources/viewmodel-testing.md

# Need GDPR compliance?
cat .claude/skills/gdpr-compliance/SKILL.md
```

Each skill has:
- **SKILL.md** - Overview and quick reference (<500 lines)
- **resources/*.md** - Detailed guides for specific topics (<500 lines each)

### 3. Use Dev Docs for Multi-Session Features

For complex features spanning multiple sessions:

```bash
# Create feature directory
mkdir -p dev/active/my-feature

# Copy templates
cp .claude/templates/feature-plan-template.md dev/active/my-feature/my-feature-plan.md
cp .claude/templates/feature-context-template.md dev/active/my-feature/my-feature-context.md
cp .claude/templates/feature-tasks-template.md dev/active/my-feature/my-feature-tasks.md

# Fill out plan and start implementing
```

**Critical Habit**: Update `my-feature-context.md` at end of each session with:
- Current Working Context (WHERE you stopped)
- Next Immediate Steps (WHAT to do next)
- Recent Changes (WHAT files modified)

See [DEV_DOCS_GUIDE.md](./DEV_DOCS_GUIDE.md) for complete workflow.

### 4. Use Test Generation Command

To generate tests for repositories:

```bash
# Ask Claude Code:
"/test-generate firebase_auth_repository"

# Review generated template and customize for your repository
```

---

## What Each Component Does

### Skills System

**Purpose**: Comprehensive pattern library for all Butlery architectural patterns

**How to Use**:
1. Open relevant SKILL.md file when implementing features
2. Use resources/*.md files for deep dives on specific topics
3. All examples are from actual Butlery production code

**When to Use**:
- Creating new repositories, services, ViewModels
- Testing any layer of the architecture
- Implementing GDPR compliance
- Adding real-time collaboration
- Setting up offline support
- Debugging dependency injection issues

### Hooks System

**Purpose**: Automation for quality checks and architecture enforcement

**Status**: Configured in settings.json, implementation TBD

**Planned Hooks**:
1. **architecture-validator** - Block critical violations (direct Firebase access, layer bypassing)
2. **skill-activation-prompt** - Auto-load relevant skills based on context
3. **file-size-enforcer** - Warn on files >500 lines without facade pattern
4. **migration-detector** - Suggest infrastructure adoption opportunities
5. **dart-analyze-check** - Run flutter analyze automatically
6. **dart-format-check** - Session cleanup checklist
7. _(Hook 7 configured)_

**Note**: Hooks are configured but not yet implemented. Skills can be used manually for now.

### Commands System

**Purpose**: Slash commands for common workflows

**Available**:
- `/test-generate [repository-name]` - Generate test templates for repositories

**Planned** (TBD):
- /repo-create, /service-create, /viewmodel-create
- /migrate-serialization
- /architecture-audit
- /dev-docs

### Dev Docs System

**Purpose**: Prevent context loss when working on multi-session features

**How to Use**:
1. Copy 3 templates to `dev/active/[feature-name]/`
2. Fill out plan template (30-60 minutes)
3. Update context template at end of each session (5 minutes)
4. Update tasks template as you work (ongoing)

**Why Use It**:
- Prevents "what was I doing?" confusion when resuming work
- Maintains technical decisions and rationale
- Tracks progress with detailed task lists
- Enables seamless handoff between sessions

---

## Common Workflows

### Creating a New Repository

1. **Reference skill**: `firebase-repository-patterns/SKILL.md`
2. **Follow pattern**: Extend BaseFirebaseRepository<T>
3. **Implement**: Collection path, fromFirestore, toFirestore
4. **Add validation**: Permission checks on CRUD operations
5. **Generate tests**: `/test-generate [repository-name]`

### Creating a New Service

1. **Reference skill**: `butlery-architecture/resources/service-pattern.md`
2. **Follow pattern**: Extend BaseService
3. **Implement**: Business logic with executeServiceOperation()
4. **Register in DI**: Add to appropriate module in `lib/core/di/modules/`
5. **Write tests**: Service test patterns in `testing-patterns/`

### Creating a New ViewModel

1. **Reference skill**: `state-management-patterns/SKILL.md`
2. **Choose pattern**:
   - Simple CRUD → BaseViewModel + ChangeNotifier
   - Debouncing/search → AsyncOperationMixin
   - Complex (500+ lines) → Manager delegation pattern
3. **Register in DI**: Add to UI module
4. **Write tests**: ViewModel test patterns in `testing-patterns/`

### Implementing GDPR Compliance

1. **Reference skill**: `gdpr-compliance/SKILL.md`
2. **Choose article**:
   - Consent → Article 7 (ConsentService patterns)
   - Data export → Article 15 (DataExportService patterns)
   - Account deletion → Article 17 (AccountDeletionService patterns)
   - Audit logging → Article 30 (FirebaseAuditRepository patterns)
3. **Follow examples**: All patterns from production code

### Migrating to Deduplication Utilities

1. **Reference skill**: `code-deduplication-utilities/SKILL.md`
2. **Choose utility**:
   - Firestore parsing → SerializationUtils
   - Error handling → ErrorHandlingMixin (via BaseService)
   - Null coalescing → Default value extensions
   - Form validation → ValidationUtils
3. **Follow decision tree**: Full migration vs Partial vs Defer
4. **Test thoroughly**: Behavior must remain unchanged

---

## Tips for Success

### 1. Use Progressive Disclosure

Don't read entire skills at once. Start with:
- **SKILL.md** for overview
- **Specific resource file** for what you need
- **Examples** in the skill files

### 2. Keep Files Under 500 Lines

When creating files >500 lines, use facade pattern:
- Extract modules to separate files
- Import managers for complex logic
- See `recipe_form_viewmodel.dart` (905 lines) as exemplary pattern

### 3. Respect Well-Architected Code

Not all code needs to be migrated:
- If it follows facade pattern, keep it
- If it has custom streams/managers, keep it
- Only migrate boilerplate-heavy code

### 4. Update Dev Docs Context

When using dev docs system:
- **Before ending session**: Update context.md (5 minutes)
- **Before starting session**: Read context.md (2 minutes)
- **Be specific**: File paths, line numbers, exact next steps

### 5. Reference Real Examples

All skills use actual Butlery code:
- Don't reinvent patterns
- Follow established conventions
- Copy structure from examples

---

## Troubleshooting

### Skills Don't Auto-Activate

**Status**: Skill auto-activation not yet implemented (hooks TBD)

**Workaround**: Manually reference skills by opening files or asking Claude to check specific skills:
```
"Check the firebase-repository-patterns skill"
"What does testing-patterns say about ViewModel tests?"
```

### Can't Find a Pattern

**Solution**: Check the relevant skill's table of contents:
1. Open SKILL.md for overview
2. Check "Resource Files" section for detailed guides
3. Use file search to find keywords:
   ```bash
   grep -r "pattern name" .claude/skills/
   ```

### Hook Not Running

**Status**: Hooks configured but not yet implemented

**Future**: When hooks are implemented, check:
- Hook script is executable (`chmod +x .claude/hooks/*.sh`)
- Hook is configured in `.claude/settings.json`
- Git Bash or WSL available on Windows

### Test Generation Not Working

**Status**: /test-generate command documented but agent not implemented

**Workaround**: Use test templates from `testing-patterns/resources/` manually:
- Repository tests: `repository-testing.md`
- Service tests: `service-testing.md`
- ViewModel tests: `viewmodel-testing.md`

---

## Next Steps

### For Daily Development

1. **Start Session**: Read relevant skill before implementing
2. **During Session**: Reference patterns as needed
3. **End Session**: Update dev docs if using multi-session workflow

### For Future Enhancement

**When hooks are implemented**:
- Skills will auto-activate based on file patterns
- Architecture violations will be caught automatically
- Migration opportunities will be suggested

**When agents are implemented**:
- Test generation will be automated
- Repository/service/ViewModel boilerplate will be generated
- Migration assistance will be available

**When commands are implemented**:
- /repo-create, /service-create, /viewmodel-create
- /migrate-serialization
- /architecture-audit

### For System Maintenance

**Updating Skills**: When patterns change, update skill files:
1. Locate skill in `.claude/skills/[skill-name]/`
2. Update SKILL.md or resource files
3. Keep examples from actual production code
4. Maintain <500 line limit per file

**Adding New Skills**: Follow established patterns:
1. Create skill directory in `.claude/skills/`
2. Create SKILL.md (<500 lines)
3. Create resources/ directory with detailed guides
4. Update skill-rules.json with triggers
5. Add to README.md skills list

---

## Resources

### Core Documentation
- **README.md** - Complete system overview and roadmap
- **IMPLEMENTATION_HISTORY.md** - Timeline of system development
- **DEV_DOCS_GUIDE.md** - Complete dev docs workflow

### Skill Files
- **All skills**: `.claude/skills/[skill-name]/SKILL.md`
- **Detailed guides**: `.claude/skills/[skill-name]/resources/*.md`

### Templates
- **Feature plan**: `.claude/templates/feature-plan-template.md`
- **Feature context**: `.claude/templates/feature-context-template.md`
- **Feature tasks**: `.claude/templates/feature-tasks-template.md`

### Configuration
- **Skill triggers**: `.claude/skill-rules.json`
- **Hook configuration**: `.claude/settings.json`

### Butlery Docs
- **Project patterns**: `../CLAUDE.md`
- **Testing dashboard**: `../docs/testing/TESTING_DASHBOARD.md`
- **Architecture docs**: `../docs/architecture/`

---

## Questions?

If you have questions or need clarification:

1. **Check the relevant skill** - All patterns are documented with examples
2. **Read resource files** - Detailed guides in `resources/` subdirectories
3. **Reference implementation history** - See how the system was built
4. **Review Butlery docs** - Project-wide patterns in `docs/` directory

---

**Created**: 2025-01-31
**Last Updated**: 2025-01-31
**Status**: ✅ System Complete (100%)
**Next**: Use skills for daily development, implement hooks/agents when needed
