# Edge Case Verification

**Feature:** Edge case robustness (whitespace normalization, empty strings)
**Date:** 2025-10-31
**Status:** ✅ Implemented, ⏳ Awaiting Manual Verification

---

## Test Scenarios

### Whitespace Variations (Multiple Spaces)
Test that multiple spaces are normalized to single space:

- [ ] `"2  dl mjölk"` → `ParsedIngredient(2.0, "dl", "mjölk")`
- [ ] `"500   g  kyckling"` → `ParsedIngredient(500, "g", "kyckling")`
- [ ] `"1    tsk    salt"` → `ParsedIngredient(1.0, "tsk", "salt")`

### Leading/Trailing Whitespace
Test that leading and trailing spaces are trimmed:

- [ ] `"  2 dl mjölk"` → `ParsedIngredient(2.0, "dl", "mjölk")`
- [ ] `"2 dl mjölk  "` → `ParsedIngredient(2.0, "dl", "mjölk")`
- [ ] `"  2 dl mjölk  "` → `ParsedIngredient(2.0, "dl", "mjölk")`
- [ ] `"   500g kyckling   "` → `ParsedIngredient(500, "g", "kyckling")`

### Attached Units (Now Explicit)
Test that units attached to numbers get properly spaced:

- [ ] `"500g kyckling"` → `ParsedIngredient(500, "g", "kyckling")` (space added)
- [ ] `"500gkyckling"` → `ParsedIngredient(500, "g", "kyckling")` (space added)
- [ ] `"2dl mjölk"` → `ParsedIngredient(2.0, "dl", "mjölk")` (space added)
- [ ] `"2dl"` → `ParsedIngredient(2.0, "dl", "")` (space added, no name)
- [ ] `"1msk smör"` → `ParsedIngredient(1.0, "msk", "smör")` (space added)

### Attached Units with Already Separated
Test that already-separated units remain unchanged:

- [ ] `"500 g kyckling"` → `ParsedIngredient(500, "g", "kyckling")` (no change)
- [ ] `"2 dl mjölk"` → `ParsedIngredient(2.0, "dl", "mjölk")` (no change)

### Empty/Invalid Input
Test graceful handling of empty or whitespace-only input:

- [ ] `""` → `ParsedIngredient(1.0, "", "")` (default)
- [ ] `"   "` → `ParsedIngredient(1.0, "", "")` (whitespace only → empty)
- [ ] `"  \t  \n  "` → `ParsedIngredient(1.0, "", "")` (all whitespace)

### Complex Whitespace Combinations
Test combinations of multiple issues:

- [ ] `"  500g   kyckling  "` → `ParsedIngredient(500, "g", "kyckling")`
  - Leading spaces + attached unit + multiple spaces + trailing spaces

- [ ] `"  2  dl    mjölk  "` → `ParsedIngredient(2.0, "dl", "mjölk")`
  - Multiple spaces throughout + leading/trailing

- [ ] `"500g"` → `ParsedIngredient(500, "g", "")` (attached unit, no ingredient)

### With ASCII Fractions (Integration)
Test that normalization works with ASCII fractions:

- [ ] `"1/2 dl olivolja"` → Works correctly
- [ ] `"  1/2  dl  olivolja  "` → Works correctly (spaces normalized)
- [ ] `"1/2dl olivolja"` → Works correctly (space added)

### With Unicode Fractions (Integration)
Test that normalization works with Unicode fractions:

- [ ] `"½ dl olivolja"` → Works correctly
- [ ] `"  ½  dl  olivolja  "` → Works correctly (spaces normalized)
- [ ] `"2 ½ dl grädde"` → Works correctly

### With Compounds (Integration)
Test that normalization works with compound ingredients:

- [ ] `"salt  och  peppar"` → Splits correctly (extra spaces normalized)
- [ ] `"  2 msk olja och smör  "` → Splits correctly (leading/trailing trimmed)
- [ ] `"500gkyckling och bacon"` → Splits correctly (attached unit spaced)

### Swedish Characters
Test that Swedish characters are handled correctly in normalization:

- [ ] `"2 dl mjölk"` → `ParsedIngredient(2.0, "dl", "mjölk")` ✅
- [ ] `"500g kött"` → `ParsedIngredient(500, "g", "kött")` ✅
- [ ] `"1 msk smör"` → `ParsedIngredient(1.0, "msk", "smör")` ✅
- [ ] `"500gköttfärs"` → `ParsedIngredient(500, "g", "köttfärs")` (space added)

### Special Characters in Ingredient Names
Test ingredients with dashes, parentheses, etc.:

- [ ] `"2 dl creme fraiche"` → Works correctly
- [ ] `"1 tsk (strö över)"` → Works correctly
- [ ] `"500g kyckling-filé"` → Works correctly

---

## Manual Testing Instructions

### Method 1: Flutter DevTools Console
```dart
import 'package:butlery/utils/text/ingredient_parser.dart';

void testEdgeCases() {
  // Multiple spaces
  print(IngredientParser.parseIngredient("2  dl   mjölk"));
  // Should output: ParsedIngredient(quantity: 2.0, unit: "dl", name: "mjölk")

  // Attached units
  print(IngredientParser.parseIngredient("500gkyckling"));
  // Should output: ParsedIngredient(quantity: 500, unit: "g", name: "kyckling")

  // Leading/trailing spaces
  print(IngredientParser.parseIngredient("  2 dl mjölk  "));
  // Should output: ParsedIngredient(quantity: 2.0, unit: "dl", name: "mjölk")

  // Empty string
  print(IngredientParser.parseIngredient(""));
  // Should output: ParsedIngredient(quantity: 1.0, unit: "", name: "")

  // Whitespace only
  print(IngredientParser.parseIngredient("   "));
  // Should output: ParsedIngredient(quantity: 1.0, unit: "", name: "")
}
```

### Method 2: Create Test Script
Create `test_edge_cases.dart`:

```dart
import 'package:butlery/utils/text/ingredient_parser.dart';

void main() {
  final testCases = {
    "2  dl mjölk": {"qty": 2.0, "unit": "dl", "name": "mjölk"},
    "500gkyckling": {"qty": 500.0, "unit": "g", "name": "kyckling"},
    "  2 dl mjölk  ": {"qty": 2.0, "unit": "dl", "name": "mjölk"},
    "": {"qty": 1.0, "unit": "", "name": ""},
    "   ": {"qty": 1.0, "unit": "", "name": ""},
  };

  print("Testing Edge Case Handling:");
  print("=" * 60);

  for (final entry in testCases.entries) {
    final input = entry.key;
    final expected = entry.value;
    final result = IngredientParser.parseIngredient(input);

    final qtyMatch = (result.quantity - expected["qty"]!).abs() < 0.001;
    final unitMatch = result.unit == expected["unit"];
    final nameMatch = result.name == expected["name"];
    final allMatch = qtyMatch && unitMatch && nameMatch;

    final status = allMatch ? "✅ PASS" : "❌ FAIL";

    print("$status | \"$input\"");
    print("   Expected: qty=${expected["qty"]}, unit='${expected["unit"]}', name='${expected["name"]}'");
    print("   Got:      qty=${result.quantity}, unit='${result.unit}', name='${result.name}'");
    print("");
  }
}
```

Then run: `dart run test_edge_cases.dart`

---

## Expected Results Summary

### What Should Work ✅

1. **Multiple Spaces**: `"2  dl   mjölk"` → Normalized to single space
2. **Leading/Trailing**: `"  2 dl  "` → Trimmed properly
3. **Attached Units**: `"500gkyckling"` → Space added: "500 g kyckling"
4. **Empty Strings**: `""`, `"   "` → Default ParsedIngredient
5. **Complex Combinations**: All variations handled gracefully

### Normalization Rules ✅

1. Multiple consecutive spaces → Single space
2. Leading/trailing whitespace → Removed
3. Digit followed by letter → Space inserted (e.g., "500g" → "500 g")
4. Already-separated text → No change

### What Should NOT Break ✅

1. ASCII fractions still work after normalization
2. Unicode fractions still work after normalization
3. Compound splitting still works after normalization
4. Swedish characters (å, ä, ö) preserved correctly
5. All existing parsing behavior unchanged

---

## Integration Tests

### With All Features Combined
Test the full pipeline with edge cases + all features:

- [ ] `"  1/2  dl  olivolja  "` → ASCII fraction + whitespace normalization
- [ ] `"500gkyckling och bacon"` → Attached unit + compound splitting
- [ ] `"  2 msk  olja  och  smör  "` → Whitespace + compound splitting
- [ ] `"  ½ tsk salt och peppar  "` → Unicode + compound + whitespace

---

## Performance Check

### Speed Verification
- [ ] Normalization adds minimal overhead (<1% performance impact)
- [ ] Parse 1000 ingredients with edge cases → Still <100ms total
- [ ] No memory leaks from regex operations

---

## Verification Status

- [ ] Multiple spaces tested
- [ ] Leading/trailing whitespace tested
- [ ] Attached units tested
- [ ] Empty/invalid input tested
- [ ] Complex combinations tested
- [ ] Swedish characters verified
- [ ] Integration with ASCII fractions tested
- [ ] Integration with Unicode fractions tested
- [ ] Integration with compound splitting tested
- [ ] Performance verified
- [ ] No analyzer warnings/errors ✅

**Completion Date:** _________

**Verified By:** _________

---

## Next Steps

After verification:
1. ✅ Mark this feature as complete
2. ⏳ Proceed to case consistency verification
3. ⏳ Update final documentation with verified results
