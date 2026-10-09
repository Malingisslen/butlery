# BUT-2338 och BUT-2337: uppföljningar till receptstädningen (2026-10-09)

Godkänd av Malin 2026-10-09 21.29 (beslutskort "Bygg båda"). Ersätter den avslutade BUT-2301/2302-planen (mergad i 727f618).

Det blir två PR:er, en per ärende, i den här ordningen. Routern ger full panel för båda eftersom de rör kontoradering och Cloud Functions. Malin får därför frågan på ett kort innan något mergas.

## BUT-2338: kontoraderingens skrubbar tål att en rad raderas mitt i

**Läget nu.** `scrubCommentField` och `scrubRatingRecipeOwner` i `functions/src/account/account-deletion-cascade.ts` gör strikta `batch.update`. `scrubCommentField` används av `scrubCommentRecipeOwner`, `scrubCommentSharedWith` och `scrubCommentReactions`.

En kommentar eller ett betyg kan raderas mellan frågan och skrivningen, antingen av `onRecipeDeleted` eller av författaren. Då avvisas hela chunken med NOT_FOUND, steget misslyckas och kontoraderingen rapporteras `gdprCompliant: false`.

**Ändring.** En gemensam hjälpare i samma fil:
- Första försöket är strikt, som i dag.
- Vid NOT_FOUND (kod 5) körs frågan en gång till och skrivningen görs om. Den nya frågan saknar de raderade och de redan skrubbade raderna.
- Taket kontrolleras på nytt.
- Ett andra misslyckande, eller en annan felkod, ger `false` som i dag.

Probe-benen påverkas inte.

**Prov** (i `account-deletion-cascade.test.ts`, skrivna och röda där de ska vara röda):
- En rad som raderas under första skrivningen ger `true`, och övriga rader skrubbas efter exakt ett nytt försök. Det gäller delningslistan, reaktionerna och betygets ägarstämpel.
- Kod 13 ger `false` utan en ny läsning.

**Filer:**
- `account-deletion-cascade.ts`, bara `scrubCommentField`, `scrubRatingRecipeOwner` och den nya hjälparen. Menyröstningens tråd har bara `removeVoteEntries` i samma fil.
- Testfilen.

## BUT-2337: bilder raderas med kommentaren eller matbilden

**Läget nu.**
- **Kommentarer:** `imageUrls` (högst 3) ligger under `users/{author}/comment_images/`. Appen raderar bilderna själv när författaren tar bort sin kommentar, men inte när servern gör det (`onRecipeDeleted`).
- **Matbilder (`cook_snaps`):** `photoUrls`, `photoUrl` och `thumbnailUrl` ligger under `users/{uid}/recipes/`. Ingen raderar dem någonsin, inte ens när författaren tar bort sin matbild.

Båda sorterna försvinner först när kontot raderas.

**Ändring.** Två nya triggers i `functions/src/cleanup/`: `onRecipeCommentDeleted` på `recipe_comments/{id}` och `onCookSnapDeleted` på `cook_snaps/{id}`.
- De raderar radens bilder med Admin SDK, och bara under radförfattarens egen sökväg.
- Kommentarer får ett nytt skydd för `users/{authorId}/comment_images/`, byggt som `recipePhotoPath`.
- Matbilder raderas med befintliga `deleteRecipePhotos` och `userId`, miniatyrer inräknade.
- En 404 räknas som klar, och fel loggas utan att kastas.
- Region och maxInstances är standard.
- Den felaktiga kommentaren i `cook_snap_service.dart` stryks.

**Prov** (ny testfil):
- Rätt filer raderas.
- En annan uid, `..` eller en annan mapp vägras.
- En 404 eller ett annat fel stoppar inte de övriga filerna.
- En rad utan bilder gör ingenting.

**Kända gränser:**
- Aktivitetsflödets kopierade URL:er visar en trasig bild. Det gäller redan i dag när ett konto raderas.
- En hemmabyggd klient kan peka en matbild på författarens egen receptbild och radera den, vilket bara skadar författaren själv.
- En anmäld rad som författaren raderar tar sina bilder med sig. Appen gör redan så för kommentarer, och `report_evidence` är text.

**Filer:**
- Nya `cleanup-comment-images.ts` och `cleanup-cook-snap-images.ts` med test.
- `functions/src/index.ts`: två exportrader.
- `functions/package.json`: en testrad.
- `lib/services/cook_snap_service.dart`: bara kommentaren.

**Distribution:** `onRecipeCommentDeleted,onCookSnapDeleted` med functions_only. Kontrollera först att ingen annan deploy körs.

## Sammanfattning för Malin

Det här är två små rättelser i serverns städning:
- En kontoradering ska inte längre felaktigt rapporteras som ofullständig när någon raderar en kommentar samtidigt.
- Bilder i kommentarer och matbilder ska raderas när raden raderas. I dag ligger de kvar tills kontot tas bort.

Inget nytt samlas in och inget ändras i appens utseende.
