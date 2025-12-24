# Recipe Parser Implementation Plan (v2 - Critical Review)

## Critical Analysis: What Actually Improves the System

### Components to KEEP (existing is better/sufficient)

| Component | Existing File | Why Keep |
|-----------|--------------|----------|
| IngredientParser | `lib/utils/text/ingredient_parser.dart` | World-class, 100+ tests, Unicode fractions, 50+ units |
| UrlNormalizer | `lib/services/import/cache/url_normalizer.dart` | Full-featured, 15+ tracking params stripped |
| ContentFingerprint | `lib/services/import/cache/content_fingerprint.dart` | Better than spec - uses title+ingredients+count |
| GlobalRecipeCache | `lib/services/import/cache/global_recipe_cache.dart` | Cross-user deduplication, Firestore-based |
| RecipeScraper | `lib/utils/recipe_scraper.dart` | Proven JSON-LD + microdata extraction |
| Site Parsers | `lib/services/extraction/site_parsers/` | Working ICA, Arla, Köket, Recept parsers |

### Components to ADD (genuinely new/better from spec)

| Component | Why Add | Security |
|-----------|---------|----------|
| **FieldResult + ParseConfidence** | Per-field confidence enables smart LLM patching | - |
| **SwedishLineClassifier** | NEW capability for Instagram/TikTok/YouTube text | - |
| **HtmlSanitizer** | Injection pattern detection, homoglyph detection | Security |
| **CircuitBreaker** | Reliability when Firestore is down | P1-3 |
| **Local RecipeCache (Hive)** | Per-user fast cache + P0-1 content-hash protection | P0-1 |
| **LLM Schema Validation** | Allowlist-based validation prevents injection | P0-2 |
| **RecipeParserService** | Quality-based tier progression, smart merging | - |
| **SiteConfigTier** | Dynamic Firestore configs (no app release for updates) | - |

### Components to SKIP

| Component | Why Skip |
|-----------|----------|
| Spec's SwedishIngredientParser | Existing is more mature |
| Spec's UrlCanonicalizer | UrlNormalizer already does this |
| Spec's AuthState | Use existing PermissionService.currentUser |
| Clock abstraction | Skip unless needed for testing |

---

## Revised Implementation Strategy

**Approach**: Enhance existing system with spec's improvements, don't replace working code.

### What This Means:

1. **Keep ImportManager** as the entry point, add RecipeParserService as a parsing backend
2. **Keep GlobalRecipeCache**, add local Hive cache for faster per-user access
3. **Keep RecipeScraper**, wrap it to produce TierResult format for tier architecture
4. **Keep site parsers**, make SiteConfigTier a complement (Firestore configs for new sites)
5. **Enhance LlmEnhancementService** with P0-2 schema validation

---

## Phase 1: Foundation Models

**Goal**: New data structures for confidence tracking

### Files to Create

```
lib/models/parsing/field_result.dart       # FieldResult<T>, ParseConfidence
lib/models/parsing/tier_result.dart        # TierResult, TierFailureReason
lib/models/parsing/parsed_recipe.dart      # ParsedRecipe with confidence tracking
lib/models/parsing/parse_metadata.dart     # ParseMetadata
lib/models/parsing/site_config.dart        # SiteConfig (for Firestore configs)
```

**Note**: ParsedIngredient can use existing ingredient models or be new.

**Dependencies**: None
**Verification**: `flutter analyze`

---

## Phase 2: Security & Reliability Infrastructure

**Goal**: Add P0-1, P1-3 security/reliability features

### Files to Create

```
lib/core/circuit_breaker.dart                           # P1-3: Reliability
lib/services/parsing/cache/local_recipe_cache.dart      # P0-1: Per-user Hive cache with content-hash
lib/services/parsing/sanitizers/html_sanitizer.dart     # Injection detection
```

### Files to Modify

```
lib/services/import/cache/global_recipe_cache.dart      # Optional: Add P0-1 content-hash enhancement
```

**Key P0-1 Fix**: Cache key = SHA256(userId | urlHash | contentHash | source | version)
- Content-hash prevents poisoning from A/B tests, geo-targeting

**Dependencies**: Phase 1 models
**Verification**: Unit tests for CircuitBreaker, cache key generation

---

## Phase 3: Swedish Line Classifier (NEW Capability)

**Goal**: Classify unstructured text (Instagram, TikTok, YouTube)

### Files to Create

```
lib/services/parsing/parsers/swedish_line_classifier.dart
```

**Features**:
- Classifies lines as: ingredient, instruction, title, metadata, sectionHeader, empty
- Swedish food words, verb detection, unit detection
- Groups lines into RecipeSections
- Handles section headers ("Ingredienser:", "Gör så här:", etc.)

**Dependencies**: Phase 1 models
**Verification**: Unit tests with Swedish recipe text samples

---

## Phase 4: Tier Architecture

**Goal**: Wrap existing parsers in tier pattern for quality-based progression

### Files to Create

```
lib/services/parsing/tiers/parsing_tier.dart           # Abstract + TimeoutHandling
lib/services/parsing/tiers/parsing_context.dart        # Shared context (DOM parsed once)
lib/services/parsing/tiers/schema_org_tier.dart        # Wraps RecipeScraper
lib/services/parsing/tiers/site_config_tier.dart       # Firestore-based CSS selectors
lib/services/parsing/tiers/rule_based_tier.dart        # Uses SwedishLineClassifier
lib/services/parsing/tiers/llm_tier.dart               # P0-2: Schema validation
lib/services/parsing/common/recipe_merger.dart         # Merges results from tiers
```

### Implementation Notes

**SchemaOrgTier**: Delegates to existing RecipeScraper, converts output to TierResult
**SiteConfigTier**: New Firestore collection for CSS selectors per domain
**RuleBasedTier**: Uses new SwedishLineClassifier + existing IngredientParser
**LlmTier**: Wraps existing LlmEnhancementService with P0-2 validation

### P0-2 Security Fix in LlmTier

```dart
// Allowlist-based schema validation
const allowedKeys = {'title', 'portions', 'ingredients', 'instructions', 'totalTimeMinutes'};
const allowedIngredientKeys = {'quantity', 'unit', 'name', 'preparation'};
// Reject if unknown keys or suspicious patterns in values
```

**Dependencies**: Phase 1-3
**Verification**: Integration tests per tier

---

## Phase 5: Orchestration

**Goal**: Wire tiers together with quality-based progression

### Files to Create

```
lib/services/parsing/recipe_parser_service.dart        # Main orchestration, P1-3 circuit breaker
lib/repositories/site_config_repository.dart           # Reads Firestore site configs
```

### RecipeParserService Logic

```
1. Check local cache (P0-1 protected)
2. Check global cache (existing GlobalRecipeCache)
3. Run tiers in order:
   - Tier 1: SchemaOrgTier (JSON-LD)
   - Tier 2: SiteConfigTier (CSS selectors from Firestore)
   - Tier 3: RuleBasedTier (Swedish line classification)
   - Tier 4: LlmTier (expensive fallback with P0-2 validation)
4. Stop when quality >= threshold
5. Merge results from multiple tiers
6. LLM patch weak fields if quality < threshold
7. Save to caches (with P1-3 circuit breaker)
```

### Files to Modify

```
lib/services/import/import_manager.dart                # Add option to use RecipeParserService
lib/services/import/url_import_strategy.dart           # Delegate to RecipeParserService
DI module                                              # Register new services
```

**Dependencies**: All previous phases
**Verification**: End-to-end test importing recipe from URL

---

## Phase 6: Backend (Optional - Can Defer)

**Goal**: Server-side analytics and security

### Files to Create (if proceeding)

```
functions/src/utils/rate-limiter.ts
functions/src/events/log-parse-event.ts     # P1-4: Server ignores client tierSummaries
```

### Firestore Rules to Add

```
/site_configs/{domain}                       # Read-only for clients
/parse_events/{eventId}                      # No direct access (via callable only)
```

**Note**: Backend can be added later. Core parsing improvements work without it.

---

## Security Fixes Summary

| Fix | Location | Description |
|-----|----------|-------------|
| **P0-1** | `local_recipe_cache.dart` | Content-hash in cache key prevents poisoning |
| **P0-2** | `llm_tier.dart` | Allowlist schema validation prevents injection |
| **P1-3** | `recipe_parser_service.dart` | Circuit breaker for cache/event writes |
| **P1-4** | `log-parse-event.ts` | Server ignores client analytics (optional/defer) |

---

## Files Summary

### New Files (~15 Dart)

```
lib/models/parsing/field_result.dart
lib/models/parsing/tier_result.dart
lib/models/parsing/parsed_recipe.dart
lib/models/parsing/parse_metadata.dart
lib/models/parsing/site_config.dart
lib/core/circuit_breaker.dart
lib/services/parsing/cache/local_recipe_cache.dart
lib/services/parsing/sanitizers/html_sanitizer.dart
lib/services/parsing/parsers/swedish_line_classifier.dart
lib/services/parsing/tiers/parsing_tier.dart
lib/services/parsing/tiers/parsing_context.dart
lib/services/parsing/tiers/schema_org_tier.dart
lib/services/parsing/tiers/site_config_tier.dart
lib/services/parsing/tiers/rule_based_tier.dart
lib/services/parsing/tiers/llm_tier.dart
lib/services/parsing/common/recipe_merger.dart
lib/services/parsing/recipe_parser_service.dart
lib/repositories/site_config_repository.dart
```

### Files to Modify (~3)

```
lib/services/import/import_manager.dart          # Add RecipeParserService option
lib/services/import/url_import_strategy.dart     # Delegate to new service
DI module                                        # Register services
```

### Files to KEEP Unchanged

```
lib/utils/text/ingredient_parser.dart            # Excellent existing implementation
lib/utils/recipe_scraper.dart                    # Wrap, don't replace
lib/services/import/cache/url_normalizer.dart    # Already sufficient
lib/services/import/cache/content_fingerprint.dart
lib/services/import/cache/global_recipe_cache.dart
lib/services/extraction/site_parsers/*           # Keep as fallback
```

---

## Verification Checklist

After each phase:
- [ ] `flutter analyze` passes
- [ ] New tests pass
- [ ] No regressions in existing import functionality

Final verification:
- [ ] Import recipe from URL works end-to-end
- [ ] Swedish line classifier handles Instagram/TikTok text
- [ ] Quality-based tier progression works
- [ ] LLM fallback triggers appropriately
- [ ] P0-1, P0-2, P1-3 security fixes verified
