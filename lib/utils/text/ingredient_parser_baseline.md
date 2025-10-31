# IngredientParser - Current Behavior (Baseline)

**Version:** 1.0 (Pre-upgrade)
**Date:** 2025-10-31
**Purpose:** Document current behavior before world-class upgrade

---

## What Works ✅

### 1. Unicode Fractions (Excellent)
The parser handles traditional Swedish Unicode fractions perfectly:

```dart
// Simple unicode fractions
"½ dl olivolja" → ParsedIngredient(quantity: 0.5, unit: "dl", name: "olivolja")
"¼ tsk salt" → ParsedIngredient(quantity: 0.25, unit: "tsk", name: "salt")
"¾ dl mjölk" → ParsedIngredient(quantity: 0.75, unit: "dl", name: "mjölk")

// Mixed unicode fractions
"2 ½ dl grädde" → ParsedIngredient(quantity: 2.5, unit: "dl", name: "grädde")
"1 ¼ msk socker" → ParsedIngredient(quantity: 1.25, unit: "msk", name: "socker")
"3 ¾ dl vatten" → ParsedIngredient(quantity: 3.75, unit: "dl", name: "vatten")
```

### 2. Swedish Comma Decimals (Excellent)
Proper handling of Swedish number formatting:

```dart
"2,5 dl mjölk" → ParsedIngredient(quantity: 2.5, unit: "dl", name: "mjölk")
"1,75 kg mjöl" → ParsedIngredient(quantity: 1.75, unit: "kg", name: "mjöl")
"0,5 tsk vaniljsocker" → ParsedIngredient(quantity: 0.5, unit: "tsk", name: "vaniljsocker")
```

### 3. Attached Units (Good)
Regex-based parsing handles units attached to numbers:

```dart
"500g kycklingfilé" → ParsedIngredient(quantity: 500, unit: "g", name: "kycklingfilé")
"2dl mjölk" → ParsedIngredient(quantity: 2, unit: "dl", name: "mjölk")
"400g finhackad kött" → ParsedIngredient(quantity: 400, unit: "g", name: "finhackad kött")
```

### 4. Whole Numbers (Excellent)
Standard integer quantities:

```dart
"2 dl mjölk" → ParsedIngredient(quantity: 2.0, unit: "dl", name: "mjölk")
"400 g mjöl" → ParsedIngredient(quantity: 400.0, unit: "g", name: "mjöl")
"3 ägg" → ParsedIngredient(quantity: 3.0, unit: "", name: "ägg")
```

### 5. Unit-First Detection (Excellent)
Smart algorithm prioritizes known units for accurate parsing:

```dart
"1 msk smör" → ParsedIngredient(quantity: 1.0, unit: "msk", name: "smör")
"2 tsk salt" → ParsedIngredient(quantity: 2.0, unit: "tsk", name: "salt")
"5 st ägg" → ParsedIngredient(quantity: 5.0, unit: "st", name: "ägg")
```

### 6. Unit-less Ingredients (Good)
Handles ingredients without measurement units:

```dart
"3 ägg" → ParsedIngredient(quantity: 3.0, unit: "", name: "ägg")
"1 stor lök" → ParsedIngredient(quantity: 1.0, unit: "", name: "stor lök")
"salt" → ParsedIngredient(quantity: 1.0, unit: "", name: "salt")
```

### 7. Comprehensive Unit Support (Excellent)
Extensive unit recognition (50+ units):

**Swedish Units:**
- Weight: g, kg, hg, dag, mg
- Volume: dl, l, ml, cl
- Cooking: msk, tsk, krm
- Packaging: burk, pkt, förpackning, påse, ask, flaska
- Counting: st, bit, skiva, klyfta, port, knippe, blad, kvist, etc.

**American Units:**
- Volume: cup, cups, oz, fl oz, tbsp, tsp, pint, quart, gallon
- Weight: lb, lbs, pound, pounds, ounce, ounces

### 8. Case Insensitivity (Good)
Handles mixed case input:

```dart
"2 DL MJÖLK" → ParsedIngredient(quantity: 2.0, unit: "dl", name: "mjölk")
"500G Kyckling" → ParsedIngredient(quantity: 500, unit: "g", name: "kyckling")
```

### 9. Intelligent Scaling (Excellent)
The `scaleAndFormatIngredient()` method provides:
- Smart unit conversion (800g → 0.8kg)
- Swedish fraction formatting (½, ¼, ¾)
- Pluralization support via SwedishPluralization
- Preservation of original format when appropriate

### 10. Empty Input Handling (Good)
Gracefully handles empty strings:

```dart
"" → ParsedIngredient(quantity: 1.0, unit: "", name: "")
"   " → ParsedIngredient(quantity: 1.0, unit: "", name: "")
```

---

## What Doesn't Work ❌

### 1. ASCII Fractions (Critical Gap)
Users typing ASCII fractions will not get expected results:

```dart
// FAILS - ASCII simple fractions not supported
"1/2 dl olivolja" → Likely parsed incorrectly
"1/4 tsk salt" → Likely parsed incorrectly
"3/4 dl mjölk" → Likely parsed incorrectly

// FAILS - ASCII mixed fractions not supported
"1 1/2 dl grädde" → Likely parsed incorrectly
"2 1/4 msk socker" → Likely parsed incorrectly

// Expected behavior:
"1/2 dl olivolja" → SHOULD BE ParsedIngredient(0.5, "dl", "olivolja")
"1 1/2 dl grädde" → SHOULD BE ParsedIngredient(1.5, "dl", "grädde")
```

**Impact:** High - Many users type fractions as "1/2" instead of "½"
**Priority:** P1 - Critical improvement

### 2. Compound Ingredients (Major Gap)
No support for splitting "och" (and) separated ingredients:

```dart
// CURRENT BEHAVIOR - treats as single ingredient
"salt och peppar" → ParsedIngredient(1.0, "", "salt och peppar")

// EXPECTED BEHAVIOR - should split into 2
"salt och peppar" → Should return 2 separate ingredients:
  - ParsedIngredient(1.0, "", "salt")
  - ParsedIngredient(1.0, "", "peppar")

// More complex cases:
"2 msk olja och smör" → Should split with shared quantity:
  - ParsedIngredient(2.0, "msk", "olja")
  - ParsedIngredient(2.0, "msk", "smör")

"1 dl mjölk och 2 dl grädde" → Should split with separate quantities:
  - ParsedIngredient(1.0, "dl", "mjölk")
  - ParsedIngredient(2.0, "dl", "grädde")

"salt och peppar och vitlök" → Should split into 3 ingredients
```

**Impact:** Medium-High - Common in Swedish recipes to list multiple ingredients together
**Priority:** P1 - Critical improvement

### 3. Whitespace Edge Cases (Minor)
Some whitespace variations might not be handled perfectly:

```dart
// Attached units with no space work (via regex)
"500g kyckling" → Works ✓

// But multiple spaces might have inconsistencies
"2  dl   mjölk" → May work but not documented/tested
"  2 dl  " → Should trim but not verified
```

**Impact:** Low - Edge cases in user input
**Priority:** P2 - Nice to have

### 4. Division by Zero in ASCII Fractions
If ASCII fraction parsing is added, need to guard against:

```dart
"1/0 dl olja" → Must handle gracefully (avoid crash)
"0/0 tsk salt" → Must handle gracefully
```

**Impact:** Low - Rare user input, but safety critical
**Priority:** P2 - Must handle when implementing ASCII fractions

### 5. Normalization Inconsistency
No explicit whitespace normalization helper documented:

```dart
// These SHOULD work but behavior not explicitly guaranteed:
"500g kyckling" vs "500  g  kyckling" vs "500g" vs "500 g"
```

**Impact:** Low - Mostly works due to regex, but not explicit
**Priority:** P2 - Polish for consistency

---

## API Surface

### Public Methods
1. `parseQuantity(String qtyString)` → `double`
   - Parses Swedish quantity strings with fractions
   - Currently supports Unicode fractions only

2. `parseIngredient(String rawIngredient)` → `ParsedIngredient`
   - Main parsing method
   - Returns single ParsedIngredient (no compound splitting)

3. `scaleAndFormatIngredient(String rawIngredient, double scaleFactor)` → `String`
   - Intelligent scaling with unit conversion
   - Swedish formatting with fractions and pluralization

### Data Structure
```dart
class ParsedIngredient {
  final double quantity;
  final String unit;
  final String name;

  String get key;  // For grouping in shopping lists
  String toString();
}
```

---

## Dependencies
- `text_formatting.dart` - Swedish fraction formatting
- `unit_converter.dart` - Smart unit conversion
- `swedish_pluralization.dart` - Ingredient pluralization

---

## Architecture Strengths
1. **Unit-First Detection** - Prioritizes known units for accuracy
2. **Regex Fallback** - Handles attached units like "400g"
3. **Smart Scaling** - Unit optimization and Swedish formatting
4. **Comprehensive Units** - 50+ Swedish and American units
5. **Clean API** - Static utility class with clear methods

---

## Performance Characteristics
- **Speed:** Sub-millisecond parsing for typical ingredients
- **Memory:** Minimal allocation (no caching, stateless parsing)
- **Regex:** Single quantityRegex pattern, efficient matching

---

## Test Coverage Status
**Note:** No automated tests exist (verified by user context)
**Verification Method:** Manual testing with real examples
**Risk:** Changes must be carefully validated manually

---

## Upgrade Path

### Priority 1: Critical Improvements (P1)
1. **ASCII Fraction Support** - Add "1/2", "3/4", "1 1/2" parsing
2. **Compound Splitting** - Add method to split "salt och peppar"

### Priority 2: Robustness (P2)
3. **Edge Case Handling** - Whitespace normalization, division by zero
4. **Case Consistency** - Ensure lowercase output consistently

### Priority 3: Polish (P3)
5. **Performance Verification** - Ensure no regression
6. **Documentation Enhancement** - Comprehensive examples

### Backward Compatibility Requirements
- ✅ All existing code must continue working unchanged
- ✅ Existing `parseIngredient()` method must maintain signature
- ✅ New features added as new methods or automatic enhancements
- ✅ No breaking changes to `ParsedIngredient` class

---

**Next Steps:** Proceed with Phase 2 - Implementation
- Start with ASCII fraction support (highest impact)
- Run `dart analyze` after every change
- Create verification checklists for manual testing
