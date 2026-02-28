---
description: >
  Validates that ingredient coverage is checked before making allergen/dietary
  safety decisions. Use when filtering recipes by allergen/dietary status,
  displaying allergen badges in UI, or debugging why recipes are excluded from filters.
---

# Coverage Tracker

> Warn when ingredient coverage < 100% affects safety decisions.

## Grundregel

**Coverage = andel ingredienser som hittades i databasen**

```dart
coverage = matched.length / (matched.length + unmatched.length)
```

| Coverage | Betydelse | Allergen/Dietary Status |
|----------|-----------|-------------------------|
| 1.0 (100%) | Alla ingredienser kända | Kan vara FREE eller CONTAINS |
| < 1.0 | Okända ingredienser finns | ALLTID UNKNOWN |

## Kritiska Regler

### ❌ Ignorera coverage i filter

```dart
// FARLIGT - visar "veganska" recept som kanske inte är veganska
recipes.where((r) => r.tagResult.isVegan)
```

### ✅ Kontrollera coverage

```dart
// SÄKERT - endast recept med full coverage
recipes.where((r) =>
  r.tagResult.hasFullCoverage &&
  r.tagResult.isDietarySafe('vegansk')
)
```

---

### ❌ UI utan coverage-indikator

```dart
// VILSELEDANDE - användaren vet inte att det är osäkert
if (recipe.tagResult.isGlutenFree) {
  return Icon(Icons.check, color: Colors.green);
}
```

### ✅ UI med coverage-varning

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

## Coverage i TagResult

```dart
TagResult {
  coverage: double,              // 0.0 - 1.0
  unknownIngredients: List<String>,  // Vilka som inte hittades

  // Helpers
  bool get hasFullCoverage => coverage >= 1.0;
  bool get hasUnknowns => unknownIngredients.isNotEmpty;
}
```

## Visa Okända Ingredienser

```dart
if (tagResult.hasUnknowns) {
  return Column(children: [
    Text('Kunde inte analysera:'),
    ...tagResult.unknownIngredients.map((i) => Text('• $i')),
  ]);
}
```

## Query-mönster

```dart
// Säker query för allergiker
Query allergenSafeQuery(String allergen) {
  return recipesRef
    .where('tagResult.coverage', isEqualTo: 1.0)
    .where('tagResult.allergenStatus.$allergen', isEqualTo: 'FREE');
}
```

## Edge Cases

| Situation | Coverage | Beteende |
|-----------|----------|----------|
| Inga ingredienser | 1.0 | Komplett analys (inget att analysera) |
| Alla okända | 0.0 | Allt UNKNOWN |
| 9 av 10 kända | 0.9 | Allt UNKNOWN (ej 100%) |

