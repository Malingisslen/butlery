# Butlery mockup-kit

Gör HTML-mockuper som ser ut som appens NYA design. Kitet är skrivet för Malin och för
Claude-sessioner som ritar nya funktioner innan de byggs.

| Fil | Vad den är |
|---|---|
| `kit.html` | Alla tokens, typsnitt, ikoner och komponenter, i ljust och mörkt läge, med en kopieringsknapp per komponent. |
| `examples.html` | Facit: Mer, Appinställningar och ett recept i 360 × 800, ljust och mörkt. |
| `designlabb.html` | Reglage för typsnitt, textstorlek, rundning, avstånd, linjer, ikoner (egna, Lucide, Phosphor) och varje färg, samt dra-och-släpp av delar i exempelskärmarna: skärmarna ändras direkt. "Spara och för in i appen" kopierar ändringarna som text som ges till Claude, som för in dem i `tokens.json`. |
| `components.css` | Komponenternas CSS. Ändra en komponent här, inte i sidorna. |

## Så gör du en mockup

1. Kopiera `examples.html` till din egen fil. Behåll allt mellan `BEGIN GENERATED` och
   `END GENERATED`: där ligger typsnittet, färgerna, komponenterna och ikonerna.
2. Behåll en `<div class="phone">` per skärm och byt ut innehållet. Hämta delarna från
   `kit.html` med "Kopiera HTML". Startmallen sist i `kit.html` är en tom skärm.
3. Mörkt läge: `<div class="phone" data-theme="dark">`. Rita alltid båda lägena.
4. Hitta inte på egna färger, mått eller ikoner. Använd `var(--butlery-…)`, klasserna
   `.b-*` och `.t-*` och `<svg class="i"><use href="#i-namn"/></svg>`. Saknas något,
   skriv det i mockupen som en fråga i stället för att rita en egen variant.

## Nya designen i korthet

- **Typsnitt:** ButlerySans överallt. Vikten bär hierarkin: 26/700 sidrubrik, 22/700
  rubrik i tomt läge, 15/600 korttitel, 14/400 brödtext och rader, 12 sekundärtext,
  10,5/700 versaler för överrader.
- **Färger:** papper (`surface-base`) som grund, upphöjd yta (`surface-raised`) för kort
  och band, grönt (`surface-ink`) för undersidans toppfält, bottenmenyn och primärknappen.
  Saffran bara för hjälteknappen (högst en per vy), räknare och markeringar. Rött bara
  för det som raderar.
- **Mått:** skärm 360 × 800, sidmarginal 24 px (20 px under 360 px). Avstånd 4, 8, 12,
  16, 24, 32. Radier: 8 för knappar och fält, 12 för kort och ark, pill för chips och
  statuspiller. Träffytor minst 48 × 48.
- **Toppfält:** huvudflikarna Meny, Inköp och Mer har pappersbakgrund och 26/700-rubrik
  utan bakåtpil. Hem har inget toppfält. Allt under en flik får det gröna toppfältet med
  chevron-left och titel 14/700. Aldrig både X och bakåtpil.
- **Navigering:** grön bottenmeny i båda lägena: Hem, Meny, den runda saffransknappen
  Lägg till, Inköp, Mer. Vald flik har ljus text och en saffranslinje under ordet.
- **Listor:** inställningar och navigering är rader, inte kort. Grön överrad i versaler,
  raderna platt på sidan, en tunn linje mellan raderna. Värdet står i sekundärtext före
  chevronen. Den röda raden (Radera kontot) står sist.
- **Kort:** för innehåll som recept och inköpslistor. Upphöjd yta, 1 px tunn kant,
  radie 12, ingen skugga.
- **Knappar:** 48 hög, 14/600. Primär = grön fylld. Hjälte = saffran. Avbryt =
  textknapp. Upptagen knapp behåller färgen och får tallrikslinjen i underkanten.
- **Fält:** etiketten står ovanför rutan (13/600). Rutan har pappersfyllning och 1 px
  kontrollkant. Fokus är en ring utanför rutan. Fel är 1,5 px röd kant och en felrad med
  ikon.
- **Ark och dialoger:** arket har pappersyta, radie 12 upptill och handtag. Dialogen har
  radie 8, titel 17/600 och text 16/400; den röda knappen säger samma verb som titeln.
  Radera när något upphör, Ta bort när det bara lyfts ur en lista.
- **Tomma lägen och fel:** centrerad ikon, rubrik 22/700, en mening och en knapp.
  Laddning är alltid tallrikslinjen, aldrig en snurra.
- **Ikoner:** Butlerys egna glyfer i `design/assets/icons/`. Inga Material-ikoner.

## Bra förebilder i appen

Mer och alla sidor under den (Mer, omtänkt, #710, #712, #714, #715), inmatningsfälten
(#707, #711, #713) och sökfältet `ButlerySearchBox`. `examples.html` är byggd efter dem.

## Delar som fortfarande har GAMLA designen

Använd inte de här som förebild. Listan kommer från helappsgenomgången 2026-10-10 och
spårplanen för BUT-2366 till BUT-2376. Stryk en rad när dess ärende är mergat.

- **Borttagningsdialoger** ser olika ut i taggar, chatt, konversationer och
  gruppinbjudningar (BUT-2366). Följ dialogen i kitet.
- **Hem och sidmallen:** Hems rubrik, "Lägg till recept" utan tillbakapil, väntande
  radering, egna innehållsbredder och sparknappar på fem sätt (BUT-2368).
- **Fel, tomma lägen och snackbars:** felrutan utan ikon, egna tomlägen i vänner,
  skafferiet och synkkön, egna snackbars i receptet, gruppvyn och matlagningsläget
  (BUT-2371).
- **Knappar:** handpåsatt saffran, grå avbryt-knappar och "LÄGG TILL" i versaler i
  skafferiet, snabbregistrering och anmälningsdialogen (BUT-2367).
- **Avsnittsrubriker** i gruppvyn, statistiken, skafferiet och profilen (BUT-2369).
- **Kort och listrader:** kort i menyerna, inköpslistorna och adminvyerna, vänkort och
  gruppinbjudningskort, papperskorgens rader (BUT-2370).
- **Färg, ikonstorlek och avstånd** i veckomenyns kalender och familjens betygsvyer
  (BUT-2376).
- **Bottenark, märken och chips:** skafferiets och matlagningslägets ark, egna märken i
  adminvyerna, egna chips (BUT-2373).
- **Ord:** vara/artikel/objekt, inköpslista/handlingslista, veckomeny/veckans plan
  (BUT-2372). Kitet använder de rätta orden.
- **Konto & säkerhet och tvåstegsverifiering** väntar på #641.

## När designen ändras

Kitets genererade block skrivs av `tools/mockup_kit.dart` ur samma källor som appens
tema: `design/tokens.json` (via `design/assets/generated/tokens.css`), typsnitten i
`design/assets/fonts/` och glyferna i `design/assets/icons/`. Komponenterna ändras i
`components.css`. Kör sedan från repots rot:

```
dart run tools/mockup_kit.dart
```

CI-jobbet Design system kör `dart run tools/mockup_kit.dart --check` och blir rött när
kitet inte längre stämmer med tokens, ikoner eller `components.css`. Ändras en
komponent i appen ändras `components.css` i samma PR.
