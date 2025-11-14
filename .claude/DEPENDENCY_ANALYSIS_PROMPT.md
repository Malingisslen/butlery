# Comprehensive Dependency Analysis - Execution Prompt

## Objective
Conduct a complete dependency analysis of the `/lib` directory to identify opportunities for code streamlining, elimination of single-use or low-use code, and overall reduction of codebase complexity. The goal is to ensure every file and class justifies its existence and cannot be simplified, merged, or eliminated.

## Analysis Goals
1. **Identify Low-Usage Code**: Find files/classes used by only 1-3 other files
2. **Find Merge Opportunities**: Locate small, related files that could be consolidated
3. **Detect Dead/Orphaned Code**: Identify code with zero or near-zero usage
4. **Uncover Duplication**: Find similar functionality across multiple files
5. **Validate Abstractions**: Ensure interfaces/base classes have sufficient implementations to justify existence
6. **Streamline Dependencies**: Identify unnecessary dependency chains and circular dependencies

## Analysis Strategy (Token-Efficient Phased Approach)

### Phase 1: Automated Dependency Mapping
**Tools**: Use `Grep` with `-C` context to build dependency graph
**Steps**:
1. Generate file inventory: `Glob` pattern `lib/**/*.dart`
2. For each layer (bottom-up to minimize token usage):
   - Extract imports using `Grep` pattern: `^import 'package:butlery/`
   - Count usage of each file by searching for its imports
   - Store results in structured markdown tables

**Deliverable**: Dependency matrix showing:
- File path
- Number of files importing it (usage count)
- List of dependents
- File size (lines of code)
- Layer (repository/service/viewmodel/widget/utility)

### Phase 2: Low-Usage Analysis (Bottom Layer First)
**Focus**: Files with usage count ≤ 3
**Process**:
1. Start with utilities and helpers (most likely candidates)
2. Then models and extensions
3. Then repositories
4. Then services
5. Then viewmodels
6. Finally widgets

**For each low-usage file**:
- Read the file
- Read the 1-3 files that use it
- Analyze:
  - Can functionality be inlined into dependent file?
  - Can it be merged with a similar utility?
  - Is the abstraction necessary or premature?
  - Does it violate YAGNI (You Aren't Gonna Need It)?

**Deliverable**: Table of recommendations:
| File | Usage Count | Recommendation | Rationale | Effort |
|------|-------------|----------------|-----------|--------|

### Phase 3: Small File Consolidation Analysis
**Focus**: Files < 100 lines with related functionality
**Process**:
1. Use `Bash` to list files by size: `find lib -name "*.dart" -exec wc -l {} + | sort -n`
2. Group small files by directory/feature
3. For each group, assess if consolidation makes sense

**Deliverable**: Consolidation proposals with before/after structure

### Phase 4: Abstraction Validation
**Focus**: Base classes, interfaces, mixins
**Process**:
1. Find all abstract classes: `Grep` pattern `^abstract class`
2. Find all mixins: `Grep` pattern `^mixin `
3. For each abstraction:
   - Count implementations/usages
   - If ≤ 2 implementations: Analyze if abstraction is premature
   - Recommend: Keep, Simplify, or Remove

**Deliverable**: Abstraction review table

### Phase 5: Duplication Detection
**Focus**: Similar functionality across files
**Process**:
1. Review files in same layer/domain with similar names
2. Use `Task` tool with `subagent_type=Explore` for semantic similarity search
3. Focus on:
   - Multiple "manager" classes doing similar things
   - Multiple "helper" classes with overlapping utilities
   - Multiple "service" classes with similar patterns

**Deliverable**: Duplication matrix with merge proposals

### Phase 6: Circular Dependency Check
**Focus**: Identify and break circular dependencies
**Process**:
1. From Phase 1 dependency matrix, identify circular chains
2. For each circle:
   - Analyze which dependency can be removed
   - Recommend inversion of control or interface extraction

**Deliverable**: Circular dependency report with resolution strategy

### Phase 7: Final Recommendations & Roadmap
**Consolidate all findings into**:
1. **High-Priority Actions** (effort < 2 hours, high impact)
   - File deletions (dead code)
   - Simple merges
2. **Medium-Priority Actions** (effort 2-8 hours, medium impact)
   - Abstraction removals
   - Small refactorings
3. **Low-Priority Actions** (effort > 8 hours, low impact)
   - Large consolidations
   - Major restructuring

**Deliverable**: Prioritized action plan with:
- Specific file operations (delete, merge, refactor)
- Estimated LOC reduction
- Risk assessment
- Test impact analysis

## Token Management Strategy
- **Phase 1**: Single Task agent with file list processing
- **Phase 2-6**: Process in batches of 10-20 files per session
- **Between phases**: Save results to markdown files in `.claude/analysis/`
- **Use TodoWrite**: Track progress across multiple sessions
- **Incremental commits**: Commit analysis results after each phase

## Success Metrics
- **Target**: Reduce `/lib` directory by 10-15% LOC
- **Quality**: No functionality loss
- **Maintainability**: Fewer files with clearer responsibilities
- **Test Coverage**: Maintained or improved

## Execution Instructions
When running this analysis:
1. Start with Phase 1 to build the foundation
2. Use `TodoWrite` to track phases as you progress
3. Save intermediate results to `.claude/analysis/dependency_analysis_phaseN.md`
4. After each phase, summarize findings and ask user if they want to proceed or pivot
5. Be ruthless about questioning the value of each piece of code
6. Follow Butlery architecture patterns (MVVM, Repository, DI modules)
7. Consult `CLAUDE.md` for project-specific patterns and standards

## Starting the Analysis
To begin, use this prompt:
```
I want to execute the Comprehensive Dependency Analysis as defined in .claude/DEPENDENCY_ANALYSIS_PROMPT.md.
Start with Phase 1: Automated Dependency Mapping for the /lib directory.
Use the Task tool with subagent_type=Explore to efficiently gather the dependency data.
Save results to .claude/analysis/dependency_analysis_phase1.md and report findings.
```

---
**Created**: 2025-11-12
**Purpose**: Guide systematic dependency analysis to streamline Butlery codebase
**Estimated Total Effort**: 8-16 hours across multiple sessions
