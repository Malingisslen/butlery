# Fas 0 · kvarvarande arbete
2026-08-02 · efter **Fas 0.18**. Inga körsummeringar här — de står i `fas0/verify-report.json` och `fas0/kontrollstatus.md`, som genereras av körningen.

## Rättat i Fas 0.18

| Fel | Åtgärd |
|---|---|
| Helradsjämförelsen var en hårdkodad fältlista | **äkta djupjämförelse**: JSON-rundresa för att normalisera bort `undefined`, sedan `isDeepStrictEqual` på hela raden. Extra, borttagna och ändrade fält fäller alla — inklusive `legacyId`, `scope`, `passedTests`, `skipped`, `coverage`, `integrity`, `parsed`, `verified`, `bad`, `missing`, `duplicates`, `unlisted`, `outsideAbsent`, `expected` och `mode`. Skillnaderna redovisas med fältnamn, även nästlade |
| Provet bevisade inte påståendet | åtta nya negativa M-23-fall: `legacyId`, `scope`, `passedTests`, nästlat `coverage`, nästlat `integrity`, manifestfältet `verified`, ett **extra** fält och ett **borttaget** fält |

## Kvar

| # | Uppgift | Ägare |
|---|---|---|
| 1 | **Kör kedjan på det här paketet** och låt körningen generera alla siffror. | DEV |
| 2 | **CI-01** — aktivera workflowen i det riktiga repot. Tills dess är Fas 0 **delvis klar**, inte passerad. | DEV |
| 3 | **Märk resten av komponenterna** tills `LC-COVERAGE` visar noll omärkta kandidater. Omärkta kandidater **fäller** LC-01 sedan Fas 0.5. | DS |
| 4 | **Migrera Skärmbevis till typad grammatik** och stäng de rader T-14 rapporterar utan bevis. | DS |
| 5 | **Rollvokabulären** (T-08) och **träffytorna** — antalet står i rapporten, inte här. | DS |
| 6 | **Ikonmastrarna** och **schemautökningen** — Fas 1-arbete. | DS |

## Baslinjefynd att föra vidare

Den senaste officiella körningens fynd är **baslinje, inte blockerare**: de ska föras vidare i evidensmatrisen och lösas i sin fas. Rött hindrar inte Fas 0 från att passera — falska gröna statusar gör det.
