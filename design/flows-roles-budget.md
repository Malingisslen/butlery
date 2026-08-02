# Butlery · Flöden, roller och tillstånd

Normativ för hur man **når** varje tillstånd. Skärmfilen visar hur de ser ut; den här filen visar vägen dit.
Version **1.1** · 2026-07-26.

---

## Tillståndsmodell

Tillståndsmaskinen är gemensam; **vilka tillstånd en enskild vy måste ha är det inte.** En dialog har inget `empty`, en läsvy har ingen `conflict`. Den normativa listan per vy står i `testmatris.md` § 1 — den här filen beskriver övergångarna, inte kravet.

`idle → loading → success | empty | error | offline | conflict`

- **loading** — synlig progress med text som säger vad som görs. Skelett bara där formen är känd.
- **empty** — beskriver läget, inte problemet. Illustration tillåten.
- **error** — vad hände · vad bevarades · vad du kan göra. Aldrig illustration.
- **offline** — banner, inte dialog. Läsning fungerar ur cache, skrivning köas.
- **conflict** — det finns ingen generisk konfliktregel. Strategin är **per entitet** och står i `produktregler.md` § 2. Gemensamt gäller bara: användaren får alltid veta att en konflikt inträffat, och ingen strategi får tyst kasta data som bara finns lokalt.

---

## 01 · Veckomeny — generera

| Från | Händelse | Till | Skärm |
|---|---|---|---|
| `tom vecka` | Generera | `genererar` | `#veckogenererar` |
| `vecka med rätter` | Generera | `bekräfta överskrivning` **före beräkningen startar** | `#veckoskrivover` |
| `genererar` | > 10 s | `lång väntan` | `#veckogenererar` |
| `lång väntan` | Fortsätt i bakgrunden | `bakgrund` + notis vid klar | — |
| `genererar` | alla dagar klara | `resultat` | `#veckokalender` |
| `genererar` | 1 ≤ n < begärt antal **recept** placerade | `partiellt` | `#veckoresultat` |
| `genererar` | 0 recept placerade | `inga matchningar` | `#veckofel` |
| `genererar` | 6–10 s | **samma vy**, stegtexten byts till ”Det tar längre tid än vanligt” | `#veckogenererar` |
| `genererar` | offline | `avbrutet` + banner, tidigare vecka orörd | — |
| `resultat` | Ångra (snackbar, **30 s**) | föregående vecka återställd | — |
| `resultat` | efter 30 s | överskriven version nås i **Återställ** i 30 dagar | — |

Avbryt lämnar vyn men behåller det lokala utkastet med redan placerade recept; endast ”Släng utkastet” raderar det. Inget skrivs till den sparade veckan förrän användaren sparar. Delresultat mäts i **recept**, aldrig i dagar — veckan har 21 platser (`produktregler.md` § 4).

## 02 · Veckomeny → inköpslista

| Från | Händelse | Till |
|---|---|---|
| `veckomeny` | Till inköpslistan | `merge-ark` (`#inkopmerge`) |
| `merge-ark` | Lägg till N varor | `inköp` + snackbar med Ångra |
| `merge-ark` | Ersätt listan (på) | egna manuella varor behålls, receptskapade rader ersätts |
| `lägga till` | listan ändrad av annan person samtidigt | `conflict`: dina rader läggs till, inget skrivs över |

Merge-ordning: dubbletter slås samman → enheter konverteras inom samma varutyp → skafferivaror dras bort (delvis täckta läggs till med differensen).

## 03 · Receptimport

| Från | Händelse | Till |
|---|---|---|
| `länkfält` | Importera | `hämtar` |
| `hämtar` | ok | `granska före sparande` |
| `hämtar` | privat / trasig länk | `error`: "Länken kunde inte läsas" + Klistra in texten själv |
| `hämtar` | betalvägg | `error`: "Sidan kräver inloggning" + Klistra in texten själv |
| `hämtar` | sidan har inget recept | `error`: "Vi hittade inget recept på sidan" + Skriv själv |
| `granska` | fält med låg säkerhet | markeras och kräver bekräftelse innan Spara |
| `granska` | receptet finns redan | `dubblett`: Öppna befintligt · Spara som nytt |
| `foto/OCR` | otolkad text | `granska` med raden tom och markerad — aldrig gissad text |

## 04 · Matlagningsläge

| Från | Händelse | Till |
|---|---|---|
| `receptdetalj` | Börja laga | `steg 1`, skärmen hålls vaken |
| `steg n` | timer startad | timer i systemnotis; flera timers tillåtna, namngivna efter steget |
| `steg n` | app i bakgrunden | timers fortsätter; notisbehörighet saknas → varning **innan** timern startas |
| `steg n` | bakåt / stäng | `bekräfta avslut` om mer än ett steg är klart |
| `avslutat` | Klart | `receptdetalj` + "Lagat N gånger" uppräknad |
| `steg n` | rotation | layout byter, steg och timer bevaras |

## 05 · Delning och samarbete

| Från | Händelse | Till |
|---|---|---|
| `deep link` | utloggad | `inloggning` → tillbaka till länkens mål |
| `deep link` | länken återkallad eller utgången | `error`: "Länken gäller inte längre" + Begär ny |
| `deep link` | redan medlem | direkt till objektet, ingen mellanvy |
| `grupp` | ägaren lämnar | ägarskap måste överlåtas först — annars blockeras handlingen |
| `medlem` | behörighet sänks till endast läsa | öppna redigeringsvyer stängs med förklaring, osparat erbjuds som kopia |
| `person` | blockerad | delningar döljs åt båda håll, historik behålls |

## 06 · Konto

`skapa konto → verifiera e-post → klart` · verifieringslänk utgången → `begär ny` · glömt lösenord → `återställ` → `sätt nytt` · byt e-post kräver omverifiering av båda adresserna · MFA-återställning via engångskoder · sessionsutgång → `logga in igen` med returväg · radera konto → `bekräfta med lösenord` → 30 dagars återkallningsfönster → permanent.

## 07 · Behörigheter (kamera, foto, notiser)

| Läge | Beteende |
|---|---|
| **first ask** | Förklara nyttan i egen vy **före** systemdialogen |
| **nekad** | Funktionen finns kvar, visar vad den kunde gjort + **Fråga igen** |
| **permanent nekad** | Samma vy, men knappen är **Öppna inställningar** |
| **spärrad av systemet / MDM** | Förklara att enheten spärrat funktionen. Ingen knapp — det finns inget användaren kan göra |
| **utan behörighet** | Kamera → välj ur galleri · Galleri → skriv själv · Notiser → timers syns bara i appen (sägs explicit) |

## 08 · Offline och synk

Cachas: alla egna recept, veckomeny, inköpslista, skafferi, senaste 30 dagars chattar.
Köindikator i toppfältet när något väntar. Stale data märks med tidsstämpel, inte med grå text.
Konfliktpolicy per entitet och offlinekönens regler (idempotens, ordning, beroenden, omförsök, permanent fel, användarens kövy) är normativa i `produktregler.md` §§ 2–3 — den här filen upprepar dem inte.
Lagringsutrymme slut → varning innan nedladdning startar, aldrig efter.

---

## Roll- och behörighetsmatris

| Handling | Ägare | Medlem | Gäst (delad länk) | Endast läsa | Admin |
|---|---|---|---|---|---|
| Se recept | ✔ | ✔ | ✔ | ✔ | ✔ (moderering) |
| Redigera recept | ✔ | ✔ (egna) | — | — | — |
| Radera recept | ✔ | ✔ (egna) | — | — | ✔ (moderering, loggas) |
| Planera veckan | ✔ | ✔ | — | — | — |
| Ändra inköpslista | ✔ | ✔ | ✔ (bocka av) | — | — |
| Bjuda in medlemmar | ✔ | — | — | — | — |
| Ändra behörigheter | ✔ | — | — | — | — |
| Ändra allergener | ✔ | ✔ (egna) | — | — | — |
| Radera hushållet | ✔ | — | — | — | — |
| Se admin-data | — | — | — | — | ✔ |

Gäst når bara det som länken pekar på. Behörighetssänkning tar effekt direkt i öppna vyer.
**Roll och länkbehörighet är två olika saker.** Rollen (ägare/medlem/gäst/admin) styr vad personen får göra i hushållet; länkbehörigheten (`läsa` eller `läsa + bocka`) styr vad en delad länk tillåter. En gäst med en `läsa + bocka`-länk får bocka varor i just den listan och ingenting annat — det gör hen inte till medlem. Se `produktregler.md` § 5.
Admin ser aldrig privat receptinnehåll utom det som är rapporterat, och varje åtgärd loggas i audit-loggen.

---

## Prestandabudget

| Mått | Budget | Mäts |
|---|---|---|
| Kall start till första ritning | ≤ 1,5 s | referensenhet Pixel 9a |
| Startanimation | **400 ms lyft → navigering. Ingen loop i produkten** (beslut B-20; 5 s-loopen finns bara i rörelsedemon) | |
| Vy till interaktiv | ≤ 400 ms från navigering | |
| Receptbild, komprimerad | ≤ 250 kB, långsida ≤ 1600 px | |
| Ikon- och brandassets totalt | ≤ 120 kB | |
| Fontpaket (6 stilar, WOFF2) | ≤ 420 kB, Regular + Semibold laddas först | |
| Offline-cache per hushåll | ≤ 80 MB, äldsta bilder rensas först | |
| Listscroll | inga tappade ramar vid 120 Hz i 200 rader | |
| Menygenerering | mål ≤ 6 s · 6–10 s samma vy med ändrad stegtext · > 10 s `#veckogenererar` | |

## Analytics- och samtyckesplan

Mäts (händelser utan innehåll):
`app_open` · `recipe_saved{källa: import|foto|manuell}` · `week_generated{utfall: full|partiell|noll}` · `week_saved` · `shopping_list_created{källa}` · `item_checked` · `cooking_started` · `cooking_completed{steg_klara}` · `share_created{typ}` · `share_opened` · `permission_result{typ, utfall}` · `error_shown{flöde, kategori}` · `offline_queue_flushed`.

Aldrig: receptnamn, ingredienser, allergener, chattinnehåll, personnamn, bilder, fritext.
Allergener är hälsouppgifter. De lagras krypterat och skickas till servern endast för hushållssynk och menygenerering, där de behandlas som transient indata och inte loggas — aldrig för analys, rekommendationer utanför hushållet eller tredjepart (`produktregler.md` § 5).
Analys kräver aktivt samtycke i onboarding, kan stängas av under Mer → Samtycken, och avstängning tar effekt direkt utan omstart. Krascher rapporteras utan innehåll och kan väljas separat.
