# Källauktoritetsregister

**GENERERAD FIL — ändra `source-authority.json`, inte den här.** Renderad av `tools/gen-authority.mjs` ur `source-authority.json` 2.0 (2026-08-05). Valideras av T-20: exakt en aktiv auktoritet per domän, varje deklarerad fil finns, statusarna hör till ordboken, och `supersededBy` bildar ingen cykel.

**Precedens.** En rad per beslutsdomän. Auktoriteten följer styrdokumentets § 3 — **domänägarskap, ingen generell vinnarordning**. En konflikt mellan två domäner är ett valideringsfel som ska fälla bygget och visa båda källorna, aldrig ett tyst val.

**Maskin-id.** Kontroller heter `CHK-*`, krav heter `REQ-*`. Namnrymderna är disjunkta sedan Fas 0.10 och prövas av M-20.

## Normativa källor

**Två dimensioner, inte en.** `authorityState` säger vilken roll posten spelar för sin domän; `changePolicy` säger om källan får ändras. De är oberoende — `legacy-api-contract.json` är både **gällande** och **fryst**. Endast `active` är normativ, och endast `planned` får sakna fil.

| Domän-id | Domän | Normativ källa | Version | Tillstånd | Ändringspolicy | Ägare | Anmärkning |
|---|---|---|---|---|---|---|---|
| `product-invariants` | Produktinvarianter (beteende, datasäkerhet) | `produktregler.md` | 1.12 | gällande (`active`) | underhålls | PRODUKT | **två** öppna beslut kvar (genereringskontraktet, åldersgränsen). Allergentillstånden och veckomodellen är beslutade — se styrdokumentets § 9A |
| `design-values` | Designvärden | `tokens.json` | 1.13 | gällande (`active`) | underhålls | DS | schemat validerar hela strukturen (`butlery-tokens/2`), fältnivå för samtliga 13 kontrollkomponenter · T-01. Designvärden bor BARA här: `bodyMedium` och de sju överläggstokens flyttades hit från mappningsfilen |
| `token-structure` | Tokenstruktur | `butlery-tokens.schema.json` | 2.0 | gällande (`active`) | underhålls | DS | fältnivå, typer och gränser. Samma validator (`walkSchema`) som rapport- och mappningsschemat |
| `legacy-dart-api-map` | Äldre Dart-API mot token-id | `tools/app-theme-map.json` | 1.4 | gällande (`active`) | underhålls | DEV | mappningsbeslut, **aldrig designvärden** — varje högersida är ett token-id eller ett rollnamn (T-01). Eget schema; värdena mäts mot genererad Dart av TG-01, inklusive `scheme.darkOverrides` och `typeSemantic.color` |
| `brand-colors` | Externa varumärkesfärger | `assets/brand-colors.json` | 1.0 | gällande (`active`) | underhålls | PRODUKT | citat, inte design. Schemavalideras av T-01 |
| `legacy-api-surface` | Publik Dart-API-yta (legacy) | `legacy-api-contract.json` | 1.0 | gällande (`active`) | fryst | DEV | 120 AppColors-medlemmar, 2 ColorScheme-fält, 76 AppTextStyles-getters, 3 strängkonstanter. TG-01 kräver exakt mängdlikhet i båda riktningarna. **Fryst ur den levererade koden, inte ur app-repot** — att ytan motsvarar appens faktiska anrop är overifierat till Fas 2 (§ 9E) |
| `component-contract` | Komponent-API, semantik, tillstånd | *saknas* | — | planerad (`planned`) | underhålls | DS | Fas 3-leverabel. Ingen aktiv auktoritet finns för domänen förrän dess. `Butlery Komponentark v1.dc.html` är handritad, ej maskinläsbar och **inte normativ** — den läses som underlag, aldrig som kontrakt. |
| `layout-composition` | Layout och komposition | `Butlery Skarmar v12.dc.html` | v12 | gällande (`active`) | underhålls | DS | innehållsfil plus fjorton delfiler. 326 artefakter utan `artifact`/`status` — Fas 2 |
| `content-text` | Text | `content-style-guide.md` | 1.1 | gällande (`active`) | underhålls | DS | — |
| `a11y-handoff` | Semantik och tillstånd (handoff) | `Butlery tillganglighetshandoff.dc.html` | mot manual V6 | gällande (`active`) | underhålls | DS | täcker roll och namn, **inte tillstånd** — minst 245 luckor (A11Y-02) |
| `icon-names` | Ikonnamn och antal | `icons.json` | 1.8 | gällande (`active`) | underhålls | DS | `usages` genereras av `gen-icons`, statusen mäts mot filnärvaro av T-05. Regenererad och byteidentisk mellan körningar |
| `asset-status` | Filstatus och paketering | `assets-manifest.json` | 1.4 | gällande (`active`) | underhålls | DEV | filreferenser kontrolleras av T-06b |
| `principles` | Principer och motiv | `Butlery Grafisk manual v6.dc.html` | V6 | gällande (`active`) | underhålls | DS | förklarar, föreskriver inte värden |
| `requirement-status` | Kravstatus | `evidensmatris.md` | 1.0 | gällande (`active`) | underhålls | DS | radantal och statusfördelning räknas ur filens egna rader och redovisas i `fas0/verify-report.json` — inga handskrivna totaler |
| `test-matrix` | Vad som ska bevisas | `testmatris.md` | 1.1 | gällande (`active`) | underhålls | DS | T-01…T-12 definieras där, T-13…T-19 i `evidensmatris.md`. Kontrollernas utfall står i den genererade rapporten |
| `platform-differences` | Plattformsskillnader | `plattformsmatris.md` | 1.0 | gällande (`active`) | underhålls | DS | — |
| `flows-budget-analytics` | Flöden, budget, analytics | `flows-roles-budget.md` | 1.1 | gällande (`active`) | underhålls | DS | — |
| `decisions` | Beslut | `beslutslogg.md` | 1.6 | gällande (`active`) | underhålls | DS | de tre besluten ur `luckor-etapp9.md` är införda som B-44, B-47 och B-48; K-09 är stängd av B-45 |
| `report-schema` | Verifieringsrapportens struktur | `fas0/verify-report.schema.json` | 2.0 | gällande (`active`) | underhålls | DS | genereras ur `REPORT_SCHEMA` av `tools/gen-schema.mjs` |
| `control-register` | Kontrollregister | `tools/controls.mjs` | — | gällande (`active`) | underhålls | DS | kontrollernas id, namn, ägare, fas och grindtillhörighet. Renderas till både `verify-report.json` och `kontrollstatus.md` — skriv inga kontrollrader för hand |
| `source-authority` | Källauktoritet | `source-authority.json` | 2.0 | gällande (`active`) | underhålls | DS | den här filen. `fas0/kallauktoritetsregister.md` genereras ur den; T-20 validerar den. Filens `version` och den här postens `version` är samma värde — avvikelse fälls av T-20 (F1-H01). |
| `governance` | Styrning, fasmodell och grindar | `Butlery styrdokument modulart designsystem.dc.html` | 2.6 | gällande (`active`) | underhålls | DS | ligger i leveransroten (`zip:/`), men källan är versionshanterad i `leverans/` sedan F1-U01 — T-20 läser och jämför dess verkliga version. Definierar faserna, grindarna, statusordboken och §§ 9A–9E. **2.6**: § 18.4 skriven mot den tvådimensionella modellen (F1-U07). |
| `document-runtime` | Dokumentruntime (dc-runtime) | `support.js` | — | gällande (`active`) | fryst | DEV | genererad körtidsfil för `.dc.html`-dokumenten — `// GENERATED from dc-runtime/src/*.ts`. Den bär ingen egen version. **Två byggen finns i leveransen** och de är avsiktligt olika, se `runtimeInstances`. Ingen av dem får skrivas över eller slås ihop utan att relationen omprövas (F1-H07). |
| `selection-contexts` | Urvalsdimensioner och runtimeadapter | `selection-contexts.json` | 1.1 | gällande (`active`) | underhålls | DEV | F2-A04: vokabulär, giltiga urvalskontexter och runtimeadapter. plattformsmatris.md är dokumentation och genereras härifrån — en Markdown-tabell kan inte vara maskinkälla. En dimension får aktiveras först när den har både dokumentationskälla och en deterministisk runtimeadapter med verkliga användningsställen i appkoden. |
| `layout-contract` | Layoutlagen, viewportprofiler och prober | `layout-contract.json` | 1.3 | planerad (`planned`) | underhålls | DS | F2-L01: tre lagen (compact/medium/expanded), fyra profiler och sex prober. DRAFT - contractState draft och activationBlockers i filen. Appens brytpunktskod far inte andras forran 72-anropsinventeringen och R-01…R-04 ar granskade. Kolumntrappan med steg vid 1920 ar en oloest parallell modell, se parallelModels. |

## Dokumentruntime

Två byggen av `support.js` finns i leveransen. De är **avsiktligt olika** och båda är manifestdeklarerade. Ingen av dem får skrivas över eller slås ihop utan att relationen omprövas.

| Sökväg | Var | Manifeststatus | Konsumenter | Anmärkning |
|---|---|---|---|---|
| `support.js` | reporoten | declared | 23 | laddas av de 23 `.dc.html`-dokumenten i reporoten. Äldre bygge — saknar deck-stödet nedan. Inget dokument i leveransen använder deck-taggar, så skillnaden är utan verkan i dag. |
| `zip:/support.js` | leveransroten | declared | 4 | laddas av de fyra dokumenten i leveransroten. **Senare bygge**: strikt superset av den inre — 70 rader mer, tillägget är `isDeckMountTag`, `renderDeckKids` och `walkDeckChildren`. Ingenting är borttaget. |

## Genererade artefakter — ingen egen auktoritet

Tabellen nedan räknas ur den här filens `generatedArtifacts` och headerns egen tokenversion — den skrivs inte för hand. Beslut B-27 är omformulerat: temat är *genererat ur* tokens och är därmed inte en egen sanning.

| Fil | Generator | Tokenversion i headern | Aktuell mot `tokens.json` 1.13 |
|---|---|---|---|
| `fas0/verify-report.schema.json` | `tools/gen-schema.mjs` | — | ingen tokenrad (renderas ur annan källa) |
| `assets/generated/tokens.css` | `tools/gen-css.mjs` | 1.13 | **ja** |
| `lib/theme/butlery_tokens.dart` | `tools/gen-flutter.mjs` | 1.13 | **ja** |
| `lib/theme/app_colors.dart` | `tools/gen-app-theme.mjs` | 1.13 | **ja** |
| `lib/theme/app_text_styles.dart` | `tools/gen-app-theme.mjs` | 1.13 | **ja** |
| `fas0/kallauktoritetsregister.md` | `tools/gen-authority.mjs` | — | ingen tokenrad (renderas ur annan källa) |
| `fas0/artefaktforslag.md` | `tools/gen-artifact-proposal.mjs` | — | ingen tokenrad (renderas ur annan källa) |

## Superseded och frysta

| Fil | Var | Tillstånd | Ändringspolicy | Ersatt av | Anmärkning |
|---|---|---|---|---|---|
| `uploads/Butlery-arbetsorder-modulart-designsystem.md` | uploads-roten | ersatt (`superseded`) | fryst | `Butlery styrdokument modulart designsystem.dc.html` | superseded som instruktion. Sökvägen är leveransrelativ (zip:/uploads/…) — F1-H07: det bara-filnamnet som stod här matchade ingen manifestpost och kunde därför inte kontrolleras. |
| `Butlery granskning och implementeringsplan.dc.html` | projektroten | ersatt (`superseded`) | fryst | `Butlery styrdokument modulart designsystem.dc.html` | superseded som instruktion |
| `arbetsplan.md` | paketet | historisk (`historical`) | fryst | — | etapp 0–11 genomförda |
| `grundgranskning.md` | paketet | ersatt (`superseded`) | fryst | `beslutslogg.md` | besluten B-36…B-38, B-40, B-41 |
| `luckor-etapp9.md` | paketet | ersatt (`superseded`) | fryst | `beslutslogg.md` | de tre besluten finns som B-44, B-47 och B-48. Filen bär inget levande beslut |
| `migration-gap.md` | paketet | ersatt (`superseded`) | fryst | `beslutslogg.md` | K-09 är stängd av B-45 |
| `granskning-v12.md` | paketet | ersatt (`superseded`) | fryst | `fas0/verify-report.json` | dess sluttal (320 ramar, noll fynd) är motbevisade |
| `fas0/baseline-report-SUPERSEDED.json` | paketet | ersatt (`superseded`) | fryst | `fas0/verify-report.json` | sandlådebaslinje, behålls som spår |

## Statusordbok för kontroller

| Status | Betyder | Får uppfylla ett godkännandekriterium? |
|---|---|---|
| `passed` | kontrollen kördes och godkändes (varningar tillåtna, räknas separat) | ja |
| `failed` | kontrollen kördes och fällde | **nej** |
| `blocked` | kontrollen kördes mot en artefakt som en fallerad producent inte kunde skriva om — utfallet är en följd, inte ett självständigt fynd | **nej** |
| `not run` | kontrollen kördes inte | **nej** |
| `not applicable` | kontrollen kan inte gälla i detta läge; motivering och ägare obligatoriska | ja |

`not applicable` får aldrig användas för något som bara ännu inte körts. Samma ordbok gäller i styrdokumentets § 15, `tools/controls.mjs` och den genererade `fas0/kontrollstatus.md`.

## Statusordbok för källor

Maskinvärdena är engelska och definieras i `tools/authority-contract.mjs`. De svenska etiketterna sätts i presentationslagret — de finns inte i maskinfältet och får inte skrivas dit.

| `authorityState` | Etikett | Normativ? | Aktuell auktoritet? | Kräver fil? |
|---|---|---|---|---|
| `active` | gällande | **ja** | ja | ja |
| `planned` | planerad | nej | ja | nej |
| `superseded` | ersatt | nej | **nej** | ja |
| `historical` | historisk | nej | **nej** | ja |
| `concept` | koncept | nej | **nej** | ja |

| `changePolicy` | Etikett | Betyder |
|---|---|---|
| `maintained` | underhålls | källan får ändras inom sin domän |
| `frozen` | fryst | låst — får inte ändras utan att kontraktet omförhandlas. Oberoende av `authorityState`: en källa kan vara `active` och `frozen` samtidigt |

## Regel för frysta filer

En fryst fil får inte samtidigt vara enda källa till ett levande beslut. Skulle en fryst fil visa sig bära ett levande beslut ska den **återaktiveras** tills beslutet migrerats — inte frysas med en fotnot.

## Rapportkatalog

Reporoten är paketet. Rapportkatalogen är dess `fas0/`. Körningen skriver `verify.log`, `verify-report.json` och `kontrollstatus.md` dit. **Inga körsummeringar står i dokument** — de läses ur den genererade rapporten.
