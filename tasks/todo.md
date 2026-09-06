# BUT-2020 — receptimport från arla.se misslyckas alltid

## Vad som är mätt

`ArlaRecipeParser.parseRecipe` returnerade `null` för varje arla.se-sida byggd som den
hämtade fixturen. Mätt 2026-09-05 mot en sida hämtad samma dag, och pinnat av
`DEFECT:`-fall i `test/unit/services/extraction/site_parsers/real_structure_test.dart`
som skrevs för att bli röda när det här landar.

Tre oberoende orsaker, var och en tillräcklig. Detaljerna står i ärendet; det som styr
planen är att **orsak 1 och 2 båda måste lagas för att någonting ska ändras** — mätt: att
bara laga orsak 1 lämnar kvaliteten på 0.70 mot tröskeln 0.80, alltså fortfarande `null`.

## Ändringar

### 1. `lib/utils/recipe_scraper.dart` — läs attributet ur DOM:en, inte ur råtexten

`_extractJsonLd` matchade `type=["']?application/ld\+json` med en regex över **rå
HTML**. Arla skriver `application/ld&#x2B;json`, så den träffar aldrig.

Fixen är **inte** att lägga till `&#x2B;` i regexen. Nästa sajt stavar det på ett fjärde
sätt. I stället: tolka dokumentet en gång och plocka `script`-elementen, så löser
HTML-tolken varje teckenreferens åt oss — det är precis vad en tolk är till för.

Behåll `hadJsonLdBlocks`-signalen. Den är det som skiljer "sidan har ingen strukturerad
data" från "sidan hade strukturerad data men vi fick inget ur den", och utan den ser båda
likadana ut. Det är den egenskap `butlery-9f` namngav och som gjorde felet osynligt.

### 2. En delad utplattning av `HowToSection`

`recipeInstructions` kan vara en lista av `HowToSection` vars steg ligger i
`itemListElement`. Det är standard schema.org, inte Arla-specifikt.

Fyra filer bär samma trasiga filter — `{arla,ica,koket,recept}_recipe_parser.dart`,
alla `inst is Map && inst['text'] != null` — plus `RecipeQualityScorer._extractInstructions`.
Alla fem lagas genom **en** delad hjälpare, inte fem kopior; fem kopior av ett beslut är
hur de driver isär.

`schema_org_tier.dart` hanterar redan formen och är förlagan — **med en avvikelse jag inte
kopierar**: den lägger till sektionens `name` som ett eget steg, så "Första instruktionen"
blir instruktion nummer ett. Rubriken är ingen tillagning. Min utplattning tar sektionens
egna steg och hoppar över dess namn när `itemListElement` finns.

### 2b. Tillagt 2026-09-05 efter granskning: fixen nådde inte hela vägen

`code-reviewer` mätte att samma matchning över RÅ källkod lever kvar på fler ställen,
och att ett av dem kör **före** ändringen ovan: `HtmlSanitizer.sanitize()`s `preserveWhen`
tog bort Arlas script MED innehåll innan schema.org-tiern läste det. Bara den vägen
saneras: `sanitize()` har en enda anropare i `lib/` (`parsing_context.dart:89`). Tier 2
och tier 3:s strukturerade halva läser RÅ HTML (`url_import_strategy.dart:133` och
`:162`); parserhalvorna går via `ParsingContext.fromUrl` och saneras.

Lagat: `html_sanitizer.dart` (`preserveWhen` + `_scriptTagPattern`) och
`_hasOnlyNonRecipeJsonLd` i `url_import_strategy.dart`.

**Detta är en sanerare — varje breddning av ett UNDANTAG är en potentiell försvagning.**
Två rester, i motsatta riktningar: mönstret är för SVAGT mot ett `type=` inuti ett annat
attributs värde (BUT-2034), och för STRÄNGT mot stavningar av `+` som parsern löser
upp (BUT-2037) — en regel, inte en uppräkning.

`firebase-backend-security` mätte att `preserveWhen` aldrig krävt ett riktigt
`type=`-attribut — den testade en naken delsträng, så kryphålet var levande hela tiden.
Samma granskning visade att en `\b`-avgränsning inte räcker
(`data-type=` passerar) och att mönstret måste avgränsas i BÅDA ändar.

Ingen konsument renderar det sanerade innehållet i dag — alla fyra läsare av
`sanitizedContent` är parsningstiers — så det här är djupförsvar, inte en levande XSS.
Nästa konsument som renderar det ärver en.

### 3. Orsak 3 lagas INTE här

CSS-fallbacken hittar inte Arlas tabell (`<th>` med namn, `<td>` med mängd). Med orsak 1
och 2 lagade når vi aldrig fallbacken för den här sajten, så den är inte längre på den
kritiska vägen. Att bygga tabellstöd är en egen ändring med egen risk för de tre andra
sajterna. Ärendet får en notering; DEFECT-testet för orsak 3 står kvar och är fortfarande
sant.

## Tester

De fyra DEFECT-fallen för orsak 1 och 2 **ska bli röda** — det är kvittot. De ersätts i
samma edit av den positiva assertionen: `parseRecipe(realStructureKassler)` ger 8
ingredienser och 4 steg. Utan den står Arlas fungerande väg opinnad efter lagningen
(BUT-1849:s klass).

Testet som pinnar att fixturen bär den teckenkodade stavningen står kvar oförändrat och
ska vara grönt — det skyddar fixturen, inte parsern.

Muteringsprov, ett i taget, med `.dart_tool/flutter_build` rensat mellan mutation och
körning. Endast rött räknas.

Regressionsyta: hela `test/unit/services/extraction/` och `test/golden/` — de fyra
parsersviterna delar den hjälpare som ändras, och `koket`/`recept`/`ica` har egna
instruktionstester som måste stå kvar gröna.

## Risk

Låg och begränsad till receptimport. Värsta utfallet om utplattningen är fel är att steg
dubbleras eller tappas för en sajt — vilket parsersviterna fångar. Ångras med en revert.
Ingen användardata, inga regler, ingen Firestore.

## Vad det betyder i klartext

Att importera ett recept från Arla har aldrig fungerat — appen har svarat "hittade inget
recept" fast receptet fanns. Två saker lagas: vi läser sidan som en webbläsare gör i
stället för att leta i råtexten, och vi hittar tillagningsstegen även när sajten grupperar
dem. Testerna som bevisar buggen blir röda när fixen landar, vilket är själva kvittot på
att den bet.
