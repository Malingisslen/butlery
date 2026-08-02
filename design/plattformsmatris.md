# Butlery · Plattformsmatris

Vad som skiljer Android och iOS, och vad som är samma. Version **1.0** · 2026-07-26.
Normativ för **plattformsbeteende**. Referensplattform är Android (Pixel 9a); iOS får aldrig sämre tillgänglighet, bara annat systemidiom.

---

## 1 · Behörigheter

| Behörighet | Android | iOS | Butlerys regel |
|---|---|---|---|
| **Kamera** | `CAMERA` · kan nekas permanent | `NSCameraUsageDescription` · andra frågan finns inte | Förklara i egen vy **före** systemdialogen. Utan behörighet: välj ur galleriet |
| **Foton** | `READ_MEDIA_IMAGES` (13+) · *Välj foton* ger partiell åtkomst | Begränsad åtkomst är standard sedan iOS 14 | **Partiell åtkomst är ett förstklassigt läge**, inte ett fel. ”Välj fler bilder” visas i väljaren, aldrig som varning |
| **Notiser** | Runtime-fråga sedan Android 13 | Alltid runtime-fråga | Frågas först när användaren startar en timer eller delar något — aldrig vid start. Utan notiser: timers syns bara i appen, och det sägs innan timern startas |
| **Exakta larm** | `SCHEDULE_EXACT_ALARM` behövs för matlagningstimer | ingen motsvarighet | Android: förklara varför innan systemsidan öppnas. iOS: lokal notis räcker |
| **Kontakter** | `READ_CONTACTS` | `NSContactsUsageDescription` | Aldrig obligatorisk. Vänner hittas med kod eller länk i första hand |
| **Spärrad av MDM** | förekommer i företagsprofiler | förekommer via konfigurationsprofil | Eget läge: förklara att enheten spärrat, ingen knapp |

Fyra behörighetslägen gäller på båda plattformarna: *ej frågad · nekad · permanent nekad · spärrad*. Se `produktregler.md` § 5.

## 2 · Navigation och gester

| Beteende | Android | iOS | Butlerys regel |
|---|---|---|---|
| **Bakåt** | systemgest eller knapp, kan lämna appen | svepgest från vänsterkant | Varje vy har en **synlig** bakåtväg. Systemgesten är alltid ett komplement, aldrig enda vägen |
| **Bakåt med osparat** | måste fångas | måste fångas | Samma dialog på båda: Spara och lämna · Fortsätt redigera · Lämna utan att spara |
| **Bakåt i ark** | stänger arket, inte vyn | svep ned stänger arket | Samma: ett lager i taget |
| **Toppfält** | ett gemensamt fält | ett gemensamt fält — `AdaptiveAppBar` avvecklas | **Avgjort (B-45)**: samma fält på båda plattformarna, iOS-gesterna behålls. K-09 stängd 2026-07-30. Avvecklingen rör 39 migrerade vyer och är kod, inte ritning |
| **Långtryck** | etablerat för flerval | mindre etablerat, `contextMenu` är idiomet | Flerval måste ha en **synlig** ingång på båda plattformarna. Långtryck är genväg, aldrig enda vägen |
| **Haptik** | `HapticFeedback` | Taptic Engine | Endast vid destruktiv bekräftelse och timerslut. Aldrig vid navigering |

## 3 · Text, tangentbord och inmatning

| Beteende | Android | iOS | Butlerys regel |
|---|---|---|---|
| **Systemtextstorlek** | upp till 2,0× (+ *förstora skärmen*) | Dynamic Type upp till AX5 | Testas i 2,0×. Layout bryter rad — ellips är förbjuden i knappar |
| **Fet systemtext** | *Fet text* i inställningar | *Bold Text* | Butlery Sans 600 ersätter 400; syntetisk fet är förbjuden |
| **Tangentbordshöjd** | varierar med IME | varierar med språk och emoji-rad | Åtgärdsraden flyttas ovanför tangentbordet. Mät aldrig med ett antaget värde |
| **Automatisk stor bokstav** | IME-styrd | systemstyrd | Av i mängdfält och koder, på i namn och fritext |
| **Numeriskt tangentbord** | `inputType=number` | `keyboardType: .numberPad` | Mängd, portioner, OTP. Decimalkomma, inte punkt — svensk konvention |
| **Autofyll** | Autofill Framework | Password AutoFill | Stöds för e-post, lösenord och OTP. OTP läses som **ett** fält av skärmläsaren |

## 4 · Tillgänglighet

| Beteende | Android | iOS | Butlerys regel |
|---|---|---|---|
| **Skärmläsare** | TalkBack | VoiceOver | Roll, namn och tillstånd på varje kontroll. Verifieras separat på båda |
| **Träffyta** | 48 dp | 44 pt | **48 dp gäller överallt.** Det uppfyller iOS automatiskt; det omvända gäller inte |
| **Reducerad rörelse** | `disableAnimations` | `UIAccessibility.isReduceMotionEnabled` | Ingen förflyttning; slutläget visas direkt |
| **Fokusram** | tangentbord och switch access | tangentbord och Full Keyboard Access | 2 px, 3 px offset, runt hitboxen |
| **Kontrast** | Accessibility Scanner | Accessibility Inspector | Samma golv på båda: 4,5:1 liten text, 3:1 stor text och grafik |

## 5 · Länkar och delning

| Beteende | Android | iOS | Butlerys regel |
|---|---|---|---|
| **Djuplänkar** | App Links (verifierad `assetlinks.json`) | Universal Links (`apple-app-site-association`) | Samma URL-struktur. Utloggad → inloggning → tillbaka till länkens mål |
| **Delning in** | `ACTION_SEND` | Share Extension | Delat innehåll landar i importflödet, aldrig i en tom vy |
| **Delning ut** | `Intent.createChooser` | `UIActivityViewController` | Systemets eget ark. Butlery ritar aldrig eget delningsark för systemmål |
| **Utklipp** | notifieras vid läsning (13+) | klistra-in kräver tillstånd (16+) | Läs aldrig utklipp automatiskt. ”Klistra in” är alltid en knapp användaren trycker |

## 6 · Systemytor

| Yta | Android | iOS | Butlerys regel |
|---|---|---|---|
| **Statusrad** | ljust/mörkt innehåll sätts av appen | samma | Följer aktuell yta, inte varumärket |
| **Navigationsfält / hemindikator** | 3 knappar eller gest | hemindikator | Innehåll slutar ovanför båda. Safe area är aldrig valfri |
| **Notch och hål** | varierar | Dynamic Island | Ingen text eller kontroll inom safe area-insetet |
| **Delad skärm** | vanligt | Slide Over på iPad | Ned till 320 dp bredd fungerar; under det visas en förklaring |
| **Appikon** | adaptiv, 108 dp med säker zon | 1024 px, ingen genomskinlighet | Levererade, se `assets-manifest.json` |
| **Widgets** | ej i scope | ej i scope | — |

## 7 · Det som är exakt samma

Färg, typografi, rum, radie, rörelsekurvor, ikonfamilj, copy, tillståndslogik, allergiregler, konfliktstrategier, offlinekö och träffytegolv. **Butlery ser ut som Butlery på båda plattformarna.** Skillnaderna ovan handlar om hur systemet fungerar, aldrig om hur Butlery ser ut.

---

## Öppet

| Fråga | Var den avgörs |
|---|---|
| Flervalets ingång — ritningen | **Avgjord (B-46)**: ”Välj” i toppfältet, långtryck kvar som genväg. Kvar: rita ingången på de sex ytorna |
| Safe area-bevis i ritning | `evidensmatris.md` R-08 |
