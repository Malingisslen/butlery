# BUT-1975 + BUT-1965 — kalendern ska visa redigeringen, inte snurran

Malins beslut 2026-08-28: *"Visa redigeringen direkt, sluta snurra."* Priset hon
accepterade: en sparning som servern senare nekar hinner synas innan den rullas tillbaka.

BUT-1965 byggs i samma ändring. Fas 4 mätte att de två inte kan lagas var för sig.

## Vad som är fel, mätt

`isLoading` har **exakt två** konsumenter:

- `calendar_weekly_menu_widget.dart:96` → `LoadingStateBuilder`, som returnerar sin
  laddningswidget **innan** den läser `data`. Under en obesvarad sparning är kalendern
  alltså en snurra oavsett vad `_plan` innehåller.
- `veckomeny_view.dart:315` → avaktiverar inköpslistsknappen.

Varje skrivoperation går genom `executeAsyncVoid`, som gör `setLoading(true)` och rensar
först efter `await operation()` (`base_viewmodel.dart:227-231`). Offline fullbordas
`set()`-Future:n aldrig (fas 4:s mätning), så flaggan fastnar sann på **båda** ytorna.

Och `_plan` tilldelas först EFTER `await save`, så det finns dessutom inget att rita.

## Bygget

### 1. Skilj läsning från skrivning

Skrivvägarna ska inte äga laddningsläget. Ny privat hjälpare i viewmodellen som speglar
`executeAsyncVoid` **utan** `setLoading`:

```dart
Future<bool> _executeWrite(
  Future<void> Function() op, {
  required String errorPrefix,
}) async { ... clearError, try/catch, setError(errorPrefix) ... }
```

Flyttas över: `setSlotPresence`, `setDayPresence`, `applyGeneratedMenu`, `assignRecipe`,
`moveEntry`, `removeEntry`, `clearWeek`, `undoClearWeek`, `copyWeekToNext`,
`bulkMoveSelected`.

**`_fetchWeek` behåller `executeAsyncVoid`** — det är läsningen, och snurran hör till den.

### 2. Publicera optimistiskt, rulla tillbaka vid fel

I varje skrivoperation: tilldela `_plan` och `notifyListeners()` **före** `await save`.
Vid kast: återställ föregående plan, notifiera, sätt fel.

Det är den halva som gör en offline-redigering synlig (BUT-1965).

**Detta vänder fas 2:s ordning med flit.** Fas 2 landade på persist-then-publish av goda
skäl, och den ordningen var rätt *så länge snurran täckte kalendern*. När snurran försvinner
är den ordningen precis det som gör en offline-redigering osynlig. Vändningen är alltså
beslutad, inte en återgång till det fas 2 förkastade — läs BUT-1962:s planavsnitt innan
någon "rättar tillbaka" den.

### 3. Spärr mot överlappande redigeringar

Snurran hindrade hittills två samtidiga redigeringar. Tas den bort kan två ändringar starta
från samma `_plan` och den sista skriva över den första.

En `_writeInFlight`-flagga: en skrivning som startar medan en annan är obesvarad **vägras**
(returnerar false) i stället för att bygga på en inaktuell bas. `_applyInFlight` finns redan
för `applyGeneratedMenu` och ersätts av den gemensamma.

### 4. Inköpslistsknappen

`veckomeny_view.dart:315` avaktiverar på `isLoading` och kommentaren säger att det ersätter
en handrullad re-entrancy-flagga. När skrivningar lämnar `isLoading` slutar knappen vara
avaktiverad under en sparning — vilket är poängen, men re-entrancy-skyddet får inte
försvinna. Generatorn har redan sin egen `alreadyRunning`-sentinel. **Avgörs vid bygget:**
peka om till skriv-flaggan eller låt den ligga kvar på `isLoading`. Får inte tyst tappa
skyddet.

## Acceptans

1. En obesvarad sparning lämnar kalendern **renderad**, inte som snurra. Pinnat.
2. En genererad vecka renderas offline, och en verkligt misslyckad sparning visar
   fortfarande fel. *(Ordagrant från BUT-1965, som inte kunde uppfylla det ensam.)*
3. En nekad sparning rullar tillbaka redigeringen och visar ett svenskt fel.
4. Två överlappande redigeringar: den andra vägras, den första överlever.
5. `_fetchWeek` visar fortfarande snurran under en läsning.
6. Varje ny gren mutationsprövad.

## Risker

- **Störst:** punkt 3 byter en synlig bugg mot en tyst om återställningen är fel. Den ska ha
  ett eget test, inte bara ett hörn av ett annat.
- Punkt 2 kan inte verifieras på en telefon här (fas 4). Testas mot en `Completer` som
  aldrig fullbordas — samma tillstånd, mätbart, men inte samma klient.

## För Malin

Kalendern slutar bli en snurra när du redigerar utan täckning. Din ändring syns direkt och
sparas i bakgrunden. Om servern nekar den försvinner den igen och du får ett felmeddelande —
det var priset du valde. Två snabba ändringar efter varandra: den andra avvisas hellre än
att den skriver över den första.
