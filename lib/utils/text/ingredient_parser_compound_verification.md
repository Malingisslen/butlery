# Compound Ingredient Verification

**Feature:** Compound ingredient splitting ("salt och peppar")
**Date:** 2025-10-31
**Status:** ✅ Implemented, ⏳ Awaiting Manual Verification

---

## Test Scenarios

### Simple Compounds (Basic)
Test splitting ingredients connected with "och":

- [ ] `"salt och peppar"` → 2 ingredients:
  - `ParsedIngredient(1.0, "", "salt")`
  - `ParsedIngredient(1.0, "", "peppar")`

- [ ] `"olja och smör"` → 2 ingredients:
  - `ParsedIngredient(1.0, "", "olja")`
  - `ParsedIngredient(1.0, "", "smör")`

- [ ] `"vitlök och ingefära"` → 2 ingredients:
  - `ParsedIngredient(1.0, "", "vitlök")`
  - `ParsedIngredient(1.0, "", "ingefära")`

### With Shared Quantity/Unit (Advanced)
Both ingredients should inherit the quantity and unit:

- [ ] `"2 msk olja och smör"` → 2 ingredients:
  - `ParsedIngredient(2.0, "msk", "olja")`
  - `ParsedIngredient(2.0, "msk", "smör")`

- [ ] `"1 tsk salt och peppar"` → 2 ingredients:
  - `ParsedIngredient(1.0, "tsk", "salt")`
  - `ParsedIngredient(1.0, "tsk", "peppar")`

- [ ] `"3 dl mjölk och grädde"` → 2 ingredients:
  - `ParsedIngredient(3.0, "dl", "mjölk")`
  - `ParsedIngredient(3.0, "dl", "grädde")`

- [ ] `"500g kyckling och bacon"` → 2 ingredients:
  - `ParsedIngredient(500, "g", "kyckling")`
  - `ParsedIngredient(500, "g", "bacon")`

### With Separate Quantities (Advanced)
Each ingredient has its own quantity/unit:

- [ ] `"1 dl mjölk och 2 dl grädde"` → 2 ingredients:
  - `ParsedIngredient(1.0, "dl", "mjölk")`
  - `ParsedIngredient(2.0, "dl", "grädde")`

- [ ] `"500g kyckling och 200g bacon"` → 2 ingredients:
  - `ParsedIngredient(500, "g", "kyckling")`
  - `ParsedIngredient(200, "g", "bacon")`

- [ ] `"2 msk olja och 1 msk smör"` → 2 ingredients:
  - `ParsedIngredient(2.0, "msk", "olja")`
  - `ParsedIngredient(1.0, "msk", "smör")`

- [ ] `"½ dl socker och ¼ dl honung"` → 2 ingredients:
  - `ParsedIngredient(0.5, "dl", "socker")`
  - `ParsedIngredient(0.25, "dl", "honung")`

### Triple Compounds (Complex)
More than 2 ingredients:

- [ ] `"salt och peppar och vitlök"` → 3 ingredients:
  - `ParsedIngredient(1.0, "", "salt")`
  - `ParsedIngredient(1.0, "", "peppar")`
  - `ParsedIngredient(1.0, "", "vitlök")`

- [ ] `"1 tsk salt och peppar och vitlökspulver"` → 3 ingredients (shared quantity):
  - `ParsedIngredient(1.0, "tsk", "salt")`
  - `ParsedIngredient(1.0, "tsk", "peppar")`
  - `ParsedIngredient(1.0, "tsk", "vitlökspulver")`

- [ ] `"paprika och chili och cayennepeppar"` → 3 ingredients:
  - `ParsedIngredient(1.0, "", "paprika")`
  - `ParsedIngredient(1.0, "", "chili")`
  - `ParsedIngredient(1.0, "", "cayennepeppar")`

### Not Compound (Should Return Single Item)
These should return a list with 1 ingredient only:

- [ ] `"2 dl mjölk"` → List of 1:
  - `ParsedIngredient(2.0, "dl", "mjölk")`

- [ ] `"500g kyckling"` → List of 1:
  - `ParsedIngredient(500, "g", "kyckling")`

- [ ] `"kyckling"` → List of 1:
  - `ParsedIngredient(1.0, "", "kyckling")`

- [ ] `"1 stor lök"` → List of 1:
  - `ParsedIngredient(1.0, "", "stor lök")`

### Edge Cases

#### Empty/Invalid
- [ ] `""` → List of 1 (empty ingredient):
  - `ParsedIngredient(1.0, "", "")`

- [ ] `"   "` → List of 1 (empty ingredient):
  - `ParsedIngredient(1.0, "", "")`

- [ ] `"och"` → List of 1 (just "och"):
  - Should handle gracefully

#### "och" Without Spaces (Should NOT Split)
These should NOT be treated as compounds:

- [ ] `"brocoli"` → Contains "och" but not as separator, returns 1 item:
  - `ParsedIngredient(1.0, "", "brocoli")`

- [ ] `"chokladkaka"` → Contains "och" but not as separator, returns 1 item:
  - `ParsedIngredient(1.0, "", "chokladkaka")`

### Case Insensitivity
- [ ] `"SALT OCH PEPPAR"` → 2 ingredients (both lowercase):
  - `ParsedIngredient(1.0, "", "salt")`
  - `ParsedIngredient(1.0, "", "peppar")`

- [ ] `"2 MSK OLJA OCH SMÖR"` → 2 ingredients (all lowercase):
  - `ParsedIngredient(2.0, "msk", "olja")`
  - `ParsedIngredient(2.0, "msk", "smör")`

### ASCII Fractions in Compounds (Integration Test)
Verify ASCII fractions work with compound splitting:

- [ ] `"1/2 tsk salt och peppar"` → 2 ingredients:
  - `ParsedIngredient(0.5, "tsk", "salt")`
  - `ParsedIngredient(0.5, "tsk", "peppar")`

- [ ] `"1 1/2 dl mjölk och grädde"` → 2 ingredients:
  - `ParsedIngredient(1.5, "dl", "mjölk")`
  - `ParsedIngredient(1.5, "dl", "grädde")`

### Real-World Swedish Recipes
Test with actual recipe patterns:

- [ ] `"salt och peppar efter smak"` → 2 ingredients:
  - `ParsedIngredient(1.0, "", "salt")`
  - `ParsedIngredient(1.0, "", "peppar efter smak")`

- [ ] `"2 dl vispgrädde och mjölk"` → 2 ingredients (shared):
  - `ParsedIngredient(2.0, "dl", "vispgrädde")`
  - `ParsedIngredient(2.0, "dl", "mjölk")`

- [ ] `"1 msk honung och senap"` → 2 ingredients (shared):
  - `ParsedIngredient(1.0, "msk", "honung")`
  - `ParsedIngredient(1.0, "msk", "senap")`

- [ ] `"½ tsk spiskummin och koriander"` → 2 ingredients (shared):
  - `ParsedIngredient(0.5, "tsk", "spiskummin")`
  - `ParsedIngredient(0.5, "tsk", "koriander")`

---

## Manual Testing Instructions

### Method 1: Flutter DevTools Console
```dart
import 'package:butlery/utils/text/ingredient_parser.dart';

void testCompoundIngredients() {
  // Simple compound
  final result1 = IngredientParser.parseCompoundIngredient("salt och peppar");
  print("Result 1 (should be 2 items): ${result1.length}");
  for (final ing in result1) {
    print("  - ${ing.toString()}");
  }

  // With shared quantity
  final result2 = IngredientParser.parseCompoundIngredient("2 msk olja och smör");
  print("\nResult 2 (should be 2 items with 2 msk each): ${result2.length}");
  for (final ing in result2) {
    print("  - ${ing.toString()}");
  }

  // Not compound
  final result3 = IngredientParser.parseCompoundIngredient("2 dl mjölk");
  print("\nResult 3 (should be 1 item): ${result3.length}");
  for (final ing in result3) {
    print("  - ${ing.toString()}");
  }
}
```

### Method 2: Create Test Script
Create `test_compound_ingredients.dart`:

```dart
import 'package:butlery/utils/text/ingredient_parser.dart';

void main() {
  final testCases = {
    "salt och peppar": 2,
    "2 msk olja och smör": 2,
    "1 dl mjölk och 2 dl grädde": 2,
    "salt och peppar och vitlök": 3,
    "2 dl mjölk": 1,
    "kyckling": 1,
  };

  print("Testing Compound Ingredient Splitting:");
  print("=" * 60);

  for (final entry in testCases.entries) {
    final input = entry.key;
    final expectedCount = entry.value;
    final result = IngredientParser.parseCompoundIngredient(input);

    final passed = result.length == expectedCount;
    final status = passed ? "✅ PASS" : "❌ FAIL";

    print("$status | \"$input\"");
    print("   Expected: $expectedCount items, Got: ${result.length} items");
    for (int i = 0; i < result.length; i++) {
      final ing = result[i];
      print("   [$i] qty=${ing.quantity}, unit='${ing.unit}', name='${ing.name}'");
    }
    print("");
  }
}
```

Then run: `dart run test_compound_ingredients.dart`

---

## Expected Results Summary

### What Should Work ✅
1. Simple compounds: `"salt och peppar"` → 2 items
2. Shared quantity/unit: `"2 msk olja och smör"` → both get 2 msk
3. Separate quantities: `"1 dl mjölk och 2 dl grädde"` → each has own
4. Triple+ compounds: `"salt och peppar och vitlök"` → 3 items
5. Not compound: `"2 dl mjölk"` → 1 item (in a list)
6. Case insensitive: `"SALT OCH PEPPAR"` → works, lowercase output

### Inheritance Logic ✅
- If subsequent ingredient has no quantity/unit → inherits from first
- If subsequent ingredient has own quantity/unit → uses its own
- First ingredient always establishes the "base" values

### What Should NOT Split ✅
1. "och" without spaces: `"brocoli"`, `"chokladkaka"` → 1 item each
2. Single ingredients: `"mjölk"`, `"500g kyckling"` → 1 item each
3. Empty strings: `""`, `"   "` → 1 item (empty)

### Backward Compatibility ✅
- Existing `parseIngredient()` method unchanged
- All existing code continues working
- New method is OPTIONAL - only use if you want compound splitting

---

## Integration Tests

### With ASCII Fractions
- [ ] ASCII fractions + compounds work together
- [ ] `"1/2 tsk salt och peppar"` splits correctly

### With Unicode Fractions
- [ ] Unicode fractions + compounds work together
- [ ] `"½ tsk salt och peppar"` splits correctly

### With Attached Units
- [ ] Attached units + compounds work together
- [ ] `"500g kyckling och bacon"` splits correctly

---

## Verification Status

- [ ] All simple compounds tested
- [ ] All shared quantity/unit cases tested
- [ ] All separate quantity cases tested
- [ ] Triple compounds tested
- [ ] Not compound (single item) cases tested
- [ ] Edge cases tested
- [ ] Case insensitivity verified
- [ ] Real-world recipes tested
- [ ] Integration with ASCII fractions tested
- [ ] Integration with Unicode fractions tested
- [ ] Backward compatibility verified
- [ ] No analyzer warnings/errors ✅

**Completion Date:** _________

**Verified By:** _________

---

## Next Steps

After verification:
1. ✅ Mark this feature as complete
2. ⏳ Proceed to next improvement: Edge case robustness
3. ⏳ Update final documentation with verified results
