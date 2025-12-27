# Firebase Ingredient Patterns

> Använd denna skill vid arbete med ingredienser, lookup, och tagging-integration.

## Grundprincip

**Ingrediensdata lagras i Firebase, ALDRIG hårdkodat i kod.**

```
Firebase Collection: 'ingredients' (2230+ entries)
├── IngredientData documents
│   ├── id, swedish, english
│   ├── group (hierarchiskt: 'protein/meat/poultry')
│   ├── properties (Set: 'meat', 'poultry', 'animal-product')
│   └── aliasesSv, aliasesEn
```

## Lookup Pipeline

```
Recept-ingredienser (råtext)
    ↓
IngredientNormalizer (cleanar)
    ↓
IngredientLookupService (söker)
    ↓
IngredientLookupResult (matchade + okända)
    ↓
TagGenerator (genererar tags)
```

## Sökordning (4 steg)

```dart
// IngredientLookupService._findIngredient()
1. Global database: exakt namn
2. User-defined ingredients (per användare)
3. Global database: alias
4. Fuzzy match (compound words)
```

## IngredientData-struktur

```dart
IngredientData {
  id: String,              // 'chicken-breast' (kebab-case)
  swedish: String,         // 'kycklingbröst'
  english: String,         // 'chicken breast'
  group: String,           // 'protein/meat/poultry' (hierarchiskt)
  properties: Set<String>, // {'meat', 'poultry', 'animal-product'}
  aliasesSv: List<String>, // ['kycklingfilé', 'kycklingbröstfilé']
  aliasesEn: List<String>,
  status: String,          // 'verified', 'draft', 'user-defined'
}
```

## Group Hierarchy

```
protein/
├── meat/
│   ├── poultry    (kyckling, kalkon)
│   ├── beef       (nötkött)
│   └── pork       (fläsk)
├── seafood/
│   ├── fish       (lax, torsk)
│   └── shellfish  (räkor, musslor)
└── dairy          (mjölk, ost)

vegetable/
├── leafy         (sallad, spenat)
├── root          (potatis, morot)
└── allium        (lök, vitlök)
```

Använd: `ingredient.topLevelGroup`, `ingredient.isInGroup('protein/meat')`

## IngredientLookupResult

```dart
IngredientLookupResult {
  matched: List<IngredientData>,  // Hittade ingredienser
  unmatched: List<String>,        // Okända ingrediensnamn
  coverage: double,               // 0.0 - 1.0
}

// Viktiga getters
result.hasFullCoverage  // coverage >= 1.0
result.hasUnknowns      // unmatched.isNotEmpty
result.getPropertyStatus('meat')  // TriState baserat på alla matchade
```

## Kritiska Regler

### 1. Coverage påverkar säkerhet

```dart
// ❌ FARLIGT - ignorerar okända ingredienser
if (result.getPropertyStatus('gluten') == TriState.free) {
  showSafeForCeliac(); // Kan vara FEL om coverage < 100%
}

// ✅ SÄKERT - kontrollera coverage
if (result.hasFullCoverage &&
    result.getPropertyStatus('gluten') == TriState.free) {
  showSafeForCeliac();
}
```

### 2. Caching-strategi

```dart
// Repository laddar ALLT vid startup (2230 entries)
await ingredientRepository.loadCache();

// Sedan sker lookups mot in-memory cache
final ingredient = await repository.findByName('lök'); // Snabbt!
```

### 3. Normalizer bevarar diet-descriptors

```dart
// ✅ Bevaras (viktigt för tagging)
"glutenfri pasta" → "glutenfri pasta"
"laktosfri mjölk" → "laktosfri mjölk"

// ❌ Tas bort (preparation/size)
"hackad lök" → "lök"
"stor tomat" → "tomat"
```

## User-Defined Ingredients

```dart
// Användare kan lägga till egna ingredienser
final userRepo = ServiceLocator.get<UserIngredientRepository>();

// Dessa söks EFTER global databas
// Collection: users/{userId}/ingredients
```

## Properties för Tagging

Standard-properties som tagging använder:

```
Allergen-triggers:
- contains-gluten, contains-lactose, contains-alcohol
- tree-nut, peanut, egg, dairy, fish, shellfish, soy, sesame

Dietary-triggers:
- meat, poultry, pork, beef
- animal-product, seafood
- is-spicy, high-mercury
- vegan-friendly, plant-based
```

## Nyckelfilar

- `lib/services/tagging/ingredient_lookup_service.dart` - Lookup orchestrator
- `lib/repositories/firebase/firebase_ingredient_repository.dart` - Firebase access
- `lib/repositories/firebase/firebase_user_ingredient_repository.dart` - User ingredients
- `lib/models/tagging/ingredient_data.dart` - Data model
- `lib/models/tagging/ingredient_lookup_result.dart` - Result + aggregation
- `lib/utils/text/ingredient_normalizer.dart` - Name normalization

## När triggas denna skill?

- Modifierar ingrediens-lookup logik
- Lägger till nya properties för tagging
- Arbetar med user-defined ingredients
- Debuggar varför ingredienser inte hittas
- Implementerar ingrediens-sök i UI
