---
description: Run Flutter analyze and create todo list for all issues, warnings, and infos
argument-hint: (no arguments required)
---

You are going to run Flutter analyze and create a structured todo list for all issues found.

First, run Flutter analyze using the correct WSL command:
```bash
cd /mnt/c/Butlery/butlery && cmd.exe /c "flutter analyze"
```

Then, create a todo list file `/tasks/todo_analyze.md` that includes:

1. **📊 ANALYSIS SUMMARY**: Total count of issues by type (errors, warnings, infos)
2. **🚨 ERRORS**: List all errors that prevent compilation
3. **⚠️ WARNINGS**: List all warnings that should be addressed  
4. **ℹ️ INFOS**: List all info suggestions for code improvement
5. **📁 FILE BREAKDOWN**: Group issues by file for easier navigation

Format each issue as a checkable todo item with:
- [ ] **File:Line** - Issue description (rule_name)

After creating the todo list, ask the user:
"Would you like me to create a detailed plan to fix all these issues and replace this todo list with a comprehensive remediation strategy?"

Focus on being systematic and actionable - organize issues by priority and file location for efficient resolution.