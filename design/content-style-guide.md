# Butlery · Svensk content style guide

Normativ för all text i produkten. Vid konflikt med skärmfilen gäller den här filen — skärmen rättas.
Version **1.1** · 2026-07-26 · komplement till manual V6 kap 03.
Alla regler nedan har antingen ett exempel eller ett uttryckligt undantag. En regel utan undantag som skärmarna bryter mot är ett fel i den här filen, inte i skärmen.

---

## Röst

Butlery är en lugn, kunnig hjälp i köket. Skriver kort, konkret och utan pekpinnar.

- **Du** till användaren. **Undantag:** i hushållsdelade flöden tilltalas hushållet som **ni** ("Något ni undviker?", "Vad tyckte ni?") — plural syftar då på personerna i hushållet, aldrig på användaren ensam. "Man" används aldrig.
- **"Vi" är tillåtet** som Butlerys kollektiva tjänsteröst i systemsvar om vad tjänsten gjort eller inte kunde göra: "Vi hittade tre rätter", "Vi kunde inte läsa länken". Aldrig "vi" i beröm, marknadston eller om användarens egna handlingar. (Beslutet ersätter V1.0-regeln "aldrig vi utom juridiskt", som skärmarna aldrig följde.)
- Aktiv form: "Vi hittade tre rätter" — inte "tre rätter hittades".
- Inga utropstecken. Ingen humor på användarens bekostnad. **Inga emoji i systemtext** — inte i knappar, rubriker, tomma lägen, notiser, etiketter eller ikoner (det utesluter `📊` i omröstningsbubblan).
- **Användarens innehåll är fritt.** Meddelanden, kommentarer och receptanteckningar får emoji — och **reaktioner räknas som användarens ord**, inte som vår typografi: de sex låsta reaktionerna (`thumbs_up` · `heart` · `fire` · `laughing` · `yum` · `thinking`) är tillåtna. Ingen fri emoji-väljare: sex reaktioner går att moderera, oändligt många gör det inte. Se `#socreaktion`.
- Inget "tyvärr", "hoppsan", "något gick fel". Fel beskrivs sakligt.

## Datum, veckodagar och tid

| Sammanhang | Form | Exempel |
|---|---|---|
| Veckodag, förkortad (listor, brickor) | **fast lista, ingen punkt** — svensk standardförkortning, inte mekaniskt tre tecken | `Mån Tis Ons Tors Fre Lör Sön` (`Tors` är fyra tecken och korrekt) |
| Veckodag, utskriven | gemener mitt i mening | `torsdag 9 juli` |
| Datum i löptext | dag + månad utskriven, inget år om innevarande | `9 juli` · `9 juli 2025` |
| Datum i tabell/metadata | dag + månad förkortad inte tillåten — skriv `9 juli` | |
| Vecka | `Vecka 28` med versalt V först i mening, annars `vecka 28` | `Vecka 28 · 6–12 juli` |
| Veckospann | tankstreck utan mellanslag | `6–12 juli` |
| Klockslag | 24-timmars, kolon | `19:26` |
| Tidsåtgång | siffra + `min`, aldrig `minuter` i metadata | `45 min` |
| Över en timme | `1 h 30 min`, inte `90 min` | |

**Relativa datum** — används bara för de tre senaste dygnen, därefter absolut datum:
`nu` · `5 min sedan` · `i dag 14:02` · `i går` · `9 juli`.
**`i går` skrivs i två ord.** Aldrig "igår".

## Mängder, enheter och siffror

- Alltid **mellanslag mellan siffra och enhet**: `400 g`, `3 dl`, `2 st`, `45 min`.
- Enheter förkortas utan punkt: `g` `kg` `ml` `dl` `l` `msk` `tsk` `krm` `st`.
- **Decimaltecken är komma**: `4,5` — aldrig punkt.
- Bråk skrivs ut som decimal: `0,5 dl`, inte `½ dl`.
- Tusentalsavgränsare är tunt mellanslag: `1 908`.
- Skalade mängder avrundas till närmast praktiska mått: 1,33 dl → `1,5 dl`; 0,66 st → `1 st`. Avrundning visas aldrig som "ca".
- **Tabulära siffror** (`font-variant-numeric: tabular-nums`) där siffror står i kolumn eller räknar: mängdkolumner, timers, progressantal, OTP-rutor, tabeller. **Proportionella** i löptext och i fristående datum/metadata ("torsdag 9 juli", "45 min") — det är samma regel som manual V6 kap 03. Datum blir tabulära först när de står kolumnställda.

## Singular, plural och förkortningar

| Fel | Rätt |
|---|---|
| 1 rätter | 1 rätt |
| 4 port / 4 portioner (blandat) | metadata i kort: `4 port.` · detaljvy och knappar: `4 portioner` |
| Lagat 3 ggr | Lagat 3 gånger |
| 1 varor tillagd | 1 vara tillagd |
| 0 träffar | Inga träffar |

Godkända förkortningar: `min`, `st`, `msk`, `tsk`, `dl`, `port.` (endast i kortmetadata), `nr`.
Aldrig: `ggr`, `st.`, `ca`, `t.ex.` (skriv "till exempel"), `osv`.

## Interpunktion

- **Ellips är tecknet `…`**, aldrig tre punkter. Används bara i pågående tillstånd och platshållartext: `Sparar …`, `Receptets namn …` — med mellanslag före.
- **Mellanslagsseparator i metadata är `·`** med mellanslag runt: `45 min · 4 port. · Vegetariskt`.
- Tankstreck `–` i spann och som pausmarkering. Bindestreck `-` bara i sammansättningar.
- Citattecken: `"raka citattecken används inte"` → använd `”svenska dubbla”`.
- Ingen punkt efter enstaka mening i etikett, chip, badge eller knapp. Punkt i hjälptext och flerradig brödtext.
- Versaler bara i kategorier och systemetiketter (`GRÖNT & FRUKT`, `IKVÄLL`). Aldrig versala meningar.

## Knapptexter

Knappen namnger **resultatet**, inte objektet:

| Fel | Rätt |
|---|---|
| Inköpslista | Lägg 2 varor i inköpslistan |
| OK | Stäng · Försök igen · Ångra · Öppna inställningar |
| Meny (i löptext) | Veckomeny — men **`Meny` är tillåten navigationsetikett**, där ytan är 64 px bred |
| Meny | Planera veckan |
| Spara | Spara veckan · 5 rätter |
| Ja / Nej | Behåll min vecka / Skriv över de fem dagarna |

Destruktiva knappar säger vad som försvinner: `Radera receptet`, inte `Radera`.
**Radera** = innehållet upphör att finnas (eget recept, konto, meddelande). **Ta bort** = något lyfts ur en lista eller relation men finns kvar (vara ur inköpslistan, medlem ur grupp, recept ur veckomeny). Orden är inte utbytbara.
Max 3 ord där ytan är trång, max 5 annars.

## Felmeddelandets struktur

Tre delar, alltid i den här ordningen:

1. **Vad hände** — konkret, utan skuld: "Länken kunde inte läsas."
2. **Vad bevarades** — om något står på spel: "Din text ligger kvar."
3. **Vad du kan göra** — en åtgärd som knapp: "Försök igen" · "Klistra in texten själv".

Aldrig felkoder i användartext (de hör till loggen). Aldrig "något gick fel" utan orsak.
Snackbar får aldrig ha `OK` som enda åtgärd — den ska bära en verklig handling eller `Stäng`.
Sparad-snackbaren bär alltid åtgärden `Visa receptet`. En snackbar utan möjlig följdhandling får `Stäng`.

## Radbrytning och maxlängd

| Element | Maxrader | Överskott |
|---|---|---|
| Receptnamn i kort | 2 | ellips |
| Receptnamn i detaljvy | 3 | ellips |
| Ingrediensrad | 2 | radbrytning, aldrig ellips på mängden |
| Personnamn | 1 | ellips |
| Chip / tagg | 1 | chippet växer, texten kortas aldrig |
| Snackbar | 2 | ellips |
| Brödtext | obegränsat | `text-wrap: pretty` |

Mängd och enhet får aldrig brytas isär (`white-space: nowrap`).

## Benämningar — ett ord per sak

| Begrepp | Ord | Aldrig |
|---|---|---|
| Ett sparat recept | **recept** | maträtt, dish |
| En planerad måltid i veckan | **rätt** | måltid, meal |
| En plats i en dag | **plats** (lunch · middag · kväll) | slot, lucka |
| Rad i inköpslistan | **vara** | artikel, item, produkt |
| Vad man har hemma | **skafferi** | förråd, pantry |
| Veckans plan | **veckomeny** | matsedel, plan · navigationsetiketten `Meny` är undantaget |
| Grupp av personer | **grupp** · hushållet = **familjen** | team |
| Att göra mat | **laga** | koka, tillaga |

## Tomma lägen

Tre rader, i den ordningen: rubrik som beskriver läget (inte problemet), en mening om varför det är tomt och vad som fyller det, en primär åtgärd.
Rubriken är aldrig en uppmaning: "Veckan är oplanerad", inte "Planera din vecka!".
