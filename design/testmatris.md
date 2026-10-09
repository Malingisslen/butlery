# Butlery · Test- och tillståndsmatris

## Namnrymder

Prefixen är **inte** globalt unika i paketet, och det är en känd risk för både människor och verktyg. Från och med 2026-08-01 gäller:

| Namnrymd | Betyder | Var |
|---|---|---|
| `T-nn`, `LC-`, `A11Y-`, `GEN-`, `MF-`, `ST-`, `MT-`, `CI-` | **verifieringskontroll** | `tools/controls.mjs` — kanoniskt register |
| `B-nn` | **beslut** | `beslutslogg.md` |
| Tvåbokstavsprefix + nummer (`KI-`, `MR-`, `SK-`, `AU-`, `BH-`, `P-`, `Y-`, `K-`…) | **krav** | `evidensmatris.md` |
| `P0-`, `P1-` | **granskningsfynd** | `00-spec-index.md` |

**Prefixen räckte inte.** Sjutton id förekom både som kontroll och som krav — `T-01` betydde både schemakoll och träffyta, `K-01` både `dart analyze` och kontrastkrav, `R-01` både renderad kontrast och 320-dp-layout. Från Fas 0.10 gäller **disjunkta maskin-id**:

| Maskin-id | Betyder | Källa |
|---|---|---|
| `CHK-*` | verifieringskontroll (`CHK-T-14`, `CHK-LC-01`, `CHK-MF-01`…) | `tools/controls.mjs` — fältet `id` |
| `REQ-*` | krav | `evidensmatris.md` — kravtabellernas `Krav-ID`, maskinellt prefixat |

Kontrollernas `legacyId` (`T-14`, `LC-01`…) bevaras för läsbarhet i prosa och i äldre referenser, men **all automation använder `CHK-`-formen**. Delade kontroller bär suffix: `CHK-T-06a`, `CHK-T-06b`.

Version **1.1** · 2026-07-26. Normativ för vad som ska bevisas innan en vy får kallas klar.
**`implementerad` ≠ `verifierad`.** En vy är verifierad först när raden nedan är ifylld med datum och enhet.

---

## 1. Tillstånd per vy

”Alla sex tillstånd i varje vy” är fel krav — *empty* finns inte i en dialog och *conflict* finns inte i en läsvy. Följande gäller i stället. **✔ = måste finnas ritat. – = ej relevant, får inte ritas.**

| Vy | default | loading | empty | partial | error | offline | conflict |
|---|---|---|---|---|---|---|---|
| Hem | ✔ | ✔ | ✔ | – | ✔ | ✔ | – |
| Receptlista / sök | ✔ | ✔ | ✔ | – | ✔ | ✔ | – |
| Receptdetalj | ✔ | ✔ | – | – | ✔ | ✔ | ✔ |
| Recepteditor | ✔ | – | – | – | ✔ | ✔ | ✔ |
| Import av recept | ✔ | ✔ | – | ✔ | ✔ | ✔ | – |
| Veckomeny | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Veckogenerering | ✔ | ✔ | – | ✔ | ✔ | ✔ | ✔ |
| Inköpslista | ✔ | ✔ | ✔ | – | ✔ | ✔ | ✔ |
| Skafferi | ✔ | ✔ | ✔ | – | ✔ | ✔ | ✔ |
| Matlagningsläge | ✔ | – | – | – | ✔ | ✔ | – |
| Chatt | ✔ | ✔ | ✔ | – | ✔ | ✔ | – |
| Vänner / grupp | ✔ | ✔ | ✔ | – | ✔ | ✔ | – |
| Profil / inställningar | ✔ | ✔ | – | – | ✔ | ✔ | – |
| Auth / OTP | ✔ | ✔ | – | – | ✔ | ✔ | – |
| Juridik | ✔ | ✔ | – | – | ✔ | ✔ | – |
| Admin | ✔ | ✔ | ✔ | – | ✔ | – | – |
| Dialog / sheet | ✔ | ✔ | – | – | ✔ | – | – |

---

## 2. Bredd- och skalmatris

Referensbredd är **412 dp** (Pixel 9a). Bevis krävs i:

| Villkor | Krav | Bevis i skärmfilen | Status |
|---|---|---|---|
| 320 dp | inget horisontellt scroll, inga trunkerade primärhandlingar, ingrediensnamn får **två rader** | `#lagastaende320` · `#lagastaende320` · `#chatt320` · Inköp (komponentark 14) | ✔ ritat |
| 360 dp | samma | `#hem360` · `#langavarden` | ✔ ritat |
| 412 dp | referens | hela skärmfilen | ✔ |
| Största systemtext (2,0×) | ingen text klipps, ingen kontroll under 48 dp, **radbrytning i stället för ellips**, flikraden horisontellt rullbar med fullständiga namn | `#storsttext` | ✔ ritat |
| Landskap | endast matlagningsläge och video | `#lagaliggande` (924 × 412) | ✔ ritat |
| Tangentbord öppet | sticky action bar ovanför tangentbordet; fältet i fokus syns | `#tangentbord` | ✔ ritat — **ritad tangentbordsyta, inte systemtangentbord.** Safe area och verklig kollision mäts i § 4 |
| Lång svensk copy | ”Ugnsbakad rotselleri med brynt smör och rostade hasselnötter” | `#langavarden` | ✔ ritat |
| Långa användarnamn | 28 tecken utan mellanslag | `#langavarden` (”Marie-Kristinasdotterberg”, 24 tecken med bindestreck) | ◐ ritat men inte 28 obrutna tecken |

**Ritteknisk skuld:** telefonramarna i specen har fast höjd och `overflow:hidden`. Scroll, sticky-beteende och tangentbordskollision går därför inte att bevisa i den här filen — de verifieras i den byggda appen och protokollförs i § 4.

---

## 3. Läge och tema

| Vyfamilj | Ljust | Mörkt ritat | Mörkt genererat ur matrisen |
|---|---|---|---|
| Kärnvyer (recept, vecka, inköp) | ✔ | ✔ | — |
| Auth | ✔ | ✔ | — |
| Social / chatt | ✔ | ✔ | — |
| Juridik | ✔ | ✔ | — |
| Admin | ✔ | ✔ | — |
| Formulär och editorer | ✔ | **✔ `#formularmorkt`** | — ritat, matrisen behövs inte |
| Sheets och dialoger | ✔ | **✔ `#arkmorkt`** | — ritat, matrisen behövs inte |
| Onboarding, notiser, inställningar | ✖ | ✖ | odesignade — se `migration-gap.md` § B |

**Regeln:** en vy får sakna mörk ritning bara om varje färgat element i den finns som en rad i komponentark 13. Ordet ”mekaniskt” utgår — antingen täcker matrisen vyn (och då behövs ingen ritning) eller så gör den inte det (och då krävs en ritning).

---

## 4. Verifieringsprotokoll

**Ägare: utvecklingsteamet** (beslut B-24). Fylls i på fysisk enhet. Tom rad = ej verifierad. Designspecen levererar tabellen, teamet levererar resultaten.

| Kontroll | Verktyg | Enhet | Datum | Signatur |
|---|---|---|---|---|
| TalkBack — fyra flikar + plusknapp, ordning och namn | TalkBack | | | |
| TalkBack — OTP som ett fält | TalkBack | | | |
| TalkBack — betyg som radiogrupp | TalkBack | | | |
| VoiceOver — samma tre | VoiceOver | | | |
| Träffytor ≥ 48 dp | Accessibility Scanner | | | |
| Kontrast, ljust och mörkt | Accessibility Scanner + CI-lint (T-02) | | | |
| **Renderad** träffytegeometri i alla <!--n:frames-->280<!--/n--> ramar | browserprob, mäter varje interaktiv nod | | | |
| Roll, namn, tillstånd per kontroll | TalkBack + `data-a11y-role`-revision | | | |
| **Nästlade kontroller** — `[data-a11y-role] [data-a11y-role]` ska ge 0 | browserprob (regex kan inte se nästling) | | | |
| Största systemtext | systeminställning 2,0× | | | |
| Reducerad rörelse | systeminställning | | | |
| Tangentbord + sticky bar | manuellt | | | |
| Offline och kö — i flygläge: skapa, ändra och radera ett recept; räknaren i toppfältet visar ändringarna | flygplansläge | | | |
| Offline och kö — starta om appen i flygläge; ändringarna och räknaren finns kvar | flygplansläge | | | |
| Offline och kö — slå av flygläget; kön töms och ändringarna syns på en andra enhet | flygplansläge + andra enhet | | | |
| Offline och kö — lägg till ett foto i flygläge och spara; fotot kommer upp i receptet när nätet är tillbaka | flygplansläge | | | |
| Offline och kö — ett foto på 10 MB eller mer ger "Bilden är för stor" | stor bildfil | | | |
| Offline och kö — logga ut med ändringar i kön; utloggningen stoppas och förklaras | flygplansläge | | | |

---

## 5. Automatiska acceptanstester (CI)

| # | Test | Underkänt när |
|---|---|---|
| T-01 | Tokens mot JSON Schema | rekursiv typ-, required-, pattern- och const-kontroll fäller |
| T-02 | Kontrastlint över `tokens.contrastPairs` + avatarparen, mot **rätt** bakgrund | under parets deklarerade golv |
| T-03 | Råfärgslint i spec-HTML | hex som inte finns i `tokens.json` — **varning, aldrig fel** (beslut B-27: specen är en ritning) |
| T-04 | Opacitetslint | värde utanför `opacityLadder` |
| T-05 | Ikonlint | `data-icon` utan post i `icons.json`, eller post utan fil |
| T-06a (usages) + T-06b (sökvägar) | Manifestlint | `usages` avviker från faktisk räkning · asset-sökväg utan fil |
| T-07 | Versionslint | referens till en äldre version än den i `00-spec-index.md` |
| T-08 | Träffyte- och **rollint** — rollvärde utanför den tillåtna vokabulären hör hit, inte till T-11 (rättat 2026-08-01) | a11y-märkt kontroll under 48 dp **utan `data-hit`** i källan · renderad geometri mäts i browsertestet |
| T-09 | Syntaxlint | dubblerade `id`, dubbla attribut, obalanserade CSS-klamrar |
| T-10 | Indexlint | `00-spec-index.md` versionstabell mot filernas egna `version`-fält · indexet motsäger sig själv om stängningsstatus |
| T-11 | Räkningslint | ram- eller kontrollsiffra i prosan avviker från skärmfilen |

| T-12 | Ankarlint | ett citerat `#ankare` saknar motsvarande `id` i skärmfilen |
