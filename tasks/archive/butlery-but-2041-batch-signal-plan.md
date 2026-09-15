# BUT-2041 — flytta batchsignalen bort från kontrollerna

**Beslut (Malin, 2026-09-07):** kör rekommendationen — en skärmnivå-indikator som bara
beror på `_batchRunning`, och ta bort de två knapp-spinnarna så att det förblir exakt en
signal.

## Problemet i en mening

Signalen sitter på kontroller som är villkorade på att det finns en markering, och både
flikbyte och "Rensa" nollar markeringen mitt i en pågående batch — då försvinner varje
spår av att något körs. Att låsa de två utgångarna är en förbudslista; att flytta signalen
stänger formen.

## Steg

1. **Ny widget** `lib/widgets/common/indicators/batch_activity_bar.dart`
   - Indeterminate `LinearProgressIndicator` i full bredd, dold när `active == false`.
   - Egen `Semantics(liveRegion: true, label: ...)`, precis som `LoadingIndicator` äger sin
     — så att en användare av widgeten inte kan glömma annonseringen.
   - Etikett: `context.l10n.a11yLoading` som default, överskrivbar. Ingen ny ARB-sträng —
     ARB-redigeringar skriver om hela filen och kräver `flutter gen-l10n`, och "Laddar" är
     korrekt för det här.
   - `AnimatedSwitcher`-in/ut som offline-bannern bredvid den, så den inte hoppar in.

2. **`friend_requests_view.dart`** — lägg baren i `Column`:en direkt under
   `LayoutComponents.offlineIndicator()`, matad med `_batchRunning`. Den ligger utanför
   `TabBarView`, så den överlever både flikbyte och tömd markering.

3. **`friend_request_actions.dart`** — FAB:ens `icon:`-ternär tillbaka till
   `const Icon(Icons.check_circle)`. `onPressed: batchRunning ? null : …` står kvar.

4. **`friend_request_builders.dart`** — avbryt-knappens `icon:`-ternär tillbaka till
   `Icon(Icons.cancel, …)`. `onPressed`-låset och `enabled: !batchRunning` står kvar.
   Kommentaren om varför menyknappen är tyst stryks — den premissen (FAB:en bär signalen)
   gäller inte längre.

5. **Tester**
   - `friend_requests_selection_lock_test.dart`: busy-armen pinnar baren i stället för
     spinnern i knappen. NYTT fall — det som är hela biljetten: starta en batch, byt flik
     ELLER tryck "Rensa", och kräv att baren fortfarande syns och annonserar. Det är det
     enda testet som blir rött av dagens defekt.
   - `friend_requests_batch_actions_test.dart`: FAB:ens busy-fall tappar sin
     annonserings-assertion (FAB:en annonserar inte längre) och behåller att andra trycket
     vägras. Assertionen flyttar inte hit — baren finns inte i det pumpade trädet.
   - Muteringsprova varje ny assertion var för sig, med filen återställd och
     `git diff --numstat` tom emellan.

## Acceptans

- En batch som körs syns även när markeringen är tom och även på andra fliken.
- Exakt en laddningssignal på skärmen i varje läge — nu strukturellt, inte som påstående:
  baren är den enda, och ingen knapp har längre någon.
- `flutter analyze` rent, `dart format` 0 ändrade, de tre sviterna gröna.

## Vad jag INTE gör

- Låser inte flikbytet eller "Rensa". Batchen är ofarlig att lämna och skriver klart ändå.
- Rör inte `_clearSelection`-beteendet i sig (att flikbyte tömmer markeringen kan vara fel
  i sig, men det är en annan fråga och en annan biljett).

## För Malin

Knapparna slutar snurra — de blir gråa och otryckbara som förut — och i stället får skärmen
en tunn rad överst som säger att något körs. Den sitter kvar oavsett vad du gör med
markeringen eller vilken flik du står på. Det är en signal i stället för två, och den kan
inte försvinna av misstag.
