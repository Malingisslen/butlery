---
allowed-tools: Bash, Read, Edit, MultiEdit, Glob, Grep
description: Automatically update all documentation files based on recent code changes
---

# Auto-Documentation Update Command

You are tasked with automatically updating all documentation files in this Flutter project based on code changes since last git commit. This includes CLAUDE.md, and all files in the /docs directory.

## Your Task

1. **Detect Code Changes**: Use `git diff HEAD~1..HEAD` and `git status` to identify what files have been modified, added, or removed since the last commit.

2. **Analyze Changes**: For each changed file, understand:
   - New services, models, or viewmodels added
   - Updated architecture patterns
   - New features or functionality
   - Changed dependencies or configurations
   - Modified Flutter/Firebase integrations

3. **Update Documentation Files**:

   **CLAUDE.md**: Update with:
   - Summary of the current aim and state of the project

   **docs/ files**: Update relevant documentation:
   - PROJECT_PLAN.md: Update progress and completed features
   - development_guide.md: Add new development patterns or processes
   - firebase_architecture_guide.md: Update if Firebase integration changed
   - Any other relevant docs based on the changes

4. **Flutter-Specific Considerations**:
   - This is a Flutter project using MVVM + Repository pattern
   - Firebase integration for authentication, storage, and social features
   - Social features (friends, groups, collaborative editing)
   - Real-time synchronization capabilities
   - Shopping list and recipe management features
   - WSL environment with Windows Flutter commands

5. **Preserve Existing Structure**: 
   - Keep existing documentation organization
   - Maintain current formatting and style
   - Only add or update sections that relate to the detected changes
   - Don't remove existing content unless it's clearly obsolete

6. **Focus Areas Based on Project Structure**:
   - lib/services/: New or updated services
   - lib/models/: New data models or schema changes
   - lib/viewmodels/: New UI logic or state management
   - lib/repositories/: Data layer changes
   - lib/views/: New UI components or screens
   - Firebase configuration changes
   - Dependencies in pubspec.yaml

## Important Notes

- Only update documentation if actual code changes are detected
- Be specific about what changed and why it matters
- Maintain the professional tone of existing documentation
- If no significant changes are found, report that documentation is up to date
- Focus on architectural and feature changes rather than minor bug fixes
- Respect the 500-line file size limit mentioned in CLAUDE.md

Start by analyzing recent changes and then systematically update each documentation file as needed.