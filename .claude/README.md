# Butlery Claude Code Infrastructure

This directory contains a comprehensive Claude Code infrastructure system designed specifically for Butlery's Flutter/Dart development workflow.

## System Overview

This infrastructure provides:
- **12 Skills** ✅ COMPLETE (all skills implemented)
- **Dev Docs System** ✅ COMPLETE (templates and workflow guide)
- **7 Hooks** ✅ IMPLEMENTED (6 working hooks configured)
- **7 Agents** ✅ IMPLEMENTED (code review agents)
- **8 Slash Commands** ✅ IMPLEMENTED (custom workflows)

**Status**: Core System Complete (January 2025) - Skills, Hooks, Agents operational

## Directory Structure

```
.claude/
├── skills/                    # 12 domain-specific skills
│   ├── butlery-architecture/
│   │   ├── SKILL.md
│   │   └── resources/        # Progressive disclosure (<500 lines each)
│   ├── testing-patterns/
│   ├── firebase-repository-patterns/
│   ├── state-management-patterns/
│   ├── code-deduplication-utilities/
│   ├── flutter-widget-guidelines/
│   ├── gdpr-compliance/
│   ├── realtime-collaboration/
│   ├── offline-first-patterns/
│   ├── navigation-routing/
│   ├── dependency-injection-patterns/
│   └── performance-optimization/
├── hooks/                     # 7 automation hooks
│   ├── skill-activation-prompt.sh
│   ├── architecture-validator.sh
│   ├── test-coverage-tracker.sh
│   ├── migration-detector.sh
│   ├── file-size-enforcer.sh
│   ├── dart-analyze-check.sh
│   └── dart-format-check.sh
├── agents/                    # 6 specialized agents
│   ├── flutter-test-generator.md
│   ├── migration-assistant.md
│   ├── repository-generator.md
│   ├── viewmodel-generator.md
│   ├── architecture-auditor.md
│   └── service-generator.md
├── templates/                 # Dev docs templates
│   ├── feature-plan-template.md
│   ├── feature-context-template.md
│   └── feature-tasks-template.md
├── commands/                  # Slash command definitions
│   ├── test-generate.md
│   ├── repo-create.md
│   ├── service-create.md
│   ├── viewmodel-create.md
│   ├── migrate-serialization.md
│   ├── architecture-audit.md
│   └── dev-docs.md
├── skill-rules.json          # Skill activation configuration
├── settings.json             # Hook configuration
└── README.md                 # This file
```

## Quick Start

### Week 1: Foundation (6 hours)
1. **Implemented**: butlery-architecture skill
2. **Next**: testing-patterns and firebase-repository-patterns skills
3. **Then**: skill-activation-prompt and architecture-validator hooks
4. **Finally**: skill-rules.json and settings.json

### Weeks 2-4: Full Implementation
See [Implementation Roadmap](#implementation-roadmap) below.

## Skills System (12 Skills)

Skills automatically activate based on file patterns, keywords, and user intent. Each skill provides:
- Main SKILL.md (<500 lines) with overview and quick reference
- 3-6 resource files (<500 lines each) for deep dives
- Code examples from actual Butlery codebase
- Trigger configuration in skill-rules.json

### Critical Skills (Week 1)
1. **butlery-architecture** - MVVM + Repository pattern enforcement
2. **testing-patterns** - Test generation templates and patterns
3. **firebase-repository-patterns** - BaseFirebaseRepository usage

### High-Value Skills (Week 2)
4. **state-management-patterns** - Provider + ChangeNotifier, AsyncOperationMixin
5. **flutter-widget-guidelines** - Widget composition, theme, accessibility
6. **dependency-injection-patterns** - 7-module DI system

### Migration Skills (Week 3)
7. **code-deduplication-utilities** - SerializationUtils, ErrorHandlingMixin, extensions
8. **gdpr-compliance** - Articles 7/15/17/30 patterns

### Advanced Skills (Week 4)
9. **realtime-collaboration** - Real-time service patterns
10. **offline-first-patterns** - Hive + Firebase sync
11. **navigation-routing** - Custom AppRouter patterns
12. **performance-optimization** - Image optimization, caching, startup

## Hooks System

Hooks automatically run at specific lifecycle events to enforce architecture patterns and activate relevant skills.

### UserPromptSubmit Hooks (Before Claude Processes)

**skill-activation-prompt** ✅ ENHANCED - Auto-activate relevant skills before Claude thinks

**Features**:
- Parses all 12 skills from skill-rules.json dynamically
- Matches user prompts against keywords AND intent patterns (regex)
- Detects recently modified files and matches against path patterns
- Priority-based skill ordering (critical → high → medium)
- Injects skill activation instructions into conversation context

**How it works**:
1. User submits: "create a new recipe repository"
2. Hook matches keywords: "create", "repository"
3. Hook activates: `firebase-repository-patterns` (critical), `butlery-architecture` (critical)
4. Claude sees: "Read these skills before responding: [skill paths]"
5. Claude automatically uses patterns from activated skills

**Triggers**:
- Prompt keywords (architecture, test, repository, service, etc.)
- Intent patterns (create.*service, new.*repository, etc.)
- File edits (editing lib/repositories/*.dart auto-activates firebase-repository-patterns)

**Windows Note**: Requires Python 3.x. If hooks don't auto-activate, manually reference skills using:
`"Check the firebase-repository-patterns skill and help me..."`

### PostToolUse Hooks (after file changes)
- **architecture-validator** - HYBRID enforcement: BLOCK critical violations, WARN style issues
- **test-coverage-tracker** - Update TESTING_DASHBOARD.md automatically
- **migration-detector** - Suggest SerializationUtils/ErrorHandlingMixin usage
- **file-size-enforcer** - Warn on 500+ LOC without facade pattern

### Stop Hooks (before returning control)
- **dart-analyze-check** - Run flutter analyze
- **dart-format-check** - Auto-format changed files

### Hybrid Enforcement Model

The **architecture-validator** hook uses a hybrid approach:

**BLOCK (prevents commit):**
- Direct `FirebaseFirestore.instance` usage
- Missing permission validation in repositories
- Legacy `sl<T>()` pattern usage
- ViewModels accessing repositories directly

**WARN (allows commit with warning):**
- Files >500 LOC without facade pattern
- Services not extending BaseService
- Try-catch blocks instead of ErrorHandlingMixin
- Manual parsing instead of SerializationUtils

## Agents System

Agents are specialized sub-agents that can be invoked to perform specific tasks.

### Active Code Review Agents (7 Implemented)

These agents proactively review code after modifications:

1. **code-reviewer** - Senior code review for quality and maintainability
   - Readability, naming, code structure
   - Architecture compliance (MVVM, DI patterns)
   - Error handling and Dart/Flutter best practices

2. **testing-specialist** - Test coverage and quality reviewer
   - Identifies missing tests for modified production code
   - Ensures tests follow project patterns
   - Uses templates from `/test/templates/`

3. **performance-optimizer** - Flutter performance specialist
   - Widget optimization (const, keys, builders)
   - ViewModel optimization (notifyListeners, streams)
   - Real-time optimization (Firebase listeners, pagination)

4. **firebase-backend-security** - Firebase security and GDPR compliance
   - Permission validation and authorization
   - GDPR compliance (consent, data export, deletion)
   - Query optimization and real-time listeners

5. **flutter-developer** - Flutter development best practices
6. **debugger** - Debugging assistance and issue resolution
7. **uiux-designer** - UI/UX design review and accessibility

**How to Use**: Agents are designed to be invoked AFTER writing code to review it.
They complement skills (which are reference docs used WHILE coding).

### Planned Generator Agents (Not Yet Implemented)

Future agents for code generation:
- **flutter-test-generator** - Generate tests for services/repos/ViewModels
- **repository-generator** - Generate BaseFirebaseRepository implementations
- **service-generator** - Generate BaseService implementations
- **viewmodel-generator** - Generate ViewModels with AsyncOperationMixin
- **migration-assistant** - Migrate to SerializationUtils, ErrorHandlingMixin
- **architecture-auditor** - Full codebase MVVM compliance audit

## Slash Commands (8 Implemented)

Custom slash commands for common workflows:

**Implemented**:
- `/test-generate [repository-name]` - Generate comprehensive test for repository
- `/analyze` - Run Flutter analyze with structured todo list
- `/test_architecture` - Run Code Intelligence Platform analysis
- `/commit` - Commit session changes with proper message format
- `/branch` - Create and switch to new git branch
- `/main` - Merge current branch to main and cleanup
- `/worktree` - Manage git worktrees for parallel development
- `/docs-update` - Update documentation files based on code changes

**Planned**:
- `/repo-create [name]` - Generate new repository
- `/service-create [name]` - Generate new service
- `/viewmodel-create [name]` - Generate new ViewModel
- `/migrate-serialization [file]` - Migrate to SerializationUtils

## Configuration Files

### settings.json (Committed)

**Purpose**: Shared hook and infrastructure configuration for all team members.

**Contains**:
- Hook configuration (userPromptSubmit, postToolUse, stop)
- Custom instructions for Claude Code
- Linting preferences
- Documentation auto-update settings

**Location**: `.claude/settings.json` (committed to repository)

### settings.local.json (Gitignored)

**Purpose**: Developer-specific overrides and local customization.

**Contains**:
- Personal hook preferences
- Local-only custom instructions
- Development environment settings

**Location**: `.claude/settings.local.json` (in `.gitignore`)

**Note**: Local settings override committed settings. Use for personal workflow preferences without affecting the team.

### skill-rules.json

Defines when each skill activates:

```json
{
  "butlery-architecture": {
    "type": "domain",
    "enforcement": "enforce",
    "priority": "critical",
    "promptTriggers": {
      "keywords": ["architecture", "mvvm", "repository", "service"],
      "intentPatterns": ["create.*service", "new.*repository"]
    },
    "fileTriggers": {
      "pathPatterns": ["lib/services/**/*.dart", "lib/repositories/**/*.dart"],
      "contentPatterns": ["class.*Service", "class.*Repository"]
    }
  }
  // ... other skills
}
```

### settings.json

Configures hook execution:

```json
{
  "hooks": {
    "userPromptSubmit": [
      {
        "path": ".claude/hooks/skill-activation-prompt.sh",
        "description": "Auto-activate relevant skills",
        "blocking": false
      }
    ],
    "postToolUse": [
      {
        "path": ".claude/hooks/architecture-validator.sh",
        "description": "Validate MVVM compliance (hybrid enforcement)",
        "blocking": true
      }
    ],
    "stop": [
      {
        "path": ".claude/hooks/dart-analyze-check.sh",
        "description": "Run flutter analyze",
        "blocking": false
      }
    ]
  }
}
```

## Implementation Roadmap

### ✅ Week 1: Foundation (COMPLETE)

**Day 1-2**: Core Skills
- ✅ butlery-architecture skill (SKILL.md + 5 resources)
- ✅ testing-patterns skill (SKILL.md + 6 resources)
- ✅ firebase-repository-patterns skill (SKILL.md + 3 resources)

**Day 3**: Hooks Setup (1.5 hours)
- Create skill-activation-prompt hook
- Create architecture-validator hook (hybrid enforcement)

**Day 4**: Configuration (1 hour)
- Create skill-rules.json with 3 skills configured
- Create settings.json with 2 hooks configured

**Day 5**: Testing (0.5 hours)
- Test skill activation on service/repository files
- Test architecture validator blocking critical violations
- Test architecture validator warning on style issues

### ✅ Week 2: Core Skills Complete (COMPLETE)

**Skills Created**:
- ✅ state-management-patterns skill (SKILL.md + 4 resources)
- ✅ flutter-widget-guidelines skill (SKILL.md + 5 resources)
- ✅ code-deduplication-utilities skill (SKILL.md + 6 resources)

**Note**: Hooks, agents, and slash commands deferred for future implementation

### Week 3: Skipped (Skills prioritized)

Skills moved to earlier weeks for immediate value.

### ✅ Week 4: Final 6 Skills (COMPLETE)

**HIGH VALUE Skills** (Comprehensive implementation):
- ✅ dependency-injection-patterns (SKILL.md + 5 resources)
  - Complete 7-module DI architecture
  - Service access patterns, testing with DI
- ✅ gdpr-compliance (SKILL.md + 5 resources)
  - Articles 7/15/17/30 compliance patterns
  - Consent, data export, deletion, audit logging

**MEDIUM VALUE Skills** (Comprehensive implementation):
- ✅ realtime-collaboration (SKILL.md + 6 resources)
  - Real-time services, presence tracking
  - Conflict resolution, models, UI integration
- ✅ offline-first-patterns (SKILL.md + 6 resources)
  - OfflineService, caching strategies
  - Sync mechanisms, models, UI patterns

**LOW VALUE Skills** (Concise reference guides):
- ✅ navigation-routing (SKILL.md only)
  - Flutter navigation, deep linking, guards
- ✅ performance-optimization (SKILL.md only)
  - Widget optimization, caching, memory management

**Total Resources Created**: 28 comprehensive documentation files

**Note**: Hooks, agents, slash commands, and dev docs system deferred for future implementation based on team needs

## Usage Examples

### Skill Activation

Skills activate automatically:
```dart
// Open lib/services/my_service.dart
// butlery-architecture skill auto-activates

// Ask: "create a new recipe repository"
// firebase-repository-patterns skill auto-activates

// Open test/unit/services/my_service_test.dart
// testing-patterns skill auto-activates
```

### Hook Execution

Hooks run automatically:
```bash
# After editing lib/services/bad_service.dart with direct Firebase access:
# architecture-validator hook BLOCKS commit with error message

# After editing lib/services/large_service.dart (600 LOC, no facade):
# file-size-enforcer hook WARNS about file size

# Before returning control to user:
# dart-analyze-check hook runs flutter analyze
# Shows any errors/warnings to Claude
```

### Slash Commands

```bash
# Generate test for a service
/test-generate lib/services/recipe_service.dart

# Create new repository
/repo-create RecipeSharingRepository

# Migrate file to SerializationUtils
/migrate-serialization lib/models/recipe.dart

# Run architecture audit
/architecture-audit
```

### Dev Docs Workflow

**Manual Setup** (slash commands not yet implemented):

```bash
# Starting new feature
mkdir -p dev/active/recipe-sharing
cd dev/active/recipe-sharing

# Copy templates
cp .claude/templates/feature-plan-template.md recipe-sharing-plan.md
cp .claude/templates/feature-context-template.md recipe-sharing-context.md
cp .claude/templates/feature-tasks-template.md recipe-sharing-tasks.md

# Fill out plan (30-60 minutes)
# Then start implementing...

# At end of session (CRITICAL - prevents context loss):
# Update context.md with:
# - Current Working Context (WHERE you stopped)
# - Next Immediate Steps (WHAT to do next)
# - Recent Changes (WHAT files modified)

# At start of next session:
cat dev/active/recipe-sharing/recipe-sharing-context.md
# Read "Current Working Context" section to resume
```

**Complete Workflow**: See [DEV_DOCS_GUIDE.md](DEV_DOCS_GUIDE.md) for detailed instructions.

## Expected Outcomes

After full implementation:

### Test Coverage
- Current untested repositories get test files
- Test coverage increases incrementally
- Consistent test patterns across all layers

### Code Quality
- No direct Firebase access violations
- All services extend BaseService
- All repositories extend BaseFirebaseRepository
- Permission validation on all CRUD operations

### Migration Progress
- SerializationUtils adoption increases from current state
- ErrorHandlingMixin usage increases
- Manual error handling patterns eliminated

### Development Efficiency
- Test generation saves 30-45 min per repository
- Boilerplate generation saves 15-20 min per service/repository
- Architecture validation catches issues in seconds
- Dev docs prevent context loss after resets

## File Templates

### Skill Template Structure

Each skill follows this structure:

```markdown
# [Skill Name]

## Purpose
[1-2 sentences]

## When to Use This Skill
[Activation scenarios]

## [Main Content Sections]
[Key patterns, rules, examples]

## Resource Files
[Links to detailed guides]

## Examples from Butlery Codebase
[Real code examples]
```

### Hook Template Structure

Each hook follows this structure:

```bash
#!/bin/bash
# Hook Name
# Event: UserPromptSubmit | PostToolUse | Stop
# Enforcement: block | warn | suggest

# [Hook logic]
# [Validation checks]
# [Output to Claude]
```

### Agent Template Structure

Each agent follows this structure:

```markdown
# [Agent Name] Agent

You are an expert Flutter/Dart developer specializing in [domain].

## Your Task
[Detailed task description]

## Context About Butlery
[Project-specific patterns]

## Analysis Steps
[Step-by-step instructions]

## Output Format
[Expected output structure]

## Tools Available
[What tools to use]

## Examples
[Concrete examples from codebase]
```

## Progressive Disclosure Strategy

To respect Claude's context limits:

1. **Skills**: Main SKILL.md <500 lines, resource files <500 lines each
2. **Activation**: Only load relevant skills based on triggers
3. **Resources**: Load resource files only when user asks for details
4. **Examples**: Include 3-5 examples in main skill, more in resources

## Testing the System

### Test Skill Activation
1. Open `lib/services/recipe_service.dart`
2. Verify butlery-architecture skill activates
3. Ask Claude about architecture patterns
4. Verify Claude uses skill knowledge

### Test Architecture Validator (Critical Violations - BLOCK)
1. Edit a service to use `FirebaseFirestore.instance`
2. Save the file
3. Verify hook blocks with error message
4. Fix the violation
5. Verify hook allows the change

### Test Architecture Validator (Style Issues - WARN)
1. Create a new service without extending BaseService
2. Save the file
3. Verify hook warns but doesn't block
4. Optionally fix or proceed

### Test Test Generator
1. Run `/test-generate lib/services/my_service.dart`
2. Verify test file created with proper structure
3. Run `flutter test test/unit/services/my_service_test.dart`
4. Verify tests pass

## Maintenance

### Updating Skills
- Skills reflect current Butlery patterns
- Update skills when architectural patterns change
- Keep examples from actual codebase

### Updating Hooks
- Test hooks after Claude Code updates
- Adjust enforcement based on team feedback
- Monitor false positives/negatives

### Updating Agents
- Refine agent prompts based on output quality
- Add new agents for repetitive tasks
- Remove agents that aren't used

## Troubleshooting

### Skill Not Activating
- Check skill-rules.json configuration
- Verify file path matches pathPatterns
- Check keyword matches

### Hook Not Running
- Check settings.json configuration
- Verify hook script is executable (`chmod +x`)
- Check hook script syntax

### Agent Not Working
- Verify agent prompt clarity
- Check if agent has access to needed tools
- Test agent with simpler inputs first

## Contributing

When adding new skills, hooks, or agents:

1. Follow existing naming conventions
2. Keep files under 500 lines (progressive disclosure)
3. Include real Butlery code examples
4. Test thoroughly before committing
5. Update this README

## Resources

- **Phase 1 Analysis**: [See project root for detailed codebase analysis]
- **CLAUDE.md**: [Project-specific Claude Code instructions]
- **Butlery Documentation**: `docs/` directory

---

**Created**: 2025-01-31
**Last Updated**: 2025-01-31
**Maintained By**: Butlery Development Team
**Claude Code Version**: Latest
