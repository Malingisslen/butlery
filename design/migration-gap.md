> **FRYST 2026-07-31 · historisk — men bär K-09 som plattformsmatris.md pekar på.** Underhålls inte. Får inte citeras som gällande. Se `fas0/kallauktoritetsregister.md`.

# Butlery · Gap-analys spec mot kod

Läst 2026-07-26 mot `Malingisslen/butlery@main`. Underlag: `lib/theme/*`, `.claude/rules/ui-conventions.md`, `docs/design-system/CROSS_CUTTING_RULES.md`, `docs/design/BUTLERY_VIEWS_AND_STATES.md` och hela `lib/views/`-trädet (183 filer).

---

## Slutsatsen först

**Appen är byggd och i drift med ett helt annat designsystem än specen.** Specen och koden delar namnet Butlery och nästan ingenting annat:

| | Specen (målet) | Appen (i dag) |
|---|---|---|
| Primärfärg | ink #24382C | forestGreen #4A7C59 |
| Accent | saffran #CE7C1E | rust #8B5A3C (dekor, aldrig fel) |
| Bakgrund | paper #F5F4ED | cream #F8F4E8 |
| Typsnitt | Butlery Sans, sex stilar | Josefin Sans (rubrik) + Space Grotesk (brödtext) |
| Mörkt läge | ink-grönt | varmbrunt #1A1611, seedat ur forestGreen |
| Bottennavigation | Hem · Meny · (+) · Inköp · Mer | Mina recept · Lägg till · Veckomeny · Inköpslista |
| Primärhandling | rund saffransknapp i naven | kvadratisk FAB app-brett |

**Beslutat: specen vinner.** Det här är en omdesign, inte en portning. Appens visuella system, navigation och komponentyta byts ut. Konsekvenserna, uttalade:

- Varje vy i appen kommer att röras. 183 vyfiler, 174 delade widgets.
- Appens dokumenterade UI-beslut (BUT-964 kvadratisk FAB, BUT-948 långtryck, ”Lägg till” som flik) rivs upp och ersätts. Ta bort eller skriv om dem i `.claude/rules/ui-conventions.md` och `docs/design-system/CROSS_CUTTING_RULES.md` samtidigt — annars styr de nästa utvecklare mot det gamla.
- Appen kommer att se blandad ut under resan. Det är oundvikligt och ska inte hanteras med feature flags per vy — tokens först gör övergången till ett steg, inte trettio.

**Men specen är inte färdig för det här.** Den beskriver 19 vyer. Appen har ungefär 50, och ungefär 30 av dem har aldrig designats. Specen har också fyra rena hål som koden i dag fyller med beslut vi inte fattat (§ A: flerval, iOS-toppfält, bildfel, allergenikonen). **Omdesignen är därför i första hand ett designarbete, inte ett kodarbete** — och det är mitt arbete, inte Claude Codes.

## A · Direkta konflikter — kräver ett beslut per rad

Specen vinner överallt utom där den är **tom**. Kolumnen längst till höger säger vilket: *ersätts* = koden rättas efter specen, mekaniskt. *Specen saknar svar* = jag måste designa något innan vyn kan byggas. De fyra sista är det som faktiskt stoppar arbetet.

| # | Fråga | Specen säger | Koden säger | Åtgärd |
|---|---|---|---|---|
| K-01 | **Palett** | ink/saffran/paper | forestGreen/rust/cream (~90 tokens + 25 varumärkesfärger) | **Ersätts** — genereras ur `tokens.json`. Allt som läser `AppColors.*` följer med gratis. Varumärkesfärgerna (YouTube, ICA…) behålls som de är. |
| K-02 | **Typsnitt** | Butlery Sans, sex stilar | Josefin Sans + Space Grotesk; **på iOS `fontFamily: null`**, alltså systemfonten | **Ersätts** — men iOS-undantaget måste bort medvetet: specen kräver Butlery Sans på båda plattformarna. Det är en synlig förändring för iOS-användare. |
| K-03 | **Bottennavigation** | fem platser med Hem och Mer | fyra flikar, ingen Hem-vy finns | **Ersätts** — och Hem är en helt ny vy som ska byggas. Specen har den ritad; ingen kod finns. Störst enskild UX-vinst i hela omdesignen. |
| K-04 | **Primärhandling** | rund saffransknapp, 56 px, i naven | kvadratisk FAB app-brett; recept-tillägg som egen flik, märkt *owner decision — keep* | **Ersätts** — men beslutet i repot måste formellt återkallas, inte bara överskridas. Rör varje listvy. |
| K-05 ✅ | **Långtryck** — *stängd 2026-07-30, B-46: ”Välj” i toppfältet, långtryck som genväg* | ersatt av synlig kontroll (kebab) | långtryck = flerval på fyra listytor (BUT-948) | **Specen saknar svar.** Flerval är en funktion, inte en gest — skafferi, inköp, taggar och gruppmedlemmar behöver en ingång. Jag måste designa den. |
| K-06 | **Laddning** | tallrikslinje + text, aldrig spinner, aldrig shimmer | skelett **med shimmer**, overlay-spinner, ”Genererar meny…” med spinner | Alla laddningstillstånd byggs om. Låg risk, mycket yta. |
| K-07 ✅ | **Allergenmärkning** — *stängd 2026-07-30, B-50: ord + statusfärg, aldrig ikon* | tre tillstånd i **ord** + statusfärg, aldrig ikon | tre tillstånd med **form + ikon**, färger utanför båda paletterna | **Specen saknar svar.** Logiken stämmer (tre tillstånd), men appens formskillnad — cirkel mot triangel — är en tillgänglighetsvinst vår ordregel tappar. Jag ritar om märkningen så den bär både ord och form. |
| K-08 | **Snackbar** | `OK` aldrig enda åtgärd | fel-snackbar = 5 s **+ OK-knapp**, fyra typfärger utanför paletten | Litet ingrepp, men rör `SnackBarUtils` och alla anrop. |
| K-09 ✅ | **Toppfält** — *stängd 2026-07-30, B-45: ett gemensamt fält, iOS-gesterna behålls* | ett fält, samma på båda plattformar | `AdaptiveAppBar`, Cupertino på iOS, 39 vyer migrerade | **Specen saknar svar.** Antingen ritar jag iOS-varianten av varje toppfält, eller så överges plattformsanpassningen. Måste avgöras — det är 39 vyer. |
| K-10 | **Ikonkonvention** | egen familj, 47 glyfer | `AdaptiveIcons` med hjärta/stjärna/bokmärke-semantik (BUT-944) och färgregler (BUT-1213) | Vår ikonfamilj måste mappas mot deras semantiska alias, inte mot råa namn. Konventionen i koden är bättre specificerad än vår. |
| K-11 | **Destruktiva åtgärder** | ”Radera” ≠ ”Ta bort” | tre allvarlighetsklasser efter återställbarhet (BUT-954) | **Kompletterande, inte motstridiga.** Slå ihop: deras klass styr friktionen, vår regel styr ordet. |
| K-12 | **Datum och tid** | svenska format, tabulära siffror i kolumner | `ContextualTimeFormatter`, tre nivåer (BUT-961) | Kompatibelt. Vår content-guide behöver bara peka på deras helper. |
| K-13 | **Träffytor** | 48 × 48 dp golv, deklarerad hitbox | granskningsverktyget mäter **semantik**, inte storlek | **Ersätts** — men `app_dimensions.dart` behöver läsas först; den kan redan ha ett golv. |
| K-14 | **Receptbild** | mediaytan kollapsar när bild saknas | platshållare vid laddning, restaurangikon vid fel | **Specen saknar svar.** B-04 gäller *saknad* bild. *Misslyckad* bild är ett annat fall och behöver egen design. |

---

## B · Vyer i appen som aldrig designats

Det här är den dyra listan. Ungefär **30 vyer och flöden** finns i produktion utan att någon designat dem i specen. Fram till att var och en fått en åtgärd kommer varje implementatör att fatta designbeslut åt er.

**Onboarding och konto** (7 vyer) — välkomst, åldersgrind, **blockerad åldersgrind**, allergensida, kostsida, importsida, e-postverifiering.
**Inställningar** (9 vyer) — inställningsnav, kontosäkerhet, **MFA**, notisinställningar, hushållsstorlek, samlingsstatistik, mina anmälningar, allergenpreferenser, samtyckeshantering.
**Integritet och juridik** (6) — dataexport, samtycke, integritetspolicy, användarvillkor, communityriktlinjer, markdown-visaren.
**Admin och moderering** (9) — adminskal, feedback-inkorg, moderatorgranskning, driftlogg, parsningsdetaljer, mätflikar.
**Personliga taggar** (5) — tagglista, taggdetalj med **automatiseringsregler**, bulkdialoger, taggväljare.
**Import** (8 flöden) — YouTube, Instagram/TikTok, länk, foto med OCR, **röst**, fil, arkiv, snabbfångst, ta-emot-delning, assisterad import som fallback.
**Socialt** (12) — vänlista, förfrågningar, vänprofil, publik profil, grupper, gruppdetalj, lägg till medlemmar, delat med mig, delade listor, menyförhandsvisning, profilredigering.
**Övrigt** — notiscentral, **cook snaps**, familjebetyg med poolning, menyröstning, **konfliktdiffvy**, menyplacering, ingredienssök, upptäcktshyllor, okänd-ingrediens-guiden, hastighetsgränsdialog, sessionstimeout, ägarskapsöverföring.

Utöver detta finns en produktmodell i koden som specen inte beskriver alls: **taggautomatisering** (regler som taggar recept efter nyckelord och ingredienser), **poolade familjebetyg** med egen DPIA och LIA, **presence och realtidssynk**, och en **receptpipeline** med LLM-versionering och kill-switch.

I en omdesign finns bara två åtgärder per rad: **omdesigna** eller **ta bort**. Att ”porta som är” är inte tillgängligt — vyn har aldrig haft en design att porta.

Det betyder att omdesignen är ungefär **tre gånger så stor som specen är i dag**. Det är den enda siffran i det här dokumentet som betyder något för din planering.

Min föreslagna indelning, som du kan skjuta på:

**Måste designas** (kärnupplevelse, syns dagligen): Hem, onboarding-flödet i sin helhet, notiscentralen, inställningsnavet, de åtta importflödena reducerade till ett gemensamt mönster, personliga taggar, vänner och grupper, chatt.
**Bör designas** (syns sällan men bär tillit): samtyckeshantering, dataexport, kontosäkerhet och MFA, hushållsstorlek, mina anmälningar, juridikvyerna.
**Räcker med mönster** (ärver komponenter, ingen egen ritning): admin och moderering, driftlogg, parsningsdetaljer, mätflikar, samlingsstatistik.
**Kandidater för borttagning** — värda en fråga innan de designas: röstimport, snabbfångst, upptäcktshyllor, cook snaps, menyröstning. Fem funktioner som var och en kostar design, kod och underhåll. I preproduktion är det billigare att stryka än att förfina.

---

## C · Det som redan stämmer

Värt att säga, för det är mer än man tror:

- **Tre säkerhetstillstånd** för allergener finns redan i koden (`FREE` / `CONTAINS` / `UNKNOWN`) — vår `produktregler.md` § 1 beskriver samma modell. Bara färg och ikon skiljer.
- **Skafferiet** finns med kort, ark och flerval.
- **Konfliktvy** finns (`realtime/conflict_diff_view.dart`) — vår konfliktmatris har alltså en mottagare.
- **Roller och behörighet** finns modellerat (`household_roster_member`, `shared_content_member`, `group_invitation`) och matchar vår § 5 i grova drag.
- **Tillgänglighetsdisciplinen i koden är starkare än specens.** `Semantics(label:)` är obligatoriskt, lokaliserat, granskat av ett verktyg och testat per chunk. Vår handoff bör peka på deras `a11y`-nyckelkonvention i stället för att beskriva sin egen.
- **Fonterna i appen är också OFL** (Josefin Sans, Space Grotesk) — samma licensdisciplin som Butlery Sans kräver, så `assets/LICENSES.md` har en färdig mottagare.

---

## D · Ordning

Omdesignen är designarbete först, kodarbete sedan. Claude Code kommer in i steg 4.

**1 · Fyll specens fyra hål** (jag, en vända). Flerval utan långtryck, iOS-toppfältet, allergenmärkning med både ord och form, bildfel. Utan dessa kan ingen vy byggas färdigt.

**2 · Bestäm omfattningen** (du). Indelningen i § B, och särskilt de fem borttagningskandidaterna. Varje ja där kostar mig en ritning och teamet en implementation.

**3 · Designa i flödesordning, inte vylistordning** (jag). Ett flöde helt färdigt innan nästa börjar:
   a. *Öppna appen → se ikväll → laga* — Hem, receptdetalj, matlagning. Den finns nästan redan.
   b. *Planera veckan → handla* — veckomeny, generering, inköp, skafferi. Finns, behöver förbättras.
   c. *Första gången* — onboarding, åldersgrind, allergener. Finns i kod, saknas i design.
   d. *Lägg till ett recept* — åtta importflöden till ett mönster. Största förenklingsvinsten.
   e. *Tillsammans* — vänner, grupper, chatt, delning.
   f. Resten enligt § B.

**4 · Kod, i den här ordningen** (Claude Code):
   - **Tokens först.** `app_colors.dart` och `app_text_styles.dart` genereras ur `tokens.json`. Ingen vy rörs, hela appen byter utseende i ett steg, och varje avvikelse blir synlig automatiskt. Störst effekt per timme i hela projektet.
   - **Delade widgets sedan** — `lib/widgets/common/` (174 filer). Knapp, kort, chip, dialog, ark, snackbar, tomma och felaktiga lägen, laddning.
   - **Sedan vy för vy**, i samma flödesordning som steg 3, med design färdig innan vyn börjar.
   - **Samtidigt:** riv ut de BUT-beslut som ersatts ur `.claude/rules/ui-conventions.md` och `CROSS_CUTTING_RULES.md`. En kvarglömd regel styr nästa utvecklare mot det gamla.

**5 · Verifiering** enligt `testmatris.md` § 4, på byggd app.

---

## Vad jag behöver av dig nu

1. **De fem borttagningskandidaterna** — röstimport, snabbfångst, upptäcktshyllor, cook snaps, menyröstning. Behåll eller stryk?
2. **iOS-toppfältet** — ska Butlery se likadan ut på båda plattformarna, eller behåller vi Cupertino-anpassningen? Påverkar 39 vyer.
3. **Startpunkt** — börjar jag med hål-fyllningen (§ D1) eller med flöde a, som är närmast färdigt?

Kvar för mig att läsa innan kodordningen kan detaljeras: `lib/theme/app_dimensions.dart`, `lib/widgets/common/` och `docs/design/butlery-mockup-reference.md`.

## Etapp 8.1–8.2 · appens temafiler genererade (2026-07-26)

`tools/gen-app-theme.mjs` skriver om appens **befintliga** `lib/theme/app_colors.dart` och `app_text_styles.dart` ur `tokens.json`. Varje medlemsnamn behålls, så de 50 vyerna kompilerar oförändrade — bara värdena byter källa. Kartan ligger i `tools/app-theme-map.json`.

Fem saker som inte är kosmetiska:

1. **Färgnamnen är nu historiska.** `forestGreen` bär ink #24382C, `cream` bär paper #F5F4ED. Omdöpningen är en egen mekanisk vända — inte den här.
2. **Mörka schemat slutar gissa.** Det byggdes med `ColorScheme.fromSeed` plus tio handöverskrivningar; nu är varje slot en token med ett mätt kontrastpar, och schemat är `const`.
3. **Ingen blå finns i systemet** — `info` bär saffranslänken #A15A0A. Den gamla #2563CA hade ingen hemvist.
4. **Typsnittsgaffeln är borta.** `_primaryFontFamily` gav iOS `null` (= San Francisco) och Android Space Grotesk: appen såg olika ut på de två plattformarna. Nu Butlery Sans överallt.
5. **10 px och 44 px utgår.** Systemet tillåter 10,5 px endast i 700, och skalans topp är 32 (display). `textXs`, `badge` och `mainViewTitle` flyttas därför — den sista är en synlig ändring i alla huvudvyer och bör granskas av uppdragsgivaren.

Undantag som medvetet **inte** tokeniseras: `brand*`-färgerna (YouTube, ICA, Arla …). De är externa varumärkesidentiteter — citat, inte design.
