---
name: "source-command-tagging-domain-knowledge"
description: "Recipe tagging domain knowledge: TriState allergen/dietary logic, 5-phase pipeline, coverage rules. Use when modifying files in lib/services/tagging/, using TriState/TagResult/TagGenerator, implementing allergen/dietary filters, or writing queries on dietary/allergen status."
---

# source-command-tagging-domain-knowledge

Use this skill when the user asks to run the migrated source command `tagging-domain-knowledge`.

## Command Template

# Tagging Domain Knowledge

> Recipe tagging: TriState logic, allergen/dietary status, and 5-phase pipeline.

## Grundregler

1. **Tri-State, INTE Boolean** - Allergen/dietary-status är ALLTID `TriState.contains | free | unknown`
2. **Coverage avgör säkerhet** - `coverage < 1.0` → alla allergens/dietary = `unknown`
3. **5-fas pipeline** - Phase1 → Phase2 → Phase3 → Phase4 → Phase5 (strikt ordning)
4. **FREE kräver bevis** - En allergen är `free` ENDAST om 100% coverage OCH ingen ingrediens har egenskapen
5. **UNKNOWN är default** - Saknad data = `unknown` (säkert för allergiker)

## Tri-State Prioritet

```
CONTAINS > UNKNOWN > FREE

orCombine():  nötter = tree-nut OR peanut
andCombine(): vegan = no meat AND no dairy AND no eggs
```

## Kritiska Fel att Undvika

❌ **Boolean för allergen**
```dart
if (recipe.isGlutenFree) // FARLIGT - ignorerar UNKNOWN
```
✅ **Tri-State check**
```dart
if (tagResult.getAllergenStatus('gluten') == TriState.free) // SÄKERT
```

---

❌ **Ignorera coverage**
```dart
final isVegan = dietaryStatus['vegansk'] == TriState.free;
```
✅ **Kontrollera coverage**
```dart
final isVegan = coverage >= 1.0 && dietaryStatus['vegansk'] == TriState.free;
```

---

❌ **Faser ur ordning**
```dart
final phase2 = _phase2.calculate(phase1, recipe);
final phase1 = _phase1.calculate(lookup, recipe); // FEL - phase2 kördes först
```
✅ **Sekventiell körning**
```dart
final phase1 = _phase1.calculate(lookup, recipe);
final phase2 = _phase2.calculate(phase1, recipe);
```

## TagResult-struktur

```dart
TagResult {
  tags: Set<String>,              // 'kyckling', 'pasta-dish', 'under-30-min'
  allergenStatus: Map<String, TriState>,  // 'gluten' → CONTAINS/FREE/UNKNOWN
  dietaryStatus: Map<String, TriState>,   // 'vegansk' → CONTAINS/FREE/UNKNOWN
  coverage: double,               // 0.0 - 1.0
  unknownIngredients: List<String>,
  generatorVersion: String?,      // '1.0.0' eller 'failed'
}
```

## Fas-pipeline

| Fas | Input | Output | Exempel-tags |
|-----|-------|--------|--------------|
| 1 | Ingredienser + Recept | Base | time, allergen, dietary, protein |
| 2 | Phase1 + Recept | Simple derived | pasta-dish, pescetarian, few-ingredients |
| 3 | Phase1 + Phase2 + Recept | Complex | one-pot, no-bake, quick-meal |
| 4 | Phase1-3 + Recept | Mood/occasion | weeknight, comfort-food |
| 5 | Phase1-4 + Ingredienser | Cuisine | svensk, italiensk, asiatisk |

## Allergen-nycklar (Svenska)

```
EU-14: gluten, mjölk, ägg, fisk, kräftdjur, blötdjur, trädnötter,
       jordnötter, soja, sesam, selleri, senap, lupin, sulfiter
Extra: laktos, alkohol, kött, fläsk, nötkött, skaldjur, nötter
```

## Dietary-nycklar (Svenska)

```
vegetarisk, vegansk, pescetarian, graviditetssäker,
barnvänlig, halalanpassad, kosheranpassad, nötkötsfri
```

## Nyckelfilar

- `lib/models/tagging/tri_state.dart` - TriState enum + combine-logik
- `lib/models/tagging/tag_result.dart` - TagResult modell
- `lib/models/tagging/tag_overrides.dart` - User overrides till auto-tags
- `lib/services/tagging/tag_generator.dart` - 5-fas orchestrator
- `lib/services/tagging/phases/tag_phase1_base.dart` - Allergen/dietary beräkning
- `lib/services/tagging/phases/tag_phase5_cuisine.dart` - Cuisine-tagging (17 kök)
- `lib/services/tagging/config/allergen_config.dart` - 22 allergener
- `lib/services/tagging/config/dietary_config.dart` - 8 dieter
- `lib/services/tagging/tag_editing_service.dart` - Effective status med overrides
- `lib/services/tagging/tag_resolution_service.dart` - Resolves auto+override+personal tags
- `lib/services/tagging/personal_tag_service.dart` - Personal tags + automation rules
