# Block 287 — remedieringsunderlaget

Den här sidan säger vad som gäller, hur man kör om det och vad man aldrig ska
köra. Den förutsätter ingen chatthistorik och inga tillfälliga arbetsmappar.

**PRODUKTSKRIVNINGSGRINDEN ÄR STÄNGD.** Ingen produktremediering får utföras
förrän en separat, uttrycklig auktorisation finns. Block 287 producerar
*underlaget* för skrivningen, inte skrivningen.

---

## Vad Block 287 är

Block 287 är remedieringspopulationen för designsystemet: varje krav som måste
åtgärdas i ritningen, vem som äger kravet, och exakt var i källan ändringen ska
skrivas. Den bygger på blocken 282–286 (flödestillstånd, tillämplighet,
rollvokabulär, roll-tillstånd, tokeniserad tillståndsmodell), som står frysta
och inte ändras av Block 287.

Tre identiteter hålls isär och ingen får ersätta någon annan:

| Identitet | Svarar på | Exempel |
|---|---|---|
| `REQUIREMENT_ID` | vad som ska åtgärdas | `RP::ROLE_AND_NAME::laga::namn::portioner` |
| `WRITE_OWNER_ID` | vem som äger skrivningen | `EL::del 1 recept och veckomeny::occ::occ-xxxxxxxxxxxx` |
| `TARGET_SOURCE_KEY` | var deklarationen fysiskt står | `…::occ::occ-xxxxxxxxxxxx::del::ikon-star` |

En ägare kan äga flera fysiska mål. Ett fysiskt mål kan bära flera krav — då
listar raden varje ändring för sig i `CHANGES[]`, med sitt eget krav och sin
egen facett. Ingenting slås ihop tyst.

---

## Kanonisk frysning

**Artefakt:** `fas2/block287k-frysning.json` — manifestet, med `STATUS: "FROZEN"`
och hela bindningen under `BINDNING`.

**Vilken commit som bär den:** den senaste commit som rör
`fas2/block287k-frysning.json` och vars manifest har `STATUS: "FROZEN"`:

```
git log -1 --format=%H -- fas2/block287k-frysning.json
```

Manifestet innehåller medvetet **inte** hashen för den commit som innehåller det
självt — en fil kan inte bära sin egen commit-hash. Fältet
`BASLINJE.GENERATED_FROM_COMMIT` anger det källhuvud frysningen byggdes **ur**.

**Frysningens artefakter:**

```
fas2/block287k-frysning.json        manifest och bindning
fas2/block287k-population.json      alla enheter
fas2/block287k-skrivplan.json       en rad per fysisk skrivning
fas2/block287k-gruppexpansion.json  varje krav till exakta källelement
fas2/block287k-ankarkarta.json      de semantiska ankarna
fas2/block287k-avgoranden.json      klassningen per förekomst
fas2/block287k-fyndstangning.json   M1 och M5 mot faktiska artefakter
fas2/block287k-m2.json              M2-regressionen
```

Prefixet `block287k-` betyder *korrigerad*. Filer utan `k` är historiska.

---

## Tre identitetsnivåer

Underlaget håller isär tre saker som ofta blandas ihop:

| Nivå | Vad det är | Var det står |
|---|---|---|
| `REQUIREMENT_ID` | vad som ska vara sant | enhetens `id` i populationen |
| `WRITE_OWNER_ID` | vilket semantiskt objekt kravet hör till | skrivplanens ägarnyckel |
| `TARGET_SOURCE_KEY` | vilket fysiskt element som ska ändras | skrivplanens målnyckel |

I källan finns två skilda attribut, och de får aldrig förväxlas:

* `data-occurrence` — det **semantiska ankaret**. Ogenomskinligt, `occ-` plus
  tolv bokstäver. Det pekar ut ett semantiskt objekt. Ett element som bär ett
  eget ankare identifieras alltid av det, aldrig av mönster eller namn.
* `data-part-occurrence` — en **fysisk delnyckel**. Den namnger delens
  strukturella roll inuti ägaren, till exempel radens värdefält. Den skapar
  eller ersätter aldrig en semantisk ägare, och den får aldrig vara synlig text,
  valt värde, index, radnummer, geometri, färg eller tillstånd.

Ett valt värde är alltid **tillstånd**, aldrig identitet. Raden äger kravet på
roll och namn; värdefältet äger kravet på det aktuella värdet.

---

## Reproduktion

Ett anrop bygger hela kedjan från noll ur repot:

```
node tools/block287/kedja.mjs --root=<repotrot> --ut=<byggkatalog>
```

* Byggkatalogen måste ligga **utanför** repot och får inte heller dela
  namnprefix med det (`/x/foo` och `/x/foo-bygg` är olika kataloger, men
  jämförelsen sker på katalogsgräns).
* Kedjan renderar i huvudlöst Chrome. Den tar några minuter.
* Ingen sparad ögonblicksbild får återanvändas. Ett cachat baslinjebygge har
  tidigare dolt riktiga fel; `kedja.mjs` räknar alltid om.

Determinism prövas med omvänd filordning:

```
node tools/block287/kedja.mjs --root=<rot> --ut=<A>
node tools/block287/kedja.mjs --root=<rot> --ut=<B> --filordning=fallande
node tools/block287/reproprov.mjs --a=<A> --b=<B> --root=<rot>
```

Kravet är `BYTE_IDENTICAL YES` och noll skiljande bindningsnycklar.

Skapa en ny frysning:

```
node tools/block287/slutfrysning.mjs --root=<rot> --bygge=<A>
```

Den vägrar skriva om någon grind är skild från noll.

---

## Validering

```
node tools/block287/frysvalidator.mjs --root=<rot> --bygge=<A> \
  --manifest=fas2/block287k-frysning.json
```

Validatorn räknar om varje hash ur källan och artefakterna. Den kräver **exakt**
den kanoniska nyckelmängden: en saknad nyckel, en okänd extranyckel, fel form
eller noll jämförda nycklar ger FAIL. En tom jämförelse är aldrig ett
godkännande.

Det aktiva Block 287-provet:

```
node tools/block287/frysningsprov.mjs --root=<rot> --bygge=<A>
```

Övriga prov, alla körbara ur repot:

| Prov | Vad |
|---|---|
| `tools/semantic-owner-identity-fixtures.mjs` | identitetsmetoden |
| `tools/block287/identitetsmutationer.mjs` | skrivnyckeln, W01–W15 |
| `tools/block287/malnyckelprov.mjs` | målnyckeln, TK-01–TK-12 |
| `tools/block287/baslinjeprov.mjs` | baslinjens medlemsmängder, BV |
| `tools/block287/m2prov.mjs` | ett krav får aldrig vara sitt eget bevis |
| `tools/block287/frysvalidatorprov.mjs` | FV-01–FV-10 |
| `tools/block287/frysvalidatorcli-prov.mjs` | CLI-FV, den ingång man faktiskt kör |
| `tools/block287/gruppexpansionsprov.mjs` | GE, faller stängt på saknad indata |
| `tools/block287/namnmutationsprov.mjs` | ingen ägare byter identitet av en namnändring |

---

## Historiska filer — kör inte dessa som om de vore aktuella

| Fil | Status |
|---|---|
| `fas2/block287-frysning.json` | **OGILTIGFÖRKLARAD.** Bygger på den gamla positionsidentiteten (`EL::fil#tplN`) och ett kandidatträd som aldrig fanns i git. |
| `fas2/block287-population.json` | historisk. Läses fortfarande av `fyndstangning.mjs` som evidens för M5:s historiska relation 33 / 4 / 39. |
| `fas2/block287-skrivledger.json` | historisk. Samma skäl: den bär talet 39. |
| `fas2/block287-avgoranden.json` | historisk indata till `block287-censusomprovning.mjs`. |
| `fas2/arkiv/utkast-runda4/` | utkast från en tidigare runda, självmärkt `NOT_FROZEN`. Läses av ingenting. |
| `tools/block287-HISTORISK-frysningsprov.mjs` | provar den ogiltiga frysningen. Kräver flaggan `--historisk` och säger ingenting om nuläget. |

De historiska filerna raderas inte, eftersom den nuvarande fyndstängningen
citerar dem som evidens. De får däremot aldrig behandlas som en aktuell
skrivplan.

---

## Vad enheterna betyder

`fas2/block287k-population.json` innehåller alla enheter. Den som ska
implementera bryr sig om `CATEGORY`:

| Kategori | Betydelse |
|---|---|
| `PRODUCT_REMEDIATION_REQUIRED` | ska skrivas i ritningen |
| `SPEC_SYNC_REQUIRED` / `LINT_SYNC_REQUIRED` | förutsättning i spec eller lint, ingen ritningsändring |
| `DOWNSTREAM_APP_IMPLEMENTATION_REQUIREMENTS` | appen avgör, inte ritningen |
| `ALREADY_SATISFIED` / `NOT_REQUIRED` / `UNSPECIFIED_NO_ACTION` | ingen åtgärd |
| `HISTORICAL_OR_SUPERSEDED` | ersatt av senare metod |

Produktremedieringarna delar sig i tre:

* **med exakt källmål** — finns i skrivplanens `rader`, redo att skrivas
* **`NEW_FRAME_REQUIRED`** — vytillståndet finns inte i ritningen än. Står i
  `NYA_RAMAR`. Inget källmål får hittas på för dem.
* **terminala utanför produktomfånget** — förklaringstext eller demoramar.
  Står i `TERMINALA` med sin grund.

Varje rad i `rader` har `CHANGES[]`, där varje post bär `REQUIREMENT_ID`,
`FACET`, `CURRENT_VALUE` och `REQUIRED_VALUE`. Facetten säger vad som ska
skrivas. Saknas den faller skrivplansbygget stängt.

---

## Vad man aldrig ska göra

* Bygga med en sparad `bas.json` eller annan cachad ögonblicksbild.
* Behandla `fas2/block287-frysning.json` eller `fas2/arkiv/` som aktuella.
* Köra `tools/block287-HISTORISK-frysningsprov.mjs` och tolka grönt som att
  nuläget är i ordning.
* Härleda identitet ur position, radnummer, `data-dc-tpl`, synlig text, färg,
  geometri, värde, tillstånd eller dagens verdikt.
* Låta ett kvarliggande krav bevisa att ett element är en kontroll. Ordningen är
  alltid: källbevis → semantisk klass → krav.
* Skriva i produktkällan innan produktskrivningsgrinden öppnats.
* Kopiera skrivplanen rakt in i applikationsrepot `C:Butleryutlery`. Det är
  ett separat repo med egen historik. Underlaget här är ritningens, inte appens.

---

## Nuvarande status

Alla tolv granskningsfynd (F1, F2, M1–M7, L2, L3, L5) är stängda och verifierade
av en oberoende slutgranskning, liksom slutgranskningens egna fynd A-01–A-07.

Den efterträdande frysningen är den aktuella. Den har reproducerats ur en ren
utcheckning av sin egen commit: artefakterna blir byteidentiska och manifestets
samtliga fält återskapas, utom `BASLINJE.GENERATED_FROM_COMMIT`, som per
konstruktion pekar på det källhuvud frysningen byggdes ur. Kedjan reproducerar
sig också byteidentiskt med omvänd filordning. Företrädarens manifest validerar
inte längre som aktuellt.

Ritningens underlag är alltså klart. Applikationen är det inte: `C:Butleryutlery`
är ett separat repo som ännu inte är granskat mot den här frysningen.

Nästa steg är en läsande granskning tvärs de två repona, följd av en separat
auktoriserad produktskrivningsplan. Fram till dess:
**PRODUKTSKRIVNINGSGRINDEN ÄR STÄNGD.**
