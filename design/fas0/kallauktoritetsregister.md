# Källauktoritetsregister · Fas 0

**Statusordbok — fem värden.** `passed` · `failed` · `blocked` (kördes mot en artefakt en fallerad producent inte kunde skriva om) · `not run` · `not applicable`. Endast `passed` och `not applicable` uppfyller ett godkännandekriterium. Samma ordbok gäller i styrdokumentets § 15, `tools/controls.mjs` och den genererade `fas0/kontrollstatus.md`.

**Maskin-id.** Kontroller heter `CHK-*`, krav heter `REQ-*`. Namnrymderna är disjunkta sedan Fas 0.10; se `testmatris.md` § Namnrymder.
Genererat 2026-07-31. En rad per beslutsdomän. `auktoritet` följer styrdokumentets § 3 — domänägarskap, ingen generell vinnarordning.
En konflikt mellan två domäner är ett valideringsfel som ska fälla bygget, inte lösas tyst.

## Normativa källor

| Domän | Normativ källa | Version | Status | Anmärkning |
|---|---|---|---|---|
| Produktinvarianter (beteende, datasäkerhet) | `produktregler.md` | 1.12 | gällande | **två** öppna beslut kvar (genereringskontraktet, åldersgränsen). Allergentillstånden och veckomodellen är beslutade — se styrdokumentets § 9A |
| Designvärden | `tokens.json` | **1.9** | gällande | indexets versionstabell rättad till 1.9 i Fas 0 · schemat validerar ännu inte hela strukturen (Fas 1) |
| Komponent-API, semantik, tillstånd | *saknas* | — | **ska skapas (Fas 3)** | interimistiskt: `Butlery Komponentark v1.dc.html`, handritad, ej maskinläsbar |
| Layout och komposition | fjorton skärmdelfiler | v12 | gällande, oklassificerad | 326 artefakter utan `artifact`/`status` — Fas 2 |
| Text | `content-style-guide.md` | 1.1 | gällande | |
| Semantik och tillstånd (handoff) | `Butlery tillganglighetshandoff.dc.html` | mot manual V6 | gällande | täcker roll och namn, **inte tillstånd** — minst 245 luckor |
| Filer och namn | `icons.json` 1.6 · `assets-manifest.json` 1.4 | | gällande, ej regenererade | `usages` genereras av `gen-icons` · avvikelser står i den genererade rapporten |
| Principer och motiv | `Butlery Grafisk manual v6.dc.html` | V6 | gällande | förklarar, föreskriver inte värden |
| Kravstatus | `evidensmatris.md` | 1.0 | gällande | radantal och statusfördelning räknas ur filens egna rader och ur `fas0/verify-report.json` — inga handskrivna totaler |
| Vad som ska bevisas | `testmatris.md` | 1.1 | gällande | T-01…T-12 definierade där; **T-13…T-17 definieras i `evidensmatris.md`** och är implementerade i Fas 0.2 utom T-13 (renderad, Fas 2) · `lint-controls` är steg i `tools/verify.mjs` · CI-workflowen levererad men **inte aktiverad** (CI-01) |
| Plattformsskillnader | `plattformsmatris.md` | 1.0 | gällande | |
| Flöden, budget, analytics | `flows-roles-budget.md` | 1.1 | gällande | |
| Beslut | `beslutslogg.md` | 1.6 | gällande | **50 poster.** De tre besluten ur `luckor-etapp9.md` är införda som B-44, B-47 och B-48; K-09 är stängd av B-45 (kontrollerat 2026-07-31) |

## Genererade artefakter — ingen egen auktoritet

| Fil | Anger tokenversion | Källa | Status |
|---|---|---|---|
| `assets/generated/tokens.css` | 1.3 | tokens.json 1.9 | **inaktuell** — regenereras i Fas 1 |
| `lib/theme/app_colors.dart` | 1.3 | tokens.json 1.9 | **inaktuell** |
| `lib/theme/app_text_styles.dart` | 1.3 | tokens.json 1.9 | **inaktuell** |
| `lib/theme/butlery_tokens.dart` | 1.4 | tokens.json 1.9 | **inaktuell** |

Beslut B-27 är **omformulerat i Fas 0** (`beslutslogg.md` och `00-spec-index.md`): temat är *genererat ur* tokens och är därmed inte en egen sanning. Formuleringen var giltig så länge temat var det enda maskinläsbara.

## Superseded och frysta

| Fil | Var | Status | Ersatt av |
|---|---|---|---|
| `Butlery-arbetsorder-modulart-designsystem.md` | uploads-roten | **superseded som instruktion** | `Butlery styrdokument modulart designsystem.dc.html` |
| `Butlery granskning och implementeringsplan.dc.html` | projektroten | **superseded som instruktion** | samma |
| `arbetsplan.md` | paketet | historisk, fryst | etapp 0–11 genomförda |
| `grundgranskning.md` | paketet | historisk, fryst | besluten B-36…B-38, B-40, B-41 |
| `luckor-etapp9.md` | paketet | historisk, fryst | **kontrollerat 2026-07-31:** de tre besluten finns i `beslutslogg.md` som B-44 (emoji-regeln), B-47 (knuffar och svep-tips) och B-48 (röstimporten). Filen bär inget levande beslut |
| `migration-gap.md` | paketet | historisk, fryst | **kontrollerat 2026-07-31:** K-09 är stängd av B-45 (gemensamt toppfält, iOS-gesterna kvar). `plattformsmatris.md` ska peka på B-45 i stället — kvarvarande redaktionell rad, inget levande beslut |
| `granskning-v12.md` | paketet | historisk, fryst | dess sluttal (320 ramar, noll fynd) är motbevisade; ersätts av paketets genererade `fas0/verify-report.json` |

Frysta filer underhålls inte och får inte citeras som gällande. De bär en `FRYST`-rad överst.

## Statusordbok

| Status | Betyder | Får uppfylla ett godkännandekriterium? |
|---|---|---|
| `passed` | kontrollen kördes och godkändes | ja |
| `failed` | kontrollen kördes och fällde | nej |
| `blocked` (kördes mot en artefakt en fallerad producent inte kunde skriva om — uppfyller aldrig ett kriterium) · `not run` | kontrollen kördes inte | **nej — aldrig** |
| `not applicable` | kontrollen kan inte gälla i detta läge; motivering och ägare obligatoriska | ja |

`not applicable` får aldrig användas för något som bara ännu inte körts.

## Fas 0-artefakter

| Fil | Innehåll |
|---|---|
| `fas0/baseline-report-SUPERSEDED.json` | **superseded** sandlådebaslinje — behålls som spår, är inte normativ |
| `fas0/kontrollstatus.md` (i paketet) | genererad av `tools/gen-report.mjs` ur samma rapport — finns inte i ZIP-roten |
| `fas0/blockerar-fas1.md` | kvarvarande Fas 0-arbete och vad som faktiskt blockerar Fas 1 |
| `fas0/andrade-filer.md` | ändrade filer med fullständig SHA-256 |
| `fas0/run-verify.sh` | officiell körning från ren kopia, skriver rå logg |
| `.github/workflows/verify.yml` | CI-koppling i paketet |

## Rättade verktyg

| Fil | Ändring |
|---|---|
| `tools/lint-core.mjs` | T-11 och T-12 aggregerar hela dokumentträdet · global id-kontroll som **T-16** (hette T-09b provisoriskt) · T-14, T-15 och T-17 implementerade · A11Y-01 och A11Y-02 som verkliga kontroller · körbevis per kontroll |
| `tools/verify.mjs` | `lint-controls` är ett steg i kedjan · alla steg körs · tre skilda mätklasser · körbevis avgör status · in/out-hashar · skriver rapport och Markdown |
| `tools/screen-files.mjs` | **ny** — kanonisk fillista som gen-counts, gen-icons, lint-core och lint-controls delar |
| `tools/controls.mjs` | **ny** — kanoniskt kontrollregister |

## Regel för frysta filer

En fryst fil får inte samtidigt vara enda källa till ett levande beslut. Kontrollen är gjord: båda de filer som tidigare bar den rollen har fått sina beslut migrerade till `beslutslogg.md` (B-44, B-45, B-47, B-48). Skulle en fryst fil visa sig bära ett levande beslut ska den **återaktiveras** tills beslutet migrerats — inte frysas med en fotnot.

## Rapportkatalog

Reporoten är paketet. Rapportkatalogen är dess `fas0/` — det finns ingen andra rot sedan Fas 0.5. Körningen skriver `verify.log`, `verify-report.json` och `kontrollstatus.md` dit. ZIP-roten bär bara en pekare; hela reporoten ligger i paketet.

## Kontrollregister

Kontrollernas id, namn, ägare, statiska statusar och motiveringar bor i `tools/controls.mjs` och renderas till både `verify-report.json` och `kontrollstatus.md`. Skriv inga kontrollrader för hand någon annanstans.
