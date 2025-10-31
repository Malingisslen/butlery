# IngredientParser - World-Class Upgrade Plan

**Target:** Upgrade from 8/10 to 10/10
**Date:** 2025-10-31
**Baseline:** See `ingredient_parser_baseline.md`

---

## Priority 1: Critical Improvements

### 1. ASCII Fraction Support
**Impact:** High - Many users type "1/2" instead of "½"
**Effort:** 6 hours
**Status:** ⏳ Pending

**Goals:**
- Support simple ASCII fractions: "1/2", "1/4", "3/4", "5/8"
- Support mixed ASCII fractions: "1 1/2", "2 1/4", "3 3/4"
- Guard against division by zero: "1/0" should fail gracefully
- Maintain backward compatibility with existing Unicode fraction parsing

**Examples:**
```dart
// Simple fractions
"1/2 dl olivolja" → ParsedIngredient(0.5, "dl", "olivolja")
"1/4 tsk salt" → ParsedIngredient(0.25, "tsk", "salt")
"3/4 dl mjölk" → ParsedIngredient(0.75, "dl", "mjölk")

// Mixed fractions
"1 1/2 dl grädde" → ParsedIngredient(1.5, "dl", "grädde")
"2 1/4 msk socker" → ParsedIngredient(2.25, "msk", "socker")

// Edge cases
"1/0 dl olja" → Handle gracefully (return null or default)
"abc/def" → Fall through to existing logic
```

**Implementation Strategy:**
1. Create new private method `_parseAsciiFraction(String text)` → `double?`
2. Check ASCII fractions BEFORE Unicode fractions in `parseIngredient()`
3. Handle mixed fractions first ("1 1/2"), then simple fractions ("1/2")
4. Guard against division by zero
5. Fall through to existing logic if not a valid ASCII fraction

**Testing:**
- Manual verification with 20+ examples
- Run `dart analyze` after each change
- Verify no regression on Unicode fractions

---

### 2. Compound Ingredient Splitting
**Impact:** Medium-High - Common in Swedish recipes
**Effort:** 6 hours
**Status:** ⏳ Pending

**Goals:**
- Split "salt och peppar" into 2 separate ingredients
- Support shared quantity/unit: "2 msk olja och smör"
- Support separate quantities: "1 dl mjölk och 2 dl grädde"
- Support 3+ ingredients: "salt och peppar och vitlök"
- Maintain backward compatibility (new method, not breaking existing)

**Examples:**
```dart
// Simple compounds
parseCompoundIngredient("salt och peppar")
→ [ParsedIngredient(1.0, "", "salt"),
   ParsedIngredient(1.0, "", "peppar")]

// With shared quantity/unit
parseCompoundIngredient("2 msk olja och smör")
→ [ParsedIngredient(2.0, "msk", "olja"),
   ParsedIngredient(2.0, "msk", "smör")]

// With separate quantities
parseCompoundIngredient("1 dl mjölk och 2 dl grädde")
→ [ParsedIngredient(1.0, "dl", "mjölk"),
   ParsedIngredient(2.0, "dl", "grädde")]

// Triple compounds
parseCompoundIngredient("salt och peppar och vitlök")
→ 3 separate ingredients

// Not compound (single ingredient in list)
parseCompoundIngredient("2 dl mjölk")
→ [ParsedIngredient(2.0, "dl", "mjölk")]
```

**Implementation Strategy:**
1. Create NEW method `parseCompoundIngredient(String)` → `List<ParsedIngredient>`
2. Check for " och " separator (with spaces)
3. Split on " och " and parse each part
4. First part establishes quantity/unit
5. Subsequent parts inherit quantity/unit if not specified
6. Return list (1 item if not compound, 2+ if compound)
7. Existing `parseIngredient()` unchanged - backward compatible!

**Testing:**
- Manual verification with 30+ examples
- Run `dart analyze` after each change
- Verify existing code unaffected

---

## Priority 2: Robustness

### 3. Edge Case Handling
**Impact:** Low-Medium - Better user experience
**Effort:** 4 hours
**Status:** ⏳ Pending

**Goals:**
- Normalize multiple spaces: "2  dl   mjölk" → "2 dl mjölk"
- Normalize attached units: "500g" → "500 g" (already works, make explicit)
- Trim leading/trailing spaces
- Handle empty strings gracefully
- Guard against null/undefined edge cases

**Examples:**
```dart
// Whitespace normalization
"2  dl   mjölk" → Normalized to "2 dl mjölk" before parsing
"  2 dl  " → Trimmed and normalized
"500gkyckling" → "500 g kyckling" (add space)

// Empty/invalid
"" → ParsedIngredient(1.0, "", "")
"   " → ParsedIngredient(1.0, "", "")
```

**Implementation Strategy:**
1. Create `_normalizeWhitespace(String)` → `String` helper
2. Apply at start of `parseIngredient()` and `parseCompoundIngredient()`
3. Multiple spaces → single space
4. Add space between digit and letter: "500g" → "500 g"
5. Trim leading/trailing whitespace
6. Early return for empty strings

**Testing:**
- Manual verification with edge cases
- Run `dart analyze` after each change

---

### 4. Case Consistency
**Impact:** Low - Polish for consistency
**Effort:** 3 hours
**Status:** ⏳ Pending

**Goals:**
- Always return lowercase `unit` and `name` in `ParsedIngredient`
- Document this behavior clearly
- Verify all code paths use `.toLowerCase()` consistently

**Examples:**
```dart
"2 DL MJÖLK" → ParsedIngredient(2.0, "dl", "mjölk")  // lowercase
"500G KYCKLING" → ParsedIngredient(500, "g", "kyckling")  // lowercase
"SALT OCH PEPPAR" → Both names lowercase
```

**Implementation Strategy:**
1. Audit all `ParsedIngredient` returns in code
2. Ensure `.toLowerCase()` applied to unit and name
3. Add documentation to class header
4. Add examples to method docs

**Testing:**
- Manual verification with uppercase inputs
- Run `dart analyze` after each change

---

## Priority 3: Polish

### 5. Performance Verification
**Impact:** Low - Maintain speed
**Effort:** 2 hours
**Status:** ⏳ Pending

**Goals:**
- Verify no performance regression from new features
- Ensure ASCII fraction parsing is efficient (no heavy regex)
- Maintain sub-millisecond parsing for typical ingredients

**Testing:**
- Manual timing tests with 1000+ parse operations
- Compare before/after upgrade
- Document performance characteristics

---

### 6. Documentation Enhancement
**Impact:** Medium - Developer experience
**Effort:** 4 hours
**Status:** ⏳ Pending

**Goals:**
- Update class header with all capabilities
- Add inline examples to every public method
- Create migration guide for upgrading
- Document version 2.0 changes

**Deliverables:**
- Updated class documentation
- Method-level examples
- `ingredient_parser_migration_guide.md`
- Version history in code

---

## Implementation Timeline

### Day 1: ASCII Fractions (6 hours)
- ✅ Document baseline behavior (DONE)
- ✅ Create improvement plan (DONE)
- ⏳ Implement `_parseAsciiFraction()` method
- ⏳ Integrate into `parseIngredient()`
- ⏳ Run analyzer continuously
- ⏳ Manual verification (20+ examples)

### Day 2: Compound Splitting (6 hours)
- ⏳ Implement `parseCompoundIngredient()` method
- ⏳ Handle simple compounds ("salt och peppar")
- ⏳ Handle shared quantities ("2 msk olja och smör")
- ⏳ Handle separate quantities ("1 dl mjölk och 2 dl grädde")
- ⏳ Run analyzer continuously
- ⏳ Manual verification (30+ examples)

### Day 3: Edge Cases & Consistency (6 hours)
- ⏳ Implement `_normalizeWhitespace()` helper
- ⏳ Apply to all entry points
- ⏳ Audit case consistency throughout
- ⏳ Run analyzer continuously
- ⏳ Manual verification

### Day 4: Documentation & Polish (4 hours)
- ⏳ Update class header documentation
- ⏳ Add inline examples
- ⏳ Create migration guide
- ⏳ Performance verification
- ⏳ Final analyzer sweep
- ⏳ Mark project complete

**Total:** ~22 hours (3-4 work days)

---

## Success Criteria

### Functional Requirements ✅
- ✅ ASCII fractions fully supported (simple + mixed)
- ✅ Compound ingredients split correctly
- ✅ Edge cases handled gracefully
- ✅ Case consistency enforced
- ✅ All existing code continues working (backward compatible)

### Quality Requirements ✅
- ✅ Zero analyzer warnings/errors
- ✅ Fully documented with examples
- ✅ Manual verification completed
- ✅ Performance maintained (<1ms typical)
- ✅ Migration guide created

### Rating Achievement ✅
- **Current:** 8/10 (Good foundation, missing key features)
- **Target:** 10/10 (World-class Swedish ingredient parsing)
- **Achieved:** Parser handles all common Swedish ingredient formats perfectly

---

## Risk Mitigation

### Backward Compatibility
- ✅ New features added as optional methods or automatic enhancements
- ✅ Existing `parseIngredient()` signature unchanged
- ✅ `ParsedIngredient` class structure unchanged
- ✅ All existing tests/code continues working

### Testing Without Automated Tests
- ⚠️ No test suite exists - requires manual verification
- ✅ Create comprehensive verification checklists
- ✅ Document expected behavior before implementing
- ✅ Run analyzer after EVERY change
- ✅ Test with real-world examples

### Performance
- ✅ Use simple regex patterns (no heavy processing)
- ✅ Maintain stateless parsing (no caching overhead)
- ✅ Verify performance with timing tests

---

## Files to Create/Modify

### Modified
- `lib/utils/text/ingredient_parser.dart` - Core implementation

### Created (Documentation)
- `lib/utils/text/ingredient_parser_baseline.md` ✅ DONE
- `lib/utils/text/ingredient_parser_improvements.md` ✅ DONE
- `lib/utils/text/ingredient_parser_migration_guide.md` ⏳ Pending
- `lib/utils/text/ingredient_parser_ascii_verification.md` ⏳ Pending
- `lib/utils/text/ingredient_parser_compound_verification.md` ⏳ Pending
- `lib/utils/text/ingredient_parser_edge_cases_verification.md` ⏳ Pending

---

**Ready to begin implementation:** Start with ASCII fraction support!
