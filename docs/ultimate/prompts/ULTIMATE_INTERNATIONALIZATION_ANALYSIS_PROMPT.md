# ULTIMATE INTERNATIONALIZATION & LOCALIZATION ANALYSIS PROMPT

## Mission

Perform a comprehensive internationalization (i18n) and localization (l10n) analysis of the Butlery Flutter application. The goal is to achieve **world-class global readiness** for international expansion with:

- **Zero hardcoded strings** (all user-facing text externalized)
- **Complete translation infrastructure** (flutter_localizations, ARB files)
- **RTL language support** (Arabic, Hebrew readiness)
- **Locale-specific formatting** (dates, numbers, currency)
- **Cultural sensitivity** (images, colors, examples appropriate globally)
- **Pluralization handling** (count-based text variations)
- **Translation quality** (accurate, natural, context-aware)
- **Locale-specific business rules** (regional differences)

This is not a superficial i18n check. This is a **forensic-level globalization audit** across 8 dimensions of international readiness.

---

## ⚠️ CRITICAL: TWO-PHASE APPROACH - READ CAREFULLY

This analysis follows a **strict two-phase approach**:

### PHASE 1: INVESTIGATION & DOCUMENTATION (Your Current Task)

**🚫 ABSOLUTELY NO CODE CHANGES ALLOWED**

Your **ONLY** task is to:
1. **INVESTIGATE** - Examine all i18n/l10n aspects
2. **DOCUMENT** - Record every hardcoded string with file:line
3. **CATEGORIZE** - Classify by priority (Critical/High/Medium/Low)
4. **ESTIMATE** - Provide effort estimates for internationalization

**DO NOT:**
- ❌ Externalize ANY strings
- ❌ Create ANY ARB files
- ❌ Implement ANY translations
- ❌ Modify ANY code
- ❌ Add ANY localization packages
- ❌ Even suggest "let me fix this quickly"

**Your output is a COMPREHENSIVE I18N AUDIT REPORT** - nothing else.

### PHASE 2: SMART REMEDIATION PLAN (After Documentation Complete)

**Only after Phase 1 is 100% complete**, you will:
1. **ANALYZE** all documented findings together
2. **PRIORITIZE** by user impact and expansion plans
3. **GROUP** related i18n work
4. **CREATE** a smart, optimized internationalization plan
5. **SEQUENCE** implementation to minimize disruption

**This is a separate step that happens AFTER all investigation is done.**

---

## Why This Approach?

✅ **Complete Picture**: See ALL i18n work before starting
✅ **Smart Prioritization**: Focus on user-facing text first
✅ **Efficient Planning**: Group related string externalization
✅ **Risk Management**: Sequence changes to avoid breaking UI
✅ **Better Decisions**: Understand scope before committing to localization

**Remember: Investigation first, action later. Document everything, change nothing.**

---

## Analysis Framework: 8 Dimensions

### Dimension 1: Hardcoded String Audit (30%)

**Investigation Scope**: Identify ALL hardcoded user-facing strings in the codebase

**Gold Standard**: Zero hardcoded user-facing strings. All text externalized to ARB files.

**Investigate:**

1. **User-Facing String Inventory**
   ```dart
   // Search for hardcoded UI strings
   Patterns to find:
   - Text('Hardcoded string')
   - title: 'Hardcoded'
   - hintText: 'Enter value'
   - labelText: 'Field name'
   - errorText: 'Error message'
   - tooltip: 'Tooltip text'
   - AppBar(title: Text('Page'))
   - showDialog(title: 'Dialog')
   - SnackBar(content: Text('Message'))
   ```
   - Search for Text widget usage:
     ```dart
     grep -rn "Text(" lib/ | grep -v "// Translation:"
     grep -rn "title:" lib/ | grep -v "l10n\."
     grep -rn "hintText:" lib/
     grep -rn "labelText:" lib/
     grep -rn "errorText:" lib/
     ```
   - Document file:line for each hardcoded string
   - Categorize by type (button, label, error, etc.)
   - Count total hardcoded strings

2. **String Categories**
   ```dart
   Categorize hardcoded strings:

   CRITICAL (User-facing UI):
   - Button text ("Save", "Cancel", "Delete")
   - Error messages ("Invalid input", "Network error")
   - Dialog titles and messages
   - Form labels ("Email", "Password", "Recipe name")
   - Navigation titles ("Settings", "Profile", "Recipes")
   - Empty state messages ("No recipes found")

   HIGH (User interaction):
   - Placeholder text ("Enter your email...")
   - Tooltip text ("Tap to edit")
   - Confirmation messages ("Are you sure?")
   - Success messages ("Recipe saved!")
   - Validation messages ("Email is required")

   MEDIUM (Informational):
   - Help text
   - Instructions
   - Feature descriptions
   - Onboarding text

   LOW (Technical/Debug):
   - Log messages (not user-facing)
   - Debug strings
   - Developer comments
   ```
   - Categorize each hardcoded string
   - Document category distribution
   - Prioritize by user impact

3. **String Externalization Patterns**
   ```dart
   // Check current i18n implementation
   Current state:
   - flutter_localizations package added?
   - ARB files exist? (lib/l10n/*.arb)
   - Generated l10n classes?
   - AppLocalizations usage?

   // Anti-patterns to find:
   // BAD: Hardcoded
   Text('Save Recipe')

   // GOOD: Externalized
   Text(AppLocalizations.of(context)!.saveRecipe)
   // or
   Text(context.l10n.saveRecipe)
   ```
   - Check pubspec.yaml for flutter_localizations
   - Search for existing ARB files
   - Find AppLocalizations usage patterns
   - Document current i18n infrastructure

4. **Computed/Dynamic Strings**
   ```dart
   // Find string interpolation (needs special handling)
   'Welcome, $userName!'  // Needs: welcome(String name)
   'Recipe count: ${recipes.length}'  // Needs: recipeCount(int count)
   '${count} items selected'  // Needs: itemsSelected(int count)
   ```
   - Search for string interpolation patterns
   - Identify strings with variables
   - Document dynamic string requirements
   - Note pluralization needs

5. **Code-Generated Strings**
   ```dart
   // Find strings that shouldn't be translated
   - API endpoints (technical)
   - Firebase collection names (backend)
   - Log messages (developer-facing)
   - JSON keys (data structure)
   - Enum values (code)
   - Test data (not user-facing)
   ```
   - Identify non-translatable strings
   - Document exclusions from i18n
   - Verify technical strings not translated

**Output Requirements:**
- Complete hardcoded string inventory (file:line, string value)
- String count by category (Critical/High/Medium/Low)
- String count by type (button, label, error, placeholder, etc.)
- Current i18n infrastructure assessment
- Dynamic string requirements list
- Non-translatable string exclusions
- **Externalization effort**: X hours (Y strings to externalize)

---

### Dimension 2: Translation Infrastructure (20%)

**Investigation Scope**: Assess localization infrastructure readiness

**Gold Standard**: Complete flutter_localizations setup with ARB file workflow.

**Investigate:**

1. **Flutter Localization Setup**
   ```yaml
   # Check pubspec.yaml
   dependencies:
     flutter_localizations:
       sdk: flutter
     intl: any  # For date/number formatting

   flutter:
     generate: true  # Enables l10n code generation

   # Check l10n.yaml existence
   arb-dir: lib/l10n
   template-arb-file: app_en.arb
   output-localization-file: app_localizations.dart
   ```
   - Check pubspec.yaml for localization dependencies
   - Verify l10n.yaml configuration file
   - Document current setup status
   - Identify missing configuration

2. **ARB File Structure**
   ```json
   // lib/l10n/app_en.arb (English template)
   {
     "@@locale": "en",
     "saveRecipe": "Save Recipe",
     "@saveRecipe": {
       "description": "Button to save a recipe"
     },
     "recipeCount": "{count, plural, =0{No recipes} =1{1 recipe} other{{count} recipes}}",
     "@recipeCount": {
       "description": "Display recipe count",
       "placeholders": {
         "count": {
           "type": "int"
         }
       }
     }
   }
   ```
   - Check for existing ARB files
   - Review ARB file structure
   - Verify metadata (@key descriptions)
   - Document ARB file coverage
   - Identify missing translations

3. **Code Generation**
   ```dart
   // Generated: .dart_tool/flutter_gen/gen_l10n/app_localizations.dart
   class AppLocalizations {
     String get saveRecipe;
     String recipeCount(int count);
   }

   // Usage in code:
   import 'package:flutter_gen/gen_l10n/app_localizations.dart';

   Text(AppLocalizations.of(context)!.saveRecipe)
   ```
   - Check for generated localization files
   - Verify code generation working
   - Document generated class usage
   - Identify code generation issues

4. **Supported Locales**
   ```dart
   // main.dart configuration
   MaterialApp(
     localizationsDelegates: [
       AppLocalizations.delegate,
       GlobalMaterialLocalizations.delegate,
       GlobalWidgetsLocalizations.delegate,
       GlobalCupertinoLocalizations.delegate,
     ],
     supportedLocales: [
       Locale('en'), // English
       Locale('sv'), // Swedish
       Locale('de'), // German
       Locale('fr'), // French
       Locale('es'), // Spanish
       // Add more locales
     ],
   )
   ```
   - Check MaterialApp configuration
   - Document supported locales
   - Verify delegate setup
   - Identify missing locale support

5. **Fallback Strategy**
   ```dart
   // Locale resolution
   localeResolutionCallback: (locale, supportedLocales) {
     // Check if supported
     // Fallback to English if not
   }
   ```
   - Review locale resolution strategy
   - Check fallback locale configuration
   - Document unsupported locale handling

**Output Requirements:**
- Localization infrastructure status
- ARB file inventory and coverage
- Supported locales list
- Code generation status
- Missing infrastructure components
- **Setup effort**: X hours

---

### Dimension 3: RTL (Right-to-Left) Language Support (15%)

**Investigation Scope**: Readiness for Arabic, Hebrew, Urdu, and other RTL languages

**Gold Standard**: UI automatically mirrors for RTL languages without manual intervention.

**Investigate:**

1. **Directional Layout Audit**
   ```dart
   // Check for directional layout patterns
   Problems to find:
   - Hardcoded Row() instead of Directionality-aware Row
   - EdgeInsets.only(left: 10) instead of EdgeInsetsDirectional.only(start: 10)
   - Alignment.centerLeft instead of AlignmentDirectional.centerStart
   - Padding(padding: EdgeInsets.fromLTRB()) instead of EdgeInsetsDirectional
   ```
   - Search for hardcoded left/right:
     ```dart
     grep -rn "EdgeInsets.only(left:" lib/
     grep -rn "EdgeInsets.only(right:" lib/
     grep -rn "Alignment.centerLeft" lib/
     grep -rn "Alignment.centerRight" lib/
     ```
   - Count directional layout issues
   - Document file:line for each issue

2. **Icon and Image Directionality**
   ```dart
   // Check for directional icons
   Issues:
   - Arrow icons (← vs →) that need flipping
   - Icons with implicit direction (back button)
   - Images with text/direction (screenshots)
   - Asymmetric images that should flip
   ```
   - Identify directional icons
   - Find icons needing RTL variants
   - Document image directionality needs

3. **Text Alignment**
   ```dart
   // Check text alignment
   Problems:
   - textAlign: TextAlign.left (should be TextAlign.start)
   - textAlign: TextAlign.right (should be TextAlign.end)
   - Hardcoded alignments
   ```
   - Search for hardcoded text alignment
   - Document text alignment issues

4. **RTL Testing Infrastructure**
   ```dart
   // Check for RTL testing capability
   - Device/simulator with RTL locale?
   - RTL test cases?
   - Screenshot tests for RTL?
   ```
   - Document RTL testing setup
   - Identify testing gaps

5. **Third-Party Widget RTL Support**
   ```dart
   // Check third-party packages for RTL support
   - Do all UI packages support RTL?
   - Custom widgets RTL-aware?
   ```
   - Audit third-party widget RTL support
   - Document RTL compatibility

**Output Requirements:**
- Directional layout issue inventory (file:line)
- Icon/image directionality assessment
- Text alignment issue count
- RTL testing infrastructure status
- Third-party widget RTL compatibility
- **RTL readiness score**: X%
- **RTL remediation effort**: X hours

---

### Dimension 4: Locale-Specific Formatting (12%)

**Investigation Scope**: Date, number, currency, and time formatting for different locales

**Gold Standard**: All formatting uses locale-aware methods (DateFormat, NumberFormat).

**Investigate:**

1. **Date Formatting**
   ```dart
   // Find date formatting patterns
   Problems to find:
   - DateTime.toString() (not locale-aware)
   - Manual date formatting ('${day}/${month}/${year}')
   - Hardcoded date formats

   // Good pattern:
   import 'package:intl/intl.dart';
   DateFormat.yMMMd(locale).format(date);  // Feb 15, 2024 (en) vs 15 févr. 2024 (fr)
   ```
   - Search for date formatting:
     ```dart
     grep -rn "DateTime.toString()" lib/
     grep -rn "toIso8601String()" lib/
     grep -rn "DateFormat" lib/
     ```
   - Count non-locale-aware date formatting
   - Document date formatting issues

2. **Number Formatting**
   ```dart
   // Find number formatting
   Problems:
   - number.toString() (doesn't handle locale-specific separators)
   - Manual formatting (1,000 vs 1.000 vs 1 000)

   // Good pattern:
   NumberFormat.decimalPattern(locale).format(number);
   NumberFormat.compact(locale).format(number);  // 1.2K vs 1,2K
   ```
   - Search for number formatting
   - Count non-locale-aware number formatting
   - Document number formatting issues

3. **Currency Formatting**
   ```dart
   // Find currency formatting
   Problems:
   - '\$${amount.toStringAsFixed(2)}' (hardcoded $ symbol)
   - Manual currency formatting

   // Good pattern:
   NumberFormat.currency(locale: locale, symbol: '€').format(amount);
   // $1,234.56 (en-US) vs 1 234,56 € (fr-FR)
   ```
   - Search for currency formatting
   - Identify hardcoded currency symbols
   - Document currency formatting issues

4. **Time Formatting**
   ```dart
   // Find time formatting
   Problems:
   - 12-hour vs 24-hour format hardcoded
   - Manual time formatting

   // Good pattern:
   DateFormat.jm(locale).format(time);  // 3:30 PM vs 15:30
   ```
   - Search for time formatting
   - Document time formatting issues

5. **Relative Time**
   ```dart
   // Find relative time formatting
   Examples:
   - "2 hours ago" (needs translation)
   - "in 3 days" (needs translation)
   - "Yesterday", "Today", "Tomorrow"

   // Use package like timeago with localization
   ```
   - Search for relative time strings
   - Document relative time formatting

**Output Requirements:**
- Date formatting issue inventory
- Number formatting issue count
- Currency formatting assessment
- Time formatting issues
- Locale-aware formatting coverage
- **Formatting fix effort**: X hours

---

### Dimension 5: Pluralization & Gender (10%)

**Investigation Scope**: Plural forms and gender-based text variations

**Gold Standard**: All count-based strings use ICU message format with proper pluralization.

**Investigate:**

1. **Plural String Patterns**
   ```dart
   // Find plural string handling
   Problems:
   - '${count} recipes' (no singular handling)
   - count == 1 ? 'recipe' : 'recipes' (English-only, missing zero/few/many)

   // Good pattern (ICU message format):
   "{count, plural, =0{No recipes} =1{One recipe} other{{count} recipes}}"

   // Some languages need more:
   // Russian: zero, one, few, many
   // Arabic: zero, one, two, few, many, other
   ```
   - Search for plural patterns:
     ```dart
     grep -rn "== 1 ?" lib/
     grep -rn "> 1" lib/
     grep -rn "plural" lib/
     ```
   - Count plural string issues
   - Document languages with complex plurals

2. **Zero Handling**
   ```dart
   // Check zero-count handling
   Examples:
   - "0 recipes" vs "No recipes"
   - "0 items" vs "Empty"
   ```
   - Find zero-count string handling
   - Document zero-case issues

3. **Gender-Based Text** (if applicable)
   ```dart
   // Find gender-specific text
   Examples:
   - "He shared a recipe" vs "She shared a recipe"
   - Gendered nouns in some languages (French, Spanish, German)
   ```
   - Search for gender-specific text
   - Document gender handling needs
   - Assess if gender support needed

4. **ICU Message Format Usage**
   ```json
   // ARB file plural examples
   "recipeCount": "{count, plural, =0{No recipes} =1{One recipe} other{{count} recipes}}",
   "daysRemaining": "{days, plural, =0{Today} =1{Tomorrow} other{In {days} days}}"
   ```
   - Check for ICU message format usage
   - Document plural ARB entries
   - Identify missing plural support

**Output Requirements:**
- Plural string issue inventory
- Zero-case handling assessment
- Gender-based text requirements
- ICU message format coverage
- Language-specific plural rules needed
- **Pluralization fix effort**: X hours

---

### Dimension 6: Cultural Sensitivity & Adaptation (8%)

**Investigation Scope**: Cultural appropriateness of content, images, colors, and examples

**Gold Standard**: Content is culturally neutral or locale-adapted.

**Investigate:**

1. **Image Cultural Sensitivity**
   ```dart
   // Review images for cultural issues
   Checks:
   - Food images (culturally appropriate?)
   - People in images (diverse representation?)
   - Symbols/icons (offensive in some cultures?)
   - Flags/national symbols (correct usage?)
   ```
   - Audit app images
   - Identify culturally-specific images
   - Document images needing locale variants

2. **Color Cultural Meanings**
   ```dart
   // Review color usage
   Cultural color meanings:
   - Red: Danger (West), Good luck (China), Purity (India)
   - White: Purity (West), Mourning (China/Korea)
   - Green: Nature (West), Islam (Middle East)
   - Yellow: Caution (West), Royalty (China)
   ```
   - Review primary color choices
   - Document color cultural sensitivity
   - Identify colors needing adaptation

3. **Example Data Appropriateness**
   ```dart
   // Review placeholder/example data
   Issues:
   - Names (use culturally-appropriate names per locale)
   - Addresses (format varies by country)
   - Phone numbers (format varies)
   - Example recipes (culturally appropriate?)
   ```
   - Audit example/placeholder data
   - Document culturally-specific examples
   - Identify examples needing localization

4. **Units of Measurement**
   ```dart
   // Review measurement units
   Issues:
   - Metric vs Imperial (kg vs lb, cm vs inches)
   - Temperature (Celsius vs Fahrenheit)
   - Volume (liters vs gallons, ml vs cups)

   // Recipe-specific:
   - Cups, tablespoons (varies by country)
   ```
   - Search for hardcoded units
   - Document measurement unit usage
   - Identify unit conversion needs

5. **Idioms and Colloquialisms**
   ```dart
   // Find culturally-specific phrases
   Examples:
   - "Piece of cake" (doesn't translate)
   - "Raining cats and dogs"
   - Culture-specific humor
   ```
   - Search for idioms
   - Document phrases needing adaptation

**Output Requirements:**
- Image cultural sensitivity audit
- Color usage assessment
- Example data appropriateness review
- Measurement units inventory
- Idiom/colloquialism list
- **Cultural adaptation effort**: X hours

---

### Dimension 7: Translation Quality & Completeness (3%)

**Investigation Scope**: If translations exist, assess quality and completeness

**Gold Standard**: 100% translation coverage, natural and accurate translations.

**Investigate:**

1. **Translation Coverage**
   ```
   // Check ARB files for completeness
   - app_en.arb (English - template): 250 strings
   - app_sv.arb (Swedish): 250 strings (100%)
   - app_de.arb (German): 180 strings (72% - INCOMPLETE)
   - app_fr.arb (French): 0 strings (0% - MISSING)
   ```
   - Count strings per locale
   - Calculate coverage percentage
   - Identify missing translations

2. **Translation Quality**
   ```dart
   // Review translation quality (if applicable)
   Issues to check:
   - Machine translation artifacts (awkward phrasing)
   - Untranslated strings (English in non-English ARB)
   - Context-inappropriate translations
   - Inconsistent terminology
   ```
   - Spot-check translation quality
   - Identify machine-translated content
   - Document quality issues

3. **Translation Workflow**
   ```
   // Document translation process
   - Who creates translations?
   - Professional translators or machine?
   - Review process exists?
   - Translation memory/glossary used?
   ```
   - Document translation workflow
   - Assess translation quality process

4. **Translation Tools**
   ```
   // Check for translation tooling
   - Localization platform (Lokalise, Crowdin, POEditor)?
   - Translation management?
   - Translator collaboration?
   ```
   - Document translation tools used
   - Assess translation infrastructure

**Output Requirements:**
- Translation coverage matrix (locale × strings)
- Translation quality assessment
- Translation workflow documentation
- Missing translation count
- **Translation effort**: X hours

---

### Dimension 8: Locale-Specific Business Rules (2%)

**Investigation Scope**: Business logic that varies by locale/region

**Gold Standard**: Business rules adapt to locale when necessary.

**Investigate:**

1. **Regional Regulations**
   ```dart
   // Find region-specific business logic
   Examples:
   - GDPR (EU) vs CCPA (California)
   - Age requirements (alcohol recipes)
   - Measurement standards
   - Privacy requirements
   ```
   - Identify regulatory differences
   - Document region-specific logic needs

2. **Feature Availability by Region**
   ```dart
   // Check for feature flags by region
   - Features available in some countries only?
   - Payment methods by country?
   - Social features restrictions?
   ```
   - Document feature availability variations
   - Identify geo-blocking needs

3. **Locale-Specific Defaults**
   ```dart
   // Check default values by locale
   Examples:
   - Default recipe portions (varies by country)
   - Temperature defaults (C vs F)
   - Measurement unit defaults
   ```
   - Identify locale-specific defaults
   - Document default value variations

**Output Requirements:**
- Regional business rule inventory
- Feature availability matrix
- Locale-specific defaults list
- **Effort**: X hours

---

## Investigation Process

### Week 1: String Audit & Infrastructure (Days 1-3)

**Day 1: Hardcoded String Inventory (4-5 hours)**
1. Search for all hardcoded strings in UI code
2. Categorize strings (Critical/High/Medium/Low)
3. Count strings by type (button, label, error, etc.)
4. Identify dynamic/interpolated strings
5. Document non-translatable strings
6. **Output**: Complete string inventory (file:line)

**Day 2: Translation Infrastructure Assessment (3-4 hours)**
7. Check flutter_localizations setup
8. Review ARB file structure and coverage
9. Verify code generation working
10. Document supported locales
11. Assess translation workflow
12. **Output**: Infrastructure status report

**Day 3: RTL & Formatting Audit (3-4 hours)**
13. Search for directional layout issues
14. Identify icon/image directionality needs
15. Audit date/number/currency formatting
16. Check time formatting patterns
17. **Output**: RTL readiness & formatting assessment

### Week 2: Pluralization, Culture, Quality (Days 4-5)

**Day 4: Pluralization & Cultural Sensitivity (3-4 hours)**
18. Find plural string patterns
19. Check ICU message format usage
20. Review image cultural sensitivity
21. Audit color cultural meanings
22. Check measurement units
23. **Output**: Pluralization & culture report

**Day 5: Translation Quality & Business Rules (2-3 hours)**
24. Assess translation coverage
25. Review translation quality
26. Document translation workflow
27. Identify locale-specific business rules
28. **Output**: Translation quality assessment

### Week 3: Synthesis (Day 6)

**Day 6: Comprehensive Report (2-3 hours)**
29. Calculate dimension scores
30. Create i18n readiness scorecard
31. Prioritize internationalization work
32. Generate localization roadmap
33. **Output**: Complete i18n analysis report

---

## Output Deliverables

### 1. Executive Summary
```markdown
# BUTLERY INTERNATIONALIZATION ANALYSIS - PHASE 1: I18N AUDIT FINDINGS

Analysis Date: [Date]
Analyst: Claude (Sonnet 4.5)
Codebase: 812 files, 138k LOC

## OVERALL I18N SCORE: X/100

├─ Hardcoded Strings:            X/30 points
├─ Translation Infrastructure:   X/20 points
├─ RTL Support:                  X/15 points
├─ Locale Formatting:            X/12 points
├─ Pluralization & Gender:       X/10 points
├─ Cultural Sensitivity:         X/8 points
├─ Translation Quality:          X/3 points
└─ Locale Business Rules:        X/2 points

## I18N READINESS: [Excellent | Good | Needs Work | Not Ready]

### Key Findings
- **Hardcoded Strings**: X strings found across Y files
- **Translation Infrastructure**: [Complete | Partial | Missing]
- **RTL Readiness**: [Ready | Needs Work | Not Ready]
- **Supported Locales**: [en, sv, ...] (X locales)

### Internationalization Effort
- **String Externalization**: X hours (Y strings)
- **Infrastructure Setup**: X hours
- **RTL Remediation**: X hours
- **Translation**: X hours (Y strings × Z locales)
- **Total Effort**: X hours (Y days)

### Priority Markets
Based on analysis, recommend focusing on:
1. [Country/Language] - [Reason]
2. [Country/Language] - [Reason]
```

### 2. Hardcoded String Inventory
```markdown
## Hardcoded Strings - Score: X/30

### Summary
- **Total Hardcoded Strings**: X strings
- **Distribution**: Y files affected
- **Categories**:
  - Critical (buttons, errors): X strings
  - High (labels, placeholders): X strings
  - Medium (help text): X strings
  - Low (technical): X strings

### Top 20 Most Critical Strings

| File | Line | String | Category | Priority |
|------|------|--------|----------|----------|
| lib/views/recipe_detail_view.dart | 89 | "Save Recipe" | Button | P0 |
| lib/views/auth/login_view.dart | 45 | "Email" | Label | P0 |
| lib/services/auth_service.dart | 142 | "Invalid credentials" | Error | P0 |

[... continue for top 20 ...]

### String Count by File

| File | String Count | Category |
|------|--------------|----------|
| lib/views/recipe_form_view.dart | 45 | Critical |
| lib/views/settings_view.dart | 32 | High |

### Externalization Roadmap

**Phase 1: Critical Strings (Week 1)** - X strings
- All button text
- All error messages
- All form labels
- **Effort**: X hours

**Phase 2: High Priority (Week 2)** - X strings
- Placeholder text
- Validation messages
- Dialog titles
- **Effort**: X hours

**Phase 3: Medium Priority (Week 3)** - X strings
- Help text
- Instructions
- Feature descriptions
- **Effort**: X hours

**Total Externalization Effort**: X hours
```

### 3. Translation Infrastructure Report
```markdown
## Translation Infrastructure - Score: X/20

### Current Status

| Component | Status | Details |
|-----------|--------|---------|
| flutter_localizations | ✅/❌ | Installed/Not installed |
| intl package | ✅/❌ | Version X.Y |
| l10n.yaml | ✅/❌ | Configured/Missing |
| ARB files | ✅/⚠️/❌ | Complete/Partial/Missing |
| Code generation | ✅/❌ | Working/Not setup |

### Supported Locales

| Locale | Language | Coverage | Status |
|--------|----------|----------|--------|
| en | English | 100% (250/250) | ✅ Complete |
| sv | Swedish | 72% (180/250) | ⚠️ Incomplete |
| de | German | 0% (0/250) | ❌ Missing |

### Infrastructure Gaps

1. **Missing l10n.yaml configuration** (BLOCKER)
   - Impact: Can't generate localization code
   - Effort: 30 minutes

2. **Incomplete Swedish translations** (HIGH)
   - Missing: 70 strings
   - Effort: 4 hours (translation)

3. **No code generation setup** (HIGH)
   - Impact: Can't use AppLocalizations
   - Effort: 1 hour

**Setup Effort**: X hours
```

### 4. RTL Readiness Report
```markdown
## RTL Language Support - Score: X/15

### Directional Layout Issues

**Total Issues Found**: X instances

| Issue Type | Count | Example File |
|------------|-------|--------------|
| EdgeInsets.only(left:) | X | lib/views/recipe_view.dart:89 |
| EdgeInsets.only(right:) | X | lib/widgets/recipe_card.dart:45 |
| Alignment.centerLeft | X | lib/views/settings_view.dart:123 |
| Hardcoded Row direction | X | lib/widgets/menu_item.dart:67 |

### Critical Fixes Required

#### Issue 1: Hardcoded Left Padding
**Location**: `lib/views/recipe_detail_view.dart:89`
**Current**:
```dart
Padding(
  padding: EdgeInsets.only(left: 16.0),
  child: Text('Recipe Title'),
)
```
**Should be**:
```dart
Padding(
  padding: EdgeInsetsDirectional.only(start: 16.0),
  child: Text('Recipe Title'),
)
```

[... continue for each critical issue ...]

### Icon Directionality

**Icons Needing RTL Variants**: X icons
- Back arrow (←/→)
- Forward navigation
- Drawer icon

### RTL Readiness Score: X%

**RTL Remediation Effort**: X hours
```

### 5. Locale Formatting Assessment
```markdown
## Locale-Specific Formatting - Score: X/12

### Date Formatting Issues

**Non-Locale-Aware Date Formatting**: X instances

| File | Line | Current | Should Use |
|------|------|---------|------------|
| lib/views/recipe_detail.dart | 89 | DateTime.toString() | DateFormat.yMMMd(locale) |

### Number Formatting Issues

**Hardcoded Number Formatting**: X instances

### Currency Formatting Issues

**Hardcoded Currency Symbols**: X instances

| File | Line | Hardcoded | Issue |
|------|------|-----------|-------|
| lib/models/recipe.dart | 45 | '\$${amount}' | USD-only |

### Recommended Packages
- intl: ^0.18.0 (for DateFormat, NumberFormat)
- timeago: ^3.0.0 (for relative time with localization)

**Formatting Fix Effort**: X hours
```

### 6. Pluralization Report
```markdown
## Pluralization & Gender - Score: X/10

### Plural String Issues

**Total Plural Issues**: X instances

| File | Line | Current | Languages Affected |
|------|------|---------|-------------------|
| lib/views/recipe_list.dart | 89 | '${count} recipes' | Russian, Arabic, Polish |

### ICU Message Format Examples Needed

```json
// app_en.arb
{
  "recipeCount": "{count, plural, =0{No recipes} =1{One recipe} other{{count} recipes}}",
  "daysAgo": "{days, plural, =0{Today} =1{Yesterday} other{{days} days ago}}"
}
```

### Languages with Complex Plurals

Planning to support these languages? They have complex plural rules:

| Language | Plural Forms | Example |
|----------|--------------|---------|
| Russian | zero, one, few, many | 0/5/6-20 машин, 1 машина, 2-4 машины |
| Arabic | zero, one, two, few, many, other | 6 forms |
| Polish | one, few, many | 3 forms |

**Pluralization Fix Effort**: X hours
```

### 7. Cultural Sensitivity Audit
```markdown
## Cultural Sensitivity & Adaptation - Score: X/8

### Image Review

**Images Requiring Locale Variants**: X images
- Default profile avatars (need diverse representation)
- Food photography (culturally appropriate?)
- Onboarding illustrations

### Color Usage

**Culturally-Sensitive Colors Identified**:
- Primary red: OK in West, consider for China market
- White backgrounds: Consider for Asian markets (mourning color)

### Measurement Units

**Hardcoded Units Found**: X instances

| File | Line | Unit | Markets Affected |
|------|------|------|------------------|
| lib/models/recipe.dart | 89 | cups/tbsp | Non-US markets |
| lib/models/recipe.dart | 102 | Fahrenheit | Metric countries |

### Recommendations

1. **Add unit preference setting**
   - Metric (kg, L, °C)
   - Imperial (lb, gal, °F)
   - US cooking (cups, tbsp, °F)

2. **Provide unit conversion**
   - Automatic conversion based on locale
   - Manual toggle available

**Cultural Adaptation Effort**: X hours
```

### 8. Internationalization Roadmap
```markdown
## Internationalization Roadmap

### Phase 1: Infrastructure Setup (Week 1) - FOUNDATION

**Goal**: Prepare app for internationalization

1. Add flutter_localizations dependency (30 min)
2. Create l10n.yaml configuration (30 min)
3. Set up ARB file structure (1 hour)
4. Configure code generation (1 hour)
5. Create AppLocalizations helper (1 hour)

**Total Effort**: 4 hours
**Outcome**: Infrastructure ready for string externalization

---

### Phase 2: Critical String Externalization (Weeks 2-3)

**Goal**: Externalize all user-facing strings

**Week 2**: Critical & High Priority (X strings)
- All button text (X strings, 2 hours)
- All error messages (X strings, 3 hours)
- All form labels (X strings, 2 hours)
- All dialog titles (X strings, 1 hour)

**Week 3**: Medium Priority (X strings)
- Placeholder text (X strings, 2 hours)
- Help text (X strings, 2 hours)
- Instructions (X strings, 1 hour)

**Total Effort**: 13 hours
**Outcome**: Zero hardcoded user-facing strings

---

### Phase 3: RTL Support (Week 4)

**Goal**: Support Arabic, Hebrew, Urdu

1. Fix directional layout (EdgeInsets) - X instances, 4 hours
2. Fix text alignment (TextAlign) - X instances, 2 hours
3. Add directional icon variants - 2 hours
4. Test with RTL locale - 2 hours

**Total Effort**: 10 hours
**Outcome**: RTL-ready UI

---

### Phase 4: Locale Formatting (Week 5)

**Goal**: Proper date/number/currency formatting

1. Replace DateTime.toString() - X instances, 2 hours
2. Add NumberFormat for numbers - X instances, 2 hours
3. Add currency formatting - X instances, 1 hour
4. Implement unit conversion - 4 hours

**Total Effort**: 9 hours
**Outcome**: Locale-aware formatting

---

### Phase 5: Translation (Weeks 6-8)

**Goal**: Translate to target languages

**Per Locale Effort** (assuming professional translation):
- Translation: 4-6 hours (250 strings)
- Review: 2 hours
- Testing: 2 hours
- **Total per locale**: 8-10 hours

**Recommended Locales** (in order):
1. **Swedish (sv)** - 8 hours (primary market)
2. **German (de)** - 8 hours (large EU market)
3. **French (fr)** - 8 hours (large EU market)
4. **Spanish (es)** - 8 hours (global reach)
5. **Arabic (ar)** - 10 hours (RTL testing)

**Total Translation Effort**: 40-50 hours (5 locales)

---

### Total Internationalization Effort

| Phase | Effort | Priority |
|-------|--------|----------|
| Infrastructure | 4 hours | P0 - CRITICAL |
| String Externalization | 13 hours | P0 - CRITICAL |
| RTL Support | 10 hours | P1 - High |
| Locale Formatting | 9 hours | P1 - High |
| Translation (5 locales) | 42 hours | P2 - Medium |

**Grand Total**: 78 hours (10 days)

### Expected Outcome

- ✅ 100% string externalization
- ✅ Support for 5+ languages (en, sv, de, fr, es, ar)
- ✅ RTL language support
- ✅ Locale-aware formatting
- ✅ Cultural sensitivity
- ✅ Ready for global markets
```

---

## Phase 1 Deliverables Checklist

**Investigation & Documentation Only - No Code Changes**

- [ ] Complete hardcoded string inventory (file:line, string value)
- [ ] String categorization (Critical/High/Medium/Low)
- [ ] Translation infrastructure assessment
- [ ] RTL readiness audit
- [ ] Locale formatting issue inventory
- [ ] Pluralization pattern review
- [ ] Cultural sensitivity assessment
- [ ] Translation quality evaluation (if applicable)
- [ ] Locale business rule documentation
- [ ] Internationalization effort estimates
- [ ] Localization roadmap

---

## Phase 1 Success Criteria

**This investigation phase is complete when:**

1. ✅ All 8 dimensions investigated thoroughly
2. ✅ Every hardcoded string documented (file:line, string value)
3. ✅ Translation infrastructure status assessed
4. ✅ RTL readiness scored
5. ✅ Locale formatting issues cataloged
6. ✅ Pluralization patterns reviewed
7. ✅ Cultural sensitivity audit complete
8. ✅ Internationalization effort estimated
9. ✅ Localization roadmap created
10. ✅ **ZERO code changes made** - documentation only

**Phase 1 Output:** Comprehensive i18n audit report with localization roadmap.

**Phase 2 Input:** Use this report to implement internationalization plan.

---

## Time Estimate

**Total Investigation Time: 12-16 hours**
- Week 1 (Strings & Infrastructure): 10-13 hours
- Week 2 (Pluralization & Culture): 4-6 hours
- Week 3 (Synthesis): 2-3 hours

---

## Critical Reminders

1. **DOCUMENT, DON'T FIX**: This is investigation only
2. **COUNT EVERYTHING**: Every hardcoded string matters
3. **CONTEXT MATTERS**: Note string context for translators
4. **RTL IS HARD**: Directional layouts often overlooked
5. **PLURALS ARE COMPLEX**: Different languages, different rules
6. **CULTURE SENSITIVITY**: Images, colors, examples matter
7. **ZERO CODE CHANGES**: Investigation and documentation only

---

## Ready to Begin I18N Audit

When you're ready to start Phase 1, begin with:
1. **Hardcoded String Search** (grep for Text() widgets)
2. **Translation Infrastructure Check** (pubspec.yaml, l10n.yaml)
3. **RTL Layout Audit** (EdgeInsets, Alignment patterns)
4. Work through remaining dimensions systematically

**Remember: Document everything, change nothing. This audit reveals the scope of internationalization work.**

**Phase 1 Goal:** A complete i18n readiness report ready for Phase 2 implementation planning.
