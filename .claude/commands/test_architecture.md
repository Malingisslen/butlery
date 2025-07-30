---
description: Run Code Intelligence Platform analysis and provide actionable summary with fixing plan
argument-hint: (no arguments required)
---

You are going to run the revolutionary Code Intelligence Platform and provide a comprehensive summary of the results with an actionable fixing plan.

First, run the Code Intelligence Platform:
```bash
cd /mnt/c/Butlery/butlery && cmd.exe /c "dart tools/code_intelligence_platform.dart"
```

Then, read and analyze the results from `tools/results/code_intelligence_report.json` and provide:

1. **🏆 HEALTH SUMMARY**: Overall health score and dimensional scores (Security, Performance, Architecture, Quality)
2. **🚨 CRITICAL ISSUES**: List critical violations requiring immediate attention (security risks, performance issues)
3. **📊 VIOLATION BREAKDOWN**: Summary by severity and category (Security, Performance, Architecture, Quality, Predictive)
4. **🎯 ACTIONABLE PLAN**: Prioritized remediation roadmap with specific steps and effort estimates
5. **💡 STRATEGIC RECOMMENDATIONS**: Multi-dimensional improvements and architectural guidance
6. **🔮 PREDICTIVE INSIGHTS**: Bug hotspots and maintenance burden forecasts

Format the response clearly with emojis and be specific about which files need attention and what actions to take.

Focus on being actionable with reality-based assessments - tell me exactly what to fix and in what order based on the multi-dimensional analysis.