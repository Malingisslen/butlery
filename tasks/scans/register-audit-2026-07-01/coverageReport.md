# Register coverage audit

Method: simulated the actual runtime pipeline — `IngredientLookupService._cleanForLookup` (Swedish-char ASCII fold), `IngredientNormalizer` (preparation-word stripping incl. `stekt/kokt/grillad/rostade/torkad/osötad`, definite-form map, diet-descriptor preservation), and `_generateLookupVariations` (no-space compounds, `CompoundSuffixes` splitting, plural `-or/-ar/-er`, definite `-n/-en/-et`, adjective stripping) — against all names + aliases in `register_compact.jsonl`.

## 1. Classified golden misses (44 shown in file)

### (a) Would match after normalization at runtime — golden-eval used exact match only
| Miss | Runtime path |
|---|---|
| smöret, mjölet, grädden, sockret, vattnet, saltet, riset, pastan | `_definiteFormMap` in IngredientNormalizer (hard-coded) |
| potatisen, citronen, persiljan | generic `-en`/`-n` definite stripping |
| färsk pasta, kokt ris, grillad kyckling, torkad frukt, rostade pumpakärnor, osötad mandelmjölk, citronskivor | preparation-word / suffix stripping → base in register |
| bit ingefära | IngredientParser treats "bit" as unit → "ingefära" |
| dijon senap | no-space variation → `dijonsenap` (in register) |
| vild ris | no-space → `vildris` (in register) |
| röd curry pasta | color removal + no-space → `currypasta` (in register) |
| ljus japansk soja | "ljus" stripped → "japansk soja" (in register) |
| cream cheese, fish sauce | exact alias hits (register has them — golden matcher likely failed on casing/whitespace) |
| stekt fläsk* | "stekt" stripped → "fläsk" — **but no bare `fläsk` entry**; needs alias (see gaps) |

### (b) Typo / encoding corruption in golden data
- `crme fraiche`, `créme frache` — mangled *crème fraîche* (register covers 5 spelling aliases)
- `msli` — mangled *müsli* (register has müsli + `musli` alias)
- `grönsaksbuljonk` — typo for *grönsaksbuljong* (in register)
- `turkish peppar` — English/Swedish hybrid; probable *turkisk peppar* (candy-spice) — no register entry either way
- `gruyre ost` — mangled *gruyère* (register has gruyère)
- `mixed sallad` — English hybrid for *blandsallad* (no `blandsallad`/`mixsallad` entry — borderline gap)

### (c) Genuine gaps / normalization defects
| Miss | Verdict |
|---|---|
| **korv / rökta korvar / korvar** | No generic "korv" entry (only specific sausages). Alias or generic entry needed — **gluten, milk, soy** allergens |
| **yoggi** | Brand alias for yoghurt missing — **milk** |
| **kokos** | No bare "kokos"; only compounds (kokosnöt exists but "kokos" isn't an alias) — **coconut/tree-nut-adjacent** |
| **ärter** | Register has "ärtor" but not the common variant "ärter"; plural rules don't map er→or — alias gap |
| **morötterna** | Register alias has "morötter" but no rule strips definite-plural **`-erna`/`-orna`** (not in lookup variations or SwedishPluralization) — normalization defect, affects a whole word class |
| **turkiskyoghurt** | Register has "turkisk yoghurt" but space-*insertion* only works for `CompoundSuffixes.primarySuffixes`, which lacks `yoghurt` — normalization defect — **milk** |
| **glutenfritt mjöl** | No entry; diet descriptor is preserved so full string never matches — **gluten-free marker lost → wrong gluten verdict** |
| **sour cream** | No entry/alias (gräddfil exists; "sour cream" should alias to it) — **milk** |
| **salt och peppar** | "och"-conjunction lines aren't split by the pipeline (only "eller" is) — normalization defect, very common line (count 3) |
| **halloumi ost** (defect) | Register has halloumi, but suffix-strip variation leaves a **trailing space** (`'halloumi '`) — variations in `_generateLookupVariations` are never trimmed, so exact lookup fails. One-line fix in `lib/services/tagging/ingredient_lookup_service.dart` (`.trim()` the generated variations) |

## 2. Independent gap sweep (grepped absent, aliases included)

Coverage is strong — dairy, flours, charcuterie, veg substitutes, sauces are nearly all present (gräddfil, kvarg, kesella, filmjölk, ströbröd, quorn, oumph, sojafärs, isterband, kabanoss, bearnaise, ostronsås etc. all found). Confirmed absent:

| Missing staple | Allergen impact |
|---|---|
| **skorpmjöl** (0 hits) | gluten — breading staple, UNKNOWN verdict |
| **vaniljyoghurt** (0 hits, no vanilj+yoghurt combo) | milk |
| **korv** generic + **korvar** plural alias | gluten/milk/soy (sausage fillers) |
| **fläsk** bare (only compounds/sidfläsk) | none direct, but misses "stekt fläsk" classic |
| **sour cream** (EN alias for gräddfil) | milk — English-language recipes |
| **glutenfritt mjöl** (gluten-free flour mix) | gluten (false CONTAINS or UNKNOWN) |
| **blandsallad/mixsallad** | low risk |
| **turkisk peppar** | low risk (candy) |
| **yoggi** (brand) | milk |
| **kokos** bare alias | coconut |

## Key takeaways
- Majority of golden misses (≈25/44) are artifacts of exact-match evaluation, not real gaps — runtime normalization handles them.
- Three **code defects** matter more than register gaps: no `-erna/-orna` definite-plural stripping, untrimmed suffix-split variations (trailing space), and no "och" splitting. Each blocks whole classes of lines, not single ingredients.
- Highest-allergen-risk register additions: **skorpmjöl, generic korv, vaniljyoghurt, sour cream→gräddfil alias, glutenfritt mjöl, yoggi, kokos alias**.