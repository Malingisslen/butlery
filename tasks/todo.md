# Kärnflöde steg 5D: täckningskrav, osäkra taggar och omtaggning

Del av den godkända steg 5-planen (`/mnt/project-files/steg5/plan.md`, 5D; Malins beslut 5
2026-10-30, "kör" 21:45). Bygger på 5C (#1077). Regeln följer Drive-arket "Butlery TagRules
v1.0", fliken CoverageConfig, kolumnen `vid_osäkerhet`, och testfallen COV-05/COV-06.

- [x] 1. Protein under 80 % täckning: bara proteintaggar som en huvudingrediens ger
      ("sätt ändå om tydlig huvudingrediens"). Över gränsen som i dag.
- [x] 2. Kök under 60 %: ingredienserna ger inga poäng; titel och receptets eget kök
      (schema.org) räcker fortfarande ("italiensk sätts ej" vid pasta + tomat + två okända).
- [x] 3. Stämning/praktiskt under 60 %: taggar som bygger på att något SAKNAS bland
      ingredienserna (frysbar, meal-prep: inget som inte tål frysning) sätts inte. Taggar som
      bygger på något som FINNS sätts på tillgänglig info, som Drive säger.
- [x] 4. Receptdetaljens taggruta visar "Osäkra taggar, X ingredienser okända" när täckningen
      är under 80 % och minst en ingrediens är okänd. Bara i detaljen.
- [x] 5. `kTagGeneratorVersion` 2.3.0 → 2.4.0, en gång, så appen taggar om alla recept med
      steg 5A–5D.
- [x] 6. Tester per punkt, `flutter analyze`, grindarna, PR med auto-merge.

Sammanfattning för Malin: när appen inte känner igen alla ingredienser i ett recept blir den
försiktigare. Under 80 % kända ingredienser sätts bara proteintaggar för det receptet faktiskt
är byggt på, och under 60 % gissar appen inte kök utifrån ingredienserna eller lovar "frysbar".
Receptet visar då "Osäkra taggar, 3 ingredienser okända" vid taggarna. Till sist taggas alla
dina recept om automatiskt med allt nytt från steg 5.

# Kärnflöde steg 3B-2b: receptrader och inköpsrader får ingrediens-id

Del av den godkända steg 3-planen (`/mnt/project-files/steg3/plan.md`, 3B punkt 2–4; Malin "kör"
2026-10-30 21:00). Bygger på #1073. Ingen omskrivning av lagrade recept eller listor.

- [x] 1. `IngredientRepository.idsForKey`: alla ingrediens-id vars namn eller alias har den
      nyckeln. Indexet behåller dagens vinnare (taggningen ändras inte) men minns krockarna.
- [x] 2. `IngredientIdResolver` (ny, `lib/services/ingredients/`): id till en receptrad bara när
      radens namn, eller namnet utan märke, är exakt ett namn eller alias för exakt EN global
      ingrediens. Tvetydigt, okänt, sammansatt ("salt och peppar") eller bara likt → inget id.
      Användarens egna ingredienser används inte: ett recept kan delas, ett privat id ska inte följa med.
      Läser ingrediensernas minnescache, ingen extra Firestore-läsning.
- [x] 3. `RecipeIngredient.ingredientId` (valfritt fält, sparas bara när det finns). Sätts när ett
      personligt recept skapas, redigeras eller kopieras, före taggningen.
- [x] 4. `UnifiedShoppingItem.ingredientId`. Veckolistan bär id:t från receptraderna (raderna som
      slås ihop behåller id:t bara när alla som har ett är överens); receptknappen likaså.
      GDPR-exportens fältlista får fältet.
- [x] 5. Skafferiet räknar en rad som samma vara när id:na är lika ELLER namnen är samma som i dag:
      veckolistans avdrag, receptknappens avdrag och "köpt" till skafferiet.
- [x] 6. Tester per punkt, `flutter analyze`, grindarna, PR med auto-merge.

Sammanfattning för Malin: varje ingrediensrad i ett recept, och varje rad på inköpslistan, kommer
ihåg vilken vara i ingrediensdatabasen den är, när det går att avgöra säkert. Då vet skafferiet att
"gul lök" du har hemma räcker till receptets "lök" även när namnen skiljer sig. När ett namn kan
betyda två saker ("bringa" kan vara nöt eller lamm) gissar appen inte. Befintliga recept får
kopplingen nästa gång de sparas; inget skrivs om i bakgrunden.

# Kodhygien: tre duplicerade kluster i lib/ (Malin 2026-10-29)

Malins uppdrag: en delad hjälpare per kluster som `node tools/code_hygiene.mjs` pekar ut,
inget mer. Fortsättning på c53bc2f13 och 4aae2ac42, samma form: hjälparen tar rena värden
(dialogerna har olika vy-modeller) och parsarhjälparna ligger på `RecipeSiteParser`.
Beteendet ändras inte. Fas 2-planen nedan är en annan sessions och lämnas orörd.

- [x] 1. `RecipeShareDialogFrame` (ny fil i `recipe_selection/`): AlertDialog-ramen med
      titel, innehåll, Avbryt och Dela-knappen. Vän- och gruppdialogen bygger den med
      värden ur sin vy-modell. Widgettest för ramen.
- [x] 2. `RecipeSiteParser.cleanCirkaFormatting`: Köket och Recept har samma
      `_clean…Formatting`; båda anropar basklassens. Enhetstest i basklassens svit.
- [x] 3. `RecipeSiteParser.extractPortions(doc, siteSelector:)`: Arla, ICA, Köket och Recept
      har samma `_extractPortions` utom en egen selektor på andra plats (ICA ingen), som
      `extractImage`. Enhetstest som låser selektorordningen.
- [x] 4. Bevis: `flutter analyze`, parsartesterna + dialogtesterna + nya tester,
      `node tools/code_hygiene.mjs` visar att de tre klustren är borta (och inget nytt
      kluster i filerna), `--update-baseline`, commit genom grindarna, push till main.

Sammanfattning för Malin: ställen där samma kod låg kopierad får en gemensam version var. Appen beter sig likadant; nästa ändring görs på ett ställe.

# Fas 2 (BUT-2430): repot byter till `butlery-prod`

Genomför fas 2 i den godkända planen `tasks/new-prod-project-plan.md` (B, "Fas 2 — Repot";
Malin godkände planen 2026-10-20 och sa "Ja, starta Fas 2" 2026-10-21). Inga nya beslut här;
det här är bara körlistan. Mätta fakta från fas 1: BUT-2429-kommentarerna.

No architecture-changing unknowns — assumptions: the plan's literal list plus a repo-wide grep is
the universe; butlery.app ownership is unverified, so nothing new depends on it and the CORS
lists are left as they are.

## Commits, en per grind-familj
- [x] Arbetsflöden (inga grindar): WIF i alla sju prod-flöden (`measure-production.yml` är
      det sjunde, saknas i planens lista), taggtriggern bort, `_EU`-hemligheten i
      build-validation + emulator-lane, `patch_live_files.py` tar token från gcloud.
- [x] functions (cloud-functions-specialist): `require-project.ts` (+ test),
      `deploy-project-guard.test.ts` (WIF-kontroller), övriga literaler under functions/src.
- [x] Regler (firestore-rules-tester + cloud-functions-specialist): chattbildens
      bucket-regex i `firestore.rules` släpper bara `butlery-app-(1|staging)` — saknas i
      planens lista; utan bytet nekas varje offline-chattbild på butlery-prod.
- [x] Dart (code-reviewer, testing-specialist, integration-reviewer; max 3 filer per runda):
      `firebase_options.dart`, `firebase_env.dart`, `main.dart`, `admin_main.dart`
      (reCAPTCHA Enterprise), tester, `scripts/crf/*.dart`.
- [x] Native + konfig (inga grindar): `.firebaserc`, `firebase.json`, `build.gradle.kts`,
      `Info.plist`, entitlements, `security.txt`, skript, `check_model_versions.py`.
- [x] Docs och runbooks.

## Bevis
- [x] Repo-vid grep på `butlery-app-1` (utom `.dart_tool`, `__pycache__`,
      `functions/fnlist.tmp.json`, `.claude/state`): bara avsiktliga träffar kvar.
- [x] `flutter analyze --fatal-infos`, functions unit-svit, `flutter build apk --flavor prod`
      med oförändrad signatur (F12).
      Lokalt rött i `test:reset-analytics-prune` och `test:erasure-export-coverage`,
      inga fas 2-filer; CI cloud-functions-unit grönt på main.
- [x] F4: `firebase use production` → `butlery-prod`; vakttestet grönt.
- [x] F15a: avkodad `GOOGLE_SERVICES_JSON_BASE64_EU` innehåller `butlery-prod`.
- [ ] Push, sedan Malins byte av miljövariablerna i `production` steg för steg.
- [ ] Bevis på BUT-2430, kort svensk rapport.
