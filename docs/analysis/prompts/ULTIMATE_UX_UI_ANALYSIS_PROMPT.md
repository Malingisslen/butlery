# ULTIMATE BUTLERY UX/UI QUALITY ANALYSIS PROMPT

**Copy and paste this entire prompt to Claude to trigger the most comprehensive UX/UI investigation.**

---

## Mission: World-Class User Experience Analysis

Perform the most thorough, uncompromising UX/UI analysis of the Butlery Flutter application. The goal is to achieve **world-class user experience** with:
- Intuitive, delightful user interactions
- Consistent visual design language
- Accessible to all users (WCAG 2.1 AA compliance)
- Responsive and adaptive layouts
- Smooth, performant animations
- Clear user feedback and error communication
- Effortless user flows
- Professional visual polish

This is not a superficial design review. This is a **comprehensive UX/UI audit** across 10 dimensions of user experience quality.

---

## ⚠️ CRITICAL: TWO-PHASE APPROACH - READ CAREFULLY

This analysis follows a **strict two-phase approach**:

### PHASE 1: INVESTIGATION & DOCUMENTATION (Your Current Task)

**🚫 ABSOLUTELY NO CODE OR DESIGN CHANGES ALLOWED**

Your **ONLY** task is to:
1. **INVESTIGATE** - Thoroughly examine all UI/UX aspects
2. **DOCUMENT** - Record every finding with file:line references and screenshots
3. **CATEGORIZE** - Classify issues by severity (Critical/High/Medium/Low)
4. **ESTIMATE** - Provide effort estimates for each improvement

**DO NOT:**
- ❌ Make ANY code edits
- ❌ Fix ANY UI issues
- ❌ Modify ANY designs
- ❌ Create ANY new components
- ❌ Change ANY styles
- ❌ Even suggest "let me fix this quickly"

**Your output is a COMPREHENSIVE UX/UI FINDINGS REPORT** - nothing else.

### PHASE 2: SMART DESIGN IMPROVEMENT PLAN (After Documentation Complete)

**Only after Phase 1 is 100% complete**, you will:
1. **ANALYZE** all documented findings together
2. **PRIORITIZE** by user impact, effort, and design system consistency
3. **GROUP** related UI improvements for efficient batch implementation
4. **CREATE** a smart, optimized design remediation plan
5. **SEQUENCE** improvements to maximize user value and minimize disruption

**This is a separate step that happens AFTER all investigation is done.**

---

## Why This Approach?

✅ **Complete Picture**: See ALL UX issues before deciding what to improve
✅ **Smart Prioritization**: Understand user impact and design system relationships
✅ **Efficient Planning**: Group related improvements, create consistent design
✅ **Risk Management**: Sequence changes to maintain user familiarity
✅ **Better Decisions**: Full UX context before making design changes

**Remember: Investigation first, action later. Document everything, change nothing.**

---

## Analysis Framework: 10 UX/UI Dimensions

### 1. DESIGN SYSTEM CONSISTENCY (Weight: 15%)

**Gold Standard:** Every screen follows a unified design language with consistent patterns, spacing, typography, and color usage.

**Investigate:**
1. **Component Consistency**
   - Find inconsistent button styles (different sizes, colors, shapes across screens)
   - Identify card design variations (should have unified CardWidget patterns)
   - Check dialog implementations (should use consistent dialog patterns)
   - Audit form field styles (consistent TextFormField styling)
   - Review list item designs (unified list tile patterns)

2. **Color Usage**
   - Verify theme color compliance (primary, secondary, accent usage)
   - Find hard-coded colors (should use theme colors)
   - Check color contrast ratios (WCAG AA: 4.5:1 for normal text, 3:1 for large text)
   - Identify inconsistent color meanings (e.g., red for delete vs. red for error)
   - Review dark mode support (if applicable)

3. **Typography & Text Styles**
   - Audit text style consistency (should use theme.textTheme)
   - Find hard-coded font sizes/weights
   - Check heading hierarchy (H1, H2, H3 equivalent usage)
   - Verify line height and letter spacing consistency
   - Review font family usage (consistent across app)

4. **Spacing & Layout**
   - Find magic number spacing (should use consistent spacing scale: 4, 8, 16, 24, 32)
   - Check padding/margin consistency across similar components
   - Verify alignment patterns (left, center, right usage)
   - Review whitespace usage (breathing room, visual hierarchy)

**Output Required:**
- List of design inconsistencies with file:line references and screenshots
- Component variations that should be unified
- Hard-coded values that should use design tokens
- Severity classification for each inconsistency
- Effort estimates for design system improvements

---

### 2. ACCESSIBILITY & INCLUSIVITY (Weight: 15%)

**Gold Standard:** WCAG 2.1 Level AA compliance. Usable by all users including those with visual, motor, hearing, and cognitive disabilities.

**Investigate:**
1. **Screen Reader Support**
   - Check Semantics widget usage for all interactive elements
   - Verify meaningful labels for images (Semantics label)
   - Ensure button purposes are clear to screen readers
   - Check navigation announcements
   - Verify form field labels and hints are announced

2. **Color Contrast**
   - Audit all text for WCAG AA compliance (4.5:1 normal, 3:1 large)
   - Check interactive element contrast (3:1 minimum)
   - Verify disabled state contrast (perceivable but clearly disabled)
   - Review error message visibility
   - Check placeholder text contrast

3. **Touch Target Sizes**
   - Verify minimum 44x44 logical pixels for all interactive elements
   - Check spacing between adjacent touch targets (8px minimum)
   - Review slider thumb sizes
   - Check checkbox/radio button sizes
   - Verify icon button sizes

4. **Keyboard Navigation** (for web/desktop)
   - Check focus indicators (visible focus state)
   - Verify tab order makes sense
   - Test keyboard shortcuts accessibility
   - Ensure all actions are keyboard accessible

5. **Motion & Animation**
   - Verify support for reduced motion preferences
   - Check autoplay animations can be paused
   - Review animation speeds (not too fast for comprehension)

**Output Required:**
- WCAG compliance report with specific violations
- Accessibility issues prioritized by user impact
- Components needing accessibility improvements
- Screen reader experience audit
- Touch target size violations
- Effort estimates for accessibility fixes

---

### 3. USER FLOWS & NAVIGATION (Weight: 15%)

**Gold Standard:** Intuitive navigation, minimal steps to complete tasks, clear user journeys with logical flow.

**Investigate:**
1. **Core User Journeys**
   - Recipe creation flow (how many steps? any friction points?)
   - Recipe discovery/search flow (efficient? intuitive?)
   - Shopping list creation (quick add? bulk operations?)
   - Menu planning flow (calendar interaction? drag-drop?)
   - Social sharing flow (share recipe, invite friends - seamless?)
   - User onboarding (first-time user experience - guided?)

2. **Navigation Patterns**
   - Bottom navigation clarity (labels clear? appropriate icons?)
   - Drawer navigation organization (logical grouping?)
   - Back button behavior (consistent? predictable?)
   - Deep linking support (share URLs work correctly?)
   - Breadcrumb trails (can users orient themselves?)

3. **Information Architecture**
   - Menu structure clarity (categories make sense?)
   - Search functionality (findable? effective filters?)
   - Content organization (logical grouping?)
   - User mental model alignment (matches user expectations?)

4. **Task Efficiency**
   - Count steps for common tasks (create recipe: X steps)
   - Identify unnecessary confirmation dialogs
   - Find repetitive data entry (could be auto-filled?)
   - Check for bulk operations (delete multiple items, share multiple recipes)
   - Review gesture support (swipe to delete, pull to refresh)

**Output Required:**
- User journey maps with friction points identified
- Step count analysis for core tasks (with optimization opportunities)
- Navigation confusion points with file:line references
- Information architecture issues
- Task efficiency improvements
- Effort estimates for flow optimizations

---

### 4. LOADING STATES & FEEDBACK (Weight: 10%)

**Gold Standard:** Users always know what's happening. No perceived delays. Clear feedback for all actions.

**Investigate:**
1. **Loading Indicators**
   - Check all async operations have loading states
   - Verify loading indicator consistency (same spinner/pattern)
   - Review skeleton screens usage (better UX than plain spinners)
   - Check loading state placement (contextual to content loading)
   - Verify loading state cancellation (user can cancel long operations)

2. **Progress Feedback**
   - Find long operations without progress indication
   - Check upload/download progress visibility
   - Review batch operation feedback (5 of 10 items processed)
   - Verify multi-step process progress (step 2 of 5)

3. **Action Feedback**
   - Check button press feedback (visual state change, haptic)
   - Verify success confirmations (toasts, snackbars, check marks)
   - Review form submission feedback (button disabled, loading state)
   - Check gesture feedback (swipe animations, pull-to-refresh)
   - Verify error feedback (clear, specific, actionable)

4. **Optimistic Updates**
   - Identify operations that could show immediate UI updates
   - Check for jarring loading → content flashes
   - Review rollback handling (if optimistic update fails)

**Output Required:**
- Missing loading states with file:line references
- Loading UX improvements (skeleton screens, progress indicators)
- Action feedback gaps
- Optimistic update opportunities
- Severity classification (user confusion impact)
- Effort estimates for feedback improvements

---

### 5. ERROR STATES & USER COMMUNICATION (Weight: 10%)

**Gold Standard:** Errors are clear, helpful, and guide users to resolution. Never blame the user.

**Investigate:**
1. **Error Message Quality**
   - Check error message clarity (technical jargon? user-friendly?)
   - Verify error messages provide solutions (not just "Error occurred")
   - Review error message tone (friendly? not blaming user?)
   - Check localization of error messages
   - Verify error message visibility (not buried in logs)

2. **Error State Design**
   - Audit empty states (helpful? actionable? inviting?)
   - Review error page designs (network error, 404, server error)
   - Check form validation error display (inline? clear? helpful?)
   - Verify error icon usage (consistent error iconography)
   - Review error color usage (red used consistently for errors)

3. **Input Validation**
   - Check real-time validation (as user types? on blur? on submit?)
   - Verify validation message helpfulness ("Email required" vs "Please enter your email")
   - Review validation timing (not too aggressive, not too late)
   - Check validation for all form fields
   - Verify validation clear on correction (error disappears when fixed)

4. **Recovery Flows**
   - Check retry mechanisms (easy to retry failed operations?)
   - Verify offline mode communication (clear when offline, auto-retry when back online)
   - Review data loss prevention (unsaved changes warnings)
   - Check undo functionality (can users undo mistakes?)

**Output Required:**
- Error message quality issues with examples
- Error state design improvements needed
- Form validation UX problems
- Recovery flow gaps
- User communication improvements
- Effort estimates for error UX improvements

---

### 6. FORM DESIGN & INPUT EXPERIENCE (Weight: 10%)

**Gold Standard:** Forms are effortless to fill, with intelligent defaults, smart validation, and minimal friction.

**Investigate:**
1. **Form Layout & Organization**
   - Check form field grouping (logical sections?)
   - Verify label placement (above field? inline? floating?)
   - Review field length appropriateness (text field width matches expected input)
   - Check multi-column form layouts (work on mobile?)
   - Verify form scrolling behavior (fields not obscured by keyboard)

2. **Input Types & Interactions**
   - Verify appropriate keyboard types (email keyboard for email, number pad for quantities)
   - Check date/time pickers (native? custom? intuitive?)
   - Review dropdown vs. autocomplete usage
   - Check file upload UX (drag-drop? preview? progress?)
   - Verify slider controls (appropriate for use case?)

3. **Smart Defaults & Autocomplete**
   - Check for intelligent defaults (pre-fill known data?)
   - Verify autocomplete support (browser autocomplete enabled?)
   - Review auto-capitalization appropriateness
   - Check auto-correction settings (appropriate for field type)

4. **Multi-step Forms**
   - Review wizard/stepper clarity (current step clear? progress visible?)
   - Check step validation (can't proceed with invalid data?)
   - Verify back navigation works (previous data preserved?)
   - Review form state persistence (data saved if user leaves?)

**Output Required:**
- Form UX issues with file:line references
- Input type improvements
- Field validation improvements
- Multi-step form optimization opportunities
- Smart default suggestions
- Effort estimates for form improvements

---

### 7. VISUAL HIERARCHY & READABILITY (Weight: 10%)

**Gold Standard:** Users can instantly understand page structure, scan content effortlessly, and find what they need.

**Investigate:**
1. **Content Hierarchy**
   - Check heading size progression (clear H1 → H2 → H3 hierarchy)
   - Verify visual weight matches importance (important items stand out)
   - Review use of bold, color, size to create hierarchy
   - Check section dividers (clear content separation)

2. **Readability**
   - Verify line length (45-75 characters for optimal reading)
   - Check line height (1.4-1.6 for body text)
   - Review text alignment (left-aligned for Western languages)
   - Verify paragraph spacing (adequate whitespace)
   - Check text contrast (4.5:1 minimum)

3. **Scannability**
   - Check for effective use of whitespace
   - Verify bullet points and lists usage (break up walls of text)
   - Review information density (not too crowded, not too sparse)
   - Check use of subheadings (break up long content)

4. **Visual Focus**
   - Verify clear focal points on each screen (where should eye go first?)
   - Check for visual clutter (too many competing elements?)
   - Review use of color to guide attention
   - Verify call-to-action prominence (clear primary actions)

**Output Required:**
- Visual hierarchy issues with file:line references
- Readability problems (contrast, line length, spacing)
- Content structure improvements
- Scannability enhancement opportunities
- Effort estimates for visual improvements

---

### 8. RESPONSIVE DESIGN & ADAPTABILITY (Weight: 8%)

**Gold Standard:** Perfect experience across all screen sizes, orientations, and form factors.

**Investigate:**
1. **Screen Size Adaptability**
   - Test layouts on small phones (320px width)
   - Test on standard phones (375px, 414px widths)
   - Test on tablets (768px+, landscape and portrait)
   - Check desktop/web layouts (if applicable)
   - Verify foldable device support (if applicable)

2. **Layout Flexibility**
   - Check for horizontal scrolling issues (should not happen)
   - Verify text wrapping (no text cutoff)
   - Review image scaling (maintains aspect ratio, no distortion)
   - Check grid/column layouts (appropriate for screen size)
   - Verify bottom navigation on small screens (not overlapping content)

3. **Orientation Handling**
   - Test portrait to landscape transitions (smooth? data preserved?)
   - Check landscape layout optimization (uses horizontal space well?)
   - Verify keyboard doesn't obscure critical content
   - Review video/media player landscape mode

4. **Platform Adaptations**
   - Verify iOS-specific patterns (if applicable)
   - Check Android-specific patterns (Material Design)
   - Review web-specific adaptations (if applicable)
   - Check platform-specific gestures (swipe back on iOS)

**Output Required:**
- Responsive layout issues by screen size
- Orientation handling problems
- Platform-specific UX gaps
- Components needing responsive improvements
- Effort estimates for responsive fixes

---

### 9. ANIMATION, TRANSITIONS & MICRO-INTERACTIONS (Weight: 7%)

**Gold Standard:** Smooth, purposeful animations that enhance understanding and delight users without causing distraction.

**Investigate:**
1. **Screen Transitions**
   - Check page navigation animations (smooth? too slow? too fast?)
   - Verify modal/dialog animations (slide up, fade in - consistent?)
   - Review bottom sheet transitions
   - Check tab switching animations

2. **Micro-interactions**
   - Verify button press animations (scale, ripple, color change)
   - Check toggle switch animations (smooth state change)
   - Review checkbox/radio animations
   - Verify pull-to-refresh animation (engaging?)
   - Check swipe gesture feedback

3. **Loading Animations**
   - Review spinner/progress indicator animations (smooth? not janky?)
   - Check skeleton loading animations (shimmer effect?)
   - Verify content fade-in animations (smooth appearance)

4. **Animation Performance**
   - Check for animation jank (60fps on all animations?)
   - Verify no animation-related performance issues
   - Review reduced motion support (respects user preferences)
   - Check animation cancellation (user can interrupt)

**Output Required:**
- Animation issues with file:line references
- Missing micro-interactions
- Animation performance problems
- Transition inconsistencies
- Effort estimates for animation improvements

---

### 10. COMPONENT LIBRARY & WIDGET REUSABILITY (Weight: 10%)

**Gold Standard:** Comprehensive component library with reusable, well-documented widgets that enforce design consistency.

**Investigate:**
1. **Widget Reusability**
   - Find duplicate widget implementations (should be unified)
   - Check for shared widget library (lib/widgets/)
   - Verify widget parameterization (flexible, not hardcoded)
   - Review widget composition (small, focused widgets)

2. **Component Library Completeness**
   - Audit available components:
     - Buttons (primary, secondary, text, icon buttons)
     - Cards (recipe card, list item card, info card)
     - Dialogs (confirmation, form, info dialogs)
     - Form fields (text, dropdown, date picker, etc.)
     - Lists (standard list, grid, swipeable list)
     - Navigation (bottom nav, drawer, app bar)
     - Feedback (snackbars, toasts, loading indicators)
   - Identify missing components (should be added to library)
   - Check for one-off implementations (should use library)

3. **Widget Documentation**
   - Verify widget documentation (usage examples? parameters explained?)
   - Check for widget showcase/style guide
   - Review widget naming clarity
   - Verify widget props documentation

4. **Design System Enforcement**
   - Check if components enforce design system (spacing, colors, typography)
   - Verify components reject invalid configurations
   - Review component API consistency (similar components have similar APIs)

**Output Required:**
- Duplicate widget implementations to consolidate
- Missing component library elements
- Widget reusability improvements
- Component documentation gaps
- Design system enforcement issues
- Effort estimates for component library improvements

---

## Investigation Execution Plan

**Remember: This is INVESTIGATION ONLY - Document findings, make NO changes.**

### Stage 1: Automated UI Analysis (2-3 hours)
1. Run Flutter analyze for UI-specific warnings
2. Audit all screens and major user flows
3. Generate widget inventory (list all custom widgets)
4. Screenshot capture for visual consistency analysis
5. Accessibility scanner run (if available)

**Tools to use:** Grep, Glob, Read, app inspection (no Edit, no Write)

### Stage 2: Manual UX Investigation (10-12 hours)

#### Design System Audit (2 hours)
- Audit color usage across all screens
- Review typography consistency
- Check spacing patterns
- Document component variations
- **Screenshot inconsistencies, document with file:line references**

#### Accessibility Review (2 hours)
- Screen reader testing (TalkBack/VoiceOver)
- Color contrast analysis
- Touch target size verification
- Keyboard navigation testing
- **Document WCAG violations with severity**

#### User Flow Analysis (2 hours)
- Walk through core user journeys
- Count steps for major tasks
- Identify friction points
- Review navigation patterns
- **Document flow issues with user impact assessment**

#### Interaction & Feedback Review (2 hours)
- Audit loading states
- Review error states and messages
- Check action feedback
- Test form interactions
- **Document missing feedback and UX gaps**

#### Visual & Layout Review (2 hours)
- Assess visual hierarchy
- Check readability
- Test responsive layouts (multiple screen sizes)
- Review animations and transitions
- **Document visual issues with screenshots**

#### Component Library Audit (2 hours)
- Inventory all custom widgets
- Identify duplicate implementations
- Check component reusability
- Review design system enforcement
- **Document consolidation opportunities**

### Stage 3: Comprehensive UX Report Compilation (2-3 hours)
- Compile ALL findings with screenshots
- Classify every issue by severity and user impact
- Add effort estimates for each improvement
- Create UX metrics dashboard
- Generate executive summary with overall UX score
- **Output: Complete UX/UI findings document ready for Phase 2 planning**

**Total Investigation Time: 14-18 hours**

**Deliverable:** Comprehensive UX/UI findings report with screenshots. NO DESIGN OR CODE CHANGES.

---

## Output Format Required

### Executive Summary
```
BUTLERY UX/UI QUALITY ANALYSIS - PHASE 1: INVESTIGATION FINDINGS
=================================================================
Analysis Date: [Date]
Analyst: Claude (Sonnet 4.5)
Platform: Flutter Mobile App
Screens Audited: ~X screens

OVERALL UX SCORE: X/100
├─ Design System Consistency:   X/15 points
├─ Accessibility:                X/15 points
├─ User Flows:                   X/15 points
├─ Loading States:               X/10 points
├─ Error Communication:          X/10 points
├─ Form Design:                  X/10 points
├─ Visual Hierarchy:             X/10 points
├─ Responsive Design:            X/8 points
├─ Animations:                   X/7 points
└─ Component Library:            X/10 points

USER EXPERIENCE STATUS: [World-Class | Good | Needs Improvement | Critical Issues]

CRITICAL ISSUES: X found (severe user impact)
HIGH PRIORITY: X found (significant UX friction)
MEDIUM PRIORITY: X found (polish opportunities)
LOW PRIORITY: X found (nice-to-have improvements)
```

### Detailed Findings by Dimension

For each of the 10 dimensions, provide:

```markdown
## [DIMENSION NAME] - Score: X/Y

### Summary
[2-3 sentence overview of UX findings for this dimension]

### Issues Found

#### CRITICAL Issues (Severe User Impact - Must Fix)
1. **[Issue Title]** - [Screen/File:Line]
   - User Impact: [How this affects user experience]
   - Current State: [Description + screenshot reference]
   - Expected State: [What it should be]
   - Accessibility Impact: [WCAG violation? User group affected?]
   - Effort: [Hours/Days]
   - Priority: CRITICAL

#### HIGH Priority Issues
[Same format as CRITICAL]

#### MEDIUM Priority Issues
[Same format]

#### LOW Priority Issues
[Same format]

### Recommendations
- [Specific UX improvement recommendation]
- [Another recommendation]

### Quick Wins (High Impact, Low Effort)
- [Easy UX improvement with significant benefit]
```

### Initial Issue Grouping (For Phase 2 Planning)

**Note:** This is a preliminary grouping. The detailed smart design improvement plan will be created in Phase 2 after ALL findings are documented.

```markdown
## Issues by Severity

### CRITICAL UX Issues (X found)
[List all critical issues with screen/file:line references]
- Accessibility violations preventing app use (WCAG failures)
- Broken user flows (task completion impossible)
- Critical loading state gaps (user confusion)

**Estimated Total Effort**: X days

### HIGH Priority UX Issues (X found)
[List all high priority issues]
- Design inconsistencies creating confusion
- Significant navigation friction
- Form UX problems reducing completion rates
- Error communication failures

**Estimated Total Effort**: X days

### MEDIUM Priority UX Issues (X found)
[List all medium priority issues]
- Visual hierarchy improvements
- Animation polish
- Responsive layout refinements
- Component consolidation opportunities

**Estimated Total Effort**: X days

### LOW Priority UX Issues (X found)
[List all low priority issues]
- Micro-interaction enhancements
- Documentation improvements
- Nice-to-have visual polish

**Estimated Total Effort**: X days

---

## Phase 2 Preparation

**Total UX Issues Found**: X
**Estimated Total Remediation Effort**: X days

**Next Steps (Phase 2):**
1. Analyze all UX findings together for patterns and relationships
2. Group related improvements by screen/flow for efficient implementation
3. Create design system updates needed for consistency
4. Generate smart UX improvement plan with sprint structure
5. Prioritize by user value and effort
6. Begin implementation with user testing

**This UX investigation is complete. Ready for Phase 2 smart design planning.**
```

### UX Metrics & Benchmarks

```markdown
## UX Quality Metrics

### Current vs. World-Class Standards

| Metric | Current | Target | Gap | Status |
|--------|---------|--------|-----|--------|
| WCAG 2.1 AA Compliance | X% | 100% | X% | ? |
| Design Consistency Score | X% | 95% | X% | ? |
| Avg Steps for Core Task | X | <5 | X | ? |
| Touch Target Compliance | X% | 100% | X% | ? |
| Color Contrast Pass Rate | X% | 100% | X% | ? |
| Loading State Coverage | X% | 100% | X% | ? |
| Error Message Quality | X/10 | 9/10 | X | ? |
| Component Reuse Rate | X% | 85% | X% | ? |
| Responsive Layout Score | X/10 | 9/10 | X | ? |
| Animation Smoothness | X fps | 60 fps | X | ? |

### User Experience Benchmarks

| Dimension | Current | Industry Best | Status |
|-----------|---------|---------------|--------|
| Task Completion Rate | X% | >90% | ? |
| Error Recovery Rate | X% | >85% | ? |
| First-Time User Success | X% | >80% | ? |
| User Flow Efficiency | X clicks | <5 clicks | ? |
```

### Top 10 UX Issues Summary (Quick Reference)

```markdown
## Critical UX Issues Requiring Immediate Attention

1. 🔴 **[Critical UX Issue #1]** - [Screen/Flow] (CRITICAL)
   - User Impact: [Description]
   - Effort: X hours/days | Impact: [User group affected]

2. 🔴 **[Critical UX Issue #2]** - [Screen/Flow] (CRITICAL)
   - User Impact: [Description]
   - Effort: X hours/days | Impact: [User group affected]

[... continue with top 10]
```

---

## Phase 1 Deliverables Checklist

**Investigation & Documentation Only - No Design or Code Changes**

- [ ] Executive summary with overall UX score (out of 100)
- [ ] Detailed findings for all 10 UX dimensions
- [ ] Issue classification (Critical/High/Medium/Low) with counts
- [ ] File:line references for every issue found
- [ ] Screenshots of visual issues (stored in analysis_screenshots/ folder)
- [ ] UX metrics comparison (current vs. world-class standards)
- [ ] Top 10 critical UX issues summary
- [ ] Effort estimates for each improvement
- [ ] WCAG compliance report
- [ ] User flow diagrams with friction points
- [ ] Component inventory and duplication analysis
- [ ] Initial issue grouping by severity (for Phase 2 planning)

---

## Phase 1 Success Criteria

**This UX investigation phase is complete when:**

1. ✅ Every major screen and user flow has been reviewed
2. ✅ All 10 UX dimensions scored and documented with detailed findings
3. ✅ All issues categorized by severity (Critical/High/Medium/Low) with counts
4. ✅ Effort estimates provided for each improvement (hours/days)
5. ✅ File:line references documented for every issue
6. ✅ Screenshots captured for visual issues
7. ✅ WCAG compliance assessment complete
8. ✅ User journey friction points identified and documented
9. ✅ Component duplication analysis complete
10. ✅ **ZERO code or design changes made** - documentation only
11. ✅ Phase 2 preparation complete (issue grouping ready for smart planning)

**Phase 1 Output:** Comprehensive UX/UI findings report with all issues documented and categorized.

**Phase 2 Input:** Use this report to create smart, optimized design improvement plan.

---

## Analysis Approach Guidelines

### Be User-Centric
- Always consider user perspective (not just designer perspective)
- Prioritize usability over aesthetics
- Consider diverse user abilities and contexts
- Focus on reducing cognitive load

### Be Specific
- Always provide screen/file:line references
- Include screenshots for visual issues
- Show concrete examples of problems
- Demonstrate best practices for comparison
- Give concrete effort estimates

### Be Comprehensive
- Test on multiple devices/screen sizes
- Consider accessibility for all users
- Review all major user journeys
- Don't skip edge cases or error states

### Be Actionable
- Every issue must have a suggested improvement
- Prioritize by user impact and effort
- Group related issues for efficient fixing
- Identify quick wins for immediate value

### Be Realistic
- Consider existing design system
- Respect platform conventions (Material Design for Android, Cupertino for iOS)
- Balance perfection with pragmatism
- Account for implementation complexity

---

## Context: Known Butlery App Intelligence

**Use this intelligence to focus your UX analysis:**

### App Structure
- Flutter mobile app (iOS and Android)
- MVVM architecture (Views in lib/views/, Widgets in lib/widgets/)
- ~112 view files, ~197 widget files
- Core features: Recipe management, Menu planning, Shopping lists, Social sharing

### Key User Flows to Audit
1. **Recipe Management**: Create, edit, view, delete recipes
2. **Menu Planning**: Create weekly menus, add recipes to calendar
3. **Shopping Lists**: Generate from recipes, manual add, collaborative lists
4. **Social Features**: Share recipes, invite friends, collaborative features
5. **Import**: Photo OCR, URL import, text import
6. **Discovery**: Search, browse, filter recipes

### Known UI Areas
- Recipe form (lib/views/recipe_form/)
- Recipe detail view
- Menu/calendar view (veckomeny_view.dart - 859 lines)
- Shopping list views
- Social/group views
- Settings and profile

### Design System Status
- Theme system in place (colors, text styles)
- Component library exists (lib/widgets/)
- Some documented patterns in CLAUDE.md

---

## 🚀 BEGIN PHASE 1 UX INVESTIGATION NOW

**CRITICAL REMINDERS:**
- 🚫 **NO CODE OR DESIGN CHANGES** - Investigation and documentation ONLY
- 📋 Document every finding with file:line references and screenshots
- 🏷️ Categorize all issues by severity (Critical/High/Medium/Low)
- ⏱️ Provide effort estimates (hours/days) for each improvement
- 🎯 Follow all 10 UX dimensions systematically
- ✅ Complete deliverables checklist before finishing

**Your Mission:**
Execute comprehensive UX/UI investigation following the framework above. Experience the app as a user would. Test all flows. Document every friction point. Change nothing.

**This app deserves world-class user experience** - and this investigation is the first step to achieving it.

**Phase 1 Goal:** A complete, detailed UX/UI findings report with screenshots, ready for Phase 2 smart design improvement planning.
