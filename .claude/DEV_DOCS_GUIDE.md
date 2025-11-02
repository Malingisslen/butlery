# Dev Docs System - Workflow Guide

**Purpose**: Prevent context loss when Claude Code sessions reset by maintaining structured feature documentation.

---

## The Problem

When working on complex features across multiple sessions:
- **Context resets** - Claude loses all previous conversation context
- **Time wasted** - Repeating explanations and re-explaining decisions
- **Errors introduced** - Missing critical details from previous sessions
- **Inconsistent patterns** - Forgetting what approach was being used

## The Solution

The **Dev Docs System** maintains three synchronized documents for each feature:

1. **[feature]-plan.md** - The "what and why" (rarely changes)
2. **[feature]-context.md** - The "where we are" (updated every session)
3. **[feature]-tasks.md** - The "detailed todo list" (updated frequently)

---

## When to Use Dev Docs

### Use Dev Docs When:
- ✅ Feature will take multiple sessions (>2 hours total)
- ✅ Feature is complex with many moving parts
- ✅ Multiple people will work on the feature
- ✅ You need to preserve technical decisions
- ✅ Context loss would significantly slow progress

### Don't Use Dev Docs When:
- ❌ Quick fix (<30 minutes)
- ❌ Simple one-file change
- ❌ Exploratory spike (use after deciding on approach)
- ❌ Just reading/understanding code

---

## Directory Structure

```
dev/
├── active/                    # Currently in development
│   ├── recipe-sharing/
│   │   ├── recipe-sharing-plan.md
│   │   ├── recipe-sharing-context.md
│   │   └── recipe-sharing-tasks.md
│   └── offline-sync/
│       ├── offline-sync-plan.md
│       ├── offline-sync-context.md
│       └── offline-sync-tasks.md
├── completed/                 # Finished features
│   └── user-authentication/
│       ├── user-authentication-plan.md
│       ├── user-authentication-context.md
│       └── user-authentication-tasks.md
└── archived/                  # Cancelled or deprecated
    └── old-feature/
        └── ...
```

---

## Workflow

### Phase 1: Starting a New Feature

**Step 1: Create Dev Docs Directory**
```bash
mkdir -p dev/active/recipe-sharing
cd dev/active/recipe-sharing
```

**Step 2: Copy Templates**
```bash
cp .claude/templates/feature-plan-template.md recipe-sharing-plan.md
cp .claude/templates/feature-context-template.md recipe-sharing-context.md
cp .claude/templates/feature-tasks-template.md recipe-sharing-tasks.md
```

**Step 3: Fill Out Plan** (30-60 minutes)
- Open `recipe-sharing-plan.md`
- Fill in all sections from template
- This becomes the **source of truth** for the feature

**What to Include**:
- Clear purpose and user story
- Architecture design (layers, data flow, Firebase structure)
- Technical decisions and patterns
- Implementation phases
- Testing strategy
- Risks and mitigation

**Step 4: Initialize Context and Tasks**
- Open `recipe-sharing-context.md`
- Set initial status (Planning phase)
- Mark all sections as "Not Started"
- Open `recipe-sharing-tasks.md`
- Break plan phases into specific tasks
- Prioritize tasks (P0/P1/P2/P3)

---

### Phase 2: During Development

**At START of Each Session**:

1. **Read Context First** (2-3 minutes)
   ```bash
   cat dev/active/recipe-sharing/recipe-sharing-context.md
   ```
   - Locate "Current Working Context" section
   - Read "What I Was Just Doing"
   - Read "Next Immediate Steps"

2. **Tell Claude** (in Claude Code):
   ```
   I'm resuming work on recipe-sharing feature.

   Please read:
   - dev/active/recipe-sharing/recipe-sharing-context.md

   Focus on "Current Working Context" and "Next Immediate Steps" sections.
   Let me know what we should work on next.
   ```

3. **Claude Reviews & Resumes**
   - Claude reads context
   - Understands current state
   - Proposes next steps
   - You confirm and proceed

**During the Session**:

1. **Work on Tasks**
   - Complete tasks from todo list
   - Write code, tests, documentation

2. **Update Tasks Doc** (every 30-60 minutes)
   - Mark completed tasks as ✅
   - Update in-progress tasks with progress
   - Add newly discovered tasks
   - Update time estimates

3. **Make Notes in Context** (as you go)
   - Add to "Recent Changes" when files modified
   - Note key decisions in "Key Decisions Made"
   - Track bugs in "Manual Testing Done"
   - Update "Current Working Context" with where you are

**At END of Each Session** (5-10 minutes):

1. **Update Context Document**:
   ```bash
   # Open context file
   code dev/active/recipe-sharing/recipe-sharing-context.md
   ```

2. **Update Critical Sections**:
   - ✅ **"Current Status Summary"** - What's complete/in-progress/pending
   - ✅ **"Recent Changes"** - All files modified this session
   - ✅ **"Current Working Context"** - EXACTLY where you stopped
   - ✅ **"Next Immediate Steps"** - First 3 actions for next session
   - ✅ **"Open Questions"** - Any blockers or uncertainties

3. **Update Date Stamps**:
   - Update "Last Updated" at top
   - Update "Last Session End" timestamp

4. **Quick Resume Instructions**:
   - Write one paragraph at bottom explaining how to resume
   - Be VERY specific about what file, what line, what to do

**Example End-of-Session Update**:
```markdown
### Current Working Context

#### What I Was Just Doing
Implementing the `shareRecipeWithFriends()` method in RecipeSharingService.
Was adding permission validation to ensure user owns the recipe before sharing.

**Specific Code Location**:
- File: `lib/services/recipe_sharing_service.dart`
- Line: ~147
- Function: `shareRecipeWithFriends(String recipeId, List<String> friendIds)`

**Where I Left Off**:
Just finished permission check. Next need to create FirebaseSharedRecipe
documents for each friend. The loop structure is outlined but not implemented.

#### Next Immediate Steps
1. **First**: Complete the friend loop in shareRecipeWithFriends()
   - File: `lib/services/recipe_sharing_service.dart:150`
   - Action: For each friendId, create SharedRecipe document with permissions

2. **Then**: Add error handling for the batch operation
   - Use ErrorHandlingMixin.safeExecuteBatch()
   - Handle partial failures gracefully

3. **After That**: Write service tests
   - File: `test/unit/services/recipe_sharing_service_test.dart`
   - Test: shareRecipeWithFriends with various scenarios
```

---

### Phase 3: Completing a Feature

**When All Tasks Done**:

1. **Final Context Update**
   - Mark all sections as ✅ Complete
   - Document any technical debt introduced
   - Note any deferred tasks

2. **Move to Completed**
   ```bash
   mv dev/active/recipe-sharing dev/completed/
   ```

3. **Create Summary** (optional)
   - Add "COMPLETED.md" with:
     - What was built
     - Lessons learned
     - Known limitations
     - Future enhancement ideas

---

## Document Responsibilities

### [feature]-plan.md (The Blueprint)

**Update Frequency**: Rarely (only when scope changes)

**Purpose**: Long-term reference for what and why

**Key Sections**:
- Overview and user story
- Architecture design
- Technical decisions
- Implementation phases

**When to Update**:
- Scope changes
- Major architectural pivots
- New dependencies added
- Testing strategy evolves

---

### [feature]-context.md (The State Snapshot)

**Update Frequency**: Every session

**Purpose**: "Where we are right now"

**Key Sections**:
- Current status summary
- Recent changes
- Current working context
- Next immediate steps

**When to Update**:
- **At end of every session** (critical!)
- When making key decisions
- When discovering blockers
- When changing approach

**Most Important Sections**:
1. **Current Working Context** - WHERE you stopped
2. **Next Immediate Steps** - WHAT to do next
3. **Recent Changes** - WHAT files were modified

---

### [feature]-tasks.md (The Todo List)

**Update Frequency**: Multiple times per session

**Purpose**: Granular task tracking with progress

**Key Sections**:
- High/medium/low priority tasks
- Layer-specific tasks (Repository, Service, ViewModel, UI, Testing)
- Time tracking
- Dependencies

**When to Update**:
- Task completed
- Task started
- Task blocked
- New task discovered
- Estimates changed

---

## Best Practices

### 1. Be Obsessively Specific in Context

**Bad** ❌:
```markdown
#### What I Was Just Doing
Working on the service layer.
```

**Good** ✅:
```markdown
#### What I Was Just Doing
Implementing validation logic in RecipeSharingService.shareRecipe().
Specifically, adding check to verify recipe ownership before allowing share.

**Specific Code Location**:
- File: `lib/services/recipe_sharing_service.dart`
- Line: 147
- Function: `shareRecipe(String recipeId, List<String> friendIds)`

**Where I Left Off**:
Permission check implemented. Next step is creating the SharedRecipe
documents in a batch operation. The _createSharedRecipeDocuments() helper
method is stubbed but not implemented yet.
```

### 2. Update Context BEFORE Session Ends

Don't rely on memory after session ends. Update while context is fresh.

**Workflow**:
1. Save all code files
2. IMMEDIATELY update context file
3. Verify context makes sense
4. THEN end session

### 3. Link Between Documents

In **context.md**, reference plan:
```markdown
See [recipe-sharing-plan.md](recipe-sharing-plan.md#architecture-design)
for architecture decisions.
```

In **tasks.md**, reference context:
```markdown
See [recipe-sharing-context.md](recipe-sharing-context.md#current-working-context)
for current implementation state.
```

### 4. Use Checklists Liberally

Checklists are easy to scan and update:
```markdown
**Repository Layer**:
- [x] Create FirebaseSharedRecipeRepository
- [x] Implement CRUD operations
- [x] Add permission validation
- [ ] Write repository tests
- [ ] Add custom query methods
```

### 5. Track Decisions and Rationale

When making architectural decisions, document WHY:
```markdown
### Key Decisions Made

1. **Decision**: Use BaseFirebaseRepository<SharedRecipe>
   - **Rationale**: Standard CRUD + permission validation built-in
   - **Alternative Considered**: Custom repository from scratch
   - **Why Rejected**: Would duplicate 80% of BaseFirebaseRepository code

2. **Decision**: Store shared recipes in top-level collection, not subcollection
   - **Rationale**: Enables efficient querying across all users
   - **Alternative Considered**: Subcollection under users/{userId}/shared_recipes
   - **Why Rejected**: Can't query across all users efficiently
```

### 6. Maintain Task Dependencies

Use dependency tracking to avoid working on tasks in wrong order:
```markdown
### Task V1: Create ViewModel
- **Dependencies**: S2 (Service implementation must be complete first)
- **Status**: ⏸️ Blocked (waiting for S2)
```

### 7. Time Box Planning Sessions

- **Plan creation**: 30-60 minutes
- **End-of-session context update**: 5-10 minutes
- **Start-of-session context review**: 2-3 minutes

If taking longer, you're over-thinking. Iterate and refine over time.

---

## Templates Quick Reference

### feature-plan-template.md Sections
1. Overview (Purpose, User Story, Success Criteria)
2. Scope (In/Out of Scope, Dependencies)
3. Architecture Design (Layers, Data Flow, Firebase Structure)
4. Technical Decisions (Patterns, Infrastructure, Security)
5. Implementation Phases (6 phases with estimates)
6. Testing Strategy (Unit, Integration, Manual)
7. Risks & Mitigation
8. Rollout Plan
9. Documentation
10. Future Enhancements

### feature-context-template.md Sections
1. Current Status Summary
2. Recent Changes
3. Current Implementation State (by layer)
4. **Current Working Context** (most important!)
5. **Next Immediate Steps** (most important!)
6. Open Questions & Blockers
7. Testing Notes
8. Dependencies & Integration
9. Performance & Security
10. Firebase Structure

### feature-tasks-template.md Sections
1. Quick Status (progress overview)
2. High/Medium/Low Priority Tasks
3. Layer-Specific Tasks (Repository, Service, ViewModel, UI)
4. Testing Tasks
5. Polish & Documentation
6. Blocked/Completed/Deferred Tasks
7. Task Dependencies Diagram
8. Time Tracking

---

## Example: Real Workflow

### Session 1: Planning (1 hour)
```bash
# Create feature docs
mkdir -p dev/active/offline-sync
cd dev/active/offline-sync

# Copy templates
cp .claude/templates/feature-plan-template.md offline-sync-plan.md
cp .claude/templates/feature-context-template.md offline-sync-context.md
cp .claude/templates/feature-tasks-template.md offline-sync-tasks.md

# Fill out plan with Claude's help
code offline-sync-plan.md
# ... spend 45 minutes filling in architecture, decisions, phases ...

# Initialize context and tasks
code offline-sync-context.md
# ... mark everything as "Not Started", set phase to "Planning" ...

code offline-sync-tasks.md
# ... break down phases into specific tasks with estimates ...
```

### Session 2: Start Implementation (2 hours)
```bash
# At start: Review context
cat dev/active/offline-sync/offline-sync-context.md

# Tell Claude
"I'm starting offline-sync feature.
Read: dev/active/offline-sync/offline-sync-context.md
Let's begin with first task: creating OfflineRepository"

# Work for 2 hours, updating tasks as you go

# At end: Update context
code dev/active/offline-sync/offline-sync-context.md
```

Update:
```markdown
#### Current Working Context
Created OfflineRepository extending BaseFirebaseRepository.
Implemented getOfflineRecipes() and saveOfflineRecipe() methods.
Added permission checks.

**Where I Left Off**:
File: lib/repositories/offline_repository.dart:87
Just finished saveOfflineRecipe(). Next need to add syncToFirebase() method.

#### Next Immediate Steps
1. Add syncToFirebase() method to batch-sync offline recipes
2. Write repository tests
3. Create OfflineService to orchestrate repo operations
```

### Session 3: Resume (90 minutes)
```bash
# At start
cat dev/active/offline-sync/offline-sync-context.md

# Tell Claude
"Resume offline-sync feature.
Read context: dev/active/offline-sync/offline-sync-context.md
Focus on 'Current Working Context' section.
Let's continue where we left off with syncToFirebase()."

# Claude knows exactly where to continue!
```

---

## Troubleshooting

### Problem: Context file too long to read

**Solution**: Use sections strategically
```
Read only:
- Current Status Summary
- Current Working Context
- Next Immediate Steps
```

### Problem: Forgetting to update context

**Solution**: Add to session checklist
```markdown
## End of Session Checklist
- [ ] Save all code files
- [ ] Update context.md (Current Working Context!)
- [ ] Update context.md (Next Immediate Steps!)
- [ ] Update tasks.md with completed tasks
- [ ] Commit code changes
```

### Problem: Too much detail, takes too long

**Solution**: Focus on the essentials
- **Current Working Context**: 3-5 sentences
- **Next Immediate Steps**: 3 specific actions
- **Recent Changes**: List files, brief "why"

### Problem: Multiple features in parallel

**Solution**: Use separate directories
```
dev/active/
├── offline-sync/      # Feature 1
├── recipe-sharing/    # Feature 2
└── user-profiles/     # Feature 3
```

Update one at a time, keep them independent.

---

## Tips for Success

1. **Treat context.md as sacred** - Always update before ending session
2. **Be specific about code location** - File, line, method name
3. **Describe the EXACT next action** - "Open X file, add Y method"
4. **Use timestamps** - Know when context was last updated
5. **Link related decisions** - Connect context to plan sections
6. **Track time** - Compare estimates to actuals, improve estimation
7. **Celebrate completions** - Move completed features to completed/
8. **Review weekly** - Are dev docs helping? Adjust process.

---

## Integration with Claude Code

### At Session Start
```
Resume work on [feature-name] feature.

Please read:
- dev/active/[feature-name]/[feature-name]-context.md

Focus on:
- Current Working Context (where I stopped)
- Next Immediate Steps (what to do next)

Confirm you understand where we are, then let's continue.
```

### During Session
```
Update the context doc with this decision:
[Decision details]

Add to "Key Decisions Made" section.
```

### At Session End
```
Help me update the context file for next session.

Current state:
- Just finished implementing X
- Stopped at file Y, line Z
- Next steps are: A, B, C

Update:
- Current Working Context
- Next Immediate Steps
- Recent Changes (I modified files: ...)
```

---

## Summary

**Dev Docs System = 3 Documents**:
1. **Plan** - The blueprint (rarely changes)
2. **Context** - The snapshot (updated every session)
3. **Tasks** - The checklist (updated frequently)

**Critical Habit**:
- **Before ending session**: Update context with WHERE you stopped and WHAT's next
- **Before starting session**: Read context to understand WHERE you are

**Result**:
- Zero context loss across sessions
- Faster ramp-up time
- Consistent implementation approach
- Better collaboration across team members

---

**Created**: 2025-01-31
**Last Updated**: 2025-01-31
**Status**: Ready for use
