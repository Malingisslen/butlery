# Butlery · Produktregler

**Normativ för produktlogik.** Version **1.12** · 2026-07-26.
Den här filen finns för att en utvecklare inte ska behöva fatta produktbeslut. Där skärmar, manual eller flödesdokument säger något annat om reglerna nedan gäller den här filen.

Precedens: se `00-spec-index.md`. Den här filen ligger på nivå 3 (produktlogik) — under tokens och manifest, över skärmarna.

---

## 1. Allergener och kost — tre tillstånd, aldrig två

Ett recept har **aldrig** bara ”säker / osäker”. Varje recept har per allergen och per kostval exakt ett av tre tillstånd:

| Tillstånd | Betydelse | Visning | Får planeras automatiskt? |
|---|---|---|---|
| **säker** | Alla ingredienser har allergendata och ingen matchar hushållets hårda krav | ingen markering | ja |
| **osäker** | Minst en ingrediens matchar ett krav, eller innehåller spår | `triangle-alert` + ord + status-warning | **nej** — blockeras helt när kravet är allergi |
| **okänd** | Ingrediensdata saknas eller är ofullständig för minst en ingrediens | `info` + ord + neutral status | **nej i allergihushåll.** Ja i hushåll utan allergikrav, med kvarstående märkning |

**Frånvaro av data är aldrig ett säkert svar.** Ett recept utan allergendata är *okänt*, inte *säkert*.

**Och okänt är inte heller ett tryggt svar.** För ett hushåll med allergi är saknad data minst lika riskabel som en känd träff — skillnaden är bara att ingen ännu har tittat. Därför:

- **Automatisk planering** (genererad veckomeny, ”överraska mig”, förslag på hemskärmen) tar **endast `säker`** när hushållet har minst ett allergikrav.
- **`okänd` får visas i sökresultat och bibliotek**, alltid med märkning, datakälla och en väg till manuell granskning.
- **`okänd` kan planeras manuellt** efter att användaren granskat den saknade ingrediensen — men bara genom att ingrediensen får data, aldrig genom att varningen tystas.
- Ett recept går alltid att **läsa**. Blockeringen gäller planering för hushållet, inte tillgång till innehållet.

Detta är den enda regeln i hela specen som inte får optimeras bort för att en vy blir renare.

### 1.1 Hårda krav och preferenser

- **Hårt krav** = allergi och medicinsk kost. Blockerar: receptet placeras inte i en genererad meny, kan inte läggas i veckomeny utan undantagsdialog, och märkningen följer med hela vägen till inköpslistan.
- **Preferens** = smak, vana, hushållsönskemål (”mindre kött”). Påverkar rangordning, blockerar aldrig.
- Hushållets hårda krav är **unionen** av alla medlemmars hårda krav. En medlems allergi gäller hela hushållets genererade menyer.

### 1.2 Spår

”Kan innehålla spår av X” behandlas som **osäker**, aldrig som säker och aldrig som samma sak som ”innehåller X”. Texten säger vilket: *innehåller* eller *kan innehålla spår av*.

### 1.3 Ersättningar

En ingrediensersättning ändrar säkerhetsbedömningen bara om ersättningen har egen allergendata.

- Ersättning med känd data → tillståndet räknas om direkt och visas i samma vy.
- Ersättning som användaren skrivit själv (fritext) → receptet blir **okänt**, aldrig säkert. Butlery gissar inte på ingrediensnamn.
- En ersättning kan aldrig ta bort en varning som kommer från en annan ingrediens.

### 1.3b Vad ett `okänd`-tillstånd måste kunna svara på

En märkning som bara säger ”okänd” lämnar användaren utan handlingsalternativ. Varje `okänd` bär därför fem uppgifter, och alla fem visas i granskningsvyn:

| Uppgift | Exempel |
|---|---|
| **Varför** tillståndet är okänt | ”Ingrediensen finns inte i ingrediensdatabasen” · ”Ingrediensen är fritext” · ”Källan saknar allergenuppgift” |
| **Vilken ingrediens** som saknar data | ”misosoja (2 msk)” — raden markeras även i ingredienslistan |
| **Vilken person och vilket krav** det gäller | ”Ida · soja (allergi)” — aldrig bara ”någon i hushållet” |
| **Datakälla och senast uppdaterad** | ”Livsmedelsverket, 2026-03-14” · ”Egen uppgift, 2026-07-02” · ”Ingen källa” |
| **Vad som krävs** för att räkna om | ”Ange om misosoja innehåller soja” + knapp som öppnar ingrediensen |

När uppgiften fylls i räknas tillståndet om direkt, i alla vyer där receptet förekommer, och märkningen försvinner av sig själv. Ingen dialog bekräftar det — det är systemet som fått veta något, inte användaren som lovat något.

### 1.4 När inget säkert resultat finns

Genereringen visar `#veckofel`: orsaken per krav, vilka krav som är **släppbara** (preferenser) och vilka som är **låsta** (allergi). Låsta krav har ingen kryssruta — de kan inte släppas i det här läget. Alternativen är: släpp en preferens · utöka receptkällan · planera färre dagar.

### 1.5 Informerat undantag

Endast för **hårda krav som inte är allergi** (t.ex. ”vegetariskt”) kan användaren välja att ändå planera rätten. Dialogen namnger kravet och vem i hushållet det gäller.

**Allergikrav kan inte kringgås i appen.** Det finns ingen ”jag förstår risken”-knapp, ingen kryssruta och ingen inställning som stänger av allergiblockeringen. Receptet går att läsa och att kopiera; det går inte att planera för hushållet. Skälet är att en sådan knapp alltid trycks av någon annan än den som är allergisk.

### 1.6 Vidareföring

Varningen följer objektet: recept → veckomenyplats → inköpslista → matlagningsvy. Ingen av dessa vyer får visa raden utan sin märkning. I inköpslistan sitter märkningen på varan, inte bara på receptet den kom ifrån.

---

### 1.7 Allergidatas proveniens och godkännande

Varje allergenuppgift bär sin källa. Källan avgör hur den får användas:

| Källa | Får ge `säker`? | Märkning i UI |
|---|---|---|
| **Livsmedelsdatabas** (kurerad, versionerad) | ja | ingen |
| **Producentens egen märkning** (inläst från förpackning) | ja | ”enligt förpackning” |
| **Receptets källa** (webbplats, bok) | **nej** — ger `okänd` | ”uppgift saknas i källan” |
| **Användarens egen uppgift** | ja, för det egna hushållet | ”egen uppgift, *datum*” |
| **Automatisk tolkning** (LLM, namnmatchning) | **nej, aldrig** | ”ej bekräftad” |

**Automatisk tolkning får aldrig ensam ge `säker`.** Den får föreslå, och förslaget måste bekräftas av en människa eller av en kurerad databas innan tillståndet ändras. En modell som gissar rätt nio gånger av tio är oanvändbar när tionde gången är ett sjukhusbesök.

Databasversionen sparas med bedömningen. När databasen uppdateras räknas berörda recept om och användaren får veta att något ändrats — tyst omräkning av en säkerhetsuppgift är inte tillåten.

## 2. Konflikthantering per entitet

Det finns ingen generisk regel. Vid samtidig ändring gäller:

| Entitet | Strategi | Användaren märker | Ångra |
|---|---|---|---|
| **Inköpslista** | Union av **operationer**, inte av rader (se 2.1) | banner ”Listan uppdaterades av *namn*” | **per operationstyp** (se 2.4) |
| **Recept (eget)** | Båda versionerna visas, användaren väljer | konfliktvy med två kolumner | — valet *är* beslutet |
| **Recept (delat, andras)** | Ägarens version vinner, din ändring blir ett förslag | banner + ”Se ditt förslag” | ja, 7 dagar |
| **Veckomeny** | Senaste sparade vinner | snackbar ”*Namn* sparade veckan”, **30 s** | 30 s snackbar · därefter **Återställ** i 30 dagar |
| **Skafferi** | Per fält, senaste ändring vinner (se 2.2) | radens tidsstämpel uppdateras | **per operationstyp** (se 2.4) |
| **Profil / inställningar** | Senaste vinner **per fält** | fältet visar ”ändrat av *namn*, *tid*” | Återställ i 30 dagar |
| **Chatt** | Append-only för meddelanden; redigering och radering är egna operationer (se 2.3) | ”redigerat”-märkning | 7 s för radering |

Gemensam regel: **ingen strategi får tyst kasta data som bara finns lokalt.** Där strategin skriver över sparas den överskrivna versionen i 30 dagar och nås via **Återställ**.

### 2.1 Datamodellen som gör detta möjligt

”Union av rader” räcker inte — den återupplivar rader som någon avsiktligt raderat. Sammanslagning sker därför på **operationer**, inte på tillstånd:

| Begrepp | Regel |
|---|---|
| **Stabilt rad-ID** | Varje rad (inköpsvara, skafferipost, ingrediens, medlem) har ett ID som skapas på enheten (UUID v4) och aldrig återanvänds. Namn är aldrig identitet — ”gul lök” kan finnas två gånger med olika ID. |
| **Radering är en operation, inte en frånvaro** | En raderad rad får en **tombstone**: `{id, deletedAt, deletedBy}`. Tombstonen lever i 30 dagar och vinner alltid över en samtidig ändring av samma rad. En rad som inte finns lokalt men saknar tombstone är *ännu inte synkad*, inte *raderad*. |
| **Operationstyper** | `add` · `update{fält}` · `check{bool}` · `delete` · `restore` · `reorder`. Varje operation bär `{opId, rowId, actor, deviceTime, serverSeq}`. |
| **Versionsnummer** | Varje entitet har en monotont ökande `rev`. En skrivning skickar den `rev` den utgick från; servern avvisar en skrivning som utgår från en äldre `rev` och returnerar den nya, varpå klienten slår samman på operationsnivå. |
| **Sammanslagningsordning** | `serverSeq` avgör. Vid samma `serverSeq` avgör `deviceTime`, och vid lika `deviceTime` avgör lägst `actor`-ID — så att alla enheter kommer till **samma** resultat oberoende av ankomstordning. |
| **Idempotens** | `opId` är nyckeln. Samma operation som anländer två gånger tillämpas en gång. Det är detta som gör omförsök säkra. |
| **Historik** | Varje entitet har 30 dagars operationshistorik. Det är den som Återställ läser, och den enda källan till ”vad hände med min rad”. |

### 2.4 Ångra är inte en egenskap hos entiteten — den hör till operationen

Ett enda Ångra-värde per entitet är fel, för samma lista rymmer både en oåterkallelig radering och en trivial bockning. Appens egen regel (BUT-954) klassar efter **återställbarhet**, och den gäller här:

| Operation | BUT-954-klass | Friktion |
|---|---|---|
| `add` | 1 · reversibelt-destruktiv vid ångra | omedelbar + **7 s Ångra-snackbar** |
| `delete` | 1 | omedelbar + **7 s Ångra-snackbar** (referens `pantry_item_card.dart`) |
| `update{namn, mängd, enhet, kategori}` | 3 · light action | **ingen friktion** — fältet har en uppenbar invers |
| `check` / avbockning | 3 | **ingen friktion.** Ingen dialog, ingen snackbar |
| `assign` / `unassign` (”tar jag”) | 3 | **ingen friktion** |
| `reorder` | 3 | ingen friktion |

Samma indelning gäller skafferiet: **radborttagning** är klass 1 med Ångra, medan **kvantitetsändring** och **”har hemma”-bockning** är klass 3 utan friktion.

Regeln i en rad: **Ångra finns där data försvinner, inte där ett läge vänder.** En snackbar på varje bockning är brus i en affär, och brus lär användaren att ignorera snackbarer — inklusive den som räknades.

### 2.2 Kvantiteter slås aldrig samman med max

”Högsta kvantiteten vinner” bevarar gamla värden och tappar riktiga minskningar. Skafferiets kvantitet är därför ett **fält med senaste-ändring-vinner per fält**, inte ett värde som jämförs:

- `update{quantity}` från två enheter → den med högst `serverSeq` gäller. Den andra hamnar i historiken, inte i tystnad.
- **Relativa ändringar skickas relativt.** ”Bocka av 2 av 6” skickas som `delta: -2`, inte som `quantity: 4`. Två samtidiga avbockningar blir då −4, vilket är vad som faktiskt hände i köket.
- `quantity: null` (”har hemma, vet inte hur mycket”) är ett eget värde och skriver aldrig över en känd mängd.

### 2.3 Chatt är append-only för meddelanden, inte för allt

| Operation | Regel |
|---|---|
| **Skicka** | Append-only. Ordning enligt `serverSeq`; lokalt köade meddelanden visas i sänd-ordning med köikon. |
| **Redigera** | Egen operation med `editedAt`. Meddelandet visas märkt ”redigerat”. Endast avsändaren. Ingen redigeringshistorik visas för andra. |
| **Radera** | Tombstone. Platsen visar ”Meddelandet togs bort” — den försvinner inte, för då förstås inte samtalet. Endast avsändaren, eller admin vid rapport. |
| **Reaktioner** | Egen mängd per meddelande, `{messageId, actor, emoji}`. Union — reaktioner kan inte krocka. |
| **Läskvitton** | Högsta lästa `serverSeq` per person. Monotont; går aldrig bakåt. |

## 3. Offline, kö och lokala utkast

- Offline visas som **banner**, aldrig dialog, aldrig illustration. Statusglyfen är `wifi-off`. **Clochen används aldrig som statusbild** — den är enbart varumärke. Texten beskriver läget, inte varumärket.
- Laddning: **tallrikslinje + text**. Ingen spinner, ingen shimmer, inga cirkulära border-spinners — inte heller i importflödet. Skelett står stilla och visas först efter 300 ms.
- **Lokalt utkast** uppstår i recepteditorn, veckomenygenereringen och chattkomponisten.

| Fråga | Regel |
|---|---|
| När skapas det? | Vid första tecknet eller första placeringen |
| Var ligger det? | Enbart på enheten, aldrig i molnet förrän Spara |
| Livstid | 30 dagar sedan senaste ändring |
| Återupptagning | Vid nästa öppning av samma vy: ”Du har ett påbörjat recept från *i går*” + Fortsätt / Släng |
| Radering | Vid Spara, vid Släng, vid utgången livstid, vid utloggning |
| Avbryt | ”Avbryt” lämnar vyn men behåller utkastet. Endast ”Släng utkastet” raderar. Formuleringen ”Avbryt behåller färdiga dagar” betyder just detta |

---

### 3.1 Offlineköns regler

Kön är en del av produkten, inte en implementationsdetalj — användaren ser den och kan påverka den.

| Fråga | Regel |
|---|---|
| **Vad köas?** | Alla skrivningar. Läsningar besvaras ur cache och köas aldrig. |
| **Idempotens** | Varje köpost bär `opId`. Servern förkastar dubbletter. Omförsök är därför alltid säkra — även efter en krasch mitt i en sändning. |
| **Ordning** | FIFO per entitet, parallellt mellan entiteter. En inköpslista kan alltså synka medan ett recept väntar. |
| **Beroenden** | En post kan deklarera `dependsOn: [opId]`. `add` av en rad går alltid före `check` av samma rad. Om beroendet permanent misslyckas markeras hela kedjan som misslyckad — aldrig halvvägs. |
| **Omförsök** | Exponentiell backoff 2 s → 4 s → 8 s → 30 s → 2 min → 10 min, med jitter. Max 24 h, därefter permanent fel. Ingen omförsöksstorm vid återkommande nät. |
| **Permanent fel** | 4xx utom 408/429 försöks aldrig igen. Posten flyttas till **Väntar på dig** med orsak i ord: ”Receptet finns inte längre” · ”Du har inte längre behörighet” · ”Bilden är för stor”. Varje sådan post har en handling: Försök igen · Spara som kopia · Släng. |
| **Konflikt i kön** | Behandlas som § 2, inte som fel. Konfliktbannern visas när kön töms, inte medan appen är offline. |
| **Användarens kövy** | Mer → **Väntar på synk**: antal poster, vad de rör, ålder, och de permanenta felen först. Nås även från köindikatorn i toppfältet. |
| **Töm-kö-garanti** | Appen får aldrig radera en köpost utan att antingen ha fått serverbekräftelse eller ha visat den för användaren som permanent fel. |
| **Utloggning med kö** | Blockeras med förklaring: ”*N* ändringar har inte sparats.” Alternativ: Vänta på synk · Logga ut och släng. Aldrig tyst kast. |

## 4. Veckomenyns modell

**Avstämd mot `weekly_menu_plan.dart`, `veckomeny_view.dart`, `menu_viewmodel.dart`, `menu_placement_view.dart`, `calendar_cells.dart` och `parsed_menu_request.dart`.** Fem påståenden i den tidigare texten var fel och är strukna.

- **Platserna heter lunch · middag · övrigt** (`MealSlot`). **Frukost finns inte** — den ligger medvetet i övrigt, tillsammans med efterrätt, bak, mellanmål och fika. ”Kväll” har aldrig funnits.
- **Veckan har inte 21 fasta platser.** Lunch och middag tar **ett** recept var (14 enkla platser); **övrigt tar flera** (`isMulti`). Det är därför överskott kan uppstå i lunch/middag men aldrig i övrigt.
- **Det finns ingen månadsvy.** Två vylägen: `lista` (generering) och `kalender` (veckan), och valet sparas per användare. Första gången finns inget sparat val — då öppnas kalendern om veckan redan har poster, annars listan. Den förstagångsgissningen sparas medvetet inte.
- **Placering är ett eget, uttryckligt steg** (BUT-1241). Ett genererat resultat ligger *inte* i veckan. Under resultatet står två vägar: **placera i veckan** (automatiskt, dagsankrat — inga recept på passerade dagar) eller **jag placerar själv** (helskärmsläge, allt i minnet till Klar). Den tidigare tysta ”placera vid växling till kalender” är borttagen ur koden.
- Efter automatisk placering visas ett kvitto i **7 sekunder** med **ÄNDRA**, som öppnar manuell placering med tom arbetsvecka. Det är flödets enda ångraväg, för automatiken skriver direkt i veckan.
- **Närvaro är per måltid, inte per dag** (`presenceBySlot`, BUT-1611): lunch och middag, aldrig övrigt. Tre skilda tillstånd: *inget val* = alla hemma (standard), *uttryckligen tom* = ingen hemma, *lista* = exakt dessa. Både inget val och ingen hemma ger **full mängd** i inköpslistan — hellre för mycket än för lite.
- **Närvaro styr inte genereringen.** Den styr visning, portioner och vem-åt-vad. Skulle den scopa receptpoolen filtrerades allergier mot en mindre grupp än hushållet (BUT-1464); säker närvaromedveten generering är ett eget spår (BUT-1625).
- **Tolkningen redovisar sig** (`ExtractionTrace`): vad som förstods, vad som inte förstods, och en väg tillbaka till fältet. Det som inte förstods påverkade ingenting och står kvar i användarens egna ord.
- **Delresultat mäts i recept, inte i dagar**: ”2 av 5 rätter placerade”. Dagräkningen (1–6 dagar) utgår som definition. Ett delresultat är alltså 1 ≤ n < begärt antal recept.
- **Ordningen är: bekräfta → beräkna** — men frågan ställs bara i **kalenderläget när den synliga veckan har poster** (`_confirmOverwrite`). I listaläget frågar den aldrig, för resultatet rör inte den sparade veckan förrän något placeras. Vem som är hemma står kvar vid överskrivning: närvaro hör till veckan, inte till rätterna.
- **Svarstider:** koden har *en* yta för väntan — en helskärmsöverlagring med rubrik och underrubrik (`PeaLoadingOverlay`) — och ett mätvärde: generering över **10 s** loggas som `logSlowOperation`. Designens regel blir därför: rubriken står still, **underrubriken** bär tiden (”det tar längre tid än vanligt”). Inget nytt läge, ingen ny yta, inget bakgrundsval — det senare fanns bara i specen.

### 4.1 Enhetskonvertering vid sammanslagning

| Fall | Regel |
|---|---|
| Samma enhet | summera |
| Volym ↔ volym (ml/dl/l) | konvertera till största praktiska enhet, avrunda enligt content-guiden |
| Vikt ↔ vikt (g/hg/kg) | som ovan |
| Styck ↔ styck | summera |
| Volym ↔ vikt | **konverteras aldrig** — raderna står kvar som två rader under samma varunamn |
| Styck ↔ volym/vikt (”2 lökar” + ”1 dl hackad lök”) | **konverteras aldrig** — två rader, med hint ”samma vara” |
| Okänd eller fri enhet (”en näve”) | egen rad, ingen summering |

Två rader som inte konverteras visas alltid tillsammans, aldrig på olika ställen i listan.

### 4.2 Skafferiavdrag

| Fall | Regel |
|---|---|
| Känd mängd ≥ behovet | varan hamnar inte på listan; raden visas i ”Har hemma” |
| Känd mängd < behovet | mellanskillnaden hamnar på listan |
| Mängd okänd (”har hemma”, utan siffra) | **inget avdrag** — varan hamnar på listan märkt ”Kanske hemma” |
| Enhet okänd eller ej konverterbar | inget avdrag, samma märkning |
| Färskvara äldre än sin hållbarhetsmarkering | inget avdrag, varan märks ”Kolla datum” |

Skafferiet får aldrig ta bort en vara helt utan att användaren kan se att avdraget skett.

---

## 5. Roller, integritet och livscykel

- **Roll ≠ länkbehörighet.** Rollen styr hushållet; länken styr ett objekt. En delad länk har exakt en av behörigheterna `läsa` eller `läsa + bocka`. `läsa + bocka` ger rätt att bocka varor i just den listan — ingen redigering, inget skapande, ingen åtkomst till andra objekt.
- **Delade recept**: en medlem kan **inte** redigera ett recept som någon annan äger. Ändringar sparas som ett förslag som ägaren accepterar eller avvisar. Medlemmen kan alltid kopiera receptet till sitt eget bibliotek och redigera kopian.
- **Kebabmenyn per behörighet** (receptdetalj):

| Val | Ägare | Medlem (delat) | Gäst / läslänk |
|---|---|---|---|
| Dela | ✔ | ✔ | — |
| Redigera | ✔ | — (visas som ”Föreslå ändring”) | — |
| Kopiera till mitt bibliotek | ✔ | ✔ | ✔ (kräver konto) |
| Exportera | ✔ | ✔ | — |
| Spara offline | ✔ | ✔ | — |
| Rapportera | — | ✔ | ✔ |
| Radera receptet | ✔ | — | — |

- **Admin och rapporterat innehåll:** admin når privat innehåll endast när det är rapporterat, endast under ärendets livstid, och endast efter att ha angett en åtkomstmotivering som sparas i audit-loggen tillsammans med användar-id, tidpunkt och objekt. Audit-loggen har 24 månaders retention och är läsbar för användaren på begäran. Ärendet stängs → åtkomsten upphör automatiskt.
- **Allergidata:** lagras krypterat på enheten och i hushållets synk. Skickas till servern endast för (a) synk mellan hushållets enheter och (b) menygenerering, där den behandlas som transient indata och inte loggas. Den används aldrig för analytics, rekommendationer utanför hushållet, eller tredjepart. Formuleringen ”lämnar inte enheten utom för appens egen funktion” utgår.
- **Kontoborttagning:** konto markeras raderat direkt, innehållet blir otillgängligt för alla. 30 dagars återställningsfönster: inloggning med samma uppgifter visar ”Ditt konto är på väg att raderas — Återställ / Radera nu”. Efter 30 dagar raderas allt utom det juridiskt nödvändiga (fakturaunderlag, 7 år). Delat innehåll som andra kopierat följer kopian och raderas inte.
- **Behörighetsflöden** (kamera, foton, notiser, kontakter) har fyra lägen: **ej frågad** (be i sammanhang, aldrig vid start) · **nekad** (funktionen visar vad den kunde gjort + ”Fråga igen”) · **permanent nekad** (samma, men knappen är ”Öppna inställningar”) · **spärrad av systemet/MDM** (förklara att enheten spärrat, ingen knapp). Ingen funktion får sakna ett vettigt tillstånd utan behörigheten.

---

## 6. Hemskärmens regler

Hem finns inte i appen i dag. Den svarar på **en** fråga — *vad äter vi ikväll* — och allt annat är underordnat den.

### 6.1 Vad hjältekortet visar

Prioritetsordning. Första träffen vinner; ingen fallback hoppas över.

| # | Villkor | Kortet visar |
|---|---|---|
| 1 | Dagens plats i veckomenyn är fylld | den planerade rätten, märkt `IKVÄLL` |
| 2 | Dagens plats är tom men veckan har rätter senare | nästa planerade dag, märkt med veckodagen — aldrig `IKVÄLL` |
| 3 | Veckan är tom, biblioteket har recept | ett förslag ur biblioteket, märkt `FÖRSLAG`, med **Byt förslag** |
| 4 | Biblioteket är tomt | tomläget (§ 6.4) |

**Förslag i steg 3 följer allergireglerna i § 1:** i ett hushåll med allergikrav föreslås endast `säker`. Ett förslag är automatisk planering, inte en sökträff.

### 6.2 Hälsning och datum

- **Hälsningen** byter med klockan: 05–11 ”God morgon”, 11–17 ”Hej”, 17–22 ”God kväll”, 22–05 ”God natt”. Namnet är förnamnet ur profilen; saknas det står bara hälsningen.
- **Datumet** är fristående metadata och sätts därför **proportionellt**, inte tabulärt (§ content-guiden). Formen är ”Torsdag 9 juli” — veckodag utskriven, ingen punkt, inget årtal.
- Ingen av dem är en kontroll. De läses som text, inte som knappar.

### 6.3 Sektionerna under kortet

Hem har högst **tre** sektioner, alltid i denna ordning: **Veckan** (tre rader) · **Inköp** (en rad med läge) · och först därefter eventuella sociala rader. Fler sektioner än tre gör vyn till en meny, och då konkurrerar den med naven.

Inköpsraden visar **kvarvarande** varor, inte totalen: ”6 varor kvar av 18”. Den som står i affären bryr sig om resten, inte om summan.

### 6.4 Tomläget

Beskriver läget, inte problemet, och har **en** hjältehandling: *Lägg till recept*. Under den ligger högst tre genvägar som förklarar sig med en rad var. Allergipåminnelsen ligger sist och är en länk, inte en dialog — den ska inte stå i vägen för det första receptet.

Ingen illustration i tomläget på Hem. Clochen är varumärke och används aldrig som statusbild (beslut B-19).

### 6.5 Fel och offline

- **Fel i en sektion tömmer aldrig hela vyn.** Veckoplanen kan misslyckas medan biblioteket fungerar, och då står biblioteket kvar.
- Felrutan säger tre saker: vad hände, **vad bevarades**, vad du kan göra. ”Din plan är sparad” är inte tröst utan information — det är skillnaden mellan ett hämtningsfel och ett dataförlust.
- **Offline är en banner**, aldrig en dialog, och den är en kontroll: den leder till kövyn. Cachat innehåll märks med tidsstämpel (”hämtades 07:12”), aldrig med grå text.

### 6.6 Laddning

Tallrikslinje med text som säger vad som hämtas. Stillastående skelett endast där formen är känd, och **först efter 300 ms** — en snabb start ska aldrig blinka. Ingen spinner, ingen shimmer (beslut B-18).

---

## 7. Betyg, kommentarer och cook snaps

**Avstämd mot koden 2026-07-26.** Reglerna nedan är läsna ur `lib/models/family_rating.dart`, `diner_profile.dart`, `cook_snap.dart`, `lib/views/recipe_detail/comment_visibility.dart`, `cook_snap_visibility.dart`, `recipe_detail_sharing_status.dart` och `docs/legal/family-rating-dpia.md` — inte författade. Där specen tidigare påstod något annat är den rättad, och de fyra felen står namngivna i § 7.7 så att de inte kryper tillbaka.

### 7.1 Familjebetyg — en per person och recept, senaste vinner

Datamodellen har **exakt en** `FamilyRating` per `(recipeId, memberId)` — dokument-id:t är `recipeId|memberId`. Att betygsätta om **skriver över**.

| Regel | Innebörd |
|---|---|
| **Ett betyg per person och recept** | Inte per tillfälle. Lagar man rätten igen ändras samma betyg; det finns ingen betygshistorik per måltid |
| **Stjärnor är 1–5, som heltal** | \`final int stars\`. Ett enskilt medlemsbetyg kan aldrig vara 4,5 — decimalen finns bara på aggregatet (\`FamilyRatingSummary.displayAverage\`). Noll finns inte; ”inte satt” är **avsaknad av rad** |
| **Snittet är ett enkelt medelvärde** | Varje ätande person väger lika. Ogiltiga betyg (utanför 1–5) räknas inte |
| **`memberType`** | `user` för kontoinnehavare, `profile` för hushållsprofiler utan konto |
| **`enteredByUid`** | Vem som fysiskt matade in stjärnorna. Skiljer sig från `memberId` vid ombudsinmatning |

### 7.2 Ombudsinmatning måste synas

När `enteredByUid ≠ memberId` är betyget inmatat av någon annan — typiskt på en delad telefon vid bordet.

- Vyn visar **”inmatat av {namn}”** på raden. Ett betyg som ser ut att komma från en person men satts av en annan är en tystnad appen inte får ha.
- Ombudsinmatning rör **aldrig** inmatarens eget privata receptbetyg (`RecipeCore.rating`). De är två skilda värden.

### 7.3 Barn har inga konton — de har hushållsprofiler

**Detta är en juridiskt granskad funktion.** `docs/legal/family-rating-dpia.md` är godkänd 2026-06-29 med DPO-signatur, och designen får inte avvika från den.

| Regel | Källa |
|---|---|
| **Under 15 år kan inte ha konto.** Barn finns enbart som vuxenförvaltade *diner profiles* | ADR-0001 |
| **Vårdnadshavaren skapar profilen och matar in betyget** — barnet ”sätter” inte sitt eget betyg i appen | DPIA § 1.1 |
| **Gäster är också profiler.** \`DinerAgeBand.adult\` är en vuxen gäst utan konto: sparad, hushållsdelad, utan samtyckeskrav. Bara de tre minderårigbanden (\`toddler\`, \`child\`, \`teen\`) kräver \`GuardianConsent\` | \`diner_profile.dart\` |
| **Profilen delas i hushållet** så alla medlemmar ser och redigerar samma profil, och betygen slås samman | \`diner_profile.dart\` |
| **Samtycket är versionerat** (\`currentConsentVersion = 'v1'\`) så att en ändrad text kan upptäckas som gammal och begäras om | \`diner_profile.dart\` |
| **Ogillade ingredienser är inte hälsodata** — en mjuk planeringspreferens som rider på basprofilens samtycke, utan Art. 9-krav | \`diner_profile.dart\` |
| Profilen bär **namn, åldersspann, avatarfärg** — aldrig födelsedatum, foto eller kontaktuppgift | DPIA § 2 |
| **Allergener på en barnprofil är hälsodata (Art. 9)** och kräver separat, oförvalt, uttryckligt samtycke — skilt från profilsamtycket | DPIA R1 |
| Samtycket är versionerat, tidsstämplat och återkalleligt med ett tryck; återkallande **raderar** allergendatan | DPIA R1 |
| En profil kan skapas **utan** allergener | DPIA R1 |
| **Retention: 24 månaders vilande hushåll → varning → automatisk gallring** | DPIA § 2, signerad |

### 7.4 Varje betyg går in i ett anonymt publikt snitt

Det här stod inte i specen alls och är den viktigaste saknade uppgiften.

- Varje `FamilyRating` vecklas in i receptets **publika genomsnitt**, beräknat **serversidigt** i `recipe_social_stats` (antal, snitt, fördelning).
- **Ingen enskild rad, ingen identitet och inget barn exponeras publikt** — bara det sammanvägda talet.
- Individuella betyg och hushållsprofiler är **hushållsbundna**: bara medlemmar i samma hushåll kan läsa dem (Firestore-regler + behörighetskontroll i repositoryt).
- Att ett barns betyg bidrar till ett publikt snitt är **DPO-prövat och godkänt** (DPIA R3). Vyn ska säga det: ”räknas in i receptets snitt” måste stå där betyget sätts, inte gömt i en policy.

### 7.5 Kommentarer — publiken är receptets, inte hushållets

Läst ur `comment_visibility.dart`:

| Regel | Innebörd |
|---|---|
| **Publiken är receptets ägare + samarbetsmedlemmar, minus dig själv** | Inte hushållet |
| **Ett personligt recept har ingen publik** | Då **döljs** raden ”vem ser detta” helt — ett fel vore att skriva ut en publik som inte finns |
| **Underdriv aldrig** | Etiketten visar högst tre namn + ”+N”, där N räknas mot den **sanna** publikstorleken. Namn som inte kunde slås upp faller aldrig bort — de blir en siffra |
| **Ingen upplöst namn → siffra** | ”3 personer” är bättre än att gömma en verklig publik |

### 7.6 Cook snaps — ärver receptets publik, kan bara bli mer privat

Läst ur `cook_snap.dart` och `cook_snap_visibility.dart`:

| Regel | Innebörd |
|---|---|
| **Standardvärdet är `sameAsRecipe`** — bilden ärver receptets publik | Inte ”hushållet”. Receptets publik är **taket** |
| **Enda alternativet är `onlyMe`** | En snap kan göras mer privat, **aldrig** mer publik |
| **Publiken klassas i tre lägen** | `public` (publikt recept) · `shared` (ägare + medlemmar) · `private` (personligt recept, eller samarbete där du är enda medlemmen) |
| **Varningen kommer före uppladdningen** | Värsta fallet är att ett publikt recept tyst gör ett kaktusfoto från köket publikt. Därför varnas man **innan**, inte efter |
| **Album: högst 5 bilder**, omslaget först | `maxPhotos = 5` |
| **Bildtext högst 200 tecken** | `maxCaptionLength = 200` |
| Äldre poster utan fältet läses som `sameAsRecipe` | Legacy behåller sitt ärvda beteende |

### 7.7 Fyra fel den här avstämningen rättade

Skrivna ur minnet i första utkastet av § 7, motsagda av koden:

| Påstod | Verkligheten |
|---|---|
| ”Ett betyg per person **och tillfälle**; ny rad i historiken” | Ett betyg per person **och recept**. Senaste vinner, ingen historik per måltid |
| ”**Barn** kan sätta eget betyg via hushållsprofilen. Betyget tillhör personen, inte kontot” | Barn under 15 har inga konton. **Vårdnadshavaren** matar in betyget på en förvaltad profil, under Art. 8-samtycke |
| ”Cook snap: **standard är hushållet**, inte vänner, inte publikt” | Standard är **`sameAsRecipe`** — bilden ärver receptets publik, som kan vara publik |
| ”Kommentarssynlighet visas alltid i vyn” | Publiken finns bara på **samarbetsrecept**. På personliga recept döljs raden |
| ”**Gäster sparas inte** i hushållet — de gäller den här måltiden” | Gäster **är** sparade hushållsprofiler (`DinerAgeBand.adult`). Ett betyg kräver ett stabilt `memberId`, så en osparad gäst kan inte ens bära ett betyg |
| Per-person-betyg visade som **4,5** | `final int stars` — enskilda betyg är heltal. Decimalen finns bara på aggregatet |
| ”Delningsstatus = behörighetstabell för andras recept” | Komponenten är **ägarens** vy: mottagare med återkallande per rad. Behörighetstabellen fanns inte i koden |

Lärdomen är inte kosmetisk: **produktlogik för en funktion som redan finns skrivs inte, den läses.** Sju av sju påståenden om befintliga datamodeller var fel — och ett av dem rörde barns personuppgifter i en DPIA-granskad funktion.

### 7.10 Delningsstatus är ägarens vy

Läst ur `recipe_detail_sharing_status.dart`:

| Regel | Innebörd |
|---|---|
| **Visas bara för ägaren** | `if (recipe.createdBy != currentUserId) return SizedBox.shrink()`. Den som inte äger receptet ser ingenting |
| **Visas bara när receptet faktiskt är delat** | Varken samarbetsrecept eller delat → komponenten kollapsar. Det finns **inget tomt läge** att rita |
| **Listar mottagare, inte behörigheter** | Vänner (ur `memberPermissions`, minus ägaren själv) och grupper (ur `categoryIds`) |
| **Återkallande per rad** | Varje mottagare har ett eget kryss. Bekräftelsen namnger personen |
| **”Sluta dela med alla”** är en egen destruktiv åtgärd | Ligger i huvudet, i `error`-färg |
| Namn som inte kan slås upp faller tillbaka på id | Aldrig en tom rad |

**Det finns ingen behörighetstabell för ett recept man inte äger.** Specen påstod tidigare en sådan vy med fyra rader ja/nej. Den är struken tills något i koden motsvarar den.

### 7.8 Substitutioner i matlagningsläget

- **Byt-kontrollen är synlig på raden.** Långtryck är genvägen, aldrig enda vägen (tillgänglighetshandoffen).
- Ett byte gäller **den här matlagningen**, inte receptet. Att ändra receptet är en annan handling.
- **Ett byte får aldrig tysta en varning.** Förslag som ändrar allergenbilden märks i listan, och ett byte till fritext eller till en ingrediens utan data gör receptet `okänt` (§ 1.3).
- Förslagen anger mängd, inte bara namn — ”25 g + 2 dl vatten” är skillnaden mellan ett förslag och en gissning.

### 7.9 Timers

Flera timers är tillåtna och **namnges efter sitt steg** — ”Timer 2” säger ingenting när potatisen kokar. Tid annonseras vid start, halvtid och slut, aldrig löpande. Saknas notisbehörighet varnas användaren **innan** timern startas, inte efteråt (§ 5).

---

## 8. Delade inköpslistor

**Avstämd mot `lib/models/shared_shopping_list.dart`.** Modellen är **direkt samarbete, inte kopia**: delningen är ett eget objekt som pekar på en lista (`shoppingListId`) och varorna ligger i en subkollektion. Den som får en delning har därför ett tredje läge — hen är **erbjuden**.

### 8.1 Gå med är ett uttryckligt val (beslut B-30)

Delningen landar i **Delat med mig** och gör ingenting förrän mottagaren väljer.

| Läge | Vad som händer | Fält |
|---|---|---|
| **Erbjuden** | Kortet ligger i inkorgen. Listan är inte tillgänglig och räknas inte som din | `viewCount` räknas vid visning |
| **Gått med** | Listan hamnar bland dina listor, du syns för de andra, bockning fungerar | `joinedCount` +1 |
| **Avvisad** | Kortet försvinner ur inkorgen. Avsändaren ser inte vem som avvisat, bara att någon gjort det | `dismissalCount` +1 |

- **Ingen hamnar oombedd i en lista.** Det är hela skälet till det extra steget: en inköpslista är en förpliktelse, inte information.
- **Avvisning är tyst mot gruppen.** Avsändaren ser ett antal, aldrig ett namn — annars blir ett nej en social händelse.
- **Ett avvisat erbjudande kan delas igen.** Avvisningen gäller erbjudandet, inte personen.
- **Delningsmeddelandet visas i kortet** (`shareMessage`). Det är oftast det som avgör svaret — ”tar du grönsakerna?” säger mer än listans namn.

### 8.2 Vidaredelning visar ursprunget — men bara när det skiljer sig (beslut B-31)

Modellen håller två personer: `sharedByUserId` (delade med dig) och `originalOwnerId` (skapade listan), med en färdig sträng `attributionText`.

- **När de är samma person** — det vanliga fallet — visas bara avsändaren. En rad som säger ”ursprungligen Annas lista” när Anna just delade den är buller.
- **När de skiljer sig** visas båda, med tydlig hierarki: avsändaren i fetstil som huvudrad, ursprunget under i sekundär ton med liten avatar.
- Skälet är att `originalOwnerId` finns för att en lista **kan vandra**, och då ska det synas att den gjort det. Annars kan någons arbete spridas utan att hen finns i bilden.

### 8.3 Tre saker som lätt blandas: la in, tar, bockade

Avstämt mot `unified_shopping_item.dart`. Modellen håller **tre** skilda attributioner per vara, och UI:t får aldrig visa dem som samma sak:

| Fält | Betyder | Visas som |
|---|---|---|
| `addedBy*` | vem som la in varan | i varans detalj, inte i listraden |
| `assignedTo*` | **”tar jag”** — vem som tagit ansvar för att handla den (BUT-238) | chip på raden med initial + ”tar” |
| `purchasedBy*` | vem som faktiskt bockade av | namn efter den genomstrukna raden |

- **Att ta en vara är inte att köpa den.** En tagen vara är fortfarande köpbar av vem som helst med redigeringsrätt — claimet säger ”jag är på det”, inte ”det är gjort”.
- **Att ta och lämna tillbaka har ingen friktion.** Appens egen regel (BUT-954, klass 3) placerar claim/release och bockning bland *light actions*: ingen dialog, **ingen Ångra-snackbar**. En reversibel flip med uppenbar invers ska inte kosta något.
- **Bockning är sist-vinner per rad**, en `check`-operation enligt § 2.1. Två som bockar samma vara samtidigt är inte en konflikt — resultatet är detsamma.
- Listan visar **vilka som gått med**, inte vilka som blivit erbjudna. Ett erbjudande är inte ett deltagande.
- **Att lägga till och ta bort rader är union av operationer** med tombstones (§ 2.1). En rad som någon avsiktligt raderat återupplivas aldrig av en annan enhets synk.

### 8.3c En rad får inte vara hitbox när den innehåller en annan kontroll

Radhitbox är rätt mönster för en enkel listrad — men **bara** när raden är den enda kontrollen. En inköpsrad har två skilda light actions (bocka av, ta ansvar), och då gäller:

| Regel | Skäl |
|---|---|
| **Kryssrutan har en egen 48 dp-wrapper**, raden är en vanlig container | En `checkbox` vars subträd innehåller en `button` kan inte exponeras som två kontroller — förälderns namn blockerar barnets i uppläsningen |
| **Claim-chipet är ett syskon**, aldrig ett barn till kryssrutan | Ett tryck får inte kunna landa i båda |
| **Grannavstånd ≥ 8 dp** mellan de två hitboxarna | `tokens.json → touchTarget.minGap` |
| Aldrig nästlade `data-a11y-role` | Fångas av lintet: en märkt kontroll inuti en annan märkt kontroll är ett fel |

Ett tryck på ”tar jag” får aldrig kunna växla `bought` — det är två fält, två operationer och två hitboxar.

### 8.3b Kategoriordningen är en butiksvandring — och personlig

`ShoppingCategory.defaultStoreOrder` är ordnad efter hur en svensk butik går: frukt → grönt → mejeri → kött → fisk → bröd → torrvaror → konserv → skafferi → kryddor → fryst → dryck → snacks → hygien → övrigt.

- Ordningen är **inte** alfabetisk och ska inte göras alfabetisk. Den är en väg genom en affär.
- Den kan skrivas över **per lista och per användare** (`ListCategoryOrder`) — två personer i samma delade lista kan alltså ha olika ordning, för de handlar i olika butiker. Ordningen synkas därför aldrig som listdata.
- Nya finkorniga kategorier (`fruit`, `veg`, `meat`, `fish`) ligger före sina äldre samlingsnycklar (`fruitVeg`, `meatFish`), som finns kvar för gamla poster.

### 8.6 Tre vylägen, närvaro och claim-kapplöpning

Läst ur `collaborative_shopping_viewmodel.dart`. Tre saker specen inte kände till alls:

**1 · Listan har tre vylägen** (`ShoppingViewMode`), inte ett:

| Läge | Innehåll |
|---|---|
| `all` | Platt lista — aktiva först, avbockade sist. Standard |
| `myPart` | Tre sektioner: **Min del** · **{namn}s del** · **Otilldelat** |
| `byZone` | Grupperad efter butiksavdelning (`defaultStoreOrder`) med de som tagit varorna synliga i varje avdelning |

`myPart` är hela poängen med att dela en lista i en affär: två personer går skilda vägar och vill se *sin* del. Specen ritar i dag bara `all`.

**2 · Att ta en vara kan förloras.** `claimItem` returnerar `claimed` · `conflict` · `denied` · `error`, och `conflict` betyder att någon annan hann först. Då visas ”**{namn} tog den**” — en snackbar som *informerar*, inte en Ångra. Det motsäger inte att claim är en light action: friktionen ligger inte i handlingen utan i utfallet, och utfallet måste sägas.

**3 · Endast den som tagit varan får lämna tillbaka.** För alla andra är ett tryck på chipet ett **övertagande** (`claimItem` igen), inte ett släpp. Etiketten måste därför skilja på ”lämna tillbaka” och ”ta över” beroende på vem som läser.

**5 · Att lämna en delad lista är i dag omöjligt — för alla.** Läst ur `base_shared_content_repository.dart` och `shopping_repository_routing_module.dart`. `removeMember` tillåter självborttagning ur `members`, men för en delad inköpslista krymper samma flöde `memberPermissions`, och `_requireNoPrivilegeEscalation` avvisar varje icke-ägare som ändrar medlemskartan — `firestore.rules` nekar det redan. Ägaren i sin tur kan inte överlåta listan: inget i koden skriver om `ownerId`, så `deleteSharedContent` är enda utgången och den raderar för alla. Designen ritar därför två ramar: deltagarens lämna-dialog som **mål** (kräver ett undantag för självborttagning i backend) och ägarens dialog som **sanning** — behåll eller ta bort, ingen överlåtelse. Bockningarna står kvar i båda fallen: `purchasedBy*` hänger på varan.

**4 · Närvaro visas i huvudet.** Aktiva shoppare hålls färska med heartbeat och TTL, och listan **utesluter dig själv** — huvudet visar de andra. Att någon är inne i listan just nu är den mest användbara upplysningen i en affär, och den saknas i specen.

### 8.5 Medlemskap har tre roller — och standarden är att bara läsa

Avstämt mot `shared_content_member.dart`. Medlemmar ligger i `content/{id}/members` med **avdenormaliserat** namn och avatar från delningstillfället.

| Fält | Innebörd för designen |
|---|---|
| `role` = `viewer` · `editor` · `admin` | **Standardvärdet är `viewer`.** Att ha gått med betyder alltså inte automatiskt att man får bocka av — behörigheten är ett eget fält |
| `hasViewed` | Per medlem. Skiljer ”har öppnat” från ”har gått med” — två olika saker, och inget av dem är samma som att ha handlat |
| `displayName` / `avatarUrl` | Kopierade vid delningstillfället. **De kan vara gamla** — byter någon namn står det gamla kvar tills delningen uppdateras. Vyn får inte påstå att namnet är aktuellt |
| `initials` | Faller tillbaka på `?` när namnet är tomt. Avatarplattan har alltid något att visa |

**Konsekvens för gå-med-flödet (B-30):** knappen ”Gå med” gör dig till medlem, men vad du får göra styrs av `role`. En `viewer` som gått med ser listan och deltagarna men kan inte bocka av — och då måste vyn säga det, inte visa kryssrutor som inte fungerar. Rollen sätts av den som delar.

### 8.4 Att lämna

**Avstämd mot `base_shared_content_repository.dart` och `shopping_repository_routing_module.dart` — se § 8.6 punkt 5 för kodläget.**

Den som lämnar en delad lista tas ur deltagarlistan; hens bockningar står kvar (de är fakta om vad som handlats, och `purchasedBy*` hänger på varan, inte på medlemskapet). Listan finns kvar hos de andra.

Två avvikelser mot § 5 (grupper), som gäller delade inköpslistor:

1. **Deltagarens lämna är i dag blockerat i koden**, inte av designen. Ramen `#delatlamna` är målbilden och kräver ett backend-undantag för självborttagning ur `memberPermissions`.
2. **Ägaren kan inte överlåta listan** — den möjligheten finns inte alls i koden. Ägaren får därför inte erbjudas ”lämna”: dialogen (`#delatlamnaagare`) väljer mellan att behålla och att ta bort för alla. Designen påstår aldrig ett val som appen inte kan utföra.

---

## 9. Import av recept

**Läst ur `import_manager_result.dart`, `import_strategy.dart`, `import_base_viewmodel.dart`, `parse_metadata.dart`, `parse_confidence_review.dart`, `rate_limit_models.dart`, `assisted_import_dialog.dart` och `import_result_handler.dart`.** Appens åtta importvyer blir **ett** mönster; skillnaderna nedan är kodens, inte gränssnittets.

### 9.1 Nio källor, med tre egenskaper var

`ImportSource`: **länk · text · Instagram · TikTok · YouTube · foto · röst · fil · arkiv** (plus `unknown`). Varje källa bär tre fakta som designen ska visa:

| Egenskap | Innebörd för vyn |
|---|---|
| `requiresNetwork` | Länk, Instagram, TikTok, YouTube. Offline gråas de ut **före** valet — koden nekar dem ändå, och ett nej före är bättre än ett nej efter |
| `mayNeedLlm` | Text, socialt, YouTube, foto. Märks som **AI** — en upplysning om att vägen kan kosta av dagskvoten, inte en varning |
| `defaultCacheTtlDays` | YouTube 180 · länk 90 · socialt 60 · text och foto 30. En andra import av samma adress är ett **cacheträff**: noll tolktid, ingen AI-kostnad — och det ska sägas, för färskheten är inte given |

Fyra svenska sidor har **egen tolk** (`site_parser_registry`): ica.se, koket.se, arla.se, recept.se. Känd sida läses strukturerat; okänd faller tillbaka på generell utvinning.

### 9.2 Fyra utfall, inte två

| Utfall | Regel |
|---|---|
| **Lyckad** | Receptet landar i **editorn** (`manualEntry`, `isTemplate: true`) — aldrig tyst i samlingen |
| **Fel** | Bär `availableStrategies`: koden vet vilka andra vägar som kan klara samma innehåll, och listan **ritas**. Betalvägg och privat konto är samma utfall för användaren — *innehållet gick inte att läsa* — och skiljs bara i orsaksraden |
| **Behöver hjälp** (`needsAssistance`) | Inte ett fel. Koden lämnar tillbaka utvunnen text, föreslaget namn, miniatyr och **förhandsgissade ingredientsrader**; användaren pekar ut raderna i tre steg |
| **Kvot slut** | `RateLimitDenied` är **strukturerad**: `retryAfter`, vilken gräns som slog till, och en **föreslagen åtgärd**. Vyn ritar åtgärden, inte ett allmänt ”försök senare” (BUT-1144 finns för att sluta gissa ur felsträngen) |

### 9.3 Tolkningens säkerhet redovisas

`ParseConfidence`: **hög · medel · låg · misslyckad**. Granskningen sorterar de **osäkraste först** och ger varje rad en 4 px färgstapel. Färgen är aldrig enda signalen — skärmläsaren får ordet. Ett tryck visar **originalraden**, men bara när den skiljer sig på annat än blanksteg (”100g smör” mot ”100 g smör” är ingen skillnad värd en expandering).

### 9.4 Gränser och tider

| Gräns | Värde |
|---|---|
| Importer | 10/minut · 30/timme · 100/dygn |
| AI-operationer | 20 förbättringar · 10 fulla utvinningar · 10 bildtolkningar per dygn; burst 3/minut, 10/timme |
| AI-kostnad | 0,50 USD/dygn · 10 USD/månad |
| Tolkningstimeout | **60 s** (klientsidan). OCR: **30 s** |
| Föreslagna åtgärder | `skipLlm` (tolka regelbaserat) · `useUserAssisted` (tolka själv) · `retryLater` · `useCache` |

Offline finns en **förkontroll** (BUT-1360): utan den snurrar en offlineimport hela 60 sekunder innan användaren ser något.

### 9.5 Dubbletter söks i tre steg

Källadress → titel → **innehållslikhet** (Jaccard ≥ **0,6**). Träffar på adress eller titel visas aldrig under **80 %** — de är säkra av definition, och en låg siffra hade sett ut som ett misstag. Fyra val: behåll · ersätt · spara som nytt · **slå ihop fält för fält**. Misslyckas dubblettkollen **släpps importen igenom** — kontrollen får inte bli en vägg.

### 9.6 Sidoregler

- **Allergenupplysning** (BUT-1198): innehåller receptet ett allergen användaren inte ställt in visas en icke-blockerande banner, byggd på taggar importen redan satt. Inget nytt AI-anrop, ingen väntan, ingen gate.
- **Arvegods** (BUT-953): ett foto kan sparas som receptets källa med skrivarens namn, år och notis. Misslyckas uppladdningen **blockeras sparandet** — inget falskt kvitto — och utkastet läggs tillbaka så nästa försök inte kräver att formuläret fylls igen.
- **Delvis lyckad filimport är normalfallet**: `BatchImportResult` räknar lyckade och misslyckade var för sig. ”Sju av nio” får aldrig rapporteras som nio, och en misslyckad rad får aldrig kasta de sju.
- **Måltidstyperna i import är fem** (frukost, lunch, middag, mellanmål, efterrätt) och är **inte** veckomenyns tre platser. Två olika begrepp: receptets typ, och platsen i veckan.

---

## 10. Taggautomatisering

**Läst ur `personal_tag_rule.dart`, `condition_type.dart`, `condition_operator.dart` och `personal_tag_rule_evaluator.dart`.** Modellen fanns i koden men saknades helt i specen.

- **Regler bor i taggen**, inbäddade i dess dokument — inte i en egen samling. Därför byggs de inifrån taggen, aldrig i en fristående regelvy.
- En regel kräver **namn**, **minst ett villkor**, och ett värde i varje villkor. `matchMode` är **ALLA** eller **NÅGON** — ingen tredje logik, inga parenteser, ingen nästling.
- **Tretton villkorstyper:** ingrediens · egenskap · ord · källadress · kök · kost · tid · betyg · ålder · senast lagad · ursprung · har bild · fullständighet.
- **Tolv jämförelser, bundna till typen.** Numeriska typer får bara numeriska jämförelser; `har bild` är **boolesk** och har ingen jämförelse; `egenskap` kräver uppslagning mot ingrediensdatabasen och kan **inte** utvärderas offline.
- **”Senast lagad” räknar aldrig-lagad som maximalt antal dagar.** En regel för ”inte lagat på 60 dagar” fångar alltså även det som aldrig lagats — det är rätt, och det måste sägas i vyn.
- **Ursprung har fyra fasta värden:** min · delad · samarbete · publik.
- **Källspårning:** utvärderingen vet vilken regel som satte varje tagg. Vyn skiljer tre ursprung — regel (med namn), satt av dig, autogenererad. En tagg utan skäl ser ut som ett fel.
- Att ta bort en regelsatt tagg **på receptet** ändrar inte regeln. Två handlingar, två ställen.
- **Exklusiva grupper hoppar tyst.** Matchar flera regler taggar ur samma exklusiva grupp behålls bara den första i sorteringsordning; resten faller bort med en `debug`-logg. **Designen synliggör det** — gruppen sägs, valet sägs, den bortsorterade regeln namnges. En regel som inte gör något ska säga varför.

## 11. Kontoborttagning

**Läst ur `account_deletion_service.dart` (BUT-788). Rättar arbetsplanen:**

- **Det finns inget återkallningsfönster.** Ingen ångerperiod, ingen paus, ingen återställning. Planens ”kontoborttagning + återkallningsfönster” beskriver något koden inte har. Vyn säger det rakt ut *före* handlingen.
- Ordningen är serverns: **sökindex och lokal cache först** (klienten kan inte nå dem efteråt), sedan Firestore och lagring, och **kontot allra sist**.
- **Nio minuters** timeout på kaskaden. Väntan är ett tillstånd, inte en spinner — och den kan inte avbrytas när den startat.
- **Re-autentisering krävs** om inloggningen är äldre än **fem minuter**. Det är ett **steg i flödet**, inte ett fel: logga in igen, begäran görs om. Ritat som fel skulle användaren tro att raderingen misslyckats.
- **Raderingen kan lyckas delvis.** Svaret bär lyckade och misslyckade samlingar var för sig plus ett **revisions-id**. Delvis är ett eget utfall med egna ord: ”klart” vore en lögn, ”misslyckades” vore fel — kontot *är* borta. Vägen vidare är support med id, aldrig ”försök igen”.
- Ett **skäl** skickas med och hamnar i revisionsraden. Det frågas före, för efteråt finns ingen kvar att fråga.

## 12. Moderering

**Läst ur `moderator_review_view.dart`, `moderator_review_viewmodel.dart` och `admin_shell.dart`.**

- **Behörighet är ett svar, inte ett fel.** `admins/{uid}` läses som ström; icke-admin får en låst yta med förklaring och **ingen åtgärd** — behörighet ges inte därifrån. Utan den skärmen faller Firestore-frågan med `permission-denied`, alltså ett tekniskt fel för något som inte är ett fel.
- Listan är filtrerad till **öppna** rapporter. Tomt betyder *allt är hanterat* — inget tomhetsmotiv, ingen uppmaning.
- **Minderårigt konto visas före åtgärd** (BUT-1609). Uppslagningen är fail-closed men **memoiserar aldrig ett misslyckande** — en tillfällig störning får inte gömma en minderårig resten av sessionen. Märket är information, inte ett hinder, och det ritas ovanför knapparna: efter en radering är upplysningen värdelös.
- **Samma knapp, två innebörder:** profil → **dölj** (reversibelt, klass 2), allt annat → **radera** (oåterkalleligt, klass 1). Koden väljer bekräftelsetyp efter det, så **verbet måste följa med**.
- Adminskalet har **sex flikar** (återkoppling, import, engagemang, tolkning, recept, drift), fliken speglas i adressen och klamras till giltigt intervall. Avvikelsebannern ligger **utanför** flikarna — den gäller hela systemet.

---

## 13. Första gången (onboarding)

**Läst ur `onboarding_view.dart`, `onboarding_viewmodel.dart`, `onboarding_age_gate_page.dart`, `onboarding_age_gate_blocked_view.dart`, `onboarding_welcome_page.dart`, `onboarding_allergen_page.dart` och `onboarding_import_page.dart`. Rättar arbetsplanen på en punkt: sidordningen.**

### 13.1 Ordningen

Guiden har fem sidor i koden: **åldersgrind (0) → välkomst (1) → allergener (2) → kost (3) → import (4)**. Arbetsplanen påstod välkomst först. Grinden ligger först därför att den är ett villkor för att kontot får finnas, inte ett steg i ett flöde.

**MINIMAL (beslut B-39)** behåller fyra: åldersgrind, välkomst, allergener, import. Kostsidan flyttas till **efter första menygenereringen**. Hushållets storlek frågas inte alls — portionerna följer närvaron per måltid (BUT-1611, § 4).

### 13.2 Åldersgrinden

- Golvet är **15 år**, ur svensk dataskyddslag 2 kap. 4 § (tjänst med socialt inslag) — **inte** GDPR art. 8, vars svenska golv är 13. Det är appens enda åldersgräns.
- Endast **födelseår** samlas in. Åldern beräknas konservativt mot 1 januari.
- **Inget år är förvalt** och *Nästa* är avstängd till dess användaren väljer. Ett förvalt år vore en grind som går att passera utan att uppge sin ålder.
- Listan erbjuder ned till **13 år** — under golvet, medvetet, så att ett barn kan uppge sin verkliga ålder.
- Kontrollen körs **när grinden passeras**, inte vid slutförandet: guiden kan sträcka sig över sessioner, och ett återupptaget besök kommer in bakom grinden med födelseåret borta ur minnet.
- Tre utfall, tre olika vyer: **godkänd** (anspråket präglat, token uppdaterad), **nekad** (kontot är redan raderat serversidigt — ett besked, inte en fråga) och **infrastrukturfel** (grinden passeras inte, valet står kvar, åtgärden är *Försök igen*). Det tredje får aldrig se ut som det andra.
- Under 15 erbjuds en **föräldraväg** vid sidan av utloggningen: en vuxen skapar kontot och lägger barnet som matgäst i hushållet.

### 13.3 Att hoppa över

*Hoppa över* **slutför** guiden — den skriver `onboardingSkippedAt` och kommer inte tillbaka. Copyn får därför aldrig antyda *senare*. Bekräftelsen finns för att det som hoppas över har en säkerhetskonsekvens: utan allergener planeras veckan utan kännedom. Dialogen säger vad som förloras och var det finns i stället.

### 13.4 Slutförandet är en väntan med innehåll

- Startrecept och en **exempelvecka med inköpslista** såddas som en del av slutförandet, och väntan är inväntad — inte avfyrad och glömd. En ny användare landar aldrig i en tom app.
- Per-recept-fel tolereras tyst och sänker bara antalet. Exempelveckan läggs bara om veckan är tom, så ett återupptaget slutförande aldrig dubblerar.
- Skrivningen har ett **tak på 20 sekunder**. Vid timeout behålls valen i minnet och åtgärden är *Försök igen* — aldrig *Börja om*.

### 13.5 Framsteg och återupptagning

Varje framåtsteg sparas. En avbruten guide öppnas på det sparade steget, och den återupptagna sidan räknas som **anländ**, inte avklarad. Gränssnittet säger var användaren är — det påstår inte att hon avbröt.

### 13.6 Första importen

Fältet fylls i förväg ur **urklipp** om det ligger en länk där. En lyckad import öppnar **granskningen** (§ 9:s mönster) med receptet i, inte en tyst sparning; *Spara* återvänder in i guiden i stället för till receptdetaljen. Att hoppa över importen är ett eget mått, skilt från att hoppa över guiden.

### 13.7 Auth, e-postverifiering och MFA

**Läst ur `auth_view.dart`, `email_verification_view.dart`, `auth_mfa_service.dart` och `mfa_types.dart`.**

- Auth är **ett** formulär i två lägen. Växling mellan dem rensar lösenord och namn. **Inloggning** navigerar direkt till skalet; **registrering navigerar inte** — auth-tillståndet driver kedjan verifiering → åldersgrind → guide, och en manuell navigering där skulle hoppa över alla tre.
- **Åldern frågas en gång.** Självintyget vid registrering utgår: kontrollen i guiden är enda auktoriteten och enda skrivaren av födelseår. Två frågor om samma sak lär användaren att ingen av dem gäller.
- Samtycket till villkoren är ett verkligt samtycke och **blockerar knappen före tryck**. En varning efter tryck är ett fel som kunde ha varit ett krav.
- **Återställning av lösenord** ger identiskt kvitto oavsett om kontot finns — kontouppräkningsskydd. Adressen valideras i dialogen, före sändning.
- **E-postverifieringen är en mjuk spärr.** Den får lämnas. Skärmen frågar av sig själv var femte sekund, pausar i bakgrunden, återupptar i förgrunden, och går vidare i samma ögonblick adressen bekräftas. Omsändning har 60 sekunders karens, och nedräkningen ligger **utanför** knappens namn — en etikett som ändras varje sekund hinner aldrig läsas upp.
- **MFA-utmaningen finns inte i appen.** Tjänstelagret kan lösa en utmaning och inställningarna kan slå på tvåstegsverifiering, men ingen vy eller viewmodel tar emot resolvern. Den som aktiverar MFA kan därför låsa sig ut. Utmaningen ska bära: maskerad nummerledtråd (appen känner inte hela numret), 60 sekunders giltighet, tolerans för **automatisk verifiering** — fältet kan fyllas av telefonen och vyn bytas mitt i inmatning — och en **reservväg** om telefonen är borta. Reservvägen finns inte i dag och är ett backendkrav, inte ett ritningsval.

### 13.8 OS-behörigheter

**Läst ur `os_permission_helper.dart`, `notification_permission_service.dart`, `image_picker_service.dart` och `image_picker_provider.dart`.**

- Kontraktet är **förklaring → OS-fråga → inställningslänk vid permanent nej → aldrig hårt spärrad funktion**. Förklaringen kommer först därför att systemets fråga har en budget: två nej och appen får aldrig fråga igen. Därför anropas OS:et **bara** när användaren tryckt Tillåt i vår dialog.
- **Andra nej ger tyst hopp.** Ingen upprepad förklaring, ingen spärr. Funktionen finns kvar och kan bara inte göra just det steget.
- `granted`, `limited` och `provisional` räknas alla som beviljade. **Begränsad fotoåtkomst (iOS &quot;valda bilder&quot;) är ett eget läge** med en väg att välja fler — aldrig ett fel och aldrig en tom lista utan förklaring.
- **Notisfrågan ställs endast på Android 13 och senare.** iOS och Android 12 eller lägre kortsluts till ja. Vid permanent nej står reglagen **inaktiverade och synliga** med en länk till systeminställningarna: ett reglage som ser påslagbart ut men inte är det bryter sitt löfte vid varje tryck.
- **Två avvikelser mot kontraktet, båda kodens:** kameran och fotobiblioteket går genom en egen naken väg utan förklaring, utan inställningslänk och utan `limited`; och **exakta larm efterfrågas inte alls**, vilket betyder att matlagningslägets timer inte får utlovas på sekunden förrän behörigheten finns.

---

## 8.7 Skafferiet och listans basvaror

**Läst ur `pantry_item.dart`, `pantry_view.dart`, `pantry_item_card.dart`, `add_pantry_item_sheet.dart`, `shopping_checkoff_pantry_service.dart`, `menu_shopping_list_generator.dart`, `category_order_sheet.dart` och `category_picker_sheet.dart`. Rättar arbetsplanen: det finns inga skafferiavdrag.**

- **Mängder skalas efter närvaro, aldrig efter skafferiet.** Varje planerad måltid räknas om med *antal hemma delat med receptets portioner*, per placering; övrigt-platsen och recept utan portionsuppgift skalas inte. Antalet omräknade måltider redovisas **skilt** från uteslutna basvaror — två tal, två orsaker.
- **Skafferiet subtraherar inga mängder.** Generatorn vet inte att du har 200 g av de 400 g som behövs. Det enda den gör är att lyfta bort **hela rader** vars namn matchar en **basvara** i skafferiet. Antalet redovisas och raderna ska gå att öppna — en uteslutning som inte går att granska är en tyst ändring i en säkerhetsnära lista.
- **Uteslutningen är bästa försök.** Går skafferiet inte att läsa genereras listan *utan* uteslutning. Två listor kan alltså se identiska ut och betyda olika saker; det degraderade läget måste därför sägas i vyn, med en väg att försöka igen.
- **Basvaran måste gå att sätta.** Flaggan finns i modellen men i ingen vy: den kan i dag bara bli sann genom en handredigering i databasen. Kravet är tredelat — en plats att sätta den på, en synlig märkning i listan, och följden utskriven där den sätts. Ordet är **basvara**; användaren läser aldrig ett fältnamn.
- **Bockad vara → skafferiet** är opt-in, sker bara vid en verklig obockad→bockad övergång, och slås samman med befintlig vara **endast när både namn och enhet matchar**. Att bocka av igen **tar inte bort** varan ur skafferiet — asymmetrin sägs i samma andetag som tillägget bekräftas, och snackbaren erbjuder därför *Visa*, inte ett Ångra som inte finns.
- **Fyra platser** — kyl, frys, skafferi, kryddhylla — gissade ur ingrediensens typiska förvaring med skafferiet som fallback. Ett eget namn ger **inget taxonomi-id** och kan inte matchas mot recept; det står i vyn, inte i en felrapport.
- **Datummärket har tre lägen** med gränsen vid tre dygn, räknat i hela dygn. Märket bär ord **och** datum — aldrig färg ensam.
- **Kategoriordningen är per lista och per användare**, återställbar till den svenska butiksvandringen. Kategorin bärs av namnet; färgrutan är dekor.
- Skafferiets rader är **reversibelt destruktiva**: svep bort utan bekräftelsedialog, sju sekunders Ångra, **ett** Ångra per sats vid flerval — och **ingen** snackbar om raderingen misslyckades.
- **Den genererade veckolistan ägs av generatorn.** Den identifieras av ISO-veckomarkören, inte av namnet: en omdöpt lista regenereras ändå på plats, och en egen lista med samma namn lämnas orörd. Vid regenerering ersätts innehållet — bockningar överlever på namn **och** enhet, **manuella tillägg gör det inte**. Regeln sägs **före** knapptrycket, med en väg att flytta de egna raderna först.
- **Tre utfall skiljs åt:** inget att generera (tom vecka), misslyckat, och pågår redan. Det sista renderas som **tystnad** — en dubbeltryckning är inte ett haveri. Ett recept som inte kan läsas utesluts och **syns** i vyn.
- **Ångra-fönstret ska vara ett tal.** I dag är det fyra sekunder i inköpslistan och sju i skafferiet för samma operationsklass; det är två löften för samma handling.

---

## 4.8 Menyröstning

**Läst ur `menu_slot_vote.dart`, `menu_voting_service.dart` och `menu_voting_viewmodel.dart`.**

- Rösten hör till **platsen** (kategori + index), inte till receptet. Fönstret är **24 timmar från skapandet**, inte från senaste alternativet.
- **En röst per person, och den går inte att ändra.** Det ska stå före valet. En oåterkallelig handling får aldrig se ut som en preferens.
- **Alternativ kan läggas till hela den aktiva tiden**, också efter att andra röstat — vilket gör tidigare röster inaktuella utan att de kan flyttas. Tills detta är avgjort märks sent tillagda alternativ med hur många som redan röstat. Beslutet är antingen ändringsbar röst eller låsta alternativ efter första rösten.
- **Ett lika resultat avgörs inte automatiskt.** Oavgjort ritas som oavgjort och kräver ett mänskligt beslut; bara den som startade rösten fattar det.
- **En utgången oavgjord röst är ett eget tillstånd.** Ingenting avgör vid deadline: rösten blir varken aktiv eller avgjord. Tillståndet har tre vägar: avgör efter rösterna som finns, öppna igen, eller släpp platsen.
- **Utgången med röster skiljs från utgången utan röster.** Det senare är inget oavgjort resultat utan ett förslag ingen tog i — och ger ingen rätt på platsen.
- **Historiken visar antal, aldrig vem som röstade på vad.** Modellen vet det; vyn väljer att inte visa det. En omröstning i ett hushåll ska kunna glömmas — det är skillnaden mellan ett beslut och ett protokoll.

---

## 14. Samtycke, export och kontosäkerhet

**Läst ur `user_consent.dart`, `consent_viewmodel.dart`, `data_export_viewmodel.dart` och `account_security_view.dart`.**

- **Sju ändamål, två av dem villkor.** Nödvändig drift och databehandling är låsta till ja i koden. De ritas som **villkor med skäl**, aldrig som avstängda reglage — ett reglage som inte går att röra är ett brutet löfte vid varje tryck. Vägen bort är att radera kontot.
- **`aiProcessing` tappas vid varje sparning.** Viewmodellen bygger sitt objekt ur fem av sju ändamål, och fältets standardvärde är nej — alltså återkallas AI-samtycket när användaren sparar något annat. Samma klass som hushållsstorleken (BUT-1322): en degraderad delmängd skriver över ett värde ingen rört. Sparningen ska utgå från det **lästa** samtycket och bara ändra det användaren rört.
- **Posten är ett revisionsspår** — version, tidpunkt, enhet — och tidsstämpeln visas. *När* någon sa ja är hela poängen med att ha sagt det.
- **Godkänn alla och Återkalla allt ska bete sig lika.** I dag är den första lokal (kräver Spara) och den andra skriver direkt.
- **Förnyelse visar vad som ändrats.** `needsRenewal` är enbart en versionsjämförelse, så gränssnittet får inte påstå att något viktigt hänt utan att säga vad. Befintliga val är förval, och att avstå stänger aldrig av något.
- **Exportfilen lever bara i minnet** och nollas när vyn lämnas. Det sägs i vyn. Innehållet räknas upp — och andras uppgifter i delade listor följer inte med, för de är inte användarens att ta med.
- **Ingen delvis exportfil.** Halva uppgifter är sämre än inga: mottagaren kan inte se vad som fattas.
- **Tre felorsaker, tre besked:** utgången inloggning leder till inloggningen, nekad behörighet är vårt fel och ber inte om ett nytt försök, nätavbrott får försök igen.
- **Kontosäkerhet: eget laddtillstånd per avsnitt.** Lösenord och e-post kräver båda nuvarande lösenord; e-postbytet gäller först när länken till den nya adressen öppnats. Juridik, riktlinjer, anmälningar och öppen källkod hör **inte** i det här rummet — de flyttas till *Om Butlery*.

### 14.1 Notiser

- **Systemets tillåtelse först.** Är notiser avstängda i telefonen betyder inget val i appen något; raden ligger överst och leder till systeminställningarna.
- **Standarderna behålls och sägs högt:** inköpslistan och aktivitet är av från början eftersom de är de brusiga, och **tysta timmar 22–08 är förvalda**. Ett förvalt skydd som ingen vet om är ett skydd användaren inte kan lita på.
- **Typmatrisen är ingen inställning.** Leveransen kräver i dag tre ja — huvudström, kategori och **typ** — där typen varken syns eller går att ändra, och två av fem typer är av från början. En kategori som står på och ändå är tyst är ett brutet löfte. Frågan till användaren är **takten**: direkt · samlat · en sammanfattning · inget, per kategori.
- **Lokal lagring är en stubbe** (`toJson` ger `{}`). Offline kan valen se ut som nollställda; det ska inte kunna se ut som att användarens val försvunnit.

### 14.2 Tvåstegsverifiering

- **Landskoden är ett eget val.** Ett nummer utan landskod är inte automatiskt svenskt; att klistra på `+46` skickar koden till någon annan utan att något ser fel ut.
- **Ominloggning krävs** före på- och avslagning. Vyn ska tåla **automatisk verifiering**: telefonen kan fylla i koden och skärmen byta sig mitt i inmatningen.
- **Reservkoder hör i påslagningen** — tio engångskoder innan skyddet gäller. Utan reservväg och utan en utmaning i inloggningen (AU-10) får skyddet **inte** gå att slå på: en säkerhetsfunktion utan nödutgång låser användaren ute från hushållets recept.

### 14.3 Notiscentral, anmälningar och juridik

- **Inkorgen** sidindelas 20 i taget med tidsstämpel som markör. Oläst bärs av **vikt** och färg — vikten gör jobbet. *Markera alla lästa* hör inte i en kebabmeny; den visas som en rad när något är oläst och försvinner annars.
- **En post utan giltig rutt märks.** Routern faller i dag tillbaka till Hem, alltså lovar raden en resa den inte kan göra.
- **Borttagning ur inkorgen har sju sekunders Ångra** (§ 2.4 klass 1) och säger att bara raden försvinner — inte det den handlade om. I dag sker den optimistiskt och avfyras utan att invänta svar, så en misslyckad skrivning lämnar posten borta lokalt och kvar på servern.
- **Anmälningar visar utfallet i klartext**, inte bara en status: *åtgärdad* täcker annars både borttaget innehåll och en varning. Avslutade anmälningar har en **överklagandeväg** — UGC-policyn kräver den, och att se att något är avslutat är inte att kunna överklaga det. Status bärs av ord och form, aldrig färg ensam.
- **De juridiska dokumenten renderas som text.** I dag läggs markdown-filen i en `SelectableText`, så användaren läser `##` och hakparenteser i det dokument som ska vara begripligt; projektets egen markdown-komponent används inte. Dokumentet visar **version, datum och vilken version användaren godkänt**, och säger när språket fallit tillbaka till svenska.

### 14.4 Samlingsstatistik

- **Siffrorna är en projektion i telefonen**, räknade ur den receptlista som är laddad — inte en serverberäkning. Vyn säger vad den räknat på och när.
- **Fördelningens förklaring bär andelen i klartext.** Färgen är stöd, aldrig enda kopplingen mellan etikett och fält, och **nolldelar syns inte** i vare sig stapel eller förklaring — fyra etiketter får inte förklara tre fält.
- **Ofullständiga recept presenteras som uppgifter, inte som skam.** Tre rader med tal, störst först, var och en med en väg in. En vågrät rad av samtliga i felröd färg är en vägg, och den är dessutom lägre än en träffyta.

### 7.11 Familjemedlemmens tre slags uppgifter

**Läst ur `family_member_form_view.dart`.**

- **Tre uppgiftsslag, tre friktionsnivåer.** Vårdnadshavarens samtycke (art. 6) är **obligatoriskt** för en minderårig och spärrar sparning. Allergener är **hälsouppgifter** (art. 9) och kräver ett **eget** uttryckligt samtycke — vårdnadshavarens räcker inte. Ogillade ingredienser har **ingen** friktion: att inte tycka om svamp är en planeringspreferens, inte hälsodata.
- **Sparning spärras** både utan vårdnadshavarens samtycke och när allergener valts utan eget samtycke. Rutorna är aldrig förkryssade.
- **Avbockat allergensamtycke raderar valen på plats**, och återkallandet ligger *inne i* allergenkortet där uppgifterna syns — inte i en inställning längre bort.
- **Samtyckesposten visar datum och version** på medlemmen.
- Chipsen bär **bock och 48 dp**, aldrig färg som enda skillnad.

### 7.10 Vem åt — arket

**Läst ur `who_is_eating_sheet.dart`.**

- **Ett ark, två flöden.** Betygsflödet har *Hoppa över* och kräver minst en person; veckomenyns närvaro har *Denna måltid* och *Hela dagen* och tillåter **uttryckligen tomt**. Samma komponent, olika copy — det ska ritas som en.
- **Arket visas inte för ett solohushåll**, och inte heller när rosterladdningen misslyckas. Båda loggar maten utan närvaro. **Ett tekniskt fel får inte se ut som &quot;du bor ensam&quot;:** vid misslyckad laddning säger raden att hushållet inte kunde läsas, med ett försök igen.
- **Ovalt bärs av ram och tom ruta**, aldrig av opacitet. Ett namn på 50 % går inte att läsa och tillstånd bärs inte av genomskinlighet. Kryssrutan är 24 px; alla tre knapparna 48 dp.

---

## 15. Recepteditorn och felmodellen

**Läst ur `recipe_auto_save_manager.dart` och `contextual_error_handler.dart`.**

- **Utkast sparas efter 3 sekunder**, 1 sekund för titel och beskrivning, och först när minst **två fält** är ifyllda. Mallbaserade formulär sparas inte förrän användaren gjort **väsentliga** ändringar.
- **Utkastet är lokalt, fem platser, 24 timmars livslängd.** Alla tre står i vyn. Ett utkast som tyst försvinner i morgon är dataförlust med ett vänligt namn, och listan säger **hur länge** varje utkast finns kvar samt märker när nästa trycker ut det äldsta.
- **Misslyckad utkastsparning är tyst** i koden — därför bär vyn en **tidsstämpel**, inte en bock: den uppdateras vid varje lyckad sparning och står still när något gått fel.
- **Fel formuleras ur handling, anslutning och allvarlighet.** Samma misslyckade sparning har olika lydelse och olika åtgärd i *inget nät*, *begränsat*, *fullt nät* och *behörighet*. Går anslutningen inte att mäta antas **begränsad** — och texten får då inte påstå att nätet ligger nere.
- **Behörighetsfel är aldrig ett &quot;försök igen&quot;.** Det bär resurs, handling, skäl och föreslagen åtgärd, för det går inte att lyckas med genom att trycka igen.

### 7.8 Cook snaps — publik och galleri

**Läst ur `cook_snap_visibility_dialog.dart` och `cook_snap_gallery.dart`.**

- **Publiken sägs med namn före uppladdning.** Upplysningen byggs av anroparen (BUT-901) och för ett delat recept är det de uppslagna namnen, inte ordet &quot;hushållet&quot;. Skillnaden är mellan att veta och att tro.
- **En bild kan bara bli mer privat än receptet**, aldrig mer offentlig. *Avbryt* laddar inte upp något — inte &quot;ladda upp med standardvalet&quot;.
- **Varje bild har en synlig meny.** I dag ligger både *Ta bort* (egen) och *Anmäl* (andras) bakom långtryck: en gest som inte syns, inte annonseras och för skärmläsaren inte finns. En destruktiv åtgärd får aldrig bara ligga bakom en gest.
- **Borttagning av en bild har sju sekunders Ångra.** Den raderas i dag direkt, utan bekräftelse. En bild är inte en rad i en lista — den går inte att skriva igen.

### 7.9 Vänprofilens delningslager

**Läst ur `friend_profile_view.dart`.**

- **Delning har två riktningar och vyn ska visa båda.** Koden visar vad vännen delat *med mig* och hennes *publika* recept, men aldrig vad **jag** delat med henne — den uppgiften ligger utspridd per recept. Frågan *vad vet Anna om mig?* ställs på profilen, inte recept för recept, och återkallandet ligger där siffran står.
- **Tre publiker, tre rader:** till dig · från dig · till alla. I koden ser de två första ut som samma sorts knapp fast de betyder helt olika saker.
- **Profillänken säger vad mottagaren ser.** Djuplänken hamnar i systemets delningsark utan förklaring; den visar den publika sidan, inget ni delat.
- **Att ta bort en vän återkallar ingenting** av det som redan delats. Det står i bekräftelsen, inte i en supportartikel.

---

## 16 · Globala tillstånd

Tillstånd som kan läggas över **vilken vy som helst**. Läst ur `maintenance_mode_gate.dart`, `maintenance_mode_blocker.dart`, `session_timeout_service.dart`, `session_timeout_warning_dialog.dart`, `butlery_app.dart`, `pwa_install_banner.dart`, `first_recipe_celebration_overlay.dart` och `swipe_hint_banner.dart`. Ramar: `#globunderhall` `#globsession` `#globsessiontyst` `#globinstallera` `#globceremoni` `#globsvep`.

### 16.1 Underhållsläge

- Underhållsläget är **en helskärm utan navigation**, inte en banner: flaggan `app_maintenance_mode` byter ut hela appen inifrån `MaterialApp.builder`, och en flagga som slås på mitt i sessionen landar utan omstart.
- Rubrik och åtgärdsknapp är **hårdkodad svenska**. De får inte flyttas till lokaliseringen — de ska fungera när lokaliseringen inte gör det.
- Fjärrtexten (`app_maintenance_message_sv`) är **det enda som får variera**. Är den tom visas den generiska meningen. Ingen kontaktväg får bo i fjärrtexten; kontakt- och statuslänkar ligger fast i foten.
- Skärmen **skiljs från offline i ord, inte i färg eller glyf**: offline betyder att användaren är borta, underhåll att tjänsten är borta.
- Textskalning **kläms inte** till 1,5×. Innehållet är rullbart och möter 2,0× enligt `testmatris.md` § 4.

### 16.2 Sessionstimeout

- Sessionen löper **45 minuter** från senaste beröring; varningen visas **5 minuter** före. Aktivitet är vilken beröring som helst i appen.
- Varningsdialogen kan **inte** avvisas vid sidan om, och nedräkningen skrivs `m:ss` i tabulära siffror med `aria-live="polite"`. **Endast siffran uppdateras** — aldrig en knapps namn.
- Nedräkningen bär **ingen accentfärg**. Saffran betyder handling; en siffra är ingen handling.
- **Dialogen har två lägen.** Tom kö: vanlig fråga, *Logga ut nu* går direkt. Kö med innehåll: *Fortsätt* är primär, de väntande ändringarna räknas upp med namn, och *Logga ut nu* leder till samma bekräftelse som den manuella utloggningen (§ 2.4, `#utloggningko`).
- **En utloggning på grund av timeout får aldrig rensa kön.** Kravet gäller alla tre skäl: `timeout`, `background_timeout`, `user_requested`.
- **Timeout i bakgrunden varnar inte** — och kan inte varna. Beskedet ges i stället vid återkomsten, på inloggningsskärmen, som en lugn upplysning (`surface.raised`, `text.success`-glyf) med skälet och antalet väntande ändringar. Aldrig som fel: ingenting har gått fel för användaren.

### 16.3 Installationsbanner (endast webb)

- Visas efter tre besök, **en gång**, och stängs för gott.
- Ligger **ovanför bottennavigationen** och aldrig över primärhandlingen.
- Copyn säger vad installationen ger, inte att man ska installera: en visning måste bära sitt eget skäl.
- Alla kontroller i bannern har 48 px träffyta, även krysset.

### 16.4 Ceremonier

- Första receptets ceremoni hör till **sparningen**, aldrig till importen, och fyras **en gång per konto** — guidens import landar i editorn (`#onbimportklar`) och får inte utlösa den.
- Ceremonin varar **3 sekunder** och visar sin egen återstående tid som ett krympande hårstreck.
- Med **reducerad rörelse** ritas inget streck och ceremonin står kvar till tryck. En osynlig nedräkning är sämre än ingen.
- Knappen namnger sitt mål. *Fortsätt* är inte ett mål.

### 16.5 Gesttips behålls — med en regel för när de slutar visas

**Omvänt 2026-07-30 av B-47.** Regeln sa tidigare att tipsen utgår. De behålls, men villkorat: designens invändning var att en banner som lär ut en gest är ett kvitto på en kontroll som saknas, och villkoret nedan är det som gör invändningen ogiltig.

- **Ett gesttips får bara visas i en vy som redan har en synlig kontroll för samma handling.** Tipset lär ut en **genväg**. Finns ingen synlig väg är bannern inte ett tips utan enda dokumentationen — och då är felet den saknade kontrollen, inte bannern.
- **Tipset slutar visas permanent när gesten använts en gång.** Då är den inlärd. Har den inte använts visas tipset **högst tre gånger per gest**, aldrig två tips samtidigt, och aldrig under första sessionen (guiden äger den).
- Nycklarna behålls men byter innebörd: `seen` blir en **räknare** och `used` en **flagga**. En ren *sedd*-flagga kunde inte skilja inlärd från ignorerad — och det var orsaken till att bannern försvann just när användaren hade behövt den.
- Bannern är **avvisbar**, och ett avvisande räknas som en visning — aldrig som inlärt.
- Med **reducerad rörelse** ritas ingen animerad hand. Texten och kontrollen står still.
- De tre gesterna: **svep receptkortet** (BUT-982) mot kebaben på raden, **långtryck steget** mot timerknappen i steget, **svep varan** (BUT-1199) mot *Ta* på den delade varan.

---

## 17 · Flerval

Läst ur `mina_recept/selection_app_bar.dart`, `widgets/common/selection_bulk_bar.dart`, `widgets/common/dialogs/slot_picker_dialog.dart`, `personal_tags/personal_tag_bulk_dialogs.dart`, `personal_tag_selection_manager.dart`, `social/group_detail/group_members_list.dart`. Ramar: `#flerbar` `#flertagg` `#flermeny` `#flertaggsam` `#flergrupp`. Besvarar **K-05**.

**Rättelse av SK-17.** Påståendet att radera är den enda samlade handlingen gäller `SelectionBulkBar` (inköp, skafferi) — **inte** receptlistan, som har sex. SK-17 formuleras om till att gälla den widgeten.

### 17.1 Ingång, bar och utgång

- **Flerval har alltid en synlig ingång: *Välj* i toppfältet** (B-46 — **K-05 stängd 2026-07-30**). Ordet stod tidigare i listans kebab, alltså gömt två tryck bort bakom en glyf utan namn. Långtryck får finnas som genväg, aldrig som enda väg.
- **Sex ytor bär ordet, på samma plats:** receptlistan, inköpslistan, skafferiet, taggarna, gruppmedlemmarna och blockerade användare. Ligger listan i en flikvy sitter *Välj* i **vyns eget** toppfält och aldrig i skalets — annars byter ordet betydelse när man byter flik.
- **Toppfältet byter innehåll, inte höjd.** I flervalsläget ersätter räknaren titeln och *Avbryt* ersätter tillbakapilen. Fältet hoppar aldrig.
- Där en yta har **färre än två rader** visas *Välj* inte alls — ett flerval av ett är ingen funktion.
- **Baren hör till listan den styr.** Styr den hela skärmens lista sitter den fäst (topp i receptlistan, botten i inköp och skafferi); ligger listan i en förälders skroll är baren **inbäddad** ovanför listan.
- Räknaren är `{n} valda` i tabulära siffror. Handlingar som kräver ett urval är **avstängda vid noll** med namnet läsbart kvar.
- *Markera alla* är en **växel** och kan avmarkera. En markering utan väg tillbaka är en fälla.
- **Flervalet lämnas bara av användaren** — eller när sista bocken tas bort. Aldrig automatiskt efter ett delvis utfall, och aldrig när användaren skickas till en annan vy för att hämta något (en tagg) och kommer tillbaka.

### 17.2 Sex handlingar, ordnade

- Högst **tre handlingar i baren**, resten i en kebab, ordnade efter hur ofta de görs och hur svåra de är att ångra.
- **Radera ligger sist, ensamt**, avskilt med en linje, i `text.danger`.
- Massradering och masstagg har **7 s Ångra** (`commonUndo`). Handlingar som rör många rader får vår längsta ångerfrist.

### 17.3 Masstagg

- Semantiken är **lägg till, aldrig ersätt**, och **en tagg per omgång**. Rubriken säger vad som händer med de valda — ett ark med taggar ser annars ut som ett filter.
- **Tre utfall:** taggade (med Ångra) · alla bar redan taggen (upplysning, ingen Ångra, ingenting hände) · inga taggar finns (tom vy som leder till taggvyn **och behåller flervalet**).

### 17.4 Menyläggning och överfyllnad

- Recepten fylls i ordning från den valda dagen, och **ordningen visas i rutnätet** innan något skrivs.
- **Överfyllnad avgörs före skrivningen, aldrig efteråt.** En snackbar får inte utföra en skrivning (§ 2.4) — och särskilt inte en flerveckas. Arket ger tre lika synliga vägar: fyll det som ryms · fyll och lägg resten i nästa vecka · välj fler platser.
- De recept som inte får plats **namnges**. Ett antal utan namn är ingen upplysning.
- Tvåveckorstaket är en **gräns användaren ser**, inte en tystnad hon möter: samma situation ska se likadan ut oavsett hur hon kom dit.

### 17.5 Sammanslagning av taggar

- Sammanslagningen är **oåterkallelig i dag** och kräver därför en förhandsvisning som namnger **både** vad som raderas och hur många recept som flyttas — kodens kvitto räknar taggar där användaren väntar recept.
- Varje val visar **vad taggen bär i dag och hur många den får**: att välja minst använd tagg som mål flyttar flest recept.
- Målet får **inte** kunna byta under en skrivning. Låsningen behåller knappens namn; förloppet visas som hårstreck (K-06).
- Går Ångra att bygga är den kravet. Går den inte ska knappen heta vad den gör: *Slå samman, radera två*.

### 17.6 Delvis utfall (generaliseras som **I-29**)

- **Delvis utfall är ett tredje utfall**, inte ett lyckat och inte ett fel. Formen är `surface.raised` med varningskant.
- Det **namnger vad som gick, vad som inte gick och varför**, och de misslyckade **ligger kvar valda** så att försöket kan göras om.
- Gäller alla flervalsytor: medlemsborttagning, massradering av taggar, massdelning, massmenyläggning.

---

## 18 · Feedback och rapportering

Läst ur `feedback_fab.dart`, `feedback_form_dialog.dart`, `feedback_service.dart`, `interaction_logger.dart`, `admin/feedback_inbox_view.dart`, `report_content_dialog.dart`, `settings/blocked_users_section.dart`. Ramar: `#fbknapp` `#fbformular` `#fbinkorgvy` `#fbkortmonster` `#fbanmal` `#fbblockerade`.

### 18.1 Feedbackknappen

- Betaverktyg, inte produktfunktion. Den **konkurrerar aldrig med skärmens primärhandling**: döljs när ark eller dialog är öppen, viker för snackbaren, finns inte i matlagningsläget.
- Knappen namnger sig vid första visningen. Ett utropstecken är ingen etikett.

### 18.2 Vad som följer med (art. 9-gränsen)

- Skärmdumpen tas **innan** dialogen öppnas. Därför öppnar formuläret med bilden **synlig**, inte gömd.
- Allt som skickas står i ett eget block, **rad för rad och avbockningsbart**: bilden (med förhandsvisning och orden *även namn och allergier*), enhetsinfon **i klartext**, och skärmvägen med **de faktiska skärmnamnen**, utfällbar till alla tjugo. Man samtycker till innehåll, inte till kategorier (jfr `#familjmedlemsamtycke`).
- Tom beskrivning ger fel **vid fältet**, aldrig i en snackbar (I-23).
- Kvittot skiljer **skickat med bild** från **skickat utan bild**. En misslyckad bilduppladdning får inte tyst bli ett lyckat kvitto.

### 18.3 Adminsidan

- `Kopiera för Claude` heter **Kopiera felsökningstext**, innehåller **inte** e-postadressen, och redovisar under knappen vad som kopieras.
- **Varje kopiering loggas i `ops_log`.** En utlämning utan spår är den enda sortens utlämning vi inte kan svara på.
- Filter och status får inte se likadana ut: filtret är chips, statusen en rullgardin per kort.
- Adminvyer ritas i vår palett men **utan omsorg om skönhet** — täthet före rytm.

### 18.4 Anmälan

- Fem skäl i klartext, inga förkortningar. *Annat* kräver en beskrivning.
- **Den version av riktlinjerna anmälaren såg är den som gäller** — och versionen ska synas.
- Kvittot säger tre ting: **vem** som läser (en människa), **när** (inom ett dygn), och att **innehållet syns kvar** i väntan.
- **Blockera samtidigt** erbjuds som ett eget, avbockningsbart val. Anmälan och blockering är olika beslut.

### 18.5 Blockerade

- Sektionen är **utfälld** när listan inte är tom. En person man valt att inte se göms inte bakom ett tryck.
- Det står i klartext **vad blockeringen inte gör**: den stoppar det framåt, den återkallar ingenting redan delat, och den upplöser inte ett gemensamt gruppmedlemskap (`#vanprofildelning`).
- Ett raderat konto visas som *Kontot finns inte längre* i kursiv — aldrig som ett användar-id.
- Avblockering behöver Ångra; massavblockering följer **I-29**.

---

## 19 · Aktivitet, chatt och grupper

Läst ur `friends_list/feed_tab.dart`, `user_profile_edit/privacy_section.dart`, `poll_creation_dialog.dart`, `poll_message_widget.dart`, `emoji_reaction_picker.dart`, `emoji_reaction_display.dart`, `groups/ownership_transfer_dialog.dart`, `messaging/group_detail_view.dart`, `shared_recipes_by_friend_view.dart`. Ramar: `#socflode` `#soctomtingavanner` `#soctomttyst` `#socbegar` `#socintegritet` `#socomrostning` `#socreaktion` `#socgruppinfo` `#socoverlat` `#socdelatvan`.

### 19.1 Flödet

- **Varje händelsetyp har sitt eget verb.** Ternären *cooked → lagade, annars delade* gör falska påståenden om andras handlingar.
- Receptets titel skrivs **som den heter**. `toLowerCase()` i flödeskortet utgår — form får inte ändra ett egennamn.
- Ett kort bär **en** färgad kant (typmarkören till vänster). Den dekorativa rostkanten nedtill utgår.
- **Knuffar utgår som händelsetyp**, inte bara som funktion: kvarvarande `pinged`-händelser skulle annars visas som falska delningar.
- Tre tomma lägen, inte två: inga vänner (uppmaning) · tyst (ingen uppmaning) · **filtret tomt** (egen copy + väg tillbaka till *Allt*).
- Oändlig skroll hör i en skrollyssnare, aldrig i `itemBuilder`.

### 19.2 Begär receptet

- Kortet säger **innan** trycket att receptet inte är delat. En fråga får inte komma som svar på ett tryck som såg ut att öppna något.
- Efter skickat visar kortet **Efterfrågat** med tidpunkt, och samma fråga kan inte skickas igen.
- Ägarens sida krävs: ja och nej i `#notisertyp`, och ett nej behöver ingen förklaring.

### 19.3 Aktivitetsdelningens undervärden

- **Ett underval visar alltid sitt eget sparade värde — aldrig förälderns.** Är huvudreglaget av är gruppen **synligt vilande**, inte falskt avslagen (jfr KI-12).
- Minderårigas sökbarhet går genom servern och är låst under sparning. Det ska **synas** som ett skäl, inte som trögt reglage.
- En händelsetyp utan reglage broadcastas inte.

### 19.4 Röstningar (chatt och meny)

- **Varje röstning har en sluttid, och sluttiden avgör något.** Chattomröstningen saknar deadline; menyröstningen har en som aldrig avgör (MR-07). Båda felen rättas av samma regel.
- Att **byta röst** är möjligt och ska synas som möjligt.
- **Oavgjort** avgörs av skaparen eller genom slump — och kortet säger vilket som hände.
- En stängd röstning visar **vad som vann** och erbjuder handlingen som följer av resultatet.

### 19.5 Emoji

- Se `content-style-guide.md`: vår typografi bär inga emoji; användarens ord får emoji; **reaktioner är användarens ord**.
- Reaktionerna är **sex, låsta**. Väljaren följer vår arkform (kvadratisk, 48 px per ruta), märkena har minst 44 px höjd, och den egna reaktionen skiljs med **vikt**, inte bara ton.

### 19.6 Två slags grupper

- Chattens grupp heter **samtalet**; vänkategorins heter **gruppen**. Två saker, två ord.
- **Ingen människa raderas** (K-11): att ta bort en medlem har egen text som säger vad som blir kvar — meddelandena, kontot, möjligheten att bjuda in igen.
- Ägarskapsöverlåtelsen säger **vad ägarskapet innebär** innan man ger bort det, visar **inte** medlemmarnas e-postadresser, och den nya ägaren får veta.
- **Delade listor behöver samma överlåtelse som grupper** (D-07b).
- En delning som dragits tillbaka visas **en gång** som gråtonad rad med skäl, aldrig genom tyst försvinnande.

### 19.7 Knuffen

**Behållen 2026-07-30 av B-47**, emot designens råd. Invändningen står kvar och är formulerad som regler: en knuff är en påminnelse mellan människor som bor ihop, och den får aldrig bli ett verktyg för press.

- **En knuff per person och rätt.** Inte per dag, inte per timme — en. Går den inte fram är svaret ett samtal vid bordet, inte en andra knuff.
- **Knuffen är en händelse i flödet, inte en notis** som väcker någon. Den som knuffats ser den när hen öppnar appen.
- **Mottagaren kan stänga av knuffar för sig** i notisinställningarna, och avstängningen visas för avsändaren **innan** hen knuffar — annars skickar man i tomma intet.
- **Ingen knuff till ett barns profil.** Barn under 15 har inga konton (§ 7); en vuxenförvaltad profil kan inte tas emot en påminnelse.
- **Händelsetypen `pinged` får sitt eget verb** i flödet — *påminde*. Den ternär som i dag skriver *delade* för allt som inte är `cooked` är ett fel oavsett detta beslut, och rättas i samma ändring.
- Knuffen har **ingen räknare och ingen historik**. Antalet påminnelser är inte en uppgift någon i ett hushåll ska kunna läsa av.

---

## 20 · Inställningar, juridik, admin och komponenter

Ramar: `#insthushall` `#instportion` `#jurriktlinjer` `#sokpanel` `#admmatning` `#admdrift` `#kompbild` `#kompdubblett` `#komprelaterade` `#kompmallar` `#komprost` `#kompsason` `#kompkalla` `#komparvegods` `#installergen` `#surfplatta`.

- **20.1 Hushållsstorlek.** En sanning, en plats: den här vyn äger värdet, profilen pekar hit (B-39). Tomt heter *som receptet säger*. Exit-vakten kastar aldrig en ändring tyst.
- **20.2 Portionsskalning.** Skalning är **inte** en sparning, och det syns (*skrivet för 4*). Enhetsväxeln visas bara när receptet har amerikanska enheter — och förklarar sig då. Ett hushållsförval som landar efter första ritningen kvitteras en gång.
- **20.3 Juridiska dokument.** Fyra, samma huvud (titel, version, datum), samma fot, samma markdownvisare — och **rå markdown får aldrig nå en användare** (KI-26). Riktlinjernas version syns, eftersom den stämplas på anmälningar.
- **20.4 Sök och filter.** Sju filtergrupper ordnas efter användning; **allergener och kost ligger överst** — de är begränsningar, inte preferenser. Egna taggar är en **trelägesväxel** (av · med · utan), så att en tagg inte kan vara både vald och utesluten. Träffraden säger vad som begränsar, inte bara hur många som blev kvar.
- **20.5 Mätvärden.** Varje mätvärde bär sin definition (informationsknappen är obligatorisk). *Ingen data* skrivs som ord, aldrig som en nolla.
  - **Skalan är sekventiell.** `dataScale.sequential` (fem toner, ink → ljusast) gäller **storlek och ordning**: matrisceller, en serie, tratt, andelar. Den är monokrom med avsikt.
  - **Ingen kategorisk kulörskala finns, och ingen ska införas.** Butlery har en accent och tre statusfärger; varje femfärgsskala för obundna serier krockar antingen med statusbetydelserna eller uppfinner en palett som inte är vår. `dataScale.categorical` är `null` **med flit** — inte oifyllt.
  - **Högst tre färgade serier** (`maxColouredSeries: 3`), och de tas ur steg **1, 2 och 5** — de tre som går att skilja åt i gråskala. **Fyra eller fler serier är ingen graf, det är en tabell.**
  - **Statusfärg får bara användas när statusen *är* datan** (en felkvot i `text.danger`, en lyckandegrad i `text.success`) — och serien ska då **namnges**, aldrig bara färgas. I övrigt är statusfärger förbjudna i data.
  - **Ordningen bär informationen** (KO-12): staplar sorteras efter storlek, linjer märks vid sin slutpunkt, matriser behåller sin etikettkolumn.
  - **Steg 4 och 5 bär aldrig papper** — de kräver ink ovanpå (`dataScale.onFill`). Paren står inte i `contrastPairs` så länge ingen vy ritar skalan; de läggs tillbaka med den första vyn som gör det (D1 = B, BUT-2191, Malin 2026-10-04).
- **20.6 Adminvyer.** Gleshet före lansering förklaras **i** tabellen. Ett fält som ofta fastnar i parsningen är en **uppgift**, inte en siffra: raden leder till importerna.
- **20.7 Bilduppladdning.** Per-bild-tillstånd, aldrig en samlad stapel. Faller den primära bilden flyttas omslaget **och det sägs**.
- **20.8 Sammanslagning av recept.** Skillnaderna fält för fält, förval på det befintliga receptet, och tre löften: båda bildmängderna behålls, anteckningar och betyg följer med, **menyplaceringar pekas om**.
- **20.9 Relaterade recept.** Relationen går **båda vägarna** och det sägs vid handlingen.
- **20.10 Inköpsmallar.** Användningsantalet står först. *Använd* ligger i raden, radera i kebaben. Mallen **läggs till** och slår samman dubbletter — den ersätter aldrig listan.
- **20.11 Röstassistans.** Fyra tillstånd, fyra ord vid knappen (*säg något · hör dig … · tolkar … · läser upp*). Barge-in namnges. Pulsen bara medan den lyssnar, aldrig vid reducerad rörelse.
- **20.12 Säsongsraden.** Talet är **dina** recept, aldrig förslag utifrån. Noll träffar eller okänd månadsnyckel → raden visas inte.
- **20.13 Källartefakten.** Råtexten är ett **citat** (monospace, ramad), aldrig redigerbar. Över 30 dagar varnas som upplysning. **Jämför** är förval; *Tolka om* säger att den skriver över.
- **20.14 Arvegods.** **Originalbilden är receptet** — den sparas alltid och visas överst; texten är en avskrift. Sidordningen går att rätta även efter tolkning. Att handskrift är svårare sägs **före**, inte som fel efteråt.
- **20.15 Hushållets allergenfilter.** Följden namnges med personer och antal. Ett gömt recept är gömt, inte borta. Och **filtret är aldrig ett skydd** — det står rakt ut.
- **20.16 Bred yta.** Bred layout **lägger sida vid sida**, staplar inte om. Max textbredd gäller kolumnen, inte sidan. Tre ytor tål bred layout (receptet, veckomenyn, inköpslistan); resten förblir en kolumn. Hela nuvarande ritning är 412 px — bred layout är en egen etapp.

---

## 21 · Bred layout

Läst ur `core/responsive/breakpoints.dart`, `responsive_builder.dart`, `common/navigation/adaptive_navigation.dart`, `scaffolds/responsive_scaffold_builder.dart`, `common/responsive/responsive_grid.dart`, `recipe_detail/recipe_detail_tablet_content.dart`. Ramar: `#bredbrytpunkter` `#bredskal` `#bredlandskap` `#bredrecept` `#bredmeny` `#bredinkop` `#bredgrid` `#bredgrans` `#bredarbete`. Ersätter KO-23.

**Specen rättas.** `00-spec-index.md` sa att tablet- och desktoplayout var uttalat out of scope. Appen har ett fullt responsivt system i drift — vi hade inte avstått, vi hade lämnat det oritat.

### 21.1 Brytpunkter

- **Tre brytpunkter styr layout: 320 (golv) · 768 (skena + två spalter) · 1024 (utfälld skena + tre kolumner).** Kodens övriga tal (600, 1280, 1920) får finnas som mätpunkter men **ingen av dem ändrar en layout** utan en egen rad här.
- **600 används inte till layout.** En telefon i liggande läge är en telefon.
- Kodens tre överlappande frågor om samma bredd (`isTablet` 600–1024, `isLargeTablet` 768–1280, `isSmallMobile` <768) reduceras till en. En skärm får inte kunna vara två kategorier samtidigt.
- **Max radlängd gäller alltid, även på mobil** — `getMaxContentWidth` får inte returnera `infinity`. Löptext högst **72 tecken**, och måttet gäller **kolumnen**, inte sidan.

### 21.2 Navigationens form

- **Skena vid bredd ≥ 768 OCH höjd ≥ 500.** Under 500 px höjd gäller en spalt och bottenrad oavsett bredd — systemets enda höjdregel, och den finns för köket.
- **Skenan bär bottenradens vokabulär:** samma botten, samma etiketter med versal begynnelsebokstav (Hem, Meny, Inköp, Mer — Komponentark v1:663–666), och **rostmarkeringen** — liggande som en list till vänster om vald post. En orörd Material-`NavigationRail` byter appens identitet vid rotation.
- **`lägg till` är ingen destination.** Den är en handling: rund saffransknapp överst i skenan, avskild från platserna. (Gäller även bottenraden, där den redan är ritad så.)
- Den utfällda skenan visar **ordmärket som vektor**, aldrig `Text('Butlery')`.
- Destinationsbyte får inte kasta historik: `pushReplacementNamed` raderar skrollposition och öppet filter, vilket en synlig skena gör påtagligt.

### 21.3 Fyra ytor får bred layout

- **Receptet** — ingredienser smalt till vänster (med portionsskalaren överst, **klistrad**), stegen brett till höger, socialt i ett **fullbrett band under**. Delningen följer läsning, inte datamodell. **En sidskroll**, aldrig två oberoende skrollytor. Arvegodsskanningen ligger där omslaget ligger: brett och överst (§ 20.14).
- **Veckomenyn** — sju kolumner, måltider som rader, hela veckan samtidigt. Rutnätet finns **bara** över 768; listan är den rätta formen på telefon, inte en nödlösning. Närvaroraden är en kontroll även i en smal kolumn (B-40/41); tom plats är en knapp med 44 px mål.
- **Inköpslistan** — varorna **en kolumn bred, alltid** (bockning får inte flytta ögat i sidled); bredden går till en spalt som svarar på **härkomst** (recept, vecka, egna tillägg, skafferi). Flervalsbaren sitter i listans kolumn, inte över hela skärmen (§ 17.1).
- **Adminpanelen** — redan i drift.

### 21.4 Rutnät och kort

- **Högst tre kolumner.** Aldrig fyra: vi har inte bildmaterial som bär den, och korten blir ikoner.
- **Kolumngolv 240 px.** Ryms tre inte över golvet blir det två — innehållet bestämmer, inte brytpunkten.
- **Kortets proportion är konstant** över alla brytpunkter: bild 4:3, text under.
- Det som inte är ett rutnät blir inte ett: chips och taggar förblir `Wrap`; textlistor (inköp, skafferi, medlemmar, notiser) förblir **en kolumn**.

### 21.5 Vad som förblir en spalt

- Allt utom de fyra: inloggning och konto, familj, integritet, juridik, feedback, notisinställningar och **editorn**. Max **600 px** (`getMaxFormWidth` har redan talet), centrerat.
- **En spalt i mitten är inte ett misslyckande.** Ett formulär är en följd av frågor; två spalter gör ordningen och tabbordningen sämre.
- **Editorn:** texten smal, kontexten i marginalen (utkaststatus, bilder, källartefakt). Det som inte är text ligger utanför textens spalt.
- **Marginaler bär kontext eller ingenting** — aldrig tips, förslag eller reklam för egna funktioner. Tom marginal är vila.
- **320 px-golvet gäller först.** En layout som bara fungerar bred är trasig; en som bara fungerar smal är ofullständig.

---

## 22 · Breda vyer i detalj

§ 21 är systemreglerna (brytpunkter, skena, gränsen). § 22 är **tillståndsreglerna per bred yta**. Ramar 11.1: `#vmbnormal` `#vmbtom` `#vmbgenererar` `#vmbomrostning` `#vmbkonflikt` `#vmbdelvis` `#vmboffline` `#vmbflytta`. Läst ur `veckomeny_view.dart`, `realtime/conflict_diff_view.dart`, `cooking_mode_view.dart`, `recipe_detail_tablet_content.dart`, `input/portion_scaler.dart`, `voice_assist_button.dart` (övriga meny- och receptfiler lästa i tidigare etapper).

**Etappens bärande regel:** ett tillstånd som finns på telefonen finns också brett. **Bred layout får aldrig ha färre tillstånd än den smala** — det är så tysta fel uppstår.

### 22.1 Rutnätets ram

- **Kalenderläget lyder inte under textbredden.** Maxbredden (900 på tablet) finns för radlängd; ett rutnät är inte löptext. Listläget behåller sina 900.
- **Prompten bor i en egen smal spalt till vänster**, aldrig ovanför veckan. Den används en gång i veckan och får inte äta en tredjedel av höjden.
- **Tre cellmarkeringar, tre former, aldrig samma:** *i dag* = saffranskant · *skrivs över* = rostkant · *osparat* = streckad kant med klocka. Ingen betydelse bärs av färg ensam.
- Närvaron ligger **i cellen** (BUT-1611), är en **kontroll** på 48 px, och degraderar till *en avatar plus antal* över tre ansikten (B-40/41) — lika strikt i en smal kolumn.
- **NY-brickan** (`recentlyPlacedEntryIds`) visar vad senaste genereringen la.

### 22.2 Tom vecka

- **Ett rutnät har inget tomt läge i mitten.** Rutnätet står kvar och är fullt användbart; det tomma läget bor i promptspalten.
- **En enda framhävd ingång** (dagens ruta). Fjorton lika starka uppmaningar är ingen uppmaning.
- Förstagångsläget skiljs från den rensade veckan — koden gör det redan (`_loadViewModePreference`) och det ska bevaras.

### 22.3 Generering och överskrivning

- **Bekräftelsen är en markering i rutnätet, inte en dialog.** `_confirmOverwrite` ber i dag om *Fortsätt* utan att säga vad som förloras; brett ramas de berörda rutorna in och räknas. Samma princip som § 17.5.
- **Genereringsoverlayen utgår.** Rutorna fylls i ordning så att man ser veckan fyllas och förstår placeringslogiken. Förlopp som hårstreck per ruta, aldrig spinner (K-06); med reducerad rörelse fylls de direkt.
- **Avbryt stannar där genereringen är** — det som lagts ligger kvar.
- **Generering skriver aldrig över en manuell placering utan att säga det.**

### 22.4 Röstning i en cell

- Cellen svarar på **är dagen avgjord**: att det är en röstning, vad som leder, om du röstat, när den stänger. Alternativen ligger ett tryck bort.
- **En stängd röstning lämnar alltid något i cellen** — även när ingen vann. En utgången oavgjord röst får inte lämna rutan tom utan spår (MR-07).
- **Högst en röstning per cell.** Två samtidiga om samma måltid är en bugg, inte ett tillstånd.

### 22.5 Konflikt i en cell

- Konflikten visas **där den hände**: båda versionerna i cellen, med kodens färgspråk (min = framgång, den andras = varning) och *Behåll min* i rutan. Helskärmsdiffen gäller konflikter i receptet självt.
- **Cellen får bredda sig över två kolumner medan konflikten är öppen** — den enda plats i systemet där en cell byter storlek, och bara så länge något kräver svar.
- **Ingen sammanslagning ritas.** En av versionerna gäller; den andra ska kunna räddas med ett tryck.

### 22.6 Delvis utfall

- Resterna ligger i en **bricka ovanför nätet — ett arbetsförråd, inte en notis**: den överlever omladdning, ligger kvar tills den töms, och säger *varför* resten inte fick plats.
- Placeringsordningen visas som siffror i rutorna, så resultatet inte är en gissning.
- Med brickan blir **FL-11 onödig**: nästa vecka är ett val i brickan, inte en handling i en snackbar.

### 22.7 Frånkopplat

- **Offline låser inte rutnätet.** Planering fortsätter; endast **generering** stängs av, med skälet skrivet i klartext.
- Osparade ändringar syns **per cell**, inklusive en **tömd** ruta — borttagningen är också en ändring. Antalet står i huvudet (GL-07).

### 22.8 Flytt och dragning

- **Dragning tillåts som genväg** — till skillnad från svep-gesterna i § 16.5, eftersom **målen syns på samma skärm som handen**: gesten förklarar sig själv och behöver ingen banner.
- Lediga mål markeras under dragning; **upptagna mål byter plats**, de skriver inte över. Passerade dagar är inte mål. Släpp utanför nätet gör ingenting.
- **En likvärdig synlig väg finns alltid** i cellens kebab (*Flytta till …*), och den fungerar med tangentbord och skärmläsare: markera, *Flytta*, pilar, Enter.

### 22.9 Receptet brett · ram och skalning

- Omslaget **sträcker sig över båda spalterna** — det hör till receptet, inte till stegen.
- Det aktiva steget bär samma **3 px vilolinje** som i matlagningsläget; vokabulären är gemensam mellan vyerna.
- Titeln skrivs **som den heter** (SO-02): `toLowerCase()` finns nu på två ställen — flödeskortet och matlagningsläget — vilket gör det till en vana, inte ett misstag.
- Skalningen visar **receptets egna tal i grått** och en *Återställ* så snart man avvikit. **Tiderna i stegen skalas aldrig**, och det sägs.

### 22.10 Ofullständigt recept

- Fullständighetsbanderollen ligger **över båda spalterna, under omslaget** — den gäller receptet, inte instruktionerna — och **pekar på fälten** i stället för att konstatera.
- **Det som saknas syns där det saknas:** en lucka i mängdkolumnen, tryckbar, 44 px. Det som saknas ska gå att skilja från det som är noll.

### 22.11 Läsläge (någon annans recept)

- **Läsläget byter ut, det tar inte bort.** Redigering, radering och taggning ersätts av härkomst, *spara till mitt kök* och — när receptet inte är delat — *be om det* (SO-07). Tomrum där kontroller låg är brett ett synligt fel.
- **Ett sparat exemplar blir ditt:** ändringar syns inte hos ägaren, och ägarens ändringar kommer inte till dig. Det står i klartext.
- Reaktioner är tillåtna i läsläge; redigering är inte.

### 22.12 Arvegods brett

- **Bilden ligger där omslaget ligger** — brett och överst, inte i den smala spalten med `maxHeight: 420`.
- Under den står **råtext och avskrift sida vid sida** för radvis jämförelse; sidremsan visar alla sidor samtidigt och ordningen går att rätta efter tolkning.
- Bilden går att **förstora utan att lämna vyn** (`fullscreen_image_viewer.dart`).

### 22.13 Bandet under stegen

- Kommentarer, delningsstatus och relaterade recept ligger **fullbrett under stegen** — aldrig i en tredje spalt bredvid dem.
- Bandet är en **600 px spalt i ett fullbrett fält**; bredden går till luft (§ 21.5). **Cook snaps är undantaget** — bilder tål bredd.

### 22.14 Receptet offline

- **Dela skärmen efter vad som är sant**, inte efter en varning över allt: ingredienser, steg och skalning är lokala och orörda.
- **Laga-knappen fungerar offline.** Matlagningsläget är lokalt, och offline är dess vanligaste läge (BUT-1360).
- Ingrediensbyte kräver uppkoppling och **säger det** — en tom förslagslista offline betyder *kunde inte läsa*, inte *finns inga*.

### 22.15 Inköpslistan brett

- Varorna är **en kolumn bred, alltid**; bredden ger mer information per rad, aldrig fler rader per bredd.
- Härkomstspalten svarar på **varför** varan står där (recept, vecka, egna tillägg) och i en delad lista även **vem**.
- Skafferiet ligger i högerspalten, är **opt-in**, och utesluter inget automatiskt.
- Flervalsbaren sitter i **listans kolumn** (§ 17.1).

### 22.16 Två tomma lägen sida vid sida

- **Högerspalten finns inte förrän det finns något att förklara** — ingen rubrik, ingen tom ram, ingen platshållare. En tom marginal är vila.
- Handlingen i det tomma läget är **veckans meny**, inte *lägg till vara*.

### 22.17 Delad lista brett

- Anspråk visas **som ett namn i raden**, inte som en färg. *Tagen* är inte *bockad*.
- En *se*-medlem ser samma vy **utan bockrutor** — inte en gråtonad kopia.
- **Ett anspråk förfaller efter ett dygn** och släpps tillbaka.

### 22.18 Delad lista offline

- Huvudet säger **när** listan senast var uppdaterad, inte bara att uppkopplingen är borta.
- **Anspråk från före tystnaden märks som osäkra** — ett minne, inte ett faktum.
- Bockningar köas och tappas aldrig. Slår två personer av samma vara ska **listan säga det vid synk**, inte användaren räkna ut det i kassan.

### 22.19 Matlagningsläget · rotation och skala

- **Tvinga rotation endast under 768 px kortaste sida.** Över det följer vyn enheten: porträtt ger ingredienserna som ett band överst och stegen under; liggande ger 35/65.
- Textskalan är vyns egen (`fontScale`, BUT-898) och startar på **A+** brett.
- Skärmen hålls vaken **bara medan vyn lever**.

### 22.20 De två gesterna i matlagningsläget

- **Timergesten har redan sin synliga kontroll** (`InlineTimerText` gör tidsfrasen tryckbar, BUT-604) — alltså kan `SwipeHintBanner` tas bort ur vyn i dag utan att något går förlorat (§ 16.5).
- **Ingrediensbytet får en alltid synlig ikon** i raden. I ett kök finns ingen hovring.
- **Bytet frågar om det gäller i dag eller receptet**, med *bara i dag* som förval. Koden sparar i dag alltid i receptet — det är felet.

### 22.21 Timrar, röst och tomt recept

- Timrarna får en **egen list över hela bredden**; röstknappen sitter i stegspalten; stegnavigeringen i ingrediensspaltens fot. Tre saker slutar konkurrera om samma hörn.
- **Varje timer säger vilket steg den hör till.** En utgången timer **står kvar i listen tills den kvitteras** — en snackbar är fel kanal för något man ska höra tvärs över köket.
- Talsvaret kan tystas, och tystningsknappen finns **bara** när en svensk röst är tillgänglig.

#### 22.21b Timerns exakta tid — vad vi får lova (T-06)

Appen ber i dag aldrig om `SCHEDULE_EXACT_ALARM`, och på Android 13+ får den då inte lägga ett exakt larm. Tre vägar är ritade (`#behlarmnekat`, `#lagatimerlofte`, `#lagatimernotis`, `#lagatimerutgangen`); vägvalet är produktens, men reglerna nedan gäller oavsett vilken som väljs.

- **En timer får aldrig lova en tid den inte kan hålla.** Är exakt tid inte möjlig sägs det i vyn — *ringer strax efter* — inte i ett hjälpavsnitt. Ett kontrakt skrivet som siffra (`08:00`) är starkare än en förväntan skriven i ord, och skillnaden ska vara medveten.
- **Nej-vägen är obligatorisk.** Även väg A hamnar i nekat läge för någon: på Android 14+ är behörigheten nekad som standard och dialogens knapp leder ut i en systeminställning.
- **Butlery frågar en gång.** En app som ber om samma behörighet vid varje timer har inte accepterat svaret. Vägen tillbaka ligger som en **rad** i timervyn, inte som en påminnelse, och försvinner när tillåtelsen finns.
- **Förgrundstjänsten (väg C) är designens förstahandsval.** Den ger exakt tid utan dialog, och notisen är en funktion: tiden syns från andra sidan köket på en låst telefon. Notisen finns **bara medan en timer går**, visar **vilket steg** timern hör till, bär `+1 min` och `Pausa` — handlingar man gör med en hand — och **samlar alla timrar i en notis** med den närmaste först.
- **Kan tjänsten inte startas gäller det sänkta löftet.** Det är en fallback, inte ett fel, och den får inte visas som ett fel.
- **Den utgångna timern står kvar tills den kvitteras**, i notisen och i listen i appen. Den säger **vad** som är klart, inte att en timer gick ut, och namnger steget så att den som kommer tillbaka vet var i receptet hon var. Med reducerad rörelse pulserar ingenting.
- Ett recept **utan steg** öppnar ett tomt läge med väg till redigeringen och till inköpslistan — och **utan** tvingad rotation, vakenhållen skärm eller *lagar just nu*-signal. En signal om något som inte händer är en lögn i ett socialt flöde.

### 20.16 Tomlägesglyfen

- **Två fall, aldrig fler.** *I vyn* (rutnätets kolumn, en panel, en lista som är tom): glyfen är **dubbla rubrikgraden** — 17 px rubrik ger 34, 19 ger 38, 20 ger 40. *I stället för vyn* (helskärmsavbrott: underhåll, e-postverifiering): **fast 64**.
- **Glyfen är underordnad rubriken.** Den får aldrig konkurrera med orden — det är texten som säger vad som saknas.
- **Strecket är 1,4**, tunnare än ui-familjens 1,75: glyfen är en bild, inte en kontroll.
- Clochen används aldrig som statusbild (B-19). Och offline är en **banner**, aldrig ett tomt läge (§ 9.2) — de två får inte se likadana ut.

### 20.17 Knappordning i bekräftelser

- **Reträtten står till vänster, följden till höger.** Ordningen är fast och gäller varje dialog, ark och handlingsrad — läsordningen ska sluta i det som händer.
- **Regeln handlar om betydelse, inte om ordet *Avbryt*.** I en dialog som bekräftar ett avbrott *är* avbrottet följden: `#impassistavbryt` har därför rätt ordning med *Fortsätt tolka* till vänster och *Avbryt tolkningen* till höger. Ordet säger ingenting om vilken knapp som bär konsekvensen.
- **Reträtten bär aldrig accent.** Saffran betyder handling (K-03); den knapp man trycker för att *inte* göra något får kontur, inte fyllning.
- **Tre knappar är en varning.** Ryms handlingen inte i två val är valet oftast inte färdigtänkt — undantaget är *Spara · Kasta · Avbryt*, som är tre olika utfall och inte tre grader av samma.

### 20.18 Termbruk

- **Hushåll**, aldrig *familj*, i all systemtext. Hushållet är entiteten — den har medlemmar, roller, behörigheter och en gemensam allergiunion; *familj* är en av flera sorters hushåll och utesluter de andra. Reglerna använder ordet konsekvent på 42 ställen; UI-copyn ska göra detsamma.
- *Familj* får stå i **löptext om produkten** (rubriker, dokumentation) där ordet beskriver en läsargrupp — aldrig i en etikett, knapp eller skärmläsartext.
- **Rätt**, inte *måltid*, om maten. **Måltid** används bara om **platsen i veckan** (måndag middag är en måltid, pannbiffarna är en rätt).
- **Inköpslista** · **skafferi** · **veckomeny** är namnen. Inga synonymer finns i systemtexten och inga ska införas.
