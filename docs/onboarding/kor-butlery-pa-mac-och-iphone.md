# Komma igång med Butlery på din Mac och iPhone

Den här guiden tar dig hela vägen från en helt ny Mac till att appen Butlery kör på din egen iPhone. Du behöver inte kunna programmera. Följ stegen i ordning, uppifrån och ner. De två steg man oftast fastnar på är **inloggningen i Xcode** (steg 3) och att **de hemliga konfigurationsfilerna** finns på plats (steg 2d) — ta det lugnt på dem.

Räkna med 1-2 timmar första gången, mest väntan medan saker laddar ner.

> **Två saker om dig som du behöver veta innan du börjar:**
> 1. Du måste ha ett **Apple-ID** (samma som du använder för App Store). Ett gratis Apple-ID räcker.
> 2. Din iPhone måste köra **iOS 17 eller nyare**. Mer om detta i steg 4.

---

## Snabb checklista (det här ska du göra)

1. Installera verktyg på Macen (Xcode, Flutter, CocoaPods)
2. Hämta koden och förbered den
3. Öppna projektet i Xcode och logga in med ditt Apple-ID
4. Kontrollera att iPhonen kör iOS 17+
5. (Valfritt — kan hoppas över) App Check-token i Firebase
6. Kör appen — först i en simulator, sedan på din riktiga iPhone
7. Testa: skapa konto, gör onboarding, importera ett recept
8. Felsökning om något strular

---

## 1. Installera verktygen på Macen

En helt ny Mac har inget av detta. Vi installerar fyra saker: **Xcode**, **Flutter**, **Homebrew** och **CocoaPods**. Vissa steg tar lång tid (Xcode är flera gigabyte) — det är normalt.

Vi kommer att skriva kommandon i ett program som heter **Terminal**. Du hittar det så här: tryck `Cmd + mellanslag`, skriv `Terminal`, tryck Enter. Ett fönster med text öppnas. Där klistrar du in kommandona nedan, ett i taget, och trycker Enter efter varje.

### 1a. Xcode (Apples utvecklingsprogram)

1. Öppna **App Store** på Macen.
2. Sök efter **Xcode**.
3. Klicka **Hämta** / **Installera**. Det här är en stor nedladdning (flera GB) och kan ta en bra stund. Låt den bli klar.
4. När den är klar, **öppna Xcode en gång** (klicka på ikonen). Den ber dig godkänna ett licensavtal — klicka **Agree**. Den kan också installera lite extra komponenter; låt den göra det och vänta tills den är klar. Sedan kan du stänga Xcode.

Installera sedan Xcodes så kallade "command line tools". Klistra in i Terminal och tryck Enter:

```
xcode-select --install
```

En ruta dyker upp som frågar om du vill installera. Klicka **Install** och vänta tills den är klar.

### 1b. Homebrew (en hjälpinstallerare)

Homebrew gör det enkelt att installera CocoaPods på ett tillförlitligt sätt. Klistra in i Terminal:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Den frågar efter ditt **Mac-lösenord** (samma som du loggar in på datorn med) — skriv det och tryck Enter. Du ser inga tecken medan du skriver lösenordet, det är meningen. Mot slutet kan den skriva ut två rader som börjar med `echo` och ber dig köra dem för att "lägga till Homebrew i din PATH". Om den gör det, kopiera och kör de raderna precis som de står. Annars hoppa vidare.

### 1c. Flutter (det som bygger appen)

Flutter är ramverket som Butlery är byggd med. Följ Flutters officiella installationsguide för macOS, den är tydlig och uppdaterad:

**https://docs.flutter.dev/get-started/install/macos**

Välj **iOS** som mål när guiden frågar. Du laddar ner Flutter, packar upp det och lägger till det i din "PATH" (så att kommandot `flutter` fungerar i Terminal). Guiden visar exakt hur.

När du tror att Flutter är installerat, kontrollera det genom att klistra in i Terminal:

```
flutter doctor
```

Det här kör en självdiagnos. Du vill se gröna bockar för **Flutter** och **Xcode**. Om något har ett rött kryss eller ett utropstecken, skriver `flutter doctor` oftast ut exakt vad du ska göra — följ den instruktionen och kör `flutter doctor` igen tills det ser bra ut. Det är vanligt att den ber dig köra ett kommando om Xcode-licens; gör det den säger.

### 1d. CocoaPods (hanterar iOS-bibliotek)

CocoaPods hämtar de iOS-byggblock som appen behöver. På nyare Mac-datorer (Apple Silicon, dvs. M1/M2/M3/M4) är det mest tillförlitligt att installera CocoaPods via Homebrew. Klistra in i Terminal:

```
brew install cocoapods
```

När det är klart, kör `flutter doctor` en sista gång. Både **Xcode** och **CocoaPods** ska nu visa grönt.

---

## 2. Hämta koden och förbered den

Nu hämtar vi själva Butlery-koden och förbereder den.

> Om koden redan finns på Macen (t.ex. i en mapp som heter `butlery`), hoppa över hämtningsdelen och gå direkt till `flutter pub get` nedan.

### 2a. Hämta koden

Om du behöver hämta den, fråga Malin var koden ligger (GitHub-länken). När du har den, klistra in i Terminal — byt ut `<repo-länken>` mot den riktiga länken:

```
git clone <repo-länken>
```

Det skapar en mapp med projektet. Gå in i den (oftast heter den `butlery`):

```
cd butlery
```

Härifrån och framåt antar guiden att du står i projektmappen i Terminal.

### 2b. Förbered Flutter-delarna

Klistra in:

```
flutter pub get
```

Det här hämtar appens byggblock. Vänta tills det blir klart.

### 2c. Förbered iOS-delarna

```
cd ios
pod install
cd ..
```

> **Bra att veta:** Det här projektet saknar i nuläget en låst lista över exakta iOS-biblioteksversioner (en fil som heter `Podfile.lock`). Det betyder att `pod install` hämtar de senaste passande versionerna och **skapar den filen lokalt åt dig** första gången. Det är helt normalt och inget du behöver oroa dig för. (Tar ett par minuter.)

Det här steget gör Flutter faktiskt automatiskt åt dig när du senare kör appen — men det är bra att köra det själv en gång nu så att eventuella problem dyker upp tidigt.

### 2d. Hemliga konfigurationsfiler (fråga Malin!)

Appen behöver några **hemliga filer** som av säkerhetsskäl inte ligger i koden:

- `GoogleService-Info.plist` (ska ligga i `ios/Runner/`)
- `google-services.json` (ska ligga i `android/app/`)
- `.env` (ska ligga i projektets rotmapp)

Be Malin skicka dessa till dig och lägg dem på de platser som anges ovan. Utan `.env`-filen kraschar appen vid start. När du senare kör appen ska du använda kommandot med `--dart-define-from-file=.env` (det står i körkommandona längre ner) så att appen läser in `.env`-filen.

---

## 3. Öppna projektet i Xcode och logga in med ditt Apple-ID

Det här är det steg som är lättast att fastna på, så ta det lugnt och följ punkterna exakt. Anledningen: projektet har **inget förvalt utvecklarkonto** inställt, så Xcode måste få veta att det är **du** (ditt Apple-ID) som signerar appen. Utan det här steget vägrar appen att byggas till en riktig iPhone.

> **Viktigt:** Öppna filen som heter **`Runner.xcworkspace`** (vit ikon), INTE `Runner.xcodeproj`. Fel fil ger fel som är svåra att förstå.

1. Öppna **Finder**, gå till projektmappen och in i undermappen **`ios`**.
2. Dubbelklicka på **`Runner.xcworkspace`** (den vita ikonen). Xcode öppnas.
3. I Xcodes vänsterkant, klicka högst upp på den blå **`Runner`**-symbolen (projektet).
4. I mitten dyker en lista med "TARGETS" upp. Klicka på **`Runner`** under TARGETS (inte `RunnerTests` — den kan du strunta i).
5. Klicka på fliken **Signing & Capabilities** högst upp.
6. Bocka i **Automatically manage signing** (om den inte redan är ibockad).
7. Klicka på menyn vid **Team** och välj **Add an Account…**.
8. Logga in med **ditt eget Apple-ID** (gratis fungerar). Stäng inloggningsfönstret när det är klart.
9. Tillbaka i **Team**-menyn, välj nu det konto som dök upp — det heter något i stil med **"Ditt Namn (Personal Team)"**.
10. Xcode skapar nu automatiskt ett signeringscertifikat åt dig. Det kan ta några sekunder.

### Om Xcode klagar på att "se.butlery.app" är upptaget

På en **simulator** spelar det här ingen roll alls — hoppa över hela rutan. Det kan bara dyka upp när du bygger till en **riktig iPhone**.

Om du ser ett rött felmeddelande typ **"bundle identifier is not available"** eller liknande, betyder det att appens ID redan är upptaget av Malins utvecklarkonto. Då har du två vägar:

- **Enklast (bara för att se appen köra på din telefon):** I samma **Signing & Capabilities**-vy, ändra fältet **Bundle Identifier** från `se.butlery.app` till något unikt, t.ex. `se.butlery.app.malin` eller `se.butlery.app.<dittnamn>`. Gör detta **bara lokalt** på din Mac — **spara/committa det aldrig** tillbaka till koden.
- **Snyggast (om ni vill behålla samma ID):** Be Malin bjuda in ditt Apple-ID till Butlerys utvecklarteam i Apples utvecklarportal. Då kan du använda `se.butlery.app` som det är.

> **En sak att känna till med gratis Apple-ID:** appar du installerar på din telefon med ett gratiskonto slutar fungera efter **ungefär 7 dagar**. Det är inget fel — du installerar bara om den från Xcode igen när det händer. (Detta gäller bara den riktiga telefonen, inte simulatorn.)

Eventuella **gula varningar** om "Push Notifications" eller "Associated Domains" kan du ignorera — de stoppar inte appen från att köra. Skulle de mot förmodan blockera på ett gratiskonto, klicka på den lilla papperskorgen bredvid respektive "capability" i samma vy för att ta bort dem lokalt.

---

## 4. Kontrollera att iPhonen kör iOS 17 eller nyare

Det här är en **hård gräns**: appen är byggd för iOS 17 och uppåt och vägrar helt enkelt installeras på en iPhone med iOS 16 eller äldre ("requires a newer version of iOS").

Kolla din telefon:

1. Öppna **Inställningar** på iPhonen.
2. Gå till **Allmänt → Om**.
3. Titta på **Programvaruversion** (eller "iOS-version").

- Om det står **17.x**, **18.x** eller högre — perfekt, gå vidare.
- Om det står **16 eller lägre** — uppdatera först: **Inställningar → Allmänt → Programuppdatering**, installera senaste iOS, och starta om telefonen. (Alla iPhones från 2018 och framåt, dvs. iPhone XR/XS eller nyare, kan köra iOS 17.)

> **Försök aldrig sänka appens iOS-krav** — det är en riskabel kodändring. Uppdatera telefonen i stället. Och om din telefon av någon anledning inte kan nå iOS 17, kör appen i Macens **simulator** i stället (steg 6) — den kör iOS 17 utan problem.

---

## 5. (Valfritt) App Check-token i Firebase — du behöver troligen INTE göra detta

**Du kan hoppa över hela det här steget för en testkörning.** Vi kontrollerade Firebase: App Check står i läget **"Unenforced"** (skyddet är påslaget men blockerar ingenting ännu), så data laddas och sparas alldeles utmärkt **utan** någon token. Gå direkt till steg 6.

Det här steget finns kvar enbart som referens, om ni längre fram väljer att slå på App Check-skyddet ("Enforce") i Firebase. **Just nu behövs det inte.** Om appen mot förmodan inte laddar data är det nästan aldrig App Check (se felsökningen i steg 8 — det är oftast `.env`-filen eller nätverket).

<details>
<summary>Om ni någon gång slår på App Check (referens — inte nu)</summary>

1. Kör appen en gång. Leta i loggen (Xcodes nedre panel, eller Terminal om du kör `flutter run`) efter en rad med en **App Check debug token**:

   ```
   App Check debug token: 1a2b3c4d-5e6f-7890-abcd-1234567890ef
   ```

2. Öppna **https://console.firebase.google.com/project/butlery-app-1/appcheck**, gå till **Apps**, klicka på **iOS-appen**, välj **Manage debug tokens**, klicka **Add debug token**, klistra in koden, namnge den och spara.

</details>

---

## 6. Kör appen — först simulator, sedan riktig iPhone

Börja **alltid** med simulatorn först. Den kräver ingen signering, inget Apple-ID och inget bundle-ID-trassel — perfekt för att se att allt fungerar innan du tar in telefonen i bilden.

### 6a. Kör i simulatorn (gör detta först)

Stå i projektmappen i Terminal och klistra in:

```
flutter run --dart-define-from-file=.env
```

Flutter startar automatiskt en iPhone-simulator (ett fönster med en låtsastelefon dyker upp på skärmen), bygger appen och installerar den där. Första bygget tar några minuter — var tålmodig.

När appen är igång i simulatorn, gå vidare till steg 7 (testet). Fungerar det i simulatorn är du redo för den riktiga telefonen.

### 6b. Kör på din riktiga iPhone

1. **Koppla in iPhonen** i Macen med en USB/Lightning- eller USB-C-kabel.
2. På iPhonen dyker frågan **"Lita på den här datorn?"** upp — tryck **Lita på / Trust** och ange din telefonkod.
3. Berätta för Flutter att du vill köra på telefonen. Lista först dina enheter:

   ```
   flutter devices
   ```

   Du ser din iPhone i listan med ett ID. Kör sedan (byt ut `<enhets-id>` mot iPhonens ID från listan):

   ```
   flutter run -d <enhets-id> --dart-define-from-file=.env
   ```

   (Alternativt kan du köra appen direkt från Xcode: välj din iPhone i enhetsmenyn längst upp och tryck på den stora ▶-knappen.)

4. **Första gången** vägrar iPhonen öppna appen och säger att utvecklaren inte är betrodd. Det är förväntat. Fixa så här på telefonen:
   - Öppna **Inställningar → Allmänt → VPN och enhetshantering** (på engelska: **Settings → General → VPN & Device Management**).
   - Under **Developer App** ser du ditt Apple-ID. Tryck på det och välj **Lita på / Trust**.
   - Gå tillbaka och öppna Butlery-appen igen — nu startar den.

> Om telefonvägen krånglar är simulatorn alltid en fungerande reservplan. Du missar inget viktigt genom att testa i simulatorn.

---

## 7. Första testet: skapa konto, onboarding, importera recept

Nu ska vi bevisa att hela kedjan fungerar. Så här ser "det funkar" ut:

### 7a. Skapa ett konto

- Appen öppnar en inloggnings-/registreringsskärm (på svenska).
- Välj att **registrera** ett nytt konto. Fyll i namn, e-post, lösenord (minst 8 tecken), och bocka i åldersrutan och villkorsrutan.
- Tryck på registrera. Appen loggar in dig och går vidare.

> Det finns inga "Logga in med Google/Apple"-knappar — det är meningen (kommer senare). Bara e-post och lösenord.
>
> Du kan få en ruta om att **verifiera din e-post**. Den går att **stänga/hoppa över** — du kan fortsätta utan att klicka på någon mejllänk.

### 7b. Gör onboarding

- Efter registreringen startar en kort guide i flera steg: **ålder → välkommen → allergier → kost → första recept**.
- I ålderssteget: **låt förvalet vara** (det är satt till en trygg ålder). Väljer du en ålder under 15 stoppas du av en åldersgräns (lagkrav) — så rör inte det om du inte behöver.
- Välj eventuella allergier/kostval (eller hoppa över — det går bra).
- När guiden är klar landar du på hemskärmen.

**Så här ser "det funkar" ut:** hemskärmen, menyn och inköpslistan är **inte tomma**. Appen lägger automatiskt in några startrecept plus en exempelvecka med matsedel och inköpslista åt dig. Ser du recept och en vecka med mat — då pratar appen med Firebase korrekt.

> Om allt i stället är tomt eller snurrar utan att ladda: kontrollera att **`.env`-filen** finns och att du startade appen med `--dart-define-from-file=.env` (steg 2d/6), och att Macen har internet. Se felsökningen nedan.

### 7c. Importera ditt första recept

- Gå till receptimport (guiden erbjuder det i sista onboarding-steget, annars finns det via "lägg till recept").
- **Det mest pålitliga första testet:** klistra in en länk till ett recept från en stor svensk sajt, t.ex. **ica.se** eller **koket.se**. De sajterna läses in direkt utan att ens behöva molnet.
- Efter import ska receptet dyka upp bland dina recept med titel, ingredienser och instruktioner.

Får du in receptet — grattis, hela kedjan fungerar: konto, databas, onboarding och import. Du är klar.

---

## 8. Felsökning

Stöter du på något, prova motsvarande fix nedan. Kör berörda kommandon i Terminal från projektmappen.

**Appen är blank / vit / tom, eller data laddas aldrig**
→ Vanligaste orsaken är att appen startades **utan `.env`** eller att filen saknas. Kontrollera att `.env` ligger i projektets rotmapp (steg 2d) och att du startar med `flutter run --dart-define-from-file=.env`. Kolla också att Macen har internet. (App Check är avstängt, så det är *inte* orsaken.)

**Bygget misslyckas (Flutter/Xcode spottar ut byggfel)**
→ Rensa och bygg om från rent läge:

```
flutter clean
flutter pub get
flutter run --dart-define-from-file=.env
```

**`pod install` eller iOS-biblioteken klagar**
→ Uppdatera CocoaPods katalog och installera om:

```
cd ios
pod repo update
pod install
cd ..
```

Kör sedan `flutter run --dart-define-from-file=.env` igen.

**Telefonen vägrar öppna appen ("utvecklaren är inte betrodd")**
→ På iPhonen: **Inställningar → Allmänt → VPN och enhetshantering → [ditt Apple-ID] → Lita på**. (Samma som steg 6b punkt 4.)

**"requires a newer version of iOS" när du installerar till telefonen**
→ Telefonen kör iOS 16 eller äldre. Uppdatera den (**steg 4**) eller använd simulatorn.

**"bundle identifier is not available" i Xcode (bara på riktig telefon)**
→ Ändra **Bundle Identifier** till något unikt som `se.butlery.app.<dittnamn>` lokalt i Xcode (**steg 3**), eller be Malin lägga till dig i utvecklarteamet. Committa aldrig den ändringen.

**Appen kraschar direkt vid start**
→ Kontrollera att **`.env`-filen** finns i projektets rotmapp och att du startar med `--dart-define-from-file=.env`. Saknas filen, fråga Malin (**steg 2d**).

**`flutter doctor` visar rött kryss**
→ Läs vad den skriver — den säger oftast exakt vilket kommando du ska köra. Kör det och kör `flutter doctor` igen.

---

Kör fast du på något som inte står här? Spara felmeddelandet (kopiera texten eller ta en skärmdump) och skicka till Malin — det är mycket lättare att hjälpa till med den exakta texten framför ögonen än med "det funkar inte". Lycka till!