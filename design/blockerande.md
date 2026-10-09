# Butlery · Blockerande krav före release

Version 1.0 · 2026-07-29. **Sammanställd ur `evidensmatris.md` efter att ritningssidan stängts.** Urvalet är inte "allt som återstår" — 68 krav står `beslutad` — utan de rader där konsekvensen för en användare är **förlorad åtkomst, förlorade uppgifter eller ett brutet juridiskt löfte**. Var och en kräver en kodändring. Ingen av dem kan stängas av en ritning.

Ordningen är efter hur illa det blir, inte efter hur svårt det är att laga.

---

## 1 · Utelåsning · AU-10 · AU-12 · KI-19

**Vad som händer:** användaren slår på tvåstegsverifiering i inställningarna. Nästa inloggning kräver en kod — och **appen kan inte ta emot den**. `MfaResolverInfo` finns bara i sin egen fil; ingen vy och ingen viewmodell tar emot en utmaning. Det finns dessutom **inga reservkoder**, så en tappad telefon är ett tappat konto med hushållets recept i.

**Åtgärd, i den ordningen:**
1. Spärra påslagningen tills utmaningen finns. En knapp som låser ut användaren är värre än en saknad funktion.
2. Bygg utmaningsvyn (`#authmfa` är ritad som kravunderlag): maskerad nummerledtråd, 60 sekunders giltighet, tolerans för automatisk verifiering, **ett** fält.
3. Tio reservkoder som en del av påslagningen, inte som en inställning längre in.

**Ägare:** dev · **Bevis:** inloggning med MFA på fysisk enhet, och en återställning utan telefonen.

---

## 2 · Återkallat samtycke ingen rört · KI-02

**Vad som händer:** användaren sparar sina notisval. `ConsentViewModel` bygger sitt spar-objekt ur **fem av sju** ändamål; `aiProcessing` nämns inte och har `false` som standardvärde. **AI-samtycket skrivs tyst över till nej.** Det är samtycket receptimportens tolkning vilar på — och ett samtycke som återkallas utan användarens handling är en GDPR-fråga, inte en bugg i en inställningsvy.

**Åtgärd:** sparningen ska utgå från det **lästa** samtycket och bara ändra det användaren rört — exakt samma fix som räddade hushållsstorleken i BUT-1322.

**Ägare:** dev · **Bevis:** enhetstest som sparar notisval och verifierar att `aiProcessing` står kvar.

---

## 3 · Policykrav utan uppfyllnad · KI-24 · KI-25

**Vad som händer:** `MyReportsView` finns för Google Plays UGC-policy och visar status i fyra lägen — men policyn kräver också en **väg att överklaga**, och den finns inte. Dessutom säger *åtgärdad* ingenting om vad som hände: samma ord täcker "innehållet togs bort" och "vi bedömde att det var okej". Statusbrickan bär en textfärg mot fyra bakgrunder.

**Åtgärd:** utfallstext i klartext per anmälan, en överklagandeväg på avslutade, och status som bärs av ord och form.

**Ägare:** dev · **Bevis:** policygranskning före butiksinlämning.

---

## 4 · Ett löfte appen inte kan hålla · BH-08

**Vad som händer:** matlagningslägets timer utlovar en ringning på sekunden. **Behörigheten för exakta larm efterfrågas aldrig** — ingen förekomst av `scheduleExactAlarm` i `lib/` — och på Android 13 och senare får en app då inte lägga ett exakt larm. Timern ringer när systemet råkar vakna.

**Åtgärd:** antingen behörigheten (`#behlarm` är ritad) eller **ett ändrat löfte** i matlagningsläget. Inte båda, och inte ingen.

**Ägare:** dev · **Bevis:** timer över tid på en låst Android 13-enhet.

---

## 5 · Licens · P-06 · P-07

**Vad som händer:** Butlery Sans är ett **modifierat och omdöpt OFL-1.1-derivat** av Mona Sans, Albert Sans och DM Sans. Namnet och Butlerys egna ändringar kan tillhöra Butlery; **fontprogramvaran distribueras fortsatt under OFL** och kan inte göras proprietär eller exklusiv. Kravet är att copyrightmeddelanden och OFL-texten **följer med den faktiska releasen** — OFL 1.1 villkor 2 godtar fristående filer, läsbara headers *eller* maskinläsbar metadata, så name-tabellen är rekommenderad men inte den enda giltiga vägen. En OFL-font får uttryckligen ingå i en kommersiell mobilapp (OFL FAQ 1.20).

**✅ Åtgärdat på fontsidan 2026-07-30 · Butlery Sans 0.626.** De tre bristerna är stängda: attributionen är harmoniserad i alla sex stilar (kursivfilerna krediterade tidigare bara Mona Sans), OFL-texten är konsoliderad till en fil utan dubblerade rader, och `app-assets` bär nu licenser, `FONT-VERSION.txt` och manifest. `VALIDATION-0.626.txt` rapporterar **18/18 filer** med rätt version och identisk attribution, och **24/24 referensrenderingar pixelidentiska** med 0.625 — metadata-only, inga glyfer eller mått rörda. Specen använder 0.626 sedan samma dag.

**Kvar hos releaseansvarig — och det är hela resten av kravet:** hela `app-assets` ska med i bundlen (inte bara binärerna), och de två licensdokumenten ska nås via en **verklig rutt i appen** — *Inställningar → Om → Licenser*. Filer i en bundle som ingen kan öppna uppfyller inte OFL:s villkor 2.

**Ägare:** fontbygget (0.626) + releaseansvarig · **Bevis:** en build där copyright och OFL-text går att hitta, och sex stilar med samstämmig attribution.

---

## Näst värst: tyst dataförlust

Inte utelåsning, men användaren förlorar något utan att få veta det. Alla kräver kod.

| Krav | Vad som försvinner tyst |
|---|---|
| **MR-06** | En utgången oavgjord röstning faller mellan `activeVotes` och `resolvedVotes` och **syns ingenstans**. Röster kan ha lagts; platsen står tom. |
| **SK-04** | `isStaple` går inte att sätta i något gränssnitt — hela basvaruuteslutningen är **vilande**, och salt hamnar på varje lista. |
| **SK-13** | Manuella rader i den genererade veckolistan **försvinner** vid regenerering. Regeln finns i koden, varningen finns inte. |
| **SK-03** | Basvaruuteslutningen degraderar tyst till ingenting när skafferiet inte kan läsas. Två identiska listor betyder olika saker. |
| **KI-15** | Notisvalens lokala lager är en stubbe (`toJson` ger `{}`) — offline kan valen se ut som nollställda. |
| **I-24 · I-25** | Utkastet är lokalt, har fem platser, dör efter ett dygn, och **misslyckad sparning är tyst**. Inget av det sägs. |
| **KI-23 · S-17** | Borttagning ur notisinkorgen och av en cook snap sker **utan Ångra**, mot projektets egen § 2.4 klass 1. |

---

## Vad som *inte* står här

Rättvisefrågorna (röstningens alternativ efter lagd röst, lika resultat avgjort på ett id), tillgänglighetsraderna (långtryck som enda väg till en destruktiv åtgärd), och de fyrtiotal rader som är regler teamet bygger ur mönstret. De är verkliga och de står i `evidensmatris.md` — men de tar inte kontot, uppgifterna eller löftet ifrån någon.

**Och det som ingen kodändring löser:** verifieringsprotokollet i `testmatris.md` § 4. TalkBack, VoiceOver, 2,0× systemtext, rotation, reducerad rörelse — på fysisk enhet, med enhet och datum ifyllda. Det ägs av utvecklingsteamet och har ägts av dem sedan beslut B-24.
