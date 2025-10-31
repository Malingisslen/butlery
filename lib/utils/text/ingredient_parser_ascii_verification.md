# ASCII Fraction Verification

**Feature:** ASCII fraction parsing support
**Date:** 2025-10-31
**Status:** ✅ Implemented, ⏳ Awaiting Manual Verification

---

## Test Scenarios

### Simple Fractions (Basic)
Test these manually in your app or with a simple test script:

- [ ] `"1/2 dl olivolja"` → `ParsedIngredient(0.5, "dl", "olivolja")`
- [ ] `"1/4 tsk salt"` → `ParsedIngredient(0.25, "tsk", "salt")`
- [ ] `"3/4 dl mjölk"` → `ParsedIngredient(0.75, "dl", "mjölk")`
- [ ] `"1/3 msk honung"` → `ParsedIngredient(0.333..., "msk", "honung")`
- [ ] `"2/3 dl vatten"` → `ParsedIngredient(0.666..., "dl", "vatten")`
- [ ] `"5/8 tsk vaniljsocker"` → `ParsedIngredient(0.625, "tsk", "vaniljsocker")`

### Mixed Fractions (Advanced)
- [ ] `"1 1/2 dl grädde"` → `ParsedIngredient(1.5, "dl", "grädde")`
- [ ] `"2 1/4 msk socker"` → `ParsedIngredient(2.25, "msk", "socker")`
- [ ] `"3 3/4 dl mjöl"` → `ParsedIngredient(3.75, "dl", "mjöl")`
- [ ] `"1 1/3 tsk salt"` → `ParsedIngredient(1.333..., "tsk", "salt")`
- [ ] `"2 2/3 dl mjölk"` → `ParsedIngredient(2.666..., "dl", "mjölk")`

### Without Units (Edge Cases)
- [ ] `"1/2 stor lök"` → `ParsedIngredient(0.5, "", "stor lök")`
- [ ] `"1 1/2 ägg"` → `ParsedIngredient(1.5, "", "ägg")`
- [ ] `"3/4 paket bacon"` → `ParsedIngredient(0.75, "", "paket bacon")`

### Safety Tests (Division by Zero)
- [ ] `"1/0 dl olja"` → Should handle gracefully (not crash)
  - Expected: Fall through to default parsing or return default ingredient
- [ ] `"0/0 tsk salt"` → Should handle gracefully (not crash)
  - Expected: Fall through to default parsing or return default ingredient

### Invalid Formats (Should Fall Through)
These should NOT be parsed as ASCII fractions, should use existing logic:

- [ ] `"abc/def"` → Falls through to existing parsing logic
- [ ] `"1 / 2 dl"` → Falls through (spaces around slash not supported)
- [ ] `"1/2/3 dl"` → Falls through (invalid fraction format)
- [ ] `"/ dl"` → Falls through (no numerator/denominator)

### Backward Compatibility (Unicode Fractions Still Work)
CRITICAL: Verify existing Unicode fraction parsing still works:

- [ ] `"½ dl olivolja"` → `ParsedIngredient(0.5, "dl", "olivolja")` ✅
- [ ] `"¼ tsk salt"` → `ParsedIngredient(0.25, "tsk", "salt")` ✅
- [ ] `"¾ dl mjölk"` → `ParsedIngredient(0.75, "dl", "mjölk")` ✅
- [ ] `"2 ½ dl grädde"` → `ParsedIngredient(2.5, "dl", "grädde")` ✅
- [ ] `"1 ¼ msk socker"` → `ParsedIngredient(1.25, "msk", "socker")` ✅
- [ ] `"3 ¾ dl vatten"` → `ParsedIngredient(3.75, "dl", "vatten")` ✅

### Case Insensitivity
- [ ] `"1/2 DL OLIVOLJA"` → `ParsedIngredient(0.5, "dl", "olivolja")` (lowercase)
- [ ] `"1/4 TSK SALT"` → `ParsedIngredient(0.25, "tsk", "salt")` (lowercase)
- [ ] `"1 1/2 DL Grädde"` → `ParsedIngredient(1.5, "dl", "grädde")` (lowercase)

### Whitespace Variations
- [ ] `"1/2 dl olivolja"` → Works (standard spacing)
- [ ] `"1/2  dl  olivolja"` → Works (extra spaces)
- [ ] `"  1/2 dl olivolja  "` → Works (leading/trailing spaces)

### Real-World Swedish Recipes
Test with actual recipe ingredient lines:

- [ ] `"1/2 dl majonnäs"` → Mayonnaise measurement
- [ ] `"3/4 dl creme fraiche"` → Cream measurement
- [ ] `"1 1/2 msk tomatpuré"` → Tomato paste
- [ ] `"1/4 tsk svartpeppar"` → Black pepper
- [ ] `"2 1/2 dl riven ost"` → Grated cheese

### Performance Check
- [ ] Parse 100 ingredients with ASCII fractions → Should complete in <100ms
- [ ] No performance regression vs baseline parsing

---

## Manual Testing Instructions

### Method 1: Flutter DevTools Console
```dart
import 'package:butlery/utils/text/ingredient_parser.dart';

void testAsciiFractions() {
  // Simple fractions
  print(IngredientParser.parseIngredient("1/2 dl olivolja"));
  // Should output: ParsedIngredient(quantity: 0.5, unit: "dl", name: "olivolja")

  // Mixed fractions
  print(IngredientParser.parseIngredient("1 1/2 dl grädde"));
  // Should output: ParsedIngredient(quantity: 1.5, unit: "dl", name: "grädde")

  // Add more test cases...
}
```

### Method 2: Create Test Script
Create a temporary file `test_ascii_fractions.dart` in the project root:

```dart
import 'package:butlery/utils/text/ingredient_parser.dart';

void main() {
  final testCases = {
    "1/2 dl olivolja": 0.5,
    "1/4 tsk salt": 0.25,
    "3/4 dl mjölk": 0.75,
    "1 1/2 dl grädde": 1.5,
    "2 1/4 msk socker": 2.25,
  };

  print("Testing ASCII Fraction Parsing:");
  print("=" * 50);

  for (final entry in testCases.entries) {
    final input = entry.key;
    final expectedQty = entry.value;
    final result = IngredientParser.parseIngredient(input);

    final passed = (result.quantity - expectedQty).abs() < 0.001;
    final status = passed ? "✅ PASS" : "❌ FAIL";

    print("$status | $input");
    print("   Expected: $expectedQty, Got: ${result.quantity}");
    print("   Unit: ${result.unit}, Name: ${result.name}");
    print("");
  }
}
```

Then run: `dart run test_ascii_fractions.dart`

---

## Expected Results Summary

### What Should Work ✅
1. Simple ASCII fractions: `1/2`, `3/4`, `5/8`
2. Mixed ASCII fractions: `1 1/2`, `2 1/4`, `3 3/4`
3. With Swedish units: `dl`, `msk`, `tsk`, `g`, `kg`, etc.
4. With American units: `cup`, `tbsp`, `tsp`, `oz`, etc.
5. Without units: `1/2 stor lök`
6. Case insensitive input
7. Whitespace variations

### What Should Still Work (No Regression) ✅
1. All Unicode fractions: `½`, `¼`, `¾`
2. All mixed Unicode fractions: `2 ½`, `1 ¼`, `3 ¾`
3. Swedish comma decimals: `2,5 dl`
4. Attached units: `500g`
5. All other existing parsing behavior

### What Should Fail Gracefully ✅
1. Division by zero: `1/0` (returns null, falls through)
2. Invalid formats: `abc/def`, `1 / 2` (falls through to existing logic)
3. Malformed fractions: `1/2/3` (falls through)

---

## Verification Status

- [ ] All simple fractions tested
- [ ] All mixed fractions tested
- [ ] Edge cases tested
- [ ] Safety tests completed
- [ ] Backward compatibility verified
- [ ] Real-world recipes tested
- [ ] Performance verified
- [ ] No analyzer warnings/errors ✅

**Completion Date:** _________

**Verified By:** _________

---

## Next Steps

After verification:
1. ✅ Mark this feature as complete
2. ⏳ Proceed to next improvement: Compound ingredient splitting
3. ⏳ Update final documentation with verified results
