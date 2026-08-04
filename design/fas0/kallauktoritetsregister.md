# Källauktoritetsregister

**GENERERAD FIL — ändra `source-authority.json`, inte den här.** Renderad av `tools/gen-authority.mjs` ur `source-authority.json` 1.1 (2026-08-05). Valideras av T-20: exakt en aktiv auktoritet per domän, varje deklarerad fil finns, statusarna hör till ordboken, och `supersededBy` bildar ingen cykel.

**Precedens.** En rad per beslutsdomän. Auktoriteten följer styrdokumentets § 3 — **domänägarskap, ingen generell vinnarordning**. En konflikt mellan två domäner är ett valideringsfel som ska fälla bygget och visa båda källorna, aldrig ett tyst val.

**Maskin-id.** Kontroller heter `CHK-*`, krav heter `REQ-*`. Namnrymderna är disjunkta sedan Fas 0.10 och prövas av M-20.

## Normativa källor

| Domän | Normativ källa | Version | Status | Ägare | Anmärkning |
|---|---|---|---|---|---|
| Produktinvarianter (beteende, datasäkerhet) | `produktregler.md` | 1.12 | gällande | PRODUKT | **två** öppna beslut kvar (genereringskontraktet, åldersgränsen). Allergentillstånden och veckomodellen är beslutade — se styrdokumentets § 9A |
| Designvärden | `tokens.json` | 1.13 | gällande | DS | schemat validerar hela strukturen (`butlery-tokens/2`), fältnivå för samtliga 13 kontrollkomponenter · T-01. Designvärden bor BARA här: `bodyMedium` och de sju överläggstokens flyttades hit från mappningsfilen |
| Tokenstruktur | `butlery-tokens.schema.json` | 2.0 | gällande | DS | fältnivå, typer och gränser. Samma validator (`walkSchema`) som rapport- och mappningsschemat |
| Äldre Dart-API mot token-id | `tools/app-theme-map.json` | 1.4 | gällande | DEV | mappningsbeslut, **aldrig designvärden** — varje högersida är ett token-id eller ett rollnamn (T-01). Eget schema; värdena mäts mot genererad Dart av TG-01, inklusive `scheme.darkOverrides` och `typeSemantic.color` |
| Externa varumärkesfärger | `assets/brand-colors.json` | 1.0 | gällande | PRODUKT | citat, inte design. Schemavalideras av T-01 |
| Publik Dart-API-yta (legacy) | `legacy-api-contract.json` | 1.0 | fryst | DEV | 120 AppColors-medlemmar, 2 ColorScheme-fält, 76 AppTextStyles-getters, 3 strängkonstanter. TG-01 kräver exakt mängdlikhet i båda riktningarna. **Fryst ur den levererade koden, inte ur app-repot** — att ytan motsvarar appens faktiska anrop är overifierat till Fas 2 (§ 9E) |
| Komponent-API, semantik, tillstånd | *saknas* | — | ska skapas | DS | Fas 3-leverabel. Interimistiskt: `Butlery Komponentark v1.dc.html`, handritad, ej maskinläsbar |
| Layout och komposition | `Butlery Skarmar v12.dc.html` | v12 | gällande | DS | innehållsfil plus fjorton delfiler. 326 artefakter utan `artifact`/`status` — Fas 2 |
| Text | `content-style-guide.md` | 1.1 | gällande | DS | — |
| Semantik och tillstånd (handoff) | `Butlery tillganglighetshandoff.dc.html` | mot manual V6 | gällande | DS | täcker roll och namn, **inte tillstånd** — minst 245 luckor (A11Y-02) |
| Ikonnamn och antal | `icons.json` | 1.8 | gällande | DS | `usages` genereras av `gen-icons`, statusen mäts mot filnärvaro av T-05. Regenererad och byteidentisk mellan körningar |
| Filstatus och paketering | `assets-manifest.json` | 1.4 | gällande | DEV | filreferenser kontrolleras av T-06b |
| Principer och motiv | `Butlery Grafisk manual v6.dc.html` | V6 | gällande | DS | förklarar, föreskriver inte värden |
| Kravstatus | `evidensmatris.md` | 1.0 | gällande | DS | radantal och statusfördelning räknas ur filens egna rader och redovisas i `fas0/verify-report.json` — inga handskrivna totaler |
| Vad som ska bevisas | `testmatris.md` | 1.1 | gällande | DS | T-01…T-12 definieras där, T-13…T-19 i `evidensmatris.md`. Kontrollernas utfall står i den genererade rapporten |
| Plattformsskillnader | `plattformsmatris.md` | 1.0 | gällande | DS | — |
| Flöden, budget, analytics | `flows-roles-budget.md` | 1.1 | gällande | DS | — |
| Beslut | `beslutslogg.md` | 1.6 | gällande | DS | de tre besluten ur `luckor-etapp9.md` är införda som B-44, B-47 och B-48; K-09 är stängd av B-45 |
| Verifieringsrapportens struktur | `fas0/verify-report.schema.json` | 2.0 | gällande | DS | genereras ur `REPORT_SCHEMA` av `tools/gen-schema.mjs` |
| Kontrollregister | `tools/controls.mjs` | — | gällande | DS | kontrollernas id, namn, ägare, fas och grindtillhörighet. Renderas till både `verify-report.json` och `kontrollstatus.md` — skriv inga kontrollrader för hand |
| Källauktoritet | `source-authority.json` | 1.0 | gällande | DS | den här filen. `fas0/kallauktoritetsregister.md` genereras ur den; T-20 validerar den |
| Styrning, fasmodell och grindar | `Butlery styrdokument modulart designsystem.dc.html` | 2.5 | gällande | DS | ligger i ZIP-roten, inte i reporoten (`zip:/`). Definierar faserna, grindarna, statusordboken och §§ 9A–9E |

## Genererade artefakter — ingen egen auktoritet

Tabellen nedan räknas ur den här filens `generatedArtifacts` och headerns egen tokenversion — den skrivs inte för hand. Beslut B-27 är omformulerat: temat är *genererat ur* tokens och är därmed inte en egen sanning.

| Fil | Generator | Tokenversion i headern | Aktuell mot `tokens.json` 1.13 |
|---|---|---|---|
| `assets/generated/tokens.css` | `tools/gen-css.mjs` | 1.13 | **ja** |
| `lib/theme/butlery_tokens.dart` | `tools/gen-flutter.mjs` | 1.13 | **ja** |
| `lib/theme/app_colors.dart` | `tools/gen-app-theme.mjs` | 1.13 | **ja** |
| `lib/theme/app_text_styles.dart` | `tools/gen-app-theme.mjs` | 1.13 | **ja** |
| `fas0/kallauktoritetsregister.md` | `tools/gen-authority.mjs` | — | ingen tokenrad (renderas ur annan källa) |

## Superseded och frysta

| Fil | Var | Status | Ersatt av | Anmärkning |
|---|---|---|---|---|
| `Butlery-arbetsorder-modulart-designsystem.md` | uploads-roten | historisk | `Butlery styrdokument modulart designsystem.dc.html` | superseded som instruktion |
| `Butlery granskning och implementeringsplan.dc.html` | projektroten | historisk | `Butlery styrdokument modulart designsystem.dc.html` | superseded som instruktion |
| `arbetsplan.md` | paketet | historisk | — | etapp 0–11 genomförda |
| `grundgranskning.md` | paketet | historisk | `beslutslogg.md` | besluten B-36…B-38, B-40, B-41 |
| `luckor-etapp9.md` | paketet | historisk | `beslutslogg.md` | de tre besluten finns som B-44, B-47 och B-48. Filen bär inget levande beslut |
| `migration-gap.md` | paketet | historisk | `beslutslogg.md` | K-09 är stängd av B-45 |
| `granskning-v12.md` | paketet | historisk | `fas0/verify-report.json` | dess sluttal (320 ramar, noll fynd) är motbevisade |
| `fas0/baseline-report-SUPERSEDED.json` | paketet | historisk | `fas0/verify-report.json` | sandlådebaslinje, behålls som spår |

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

| Status | Betyder |
|---|---|
| `gällande` | aktiv normativ källa för sin domän |
| `fryst` | aktiv men låst — får inte ändras utan att kontraktet omförhandlas |
| `historisk` | underhålls inte, får inte citeras som gällande, bär en FRYST-rad överst |
| `ska skapas` | domänen har ingen maskinläsbar auktoritet ännu — leverabel i en senare fas |

## Regel för frysta filer

En fryst fil får inte samtidigt vara enda källa till ett levande beslut. Skulle en fryst fil visa sig bära ett levande beslut ska den **återaktiveras** tills beslutet migrerats — inte frysas med en fotnot.

## Rapportkatalog

Reporoten är paketet. Rapportkatalogen är dess `fas0/`. Körningen skriver `verify.log`, `verify-report.json` och `kontrollstatus.md` dit. **Inga körsummeringar står i dokument** — de läses ur den genererade rapporten.
