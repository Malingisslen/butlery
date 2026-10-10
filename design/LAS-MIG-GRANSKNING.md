> **Talen i den här filen ersattes 2026-07-31 av mätvärden ur `fas0/verify-report.json` (genereras av körningen).** Skriv inte nya för hand.

# Läs mig först — underlag för extern granskning

Butlery designspec v12. Paketerad **2026-07-30**. Den här filen finns för att en granskare
ska kunna börja på rätt ställe och inte lägga sin tid på att återupptäcka det vi redan vet.

---

## Vad det här är

En komplett designspecifikation för en svensk matlagnings- och veckomenyapp (Flutter,
iOS + Android + surfplatta). **326 artefakter** i fjorton skärmdelfiler plus en innehållsfil — varav 307 bär en enhetsram (279 telefon, 32 breda) och 19 inte gör det, plus tokens, ikonregister,
produktregler, evidensmatris och ett ticketunderlag för utvecklingsteamet.

Filerna är `.dc.html` och **öppnas direkt i en webbläsare**. `support.js` måste ligga kvar
i samma katalog — den är runtime, inte innehåll.

## Läsordning

Källauktoritet: varje artefakt äger sin domän. `00-spec-index.md` är navigationskarta och versionsregister, inte högsta instans; en konflikt mellan domäner är ett valideringsfel. Normativ definition: styrdokumentet § 3.
   Börja här. Ändringsloggen längst ner är kronologisk, nyast först.
2. **`produktregler.md`** — reglerna som designen ska följa. 22 avsnitt.
3. **`evidensmatris.md`** — 429 strikta kravrader: vilken ram som bevisar vad, vem som äger den,
   och om den är beslutad, implementerad eller verifierad.
4. **`blockerande.md`** — det som hindrar release, i löpande text med resonemang.
5. **`Butlery blockerande tickets.dc.html`** — samma sak som 18 tickets med JSON-export
   för Linear.
6. Skärmfilerna, i den ordning `00-spec-index.md` listar dem.

**Referens:** `tokens.json` (färg, typografi, mått), `icons.json` (78 ikoner, ett namn per
begrepp), `testmatris.md` (browserprober), `beslutslogg.md` (B-01…B-50),
`content-style-guide.md` (copyton), `plattformsmatris.md` (iOS/Android-skillnader).

**Historiska filer** — läses som kontext, styr inget: `arbetsplan.md`,
`grundgranskning.md`, `luckor-etapp9.md`, `migration-gap.md`. De är märkta historiska i
spec-indexets versionstabell. `migration-gap.md` och `luckor-etapp9.md` är kvar för att
något fortfarande pekar på dem och för att de bär beslut som inte finns någon annanstans.

---

## Vad vi vet är svagt — granska gärna här

Det här är inte en färdig produkt vi vill få beröm för. De här punkterna är kända och en
granskare gör mest nytta genom att pressa på dem:

Alla volym- och statustal genereras: kör `bash fas0/run-verify.sh` och läs `fas0/kontrollstatus.md`. Inga tal står i den här filen.
  `verifierad`, 135 på `beslutad` (uppmätt 2026-07-31). Skillnaden är att någon har mätt. Verifieringsprotokollet (B-43) är
  oöppnat.
- **CI-01 är `not run`.** En workflow finns (`.github/workflows/verify.yml`) men är inte aktiverad i det riktiga repot. Tills den körts är Fas 0 **delvis klar**.
  Tre handskrivna tal gled bara under paketeringsdagen — ett ram-id, en ramräkning, en
  opacitet. Alla tre hade fällts av en körning.
- **Reglerna är skrivna av oss, för oss.** 22 produktregler utan en enda extern läsare.
  Första dev-frågan som inte täcks är det riktiga testet.
- **Copy är granskad mot sig själv.** Ingen har läst den för första gången.
Alla volym- och statustal genereras: kör `bash fas0/run-verify.sh` och läs `fas0/kontrollstatus.md`. Inga tal står i den här filen.
  Vi hittade fyra riktiga inkonsekvenser i den stora granskningen — antingen är designen
  mycket konsekvent, eller så letade vi bara där det gick att mäta. Vår gissning är
  delvis det senare: kontrast är lätt att mäta, om en bekräftelsedialog behövs alls är
  det inte.
- **`data-hit` är avsiktligt ofyllt** på 846 av 1 372 märkta kontroller — 526 bär attributet, efter att 47 dubbletter tagits bort i Fas 0. Det är inte en
  lucka — T-08 ska mäta *renderad* höjd, och 799 handskrivna tal hade gjort märkningen
  sämre. Se tillgänglighetshandoffen.

## En öppen produktfråga

**T-06, timerns exakta tid.** Tre vägar är ritade (behörighet / sänkt löfte /
förgrundstjänst) eftersom vägvalet är produktens, inte designens. Designens hållning:
förgrundstjänst med det sänkta löftets copy som fallback. Se `produktregler.md` § 22.21b.

## Vad som inte finns i paketet

Ingen appkod. `lib/` innehåller bara genererade Flutter-temafiler, och `tools/` är
generatorer och lintar — de läser specen, de bygger inte appen.
