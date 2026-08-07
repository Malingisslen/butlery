# Butlery · Evidensmatris

**En rad per normativt krav. Ingenting är klart förrän raden har ett bevis-ID i varje kolumn som gäller.**
Version **1.0** · 2026-07-26. Normativ för *status*. Där den här filen och ett annat dokument säger olika saker om hur långt något är, gäller den här filen.

### Hur ”inget klipps” faktiskt mäts

En prob som utgår från `.sc-phone` mäter **fel sak**. Den yttre ramen har fast höjd och rapporterar alltid `scrollHeight === clientHeight`; det är de *inre* behållarna med `overflow:hidden` som klipper. Flera ramar (bland dem `#lagastaende320`) saknar dessutom klassen `.sc-phone` helt och missas då i sin helhet.

Den giltiga proben är:

```js
[...document.querySelectorAll('*')].filter(e => {
  const cs = getComputedStyle(e);
  return (cs.overflow === 'hidden' || cs.overflowY === 'hidden')
      && e.scrollHeight > e.clientHeight + 2;
})
```

Avsiktlig `-webkit-line-clamp` räknas inte som klippning och filtreras bort separat. **Senaste körning: 1 träff, och den är en avsiktlig clamp** (recepttiteln i `#langavarden`).

### Grundningsregel

**Produktlogik för en funktion som redan finns i koden skrivs inte — den läses.** En rad får statusen `implementerad` bara om de datamodeller och juridiska dokument den vilar på är lästa, och kolumnen `Skärmbevis` säger vilka. Etapp 1 bröt mot detta: fyra av fyra påståenden om befintliga modeller var fel, och ett rörde barns personuppgifter i en DPIA-granskad funktion (`produktregler.md` § 7.7).

Kolumnerna betyder:

- **Skärmbevis** — ett ankare som faktiskt finns i skärmfilen, eller ett avsnittsnummer i komponentarket. Inte ”finns nog”. **T-14 jämför varje citerat ankare mot skärmfilens `id`-mängd och fäller bygget vid miss** — ett ankarnamn skrivet ur minnet är samma sorts fel som en handskriven räkning.
- **Automatiskt test** — ett test-ID ur `testmatris.md` § 5 som faktiskt körs av `node tools/spec-lint.mjs` eller `node tools/test-generated.mjs`.
- **Manuellt test** — en rad i `testmatris.md` § 4. Tom rad där = kravet är obevisat.
- **Status** — `beslutad` · `implementerad` · `verifierad`.Kedjans utfall står i `fas0/verify-report.json`.

---


## Maskin-id

Kravens `Krav-ID` (`KI-02`, `P-03`, `Y-10`…) är läsformen. **Maskinformen är `REQ-` + kravets id** (`REQ-KI-02`), och verifieringskontroller heter `CHK-` + kontrollens id (`CHK-T-14`). Namnrymderna är disjunkta sedan 2026-08-01; sjutton id kolliderade tidigare mellan de två. Se `testmatris.md` § Namnrymder.

## Bevisgrammatik för kolumnen Skärmbevis

Valideras av **T-14**. En rad som står `implementerad` eller `verifierad` måste bära minst ett bevis; ett ensamt streck räknas inte.

| Form | Betyder | Valideras mot |
|---|---|---|
| `screen:#ram-id` | en ram i en skärmfil | id på ett `class="sc-item"` |
| `component:<avsnitts-id>` | ett avsnitt i komponentarket | id i komponentarket |
| `manual:kap-NN` | ett kapitel i manualen | manualens kapitelnummer |
| `file:"sökväg"` | en fil på disk | filens existens · citattecken vid mellanslag |
| `scope:all-screens` | gäller alla skärmar | inget enskilt bevis krävs |
| `n/a: motivering` | uttryckligen inget skärmbevis | motiveringen är obligatorisk |

Äldre former (`#id`, *komponentark 14*, *manual kap 02*, *samtliga skärmfiler*) godtas fortfarande men **räknas som legacy** i rapporten och ska migreras.

## 1 · Färg och kontrast

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| K-01 | Liten text ≥ 4,5:1 i båda lägen, **mot varje yta tonen får stå på** | alla | — | **T-02** ✅ 21 par (papper + surface.raised) | Accessibility Scanner | design | implementerad |
| K-02 | Stor text och grafik ≥ 3:1 | alla | — | T-02 (golv 3,0) ✅ | Accessibility Scanner | design | implementerad |
| T-13 | Avstängd text mäts mot sitt **eget golv 3:1** och aldrig mot 4,5 — undantaget är skrivet, inte antaget | alla | `#onbalder` · `#authepost` · `#authmfa` | **renderad mätning** ✅ | — | design | **verifierad** — `contrastPolicy.exemptions` |
| K-03 | Saffran är aldrig textfärg; `text.accent` är #A15A0A / #DCA968 | alla | manual kap 02 | T-02 ✅ | — | design | verifierad |
| K-04 | Pressad saffran bär **papper**, aldrig ink | knappar | komponentark 01 | T-02 (`text.onActionPrimaryPressed`) ✅ | — | design | verifierad |
| K-05 | Avatarfärger är ytor; varje yta har fastställd förgrund ≥ 4,5:1 | avatar | komponentark 06 | T-02 (5 par) ✅ | — | design | verifierad |
| K-06 | Inaktiverat: eget golv 3:1, undantaget från 4,5:1, aldrig via opacitet | formulär | `#formularmorkt` · komponentark 13 | T-02 (golv 3,0) ✅ | TalkBack | design | implementerad |
| K-09 | Ingen dekorativ glyf under 3:1 — metadataprickarna borttagna, avståndet bärs av gap | alla | `#hem` | — ❌ | — | design | implementerad |
| K-07 | Opacitet endast 0,02/0,04 på papper och 0,18/0,35/0,60 på ink | alla | — | **T-04** ◐ varning | — | design | implementerad |
| K-08 | Inga råa färgvärden i **genererad kod eller appkod** — spec-HTML:en är uttryckligen undantagen (B-27) och kontrolleras i stället av den renderade kontrastmätningen | genererad kod · app | `assets/generated/tokens.css` · `lib/theme/butlery_tokens.dart` | **T-01** ✅ · **test-generated** ✅ 122 variabler / 7 klasser · **renderad mätning** ✅ 3 017 par | — | design | **verifierad** — omformulerad till B-27:s faktiska omfattning 2026-07-29 |
| K-10 | **Spec-HTML:ens undantag är kompenserat, inte gratis:** varje ritad färg mäts mot sin renderade bakgrund i stället för mot en token-referens | alla | samtliga tio skärmfiler | **renderad mätning** ✅ 0 under golvet | — | design | **verifierad** — `contrastPolicy.renderedMeasurement` |

## 2 · Träffytor och semantik

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| T-01 | Hitbox ≥ 48 × 48 dp, deklarerad i koden | alla | <!--n:frames-->279<!--/n--> ramar | **T-08** (källa) ✅ + browserprob ✅ 0 under 48 | Accessibility Scanner | design | implementerad |
| T-02 | Kontrast mäts mot **deklarerade par** i tokens **och** mot varje par som bara finns i renderad markup | alla | samtliga tio skärmfiler | **T-02** ✅ + **renderad mätning** ✅ 3 017 par, 0 under golvet | — | design | **verifierad** — mätt 2026-07-29, lägsta icke-avstängda kvot 4,73 |
| T-03 | Fokusram runt hitboxen, aldrig runt glyfen | kryssruta · radio · reglage | komponentark 15 | — ❌ | manuell tabbning | design | implementerad |
| T-04 | Varje interaktiv kontroll har roll, namn och tillstånd | alla | <!--n:controls-->1372<!--/n--> märkta kontroller, alla med roll | T-08 ✅ + browserprob ✅ | **TalkBack + VoiceOver** | dev | implementerad |
| T-04b | **Ingen interaktiv `div`/`span` utan roll.** Maskinell genomgång av alla fjorton delfiler: kontrollhöjd + handlingsetikett utan `data-a11y-role` ska ge 0 | alla | samtliga skärmfiler | **browserprob** (testmatris § 4) | — | design | **verifierad** — 2026-07-30 — 22 hittade i del 1 och del 2, alla märkta; 0 kvar av 1 372 roller |
| T-05 | Fokusordning följer läsordning | alla | — | — ❌ | manuell tabbning | dev | beslutad |
| AU-14 | OTP läses som **ett** fält | auth | `#mfa` (inskrivning) · `#authmfa` (utmaning) | — ❌ | TalkBack rad 2 | dev | beslutad |
| T-07 | Betyg läses som radiogrupp | betyg | Familjebetyg | — ❌ | TalkBack rad 3 | dev | beslutad |

## 3 · Responsivitet och skala

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| R-01 | 320 dp: inget horisontellt scroll | recept · matlagning · chatt · inköp | `#lagastaende320` `#lagastaende320` `#chatt320` | **inre klippningsprob** ✅ | — | design | implementerad |
| R-02 | 320 dp: ingrediensnamn på två rader, mängd obruten, status på egen rad | receptdetalj | `#lagastaende320` (5 rader — ramen har fast höjd, listan är kapad medvetet till det som bevisar layouten) | **inre klippningsprob** ✅ | — | design | implementerad |
| R-03 | 360 dp: samma krav som 320 | hem · listor | `#hem360` `#langavarden` | browserprob ✅ | — | design | implementerad |
| R-04 | Största systemtext (2,0×): inget klipps, radbrytning i knappar, rullbar flikrad | receptdetalj | `#storsttext` | — ❌ | **systeminställning 2,0×** | dev | implementerad |
| R-05 | Landskap: matlagning och video | matlagning | `#lagaliggande` | — ❌ | rotation på enhet | design | implementerad |
| R-06 | Tangentbord öppet: åtgärdsrad ovanför tangentbordet | chatt · formulär | `#tangentbord` (ritad yta) | — ❌ | **verklig tangentbordskollision** | dev | beslutad |
| R-07 | Långa värden: namn 1 rad + ellips, titel 2 rader, ingrediens 2 rader | listor | `#langavarden` | — ❌ | — | design | implementerad |
| R-08 | Safe area respekteras uppe och nere | alla | `#safeareaios` (59/34) · `#safeareaandroid` (44/48 treknapp) | — ❌ | enhet med notch | design + dev | implementerad |

## 4 · Tillstånd per vy

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| S-01 | Tillstånd per vy enligt `testmatris.md` § 1 — inte sex överallt | alla | <!--n:frames-->279<!--/n--> ramar | — ❌ inget test | — | design | implementerad |
| S-02 | Mörkt läge ritat för kärnvyer, auth, social, juridik, admin | — | 5 vyfamiljer | — ❌ | enhet i mörkt läge | design | implementerad |
| S-03 | Mörkt läge för formulär och ark | formulär · ark | `#formularmorkt` `#arkmorkt` | — ❌ | — | design | implementerad |
| S-04 | Laddning: tallrikslinje + text. Ingen spinner, ingen shimmer | alla | `#stateladdar` `#stateladdar412` `#veckogenererar` | — ❌ | — | design | implementerad |
| S-07 | Saknad bild kollapsar; **misslyckad** bild behåller ytan och förklarar | kort · veckorad · detalj | komponentark (bildregeln, fyra ytor) | — ❌ | — | design | implementerad |
| S-05 | Fel säger vad hände, vad bevarades, vad du kan göra | alla | felramar | — ❌ | — | design | implementerad |
| S-06 | Offline är banner; clochen används aldrig som statusbild | alla | `#offline` | — ❌ | flygplansläge | design | implementerad |

## 5 · Säkerhet: allergener och kost

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| A-01 | Tre tillstånd: säker · osäker · okänd | recept · vecka · inköp | receptdetalj · `#veckofel` | — ❌ | — | design | implementerad |
| A-02 | **Automatisk planering tar endast `säker` i allergihushåll** | veckogenerering | `#veckoallergi` | — ❌ | — | design | implementerad |
| A-03 | `okänd` bär varför, vilken ingrediens, vem, källa, vad som krävs | receptdetalj | `#okandingrediens` (alla fem uppgifter) | — ❌ | — | design | implementerad |
| A-04 | Automatisk tolkning ger aldrig `säker` | pipeline | — | — ❌ | — | dev | beslutad |
| A-05 | Allergikrav kan inte kringgås i appen | veckomeny | `#veckoallergi` (låst krav utan kryssruta) | — ❌ | — | design + dev | implementerad |
| A-06 | Märkningen följer objektet hela vägen till inköpslistan | inköp | Inköp (komponentark 14) | — ❌ | — | design | implementerad |
| A-07 | Databasuppdatering räknar om och meddelar | pipeline | ❌ saknas | — ❌ | — | dev | beslutad |
| A-08 | Källa avgör om `säker` får ges; automatisk tolkning aldrig ensam | pipeline | `#okandingrediens` (datakälla) | — ❌ | — | dev | beslutad |

## 6 · Samarbete: konflikt, offline, kö

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| C-01 | Konfliktstrategi per entitet | alla delade | `#konflikt` · `#delatlista` | — ❌ | — | design | implementerad |
| C-02 | Stabila rad-ID, tombstones, operationstyper, `rev` | datalager | — | — ❌ | — | dev | beslutad |
| C-03 | Relativa ändringar skickas relativt (`delta`), aldrig som absolut värde | inköp · skafferi | — | — ❌ | — | dev | beslutad |
| C-07 | Ångra hör till **operationen**, inte entiteten: `add`/`delete` klass 1 med 7 s, `check`/`assign`/`update` klass 3 utan friktion | inköp · skafferi · delat | `#delatlistaaktiv` | — ❌ | — | design | implementerad — avstämd mot BUT-954 |
| C-04 | Offlinekö: idempotens, ordning, beroenden, backoff, permanent fel | alla | `#synkko` (permanenta fel först, beroende synligt) | — ❌ | flygplansläge | design | implementerad |
| C-05 | Utloggning med kö blockeras med val | konto | `#utloggningko` · `#utloggningtom` | — ❌ | flygplansläge | design | implementerad |
| C-06 | Chatt: redigering och radering är operationer med märkning | chatt | `#chattredigerat` · `#chattmeny` | — ❌ | TalkBack | design | implementerad |

## 7 · Typografi och content

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| Y-01 | Butlery Sans 0.626, sex stilar, `font-synthesis: none` | alla | manual kap 03 | **T-07** ✅ (inga 0.624-referenser) | — | design | implementerad |
| Y-02 | Ingen 400-vikt under 12 px; 10,5 px endast i 700 | alla | — | — ❌ inget test | — | design | implementerad |
| Y-03 | Tabulära siffror i kolumner och räknare, proportionella i löptext | alla | — | — ❌ | — | design | implementerad |
| Y-04 | `OK` aldrig enda åtgärd i snackbar | snackbar | `#snackbars` | — ❌ | — | design | implementerad |
| Y-05 | Radera ≠ Ta bort | dialoger · menyer | `#dialogradera` `#kontextmeny` | — ❌ | — | design | implementerad |
| Y-06 | Destruktiv copy namnger objektet | dialoger | `#dialogradera` | — ❌ | — | design | implementerad |

## 7b · Hem

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| H-01 | Hjältekortets fyra-stegs prioritet, ingen fallback hoppas över | Hem | `#hem` · `#hemtom` | — ❌ | — | design | implementerad |
| H-02 | Förslag följer allergireglerna — endast `säker` i allergihushåll | Hem | `#veckoallergi` (samma regel) | — ❌ | — | dev | beslutad |
| H-03 | Hälsning byter med klockan; datum proportionellt | Hem | `#hem` (morgon) · `#hemmorkt` (kväll) | — ❌ | — | design | implementerad |
| H-04 | Högst tre sektioner; inköpsraden visar kvarvarande, inte totalen | Hem | `#hem` | — ❌ | — | design | implementerad |
| H-05 | Tomläget har en hjältehandling och ingen illustration | Hem | `#hemtom` | — ❌ | — | design | implementerad |
| H-06 | Fel i en sektion tömmer aldrig vyn | Hem | `#hemfel` | — ❌ | — | design | implementerad |
| H-07 | Offline är banner och kontroll; cache märks med tidsstämpel | Hem | `#hemoffline` | — ❌ | flygplansläge | design | implementerad |
| H-08 | Laddning: tallrikslinje + stillastående skelett efter 300 ms | Hem | `#hemladdar` | — ❌ | — | design | implementerad |

## 7c · Socialt lager och betyg

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| B-01 | Betygsflödet är tre steg och *vem åt* går inte att hoppa förbi utan att det syns | familj | `#betygvemat` · `#betygvemarket` | — ❌ | — | design | **implementerad** — `who_is_eating_sheet.dart` läst 2026-07-29: samma ark som närvaron, med skip och minst en person |
| B-12 | Betygsarket och veckomenyns närvaroark är **samma komponent** — skip och krav på minst en person mot Hela dagen och tillåtet tomt | familj · veckomeny | `#betygvemarket` | — ❌ | — | design | **implementerad** — `_PickerConfig` |
| B-13 | **En misslyckad rosterladdning får inte se ut som ett solohushåll** — båda loggar i dag maten utan närvaro och tiger | familj | `#betygvemarket` | — ❌ | — | dev | **beslutad** — samma `skipped` för två olika orsaker |
| B-14 | Ovalt bärs av **ram och tom ruta**, aldrig av opacitet; kryssrutan är 24 px och alla tre knapparna 48 dp | familj | `#betygvemarket` | — ❌ | kontrastmätning | dev | **beslutad** — koden har opacitet 0,5, ruta 26, knappar 44 och 40 |
| B-15 | Sparning **spärras** utan vårdnadshavarens samtycke, och när allergener valts utan eget samtycke | familj | `#familjmedlemsamtycke` | — ❌ | — | design | **implementerad** — `_canSave` |
| B-16 | Avbockat allergensamtycke **raderar valen på plats**; återkallandet ligger inne i allergenkortet | familj | `#familjmedlemsamtycke` | — ❌ | — | design | **implementerad** |
| B-17 | Samtyckesposten visar **datum och version** på medlemmen | familj | `#familjmedlemsamtycke` | — ❌ | — | design | **implementerad** — `guardianConsent.at` |
| B-18 | Allergen- och ogillar-chipsen är **48 dp** och bär bock, inte färg ensam | familj | `#familjmedlemsamtycke` | — ❌ | kontrastmätning | dev | **beslutad** — ~28 px och färgskillnad i koden |
| B-02 | ”Inte satt” är avsaknad av rad, aldrig 0; ett betyg per person **och recept**, senaste vinner | betyg | `#betygperperson` · `#betygsammanslaget` | — ❌ | — | design | implementerad — avstämd mot `family_rating.dart` |
| B-03 | Gäster **och** barn är sparade hushållsprofiler; `DinerAgeBand.adult` kräver inget samtycke, de tre minderårigbanden gör det | betyg | `#betygvemat` | — ❌ | — | design | implementerad — avstämd mot `diner_profile.dart` |
| B-04 | Betyg läses som radiogrupp, 48 dp per stjärna | betyg | `#betygperperson` | T-08 ✅ | **TalkBack** | dev | implementerad |
| B-06 | Ombudsinmatning visas som ”inmatat av {namn}” och rör aldrig inmatarens eget receptbetyg | betyg | `#betygsammanslaget` | — ❌ | — | design | implementerad — avstämd mot `isProxyEntry` |
| B-07 | Varje betyg går in i ett anonymt publikt snitt, serversidigt; ingen identitet exponeras | betyg | `#betygperperson` | — ❌ | — | dev | beslutad — DPIA R3, godkänd |
| B-08 | Barnprofilens hälsouppgifter kräver ett **eget, uttryckligt** samtycke (art. 9) skilt från vårdnadshavarens (art. 6), med återkallande som raderar | familj | `#familjmedlemsamtycke` | — ❌ | — | design | **implementerad** — `family_member_form_view.dart` läst 2026-07-29 |
| B-10 | Enskilt betyg är heltal 1–5; decimal finns bara på aggregatet | betyg · recept | `#receptcooksnap` · `#betygsammanslaget` | — ❌ | — | design | implementerad — avstämd mot `final int stars` |
| B-11 | Ogillade ingredienser är en **planeringspreferens utan samtyckesfriktion** — aldrig behandlad som hälsodata | familj | `#familjmedlemsamtycke` | — ❌ | — | design | **implementerad** — 14 snabbval, ingen kryssgrind |
| B-09 | Retention: 24 mån vilande hushåll → varning → gallring | konto | ❌ saknas | — ❌ | — | dev | beslutad — DPIA § 2, signerad |
| B-05 | Snittet är enkelt medelvärde i ink; spridning i ord vid max−min ≥ 3 | betyg | `#betygsammanslaget` | — ❌ | — | design | implementerad — snittformeln avstämd mot `FamilyRatingSummary` |
| S-08 | Kommentarspubliken är receptets ägare + medlemmar; döljs på personliga recept; underdriver aldrig | recept | `#receptkommentarer` | — ❌ | — | design | implementerad — avstämd mot `comment_visibility.dart` |
| S-09 | Cook snap ärver receptets publik (`sameAsRecipe`), kan bara bli mer privat (`onlyMe`); varning **före** uppladdning | recept | `#receptcooksnap` | — ❌ | — | design | implementerad — avstämd mot `cook_snap.dart` |
| S-10 | Delningsstatus är **ägarens** vy: mottagare med återkallande per rad, dold för andra, inget tomt läge | recept | `#receptdelningsstatus` | — ❌ | — | design | implementerad — avstämd mot `recipe_detail_sharing_status.dart` |
| S-11 | Misslyckad bild behåller ytan och förklarar; ingen knapp erbjuds | recept | `#receptbildfel` | — ❌ | — | design | implementerad |
| S-12 | Substitution: synlig kontroll, gäller matlagningen, tystar aldrig en varning | matlagning | `#lagasubst` | — ❌ | — | design | implementerad |
| S-13 | Flera timers namnges efter steget; tid annonseras vid start, halvtid, slut | matlagning | `#lagatimers` | — ❌ | **TalkBack** | design | implementerad |
| S-14 | Publikupplysningen före uppladdning visar **uppslagna namn**, inte ordet &quot;hushållet&quot; | socialt | `#cooksnapsynlighet` | — ❌ | — | design | **implementerad** — BUT-901-meddelandet byggs av anroparen |
| S-15 | Bilden kan bara bli **mer privat** än receptet; Avbryt laddar inte upp något | socialt | `#cooksnapsynlighet` | — ❌ | — | design | **implementerad** — `sameAsRecipe` / `onlyMe` |
| S-16 | Varje bild har en **synlig meny** på 48 dp — destruktiv åtgärd får aldrig bara ligga bakom långtryck | socialt | `#cooksnapgalleri` | — ❌ | TalkBack | dev | **beslutad** — allt ligger i dag bakom långtryck |
| S-17 | Borttagning av en bild har **7 s Ångra** — en bild går inte att skriva igen | socialt | `#cooksnapgalleri` | — ❌ | — | dev | **beslutad** — raderas i dag direkt utan bekräftelse |
| S-18 | Vänprofilen visar delning i **båda riktningar** med tal — till dig, från dig, till alla — och återkallandet ligger där siffran står | socialt | `#vanprofildelning` | — ❌ | — | dev | **beslutad** — &quot;du har delat&quot; finns inte i vyn, bara per recept |
| S-19 | Profillänken säger **vad mottagaren ser** — den publika sidan, inget delat | socialt | `#vanprofildelning` | — ❌ | — | dev | **beslutad** — djuplänken läggs i dag i delningsarket utan förklaring |
| S-20 | Att ta bort en vän **återkallar ingenting** av det redan delade; det står i bekräftelsen | socialt | `#vanprofildelning` | — ❌ | — | dev | **beslutad** — sägs inte i dag |

## 7d · Delade inköpslistor

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| D-01 | Gå med är ett uttryckligt val i inkorgen; delningen gör ingenting förrän mottagaren väljer | delat | `#delatinkorg` | — ❌ | — | design | implementerad — B-30, avstämd mot `shared_shopping_list.dart` |
| D-02 | Avvisning är tyst mot gruppen — avsändaren ser antal, aldrig namn | delat | `#delatinkorg` | — ❌ | — | dev | beslutad |
| D-03 | Delningsmeddelandet visas i kortet | delat | `#delatinkorg` | — ❌ | — | design | implementerad |
| D-04 | Ursprunget visas endast när det skiljer sig från avsändaren | delat | `#delatvidare` (båda fallen) | — ❌ | — | design | implementerad — B-31 |
| D-05 | Deltagarraden visar dem som **gått med**, inte dem som erbjudits | delat | `#delatlistaaktiv` | — ❌ | — | design | implementerad |
| D-06 | Tre skilda attributioner: `addedBy`, `assignedTo` (”tar jag”), `purchasedBy`. Bockning och claim är **light actions** — ingen Ångra | delat | `#delatlistaaktiv` | — ❌ | — | design | implementerad — avstämd mot `unified_shopping_item.dart` + BUT-954 |
| D-09 | Kategoriordningen är en svensk butiksvandring, inte alfabetisk, och kan skrivas över per lista och användare | inköp · delat | `#delatlistaaktiv` | — ❌ | — | design | implementerad — avstämd mot `ShoppingCategory.defaultStoreOrder` + `ListCategoryOrder` |
| D-07 | Att lämna behåller egna bockningar (`purchasedBy*` hänger på varan). Lämna är i dag **blockerat** för icke-ägare av `_requireNoPrivilegeEscalation` + `firestore.rules`; deltagarramen är designens mål och kräver backend-undantag | delat | `#delatlamna` | — ❌ | — | design | **verifierad** — avstämd mot `base_shared_content_repository.dart` (`removeMember`) och `shopping_repository_routing_module.dart` |
| D-07b | **Ägaren kan inte lämna och kan inte överlåta** — inget skriver om `ownerId`. Enda utgången är `deleteSharedContent`, som raderar för alla | delat | `#delatlamnaagare` | — ❌ | — | design | **verifierad** — samma två filer |
| D-10 | Medlemsrollen är `viewer` som standard; läsaren får **inga kryssrutor**, inte inaktiverade | delat | `#delatlasare` | — ❌ | — | design | implementerad — avstämd mot `shared_content_member.dart` |
| D-11 | Medlemsnamn är denormaliserade och kan vara gamla; vyn påstår inte att de är aktuella | delat | `#delatlistaaktiv` | — ❌ | — | design | implementerad |
| D-12 | Tre vylägen: platt, **Min del / {namn}s del / Otilldelat**, samt butiksavdelning | delat | `#delatmindel` · `#delatnarvaro` (avdelning) | — ❌ | — | design | implementerad |
| D-13 | Claim kan förloras: `conflict` visar ”{namn} tog den” — information, inte Ångra | delat | `#delatclaimkonflikt` | — ❌ | — | design | implementerad |
| D-14 | Endast den som tagit varan får lämna tillbaka; andra tar över | delat | `#delatlistaaktiv` | — ❌ | — | design | implementerad — avstämd mot `unclaimItem` |
| D-15 | Närvaro i huvudet: aktiva shoppare med heartbeat, utesluter dig själv | delat | `#delatnarvaro` | — ❌ | — | design | implementerad |

### Veckomeny och generering (V)

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| V-01 | Platserna är `lunch` · `middag` · `övrigt`; **ingen frukost**, ingen ”kväll”. Övrigt tar flera recept, lunch och middag ett var | veckomeny | `#veckokalender` | — ❌ | — | design | **verifierad** — `weekly_menu_plan.dart` (`MealSlot.isMulti`) |
| V-02 | Två vylägen (`lista` · `kalender`), valet sparas; första gången öppnas kalendern om veckan har poster | veckomeny | `#veckoprompt` | — ❌ | — | design | **verifierad** — `veckomeny_view.dart` |
| V-03 | Placering är ett eget uttryckligt steg med två vägar — automatiskt eller själv. Inget placeras vid vylägesbyte | veckomeny | `#veckoresultat` · `#veckoplacering` | — ❌ | — | design | **verifierad** — BUT-1241, `menu_placement_footer.dart` |
| V-04 | Kvittot efter automatisk placering står 7 s och bär **ÄNDRA**; noll placerade ger inget kvitto | veckomeny | `#veckoautoplacerad` | — ❌ | — | design | **verifierad** — `_showAutoPlacedToast` |
| V-05 | Manuell placering håller allt i minnet till Klar; att backa med placeringar frågar först | veckomeny | `#veckoplacering` · `#veckoplaceringavbryt` | — ❌ | — | design | **verifierad** — `PopScope` + `_showDiscardDialog` |
| V-06 | Delresultat räknas i **recept**, inte dagar (”2 av 5”) | veckomeny | `#veckoplacering` | — ❌ | — | design | **verifierad** — `menuPlacementProgress` |
| V-07 | Överskott som inte fick plats hamnar i en bricka och är **dragbart** in i veckan — aldrig tyst kastat | veckomeny | `#veckooverflow` | — ❌ | — | design | **verifierad** — `OverflowTray` |
| V-08 | Närvaro är **per måltid** (lunch + middag, aldrig övrigt). Inget val = alla; tom lista = ingen hemma | veckomeny | `#veckonarvaro` | — ❌ | — | design | **verifierad** — `presenceBySlot`, `kPresenceSlots` |
| V-09 | Både *inget val* och *ingen hemma* ger full mängd i inköpslistan | veckomeny · inköp | `#veckonarvaro` | — ❌ | — | dev | **verifierad** — `servingsFor` |
| V-10 | Närvaro påverkar **inte** genereringens receptpool | veckomeny | `#veckodolda` | — ❌ | — | dev | **verifierad** — BUT-1464/1625 |
| V-11 | Veckoöversikten för närvaro är **läsbar, inte redigerbar**; redigering sker per måltid | veckomeny | `#veckonarvarooversikt` | — ❌ | — | design | **verifierad** — `presence_overview.dart` |
| V-12 | Tolkningen redovisas i två högar (förstod · förstod inte) med väg tillbaka till fältet | veckomeny | `#veckochips` | — ❌ | — | design | **verifierad** — `ExtractionTrace` |
| V-13 | Röst landar **redigerbar** i fältet; ingen generering direkt ur tal | veckomeny | `#veckoprompt` | — ❌ | — | design | **verifierad** — `VoicePromptButton` |
| V-14 | En meny som krympt av allergifiltrering förklarar sig; attributionen villkoras av om ett hushåll faktiskt filtrerade | veckomeny | `#veckodolda` | — ❌ | — | design | **verifierad** — `hiddenPrefSource` |
| V-15 | Recept som kom med trots okänd allergenstatus märks | veckomeny | `#veckodolda` | — ❌ | — | design | **verifierad** — `isUnknownSoft` |
| V-16 | Byte är en light action utan Ångra, men utfallet sägs — antal kvar, eller slut på alternativ | veckomeny | `#veckobyt` | — ❌ | — | design | **verifierad** — `SwapResult` |
| V-17 | Genereringsfel ersätter resultatytan, inte vyn: Försök igen + Avvisa, prompten står kvar | veckomeny | `#veckofel` | — ❌ | — | design | **verifierad** — `_buildInlineError` |
| V-18 | Överskrivningsfrågan ställs bara i kalenderläget när veckan har poster; närvaron står kvar | veckomeny | `#veckoskrivover` | — ❌ | — | design | **verifierad** — `_confirmOverwrite` |
| V-19 | Flerval byter cellens innebörd: markera i stället för att öppna, dragning och närvarorad av | veckomeny | `#veckoflytta` | — ❌ | — | design | **verifierad** — BUT-1043 |
| V-20 | Veckans inköpslista navigerar in i listan (listan är kvittot); skalning till närvaro sägs | veckomeny · inköp | `#veckoinkop` | — ❌ | — | design | **verifierad** — BUT-956/1613 |
| V-21 | Röstning finns bara på delade menyer och hör till **platsen**, inte receptet | veckomeny | `#veckorostning` | — ❌ | — | design | **verifierad** — `menu_slot_vote.dart` |
| V-22 | Närvaroraden är en **kontroll**: 48 dp, avatar 26, högst tre ansikten, därefter en avatar + antalet | veckomeny | `#veckonarvaro` | **lint-controls** ✅ `data-presence-row` | Accessibility Scanner | dev | **implementerad** — beslut B-40, kodens ~24 dp ska höjas |
| V-23 | Kalendercellen har egen typroll **11/600** med golvet **10,5 i 700**; text under 12 px får bara eka en klartextkälla i samma vy | veckomeny | `#veckokalender` · `#veckonarvaro` | **lint-controls** ✅ rollskalan | — | dev | **implementerad** — beslut B-41, kodens 8–9 px ska bort |

### Import av recept (I)

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| I-01 | Nio källor, inte åtta; ordnade efter användning, inte alfabet | import | `#imp1kalla` | — ❌ | — | design | **verifierad** — `ImportSource` |
| I-02 | Nätkällor gråas ut **före** valet när enheten är offline | import | `#impoffline` | — ❌ | — | design | **verifierad** — `requiresNetwork` + BUT-1360 |
| I-03 | AI-märke på källor som kan behöva LLM — upplysning, inte varning | import | `#imp1kalla` | — ❌ | — | design | **verifierad** — `mayNeedLlm` |
| I-04 | Väntan har ett slut: 60 s tolkning, 30 s OCR, och det sägs i vyn | import | `#imp2hamtar` | — ❌ | — | design | **verifierad** — `errorImportTimeout` |
| I-05 | Tolkningens säkerhet redovisas per rad, osäkrast först, färg aldrig enda signalen | import | `#imp3granska` | — ❌ | TalkBack | design | **verifierad** — BUT-925 |
| I-06 | Originalraden visas bara när den skiljer sig på annat än blanksteg | import | `#imp3granska` | — ❌ | — | design | **verifierad** — `_hasOriginal` |
| I-07 | Importen landar i editorn, aldrig tyst i samlingen | import | `#imp4sparad` | — ❌ | — | design | **verifierad** — `navigateToRecipeEditor` |
| I-08 | Allergenupplysningen är icke-blockerande och gatear aldrig importen | import | `#imp4sparad` | — ❌ | — | design | **verifierad** — BUT-1198 |
| I-09 | Assisterad tolkning i tre steg; gissade rader är förvalda men aldrig låsta | import | `#impassist1` · `#impassist2` · `#impassist3` | — ❌ | — | design | **verifierad** — `assisted_import_dialog.dart` |
| I-10 | Valda ingredienslinjer är **uteslutna** i instruktionssteget | import | `#impassist2` | — ❌ | — | design | **verifierad** — `excludedIndices` |
| I-11 | Att avbryta frågar bara när rader hunnit väljas | import | `#impassistavbryt` | — ❌ | — | design | **verifierad** — `hasSelections` |
| I-12 | En delning klassas i fyra typer med egna åtgärder och landar i granskning, aldrig i samlingen | import | `#impdelning` · `#impdelningsocial` | — ❌ | — | design | **verifierad** — `receive_share_view.dart`, `ContentDetectorService` |
| I-13 | Kvotavslag visar den **föreslagna åtgärden**, inte ett allmänt försök-senare | import | `#impgrans` · `#impgransai` | — ❌ | — | design | **verifierad** — `RateLimitDenied`, BUT-1144 |
| I-14 | AI-kvot och importkvot är skilda; slut AI betyder grövre tolkning, inte nekad import | import | `#impgransai` | — ❌ | — | design | **verifierad** — `skipLlm` |
| I-15 | Dubbletter: adress → titel → likhet ≥ 0,6; adress/titel visas aldrig under 80 % | import | `#impdubblett` | **enhetstest finns** ✅ | — | dev | **verifierad** — `import_result_handler.dart` |
| I-16 | Fyra dubblettval, inklusive sammanslagning fält för fält | import | `#impdubblett` | — ❌ | — | design | **verifierad** — `DuplicateMergeChoice` |
| I-17 | Misslyckad dubblettkoll släpper igenom importen | import | `#impdubblett` | — ❌ | — | dev | **verifierad** — `catch (_) → true` |
| I-18 | Fel bär **andra vägar** till samma innehåll | import | `#impinget` | — ❌ | — | design | **verifierad** — `availableStrategies` |
| I-19 | Cacheträff sägs, med ålder och möjlighet att hämta om | import | `#impcache` | — ❌ | — | design | **verifierad** — `ParseMetadata.cacheHit` |
| I-20 | Delvis lyckad filimport rapporteras delvis: lyckade och misslyckade var för sig | import | `#impfil` | — ❌ | — | design | **verifierad** — `BatchImportResult` |
| I-21 | Arvegods: misslyckad uppladdning blockerar sparandet och utkastet läggs tillbaka | import | `#impfoto` | — ❌ | — | dev | **verifierad** — BUT-953 |
| I-22 | Arkivimport är flerval utan tolkning, AI eller kvot | import | `#imparkiv` | — ❌ | — | design | **verifierad** — `archive_import_strategy.dart` |
| I-23 | Utkastet sparas efter **3 s** (1 s för titel och beskrivning) och först vid **minst två ifyllda fält** | editor | `#editorutkast` | — ❌ | — | design | **implementerad** — `recipe_auto_save_manager.dart` |
| I-24 | Vyn säger att utkastet är **lokalt**, att det finns **fem platser** och att det **rensas efter 24 h** | editor | `#editorutkast` · `#editorutkastval` | — ❌ | — | dev | **beslutad** — inget av det sägs i dag |
| I-25 | **Misslyckad utkastsparning är tyst** — tidsstämpeln är beviset och står still när något gått fel | editor | `#editorutkast` | — ❌ | — | dev | **beslutad** — medvetet tyst i koden |
| I-26 | Utkastlistan visar **hur länge** varje utkast finns kvar och märker när den femte platsen är full | editor | `#editorutkastval` | — ❌ | — | dev | **beslutad** — nästa utkast trycker ut det äldsta |
| I-27 | Samma fel får **olika lydelse och olika åtgärd** per uppmätt anslutning; okänd anslutning behandlas som *begränsad* | editor · import | `#editorfelkontrakt` | — ❌ | — | design | **implementerad** — `ContextualErrorHandler` |
| I-28 | Behörighetsfel bär resurs, handling, skäl **och föreslagen åtgärd** — aldrig ett &quot;försök igen&quot; | editor | `#editorfelkontrakt` | — ❌ | — | design | **implementerad** — `generatePermissionError` |

### Taggautomatisering (G)

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| G-01 | Regler bor i taggen och byggs inifrån den; ingen fristående regelvy | taggar | `#taggregel` | — ❌ | — | design | **verifierad** — inbäddade i `PersonalTag` |
| G-02 | En regel kräver namn, minst ett villkor, och värde i varje villkor | taggar | `#taggregel` | — ❌ | — | design | **verifierad** — `validate()` |
| G-03 | `matchMode` är ALLA eller NÅGON — ingen nästling, inga parenteser | taggar | `#taggregel` | — ❌ | — | design | **verifierad** |
| G-04 | Tretton villkorstyper; jämförelserna är bundna till typen | taggar | `#taggvillkor` | — ❌ | — | design | **verifierad** — `ConditionType` · `ConditionOperator` |
| G-05 | ”Senast lagad” räknar **aldrig lagad** som maximalt antal dagar | taggar | `#taggvillkor` | — ❌ | — | design | **verifierad** — `cookedRecency` |
| G-06 | Egenskapsvillkor kräver ingrediensuppslagning och fungerar inte offline | taggar | `#taggvillkor` | — ❌ | — | dev | **verifierad** — `requiresLookup` |
| G-07 | Taggens ursprung visas: regel (med namn) · satt av dig · autogenererad | recept | `#taggkalla` | — ❌ | — | design | **verifierad** — `evaluateRulesWithSources` |
| G-08 | Att ta bort en regelsatt tagg på receptet ändrar inte regeln | recept | `#taggkalla` | — ❌ | — | design | **verifierad** |
| G-09 | Exklusiv grupp: bara första taggen behålls — och **bortfallet synliggörs** | recept | `#taggexklusiv` | — ❌ | — | design | **implementerad** — koden loggar bara `debug`; vyn är designens tillägg |

### Kontoborttagning (K)

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
> **Namnrymd:** `KR-` är kontoradering. Familjen hette `K-` till 2026-07-30 och kolliderade då med kontrast- och kvalitetskraven `K-01…K-10` — sex krav-id betydde två saker. Referenser i löptext till `K-01…K-06` avser alltid **kontrast/kvalitet**.

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| KR-01 | **Inget återkallningsfönster finns** — sägs rakt ut före handlingen | konto | `#kontoradera` | — ❌ | — | design | **verifierad** — `account_deletion_service.dart` |
| KR-02 | Raderingsordningen: sökindex och cache först, kontot allra sist | konto | `#kontovantan` | — ❌ | — | dev | **verifierad** |
| KR-03 | Nio minuters timeout; väntan kan inte avbrytas och är ett eget tillstånd | konto | `#kontovantan` | — ❌ | — | design | **verifierad** — `HttpsCallableOptions` |
| KR-04 | Re-autentisering vid inloggning äldre än fem minuter är ett **steg**, inte ett fel | konto | `#kontoreauth` | — ❌ | — | design | **verifierad** — `requiresReauth` |
| KR-05 | Delvis radering är ett eget utfall: kvarstående delar + revisions-id + support | konto | `#kontodelvis` | — ❌ | — | design | **verifierad** — `failedCollections` |
| KR-06 | Skäl efterfrågas före och följer med till revisionsraden | konto | `#kontoradera` | — ❌ | — | design | **verifierad** — `reason` |

### Moderering och admin (M)

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| M-01 | Behörighet är ett svar, inte ett fel: låst yta utan åtgärd för icke-admin | admin | `#adminej` | — ❌ | — | design | **verifierad** — `watchIsAdmin` |
| M-02 | Listan visar bara öppna rapporter; tomt betyder allt hanterat | admin | `#modrapporter` · `#modtom` | — ❌ | — | design | **verifierad** — `watchOpenReports` |
| M-03 | **Minderårigt konto visas före åtgärd**; misslyckad uppslagning memoiseras aldrig | admin | `#modminderarig` | — ❌ | — | dev | **verifierad** — BUT-1609 |
| M-04 | Profil → dölj (reversibelt) · annat → radera (oåterkalleligt); verbet följer åtgärden | admin | `#moddolj` · `#modradera` | — ❌ | — | design | **verifierad** — `isReversibleAction` |
| M-05 | Adminskalet har sex flikar, fliken speglas i adressen och klamras till giltigt intervall | admin | `#adminskal` | — ❌ | — | design | **verifierad** — `admin_shell.dart` |
| M-06 | Avvikelsebannern ligger utanför flikarna — den gäller hela systemet | admin | `#adminskal` | — ❌ | — | design | **verifierad** — `AnomalyBanner` |
| M-07 | Resten av admins nio vyer byggs av teamet ur mönstret | admin | `#adminskal` (mönster) | — ❌ | — | dev | **beslutad** — uttryckligt i arbetsplanen |

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| D-08 | Rader slås samman som operationer med tombstones — aldrig union av tillstånd | delat | — | — ❌ | — | dev | beslutad — § 2.1 |

## 7b · Etapp 3 · första gången (MINIMAL)

Grundningsregeln följd: sju filer lästa före ritning — `onboarding_view.dart`, `onboarding_viewmodel.dart`, `onboarding_age_gate_page.dart`, `onboarding_age_gate_blocked_view.dart`, `onboarding_welcome_page.dart`, `onboarding_allergen_page.dart`, `onboarding_import_page.dart`. Reglerna i `produktregler.md` § 13.

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| O-01 | Guidens ordning är **åldersgrind → välkomst → allergener → import**; grinden ligger först och har ingen *Hoppa över* | onboarding | `#onbalder` | — ❌ | — | design | **implementerad** — `onboarding_view.dart`, sidordningen är kodens |
| O-02 | Endast **födelseår** samlas in, **inget år är förvalt**, och *Nästa* är avstängd till dess ett år valts | onboarding | `#onbalder` | — ❌ | — | design | **implementerad** — ADR-0001, `minAgeYears = 15` |
| O-03 | Åldersgrinden har **tre** utfall: godkänd, nekad (kontot redan raderat serversidigt) och **infrastrukturfel** — det sista passerar inte grinden och kräver inget nytt val | onboarding | `#onbaldrefel` · `#onbalderblock` | — ❌ | — | design | **implementerad** — `AgeGateAdvanceResult` |
| O-04 | Under 15 får en föräldraväg, inte bara utloggning | onboarding | `#onbalderblock` | — ❌ | — | design | **implementerad** — BUT-946 |
| O-05 | **Kostpreferenserna ställs efter första menygenereringen**, inte i guiden — samma fält, samma skrivväg | onboarding · veckomeny | `#onbsenare` | — ❌ | — | dev | **beslutad** — B-39, ny plats i menyresultatet krävs |
| O-06 | Allergenerna visar åtta och veckar ut till sjutton; markeringen bär ram, ton **och** bock — aldrig färg enbart | onboarding | `#onballergi` | — ❌ | — | design | **implementerad** — `onboarding_allergen_page.dart` |
| O-07 | *Hoppa över* **slutför** guiden (`onboardingSkippedAt`) — den återkommer inte, och bekräftelsen får inte antyda &quot;senare&quot; | onboarding | `#onbhoppa` | — ❌ | — | design | **implementerad** — `_skipOnboarding` |
| O-08 | Slutförandet såddar recept **och** en exempelvecka med inköpslista; väntan är inväntad och redovisas med sitt slut | onboarding | `#onbklar` | — ❌ | — | design | **implementerad** — BUT-926, BUT-930 |
| O-09 | Slutförandeskrivningen har ett tak på **20 s**; misslyckandet behåller valen och åtgärden är *Försök igen* | onboarding | `#onbfel` | — ❌ | — | design | **implementerad** — `_completionTimeout` |
| O-10 | En avbruten guide **återupptas** vid sparat steg, bakom åldersgrinden, och den återupptagna sidan räknas som anländ | onboarding | `#onbateruppta` | — ❌ | — | design | **implementerad** — BUT-675, `setInitialPage` |
| O-11 | Första importen fyller fältet ur **urklipp** och lyckad import öppnar **granskningen**, inte en tyst sparning | onboarding | `#onbimport` · `#onbimportklar` | — ❌ | — | design | **implementerad** — `checkClipboardForUrl`, `navigateToDetailOnSave:false` |
| O-12 | Hushållets storlek frågas **inte** i guiden; portionerna följer närvaron per måltid | onboarding | `#onbjamforelse` | — ❌ | — | dev | **beslutad** — B-39, BUT-1611 |
| O-13 | Guiden är ritad i mörkt läge: fältkant på `border.control`, markeringen bär kant och glyf där tonen inte räcker, och `text.danger` byter till `.onRaised` på upphöjd yta | onboarding | `#onbaldermorkt` · `#onballergimorkt` · `#onbfelmorkt` | — ❌ | kontrastmätning i browsern | design | **implementerad** — tokens 1.4 mörka par |
| AU-01 | Auth är **ett formulär i två lägen**; växling rensar lösenord och namn | auth | `#authlogga` · `#authskapa` | — ❌ | — | design | **implementerad** — `auth_view.dart` |
| AU-02 | Inloggning navigerar till skalet; **registrering navigerar inte** — auth-tillståndet driver verifiering → åldersgrind → guide | auth | `#authlogga` | — ❌ | — | design | **implementerad** — `_handleSubmit` |
| AU-03 | **Åldern frågas en gång.** Självintyget vid registrering utgår; `verifySignupAge` är enda auktoriteten | auth · onboarding | `#authskapa` | — ❌ | — | dev | **beslutad** — kräver kodändring, BUT-1384 |
| AU-04 | Samtycket blockerar knappen **före** tryck, inte med en varning efter | auth | `#authskapa` | — ❌ | — | dev | **beslutad** — koden varnar i dag med snackbar |
| AU-05 | Lösenordskravet visas innan inmatning; registrering använder strängare validering än inloggning | auth | `#authskapa` | — ❌ | — | design | **implementerad** — `strongPassword` |
| AU-06 | Återställningskvittot är **identiskt** oavsett om kontot finns; adressen valideras i dialogen | auth | `#authglomt` | — ❌ | — | design | **implementerad** — kontouppräkningsskydd |
| AU-07 | E-postverifiering är en **mjuk spärr** som får lämnas, frågar av sig själv var 5:e sekund och pausar i bakgrunden | auth | `#authepost` | — ❌ | — | design | **implementerad** — `_scheduleNextPoll` |
| AU-08 | Omsändning har 60 s karens; nedräkningen står **utanför** knappens namn | auth | `#authepost` | — ❌ | skärmläsare | dev | **beslutad** — koden räknar ned i etiketten |
| AU-09 | Bekräftelsen säger vart användaren är på väg — vyn byts av sig själv | auth | `#authepostklar` | — ❌ | — | design | **implementerad** |
| AU-10 | **MFA-utmaningen saknas helt i appen.** Tjänsten kan lösa den, inställningarna kan slå på den, ingen vy tar emot den — aktivering kan låsa ut användaren | auth | `#authmfa` | — ❌ | — | dev | **beslutad** — `MfaResolverInfo` används ingenstans i `lib/` |
| AU-11 | Utmaningen tål **automatisk verifiering**: fältet kan fyllas av telefonen och vyn bytas mitt i inmatning | auth | `#authmfa` | — ❌ | fysisk enhet | dev | **beslutad** — `verificationCompleted` |
| AU-12 | MFA saknar reservväg om telefonen är borta — ingen återställningskod, inget andra faktorsalternativ | auth | `#authmfa` | — ❌ | — | dev | **beslutad** — kravet är backendens |
| BH-01 | Behörighetskontraktet är **förklaring → OS-fråga → inställningslänk vid permanent nej → aldrig hårt spärrad funktion** | alla OS-behörigheter | `#behkamera` | — ❌ | — | design | **implementerad** — `os_permission_helper.dart` |
| BH-02 | OS:et frågas **bara** om användaren tryckt Tillåt i förklaringen — systemets nej-budget bränns inte av en tyst omfrågning | alla | `#behkamera` | — ❌ | — | design | **implementerad** — `requestWithRationale` |
| BH-03 | Andra nej ger **tyst hopp**; funktionen finns kvar och förklaringen upprepas inte | alla | `#behkamera` | — ❌ | — | design | **implementerad** |
| BH-04 | `limited` och `provisional` räknas som beviljade; **begränsad fotoåtkomst är ett eget läge** med väg att välja fler bilder | import · cook snaps | `#behfoton` | — ❌ | fysisk iPhone | dev | **beslutad** — fotoimporten går inte genom kontraktet |
| BH-05 | Fotoimporten och kameran ska läggas på `OsPermissionHelper` — i dag har de en naken väg utan förklaring och utan inställningslänk | import | `#behkamera` · `#behfoton` | — ❌ | — | dev | **beslutad** — `image_picker_service.dart` |
| BH-06 | Notisfrågan ställs **endast på Android 13+**; iOS och äldre Android kortsluts till ja | notiser | `#behnotiser` | — ❌ | två enheter | design | **implementerad** — `_androidTiramisuSdkInt` |
| BH-07 | Vid permanent nej är reglagen **inaktiverade och synliga**, inte gömda, och snackbaren länkar till systeminställningarna | notiser | `#behnotiser` | — ❌ | — | design | **implementerad** |
| BH-08 | **Exakta larm saknas helt.** Utan behörigheten får matlagningsläget inte lova en timer på sekunden | matlagning | `#behlarm` | — ❌ | fysisk Android | dev | **beslutad** — ingen förekomst i `lib/` |
| BH-09 | **En timer lovar aldrig en tid den inte kan hålla** — omöjlig exakt tid sägs i vyn, inte i hjälpen | matlagning | `#lagatimerlofte` · `#behlarmnekat` | — | Låst enhet över tid | design | **implementerad** |
| BH-10 | **Butlery frågar en gång.** Vägen tillbaka är en rad i timervyn, aldrig en påminnelse, och försvinner när tillåtelsen finns | matlagning | `#behlarmnekat` | — | — | design | **implementerad** |
| BH-11 | **Förgrundstjänsten:** en notis för alla timrar, närmast först, med steg, `+1 min` och `Pausa`; finns bara medan en timer går | matlagning | `#lagatimernotis` | — | Låst Android 13+ | dev | **beslutad** |
| BH-12 | **Den utgångna timern kvitteras** och står kvar i notis och list tills dess; säger vad som är klart, inte att en timer gick ut | matlagning | `#lagatimerutgangen` | — | Låst enhet, reducerad rörelse | design | **implementerad** |
| SK-01 | Generatorn **subtraherar aldrig mängder** — hela rader lyfts bort eller ingen del av dem | inköp | `#inkoputeslutna` · `#skafferibas` | — ❌ | — | design | **implementerad** — `menu_shopping_list_generator.dart` |
| SK-02 | Uteslutna basvaror **redovisas med antal och går att öppna** | inköp | `#inkoputeslutna` | — ❌ | — | design | **implementerad** — `excludedStaples` |
| SK-03 | Ett oläsbart skafferi ger en lista **utan** uteslutning — och det sägs rakt ut, med en väg att försöka igen | inköp | `#inkoputeslutna` | — ❌ | — | dev | **beslutad** — i dag bara en varningslogg |
| SK-04 | **Basvaran går att sätta, syns i listan och har sin följd utskriven** | skafferi | `#skafferibas` | — ❌ | — | dev | **beslutad** — `isStaple` finns bara i modellen, ingen vy rör den |
| SK-05 | Bockad vara till skafferiet är **opt-in**, slår samman **bara vid samma enhet**, och **att bocka av igen tar inte bort den** | inköp | `#inkopbockad` | — ❌ | — | design | **implementerad** — BUT-1050 |
| SK-06 | Kategoriordningen är **per lista och per användare**, med återställning till butiksvandringen | inköp | `#inkopkategoriordning` | — ❌ | — | design | **implementerad** — `defaultStoreOrder`, D-09 |
| SK-07 | Kategorin bärs av **namnet**; färgrutan är dekor och tonas till en linje | inköp | `#inkopkategoriordning` · `#inkopkategoribyte` | — ❌ | — | design | **implementerad** — koden har både ruta och namn; rutan ger ingen upplysning namnet inte ger |
| SK-08 | Flervalets bar bär **bara radera** — fyra obligatoriska parametrar, inga valfria; *Flytta till kategori* för hela urvalet finns inte | inköp | `#inkopflerval` | — ❌ | — | dev | **beslutad** — kategoribytet sitter per rad |
| SK-09 | Skafferiets rader är **reversibelt destruktiva**: svep utan dialog, 7 s Ångra, ett Ångra per sats, ingen snackbar om raderingen misslyckades | skafferi | `#skafferiflerval` | — ❌ | — | design | **implementerad** — BUT-948, BUT-954 |
| SK-10 | Platsen sätts ur ingrediensens typiska förvaring; ett eget namn ger **inget taxonomi-id** och kan inte matchas mot recept — vilket sägs i vyn | skafferi | `#skafferilagg` | — ❌ | — | design | **implementerad** — `fromTypicalStorage` |
| SK-11 | Mängder skalas efter **närvaro** (antal hemma / receptets portioner), per placering; antalet omräknade måltider redovisas **skilt** från uteslutna basvaror | inköp | `#inkoputeslutna` | — ❌ | — | design | **implementerad** — BUT-1613, `scaledMeals` |
| SK-12 | Övrigt-platsen skalas inte, och ett recept utan portionsuppgift skalas inte | inköp | `#inkoputeslutna` | — ❌ | — | design | **implementerad** — `_presenceFactor` |
| SK-13 | Den genererade listan identifieras av **ISO-veckomarkören**, inte namnet; regenerering ersätter innehållet, bockningar överlever på namn+enhet och **manuella tillägg försvinner** — vilket sägs **före** knapptrycket | inköp | `#inkopgenererad` | — ❌ | — | dev | **beslutad** — kontraktet finns i koden, varningen finns inte |
| SK-14 | Tre utfall skiljs: **inget att generera**, **misslyckat**, och **pågår redan** — det sista renderas som tystnad | inköp | `#inkopgenererad` | — ❌ | — | design | **implementerad** — `nothingToGenerate` · `null` · `alreadyRunning` |
| SK-15 | Ett recept som inte kan läsas utesluts ur listan och **syns** i vyn — i dag bara en logg | inköp | `#inkoputeslutna` | — ❌ | — | dev | **beslutad** — `unresolvedRecipes` |
| SK-16 | Ångra-fönstret är **ett** tal för samma operationsklass — i dag 4 s i listan och 7 s i skafferiet | inköp · skafferi | `#inkopflerval` · `#skafferiflerval` | — ❌ | — | dev | **beslutad** — två löften för samma handling |
| SK-17 | **Appens radier är 0 överallt** — `borderRadiusXs/S/M/L` är alla `0.0`, så varje `BorderRadius.circular` är en nolloperation. Specens 8/12 är en systemisk avvikelse som hör i temagenereringen | alla | `#inkopflerval` (noterat) | — ❌ | — | dev | **beslutad** — `app_dimensions.dart`, etapp 8 |
| MR-01 | **En röst per person och den går inte att ändra** — sägs före valet, aldrig efter | veckomeny | `#veckorostlagg` | — ❌ | — | design | **implementerad** — `castVote` kastar *Already voted* |
| MR-02 | Ett alternativ som tillkommer **efter** att någon röstat märks med hur många som redan röstat | veckomeny | `#veckorostlagg` | — ❌ | — | dev | **beslutad** — `addAlternative` tillåts hela den aktiva tiden |
| MR-03 | Antingen ska rösten gå att ändra, eller ska alternativen låsas när första rösten fallit | veckomeny | `#veckorostlagg` | — ❌ | — | dev | **beslutad** — produktbeslut, inte ritning |
| MR-04 | **Ett lika resultat avgörs inte automatiskt.** Id-sortering är ingen anledning någon kan förklara | veckomeny | `#veckorostavgor` | — ❌ | — | dev | **beslutad** — `leadingOption` bryter lika på id |
| MR-05 | Bara den som startade rösten avgör ett lika resultat; övriga ser vad som väntar och på vem | veckomeny | `#veckorostavgor` | — ❌ | — | dev | **beslutad** — tjänsten begränsar inte vem som resolvar |
| MR-06 | **En utgången oavgjord röst har ett eget tillstånd med tre vägar** — avgör, öppna igen, släpp platsen | veckomeny | `#veckorostutgang` | — ❌ | — | dev | **beslutad** — faller i dag utanför både `activeVotes` och `resolvedVotes` |
| MR-07 | Utgången **med** röster skiljs från utgången **utan** röster — det senare är inget resultat | veckomeny | `#veckorostutgang` | — ❌ | — | design | **implementerad** — `resolveVote` kastar vid noll röster |
| MR-08 | Historiken visar **antal**, aldrig vem som röstade på vad | veckomeny | `#veckorosthistorik` | — ❌ | — | design | **implementerad** — modellen vet det, vyn väljer att inte visa det |
| MR-09 | Röstfönstret är 24 timmar från **skapandet**, inte från senaste alternativet | veckomeny | `#veckorostlagg` | — ❌ | — | design | **implementerad** — `votingWindow` |
| KI-01 | Samtycket har **sju ändamål**; de två som är villkor ritas som **villkor med skäl**, aldrig som låsta reglage | konto | `#kontosamtycke` | — ❌ | — | design | **implementerad** — `user_consent.dart` |
| KI-02 | **`aiProcessing` skrivs över till nej vid varje sparning** — viewmodellen bygger objektet ur fem av sju ändamål | konto · import | `#samtyckeai` | — ❌ | — | dev | **beslutad** — samma klass som BUT-1322; sparningen ska utgå från det lästa samtycket |
| KI-03 | Samtyckesposten bär **version, tidpunkt och enhet** och visas — ett revisionsspår, inte en inställning | konto | `#kontosamtycke` | — ❌ | — | design | **implementerad** |
| KI-04 | **&quot;Godkänn alla&quot; sparar inte medan &quot;Återkalla allt&quot; sparar direkt** — asymmetrin ska bort | konto | `#kontosamtycke` | — ❌ | — | dev | **beslutad** — `acceptAll` är lokal, `revokeAllOptional` skriver |
| KI-05 | Förnyelse visar **vad som ändrats**, behåller befintliga val som förval, och stänger aldrig av något för att användaren avstår | konto | `#samtyckefornya` | — ❌ | — | design | **implementerad** — `needsRenewal` är enbart versionsjämförelse |
| KI-06 | Exportfilen lever **bara i minnet** och nollas när vyn lämnas — det sägs i vyn | konto | `#kontodataexport` | — ❌ | — | design | **implementerad** — `dispose` |
| KI-07 | Exporten redovisar **vad filen innehåller** och att andras uppgifter i delade listor inte följer med | konto | `#kontodataexport` | — ❌ | — | design | **implementerad** |
| KI-08 | Tre felorsaker har **egna besked och egna åtgärder**; ingen delvis fil erbjuds | konto | `#dataexportfel` | — ❌ | — | design | **implementerad** — `_formatErrorMessage` |
| KI-09 | Lösenords- och e-postformuläret har **eget laddtillstånd per avsnitt** | konto | `#kontosakerhetsvy` | — ❌ | — | dev | **beslutad** — delar i dag ett `isLoading` |
| KI-10 | E-postbytet gäller först när länken till den **nya** adressen öppnats | konto | `#kontosakerhetsvy` | — ❌ | — | design | **implementerad** — verify-before-update |
| KI-11 | Juridik och öppen källkod flyttas ur Kontosäkerhet till **Om Butlery** | konto | `#kontosakerhetsvy` | — ❌ | — | dev | **beslutad** — ligger i dag under säkerhet |
| KI-12 | Systemets tillåtelse ligger **först** i notisvyn — utan den betyder inget nedanför något | konto | `#kontonotiser` | — ❌ | — | design | **implementerad** |
| KI-13 | Standarderna behålls och **sägs**: inköp och aktivitet av, tysta timmar 22–08 förvalda | konto | `#kontonotiser` | — ❌ | — | design | **implementerad** — `NotificationPreferences.defaults` |
| KI-14 | **Typmatrisen slutar vara en inställning.** Leverans styrs av *takt* per kategori — direkt · samlat · sammanfattning · inget | konto | `#notisertyp` | — ❌ | — | dev | **beslutad** — `isEnabled` kräver i dag tre ja, och typen är osynlig |
| KI-15 | **Lokal lagring av notisval är en stubbe** — `toJson` ger `{}` och `fromJson` ger standardvärden | konto | `#notisertyp` | — ❌ | — | dev | **beslutad** — offline kan valen se ut som nollställda |
| KI-16 | **Landskoden är ett eget val**, aldrig en gissning — `+46` får inte klistras på ett nummer utan kod | konto | `#mfalagg` | — ❌ | — | dev | **beslutad** — `formattedPhone` i `_startEnrollment` |
| KI-17 | Ominloggning krävs före både på- och avslagning av tvåstegsverifiering | konto | `#mfalagg` · `#mfaaktiv` | — ❌ | — | design | **implementerad** — `AuthActionHandler.reauthenticate` |
| KI-18 | Vyn tål **automatisk verifiering** — skärmen kan bytas mitt i inmatningen och det är inte ett fel | konto | `#mfalagg` | — ❌ | fysisk enhet | design | **implementerad** — `onAutoVerified` |
| KI-19 | **Reservkoder hör i påslagningen**, och skyddet får inte gå att slå på förrän utmaningen och koderna finns | konto | `#mfaaktiv` | — ❌ | — | dev | **beslutad** — blockerande, hänger ihop med AU-10 |
| KI-20 | Notiscentralen: 20 per sida, drar-för-att-uppdatera, oläst bärs av **vikt** och färg | konto | `#notiscentral` | — ❌ | — | design | **implementerad** — `notifications_viewmodel.dart` |
| KI-21 | **Markera alla lästa** flyttas ut ur kebabmenyn till en rad som bara syns när något är oläst | konto | `#notiscentral` | — ❌ | — | dev | **beslutad** — ligger i dag i en popup |
| KI-22 | En post som **inte längre leder någonstans** märks i stället för att falla tyst till Hem | konto | `#notiscentral` | — ❌ | — | dev | **beslutad** — routern faller tillbaka |
| KI-23 | **Borttagning ur inkorgen har 7 s Ångra** och säger att bara raden försvinner, inte det den handlade om | konto | `#notisrensa` | — ❌ | — | dev | **beslutad** — `dismissSelected` är optimistisk utan Ångra, mot § 2.4 |
| KI-24 | Anmälningar visar **utfallet i klartext** och har en **överklagandeväg** på avslutade | konto | `#minaanmalningar` | — ❌ | — | dev | **beslutad** — UGC-policyn kräver överklagande; vyn visar bara status |
| KI-25 | Statusen bärs av **ord och form**, aldrig av färg ensam | konto | `#minaanmalningar` | — ❌ | kontrastmätning | dev | **beslutad** — brickan har en textfärg mot fyra bakgrunder |
| KI-26 | **De juridiska dokumenten renderas som text, inte som markdown-källa** | konto | `#kontojuridik` | — ❌ | — | dev | **beslutad** — `SelectableText` på råfilen; `markdown_body.dart` finns oanvänd |
| KI-27 | Dokumentet visar **version, datum och vilken version du godkänt**, och säger när texten fallit tillbaka till svenska | konto | `#kontojuridik` | — ❌ | — | dev | **beslutad** — versionen syns inte i dag |
| KI-28 | Statistiken säger att den räknats **i telefonen** ur den laddade samlingen, med tidpunkt | konto | `#kontostatistik` | — ❌ | — | design | **implementerad** — `RecipeQueryViewModel`-projektion |
| KI-29 | Fördelningens förklaring bär **andel i klartext**; färgen är stöd, och **nolldelar syns inte** i vare sig stapel eller förklaring | konto | `#statistikfullstandighet` | — ❌ | kontrastmätning | dev | **beslutad** — etiketterna färgkodas i dag, och nollsegment skrivs ut fast de inte ritas |
| KI-30 | Ofullständiga recept blir **tre uppgifter med tal**, störst först — inte en vågrät rad av alla i felrött | konto | `#statistikfullstandighet` | — ❌ | — | dev | **beslutad** — raden är dessutom lägre än en träffyta |

## 8 · Kod och paketering

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| P-01 | CSS genereras ur tokens och parsar | — | — | **test-generated** — antalet variabler står i `fas0/verify-report.json`, inte här | — | design | verifierad |
| P-02 | Dart genereras ur tokens och är strukturellt giltig | — | — | **test-generated** — antal klasser och färger står i `fas0/verify-report.json`, inte här | **dart analyze** | dev | implementerad |
| P-03 | Ikoner: varje `data-icon` har post och fil | alla | — | **T-05** — status ur `fas0/verify-report.json` | — | design | implementerad — T-05 faller så länge ikonmastrar saknas; status följer rapporten |
| P-04 | `usages` genereras, redigeras aldrig för hand | — | — | **T-06a (usages) + T-06b (sökvägar)** ✅ | — | design | verifierad |
| P-05 | Indexets versionstabell stämmer med filerna | — | — | **T-10** ✅ | — | design | verifierad |
| P-06 | OFL-noteringar följer varje distribuerad build | — | `assets/LICENSES.md` | — ❌ | releaseansvarig | dev | beslutad |
| P-07 | Fontens name-tabell bär copyright och licens | — | — | — ❌ | font-/releaseansvarig | dev | **beslutad** |

---

## Sammanfattning

**Statusfördelningen står inte här.** Den räknas maskinellt ur den här filens egna kravrader av `tools/verify.mjs` och renderas i `fas0/kontrollstatus.md` under *Kravstatus*, med `requirements.total` och `requirements.byStatus` i `fas0/verify-report.json`. Handskrivna kopior har glidit i varje granskningsrunda och är borttagna 2026-08-01.

**Verifieringskedjans utfall står inte heller här.** Kör `bash fas0/run-verify.sh`; rapporten redovisar tre skilda mätklasser och tre resultatnivåer.

### Vad som återstår, och hos vem

**Beslutade men obevisade krav** ägs till största delen av utvecklingsteamet och kräver körande kod eller en mätning på fysisk enhet: TalkBack, VoiceOver, 2,0× systemtext, tangentbordskollision, rotation, flygplansläge, `dart analyze`, fontens name-tabell, samt pipeline-reglerna A-04, A-07, A-08 och H-02 för allergidata.

**Tre är designens:** B-01 (betygsflödets vyer `who_is_eating_sheet.dart` och `family_rating_entry_view.dart` är inte lästa), B-08 (Art. 9-samtycket för barnprofiler saknar ritning), B-11 (ogillade ingredienser saknar ritning).

**Därutöver äger designen det verifieringen mäter:** T-14:s kravrader utan godtagbart bevis, LC-01:s komponenttäckning, T-08:s träffytor och rollvärden, A11Y-02:s kontroller utan tillståndsmetadata, samt T-05:s saknade ikonmastrar. Antalen står i rapporten.

Ritningsarbetet för etapp 0–11 är utfört och `arbetsplan.md` är historisk. Det är inte samma sak som att designen är färdig: formuleringarna &rdquo;inga egna hål kvar&rdquo; och &rdquo;inget designarbete återstår&rdquo; var avskrivna påståenden och är strukna.

Avstämningen 2026-07-26 gick i två vändor och rättade sju felaktiga påståenden om befintliga modeller; slutsatsen står i `produktregler.md` § 7.7.

## Genomgång av de beslutade kraven · 2026-07-29

**70 rader står `beslutad`.** De är inte en restlista av samma sort: sju är designens och kan stängas här, 63 kräver en **kodändring** och stängs inte av någon ritning. Grupperingen nedan är efter *vad som låser upp raden* — inte efter vy — eftersom det är den enda ordning som går att arbeta i.

### A · Blockerande före release — säkerhet och juridik

| Krav | Varför det blockerar |
|---|---|
| **AU-10 · AU-12 · KI-19** | Tvåstegsverifiering går att slå på, men inloggningen kan inte ta emot en utmaning och det finns ingen reservkod. **Den som aktiverar skyddet kan låsa sig ute.** Skyddet får inte gå att slå på förrän båda finns. |
| **KI-02** | `aiProcessing` skrivs över till nej vid varje sparning av samtycken. Ett samtycke som återkallas utan att någon rört det är en GDPR-fråga, inte en bugg i en inställningsvy. |
| **KI-24 · KI-25** | Google Plays UGC-policy kräver en **överklagandeväg**; vyn visar bara status, och statusbrickan bär en textfärg mot fyra bakgrunder. |
| **BH-08** | Exakta larm efterfrågas aldrig — matlagningslägets timer kan därför inte utlovas på sekunden på Android 13+. Antingen behörigheten eller ett ändrat löfte. |
| **P-06 · P-07** | OFL-noteringar i varje distribuerad build och fontens name-tabell. Obligatoriskt vid extern distribution. |

### B · Tyst dataförlust — användaren får inte veta

| Krav | Vad som försvinner tyst |
|---|---|
| **MR-06** | En utgången oavgjord röstning faller mellan `activeVotes` och `resolvedVotes` och **syns ingenstans**. Röster kan ha lagts; platsen står tom. |
| **KI-15** | Notisvalens lokala lager är en stubbe — offline kan valen se ut som nollställda. |
| **SK-03 · SK-13** | Basvaruuteslutningen degraderar tyst till ingenting, och manuella rader i veckolistan försvinner vid regenerering. |
| **I-24 · I-25 · I-26** | Utkastet är lokalt, har fem platser, dör efter ett dygn och **misslyckad sparning är tyst**. Inget av det sägs. |
| **KI-23 · S-17** | Borttagning ur notisinkorgen och av en cook snap sker utan Ångra, mot § 2.4 klass 1. |
| **SK-04** | `isStaple` går inte att sätta i något gränssnitt — hela uteslutningen är vilande. |

### C · Rättvisa och behörighet

**MR-02 · MR-03 · MR-04 · MR-05** — röstningens alternativ kan ändras efter att andra röstat, rösten går inte att flytta, och lika resultat bryts på ett id. **S-18 · S-19 · S-20** — delning visas i en riktning, profillänken förklarar inte vad den visar, och att ta bort en vän återkallar ingenting. **D-02 · D-08** — delade listors roller och operationsmodell. **KI-04 · KI-09 · KI-11 · KI-16 · KI-21 · KI-22 · KI-26 · KI-27 · KI-29 · KI-30** — asymmetriska samtyckesknappar, delat laddtillstånd, juridik i fel rum, `+46` på främmande nummer, färgkodade förklaringar, markdown som källkod.

### D · Tillgänglighet och lint

**S-16** — destruktiv åtgärd bara bakom långtryck. **T-05 · T-06a (usages) + T-06b (sökvägar) · T-07** — OTP som ett fält, hitboxmätning på renderad geometri, lint i CI. **A-04 · A-07 · A-08 · H-02** — allergidatans pipelineregler, som kräver körande kod. **C-02 · C-03 · R-06 · K-08 · M-07 · B-07 · B-09** — regler teamet bygger ur mönstret.

### E · Designens sju — det jag själv kan stänga

| Krav | Vad som saknas |
|---|---|
| ~~B-01~~ | **Stängd 2026-07-29.** `who_is_eating_sheet.dart` läst; två nya krav föll ut (B-13, B-14) och båda är kodens. `family_rating_entry_view.dart` kvarstår oläst men B-01 vilade på arket. |
| ~~B-08~~ | **Stängd 2026-07-29** — koden hade redan tvånivåmodellen; specen saknade den. |
| ~~B-11~~ | **Stängd 2026-07-29** — samma läsning: ogillar är en preferens utan samtyckesgrind. |
| **O-05 · O-12** | MINIMAL-beslutets två konsekvenser: kostfrågans nya plats i menyresultatet och hushållsstorlekens bortfall. Ritade som ramar, men kräver ett kodställe. |
| ~~T-02~~ · ~~K-08~~ | **Båda stängda 2026-07-29.** T-02 genom mätning av 3 017 renderade par (137 brister rättade, 0 kvar). K-08 var **fel formulerad**: den påstod att inga råa färgvärden får finnas &quot;utanför tokens.json&quot;, men B-27 hade redan avgjort att spec-HTML:en behåller sina hex. Regeln gäller **genererad kod och appkod** — där är den grön — och ritningarnas undantag är nu kompenserat av den renderade mätningen (K-10). |

**Uppdaterad 2026-07-29:** designens sju rader är nu **noll** — B-01, B-08, B-11 stängda genom kodläsning, T-02 genom mätning, K-08 genom omformulering till B-27:s faktiska omfattning, och O-05/O-12 står kvar som **kodställen** (MINIMAL-beslutets två konsekvenser), alltså dev-ägda i praktiken. **Resten är kodens.**

**Slutsatsen är obekväm och värd att säga rakt:** ritningarna är klara, men **63 av 70 kvarvarande krav kan bara stängas av någon som skriver kod**. Designens andel är sju rader, varav tre (B-01, B-08, B-11) har stått öppna sedan etapp 1 och kräver kodläsning jag inte gjort. Det är nästa naturliga arbete på den här sidan av bordet.

---

## Kontrastmätningen 2026-07-29 · T-02

Varje element med en egen textfärg i de tio skärmfilerna mättes mot sin **verkliga** bakgrund — närmaste förfader med en ogenomskinlig yta, med alla mellanliggande `rgba`-lager komponerade i rätt ordning. Golvet sattes per element: 3:1 för avstängd text (`contrastPolicy.exemptions`) och för stor text (≥ 24 px, eller ≥ 19 px i 700), annars 4,5:1.

| | |
|---|---|
| Mätta par | **3 017** |
| Under golvet vid första mätningen | **137** |
| Rättade | **137** |
| Kvar | **0** |
| Lägsta kvot bland icke-avstängda | **4,73** |

**Vad bristerna var — och de var systemiska, inte slarv i enskilda ramar:**

- **`text.secondary` #627061 på `surface.raised`** = 4,27. Tokens 1.3 införde `.onRaised`-varianten #5B6959 för precis detta, men ritningarna följde den inte. **Största gruppen, ~40 förekomster i nio filer.**
- **#B4BFA6 som plusglyf** = 1,74 på papper. Tonen togs bort ur tokens redan 2026-07-26 (`text.person`), men levde vidare som kalendercellens &quot;+&quot;. 31 förekomster, nu `text.secondary`.
- **`text.secondary` mörkt #93A48D på `surface.raised` mörkt** = 3,96 — exakt den kvot tokens själv underkänner. Rättad till #A9B2A0.
- **#7D897C som brödtext** på papper = 3,32. Tonen är `text.disabled` och duger bara under sitt eget 3:1-golv; som vanlig text är den underkänd.
- Två enstaka: papper på `surface.disabled` (1,96) och en avatarinitial i ink på #7d897c (4,35).

**Lärdomen är densamma som i grundgranskningen:** varje brist fanns redan namngiven i `tokens.json` — som en `.onRaised`-variant, ett borttaget värde eller ett undantag med golv 3. Reglerna var skrivna; det som saknades var en **mätning som läser dem**. Den mätningen är nu körd över samtliga par, inte bara över de deklarerade.

---

## Verify-kedjan körd 2026-07-29

Kedjan körd över tretton dokument (tio skärmfiler, komponentarket, manualen, tillgänglighetshandoffen). **Elva kontroller, noll fel** — men första körningen var **röd**, och de två felen var värda att hitta:

| Kontroll | Utfall |
|---|---|
| T-09 CSS-klamrar | ✔ 0 obalanserade |
| T-07 unika ram-id | ✔ 247 unika |
| T-05 ikonnamn registrerade | ✔ 73 (icons.json 1.6 — fjorton glyfer tillagda vid djupgranskningen) |
| CHK-T-06a · `usages` mot faktisk räkning | ✔ alla 64 |
| T-08 deklarerad hitbox ≥ 48 | ✔ samtliga |
| § 4 nästlade a11y-kontroller | ✔ 0 |
| kontroll = roll | ✔ 1 007 / 1 007 |
| T-04 opacitetssteg | ✔ endast dokumenterade |
| T-10 versionstabell mot filernas version | ✔ 1.6 |
| räkningsankare mot faktiskt | ✔ 245 |
| typskala och vikt | ✔ inga mellansteg |
| T-02 renderad kontrast | ✔ mätt i DOM per fil, 0 under golvet i samtliga femton filer (djupgranskning 2026-07-30) |

### Verifieringskontroller som var beslutade 2026-07-29

> Raderna nedan beskriver **kontroller** (`CHK-T-14`…`CHK-T-17`), inte krav. De låg tidigare inbäddade i en tvåkolumnstabell om körutfall, vilket gjorde att parsern avvisade dem. Flyttade och försedda med eget huvud 2026-08-01.

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| T-14 | **`Skärmbevis`-kolumnen valideras** — ett krav får inte peka på ett ram-id som ingen ram bär | alla | `korsgranskning.md` | — ❌ **implementerad i `tools/lint-core.mjs` (Fas 0.5)** | — | dev | **implementerad** — CHK-T-14 kör i `tools/lint-core.mjs` med typade bevis |
| T-15 | **T-10 mäter samtliga rader i versionstabellen**, inte tre av tolv | alla | `korsgranskning.md` | — ❌ | — | dev | **implementerad** — CHK-T-15 läser hela versionstabellen med en strategi per rad |
| T-16 | **Ram-id kan inte kollidera** — dubbletter fälls innan filen sparas | alla | `korsgranskning.md` | ✔ manuell körning | — | dev | **verifierad** — CHK-T-16 fäller dubblett-id globalt; mutationsprov i `tools/selftest.mjs` |
| T-17 | Interna `#`-länkar pekar bara på ramar i **samma fil**; övriga skrivs som filreferens | alla | samtliga tio skärmfiler | ✔ 0 döda länkar | — | design | **verifierad** — CHK-T-17 mätt 2026-07-29; mutationsprov i `tools/selftest.mjs` |

**Vad den röda körningen fångade:**

1. **Sju dubblerade ram-id** — `skafferi`, `notiser`, `statistik`, `kontosakerhet`, `dataexport`, `samtycke`, `juridik`. Varje nytt id jag hittade på i etapp 2b och etapp 6 kolliderade med en äldre ram i del 1–3. Ett dubblerat `id` är ett underkänt bygge enligt spec-lint, och det bryter dessutom varje `#ankare`-länk i dokumentet: två ramar konkurrerar om samma adress och den första vinner. Omdöpta till `skafferivyn`, `kontonotiser`, `kontostatistik`, `kontosakerhetsvy`, `kontodataexport`, `kontosamtycke`, `kontojuridik` — de äldre behöll sina, och referenserna i evidensmatrisen och sync-kvittot följde med.
2. **Två opacitetsvärden utanför skalan** — `.92` och `.72` — som jag själv införde i fotoräknarens överlägg. Rättade till steget `.60`.

**Lärdomen är tredje gången samma:** varje fel jag hittat i den här sessionen har hittats av en **mätning**, aldrig av en genomläsning. Handräknade tal (67 beslutade som var 70, tio filers ramantal som summerade till 268 mot 243), handvalda id, handvalda opaciteter — alla tre gled. Det som inte mäts glider.

**Kvar som inte går att köra härifrån:** `node tools/verify.mjs` i CI (samma kontroller, men som byggsteg), `dart analyze`, `test-generated.mjs` mot genererad CSS och Dart, och verifieringsprotokollet på fysisk enhet.

---

## 16 · Globala tillstånd (etapp 9.1)

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| GL-01 | Underhållsläget är en helskärm utan navigation; fjärrtexten är det enda som varierar | globalt | `#globunderhall` | T-12 (ankare) | — | design | implementerad |
| GL-02 | Rubrik och åtgärdsknapp hårdkodade — måste fungera utan lokalisering | globalt | `#globunderhall` | — | — | dev | beslutad |
| GL-03 | Underhåll skiljs från offline i ord, inte i färg eller glyf | globalt | `#globunderhall` · `#hemoffline` | — | Innehållsgranskning | design | implementerad |
| GL-04 | Ingen textskalningsklämning: 2,0× möts med rullning | globalt | `#globunderhall` | T-09 (typskala) | 2,0× på enhet | dev | beslutad |
| GL-05 | Timeout 45 min, varning 5 min före, nedräkning `m:ss` tabulärt, endast siffran uppdateras | globalt | `#globsession` | T-05 (tabulära siffror) | TalkBack/VoiceOver | design | implementerad |
| GL-06 | Varningsdialogen har två lägen efter köns innehåll; *Logga ut nu* med kö går via bekräftelsen i § 2.4 | globalt | `#globsession` · `#utloggningko` | — | — | dev | beslutad |
| GL-07 | **En timeout-utloggning rensar aldrig kön** — gäller alla tre skäl | globalt | `#globsession` · `#globsessiontyst` | — | Verifieringsprotokoll § 4 | dev | **beslutad · blockerande** |
| GL-08 | Timeout i bakgrunden ger besked vid återkomsten, som upplysning och aldrig som fel | globalt | `#globsessiontyst` | T-02 (kontrast) | — | dev | **beslutad · blockerande** |
| GL-09 | Installationsbannern: en gång, ovanför naven, aldrig över primärhandlingen, 48 px överallt | webb | `#globinstallera` | T-04 (träffytor) | — | design | implementerad |
| GL-10 | Ceremonin hör till sparningen, en gång per konto, 3 s med synlig återstående tid | globalt | `#globceremoni` · `#onbimportklar` | — | — | design | implementerad |
| GL-11 | Reducerad rörelse: inget hårstreck, ceremonin väntar på tryck | globalt | `#globceremoni` | — | Reducerad rörelse på enhet | dev | beslutad |
| GL-12 | **Gesttipset behålls** (B-47) men bara i en vy som redan har en synlig kontroll för samma handling | globalt | `#globsvep` | — | — | design | **implementerad** |
| GL-13 | Tipset slutar visas **permanent när gesten använts en gång**; annars efter tre visningar. Ett avvisande räknas som visning | globalt | `#globsvep` | — | Tre visningar + en gest på enhet | dev | **beslutad** |
| GL-14 | Nyckeln bär `seen`-räknare **och** `used`-flagga — en ren *sedd*-flagga kan inte skilja inlärd från ignorerad | globalt | `#globsvep` | — | — | dev | **beslutad** |
| GL-15 | Aldrig två tips samtidigt, aldrig under första sessionen, ingen animerad hand vid reducerad rörelse | globalt | `#globsvep` | — | Reducerad rörelse på enhet | dev | **beslutad** |

---

## 17 · Flerval (etapp 9.2)

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| FL-01 | Flerval har en synlig ingång — **i toppfältet, inte i kebaben** (B-46, se FL-15); långtryck är genväg | alla sex ytor | `#flervalingang` · `#flerbar` · `#flergrupp` | — | — | design | implementerad |
| FL-02 | Baren hör till listan den styr: fäst för skärmlista, inbäddad i förälderns skroll | alla fyra listor | `#flerbar` · `#flergrupp` | — | — | design | implementerad |
| FL-03 | Högst tre handlingar i baren; radera sist, ensamt, i `text.danger` | receptlistan | `#flerbar` | T-02 (kontrast) | — | design | implementerad |
| FL-04 | *Markera alla* är en växel som kan avmarkera | receptlistan | `#flerbar` | — | — | dev | beslutad |
| FL-05 | Massdelningens `catch (_)` visar fel — tomhet påstås inte | receptlistan | `#flerbar` · SK-11 | — | Flygplansläge på enhet | dev | **beslutad · tyst förlust** |
| FL-06 | Räknare i tabulära siffror; handlingar avstängda vid noll med namnet läsbart | alla fyra listor | `#flerbar` | T-04 (träffytor) · T-05 | — | design | implementerad |
| FL-07 | Masstagg lägger till, aldrig ersätter; en tagg per omgång; rubriken säger det | receptlistan | `#flertagg` | — | — | design | implementerad |
| FL-08 | Masstaggens tre utfall, inklusive *alla bar redan taggen* utan Ångra | receptlistan | `#flertagg` | — | — | design | implementerad |
| FL-09 | Flervalet behålls när användaren skickas till taggvyn och kommer tillbaka | receptlistan | `#flertagg` | — | — | dev | beslutad |
| FL-10 | Menyläggningens ordning visas i rutnätet före skrivning | receptlistan | `#flermeny` | — | — | design | implementerad |
| FL-11 | **Överfyllnad avgörs före skrivningen; ingen snackbar utför en skrivning** (§ 2.4) | receptlistan | `#flermeny` | — | Verifieringsprotokoll § 5 | dev | **beslutad · blockerande** |
| FL-12 | De recept som inte får plats namnges; tvåveckorstaket syns | receptlistan | `#flermeny` | — | — | design | implementerad |
| FL-13 | Sammanslagning: förhandsvisning som namnger raderade taggar och flyttade recept; namnet kvar under låsning | taggar | `#flertaggsam` | T-11 (ikonnamn) | — | design | implementerad |
| FL-14 | Sammanslagning får Ångra — eller knappen heter vad den gör | taggar | `#flertaggsam` | — | — | dev | **beslutad · oåterkallelig** |
| FL-15 | **Ingången är *Välj* i toppfältet** (B-46), samma plats i alla sex ytor; långtryck är genväg | alla sex ytor | `#flervalingang` · `#flerbar` | — | TalkBack: ordet läses som knapp | design | **implementerad** |
| FL-16 | Toppfältet **byter innehåll, inte höjd**: räknaren ersätter titeln, *Avbryt* ersätter tillbakapilen | alla sex ytor | `#flervalingang` · `#flerbar` | T-04 (träffytor) | — | design | **implementerad** |
| FL-17 | I en flikvy sitter *Välj* i **vyns eget** toppfält, aldrig i skalets; med **färre än två rader** visas ordet inte alls | alla sex ytor | `#flervalingang` | — | — | dev | **beslutad** |
| KN-01 | **En knuff per person och rätt** (B-47). Ingen *knuffa igen*; raden byter till kvitto på plats | socialt | `#socknuff` | — | — | design | **implementerad** |
| KN-02 | Knuffen är en **händelse i flödet, aldrig en notis** som väcker någon | socialt | `#socknuff` · `#socflode` | — | — | dev | **beslutad** |
| KN-03 | Mottagarens avstängning **visas för avsändaren innan** hen knuffar — ingen knapp som inte leder någonstans | socialt | `#socknuff` | — | TalkBack: raden utan knapp bär skälet | design | **implementerad** |
| KN-04 | **Ingen knuff till ett barns profil**; ingen räknare och ingen historik över antal påminnelser | socialt | `#socknuff` | — | — | dev | **beslutad** |
| I-29 | **Delvis utfall är ett tredje utfall**: namnger vad som gick och inte, låter misslyckade ligga kvar valda, lämnar aldrig flervalet automatiskt | alla flervalsytor | `#flergrupp` | — | Verifieringsprotokoll § 5 | dev | **beslutad · blockerande** |

---

## 18 · Feedback och rapportering (etapp 9.3)

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| FB-01 | Feedbackknappen döljs vid ark och dialog, viker för snackbaren, finns inte i matlagningsläget | globalt | `#fbknapp` | — | — | design | implementerad |
| FB-02 | Knappen namnger sig vid första visningen | globalt | `#fbknapp` | T-11 (ikonnamn) | — | design | implementerad |
| FB-03 | **Allt som skickas redovisas rad för rad och avbockningsbart** — bild, enhetsinfo, skärmväg | feedback | `#fbformular` | — | Innehållsgranskning | dev | **beslutad · art. 9** |
| FB-04 | Skärmdumpen visas öppet med förhandsvisning och orden om namn och allergier | feedback | `#fbformular` | — | — | design | implementerad |
| FB-05 | Skärmvägen visas med faktiska skärmnamn, utfällbar till alla tjugo | feedback | `#fbformular` | — | — | dev | beslutad |
| FB-06 | Tom beskrivning ger fel vid fältet, inte i snackbar | feedback | `#fbformular` | — | — | dev | beslutad |
| FB-07 | Kvittot skiljer skickat med bild från skickat utan bild | feedback | `#fbformular` | — | — | dev | **beslutad · tyst förlust** |
| FB-08 | Kopieringsknappen innehåller inte e-post, redovisar sitt innehåll och heter *Kopiera felsökningstext* | admin | `#fbinkorgvy` | — | — | design | implementerad |
| FB-09 | **Varje kopiering loggas i `ops_log`** | admin | `#fbinkorgvy` · `#admdrift` | — | Verifieringsprotokoll § 6 | dev | **beslutad · blockerande** |
| FB-10 | Filter är chips, status är rullgardin per kort | admin | `#fbinkorgvy` | — | — | design | implementerad |
| FB-11 | Anmälans kvitto säger vem, när och att innehållet syns kvar | anmälan | `#fbanmal` | — | — | design | implementerad |
| FB-12 | Blockera samtidigt erbjuds som eget val i anmälan | anmälan | `#fbanmal` | — | — | dev | beslutad |
| FB-13 | Blockeringssektionen är utfälld och säger vad blockeringen **inte** gör; raderat konto visas som text | integritet | `#fbblockerade` | — | — | design | implementerad |

## 19 · Aktivitet, chatt och grupper (etapp 9.4)

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| SO-01 | Varje händelsetyp har sitt eget verb | flödet | `#socflode` | — | Innehållsgranskning | dev | **beslutad · falskt påstående** |
| SO-02 | Receptets titel skrivs som den heter — `toLowerCase()` utgår | flödet | `#socflode` | — | — | dev | beslutad |
| SO-03 | Ett kort bär en färgad kant; den dekorativa rostkanten utgår | flödet | `#socflode` | — | — | design | implementerad |
| SO-04 | **Knuffar utgår som händelsetyp**, inte bara som funktion | flödet | `#socflode` · `#socintegritet` | — | — | dev | beslutad |
| SO-05 | Tre tomma lägen: inga vänner · tyst · filtret tomt | flödet | `#soctomtingavanner` · `#soctomttyst` | — | — | design | implementerad |
| SO-06 | Oändlig skroll ligger i en skrollyssnare, inte i `itemBuilder` | flödet | `#socflode` | — | — | dev | beslutad |
| SO-07 | Kortet säger före trycket att receptet inte är delat | flödet | `#socbegar` | — | — | design | implementerad |
| SO-08 | Efter skickad förfrågan visas *Efterfrågat* med tid; ingen upprepning | flödet | `#socbegar` | — | — | dev | beslutad |
| SO-09 | Ägarens svarsvy krävs (ja/nej i notiserna) | notiser | `#socbegar` · `#notisertyp` | — | — | dev | **beslutad · ofullständigt flöde** |
| SO-10 | **Ett underval visar sitt eget värde, aldrig förälderns**; pausad grupp är synligt vilande | profil | `#socintegritet` | — | — | dev | **beslutad · falsk visning** |
| SO-11 | Minderårigas sökbarhet: serverväg och låsning ska synas som skäl | profil | `#socintegritet` | — | Minderårigflöde på enhet | design | implementerad |
| SO-12 | Varje röstning har sluttid, och sluttiden avgör | chatt · meny | `#socomrostning` · MR-07 | — | — | dev | **beslutad · blockerande** |
| SO-13 | Byta röst syns som möjligt; oavgjort avgörs och redovisas | chatt · meny | `#socomrostning` | — | — | design | implementerad |
| SO-14 | Stängd röstning visar vad som vann och erbjuder följdhandlingen | chatt | `#socomrostning` | — | — | design | implementerad |
| SO-15 | Emoji: vår typografi bär inga; användarens ord får; reaktioner är sex och låsta | chatt · kommentarer | `#socreaktion` | T-04 (träffytor) | — | design | implementerad |
| SO-16 | Chattens grupp heter *samtalet*; ingen människa raderas (K-11) | chatt | `#socgruppinfo` | — | Innehållsgranskning | design | implementerad |
| SO-17 | Överlåtelsen förklarar ägarskapet, visar inga e-postadresser, meddelar den nya ägaren | grupper | `#socoverlat` | — | — | dev | beslutad |
| SO-18 | Delade listor får samma överlåtelse som grupper (D-07b) | delad lista | `#socoverlat` | — | — | dev | beslutad |

## 20 · Inställningar, juridik, admin, komponenter (etapp 9.5)

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| KO-01 | Hushållsstorleken har en hemvist; profilen pekar hit (B-39) | inställningar | `#insthushall` | — | — | dev | beslutad |
| KO-02 | Exit-vakten kastar aldrig en ändring tyst; misslyckad sparning behåller ändringen | inställningar | `#insthushall` | — | — | design | verifierad |
| KO-03 | Skalning är inte en sparning, och receptets eget antal syns | recept | `#instportion` | — | — | design | implementerad |
| KO-04 | Enhetsväxeln syns bara vid amerikanska enheter och förklarar sig då | recept | `#instportion` | — | — | design | implementerad |
| KO-05 | Sent hushållsförval kvitteras en gång, inte som en främmande ändring | recept | `#instportion` | — | Kall djuplänk på enhet | dev | beslutad |
| KO-06 | Fyra juridiska dokument, samma huvud och fot; rå markdown når aldrig användaren | juridik | `#jurriktlinjer` · KI-26 | — | — | dev | **beslutad · blockerande** |
| KO-07 | Riktlinjernas version syns, eftersom den stämplas på anmälningar | juridik | `#jurriktlinjer` · `#fbanmal` | — | — | design | implementerad |
| KO-08 | Allergener och kost ligger överst i filterpanelen | sök | `#sokpanel` | — | — | design | implementerad |
| KO-09 | Taggfiltret är en trelägesväxel (av · med · utan) | sök | `#sokpanel` | — | — | dev | beslutad |
| KO-10 | Träffraden säger vad som begränsar, med väg att rensa | sök | `#sokpanel` | — | — | design | implementerad |
| KO-11 | Varje mätvärde bär sin definition; *ingen data* skrivs som ord | admin | `#admmatning` | — | — | design | implementerad |
| KO-12 | En dataserie går att läsa utan färg | admin | `#admmatning` | T-02 (kontrast) | Gråskala på enhet | design | implementerad |
| KO-13 | **Skalan är sekventiell** (`dataScale.sequential`, fem toner) och gäller storlek och ordning. Ingen kategorisk kulörskala införs — `categorical` är `null` med flit | admin | `#admmatning` | T-01 (tokens) · T-02 (kontrast) | Gråskala på enhet | design | **verifierad** — tokens 1.7, § 20.5 |
| KO-24 | **Högst tre färgade serier** (steg 1, 2, 5); fyra eller fler blir en tabell | admin | `#admmatning` · `#admdrift` | T-01 (tokens) | — | design | implementerad |
| KO-25 | Statusfärg i data endast när statusen **är** datan, och serien namnges | admin | `#admmatning` | — | Innehållsgranskning | design | implementerad |
| KO-26 | Steg 4 och 5 bär ink, aldrig papper — fem nya kontrastpar mätta | admin | `#admmatning` | T-02 (kontrast) | — | design | verifierad |
| KO-14 | Gleshet före lansering förklaras i tabellen; parsningsrad leder till importerna | admin | `#admdrift` | — | — | design | implementerad |
| KO-15 | Bilduppladdning: per-bild-tillstånd; flyttat omslag sägs i klartext | recept | `#kompbild` | — | — | dev | beslutad |
| KO-16 | Receptsammanslagning: skillnader fält för fält, tre löften (bilder, anteckningar, menyplatser) | recept | `#kompdubblett` · `#impdubblett` | — | — | design | implementerad |
| KO-17 | Relationen mellan recept går båda vägarna och det sägs | recept | `#komprelaterade` | — | — | dev | beslutad |
| KO-18 | Mallen läggs till och slår samman dubbletter; *Använd* ligger i raden | inköp | `#kompmallar` | — | — | design | implementerad |
| KO-19 | Röstassistansen har fyra tillstånd med ord; barge-in namnges; puls bara vid lyssning | matlagning | `#komprost` | — | Reducerad rörelse på enhet | design | implementerad |
| KO-20 | Säsongsraden räknar egna recept; noll eller okänd månad → visas inte | hem | `#kompsason` | — | — | dev | beslutad |
| KO-21 | Källartefakten: råtext som citat, 30-dagarsvarning som upplysning, jämför är förval | recept | `#kompkalla` | — | — | design | implementerad |
| KO-22 | Arvegods: originalbilden är receptet, ordning rättas i efterhand, förväntan sätts före | import | `#komparvegods` | — | — | design | implementerad |
| KO-23 | Bred yta lägger sida vid sida; max textbredd gäller kolumnen | surfplatta | `#surfplatta` | — | Surfplatta på enhet | design | **ersatt** — 2026-07-30 — uppgår i BR-01…BR-16 (etapp 10). Raden stod kvar som *öppen fråga* efter att den besvarats |

---

## 21 · Bred layout (etapp 10)

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| BR-01 | Tre brytpunkter styr layout: 320 · 768 · 1024; övriga tal ändrar ingen layout | globalt | `#bredbrytpunkter` | — | — | design | implementerad |
| BR-02 | En skärm kan inte vara två kategorier samtidigt — de tre överlappande frågorna reduceras | globalt | `#bredbrytpunkter` | — | — | dev | **beslutad · motsägelse i kod** |
| BR-03 | Max radlängd gäller även mobil (`infinity` utgår); 72 tecken, gäller kolumnen | globalt | `#bredbrytpunkter` · `#bredgrans` | T-09 (typskala) | — | dev | beslutad |
| BR-04 | **Skena kräver bredd ≥ 768 och höjd ≥ 500** — inte 600 | globalt | `#bredskal` · `#bredlandskap` | — | Liggande telefon på enhet | dev | **beslutad · blockerande** |
| BR-05 | Skenan bär bottenradens vokabulär: vår botten, gemena etiketter, rostmarkering | globalt | `#bredskal` | T-02 (kontrast) | Rotation på surfplatta | dev | **beslutad · identitetsbrott** |
| BR-06 | *lägg till* är en handling överst i skenan, inte en destination | globalt | `#bredskal` | — | — | design | implementerad |
| BR-07 | Utfälld skena visar ordmärket som vektor, aldrig som text | globalt | `#bredskal` | T-11 (ikonnamn) | — | dev | **beslutad · varumärke** |
| BR-08 | Destinationsbyte behåller historik, skrollposition och öppet filter | globalt | `#bredskal` | — | — | dev | beslutad |
| BR-09 | Under 500 px höjd: en spalt, bottenrad, komprimerat sidhuvud | globalt | `#bredlandskap` | — | Liggande telefon på enhet | design | implementerad |
| BR-10 | Receptet delas efter läsning: ingredienser smalt, steg brett, socialt fullbrett under | recept | `#bredrecept` | — | — | design | implementerad |
| BR-11 | **En sidskroll och klistrad ingrediensspalt** — aldrig två oberoende skrollytor | recept | `#bredrecept` | — | Surfplatta på enhet | dev | beslutad |
| BR-12 | Veckorutnätet finns bara över 768; närvaroraden är en kontroll även i smal kolumn | meny | `#bredmeny` | T-04 (träffytor) | — | design | implementerad |
| BR-13 | Inköpslistans varor är en kolumn bred; bredden går till härkomst | inköp | `#bredinkop` | — | — | design | implementerad |
| BR-14 | Högst tre kolumner, kolumngolv 240 px, konstant kortproportion | recept | `#bredgrid` | — | — | design | implementerad |
| BR-15 | Fyra ytor får bred layout; allt annat är en spalt max 600 px | globalt | `#bredgrans` | — | — | design | implementerad |
| BR-16 | Marginaler bär kontext eller ingenting; 320 px-golvet gäller först | globalt | `#bredgrans` | — | 320 px på enhet | design | implementerad |

---

## 22 · Breda vyer (etapp 11.1 · veckomenyns rutnät)

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| BV-01 | **Ett tillstånd som finns smalt finns brett.** Bred layout har aldrig färre tillstånd | alla breda | hela 11.1 | — | Surfplatta på enhet | design | implementerad |
| BV-02 | Kalenderläget lyder inte under textbredden; listläget behåller 900 | meny | `#vmbnormal` | — | — | dev | beslutad |
| BV-03 | Prompten bor i en egen smal spalt, aldrig ovanför veckan | meny | `#vmbnormal` | — | — | dev | beslutad |
| BV-04 | Tre cellmarkeringar med tre **former**: i dag · skrivs över · osparat | meny | `#vmbnormal` · `#vmboffline` | T-02 (kontrast) | Gråskala på enhet | design | implementerad |
| BV-05 | Rutnätet har inget tomt läge i mitten; en enda framhävd ingång | meny | `#vmbtom` | T-04 (träffytor) | — | design | implementerad |
| BV-06 | **Överskrivning bekräftas som markering i rutnätet**, med antal och namn | meny | `#vmbgenererar` | — | Verifieringsprotokoll § 7 | dev | **beslutad · blockerande** |
| BV-07 | Genereringsoverlayen utgår; rutorna fylls i ordning, förlopp som hårstreck | meny | `#vmbgenererar` | — | Reducerad rörelse på enhet | dev | beslutad |
| BV-08 | Generering skriver aldrig över en manuell placering utan att säga det | meny | `#vmbdelvis` | — | — | dev | beslutad |
| BV-09 | **En stängd röstning lämnar alltid något i cellen**; högst en röstning per cell | meny | `#vmbomrostning` · MR-07 | — | — | dev | **beslutad · blockerande** |
| BV-10 | Konflikten visas i cellen; cellen får bredda sig medan den är öppen; ingen sammanslagning | meny | `#vmbkonflikt` | — | Två enheter samtidigt | design | implementerad |
| BV-11 | Resterna ligger i ett **arbetsförråd** som överlever omladdning och säger varför | meny | `#vmbdelvis` | — | — | dev | beslutad |
| BV-12 | Offline låser inte rutnätet; bara generering stängs av, med skäl. Osparat syns per cell | meny | `#vmboffline` | — | Flygplansläge på enhet | design | implementerad |
| BV-13 | **Dragning tillåten som genväg** (synliga mål); upptagna mål byter plats; likvärdig kebab- och tangentbordsväg | meny | `#vmbflytta` | T-04 (träffytor) | Tangentbord på surfplatta | design | implementerad |

| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Automatiskt test | Manuellt test | Ägare | Status |
|---|---|---|---|---|---|---|---|
| BV-14 | Omslaget över båda spalterna; aktivt steg med 3 px vilolinje; titeln som den heter | recept | `#rcbnormal` | — | — | design | implementerad |
| BV-15 | Skalningen visar receptets egna tal och *Återställ*; **tiderna i stegen skalas aldrig** | recept | `#rcbportion` | — | — | design | implementerad |
| BV-16 | Fullständighetsbanderollen över båda spalterna och **pekar på fälten**; luckan står i listan | recept | `#rcbofullstandigt` | T-04 (träffytor) | — | dev | beslutad |
| BV-17 | **Läsläget byter ut, tar inte bort**; sparat exemplar är ditt och det sägs | recept | `#rcblaser` | — | — | design | implementerad |
| BV-18 | Arvegodset: bilden brett och överst, råtext och avskrift sida vid sida, zoom utan att lämna vyn | recept | `#rcbarvegods` | — | — | dev | beslutad |
| BV-19 | Bandet under stegen är fullbrett men en 600 px spalt; cook snaps undantaget | recept | `#rcbkommentar` | — | — | design | implementerad |
| BV-20 | Receptet offline: dela efter vad som är sant; **laga-knappen fungerar** | recept | `#rcboffline` | — | Flygplansläge på enhet | design | implementerad |
| BV-21 | Varorna en kolumn bred; bredden ger information per rad, inte rader per bredd | inköp | `#ikbnormal` | — | — | design | implementerad |
| BV-22 | Två tomma lägen: högerspalten finns inte förrän något ska förklaras; handlingen är veckans meny | inköp | `#ikbtom` | — | — | design | implementerad |
| BV-23 | Anspråk som namn i raden, inte färg; *se*-medlem utan bockrutor; **anspråk förfaller efter ett dygn** | inköp | `#ikbdelad` | — | Två enheter samtidigt | dev | beslutad |
| BV-24 | Offline: senast synkad i huvudet, anspråk före tystnaden märks osäkra, **dubbelbockning redovisas vid synk** | inköp | `#ikboffline` | — | Flygplansläge, två enheter | dev | **beslutad · tyst konflikt** |
| BV-25 | **Tvinga rotation endast under 768 px kortaste sida**; A+ som utgångsläge brett; wakelock bara medan vyn lever | matlagning | `#lgbrotation` | — | Surfplatta i porträtt | dev | beslutad |
| BV-26 | **`SwipeHintBanner` tas bort ur matlagningsläget** — den synliga kontrollen finns redan (§ 16.5) | matlagning | `#lgbgester` | — | — | dev | beslutad |
| BV-27 | Ingrediensbytet har alltid synlig ikon och frågar **i dag eller receptet**, med *bara i dag* som förval | matlagning | `#lgbgester` | — | — | dev | **beslutad · tyst ändring** |
| BV-28 | Timrarna i egen list med stegnummer; **utgången timer står kvar tills den kvitteras**; tomt recept broadcastar inte *lagar just nu* | matlagning | `#lgbtimer` · `#lgbutan` | — | — | dev | beslutad |
| Y-07 | **Reträtten vänster, följden höger** i varje bekräftelse — betydelse, inte ordet *Avbryt* | alla | 18 handlingsrader | — | — | design | verifierad |
| Y-08 | Tomlägesglyfen: **2× rubrikgraden** i vyn, fast **64** i helskärmsavbrott, streck 1,4 | alla | `#vmbtom` `#ikbtom` `#soctomtingavanner` `#globunderhall` `#authepost` | — | — | design | verifierad |
| Y-09 | Offline är **en** form: banner på `surface.raised` med `wifi-off` i `#8A5212` — aldrig ink, aldrig illustration | alla | 12 banderoller | — | — | design | verifierad |
| Y-10 | **Hushåll, aldrig familj** i systemtext; *rätt* om maten, *måltid* om platsen i veckan | alla | alla ramar — ingen enskild ram bevisar en term (rättat 2026-07-31: pekade på ram-id morkform, som aldrig funnits) | — | Innehållsgranskning | design | verifierad |
