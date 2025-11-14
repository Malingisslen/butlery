# ULTIMATE DOCUMENTATION & COMMENTING ANALYSIS PROMPT

## Mission

Perform the most thorough, uncompromising documentation quality analysis of the Butlery Flutter codebase. The goal is to achieve **industry gold standard documentation** that balances clarity with maintainability:

- **Zero bloated comments** (obvious, redundant, or noise)
- **Zero outdated documentation** (misleading or incorrect)
- **Self-documenting code** (clear naming reduces comment need)
- **Strategic documentation** (complex logic, business rules, APIs)
- **Production-grade docs** (architecture, onboarding, deployment)

This is not a superficial review. This is a **forensic-level investigation** of every comment, doc string, and documentation file across 8 dimensions of documentation quality.

---

## ⚠️ CRITICAL: TWO-PHASE APPROACH - READ CAREFULLY

This analysis follows a **strict two-phase approach**:

### PHASE 1: INVESTIGATION & DOCUMENTATION (Your Current Task)

**🚫 ABSOLUTELY NO CODE CHANGES ALLOWED**

Your **ONLY** task is to:
1. **INVESTIGATE** - Examine every comment and doc across the codebase
2. **DOCUMENT** - Record every finding with file:line references
3. **CATEGORIZE** - Classify issues by severity (Critical/High/Medium/Low)
4. **ESTIMATE** - Provide effort estimates for cleanup

**DO NOT:**
- ❌ Delete ANY comments
- ❌ Fix ANY documentation
- ❌ Update ANY doc strings
- ❌ Create ANY new docs
- ❌ Modify ANY existing files
- ❌ Even suggest "let me fix this quickly"

**Your output is a COMPREHENSIVE FINDINGS REPORT** - nothing else.

### PHASE 2: SMART REMEDIATION PLAN (After Documentation Complete)

**Only after Phase 1 is 100% complete**, you will:
1. **ANALYZE** all documented findings together
2. **PRIORITIZE** by impact (misleading vs. noise vs. missing)
3. **GROUP** related cleanup tasks
4. **CREATE** a smart, optimized documentation improvement plan
5. **SEQUENCE** changes to maximize clarity and minimize disruption

**This is a separate step that happens AFTER all investigation is done.**

---

## Why This Approach?

✅ **Complete Picture**: See ALL documentation issues before deciding what to fix
✅ **Smart Prioritization**: Focus on misleading docs first, then bloat, then gaps
✅ **Efficient Planning**: Group related cleanup, avoid multiple file touches
✅ **Risk Management**: Sequence changes to minimize confusion
✅ **Better Decisions**: Understand patterns before making style decisions

**Remember: Investigation first, action later. Document everything, change nothing.**

---

## Analysis Framework: 8 Dimensions

### Dimension 1: Comment Bloat & Noise (25%)

**Investigation Scope**: Identify unnecessary, obvious, or redundant comments that clutter the code

**Gold Standard**: Comments should explain **WHY**, not **WHAT**. Clear code documents itself.

**Investigate:**

1. **Obvious Comments** (state the obvious)
   ```dart
   // BAD: Noise, adds no value
   // Increment counter
   counter++;

   // Create a new user
   final user = User(name: 'John');

   // Check if list is empty
   if (items.isEmpty) { ... }

   // Return true
   return true;
   ```
   - Search for comments that simply restate the code
   - Find comments on trivial operations (getters, setters, simple assignments)
   - Identify comments that duplicate what the code already shows
   - Document file:line for each obvious comment

2. **Redundant Documentation**
   ```dart
   // BAD: DartDoc repeats method name
   /// Gets the recipe
   Recipe getRecipe() { ... }

   /// Sets the title
   void setTitle(String title) { ... }

   /// Returns a list of items
   List<Item> getItems() { ... }
   ```
   - Find DartDoc that adds no information beyond the signature
   - Identify parameter docs that just repeat the parameter name
   - Search for return docs that just say "returns X"
   - Document each redundant doc string

3. **Over-Commented Simple Code**
   ```dart
   // BAD: Clear code doesn't need comments
   // Get user's first recipe
   final recipe = user.recipes.first;

   // Calculate total price
   final total = items.fold(0.0, (sum, item) => sum + item.price);

   // Check if user is authenticated
   if (currentUser != null) { ... }
   ```
   - Find blocks of simple, self-explanatory code with excessive comments
   - Identify well-named variables/methods that don't need explanation
   - Search for comments on standard Flutter/Dart patterns
   - Document over-commented sections

4. **Comment Clutter Patterns**
   ```dart
   // BAD: Visual clutter
   //================================================
   // SECTION: USER MANAGEMENT
   //================================================

   /************************************
    * IMPORTANT FUNCTION
    ************************************/

   // ---- Helper Methods ---- //
   ```
   - Find ASCII art separators and decorative comments
   - Identify excessive section headers
   - Search for comment "boxes" and visual noise
   - Document clutter patterns

5. **Placeholder Comments**
   ```dart
   // BAD: Empty or useless placeholders
   // Constructor
   MyClass() { ... }

   // Variables
   String title;
   int count;

   // Main method
   void main() { ... }
   ```
   - Find comments that are just section labels
   - Identify placeholder docs with no real content
   - Search for "Constructor", "Variables", "Methods" labels
   - Document placeholder noise

**Output Requirements:**
- Count of obvious comments by category (file:line references)
- Redundant DartDoc inventory (methods, classes, parameters)
- Over-commented code sections (file:line ranges)
- Clutter pattern examples with frequency
- Bloat severity classification (High/Medium/Low noise)
- **Estimated cleanup effort**: X hours (delete operations)

---

### Dimension 2: Outdated & Misleading Documentation (20%)

**Investigation Scope**: Find documentation that is incorrect, outdated, or actively misleading

**Gold Standard**: Documentation must be accurate or deleted. Misleading docs are worse than no docs.

**Investigate:**

1. **Incorrect Comments**
   ```dart
   // CRITICAL: Misleading - states wrong behavior
   /// Returns the user's email
   String getUserName() { ... }  // Actually returns name!

   /// Deletes the recipe
   void archiveRecipe() { ... }  // Actually archives, not deletes!

   /// Validates input (returns true if valid)
   bool validate() { ... }  // Actually returns false if valid!
   ```
   - **HIGH PRIORITY**: Find comments that describe wrong behavior
   - Check method docs against actual implementation
   - Verify parameter descriptions match actual usage
   - Identify return value mismatches
   - Document each incorrect comment with severity

2. **Outdated Implementation Comments**
   ```dart
   // BAD: Code changed, comment didn't
   /// Uses Firebase v8 API
   void saveData() {
     // Actually using v9 modular API now
     await firestore.collection('data').add(data);
   }

   /// Stores data in SharedPreferences
   Future<void> cache() {
     // Migrated to Hive months ago
     await _hive.put('key', value);
   }
   ```
   - Find comments referencing old APIs or libraries
   - Identify docs describing removed features
   - Search for comments about "legacy" or "old" approaches still in code
   - Document outdated implementation comments

3. **Incorrect Architecture Documentation**
   ```dart
   // BAD: Describes old architecture
   /// This service directly calls Firebase
   class RecipeService {
     // Actually uses Repository pattern now
     final RecipeRepository _repository;
   }

   /// Stores state using setState
   class RecipeViewModel {
     // Migrated to ChangeNotifier months ago
   }
   ```
   - Check class-level docs against actual architecture
   - Verify layer descriptions (MVVM, Repository pattern)
   - Find docs describing deprecated patterns
   - Document architectural mismatches

4. **Broken References**
   ```dart
   // BAD: References don't exist
   /// See [AuthService] for details
   // AuthService was renamed to UserService

   /// Uses [ValidationHelper] to validate
   // ValidationHelper was deleted, now uses ValidationUtils

   /// Implements the [DatabaseInterface]
   // Interface removed in refactor
   ```
   - Find doc references to renamed/deleted classes
   - Identify broken file path references
   - Search for links to removed documentation
   - Document broken reference comments

5. **Misleading TODOs/FIXMEs**
   ```dart
   // INVESTIGATE: Are these actually done?
   // TODO: Implement error handling
   void process() {
     try {
       // Error handling is actually implemented!
     } catch (e) {
       _handleError(e);
     }
   }

   // FIXME: This is slow
   // (Actually optimized 6 months ago)
   ```
   - Find TODOs for already-completed work
   - Identify FIXMEs for already-fixed issues
   - Search for outdated improvement suggestions
   - Document misleading TODO/FIXME comments

**Output Requirements:**
- **CRITICAL**: Incorrect documentation inventory (file:line, actual vs. documented)
- Outdated implementation comments list
- Broken reference catalog
- Misleading TODO/FIXME list
- Accuracy risk assessment (how many devs could be misled?)
- **Estimated fix effort**: X hours (verify + update or delete)

---

### Dimension 3: Commented-Out Code (18%)

**Investigation Scope**: Find dead code left in comments (code smell)

**Gold Standard**: Use version control for history. Commented code should not exist in production.

**Investigate:**

1. **Large Commented Code Blocks**
   ```dart
   // BAD: Dead code in comments
   // void oldImplementation() {
   //   final data = fetchData();
   //   processData(data);
   //   saveResults();
   // }

   // class OldRecipeModel {
   //   String title;
   //   int servings;
   //   // ... 50 lines of old model
   // }
   ```
   - Find blocks of 5+ consecutive commented code lines
   - Identify entire commented functions/classes
   - Search for multi-line commented-out implementations
   - Document file:line and block size

2. **Experimental Code Left Behind**
   ```dart
   // BAD: Debug/test code commented but not removed
   // print('DEBUG: Recipe count: ${recipes.length}');
   // debugPrint('User data: ${user.toJson()}');

   // Testing different approach:
   // final result = alternativeImplementation();
   // return result;
   ```
   - Find commented debug statements
   - Identify commented print/log statements
   - Search for "testing", "debug", "experiment" in comments
   - Document experimental code remnants

3. **Old Implementation Graveyard**
   ```dart
   // BAD: Multiple old versions kept in comments
   // Original implementation (2023-01):
   // return recipes.where((r) => r.userId == userId);

   // Second attempt (2023-03):
   // return recipes.where((r) => r.userId == userId && r.isActive);

   // Third attempt (2023-06):
   // return recipes.where((r) => r.userId == userId && !r.isDeleted);

   // Current (2023-09):
   return recipes.where((r) => r.userId == userId && r.status == 'active');
   ```
   - Find multiple commented versions of same logic
   - Identify "old", "original", "previous" implementation comments
   - Search for dated commented code
   - Document implementation graveyards

4. **Incomplete Refactoring Comments**
   ```dart
   // BAD: Migration artifacts
   // Old Firebase v8 code:
   // final snapshot = await firebase.collection('recipes').get();

   // Migrating to v9:
   // const recipesRef = collection(db, 'recipes');
   // const snapshot = await getDocs(recipesRef);

   // New repository pattern:
   final recipes = await _recipeRepository.getAll();
   ```
   - Find commented code from incomplete migrations
   - Identify refactoring breadcrumbs
   - Search for "old", "new", "migration" in comments
   - Document refactoring artifacts

5. **Commented Imports & Declarations**
   ```dart
   // BAD: Unused commented imports
   // import 'package:old_package/old_package.dart';
   // import 'package:http/http.dart' as http;

   // Unused service:
   // final OldService _oldService;
   ```
   - Find commented import statements
   - Identify commented variable declarations
   - Search for commented dependencies
   - Document commented declarations

**Output Requirements:**
- Commented code inventory (file:line, block size)
- Experimental/debug code catalog
- Implementation graveyard list
- Refactoring artifact map
- **Total commented code lines**: X lines across Y files
- **Cleanup effort**: X hours (delete operations, verify safety)

---

### Dimension 4: Self-Documenting Code vs. Over-Documentation (15%)

**Investigation Scope**: Assess code clarity and whether comments are necessary or compensating for poor naming

**Gold Standard**: Clear code with good naming needs minimal comments. Comments should explain complex logic, not basic code.

**Investigate:**

1. **Poor Naming Requiring Comments**
   ```dart
   // BAD: Comment needed because naming is unclear
   // User's authentication status
   bool f;  // Should be: isAuthenticated

   // Recipe preparation time in minutes
   int t;  // Should be: preparationTimeMinutes

   // Process the data and return result
   dynamic proc(dynamic d) { ... }  // Should be: processRecipe(Recipe recipe)
   ```
   - Find variables with comments explaining what they are
   - Identify methods with comments explaining what they do
   - Search for unclear names requiring documentation
   - Document naming issues disguised as documentation needs

2. **Complex Logic Without Explanation**
   ```dart
   // BAD: Complex logic needs explanation, but has none
   // Missing comment explaining the algorithm
   final result = items
     .where((i) => i.status == 'active' && i.priority > threshold)
     .fold<Map<String, int>>({}, (acc, i) {
       acc[i.category] = (acc[i.category] ?? 0) + i.score;
       return acc;
     })
     .entries
     .where((e) => e.value >= minScore)
     .map((e) => e.key)
     .toList();

   // SHOULD HAVE: Comment explaining:
   // "Groups active high-priority items by category, sums their scores,
   //  and returns categories that meet the minimum score threshold"
   ```
   - Find complex algorithms without explanation
   - Identify business logic without context
   - Search for dense code that would benefit from explanation
   - Document under-commented complexity

3. **Well-Named Code With Redundant Comments**
   ```dart
   // GOOD: Self-documenting, comment is noise
   /// Calculates the total price of all items in the cart
   double calculateTotalCartPrice(List<CartItem> items) {
     return items.fold(0.0, (total, item) => total + item.price);
   }

   // Comment is redundant - method name says it all
   // DELETE THE COMMENT
   ```
   - Find well-named methods with obvious comments
   - Identify clear code with redundant documentation
   - Search for self-explanatory patterns with noise comments
   - Document over-documentation of clear code

4. **Business Logic Without Context**
   ```dart
   // BAD: Magic numbers and business rules without explanation
   if (user.points > 100 && user.accountAge > 30) {
     user.tier = 'premium';
   }

   // SHOULD EXPLAIN: Why 100 points? Why 30 days?
   // "Premium tier requires 100+ loyalty points and 30+ day account age
   //  (Product requirement PR-2023-045)"
   ```
   - Find business rules without explanation
   - Identify magic numbers without context
   - Search for domain logic without rationale
   - Document missing business context

5. **API Documentation Quality**
   ```dart
   // GOOD: Public API with excellent documentation
   /// Calculates the nutritional information for a recipe.
   ///
   /// Takes into account ingredient quantities, portion sizes, and nutritional
   /// database values. Returns null if ingredients are missing nutritional data.
   ///
   /// **Example:**
   /// ```dart
   /// final nutrition = await calculateNutrition(recipe, portions: 4);
   /// print('Calories per portion: ${nutrition.caloriesPerPortion}');
   /// ```
   ///
   /// **Throws:**
   /// - [ArgumentError] if portions <= 0
   /// - [StateError] if recipe has no ingredients
   NutritionInfo? calculateNutrition(Recipe recipe, {required int portions});

   // BAD: Public API with poor documentation
   /// Calculates nutrition
   NutritionInfo? calculateNutrition(Recipe recipe, {required int portions});
   ```
   - Audit public API documentation completeness
   - Identify APIs without usage examples
   - Search for APIs without error documentation
   - Document API documentation quality

**Output Requirements:**
- Poor naming inventory (variables/methods needing rename, not comments)
- Complex logic without explanation (file:line, what needs explaining)
- Over-documented clear code (candidates for comment deletion)
- Missing business context (magic numbers, business rules)
- Public API documentation gaps
- Self-documentation score (% of code that's clear without comments)

---

### Dimension 5: Documentation Debt (12%)

**Investigation Scope**: Track TODO, FIXME, HACK, NOTE comments and their status

**Gold Standard**: Documentation debt should be minimal and tracked. TODOs should reference tickets.

**Investigate:**

1. **TODO Comment Audit**
   ```dart
   // Find all TODO comments
   // TODO: Implement caching
   // TODO: Add error handling
   // TODO: Optimize this query
   // TODO: Fix this hack
   // TODO: Remove this workaround
   ```
   - Search for all TODO comments (case-insensitive)
   - Categorize by type (feature, bug fix, optimization, cleanup)
   - Identify TODOs without ticket references
   - Check if TODOs are actually complete
   - Document file:line and category for each

2. **FIXME/HACK Comment Audit**
   ```dart
   // Find all FIXME and HACK comments
   // FIXME: This breaks on edge case
   // HACK: Temporary workaround until API is fixed
   // FIXME: Memory leak here
   // HACK: Hardcoded for now
   ```
   - Search for FIXME comments (technical debt)
   - Find HACK comments (workarounds)
   - Identify BUG comments
   - Categorize by severity
   - Document file:line and severity

3. **Documentation Debt Age**
   ```dart
   // BAD: Ancient TODOs nobody remembers
   // TODO: Migrate to new API (added 2020-01-15)
   // FIXME: Performance issue (added 2019-08-22)

   // Check git blame for comment age
   ```
   - Use git blame to find old TODO/FIXME comments
   - Identify comments >1 year old
   - Categorize by age (1-3 months, 3-6 months, 6-12 months, >1 year)
   - Document ancient debt

4. **Missing Ticket References**
   ```dart
   // BAD: TODO without ticket
   // TODO: Implement offline sync

   // GOOD: TODO with ticket
   // TODO(BUTL-1234): Implement offline sync for recipes
   ```
   - Find TODOs without ticket/issue references
   - Identify untraceable documentation debt
   - Document TODOs needing ticket linkage

5. **NOTE/WARNING Comments**
   ```dart
   // Find all NOTE and WARNING comments
   // NOTE: This must be called after initialization
   // WARNING: Do not modify this without updating tests
   // IMPORTANT: Keep in sync with backend
   ```
   - Search for NOTE comments (important context)
   - Find WARNING comments (critical information)
   - Identify IMPORTANT comments
   - Assess if they're legitimate or noise
   - Document file:line and legitimacy

**Output Requirements:**
- TODO inventory with categorization and age
- FIXME/HACK catalog with severity
- Ancient debt list (>1 year old)
- Missing ticket reference count
- NOTE/WARNING assessment
- Documentation debt metrics (total count, avg age, completion rate)
- **Cleanup effort**: X hours (complete, delete, or convert to tickets)

---

### Dimension 6: Architecture & Technical Documentation (10%)

**Investigation Scope**: Evaluate architecture documentation, README files, and technical guides

**Gold Standard**: Architecture should be well-documented for new developers and future maintenance.

**Investigate:**

1. **Architecture Documentation**
   ```
   Check for documentation files:
   - docs/architecture/ files
   - ARCHITECTURE.md
   - docs/MVVM_PATTERN.md
   - docs/DI_SYSTEM.md
   - Component diagrams
   ```
   - Audit existing architecture documentation
   - Check if docs match current implementation
   - Identify outdated architecture diagrams
   - Find undocumented architectural decisions
   - Document architecture doc quality

2. **README Quality**
   ```
   Audit all README files:
   - Root README.md
   - Subdirectory READMEs
   - Getting started guide
   - Development setup
   - Deployment instructions
   ```
   - Review README completeness
   - Check for outdated setup instructions
   - Verify all links work
   - Identify missing information
   - Document README improvements needed

3. **Code Organization Documentation**
   ```dart
   // Check for directory structure docs
   lib/
   ├── core/         // What goes here?
   ├── models/       // Model guidelines?
   ├── services/     // Service patterns?
   ├── viewmodels/   // ViewModel structure?
   └── views/        // View organization?
   ```
   - Find directory structure documentation
   - Check for coding guidelines
   - Identify missing organization docs
   - Document directory purpose clarity

4. **Migration & Upgrade Guides**
   ```
   Check for migration documentation:
   - Breaking changes documented?
   - Upgrade guides for major refactors?
   - Deprecation notices?
   - Migration checklists?
   ```
   - Audit migration guide quality
   - Find undocumented breaking changes
   - Identify missing upgrade paths
   - Document migration doc gaps

5. **Technical Decision Records (ADRs)**
   ```
   Check for architecture decision records:
   - Why MVVM over other patterns?
   - Why Firebase over alternatives?
   - Why GetIt for DI?
   - Major refactoring decisions?
   ```
   - Search for ADR documentation
   - Identify undocumented major decisions
   - Find missing rationale for tech choices
   - Document ADR coverage

**Output Requirements:**
- Architecture documentation assessment
- README quality report
- Code organization doc gaps
- Migration guide completeness
- ADR coverage analysis
- **Improvement effort**: X hours (create missing docs)

---

### Dimension 7: API & Public Interface Documentation (8%)

**Investigation Scope**: Evaluate documentation quality for public-facing code and APIs

**Gold Standard**: Public APIs must have excellent documentation with examples, parameter details, and error cases.

**Investigate:**

1. **Public Class Documentation**
   ```dart
   // GOOD: Comprehensive class documentation
   /// Manages recipe CRUD operations and caching.
   ///
   /// This service provides a unified interface for recipe management,
   /// handling both online and offline scenarios. It automatically
   /// caches recipes for offline access and syncs changes when online.
   ///
   /// **Usage:**
   /// ```dart
   /// final service = ServiceLocator.get<UnifiedRecipeService>();
   /// final recipe = await service.personal.createRecipe(title: 'Pasta');
   /// ```
   class UnifiedRecipeService {

   // BAD: Minimal documentation
   /// Recipe service
   class UnifiedRecipeService {
   ```
   - Audit all public class documentation
   - Check for usage examples
   - Verify comprehensive descriptions
   - Identify poorly documented classes
   - Document public class doc quality

2. **Public Method Documentation**
   ```dart
   // GOOD: Complete method documentation
   /// Creates a new recipe for the current user.
   ///
   /// **Parameters:**
   /// - [title]: Recipe title (1-200 characters)
   /// - [portions]: Number of servings (1-100)
   /// - [ingredients]: List of ingredient descriptions
   ///
   /// **Returns:** The created recipe with generated ID
   ///
   /// **Throws:**
   /// - [ArgumentError] if title is empty or portions invalid
   /// - [AuthException] if user is not authenticated
   /// - [NetworkException] if offline and creation fails
   ///
   /// **Example:**
   /// ```dart
   /// final recipe = await createRecipe(
   ///   title: 'Spaghetti Carbonara',
   ///   portions: 4,
   ///   ingredients: ['pasta', 'eggs', 'bacon'],
   /// );
   /// ```
   Future<Recipe> createRecipe({
     required String title,
     int portions = 4,
     List<String> ingredients = const [],
   });

   // BAD: Minimal method documentation
   /// Creates a recipe
   Future<Recipe> createRecipe({required String title, int portions = 4});
   ```
   - Audit all public method documentation
   - Check for parameter documentation
   - Verify return value documentation
   - Find methods without error documentation
   - Identify methods without examples
   - Document public method doc quality

3. **Parameter & Return Documentation**
   ```dart
   // Check parameter documentation completeness
   /// [userId] - WHAT DOES IT REPRESENT?
   /// [options] - WHAT OPTIONS ARE VALID?
   /// [callback] - WHEN IS IT CALLED?

   // Check return value documentation
   /// Returns a list - OF WHAT? WHEN EMPTY?
   /// Returns null - UNDER WHAT CONDITIONS?
   ```
   - Find parameters without descriptions
   - Identify unclear parameter documentation
   - Check return value documentation
   - Document parameter/return doc gaps

4. **Error & Exception Documentation**
   ```dart
   // GOOD: Exceptions documented
   /// **Throws:**
   /// - [PermissionDeniedException] if user lacks access
   /// - [RecipeNotFoundException] if recipe doesn't exist
   /// - [ValidationException] if data is invalid

   // BAD: Throws not documented
   Future<Recipe> updateRecipe(String id, RecipeData data) {
     // Can throw multiple exceptions, but not documented
   }
   ```
   - Find methods that throw but don't document it
   - Identify exception types without descriptions
   - Check error condition documentation
   - Document exception documentation gaps

5. **Usage Examples & Code Samples**
   ```dart
   // GOOD: Has usage example
   /// **Example:**
   /// ```dart
   /// final recipes = await service.personal.fetchRecipes();
   /// for (final recipe in recipes) {
   ///   print(recipe.title);
   /// }
   /// ```

   // BAD: No usage example for complex API
   Future<List<Recipe>> fetchRecipes({
     RecipeFilter? filter,
     SortOptions? sort,
     PaginationOptions? pagination,
   });
   // Complex parameters but no example showing how to use them
   ```
   - Find complex methods without examples
   - Identify APIs that would benefit from examples
   - Check example code quality and accuracy
   - Document example coverage

**Output Requirements:**
- Public class documentation audit
- Public method documentation gaps
- Parameter/return documentation issues
- Exception documentation gaps
- Usage example coverage
- API documentation score (% well-documented)
- **Improvement effort**: X hours (add examples, document errors)

---

### Dimension 8: User-Facing Documentation (2%)

**Investigation Scope**: Evaluate documentation that users see (help text, error messages, tooltips)

**Gold Standard**: User-facing text should be clear, helpful, and localized.

**Investigate:**

1. **Error Message Quality**
   ```dart
   // BAD: Technical error shown to user
   throw Exception('NullPointerException in RecipeService.fetchRecipes');

   // GOOD: User-friendly error
   throw AppException('Unable to load recipes. Please check your connection.');
   ```
   - Find technical errors shown to users
   - Identify unhelpful error messages
   - Check error message localization
   - Document error message quality

2. **Help Text & Tooltips**
   ```dart
   // Check UI help text quality
   Tooltip(
     message: 'Click here',  // BAD: Not helpful
     // vs
     message: 'Add recipe to your favorites for quick access',  // GOOD
   )
   ```
   - Audit tooltip helpfulness
   - Find vague or obvious help text
   - Check help text localization
   - Document help text improvements

3. **Placeholder Text**
   ```dart
   // Check TextField placeholders
   hintText: 'Enter text',  // BAD: Generic
   hintText: 'Enter recipe title (e.g., "Spaghetti Carbonara")',  // GOOD
   ```
   - Review placeholder text quality
   - Find generic placeholders
   - Check for examples in placeholders
   - Document placeholder improvements

4. **Empty State Messages**
   ```dart
   // BAD: Vague empty state
   'No items'

   // GOOD: Helpful empty state
   'No recipes yet. Tap the + button to create your first recipe!'
   ```
   - Audit empty state messaging
   - Find unhelpful empty states
   - Check for actionable guidance
   - Document empty state quality

**Output Requirements:**
- Error message quality audit
- Help text assessment
- Placeholder text review
- Empty state message evaluation
- User-facing documentation score
- **Improvement effort**: X hours (rewrite messages)

---

## Investigation Process

### Week 1: Comment Quality Analysis (Days 1-3)

**Day 1: Comment Bloat Investigation (3-4 hours)**
1. Search for obvious comment patterns ("increment", "create", "return")
2. Audit all DartDoc for redundancy
3. Find over-commented simple code
4. Identify comment clutter and placeholders
5. **Output**: Bloat inventory with file:line references

**Day 2: Outdated & Misleading Documentation (3-4 hours)**
6. Check method docs against implementations
7. Find outdated API references
8. Identify broken references and links
9. Audit TODO/FIXME for completion
10. **Output**: Incorrect documentation catalog (CRITICAL)

**Day 3: Commented-Out Code Sweep (2-3 hours)**
11. Search for large commented code blocks (5+ lines)
12. Find experimental/debug code remnants
13. Identify implementation graveyards
14. Document refactoring artifacts
15. **Output**: Commented code inventory

### Week 2: Documentation Quality & Completeness (Days 4-6)

**Day 4: Self-Documenting Code Assessment (3-4 hours)**
16. Find poor naming requiring comments
17. Identify complex logic without explanation
18. Audit well-named code with redundant comments
19. Find business logic without context
20. **Output**: Clarity assessment

**Day 5: Documentation Debt & Architecture (3-4 hours)**
21. Complete TODO/FIXME/HACK audit
22. Check documentation debt age (git blame)
23. Review architecture documentation
24. Audit README files
25. **Output**: Debt metrics, architecture doc assessment

**Day 6: API & User-Facing Documentation (2-3 hours)**
26. Audit public API documentation
27. Check parameter/return/exception docs
28. Review usage examples
29. Evaluate user-facing messages
30. **Output**: API doc quality report

### Week 3: Synthesis & Reporting (Day 7)

**Day 7: Comprehensive Report (2-3 hours)**
31. Calculate dimension scores (weighted)
32. Create executive summary
33. Categorize all issues by severity
34. Generate cleanup effort estimates
35. Create documentation quality dashboard
36. **Output**: Complete documentation analysis report

---

## Output Deliverables

### 1. Executive Summary
```markdown
# BUTLERY DOCUMENTATION ANALYSIS - PHASE 1: INVESTIGATION FINDINGS

Analysis Date: [Date]
Analyst: Claude (Sonnet 4.5)
Codebase: 812 files, 138k LOC

## OVERALL DOCUMENTATION SCORE: X/100

├─ Comment Bloat & Noise:        X/25 points
├─ Outdated & Misleading Docs:   X/20 points
├─ Commented-Out Code:           X/18 points
├─ Self-Documenting Code:        X/15 points
├─ Documentation Debt:           X/12 points
├─ Architecture Documentation:   X/10 points
├─ API Documentation:            X/8 points
└─ User-Facing Documentation:    X/2 points

## DOCUMENTATION QUALITY: [Excellent | Good | Needs Improvement | Poor]

### Issue Summary
- **CRITICAL**: X misleading/incorrect docs
- **HIGH**: X bloated/obvious comments
- **MEDIUM**: X commented-out code blocks
- **LOW**: X missing API documentation

### Cleanup Metrics
- **Delete**: X lines of comment bloat
- **Fix**: X outdated/incorrect docs
- **Add**: X missing explanations
- **Total Effort**: X hours
```

### 2. Comment Bloat Inventory
```markdown
## Comment Bloat & Noise - Score: X/25

### Summary
Found X instances of comment bloat across Y files:
- Obvious comments: X (state the obvious)
- Redundant DartDoc: X (adds no value)
- Over-commented clear code: X sections
- Visual clutter: X decorative comments
- Placeholder noise: X empty placeholders

### Critical Bloat Examples

#### Obvious Comments (X found)
| File | Line | Comment | Why It's Noise |
|------|------|---------|----------------|
| lib/services/recipe_service.dart | 142 | `// Increment counter` | Obvious from code |
| lib/models/recipe.dart | 67 | `// Create new user` | Redundant |

#### Redundant DartDoc (X found)
| File | Line | Method | Issue |
|------|------|--------|-------|
| lib/services/auth_service.dart | 89 | `getUserId()` | "Gets the user ID" adds nothing |

### Recommendations
1. Delete X obvious comments (save X lines)
2. Remove X redundant DartDoc entries (save X lines)
3. Clean up X over-commented sections (improve readability)

### Quick Wins
- Delete all "increment counter" style comments: X instances
- Remove "Constructor", "Variables" placeholder comments: X instances
- Clean ASCII art section separators: X instances

**Estimated Cleanup Effort**: X hours (mostly delete operations)
```

### 3. Outdated & Misleading Documentation Report
```markdown
## Outdated & Misleading Documentation - Score: X/20

### ⚠️ CRITICAL: Incorrect Documentation (X found)

**These are HIGH PRIORITY - misleading docs are worse than no docs**

| File | Line | Documented Behavior | Actual Behavior | Severity |
|------|------|---------------------|-----------------|----------|
| lib/services/recipe_service.dart | 234 | "Returns user email" | Returns user name | CRITICAL |
| lib/repositories/auth_repo.dart | 89 | "Deletes the user" | Archives the user | HIGH |

### Outdated Implementation Comments (X found)
| File | Line | Outdated Reference | Current Implementation |
|------|------|-------------------|----------------------|
| lib/services/data_service.dart | 156 | "Uses Firebase v8" | Now using v9 modular |

### Broken References (X found)
| File | Line | Broken Reference | Issue |
|------|------|------------------|-------|
| lib/models/user.dart | 45 | `See [AuthService]` | Renamed to UserService |

### Misleading TODOs (X found)
| File | Line | TODO Comment | Actually Complete? |
|------|------|--------------|-------------------|
| lib/services/cache.dart | 78 | "TODO: Add error handling" | Error handling exists |

**Estimated Fix Effort**: X hours (verify + update/delete each)
```

### 4. Commented-Out Code Inventory
```markdown
## Commented-Out Code - Score: X/18

### Summary
Found X lines of commented-out code across Y files:
- Large code blocks (5+ lines): X blocks
- Experimental/debug code: X instances
- Implementation graveyards: X files with multiple versions
- Refactoring artifacts: X migration remnants

### Critical Findings

#### Large Commented Code Blocks (X found)
| File | Lines | Block Size | Type |
|------|-------|------------|------|
| lib/services/recipe_service.dart | 234-278 | 44 lines | Old implementation |
| lib/viewmodels/auth_vm.dart | 123-167 | 44 lines | Experimental code |

#### Implementation Graveyards (X files)
| File | Versions Found | Total Lines | Age |
|------|----------------|-------------|-----|
| lib/services/sync_service.dart | 4 versions | 156 lines | 6-18 months |

### Recommendations
1. **DELETE ALL** commented code (version control has history)
2. Focus on files with 20+ commented lines first
3. Verify safety with git blame before deletion

**Cleanup Impact**:
- Delete X lines of dead code
- Clean X files
- Improve readability significantly

**Estimated Cleanup Effort**: X hours (verify safety + delete)
```

### 5. Self-Documenting Code Assessment
```markdown
## Self-Documenting Code vs Over-Documentation - Score: X/15

### Summary
- Poor naming requiring comments: X instances
- Complex logic without explanation: X cases
- Well-named code with redundant comments: X instances
- Missing business context: X magic numbers/rules

### Poor Naming Disguised as Documentation Need

| File | Line | Current | Comment | Should Be |
|------|------|---------|---------|-----------|
| lib/services/user_service.dart | 89 | `bool f` | "User auth status" | `isAuthenticated` |
| lib/models/recipe.dart | 45 | `int t` | "Prep time mins" | `preparationTimeMinutes` |

**Fix**: Rename variables, delete comments (X instances)

### Complex Logic Without Explanation (X found)

| File | Line | Complexity | Missing Explanation |
|------|------|-----------|-------------------|
| lib/services/analytics.dart | 234 | Dense algorithm | What it does, why |

**Fix**: Add WHY comments to complex logic (X instances)

### Redundant Comments on Clear Code (X found)

| File | Line | Code | Redundant Comment |
|------|------|------|------------------|
| lib/services/recipe_service.dart | 156 | `calculateTotalPrice()` | "Calculates total price" |

**Fix**: Delete redundant comments (X instances)

### Self-Documentation Score: X%
- Code clear without comments: X%
- Code needing legitimate explanation: X%
- Code with poor naming: X%

**Estimated Improvement Effort**: X hours (rename + add/delete comments)
```

### 6. Documentation Debt Report
```markdown
## Documentation Debt - Score: X/12

### TODO Inventory (X found)

#### By Category:
- Feature work: X TODOs
- Bug fixes: X FIXMEs
- Optimizations: X TODOs
- Cleanup: X TODOs
- Unknown/vague: X TODOs

#### By Age (from git blame):
- 0-3 months: X TODOs
- 3-6 months: X TODOs
- 6-12 months: X TODOs
- **>1 year: X TODOs** (ancient debt!)

#### Without Ticket References: X TODOs (X%)

### Ancient Debt (>1 year old)

| File | Line | TODO | Age | Status |
|------|------|------|-----|--------|
| lib/services/sync.dart | 89 | "TODO: Offline sync" | 18 months | Unknown |

### Misleading TODOs (Already Complete) - X found

| File | Line | TODO | Actually Done? |
|------|------|------|----------------|
| lib/services/error.dart | 45 | "TODO: Error handling" | Yes, 6 months ago |

### HACK/FIXME Comments (X found)

| File | Line | Type | Issue | Severity |
|------|------|------|-------|----------|
| lib/services/auth.dart | 123 | HACK | Hardcoded timeout | Medium |

### Recommendations
1. Delete X completed TODOs
2. Add ticket references to X TODOs
3. Fix or document X HACK/FIXME comments
4. Archive TODOs >1 year old (X items)

**Cleanup Effort**: X hours (triage + fix/delete/ticket)
```

### 7. Architecture Documentation Assessment
```markdown
## Architecture & Technical Documentation - Score: X/10

### Architecture Documentation Quality

| Document | Status | Quality | Outdated? |
|----------|--------|---------|-----------|
| docs/architecture/MVVM_PATTERN.md | Exists | Good | No |
| docs/architecture/DI_SYSTEM.md | Exists | Excellent | No |
| ARCHITECTURE.md | Missing | N/A | N/A |

### README Quality

| README | Completeness | Accuracy | Last Updated |
|--------|--------------|----------|--------------|
| Root README.md | 80% | Good | 2 months ago |
| lib/README.md | Missing | N/A | N/A |

### Missing Documentation

1. **Critical Missing Docs:**
   - Directory structure guide
   - Coding standards document
   - Contribution guidelines

2. **Outdated Docs:**
   - Firebase setup guide (references v8, now v9)
   - Deployment instructions (missing new steps)

3. **Missing Architecture Decision Records (ADRs):**
   - Why MVVM over BLoC?
   - Why GetIt for DI?
   - Why Firebase over alternatives?

**Improvement Effort**: X hours (create/update missing docs)
```

### 8. API Documentation Quality Report
```markdown
## API & Public Interface Documentation - Score: X/8

### Public Class Documentation

**Well Documented**: X classes (X%)
**Poor Documentation**: X classes (X%)
**Missing Documentation**: X classes (X%)

### Public Method Documentation Gaps

| Class | Method | Missing |
|-------|--------|---------|
| UnifiedRecipeService | `createRecipe()` | Parameter details, examples |
| UserService | `updateProfile()` | Error documentation |

### Methods Without Examples: X (X% of public methods)

**High-value methods needing examples:**
- `UnifiedRecipeService.personal.createRecipe()`
- `UnifiedShoppingService.collaborative.shareList()`
- Complex configuration methods

### Exception Documentation Gaps: X methods

**Methods that throw but don't document:**
- X methods throw exceptions but don't document them
- Common undocumented exceptions: AuthException, NetworkException

### API Documentation Score: X%

**Improvement Effort**: X hours (add examples, document parameters/errors)
```

---

## Phase 1 Deliverables Checklist

**Investigation & Documentation Only - No Code Changes**

- [ ] Executive summary with overall documentation score
- [ ] Comment bloat inventory with file:line references
- [ ] Outdated/misleading documentation catalog (CRITICAL)
- [ ] Commented-out code inventory with line counts
- [ ] Self-documenting code assessment
- [ ] Documentation debt metrics (TODO/FIXME age and status)
- [ ] Architecture documentation quality report
- [ ] API documentation gaps analysis
- [ ] User-facing documentation review
- [ ] Cleanup effort estimates (hours per category)
- [ ] Prioritized recommendations (critical → low)

---

## Phase 1 Success Criteria

**This investigation phase is complete when:**

1. ✅ All 8 dimensions investigated thoroughly
2. ✅ Every bloated/misleading comment documented with file:line
3. ✅ All commented-out code cataloged with block sizes
4. ✅ Documentation debt fully audited (TODO/FIXME inventory)
5. ✅ Architecture documentation assessed for accuracy
6. ✅ API documentation gaps identified
7. ✅ Cleanup effort estimated per category
8. ✅ Issues prioritized (misleading → bloat → gaps → debt)
9. ✅ **ZERO code changes made** - documentation only
10. ✅ Phase 2 preparation complete (cleanup plan ready)

**Phase 1 Output:** Comprehensive documentation findings report.

**Phase 2 Input:** Use this report to create smart cleanup plan (delete bloat, fix misleading, add missing).

---

## Known Context (Pre-Investigation)

Based on codebase analysis:

1. **Current State**
   - 812 Dart files in lib/
   - 138k lines of code
   - Likely significant commenting (Flutter convention)
   - Known TODO count: 14 (very low - good sign)

2. **Documentation Patterns to Check**
   - DartDoc usage on public APIs
   - Inline comment frequency
   - Commented-out code from refactoring (MVVM migration, DI migration)
   - Architecture docs in docs/ directory

3. **Known Refactorings** (potential commented code sources)
   - AsyncOperationMixin migration (12-15 ViewModels)
   - BaseService adoption (96% complete)
   - Repository pattern migration (68% adoption)
   - These may have left commented old implementations

4. **Documentation Standards**
   - CLAUDE.md exists (project instructions)
   - docs/ directory structure exists
   - Likely some architecture documentation
   - Check consistency and accuracy

---

## Analysis Approach Guidelines

### Be Uncompromising on Quality

- **Call out bloat directly**: "This comment is noise"
- **Prioritize accuracy**: Misleading docs are CRITICAL
- **Value clarity**: Self-documenting code > comments
- **Respect complexity**: Complex logic SHOULD have explanation
- **Delete ruthlessly**: Commented code should not exist

### Documentation Philosophy

**Good Comments Explain:**
- ✅ WHY (rationale, business rules, decisions)
- ✅ Complex algorithms (what it does in plain English)
- ✅ Non-obvious behavior (edge cases, gotchas)
- ✅ Public APIs (parameters, returns, errors, examples)

**Bad Comments Explain:**
- ❌ WHAT (obvious from code)
- ❌ Simple operations (increment, create, return)
- ❌ Well-named methods (name says it all)
- ❌ Standard patterns (common Flutter/Dart idioms)

### Severity Classification

**CRITICAL** (fix immediately):
- Misleading/incorrect documentation
- Broken references in docs
- Outdated API documentation

**HIGH** (next sprint):
- Excessive comment bloat (noise)
- Large commented-out code blocks
- Missing API documentation

**MEDIUM** (backlog):
- Redundant DartDoc
- Documentation debt (old TODOs)
- Missing architecture docs

**LOW** (nice-to-have):
- Visual clutter (ASCII art)
- Minor placeholder comments
- Missing usage examples

---

## 🚀 BEGIN PHASE 1 INVESTIGATION NOW

**CRITICAL REMINDERS:**
- 🚫 **NO CODE CHANGES** - Investigation and documentation ONLY
- 📋 Document every finding with file:line references
- 🏷️ Categorize all issues by severity (Critical/High/Medium/Low)
- ⏱️ Provide cleanup effort estimates (hours)
- 🎯 Follow all 8 dimensions systematically
- ✅ Complete deliverables checklist before finishing

**Your Mission:**
Execute comprehensive documentation quality investigation. Find every instance of:
- Bloated obvious comments
- Misleading outdated docs
- Commented-out dead code
- Missing explanations for complex logic
- Poor API documentation

Document everything. Change nothing.

**This codebase deserves clean, accurate, minimal documentation** - and this investigation is the first step to achieving it.

**Phase 1 Goal:** A complete documentation quality report ready for Phase 2 cleanup planning.

---

## Time Estimate

**Total Investigation Time: 12-16 hours**
- Week 1 (Comment Quality): 8-11 hours
- Week 2 (Documentation Completeness): 3-4 hours
- Week 3 (Synthesis): 1-1 hours
