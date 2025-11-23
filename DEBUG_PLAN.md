# Butlery - Debug-plan
**Skapad:** 2025-11-22
**Analyserad av:** Claude Code
**Bas:** EXISTING_FEATURES.md

---

## Sammanfattning av Butlery

**Butlery** är en komplett svensk recepthanteringsapp med stark social och samarbetsfokus. Här är kärnan:

### Vad är Butlery?

**Butlery** är en receptapp för svensktalande hemmakockar med 60+ funktioner fördelade över 15 kategorier. Appen kombinerar:

1. **Recepthantering** – Skapa, redigera, dela och importera recept från 15+ svenska webbplatser (Arla, ICA, Köket m.fl.), sociala medier (Instagram, TikTok, YouTube), foton (OCR), eller manuellt.

2. **Menyplanering med AI** – Generera veckomeny via svenska naturliga språkprompter (t.ex. "3 middagar, 2 luncher, 1 frukost"). Samarbeta i realtid med upp till 10 användare.

3. **Inköpslistor** – Skapa och hantera flera listor, lägg till ingredienser från recept (skalade efter portioner), samarbeta i realtid med vänner/familj, exportera till CSV/text.

4. **Social plattform** – Vänhantering, grupper, delning av recept/menyer/listor, kommentarer, betyg, aktivitetsflöde, rekommendationer, direktmeddelanden och gruppchatt.

5. **GDPR-efterlevnad** – Fullständig hantering av samtycke, dataexport, kontoborttagning och revisionsspår (produktionsklar för EU-marknaden).

6. **Offline-first arkitektur** – All kärnfunktionalitet fungerar offline med synkronisering när appen kommer online igen.

7. **Realtidssamarbete** – Upp till 10 samtidiga redigerare på recept, menyer och inköpslistor med live-närvaro och konfliktlösning.

**Teknisk grund:** MVVM + Repository Pattern, Firebase (Auth, Firestore, Storage, FCM), modulariserad Dependency Injection, 40 000+ rader servicelager.

---

## Prioriterade testflöden

### 1. Autentisering & Onboarding [KRITISKT]

**Flöde:**
- Öppna appen → Registrera nytt konto → Logga in → Logga ut → Återlogga in

**Varför:**
- Grund för all funktionalitet; om detta inte fungerar kan ingenting annat testas

**UI-fokus:**
- Finns det tydliga felmeddelanden vid felaktig inmatning?
- Hur ser laddningstillstånd ut (spinner, text, knappar)?
- Går navigering till rätt vy efter lyckad inloggning?

**Teststeg:**
1. Öppna appen från scratch
2. Notera vilken skärm som visas
3. Om inloggningsskärm:
   - Klicka på "Registrera" (om tillgänglig)
   - Fyll i email + lösenord
   - Observera laddning/felmeddelanden
   - Notera var du hamnar efter lyckad registrering
4. Logga ut (om det finns en knapp)
5. Logga in igen med samma credentials
6. Verifiera att du hamnar på rätt vy

---

### 2. Recepthantering (grundläggande CRUD) [HÖGT]

**Flöde:**
- Skapa recept manuellt → Visa receptlista → Öppna receptdetalj → Redigera recept → Ta bort recept

**Varför:**
- Kärnfunktionalitet som största delen av appen bygger på

**UI-fokus:**
- Visas receptet korrekt i listan efter skapande?
- Stämmer portioner, ingredienser och instruktioner i detaljvyn?
- Fungerar bilduppladdning (tumnagelbildning, progressindikator)?
- Vad händer vid långsam nätverksanslutning?

**Teststeg:**
1. Från hemskärm/receptlista: Klicka på "+" eller "Lägg till recept"
2. Välj "Skriv själv" eller manuell inmatning
3. Fyll i:
   - Titel: "Testrecept Pannkakor"
   - Portioner: 4
   - Ingredienser: "3 ägg", "5 dl mjölk", "3 dl mjöl"
   - Instruktioner: "Vispa ihop allt. Stek i smör."
4. Ladda upp en testbild (om möjligt)
5. Spara receptet
6. Observera:
   - Laddningsindikator?
   - Navigering tillbaka till listan?
   - Syns receptet i listan?
7. Klicka på receptet i listan
8. Verifiera att alla uppgifter visas korrekt
9. Klicka "Redigera" → Ändra portioner till 8 → Spara
10. Gå tillbaka och verifiera att portionerna uppdaterats
11. Ta bort receptet → Bekräfta → Verifiera att det försvinner från listan

---

### 3. Import (URL-import som exempel) [MEDELHÖGT]

**Flöde:**
- Välj "Importera via URL" → Klistra in URL från ICA/Arla → Analysera → Granska → Spara

**Varför:**
- Differentiator med stöd för 15+ svenska receptsajter

**UI-fokus:**
- Visas laddningsindikator under scraping/AI-parsing?
- Hur hanteras felade importer (felmeddelande, fallback)?
- Ser det importerade receptet korrekt ut (ingredienser, mängder, bilder)?

**Teststeg:**
1. Från hemskärm: "Lägg till" → "Importera via URL"
2. Klistra in en URL från ICA eller Arla (t.ex. https://www.ica.se/recept/pannkakor-723804/)
3. Tryck "Importera" eller "Analysera"
4. Observera:
   - Laddningsindikator/progress?
   - Hur lång tid tar det?
   - Felmeddelanden vid misslyckande?
5. När receptet laddats:
   - Kontrollera att titel, ingredienser, mängder stämmer
   - Kontrollera att bild laddats ned
6. Spara receptet
7. Verifiera i receptlistan

**Fallback-test:**
- Klistra in en ogiltig URL → Förväntat: Tydligt felmeddelande
- Klistra in URL från en icke-supportad sajt → Förväntat: AI-fallback eller felmeddelande

---

### 4. Menyplanering (AI-generering) [MEDELHÖGT]

**Flöde:**
- Öppna Veckomeny → Skriv svensk prompt ("3 middagar") → Generera → Spara meny

**Varför:**
- Unikt värde med svensk AI-integration

**UI-fokus:**
- Hur lång tid tar AI-genereringen (progressindikator)?
- Är de föreslagna recepten relevanta och logiskt ordnade?
- Kan du regenerera enskilda sektioner?

**Teststeg:**
1. Navigera till "Veckomeny" (via navigationsmeny)
2. Om det finns en "Skapa ny meny"-knapp, klicka på den
3. Skriv en svensk prompt: "3 middagar, 2 luncher och 1 frukost"
4. Tryck "Generera" eller liknande
5. Observera:
   - Laddningsindikator/progress?
   - Hur lång tid tar det?
6. När menyn genererats:
   - Kontrollera att antalet måltider stämmer (3 middagar, 2 luncher, 1 frukost)
   - Är recepten logiskt ordnade (frukost först, sedan luncher, sedan middagar)?
   - Är recepten från din egen receptsamling?
7. Testa att regenerera en sektion (t.ex. "Generera om middagar")
8. Spara menyn med ett namn (t.ex. "Vecka 47")
9. Gå tillbaka och verifiera att menyn finns sparad

---

### 5. Inköpslista (personlig + samarbete) [MEDELHÖGT]

**Flöde:**
- Skapa lista → Lägg till objekt manuellt → Lägg till från recept → Markera som köpt → Dela med vän (om möjligt)

**Varför:**
- Daglig användning, realtidssynk är kritiskt

**UI-fokus:**
- Uppdateras "köpt"-status direkt utan fördröjning?
- Fungerar svenska enhetsbeteckningar (liter→l, styck→st)?
- Vid delning: Syns ändringar i realtid för båda användarna?

**Teststeg:**
1. Navigera till "Inköpslista" (via navigationsmeny)
2. Skapa en ny lista (om knappen finns) med namn "Testlista"
3. Lägg till manuellt:
   - "2 liter mjölk"
   - "5 st ägg"
   - "1 kg mjöl"
4. Observera:
   - Visas objekten direkt i listan?
   - Formateras enheterna korrekt (liter→l, styck→st)?
5. Markera "2 liter mjölk" som köpt (checkbox/toggle)
6. Observera:
   - Uppdateras status direkt?
   - Visuell feedback (genomstruken text, färgändring)?
7. Lägg till ingredienser från ett recept:
   - Öppna ett recept → "Lägg till i inköpslista"
   - Välj portioner (t.ex. 4 portioner)
   - Verifiera att ingredienserna hamnar i listan med korrekta mängder
8. (Valfritt) Testa delning med en vän:
   - Klicka "Dela lista" eller liknande
   - Välj en vän från listan
   - Låt vännen öppna listan på sin enhet
   - Du markerar ett objekt som köpt → Vännen bör se uppdateringen direkt
   - Vännen lägger till ett nytt objekt → Du bör se det direkt

---

### 6. Social funktionalitet (vänner, delning) [MEDELLÅGT]

**Flöde:**
- Sök vän → Skicka vänförfrågan → Acceptera → Dela recept → Kommentera/Betygsätt

**Varför:**
- Viktigt för engagemang, men beroende av att flera användare finns

**UI-fokus:**
- Visas vänförfrågningar tydligt med notiser?
- Hur ser delningsmiljön ut (välj vänner/grupper)?
- Uppdateras aktivitetsflödet i realtid?

**Teststeg:**
1. Navigera till "Vänner" eller "Upptäck" (Discovery)
2. Sök efter en användare (kräver att du har en annan testanvändare)
3. Skicka vänförfrågan
4. Observera:
   - Bekräftelsemeddelande?
   - Var visas förfrågan för mottagaren?
5. Logga in som mottagaren (eller be någon acceptera)
6. Acceptera vänförfrågan
7. Dela ett recept:
   - Öppna ett recept → "Dela"
   - Välj vännen från listan
   - Skicka
8. Observera:
   - Får vännen en notis?
   - Syns receptet under "Delat med mig"?
9. Kommentera receptet:
   - Öppna det delade receptet
   - Skriv en kommentar: "Testkommentar"
   - Skicka
10. Verifiera att kommentaren visas direkt
11. Betygsätt receptet (0-5 stjärnor)
12. Verifiera att betyget visas/uppdateras

---

### 7. Offline-läge [MEDELLÅGT]

**Flöde:**
- Koppla bort nätverk → Visa recept → Skapa/redigera → Koppla på nätverk igen → Verifiera synk

**Varför:**
- Kritisk för användarupplevelse i köket (dåligt WiFi)

**UI-fokus:**
- Finns visuell indikator för offline-läge?
- Fungerar receptvisning och grundläggande funktioner offline?
- Synkas ändringar smidigt när du kommer online?

**Teststeg:**
1. Med aktiv internetanslutning: Öppna receptlistan
2. Öppna ett befintligt recept för att cacha det
3. Stäng av WiFi/mobilt nätverk på enheten
4. Observera:
   - Visas en offline-indikator i UI:t?
   - Banner/ikon/text som säger "Offline"?
5. Navigera i appen:
   - Öppna receptet du precis tittade på
   - Förväntat: Receptet visas korrekt (cachad data)
6. Försök skapa ett nytt recept:
   - Fyll i uppgifter
   - Spara
   - Observera: Sparas receptet lokalt? Felmeddelande?
7. Redigera ett befintligt recept:
   - Ändra titeln
   - Spara
8. Aktivera internetanslutning igen
9. Observera:
   - Försvinner offline-indikatorn?
   - Synkas ändringarna automatiskt?
10. Verifiera på en annan enhet (om möjligt) att ändringarna synkats

---

## Feltyper att vara uppmärksam på

### A) Logik- och datafel
- **Symptom:** Felaktig datahantering (portioner skalas inte korrekt, ingredienser saknas efter import)
- **Symptom:** Tillståndshantering (ViewModels laddar inte data eller uppdaterar inte UI vid ändringar)
- **Symptom:** Null-pointer-fel (crashes när data saknas, särskilt vid offline/async-operationer)
- **Symptom:** Firebase-regler (behörighetsproblem vid delning/samarbete)
- **Vad du ska titta efter:** Felaktiga värden, saknad data, oväntade crashes

### B) Navigation och routing
- **Symptom:** Hamnar på fel skärm efter inloggning/skapande/redigering
- **Symptom:** "Tillbaka"-knappen leder till oväntad vy
- **Symptom:** Deep links fungerar inte (t.ex. vid mottagande av delning)
- **Symptom:** Navigation stack läcker minne (för många vyer på stacken)
- **Vad du ska titta efter:** Oväntat beteende vid navigation, "Tillbaka"-knapp som inte fungerar logiskt

### C) State-hantering (särskilt i realtidsfunktioner)
- **Symptom:** Ändringar från andra användare syns inte eller fördröjt
- **Symptom:** Optimistiska uppdateringar (t.ex. "köpt"-toggle) rullas tillbaka eller dupliceras
- **Symptom:** Konfliktlösning misslyckas (två användare redigerar samma recept samtidigt)
- **Symptom:** Loading states hänger sig i "laddar..." utan felmeddelande
- **Vad du ska titta efter:** Fördröjda uppdateringar, duplikat, eviga laddningsindikatorer

### D) UX/visuella buggar
- **Symptom:** Bilder laddas inte eller visas i fel storlek/proportion
- **Symptom:** Text skärs av eller flyter utanför skärmen (responsivitet)
- **Symptom:** Knappar/fält är osynliga eller har dålig kontrast
- **Symptom:** Loading-spinners försvinner inte efter lyckad operation
- **Symptom:** Felmeddelanden är otydliga eller på engelska (ska vara svenska)
- **Vad du ska titta efter:** Layoutproblem, klippt text, dålig kontrast, engelska texter

### E) API- och nätverksfel
- **Symptom:** Långsam/timeout vid import från externa sajter
- **Symptom:** Firebase-kvotagränser (t.ex. för bilduppladdning)
- **Symptom:** Retrylogik fungerar inte vid nätverksavbrott
- **Symptom:** Generiska felmeddelanden ("Okänt fel") istället för specifika
- **Vad du ska titta efter:** Timeouts, otydliga felmeddelanden, långsamma operationer

### F) GDPR/säkerhet
- **Symptom:** Samtyckesinställningar sparas inte
- **Symptom:** Dataexport genererar ofullständiga filer
- **Symptom:** Kontoborttagning lämnar kvar data
- **Symptom:** Obehöriga användare kan se/redigera delat innehåll
- **Vad du ska titta efter:** Inställningar som inte sparas, åtkomst som inte borde finnas

---

## Kända kodproblem (från flutter analyze 2025-11-22)

**Status:** 9 fel hittade (alla "not_enough_positional_arguments")

**Berörda filer:**
1. `lib/widgets/common/friends/friend_category_widgets.dart` (4 fel)
2. `lib/widgets/common/social/social_invitation_api.dart` (4 fel)
3. `test/widget/common/social_components_ultrathink_test.dart` (1 fel)

**Potentiell påverkan:**
- Vänfunktionalitet (kategorisering, väljare)
- Social delning (inbjudningar, målval)
- Kan orsaka runtime-crashes eller kompileringsfel

**Prioritet:** HÖG (bör åtgärdas innan omfattande manuell testning av social funktionalitet)

---

## Debug-metodik

### Hypotesdriven felsökning

1. **Formulera hypotes** baserat på förväntad funktionalitet
   - Exempel: "När jag skapar ett recept bör det visas i receptlistan direkt efter sparande"

2. **Testa i UI**
   - Följ teststegen ovan
   - Notera exakt vad du ser

3. **Jämför med förväntning**
   - Stämmer beteendet med hypotesen?
   - Om nej: Vad skiljer sig?

4. **Koppla till kod**
   - Identifiera vilket ViewModel/Service som hanterar flödet
   - Granska terminalloggar för fel
   - Läs relevant kod för att förstå root cause

5. **Föreslå lösning**
   - Patch kod
   - Verifiera med nytt test

### Informationsbehov vid varje test

När du testar, beskriv alltid:

**Vad du ser:**
- Skärmnamn/titel
- Knappar och deras texter
- Formulär och fält
- Meddelanden (fel, bekräftelser)
- Loading states (spinner, progress bar)

**Vad du gör:**
- Exakta steg du följer
- Vad du klickar på
- Vad du skriver in

**Vad som händer:**
- Direkt respons (navigation, meddelande)
- Fördröjningar (hur lång tid?)
- Oväntat beteende
- Crashes eller felmeddelanden

**Vad som känns konstigt:**
- Layout-problem
- Icke-intuitiv navigation
- Otydliga instruktioner
- Långsamma operationer

---

## Nästa steg

1. **Åtgärda kända kodfel** (9 st från flutter analyze)
2. **Starta appen** och verifiera initial vy
3. **Arbeta igenom testflödena** i prioritetsordning
4. **Dokumentera buggar** med hypotes + observation
5. **Patcha kod** och verifiera fix

---

**Slutsats:** Butlery är en omfattande app med kraftfull funktionalitet. Genom systematisk testning av de 7 huvudflödena ovan kan vi identifiera och åtgärda både kritiska och kosmetiska buggar. Fokus ligger på användarupplevelse (UX), state-hantering i realtidsfunktioner och navigation.
