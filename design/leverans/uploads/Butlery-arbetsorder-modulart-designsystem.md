> **SUPERSEDED 2026-07-31 som instruktion.** Ersatt av `Butlery styrdokument modulart designsystem.dc.html`. Kvarstår som underlag; följ inte detta dokument.

# Arbetsorder: gör Butlery-specen till ett modulärt och implementerbart designsystem

## Instruktion till den LLM som utför arbetet

Du ska bygga om den befintliga Butlery-designspecifikationen till ett **kanoniskt, modulärt och maskinellt verifierbart designsystem** som kan implementeras i Flutter utan att färger, typografi, spacing, former, komponentutseende, standardstates eller responsiva grundmönster behöver underhållas separat i varje featurevy.

Detta är inte en beställning på fler fristående skärmbilder. Det är en beställning på den gemensamma designinfrastruktur som alla skärmar ska byggas av.

Läs hela det befintliga specpaketet innan du ändrar något. Bevara Butlerys beslutade visuella identitet och produktlogik, men bygg bort dubbla sanningar, lokala designvärden och manuellt duplicerade komponenter.

Arbetet är inte klart förrän samtliga godkännandekriterier i slutet av detta dokument är uppfyllda och verifieringskedjan går grönt från en ren kopia.

---

# 1. Målet

## 1.1 Det vi vill uppnå

Appens målarkitektur ska göra följande möjligt:

- En ändring av en färgtoken ska slå igenom i alla relevanta komponenter och vyer.
- En ändring av exempelvis knapphöjd, kortutseende, typografisk roll, focus ring eller dark mode ska göras på ett ställe.
- Alla återkommande kontroller och states ska implementeras som återanvändbara komponenter eller patterns.
- Featurevyer ska komponera designkomponenter och koppla dem till data och affärslogik, inte själva återskapa designen.
- Mobil, stor telefon, liggande, surfplatta och bred layout ska använda gemensamma adaptiva layoutprimitiver.
- Tillgänglighetsstandarder ska följa med komponenten som default, inte implementeras om i varje vy.
- Skärmspecifikationen ska visa hur komponenterna sätts samman, inte duplicera komponenternas CSS/mått.
- Specifikation, genererade Fluttertokens, CSS, komponentkatalog och verifieringsrapporter ska komma från samma versionslåsta källor.

## 1.2 Det vi inte menar

Målet är inte att all appkod ska flyttas till `design/`.

Featurevyer ska fortfarande äga:

- data och view models;
- affärsregler;
- navigation;
- ordningen och sammansättningen av innehåll;
- featureunika states och actions;
- featureunik copy.

Designsystemet ska äga:

- färg, typografi, spacing, storlek, radie, linje, elevation och motion;
- ikoner och ikonregler;
- standardutseende och semantik för interaktiva kontroller;
- återkommande komponenter;
- återkommande status- och feedbackmönster;
- adaptiva layoutprimitiver;
- dark mode, focus, disabled, pressed, loading och reduced motion;
- standardiserade träffytor och tillgänglighetsbeteenden.

En featurevy får komponera layout, men får inte uppfinna nya designvärden.

---

# 2. Kända problem i nuvarande leverans

Utgå från följande verifierade nuläge och kontrollera själv att siffrorna fortfarande stämmer innan refaktoreringen:

- `tokens.json` är version 1.9.
- `lib/theme/butlery_tokens.dart` anger version 1.4.
- genererad CSS samt `AppColors`/`AppTextStyles` anger version 1.3.
- De aktiva skärmfilerna använder inte de genererade `--butlery-*`-variablerna.
- Skärmfilerna innehåller cirka 11 324 inline-`style`-attribut.
- Skärmfilerna innehåller cirka 25 823 råa pixelvärden.
- Skärmfilerna innehåller cirka 10 319 hårdkodade sexsiffriga hex-färger.
- `lib` innehåller theme-/tokenfiler, men ingen komplett uppsättning återanvändbara Butlery-widgets.
- `ButleryControls` innehåller främst konstanter, inte komponentimplementationer.
- `ButleryTouch.hit` anger `button: true` för alla kontroller och kan därför inte vara generell semantikwrapper för checkbox, radio, switch, tab och andra roller.
- `lint-controls.mjs` rapporterar 339 avvikelser och ingår inte i huvudverifieringen.
- Huvudverifieringen är inte grön trots att index/evidens säger det.
- Den uppdelade specen läses inte korrekt av alla lintsteg.
- Globala dubblett-ID:n missas eftersom vissa kontroller sker fil för fil.
- 47 element har dubbla `data-hit`-attribut.
- Det finns flera konkurrerande aktiva varianter av samma vy eller state.
- 75 olika ramstorlekar blandar verkliga viewports, beskurna dokumentationsbilder och komponentboards.
- 19 koncept-/komponentboards räknas som skärmar.
- Specanteckningar och faktisk produkt-UI ligger ibland i samma DOM.

Detta är inte en lista som ska döljas genom att ändra räknare eller statuscopy. Orsakerna ska byggas bort.

---

# 3. Principer som inte får förhandlas bort

## 3.1 En källa per beslut

Varje designvärde ska ha exakt en normativ källa:

- rå färgpalett definieras en gång;
- semantiska färgtokens definieras en gång;
- typografiska roller definieras en gång;
- kontrollgeometri definieras en gång;
- komponentvarianter definieras en gång;
- skärmens komposition definieras en gång.

Genererade filer får aldrig redigeras manuellt.

## 3.2 Semantiska tokens före rå palett

Komponenter ska använda exempelvis:

- `color.text.primary`;
- `color.surface.raised`;
- `color.border.control`;
- `color.action.primary`;
- `color.status.danger.text`.

De ska inte använda `green`, `cream`, `rust` eller hexvärden direkt.

Råpaletten får endast användas när semantiska tokens definieras samt för uttryckligt dokumenterade externa varumärkesfärger eller datavisualisering.

## 3.3 Komponenter före skärmspecifik styling

Om samma visuella eller interaktiva mönster förekommer två gånger ska det bedömas som kandidat till en komponent eller ett pattern.

Skapa inte en separat “nästan likadan” knapp, rad, dialog eller toppbar för en enskild feature. Utöka den gemensamma komponentens uttryckliga API när varianten är legitim.

## 3.4 Komposition före arv

Bygg små, komponerbara komponenter. Undvik djupa widgetarvshierarkier och featureflaggor som:

```dart
if (isRecipeScreen) ...
if (isShoppingMode) ...
```

En generell komponent ska få generiska parametrar, slots och callbacks. Den ska inte importera repositories, services, feature-viewmodels eller domänmodeller.

## 3.5 Tillgänglighet är en del av API:t

Roll, namn, state, fokus, tangentbord, läsordning, hitarea och reduced motion ska definieras tillsammans med komponenten.

Tillgänglighet får inte reduceras till ett frivilligt `semanticLabel` som varje vy förväntas komma ihåg.

## 3.6 Adaptivt, inte enhetsspecifikt

Layout ska styras av tillgängliga constraints, textskala och innehåll, inte av hårdkodad telefonmodell eller OS.

## 3.7 Inga falska gröna statusar

Ett krav får bara märkas `verified` när det har ett reproducerbart test eller manuellt protokoll med datum, miljö och resultat. `Not run` ska vara en giltig och ärlig status.

---

# 4. Målarkitektur i Flutter

Skapa eller specificera följande målstruktur. Namnen får justeras mekaniskt om appen redan har en tydlig konvention, men lagren och beroenderiktningen ska behållas.

```text
lib/
  design/
    foundations/
      generated/
        butlery_tokens.g.dart
        butlery_icon_data.g.dart
      butlery_theme.dart
      butlery_theme_extension.dart
      butlery_breakpoints.dart
      butlery_insets.dart
      butlery_icons.dart
      butlery_motion.dart

    primitives/
      b_text.dart
      b_icon.dart
      b_button.dart
      b_icon_button.dart
      b_text_field.dart
      b_checkbox.dart
      b_radio.dart
      b_switch.dart
      b_chip.dart
      b_badge.dart
      b_divider.dart
      b_progress.dart

    components/
      b_top_bar.dart
      b_bottom_navigation.dart
      b_list_row.dart
      b_form_field.dart
      b_portion_stepper.dart
      b_avatar.dart
      b_avatar_stack.dart
      b_search_field.dart
      b_status_banner.dart
      b_recipe_card.dart
      b_recipe_header.dart
      b_calendar_cell.dart
      b_presence_row.dart
      b_shopping_item_row.dart
      b_pantry_item_row.dart

    patterns/
      b_loading_state.dart
      b_empty_state.dart
      b_error_state.dart
      b_offline_state.dart
      b_partial_state.dart
      b_conflict_state.dart
      b_permission_state.dart
      b_destructive_dialog.dart
      b_undo_feedback.dart
      b_fixed_bottom_action.dart

    layouts/
      b_screen.dart
      b_scroll_layout.dart
      b_form_layout.dart
      b_list_layout.dart
      b_master_detail.dart
      b_adaptive_grid.dart
      b_adaptive_sheet.dart

    testing/
      fixtures/
      widgetbook/
      goldens/
      accessibility/

  features/
    ...
```

## 4.1 Tillåten beroenderiktning

```text
generated tokens
      ↓
foundations
      ↓
primitives
      ↓
components
      ↓
patterns/layouts
      ↓
feature views
```

Inget lager får importera ett lager under sig. `design/` får inte importera `features/`.

## 4.2 Fluttertema

Använd:

- `ThemeData` och `ColorScheme` för Materialegenskaper som har en korrekt semantisk motsvarighet;
- en typad `ThemeExtension` för Butleryspecifika semantiska tokens;
- genererade, immutable tokenvärden;
- separata light/dark-mappningar från samma semantiska token-ID.

Skapa inte parallella långsiktiga theme-API:n.

`AppColors` och `AppTextStyles` får tillfälligt finnas som `@Deprecated`-märkta migrationsalias. De ska peka på samma källa och ha ett beslutat borttagningssteg. Ny kod får inte använda dem.

Generatorn ska generera tokenvärden och vid behov typade token-ID:n. Återanvändbara widgets ska vara granskad Dartkod som konsumerar tokens; generera inte stora mängder svårläst widgetkod utan tydlig vinst.

---

# 5. Målarkitektur för själva specpaketet

Skärm-HTML ska inte längre vara den primära källan för komponenternas design.

Skapa en struktur motsvarande:

```text
design-system/
  README.md
  design-system.manifest.json

  tokens/
    tokens.json
    tokens.schema.json

  contracts/
    component-contract.schema.json
    screen-composition.schema.json
    primitives/
    components/
    patterns/
    layouts/

  compositions/
    phone/
    wide/
    shared/

  templates/
    components/
    layouts/

  generated/
    css/
    flutter/
    html/
    reports/

  tests/
    fixtures/
    goldens/
```

Om befintligt verktyg eller `.dc.html`-format kräver en annan fysisk struktur är det tillåtet, men följande logiska separation är obligatorisk:

1. normativ källdata;
2. komponentkontrakt;
3. skärmkompositioner;
4. genererade visualiseringar;
5. verifieringsrapporter.

## 5.1 Genererade skärmar

De aktiva skärmarna bör i möjligaste mån genereras från:

- komponentkontrakt;
- kompositionsmanifest;
- fixtures/data;
- ett gemensamt renderingslager.

Varje skärm får definiera innehåll, komponentordning, state och särskild layoutkomposition. Den får inte återdefiniera komponenternas färg, typografi, radie, hitarea eller stateutseende.

Alla aktiva skärmar ska använda genererad token-CSS och gemensamma komponentklasser eller templates. Råa hexvärden i aktiva skärmar ska vara förbjudna utom uttryckligt dokumenterade externa brandfärger och testfixtures.

## 5.2 Separera produkt och annotering

Produkt-UI och specanteckningar ska ligga i skilda lager.

Det ska finnas ett sätt att rendera:

- endast den faktiska produktytan;
- produktyta med granskningsannoteringar;
- komponentkatalog;
- test-/debuginformation.

Krav-ID, Dartklassnamn, enums, “kvar att bygga” och liknande får aldrig ligga i product DOM eller räknas som användarcopy.

## 5.3 Klassificera artefakter

Varje item ska ha ett explicit slag:

```text
viewport
crop
component
pattern
annotation
concept
superseded
```

Endast aktiva `viewport`-artefakter får räknas som skärmtäckning eller viewport-/overflowbevis.

---

# 6. Komponentkontrakt

Varje återanvändbar komponent ska ha ett maskinläsbart kontrakt. Följande fält är minimum:

```yaml
id: button
implementation: BButton
layer: primitive
status: active
description: Gemensam handlingsknapp

variants:
  - primary
  - secondary
  - tertiary
  - destructive

sizes:
  - regular
  - compact

states:
  - enabled
  - pressed
  - focused
  - loading
  - disabled

properties:
  label:
    type: string
    required: true
  leadingIcon:
    type: icon-id
    required: false
  trailingIcon:
    type: icon-id
    required: false
  onPressed:
    type: callback
    required: false
  semanticsLabel:
    type: string
    required: false
    rule: Krävs endast när synlig label inte ger fullständigt namn

semantics:
  role: button
  disabledState: required
  busyState: required
  focusable: true

contentRules:
  maxLines: 2
  overflow: wrap
  iconOnly: false

tokens:
  height: control.button.regular.height
  radius: radius.control
  textStyle: type.label
  focusRing: focus.default

responsive:
  width: parent-controlled
  behaviorAtLargeText: grows-vertically
```

Formatet får vara JSON eller YAML, men ska schema-valideras.

## 6.1 Kontraktet ska svara på

För varje komponent:

- Vad heter komponenten i spec och kod?
- Vilket lager tillhör den?
- När ska den användas?
- När ska den inte användas?
- Vilka varianter är tillåtna?
- Vilka properties är obligatoriska?
- Vilka states finns?
- Vilka kombinationer är förbjudna?
- Vilka tokens använder den?
- Hur beter den sig med lång text?
- Hur beter den sig vid 200 % textskala?
- Hur beter den sig i dark mode?
- Vad händer vid reduced motion?
- Vilken semantisk roll, state och fokusordning gäller?
- Vilken del är interaktiv och hur stor är den faktiska träffytan?
- Vilka plattformsavvikelser är tillåtna?
- Vilka tester bevisar kontraktet?

## 6.2 Minsta komponentinventering

Inventera hela nuvarande spec och skapa en kanonisk katalog som minst täcker:

### Foundations

- semantiska färger;
- typografiska roller;
- spacing/insets/gaps;
- radier;
- linjer;
- elevation/scrim;
- ikonstorlekar och stroke;
- hitarea;
- breakpoints;
- rörelse och reduced motion;
- safe area;
- data-/avatarfärger.

### Primitives

- text;
- ikon;
- divider;
- button;
- icon button;
- link action;
- text field;
- text area;
- search field;
- checkbox;
- radio;
- switch;
- chip;
- badge/status pill;
- progress;
- avatar.

### Components

- top bar;
- bottom navigation;
- tabs/segmented control;
- list row;
- settings row;
- selection row;
- form field;
- portion/quantity stepper;
- recipe card;
- recipe header;
- shopping item row;
- pantry row;
- calendar cell;
- presence row;
- status banner;
- toast/snackbar/undo;
- dialog;
- sheet;
- menu;
- search/filter controls.

### Patterns

- loading;
- empty;
- error;
- offline;
- partial success;
- conflict;
- permission preprompt/denied/settings return;
- destructive confirmation;
- local draft/resume;
- fixed bottom action;
- selection mode;
- bulk action;
- skeleton;
- retry.

### Layouts

- standard phone screen;
- scrollable screen;
- form screen;
- list screen;
- detail screen;
- fixed bottom action;
- sheet/dialog;
- master-detail;
- adaptive grid;
- wide calendar;
- landscape cooking.

Slå ihop visuella dubbletter. Skapa inte ett separat komponentnamn för varje feature om samma struktur kan uttryckas med ett neutralt API.

---

# 7. Skärmkompositioner

Varje aktiv skärm/state ska ha:

```yaml
screenId: recipe.detail.populated
route: /recipes/:recipeId
status: active
artifact: viewport
feature: recipes
layout: detail-screen
viewportSupport:
  - phone
  - tablet
  - wide
states:
  - populated
  - loading
  - offline
  - error
components:
  - id: top-bar
    variant: back-title-actions
  - id: recipe-header
    variant: photo
  - id: tabs
    variant: equal
  - id: portion-stepper
    variant: regular
requirements:
  - R-01
productRules:
  - PR-RECIPE-04
```

Skärmkompositioner får inte innehålla:

- hexvärden;
- lokala fontstorlekar;
- lokala radier;
- lokala control heights;
- kopierade SVG-paths;
- återimplementerade button/field/list row-states.

Om en skärm verkligen behöver en unik layoutregel ska den:

1. använda befintliga tokens;
2. få ett namn;
3. dokumenteras i kompositionen;
4. ha test;
5. inte läggas in som ett anonymt inlinevärde.

---

# 8. Kanonisk status och versionsstyrning

## 8.1 Ett aktivt ID

Varje screen, component, pattern och layout ska ha ett globalt unikt ID.

Fixa särskilt de kända dubbletterna:

- `veckogenererar`;
- `veckoskrivover`.

Konkurrerande breda varianter och äldre mobila varianter ska få status:

- `active`;
- `superseded`;
- `concept`;
- `historical`.

En `superseded` artefakt ska peka på `supersededBy`.

## 8.2 Precedence

Definiera en enda precedenceordning, exempelvis:

1. beslutade produktinvariants;
2. kanoniska component contracts;
3. kanoniska screen compositions;
4. tokens;
5. mänsklig manual;
6. genererade HTML-/Flutter-/CSS-filer.

Ordningen måste vara logiskt möjlig. En genererad fil kan aldrig vinna över sin källa.

Vid konflikt ska verifieringen falla och visa båda källorna. Den får inte välja tyst.

## 8.3 Version

Alla genererade artefakter ska bära:

- designsystemversion;
- tokenversion;
- generatorversion;
- källans checksumma eller commit;
- genereringsdatum.

Körning av generatorerna två gånger utan källändring ska ge byteidentiskt resultat.

---

# 9. Produktregler som måste göras entydiga innan komponentisering

Bygg inte generella komponenter ovanpå två oförenliga produktmodeller. Följ befintliga kanoniska produktregler där de är entydiga. Där de inte är det ska konflikten lyftas som blockerande beslut, inte döljas i två aktiva varianter.

Följande ska särskilt konsolideras:

## 9.1 Veckomodell

Använd en enda modell över mobil och bred layout:

- 14 enkelplatser: lunch och middag under sju dagar;
- en flervärdesyta `Övrigt`, om det fortsatt är det beslutade produktkontraktet;
- använd inte `kväll` som parallell tredje enkelplats.

Bred layout måste visa och tillåta samma data och handlingar som mobil.

## 9.2 Generering

Definiera en enda state machine:

```text
idle
→ preflight
→ confirmed
→ generating
→ complete | partial | failed | cancelled
```

För varje övergång ska det framgå:

- vad som finns lokalt;
- vad som är persisterat på servern;
- vad cancel gör;
- vad back gör;
- vad appdöd gör;
- vad retry gör;
- vad undo gör;
- hur annan klient påverkas.

Använd inte samtidigt blockerande overlay, background generation och direkt cellskrivning utan ett uttryckligt gemensamt kontrakt.

## 9.3 Avbryt och utkast

`Avbryt` får inte tyst kasta användarens placeringsarbete. Behåll lokalt utkast tills användaren uttryckligen väljer att slänga det, om inget nytt beslut ersätter denna regel.

## 9.4 Allergensäkerhet

Modellera minst:

```text
safe
unsafe
unknown
notApplicable
```

`unknown` får visas och granskas men får inte automatplaneras eller massplaceras i ett hushåll med relevanta allergier.

Detta ska vara en domäninvariant och ett automatiserat test, inte enbart UI-copy.

## 9.5 Terminologi

Fastställ en kanonisk term för den delade gruppen. Om appen ska stödja fler relationer än kärnfamilj ska `hushåll` användas konsekvent och motstridig `familj`-copy migreras.

---

# 10. Tokens

## 10.1 Obligatoriska tokengrupper

Tokens ska minst täcka:

- palette;
- semantic color;
- typography;
- spacing;
- insets;
- size;
- radius;
- border;
- elevation;
- opacity;
- motion;
- breakpoint;
- touch target;
- icon;
- avatar;
- data visualization;
- component tokens.

## 10.2 Komponenttokens

Globala foundationtokens räcker inte för allt. Lägg uttryckliga komponenttokens där en stabil komponentregel behövs:

```text
component.button.regular.minHeight
component.button.regular.paddingX
component.field.minHeight
component.listRow.minHeight
component.topBar.height
component.bottomNavigation.height
component.calendarCell.minHeight
component.avatar.stackOverlap
```

Komponenttokens ska referera till foundations när det är möjligt.

## 10.3 Förbjudna råvärden

Utanför tokenkällor, genererade filer och dokumenterade fixtures ska CI förbjuda:

- `Color(0x...)`;
- sexsiffriga hex-färger;
- råa `fontSize`;
- numeriska `BorderRadius.circular`;
- numeriska visuella `Duration`;
- godtyckliga `EdgeInsets`;
- godtyckliga kontrollhöjder;
- direktanvändning av ikonbibliotekets glyphs;
- råa shadow/scrimvärden.

Tillåtna undantag ska ligga i en versionerad allowlist med:

- ID;
- fil;
- värde;
- motivering;
- ägare;
- expiry eller omprövningsdatum.

Ingen tom eller generell allowlist.

## 10.4 Typografi

All text ska använda typografiska roller. Komponenter får inte sätta egen kombination av fontstorlek, vikt, line-height och tracking.

Stöd:

- tabular figures där mängder, datum eller tider kräver det;
- svensk text;
- 200 % textskala;
- långa namn;
- långa sammansatta ord;
- minst tre relevanta textlängdsfixtures per komponent.

---

# 11. Responsivitet och layout

## 11.1 Centrala breakpoints

Definiera breakpoints på ett ställe. Komponenter ska reagera på constraints, inte fråga efter en specifik telefonmodell.

Minsta verifierade matrix:

- minsta stödda telefonbredd;
- Pixel 9a eller motsvarande normal Androidviewport;
- stor telefon;
- liggande telefon;
- 768 px;
- bred desktop;
- split-screen där plattformen stödjer det;
- 200 % textskala på minsta bredd.

## 11.2 Viewport kontra dokumentationsbeskärning

Alla nuvarande 75 ramstorlekar ska klassificeras. Ett beskuret sheet eller komponentprov får inte användas som viewportbevis.

## 11.3 Reflow

Vid stor text:

- kontroller får växa vertikalt;
- labels får radbrytas;
- kritisk information får inte ellipsas bort;
- sticky/fixed actions får inte täcka innehåll;
- två kolumner ska kunna bli en;
- grids ska kunna växla till lista eller scroll med begriplig ordning.

---

# 12. Tillgänglighetskontrakt

Komponentkontrakten ska modellera:

- role;
- accessible name;
- value;
- checked/selected/toggled/expanded/busy/disabled;
- hint när namnet inte räcker;
- grouping;
- heading/landmark;
- läsordning;
- fokusordning;
- focus trap;
- focus return;
- live-regionstrategi;
- tangentbordsinteraktion;
- pointer/touch;
- switch access;
- reduced motion;
- textzoom och reflow.

## 12.1 Stateful controls

Alla checkboxar, radioalternativ, switchar och tabbar ska ha explicit state. Generiska namn som `Reglage` är förbjudna.

## 12.2 Träffyta

Mät faktisk semantisk/interaktiv bounding box i browser och Fluttertest. Ett `data-hit="48"` eller en kommentar är inte bevis.

## 12.3 Rollmedvetna wrappers

Ersätt den universella `ButleryTouch.hit` med riktiga komponenter eller en rollmedveten intern primitive. En checkbox får inte exponeras som vanlig button och en tab får inte exponeras som switch.

## 12.4 Dynamiskt innehåll

Definiera särskilt:

- timer: annonsera milstolpar, inte varje sekund;
- progress: begriplig label och value;
- error: fokusflytt endast när lämpligt;
- toast/undo: tillräcklig tid och fokuserbar action;
- partial success: antal lyckade och misslyckade;
- drag-and-drop: fullständigt tangentbordsalternativ.

---

# 13. Ikoner och assets

Skapa ett typat ikonregister. Featurekod ska använda exempelvis:

```dart
BIcon(ButleryIcons.settings)
```

inte importera eller kopiera Lucide-paths direkt.

Fixa de kända saknade ikonmastrarna:

- `arrow-right`;
- `bell`;
- `block`;
- `check-square`;
- `drop`;
- `minus`;
- `move`;
- `reaction-add`;
- `settings`;
- `stop`;
- `tag`;
- `unlock`;
- `user-minus`;
- `volume`.

Alla ikoner ska ha:

- stabilt ID;
- masterfil;
- stroke-/fillregel;
- optisk storlek;
- tillåtna färgroller;
- RTL-policy där relevant;
- semantikregel;
- usage count genererad från alla aktiva specfiler.

Dekorativa ikoner ska inte få eget semantiskt namn när föräldrakontrollen redan har ett.

---

# 14. Komponentkatalog och dokumentation

Bygg en enda genererad komponentkatalog som visar:

- alla komponenter;
- alla giltiga varianter;
- alla states;
- light/dark;
- normal och 200 % text;
- kort och lång copy;
- minsta och bred layout;
- fokus;
- disabled;
- loading;
- reduced motion;
- semantiska egenskaper;
- vilka tokens komponenten använder;
- länk till contract-ID och test.

Komponentarket ska bli output från samma contracts som Flutterkomponenterna följer. Det får inte fortsätta vara en parallell handritad sanning.

---

# 15. Verifieringskedja

Skapa ett enda officiellt kommando, exempelvis:

```bash
npm run verify
```

eller motsvarande, som från en ren katalog:

1. validerar alla schemas;
2. validerar globala ID:n;
3. validerar alla tokenreferenser;
4. validerar component contracts;
5. validerar screen compositions;
6. genererar CSS;
7. genererar Fluttertokens;
8. genererar theme bridge om den fortfarande behövs;
9. genererar ikonregister;
10. genererar dokumentations-HTML;
11. kontrollerar att en andra generering inte ger diff;
12. kör lint för förbjudna råvärden;
13. kör kontrollgeometri;
14. kör browserrendering;
15. kontrollerar verklig overflow;
16. kontrollerar verkliga hitareas;
17. kör kontrastmatris;
18. kör light/dark;
19. kör textskala;
20. kör Flutter analyze/test om appkod finns i arbetsytan;
21. skapar en maskinläsbar slutrapport.

Huvudverifieringen ska inkludera `lint-controls` eller dess ersättare.

Alla 14 aktiva skärmfiler eller deras ersättande kompositionskällor ska behandlas som ett gemensamt dokumentträd. ID- och ankarkontroller får inte köras isolerat per fil.

## 15.1 Rapporter

Slutrapporten ska innehålla:

- exakt commit/checksumma;
- versionsnummer;
- antal aktiva screens;
- antal device frames;
- antal component/pattern/concept boards;
- antal komponenter;
- antal semantic controls;
- antal testade states;
- antal kontrastpar;
- antal overflow;
- antal hitareafel;
- antal schemafel;
- antal tillgänglighetsfel;
- `passed`, `failed` eller `not run` per kontroll.

Index och evidens ska konsumera den rapporten. Skriv inte manuella totalsiffror.

---

# 16. Lintregler i appkoden

Specificera och, om appkoden finns, implementera regler som minst upptäcker:

- råa färger utanför `design/`;
- rå typografi utanför `design/`;
- råa radier och visuella spacingvärden;
- direkt användning av `ElevatedButton`, `TextButton`, `OutlinedButton`, `IconButton`, `Checkbox`, `Radio`, `Switch`, `TextField`, `Dialog`, `SnackBar` och liknande i featurevyer när Butlerymotsvarighet finns;
- direkt användning av ikonbiblioteket utanför ikonregistret;
- designlager som importerar featurelager;
- nya anrop till deprecated `AppColors` och `AppTextStyles`;
- oregistrerade komponentvarianter;
- komponenter utan tester och katalogfixture.

Reglerna får inte göra legitim featurelayout omöjlig. Featurevyer får använda Flutterlayoutprimitiver men ska hämta designmått från designsystemet.

---

# 17. Migreringsstrategi

Gör inte en okontrollerad screen-by-screen-omritning.

## Fas A — frys och inventera

1. Lås appcommit och speccommit.
2. Inventera alla råa designvärden och komponentmönster.
3. Skapa canonical/superseded-status.
4. Fixa verifieringskedjan så att nuläget kan mätas ärligt.

## Fas B — foundations

1. Konsolidera `tokens.json`.
2. Reparera schema.
3. Generera Flutter/CSS/theme från samma version.
4. Inför ThemeExtension.
5. Lägg deprecated aliases för befintlig kod.

## Fas C — primitives

Implementera och verifiera grundkontrollerna först:

- text;
- icon;
- button;
- icon button;
- field;
- checkbox;
- radio;
- switch;
- chip;
- progress.

## Fas D — components och patterns

Bygg komponentkatalogens återkommande strukturer ovanpå primitives. Flytta inte affärslogik till designsystemet.

## Fas E — representativa pilotvyer

Migrera först ett litet men varierat urval:

- receptdetalj;
- veckoplan;
- inköpslista;
- onboardingformulär;
- en bred/master-detail-vy;
- en offline-/error-/partial-vy.

Piloten ska bevisa att komponenterna klarar verkliga behov utan lokala designvärden.

## Fas F — mekanisk utrullning

Migrera återstående vyer komponentfamilj för komponentfamilj:

1. alla buttons;
2. alla fields;
3. alla top bars/navigation;
4. alla rows;
5. alla feedbackstates;
6. alla layouts.

Undvik att blanda gammal och ny styling i samma komponent.

## Fas G — stäng bryggan

1. Förbjud nya legacyanrop.
2. Migrera kvarvarande aliases.
3. Ta bort `AppColors`/`AppTextStyles` när användningen är noll.
4. Gör råvärdeslint blockerande.

---

# 18. Obligatoriska leverabler

Leverera minst:

1. Ett korrigerat och versionslåst `tokens.json`.
2. Ett komplett schema som faktiskt validerar hela tokenstrukturen.
3. Ett designsystemmanifest.
4. En global ID-/statusförteckning.
5. Maskinläsbara component contracts.
6. Maskinläsbara screen compositions för alla aktiva skärmar/states.
7. Ett tydligt arkitekturdokument för Flutterlagren.
8. Genererade Fluttertokens.
9. `ThemeData` plus Butleryspecifik `ThemeExtension`.
10. En plan och kodkontrakt för primitives, components, patterns och layouts.
11. En typad ikonregistry och alla masterassets.
12. En genererad komponentkatalog.
13. Refaktorerade specskärmar som använder gemensamma tokens och komponenter.
14. Ett enda verifieringskommando.
15. En maskinläsbar verifieringsrapport.
16. En migrationskarta från gamla `AppColors`/`AppTextStyles`.
17. En lista över återstående blockerande produktbeslut — inga dolda antaganden.
18. En changelog som beskriver faktiska förändringar, inte bara nya påståenden.

Om appens fullständiga källkod inte finns i arbetsytan ska Flutterkomponenterna levereras som implementeringsklara kontrakt och scaffold där faktisk integration inte går att verifiera. Markera detta som `not run`, inte `verified`.

---

# 19. Förbjudna genvägar

Du får inte:

- bara flytta nuvarande hårdkodade värden till en stor fil utan semantisk struktur;
- kalla en konstantlista för ett komplett komponentbibliotek;
- skapa en gigantisk `ButleryWidgets.dart`;
- göra featurelogik beroende av designsystemet;
- skapa en särskild komponent för varje skärm;
- behålla flera aktiva varianter och kalla dem “flexibilitet”;
- lösa konflikter genom att välja tyst;
- skriva manuella counts eller gröna statusar;
- lägga lintfel i en generell allowlist;
- deklarera hitarea utan att mäta den;
- deklarera tillgänglighet endast genom roll/namn;
- göra skärm-HTML till en andra designkälla;
- redigera genererade filer manuellt;
- markera browser-, Flutter- eller enhetstester som verifierade om de inte körts;
- ändra Butlerys visuella identitet för att göra refaktoreringen enklare;
- försämra ljust/mörkt läge, svenska tecken, tabular figures eller befintliga säkerhetsstates.

---

# 20. Godkännandekriterier

Arbetet är klart först när alla tillämpliga kriterier är uppfyllda.

## Källor och generation

- [ ] En enda aktiv källa finns för varje token.
- [ ] Alla genererade filer anger samma aktuella token-/systemversion.
- [ ] Generering två gånger utan källändring ger ingen diff.
- [ ] Ingen genererad fil behöver handredigeras.
- [ ] `verify` går med exit code 0 från ren kopia.
- [ ] Samtliga delkontroller körs av huvudkommandot.

## Komponentisering

- [ ] Alla återkommande visuella mönster är klassificerade som primitive, component, pattern eller layout.
- [ ] Varje aktiv komponent har ett schema-validerat kontrakt.
- [ ] Varje variant och state i kontraktet finns i komponentkatalogen.
- [ ] Komponenter importerar inte featurekod.
- [ ] Featurevyer använder designkomponenter i stället för att återskapa dem.
- [ ] Det finns inget universellt semantikwrapper som felmärker olika roller som button.

## Råvärden

- [ ] Aktiva skärmkompositioner innehåller inga hexvärden, lokala fontstorlekar eller komponentradier.
- [ ] Aktiv screen HTML använder genererade tokens och gemensamma komponenter.
- [ ] Featurekod innehåller inga oregistrerade råa designvärden.
- [ ] Alla undantag är små, uttryckliga och tidsatta.

## Kanonisk spec

- [ ] Alla globala ID:n är unika.
- [ ] Exakt en aktiv variant finns per screen/state.
- [ ] Äldre varianter är märkta `superseded` eller `historical`.
- [ ] Produkt-UI och annotering kan renderas separat.
- [ ] Viewport, crop, component och concept räknas separat.
- [ ] Manuella totalsiffror har ersatts med genererade rapportvärden.

## Responsivitet

- [ ] Samma komponenter används över viewports.
- [ ] Layout växlar via gemensamma adaptiva primitives.
- [ ] Alla aktiva viewportskärmar testas på beslutad matrix.
- [ ] 200 % textskala ger ingen oavsiktlig clipping eller blockerad action.
- [ ] Mobil och bred layout når samma domändata och centrala handlingar.

## Tillgänglighet

- [ ] Alla interaktiva komponenter har rätt role, name och state.
- [ ] Alla stateful controls exponerar state.
- [ ] Faktisk träffyta möter beslutat minimum.
- [ ] Fokus, tangentbord, modal trap och focus return är testade.
- [ ] Dynamiska states har beslutad live-regionstrategi.
- [ ] Reduced motion finns där rörelse används.
- [ ] VoiceOver och TalkBack är `passed` eller ärligt `not run`.

## Teman och visuell kvalitet

- [ ] Light och dark kommer från samma semantiska tokens.
- [ ] Samtliga text-/kontrollpar klarar beslutad kontrastpolicy.
- [ ] Inga dataskalepar faller utanför verifieringen.
- [ ] En token- eller komponentändring kan visas slå igenom överallt utan screen edits.
- [ ] Golden-/screenshotdiff visar att refaktoreringen inte oavsiktligt ändrat varumärkesuttrycket.

## Migrering

- [ ] Ny kod kan inte använda deprecated theme-API.
- [ ] Alla legacyanvändningar är inventerade.
- [ ] Migrationssteg och rollback är dokumenterade.
- [ ] `AppColors`/`AppTextStyles` har borttagningskriterium.

---

# 21. Bevisprov som ska demonstreras

Innan du påstår att målet är nått ska du genomföra och dokumentera följande prov:

## Prov A — global knappändring

Ändra knappens control radius i den normativa källan. Visa att:

- komponentkatalogen uppdateras;
- alla relevanta specskärmar uppdateras;
- Fluttertoken/theme uppdateras;
- ingen featurevy eller screen composition behöver redigeras.

Återställ därefter värdet.

## Prov B — dark mode

Ändra en semantisk dark-mode-token och visa samma kedja utan lokala skärmändringar. Återställ.

## Prov C — lång svensk text

Kör minst tre centrala komponenter med:

- normal text;
- mycket lång svensk text;
- 200 % textskala.

Visa att komponenterna växer eller reflowar enligt kontrakt.

## Prov D — ny komponentstate

Lägg till ett state i en komponentkälla och visa att schema, katalog, tester och implementation kräver att state hanteras. Ta bort provstate efter demonstrationen.

## Prov E — förbjudet råvärde

Lägg till ett avsiktligt rått hexvärde och en rå `fontSize` i en featurefixture. Visa att huvudverifieringen faller. Ta bort fixturefelet.

## Prov F — dubblett-ID

Lägg till ett avsiktligt dubblett-ID i två olika specfiler. Visa att global verifiering faller. Ta bort fixturefelet.

---

# 22. Hur du ska rapportera resultatet

När arbetet är färdigt ska din slutrapport börja med:

1. **Resultat:** klart, delvis klart eller blockerat.
2. **Vad som nu är den normativa källan.**
3. **Vilka filer som skapats eller ändrats.**
4. **Vilka gamla källor som är deprecated/superseded.**
5. **Exakt verifieringskommando och faktiskt resultat.**
6. **Vilka tester som är `passed`, `failed` respektive `not run`.**
7. **Kvarvarande beslut som kräver Malins ställningstagande.**

Rapportera inte “allt grönt” om en enda tillämplig kontroll är `failed` eller inte har körts. `Not run` ska stå uttryckligen.

---

# Slutlig avsikt

När detta arbete är klart ska Butlery inte längre vara 300 skärmar som råkar se ungefär likadana ut.

Det ska vara:

```text
ett tokensystem
+ ett typat komponentbibliotek
+ ett litet antal återanvändbara patterns och layouts
+ deklarativa skärmkompositioner
+ featurekod som äger produktlogiken
+ en verifieringskedja som hindrar designen från att glida
```

Det är den arkitekturen — inte antalet ritade skärmar — som avgör om Butlery kan underhållas centralt.
