# IN EXECUTION 2026-08-05 — layout-aware recipe splitting

Approved by Malin ("a", 2026-08-05) after the measured report on why cookbook
spreads fail to split. THIS file is the live execution copy. BUT-1797 finished
and merged to main on 2026-08-05, so `tasks/todo.md` was reclaimed for this
initiative; its record is preserved below the separator. The sibling
`tasks/butlery-layout-aware-split-plan.md` is the APPROVAL snapshot and is
deliberately not kept in sync — corrections found during execution (⑥ in
particular) live here, and here only.

## Progress

- [x] Först: städa bordet — tidsutläsningen committad (cf16988bb, on main).
- [x] Steg 0: `tools/corpus_split_eval.dart` + the `recipeEntries` verified-level
      fix. Baseline recorded: single 122/133 (92%), multi 12/48 (25%), 46 lost.
- [x] Steg 1: MEASURED AND DROPPED — the strict title filter recovered 6 recipes
      but cost one recipe 29 points of ingredient-F1, past the 5-point per-recipe
      limit this plan set in advance.
- [x] Steg 2: `lib/services/ocr/text_layout.dart` — page model. Landed
      b2756986e after seven review rounds and sixteen findings.
- [ ] Steg 3: widen `DeviceTextRecognizer` to return the page model.
      IN PROGRESS. Seam widened, ML Kit mapper written and exposed for
      testing. **Decision taken 2026-08-06 (Malin):** the text swap goes
      BEHIND `enable_layout_recipe_split`, not just the split. Reason: the
      rollback did not work — the new string reaches every on-device photo,
      not only cookbook spreads, and turning off the split flag would not
      have undone it; only disabling the free tier would, at a cost per
      image. `RecognitionResult` now carries BOTH the provider's own string
      and the layout, and `OCRExtractionService` chooses from the flag.
      **AVVIKELSE fran planen, medveten (2026-08-06):** ③ och steg 3 nedan
      foreskriver "trimma per rad i stallet for globalt". Koden gor ingetdera.
      Den trimmar PROVIDER-strangen globalt — exakt som HEAD, for det ar hela
      dess uppgift att vara aterstallningen — och trimmar LAYOUT-strangen inte
      alls, for en trimning dar tar bort en inledande tomrad och forskjuter
      varje radindex. En trimning PER RAD skulle dessutom andra radernas
      innehall, inte bara deras antal. Klausulerna i ③ och steg 3 om "den enda
      trimningen ar per sida" och "trimma per rad" ar darmed OVERSPELADE —
      las den har punkten i stallet.
      **Utvarderingsprotokoll:** OCR-cachen ar nycklad pa bildens hash, inte pa
      flaggan, med 24 h livslangd. Starta om appen (eller rensa OCR-cachen)
      efter att flaggan vants, annars blandar de forsta matningarna strangar
      fran bada lagen vid omimport av samma sida.
      **Not till den som nagonsin normaliserar en x-koordinat mot sidbredden**
      (adresserades till steg 8, som ar avbojt sedan 2026-08-07): adaptern fyller
      aldrig `imageWidth`/`imageHeight` - ML Kit lamnar ingen bildstorlek - sa de
      ar 0, och kvoten blir `Infinity` (eller `NaN` vid noll gap), inte ett
      undantag. Fyll dem, eller dividera aldrig med dem. Star nu ocksa i
      `ACCEPTED_DEVIATIONS.md` under receptet for att gora om matningen.
- [x] Steg 4: carry it on `OCRResult`, cached. KLART 2026-08-07, ihop med steg
      7 - hela beskrivningen star dar nere, inte har, sa den inte hinner saga
      tva saker. Kravet "text och layout maste cachas som EN enhet under EN
      nyckel" ar uppfyllt av formen: cachen lagrade redan hela `OCRResult` under
      en bildhash, sa ett typat falt pa objektet ar automatiskt en enhet med
      texten. Verifierat i koden, inte antaget.
- [x] Steg 5: heading detector.
      KLART, d8d565981 pa main. Tre granskningsrundor, sex fynd, varav fyra
      falska pastaenden fran mig om korpusen.
      `lib/services/import/layout/heading_detector.dart`, pure compute.
      Parametrar redan MATTA, ska inte harledas om: troskel 1,50 x
      brodtextens typstorlek (1,35 hittar fler uppslag men delar sonder
      var fjarde enkelsida - och en felaktig delning ar den dyra, se (1));
      inget tak (matt SAMRE: traff 71 % -> 60 %); inga storleksklasser
      (matt samre: flersides 60 % -> 29-35 %). Textkontrollerna lyfter
      precisionen 32 % -> 62 %. Tom lista nar sidan saknar baslinje ar
      KONTRAKTET - ca en fjardedel av flersidesbilderna avbojer.
- [x] Steg 6a: radantalsjamforelsen pa `DocumentLayout`. KLART 2026-08-06.
      Alla tre granskare namnde den som SAKNAD: kontraktet i
      `text_layout.dart` foreskrev den, men ingen kod implementerade den, sa
      ett rubrikindex adresserade en strang ingen bevisat matchade parserns
      indata. Otrimmad radantalsjamforelse, aldrig bytes.

      **Cachen ar en lucka den HAR grinden inte tacker.** OCR-cachen ar
      nycklad pa bildens hash, inte pa flaggan, sa efter en flaggvandning kan
      ett cachat resultat bara providerText med en layout byggd ur samma
      block. De tva strangarna har oftast SAMMA radantal (de skiljer bara i
      separatorer och den globala trimningen), sa jamforelsen slapper igenom
      en strang indexen inte adresserar. Steg 4 maste cacha text och layout
      som EN enhet under en nyckel; beskriv aldrig den har metoden som
      tackande det fallet. Praktiskt: starta om appen efter en flaggvandning,
      annars mater man fel i upp till 24 timmar.

- [x] Steg 6: `MultiRecipeSplitter.split(input, {layout})`. KLART 2026-08-07.
      Checklistan fran steg 5: (a) konverteringen `flat -> textLineIndex` gors
      i SPLITTERN, inte i anroparen - avvikelse fran punkten som skrevs, och
      integrationsgranskaren dömde koden rätt: aritmetiken bor kvar i
      `DocumentLayout`, splittern anropar den bara pa ett objekt den redan
      haller. Att skjuta den till anroparen skulle tvinga bade
      `import_manager` och `photo_import_viewmodel` att kalla `HeadingDetector`
      och harleda forvillkoret var for sig. (b) forvillkoret ar inkopplat.
      (c) `_isCompleteRecipeBlock` anvands INTE pa layoutblock; ersatt av
      `_minLayoutBlockChars = 200` + instruktionssignal. (d) tvasidesfixturen
      finns, och den ar skriven sa att sidseparatorns radskift faktiskt syns.

      **Tre granskare gav samma blockerande fynd:** ett block som underkands
      SLANGDES tyst. En 61 tecken lang titel rackte for att skeppa tva sakra
      recept och ata ett tredje - alltsa ett SAMRE svar an textvagen, som
      lamnar sidan hel. Lost med en kastbudget: allt fore forsta rubriken plus
      varje underkant block raknas, och nar summan nar `_minLayoutBlockChars`
      avbojer hela vagen. Blockstaket ar nu PER SIDA (5 foton x 2 recept ar
      inte brus).

- [x] Steg 6b: matningen av den SKEPPADE koden pa riktig geometri. 2026-08-07.
      `tools/corpus_split_eval.dart --layout` kor bada armarna pa EN strang
      (layoutens egen text), sa skillnaden ar geometrin och inget annat.
      Planens simulering lovade 91 %/40 %; koden matte forst 86 %/29 % och
      slog sonder 8 fungerande sidor. Tva rotorsaker, bada atgardade:

      1. **Komponentrubriker** ("Topping", "Vaniljglass", "TUSENBLADSTARTA")
         ar storre an brodtext och oppnade falska recept. Ny
         `HeadingDetector.titleSizeSpread` = 1.10: en kandidat maste ligga
         inom 10 % av sidans STORSTA rubrik.
      2. **Radhojd matte alfabetet, inte grader.** En ordruta ritas runt
         black: `Provensalska agg` (nedhang + prickar) matte 166,5 medan
         syskonrubriken `Fransk omelett` matte 129 i SAMMA grad. Ny
         `lib/services/ocr/glyph_metrics.dart` delar bort de zonerna.
         Nedhangsdjupet svepptes: 0,30-0,35 ar ett platt optimum, 0,32 valt.

      **Tva granskare hittade samma bugg i min egen normalisering, oberoende
      av varandra, och en hittade en till.** (1) Ett VERSALT P/G/J/Q/Y raknades
      som nedhang, sa varje `Potatis`, `Gradde` och `GRYTA` matte 18 % for
      kort - exakt den defekt filen skrevs for att ta bort. (2) Ett ord utan
      nagon vanlig x-hojdsbokstav (`Kott`, `latt`, `Kal`) tappade x-bandet helt
      och matte 2,2 ganger for hogt. Ingen av dem syntes i 1087 grona tester,
      for det fanns inget test som korde `glyphSpan` direkt. Det finns nu
      (`test/unit/services/ocr/glyph_metrics_test.dart`), och bada buggarna
      rodnar under mutation.

      Efter rattningen svepptes nedhangsdjupet OM (den gamla platan var matt
      pa fel aritmetik): 0,32-0,38 ar platt, 0,35 valt som mittpunkt.

      **Matt slutresultat (proxysiffror - Windows offline-OCR, inte ML Kit):**
      enstaka sidor 92 % -> **92 %** (ingen forsamring alls), uppslag 19 % ->
      **33 %**, recept som aldrig kommer fram 47 -> **39**, falska extrablock
      14 -> **13** (alltsa FARRE an textvagen ensam). 7 sidor lagade, **0
      sonder**. Textvagen orord: 92 % / 25 % / 46.

      **Kvar mot planens mal:** flersides skulle na 40 %. Det gor den inte.
      Simuleringen var optimistisk. Det djarvare `titleSizeSpread = 1.15` ger
      35 % men klipper en fungerande sida i tva - en produktavvagning, en
      konstant bort, ligger i kodens tabell.

      **Kand miss, inskriven i testet:** sidan som hela funktionen designades
      mot delas fortfarande INTE. Dess tva rubriker ar satta i samma grad, men
      ordrutan runt `Provensalska` (12 tecken) vaxer med bredden pa en lutande
      rad medan `agg` (3 tecken) knappt paverkas. Glyfer var alltsa bara halva
      felet; resten ar skevhet. Tre radskattare mattes - median, max och min -
      och medianen vinner pa varje axel.
      **OVERSPELAD klausul:** har stod "den ratta fixen hor till spaltordningen
      (steg 8)". Det var ett pastaende utan matning. Steg 8 matte bade
      spaltordning och skevhetskorrigering och bada foll - las steg 8 i stallet.

      **Kand kostnad:** en kapitelrubrik satt langt over rattrubrikerna trycker
      ner dem under golvet, sa den sidan faller till textreglerna. Natto
      positivt (5 sidor raddade, 9 farre falska block, mot 5 recept som inte
      kommer fram).

- [~] Steg 6c: helhetsgranskningen fore push (2026-08-07). Den las HELA
      andringen pa en gang - de tidigare granskarna hade sett den i tva halvor -
      och hittade precis den sortens fel som bara den kan se:

      **`OcrLine.typeHeight` returnerar TVA OLIKA SKALOR och detektorn jamfor
      dem med varandra.** Med ordrutor ar vardet normaliserat (x-hojdsenheter);
      utan ordrutor faller det tillbaka pa radens rata ruta, som ligger pa en
      helt annan skala. Hur mycket, och vad som racker for att passera
      storleksgransen, star i `glyphSpan`s dokumentation och avsiktligt ingen
      annanstans - siffrorna skrevs ut pa fem stallen och tre av kopiorna blev
      fel inom en och samma andring, inklusive den har raden.

      Elementbortfall sker PER RAD - adaptern mappar varje rads element for sig
      - sa en och samma sida kan bara bada sorterna. Appens egen mlkit-test
      iscensatter redan den formen.

      Foljden ar tyst och gar at fel hall: raden blir en falsk rubrik, den kan
      hoja `tallest` sa att riktiga rubriker faller under golvet, och den hojer
      brodtextens baslinje. Det motsager splitterns egen invariant ("faller
      alltid mot textvagen, aldrig mot en felaktig delning"). Korpusen kan
      aldrig se det - varje lagrad fangst har ordrutor, sa alla siffror i den
      har planen ar matta pa fall dar buggen inte finns.

      **Atgard:** `OcrLine.hasMeasuredWords`; bade `bodyTypeHeight` och
      `HeadingDetector.headingLines` vagrar rader utan ordrutor, samma regel som
      "en omatt rad ar en franvaro, inte en nolla" redan sager en niva upp.

- [x] Steg 4 + 7: bar layouten fran OCR-sommen hela vagen till uppdelaren.
      KLART 2026-08-07, 248481c83 pa main. Fem granskningsrundor.
      Kartlagt 2026-08-07 innan en rad skrevs. Vagen ar sex hopp:

      1. `OCRResult` far ett TYPAT falt `PageLayout? layout` (aldrig i
         `metadata` - den rinner ut i felsokningsdumpar och en per-rad-geometri
         dar skulle blasa upp varje sadan dump). 5 konstruktoranrop i `lib/`,
         3 i `test/`; faltet ar valfritt sa inget annat behover roras.
      2. **Cachen ar redan EN enhet.** `_cache[imageHash] = result` lagrar hela
         `OCRResult`-objektet under en nyckel (24 h TTL, 100 poster). Sa fort
         faltet finns pa objektet cachas text och layout ihop - den lucka
         `matchesLineCountOf` uttryckligen sager att steg 4 maste stanga ar
         alltsa stangd av formen, inte av ny kod. Verifierat, inte antaget.
      3. Nivan-0-blocket slutar slanga `raw.layout`. Bara nar flaggan ar pa -
         med flaggan av ar faltet null och allt beter sig som idag.
      4. `_PhotoPage` far `layout`; `_ocrAppendOne` skickar med den.
      5. `_recombineAndParse` bygger `DocumentLayout` av sidorna i SAMMA ordning
         och med samma separator (`'\n\n'`) som strangen.
      6. `_autoParseOcrText` och `ImportManager.autoParseMulti` far en valfri
         `DocumentLayout?` som nar `split` pa import_manager.dart:609.

      **Radantalet stammer, och det ar hela poangen.** Med flaggan pa ar
      `OCRResult.text` redan layoutens egen strang (`raw.layoutText`), och det
      enda som hander med den efterat ar sanering, som bevarar radbrytningar.
      Sa sidans text och sidans layout har samma radantal, och darmed hela
      dokumentet - `matchesLineCountOf` slapper igenom.

      **Fail-closed pa blandade nivaer kraver ingen ny kod:** en sida som gick
      till en betald niva har `layout: null`, `DocumentLayout.isComplete` blir
      falskt, `text` blir null och forvillkoret avbojer. Utkastaterstallning och
      handskriftsvagen bygger ocksa sidor utan layout och faller darfor till
      textreglerna - inskrivet i koden, inte upptackt senare.


- [x] Steg 8: column ordering — MATT OCH AVBOJT 2026-08-07. Planen sa "may
      prove unnecessary"; matningen sager starkare an sa: den kostar mer an den
      ger.

      **Spaltordning (PROXYSIFFROR - Windows offline-OCR, inte ML Kit. ML Kits
      egen blockordning ar OMATT och kraver en telefon; beslutet vilar inte pa
      den.)** Av 208 sidor med >=8 rader ar 134 tvaspaltiga, och 49 av dem
      (37 %) kommer ut interfolierade i DEN motorns ordning - lasordningen ar
      alltsa inte gratis for atminstone en riktig lasare. Men en sorterare som
      lagger vanster spalt fore hoger skriver om texten pa tva av tre
      korpussidor (116 av 181) och ger: ratt blockantal 139 mot 138, recept som
      aldrig kommer fram 39 mot 39, fem sidor lagade och fyra sonder. Netto en
      sida, brus - for en andring som nodvandigtvis ror minst 68 enkelsidor
      (bara 48 av de 181 bar mer an ETT recept), alltsa precis den population planen var
      grindad pa att inte forsamra. Precis den avvagning planen sa
      var den farliga. Och skulle ML Kit visa sig sortera ratt av sig sjalv
      blir argumentet svagare, inte starkare: vinsten krymper mot noll medan
      risken att rora om pa en redan korrekt sida star kvar.

      **Deskew (min egen ide, inte planens - samma proxysiffror).** Rutan runt
      ett LUTANDE ord vaxer med ordets bredd; anpassar man radens ordhojder mot
      bredderna och tar skarningen far man en breddfri hojd. Matt: 136 av 181
      mot 138, 42 forlorade recept mot 39, 0 lagade och 2 sonder. Samre. Inom
      en rad ar spridningen oftast forsumbar (median 1,02 over 6 280 prov), sa
      anpassningen ar mest brus. Om en ANNAN skattare skulle funka ar otestat.

      **Foljd:** korpussidan funktionen designades mot delas fortfarande inte,
      och det finns ingen kand billig fix. Inskrivet i
      `heading_detector_test`, inte bortstadat.

      Noterat av granskningen av steg 7 och medvetet INTE atgardat dar: de tva
      viewmodel-sviterna har byte-identiska fixturbyggare (`row`/`body`/
      `spread`) som kodar detektorns levande troskelvarden. Flyttas
      `titleSizeSpread` eller `_minLayoutBlockChars` uppdateras sannolikt bara
      den ena och den andra blir tyst tandlos. En delad fixtur har sin egen
      kopplingskostnad; valet ar att lamna dem och skriva ner risken har.

      Ocksa noterat och medvetet uppskjutet: ett aterstallt utkast tappar
      delningen (sidan far ingen geometri). Att kora om `extractText` vid
      restore racker INTE - utkastschemat lagrar en enda bild, sa sidorna 2..N
      kan aldrig fa tillbaka sin geometri och dokumentet avbojer anda. Riktig
      fix ar en schemaandring, och just nar ett utkast behovs (processen dog)
      ar OCR-cachen tom, sa omkorningen kan bli ett BETALT anrop. Eget arende.

- [x] Steg 9: kantbeskarningen (`lib/services/ocr/edge_crop.dart`). KLART,
      d034c5ece pa main. Slapper grannsidans remsa vid bildkanten.

- [x] Steg 10: `withoutOrphanTail` — den foraldralosa svansrubriken.
      Godkand av Malin 2026-08-09 efter en fall-for-fall-granskning MOT BILDERNA.
      Planens andra halva ligger i `tasks/butlery-1816-orphan-tail-plan.md`.

      **Grinden i planens ⑤ stangde: bara `drop`-bandet byggs.** Bandet 120-200
      lamnas som `none` och UI-halvan (`uncertainIndices`, ARB-strangen,
      widget-testet) byggs darfor inte alls, precis som planen foreskrev.

      **De nio svansarna i bandet ar OMLASTA 2026-08-09, mot fotona den har
      gangen.** Verdiktet star, skalet var fel: `Chokladkram` ar ett HELT litet
      recept (titel, tva ingredienser, en not, allt synligt pa sidan) och
      `I stallet for sas` ar en ny avsnittsrubrik med eget stycke och punktlista.
      Ingendera ar en "underrubrik inne i ett recept", som forsta granskningen
      pastod. Ratt skal: **i bandet finns lasbar text under rubriken; under 120
      tecken finns bara sonderklippt skrap.** Teckenbudgeten ar en PROXY for den
      egenskapen — det ar den formuleringen som ska overleva, inte den gamla.

      **Alla tio sidor som regeln ror ar granskade mot bild: 10 av 10 ratt.**
      En tidigare textbaserad granskning sa 8 av 10; den var fel pa bada, och
      Malin fangade det. Tva av de tio ar inte ens ur kokboken — det ar
      baksidestexten pa en annan bok som ligger bakom pa bordet.

- [ ] Steg 11 (NYTT, eget arende): **korpusens facit har ett systematiskt fel.**
      Upptackt 2026-08-09 nar Malin papekade att facitet ar granskat av MIG, inte
      av henne. Halva recept som bildkanten skurit av ar inskrivna som HELA
      recept: 2 av 7 handgranskade sidor, minst 12 av alla 242 verifierade enligt
      en maskinell screening (som bara ser sista meningen och titeln, alltsa ett
      GOLV). Exempel: `Mixade vitaminer` (1 instruktion, avhuggen mitt i),
      `Annas fisks` (titeln sjalv ar avhuggen, 24 instruktioner ur en spalt som
      ligger utanfor bilden), `Dillstuvad potatis` + `Hasselbackspotatis` pa
      samma sida som ett komplett recept.

      **Vad som HALLER:** de recept som ligger helt pa bilden ar korrekt
      avskrivna (inga fel mangder, inga tappade steg), en fyrareceptssida hade
      alla fyra inskrivna, och facitet ar verkligen handrattat — 158 av 158
      jamforbara skiljer sig fran parserns egen gissning, alltsa noll stampling.

      **Vad det gor med siffrorna:** recall BELONAR appen for att behalla
      avskuren text, eftersom facitet pastar att den ar ett riktigt recept.
      Klippet tar bort exakt sadan text och straffas alltsa for att gora ratt —
      de 0,02 procentenheterna "forlorad riktig text" ar OVERDRIVNA, inte
      underskattade. Jamforelser mellan tva varianter (steg 8, enblocksregeln)
      matte samma facit pa bada sidor och star sig; de ABSOLUTA procenttalen ar
      mjukare an de ser ut.

      Atgard: markera varje avskuret fragment med ett eget falt i stallet for att
      radera det, sa kan matningen valja att rakna dem eller inte. Blockerar inte
      steg 10.

---

# Butlery — Plan: låt sidans utseende följa med från kameran

> Ersätter den tidigare planen i den här filen (tid + rubrik). Den planens steg 0–2
> är byggda men **ocommittade** — se "Först: städa bordet" nedan. Steg 3 (rubrikval)
> utgår helt: den här planen löser rubriken på ett bättre sätt.
> Mirror to `tasks/butlery-layout-aware-split-plan.md` on execution;
> `tasks/todo.md` belongs to another session.

## Context

Fotoimporten klarar en receptsida men inte ett uppslag. Mätt över 181
korpussidor med handkontrollerat facit (242 recept):

| | |
|---|---|
| Sidor med **ett** recept, rätt antal block | **91 %** |
| Sidor med **flera** recept, rätt antal block | **25 %** (12 av 48) |
| Recept som aldrig kommer fram | **46** |

Orsaken är inte en trasig regel utan en saknad indata. `MultiRecipeSplitter`
öppnar ett nytt receptblock bara när en rubrikliknande rad följs av en
**ingredienslista** (`_ingredientClusterAhead`, ≥2 måttrader inom 8 rader).
Tratten över de 109 facittitlarna på flersidesuppslagen:

```
109  titlar enligt facit
 73  finns över huvud taget i OCR-texten
 57  godkänns av _isTitleish
 23  har dessutom en ingredienslista inom 8 rader  ← de enda som får öppna block
```

Två separata fel syns i tratten:

1. **15 av de 16 underkända titlarna faller på `looksLikeIngredient`.** Den
   matchar bara ordet — `_ingredientWordPatterns`
   (`recipe_section_detector.dart:381`) innehåller `potatis`, `ägg`, `fisk`,
   `kött`. Så "Dillstuvad potatis" och "Förlorade ägg" klassas som
   ingrediensrader. Splittern har redan en STRIKT måttregex för just den här
   sortens beslut (`multi_recipe_splitter.dart:39`, med en kommentar som
   förklarar varför den lösa inte duger) — men använder ändå den lösa i
   `_isTitleish`.
2. **34 av de 57 godkända titlarna har ingen ingredienslista efter sig.** 36 av
   181 sidor är prosakokböcker där mängderna står i löpande text. Alla 8
   flersidesuppslag i den genren misslyckas, utan undantag.

Signalen som saknas finns redan på enheten. ML Kit returnerar
`RecognizedText.blocks[].lines[].boundingBox` — rad för rad, med höjd och
position. `device_text_recognizer_mlkit.dart:59` gör `recognized.text.trim()`
och slänger allt utom bokstäverna.

**Mätt** (geometri från Windows offline-OCR över alla 250 sidor, enbart som
mätinstrument — se ⑥ för vad det betyder och inte betyder). Radhöjd är
**medianen av ordhöjderna på raden**, för både brödtext och kandidat, så
skevhet i fotot påverkar båda armarna lika:

| regel | rubrikträff | precision |
|---|---|---|
| dagens (`_isTitleish` + ingredienskluster) | 21 % | 22 % |
| radhöjd ≥ 1,35× brödtexten | 81 % | 32 % |
| radhöjd + textkontroller | **71 %** | **62 %** |
| radhöjd + tak (>2,5× = kapitelrubrik) | 60 % | 62 % — **sämre, taket utgår** |
| radhöjd + storleksklasser (bara största/vanligaste klassen) | — | **mätt sämre, se ②** |

## A — Bedömningar

### ① Tröskeln väljs på villkoret "försämrar inte det som fungerar"

Jag simulerade hela den föreslagna uppdelaren mot facit — block*antal*, inte
bara rubrikträff — och mätte **båda** populationerna. K = radhöjdströskel,
minChars = minsta block, verb = blocket måste innehålla ett tillagningsverb:

| inställning | enstaka sidor kvar som en | flersides rätt | recept borta |
|---|---|---|---|
| dagens textregler | 91 % | 25 % | 46 |
| K=1,35 minChars=40 | 63 % | 60 % | 7 |
| K=1,35 minChars=120 verb | 76 % | 58 % | 13 |
| K=1,50 minChars=120 verb | 87 % | 50 % | 17 |
| **K=1,50 minChars=200 verb** | **91 %** | **40 %** | **27** |

- **Föreslaget: sista raden.** Den enda inställningen som bevisligen inte
  försämrar de 129 enstaka sidorna, och den halverar ändå antalet förlorade
  recept. Alla tre trösklarna blir namngivna konstanter.
- **Avvisat: K=1,35**, trots att den är bäst på uppslag. Den delar sönder var
  fjärde enstaka sida.
- **Asymmetrin går åt andra hållet än jag först antog.** Jag trodde en
  felaktig delning var ofarlig eftersom användaren får välja. Den läsningen är
  fel: `batch_import_preview.dart:24` **förkryssar alla** recept i `initState`,
  och widgeten har ingen ihopslagning. En felaktig delning sparar alltså två
  halva recept, båda ikryssade, utan att användaren kan foga ihop dem — tyst
  dataförlust. Ett falskt extra recept är en avbockning; en falsk delning är
  det inte. **Därför optimeras det här mot precision, inte mot täckning.**

### ② Vad kritiken föreslog och mätningen underkände

Två förslag lät bra och visade sig sämre. Båda är körda, inte resonerade bort:

- **Storleksklasser i stället för tak** (rubriker på ett uppslag är satta i
  samma grad; gruppera kandidaterna och släpp bara igenom en klass). Mätt:
  flersides föll från 60 % till 29–35 %. Instrumentets radklippning splittrar
  en rubrik i två olika höjder och förgiftar klasserna. Utgår.
- **Bredare ingredientfönster** (`_lookahead` 8 → 16 i textvägen). Mätt på
  riktig korpustext: rubrikträff 28 % → 38 % (+11 titlar), men falska öppningar
  129 → 215 (+86) — **ungefär åtta falska delningar per räddad titel**, och
  enligt ① är det den dyra feltypen. Utgår.
  *(Ett tidigare utkast skrev "ungefär två". Fel: 86/11 ≈ 8. Slutsatsen står
  kvar, siffran var min, inte mätningens.)*

Kvar från kritiken, adopterat i sin helhet: förvillkoret i ③, saneringslagen i
④, dokumentnivå-fail-closed i ⑤, flaggan och cachen i ⑥.

### ③ Layouten är sanningen, texten härleds — och kontrolleras

Rubrikens radindex måste peka rätt i strängen. Lösningen är inte en `assert`
utan en **jämförelse som faller tillbaka**:

- `DocumentLayout.text` är den ENDA producenten av den sammanfogade strängen
  (`lines.map((l) => l.text).join('\n')`, sidor med `'\n\n'`). Radindex är
  därmed radnummer per definition.
- `MultiRecipeSplitter.split` inleder med ett förvillkor som faller tillbaka:
  stämmer inte layouten med indata, sätts `layout = null` och textvägen
  gäller. Det är planens viktigaste enskilda rad.
- **Jämförelsen är RADANTAL, inte bytes, och ingen av strängarna får
  trimmas först.** Ett tidigare utkast av den här planen skrev
  `layout.text != input` — en byte-jämförelse. Den kan aldrig lyckas:
  `HtmlSanitizer.sanitizeText` normaliserar homoglyfer och tar bort
  styrtecken (men bevarar `
`), så bytesen skiljer sig på friska sidor och
  layoutvägen hade stängts av permanent — vilket ser exakt ut som
  "geometri hjälper inte". Att trimma båda före räkningen är lika fel åt
  andra hållet: den enda trimningen på vägen är PER SIDA och sker före
  hopfogningen (`device_text_recognizer_mlkit:59`;
  `photo_import_viewmodel:709` trimmar aldrig den sammanslagna strängen),
  så en trimmad räkning döljer just den förskjutningen på sida ett och
  varje radnummer blir för lågt. Kontraktet står i `text_layout.dart`.
- Den fångar automatiskt allt som annars skulle spricka tyst: den globala
  `recognized.text.trim()` på `device_text_recognizer_mlkit.dart:59` (som kan
  äta en inledande tomrad och förskjuta varje index — trimma per rad i
  stället), `'\n\n'`-hopfogningen, utkaståterställningen
  (`photo_import_viewmodel.dart:394`) som bara har text, och handskriftsvägen
  som syntetiserar text helt utan layout.

### ④ Saneringen får flytta, och det är bevisbart

`HtmlSanitizer.sanitizeText` (`html_sanitizer.dart:312-325`) gör tre saker:
tar bort `\x00`, byter 18 kyrilliska homoglyfer tecken-för-tecken, och tar bort
kontrolltecken med klassen `[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]`. **Den klassen
utesluter `\x09`, `\x0A` och `\x0D`** (verifierat i källan, inte antaget). Alla
18 homoglyfnycklar är enstaka tecken och alla värden är enstaka ASCII-bokstäver.

Alltså gäller `sanitize(a + b) == sanitize(a) + sanitize(b)`, och därmed
`sanitize(lines.join('\n')) == lines.map(sanitize).join('\n')`, byte för byte.
Saneringen kan flytta till radnivå **utan beteendeändring**, och likheten
skrivs som ett egenskapstest — inte som en kommentar. (Lagen gäller på
RAD-nivå: saneringen kan korta eller tömma en rad, så teckenoffsets får aldrig
bäras vidare, bara radindex.)

### ⑤ Flera foton blir EN text — fail-closed på dokumentnivå

`photo_import_viewmodel.dart:709` gör `_pages.map((p) => p.text).join('\n\n')`.

- `DocumentLayout { List<PageLayout?> pages }` — brödtexthöjd beräknas **per
  sida** (olika avstånd, zoom och beskärning), aldrig över dokumentet.
- **Saknar någon sida layout → hela dokumentet faller till textreglerna.** Den
  avgörande anledningen är att `_recombineAndParse` körs om vid **varje ny
  sida**: med en delvis regel skulle ett andra foto som råkar gå till en betald
  nivå tyst fälla ihop väljaren från två recept till ett mitt i flödet.
  Fail-closed gör det i stället deterministiskt och förklarligt.
- `_recordUsage('layout_mixed_tier')` så att en framtida uppmjukning kan
  motiveras med data i stället för argument.

### ⑥ Vad som inte kan bevisas här, och hur risken bärs

Alla siffror kommer från Windows offline-OCR. Produktionen använder ML Kit på
en **förbehandlad** bild (`preprocessImageForOcr` — orientering, nedskalning
till 2048 px, gråskala, kontrast, **ingen skevhetsrättning**). Det som inte är
mätt: om 1,50 är rätt konstant för ML Kits lådor, hur ML Kit grupperar rader i
en tvåspaltig uppslagning, och om `boundingBox` är tillförlitligt ifylld på iOS.

- **Risken bärs av en flagga, inte av en förhoppning.**
  `enable_layout_recipe_split`, default `false`, oberoende av
  `enable_on_device_ocr`. Trösklarna läses via Remote Config så de kan
  justeras utan release.
- **Avvisat: kräva en enhetsinsamling av geometri för alla 250 sidor som
  go/no-go.** Det vore mest korrekt, men kostar en felsökningsskärm och att
  Malin kör 250 foton genom telefonen. Flaggan ger samma skydd till en
  bråkdel av kostnaden. Insamlingen kan komma senare om flaggan visar problem.
- Saknad `boundingBox` behandlas som "ingen geometri för sidan" → fail-closed.

- **Ungefär en fjärdedel av måltavlan kommer aldrig att nå layoutvägen, och
  det är kontraktet som fungerar — inte ett fel.** Mätt över de 250 lagrade
  mätningarna avböjer `bodyTypeHeight` på 53 sidor, varav **22 av 92** sidor
  som bär mer än ett recept: för få mätta brödtextrader för att en baslinje
  ska betyda något. De faller till textvägen. Det sätter taket för steg 6:s
  flersidessiffra I FÖRVÄG, så ett nedslående resultat får INTE läsas som
  "K=1,50 är fel konstant".

- **KORPUSENS EGEN TEXT OCH GEOMETRI KOMMER FRÅN OLIKA MOTORER, och det gör
  planens grind omöjlig som den står.** `ocr.txt` är OCR.space (se
  `ocr.meta.json`), `layout-winocr.json` är Windows offline-OCR. Mätt över de
  247 parade sidorna: **0 av 247** är byte-identiska, **34 av 247** har ens
  samma radantal, och att mata WinOCR-texten till dagens splitter i stället för
  `ocr.txt` flyttar blockantalet på **12 av 133** verifierade sidor på egen
  hand. `tools/corpus_split_eval.dart` matar `ocr.txt`, så förvillkoret i ③
  (`layout.text != input` ⇒ layout = null) nollar layouten på VARJE korpussida:
  grinden "flersides ≥ 40 % mätt med corpus_split_eval" skulle rapportera noll
  effekt oavsett hur bra layoutvägen är, och läsas som "geometri hjälper inte".
  **Från steg 6 matar harnesset `layout.text`, inte `ocr.txt`** — och då är
  dagens nollmätning (single 122/133, multi 12/48) tagen på FEL text och måste
  köras om på WinOCR-texten innan något ≥91 % / ≥40 % läses. Grinden gäller mot
  den omkörda nollmätningen, aldrig mot den gamla.

### ⑦ Spaltordningen skiljs ut helt

> **AVBÖJD 2026-08-07.** Steg 8 mätte den och den betalar inte — se steg 8 i
> checklistan ovan och `docs/architecture/ACCEPTED_DEVIATIONS.md`. Texten nedan
> står kvar som record över vad som skulle kontrolleras, inte som byggorder.

Att sortera spalter ändrar texten för **varje** on-device-import, även de
enstaka sidor som ligger på 91 %. Det är den enda delen som kan försämra en
fungerande väg, och den syns inte i någon av mätningarna ovan.

- Eget commit, efter att 1–6 landat och mätts.
- **Den kan visa sig onödig:** ML Kit grupperar redan i `TextBlock`, så en
  tvåspaltig uppslagning kan mycket väl komma ut spaltvis redan. Kontrolleras
  mot riktig geometri innan en enda rad skrivs.
- När den byggs: **identitet som default** — ordnaren får bara röra sig när
  radernas x-intervall delar sig i ≥2 tydliga grupper, och två egenskapstester
  gäller (utdata är en permutation av indata; utdata är identisk med indata när
  ingen spaltstruktur hittas).
- Tier 0:s acceptgrind påverkas inte: `_calculateConfidenceFromText` och
  `RecipeTextHeuristic.looksLikeRecipe` är båda okänsliga för radordning.
- Bildutklipp i väljaren ligger utanför planen — koordinaterna är i
  förbehandlad rymd och de bytesen sparas inte.

## B — Byggordning

**Först: städa bordet.** Tidsutläsningen är byggd men ocommittad och orelaterad.
**En parallell session har ~40 filer STAGADE i samma checkout** (recept-delning
/ `grants`), så indexet får inte svepas. Committa med explicit pathspec, i
samma Bash-anrop, exakt dessa fyra:
`lib/services/import/parsers/recipe_time_extractor.dart` (ny),
`lib/services/import/parsers/text_import_normalizer.dart`,
`lib/services/import/text_import_strategy.dart`,
`test/corpus/corpus_prelabel_test.dart`. Aldrig `git add .` / `-A`
(`.claude/rules/git-workflow.md` § Parallel sessions).

**0. Mätverktyget först.** `tools/corpus_split_eval.dart` (se C) byggs innan
något ändras, annars finns ingen nollmätning att jämföra med. Det är också
verktyget varje senare steg grindas mot.

**1. Strikt rubrikfilter i textvägen — ensamt och grindat.**
`multi_recipe_splitter.dart:120` byter `RecipeSectionDetector.looksLikeIngredient(t)`
mot filens egen `_measurement`. Ett titelfilter behöver inte "nämner mat", det
behöver "bär en mängd". Mätt på rubriknivå: träff 21 → 28 % (+7 titlar), falska
öppningar 105 → 129 (+24) — **~3,4 falska per räddad titel**, alltså samma sorts
avvägning som ② avvisar, bara mildare.
**Därför landar steget bara om `corpus_split_eval` visar enstaka sidor ≥ 91 %
OCH inte fler förlorade recept än idag.** Rubrikträffen är en proxy; blockantalet
är beslutskriteriet enligt ①. Faller det, kastas steget — det ligger utanför
`enable_layout_recipe_split` och når webben och de betalda nivåerna, så det får
inte skeppas på en proxysiffra. `_lookahead` rörs INTE (②).
`recipe_section_detector.dart` rörs inte alls — 502 rader, står som
"the single audited heading/ingredient safety hinge".

**2. Sidmodell som rena, serialiserbara värdetyper.**
Ny `lib/services/ocr/text_layout.dart`: `LayoutBox {left, top, width, height}`,
`OcrWord`, `OcrLine`, `PageLayout`, `DocumentLayout`, med `toJson`/`fromJson`.
**Ingen `dart:ui`-`Rect`** — konvertering sker bara inne i ML Kit-adaptern, så
allt ovanför kan köras under vanlig `dart test`. JSON-formatet är kontraktet
mot `tools/`, som förblir Flutter-fritt (`tools/corpus/corpus_models.dart`
kräver det).

**3. Bredda sömmen.**
`DeviceTextRecognizer.recognize` returnerar `RecognitionResult { String text,
PageLayout? layout }` — **ett** anrop, en temp-fil, ett felläge. Kontraktet
"null = fall igenom, kasta aldrig" står kvar ordagrant. Trimning per rad, inte
globalt. Stubben returnerar `layout: null`.

**4. `OCRResult` bär layouten.**
Nytt typat fält `final PageLayout? layout` — inte en nyckel i `metadata`, och
inte bara för snyggheten: `metadata` rinner ut i felsöknings- och analysdumpar,
och en per-rad-geometriklump där skulle blåsa upp varje sådan dump.
*(Ett tidigare utkast skrev "och i en GDPR-export". Det är fel — inget
OCR-fält finns i `lib/services/account/export/*`, och `OCRResult` har inget
`toJson` idag. Rättat innan det hann bli en kodkommentar.)*
Layouten hålls utanför loggning. **Den måste cachas**: `_cache` håller hela
`OCRResult` i 24 h, så utan fältet skulle samma foto delas första gången och
inte andra. ~6 kB/sida × 100 poster ≈ 600 kB, acceptabelt och noterat.

**5. Rubrikdetektorn.**
Ny `lib/services/import/layout/heading_detector.dart` — ren beräkning, ingen
`BaseService` (samma kategori som `ingredient_categorizer.dart`; läggs till i
listan i `lib/services/CLAUDE.md`). Brödtexthöjd = median över rader med ≥4 ord
av radens ordhöjdsmedian; rubrik = ≥ K × den, plus textkontrollerna (längd
3–60, 1–8 ord, ingen inledande siffra, ingen avslutande `:` `,` `.`, ingen
måttangivelse, versal inledning). **Inget tak, inga storleksklasser** — båda
mätta sämre.

**6. Uppdelaren tar emot layouten.**
`split(String input, {DocumentLayout? layout})`, med förvillkoret från ③.
Med layout: gränser = rubrikrader; ett block överlever på `minChars` **plus**
ett instruktionstecken via befintliga `_isInstructional`; högst 8 block och
minst 4 icke-tomma rader mellan två gränser. Faller något av det: **textvägen**,
inte ett stup. `_isCompleteRecipeBlock` används INTE på layoutblock — den
kräver ingredienser *och* instruktioner, vilket prosarecept aldrig har.
Returkontraktet "aldrig färre än `[input]`" är filens mest värdefulla egenskap
och rörs inte.

**7. Trådning genom vyn.** `_PhotoPage` får `layout`; `_ocrAppendOne` behåller
ett värde till; `_recombineAndParse` bygger sträng och `DocumentLayout` i samma
loop; `autoParseMulti` får en `DocumentLayout?`-parameter till `split` på :609.
Utkastet bär bara text — efter navigering bort och tillbaka gäller textvägen.
Det skrivs i koden, och om det visar sig irriterande blir det ett eget ärende.

**8. Spaltordning — MÄTT OCH AVBÖJD 2026-08-07, ingen kod skrevs.** Se steg 8 i
checklistan och `ACCEPTED_DEVIATIONS.md`. ⑦ står kvar som record.

## C — Mekaniskt

Enhetstester bredvid varje ny fil, fixturer byggda från riktiga korpussidor.
Ny `tools/corpus_split_eval.dart` (mönster från `tools/corpus_eval.dart`,
återanvänder `tools/corpus/corpus_paths.dart`, som får en `ocrLayout()` bredvid
befintliga `ocrMeta()`). Den läser `layout-winocr.json` — 250 geometrifångster
ligger redan sparade bredvid sidorna — och rapporterar blockantal mot facit,
**uppdelat på enstaka och flersides**. Det är mätvärdet planen styrs av.

**Stakeholder-router**, faktisk utdata:

```
$ python tools/stakeholder_router.py --json lib/services/ocr/device_text_recognizer.dart \
    lib/services/ocr/device_text_recognizer_mlkit.dart lib/services/ocr_extraction_service.dart \
    lib/services/import/multi_recipe_splitter.dart lib/services/import/import_manager.dart
{"tier": "single", "panel": ["Data / Integrations Engineer",
 "Financial Controller / FinOps", "Monetization / Subscriptions Lead"], "high_stakes_hits": []}
```

Tier `single`, ingen panel. FinOps-träffen gäller importvägens kostnadsyta —
noll nätanrop, noll modellanrop, all beräkning på enheten. Noterat, inte hoppat
över.

**Filstorlek:** `ocr_extraction_service.dart` (1169), `import_manager.dart`
(1077) och `photo_import_viewmodel.dart` (827) står i `ACCEPTED_LARGE_FILES.md`
med **inaktuella radtal** (1142 / 888 / 647). Raderna uppdateras i samma commit
som filen växer. `multi_recipe_splitter.dart` är 192 rader.

## Verifiering

- `flutter analyze --fatal-infos` rent.
- **Egenskapstest:** `sanitize(join) == join(map(sanitize))` över genererade
  strängar med `\n`, `\t`, kyrilliska homoglyfer och kontrolltecken (④).
- **Förvillkoret:** en layout vars RADANTAL inte stämmer med indatas ⇒ exakt
  dagens blockresultat (③). Testet får inte skrivas som en byte-jämförelse.
- Rubrikdetektorn mot tre fixturer: ett riktigt uppslag, en prosasida, en
  brussida.
- Sömadaptern mot en fejkad ML Kit-retur; `OCRExtractionService` har redan
  `testDeviceRecognizer` och ett `_FakeDeviceRecognizer` att bygga på.
- Sammanslagning av två sidors layout, inklusive fallet "en sida saknar layout
  ⇒ hela dokumentet till textvägen" (⑤).
- **Negativa test som är själva poängen:** layout = null ⇒ byte-identiskt med
  dagens; en sida med en enda rubrik ⇒ ett block; en sida där layoutvägen ger
  9 block ⇒ fallback, inte 9 recept. Minst ett av dem mutationstestas (ta bort
  tröskeln, se testet rodna, återställ).
- `test/services/import/multi_recipe_splitter_test.dart` och
  `import_manager_multi_test.dart` gröna **oförändrade** — de beskriver
  textvägen, som inte får röra sig.
- `dart run tools/corpus_split_eval.dart` före och efter varje steg. Mål,
  mätt: **enstaka sidor ≥ 91 %** (ingen försämring) och **flersides ≥ 40 %**
  från dagens 25 %. Varje siffra i commit-meddelandet — och **märkt som
  proxysiffror**: de är mätta på Windows offline-OCR, inte på ML Kit, så de
  säger vad algoritmen gör, inte vad telefonen gör (⑥, och lärdomen
  "mät appens egen väg, inte ett skalverktygs").
- **Arbetsflödeskartan.** `docs/onboarding/workflow-map.html` refererar
  `photo_import_viewmodel.dart`, `multi_recipe_splitter.dart` och
  `ocr_extraction_service.dart` — alla tre ändras här, så haken stämplar
  `workflow-map.stale` och CI grindar på flödestäckning
  (`CLAUDE.md` § Workflow map freshness). Spåra om de fotoimportflöden markören
  namnger, uppdatera kartans `<script id="data">`-JSON och inget annat, kör
  lintern, radera markören, committa båda. (En markör från den parallella
  sessionen ligger redan på disk — den är inte min.)

## Open questions — Öppna frågor

No architecture-changing unknowns. Formen är bestämd: sömmen breddas, layouten
är sanningen och texten härleds ur den, degraderingen är layout → textregler →
`[input]`, och hela vägen ligger bakom `enable_layout_recipe_split`. Inget av
det nedan kan ändra den formen — de är mätrisker som bärs av flaggan och av
Remote-Config-trösklarna, inte av ett val Malin behöver göra nu. Antagandena,
i fallande ordning efter spännvidd:

1. **ML Kits geometri är omätt** — tröskel, radgruppering på tvåspaltiga
   uppslag, och iOS-lådor. Bärs av flaggan och Remote-Config-trösklarna (⑥),
   inte av en förhoppning.
2. **33 % av facittitlarna saknas i OCR-texten** över huvud taget. Layouten kan
   inte lyfta det taket. Egen fråga, inte den här planens.
3. **Facit räknar inte alltid varianträtter som egna recept** ("Med örter" är
   en riktig rubrik i boken). En del av det som mäts som överdelning är alltså
   facit, inte kod. Inte utrett.
4. **Nivå 0 måste vinna** för att geometrin ska finnas. Faller den fria
   avläsningen på konfidensgrinden går importen till en betald nivå utan
   geometri. Ingen försämring, men ingen vinst heller — just där bilden var
   svårläst.
5. **Bara latinsk skrift.** Samma avgränsning som nivå 0 redan har.

## Vad det betyder på vanlig svenska

- Fotografera ett kokboksuppslag med flera rätter och få flera recept i stället
  för ett hopkok. Mätt: från 1 sida av 4 rätt till 2 av 5, och antalet recept
  som helt försvinner nästan halveras.
- Enstaka receptsidor, som fungerar idag, rör sig inte ur fläcken. Det är
  villkoret jag valde tröskeln efter.
- Prosakokböcker, där mängderna står i löpande text, kan delas för första
  gången. Idag misslyckas de alla.
- Jag hittade en sak jag hade fel om: när appen delar ett recept i två av
  misstag kryssas **båda** i automatiskt och du kan inte foga ihop dem igen. Det
  gjorde att jag valde en försiktigare inställning än jag först tänkt.
- Ingen ny kostnad. Allt räknas på telefonen, inget nätanrop, ingen språkmodell.
- Det hela ligger bakom en avstängningsknapp tills det är provat på din telefon.
- Väljaren som visar "vi hittade tre recept" finns redan i appen — den får
  äntligen något att visa.
- Vad jag behöver av dig: ingenting nu. När det är byggt vill jag att du
  fotograferar ett par uppslag så vi ser om siffrorna håller på riktig telefon.
- **Om du hellre vill ha det djärvare:** säg "kör 1,35" — då blir 3 uppslag av 5
  rätt i stället för 2, men var fjärde vanlig receptsida delas i två av misstag.
  Jag valde bort det, men det är en siffra och den kan bytas.


==============================================================================
# PRIOR EXECUTION RECORD — BUT-1797 (completed, merged to main 2026-08-05)
==============================================================================

# IN EXECUTION 2026-08-04 — BUT-1797: group sharing that can actually be revoked

Approved by Malin ("go with this", 2026-08-04, selecting the recommendation to
reconcile Linear then start BUT-1797). The three product calls it rests on were
decided by her on 2026-08-03 and are settled. Full plan below, verbatim from
`tasks/archive/butlery-group-share-revoke-plan.md`. Prior execution records are
preserved below the separator.

## REVIEW-FIX ROUND — 2026-08-04, after 19 commit-gate reviewers

The gate ran and FAILED. Nineteen reviewers across three specialists read the 30-file
staged set; the findings below are the ones multiple agents reached independently. This
section is the plan for the fix round, written before touching code.

### Blocking — must fix

1. **`recipe_member_manager.dart:388-396` — `updateMemberPermission` wipes `grants`.**
   Found independently by SIX reviewers. Three of the four `RecipeSocialData` rebuilds in
   that file carry `grants`; the fourth enumerates seven of eight fields and drops it. The
   document is written whole, so the field is DELETED, not left unchanged. After any
   permission change, `revokeGroup` takes its `grants == null` early return, cuts nobody,
   and still returns true — the panel then shows "har inte längre åtkomst". A privacy
   control reporting success while revoking nothing is the exact thing this ticket exists
   to end. Latent (no view calls it today) but it is live public API.
   **Fix:** rebuild via `copyWith`, which cannot drop a field it never enumerates.

2. **`social_recipe_membership_service.dart:69-73, 107-111` — a THIRD membership path,
   untaught.** Found by four reviewers. `addMemberToRecipe` grants access recording no
   grant; `removeMemberFromRecipe` drops the permission and leaves a stale grant. The first
   makes a group revoke CUT someone who also holds a direct share — the outcome Malin's
   decision #2 forbids. The second makes a later revoke count a ghost and re-notify someone
   already removed. This is the twin-class lesson a second time: the SHARE twin was found
   and fixed, the MEMBERSHIP twin was missed.
   **Fix:** route both through `RecipeShareGrants.add` / `.dropMember`.

3. **`_grantAccessOnReshare` has zero assertions.** The test file declares `savedRecipes`,
   fills it from the new seam, and never reads it. So the whole re-share half of this ticket
   could be deleted with every suite green — it fails the repo's revert-and-watch-it-redden
   rule outright.
   **Fix:** assert the granted permission and the recorded grant, direct and group.

4. **A vacuous test I wrote.** `SNAPSHOT: someone who joined the group after the share is
   untouched` asserts the absence of a uid that was in neither input map. `revokeGroup` is a
   pure filter over those maps; no mutation can make it invent a key. Two tautologies plus a
   duplicate assertion. The snapshot property belongs to the SHARE path and is already
   genuinely proven there.
   **Fix:** replace with the case that is covered nowhere — a non-owner in
   `memberPermissions` with no `grants` entry must survive a revoke.

5. **A false comment I wrote,** on the widget test: it claims the assertion catches "a
   revert of the code without the copy, or the copy without the code". It catches only the
   second — the test opens the dialog and never confirms it, so `removeGroup` is never
   invoked. Fix the claim to what it actually pins.

6. **Stale comment at `unified_recipe_service.dart:410-411`,** the load-bearing record of
   BUT-1785: it says the seam has exactly one consumer. As of this change it has two.

7. **Swedish copy.** `behåller sin` strands the possessive with no head noun; `Den du även
   delat med` is singular where several people can hold a direct share; `{name}s` breaks on
   group names ending in s/x/z. Malin reads Swedish natively — this is not cosmetic.

8. **The confirm dialog does not carry the carve-out its own comment claims.** Either move
   the caveat into the confirm copy or correct the comment. Reviewers split on which; the
   copy fix is the honest one, since the file's own argument is that a post-hoc snackbar
   cannot undo a promise made at the decision point.

### Deliberately NOT fixed in this round — recorded, not silently dropped

- **`realtime/recipe_serialization.dart:292-307`** — the second, hand-rolled
  `RecipeSocialData` deserializer never learned `grants`. It also already mis-reads
  `descriptionCollaborative`. No live path round-trips a collaborative recipe through it, so
  this is latent drift, not a shipped bug. Ticket it.
- **Revoke does not trim `shared_content.sharedToUserIds`** — a revoked member keeps the
  discovery row (title, description, image) and its Art. 15 export line. Pre-existing for
  `removeMember`; this ticket makes it more visible because the copy now promises a
  revocation. Needs its own ticket and probably its own decision.
- **`grants` rides into `shared_recipes` snapshots**, exposing the uid→group mapping to
  recipients. Needs a security ruling, not a unilateral fix.
- **Three writers grant `memberPermissions` with no grant entry**
  (`firebase_recipe_repository`, `collaboration_management_module`, and the membership
  service's add — the last is fixed above). No UI reaches the other two.
- **The group-share success snackbar says "0 recept delade"** — `clearSelections()` runs
  before the count is read. Pre-existing, unrelated to provenance, real.
- **Three copies of the (memberIds, groupIds) → tokens loop.** They agree today. Collapsing
  them into `RecipeShareGrants` is right, but it is a refactor across four files and belongs
  in its own change, not in a fix round for a failed gate.

### Verification for this round

Re-run the three specialists on every file the fixes touch — a fix round is the
least-reviewed code in a change. Re-run the touched suites plus the full unit lane. Mutation
-prove finding 1: revert the `copyWith`, confirm the new test reddens, restore byte-identical.

---

# Plan: group sharing that can actually be revoked (BUT-1797)

**Status: written 2026-08-03, not started. Needs plan-mode approval before any code.**

## Context

Sharing a recipe "with a group" is half-built and does nothing a user can rely on.

The UI offers it, and `shareRecipe` takes a `categoryIds` argument — but every path funnels
into `UnifiedRecipeService.createCollaborativeRecipe`, which accepts the parameter and never
forwards it (`unified_recipe_service.dart:786` → `:788`, where `_socialModule.createCollaborativeRecipe`
has no such field). Nothing else in `lib/` writes `socialData.categoryIds`; the only other
mentions are the model and its serializer. So:

- the "Grupper" section in the sharing panel never renders,
- `RecipeMemberManager.removeGroup` is unreachable in practice,
- and if it *were* reached it would strip a display id and revoke nothing, because access
  lives in `socialData.memberPermissions`, which the group share expanded into individual
  entries with no record of where they came from.

That last part is the real defect: **there is no provenance.** Once a group is expanded, a
member who arrived via the group is indistinguishable from one invited directly, so no code
can know whom a group-revoke should cut.

**Malin's decisions, 2026-08-03 — these are settled, do not re-open:**
1. The feature is wanted: share to a group, and be able to revoke that share.
2. A member who ALSO has a direct share **keeps access** when the group is revoked. A direct
   share is its own decision and is unaffected by the group one.
3. Snapshot, not live: a group share reaches whoever is in the group **at that moment**.
   Adding someone to the group later does not silently grant them access to recipes shared
   before they joined.

## The model

Add one field to `RecipeSocialData`:

```dart
/// Which grant(s) gave each member their access. Absent = a direct share, which
/// is the pre-existing behaviour and what every current document implies.
final Map<String, List<String>> grants; // uid -> ['direct', 'group:<categoryId>', ...]
```

Why a per-member list rather than a per-group member list: revoking has to answer "does this
person still have any reason to be here?", and that question is per member. A per-group map
would make the common case (one group, no overlap) marginally simpler and the decided case
(overlap) require a second lookup.

`memberPermissions` stays exactly as it is and remains the sole source of truth for access —
`grants` only records *why*. Nothing in `firestore.rules` needs to change, which is the point:
the access model is untouched, so this cannot open a hole.

## No migration (Malin, 2026-08-03)

The project holds only TEST recipes, so there is no production data to preserve. Add the
`grants` field, write it from the start, and delete any stale test document that gets in the
way rather than writing code to tolerate it.

Specifically: do NOT add a "read a missing `grants` as all-direct" compatibility path. It
would be dead code the day it shipped.

## Behaviour

**Sharing to a group** — resolve the group's members *now*, add each to `memberPermissions`
as today, and append `'group:<categoryId>'` to that member's `grants`. Record the group id in
`socialData.categoryIds` (the field that already exists and is currently dropped), so the
panel can render it.

**Sharing directly** — append `'direct'` to that member's `grants`.

**Revoking a group** — for each member holding `'group:<categoryId>'`: remove that entry. If
their `grants` list is now empty, remove them from `memberPermissions` too. If it still holds
anything (`'direct'`, or another group), they keep access. Then drop the group from
`categoryIds`.

**Revoking a member directly** — unchanged: remove them outright, whatever their grants say.
An explicit "remove this person" is the user overriding every grant at once.

## Files

- `lib/models/recipe_unified.dart` — the field, its serialization, `copyWith`.
- `lib/services/unified/unified_recipe_service.dart` — stop dropping `categoryIds`; forward
  it and the resolved grants into the create path.
- `lib/services/unified/operations/social_recipe_creation_service.dart` — accept them.
- `lib/services/unified/operations/modules/recipe_sharing_manager.dart` — record grants on
  both the create and the re-share path.
- `lib/services/unified/operations/modules/recipe_member_manager.dart` — the revoke algorithm
  above, replacing the current `categoryIds`-only strip.
- `lib/views/recipe_detail/recipe_detail_sharing_status.dart` — render a group as one row
  ("Familjen (4 personer)"), and restore the honest-but-now-accurate copy: the group dialog
  can say it removes the group's access again, because it will.

## Tests, and the ones that must fail first

The repo's standing rule: revert the fix, watch the named test redden, restore.

1. Group revoke removes a member whose only grant was that group.
2. **The decided case:** a member with `['group:x', 'direct']` KEEPS access when group x is
   revoked, and their `grants` afterwards is exactly `['direct']`.
3. A member in two groups keeps access when one is revoked.
4. A direct removal cuts a member who also holds a group grant.
5. Snapshot: someone added to the group AFTER the share does not appear in
   `memberPermissions` and is unaffected by the revoke.
6. A member revoked individually is gone regardless of how many grants they held.
7. The panel renders one row per group, and the group dialog's title, confirm button and
   tooltip all describe a real revocation (the widget test added on 2026-08-03 asserts the
   opposite today and must be updated in the same edit, not deleted).

## Interactions worth knowing before starting

- **BUT-1812** — re-sharing a recipe someone else already shared cannot write the
  `shared_content` row at all. A group share by a second sharer will hit that first. Decide
  BUT-1812's direction (widen the rule, or stop reusing `recipeId` as the doc id) before or
  alongside this, or group sharing will look broken for the second sharer for reasons that
  have nothing to do with this plan.
- **BUT-1785** was closed by the seam fix on 2026-08-03 — member writes now actually reach
  Firestore. Without that, none of this would have worked either.

## Open questions

None blocking. The three product calls are made and recorded above. Assumptions stated:
`memberPermissions` remains the only thing `firestore.rules` reads, and `grants` is
descriptive metadata that never widens access on its own.

## What this means in plain language

- Sharing a recipe with a group looks like it works today. It doesn't — the app forgets which
  group you picked the moment you tap share.
- This makes the app remember, so "un-share this group" can actually take the recipe back
  from exactly those people.
- If you shared with someone twice — once through a group, once directly — removing the group
  leaves them alone. You made that call twice; only one of them is being undone.
- People added to a group later don't get access to things you shared before they joined.
- Nothing changes about who can read what today; the security rules are untouched. This only
  records *why* someone has access, so it can be undone.
- Risk is low and reversible: existing shares keep behaving exactly as they do now.


---

# PRIOR RECORDS

# IN EXECUTION 2026-08-03 — collapse the two shared_content membership spellings

Approved by Malin ("implement it", 2026-08-03). Full plan below, verbatim from
`tasks/archive/butlery-collapse-shared-membership-field-plan.md`. Prior sprint
records are preserved below the separator.

# Plan: collapse the two `shared_content` membership spellings into one

**Status: written 2026-08-03, not started. Needs plan-mode approval before any code.**

## Context

Every `shared_content` document currently carries the SAME recipient list twice:

- `sharedToUserIds` — what `firestore.rules` grants recipient read on (:722, :727), what the
  Art. 15 export selects on, and what `BaseSharedContentRepository` speaks.
- `sharedWithUserIds` — written by the three direct-share managers, and read in EIGHT more
  places than this plan first claimed. Corrected 2026-08-03 before implementation, by grepping
  rather than trusting the earlier sentence:
  - `social_menu_operations.dart` :224 (a shared-with count), :330 (**an access check**),
    :520 (an analytics count)
  - `shopping_social_share_module.dart` :292 (**a defence-in-depth access check**, BUT-1108),
    :348 (a count), :381 (**an access check**), :456 (an analytics count)
  - plus the deletion cascade's union query.

  Three of those are access checks. Deleting the write without repointing them would silently
  deny people access to menus and lists they can legitimately see — the collapse is a REPOINT,
  not a deletion.

The duplication is not a design. It is scar tissue: the two spellings drifted apart, rows
written under one were invisible to readers keying on the other, and on 2026-08-01 the fix was
to make every writer emit BOTH. That closed the bug and left a field that exists only so old
documents stay readable.

**Malin, 2026-08-03: the project holds only TEST recipes.** There are no old documents. The
compatibility field is protecting nothing, and half of the GDPR work on 2026-08-01/03 — the
export leg, the erasure union query, the residual probe pairs — is machinery for keeping two
copies of one fact in agreement.

Collapsing to `sharedToUserIds` deletes that whole class of bug.

## This supersedes a deviation entry — do that properly

`.claude/rules/accepted-deviations.md` currently says, of the 2026-08-01 export decision:

> Both spellings are named deliberately — the writers emit the same list twice, and an entry
> naming one invites a future reviewer to strip the other "for consistency".

That was written to stop exactly this change being made casually. It is not being overruled
casually: the premise it rests on (documents exist that only one spelling can reach) is false
in this project.

**Append a new dated entry to BOTH deviation files superseding it — never edit or delete the
old one.** The new entry should say: with no production corpus, the dual write is retired and
`sharedToUserIds` is the single membership field; the earlier entry stands as the record of
why it was ever dual.

## The trap that will bite a careless rename

`sharedWithUserIds` is ALSO the legitimate, sole field name on an unrelated collection:

- `firestore.rules:1247` — `match /recipe_comments/{commentId}`, where a comment carries a
  denormalized `recipeOwnerId` and `sharedWithUserIds` written at create time (BUT-458).
- `lib/models/recipe_comment.dart:44`, `lib/repositories/firebase/firebase_comments_repository.dart`.

A repo-wide find-and-replace would silently break comment read access. **Scope every change to
`shared_content` writers and readers, and grep by collection, not by field name.**

## The work

**Remove the write** of `sharedWithUserIds` from the three direct-share managers:
`recipe_sharing_manager.dart`, `social_menu_operations.dart`,
`shopping_social_share_module.dart`.

**Simplify the erasure leg.** `removeFromSharedContent` in `account-deletion-cascade.ts`
currently runs two `array-contains` queries and dedups by document id, purely because two
fields exist. It becomes one query. The `arrayRemove` of the second field goes; so does the
`legacyOnly` counter and the log line that reports it. The two probe pairs in
`probeResidualData` become one.

**Simplify the export.** `_sharedContentReceivedQuery` already reads only `sharedToUserIds`;
what goes is the doc comment explaining why it must, and the note about documents the client
cannot reach.

**Delete the stale test data** rather than tolerating it. If a test document exists with only
`sharedWithUserIds`, remove it; do not add a compatibility read.

## Tests

The suites added on 2026-08-01/03 encode the dual-field world and must be updated in the same
edit, not deleted:

1. `shopping_social_share_module_test.dart:451`, `recipe_sharing_manager_test.dart:287/:372`,
   `social_menu_operations_test.dart:194` each pin `sharedToUserIds` — these stay, and are the
   regression guard that the surviving field is still written.
2. `account-deletion-cascade.test.ts` — `scenario_adHocSharedContentMembershipIsScrubbed`
   currently proves BOTH spellings are cleared and that a legacy-only row is reached. Rewrite
   it to the single-field world; keep the owner-skip assertion and the "never written before
   it is deleted" check, which are about the NOT_FOUND poison-pill and remain true.
3. Mutation-test the survivor: remove `sharedToUserIds` from one writer and confirm that
   writer's test reddens. The whole reason this field matters is that a dropped membership
   field is invisible — no fake ever denies.
4. Rules suite unchanged: nothing in `firestore.rules` reads the retired spelling for
   `shared_content`, so the rules diff should be empty. If it is not, stop — that means
   something reads it that this plan did not find.

## Order

Do this **before** the two sharing plans (BUT-1797 group revoke, BUT-1812 re-share). Both
write the same row, and building either on two fields means writing the dual-write logic twice
more and then deleting it.

## What this means in plain language

- Every shared recipe currently stores the list of people twice, under two different names.
- That was a fix, not a design: the two lists drifted apart, and things that read one couldn't
  see rows written by the other. Making everything write both stopped the bleeding.
- It only exists to protect old data, and you don't have any — so it can go.
- Removing it deletes a whole category of future bug: two copies of one fact that can disagree.
- One thing to be careful of: the same field name is used, legitimately, by recipe comments.
  A careless search-and-replace would break who can read comments. The plan says so explicitly.
- It should happen before the two sharing features, because both write that same record.


---

# Sprint 2026-08-01 SALVAGE — resumed 2026-08-02

Continuation of the approved plan below. Open findings and their proposed fixes are in
`tasks/butlery-salvage-open-findings.md`; this section records only what the resume ADDS to
the approved fileset.

## Widened fileset (recorded per the repo's own rule)

**`lib/services/unified/unified_recipe_service.dart`** — one binding changed.

`SocialOpsContext.updateRecipe` was bound to `updateRecipe`, which resolves to
`PersonalRecipeCrud.updateRecipe` -> `personal_recipe_module.dart:242`:
`if (!updatedRecipe.isPersonal) return false;`

That seam is handed to exactly one consumer, `RecipeMemberManager`
(`social_recipe_operations.dart:62-67`). Every entry point there filters `r.isCollaborative`
(lines 42, 117, 228, 308, 395, 444, 460) and rebuilds with `type: recipe.type`, and personal and
collaborative are mutually exclusive (`recipe_unified.dart:1474-1476`).

So **add-member, remove-member and remove-group have never written anything** — each returned
false and surfaced as a generic error. Wider than the BUT-1785 ticket, which named only the group
case. The member-manager suite is green because it stubs the seam to `true`.

Rebound to `saveRecipeForSocialModule`, which exists for this case, says so in its own doc
comment, and is already used two bindings up by `SocialRecipeModule`.

Risk: the seam has one consumer, so the blast radius is that consumer's four write sites — all of
which want the collaborative-tolerant path. Verification is the member-manager suite driven
against the REAL terminal function rather than a stub.

---

# Sprint 2026-08-01 SALVAGE — approved plan (in execution)

> Malin approved keeping the sprint's uncommitted work and fixing its failures.
> This is the plan being executed. The sprint's own selection record is preserved
> below the separator — the ship phase still needs it (fileset deviations, ticket
> grading). Do not delete it.

# Butlery — Sprint 2026-08-01 salvage: fix the blocking defects, then ship

> On execution, mirror this plan to `tasks/butlery-sprint-salvage-plan.md` (the sprint's own
> record stays in `tasks/todo.md`; `~/.claude/plans/` is shared across all three repos).

## Context

The 2026-08-01 parallel sprint built ten tickets and then refused to commit, correctly: no
review marker on disk named the files it was about to ship. Its work — 77 changed files, 43
Dart + 18 Cloud Functions — has been sitting uncommitted in the working tree since. Malin's
decision: **keep the work and fix the failures.**

Four commit-gate specialists re-reviewed the real fileset (the sprint's own completeness
sweep proved two of them never ran during the sprint), and a fresh-context auditor then read
this plan cold and found a defect in it. Everything below is the corrected set.

Backup of the whole tree state — `tracked-changes.patch` plus copies of the 9 untracked files —
is at
`C:/Users/malla/AppData/Local/Temp/claude/C--Butlery-butlery/9fede5e3-3a2f-4230-ad3d-b8e12a829903/scratchpad/sprint-backup/`
and stays until the commit lands.

## Scope decisions

- **In:** defects that are verified against real command output *and* would break production
  or leak/strand user data. Allergen correctness is in scope, always (A3).
- **Out — the group-conversation path unification.** Groups are written to
  `users/{uid}/conversations` and read from top-level `conversations` by five server callers
  and two rules blocks. That is a migration, not a fix (BUT-1795, BUT-1796). This plan fixes
  the *lie* it produces — a failed leave that reports success — so the bug becomes visible.
- **Out, with the hole each one leaves open:**
  - BUT-1797 — taking a group off a shared recipe revokes no access; those members keep full
    access until it lands. Needs Malin's product call.
  - BUT-1801 — six more wrong-path recipe reads, including the Art. 15 export and Art. 17
    cascade. Same bug class as B1 below; those legs stay broken.
  - BUT-1805 — an admin removing another member leaves no audit row; the trail is console-only.
  - BUT-1804/1806/1807/1808 — test gaps and small leftovers, no user-facing hole.
- Malin's answer, 2026-08-01: the export's `shared_content` section ships **with** other
  recipients' UIDs and the sharer's display name; avatars stay stripped.

---

## A. Production-breaking — fix now

**A1. `firestore.rules:1547-1548` — the group-takeover guard denies every update to a
conversation whose `metadata` is null or absent, taking message sending down with it.**
In rules CEL `.get(k, default)` returns the default only when the key is *absent*; a key
present with value `null` returns `null`, and `.get()` on `null` is an evaluation error →
blanket deny. `ConversationDto.toFirestore` (`conversation_dto.dart:143`) emits
`'metadata': conversation.metadata` unconditionally and `message_mutation_module.dart:186-194`
sends it on every message, in the same atomic batch as the message. Apply the spelling the
rules specialist verified on the emulator (13/13 probe cases; all six takeover denies kept):

```
&& (request.resource.data.get('metadata', {}) is map
    ? request.resource.data.get('metadata', {}).get('creatorId', null) : null)
   == (resource.data.get('metadata', {}) is map
    ? resource.data.get('metadata', {}).get('creatorId', null) : null);
```

**A1b. `functions/src/__tests__/conversations-rules.test.ts` — the allow test certifies the
broken case as working.** C11 sends `update({lastMessage})` with no `metadata` key, which
genuinely allows, while the real client write on the same document denies. Mirror
`ConversationDto.toFirestore`'s full key set (including `metadata`) in at least one allow test
per write path; add the legacy-doc takeover deny (C12) and a group-rename allow so a future
blanket `metadata` freeze cannot pass green.

**A2. `lib/services/unified/operations/modules/recipe_sharing_manager.dart:589` — the
first-ever share of any recipe silently fails.** The new create-only `sharedAt` stamping probes
`sharedContentRef.get()`, but `firestore.rules:723` dereferences `resource.data.sharedByUserId`
in `allow get`; on a document that does not exist `resource` is null → `PERMISSION_DENIED` →
swallowed by the catch at `:638` → the row is never created. That costs the recipient their
read grant *and* their Art. 15 row — exactly what the change was written to protect.
`fake_cloud_firestore` evaluates no rules, so no existing test can see it. Fail the probe open:

```dart
var isNew = true;
try {
  isNew = !(await sharedContentRef.get()).exists;
} on FirebaseException catch (e) {
  if (e.code != 'permission-denied') rethrow;
}
```
Test: new case in `functions/src/__tests__/` — sharer `get()` on a non-existent
`shared_content/{recipeId}` denies, so the probe must not be trusted as an existence oracle.

**A3. BUT-1794 (Urgent) — the ingredient retag cascades match nothing for å/ä/ö.**
`on-ingredient-soft-deleted.ts:112-116` and `on-ingredient-properties-changed.ts:157-161`
query `core.ingredientsNormalized array-contains stripDiacritics(name.toLowerCase())`, but the
producer (`IngredientNormalizer` via `ingredient_processor.dart:384`) preserves diacritics.
**8 of the 14 EU allergens have å/ä/ö in their Swedish names.** The corpus is mixed (a retired
backfill wrote stripped forms), so the fix is a **union**, not a swap:

```ts
const variants = [...new Set([
  ingredientName.toLowerCase(),
  stripDiacritics(ingredientName.toLowerCase()),
])];
.collectionGroup(Collections.recipes)
.where("core.ingredientsNormalized", "array-contains-any", variants);
```
Delete the false comment at `on-ingredient-soft-deleted.ts:102` in the same edit. No index work:
`firestore.indexes.json` already declares that field CONTAINS at COLLECTION and COLLECTION_GROUP
scope. Tests: extend the existing ingredient-trigger suites with an å/ä/ö case per trigger, and
mutation-test them (drop one variant, confirm red).

**A4. `lib/models/notification_preferences.dart:186-190` + `notification_preference_manager.dart:391-406`
— a stale local cache still serves factory defaults as a real answer.** BUT-1799's main hole is
closed, but `fromJson` returns `defaults()` for an unusable payload and `_loadPreferencesLocally`
returns that as a non-null cache hit. The old `toJson()` stub wrote the literal `'{}'`, so that
string is in every existing user's `SharedPreferences` today: first failed read after upgrade
serves defaults, caches them, and the next toggle in
`notification_preferences_view.dart:107-116` persists factory defaults to Firestore. Make the
unusable-shape branch return `null` and let the caller fall through to the uncached,
unpersisted defaults path that already exists.
Test: `test/unit/services/notifications/notification_preference_manager_test.dart` — a `'{}'`
cache entry must NOT be reported as a cache hit, and must not be persisted on the next write.

**A5. `lib/repositories/firebase/modules/conversation_mutation_module.dart:333-347` — a no-op
leave is spelled exactly like a completed one.** `removeParticipant` is `Future<void>`: it
awaits the callable, never reads `removed`/`remainingParticipants`, and logs success
unconditionally. The callable's no-oracle gate (`leave-group-conversation.ts:271`) returns
`{removed:false, remaining:0}` for a missing document — reachable by construction, since groups
live at `users/{uid}/conversations`. `ConversationsViewModel.leaveGroup:209-219` then returns
`true` and fires `logGroupLeft`.
Return the parsed result up through `MessagingRepository.removeParticipant` →
`removeParticipantFromGroup` → `ConversationsViewModel` and `GroupDetailViewModel`, and treat
`removed == false` as a visible failure. This does **not** fix the path split (BUT-1795); it
stops it lying.
- Signature change crosses three layers — pin it with tests in
  `test/unit/repositories/firebase/modules/conversation_mutation_module_test.dart` and
  `test/unit/viewmodels/conversations_viewmodel_test.dart` (a `removed:false` reply must yield a
  failed leave and must NOT fire `logGroupLeft`).
- New user-facing string: `leaveGroupFailed` in **both** `lib/l10n/app_sv.arb` and
  `app_en.arb`, regenerated into both `app_localizations_*` files. Swedish copy — "Kunde inte
  lämna gruppen. Försök igen."

---

## B. GDPR — export ⊇ erasure

**B1. `functions/src/account/account-deletion-cascade.ts` — the uid the export now returns
cannot be erased, and it must be queried under BOTH spellings.**
The cascade discovers `shared_content` only via a `members/{uid}` subcollection doc
(`:1369-1392`), but the three writers touched this sprint (`recipe_sharing_manager`,
`social_menu_operations`, `shopping_social_share_module`) write the parent doc only. Nothing
scrubs `sharedWithUserIds` at all, and `probeResidualData` has no `shared_content` entry, so
the residual is invisible.

**The correction the auditor caught:** membership is written under two spellings, and documents
shared *before* the writer fix carry only `sharedWithUserIds`. Querying `sharedToUserIds` alone
would miss exactly the legacy corpus this leg exists to clean. The export was forced onto
`sharedToUserIds` because `firestore.rules:722` refuses the other spelling **to a client** — the
cascade runs on the admin SDK and has no such constraint. So: **union both queries and dedup by
document id**, the pattern already used at `account-deletion-cascade.ts:604-609`. `arrayRemove`
the uid from both fields on every hit, and add both probe pairs to `probeResidualData`.

**B2. `lib/repositories/firebase/firebase_data_export_repository.dart:445-451` — shared shopping
lists are readable by their recipient and absent from their export.**
`_sharedContentReceivedQuery` is type-parameterised and only two of the three `contentType`
values are used. Add the third leg (`'shopping_list'` → `shared_shopping_lists_received`) through
the same `_dropSharerAvatar`. `exportSharedShoppingLists*` is not coverage — it queries
`unified_shared_shopping_lists`, a different collection.
Test: `test/unit/repositories/firebase/firebase_data_export_repository_shared_content_test.dart`
(already touched this sprint) gains a `shopping_list` row asserting it appears and its avatar is
stripped.

**B3. Record the decision by EXTENDING the existing entry, not beside it.**
`.claude/rules/accepted-deviations.md` already governs `shared_content` avatars via the
conversations entry (BUT-1772/1767/**1775**), which explicitly requires all these sections to go
through one shared helper "so the sections cannot drift apart". So B3 **amends that entry**
(both files, same edit) to state: the `shared_content` export sections — recipe, menu, and the
`shopping_list` rows B2 adds — keep other recipients' UIDs and `sharedByDisplayName`, and strip
`sharedByAvatarUrl`. Mark it **Malin's explicit call, 2026-08-01**, and say in the entry that it
is *not* derived from BUT-1732 or BUT-1772 — each of those decided a different question, and
reasoning by analogy from them is the error BUT-1732 itself records.

---

## C. Robustness (small, same commit)

- `functions/src/admin/bulk-retag.ts:245,268,278` — the drain callable can never drain: a full
  collection-group `limit(limit)` scan with no `orderBy`/cursor, re-reading the same first N docs
  forever, with an operator-supplied uncapped `limit`. Add a `startAfter` cursor + `nextCursor`
  return (the `backfillCanonicalRatings` shape) and clamp to 1000.
- `functions/src/messaging/leave-group-conversation.ts:48` — module-scope `admin.firestore()`,
  safe only because of statement order in `index.ts`. Use a lazy `getDb()`.
- Both ingredient triggers — `retry: true` is now on, so an absent `event.data` becomes an
  hour-long retry loop. Add `if (!event.data) return;`.
- `functions/src/account/account-deletion-cascade.ts:1289` — an `Error` nested in the logger
  payload serializes to `{}`; use the `errCode`/`errName` shape from `:375`.
- `docs/architecture/ACCEPTED_LARGE_FILES.md` — restate the two stale rows A2/B2 grow further:
  `firebase_data_export_repository.dart` (row says 783, actual 857) and
  `recipe_sharing_manager.dart` (row says 604, actual 646). Both are already waived; the rows
  just need to match reality.

---

## Verification — every command's real output pasted, nothing asserted

1. `dart analyze --fatal-infos` → clean.
2. Named Dart tests, not "areas": `recipe_member_manager_test.dart`,
   `notification_preference_manager_test.dart`, `conversation_mutation_module_test.dart`,
   `conversations_viewmodel_test.dart`,
   `firebase_data_export_repository_shared_content_test.dart`,
   `rating_statistics_denormalization_test.dart`, `recipe_save_navigation_test.dart`.
3. `cd functions && npx tsc --noEmit` → clean. Run the five suites already green
   (`leave-group-conversation`, `cascade-retry-semantics`, `recipe-collection-group-indexes`,
   `compute-feature-retention`, `account-deletion-cascade`) **and** the rest of the unit lane —
   if anything else is red, report it rather than omitting it.
4. Rules: `test:rules:all` on the emulator, plus re-run the mutation proof on the
   `metadata.creatorId` conjunct in **both** directions and the 13-case probe against the fixed
   spelling.
5. **Re-review the fix diff itself.** Per the repo's own lesson the fix round lands after the
   last review and is the least-reviewed, most-likely-wrong code in the change. Hand each
   reviewer the rationale, not just the diff.
6. If `docs/onboarding/workflow-map.stale` appears (A2/A5/B1/B2 touch mapped code), re-trace only
   the flows its `triggers` name, update the map's `<script id="data">` JSON, run
   `python tools/check_workflow_map.py`, delete the marker.

## Ship

7. Run the six commit-gate specialists against the **actual staged fileset**
   (`git diff --cached --name-only`), **in batches of ≤3 files per agent** — agents stall above
   that (`memory/feedback_agent_timeout.md`) — touching each marker only after its final batch.
   Markers pin `path@<staged blob sha>` from `git rev-parse :<path>` taken **after** the final
   `git add`. No agent may write a marker before emitting its findings.
8. Append a **Fileset deviations** block to the sprint section of `tasks/todo.md` naming the ~15
   files changed outside every declared batch (BUT-1803), and name them in the markers too.
9. Immediately before committing: re-verify `git status --porcelain` for any `MM`/` M` left by a
   reviewer's mutation probe, re-pin blob shas if anything moved, then **stage by explicit
   pathspec and commit in the same Bash call**. Push to main.
10. `firestore.rules` and `firestore.indexes.json` are in this change — commit+push does **not**
    make them live. Deploy them explicitly, `--non-interactive`, **never `--force`** (13 live TTL
    policies are absent from the indexes file and `--force` deletes them).
11. Linear: close only tickets whose acceptance criteria the shipped diff actually meets.
    BUT-1785, BUT-1781 and BUT-1774 stay **In Review**; BUT-1788 must not be graded Done.

---

## Panel conditions (2026-08-01, full-panel — fold into execution as acceptance criteria)

Seated: Privacy/DPO, Security Architect, DBA/Data-layer, Legal Counsel, Customer Support/Ops,
Codebase Archaeologist. Dropped as incidental: FinOps (cost items already quantified and
bounded by the existing 1h guard), Performance (no new hot path), Data Analyst/BI (the false
`logGroupLeft` is fixed by A5, no metric redefinition), Product (the one product call is
BUT-1797, explicitly out of scope and ticketed need-malin), Trust & Safety (takeover guard
covered by Security), Vendor and Software Architect (no vendor change, no new layer).

**Gating — real work, blocks B2:**
- **C1. Audit the nested `listData` blob before B2 ships.** `shopping_social_share_module.dart:81`
  writes `'listData': listData` — an entire personal shopping-list document nested inside the
  `shared_content` row. `_dropSharerAvatar` (`social_export_manager.dart:341`) removes exactly
  one *top-level* key. Any avatar URL, contributor UID, permission level or cached display name
  inside that blob would ship unredacted in a section that has never been reviewed against real
  data. Enumerate its actual key set against a real row, then either bound it to a named
  allow-list or extend the shared helper to walk it. Anything third-party that survives gets its
  own line in the deviation entry — never silent passage.

**Corrections to this plan's own text:**
- **C2. B3 splits into TWO entries** (both files, same edit), because folding a newly-decided
  question into an older entry is structurally the analogy error BUT-1732 records:
  (a) mechanical extension of the BUT-1775 entry — the `shared_content` avatar strip now also
  covers B2's `shopping_list` rows, still through the one shared helper;
  (b) a **separate dated entry** for the new question, marked *Malin's explicit call,
  2026-08-01*, reasoned on its own merits, stating it is **not** derived from BUT-1732 or
  BUT-1772. It must name **both** field spellings (`sharedToUserIds` AND `sharedWithUserIds` —
  writers emit the same third-party UID list twice) and scope itself to rows where the requester
  is a **recipient**. It must enumerate concretely what was shown to Malin — UIDs,
  `sharedByDisplayName`, avatars stripped — in the same style as the BUT-1732 correction, not a
  compressed one-liner.
- **C3. Re-title section B** to what it actually delivers: *export ⊇ erasure **for
  `shared_content` membership***. The current heading claims an invariant BUT-1801 demonstrably
  leaves broken, which is exactly how BUT-1724 was graded Done while four instances of its own
  disease were live.
- **C4. The plain-language summary must name the BUT-1801 Art. 17 residual next to the export
  expansion**, so both halves of the tradeoff are visible in one read rather than split between
  a scope bullet and a summary that doesn't cross-reference it.

**Implementation conditions:**
- **C5. B1 clears BOTH spellings unconditionally on every union hit**, deduped by document id —
  not just the field whose query matched. `arrayRemove` is a documented no-op when the value is
  absent, so the double-clear is safe and cheap; a conditional clear leaves the other spelling as
  residual debt. Verify in the actual diff, not the plan prose.
- **C6. The residual probe keys on BOTH spellings, pinned by a mutation test** — drop one probe
  pair, confirm red. A probe that only ever checks `sharedToUserIds` re-creates the invisible
  residual B1 exists to kill.
- **C7. B1 logs the legacy-only hit count**, so the size of the `sharedWithUserIds`-only corpus is
  known rather than assumed.
- **C8. C's cursor is a `DocumentSnapshot`**, mirroring the already-correct `getRetagStatus`
  pagination in the same file — a raw-value cursor without an explicit `orderBy` misbehaves silently.
- **C9. Give the two shopping sections distinct, self-describing keys** plus a one-line provenance
  note each ("shared with you by a friend" vs "shared via a shared list"). Two near-identically
  named shopping sections with different provenance is an Art. 12(1) intelligibility defect.
- **C10. The `data_minimisation` note must be verified against a shipped row.** A note claiming a
  redaction that did not happen is itself an Art. 12(1) defect — this repo has shipped that bug.
- **C11. Drop "Försök igen" from the leave-group copy.** Retrying can never succeed until BUT-1795
  lands, so the string is a false promise support must walk back on every ticket. Reuse the
  existing `errorCouldNotLeaveGroup` (already in both arb files) instead of adding a new key —
  this replaces A5's proposed new string.
- **C12. `--non-interactive`, never `--force`, must survive into the actual deploy command run**,
  not just the plan text.

**Security Architect — two catches that change the work:**
- **C16. A1's spelling is verified airtight, for a reason worth writing down.** The ternary
  collapses absent, `null` and non-map metadata to the same value on *both* sides, so adding a
  `creatorId` where none was stored yields `non-null == null` → deny. The invariant is monotonic:
  the only way a write can store `creatorId == X` is if it already equals X, so there is no
  two-step laundering path. All six takeover denies survive. Put that reasoning in the rule's
  comment — it is the thing a future "simplification" will destroy.
- **C17. A1b's fixture is the WRONG SHAPE, so the suite still cannot go red on the live defect.**
  `NO_METADATA_GROUP` (`conversations-rules.test.ts:258-262`) seeds metadata **absent** — which
  the current rule already handles. The production-breaking shape is metadata **present with
  value `null`**, which is what `ConversationDto.toFirestore` emits, and no fixture in the file
  has ever had it. Fixing only the payload leaves the regression uncovered. Required: seed a
  third fixture with explicit `metadata: null`, pin an allow test mirroring the DTO's full key
  set, and mutation-test it — revert the conjunct to the current spelling and confirm *that*
  test goes red. If it stays green the fixture is still wrong.
  Also: C12 must deny the takeover on **both** legacy shapes (absent AND null — different
  branches of the ternary, one does not prove the other), and add a deny for `metadata` written
  as a non-map, proving `is map` cannot launder a stored creatorId to null.
- **C18. B1 will arrayRemove every document it is about to hard-delete.**
  `_writeToSharedRecipesCollection:574` writes `{currentUserId, ...memberIds}` into both arrays,
  so a deleted user is always in their *own* docs' membership. The new queries would update every
  owned doc, which the pre-existing `sharedByUserId == uid` leg (`:1398-1406`) then hard-deletes —
  wasted writes, and a `batch.update` on an already-deleted doc throws NOT_FOUND and poison-pills
  the chunk on retry. Same failure shape as BUT-1582/1583. Exclude `sharedByUserId == uid` docs
  from the scrub set (or order scrub strictly before delete and tolerate NOT_FOUND per doc), and
  prove it with a fixture where the deleted user is both sharer and recipient of the same doc —
  the normal case. This makes B1 **cost-negative**.
- **C19. A2's fail-open is wrong in one reachable case, and fails silently there.** The
  `shared_content` doc id *is* the recipeId, so if another user already shared that recipe and we
  are not in their `sharedToUserIds`, our probe denies on an **existing** doc → `isNew = true` →
  `sharedAt` stamped → the write becomes an update → `cannotModify(['sharedAt'])` denies the whole
  `set(merge:true)` → swallowed by the same catch the change exists to escape. Required: on an
  inconclusive probe, attempt the create and, on a `permission-denied` write, retry once
  **without** `sharedAt`; log that branch distinctly and pin it with a test. Do not ship a
  fail-open whose only failure mode is the silent swallow this ticket is about.
- **C20. Keep A2's fix client-side.** Do **not** "fix it properly" by adding `resource == null`
  to `firestore.rules:724`. Today non-existent and not-yours both return permission-denied and are
  indistinguishable; a null-resource allow would turn that into a **shared-content existence
  oracle** over recipeIds. The client-side fail-open preserves the non-oracle property and adds
  zero attack surface.
- **C21. Two `array-contains` clauses in one query are illegal in Firestore** (including inside
  `Filter.or`). The union-of-two-queries shape is the only legal spelling, not a stylistic
  preference — say so in the code comment, or a future "simplification" produces a runtime error.
- **C22. The new scrub legs must not inherit `strict: false` silently.** The existing leg runs
  `commitInChunks(..., {strict: false})`, so a chunk failure does not fail the step and erasure
  can report success over data it never removed. That is acceptable only if the probe legs
  (C6) genuinely exist and genuinely fail the run.
- **C23. Verification step 4 runs the mutation proof in BOTH directions on the NEW spelling** —
  rules reverted → the null-metadata allow goes red; conjunct deleted → C8/C9/C12 go red. A 13/13
  probe count on its own does not prove the suite would catch a regression.
- **C24. Scope note to state, not fix:** A1 pins only `creatorId`; the rest of `metadata` stays
  mutable by any participant, so any member can rewrite `metadata.title` that everyone sees. The
  new group-rename allow-test will *bless* that. Say so explicitly in the test, or a future reader
  will take it as a deliberate decision that metadata is unprotected.

**New follow-up tickets (file during execution, do not build):**
- **C13.** One-off backfill for legacy `sharedWithUserIds`-only `shared_content` documents, and a
  dated accepted-gap note recording the interim state: *the cascade erases a legacy corpus the
  export cannot show.* This is a new asymmetry B1 opens in the opposite direction — real, and
  currently unticketed.
- **C14.** Support-runbook entries for BUT-1795 ("can't leave group" is a known gap, point at the
  ticket, don't escalate as new) and BUT-1797 ("my ex-group member still sees my recipe" is a
  known gap, not a fresh security incident).
- **C15.** Cross-reference the five accepted-deviations entries that now collectively constitute
  Butlery's Art. 15(4) balancing policy into the Art. 30 record / `docs/security`, so the
  reasoning is producible without git archaeology.

**Escalated to Malin — see the question at the end of this plan:** whether A5 ships at all.
Support's position is that it should, but with honest copy; the tradeoff is a permanent visible
error versus a silent no-op. Legal separately flags an accumulating pattern of case-by-case
Art. 17 deferrals (BUT-1570, BUT-1747, now BUT-1801, plus BUT-1795/96/97/1805) that would read to
a regulator as systemic rather than incidental — that is a standing concern, not a blocker here.

## Open questions

**Asked and answered (2026-08-01, via AskUserQuestion):**
- *What may the newly-live `shared_content` export section contain?* → Malin: keep other
  recipients' UIDs **and** the sharer's display name; avatars stay stripped. Folded into B3 as
  an acceptance criterion, recorded in her name and explicitly **not** as an analogy from
  BUT-1732 or BUT-1772.

**Open, surfaced not assumed:**
- *Drop A5?* — see Weakest point below. Default is to keep it; one word changes that.

**No further architecture-changing unknowns. Assumptions, stated so they can be corrected:**
- The group-conversation path split is a migration, not a fix, and stays out (BUT-1795/1796);
  this plan only stops it reporting false success.
- Legacy `sharedWithUserIds`-only documents are reachable by the admin SDK, which bypasses the
  client rule that forced the export onto the other spelling. B1 depends on this; it is asserted
  from `firestore.rules:722` being a client-scoped rule, and must be **proven on the emulator**
  before B1 is called done.
- Everything already filed as a follow-up ticket stays filed and unbuilt; this run adds no new
  tickets unless a fix turns one up.

## Weakest point

**A5 is the shakiest part of this plan.** It changes a method signature through three layers to
make a failure visible, without fixing the underlying cause (BUT-1795). If the parsed reply is
wired through wrongly, a leave that *did* work could start reporting failure — annoying, but the
opposite of dangerous, and the two named tests pin both directions. The alternative is to leave
it lying until BUT-1795 lands; say the word and I'll drop A5 and ship the rest.

## What this means in plain language

- The sprint's work is worth keeping, but nine things would have hurt if they had shipped.
- Sharing a recipe **for the very first time** would have silently failed — the other person
  never gets access, and the share never appears in their data export.
- **Sending a message** would have broken on older chats, because a new anti-takeover rule
  accidentally blocked the message too.
- Your **data export** would have started handing out other people's IDs that account deletion
  could never clean up. Fixing that properly means cleaning records saved under an older field
  name too — the auditor caught that I had missed exactly those.
- **Allergens:** the ingredient cleanup never matched anything containing å, ä or ö. That is 8 of
  the 14 EU allergens. Fixed here, not deferred.
- **Leaving a group chat** still won't work — that's a move-house job with its own ticket. After
  this it will at least *tell you* it failed instead of pretending.
- Your export decision from today gets written down in your name, as its own call rather than
  borrowed from an older one.
- **The panel found four more things** the six specialists had missed, including one real privacy
  problem: shared shopping lists carry a copy of the whole list inside them, and the export only
  cleans the outside of that parcel. Nobody has ever looked inside it. I will, before shipping.
- **Also still broken and deliberately left alone:** deleting your account does not fully clean up
  six other places that read recipes from the wrong location. Your lawyer's point, and it is fair:
  this change *widens* what the export shows while that gap stays open. Both halves are on the
  table on purpose.
- **Risk and undo:** nothing is committed yet, the full tree is backed up, and every step is
  reversible until the push. After the push, main is fixable forward with another commit — no
  deploy happens automatically.


---

# Sprint 2026-08-01 — Selection

Backlog scanned: Linear MCP live (`list_issues` confirmed), team Butlery. 130 Backlog + 2
Todo (BUT-1480, BUT-1685, both older/not selected this run) + 0 In Progress + 0 Triage.
`onboarding-reserved` items (BUT-677, BUT-722) excluded from scoring entirely, per instruction.

**Ship-state check first.** `git log --since="7 days ago"` shows three sprints landed since
the archived 2026-07-30c write-up below: the crashed-sprint rescue (`c0dc8c984`, 9 tickets:
BUT-1766/1767/1768/1773/1760/1755/1722/1770/1761 — all confirmed absent from the current
Backlog fetch, i.e. genuinely Done, not stale), then `46f642baf` (BUT-1762) and `a02d5ff32`
(BUT-1699 — the TTL-enable ticket that sat in "Needs your call" for two prior sprints,
since built), then a docs/gates commit. Working tree is clean. No obsolete tickets found —
every BUT-id referenced in the last 7 days' commits is already absent from the open backlog.

Most of today's candidates are fresh (2026-07-31) findings from a `/linear scan night` +
specialist-review pass on the just-shipped sprints — verified independently below, not taken
on the filer's word.

**Step-0 grep-of-main premise check** for every ticket selected below:
- `lib/views/recipe_detail/recipe_save_navigation.dart:33` — still `arguments: savedRecipe.id`
  (bare string, not a `Recipe`). BUT-1779 live.
- `lib/models/notification_preferences.dart` / `lib/views/settings/notification_preferences_view.dart`
  — `soundEnabled`/`vibrationEnabled` grep across `lib/` (excluding those two files) returns
  nothing. BUT-1783 live (routed to needsApproval, not built).
- `lib/widgets/recipe/recipe_card.dart` — `showAllergenBadges` still appears only in this one
  file (declaration, default `false`, two gates); no passer anywhere. BUT-1780 live (deferred
  to capacity this sprint, see below).
- `firestore.rules:1532-1535` — the `conversations` update rule still denies any diff touching
  `participantIds`; no self-leave exception exists anywhere in the file. BUT-1788 live.
- `functions/src/shared/collections.ts:9` — `recipes: "recipes"` (top-level) still feeds the
  five call sites BUT-1781 names. BUT-1781 live.
- `lib/services/account/export/social_export_manager.dart` — **partial premise change**:
  `_dropOtherPeoplesAvatars` already narrows `perUserSettings` to the requester's own entry as
  a conservative *placeholder* default (comment: "NOT the BUT-1772 decision... until that
  verdict exists"). Her verdict (recorded in BUT-1774's body) asks for exactly that behavior,
  so item 1 of that ticket is functionally already shipped — but items 2–5 (extend the
  avatar-strip to `shared_content`, fix the two `sharedByAvatarUrl`/raw-Auth-displayName write
  sites in `recipe_sharing_manager.dart:584-586` and `social_menu_operations.dart:87-88`, and
  update the deviation docs) are still live — grep confirms zero `sharedByAvatarUrl` handling
  in the export manager. Not obsolete; re-scoped in the acceptance criteria below.

Nothing else here is already fixed. Every ticket below except BUT-1774/1775 was Claude-authored
(the `/linear scan night` + specialist-review round from 2026-07-31), never human-approved —
the mandate column records why each is safe to build anyway.

## Already decided — her answer, applied (not re-litigated)

- **BUT-1774** (merged with **BUT-1775**) — ticket body carries "BESLUT FATTAT AV MALIN
  2026-07-30": strip other participants' `perUserSettings`, keep `lastReadTimestamps`; merge
  with BUT-1775 (strip `sharedByAvatarUrl` in `shared_content`, same file family) in one
  change; build order set the same day — **BUT-1766 and BUT-1767 build first**. Both landed in
  `c0dc8c984`, so the wait condition that held this back the last two sprints is now cleared.
  Applied as **build**, batched below (Agent G). Her stated conditions are copied into the
  acceptance criteria verbatim.

## Needs your call (found this run, not built)

- **BUT-1783** — notification sound/vibration switches persist correctly but control nothing
  (Android channel is hardcoded `enableVibration: true, playSound: true`; zero consumers of
  either preference anywhere in `lib/` or `functions/src/`). The ticket's own filer frames it
  explicitly as a product choice: **build real per-channel wiring** (touches both trees, an
  Android notification channel can't change sound/vibration after creation so this is a real
  redesign) vs. **remove the two switches** until there's something behind them. No comment
  recorded on the ticket — genuinely undecided.
  **My read:** lean toward removing the switches — nobody has asked for per-app sound control,
  Android's own per-channel settings already give users that lever at the OS level, and a
  switch that lies costs more trust than a missing one. But it's a product call, not mine to
  make. Not built this sprint.

## Deferred to capacity (clear-enough mandate, held back this sprint)

- **BUT-1780** — allergen/dietary badges never render on `RecipeCard` in any list/grid (the
  settings screen promises "show on cards", defaults it on, and delivers nothing — the wiring
  parameter exists but nothing passes `true`). Genuinely a real bug against a shipped promise,
  but the ticket's own filer flags it should get "a second look from the product side before
  the 'clean cards by default' intent is overridden" — a `build-review` disposition, not a
  clean `build`. Held this sprint so BUT-1774/1775 (a *decided*, time-sensitive item, unblocked
  today) could take its slot within the auto-sized batch count. Next sprint's Agent G.
- **BUT-1792** — three more Firestore collections (+ presence) need TTL policies declared, same
  mechanism BUT-1699 just proved works. Clear follow-up to already-approved work, but lower
  time-pressure than this sprint's live-bug and GDPR-deletion tickets; held for capacity.
- **BUT-1786** — `cleanupExpiredCache` reads the whole `globalRecipeCache` with no `.limit()`,
  risking a timeout-before-progress cost spiral. Its own ticket suggests fixing it alongside
  its sibling BUT-1671 (persisted-cursor gap, also backlog) — held together for next sprint.
- **BUT-1790** — a personal shopping list with no stored `updatedAt` never gets the BUT-1762
  day-stamp (parse-time `clock.now()` synthesis makes the guard compare "now" to "now"). Real
  but narrow (only pre-existing/handwritten docs lack the field, and such a list was already
  invisible to the metric before BUT-1762 too) — Medium priority, held for capacity.

## Standing need-malin backlog (unchanged, carried from prior sprints)

BUT-1693, BUT-1718, BUT-1730, BUT-1731, BUT-1747, BUT-1480, BUT-1323, BUT-1685, BUT-880,
BUT-1502, BUT-1557, BUT-1179, BUT-1368, BUT-863, BUT-1445, BUT-1649, BUT-1636, BUT-1361 — the
standing manual-QA / compliance-diagnosis / product-decision backlog, not re-derived this run
(each already carries its own reasoning in the archived sprint sections below).

## Agent A — recipe: two dead-end share/save flows
Area: recipe. Router: single (Software Architect, Product Manager). File-disjoint from every
other batch: `lib/views/recipe_detail/recipe_save_navigation.dart`,
`lib/views/smart_import/import_result_handler.dart`,
`lib/views/recipe_detail/recipe_detail_sharing_status.dart`,
`lib/services/unified/operations/modules/recipe_member_manager.dart`,
`lib/services/unified/operations/social_recipe_operations.dart`, plus tests under
`test/widget/views/`, `test/unit/services/unified/operations/`.

- [ ] **BUT-1779** [Tier A][build] `pushReplacementNamed(Routes.recipeDetail, arguments:
  savedRecipe.id)` sends a bare id string to a router that only accepts a `Recipe` or a Map
  wrapping one — every non-onboarding manual save (and 3 import-duplicate-resolution sites)
  lands on the error screen immediately after a successful save. **requiresPlanMode: true**
  (Urgent + Bug). Router: single.
  - Fix: pass the `Recipe` object at all four sites (matching every working call site
    elsewhere in the app).
  - Acceptance:
    1. All four sites (`recipe_save_navigation.dart` + the three branches in
       `import_result_handler.dart`) pass a `Recipe`, not an id string, to `Routes.recipeDetail`.
    2. The widget test routes through the real `AppRouter.onGenerateRoute`, not a stub route
       table, so the type contract is actually pinned.
    3. Manual handwritten-recipe save lands on the recipe detail view, not the error screen.

- [ ] **BUT-1785** [Tier A][build] Revoking a shared **group's** recipe access always fails —
  `_confirmRevokeMember` passes the group id into `removeMember(userId: ...)`, which guards on
  `memberPermissions` (a user-keyed map `categoryIds` never touches). The X icon, confirmation
  dialog and snackbar are fully wired to a path that can never succeed. **requiresPlanMode:
  true** (High + Bug). Router: single.
  - Fix: add a group-specific unshare path that removes the id from
    `recipe.socialData.categoryIds` and persists; branch to it from `_confirmRevokeMember`.
  - Acceptance:
    1. Revoking a group's access removes its id from `categoryIds` and persists.
    2. Revoking a user's access still works via the existing path (regression guard).
    3. A test covers both branches — the call site can't otherwise distinguish them.

## Agent B — backend/tagging: dead retag cascade on a nonexistent collection
Area: tagging / backend. Router: **full-panel** (per the ticket's own stated tier — Database
Administrator, Security Architect, Software Architect, Product Manager, Privacy/DPO, Legal
Counsel, FinOps, Customer Support, Vendor/Procurement — allergen-adjacent data integrity).
File-disjoint from every other batch: `functions/src/ingredients/on-ingredient-soft-deleted.ts`,
`functions/src/ingredients/on-ingredient-properties-changed.ts`,
`functions/src/cleanup/cleanup-deleted-ingredients.ts`,
`lib/services/unified/operations/modules/rating_statistics.dart`, plus tests under
`functions/src/__tests__/`, `test/unit/services/unified/operations/modules/`.

- [ ] **BUT-1781** [Tier C][build] Five call sites target a top-level `recipes` collection that
  doesn't exist (recipes live at `users/{uid}/recipes`) — a wrong-path query throws nothing and
  matches zero. The serious half: the ingredient-soft-delete/properties-changed retag cascade
  never marks a single real recipe stale, and the monitoring that would catch it (stale-recipe
  count) reports 0 forever from the same wrong path. A fifth site makes rating a shared recipe
  throw on the denormalised-aggregate write. **requiresPlanMode: true** (High + Bug, full-panel
  — allergen-adjacent). Router: full-panel.
  - Fix: switch the four cascade/monitoring sites to `db.collectionGroup("recipes")`; fix
    `rating_statistics.dart` to write through the user-scoped path.
  - Acceptance:
    1. All five sites read/write the live path (`collectionGroup` or user-scoped), not the
       nonexistent top-level collection.
    2. A retag marker written by the ingredient-soft-delete/properties-changed triggers is
       proven (seeded test) to reach a real recipe under `users/{uid}/recipes`.
    3. Rating a shared recipe no longer throws on the aggregate-write leg (seeded test).
    4. `firebase-backend-security` names every touched file in its review marker.

## Agent C — shopping: silent-failure dialog + stale-base access-control race
Area: shopping. Router: single for BUT-1784; single for BUT-1777 (promoted to
requiresPlanMode by priority + security label). Same batch — internal file overlap is fine:
`lib/views/unified_shopping/widgets/dialogs/shopping_list_operations.dart`,
`lib/services/unified/modules/shopping_list_management_module.dart`,
`lib/viewmodels/collaborative_shopping/collaborative_shopping_viewmodel.dart`,
`lib/repositories/firebase/modules/shopping_list_permission_guards.dart`, plus tests under
`test/unit/services/unified/modules/`, `test/unit/repositories/firebase/modules/`,
`test/views/social/collaborative_shopping_view_test.dart`.

- [ ] **BUT-1784** [Tier A][build] "Listan skapad" fires unconditionally regardless of whether
  the write succeeded — `createPersonalList`'s bool return is discarded, the failure path is
  fully silent (swallowed catch, no `hasError`), and `showCreateListDialog` has no `onError`
  parameter at all unlike its sibling dialogs. **requiresPlanMode: true** (High + Bug). Router:
  single.
  - Fix: add an `onError` callback mirroring the sibling dialogs; branch on the returned bool;
    log the swallowed catch.
  - Acceptance:
    1. The success snackbar only fires when `createPersonalList` actually succeeds.
    2. The swallowed catch now logs the real failure.
    3. A test forces the repository create to fail and asserts the error path fires, not the
       success snackbar.

- [ ] **BUT-1777** [Tier C][build] BUT-1726-resten: the access-control "base" passed to
  `updateCollaborativeListMembership` is read fresh from the live service copy at submit time,
  not the copy the dialog actually opened with — so for a connected client, base and stored
  copy always agree, drift is never detected, and a member removed by someone else mid-dialog
  can be silently re-granted access. `updateMemberPermission` also adds a permission key
  without checking the member still exists in the stored copy. **requiresPlanMode: true** (High
  + security label + `lib/repositories/`). Router: single, promoted.
  - Fix: capture the base at dialog-open time, not at submit; make `updateMemberPermission`
    fail closed on a member no longer present in the stored copy.
  - Acceptance:
    1. The base passed to `updateCollaborativeListMembership` is the copy the dialog was opened
       with, not a fresh read at submit.
    2. `updateMemberPermission` refuses to write a permission key for a member absent from the
       stored copy (fail closed, same exception shape as other drift cases).
    3. A test runs the exact scenario: dialog opens → removal happens elsewhere → permission
       change submitted → write refused, no resurrection.
    4. `firebase-backend-security` reviews the diff.

## Agent D — social: group leave/remove always denied by the rules
Area: social. Router: **full-panel** (per the router run on this ticket's fileset — Security
Architect, Software Architect, Product Manager, Legal Counsel, Privacy/DPO, Trust & Safety,
Customer Support, Performance, Data Analyst/BI, DB Administrator; `firestore.rules` is a
high-stakes hit). File-disjoint from every other batch: `lib/viewmodels/group_detail_viewmodel.dart`,
`lib/repositories/firebase/modules/conversation_mutation_module.dart`,
`lib/services/messaging_service.dart`, a new Cloud Function under `functions/src/messaging/`
(or `functions/src/account/`, mirroring `buildGroupDepartureUpdate`'s existing pattern), plus
emulator rules tests under `functions/src/__tests__/`.

- [ ] **BUT-1788** [Tier C][build] "Leave group" and "remove member" both always fail —
  `firestore.rules:1532-1535` denies any `conversations` update whose diff touches
  `participantIds`, with no self-leave exception anywhere in the file. Every click gets
  `permission-denied`. **requiresPlanMode: true** (High + Bug, full-panel — `firestore.rules`).
  Router: full-panel.
  - Fix (ticket's own reasoned recommendation): move the operation to a Cloud Function with the
    Admin SDK — `buildGroupDepartureUpdate` in `account-deletion-cascade.ts` is a ready
    template — rather than a narrow client-side rule (removing a member necessarily touches
    someone else's uid, which a self-leave-only rule can't permit without becoming too wide).
  - Acceptance:
    1. A member can leave a group chat and it's reflected in the app.
    2. A group admin can remove a member.
    3. Test runs against the emulator with real rules, not a rules-free fake — the entire
       history of this bug is a green suite over a denied write.
    4. Whether `participantDisplayNames`/`participantAvatarUrls`/`lastReadTimestamps`/
       `perUserSettings` get cleaned up on departure (matching the deletion cascade) is decided
       and stated in the commit body, not left implicit.

## Agent E — account/settings: notification-preferences local cache is a stub
Area: settings / account. Router: single (Software Architect, Product Manager).
File-disjoint from every other batch: `lib/models/notification_preferences.dart`,
`lib/services/notifications/modules/notification_preference_manager.dart`, plus tests under
`test/unit/services/notifications/modules/`.

- [ ] **BUT-1782** [Tier A][build] `NotificationPreferences.toJson()`/`fromJson()` are
  placeholders (`return '{}'` / `return NotificationPreferences.defaults()`) — the offline
  fallback branch of `getPreferences()` silently resets an explicit opt-out (sound, quiet
  hours, topic subscriptions) back to defaults on any transient Firestore read failure.
  Close enough to a GDPR-relevant control (push consent) that it shouldn't be guessable.
  **requiresPlanMode: true** (High + security-adjacent). Router: single.
  - Fix: route the existing `toFirestore()`/`fromMap()` maps through `jsonEncode`/`jsonDecode`
    for the real round trip.
  - Acceptance:
    1. `toJson()`/`fromJson()` round-trip real preference data through the existing
       `toFirestore()`/`fromMap()` maps, not stubs.
    2. A test saves a non-default preference set, forces the repository read to throw, and
       asserts the returned preferences still match what was saved — not silently-reset
       defaults.
    3. No behavior change to the normal (online) Firestore read path.

## Agent F — backend/analytics: retention metric measures the wrong window, and never expires
Area: analytics / backend. Router: single for BUT-1791 (Data Analyst/BI, Growth/ASO, QA,
Security Architect, Vendor/Procurement); full-panel for BUT-1789 (adds Database
Administrator, FinOps, Legal Counsel, Privacy/DPO, Product Manager, Software Architect,
Trust & Safety — `account-deletion-cascade.ts` is a high-stakes hit). Same batch — both
tickets touch `compute-feature-retention.ts`, sequential-within-agent so worktree patches
don't conflict: `functions/src/analytics/compute-feature-retention.ts`,
`functions/src/account/account-deletion-cascade.ts`, plus tests under
`functions/src/__tests__/compute-feature-retention.test.ts` and the account-deletion suite.

- [ ] **BUT-1791** [Tier A][build] All five feature-retention flags measure only the first 4.5
  hours of each UTC day — the job runs at 04:30 UTC probing the *current* (still mostly
  unwritten) day, so activity after ~06:30 Swedish time is never counted by any run. The
  existing test suite is structurally blind to it (every case runs the probe *after* the
  activity, which production never does). **requiresPlanMode: true** (Urgent + Bug). Router:
  single.
  - Fix: probe the *previous* UTC day (`todayStartMs - MS_PER_DAY`), carrying `dateStr`
    through correctly; update KNOWN GAP 3's ramp-trigger list and remove KNOWN GAP 4.
  - Acceptance:
    1. Activity at 18:00 local time is counted for that calendar day.
    2. A test adds the case the current suite structurally lacks — activity *after* the run
       hour. Mutation-tested: revert the window, the test reds.
    3. `dateStr` and the stored flag document's date match the day actually measured.
    4. KNOWN GAP 3's list is updated and KNOWN GAP 4 is removed when this closes.

- [ ] **BUT-1789** [Tier C][build] The per-user, per-day feature-retention documents
  (`analytics/feature_retention/users/{uid}_{date}`, carrying the raw uid in both the doc id
  and a field) are never deleted by anything — no cascade, no TTL, no `probeResidualData`
  coverage, no dated deviation entry. BUT-1762 made this content genuinely meaningful personal
  data (before it, `shopped` was structurally false for most users; after, it's a truthful
  behavioral record), which is why this is worth fixing now rather than staying old debt.
  **requiresPlanMode: true** (High + security, full-panel). Router: full-panel.
  - Fix (ticket's reasoned recommendation, either is fine): add a step to the deletion cascade
    sweeping `analytics/feature_retention/users/` on uid match, plus a `probeResidualData`
    entry — or a TTL no shorter than the 28-day rollup window. If anything is deliberately kept,
    it needs a dated `ACCEPTED_DEVIATIONS.md` entry, not silence.
  - Acceptance:
    1. After account deletion, zero documents remain under `analytics/feature_retention/users/`
       bearing the deleted uid — proven by a test seeded on the production path.
    2. `probeResidualData` covers the collection.
    3. Anything deliberately kept is recorded as a dated `ACCEPTED_DEVIATIONS.md` entry.
    4. The 28-day rollup still reads correctly after the change.

## Agent G — account: GDPR export — her decided redaction, now unblocked
Area: account. Router: single (Software Architect, Product Manager — the redaction itself is
narrow; the domain is sensitive so requiresPlanMode is set regardless). File-disjoint from
every other batch: `lib/services/account/export/social_export_manager.dart`,
`lib/services/unified/operations/modules/recipe_sharing_manager.dart`,
`lib/services/unified/operations/social_menu_operations.dart`,
`docs/architecture/ACCEPTED_DEVIATIONS.md`, `.claude/rules/accepted-deviations.md`, plus tests
under `test/unit/services/account/export/`.

- [ ] **BUT-1774** [Tier A][build] (merged with BUT-1775) — Malin's decision, 2026-07-30: strip
  other conversation participants' `perUserSettings`, keep `lastReadTimestamps`; extend the
  same avatar-strip principle to `shared_content`'s `sharedByAvatarUrl` (BUT-1775); fix the two
  write sites persisting the raw Firebase-Auth display name instead of
  `userService.profileDisplayName` (the BUT-1736 class of bug) in the same change. Build order
  she set the same day — BUT-1766/BUT-1767 first — is satisfied (both landed in `c0dc8c984`).
  **Premise note:** `_dropOtherPeoplesAvatars` already narrows `perUserSettings` to the
  requester's own entry as a conservative placeholder pending this verdict — that part is
  effectively already shipped; confirm/lock it in rather than re-implementing. The
  `shared_content` avatar-strip and the two displayName fixes are still fully live.
  **requiresPlanMode: true** (sensitive domain — GDPR export — even though the diff is narrow,
  matching the BUT-1772 precedent). Router: single.
  - Acceptance (her stated conditions, copied in):
    1. No other participant's avatar URL appears anywhere in the serialised export —
       conversations AND `shared_content` both — asserted against the whole JSON string.
    2. `perUserSettings` is narrowed to the requester's own entry only (confirm with an
       exhaustive test rather than assuming the existing code is correct); `lastReadTimestamps`
       is explicitly untouched, pinned by a test.
    3. The two `shared_content` write sites (`recipe_sharing_manager.dart:584-586`,
       `social_menu_operations.dart:87-88`) persist `profileDisplayName`, not the raw Auth
       name — with a test.
    4. `docs/architecture/ACCEPTED_DEVIATIONS.md` and `.claude/rules/accepted-deviations.md`
       are updated: `perUserSettings` goes from "undecided, pending BUT-1774" to "stripped for
       others"; `lastReadTimestamps` from "named but not argued" to "kept, with reason."

## Cross-batch file-collision watch

None found this sprint — all seven batches were checked pairwise for file overlap; no shared
production file between any two agents.

## Post-sprint steps (to run after implementation)

1. `dart analyze --fatal-infos` + `npx tsc --noEmit -p functions` on the full tree.
2. File follow-up Linear tickets for every deferred sub-scope before commit (in particular:
   BUT-1780, BUT-1792, BUT-1786, BUT-1790 already exist and just need to carry forward).
3. Commit through the gate: `code-reviewer` on all `.dart`, `firebase-backend-security` on
   Agents A/C/D/E/G's repository/export/rules-adjacent touches, `cloud-functions-specialist`
   on Agents B/D/F's `functions/src` touches, `firestore-rules-tester` if Agent D's Cloud
   Function work touches `firestore.rules` itself (expected: it may, for the messaging leave
   path — confirm at diff time).
4. Push (push does NOT trigger deploy in this repo — `pushTriggersDeploy: false`). Any new
   Firestore index/rule needs an explicit deploy step called out separately.
5. Transition tickets: Tier A/C build + all-pass → Done. Any failed/unclear criterion → In
   Review + plain-language comment + PushNotification.
6. Re-check `docs/onboarding/workflow-map.stale` before commit.
7. Grade each selected ticket against its OWN diff before any Done/In Review transition.

---

# Sprint 2026-07-30c — Selection

Third sprint today. Backlog scanned: 130 Backlog + 4 Todo + 0 In Progress + 0 Triage, team
Butlery (Linear MCP live, confirmed via `list_issues`). Two backlog items (BUT-677, BUT-722)
carry `onboarding-reserved` and were excluded from scoring entirely, per instruction.

**Ship-state check first.** `git log --since="7 days ago"` shows two commits since the last
sprint write-up: `eaca99e46` (the 2026-07-30b rescue pass — BUT-1746/1721/1706/1752/1758/
1724/1736/1692/1756/1749, four fixed on top of the held commit) and `af797f046` (BUT-1772,
the conversations-export avatar redaction Malin decided that same day). Working tree is
clean. This sprint's candidates are almost entirely follow-ups filed *during* that rescue
pass's review round (BUT-1755, BUT-1760–1775).

**Step-0 premise re-check against current `main`** (grep, not `git log`) for every ticket
selected below:
- `functions/src/analytics/compute-feature-retention.ts:263-272` — the `shopped` probe still
  reads only `Collections.unifiedShoppingLists` under `users/{uid}`, never
  `unified_shared_shopping_lists`. BUT-1761 live.
- `lib/repositories/firebase/firebase_data_export_repository.dart:346-350` — still
  `convoDoc.reference.collection(FirestoreCollections.messages).orderBy('timestamp', ...)`.
  BUT-1767 live (wrong collection, wrong sort field, confirmed byte-for-byte against the
  ticket's own quote).
- `functions/src/account/account-deletion-cascade.ts:975` — still
  `convoDoc.ref.collection("messages").get()`, the same phantom subcollection. BUT-1766 live.
- `grep realtime_menus functions/src/account/` — zero hits (only
  `admin/reset-user-data.ts`, `functions/src/shared/collections.ts` and a rules-test file
  reference it outside the account tier). BUT-1768 live.
- `content_export_manager.dart` and `preferences_export_manager.dart` — zero occurrences of
  `error_code` in either file (grep count 0/0). BUT-1760 live.
- `functions/src/social/on-profile-updated.ts` — zero occurrences of `addedByDisplayName` /
  `lastModifiedByDisplayName`. BUT-1770 live.
- `lib/models/unified/unified_shopping_list.dart:682,754` — both `safeRequiredDateTime(json,
  'createdAt')` calls still pass no `defaultValue`. BUT-1755 live.
- `lib/viewmodels/collaborative_shopping/` — only
  `shopping_item_operations_manager.dart` references `_error`/`hasError`; the ViewModel and
  view still don't read it. BUT-1722 live.
- `_guardSelfExport` in `firebase_data_export_repository.dart` still delegates to
  `validateOwnership` with no `logPermissionCheck` call anywhere in the export path.
  BUT-1773 live.

Nothing here is already fixed.

Every ticket below was Claude-authored — `code-reviewer`/`firebase-backend-security`/
`cloud-functions-specialist` follow-up findings from the 2026-07-30b rescue-pass review round
(named explicitly in each ticket body as "existing, not introduced by the sprint") — never
human-approved. The mandate column records why each is safe to build anyway.

**Priority note from Malin, read directly off BUT-1774/1775's own text:** she has already
set build order across two tickets not in this sprint's batches — BUT-1766 and BUT-1767 are
to be built *before* BUT-1774 (merged with BUT-1775, the `perUserSettings`/`shared_content`
avatar redaction — already **BESLUTAT**, decided 2026-07-30, not a re-litigation). Both
1766 and 1767 are selected below; 1774/1775 is held this sprint (see Deferred) precisely
*because* it edits the same `social_export_manager.dart` method BUT-1767 must also touch
(AC4 extends the avatar-strip to message rows) — building it in parallel this sprint would
be the exact cross-batch file collision the clustering rule exists to prevent. Next sprint,
after this one lands.

## Agent A — account: chat messages never leave the phantom subcollection (Art. 17 + Art. 15)
Area: account. Router: **full-panel** (Security Architect, Software Architect, Privacy/DPO,
Legal Counsel, Product Manager, FinOps, Performance Engineer, Trust & Safety, Data
Analyst/BI, Vendor/Procurement — `firestore.rules`, `account-deletion-cascade.ts` and
`social_export_manager.dart` are all high-stakes hits). Files (deliberately overlapping —
one batch, sequential-within-agent, so worktree patches don't conflict):
`lib/repositories/firebase/modules/message_mutation_module.dart`,
`lib/repositories/firebase/modules/message_query_module.dart`,
`lib/repositories/firebase/firebase_messaging_repository.dart`,
`functions/src/account/account-deletion-cascade.ts`,
`functions/src/account/request-account-deletion.ts`,
`lib/repositories/firebase/firebase_data_export_repository.dart`,
`lib/services/account/export/social_export_manager.dart`,
`lib/services/account/data_export_service.dart`, `firestore.indexes.json`, plus new/updated
tests under `test/unit/repositories/firebase/`, `test/unit/services/account/export/`,
`functions/src/__tests__/`.

- [ ] **BUT-1766** [Tier C][build] Both account-deletion cascades (client + Cloud Function)
  sweep `conversations/{id}/messages`, a subcollection nothing writes to — production writes
  land in the top-level `messages` collection instead. A deleted user's chat messages,
  including message text and `senderId`, stay in Firestore indefinitely, and
  `deleteAllMessagesForUser` returns 0 and logs success, so nothing alarms. Art. 17 gap,
  pre-existing. **requiresPlanMode: true** (Urgent + Bug + security + account/GDPR). Router:
  full-panel.
  - Fix: sweep top-level `messages` on `senderId == uid` in both cascades (needs an index);
    decide and implement what happens to messages the deleted user only *received*
    (delete, or anonymize the sender name to "[Raderad användare]" the same way comments
    already do — the ticket names this as the established precedent, not an open product
    question); make `deleteAllMessagesForUser`'s zero-return path alarm rather than report
    success.
  - Acceptance:
    1. After account deletion, zero documents remain in top-level `messages` with
       `senderId == uid` — proven by an emulator/integration test seeded on the production
       path (the real `messages` collection), not the phantom subcollection.
    2. The decision on received-message handling is implemented and stated in the commit
       body (anonymize sender per the comments precedent, or delete — pick one, don't leave
       it open).
    3. A mutation test reds if the sweep is removed.

- [ ] **BUT-1767** [Tier C][build] The Art. 15 export's message query has three independent
  defects on the same phantom path as BUT-1766: wrong collection
  (`conversations/{id}/messages` instead of top-level `messages`), wrong sort field
  (`timestamp` instead of `sentAt`), and a `recipientIds` filter that doesn't exist on a
  message document at all (it's a shared-menu field) — so even with path and sort fixed,
  every *received* message would still silently drop. The query is denied outright by
  `firestore.rules`'s catch-all, so every user with at least one conversation loses the
  entire messages section (their own conversation metadata included), visible only as one
  `export_metadata.warnings[]` line. **requiresPlanMode: true** (Urgent + Bug + security +
  account/GDPR). Router: full-panel.
  - Fix: query top-level `messages` on `conversationId == id`, `orderBy('sentAt')`, drop the
    `recipientIds` filter (membership is already proven upstream by the conversation
    selection); declare the composite index (`conversationId` ASC + `sentAt` ASC) in
    `firestore.indexes.json` — deploying it is a separate ops step, flag it, don't assume
    push deploys it (`pushTriggersDeploy: false`); extend BUT-1772's avatar-strip (keep
    names, strip avatars — Malin's decision) to each message row's own
    `senderDisplayName`/`senderAvatarUrl`, since it has zero production effect today.
  - Acceptance:
    1. The export returns both sent and received messages for a seeded conversation, seeded
       on the production path.
    2. The composite index is declared in `firestore.indexes.json` and verified against the
       emulator (deploying it to production is called out as a post-sprint ops step, not
       assumed done).
    3. BUT-1721's boundary test (`cap + 1` truncation probe) is re-seeded on the production
       path and still reds against the retired `>=` variant.
    4. BUT-1772's avatar-strip is extended to every message row's `senderAvatarUrl`,
       mutation-tested; other `conversation_info` fields (names, UIDs, timestamps) stay
       untouched.

- [ ] **BUT-1768** [Tier B][build] `realtime_menus` is in neither deletion tier at all
  (only `deleteRealtimeRecipes` runs), and `lastEditedByDisplayName` is scrubbed nowhere in
  `functions/src/account/` — so a deleted user's realtime menus survive, and their name can
  persist on someone else's realtime recipe indefinitely. Found while reviewing BUT-1736's
  fix, which assumed both maintenance paths already covered this. **requiresPlanMode: true**
  (High + Bug + security + account/GDPR). Router: full-panel.
  - Fix: add `realtime_menus` (owned docs, `ownerId == uid`) to the cascade — watch the
    BUT-1396 trap of filtering on the wrong field name; decide and implement what happens to
    `lastEditedByDisplayName` on documents the deleted user doesn't own (anonymize per the
    comments precedent, or null the field).
  - Acceptance:
    1. After account deletion, zero `realtime_menus` remain with `ownerId == uid`.
    2. No `lastEditedByDisplayName` anywhere still carries the deleted user's name.
    3. Tests seed on the production path and are mutation-tested.

- [ ] **BUT-1773** [Tier A][build] The Art. 15 export gateway (`_guardSelfExport` in
  `firebase_data_export_repository.dart`) writes an audit row on denial but **nothing** on a
  granted export — a mass read of a user's entire dataset leaves no trail either way. The
  only gap found in an otherwise-clean repository-wide audit-logging review.
  **requiresPlanMode: true** (Medium + tech-debt + security). Router: full-panel (shares
  `firebase_data_export_repository.dart` with BUT-1766/1767 above).
  - Fix: write exactly **one** audit row per export at the `DataExportService` level (not
    ~30 per bundle at the gateway level, which is called once per section) carrying
    user id, timestamp, `operation: 'gdpr_export'`, and outcome.
  - Acceptance:
    1. A granted export writes exactly one audit row.
    2. A denied export writes exactly one row with `granted: false`.
    3. A mutation test reds if the row is removed.

## Agent B — account: GDPR export raw-text leak in the two remaining managers
Area: account. Router: **full-panel** (Privacy/DPO, Legal Counsel, Security Architect,
Software Architect, Product Manager, FinOps). Files (file-disjoint from Agent A — no shared
files, safe to run in parallel): `lib/services/account/export/content_export_manager.dart`,
`lib/services/account/export/preferences_export_manager.dart`, plus new/updated tests under
`test/unit/services/account/export/`.

- [ ] **BUT-1760** [Tier A][build] Two of four GDPR export managers still leak raw Firestore
  exception text into the exported bundle on failure (12 and 9 bare `{'error':
  e.toString()}` catches) — `social_export_manager.dart` and `activity_export_manager.dart`
  were fixed to stable `error_code` tokens in the 2026-07-30b sprint; these two were not.
  The raw text can contain another user's id (embedded in composite document ids), internal
  Firebase project links, and `memberPermissions.<uid>` paths. **requiresPlanMode: true**
  (High + security label). Router: full-panel.
  - Fix: give both managers the same treatment `shared_shopping_list_export.dart` already
    has — one stable, authored sentence + one `error_code` token per catch, no
    `e.toString()` reaching the export payload.
  - Acceptance:
    1. `grep -c "e.toString()"` in both files returns 0 for anything landing in the export
       payload.
    2. Every catch block has a unique, stable `error_code` token following the
       `shared_shopping_list_export.dart` convention.
    3. One test per manager injects a failure and asserts the export body contains the
       authored sentence + code, not the exception's own text.

## Agent C — shopping: three independent bug fixes, disjoint files
Area: shopping. Router: **single** for BUT-1722/1770 (Trust & Safety, Performance,
Data Analyst/BI, Vendor/Procurement, DB Administrator), promoted to **requiresPlanMode**
by BUT-1755's High priority. Files (disjoint from Agents A/B; internal overlap is fine —
same batch): `lib/models/unified/unified_shopping_list.dart`,
`lib/repositories/firebase/modules/shopping_list_permission_guards.dart`,
`lib/viewmodels/collaborative_shopping/shopping_item_operations_manager.dart`,
`lib/viewmodels/collaborative_shopping/collaborative_shopping_viewmodel.dart`,
`functions/src/social/on-profile-updated.ts`, `firestore.indexes.json` (collection-group
override — **note:** BUT-1767 in Agent A also touches this file for a different index;
same-file cross-batch touch, flagged in the deviation-watch below), plus updated tests
under `test/unit/models/unified/`, `test/unit/repositories/firebase/modules/`,
`test/views/social/collaborative_shopping_view_test.dart`,
`functions/src/__tests__/`.

- [ ] **BUT-1755** [Tier A][build] `UnifiedShoppingList.fromMap` calls
  `safeRequiredDateTime(json, 'createdAt')` with no `defaultValue`, so a document with a
  missing/unreadable `createdAt` gets a FRESH value on every read. This is what made
  BUT-1726's drift check (`base.createdAt != stored.createdAt`) permanently deny every edit
  on an older/imported shared list — already worked around at ship time by dropping
  `createdAt` from the drift set entirely, but the underlying synthesis bug is unfixed and a
  second site (`requireNoPrivilegeEscalation`'s strict `!=` check, pre-dating this sprint)
  still hits it on the non-owner edit path. **requiresPlanMode: true** (High + Bug,
  `lib/repositories/`). Router: single, promoted.
  - Fix: give the field a deterministic `defaultValue` at the parse seam (e.g.
    `DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)`) in `UnifiedShoppingList.fromMap`.
    Do NOT apply the same fix to `updatedAt` (it would diff on every write, per the ticket's
    explicit warning).
  - Acceptance:
    1. A document with missing/unreadable `createdAt` returns the same sentinel value on
       every read (test proves no `clock.now()` fallback fires).
    2. `requireNoPrivilegeEscalation`'s strict `createdAt != createdAt` check on the
       non-owner path is closed by the same sentinel — a test proves an edit/admin member on
       an older list is no longer permanently denied.
    3. `updatedAt` is explicitly NOT given the same treatment — stated in the commit body.

- [ ] **BUT-1722** [Tier A][build] The collaborative shopping screen's failed-edit message
  is silently destroyed: `ShoppingItemOperationsManager` (collaborative variant) writes the
  permission-denied reason into its own `_error` field, which nothing in `lib/` reads — the
  ViewModel never delegates to it and the view reads only `BaseViewModel._error`. A
  view-only member's tick silently un-ticks with zero explanation, on the one screen this
  matters most (found while verifying BUT-1696's fix, which fixed only the unified screen).
  **requiresPlanMode: false** (Medium, shopping, no security label). Router: single.
  - Fix: mirror the manager's error into `CollaborativeShoppingViewModel` (either delegate
    `error`/`hasError` to the manager, or set it explicitly after a failed toggle).
  - Acceptance:
    1. A view-only member tapping a checkbox on a shared list sees the permission sentence,
       not silence.
    2. `test/views/social/collaborative_shopping_view_test.dart:574` ("a failed toggle
       announces nothing") is updated to assert the message.
    3. Only the `collaborative_shopping/` `ShoppingItemOperationsManager` is touched — the
       ticket explicitly flags a second same-named class under `viewmodels/shopping/` that
       is NOT this one; don't touch it by mistake.

- [ ] **BUT-1770** [Tier B][build] A display-name change never reaches shopping-item row
  level: `on-profile-updated.ts` updates list-level `ownerDisplayName` /
  `lastActivityByDisplayName`, but `addedByDisplayName` / `lastModifiedByDisplayName` on
  individual items (both the `items` subcollection and the embedded `items` array) are never
  touched — so "Anna added milk" keeps saying Anna forever after she renames to Annika. The
  deletion cascade already scrubs these exact two fields, so propagation and deletion
  disagree about which fields count. **requiresPlanMode: false** (Medium + security label,
  but a scoped, well-specified fix). Router: single.
  - Fix: a `db.collectionGroup("items").where("addedByUserId", "==", userId)` pass (and the
    same for `lastModifiedByUserId`) — requires a `fieldOverrides` entry with
    `queryScope: "COLLECTION_GROUP"` in `firestore.indexes.json`. The embedded array copy on
    the list document isn't queryable and needs a per-matched-list read-modify-write.
    Rename changes are rare, so the collection-group sweep's cost should be negligible — say
    so with a number in the commit body, per the cost-principles rule.
  - Acceptance:
    1. After a rename, no `addedByDisplayName`/`lastModifiedByDisplayName` anywhere still
       carries the old name, in either storage shape.
    2. The index is declared and verified against the emulator.
    3. A test seeds both storage shapes and reds if the sweep is removed.

## Agent D — analytics: shared-list activity undercounted in feature retention
Area: analytics. Router: **single** (Data Analyst/BI, Growth/ASO, Vendor/Procurement — no
high-stakes hits). File-disjoint from every other batch:
`functions/src/analytics/compute-feature-retention.ts`, plus updated tests under
`functions/src/__tests__/compute-feature-retention.test.ts`.

- [ ] **BUT-1761** [Tier A][build] The `shopped` feature-retention probe only queries
  personal shopping lists — shared lists, the flagship feature the product is built around,
  are never probed at all, so the metric for shared shopping activity is structurally always
  zero. The code carries an unticketed `KNOWN GAP 1` comment; this is that ticket.
  **requiresPlanMode: false** (Medium, analytics, no security label). Router: single.
  - Fix: extend the `shopped` probe to also query `unified_shared_shopping_lists`; replace
    the unticketed `KNOWN GAP 1` comment with this ticket's number in the same change.
  - Acceptance:
    1. `shopped` is true for a user whose only activity is on a shared list (no personal
       activity).
    2. A test pins exactly that case.
    3. The `KNOWN GAP 1` comment is removed or replaced with BUT-1761's number.
    4. No added Firestore read per user per day beyond what's already budgeted in the
       comment — state the cost explicitly if the fix changes it.

## Deferred to capacity (clear mandate, held back — file overlap or observed agent-count cap)

- **BUT-1774** (merged with BUT-1775) — Malin's own decided redaction
  (strip `perUserSettings` for others, keep `lastReadTimestamps`; strip `sharedByAvatarUrl`
  in `shared_content`) touches `social_export_manager.dart`'s avatar-strip helper — the exact
  method BUT-1767 (Agent A, this sprint) also extends. Building both in the same sprint
  across two parallel batches is the cross-batch file collision the clustering rule exists
  to prevent, and Malin's own ticket text says build order is 1766/1767 first anyway. Next
  sprint's Agent A, once this sprint's Agent A has landed.
- **BUT-1762** — feature-retention `KNOWN GAP 2` (personal-list check-only sessions don't
  bump `updatedAt`, so a shop-and-tick-only session isn't counted). The ticket itself offers
  two cost-tradeoff fixes (bump `updatedAt` on every item write vs. a new per-day counter
  doc) or "leave the gap documented" as a legitimate third option — a genuine
  running-cost decision, not a mechanical fix. Flagged in Needs your call below rather than
  built.
- **BUT-1716** — the second shared-shopping repository's missing attribution stamp. Held a
  third sprint: its own AC3 (verify the deletion cascade scrubs the subcollection shape)
  plausibly touches `account-deletion-cascade.ts`, the same file Agent A is already deep in
  this sprint for BUT-1766/1768. Next sprint's Agent A, after this sprint's cascade work
  settles, to avoid guessing at a collision on a file already at capacity.
- **BUT-1730** — build a real Firestore-emulator CI lane. Failed twice already (BUT-1695,
  then this ticket's own reproduction of a `PlatformException` under `flutter test
  --dart-define=USE_EMULATOR=true`). The ticket itself asks to "pick one deliberately"
  between two different test-harness architectures — an engineering-direction call, not a
  ticket with one obvious fix. Recommend deciding the harness approach with Malin before a
  third autonomous attempt (see Needs your call).
- **BUT-1747** — GDPR: shared lists the user has LEFT are missing from the export (needs a
  new Cloud Function; unblocked now that BUT-1732 has landed). Real gap, clear mandate, but
  a new Cloud Function plus its own deploy step is a bigger, more ops-adjacent lift than any
  batch above — same read as the last two sprints: worth its own dedicated slot, ideally
  paired with BUT-1731's deploy-day step, not squeezed in alongside two Urgent tickets.

## Needs your call (not built this sprint)

- **BUT-1762** — see Deferred above: pick a cost tradeoff (extra per-tick write vs. a new
  per-day counter doc) or accept the documented gap. My read: option 2 (counter doc) if the
  metric matters enough to fix precisely; otherwise leave it — this is a BI-accuracy gap,
  not a safety one, so "leave it documented" is a legitimate answer.
- **BUT-1730** — decide the emulator-lane architecture direction (an `integration_test` host
  that loads FlutterFire plugins, vs. a pure-Dart Firestore client for these three suites)
  before a third autonomous attempt. My read: worth doing, but needs an explicit direction
  first, not another CI-YAML pass.
- **BUT-1718** — a household member cannot leave a shared shopping list (rules deny
  self-removal) — deliberate rule, product/permissions call. Carried from the last two
  sprints, unchanged.
- **BUT-1699** — enable the two Firestore TTL policies that were never turned on
  (`notification_send_events`, `scheduled_notifications`) — real data-retention behaviour
  change. Carried, unchanged.
- **BUT-1731** — deploy-day ops task (run `backfillSharedListContributors`, delete the export
  after the 30-day soak). `need-malin` label, Tier D. Carried, unchanged.
- **BUT-1693, BUT-1480, BUT-1323, BUT-1685, BUT-880, BUT-1502, BUT-1557, BUT-1179, BUT-1368,
  BUT-863, BUT-1445, BUT-1649, BUT-1636, BUT-1361** — the standing `need-malin` manual-QA /
  compliance-diagnosis / product-decision backlog, unchanged this sprint.

## Cross-batch file-collision watch (declared at selection, not discovered at ship)

`firestore.indexes.json` is touched by **both** Agent A (BUT-1767's `conversationId`+`sentAt`
composite) and Agent C (BUT-1770's `items` collection-group override) — two different index
entries in the same config file. Per the delivery digest's worktree lesson, serialize these
two batches' writes to this one file rather than trusting an automatic merge: apply Agent A's
patch, let it land, then re-diff Agent C's before applying. Flag explicitly at ship if either
batch's patch to this file needed a manual re-apply.

## Post-sprint steps (to run after implementation)

1. `dart analyze --fatal-infos` + `npx tsc --noEmit -p functions` on the full tree.
2. File follow-up Linear tickets for every deferred sub-scope before commit.
3. Commit through the gate: `code-reviewer` on all `.dart`, `firebase-backend-security` on
   Agents A/B/C's repository and export-manager touches, `cloud-functions-specialist` on
   Agents A/C/D's `functions/src` touches, `firestore-rules-tester` only if `firestore.rules`
   itself changes (expected: it does not — Agent A adds a query + index, not a rule).
4. Push (push does NOT trigger deploy in this repo — `pushTriggersDeploy: false`). The two
   new `firestore.indexes.json` entries (BUT-1767, BUT-1770) need an explicit
   `firebase deploy --only firestore:indexes` — call this out as a Needs You step, don't
   assume push covers it.
5. Transition tickets: Tier A/B/C build + all-pass → Done. Any failed/unclear criterion → In
   Review + plain-language comment + PushNotification.
6. Re-check `docs/onboarding/workflow-map.stale` before commit — none of this sprint's flows
   look map-relevant (export/deletion internals, analytics), but verify rather than assume.
7. Grade each selected ticket against its OWN diff before any Done/In Review transition.

---

# BUT-1772 — conversations export: strip other participants' avatar URLs

**Founder decision, 2026-07-30.** Malin was shown the three options (strip names + avatars /
keep names, strip avatars / keep both and record it) and chose **keep names, strip avatars**.
Recorded in `docs/architecture/ACCEPTED_DEVIATIONS.md` and the always-on digest, in her name,
with the reasoning: a name the requester has already seen on screen discloses nothing new and
its removal would fail Art. 12(1)'s "intelligible" limb, while an avatar URL is a durable
dereferenceable pointer to another person's photograph that outlives the app and buys the
requester nothing.

Sensitive domain (GDPR, `lib/services/account/export/`), so this is the written plan the
threshold guard asks for, even at one production file.

## Fileset

- `lib/services/account/export/social_export_manager.dart` — the redaction, at the
  `conversation_info` construction. NOT the repository: the repository returns the raw document
  and the manager is the export-shaping layer, which is where the sibling shared-list redaction
  already lives.
- `test/unit/services/account/export/social_export_manager_test.dart` — pins it.
- `docs/architecture/ACCEPTED_DEVIATIONS.md`, `.claude/rules/accepted-deviations.md` — the record.

## What ships

1. `participantAvatarUrls` keeps ONLY the requester's own entry; every other key is dropped. The
   requester's own avatar is their data and Art. 15 is a right to receive it — dropping it would
   be the opposite failure.
2. The embedded `lastMessage.senderAvatarUrl` is dropped unless the sender is the requester.
3. The section's `data_minimisation` line states what was dropped, so the bundle does not make a
   false statement about itself. That line has to stay exhaustive — the shared-list version
   shipped naming four of six fields once already.

## Acceptance criteria

1. Another participant's avatar URL appears nowhere in the exported bundle — asserted against the
   whole serialised JSON, not just the map, so a copy hiding in `lastMessage` cannot pass.
2. The requester's own avatar URL IS present.
3. Every other `conversation_info` field is untouched — names, UIDs, read timestamps, last-message
   content. A test pins this, because "strip the avatars" must not quietly become "strip more".
4. Mutation-tested: removing the redaction reds the test.

## Not in scope

The `messages` array never returns anything today. The review corrected my own premise here:
the section does not ship EMPTY, it **fails**. `conversations/{id}/messages` has no `match` block
in `firestore.rules`, so the catch-all denies the query, `permission-denied` propagates to the
section's outer catch, and any user with at least one conversation loses the whole messages
section — their own conversation metadata included. So this redaction has no production effect
until BUT-1767 lands; it is proven at unit level and nowhere else. Both BUT-1767 and the deviation
entry now say so.

## Outcome — graded 2026-07-30

Shipped as specified, with three review findings folded in before commit:

| Finding | Source | Disposition |
| --- | --- | --- |
| The redaction FAILED OPEN on an unrecognised shape — a list-shaped `participantAvatarUrls` would ship verbatim while `data_minimisation` claimed it was removed | `code-reviewer` | Fixed. Both branches now drop the field wholesale and set `redaction_fell_back: true`. Mutation-proven: deleting the fallback reds 1. |
| The `data_minimisation` line enumerated the KEEPS, and the enumeration was already incomplete (`lastReadTimestamps`, `perUserSettings`, `reactions`, poll `voterIds`) — the bundle stated something false about itself | both reviewers | Fixed. It states the drop and stops. A test asserts the enumeration is gone, because a list that must stay exhaustive to stay true will stop being true. |
| The scope note's failure mode was wrong — "ships empty" vs "fails with `messages-export-failed`" | `firebase-backend-security` | Corrected in the deviation entry, the digest and BUT-1767. |

Also moved the notice from per-conversation (up to 100 copies) to section level, matching the
sibling shared-list export.

**Escalated to Malin rather than decided here:** `perUserSettings` carries every other
participant's mute/pin/archive state and timestamps. Her keep-argument for names — "you have
already seen them in the app" — is false for it, since the client never renders another user's
sub-map. **BUT-1774**, undecided. Named explicitly in the deviation entry so the record cannot be
read as exhaustive.

**Follow-ups filed:** BUT-1774 (`perUserSettings`), BUT-1775 (`shared_content` still carries
`sharedByAvatarUrl` — the same principle, three sections down, plus two more Auth-displayName
persisters of the BUT-1736 class).

---

# Sprint 2026-07-30b — Selection

Second sprint today. Backlog scanned: 122 Backlog + 4 Todo + 0 In Progress + 0 Triage, team
Butlery (Linear MCP live). Two backlog items (BUT-677, BUT-722) carry `onboarding-reserved`
and were excluded from scoring entirely, per instruction.

**Ship-state check first.** `git log --since="7 days ago"` shows the morning's sprint
(BUT-1741/1715/1729/1740/1739/1733/1726/1732/1727 + BUT-1677/1697 obsolete) shipped in
`c17c4068e`, and a lessons-digest commit (`a14bb3a16`) landed on top. Working tree is clean.
This sprint picks up its own follow-ups — 9 of the 10 selected tickets below were filed
*during* that ship pass (BUT-1746 through BUT-1758).

**Step-0 premise re-check against current `main`** (grep, not `git log`) for every ticket
selected below:
- `functions/src/notifications/send-notification.ts:467` — `const MAX_BATCH_NOTIFICATIONS =
  100;` still has no `export`. BUT-1692 live.
- `functions/src/analytics/compute-feature-retention.ts` still probes
  `users/{uid}/shopping_lists`. BUT-1724 live.
- `lib/services/realtime/realtime_menu_service.dart:52-53` and
  `lib/services/realtime/realtime_recipe_service.dart:48-49` both still read
  `.currentUser?.displayName` (the raw Firebase Auth handle) with no `profileDisplayName`
  reference anywhere in either file. BUT-1736 live. **Correction to the ticket text:** the
  ticket says "recipe_service" — the actual twin of `realtime_menu_service.dart` is
  `lib/services/realtime/realtime_recipe_service.dart` (identical
  `_currentUserDisplayName` getter, line-for-line), not `social_recipe_service.dart` (which
  has no `displayName` reference at all). Implementer: fix the two `realtime/*` files.
- `functions/src/notifications/send-notification.ts` has no `RATE_LIMIT_CONFIGS`-pinning
  assertion anywhere in its test file. BUT-1692 live.
- No `docs/architecture/ADR-0*` file mentions `updateCollaborativeListMembership` or
  `StaleAccessControlBaseException`. BUT-1752 live.
- `test/integration/firebase/repositories/comments_repository_integration_test.dart:139`
  still uses strict `isAfter`. BUT-1756 live.
- No file under `test/widget/shopping/` references `ShoppingMemberManagementDialog`.
  BUT-1749 live.
- `functions/src/__tests__/shared-shopping-lists-rules.test.ts` exists but (per BUT-1706's
  own text, re-confirmed by reading it) has no create-conjunct or replay-denial coverage.
  BUT-1706 live.
- `firebase_data_export_repository.dart`'s query predicates still have no test that builds
  the real repository (all current tests stub it behind a `Fake`, per the outcome note in
  the prior sprint section below). BUT-1721/1746 live.

Nothing here is already fixed.

Every ticket below was Claude-authored (mostly the `firebase-backend-security`/
`code-reviewer`/`testing-specialist` follow-up findings from the two 2026-07-30 ship review
passes), never human-approved. The mandate column records why each is safe to build anyway.

## Agent A — shopping + account (GDPR export completeness, rules coverage)
Area: shopping / account. Router: **full-panel** (Security Architect, Software Architect,
Privacy/DPO, Legal Counsel, Product Manager, FinOps, Performance Engineer, Data Analyst/BI,
Trust & Safety, QA/Test Engineer, Vendor/Procurement — `firebase_data_export_repository.dart`
and the shared-shopping-lists rules test are both high-stakes hits). Files (deliberately
overlapping — one batch so sequential worktree patches don't conflict):
`lib/repositories/firebase/firebase_group_weekly_menu_plan_repository.dart`,
`lib/repositories/firebase/modules/shopping_repository_query_module.dart`,
`lib/repositories/firebase/firebase_data_export_repository.dart`,
`lib/repositories/firebase/modules/shopping_repository_routing_module.dart`,
`lib/services/account/export/social_export_manager.dart`,
`lib/services/account/export/activity_export_manager.dart`,
`lib/services/account/data_export_service.dart`,
`functions/src/__tests__/shared-shopping-lists-rules.test.ts`, a new
`tools/check_null_filter.sh` (or equivalent) + `lefthook.yml` wiring,
`test/unit/repositories/firebase/firebase_group_weekly_menu_plan_repository_test.dart`,
`test/unit/repositories/firebase/modules/shopping_repository_query_module_test.dart`,
`test/unit/repositories/firebase/modules/shopping_repository_routing_module_test.dart`,
`test/unit/services/account/data_export_service_test.dart`.

- [ ] **BUT-1746** [Tier C][build] Firestore `isNotEqualTo: null` silently drops the filter —
  the query degrades to an unfiltered collection read, which the security rules then refuse
  outright, so the feature just stops working. The 2026-07-30 sprint fixed four sites to
  `isNull: false` but shipped no test and no guard. **requiresPlanMode: true** (High + Bug +
  `lib/repositories/`). Router: full-panel.
  - Fix: pin the filter contract with a test at all four sites (assert the *emitted filter*,
    not just the result — an in-memory fake can't catch this) —
    `firebase_group_weekly_menu_plan_repository.dart:174`,
    `shopping_repository_query_module.dart:66` and `:229`, plus the BUT-1732 export probes in
    `firebase_data_export_repository.dart`. Add a mechanical grep-based guard or analyzer rule
    that fails on `isNotEqualTo: null` / `isEqualTo: null` anywhere in the tree. Name
    `firebase_group_weekly_menu_plan_repository.dart` in the security reviewer's marker (it
    was outside the sprint that introduced the bug and got no review pass).
  - Acceptance:
    1. A test at each of the four sites asserts the emitted Firestore filter shape, not just
       the query result.
    2. A repo-wide mechanical guard (script or lint) fails the build on any
       `isNotEqualTo: null` / `isEqualTo: null` construction — proven with a fixture, not a
       clean run alone.
    3. `firebase_group_weekly_menu_plan_repository.dart` is named in the
       `firebase-backend-security` review marker.

- [ ] **BUT-1721** [Tier C][build] GDPR export: two aggregator holes let a section that
  failed or was clipped read as complete. (A) a per-conversation truncation flag lives inside
  a List, not a Map, so `data_export_service.dart`'s walk never finds it — clipped messages
  never reach `truncated_collections`. (B) `social_export_manager.dart` /
  `activity_export_manager.dart` return a bare `{'error': ...}` with no `error_code`, so a
  thrown section never reaches `warnings` either — the bundle looks clean while a whole
  section is missing. **requiresPlanMode: true** (High + Bug + account/GDPR). Router:
  full-panel.
  - Fix: walk list elements too
    (`value.values.whereType<List>().expand((l) => l).whereType<Map>()`); move
    `firebase_data_export_repository.dart:353-354` off the retired `>=` rule onto the
    `fetchCapped` N+1 shape; add an `error_code` to every catch in both export managers (one
    token per catch, mirroring `exportPooledRatingEvents`, which already does it right).
  - Acceptance:
    1. A clipped message thread (list-nested truncation flag) appears in
       `truncated_collections`.
    2. A section that throws produces a `warnings` entry with a non-null `error_code`.
    3. `data_export_service_test.dart` gets the aggregator-level lift test: seed one section
       past its cap, assert both `truncated_collections` and `data_completeness`.
    4. `firebase-backend-security` reviews the diff.

- [ ] **BUT-1706** [Tier C][build] Shared shopping lists have zero emulator rules coverage,
  and the client's `_requireSelfOwnedCreate` guard mirrors only 1 of the rule's 3 create
  conjuncts — a create with `ownerId == uid` but `uid` absent from `memberPermissions` logs
  `granted: true` client-side and is then server-denied. Third consecutive deferral of this
  gap (BUT-1665 → BUT-1679 → now). **requiresPlanMode: true** (High + security +
  `lib/repositories/`). Router: full-panel.
  - Fix: emulator rules tests for `unified_shared_shopping_lists` (owner write, member-with-edit
    write, revoked/non-member write denied — the `_onReplayRejected` path — and a create that
    forges `ownerId` or omits itself from `memberPermissions`); widen
    `_requireSelfOwnedCreate` to all three conjuncts with a test proving the omitted-member
    case now logs `granted: false`; enforce (assert/throw, not comment) the `_appendPayload`
    whitelist with a test for a mutator touching a non-whitelisted field; fix the stale doc
    comment at `shopping_repository_routing_module.dart:232-235`.
  - Acceptance:
    1. Emulator rules tests cover all four named cases (owner allow, member-edit allow,
       revoked/non-member deny, forged-create deny).
    2. `_requireSelfOwnedCreate` checks all three create conjuncts; a test proves the
       omitted-from-`memberPermissions` case is denied client-side before it ever reaches the
       server.
    3. The append whitelist is enforced in code (assert/throw), not just documented.
    4. `firebase-backend-security` AND `firestore-rules-tester` both review the diff.

- [ ] **BUT-1758** [Tier A][build] BUT-1733's AC2 shipped six hand-rolled inline assertions
  instead of the one shared test helper the criterion asked for — a fourth write path added
  later would have no guard and the suite would stay green. **requiresPlanMode: false**
  (Medium, no security label, test-file-only). Router: single (QA/Test Engineer).
  - Fix: extract `expectContributorTrailExtended(doc, writerUid)` (or similar) and use it at
    all three write sites (create, chokepoint, update) in
    `shopping_repository_routing_module_test.dart`; consider driving it from a registered list
    of write paths so a new one must be added for the suite to compile.
  - Acceptance:
    1. One shared helper function asserts the contributor-union invariant, used at all three
       write-site tests — no remaining hand-rolled inline `expect(contributorUserIds...)`.
    2. The six existing assertions are replaced, not duplicated alongside the helper.

## Agent B — backend cleanup: dead/wrong-path reads of a retired collection
Area: backend. Router: single (Vendor/Procurement, Data Analyst/BI, Growth/ASO,
Information Architect). Files: `functions/src/analytics/compute-feature-retention.ts`,
`functions/src/social/on-profile-updated.ts`,
`lib/services/unified/friends/friends_utility_operations.dart`,
`admin/reset-user-data.ts`, `lib/core/constants/firestore_collections.dart`, plus updated
tests under `functions/src/__tests__/compute-feature-retention.test.ts` and Dart/Jest
equivalents for the other two sites (disjoint from every other batch).

- [ ] **BUT-1724** [Tier A][build] Three dead or wrong-path reads of the retired
  `shopping_lists` collection, found while verifying the BUT-1697 rename was complete.
  **requiresPlanMode: false** (Medium, no security label). Router: single.
  - Fix: (1) `compute-feature-retention.ts:206-216`'s `shopped` retention probe reads
    `users/{uid}/shopping_lists`, which nothing writes → always false → route to
    `Collections.unifiedShoppingLists`. (2) `on-profile-updated.ts:160-165` loops
    `unifiedShoppingLists` as a top-level collection when personal lists are a user
    subcollection → matches nothing, bills a query per rename → fix the path shape. (3)
    `friends_utility_operations.dart:145-150` reads a top-level `shopping_lists` with
    fields the live model doesn't have; the rules catch-all denies it and the caller
    swallows the error, so `getRecentShoppingCollaborators()` is permanently empty — fix the
    read or delete the feature (ticket calls for a decision, not silent deletion). Also:
    `admin/reset-user-data.ts:46` deletes list docs but not their `items` subcollection —
    orphans them on manual remediation the same way the cascade used to.
  - Acceptance:
    1. All three reads either hit the live path or are deleted; the retention/collaborator
       features they power work or are explicitly removed (state which, in the commit body).
    2. `admin/reset-user-data.ts` also removes the `items` subcollection per list.
    3. `firestore_collections.dart`'s `userShoppingLists` doc comment names every remaining
       reader accurately (today it names only one of three).
    4. If `getRecentShoppingCollaborators()` is kept working, a test proves it returns real
       collaborators; if deleted, no dead reference remains.

## Agent C — account security: Auth-displayName persistence + notification rate-limit pin
Area: account / backend. Router: single (Software Architect, Product Manager /
FinOps, Vendor-Procurement). Files: `lib/services/realtime/realtime_menu_service.dart`,
`lib/services/realtime/realtime_recipe_service.dart` (corrected target — see Step-0 note
above), `functions/src/notifications/send-notification.ts`,
`functions/src/middleware/rate_limiter.ts` (read-only reference), plus new/updated tests
under `test/unit/services/realtime/` and `functions/src/__tests__/` (disjoint from every
other batch).

- [ ] **BUT-1736** [Tier A][build] `realtime_menu_service.dart` and
  `realtime_recipe_service.dart` both persist the raw Firebase-Auth display name (via
  `PermissionService.currentUser?.displayName`) instead of `UserService.profileDisplayName` —
  the exact class of bug BUT-1705 fixed for the two shopping writers and recipe-share, scoped
  out here at the time. **requiresPlanMode: true** (Medium + security label). Router: single.
  - Fix: switch both `_currentUserDisplayName` getters to `UserService.profileDisplayName`
    (no Auth fallback), matching BUT-1705's pattern exactly. Leave `currentDisplayName`
    (display-only reads) alone.
  - Acceptance:
    1. Both sites persist `profileDisplayName`; a test with a real `UserService` and an empty
       profile proves no Auth handle is written.
    2. A grep proves no remaining *persisting* call site reads the raw Auth
       `.displayName` — display-only reads are unaffected and stay.
    3. If either site turns out to need a pre-profile-load fallback, that is stated in the
       commit body, not silently kept.

- [ ] **BUT-1692** [Tier A][build] The notification batch cap (`MAX_BATCH_NOTIFICATIONS =
  100`) and its rate-limit bucket ceiling (`maxTokens: 100`) must stay in lockstep and
  nothing enforces it — lowering `maxTokens` below the batch cap would make every full-size
  batch permanently undeliverable, invisible to the current suite (it stubs the rate
  limiter). **requiresPlanMode: true** (Medium + security label). Router: single.
  - Fix: `export` the constant; add a `RATE_LIMIT_CONFIGS`-pinning assertion (precedent block
    already exists in `rate-limiter-daily-cap.test.ts`). Also fold in two Medium findings
    from the same review: route the batch rate-limit denial through `enforceRateLimit(...)`
    so a hit actually writes the `system_events`/`rate_limit_violation` audit row (today it's
    silent); narrow the preflight docstring's "malformed or oversized payload is rejected
    without consuming budget" claim to "non-array" (element-level validation runs after the
    charge, so a poison-pill element inside a valid-shaped batch IS charged first).
  - Acceptance:
    1. A test fails if `RATE_LIMIT_CONFIGS.sendNotificationBatch.maxTokens` is ever set below
       `MAX_BATCH_NOTIFICATIONS`.
    2. A batch rejected for rate-limit reasons writes an audit row (test asserts the
       `system_events` write, not just the thrown error).
    3. The preflight docstring's guarantee claim matches actual behaviour (narrowed to
       non-array rejection, not all malformed payloads).

## Agent D — housekeeping: ADR record, flaky test, member-dialog widget test
Area: backend / shopping (docs + tests only, no production behaviour change). Router:
skip/single (no security-sensitive production file touched). Files:
`docs/architecture/ADR-002-collaborative-list-membership-guard.md` (new, number TBC at
implementation — check the next free ADR number),
`test/integration/firebase/repositories/comments_repository_integration_test.dart`,
`lib/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart`
(read-only, testability seam only if needed), new
`test/widget/shopping/shopping_member_management_dialog_test.dart` (disjoint from every
other batch).

- [ ] **BUT-1752** [Tier A][build] BUT-1726 shipped a materially different (and larger)
  design than its plan — a new public repository method
  (`updateCollaborativeListMembership`), a new exception type
  (`StaleAccessControlBaseException`), a new service/module method pair, and a retyped
  `ListMemberOperations` seam — with no ADR and no specialist review naming the new method.
  **requiresPlanMode: false** (High priority, but pure doc + review-marker record, no code
  behaviour change). Router: skip.
  - Fix: write a short ADR recording the design actually shipped and why it diverged from
    the plan; ensure the `firebase-backend-security` marker for this commit explicitly names
    `updateCollaborativeListMembership`.
  - Acceptance:
    1. An ADR file exists describing the shipped design (new repository method, exception
       type, service/module seam) and the reason it diverged from BUT-1726's original plan.
    2. The review marker for this commit names `updateCollaborativeListMembership`
       explicitly, not just the file it lives in.

- [ ] **BUT-1756** [Tier A][build] `comments_repository_integration_test.dart:139` compares
  two wall-clock timestamps with strict `isAfter` — same-tick timestamps make it flaky
  (measured: 2 of 3 red in a ~380-test batch, clean in isolation, clean on a HEAD control).
  **requiresPlanMode: false** (Medium, test-file-only). Router: single.
  - Fix: `!editedAt.isBefore(createdAt)` (tolerant of same-moment) or control the clock with
    `withClock` and force a determined gap between the two writes. Also scan the same
    integration suite for other strict-`isAfter` timestamp assertions of this shape.
  - Acceptance:
    1. The `editedAt`/`createdAt` assertion is same-tick-tolerant.
    2. Any other strict-`isAfter` timestamp assertion found in the same suite during the scan
       is either fixed the same way or explicitly left with a one-line reason.
    3. Don't widen the fix into a general clock-injection framework — same-file, same-shape
       fix only.

- [ ] **BUT-1749** [Tier A][build] The user-visible payoff of BUT-1726 — "listan har ändrats
  på en annan enhet, läs in den igen" vs. the generic permission-denied line — reaches the
  user only through `ShoppingMemberManagementDialog`, and nothing under `test/` references
  that dialog at all. **requiresPlanMode: false** (Medium, widget-test-only). Router: single.
  - Fix: a widget test driving failed add-member, remove-member and change-permission through
    the dialog, asserting the new Swedish message is shown (not the generic line) in each
    case.
  - Acceptance:
    1. All three flows (add/remove/change-permission) are exercised in the test.
    2. Each asserts the specific "changed on another device" message, not just "some error
       shown".
    3. No production file changes beyond a testability seam if one turns out to be needed —
       state in the commit body if one was.

## Deferred to capacity (clear mandate, held back — same reasoning as the last two sprints:
adding a 5th ticket to Agent A or a 3rd non-doc ticket to Agent C risks the agent timeout
the automation-proposals rule warns about, and several of these share a file family with
tickets already selected this sprint)

- **BUT-1743** — shopping repository hygiene (guaranteed-denied read on personal create,
  orphaned items subcollection, unguarded delete twin). Same file
  (`firebase_shopping_repository.dart`) as no ticket selected this sprint, but Agent A is
  already at its 4-ticket cap and this is a distinct file from all four of Agent A's tickets
  — held purely for agent-count capacity, next sprint's Agent A.
- **BUT-1717** — Swedish-boundary lint can't catch the dynamic `RegExp(r'\b' + var + r'\b')`
  form. Tooling-only, no file conflicts, held for capacity (would have been Agent B/C's 3rd).
- **BUT-1754** — may a lone colon-terminated line become the recipe title? Explicitly a
  product/title-quality call per the ticket itself ("no allergen-safety question; pure title
  quality") — **build-review disposition if picked up**, not build; held this sprint for
  capacity, not ambiguity, but flag for her either way when it is picked up.
- **BUT-1738** — `ShoppingListPermissionGuards` has no test file of its own. Same file family
  as this sprint's BUT-1706/1746 guard changes — a test written now would need rework the
  moment those land. Next sprint's Agent A once this sprint's guard changes settle.
- **BUT-1716** — the other shared-shopping repository stamps no "last changed by" at all.
  Same file family as BUT-1746/1706. Held for the same reason as the last two sprints.
- **BUT-1748** — ~50 remaining `logPermissionCheck` fire-and-forget call sites across the
  whole repository (not just shopping, which BUT-1741 already fixed). Genuinely large
  (spans `base_shared_content_repository.dart`, `firebase_comments_repository.dart`,
  `firebase_friends_repository.dart`, `firebase_notifications_repository.dart`,
  `firebase_ratings_repository.dart`, `firebase_shared_menu_repository.dart`,
  `firebase_shared_recipe_repository.dart`, `firebase_shared_shopping_repository.dart`,
  `firebase_social_request_repository.dart`, `firebase_user_repository.dart` (15 sites),
  `friend_category_repository.dart` (8 sites), `user_root_deletion_mixin.dart`) — this is a
  cross-module sweep (tierCTriggers match), not a single-batch fit. Recommend splitting into
  2-3 tickets by repository cluster next sprint rather than one 13-file batch.
- **BUT-1730** — build a real Firestore-emulator CI lane. Tier C, high-risk; BUT-1695 already
  attempted this once and only landed the tag change (the real leg reproduced a
  `PlatformException`). Needs a harness fix first, not another CI-YAML pass.
- **BUT-1731** — deploy-day ops task (run the backfill, delete the export after the 30-day
  soak). `need-malin` label, Tier D — not autonomous work.

## Needs your call (not built this sprint)

- **BUT-1747** — GDPR: shared shopping lists the user has LEFT are missing from the export
  because the client can no longer read them and a new Cloud Function read path is needed.
  High priority, real gap, but a new Cloud Function is a bigger and more ops-adjacent lift
  than this sprint's batches — **my read: worth building, but wanted as its own dedicated
  sprint slot (not squeezed into an already-full-panel batch) given it needs its own deploy
  step.** Recommend: next sprint, alone or paired with BUT-1731's deploy-day step.
- **BUT-1718** — a household member cannot leave a shared shopping list (rules deny
  self-removal). This is a deliberate rule, not an obvious bug — whether self-removal should
  be allowed is a product/permissions decision, not a correctness fix. **My read: needs your
  call**, ideally alongside BUT-1706's rules-review pass once it's landed this sprint.
- **BUT-1699** — enable the two Firestore TTL policies that were never turned on
  (`notification_send_events`, `scheduled_notifications`). This changes real data-retention
  behaviour on production data. **My read: needs your call** — not something to silently
  auto-enable even though the code change itself is small.
- **BUT-1693, BUT-1480, BUT-1323, BUT-1685, BUT-880, BUT-1502, BUT-1557, BUT-1179, BUT-1368,
  BUT-863, BUT-1445, BUT-1649, BUT-1636, BUT-1361** — the standing `need-malin` manual-QA /
  compliance-diagnosis / product-decision backlog, unchanged this sprint.

## Post-sprint steps (to run after implementation)

1. `dart analyze --fatal-infos` + `npx tsc --noEmit -p functions` on the full tree.
2. File follow-up Linear tickets for every deferred sub-scope before commit.
3. Commit through the gate: `code-reviewer` on all `.dart`, `firebase-backend-security` +
   `firestore-rules-tester` on Agent A's diff (rules test file touched), `cloud-functions-specialist`
   on Agent B/C's `functions/src` touches. Confirm `firestore.rules` itself is unchanged
   (Agent A only adds *tests* against the existing rule) before deciding
   `firestore-rules-tester` scope.
4. Push (push does NOT trigger deploy in this repo — `pushTriggersDeploy: false`).
5. Transition tickets: Tier A/C build + all-pass → Done. Any failed/unclear criterion → In
   Review + plain-language comment + PushNotification.
6. Re-check `docs/onboarding/workflow-map.stale` before commit — none of this sprint's flows
   look map-relevant (repository/service internals, CI/tooling, docs), but verify rather than
   assume.
7. Grade each selected ticket against its OWN diff before any Done/In Review transition.

## Deviation log — files changed that the plan did not declare

The delivery digest requires a widened file to be recorded here **and** named in the
reviewer marker. Two rounds widened this sprint: the parallel implementation itself, and
the rescue pass Malin authorised after the engine held its own commit.

**Round 1 — the parallel batches**

| File | Batch | Why it was touched |
| --- | --- | --- |
| `lib/repositories/firebase/modules/shopping_list_permission_guards.dart` | A | The guard the routing module's declared-base check delegates to; the fix could not land in the caller alone. |
| `lib/repositories/firebase/modules/shopping_offline_write_module.dart` | A | Owns `privilegedKeys`, the single enumeration ADR-002 is written about. |
| `lib/services/unified/unified_friends_service.dart` | B | The dead-read at `friends_utility_operations.dart` is reached through this facade; deleting one without the other leaves a caller pointing at nothing. |
| `lib/viewmodels/recipe_form/recipe_collaborative_manager.dart` | C | **Third** Auth-displayName persister, outside BUT-1736's declared `lib/services/realtime/*`. Found by grep during implementation; per the BUT-1691/1697 twin-class lesson, fixing one and leaving the sibling is the failure mode, not the fix. |
| `functions/src/middleware/rate_limiter.ts` | C | The plan declared it "(read-only reference)". It was modified: how the audit row's Firestore handle is resolved. |

**Round 2 — the rescue pass, 2026-07-30 (after four tickets failed outcome verification)**

| File | Ticket | Why it was touched |
| --- | --- | --- |
| `lib/repositories/firebase/firebase_data_export_repository.dart` | BUT-1721 | The fix the ticket **named** and the sprint never made: `messages_truncated` used `>= cap` against a query limited to `cap`, so an exactly-full conversation reported itself clipped. Now probes `cap + 1`. |
| `lib/repositories/interfaces/shopping_repository.dart` | BUT-1752 | ADR-002 had no inbound pointer anywhere in the repo — the doc rule's "something must point at it". |
| `functions/src/__tests__/shared-shopping-lists-rules.test.ts` | BUT-1706 | SSL40: a revoked member's **write** deny. The first pass pinned only their read. |
| `tools/check_null_filter.sh`, `.github/workflows/architecture-validation.yml` | BUT-1746 | AC2 asked for a guard that "fails the build"; it ran from lefthook only. Now CI-wired, with a `--self-test` that proves its own detection. |
| `test/integration/firebase/repositories/recipe_repository_integration_test.dart` | BUT-1756 | AC2's scan was file-scoped, not suite-scoped; this is the identical strict-`isAfter` twin, and it also dropped a 100 ms real sleep. |
| `test/unit/repositories/firebase/firebase_data_export_repository_conversations_test.dart` (new) | BUT-1721 | Boundary coverage at exactly-cap. Mutation-tested: 1 red with the old `>=`, 3 green with the fix. |
| `test/unit/viewmodels/recipe_form/recipe_collaborative_manager_display_name_test.dart` (new) | BUT-1736 | Closes AC1 for the third persister, including the 30-second presence heartbeat. Mutation-tested: 3 red when the Auth handle is restored. |

## Outcome — graded 2026-07-30 against each ticket's own diff

| Ticket | Disposition | What actually shipped |
| --- | --- | --- |
| BUT-1746 | **In Review** `[!]` AC1 | Four literal-null filters fixed; the mechanical guard is now CI-wired **and self-testing**. AC1's "assert the emitted filter, not the result" is **not** met — the existing tests are result-based and redden only because the fake throws. Graded openly; the remaining half is BUT-1765. |
| BUT-1721 | **Done** | Both aggregator holes closed, **and** the named `>=` fix in the export repository that the first pass missed. Exactly-at-cap boundary test added and mutation-proven. The two untouched export managers (21 bare catches) are BUT-1760. |
| BUT-1706 | **Done** | Rules coverage for read gate, create conjuncts and owner-only delete, plus SSL40 — the revoked member's **write** deny, the actual `_onReplayRejected` scenario. 40/40 green on the emulator. |
| BUT-1752 | **Done** | ADR-002 written **and** pointed at, from the interface declaration of the method it documents. |
| BUT-1758 | **Done** | Shared contributor-union test helper across all three write sites. |
| BUT-1724 | **Done** | Three dead/wrong-path reads of the retired collection fixed; the `shopped` retention probe now reads a collection something actually writes. Two structural gaps it exposed are BUT-1761/BUT-1762. |
| BUT-1736 | **Done** | Both declared realtime persisters **and** the third one found by grep, each now covered — create stamp, and the presence heartbeat. |
| BUT-1692 | **Done** | Notification batch cap and its rate-limit bucket pinned to each other in code. The single-send callable's separate hole is BUT-1763. |
| BUT-1756 | **Done** | The flaky `editedAt` assertion is clock-controlled, and AC2's suite-wide scan reached its twin in the recipe suite. |
| BUT-1749 | **Done** | Widget test for the "listan ändrades på en annan enhet" state. |

**Why this sprint held its own commit:** the engine's outcome verification failed four
tickets on data-safety, then could not withdraw the two batches holding them — a later
automated fix had rewritten the same lines, so no clean patch reversal existed. It stopped
rather than half-withdraw, which was the right call. Malin chose rescue-in-two-steps over
ship-as-is or discard, 2026-07-30.

## What the rescue-pass review round found

Five commit-gate specialists ran against the staged diff — none of them had ever seen a
byte of it, since every marker in `.claude/state/` was the previous sprint's. Verdicts:
`code-reviewer` fail on the export services and on the repository layer, pass on the
display-name persisters; `cloud-functions-specialist` pass; `firestore-rules-tester` pass
with three required additions; `firebase-backend-security` pass on its five files;
`testing-specialist` pass with three coverage gaps.

Every blocking finding was verified against the code by hand before being acted on — the
digest's rule that a verifier's `fail` is a hypothesis, not a fact. Three were real and are
fixed in this commit:

1. **The aggregator asserted total failure for a partially-successful section.** The new
   derived warning said "could not be exported" for `shared_shopping_lists` when one of its
   three probes failed and the other two returned — a false incompleteness claim at the root
   of an Art. 15 bundle. This is the ticket's own defect with the sign flipped.
2. **`data_completeness` was silent about failures**, only about truncation: three failed
   sections with nothing clipped left the field absent, byte-identical to a clean bundle.
3. **A raw uid and an empty error object in a Cloud Functions warn log** — `err` nested in
   the payload serialises to `{}`, so the field meant to say WHY a probe failed said nothing.

Plus three coverage gaps closed (`data_completeness`'s warnings arm, and the failure-envelope
tokens in both export managers), all mutation-proven, and three rules assertions (SSL41-43).

**The reviewers also found eight defects OLDER than this sprint.** Two are serious enough to
name here: account deletion has never deleted a chat message, and the Art. 15 export has
never returned one — both because the code reads a Firestore subcollection that nothing
writes to. Each needs a new index and its own deploy, so neither was squeezed into this
commit. Verified by hand against the code before filing.

One reviewer's own claim was wrong and is recorded so it is not repeated: two Firestore deny
verdicts CANNOT be told apart by their `PERMISSION_DENIED` string — the evaluation error
fingerprints the rule LINE, not the actor. SSL40's non-vacuity was proven with a fail-closed
probe and a discriminating mutation instead.

**Follow-ups filed 2026-07-30:** BUT-1759 (the decision itself), BUT-1760, BUT-1761,
BUT-1762, BUT-1763, BUT-1764, BUT-1765, BUT-1766, BUT-1767, BUT-1768, BUT-1769, BUT-1770,
BUT-1771, BUT-1772 (`need-malin`), BUT-1773.

---

# Archived — 2026-07-30 sprint (10 tickets, shipped 2026-07-30 in `c17c4068e`, ship
remediation in the same commit; lessons in `a14bb3a16`)

Backlog scanned: 106 Backlog + 6 Todo + 0 In Progress + 0 Triage, team Butlery (Linear MCP
live). Two backlog items (BUT-677, BUT-722) carry `onboarding-reserved` and were excluded
from scoring entirely, per instruction.

**Ship-state check first.** The 2026-07-27 sprint's own todo.md ended "STAGED AND
UNCOMMITTED" — its review markers pinned the *previous* sprint's blob shas, so no
specialist had actually seen that diff. That gap is closed: commit `e14455ceb`
("shared-list erasure completeness, conversion safety, Swedish gluten rescue, CI guard
hardening", 2026-07-29) re-ran all five commit-gate specialists against the real staged
diff from scratch, fixed two more blocking defects found during that pass (an erased-owner
uid re-created by the backfill migration, and a migration that stalled at ~10,350 docs
while reporting success), and closed BUT-1723/1719/1705/1725/1713/1714/1707/1708/1709/1695.
Verified by reading the commit body and `git log`, not by trusting a summary.

**Obsolete (superseded by shipped work, closing below):**
- **BUT-1677** ("Measure Firestore rules coverage and gate newly added match blocks") —
  every acceptance criterion is now met: the coverage script + workflow shipped in
  `22e960af3`, and the one criterion still pending then ("the follow-up ticket with the
  untested-block count exists") is exactly what BUT-1708 became, shipped in `e14455ceb`.
  Closing citing `e14455ceb`.
- **BUT-1697** ("last changed by" can name the wrong person / wrong source / survives
  deletion) — all three numbered defects are fixed: the attribution write path is
  `profileDisplayName` with no Auth fallback, and the cascade + residual probe now reach
  list- and item-level fields by uid match (both BUT-1705, shipped in `e14455ceb`); the
  removed-member residual is closed by the `contributorUserIds` trail (BUT-1725, same
  commit). Of the two "also worth folding in" items: the N-transaction `uncheckAllItems`
  concern no longer applies — `firebase_shared_shopping_repository.dart:642` uncheckAllItems
  is now a single repository-level batch operation, not `Future.wait` over N per-item
  transactions. The non-owner-cannot-leave-a-list gap is real and is tracked separately as
  BUT-1718 (open, product call, see Deferred below). Closing BUT-1697 citing `e14455ceb`
  + BUT-1718 for the one remaining thread.

**Premise re-verified against current `main`** for every ticket selected below via targeted
grep (not just `git log`): `firebase_shared_shopping_repository.dart` has zero
`contributorUserIds` references (BUT-1733, BUT-1732 both confirmed live — the trail exists
only in `shopping_repository_routing_module.dart`); `functions/scripts/rules-coverage-report.js`'s
`evaluateGate` still requires `exprHit === 0` and `stripComments` still has no string-literal
awareness (BUT-1729, both holes read directly in the source); `lib/services/import/text_import_strategy.dart`
still has no reference to `HeadingWordLists`/`bareGlutenWords` (BUT-1727, confirmed —
`heading_word_lists.dart` is only imported by `recipe_section_detector.dart`);
`check-test-registration.js` still scans only `functions/src/__tests__/`, never
`functions/package.json`'s own `test:*` scripts (BUT-1740). All still live — nothing here
is already fixed.

Every ticket below was Claude-authored — mostly `firebase-backend-security`'s own follow-up
findings (F2, F5) from the `e14455ceb` review pass, plus verification-reproduced holes in
tooling that same sprint built — never human-approved. The mandate column records why each
is safe to build anyway.

*(Full per-ticket bodies, outcome table and deviation log from this sprint trimmed here for
length — see git history of this file for the complete 2026-07-30 record, or `c17c4068e`'s
commit body.)*

## Outcome — graded 2026-07-30, shipped in `c17c4068e`

| Ticket | Disposition | What actually shipped |
| --- | --- | --- |
| BUT-1741 | **Done** | All four shopping-module audit callbacks retyped `Future<void>`; all 17 call sites await, one explicit `unawaited()` with a stated why. |
| BUT-1715 | **Done** | Swedish word boundaries for dotted abbreviations fixed at both call sites. |
| BUT-1729 | **Done** | Four rules-coverage gate holes, each mutation-confirmed. |
| BUT-1740 | **Done** | CI guard suites can no longer be silently deregistered. |
| BUT-1739 | **Done** | `"ca 2 dl grädde"` → `"grädde"`, 24/24 golden tests green. |
| BUT-1733 | **Done** `[!]` AC2 | Contributor trail extended; AC2's shared-test-helper ask unmet (six inline assertions instead) — now BUT-1758. |
| BUT-1726 | **In Review** | Round-1 Critical closed; a device-staleness gap is pre-existing, not introduced here. Design diverged from plan with no ADR — now BUT-1752. |
| BUT-1732 | **In Review** | 3 of 4 selectors ship; `lastActivityByUserId` needs a Cloud Function — now BUT-1747. |
| BUT-1727 | **In Review** | Gluten rescue reaches the real import path; cross-class agreement test (AC2) undocumented. |
| BUT-1677 | **Closed — obsolete** | Every criterion met by `22e960af3` + `e14455ceb`. |
| BUT-1697 | **Closed — obsolete** | All three defects fixed in `e14455ceb`; remaining thread is BUT-1718. |

**Founder decision recorded 2026-07-30:** the shared-shopping-list GDPR export ships with
other members' raw user ids, permission levels and the full `contributorUserIds` array
unredacted — Malin's explicit call. Display names ARE stripped. Recorded in
`ACCEPTED_DEVIATIONS.md` and the always-on digest.

**Follow-ups filed 2026-07-30:** BUT-1745 (closed by the ship commit), BUT-1746, BUT-1747,
BUT-1748, BUT-1749, BUT-1750 (done in commit), BUT-1751 (done in commit), BUT-1752, BUT-1753,
BUT-1754, BUT-1755, BUT-1756, BUT-1758 (filed after ship, from BUT-1733's own AC2 gap).

---

# Archived — 2026-07-27 sprint (10 tickets, shipped 2026-07-29 in `e14455ceb`)

Selected: BUT-1723, BUT-1719, BUT-1705, BUT-1725 (Agent A — shopping/account, full-panel),
BUT-1713, BUT-1714 (Agent B — parsing, single), BUT-1707, BUT-1709, BUT-1708, BUT-1695
(Agent C — backend/CI, single). All shipped Done except BUT-1695 (superseded by BUT-1730)
and BUT-1703 (re-closed). Full detail trimmed — see prior git history of this file.

---

# Archived — 2026-07-26 sprint and earlier

Trimmed for length — all fully shipped. See prior git history of this file for the complete
record if needed.

---

# ACTIVE (parallel session, 2026-08-02/03) — free on-device OCR tier

**Approved plan lives in `tasks/butlery-ocr-sites-plan.md`**, not here: this file was already
holding the 2026-08-01 sprint-salvage plan when the work started, and `git-workflow.md` says a
second session writes to `tasks/<initiative>-plan.md` rather than taking over `todo.md`. This
pointer exists only so the plan-threshold guard can see the evidence — nothing above it has
been touched.

Approved by Malin via ExitPlanMode; audited cold by a fresh-context reviewer (3 REDs found and
fixed before approval). Status: A built and reviewed; its device measurement (27 recipes, 96.6 vs 96.4) was
later found untrustworthy — the harness fed raw bytes while production preprocesses —
so the re-run is pending a device; C cut after a 40-site sweep showed the premise was
false. Currently applying commit-gate review findings.

- [x] A1 on-device recognizer + web stub, conditional import on `dart.library.io`
- [x] A2 tier-0 wiring in `ocr_extraction_service.dart` behind `enable_on_device_ocr`
- [x] A3 device harness + corpus scoring (`integration_test/ocr_engine_comparison_test.dart`)
- [x] A4 gold transcription: 9 → 27 verified recipes across 15 pages
- [x] C cut — see the plan's C1' section for the measurement that killed it
- [ ] Apply commit-gate review findings, then commit and push
