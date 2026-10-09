> **FRYST 2026-07-31 · historisk — sluttalen motbevisade av fas0/baseline-report.json.** Underhålls inte. Får inte citeras som gällande. Se `fas0/kallauktoritetsregister.md`.

# Butlery · Djupgranskning v12

Version 1.0 · 2026-07-29. Maskinell granskning av **alla 15 skärmfiler** (320 ramar) mot `tokens.json`, `icons.json` och manualen, följd av rättning. Metod: egen mätning i skript (färger, kontrast, radier, opacitet, ikonnamn, träffytor, siffersättning, ankare, ram-id) plus renderad DOM-mätning i webbläsaren där bakgrunden måste lösas på riktigt.

## Vad som mättes och vad som hittades

| Kategori | Fynd | Utfall |
|---|---|---|
| **Ikonnamn utanför inventeringen** | 28 unika namn i etapp 9–11 | **13 döptes om** till befintliga glyfer, **14 nya glyfer** infördes i `icons.json` (1.5 → **1.6**, 59 → 73 ui-glyfer). `minus` och `arrow-right` var verkliga hål: `plus` och `arrow-left` fanns, motparterna inte |
| **Odeklarerade färger** | 9 unika, 122 förekomster | **4 nya semantiska ytor** (`surface.tint.warning/accent/success/danger`) + `border.onInk` i tokens **1.8**, med sju nya kontrastpar. **4 konsoliderades** bort: `#4A5D45`→`#4A5C50`, `#E8B06A`→`#DCA968`, `#B9C6B6`→`#A9B2A0`, och tintdubbletten `#F4E8D4`→`#F0EEE2` |
| **Renderad kontrast** | 6 par under golvet i etapp 11 | `#788477` (text.disabled.onRaised) användes som brödtext — rättat till `#5B6959`. Ett inline-par rättat i etapp 9 |
| **Opacitet utanför skalan** | 8 verkliga (0,45 · 0,55 · 0,7 · 0,75) | Alla ersatta med **deklarerade toner**. De kvarvarande 0,5/0,32 ligger i `@keyframes` och är nu ett skrivet undantag: **rörelse är inte tillstånd** |
| **Radier utanför skalan** | 14 px (5), 16 px (1), 1 px (2) | 14 → 20 (dokumentram), 16 → 12 (kort), 1 → 2 (knob). Dokumentramens 20 är nu deklarerad i `docOnly` |
| **Träffytor** | 13 under 44 px | Kryssrutans hitbox **deklareras i markupen** (`data-hit="48"`, tokens.controls.checkbox), *Ta*-knappen fick `min-width: 48`, inline-timerchippen fick deklarerad 44 |
| **Siffersättning** | 143 tal utan tabulära siffror | Alla mängder, tider och antal är nu `tabular-nums` enligt `typography.numerals` — **den enskilt största bristen**, och den fanns i tio av filerna |
| **Mikrotext under golvet** | 46 st på 9 px (~font-size~) + **28 i font-shorthand och 10 px** som första sökningen missade | Allt höjt: **10,5 px** för överline, **11 px** för kalendercellens text enligt ~typography.roles~. Avatarinitialerna i närvaroraden bröt mot sin egen token (~labelSize: 10.5~, B-40/41) — de låg i ~font:700 9px~-shorthand, som regexen inte såg. **Granskningsskriptet läser nu shorthand.** |
| **Versal knapptext** | 1 (*ÄNDRA*) | → *Ändra*. Knappar är gemena |
| Ellips i knappar | 0 | `text-overflow` förekommer bara i listrader, aldrig i knappar |
| Dubbla ram-id | 0 | 320 unika |
| Döda ankarlänkar | 0 | — |
| Tillgänglighetsnamn | 0 saknade | Varje `data-a11y-role` har ett namn |
| Emoji i systemtext | 0 | De 14 träffarna är **användarinnehåll** (kommentarer, chattmeddelanden) eller reaktionsväljaren — tillåtet enligt den omskrivna regeln |
| Utropstecken | 4 | Alla i **citerade användarkommentarer**. Regeln gäller systemtext, och där finns inga |

## Tre systemiska orsaker

**1 · Tabulära siffror var aldrig maskinellt kontrollerade.** Regeln stod i `tokens.json` sedan 1.0, men ingen kontroll läste den — därför drev 143 tal bort från den, jämnt över alla etapper. Det är samma klass av fel som `.onRaised`-varianten en gång var: en regel utan mätning är en önskan.

**2 · Nya ritningar uppfinner ikonnamn.** Etapp 9–11 lade 28 namn som inte fanns. Inget av dem var slarv i sak — de pekade på riktiga glyfer som saknades (minus, klocka-klar, tysta, flytta) — men de skrevs som om inventeringen inte fanns. `gen-icons.mjs` räknar användningar men **stoppar inte okända namn**; det är därför de kunde ligga kvar.

**3 · Tintytorna växte utanför paletten.** Fyra statustintar och en linjeton användes i ritningarna utan att finnas i `tokens.json` — och en av dem hade dessutom **två snarlika värden** för samma betydelse. Nu deklarerade och mätta.

## Kvar att göra i verktygen

- `lint-core.mjs` behöver tre nya kontroller: **tabulära siffror**, **okända ikonnamn** (hårt fel, inte bara räkning) och **radier utanför skalan**.
- `gen-icons.mjs` ska falla på okänt namn i stället för att tiga.
- Kontrastkontrollen bör köras **renderat** i CI, inte bara mot deklarerade par — de sex felen i etapp 11 syntes bara i DOM.

---

## Omgång 2 · renderad mätning per fil

Version 1.1 · 2026-07-30. Den textuella mätningen från omgång 1 visade sig **oförmögen** att avgöra kontrast: bakgrunden ärvs genom trädet, och en textuell parser kan varken lösa arv eller hitta delträdens gränser i de här filerna. Omgång 2 mätte därför **renderat i DOM**, en fil i taget, med bakgrunden upplöst genom förälderkedjan.

### Vad det kostade att lära sig

Den textuella metoden införde **en regression som gjorde mörkt läge oläsbart**: den antog papper där ytan var ink, dömde mörkt läges korrekta toner som underkända och skrev ljusa lägets toner i deras ställe — 143 ändringar i elva filer, varav 33 element i del 4 hamnade på 2,15:1. Rättat genom att återställa de deklarerade tonerna per ram (78 ramar i fjorton filer), och därefter genom att **mäta varje fil renderat**.

### Fynd och rättelser, omgång 2

| Fil | Fynd | Rättat |
|---|---|---|
| del 1 recept och veckomeny | 11 kontrastpar (ink på ink i startskärm och mängdkolumn, sage på papper) | mängdkolumnen bär papper i mörk telefon, ink i ljus · 13 sage-toner → `#5B6959` |
| del 2 familj och socialt | 16 par — **mörka delytor inuti ljusa ramar** (bottennav, skafferipanel) hade fått ljusa lägets toner | 22 mörka delträd återställda |
| del 3 sok och skalbevis | 25 par, alla sage på papper i tabellhuvuden och chips | 25 ersättningar via DOM-mätta stilsträngar |
| del 4 mörkt läge | 33 + 8 par | tonerna återställda; mängdkolumn och två stilar rättade |
| etapp 2 | 1 klippning (7 px) + 28 sage | ramhöjd 700 → 712 · toner rättade |
| etapp 3 onboarding | 6 par | avstängda etiketter behölls (golv 3), accent → `#8A5212` |
| etapp 5-7 | 1 klippning (79 px) | ramhöjd 860 → 944 |
| etapp 6 | 1 par (ram-id-brickan) | `.sc-id` bär nu ink i alla filer |
| etapp 9 globala | 16 par + 2 klippningar | ärvda toner i delträd · ramhöjder 660 → 696 och 720 → 764 |
| etapp 9 socialt | 4 par + 1 **egen regression** (`#E8B06A` användes som yta) + 3 klippningar + 2 träffytor | ytan → `#2F4437` · tre ramhöjder · två kontroller till 48 px |
| etapp 10 | 1 par | `.sc-cap` → `#5B6959` |
| etapp 11 | 21 par — accenten `#DCA968` (mörkt läge) i **ljusa** ramar | 14 rättade per ram |
| innehållsfilen | 0 | — |

### Slutläge

**Alla femton skärmfiler mäter noll** i renderad kontrast, noll träffytor under 44 px utan deklarerad hitbox, noll mikrotext under 10,5 px och noll klippning. De kvarstående överlappen i del 3, del 4 och etapp 9 är avsiktlig lagring: öppna menyer och annoteringsetiketter, bekräftade med `position`, opak bakgrund och mätning av att ingen text hamnar utanför.

### Regel som följer av detta

**Kontrast mäts renderat, aldrig textuellt.** En sökning kan hitta *kandidater*; bara DOM kan avgöra. Skrivs in i `korsgranskning.md` som krav på verifieringskedjan: `lint-core.mjs` ska köra kontrastmätningen i en riktig renderare, annars är kontrollen en förhoppning.

**Och en andra:** en global ton-ersättning måste veta vilken yta elementet faktiskt står på. Tre gånger under den här granskningen skrev ett välmenande svep fel ton på rätt ställe. Ljusa och mörka toner är inte utbytbara, och deras skillnad är inte synlig i filens text.

---

## Omgång 3 · okulär granskning — systemkonsekvens, dokument, innehåll

Version 1.2 · 2026-07-30. Omgång 1 och 2 mätte **värden**. Omgång 3 jämförde **former** mellan etapper, kontrollerade dokumenten mot verkligheten och läste copyn. Fynden här kunde inget skript hitta, för inget av dem bryter mot en regel som fanns — de **saknade** en regel.

### Systemkonsekvens

| Fynd | Utfall |
|---|---|
| **Offlinebanderollen hade två former.** Nio förekomster i fem filer bar `surface.raised` med `wifi-off` i `#8A5212`; etapp 11 bar ink med papper. | Etapp 11:s tre konverterade. **Ink läser som larm, och hela vår offlinehållning är motsatsen** — man ska kunna fortsätta planera. Krav **Y-09** |
| **Tomlägesglyfen varierade: 34 · 36 · 38 · 40 · 64 · 80 px.** Mönstret visade sig vara *dubbla rubrikgraden* i fyra av fem fall — men `#soctomt` hade 40 **och** 36 för samma rubrikgrad, i samma ram. | Skalan deklarerad i `tokens.json` (`emptyStateGlyph`) och § 20.16: **2× rubrikgraden i vyn, fast 64 i helskärmsavbrott**, streck 1,4. Fyra glyfer normaliserade. Krav **Y-08** |
| **Knappordningen i bekräftelser var jämnt delad: 9 mot 9.** Ingen regel fanns. | Regeln formulerad i **betydelse, inte i ordet *Avbryt***: reträtten vänster, följden höger. Sju handlingsrader vända. Undantaget `#impassistavbryt` förblir rätt — där *är* avbrottet följden. § 20.17, krav **Y-07** |
| **Länkfärgen `#A15A0A` klarade papper (4,53) men föll på upphöjd yta (4,30)** — och en korsreferens i löptext kan inte garantera vilken yta den hamnar på. | Baslänkfärgen är nu `#8A5212` i alla femton filer: 5,90 på papper, 5,20 på upphöjd, godkänd på alla fyra statustintar. `text.link` deklarerad, tokens **1.9** |

### Dokument mot verklighet

- **`00-spec-index.md` räknade tio delfiler och 245 ramar** när det är fjorton och **320**. Tokens stod på 1.7, ikoner på 1.5. Allt rättat.
- **Krav-id kolliderade:** `K-01…K-06` betydde både *kontrast och kvalitet* och *kontoradering* — sex id med två innebörder. Konto-familjen är nu **`KR-`**, med en namnrymdsnot i matrisen. Löptextens `K-0x` avser alltid kontrast.
- Två testräkningar var inaktuella (ikonnamn 64 → 73; kontrastparen ersatta av *mätt i DOM per fil*).
- Kontrollerat rent: **418 kravrader pekar alla på ramar som finns**, `gen-counts.mjs` läser alla fjorton skärmfiler (innehållsfilen har noll ramar och är korrekt utesluten).

### Innehåll

- **`Dela med familjen` → `Dela med hushållet`.** Reglerna använder *hushåll* konsekvent på 42 ställen; detta var den enda avvikelsen i UI-copy. **Hushållet är entiteten** — medlemmar, roller, allergiunion; *familj* är en av flera sorters hushåll och utesluter de andra. § 20.18, krav **Y-10**
- Rösten mäter rent: ingen versal knapptext, ingen engelska, inget *ni*, ingen punkt i etiketter. De fyra träffarna var korrekta — citerade receptrader som slutar i punkt, svenska *filter*, och juridikens *vi* om företaget.

### Slutläge efter tre omgångar

**320 ramar, femton filer, noll fynd i varje mätbar kategori** — odeklarerade färger, ikonnamn, opacitet, radier, tabulära siffror, mikrotext, dubbla ram-id, döda ankare, renderad kontrast, träffytor, klippning.

Och en observation värd mer än siffrorna: **de tre omgångarna hittade tre olika sorters fel.** Omgång 1 hittade värden som drivit från sin regel. Omgång 2 hittade regler som inte gick att mäta som vi trodde. Omgång 3 hittade **former som aldrig fått en regel** — och de var de svåraste, för ingenting var trasigt. Knappordningen stod 9 mot 9 i fyra år utan att någon kontroll kunde ha larmat, eftersom ingen hade sagt vad som var rätt.
