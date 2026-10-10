# Butlery · Korsgranskning av hela specen

Version 1.0 · 2026-07-29. **Granskningen gäller dokumenten mot varandra**, inte designen mot sig själv — den senare täcks av verify-kedjan och kontrastmätningen i `evidensmatris.md`. Frågan här är den enda som ett dokumentpaket kan misslyckas med i tysthet: **påstår filerna samma saker om varandra?**

Metod: maskinell. Varje ram-id samlades ur de tio skärmfilerna; varje referens till ett id, en fil och en version i tolv dokument kontrollerades mot den mängden. Ingen bedömning, bara matchning.

---

## Utfall

| Kontroll | Före | Efter |
|---|---|---|
| Ram-id refererade i dokument som inte finns | **11** | 0 |
| Interna `#`-länkar som pekar utanför sin fil | **4** | 0 |
| Filreferenser till dokument som inte finns | 0 | 0 |
| Versionstabellen mot filernas egna `version` | **3 fel** | 0 |
| Arbetsplanens totalsumma mot faktiskt antal ramar | **fel (243/245)** | 0 |

---

## Vad som var fel — och varför det är samma fel varje gång

### 1 · Elva döda ramreferenser

Fem id:n citerades i evidensmatrisen, produktreglerna, testmatrisen och flödesdokumentet **utan att någon ram bar dem**: `#receptdetalj320`, `#veckoingamatch`, `#veckolangvantan`, `#veckopartiellt`, `#veckomeny`. Fyra av dem ser ut som ramar som fanns tidigt och döptes om; en (`#veckomeny`) är sannolikt aldrig ritad utan bara antagen.

**Konsekvensen är precis den som statusordboken finns för att förhindra:** ett krav vars `Skärmbevis`-kolumn pekar på en ram som inte finns läser som *bevisat* men är obevisat. Kolumnen är hela mekanismen bakom `implementerad`, och den var trasig på fem ställen.

Rättade till de ramar som faktiskt bär innehållet: `#lagastaende320`, `#veckofel`, `#veckogenererar`, `#veckoresultat`, `#veckokalender`.

### 2 · Fyra länkar som pekade in i tomma luften

Efter att skärmfilen delades i tio bär varje fil bara sina egna ankare — men fyra `href="#…"` i del 2, del 3 och del 4 pekade på ramar som ligger i **andra** filer. En sådan länk gör ingenting alls när man klickar. Omskrivna till filreferenser (`…del 4 …dc.html#betygvemat`).

Det här är en direkt följd av delningen 2026-07-26 och borde ha fångats då. Ingen kontroll fanns som kunde se det förrän nu.

### 3 · Tre versionsmotsägelser

Indexet påstod **Ikoner 1.4** medan `icons.json` sa 1.5, och **Produktregler 1.12** medan filen sa 1.11. `icons.json` hade dessutom inget uppdaterat `version`-fält trots att `usages` regenererats ett dussin gånger under sessionen.

Det är exakt vad **T-10** finns för att fälla — och testet mätte bara tokens, inte de övriga filerna. Kontrollen är nu utökad i granskningsskriptet, men **T-10 i `spec-lint.mjs` bör mäta samtliga rader i versionstabellen**, inte tre av dem. Det är ett kvarstående kodarbete och står som nytt krav.

### 4 · Arbetsplanens summa

Planen sa 243 ramar; filerna innehöll 245. Två ramar (`#betygvemarket`, `#familjmedlemsamtycke`) ritades efter att planen uppdaterades och summan skrevs för hand.

---

## Förbättringspotential som *inte* är fel

Sådant som fungerar men bär risk. Ingen av dem är åtgärdad här; de kräver beslut eller kod.

| Observation | Varför det spelar roll |
|---|---|
| **T-10 mäter tre av tolv versionsrader** | Motsägelserna ovan låg utanför testets räckvidd. Ett index som validerar en tredjedel av sig själv ger falsk trygghet. |
| **Ram-id är handvalda** | Sju kollisioner uppstod under en session (`skafferi`, `notiser`, `statistik` …). Ett prefix per fil, eller en lint som fäller dubbletter *innan* filen sparas, tar bort hela felklassen. |
| **`Skärmbevis`-kolumnen valideras inte** | Den bär statusen `implementerad`. Att den kan peka på en ram som inte finns är den allvarligaste tysta bristen i hela kedjan — och den upptäcktes först nu. **Bör bli ett CI-test.** |
| **Räkningar skrivs på tre ställen** | Innehållsförteckningen, arbetsplanen och indexets ankare. Två av tre gled under sessionen. Ankaret genereras; de andra två borde också göra det. |
| **Tio filer, ingen navigering mellan dem** | Varje skärmfil länkar tillbaka till innehållsförteckningen men inte till syskonen. En läsare som följer ett krav mellan två etapper får gå via mitten. |
| **`grundgranskning.md` beskriver ett läge som inte finns kvar** | Dess tre öppna punkter är avgjorda (B-36…B-38, B-40, B-41). Filen bör märkas historisk, inte gällande. |

---

## Vad granskningen *inte* täcker

Designens innehåll. Om en ram är rätt ritad, om copyn är begriplig, om ett flöde håller — det avgörs av verifieringsprotokollet på enhet och av användare, inte av matchning mellan filer. Den här granskningen kan bara svara på om dokumenten är eniga.

**De är det nu.** Det var de inte för en halvtimme sedan, och skillnaden syntes inte för ett mänskligt öga i något av dokumenten.

---

## Tillägg efter djupgranskningen (2026-07-30)

Fem krav på verifieringskedjan, alla med samma orsak: **en regel utan mätning är en önskan.**

1. **Kontrast mäts renderat, aldrig textuellt.** Bakgrunden ärvs genom trädet; en sökning kan hitta kandidater, bara DOM kan avgöra. Under granskningen skrev tre välmenande textuella svep fel ton på rätt ställe — värst blev mörkt läge oläsbart på 2,15:1.
2. **Tabulära siffror kontrolleras maskinellt.** Regeln har stått i `tokens.json` sedan 1.0 och 143 tal hade drivit bort från den, jämnt över alla etapper.
3. **Okända ikonnamn är ett hårt fel**, inte en räkning. `gen-icons.mjs` tigde om 28 påhittade namn i etapp 9–11.
4. **Radier och opacitet mäts mot skalan**, inklusive `font`- och `border-radius`-shorthand. Mikrotexten i `font:700 9px` gick igenom två pass innan den upptäcktes.
5. **Träffytor mäts renderat med hitbox-deklarationen inräknad.** Kryssrutor och reglage renderar 24–28 px; utan `data-hit` i markupen är regeln bruten i koden även när dokumentationen har rätt.
