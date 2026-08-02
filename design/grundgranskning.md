> **FRYST 2026-07-31 · historisk — de tre öppna punkterna avgjorda (B-36…B-38, B-40, B-41).** Underhålls inte. Får inte citeras som gällande. Se `fas0/kallauktoritetsregister.md`.

> **HISTORISK · 2026-07-29.** Filens tre öppna punkter är avgjorda: rumsskalan (B-36), kryssrutan (B-37), radierna (B-38) och kalenderns två mått (B-40, B-41). Dokumentet står kvar som underlag för *varför* besluten togs — det är inte längre en lista över öppna avvikelser.

# Grundgranskning — alla ritade etapper mot manual v6 och grund v12

**Datum:** 2026-07-26 · **Granskat:** 167 ramar i sex filer, `tokens.json` 1.3, `Butlery Grafisk manual v6`, `Butlery Komponentark v1`
**Metod:** mekanisk mätning i källan och i renderad DOM (typstorlek, vikt, radie, rum, kontrollgeometri, kontrastpar, träffyta), därefter jämförelse mot manualens normativa formuleringar.

Detta är en **granskning**, inte en spec. Det som rättats står under *åtgärdat*; det som kräver ditt beslut står under *öppet*.

---

## 1 · Åtgärdat i denna vända (etapp 2 veckomeny + etapp 4 import, 39 ramar)

| Regel i manualen | Vad jag hittade | Åtgärd |
|---|---|---|
| ”Mellansteg finns inte: **13,5 och 14,5 px utgår** — tät UI är 13, brödtext 14” | 13,5 px på 40 ställen, 14,5 på 1, 15,5 på 5 | Allt till 13 / 14 / 15 |
| Typskalans roller (32 · 26 · 22 · 19 · 17 · 16 · 15 · 14 · 13 · 12,5 · 12 · 11 · 10,5) | **11,5 px** på 52 ställen — ingen roll i skalan | Till 12,5/600 (`meta`) |
| ”Aldrig 400 under 12 px” | 28 element i vikt 400 under 12 px | Vikt 600, eller 12,5 för den kursiva originalraden |
| ”10,5 px endast i vikt 700” | En platshållarruta i 10,5/400 | 10,5/700 |
| ”Flikar: **13/700** versalgemener” | Vylägesflikarna satta 12,5/700 | 13/700 (15 flikpar) |
| ”Radier: 0 · 8 · 12 · full” | **Radie 6** på 7 chips, radie 10 på 3 kort | Chips → full, kort → 12 |
| ”Avatarskala 26 / 32 / 40 / 54 / 72 **utan mellansteg**” | 21 avatarer i 18 och 22 px | Alla till 26 px |
| ”Statuspill 10,5/700 padding **3 × 9**” · ”badge padding **2 × 7**” | NY- och IDAG-pillar i 1 × 4 och 2 × 6; huvudbadgar i 3 × 8 | Rättade till 3 × 9 respektive 2 × 7 |
| ”Platshållartext är **inte** inaktiverad text — den använder text.secondary” | 9 platshållare i `text.disabled` #7D897C (3,19:1 — otillåten) | Till text.secondary #627061 |
| ”Överrader på surface.raised använder **text.secondary.onRaised**” (#627061 ger 3,96:1 på mörkt raised och underkänns) | En överrad i #627061 på raised (`#impdubblett`) | Till #5B6959 |
| ”Säkerhets-, allergi- och samtyckestext sätts 12,5–13 px i **text-primary** och får aldrig tonas ned” | Allergenupplysningen satt 12–12,5 px i `text.body` och `text.warning` | Till 12,5–13 px i #24382C; ikonen behåller varningsfärgen |

Efter rättning: **inga** storlekar utanför skalan i de 39 ramarna (uppmätt i DOM: 10,5 · 11 · 12 · 12,5 · 13 · 14 · 15 · 16 · 19 · 22), noll element i 400 under 12 px, noll nästlade kontroller, noll träffytor under 48 dp, noll klippning.

---

## 2 · ~~Öppet~~ — **avgjort 2026-07-27** (B-36 · B-37 · B-38)

> **1A** rumsskalan sex steg · **2B** kryssrutan 24 px · **3A** radie 0 och 2 som tokens. Dessutom flyttades hela kontrollgeometrin in i grunden som `tokens.controls`, och `tools/lint-controls.mjs` mäter den. Avsnitten nedan står kvar som underlaget besluten fattades på.

### 2.1 Grunden och manualen säger olika om rumsskalan

`tokens.json → space.scale` är **4 · 8 · 12 · 16 · 20 · 24 · 32 · 44 · 56**.
Manual v6 säger **4 · 8 · 12 · 16 · 24 · 32 + layoutmarginal 20**.

Alltså: **20 är en layoutmarginal i manualen men ett skalsteg i tokens**, och **44 och 56 finns bara i tokens**. Generatorn skriver ut dem som `ButlerySpace.s44` och `s56`, så de är redan kod. Antingen tas de ur tokens, eller skrivs de in i manualen. Jag har inte gissat.

### 2.2 Kryssrutan är 24 px i ramarna och 20 px i manualen

Manualen och komponentarket säger **kryssruta 20 px med radie 6**. De 14 kryssrutorna i de äldre ramarna är **24 px** (radie 6), och de nya i importflödet är 20–22. Det är en låst kontrollgeometri, så en av de två måste ändras — och ändras kryssrutan ändras varje inköpslista och varje flervalsvy.

### 2.3 Systemisk skuld i de 128 ramar som ritades före granskningen

Mätt i de fyra äldre filerna plus delade listor:

| Avvikelse | Antal | Kommentar |
|---|---|---|
| 13,5 px | **145** | Manualen säger uttryckligen att storleken utgår |
| Radie 6 (chips, småkort) | **115** | Ska vara full eller 8 |
| Radie 2 och 5 | 154 | Dekorativa staplar och pillar; radie 2 är dessutom manualens egen anatomi för saffransknoppen — behöver undantag skrivet, inte tystnad |
| Avatarer under 26 px | 16 | Mellansteg som skalan förbjuder |
| 9 och 10 px | 13 | Avatarinitialer; under 10,5 finns ingen nivå |
| 11,5 px | 15 | Ingen roll |
| 18 / 20 / 21 / 23 px | 18 | Utanför rollskalan |

Detta är **inte** rättat. Att röra 145 textstorlekar i 128 ramar utan att se resultatet i taget är hur man förstör en spec, och jag ville inte göra det i samma vända som jag ritade nytt. Det är två à tre timmars mekanik med kontroll per fil, och det bör göras som en egen etapp — förslagsvis 8.5, före kodgenereringen, eftersom generatorerna läser samma tokens.

---

## 3 · Avvikelser jag valt medvetet — med skäl

| Avvikelse | Skäl |
|---|---|
| **Placeringsfoten staplar två fullbreddsknappar** (`#veckoresultat`), fastän manualen skriver ”föredra sida-vid-sida” | Koden gör det (`MenuPlacementChoiceFooter` är en `Column`), och etiketterna ”Placera i veckan” / ”Jag placerar själv” ryms inte sida vid sida på 360 dp utan trunkering. Manualen säger också att primärtext **aldrig** trunkeras. Regeln som väger tyngst vinner |
| **Kalendercellernas 3 px vänsterkant och 2 px underkant** (`#veckokalender`) ligger utanför linjeinventariet (1 och 1,5 px) | Geometrin är kodens (`_accentedBorder` i `calendar_cells.dart`). Att rita 1 px där appen har 3 hade gjort ritningen osann. Linjeinventariet bör utökas med cellaccenten, eller koden ändras |
| **Övrigt-platsen har inget maxantal** | Modellen (`MealSlot.isMulti`) sätter inget tak. Ett tak i ritningen hade varit en påhittad regel |
| **Närvarosraden ritas 48 dp** trots att appen ritar ~24 | Manualen kräver 48 för kontroller. Avvikelsen är dokumenterad som öppet krav V-22, riktat till utvecklingsteamet |

---

## 4 · Vad granskningen bekräftade

- **Färgerna håller.** Varje hex i alla sex skärmfiler har täckning i `tokens.json` — noll uppfunna kulörer (B-28 håller).
- **Kontrollgeometrin håller** där den mäts: 602 märkta kontroller, samtliga med roll, ingen under 48 dp, noll nästling.
- **Ikonerna håller:** 58 registrerade glyfer, noll okända namn, varje glyf med master i `assets/icons/`.
- **Ingen skugga** någonstans i de 167 ramarna, i enlighet med ”noll skugga”.
- **Rörelse:** inga animationer i skärmfilerna utöver startskärmens låsta kloche — `.sc-spin{animation:none}` står kvar, så inga snurrande platshållare smugit in.

---

## 5 · Rekommenderad ordning

1. **Beslut** om 2.1 och 2.2 — de är enrads­beslut som styr allt annat.
2. **Etapp 8.5:** rensa den systemiska skulden i de 128 äldre ramarna, fil för fil med kontroll emellan.
3. Först därefter etapp 5–7, så att nya ramar inte ärver skulden.

---

## 6 · Skillnadslista — grund v12 (`tokens.json` 1.3) mot manual v6

Mekanisk jämförelse. **Färgerna stämmer i en riktning:** varje hex i manualen finns i tokens — det finns ingen kulör i manualen som grunden saknar.

### 6.1 Grunden har sju färger manualen inte visar

`#5B6959` · `#788477` · `#C9D3C4` · `#E5A08A` · `#66755C` · `#C3C6BA` · `#DFE0D6`

Det är kontrastparen för **upphöjd yta och mörkt läge** (`text.secondary.onRaised`, `text.disabled.onRaised`, `text.bodyOnDark`, `text.danger.onRaisedDark` m.fl.), tillagda i tokens 1.3 efter att mätningen visade att `text.secondary` ger 3,96:1 på `#2F4437` och underkänns. **Här vinner grunden** — motiveringen är mätt kontrast, inte smak. Manualens figurer 8–10 och 18 behöver uppdateras med de sju, annars är manualen den som ljuger.

### 6.2 Rumsskalan skiljer sig i tre steg

| | Manual v6 | tokens 1.3 |
|---|---|---|
| Skala | 4 · 8 · 12 · 16 · 24 · 32 | 4 · 8 · 12 · 16 · **20** · 24 · 32 · **44** · **56** |
| Layoutmarginal | 20 (”egen token **utanför** skalan”) · 24 vid 360–430 | `layoutMargin` 320 → 20, 360–430 → 24 |

**20 finns i båda men med olika status** (skalsteg mot layoutmarginal), och **44 och 56 finns bara i grunden**. Generatorn skriver dem redan som `ButlerySpace.s44`/`s56`. Öppet beslut (2.1) — jag har inte gissat.

### 6.3 Typografin: två roller saknar motsvarighet

| Manualens formulering | tokens 1.3 | Skillnad |
|---|---|---|
| ”**Flikar: 13/700** versalgemener” | `listItem` 13/**600** — ingen 13/700-roll | Flikrollen finns i manualen men inte i grunden. Jag har satt vylägesflikarna 13/700 enligt manualen |
| ”**Nav-etikett: 10,5**” | `navLabel` **11**/700, med noteringen ”höjd från 10,5 — kökskontext” | Grunden har medvetet höjt storleken. **Här vinner grunden** — skälet (läsavstånd i kök) är skrivet och starkare än manualens siffra. Manualen bör rättas till 11 |
| ”Aldrig 400 under 12 px” · ”10,5 endast i 700” · ”13,5 och 14,5 utgår” | Samma regler ordagrant i `typography.rules` | Överens |
| ”Säkerhets- och samtyckestext 12,5–13 i text-primary” | `meta` 12,5/600 med samma notering | Överens |
| ”Knappar 14/600 genom alla nivåer, aldrig 700” | `label` 14/600 med samma notering | Överens |

### 6.4 Radier: grunden har tre, manualen fyra

Manualen: **0** (tabeller/redaktionellt) · **8** (knappar/fält) · **12** (kort/sheets) · **full** (chips/avatarer).
tokens: `control` 8 · `card` 12 · `pill` 999. **Radie 0 saknas som token** — den finns bara som frånvaro. Det gör att ”redaktionell nolla” inte går att uttrycka i kod, och att generatorn inte kan skilja *avsiktlig* nolla från oskriven radie. Förslag: lägg `radius.sharp: 0` i tokens.

Manualens anatomi nämner dessutom **radie 2** för saffransknoppen (ordmärkets linje) — ett dokumenterat undantag som borde stå som sådant i grunden, inte upptäckas i en mätning.

### 6.5 Kontrollgeometri: manualen är detaljerad, grunden tyst

Manualen låser **kryssruta 20 px radie 6 · radio 19 · toggle 34 × 20 knopp 16 · chip 12/600 padding 7 × 13 (kompakt i fält 6 × 11) · statuspill 10,5/700 padding 3 × 9 · badge padding 2 × 7 · avatarskala 26/32/40/54/72**.

`tokens.json` innehåller **ingen** av dessa mått — bara `touchTarget.min: 48` och `minGap: 8`. Kontrollgeometrin lever alltså enbart i manualtexten och komponentarket, vilket är varför den kunde glida i ritningarna: den går inte att lint:a. **Förslag:** `tokens.controls` med de åtta måtten, och en lintregel som mäter dem i skärmfilerna. Utan det upprepas felet.

### 6.6 Rörelse: överens, men grunden har mer

Manualen beskriver uppdukningen (5 s, endast startskärm) och tempo/kurvor i figur 15. tokens har `micro` 180 · `standard` 320 · `clocheLift` 400 · `clocheReturn` 200 · `splashLoop` 5000 med kurvan `cubic-bezier(0.33,0,0.2,1)` och en `reducedMotion`-regel. Inga motsägelser — manualen namnger färre värden än grunden bär.

---

## 7 · Vad jag rättade efter skillnadslistan (manualen vinner där jag inte kan motivera annat)

| Regel | Åtgärd i de 39 nya ramarna |
|---|---|
| Skala 4/8/12/16/24/32 | **189 paddingvärden** snappade till skalan (11 → 12, 14 → 16, 22 → 24 …). Manualens låsta kontrollpaddingar undantagna: chip 7 × 13, pill 3 × 9, badge 2 × 7 |
| Kryssruta 20 px **radie 6** | 21 kryssrutor rättade från 20–22 px kvadratiska till 20 px med radie 6 |
| Chip 12/600, padding 7 × 13, full radie, grannavstånd ≥ 8 | 7 tolkningschips rättade (var 12,5/600 i 8 × 12 med gap 6) |
| Flikar 13/700 | Vylägesflikarna rättade från 12,5/700 |

Uppmätt efter rättning: noll klippning, noll träffytor under 48 dp, noll nästling, inga storlekar utanför rollskalan.

**Kvar som medveten avvikelse:** kalendercellens markeringsruta är 13 px och följer *inte* kryssrutans 20/6 — där är **hela cellen** kontrollen och rutan bara en markör, precis som i `calendar_cells.dart`. Att ge markören kryssrutans mått hade antytt en egen träffyta som inte finns.

---

## 8 · Etapp 8.5 — skulden rensad (2026-07-27)

Kontrollen (`tools/lint-controls.mjs`, replikerad i webbläsaren) räknade **555 avvikelser** i de sex skärmfilerna. Efter rensning: **0**.

| Vad | Antal | Åtgärd |
|---|---|---|
| 13,5 px | 145 | → 13 (tät UI) |
| Radie 6 på annat än kryssrutor | 115 | → 8 för brickor och tangenter; kryssrutorna till 24 px enligt B-37 |
| Avatarer utanför skalan | 40 | 18–25 → 26 · 36 → 40 · 56 → **54** (skalan har 54, inte 56) |
| Radie 1 · 3 · 4 · 5 · 10 · 24 | 84 | 1 → 0 · 3 → 2 (knob) · 4 → full · 5 → 8 · 10 → 12 · 24 → full |
| 11,5 px | 15 | → 12,5/600 |
| 9 och 10 px | 13 | → 10,5/700 |
| 18 · 20 · 21 · 23 · 24 px | 18 | → närmaste roll: 19 respektive 22 |
| 400-vikt under 12 px | 14 | → 600, och 700 vid 10,5 |

**Uppmätt efter rensning, fil för fil:** noll klippning i 167 ramar, noll träffytor under 48 dp, noll nästlade kontroller, inga storlekar utanför rollskalan, inga radier utanför tokens.

Ett fynd i mätningen värt att notera: **avatarskalan säger 54, ramarna hade 56.** Tio avatarer låg två pixlar utanför en skala som uttryckligen saknar mellansteg — precis den sorts glidning som inte syns för ögat och som är hela skälet till att geometrin nu är en token.

Linten fick också en skärpning under arbetet: den första versionen flaggade **prickar, ikoncirklar och laddindikatorer som avatarer**. En avatar känns igen på att den bär initialens textfärg och storlek — utan dem är den runda ytan något annat. 125 falska positiva blev noll.

---

## 9 · Kontrollmetoden skärpt (2026-07-27)

Granskningen av etapp 5–7 avslöjade att **min egen mätning var för ytlig**: jag jämförde `.sc-phone.scrollHeight` mot `clientHeight`, men klippningen sker i den **inre** `flex:1 … overflow:hidden`-diven. Telefonen mäter då rent medan innehållet kapas — två ramar hade förlorat innehåll utan att någon siffra visade det (`#taggregel` 21 px, `#taggvillkor` 111 px, där hela villkorsgruppen *Om posten* låg utanför ramen som etiketten beskrev).

**Rätt probe** går igenom `.sc-phone` **och alla dess barn**, och undantar avsiktlig trunkering:

```js
[...document.querySelectorAll('.sc-phone, .sc-phone *')].filter(el => {
  const s = getComputedStyle(el);
  return s.overflow === 'hidden'
      && !/^\d+$/.test(s.webkitLineClamp || '')   // tvåradsklämma är manualens regel, inte ett fel
      && el.scrollHeight > el.clientHeight + 1;
})
```

Undantaget är nödvändigt: `-webkit-line-clamp: 2` på receptnamn **är** manualens radbrytningsregel. Utan filtret flaggade proben `#langavarden` — en ram som stresstestar just den regeln — och jag hade råkat ”rätta” en avsiktlig klämma till en ram 32 px för hög innan jag insåg det.

**Alla sju skärmfiler mätta med den skärpta proben: noll klippning.** Rotorsaken i båda felen var densamma — rambudgeten sattes före innehållet, och en `flex:1`-behållare med `overflow:hidden` krymper inte, den kapar.

---

## 10 · Ikonbanorna synkade mot mastrarna (2026-07-27)

Granskningen hittade en felklass ingen räkning kunde se: **glyfer ritade ur minnet i stället för ur mastern.** `users` ritade två personer där `assets/icons/users.svg` har tre; `message-square` ritade en kantig bubbla utan punkter där mastern har en rundad med tre. Namnet stämde i båda fallen, så `gen-icons` rapporterade ”noll okända ikonnamn” medan ritningen visade en annan ikon än den inventering manualen kallar normativ.

Åtgärd, och den är strukturell snarare än en rättelse: `tools/sync-icon-paths.mjs` läser varje master i `assets/icons/` och skriver om alla inline-glyfer i dokumenten ur den. **197 av 923 glyfer** i tio dokument var glidna — inte bara i de nya ramarna, utan i sex av sju skärmfiler och i komponentarket. Öppningstaggen lämnas orörd, så storlek och stroke-bredd (2,2 för bock och kryss i täta ytor) består.

Efter körning: **0 av 923 avviker.** Glyferna kan inte glida igen utan att verktyget säger till, och en glyf utan master avbryter körningen — en ikon som inte finns som master går inte att verifiera.
