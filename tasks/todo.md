# BUT-2046 — `user_moderation` når raderingen, och `reportHistory` slutar vara en array

Status: **BYGGD 2026-09-08.** Uppföljning på BUT-2032. Granskad av reducerad panel (DPO, DBA, arkeologen); ADR-0017 för den enda konflikten. Malins fem beslut inskrivna nedan.

---

## 1. Mätt i koden i dag

`user_moderation/{contentOwnerId}` skrivs av `functions/src/feedback/on-report-created.ts`
i samma transaktion som anmälan hanteras:

- **Dokument-id:t är den anmälda personens uid.**
- `totalReports`, `lastReportedAt` — strike-räknaren som driver femanmälningströskeln.
- `reportHistory` — en **array av maps**, en post per anmälan, var och en med `reporterId`,
  alltså **andra personers uid**.

Tre mätningar som avgör designen:

1. **Ingen läser samlingen.** Enda träffarna i hela repot är skrivaren själv och
   `admin/reset-collection-lists.ts`. Ingen moderatorvy, ingen export.
   (Admin-dashboarden är en separat app som inte går att greppa härifrån.)
2. **Ingen `firestore.rules`-post finns.** Samlingen är oåtkomlig för klienten; varje
   skrivning är Admin SDK.
3. **`reporterId` inuti en array-av-maps går inte att fråga på.** Att svara "anmäler konto
   X samma person upprepat?" kräver en läsning av hela samlingen — och en radering av
   anmälarens uid ur *andra* personers dokument är omöjlig utan samma svep.

Punkt 3 är buggen: **en anmälares uid i någon annans dokument är i dag oåtkomligt för
varje raderingsväg som inte skannar hela samlingen.**

---

## 2. Malins beslut, 2026-09-08

1. **Släpp brigading-ambitionen.** Anmälarens uid raderas när anmälaren raderar sitt
   konto, utan ersättande räknare. Hon fick se alternativet (bygg en frågbar
   anmälar-räknare först, DSA artikel 23) och dess pris: GDPR-luckan står öppen tills
   det är byggt. Vi förlorar ingen förmåga vi faktiskt har — inget läser datan, och
   ingen fråga kan ställas mot den i den form den ligger.
   Detta **omprövar inte** ADR-0015, som avgjorde att frågan skulle ställas separat; det
   är svaret på den frågan.
2. **Flytta `reportHistory` till en subsamling.** Samma grepp som BUT-1832/1835 gjorde med
   `voterIds`: en rad per anmälan i stället för en array. Befintliga rader migreras.
3. **Artikel 15: hela samlingen undantas — på TVÅ skäl, inte ett.** Anmälarnas identiteter
   är tredje parts data och skyddas av artikel 15(4). `totalReports` är personens EGEN
   uppgift om sig själv, och 15(4) når inte dit; det undantas på det svagare skälet att ett
   pågående anmälningsantal röjer att granskning sker. Malin tog den andra halvan separat
   2026-09-08, efter att DPO-sätet visat att det första skälet inte täckte den. ADR-0017.
   De två skälen får inte slås ihop till en mening igen.

---

## 3. Bygget

### 3.1 Ny form

`user_moderation/{contentOwnerId}/report_history/{reportId}` — ett dokument per anmälan:
`reportId`, `reporterId`, `reason`, `contentType`, `contentId`.

Dokument-id:t **är** `reportId`, vilket ersätter det `arrayUnion` gjorde: en omkörd
trigger skriver samma dokument igen i stället för att lägga till en dubblett. Idempotensen
är alltså bevarad genom formen, inte genom en dedupe.

`totalReports` och `lastReportedAt` blir kvar på föräldern — de är räknare, inte
persondata om tredje part.

### 3.2 Skrivaren

`processReport` skriver `tx.set(historyRef, {...})` i **samma transaktion** som strike-
räknaren och markören. Ingen ny transaktion, ingen ny felväg.

### 3.3 Raderingen — tre ben, i kaskaden

Placeringen är avgjord av samma sak som i BUT-2032: sonden körs före `auth.deleteUser`,
triggern efter.

1. **Den erasade är den ANMÄLDA:** radera `user_moderation/{uid}` **och** dess
   `report_history`-subsamling. Firestore kaskadraderar aldrig subsamlingar, så föräldern
   ensam räcker inte.
2. **Den erasade är ANMÄLAREN:** `collectionGroup("report_history").where("reporterId","==",uid)`
   → radera raderna. Tak med avböj som i BUT-2032.
3. **Den gamla formen:** ett dokument som ännu inte migrerats bär arrayen. Benet raderar
   hela dokumentet när den erasade är ÄGAREN (ben 1 täcker det), men en anmälares uid inuti
   *någon annans* array är oåtkomligt utan totalsvep. **Det är migreringen som stänger
   det**, inte raderingen — se 3.5.

### 3.4 Sonden

- `collectionGroup("report_history").where("reporterId","==",uid).count()`
- föräldradokumentets existens plus en `count()` på dess subsamling

Kräver en `fieldOverrides`-post för `report_history.reporterId` med både `COLLECTION` och
`COLLECTION_GROUP`, exakt formen `poll_votes.voterId` redan har i `firestore.indexes.json`.
Utan den fallerar frågan — och den fallerar **stängt** i sondens try/catch, alltså som
falsklarm och aldrig som falsk frisksedel.

### 3.5 Migreringen är bärande, inte kosmetisk

`admin/migrate-report-history.ts`, samma form som `admin/migrate-friend-categories.ts`:
läs varje `user_moderation`-dokument, skriv en `report_history`-rad per arraypost, ta bort
`reportHistory`-fältet från föräldern.

Den är det enda som gör en anmälares uid i någon annans dokument raderbart. **Namngiven
restrisk:** körs den inte, kan ett sådant uid inte nås av någon raderingsväg. Appen är inte
live, och samlingen är liten.

### 3.6 Register och text

- `reset-collection-lists.ts`: `user_moderation` får `subcollections: ["report_history"]`,
  och namnet läggs i `KNOWN_SUBCOLLECTION_NAMES`.
- Artikel 15-undantaget skrivs i `accepted-deviations.md` — **inte** i `EXPORT_EXEMPT`,
  som är scopad till `USER_SUBCOLLECTIONS` och vars `stale`-check reddnar på en
  toppnivåsamling (samma sak som BUT-2032 fick lära sig).
- ADR-0015 superseders inte; den avgjorde att frågan skulle ställas, och det är gjort.

### 3.7 Prov

I kaskadsviten, alla mutationsprovade: ägarfallet (förälder + subsamling), anmälarfallet
över collection-group, sondens rena/smutsiga par, tak-och-avböj, och att en **annan**
persons rader överlever varje ben. Kopplingen läggs i den permanenta
`request-account-deletion.test.ts`-assertionen. Skrivarens nya form provas i
`on-report-created`-sviten, inklusive att en omkörd trigger inte dubblerar raden.

---

## 4. Vad det betyder, i klartext

I dag sparar Butlery, för varje person som blivit anmäld, en lista över vem som anmälde
dem. Den listan städas inte när anmälaren raderar sitt konto — och den ligger i ett format
som gör den omöjlig att städa. Efter det här ligger varje anmälan som en egen rad, som går
att hitta och radera, och den försvinner när anmälaren försvinner.

Vi bygger medvetet ingen funktion för att upptäcka den som anmäler folk i onödan. Den
funktionen finns inte i dag heller — datan går varken att läsa eller söka i. Om vi vill ha
den bygger vi den som en riktig funktion, inte som en biprodukt av data vi råkat spara.


---

## 5. Panelens utfall och vad som ändrades

Tre säten, alla `approve-with-conditions`. Avförda: T&S (dess fråga var den Malin just
besvarat), Security (samlingen har ingen klientyta), och de fem övriga som i BUT-2032.

**Vad panelen ändrade i planen:**

- **Migreringen blev transaktionell per dokument.** Som jag först skrev den — läs arrayen,
  kopiera, nolla fältet — kunde en anmälan som landar mellan läsningen och nollningen
  försvinna tyst. `migrate-friend-categories.ts`, förlagan, har ingen levande skrivare att
  kappas med; den här har det. Skriptet dokumenterar också att det får köras först när den
  nya skrivaren är deployad.
- **Tak-och-avböj lades på ÄGARBENET** också, inte bara anmälarbenet. Radantalet där styrs
  av andra människor, vilket är exakt villkoret som kräver tak i den filen.
- **Anmälarbenet flyttades till EFTER tier 1**, som `deleteBlockMirrors`, för att vinna
  samma kapplöpning mot triggern.
- **Artikel 15-motiveringen delades i två.** Se avsnitt 2, punkt 3 och ADR-0017.
- **Retentionsbeslut** togs (180 dagar) — tystnad var inget beslut.

**Namngivna restrisker, alla i avvikelsefilerna:** en anmäld kan radera sig ur en pågående
granskning och ingen legal hold hindrar det; migreringen är inte klar förrän den KÖRTS
skarpt; och kapplöpningen med triggern stängs av TTL:en, inte av kaskaden.

**Mätt:** tsc rent, kaskadsviten 337/337, orkestreringen 4/4, registreringsvakten 20/20,
workflow-map-lintern OK. Sju mutationssonder röda-sedan-gröna: föräldern raderad före sina
rader, avstängt tak på ägarbenet, sondbenet på fel fält, anmälarsvepet utan filter,
borttagen auditstagning, och båda kopplingarna i orkestreraren.
