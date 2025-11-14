# ULTIMATE BUTLERY DEPENDENCIES & SUPPLY CHAIN SECURITY ANALYSIS PROMPT

**Copy and paste this entire prompt to Claude to trigger the most comprehensive dependency security investigation.**

---

## Mission: Secure & Maintainable Dependency Stack

Perform the most thorough, uncompromising third-party dependency and supply chain security analysis of the Butlery Flutter application. The goal is to achieve **dependency security excellence** with:
- Zero known vulnerabilities (CVEs)
- Current, actively maintained packages
- Clean license compliance (commercial-safe)
- Minimal dependency bloat
- Secure supply chain practices
- Clear upgrade paths
- Documented security policies

This is not a superficial dependency check. This is a **comprehensive supply chain security audit** across 7 critical dimensions.

---

## ⚠️ CRITICAL: TWO-PHASE APPROACH - READ CAREFULLY

This analysis follows a **strict two-phase approach**:

### PHASE 1: INVESTIGATION & DOCUMENTATION (Your Current Task)

**🚫 ABSOLUTELY NO DEPENDENCY CHANGES ALLOWED**

Your **ONLY** task is to:
1. **INVESTIGATE** - Thoroughly examine all dependencies and supply chain
2. **DOCUMENT** - Record every finding with package names and versions
3. **CATEGORIZE** - Classify issues by severity (Critical/High/Medium/Low)
4. **ESTIMATE** - Provide effort estimates and security risk levels

**DO NOT:**
- ❌ Update ANY dependencies
- ❌ Add ANY packages
- ❌ Remove ANY packages
- ❌ Modify pubspec.yaml
- ❌ Run pub upgrade
- ❌ Even suggest "let me update this quickly"

**Your output is a COMPREHENSIVE DEPENDENCY SECURITY REPORT** - nothing else.

### PHASE 2: SMART UPGRADE & REMEDIATION PLAN (After Documentation Complete)

**Only after Phase 1 is 100% complete**, you will:
1. **ANALYZE** all documented findings together
2. **PRIORITIZE** by security risk, breaking change impact, and effort
3. **GROUP** related upgrades for efficient batch updates
4. **CREATE** upgrade strategies with rollback plans
5. **SEQUENCE** updates to minimize breaking changes

**This is a separate step that happens AFTER all investigation is done.**

---

## Why This Approach?

✅ **Complete Picture**: See ALL dependency issues before deciding what to upgrade
✅ **Smart Prioritization**: Understand breaking change cascades before updating
✅ **Risk Management**: Sequence upgrades to minimize production issues
✅ **License Compliance**: Identify all license concerns before using packages
✅ **Better Decisions**: Full context before making dependency changes

**Remember: Investigation first, action later. Document everything, change nothing.**

---

## Analysis Framework: 7 Dependency Dimensions

### 1. VULNERABILITY SCANNING & CVE ANALYSIS (Weight: 25%)

**Gold Standard:** Zero known vulnerabilities, active vulnerability monitoring.

**Investigate:**

1. **Known Vulnerabilities (CVEs)**
   - Run `flutter pub audit` or check pub.dev for security advisories
   - Cross-reference with National Vulnerability Database (NVD)
   - Identify packages with known CVEs
   - Check vulnerability severity (CVSS score)
   - Verify if fixes are available (patched versions?)

2. **Transitive Dependencies**
   - Run `flutter pub deps` to see full dependency tree
   - Identify vulnerable transitive dependencies
   - Check if vulnerabilities can be mitigated by direct dep upgrade
   - Verify no conflicting version constraints preventing fixes

3. **Security Advisory Sources**
   - Check pub.dev security advisories for each package
   - Review GitHub Security Advisories for Dart packages
   - Check for Dependabot alerts (if repo on GitHub)
   - Verify CVE databases for Dart ecosystem

4. **Historical Vulnerability Patterns**
   - Check if package has history of vulnerabilities
   - Review maintainer response time to security issues
   - Verify security disclosure process exists
   - Check for proactive security audits

**Output Required:**
- List of ALL packages with known CVEs (with severity scores)
- Vulnerability details (CVE IDs, CVSS scores, exploitability)
- Patches available (upgrade path to fix?)
- Transitive dependency vulnerabilities
- Security risk assessment for each vulnerability
- Upgrade complexity and effort estimates

---

### 2. VERSION CURRENCY & MAINTENANCE STATUS (Weight: 20%)

**Gold Standard:** All packages current within 1-2 minor versions, actively maintained.

**Investigate:**

1. **Version Currency**
   - List all dependencies from pubspec.yaml
   - Check latest version for each package (pub.dev)
   - Calculate version lag:
     - Minor version behind (e.g., 2.3.0 vs. 2.5.0) - OK
     - Major version behind (e.g., 2.x vs. 4.x) - RISK
     - Multiple major versions behind (e.g., 2.x vs. 6.x) - CRITICAL
   - Identify packages >2 major versions behind

2. **Maintenance Status**
   - Check last update date for each package
   - Verify package actively maintained:
     - Updated in last 6 months - Active
     - 6-12 months - Monitor
     - >12 months - At Risk
     - >24 months - Abandoned
   - Check commit frequency on GitHub
   - Review open issues and PR responsiveness

3. **Deprecation Status**
   - Check for deprecated packages (marked on pub.dev)
   - Verify recommended alternatives exist
   - Identify packages marked "discontinued"
   - Check Flutter/Dart SDK deprecation notices

4. **Breaking Changes**
   - Review CHANGELOG.md for breaking changes in newer versions
   - Identify breaking changes preventing upgrade
   - Assess migration complexity for major version upgrades
   - Check for automated migration tools (e.g., `dart fix`)

**Output Required:**
- Complete dependency list with current vs. latest versions
- Maintenance status for each package (active/at-risk/abandoned)
- Deprecated/discontinued packages with alternatives
- Breaking change impact assessment
- Upgrade priority ranking
- Effort estimates for version upgrades

---

### 3. LICENSE COMPLIANCE & LEGAL RISK (Weight: 18%)

**Gold Standard:** All licenses commercial-safe, clearly documented, compliant with EU/US regulations.

**Investigate:**

1. **License Inventory**
   - List all dependencies and their licenses
   - Categorize by license type:
     - ✅ Permissive (MIT, BSD, Apache 2.0)
     - ⚠️ Weak Copyleft (LGPL, MPL)
     - ❌ Strong Copyleft (GPL, AGPL)
     - ⚠️ Custom/Proprietary
     - ❌ No License (all rights reserved)

2. **Commercial Use Compliance**
   - Verify all licenses allow commercial use
   - Check for GPL/AGPL (requires source disclosure)
   - Identify licenses requiring attribution
   - Verify compliance with license terms

3. **License Compatibility**
   - Check for license conflicts (GPL + proprietary)
   - Verify multi-license compliance
   - Review sublicensing requirements
   - Check for patent clauses (Apache 2.0 patent grant)

4. **Attribution Requirements**
   - Identify packages requiring attribution
   - Check if attribution file exists (LICENSES, NOTICE)
   - Verify in-app attribution screen (required for some licenses)
   - Review app store compliance (license disclosure)

**Output Required:**
- Complete license inventory with package names
- Commercial use compliance assessment
- GPL/AGPL packages (CRITICAL - requires source disclosure)
- Custom/proprietary licenses (legal review needed)
- Missing licenses (packages with no license info)
- Attribution requirements and current compliance
- Legal risk assessment
- Remediation recommendations

---

### 4. DEPENDENCY BLOAT & BUNDLE SIZE IMPACT (Weight: 15%)

**Gold Standard:** Minimal dependencies, no unused packages, each dependency justified.

**Investigate:**

1. **Dependency Necessity**
   - List all direct dependencies
   - Identify usage of each package in codebase (Grep)
   - Find unused dependencies (not imported anywhere)
   - Verify dev_dependencies not in dependencies

2. **Bundle Size Impact**
   - Estimate bundle size contribution of each package
   - Identify largest dependencies (>1MB compiled)
   - Check for heavy dependencies (ML models, large assets)
   - Verify tree-shaking effectiveness

3. **Redundant Functionality**
   - Find packages with overlapping functionality
   - Check for multiple implementations of same feature
   - Identify packages that could be replaced by lighter alternatives
   - Verify no duplicated utilities (multiple date/time packages)

4. **Alternative Packages**
   - For large dependencies, identify lighter alternatives
   - Check if functionality could be implemented directly (small utility)
   - Verify no over-engineering (using full package for one function)
   - Review pub.dev alternatives and comparisons

**Output Required:**
- Unused dependency list
- Bundle size impact ranking (largest contributors)
- Redundant package identification
- Lighter alternative recommendations
- Package removal opportunities
- Bundle size reduction potential
- Effort estimates for dependency cleanup

---

### 5. SECURITY PRACTICES & SUPPLY CHAIN INTEGRITY (Weight: 12%)

**Gold Standard:** Trusted packages, verified publishers, secure supply chain practices.

**Investigate:**

1. **Publisher Verification**
   - Check verified publisher status on pub.dev
   - Identify packages from trusted sources (Google, Flutter team, verified orgs)
   - Flag packages from unverified/unknown publishers
   - Review publisher reputation (downloads, pub points)

2. **Package Popularity & Trust**
   - Check package popularity (pub points, likes, downloads)
   - Review pub.dev score (health, maintenance, popularity)
   - Verify package has adequate documentation
   - Check for active community (issues, PRs, discussions)

3. **Supply Chain Security**
   - Verify packages use semantic versioning
   - Check for dependency pinning (version constraints)
   - Review pubspec.lock for unexpected changes
   - Verify no dependency confusion attacks possible

4. **Code Quality & Testing**
   - Check if packages have test coverage
   - Review package quality (pub.dev analysis score)
   - Verify CI/CD in place (automated testing)
   - Check for code review processes

**Output Required:**
- Unverified publisher packages (risk assessment)
- Low-reputation packages (pub points < 100)
- Supply chain risk factors
- Package trust scoring
- Recommendations for package replacement/vetting
- Effort estimates for supply chain improvements

---

### 6. PLATFORM COMPATIBILITY & SUPPORT (Weight: 5%)

**Gold Standard:** All packages support required platforms, no platform-specific issues.

**Investigate:**

1. **Platform Support Matrix**
   - Check platform support for each package (iOS, Android, web)
   - Verify packages support minimum SDK versions required
   - Identify platform-specific packages (only for one platform)
   - Check for null-safety migration status

2. **Flutter/Dart SDK Compatibility**
   - Verify packages compatible with current Flutter version
   - Check for Flutter SDK version constraints
   - Identify packages requiring older Flutter versions
   - Review Dart SDK constraints

3. **Native Dependencies**
   - Identify packages with native code (platform plugins)
   - Check native dependency requirements (CocoaPods, Gradle)
   - Verify native build configuration
   - Review platform-specific permissions required

**Output Required:**
- Platform compatibility matrix
- SDK compatibility issues
- Native dependency requirements
- Platform-specific concerns
- Compatibility risk assessment

---

### 7. UPGRADE PATH & MIGRATION STRATEGY (Weight: 5%)

**Gold Standard:** Clear upgrade paths, documented migrations, tested upgrade strategies.

**Investigate:**

1. **Upgrade Complexity**
   - Assess breaking change impact for each major upgrade
   - Identify dependency constraint conflicts
   - Check for cascade upgrades (updating A requires updating B, C, D)
   - Review migration guides availability

2. **Testing Requirements**
   - Identify packages requiring extensive testing after upgrade
   - Check for packages with behavior changes
   - Verify test coverage for affected code
   - Review integration test needs

3. **Rollback Strategy**
   - Verify ability to rollback upgrades
   - Check for data migration concerns (persistence formats)
   - Review production deployment strategy (gradual rollout?)
   - Assess risk of upgrade failure

**Output Required:**
- Upgrade complexity ranking (simple → complex)
- Breaking change cascades identified
- Migration guides available (or missing)
- Testing requirements for upgrades
- Rollback risk assessment
- Upgrade sequencing recommendations

---

## Investigation Execution Plan

**Remember: This is INVESTIGATION ONLY - Document findings, make NO changes.**

### Stage 1: Dependency Inventory & Automated Scanning (2-3 hours)
1. Extract all dependencies from pubspec.yaml
2. Run `flutter pub deps --style=compact` (full dependency tree)
3. Run `flutter pub audit` (vulnerability scan)
4. Check pub.dev for each package (version, license, status)
5. Document current dependency state

**Tools to use:** Read, Bash (pub commands), web searches (no pub upgrade)

### Stage 2: Deep Dependency Analysis (6-8 hours)

#### Vulnerability Audit (1.5 hours)
- Cross-reference CVE databases
- Check security advisories for each package
- Assess transitive dependency vulnerabilities
- **Document all vulnerabilities with severity**

#### Version & Maintenance Review (1.5 hours)
- Check latest version for each package
- Review maintenance status (last updated, activity)
- Identify deprecated/abandoned packages
- **Document version currency and maintenance concerns**

#### License Compliance Audit (1.5 hours)
- Extract licenses for all packages
- Categorize by license type
- Check commercial use compliance
- **Document license risks and compliance issues**

#### Dependency Bloat Analysis (1 hour)
- Search codebase for package usage
- Identify unused dependencies
- Estimate bundle size impact
- **Document bloat and cleanup opportunities**

#### Security Practices Review (1 hour)
- Check publisher verification status
- Review package reputation and trust
- Assess supply chain security
- **Document supply chain risks**

#### Compatibility & Upgrade Assessment (0.5 hours)
- Check platform compatibility
- Assess upgrade complexity
- **Document compatibility issues and upgrade paths**

### Stage 3: Dependency Security Report Compilation (2-3 hours)
- Compile ALL findings with risk assessments
- Classify every issue by severity
- Add effort estimates and upgrade complexity
- Create dependency health dashboard
- Generate executive summary with security score
- **Output: Complete dependency security document ready for Phase 2 planning**

**Total Investigation Time: 10-14 hours**

**Deliverable:** Comprehensive dependency security report. NO DEPENDENCY CHANGES.

---

## Output Format Required

### Executive Summary
```
BUTLERY DEPENDENCY & SUPPLY CHAIN SECURITY ANALYSIS - PHASE 1
===============================================================
Analysis Date: [Date]
Analyst: Claude (Sonnet 4.5)
Total Dependencies: X direct, Y transitive (Z total)
Flutter SDK: X.X.X | Dart SDK: X.X.X

OVERALL DEPENDENCY HEALTH SCORE: X/100
├─ Vulnerabilities (CVEs):      X/25 points
├─ Version Currency:             X/20 points
├─ License Compliance:           X/18 points
├─ Dependency Bloat:             X/15 points
├─ Security Practices:           X/12 points
├─ Platform Compatibility:       X/5 points
└─ Upgrade Path:                 X/5 points

SECURITY STATUS: [Secure | Needs Attention | Critical Vulnerabilities]

CRITICAL ISSUES: X found (active CVEs, GPL licenses, abandoned packages)
HIGH PRIORITY: X found (outdated packages, security risks, license concerns)
MEDIUM PRIORITY: X found (minor versions behind, bloat, compatibility)
LOW PRIORITY: X found (optimization opportunities)

KEY METRICS:
- Known CVEs: X packages (X critical, X high, X medium, X low)
- Abandoned Packages: X packages (last update >24 months ago)
- Major Versions Behind: X packages (>2 major versions outdated)
- GPL/AGPL Licenses: X packages (source disclosure required)
- Unused Dependencies: X packages
- Bundle Size Impact: XXmb from dependencies
```

### Detailed Findings by Dimension

[Same format as other analysis prompts with dependency-specific details]

### Complete Dependency Inventory

```markdown
## Direct Dependencies (from pubspec.yaml)

### Production Dependencies

| Package | Current | Latest | Gap | License | Pub Points | Last Updated | Status |
|---------|---------|--------|-----|---------|------------|--------------|--------|
| firebase_core | 2.24.2 | 2.27.0 | 2 minor | BSD-3 | 140/140 | 2 weeks ago | ✅ |
| cloud_firestore | 4.13.6 | 4.15.2 | 2 minor | BSD-3 | 140/140 | 1 week ago | ✅ |
| [package] | X.X.X | Y.Y.Y | Z major | [license] | XX/140 | X ago | ⚠️/❌ |
| [... all packages] |

### Dev Dependencies

[Same format for dev dependencies]

### Transitive Dependencies (Key Ones)

[List important transitive dependencies with same format]

## Vulnerability Report

### Critical Vulnerabilities (CVSS 9.0-10.0)
[None / List with CVE IDs, affected packages, exploit details]

### High Vulnerabilities (CVSS 7.0-8.9)
[List with details]

### Medium/Low Vulnerabilities (CVSS <7.0)
[List with details]

## License Compliance Matrix

### ✅ Permissive Licenses (Commercial-Safe)
- MIT: X packages
- BSD-3-Clause: Y packages
- Apache-2.0: Z packages
[List packages]

### ⚠️ Weak Copyleft (Review Required)
- LGPL: X packages [List packages]
- MPL: Y packages [List packages]

### ❌ Strong Copyleft (Source Disclosure Required)
- GPL: X packages [List packages - CRITICAL]
- AGPL: Y packages [List packages - CRITICAL]

### ⚠️ Other Concerns
- Custom Licenses: X packages [List - legal review needed]
- No License: X packages [List - CRITICAL]

## Dependency Health Dashboard

### Maintenance Status
- 🟢 Active (updated <6 months): X packages
- 🟡 Monitor (6-12 months): Y packages
- 🔴 At Risk (12-24 months): Z packages
- ⚫ Abandoned (>24 months): W packages

### Version Currency
- ✅ Current (0-1 minor behind): X packages
- ⚠️ Outdated (1-2 major behind): Y packages
- ❌ Severely Outdated (>2 major behind): Z packages

### Security Posture
- ✅ Verified Publishers: X packages
- ⚠️ Unverified Publishers: Y packages
- High Pub Points (>120): X packages
- Low Pub Points (<80): Y packages

## Upgrade Roadmap Complexity

### Simple Upgrades (No Breaking Changes)
[List packages with minor version upgrades]
**Effort:** X hours total

### Medium Complexity (Minor Breaking Changes)
[List packages with one major version upgrade]
**Effort:** X days total

### High Complexity (Multiple Major Versions)
[List packages requiring significant migration]
**Effort:** X days total
**Risk:** High (requires extensive testing)
```

### Initial Issue Grouping (For Phase 2 Planning)

```markdown
## Issues by Severity

### CRITICAL Dependencies Issues (X found)
- Known CVEs (exploitable vulnerabilities)
- GPL/AGPL licenses (requires source disclosure)
- Abandoned packages (no security updates)
- Packages with no license (legal risk)

**Estimated Total Effort**: X days
**Risk**: Critical (security, legal, stability)

### HIGH Priority Dependency Issues (X found)
- Packages >2 major versions behind
- Deprecated packages (no alternatives implemented)
- Vulnerable transitive dependencies
- Unverified high-risk publishers

**Estimated Total Effort**: X days
**Impact**: Security, stability, maintainability

### MEDIUM Priority Dependency Issues (X found)
- Minor version updates available
- Unused dependencies (bloat)
- Alternative lighter packages available
- Missing license attributions

**Estimated Total Effort**: X days

### LOW Priority Dependency Issues (X found)
- Dev dependency updates
- Documentation improvements
- Optimization opportunities

**Estimated Total Effort**: X hours

---

## Phase 2 Preparation

**Total Dependency Issues Found**: X
**Estimated Total Remediation Effort**: X days
**Breaking Change Risk**: [Low/Medium/High]
**License Compliance Status**: [Compliant/Needs Review/Non-Compliant]

**Next Steps (Phase 2):**
1. Analyze all findings together for upgrade cascades
2. Create dependency upgrade sequencing plan
3. Prioritize by security → legal → maintenance → optimization
4. Generate testing strategy for each upgrade
5. Create rollback plans for high-risk upgrades
6. Document license compliance actions required

**This dependency investigation is complete. Ready for Phase 2 smart upgrade planning.**
```

---

## Phase 1 Deliverables Checklist

**Investigation & Documentation Only - No Dependency Changes**

- [ ] Executive summary with overall dependency health score (out of 100)
- [ ] Detailed findings for all 7 dependency dimensions
- [ ] Complete dependency inventory (direct + transitive)
- [ ] Vulnerability report with CVE details
- [ ] License compliance matrix
- [ ] Version currency assessment
- [ ] Maintenance status for all packages
- [ ] Bundle size impact analysis
- [ ] Supply chain security assessment
- [ ] Platform compatibility matrix
- [ ] Upgrade complexity ranking
- [ ] Issue classification (Critical/High/Medium/Low) with counts
- [ ] Effort estimates for all upgrades/remediations
- [ ] Initial issue grouping by severity (for Phase 2 planning)

---

## Phase 1 Success Criteria

**This dependency investigation phase is complete when:**

1. ✅ All dependencies inventoried (direct + transitive)
2. ✅ All 7 dependency dimensions scored and documented
3. ✅ Vulnerability scan complete with CVE details
4. ✅ License compliance audit complete
5. ✅ Version currency assessed for every package
6. ✅ Maintenance status checked for all packages
7. ✅ Bundle size impact estimated
8. ✅ Supply chain security evaluated
9. ✅ All issues categorized by severity with counts
10. ✅ Upgrade complexity assessed
11. ✅ **ZERO dependency changes made** - documentation only
12. ✅ Phase 2 preparation complete (upgrade roadmap ready)

**Phase 1 Output:** Comprehensive dependency security report with upgrade roadmap.

**Phase 2 Input:** Use this report to create smart, sequenced upgrade and remediation plan.

---

## 🚀 BEGIN PHASE 1 DEPENDENCY INVESTIGATION NOW

**CRITICAL REMINDERS:**
- 🚫 **NO DEPENDENCY CHANGES** - Investigation and documentation ONLY
- 📋 Document every finding with package names and versions
- 🏷️ Categorize all issues by severity (Critical/High/Medium/Low)
- 🔒 Assess security risks (CVEs, supply chain, licenses)
- ⏱️ Provide effort estimates (hours/days) for upgrades
- 🎯 Follow all 7 dependency dimensions systematically
- ✅ Complete deliverables checklist before finishing

**Your Mission:**
Execute comprehensive dependency and supply chain security investigation. Scan for vulnerabilities, audit licenses, check maintenance status, assess upgrade paths. Document everything. Change nothing.

**This app's security depends on dependency health** - and this investigation is the security foundation.

**Phase 1 Goal:** A complete, detailed dependency security report ready for Phase 2 smart upgrade planning.
