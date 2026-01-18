# Butlery – Komplett Designspecifikation v5.1

**Syfte:** Detta dokument är den enda källan Claude Code behöver för att implementera Butlerys design i Flutter. All information är extraherad från mockups och konsoliderad här.

**Grundregel:** Om något inte specificeras här – välj det mest neutrala alternativet och dokumentera antagandet. Skapa aldrig nya designmönster, färger eller illustrationer.

---

## 0. Mockup-referens

Mockups finns i `docs/design/mockups/`. Använd dessa för visuell QA vid behov:

| Fil | Innehåll | Relevanta sektioner |
|-----|----------|---------------------|
| `01-allergen-status.png` | Allergen trevärd logik (info-skärm) | 3.16, 4.10 |
| `02-loading-och-toasts.png` | Loading states + toast-varianter (4 skärmar) | 3.9, 5.1 |
| `03-empty-states.png` | Tom recept/inköp/meny (3 skärmar) | 5.2 |
| `04-login.png` | Inloggningsskärm | 4.1 |
| `05-inkopslista.png` | Inköpslista med kategorier och checkboxar | 3.10, 3.11, 4.5 |
| `06-meny.png` | Min meny med måltidssektioner | 4.4 |
| `07-import-error.png` | Import misslyckades | 4.9 |
| `08-import-progress.png` | Import pågår (progress stepper) | 3.15, 4.8 |
| `09-import-url.png` | URL-input för import | 4.7 |
| `10-lagg-till.png` | Lägg till-grid (4 alternativ) | 4.6 |
| `11-receptdetalj.png` | Receptvy med ingredienser | 4.3 |
| `12-recept-lista.png` | Mina recept (lista med kort) | 3.5, 4.2 |
| `13-gronsaksguide.png` | Illustration → kontext-mappning | 2.2 |

---

## 1. Design Tokens

### 1.1 Färgpalett

#### Primära färger
| Namn | Hex | Användning |
|------|-----|------------|
| `blue` | `#0038FF` | Recept-sektion, primära CTA, länkar |
| `cream` | `#F7F3EB` | App-bakgrund (alla skärmar) |
| `creamDark` | `#E8E2D6` | Borders, separatorer, inaktiva element |
| `white` | `#FFFFFF` | Kort, inputs, modaler |
| `black` | `#1A1A1A` | Primär text |
| `charcoal` | `#333333` | Sekundär text, toast-bakgrund |
| `grey` | `#666666` | Tertiär text |
| `greyLight` | `#999999` | Placeholder-text, inaktiva labels |
| `greyLighter` | `#BBBBBB` | Disabled states |
| `border` | `#CCCCCC` | Input borders, checkbox borders |

#### Sektionsfärger (accent per flik)
| Namn | Hex | Sektion |
|------|-----|---------|
| `blue` | `#0038FF` | Recept |
| `wine` | `#8B1538` | Meny |
| `orange` | `#F28B50` | Inköp |
| `coral` | `#E85A50` | Lägg till |

#### Semantiska färger
| Namn | Hex | Användning |
|------|-----|------------|
| `success` | `#2D5A4A` | Success states, "FREE" allergen-chips |
| `warning` | `#F28B50` | Varningar (samma som orange) |
| `error` | `#DC3545` | Error states, "CONTAINS" allergen-chips |
| `info` | `#0038FF` | Info-meddelanden (samma som blue) |

#### Kategori-headers (Inköpslista)
| Kategori | Bakgrund | Text |
|----------|----------|------|
| Kött & Fisk | `#8B1538` (wine) | white |
| Mejeri | `#F2C94C` (guld) | black |
| Grönsaker | `#2D5A4A` (success/green) | white |
| Frukt | `#F28B50` (orange) | white |
| Skafferi | `#333333` (charcoal) | white |

### 1.2 Typografi

**Font-familj:** DM Sans (alla vikter)

| Stil | Storlek | Vikt | Övrigt |
|------|---------|------|--------|
| Header (H1) | 40px | 800 | uppercase, letter-spacing: -1px, line-height: 0.95 |
| Section label | 11px | 700 | uppercase, letter-spacing: 1px |
| Body | 14-15px | 400/500 | line-height: 1.4 |
| Body emphasis | 14-15px | 600 | - |
| Meta/small | 11-13px | 400/500 | - |
| Button | 14px | 600 | - |
| Button large | 16px | 700 | - |
| Chip | 12px | 600 | - |
| Chip small | 11px | 600 | - |
| Nav label | 12px | 600 | - |

### 1.3 Spacing & Layout

| Token | Värde | Användning |
|-------|-------|------------|
| `screenPaddingH` | 20px | Horisontell padding på alla skärmar |
| `navHeight` | 64px | Bottom navigation höjd |
| `bottomActionHeight` | 72px | Bottom action bar min-height |
| `safeAreaBottom` | 16px | Extra buffer under nav |
| `headerPaddingTop` | 56px | Padding ovanför header-titel |
| `headerPaddingBottom` | 16px | Padding under header-titel |
| `sectionGap` | 24px | Mellanrum mellan sektioner |
| `cardGap` | 12px | Mellanrum mellan kort i lista |
| `chipGap` | 8px | Mellanrum mellan filter chips |

### 1.4 Border Radius

| Token | Värde | Användning |
|-------|-------|------------|
| `radiusSmall` | 4px | Inputs, chips, små knappar |
| `radiusMedium` | 8px | Kort, toast |
| `radiusLarge` | 16px | Stora kort, modaler |
| `radiusRound` | 50% | Avatars, runda knappar |

### 1.5 Shadows

| Namn | Värde |
|------|-------|
| `cardShadow` | `0 2px 8px rgba(0,0,0,0.08)` |
| `toastShadow` | `0 4px 12px rgba(0,0,0,0.15)` |
| `modalShadow` | `0 8px 24px rgba(0,0,0,0.2)` |

---

## 2. Illustrationer

### 2.1 Asset-katalog

**Bas-sökväg:** `assets/illustrations/`

| ID | Sökväg | Typ |
|----|--------|-----|
| `pea_pod` | `pea/tomartskida.png` | Statisk |
| `pea_frame_1` | `pea/arta1.png` | Animation frame |
| `pea_frame_2` | `pea/arta2.png` | Animation frame |
| `pea_frame_3` | `pea/arta3.png` | Animation frame |
| `pea_frame_4` | `pea/arta4.png` | Animation frame |
| `pepper` | `paprika.png` | Statisk |
| `tomato` | `tomat.png` | Statisk |
| `carrot` | `morot.png` | Statisk |
| `beetroot` | `rodbeta.png` | Statisk |
| `broccoli` | `broccoli.png` | Statisk |

### 2.2 Användningsmappning

| Illustration | Primär användning | Sekundär användning |
|--------------|-------------------|---------------------|
| **Ärtskida (animation)** | Loading states, App-logo | - |
| **Paprika** | Success toast, Receptdetalj hero placeholder | Watermark: Recept-header |
| **Tomat** | Error states, Empty: Meny | Watermark: Lägg till |
| **Morot** | Empty: Inköp | Watermark: Inköp-header |
| **Rödbeta** | Empty: Recept | Watermark: Meny-header |
| **Broccoli** | Alternativ decoration | - |

### 2.3 Ärtskida-animation

```
Loop: arta1 → arta2 → arta3 → arta4 → (repeat)
Timing: 140ms per frame
Total loop: 560ms
```

**Användning:**
- Loading recept: 1.6s (snabb)
- Generera meny: 3s+ (full animation tills klar)
- Import: Spela tills steg är klart

### 2.4 Rendering-regler

```dart
Image.asset(
  path,
  fit: BoxFit.contain,
  filterQuality: FilterQuality.high,
  gaplessPlayback: true,
)

// Dekorativa bilder ska exkluderas från semantics:
ExcludeSemantics(
  child: Image.asset(...)
)
```

### 2.5 Watermark-specifikation

| Egenskap | Värde |
|----------|-------|
| Opacity | 0.11 |
| Storlek | 130×130 (default) |
| Position | Positioned, right: 5px, top: ~55% av header-höjd |
| Z-index | Bakom all text och interaktiva element |

---

## 3. Komponenter

### 3.1 Bottom Navigation

```
┌─────────────────────────────────────┐
│  [icon]    [icon]    [icon]   [icon]│
│  Recept     Meny     Inköp   Lägg   │
│                              till   │
└─────────────────────────────────────┘
```

| Egenskap | Värde |
|----------|-------|
| Höjd | 64px |
| Bakgrund | white |
| Border top | 1px creamDark |
| Ikon-storlek | 22×22 |
| Ikon stroke width | 2 |
| Label font | 12px / 600 |
| Gap ikon-label | 4px |
| Inaktiv färg | greyLight (#999999) |

**Aktiv färg per flik:**
- Recept: blue (#0038FF)
- Meny: wine (#8B1538)
- Inköp: orange (#F28B50)
- Lägg till: coral (#E85A50)

**Ikoner (Lucide eller motsvarande):**
- Recept: `grid-2x2` eller `layout-grid`
- Meny: `calendar` eller `square`
- Inköp: `shopping-cart`
- Lägg till: `plus`

### 3.2 Page Header

```
┌─────────────────────────────────────┐
│                            [Avatar] │
│  HEADER                             │
│  TITEL          [watermark behind]  │
│  Subtitle text                      │
└─────────────────────────────────────┘
```

| Egenskap | Värde |
|----------|-------|
| Padding | 56px 20px 16px 20px |
| Titel | 40px / 800 / uppercase |
| Letter-spacing | -1px |
| Line-height | 0.95 |
| Titel-färg | Sektionsfärg |
| Subtitle | 13px / 400 / greyLight |

**Header med actions (Meny, Inköp):**
```
┌─────────────────────────────────────┐
│  HEADER        [⬇️] [💾] [📤]      │
│  TITEL                              │
│  12 recept planerade                │
└─────────────────────────────────────┘
```

Action buttons: 40×40, icon 20×20, transparent bakgrund

### 3.3 Sökfält

```
┌─────────────────────────────────────┐
│  🔍  Sök recept...                  │
└─────────────────────────────────────┘
```

| Egenskap | Värde |
|----------|-------|
| Margin | 0 20px 12px |
| Padding | 14px 16px |
| Bakgrund | white |
| Border | 1px creamDark |
| Radius | 4px |
| Ikon | 18×18, grey |
| Gap ikon-text | 10px |
| Placeholder | 14px, greyLight |

### 3.4 Filter Chips

**Container:**
- Horisontell scroll
- Gap: 8px
- Padding: 0 20px 16px

**Chip (normal):**
| State | Bakgrund | Text | Border |
|-------|----------|------|--------|
| Inactive | transparent | charcoal | 1px border (#CCCCCC) |
| Active | sektionsfärg | white | none |

| Egenskap | Värde |
|----------|-------|
| Padding | 10px 16px |
| Font | 12px / 600 |
| Radius | 4px |

**Chip (small variant):**
- Padding: 6px 10px
- Font: 11px / 600

### 3.5 Recipe Card (lista)

```
┌─────────────────────────────────────┐
│ [img]  Krämig kycklingpasta         │
│ 72×72  Med soltorkade tomater       │
│        25 min · 4 portioner · ⭐ 4.8│
├─────────────────────────────────────┤
```

| Egenskap | Värde |
|----------|-------|
| Padding | 12px 20px |
| Bakgrund | transparent (på cream) |
| Border bottom | 1px creamDark |
| Bild | 72×72, radius 4px |
| Gap bild-text | 12px |
| Titel | 15px / 600 / black |
| Subtitle | 13px / 400 / grey |
| Meta | 12px / 400 / greyLight |
| Rating star | #F2C94C |

### 3.6 Section Header

```
MIDDAG
═══════ (3px linje i sektionsfärg)
```

| Egenskap | Värde |
|----------|-------|
| Label | 11px / 700 / uppercase |
| Letter-spacing | 1px |
| Text-färg | charcoal eller sektionsfärg |
| Underline | 3px höjd, sektionsfärg, 40px bred |
| Margin bottom | 12px |

### 3.7 Buttons

#### Primary Button
| Egenskap | Värde |
|----------|-------|
| Bakgrund | sektionsfärg |
| Text | white |
| Padding | 14px 20px |
| Font | 14px / 600 |
| Radius | 4px |
| Min-width | full-width i de flesta fall |

#### Secondary Button (Outline)
| Egenskap | Värde |
|----------|-------|
| Bakgrund | transparent |
| Text | sektionsfärg |
| Border | 2px sektionsfärg |
| Padding | 12px 18px (kompensera för border) |

#### Large Button
- Padding: 18px 24px
- Font: 16px / 700

#### Icon Button
| Egenskap | Värde |
|----------|-------|
| Storlek | 40×40 (standard), 48×48 (large) |
| Ikon | 20×20 |
| Bakgrund | transparent eller sektionsfärg |
| Radius | 4px eller 50% |

### 3.8 Avatar

| Storlek | Diameter | Text |
|---------|----------|------|
| Small | 32px | 11px / 700 |
| Medium | 40px | 14px / 700 |
| Large | 80px | 28px / 700 |

- Form: Cirkel (radius 50%)
- Bakgrund: blue (default), kan vara wine/coral/green/orange
- Text: white, uppercase initialer (max 2)

### 3.9 Toast

```
┌─────────────────────────────────────┐
│  [🫑]  Receptet har sparats!        │
└─────────────────────────────────────┘
```

| Typ | Bakgrund | Ikon |
|-----|----------|------|
| Success | charcoal (#333333) | Paprika (wiggle-animation) |
| Error | coral (#E85A50) | Tomat |

| Egenskap | Värde |
|----------|-------|
| Padding | 16px 20px |
| Radius | 8px |
| Text | 14px / 500 / white |
| Ikon | 24×24 |
| Gap | 12px |
| Position | 16px ovan bottom nav |
| Shadow | toastShadow |
| Duration | 3 sekunder |

### 3.10 Checkbox (Inköpslista)

```
Unchecked: [ ]  Kycklingfilé, 400 g
Checked:   [✓]  S̶m̶ö̶r̶,̶ ̶2̶5̶0̶ ̶g̶
```

| State | Box | Text |
|-------|-----|------|
| Unchecked | border 2px #CCCCCC, white bg | black, normal |
| Checked | bg orange, white checkmark | greyLight, strikethrough |

| Egenskap | Värde |
|----------|-------|
| Box storlek | 22×22 |
| Radius | 4px |
| Checkmark stroke | 3px, white |
| Row padding | 12px 20px |
| Row border | 1px bottom creamDark |
| Gap | 12px |

### 3.11 Category Header (Inköpslista)

```
┌─────────────────────────────────────┐
│  KÖTT & FISK                      3 │
└─────────────────────────────────────┘
```

| Egenskap | Värde |
|----------|-------|
| Padding | 10px 20px |
| Font | 11px / 700 / uppercase |
| Letter-spacing | 1px |
| Text | white (eller black för guld-bg) |
| Count | Samma stil, högerställd |

### 3.12 Dropdown / Select

```
┌─────────────────────────────────┐ ┌────┐
│  Alla varor                   ▼ │ │ + │
└─────────────────────────────────┘ └────┘
```

| Egenskap | Värde |
|----------|-------|
| Padding | 12px 16px |
| Bakgrund | white |
| Border | 1px creamDark |
| Radius | 4px |
| Font | 14px / 500 |
| Chevron | 16×16, greyLight |
| Flex | 1 (tar tillgängligt utrymme) |

**Ny lista-knapp:**
- 48×48
- Bakgrund: orange
- Ikon: plus, 20×20, white
- Radius: 4px

### 3.13 Input Field

```
E-post
┌─────────────────────────────────────┐
│  din@email.se                       │
└─────────────────────────────────────┘
```

| Egenskap | Värde |
|----------|-------|
| Label | 13px / 500 / charcoal, margin-bottom 8px |
| Padding | 16px |
| Bakgrund | white |
| Border | 1px creamDark |
| Border (focus) | 1px blue |
| Radius | 4px |
| Font | 15px / 400 |
| Placeholder | greyLight |

### 3.14 Bottom Action Bar

```
┌─────────────────────────────────────┐
│                                     │
│    [ Lägg till i inköpslista ]      │
│                                     │
└─────────────────────────────────────┘
```

| Egenskap | Värde |
|----------|-------|
| Position | Fixed, ovan bottom nav |
| Min-height | 72px |
| Padding | 12px 20px |
| Bakgrund | white |
| Border top | 1px creamDark |
| Button | Full-width primary |

### 3.15 Progress Stepper (Import)

```
  ✓ Hämtar sidan
  ◉ Analyserar recept    (spinner)
  ○ Taggar ingredienser  (väntande)
```

| State | Ikon | Text |
|-------|------|------|
| Completed | ✓ (checkmark i cirkel, success-färg) | black |
| Active | Spinner (animerad) | black |
| Pending | ○ (tom cirkel, greyLight) | greyLight |

| Egenskap | Värde |
|----------|-------|
| Cirkel storlek | 24×24 |
| Gap cirkel-text | 12px |
| Vertical gap | 16px |
| Text | 14px / 500 |

### 3.16 Allergen Chips (Receptdetalj)

Tre-värd logik: FREE, CONTAINS, UNKNOWN

| Status | Prefix | Bakgrund | Text | Border |
|--------|--------|----------|------|--------|
| FREE | ✓ | success (#2D5A4A) light bg | success | success |
| CONTAINS | ⚠ | error light bg (#FDE8E8) | error (#DC3545) | none |
| UNKNOWN | ? | greyLighter bg | charcoal | none |

```
[✓ Laktosfri] [✓ Äggfri] [? Glutenfri] [⚠ Nötter]
```

| Egenskap | Värde |
|----------|-------|
| Padding | 6px 12px |
| Font | 12px / 600 |
| Radius | 4px |
| Gap | 8px |

**Kritiskt:** Filtrera med `status == FREE`, aldrig `NOT CONTAINS`.

### 3.17 Tabs (Receptdetalj)

```
  Ingredienser     Instruktioner
  ════════════     
```

| Egenskap | Värde |
|----------|-------|
| Font | 14px / 600 |
| Active | sektionsfärg, underline 2px |
| Inactive | grey |
| Padding | 12px 0 |
| Gap | 24px |

### 3.18 Portion Adjuster

```
Portioner:  [ - ]  4  [ + ]
```

| Egenskap | Värde |
|----------|-------|
| Buttons | 36×36, border 1px creamDark, radius 4px |
| Icon | 16×16 |
| Number | 16px / 600 |
| Gap | 12px |

### 3.19 Ingredient Row

```
400 g      kycklingfilé
300 g      pasta (penne)
50 g       ⚠ pinjenötter
```

| Egenskap | Värde |
|----------|-------|
| Mängd | 13px / 500 / grey, width 60px |
| Ingrediens | 14px / 400 / black |
| Allergen-varning | ⚠ error-färg före text |
| Row padding | 8px 0 |
| Border | 1px bottom creamDark (mellan rader) |

---

## 4. Skärmspecifikationer

### 4.1 Login

**Header:**
- Ärtskida-logo: 80×80, centrerad
- "Butlery": 32px / 700
- Tagline: "Dina recept. Resten löser sig." 14px / 400 / grey

**Form:**
- E-post input
- Lösenord input (obscured)
- "Logga in" button (primary, blue, full-width)
- "Glömt lösenord?" link (blue, centrerad)
- "Har du inget konto? Skapa konto" (grey + blue link)

**Layout:**
- Bakgrund: cream
- Vertical spacing: 24px mellan sektioner

### 4.2 Mina Recept (Recept-fliken)

**Header:**
- Titel: "MINA RECEPT" (blue)
- Subtitle: "152 recept i din samling"
- Avatar: Höger, 40px
- Watermark: Ärtskida + morot, opacity 0.11

**Content:**
- Sökfält
- Filter chips: [Alla] [Favoriter] [Middag] [Vegetariskt] ...
- Horizontal scroll indicator (grå linje under chips)
- Recipe cards lista

**Empty state:**
- Rödbeta illustration (120×120)
- "Inga recept ännu"
- "Lägg till ditt första recept genom att importera från en webbsida eller skriva det manuellt."
- [Lägg till recept] button (primary, blue)

### 4.3 Receptdetalj

**Hero:**
- Höjd: 220px
- Bakgrund: creamDark
- Illustration: Centrerad (placeholder om ingen bild)

**Overlay buttons (på hero):**
- Tillbaka: Vänster, 40×40, white bg, radius 50%
- Favorit (hjärta): Höger, 40×40, white bg
- Dela: Höger, 40×40, white bg

**Info-sektion:**
- Titel: 24px / 700 / black
- Källa: "Från ICA.se" 13px / grey
- Meta: ⏱ 25 min · 👤 4 portioner · Enkel
- Rating: ⭐⭐⭐⭐☆ (47 omdömen)
- Allergen chips (3.16)

**Tabs:** Ingredienser | Instruktioner | (Näring)

**Ingredienser-tab:**
- Portion adjuster
- Ingredient rows

**Bottom action:** "Lägg till i inköpslista"

### 4.4 Min Meny (Meny-fliken)

**Header:**
- Titel: "MIN MENY" (wine)
- Subtitle: "12 recept planerade"
- Actions: Download, Save, Share (40×40)
- Watermark: Rödbeta/tomat, opacity 0.11

**Content:**
- Sökfält: "Sök i menyn..."
- [Generera meny] button (primary, wine, full-width, med refresh-ikon)

**Meal sections:**
- MIDDAG (section header, wine underline)
  - Recipe rows med swap-ikon (refresh icon, höger)
- LUNCH
- FRUKOST

**Recipe row (meny):**
```
Kycklingwok med nudlar              [🔄]
30 min · 4 portioner
```

**Empty state:**
- Tomat illustration
- "Ingen meny ännu"
- [Generera meny] (primary)
- [Välj recept manuellt] (secondary)

### 4.5 Inköpslista (Inköp-fliken)

**Header:**
- Titel: "INKÖPS-LISTA" (orange, bindestreck för radbrytning)
- Subtitle: "23 varor · 3 avprickade"
- Actions: Download, Save, Share
- Watermark: Morot

**Controls:**
- Dropdown + Ny lista-knapp (3.12)

**Lista:**
- Category headers (3.11)
- Checkbox items (3.10)
- Grupperat per kategori

**Empty state:**
- Morot illustration
- "Inga varor ännu"
- [Lägg till vara] (primary)
- [Generera från meny] (secondary)

### 4.6 Lägg till (Lägg till-fliken)

**Header:**
- Titel: "LÄGG TILL" (coral)
- Subtitle: "Välj hur du vill lägga till"
- Watermark: Tomat

**Grid (2×2):**
```
┌─────────────┐ ┌─────────────┐
│     🔗      │ │     📷      │
│ Klistra in │ │  Ta foto    │
│   länk      │ │             │
├─────────────┤ ├─────────────┤
│     🖼      │ │     ✏️      │
│  Välj bild  │ │   Skriv     │
│             │ │  manuellt   │
└─────────────┘ └─────────────┘
```

| Egenskap | Värde |
|----------|-------|
| Card | Bakgrund coral, radius 8px |
| Ikon | 32×32, white, stroke 2 |
| Text | 14px / 600 / white |
| Gap | 12px (mellan cards) |
| Padding | 24px (inuti card) |
| Aspect ratio | ~1:1 (kvadratisk) |

### 4.7 Importera recept (under-skärm)

**Header:**
- Tillbaka-pil (vänster)
- Titel: "Importera recept" (coral, centrerad)

**URL-input:**
```
Klistra in en länk till receptet
┌─────────────────────────────────┐ ┌────┐
│ https://ica.se/recept/kramig...│ │ 📋 │
└─────────────────────────────────┘ └────┘
```

**Validering:**
- ✓ ICA.se – stöds (success-färg)
- ✗ Sidan stöds inte (error-färg)

**Buttons:**
- [Importera recept] (primary, coral)
- [Avbryt] (secondary, coral outline)

### 4.8 Import pågår

**Header:** "Importerar..." (coral)

**Animation:**
- Ärtskida-animation (stor, centrerad)

**Progress stepper (3.15):**
- ✓ Hämtar sidan
- ◉ Analyserar recept
- ○ Taggar ingredienser

**Info:** "Detta tar vanligtvis 5–10 sekunder"

**Button:** [Avbryt] (secondary)

### 4.9 Import misslyckades

**Header:** "Import misslyckades" (coral)

**Error card:**
- Bakgrund: error light (#FDE8E8)
- Padding: 32px
- Radius: 16px
- Tomat illustration (80×80)
- "Receptet gick inte att importera" (16px / 600 / coral)
- "Sidan kunde inte läsas. Kontrollera att länken är korrekt och prova igen." (14px / 400 / grey)

**Buttons:**
- [Försök igen] (primary, coral)
- [Skriv in manuellt] (secondary, coral outline)

### 4.10 Allergen-status (info-skärm)

**Header:** "ALLERGEN-STATUS" (blue)
**Subtitle:** "Trevärd logik"

**Sektioner:**

**FREE (BEVISAT FRITT)**
- Grön underline
- Chips: [✓ Glutenfri] [✓ Laktosfri] [✓ Nötfri]
- Beskrivning: "100% coverage – alla ingredienser analyserade och inga innehåller allergenen."

**CONTAINS (INNEHÅLLER)**
- Röd underline
- Chips: [⚠ Gluten] [⚠ Nötter]
- Beskrivning: "Minst en ingrediens innehåller allergenen. Tydlig varning visas."

**UNKNOWN (OSÄKERT)**
- Grå underline
- Chips: [? Glutenfri] [? Laktos]
- Beskrivning: "Coverage < 100% eller okänd ingrediens. Behandlas som osäkert – aldrig som fritt."

**Info-box:**
- Bakgrund: info light
- "Kritiskt: Filtrera med status == FREE, aldrig NOT CONTAINS."

---

## 5. Loading & Empty States

### 5.1 Loading States

| Skärm | Illustration | Text |
|-------|--------------|------|
| Recept | Ärtskida (animation) | "Laddar recept..." |
| Meny | Ärtskida (animation) | "Genererar din veckomeny..." |
| Import | Ärtskida (animation) | Progress stepper |

### 5.2 Empty States

| Skärm | Illustration | Rubrik | CTA |
|-------|--------------|--------|-----|
| Recept | Rödbeta | "Inga recept ännu" | "Lägg till recept" |
| Inköp | Morot | "Inga varor ännu" | "Lägg till vara" + "Generera från meny" |
| Meny | Tomat | "Ingen meny ännu" | "Generera meny" + "Välj recept manuellt" |

---

## 6. Animationer

### 6.1 Ärtskida (Loading)

- **Frames:** 4 (arta1–arta4)
- **Timing:** 140ms/frame
- **Loop:** Oändlig
- **Precache:** Ja, i `didChangeDependencies`

### 6.2 Paprika (Toast wiggle)

- **Trigger:** Success toast visas
- **Animation:** Kort wiggle (rotation ±5°)
- **Duration:** 400ms
- **Easing:** elasticOut

### 6.3 Transitions

| Typ | Duration | Curve |
|-----|----------|-------|
| Page push | 300ms | easeInOut |
| Modal | 250ms | easeOut |
| Toast enter | 200ms | easeOut |
| Toast exit | 150ms | easeIn |
| Checkbox | 150ms | easeInOut |

---

## 7. Responsivitet

### 7.1 Design-canvas

- Referens: 375×812 (iPhone X)
- Ska vara responsiv men bibehålla:
  - 20px sidopadding
  - 64px nav-höjd
  - Proportioner på komponenter

### 7.2 Safe Areas

```dart
SafeArea(
  child: content,
  bottom: false, // Hantera manuellt för nav
)
```

- Bottom padding = navHeight + safeAreaBottom (64 + 16 = 80px)
- Om bottom action bar: + 72px

### 7.3 Breakpoints (framtid)

| Namn | Bredd | Anpassning |
|------|-------|------------|
| mobile | < 600px | Default |
| tablet | 600-900px | 2-kolumn grid |
| desktop | > 900px | Max-width 600px, centrerad |

---

## 8. Accessibility

### 8.1 Semantics

- Dekorativa bilder: `ExcludeSemantics`
- Interaktiva element: Tydlig `semanticLabel`
- Buttons: `Semantics(button: true, label: ...)`

### 8.2 Kontrast

Alla text-bakgrund-kombinationer uppfyller WCAG AA:
- black på cream: ✓
- white på sektionsfärger: ✓
- greyLight på white: Gränsfall, endast för meta-text

### 8.3 Touch targets

- Minimum: 44×44
- Rekommenderat: 48×48

---

## 9. Implementation Checklist

### 9.1 Tokens & Theme
- [ ] Definiera alla färger i `AppColors`
- [ ] Definiera text styles i `AppTextStyles`
- [ ] Definiera spacing i `AppSpacing`
- [ ] Definiera radii i `AppRadius`

### 9.2 Bas-komponenter
- [ ] `ButleryBottomNav`
- [ ] `ButleryPageHeader`
- [ ] `ButlerySearchField`
- [ ] `ButleryButton` (primary, secondary, icon variants)
- [ ] `ButleryChip` (filter, allergen variants)
- [ ] `ButleryCard` (recipe)
- [ ] `ButleryCheckbox`
- [ ] `ButleryInput`
- [ ] `ButleryToast`
- [ ] `ButleryAvatar`

### 9.3 Illustrationer
- [ ] Enum `ButleryIllustration` med alla IDs
- [ ] `IllustrationWidget` med standard rendering
- [ ] `PeaAnimation` för ärtskida-loader
- [ ] Precaching i app start

### 9.4 Skärmar
- [ ] Login
- [ ] Recept (lista + tom)
- [ ] Receptdetalj
- [ ] Meny (lista + tom)
- [ ] Inköp (lista + tom)
- [ ] Lägg till (grid)
- [ ] Import-flöde (input → progress → success/error)

---

## 10. Antaganden och beslut

Dokumentera här om något implementeras som inte täcks av specen:

| Datum | Beslut | Motivering |
|-------|--------|------------|
| | | |

---

*Senast uppdaterad: 2026-01-18*
