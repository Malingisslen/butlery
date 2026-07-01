## Firestore vs CSV drift check — `ingredients` collection (project butlery-app-1)

### Targeted docs

| id | properties (Firestore vs CSV) | status | aliasesSv | Match? |
|---|---|---|---|---|
| `vegofärs` | plant-based, processed, vegan-friendly = CSV | validated = CSV | Firestore stores **one element** `"vegetarisk färs,växtbaserad färs"` (comma-joined string), CSV intends 2 aliases | ⚠️ match in content, malformed array split |
| `tartar-sauce` | plant-based, processed, vegan-friendly = CSV | validated = CSV | `remouladsås` = CSV; searchTerms also one comma-joined string `"tartar sauce,tartarsås"` | ⚠️ same comma issue in searchTerms |
| `oyster` | animal-product, mollusc, needs-cooking, seafood = CSV | draft = CSV | europeiskt ostron; platt ostron = CSV | ✅ |
| `chicken-oyster` | animal-product, meat, needs-cooking, poultry = CSV | draft = CSV | ostron; ryggbit = CSV | ✅ |
| `soy-mince` | needs-cooking, plant-based, soy, vegan-friendly = CSV | draft = CSV | vegofärs; växtfärs; sojakross = CSV | ✅ |
| `remoulade` | animal-product, egg, processed = CSV | draft = CSV | remoulade; dansk remoulade = CSV | ✅ |

### 10-doc sample (a-fil … aioli)
All 10 match the CSV on properties, status, group, swedish/english, and aliases. One cosmetic difference: `abalone` doc has aliasesSv `[havsöra, paua]` and aliasesEn `[paua, ear shell]` — identical to CSV. No content drift found in any sampled doc.

### learnedAliasesSv
None of the 16 docs inspected have a `learnedAliasesSv` field at all. A collection query for `learnedAliasesSv != []` returned **zero documents** — so no doc in the collection has a non-empty `learnedAliasesSv` (the query also excludes docs lacking the field, which is the correct semantics here). The learning loop has written nothing the CSV doesn't know about.

### Collection size
The available Firebase MCP tooling has no count/aggregation call, so I could not count the collection. (Query with limit works; no size estimate beyond "≥ the sampled docs".)

### Verdict
**No meaningful drift.** Live Firestore matches the CSV on properties, status, and alias content for all 16 docs checked, and there are zero learned aliases anywhere. The only defect found is a **sync bug, not drift**: rows whose CSV alias/search-term lists use commas instead of semicolons (`vegofärs`, `tartar-sauce` — the ai-coverage-check rows) get synced as a single comma-joined array element instead of being split — worth fixing in `sync-ingredients.ts` (split on both `;` and `,`, or normalize the CSV). Firestore timestamps show the last sync ran 2025-12-27.