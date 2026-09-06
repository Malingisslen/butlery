---
name: "source-command-tri-state-validator"
description: "SAFETY-CRITICAL: Validates that TriState is never used as boolean and that coverage is checked before safety decisions. Use when code references isGlutenFree/isDairyFree, filters recipes on allergen/dietary status, displays allergen badges in UI, writes queries against tagResult, or debugging why recipes are excluded from allergen/dietary filters."
---

# source-command-tri-state-validator

Use this skill when the user asks to run the migrated source command `tri-state-validator`.

## Command Template

# Tri-State Validator

> SAFETY-CRITICAL: Validate that TriState is never used as boolean.

## Grundregel

**TriState har TRE värden, inte två:**
- `contains` - Receptet innehåller allergenen
- `free` - Receptet är BEVISAT fritt (100% coverage)
- `unknown` - Vi vet inte (coverage < 100% eller okända ingredienser)

## Kritiska Fel att Fånga

### ❌ Boolean-konvertering

```dart
// FARLIGT - isGlutenFree är boolean som ignorerar UNKNOWN
if (recipe.tagResult.isGlutenFree) {
  showSafeForCeliac(); // KAN VARA FEL!
}
```

### ✅ Korrekt TriState-check

```dart
if (recipe.tagResult.getAllergenStatus('gluten') == TriState.free) {
  showSafeForCeliac(); // Säkert - explicit FREE
}
```

---

### ❌ Ignorera UNKNOWN i filter

```dart
// FARLIGT - visar recept där status är UNKNOWN
recipes.where((r) => !r.tagResult.containsAllergen('gluten'))
```

### ✅ Explicit FREE-filter

```dart
// Säkert - bara recept som är BEVISAT glutenfria
recipes.where((r) => r.tagResult.isAllergenFree('gluten'))
```

---

### ❌ Boolean i UI

```dart
// FARLIGT - visar "Glutenfri" även när UNKNOWN
Text(recipe.isGlutenFree ? 'Glutenfri' : 'Innehåller gluten')
```

### ✅ Tre-vägs UI

```dart
final status = recipe.tagResult.getAllergenStatus('gluten');
switch (status) {
  case TriState.free:
    return Badge('Glutenfri', color: Colors.green);
  case TriState.contains:
    return Badge('Innehåller gluten', color: Colors.red);
  case TriState.unknown:
    return Badge('Okänt', color: Colors.grey);
}
```

## Varningssignaler att Söka Efter

| Mönster | Problem |
|---------|---------|
| `isGlutenFree`, `isDairyFree` etc. som boolean | Ignorerar UNKNOWN |
| `!containsAllergen(x)` | Inkluderar UNKNOWN |
| `allergenStatus[x] == true/false` | TriState är inte boolean |
| Saknar `TriState.unknown` case | Incomplete switch |

## Coverage Rule

```dart
// UNKNOWN is ALWAYS default when coverage < 100%
if (tagResult.coverage < 1.0) {
  // All allergen/dietary = TriState.unknown
}
```

| Situation | Coverage | Behavior |
|-----------|----------|----------|
| No ingredients | 1.0 | Complete analysis (nothing to analyze) |
| All unknown | 0.0 | Everything UNKNOWN |
| 9 of 10 known | 0.9 | Everything UNKNOWN (not 100%) |

## Coverage-Aware UI

### ❌ Badge without coverage check

```dart
// MISLEADING - user doesn't know it's uncertain
if (recipe.tagResult.isGlutenFree) {
  return Icon(Icons.check, color: Colors.green);
}
```

### ✅ Badge with coverage warning

```dart
final status = recipe.tagResult.getAllergenStatus('gluten');
final hasCoverage = recipe.tagResult.hasFullCoverage;

if (status == TriState.free && hasCoverage) {
  return Icon(Icons.check, color: Colors.green);
} else if (status == TriState.free && !hasCoverage) {
  return Row(children: [
    Icon(Icons.check, color: Colors.orange),
    Text('Osäkert - okända ingredienser'),
  ]);
}
```

## Display Unknown Ingredients

```dart
if (tagResult.hasUnknowns) {
  return Column(children: [
    Text('Kunde inte analysera:'),
    ...tagResult.unknownIngredients.map((i) => Text('• $i')),
  ]);
}
```

## Safe Helper

```dart
/// Returns true ONLY if proven safe
bool isSafeForAllergen(TagResult result, String allergen) {
  return result.hasFullCoverage &&
         result.getAllergenStatus(allergen) == TriState.free;
}
```
