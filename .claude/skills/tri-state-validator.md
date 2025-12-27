# Tri-State Validator

> SÄKERHETSKRITISK: Validera att TriState aldrig används som boolean.

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

## Coverage-regel

```dart
// UNKNOWN är ALLTID default om coverage < 100%
if (coverage < 1.0) {
  // Alla allergen/dietary = TriState.unknown
}
```

## Säker Hjälpmetod

```dart
/// Returnerar true ENDAST om bevisat säkert
bool isSafeForAllergen(TagResult result, String allergen) {
  return result.hasFullCoverage &&
         result.getAllergenStatus(allergen) == TriState.free;
}
```

## När triggas denna skill?

- Använder `isGlutenFree`, `isDairyFree` etc.
- Filtrerar recept på allergen/dietary
- Visar allergen-status i UI
- Skriver queries mot tagResult
