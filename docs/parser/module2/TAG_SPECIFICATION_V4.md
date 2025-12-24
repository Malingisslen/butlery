# BUTLERY TAG SPECIFICATION

**Version 4.0 • MASTER EDITION • December 2024**

Kombinerar taggspecifikation med Butlery-integration (IngredientService, Firebase, Hive)

---

## Sammanfattning

| Mätvärde | Antal | Kommentar |
|----------|-------|-----------|
| Totalt taggar | 168 | 17 kategorier |
| Tier 1 (kritiska) | 62 | Implementera först |
| Tier 2 (viktiga) | 74 | Implementera därefter |
| Tier 3 (nice-to-have) | 32 | Baserat på användarbehov |
| Properties totalt | 41 | 20 befintliga + 21 nya |
| Beräkningsfaser | 4 | Dependency-ordning |
| Coverage-krav | ≥95% | För säkerhetskritiska taggar |

---

## Designbeslut

### Namnkonventioner
- Svenska taggnamn med bindestreck: `under-15-min`, `innehåller-gluten`
- Engelska tekniska termer där svenska saknas: `comfort-food`
- Gemener med kebab-case

### Tier-system (färgkodade)

| Tier | Färg | Betydelse | Implementation |
|------|------|-----------|----------------|
| Tier 1 | 🔴 Röd | Kritiska - allergener, grundläggande dietary | Implementera först |
| Tier 2 | 🟠 Orange | Viktiga - cuisine, metoder, praktiska | Implementera därefter |
| Tier 3 | 🟢 Grön | Nice-to-have - nischade, subjektiva | Baserat på användarbehov |

### Coverage-krav
- ≥95% för säkerhetskritiska taggar (allergener, dietary)
- ≥90% för dietary preferences (keto, paleo, fodmap)
- Coverage = andel ingredienser som finns i databasen med rätt properties

### Negativa Cuisine-triggers

För att förhindra att ett recept får flera motstridiga cuisine-taggar:
- **Italiensk**: ≥3 av [pasta,parmesan...] OCH INTE [sojasås,sesamolja,fisksås]
- **Kinesisk**: ≥3 av [sojasås,sesamolja...] OCH INTE [parmesan,fisksås,kokosmjölk]

---

## Definitioner

### Avancerade tekniker (för svårighetsgrad)
sous vide, temperera choklad, jäsa deg över natten, emulgera, flambera, reducera till, dra fond, filera fisk, bena ur kött, rulla sushi, göra egen pasta, spritsa, dekorera tårta

### Pantry-staples (exkluderas från ingrediensräkning)
salt, peppar, vatten, matolja, olivolja, smör, socker, vetemjöl, vinäger, soja (bas)

### Kräftdjur vs Blötdjur
- **Kräftdjur (crustacean)**: räkor, krabba, hummer, kräftor, langust
- **Blötdjur (mollusc)**: musslor, ostron, bläckfisk, sniglar, snäckor

⚠️ Dessa är separata EU-allergener och måste hanteras separat!

### Trädnötter vs Jordnötter
- **Trädnötter (tree-nut)**: mandel, hasselnöt, valnöt, cashew, pistage, pekannöt
- **Jordnötter (peanut)**: jordnöt, jordnötssmör (är baljväxt, inte nöt!)

Vissa är allergiska mot bara en typ, därför finns `trädnötsfri` och `jordnötsfri` separat.

---

## Properties i Ingrediensdatabasen

Totalt 41 properties. 20 finns redan i databasen, 21 nya behöver läggas till.

### Befintliga Properties (20 st) ✓

| Property | Kategori | Används för | Tier |
|----------|----------|-------------|------|
| `animal-product` | Dietary Base | vegansk | Tier 1 |
| `plant-based` | Dietary Base | (validering) | Tier 1 |
| `meat` | Dietary Base | vegetarisk, innehåller-kött | Tier 1 |
| `seafood` | Dietary Base | vegetarisk, pescetarian | Tier 1 |
| `dairy` | Dietary Base | mjölkfri, innehåller-mjölk | Tier 1 |
| `egg` | Dietary Base | äggfri, innehåller-ägg | Tier 1 |
| `contains-gluten` | Allergens | glutenfri, innehåller-gluten | Tier 1 |
| `contains-lactose` | Allergens | laktosfri, innehåller-laktos | Tier 1 |
| `tree-nut` | Allergens | trädnötsfri, innehåller-trädnötter | Tier 1 |
| `peanut` | Allergens | jordnötsfri, innehåller-jordnötter | Tier 1 |
| `shellfish` | Allergens | (ersätts av crustacean+mollusc) | Tier 1 |
| `pork` | Meat Detail | fläskfri, halalanpassad | Tier 1 |
| `high-protein` | Nutrition | proteinrik | Tier 2 |
| `high-fiber` | Nutrition | fiberrik | Tier 2 |
| `high-fat` | Nutrition | lyxig, energität | Tier 2 |
| `umami` | Taste | umami (smakprofil) | Tier 3 |
| `sweet` | Taste | söt (smakprofil) | Tier 3 |
| `sour` | Taste | syrlig (validering) | Tier 3 |
| `summer-seasonal` | Season | sommar | Tier 2 |
| `winter-seasonal` | Season | vinter | Tier 2 |

### Nya Properties att Lägga Till (21 st)

| Property | Beskrivning | Exempel-ingredienser | Tier |
|----------|-------------|----------------------|------|
| `crustacean` | Är kräftdjur (EU-allergen) | räkor, krabba, hummer, kräftor | Tier 1 |
| `mollusc` | Är blötdjur (EU-allergen) | musslor, ostron, bläckfisk, sniglar | Tier 1 |
| `fish` | Är fisk | lax, torsk, sill, tonfisk | Tier 1 |
| `soy` | Innehåller soja (EU-allergen) | sojasås, tofu, edamame, tempeh, miso | Tier 1 |
| `sesame` | Innehåller sesam (EU-allergen) | sesamfrö, sesamolja, tahini | Tier 1 |
| `celery` | Innehåller selleri (EU-allergen) | selleri, sellerisalt, supperöt | Tier 1 |
| `mustard` | Innehåller senap (EU-allergen) | senap, senapskorn, dijonsenap | Tier 1 |
| `lupin` | Innehåller lupin (EU-allergen) | lupinmjöl, lupinfrön | Tier 1 |
| `alcohol` | Innehåller alkohol | vin, öl, konjak, rom, likör | Tier 1 |
| `sulfites` | Innehåller sulfiter >10mg/kg | vin, torkad frukt, vinäger | Tier 2 |
| `is-spicy` | Ger hetta/styrka | chili, jalapeño, cayenne, sriracha | Tier 2 |
| `added-sugar` | Är tillsatt socker | socker, sirap, honung, lönnsirap | Tier 2 |
| `legume` | Är baljväxt | linser, kikärtor, bönor, ärtor | Tier 2 |
| `grain` | Är spannmål | vete, havre, råg, ris, majs | Tier 2 |
| `game` | Är viltkött | älg, rådjur, vildsvin, hjort | Tier 2 |
| `high-fodmap` | Hög FODMAP-halt | vitlök, lök, äpple, vete, mjölk | Tier 2 |
| `spring-seasonal` | Vårsäsong | sparris, rabarber, ramslök, nässla | Tier 2 |
| `autumn-seasonal` | Höstsäsong | svamp, kantareller, äpple, pumpa | Tier 2 |
| `pantry-staple` | Basråvara (exkluderas) | salt, peppar, vatten, olja | Tier 3 |
| `premium-ingredient` | Dyr/lyxig ingrediens | oxfilé, hummer, saffran, tryffel | Tier 3 |
| `doesnt-freeze-well` | Fryser dåligt | sallad, gurka, majonnäs, gräddfil | Tier 3 |

---

## Beräkningsordning (Dependency Graph)

Taggar MÅSTE beräknas i rätt ordning eftersom vissa beror på andra. Fyra faser:

| Fas | Antal taggar | Beroenden | Beskrivning |
|-----|--------------|-----------|-------------|
| Fas 1 | 112 | Inga | Grundtaggar - direkt från rådata |
| Fas 2 | 19 | Fas 1 | Enkla härledda - enkla kombinationer |
| Fas 3 | 16 | Fas 1 + 2 | Komplexa härledda - flera beroenden |
| Fas 4 | 21 | Fas 1 + 2 + 3 | Mood/Occasion - beror på många taggar |

---

## Fas 1: Komplett Tagglista (112 taggar)

Grundtaggar som beräknas direkt från data utan beroenden. Kan köras parallellt.

### 1.1 Tidstaggar (5 st)

| Tagg | Trigger | Datakälla | Tier |
|------|---------|-----------|------|
| `under-15-min` | totalTime ≤ 15 | totalTime | 1 |
| `under-30-min` | totalTime ≤ 30 | totalTime | 1 |
| `under-45-min` | totalTime ≤ 45 | totalTime | 1 |
| `under-60-min` | totalTime ≤ 60 | totalTime | 1 |
| `över-60-min` | totalTime > 60 | totalTime | 2 |

### 1.2 Allergen-contains (18 st)

| Tagg | Trigger | Property | Tier |
|------|---------|----------|------|
| `innehåller-gluten` | ≥1 ingrediens har 'contains-gluten' | contains-gluten | 1 |
| `innehåller-laktos` | ≥1 ingrediens har 'contains-lactose' | contains-lactose | 1 |
| `innehåller-mjölk` | ≥1 ingrediens har 'dairy' | dairy | 1 |
| `innehåller-ägg` | ≥1 ingrediens har 'egg' | egg | 1 |
| `innehåller-trädnötter` | ≥1 ingrediens har 'tree-nut' | tree-nut | 1 |
| `innehåller-jordnötter` | ≥1 ingrediens har 'peanut' | peanut | 1 |
| `innehåller-nötter` | ≥1 'tree-nut' ELLER 'peanut' (paraply) | tree-nut\|peanut | 1 |
| `innehåller-skaldjur` | ≥1 ingrediens har 'crustacean' | crustacean | 1 |
| `innehåller-blötdjur` | ≥1 ingrediens har 'mollusc' | mollusc | 1 |
| `innehåller-fisk` | ≥1 ingrediens har 'fish' | fish | 1 |
| `innehåller-soja` | ≥1 ingrediens har 'soy' | soy | 1 |
| `innehåller-sesam` | ≥1 ingrediens har 'sesame' | sesame | 1 |
| `innehåller-selleri` | ≥1 ingrediens har 'celery' | celery | 2 |
| `innehåller-senap` | ≥1 ingrediens har 'mustard' | mustard | 2 |
| `innehåller-lupin` | ≥1 ingrediens har 'lupin' | lupin | 2 |
| `innehåller-sulfiter` | ≥1 ingrediens har 'sulfites' | sulfites | 2 |
| `innehåller-fläsk` | ≥1 ingrediens har 'pork' | pork | 1 |
| `innehåller-kött` | ≥1 ingrediens har 'meat' | meat | 1 |
| `innehåller-alkohol` | ≥1 ingrediens har 'alcohol' | alcohol | 1 |

### 1.3 Dietary-free (16 st)

| Tagg | Trigger | Tier |
|------|---------|------|
| `glutenfri` | INGEN 'contains-gluten' OCH coverage ≥95% | 1 |
| `laktosfri` | INGEN 'contains-lactose' OCH coverage ≥95% | 1 |
| `mjölkfri` | INGEN 'dairy' OCH coverage ≥95% | 1 |
| `äggfri` | INGEN 'egg' OCH coverage ≥95% | 1 |
| `trädnötsfri` | INGEN 'tree-nut' OCH coverage ≥95% | 1 |
| `jordnötsfri` | INGEN 'peanut' OCH coverage ≥95% | 1 |
| `nötfri` | INGEN 'tree-nut' OCH INGEN 'peanut' OCH coverage ≥95% | 1 |
| `skaldjursfri` | INGEN 'crustacean' OCH coverage ≥95% | 1 |
| `blötdjursfri` | INGEN 'mollusc' OCH coverage ≥95% | 1 |
| `fiskfri` | INGEN 'fish' OCH coverage ≥95% | 1 |
| `sojafri` | INGEN 'soy' OCH coverage ≥95% | 1 |
| `sesamfri` | INGEN 'sesame' OCH coverage ≥95% | 2 |
| `alkoholfri` | INGEN 'alcohol' OCH coverage ≥95% | 1 |
| `fläskfri` | INGEN 'pork' OCH coverage ≥95% | 1 |
| `vegetarisk` | INGEN 'meat' OCH INGEN 'fish' OCH INGEN 'crustacean' OCH INGEN 'mollusc' OCH coverage ≥95% | 1 |
| `vegansk` | INGEN 'animal-product' OCH coverage ≥95% | 1 |

### 1.4 Protein-taggar (15 st)

| Tagg | Trigger | Hierarki | Tier |
|------|---------|----------|------|
| `kyckling` | ingrediens: kyckling-variant | - | 1 |
| `nötkött` | ingrediens: nöt-variant [nötfärs,biff,entrecote,högrev,oxfilé] | - | 1 |
| `fläskkött` | ingrediens: fläsk-variant [fläskfilé,bacon,sidfläsk,skinka] | - | 1 |
| `lamm` | ingrediens: lamm-variant | - | 1 |
| `anka` | ingrediens: anka-variant | - | 2 |
| `fisk` | ≥1 ingrediens har 'fish' (paraply-tagg) | lax,torsk,sill→fisk | 1 |
| `lax` | ingrediens: lax-variant → sätter även fisk=true | →fisk | 1 |
| `torsk` | ingrediens: torsk-variant → sätter även fisk=true | →fisk | 2 |
| `sill` | ingrediens: sill-variant → sätter även fisk=true | →fisk | 2 |
| `räkor` | ingrediens: räk-variant | →skaldjur | 1 |
| `skaldjur` | ≥1 'crustacean' ELLER 'mollusc' (paraply) | räkor→skaldjur | 1 |
| `tofu` | ingrediens: tofu, tempeh, seitan | - | 1 |
| `baljväxter` | ingrediens: linser, kikärtor, bönor etc | - | 1 |
| `ägg` | ≥2 ägg ELLER titel:'omelett\|frittata' — OCH NOT dessert-kontext | - | 1 |
| `vilt` | ≥1 'game' ELLER ingrediens: älg, rådjur, vildsvin | - | 2 |

### 1.5 Bas/Kolhydrat-taggar (6 st)

| Tagg | Trigger | Tier |
|------|---------|------|
| `pastabaserad` | ingrediens: pasta-typ (spaghetti, penne, fusilli, etc) | 1 |
| `risbaserad` | ingrediens: ris-typ | 1 |
| `potatisbaserad` | ingrediens: potatis-typ | 1 |
| `nudelbaserad` | ingrediens: nudel-typ (risnudlar, udon, etc) | 2 |
| `brödbaserad` | ingrediens: bröd-typ (bröd, tortilla, pita, etc) | 2 |
| `fullkorn` | ingrediens: quinoa, bulgur, råris, fullkornspasta | 2 |

### 1.6 Tillagningsmetod (14 st)

| Tagg | Instructions-keywords | Tier |
|------|----------------------|------|
| `ugnsbakad` | 'ugn\|°C\|grader\|baka\|gratinera' | 1 |
| `stekt` | 'stekpanna\|stek\|fräs\|bryna' OCH NOT 'ugn' | 1 |
| `grillad` | 'grill\|grilla\|kolgrill\|grillpanna' | 1 |
| `kokt` | 'koka\|sjuda\|kastrull' | 1 |
| `ångkokt` | 'ångkoka\|ånga\|steam' | 2 |
| `pocherad` | 'pochera\|pocherad\|sjudande vatten' | 2 |
| `friterad` | 'frityr\|fritera\|djupstekt' | 2 |
| `airfryer` | 'airfryer\|air fryer\|luftfritös' | 1 |
| `slow-cooker` | 'slow cooker\|crock pot\|långsamkokare' | 1 |
| `tryckkokare` | 'tryckkokare\|instant pot\|pressure' | 2 |
| `sous-vide` | 'sous vide\|vakuumpåse\|vattenbad' | 3 |
| `wokad` | 'wok\|woka\|wokpanna' | 1 |
| `microugn` | 'micro\|mikro\|mikrovågsugn' | 2 |
| `rökt` | 'röka\|rök\|smoker\|rökspån' (aktiv rökning) | 3 |

### 1.7 Rätttyp från titel (21 st)

| Tagg | Titel-keywords | Tier |
|------|---------------|------|
| `soppa` | 'soppa\|buljong\|bisque\|chowder' | 1 |
| `sallad` | 'sallad\|coleslaw\|tabbouleh' | 1 |
| `gryta` | 'gryta\|stew\|goulash\|kalops' | 1 |
| `gratäng` | 'gratäng\|gratin\|casserole' | 1 |
| `curry` | 'curry' | 1 |
| `smörgås` | 'smörgås\|macka\|sandwich\|wrap' | 1 |
| `hamburgare` | 'burger\|hamburgare' | 1 |
| `pizza` | 'pizza\|focaccia\|calzone' | 1 |
| `taco` | 'taco\|burrito\|fajita\|enchilada' | 1 |
| `bowl` | 'bowl\|poke\|buddha bowl' | 2 |
| `paj` | 'paj\|pie\|quiche\|tarte' | 1 |
| `kaka` | 'kaka\|tårta\|brownie\|kladdkaka' | 1 |
| `bröd` | 'bröd\|limpa\|fralla' | 2 |
| `köttbullar` | 'köttbullar\|meatballs' | 1 |
| `omelett` | 'omelett\|frittata\|äggröra' | 2 |
| `pannkaka` | 'pannkaka\|pannkakor\|crêpe\|plättar' (EJ våffla) | 1 |
| `våffla` | 'våffla\|våfflor\|waffle' (separat från pannkaka) | 1 |
| `smoothie` | 'smoothie\|shake' | 2 |
| `wok` | 'wok\|stir-fry' | 2 |
| `dipp` | 'dipp\|hummus\|guacamole\|tzatziki' | 2 |
| `sås` | 'sås\|sauce\|dressing\|pesto' | 2 |

### 1.8 Cuisine (17 st)

| Tagg | Positiv trigger (≥N av) | Negativ trigger | Tier |
|------|------------------------|-----------------|------|
| `svensk` | ≥3: potatis,dill,lingon,grädde,falukorv,köttbullar,sill | sojasås,sesamolja | 1 |
| `italiensk` | ≥3: pasta,parmesan,olivolja,basilika,tomat,mozzarella | sojasås,sesamolja,fisksås | 1 |
| `mexikansk` | ≥3: tortilla,lime,koriander,svarta bönor,avokado,jalapeño | sojasås,parmesan | 1 |
| `thailändsk` | ≥3: kokosmjölk,lime,fisksås,koriander,citrongräs | parmesan | 1 |
| `indisk` | ≥3: garam masala,gurkmeja,spiskummin,ingefära,chili,yoghurt | - | 1 |
| `kinesisk` | ≥3: sojasås,sesamolja,ingefära,ostronsås,hoisinsås | fisksås,kokosmjölk | 1 |
| `japansk` | ≥2: miso,wasabi,nori,dashi,mirin,sake,teriyaki | - | 1 |
| `koreansk` | ≥2: gochujang,kimchi,gochugaru,ssamjang | - | 2 |
| `vietnamesisk` | ≥3: fisksås,lime,mynta,koriander,risnudlar | - | 2 |
| `grekisk` | ≥3: fetaost,oliver,oregano,citron,olivolja,yoghurt | - | 1 |
| `medelhavsmat` | ≥4: olivolja,citron,vitlök,tomat,fetaost,oliver | - | 2 |
| `mellanöstern` | ≥3: tahini,hummus,kikärtor,sumak,za'atar,pitabröd | - | 2 |
| `fransk` | ≥3: smör,grädde,vin,dijonsenap,timjan,dragon | - | 2 |
| `spansk` | ≥3: chorizo,saffran,rökt paprika,oliver,sherry | - | 2 |
| `amerikansk` | ≥3: cheddar,bacon,bbq-sås ELLER titel:'burger\|bbq' | - | 2 |
| `nordisk` | ≥3: dill,lingon,potatis,rökt fisk,rödbetor,lax | - | 2 |
| `asiatisk` | ≥2: sojasås,sesamolja,ingefära,risnudlar,miso,fisksås | - | 1 |

---

## Fas 2: Enkla Härledda (19 taggar)

Beror på Fas 1 eller enkla kombinationer:

| Tagg | Beroende av | Regel | Tier |
|------|-------------|-------|------|
| `pastarätt` | pastabaserad | pastabaserad=true | 1 |
| `risrätt` | risbaserad | risbaserad=true OCH ris är huvudkomponent | 1 |
| `nudelrätt` | nudelbaserad | nudelbaserad=true OCH asiatisk kontext | 2 |
| `rå` | tillagningsmetod | INGA tillagningsmetod-taggar satta | 2 |
| `en-gryta` | instructions | instructions: 'allt i en\|one pot\|en gryta' | 1 |
| `plåtmat` | ugnsbakad | ugnsbakad + 'plåt' i instructions | 2 |
| `no-bake` | dessert + metod | dessert-kontext OCH INGEN ugn/stek | 2 |
| `långkok` | tid + instructions | totalTime≥120 ELLER slow-cooker keywords | 2 |
| `över-natten` | instructions | 'över natten', 'overnight', 'jäsa [8-24]h' | 2 |
| `lite-jobb` | activeTime | activeTime≤15 ELLER passiv tillagning | 2 |
| `få-ingredienser` | ingredientCount | ingredientCount≤5 (exkl pantry-staple) | 1 |
| `stark` | is-spicy property | ≥1 ingrediens har 'is-spicy' | 2 |
| `mild` | stark | NOT stark (ingen spicy ingrediens) | 2 |
| `dessert` | titel + ingredienser | kaka=true ELLER titel:'dessert\|efterrätt\|glass' | 1 |
| `frukost` | titel + ingredienser | titel:'frukost\|gröt\|overnight' ELLER frukost-kombo | 1 |
| `fika` | titel | titel:'fika\|bulle\|kanelbulle\|scones\|kladdkaka' | 1 |
| `dryck` | titel | titel:'smoothie\|juice\|lemonad\|cocktail\|dryck\|glögg' | 2 |
| `pescetarian` | vegetarisk + fisk | INGEN meat OCH (fish ELLER crustacean ELLER mollusc) | 1 |
| `halalanpassad` | pork + alcohol | INGEN 'pork' OCH INGEN 'alcohol' OCH coverage ≥95% | 2 |

---

## Fas 3: Komplexa Härledda (16 taggar)

Beror på Fas 1 + Fas 2:

| Tagg | Beroende av | Regel | Tier |
|------|-------------|-------|------|
| `enkel` | tid + count + steg | ≤8 ingredienser OCH ≤6 steg OCH ≤45 min OCH INGA avancerade tekniker | 1 |
| `medel` | enkel, avancerad | NOT enkel OCH NOT avancerad | 2 |
| `avancerad` | tid + count + tekniker | ≥15 ingredienser ELLER ≥12 steg ELLER ≥120 min ELLER avancerade tekniker | 2 |
| `krämig` | ingredienser | ≥2 av [grädde,crème fraiche,kokosmjölk,mascarpone] | 2 |
| `krispig` | instructions | 'krispig', 'knaprig', 'frasig', 'panerad' i instructions | 2 |
| `ostig` | ingredienser | ≥2 ost-ingredienser ELLER 'gratinera' i instructions | 2 |
| `kall-rätt` | rå + instructions | rå=true ELLER sallad=true ELLER 'kall\|kyld' i instructions | 2 |
| `varm-rätt` | rå | NOT rå OCH NOT kall-rätt | 2 |
| `grönsaksrik` | ingredienser | ≥4 olika grönsaker bland ingredienserna | 2 |
| `örtig` | ingredienser | ≥3 ingredienser har 'fresh-herb' | 2 |
| `proteinrik` | high-protein | ≥2 ingredienser har 'high-protein' | 2 |
| `fiberrik` | high-fiber | ≥3 ingredienser har 'high-fiber' | 2 |
| `barnvänlig` | mild + rätttyp | mild=true OCH (pastarätt\|köttbullar\|pannkaka\|pizza\|hamburgare\|våffla) | 1 |
| `matlådevänlig` | servings + frys | servings≥4 OCH (gryta\|pastarätt\|risrätt) OCH NOT 'doesnt-freeze-well' | 1 |
| `frysvänlig` | rätttyp + properties | (gryta\|soppa\|pastarätt\|bröd) OCH NOT 'doesnt-freeze-well' | 1 |
| `storkok` | servings | servings ≥ 6 | 2 |

---

## Fas 4: Mood/Occasion (21 taggar)

Beror på många andra taggar. Sist att beräknas:

| Tagg | Beroende av | Regel | Tier |
|------|-------------|-------|------|
| `vardagsmat` | enkel + tid | enkel=true OCH under-45-min=true | 1 |
| `helgmat` | tid + avancerad | totalTime≥60 ELLER avancerad=true | 1 |
| `bjudmat` | servings | servings≥8 ELLER titel:'fest\|buffé\|mingel' | 2 |
| `comfort-food` | krämig + ostig + rätttyp | (krämig ELLER ostig) OCH (pastarätt\|gratäng\|gryta\|köttbullar) | 1 |
| `värmande` | rätttyp + säsong | soppa ELLER gryta ELLER curry | 2 |
| `uppfriskande` | sallad + kall-rätt | sallad ELLER kall-rätt ELLER fräsch=true | 2 |
| `snabbfix` | tid + ingredienser | under-15-min ELLER (under-30-min OCH få-ingredienser) | 1 |
| `lyxig` | premium + avancerad | avancerad=true OCH (lax\|räkor\|lamm\|oxfilé) | 2 |
| `fredagsmys` | cuisine + comfort | taco ELLER mexikansk ELLER pizza ELLER (under-30-min OCH comfort-food) | 1 |
| `jul` | titel + ingredienser | titel:'jul\|christmas\|advent' ELLER ≥3 av [julskinka,sill,köttbullar,grönkål,glögg,pepparkakor,saffran] | 1 |
| `lucia` | titel + ingredienser | titel:'lucia\|lussekatt' ELLER (saffran + bulle/bröd) | 2 |
| `påsk` | titel + ingredienser | titel:'påsk\|easter' ELLER ≥2 av [lamm,ägg (stora mängder),sparris] | 2 |
| `midsommar` | titel + ingredienser | titel:'midsommar' ELLER ≥3 av [sill,färskpotatis,gräddfil,gräslök,jordgubbar] | 1 |
| `kräftskiva` | ingrediens | ingrediens 'kräftor' | 2 |
| `nyår` | titel + ingredienser | titel:'nyår' ELLER (lyxiga ingredienser: oxfilé, hummer) | 2 |
| `söndagsmiddag` | cuisine + tid | svensk=true OCH (gryta ELLER stek) OCH totalTime≥60 | 2 |
| `vår` | season | ≥2 'spring-seasonal' ELLER ≥2 av [sparris,rabarber,ramslök,nässla] | 2 |
| `sommar` | season | ≥2 'summer-seasonal' ELLER ≥2 av [jordgubbar,färskpotatis,hallon,blåbär] | 2 |
| `höst` | season | ≥2 'autumn-seasonal' ELLER ≥2 av [svamp,kantareller,äpple,pumpa,vilt] | 2 |
| `vinter` | season + jul | ≥2 'winter-seasonal' ELLER jul=true ELLER ≥2 av [kål,rotfrukter,citrus] | 2 |
| `året-runt` | season | Ingen säsongsspecifik tagg matchar | 3 |

---

## Övriga Kategorier (kompakt)

### Måltidstyp (11 st)
frukost, brunch (Tier 2), lunch (Tier 2), middag (Tier 2), förrätt (Tier 2), tillbehör (Tier 2), dessert, mellanmål (Tier 2), fika, dryck (Tier 2), huvudrätt

### Textur (7 st)
krämig, krispig, fluffig (Tier 3), ostig, seg (Tier 3), kall-rätt, varm-rätt

### Smakprofil (11 st)
stark, lagom-stark (Tier 3), mild, söt, umami, syrlig, fräsch, rökig, örtig, vitlöksrik (Tier 3), bitter (Tier 3)

### Hälsa/Näring (6 st)
proteinrik, fiberrik, grönsaksrik, lätt, balanserad (Tier 3), energität (Tier 3)

### Praktiskt (12 st)
matlådevänlig, frysvänlig, restvänlig, lunchlåda, förbered-i-förväg, budgetvänlig, barnvänlig, portabel, imponerande (Tier 3), storkok, under-30-min-och-enkel, vegetarisk-protein

### Mood (6 st)
comfort-food, hälsosam-känsla, värmande, uppfriskande, snabbfix, lyxig

### Tillfälle/Högtid (16 st)
vardagsmat, helgmat, bjudmat, jul, lucia, påsk, midsommar, kräftskiva, nyår, fredagsmys, söndagsmiddag, grillfest, romantisk-middag (Tier 3), halloween (Tier 3), picknick (Tier 3), alla-hjärtans-dag (Tier 3)

---

## Test-checklista

Kritiska testfall för att verifiera korrekt taggning:

| # | Testfall | Förväntat resultat | Testar |
|---|----------|-------------------|--------|
| 1 | Pasta + sojasås | INTE både italiensk OCH kinesisk | Negativa triggers |
| 2 | Endast mandel | innehåller-trädnötter=true, innehåller-jordnötter=false | Separerade nöt-taggar |
| 3 | Vegetariskt + lax | pescetarian=true, vegetarisk=false | Pescetarian-logik |
| 4 | Slow-cooker 8h, 10min aktivt | lite-jobb=true, helgprojekt=false | Tid-taggar |
| 5 | Köttbullar + lingon + potatis | svensk=true, italiensk/asiatisk=false | Cuisine-exklusivitet |
| 6 | Lax-recept | lax=true OCH fisk=true | Hierarkiska protein-taggar |
| 7 | Saffransbullar i juni | jul=false (kräver ≥3 jul-ingredienser) | Högtids-trösklar |
| 8 | Pannkakor vs våfflor | Separata taggar, inte samma | Separerade rätttyper |
| 9 | Chokladkaka med ägg | ägg-protein=false (dessert-exkludering) | Ägg-undantag |
| 10 | Musslor | innehåller-blötdjur=true, innehåller-skaldjur=false | Blötdjur vs kräftdjur |
| 11 | 50% okända ingredienser | INGEN fri-tagg (coverage <95%) | Coverage-tröskel |
| 12 | Fas-ordning | pastarätt (Fas 2) efter pastabaserad (Fas 1) | Dependency-ordning |

---

## Implementationsguide

### Steg 1: Properties (1-2 veckor)
- Verifiera att befintliga 20 properties finns och fungerar
- Lägg till Tier 1 nya properties: crustacean, mollusc, fish, soy, sesame, celery, mustard, lupin, alcohol
- Lägg till Tier 2: is-spicy, added-sugar, legume, grain, game, high-fodmap, spring-seasonal, autumn-seasonal, sulfites

### Steg 2: Tier 1 Taggar (1-2 veckor)
- Implementera alla Fas 1 taggar med tier=1
- Kör test-checklistan

### Steg 3: Resterande Tier 1 + Tier 2 (2 veckor)
- Implementera Fas 2, 3, 4 med tier=1
- Implementera tier=2 taggar

### Steg 4: Tier 3 + Polish (ongoing)
- Implementera tier=3 baserat på användarbehov
- Finjustera triggers baserat på verkliga recept

---

## Slutlig Sammanfattning

| Kategori | Antal | Tier 1 | Tier 2 | Tier 3 |
|----------|-------|--------|--------|--------|
| Innehåller/Allergener | 18 | 14 | 4 | 0 |
| Kost/Free-from | 16 | 14 | 1 | 1 |
| Tid | 5 | 4 | 1 | 0 |
| Svårighetsgrad | 5 | 2 | 2 | 1 |
| Cuisine | 17 | 8 | 9 | 0 |
| Måltidstyp | 11 | 4 | 7 | 0 |
| Rätttyp | 21 | 13 | 8 | 0 |
| Tillagningsmetod | 14 | 6 | 6 | 2 |
| Protein | 15 | 11 | 4 | 0 |
| Bas/Kolhydrat | 6 | 3 | 3 | 0 |
| Textur | 7 | 0 | 5 | 2 |
| Smakprofil | 11 | 0 | 8 | 3 |
| Hälsa/Näring | 6 | 0 | 4 | 2 |
| Praktiskt | 12 | 4 | 7 | 1 |
| Mood | 6 | 2 | 4 | 0 |
| Tillfälle/Högtid | 16 | 4 | 8 | 4 |
| Säsong | 5 | 0 | 4 | 1 |
| **TOTALT** | **168** | **62** | **74** | **32** |

---

# Butlery Integration

## Systemkontext

```
┌─────────────────────────────────────────────────────────────────┐
│                        BUTLERY APP                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │   MODUL1     │    │   MODUL2     │    │   Recipe     │       │
│  │ Ingredient   │───▶│    Tag       │───▶│   Storage    │       │
│  │ Normalizer   │    │  Generator   │    │  (Firestore) │       │
│  └──────────────┘    └──────────────┘    └──────────────┘       │
│         │                   │                                    │
│         └───────────────────┴──────────────┐                    │
│                                            ▼                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                 IngredientService                        │   │
│  │                 (ersätter KnownIngredients)              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Hive Local Cache                            │   │
│  │              ~1750 ingredienser + alias-index            │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              ▲                                   │
│                              │ Poll vid startup                  │
│                              │                                   │
└──────────────────────────────┼───────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Firebase Firestore                            │
│                    ingredients_db/v1 (~500 KB)                   │
└─────────────────────────────────────────────────────────────────┘
                               ▲
                               │ Export
                               │
┌─────────────────────────────────────────────────────────────────┐
│                    Google Sheets (Excel)                         │
│                    SOURCE OF TRUTH                               │
│                    ~1750 ingredienser med properties             │
└─────────────────────────────────────────────────────────────────┘
```

## IngredientService

```dart
class IngredientService {
  /// Hämta ingrediens med alla properties
  Ingredient? lookup(String normalizedName);

  /// Kontrollera om ingrediens finns i databasen
  bool isKnown(String normalizedName);

  /// Hämta alla properties för en ingrediens
  Set<String> getProperties(String normalizedName);

  /// Kontrollera om ingrediens har en specifik property
  bool hasProperty(String normalizedName, String property);

  /// Synkronisera med Firebase (vid app-startup)
  Future<void> syncFromFirebase();

  /// Nuvarande databasversion
  String get version;
}
```

### Ingredient-modell

```dart
class Ingredient {
  final String id;                    // "chicken"
  final String swedish;               // "kyckling"
  final String english;               // "chicken"
  final String group;                 // "protein/poultry"
  final Set<String> properties;       // {"animal-product", "meat", "poultry"}
  final List<String> aliasesSv;       // ["kycklingfilé", "kycklingbröst"]
  final String? typicalUnit;          // "g"
  final String status;                // "verified"
}
```

## Firebase-struktur

**Path:** `ingredients_db/v1` (ett enda dokument, ~500 KB)

```javascript
{
  // === METADATA ===
  "version": "1.0.0",
  "updatedAt": "2025-01-15T10:00:00Z",
  "ingredientCount": 1752,
  "propertyCount": 41,

  // === INGREDIENSER ===
  "ingredients": {
    "chicken": {
      "swedish": "kyckling",
      "english": "chicken",
      "group": "protein/poultry",
      "properties": ["animal-product", "meat", "poultry"],
      "aliasesSv": ["kycklingfilé", "kycklingbröst"],
      "typicalUnit": "g",
      "status": "verified"
    },
    "shrimp": {
      "swedish": "räkor",
      "english": "shrimp",
      "group": "protein/seafood/crustacean",
      "properties": ["animal-product", "seafood", "crustacean"],
      "aliasesSv": ["räka", "jätteräkor"],
      "typicalUnit": "g",
      "status": "verified"
    }
    // ... ~1750 ingredienser
  },

  // === PROPERTIES ===
  "properties": {
    "animal-product": {
      "nameSv": "Animalisk produkt",
      "category": "diet-base",
      "excludesTags": ["vegansk"]
    },
    "crustacean": {
      "nameSv": "Kräftdjur",
      "category": "allergen",
      "excludesTags": ["skaldjursfri"]
    }
    // ... 41 properties
  }
}
```

## Hive Cache

```dart
@HiveType(typeId: 50)
class IngredientCache {
  @HiveField(0)
  final String version;

  @HiveField(1)
  final DateTime updatedAt;

  @HiveField(2)
  final Map<String, Ingredient> ingredients;

  @HiveField(3)
  final Map<String, Property> properties;

  @HiveField(4)
  final Map<String, String> aliasIndex;  // "kycklingfilé" → "chicken"
}
```

### Uppdateringsstrategi

```
App startar
    │
    ▼
Läs lokal version från Hive-cache
    │
    ▼
Har nätverk?
    │
    ├── Nej → Använd lokal cache, fortsätt
    │
    └── Ja → Hämta version från Firebase
                  │
                  ▼
              Samma version?
                  │
                  ├── Ja → Använd lokal cache
                  │
                  └── Nej → Ladda ner hela dokumentet
                                │
                                ▼
                           Spara i Hive
                                │
                                ▼
                           Bygg alias-index
```

## Integrationspunkter

### UrlImportStrategy

Naturlig plats för taggning: `UrlImportStrategy._convertParsedRecipeToImportResult()`

```dart
// Efter parsing av recept
final tagResult = await tagGenerator.generateTags(
  normalizedIngredients: parsedRecipe.ingredientsNormalized,
  totalTime: parsedRecipe.timeMinutes,
  title: parsedRecipe.title,
  instructions: parsedRecipe.instructions,
);

// Spara på receptet
recipe.tags = tagResult.tags.toList();
recipe.taggingMetadata = tagResult.metadata;
```

### DI Registration

```dart
// lib/core/di/modules/content_module.dart

void registerTaggingServices() {
  // IngredientService (prerequisite)
  ServiceLocator.registerSingletonAsync<IngredientService>(
    () async {
      final service = IngredientService();
      await service.initialize();
      return service;
    },
  );

  // TagGenerator
  ServiceLocator.registerLazySingleton<TagGenerator>(
    () => TagGenerator(
      ingredientService: ServiceLocator.get<IngredientService>(),
    ),
  );
}
```

## Filstruktur

```
lib/
├── models/
│   ├── ingredient/
│   │   ├── ingredient.dart
│   │   └── property.dart
│   └── tagging/
│       ├── tag_result.dart
│       ├── tag_confidence.dart
│       ├── generated_tag.dart
│       └── tag_warning.dart
├── services/
│   ├── ingredient/
│   │   ├── ingredient_service.dart
│   │   ├── ingredient_cache.dart
│   │   └── ingredient_repository.dart
│   └── tagging/
│       ├── tag_generator.dart
│       └── strategies/
│           ├── tag_strategy.dart
│           ├── contains_tag_strategy.dart
│           ├── free_from_tag_strategy.dart
│           ├── dietary_tag_strategy.dart
│           ├── time_tag_strategy.dart
│           ├── cuisine_tag_strategy.dart
│           └── mood_tag_strategy.dart
└── repositories/
    └── ingredient_repository.dart
```

---

## Versionshistorik

| Version | Datum | Ändringar |
|---------|-------|-----------|
| 4.0 | 2024-12 | Master edition: 168 taggar, 41 properties, 4 faser, Butlery-integration |
| 3.0 | 2024-12 | Lagt till spring/autumn-seasonal |
| 2.0 | 2024-12 | Excel-databas med individuella properties |
| 1.0 | 2024-12 | Initial taggningsspec |

---

*Detta är den auktoritativa specifikationen för Butlerys taggningssystem.*
