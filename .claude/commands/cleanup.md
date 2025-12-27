---
description: Scan for dead code, unused files, and documentation drift
argument-hint: [optional: path or category to focus on]
---

Systematically scan for cleanup opportunities in this codebase. Focus on:

1. **Dead Code Analysis**
   - Unused imports and variables
   - Unreferenced functions and classes
   - Deprecated code still present

2. **File Hygiene**
   - Empty or near-empty files
   - Duplicate implementations
   - Orphaned test files (testing deleted code)

3. **Documentation Drift**
   - .md files describing removed features
   - README files for deleted directories
   - Outdated implementation plans
   - V1/V2 version files that should be consolidated

4. **Migration Cleanup**
   - Completed migration files still present
   - Debug/troubleshooting docs for resolved issues
   - Temporary files or experiments

If a path/category argument is provided, focus only on that area: $ARGUMENTS

Create a structured report with:
- Total cleanup opportunities found
- Categorized list of items to remove
- Estimated impact (files/lines to remove)
- Recommended cleanup order

Ask: "Should I proceed with the cleanup? (all / category / skip)"
