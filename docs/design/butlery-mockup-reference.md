# Butlery Mockup Design Reference

Extracted from `butlery-mockup-fixad.html` (Komplett Mockup, Konsum Edition).

Phone frame: **375 x 812px** (iPhone X dimensions).
Page background: `#9A8F82` (warm gray-brown).

---

## 1. Design Tokens (CSS Custom Properties)

### Colors

| Token | Hex | Usage |
|---|---|---|
| `--green` | `#4A7C59` | Primary brand color, active states, borders, chips, badges |
| `--green-dark` | `#3D6849` | Page headers, header text, active nav, dark accents |
| `--green-light` | `#6B9B7A` | Light green accent (was `#5A8F6A` in the original mockup; realigned to `forestGreenLight`) |
| `--green-pale` | `#E8F0EA` | Subtle green backgrounds, recipe image placeholder bg, settings icon bg |
| `--green-muted` | `#526A55` | Inactive nav items, muted hero icon stroke (darkened from `#7A9A80` for WCAG AA ≥4.6:1 on `creamDarker`; matches `greenMuted`) |
| `--rust` | `#8B5A3C` | Section titles, header accent stripe, card bottom border, add-option bg |
| `--rust-light` | `#A77B5E` | Recipe card bottom border (was `#A67B5B`; realigned to `rustLight`) |
| `--leather` | `#6B4A2C` | (defined, not directly used in mockup screens) |
| `--cream` | `#F8F4E8` | Phone screen background, header text color, button text, bottom sheet bg, dialog bg |
| `--cream-dark` | `#E8E2D6` | Bottom nav bg, tab border, portion adjuster bg, input border, ingredient row divider |
| `--cream-darker` | `#D8D2C6` | Sheet handle, toggle track inactive, step checkbox border, filter toggle border |
| `--white` | `#FFFFFF` | Card backgrounds, search box bg, input bg, shopping items |
| `--charcoal` | `#2C2C2C` | Image preview background |
| `--text` | `#1A1A1A` | Primary text color |
| `--text-light` | `#666666` | Secondary text, descriptions, mockup labels, rating count |
| `--text-muted` | `#999999` | Placeholder text, muted labels, chevrons |
| `--error` | `#C44536` | Error states, "contains" badges, destructive buttons, ingredient warnings |
| `--warning` | `#D4A03C` | Rating stars, dairy category header bg |
| `--success` | `var(--green)` | Success states (aliases green) |

> **Source of truth for implementation:** `lib/theme/app_colors.dart`. Where the
> original mockup HTML and the code diverge, the code wins — several values above
> were darkened/renamed for WCAG AA contrast (`--green-muted`, `--green-light`,
> `--rust-light`) and these rows now reflect `app_colors.dart`, not the original
> mockup hex.
>
> **Cream scale — intentional deviation (do not "fix"):** the code's cream ramp
> is `cream #F8F4E8` → `creamDark #F0EAD6` → `creamDarker #E8E2D6` and is an
> [accepted deviation](../../.claude/rules/accepted-deviations.md) — deliberately
> *not* realigned to the mockup. Note the naming offset: the mockup's
> `--cream-dark` (`#E8E2D6`) corresponds to the code's `creamDarker`, and the
> code's `creamDark` (`#F0EAD6`) has no mockup token. The cream rows below are
> kept at their mockup values for historical reference only — use the code names.

### Derived/Inline Colors

| Value | Usage |
|---|---|
| `rgba(255,255,255,0.15)` | Icon button bg in header |
| `rgba(255,255,255,0.2)` | Icon button border in header |
| `rgba(255,255,255,0.6)` | Header subtitle text |
| `rgba(0,0,0,0.4)` | Bottom sheet overlay |
| `rgba(0,0,0,0.5)` | Dialog overlay |
| `rgba(0,0,0,0.25)` | Phone frame box-shadow |
| `rgba(0,0,0,0.2)` | FAB box-shadow, toast shadow |
| `rgba(139, 90, 60, 0.08)` | Section header bg tint |
| `rgba(212, 160, 60, 0.12)` | Rating badge bg |
| `rgba(212, 160, 60, 0.25)` | Rating badge border |
| `rgba(74, 124, 89, 0.12)` | Free dietary badge bg |
| `rgba(74, 124, 89, 0.15)` | Free allergy badge bg |
| `rgba(196, 69, 54, 0.1)` | Contains dietary badge bg |
| `rgba(196, 69, 54, 0.12)` | Contains allergy badge bg |
| `rgba(102, 102, 102, 0.1)` | Unknown dietary badge bg |
| `rgba(102, 102, 102, 0.12)` | Unknown allergy badge bg |
| `rgba(248, 244, 232, 0.9)` | Loading overlay bg (cream with 90% opacity) |

---

## 2. Typography

### Font Families

| Family | Weight Range | Usage |
|---|---|---|
| **Josefin Sans** | 300, 400, 500, 600, 700 | Brand name, page titles, section labels, empty state titles, recipe main title, dialog title, sheet title, profile name, form title, simple header title, mockup labels |
| **Space Grotesk** | 300, 400, 500, 600, 700 | Body text, all UI text, buttons, form inputs, descriptions |

### Type Scale

| Element | Font | Size | Weight | Letter-Spacing | Transform | Line-Height |
|---|---|---|---|---|---|---|
| Doc title (brand) | Josefin Sans | 48px | 300 | 12px | lowercase | -- |
| Page header title | Josefin Sans | 32px | 600 | 2px | lowercase | 1.1 |
| Profile name | Josefin Sans | 24px | 600 | -- | -- | -- |
| Recipe main title | Josefin Sans | 24px | 600 | 1px | -- | -- |
| Form title | Josefin Sans | 20px | 600 | 1px | lowercase | -- |
| Empty state title | Josefin Sans | 20px | 600 | 1px | lowercase | -- |
| Simple header title | Josefin Sans | 18px | 600 | 1px | lowercase | -- |
| Sheet title | Josefin Sans | 18px | 600 | -- | -- | -- |
| Dialog title | Josefin Sans | 18px | 600 | -- | -- | -- |
| Error title | Josefin Sans | 18px | 600 | -- | -- | -- |
| Loading overlay text | Space Grotesk | 16px | -- | -- | -- | -- |
| Recipe card title | Space Grotesk | 15px | 600 | -- | -- | -- |
| Menu item title | Space Grotesk | 15px | 600 | -- | -- | -- |
| Settings item text | Space Grotesk | 15px | -- | -- | -- | -- |
| Form input | Space Grotesk | 15px | -- | -- | -- | -- |
| Button text | Space Grotesk | 14px | 600 | -- | -- | -- |
| Button large | Space Grotesk | 15px | 600 | -- | -- | -- |
| Search box text | Space Grotesk | 14px | -- | -- | -- | -- |
| Input field | Space Grotesk | 14px | -- | -- | -- | -- |
| Ingredient row | Space Grotesk | 14px | -- | -- | -- | -- |
| Step text | Space Grotesk | 14px | -- | -- | -- | 1.5 |
| Empty state desc | Space Grotesk | 14px | -- | -- | -- | 1.5 |
| Error desc | Space Grotesk | 14px | -- | -- | -- | 1.5 |
| Toast text | Space Grotesk | 14px | 500 | -- | -- | -- |
| Dialog message | Space Grotesk | 14px | -- | -- | -- | 1.5 |
| Profile email | Space Grotesk | 14px | -- | -- | -- | -- |
| Save button | Space Grotesk | 14px | 600 | -- | -- | -- |
| Avatar initials | Space Grotesk | 14px | 700 | -- | -- | -- |
| Profile avatar initials | Josefin Sans | 36px | 600 | -- | -- | -- |
| Profile stat value | Space Grotesk | 24px | 600 | -- | -- | -- |
| Filter toggle text | Space Grotesk | 13px | -- | -- | -- | -- |
| Recipe meta item | Space Grotesk | 13px | -- | -- | -- | -- |
| Recipe rating | Space Grotesk | 13px | -- | -- | -- | -- |
| Portion label | Space Grotesk | 13px | -- | -- | -- | -- |
| Toggle label | Space Grotesk | 13px | -- | -- | -- | -- |
| Loading subtext | Space Grotesk | 13px | -- | -- | -- | -- |
| Settings help text | Space Grotesk | 13px | -- | -- | -- | -- |
| Add option text | Space Grotesk | 13px | 600 | -- | -- | -- |
| Tab text | Space Grotesk | 13px | 600 | -- | -- | -- |
| Chip text | Space Grotesk | 12px | 600 | -- | -- | -- |
| Recipe card desc | Space Grotesk | 12px | -- | -- | -- | -- |
| Recipe source | Space Grotesk | 12px | -- | -- | -- | -- |
| Menu item meta | Space Grotesk | 12px | -- | -- | -- | -- |
| Settings item desc | Space Grotesk | 12px | -- | -- | -- | -- |
| Form hint | Space Grotesk | 12px | -- | -- | -- | -- |
| Form error | Space Grotesk | 12px | -- | -- | -- | -- |
| Portion note | Space Grotesk | 12px | -- | -- | -- | -- |
| Step desc | Space Grotesk | 12px | -- | -- | -- | -- |
| Header subtitle | Space Grotesk | 12px | -- | -- | -- | -- |
| Portion scaler header | Space Grotesk | 12px | 600 | 1px | uppercase | -- |
| Header count badge | Space Grotesk | 11px | 600 | 1px | -- | -- |
| Section label | Josefin Sans | 10px | 700 | 3px | uppercase | -- |
| Category header | Space Grotesk | 11px | 700 | 2px | uppercase | -- |
| Section count | Space Grotesk | 11px | -- | -- | -- | -- |
| Dietary badge text | Space Grotesk | 11px | 600 | -- | -- | -- |
| Allergy badge text | Space Grotesk | 11px | 500 | -- | -- | -- |
| Profile stat label | Space Grotesk | 11px | -- | 1px | uppercase | -- |
| Section title (doc) | Josefin Sans | 11px | 700 | 4px | uppercase | -- |
| Mockup label | Josefin Sans | 11px | 600 | 2px | lowercase | -- |
| Form label | Space Grotesk | 11px | 600 | 1px | uppercase | -- |
| Input label | Space Grotesk | 11px | 600 | 1px | uppercase | -- |
| Settings section title | Space Grotesk | 11px | 600 | 1px | uppercase | -- |
| Sheet section title | Space Grotesk | 11px | 600 | 1px | uppercase | -- |
| Nav item text | Josefin Sans | 10px | 500 | 1px | lowercase | -- |
| Rating star | Space Grotesk | 10px | -- | -- | -- | -- |
| Meal type header | Josefin Sans | 11px | 700 | 3px | uppercase | -- |

---

## 3. Screen Inventory

### Section: Recept

#### 3.1 receptlista
- **Header**: Dark green (`--green-dark`) page header with title "dina recept" (Josefin Sans 32px, lowercase), recipe count badge "48 recept" (cream bg, green-dark text), avatar "ML" (rust bg, cream text).
- **Search**: Search box with green border, rust bottom accent, search icon, placeholder "sok bland recepten..."
- **Chips**: Horizontal scrollable chip row -- "Alla" (filled green), "Favoriter", "Under 30 min", "Vegetariskt" (outline chips).
- **Section header**: "Senast tillagda" with left rust border accent, "5 recept" count.
- **Recipe cards** (x4): White bg, 5px green left border, 3px rust-light bottom border. Each has: 56x56 image placeholder (green-pale bg), title (15px 600), description (12px), meta row (time, portions, rating badge with star).
- **Bottom nav**: Active = "recept" (green-dark, rust underline). Items: recept, meny, inkop, lagg till.

#### 3.2 tom samling (empty collection)
- **Header**: Same as receptlista but without count badge.
- **Empty state**: Centered broccoli illustration (120x120), title "inga recept annu" (Josefin Sans 20px), description text, full-width primary CTA "Lagg till recept".
- **Bottom nav**: recept active.

#### 3.3 inga traffar (no search results)
- **Header**: Same as receptlista with "48 recept" badge.
- **Search**: Active search with text "vegetarisk pad thai".
- **Empty state**: Champinjon illustration, title "inga traffar", description, secondary button "Rensa sokning".
- **Bottom nav**: recept active.

#### 3.4 receptdetalj (recipe detail)
- **Hero image**: 200px height, green-pale bg, broccoli image. Overlay buttons at top: back arrow (left), heart + share (right). Buttons are 40x40 cream squares.
- **Title section**: White bg with 3px green bottom border. Recipe title "kramig kycklingpasta" (Josefin Sans 24px, green-dark). Source "Fran ICA.se" (12px muted). Meta row: clock icon + "25 min", people icon + "4 port", "Enkel". Star rating "5 stars (47 omdomen)".
- **Dietary badges**: Row of allergy badges -- "Laktosfri" (free/green), "Aggfri" (free/green), "Glutenfri?" (unknown/gray), "Notter" (contains/red).
- **Tabs**: "Ingredienser" (active, green underline), "Instruktioner" (muted).
- **Portion adjuster**: Cream-dark bg strip, "Portioner:" label, minus/value(4)/plus controls.
- **Ingredient list**: Rows with amount (70px, bold green-dark) + name. "pinjenotter" marked with warning icon in red.
- **FAB**: Green square (48x48) with shopping cart icon, bottom-right, shadow.
- **Bottom nav**: recept active.

#### 3.5 filter (bottom sheet)
- **Backdrop**: Dimmed screen (brightness 0.7) + black overlay (0.4 opacity).
- **Bottom sheet**: Cream bg, max-height 75%. Handle bar (40x4 cream-darker, rounded). Title "Filtrera recept" (Josefin Sans 18px centered).
- **Sheet sections**:
  - "Allergener": Glutenfri (active), Laktosfri, Notfri (active), Aggfri -- filter toggles with square checkbox indicators.
  - "Kosttyp": Vegetarisk, Vegansk, Pescetarian.
  - "Tid": Under 30 min, Under 60 min.
- **Sheet actions**: "Rensa" (secondary) + "Visa 12 recept" (primary), flex-1 / flex-2 ratio.

#### 3.6 instruktioner (recipe detail, instructions tab)
- **Hero image**: Morot image, same overlay buttons as receptdetalj.
- **Title section**: "morotssoppa", source "Eget recept".
- **Tabs**: "Ingredienser" inactive, "Instruktioner" active.
- **Instruction steps**: Each step has a 28x28 square checkbox (checked = green bg + white checkmark, unchecked = cream-darker border). Checked steps show completed text (muted, line-through). 5 steps total, first 2 checked.
- **Bottom nav**: recept active.

#### 3.7 allergenbadges (allergen badge reference)
- **Header**: Smaller title "allergen-badges" (24px).
- **Badge categories**: Showcases all three badge states:
  - FREE: Green tint bg, green text, checkmark icon. Shown: Glutenfri, Laktosfri, Notfri, Aggfri.
  - CONTAINS: Red tint bg, red text, triangle/warning icon (filled). Shown: Gluten, Laktos, Notter, Agg.
  - UNKNOWN: Gray tint bg, gray text, question-mark-circle icon. Shown: Gluten?, Laktos?, Notter?.
  - Dietary: Vegetarisk (free), Vegansk (free), Ej veg (contains).
- **Example recipe card**: "Kycklingpasta med graddsas" with mixed badges.
- **Bottom nav**: recept active.

### Section: Lagg till

#### 3.8 lagg till (add recipe options)
- **Header**: "lagg till recept" (32px).
- **Add grid**: 2x2 grid of square option cards:
  - "Importera lank" (rust bg, link icon)
  - "Skriv manuellt" (green bg, plus icon)
  - "Fran bild" (green bg, image icon)
  - "Scanna recept" (rust bg, camera icon)
- **Recently imported section**: Header "Nyligen importerade", one recipe card "Pasta Carbonara" from koket.se.
- **Bottom nav**: lagg till active.

#### 3.9 importera (import URL progress)
- **Form header**: Back arrow, "importera recept" title, green-dark bg with rust bottom stripe.
- **Input**: "Receptlank" label, field with URL value.
- **Progress stepper**: 4 steps with circular indicators:
  1. "Hamtar recept" -- done (green circle, checkmark)
  2. "Laser ingredienser" -- done (green circle, checkmark)
  3. "Analyserar allergener" -- current (green bordered circle, green-pale bg)
  4. "Sparar" -- pending (cream-dark bordered circle, white bg)
- **Bottom nav**: lagg till active.

#### 3.10 import fel (import error)
- **Form header**: Same as importera.
- **Error state**: Rodlok illustration (100x100), title "Receptet gick inte att importera" (error color, 18px Josefin), description text.
- **Action buttons**: "Forsok igen" (error filled), "Skriv in manuellt" (error outline).
- **Bottom nav**: lagg till active.

#### 3.11 skriv sjalv (manual recipe form)
- **Simple header**: Back button, "nytt recept" title, green-dark bg.
- **Image upload area**: 180px height, cream-dark bg, image icon + "Lagg till bild" text.
- **Form sections** (separated by cream-dark bottom borders):
  - "Titel *": text input with placeholder.
  - "Beskrivning": textarea (min-height 100px).
  - Row: "Portioner" (minus/4/plus controls) + "Tid (min)" (number input = 30).
  - "Ingredienser": Editor with drag-handle rows (hamburger icon, text input, X delete button) + "Lagg till ingrediens" add row (green plus icon).
  - "Instruktioner": Large textarea (min-height 120px).
- **Bottom action**: Fixed bar above nav with "Spara recept" primary button. White bg, 2px green top border.
- **Bottom nav**: lagg till active.

#### 3.12 foto import (photo import)
- **Simple header**: Back button, "importera foto" title.
- **Content**: Centered champinjon illustration, heading "Fotografera ett recept", description text.
- **Buttons** (stacked): "Ta ett foto" (primary, camera icon), "Valj fran galleri" (secondary, image icon).
- **Bottom nav**: lagg till active.

### Section: Meny

#### 3.13 veckomeny (weekly menu)
- **Header**: "veckans meny", count badge "Vecka 6 - 5 ratter". Action buttons: save icon, share icon (40x40 translucent white squares).
- **Search box**: "sok i menyn..."
- **Generate button**: Full-width primary large button "Generera ny meny" with refresh icon.
- **Meal type sections**:
  - "MIDDAG" header (green-pale bg, green left border, Josefin 11px uppercase): 3 menu items.
  - "LUNCH" header: 1 menu item.
- **Menu items**: White bg, 4px rust left border. Title + meta (time, portions). Right: 36x36 change/refresh button (cream-dark bg, green icon).
- **Bottom nav**: meny active.

#### 3.14 tom meny (empty menu)
- **Header**: "veckans meny" without count badge.
- **Empty state**: Artskida illustration, "ingen meny annu", description. Two buttons: "Generera meny" (primary, full-width), "Valj recept manuellt" (secondary, full-width).
- **Bottom nav**: meny active.

#### 3.15 genererar (generating menu / loading overlay)
- **Header**: "veckans meny" (visible behind overlay).
- **Loading overlay**: Cream bg 90% opacity, covers entire phone. Animated artskida pod loader (6-frame ping-pong animation, 3.1s duration), text "Genererar din veckomeny...", subtext "Hittar recept som passar dina preferenser".
- **Bottom nav**: meny active.

### Section: Inkopslista

#### 3.16 inkopslista (shopping list)
- **Header**: "inkops-lista", count "23 varor - 3 klara". Action buttons: save + share.
- **Search box**: "sok i listan..."
- **List selector row**: Dropdown "Alla varor" (white bg, cream-dark border, chevron-down) + new-list button (48x48 rust square, plus icon).
- **Category headers** (color-coded, full-width, uppercase, 11px bold):
  - "Kott & Fisk" -- rust bg, cream text, count "3"
  - "Mejeri" -- warning/gold bg, dark text, count "3"
  - "Gronsaker" -- green bg, cream text, count "4"
- **Shopping items**: White bg, 22x22 square checkbox (green border; checked = green fill + white checkmark). Checked items have strikethrough muted text.
- **Bottom nav**: inkop active.

#### 3.17 tom inkopslista (empty shopping list)
- **Header**: "inkops-lista" without count.
- **Empty state**: Morot illustration, "inkopslistan ar tom", description. Primary button "Generera veckomeny".
- **Bottom nav**: inkop active.

#### 3.18 lagg till vara (add item dialog)
- **Backdrop**: Dimmed screen (brightness 0.6) + black overlay (0.5 opacity).
- **Dialog**: Cream bg, max-width 340px, 24px padding. Title "Lagg till vara" (Josefin 18px).
- **Form fields**:
  - "Vara": text input with value "Kycklingfile".
  - Row: "Mangd" (input "400") + "Enhet" (dropdown showing "g").
  - "Kategori": dropdown with color dot indicator (red) + "Kott & Fisk".
- **Actions**: "Avbryt" (secondary/transparent) + "Lagg till" (primary/green), right-aligned.

### Section: Profil & Installningar

#### 3.19 profil (profile)
- **Profile header**: Green-dark bg, centered. Back arrow top-left.
  - Avatar: 100px circle, cream bg, Josefin 36px initials "ML" in green-dark.
  - Name "Malin Lindqvist" (Josefin 24px cream).
  - Email "malin.lindqvist@email.se" (14px green-pale).
  - Stats row: 48 Recept, 12 Menyer, 5 Vanner (value 24px bold cream / label 11px uppercase green-pale).
- **Settings sections**:
  - "Konto": Redigera profil (user icon), Allergener & Kost (shield icon, desc "Glutenfri, Notfri").
  - "App": Utseende (sun icon, desc "Ljust tema"), Notiser (bell icon).
- **Settings items**: Icon in 36x36 green-pale square + text + chevron-right.
- **Bottom nav**: No item active (accessed from avatar tap).

#### 3.20 allergener (allergen & diet preferences)
- **Simple header**: "allergener & kost".
- **Section "Mina allergener"**: Help text "Recept med dessa allergener markeras automatiskt."
  - Toggle list (vertical, full-width filter toggles with checkbox right-aligned): Gluten (active), Laktos, Notter (active), Agg, Soja, Fisk, Skaldjur.
- **Section "Kostpreferenser"**: Vegetarisk, Vegansk, Pescetarian, Halal (all inactive).
- **Bottom nav**: No specific active state (sub-page of profile).

#### 3.21 portioner (portion scaler detail)
- **Simple header**: "morotssoppa".
- **Portion scaler component**: Green-pale bg, 4px green left border.
  - Header: People icon + "Portioner" (12px bold uppercase).
  - Controls: Minus / 6 (24px bold) / Plus (40x40 buttons).
  - Note: "Skalat fran 4 till 6 portioner" (12px light).
  - Unit toggle: Track switch (active = green), label "Konvertera amerikanska enheter".
- **Ingredient list**: Scaled for 6 portions. White bg, cream-darker border. 5 rows with amounts in bold green-dark.
- **Bottom nav**: recept active.

### Section: Laddning & Feedback

#### 3.22 laddar (loading state)
- **Header**: "dina recept" (no count, no avatar).
- **Loader**: Animated artskida pod illustration (6-frame ping-pong, 80x140 container), text "Laddar recept..." (14px light).
- **Bottom nav**: recept active.

#### 3.23 toast (success toast)
- **Background**: Normal recipe list screen with search and one recipe card.
- **Toast**: Positioned absolute bottom 90px. Green-dark bg, cream text, 14px 500 weight. Checkmark icon + "Receptet sparades". Shadow 0 4px 12px black 20%.
- **Bottom nav**: recept active.

---

## 4. Component Patterns

### 4.1 Bottom Navigation Bar

- **Container**: Absolute bottom, full width. Background `--cream-dark`. Padding 8px 16px 12px. Flex with space-around.
- **Nav items**: 4 items -- recept, meny, inkop, lagg till. Each: column flex (icon above text), Josefin Sans 10px 500 lowercase, 1px letter-spacing. Color `--green-muted`, 2px transparent bottom border.
- **Active state**: Color `--green-dark`, bottom border color `--rust`.
- **Icons**: 18x18 SVG, stroke = currentColor, stroke-width 2, no fill.

### 4.2 Page Header

- **Background**: `--green-dark`. Padding 52px 20px 20px (52px top for status bar).
- **Accent stripe**: 4px `--rust` pseudo-element at bottom.
- **Title**: Josefin Sans 32px 600, `--cream`, 2px letter-spacing, lowercase, line-height 1.1.
- **Subtitle**: 12px, `rgba(255,255,255,0.6)`.
- **Count badge**: Inline-block, 4px 10px padding, cream bg, green-dark text, 11px 600, 1px letter-spacing.
- **Header actions**: Icon buttons 40x40, `rgba(255,255,255,0.15)` bg, `rgba(255,255,255,0.2)` border, 18x18 cream-stroke icons.
- **Avatar**: 40x40 square, rust bg, 14px 700 cream text, initials.

### 4.3 Simple Header

- **Layout**: Flex row, align-items flex-end, space-between. Same bg/padding/stripe as page header.
- **Title**: Josefin Sans 18px 600, cream, 1px letter-spacing, lowercase.
- **Back button**: 40x40, 24x24 cream SVG chevron-left icon.

### 4.4 Form Header

- **Layout**: Flex row, space-between, center-aligned. Same bg/padding/stripe.
- **Title**: Josefin Sans 20px 600, cream, 1px letter-spacing, lowercase.
- **Back link**: 40x40, 24x24 cream chevron-left icon.
- **Save button**: 14px 600 cream text, `rgba(255,255,255,0.15)` bg, 8px 12px padding.

### 4.5 Search Box

- **Container**: Margin 20px 16px. Padding 14px 16px. White bg.
- **Border**: 2px `--green` sides/top, 4px `--rust` bottom (distinctive double-accent).
- **Content**: Flex, 12px gap. 18x18 green-stroke search icon + placeholder text 14px `--text-muted`.

### 4.6 Chip / Filter Tag

- **Filled chip**: Padding 8px 14px, 12px 600, `--green` bg, `--cream` text, no border-radius.
- **Outline chip**: Same sizing, transparent bg, `--green-dark` text, 2px `--green` border.
- **Container**: Horizontal flex, 8px gap, 0 16px 16px padding, overflow-x auto.

### 4.7 Section Header

- **Layout**: Flex row, space-between, center-aligned.
- **Styling**: 12px 16px padding, 4px `--rust` left border, `rgba(139, 90, 60, 0.08)` bg tint. Margin 0 16px 12px.
- **Label**: Josefin Sans 10px 700, 3px letter-spacing, uppercase, `--rust`.
- **Count**: 11px `--text-light`.

### 4.8 Recipe Card

- **Container**: Margin 0 16px 12px. Padding 14px 16px. White bg. 5px `--green` left border. 3px `--rust-light` bottom border. No border-radius.
- **Image**: 56x56 square, `--green-pale` bg, centered content. No border-radius.
- **Title**: 15px 600 `--text`.
- **Description**: 12px `--text-light`.
- **Meta row**: 11px `--text-muted`, flex with 8px gap. Separator dots. Rating badge inline.
- **Rating badge**: `rgba(212,160,60,0.12)` bg, 1px `rgba(212,160,60,0.25)` border. Star `--warning` 10px + value 600 `--text-light`.

### 4.9 Menu Item

- **Container**: Flex row, space-between, center. Padding 14px 16px. Margin 0 16px 8px. White bg. 4px `--rust` left border.
- **Title**: 15px 600 `--text`.
- **Meta**: 12px `--text-light`.
- **Change button**: 36x36 square, `--cream-dark` bg, 16x16 green-stroke refresh icon.

### 4.10 Meal Type Header

- **Styling**: Padding 10px 16px, Josefin Sans 11px 700, 3px letter-spacing, uppercase, `--green-dark` text, `--green-pale` bg, 4px `--green` left border. Margin 0 16px 8px.

### 4.11 Shopping Item

- **Container**: Flex row, 12px gap, center. Padding 12px 16px. Margin 0 16px 4px. White bg. 14px text.
- **Checkbox**: 22x22 square, 2px `--green` border, no border-radius. Checked: `--green` bg + fill, 14x14 cream checkmark SVG (stroke-width 3).
- **Checked state**: Text gets `--text-muted` color + line-through.

### 4.12 Category Header (Shopping)

- **Container**: Flex row, space-between. Padding 10px 16px. 11px 700 uppercase, 2px letter-spacing. Margin 0 16px 4px.
- **Variants**: `.meat` = `--rust` bg cream text | `.dairy` = `--warning` bg dark text | `.veg` = `--green` bg cream text.

### 4.13 Dietary / Allergy Badge

- **Base**: Inline-flex, center, 4px gap. Padding 5px 10px (dietary) or 4px 10px (allergy). 11px 600/500.
- **FREE**: Green-tinted bg, `--green` text, 3px `--green` left border (dietary). Checkmark icon (stroke).
- **CONTAINS**: Red-tinted bg, `--error` text, 3px `--error` left border (dietary). Triangle/warning icon (filled).
- **UNKNOWN**: Gray-tinted bg, `--text-light` text, 3px `--text-muted` left border (dietary). Question-circle icon (stroke).
- **Icon size**: 12px (allergy) with stroke-width 2.5.

### 4.14 Button

- **Base `.btn`**: Flex center, 8px gap. Padding 14px 20px. 14px 600. No border, no border-radius.
- **Primary**: `--green` bg, `--cream` text.
- **Secondary**: Transparent bg, `--green` text, 2px `--green` border.
- **Large**: Padding 16px 24px, 15px font-size.
- **Error**: `--error` bg, white text.
- **Error outline**: Transparent bg, `--error` text + 2px border.
- **Icon**: 18x18 SVG, stroke = currentColor, stroke-width 2.

### 4.15 Add Option Card

- **Container**: 2x2 grid, 12px gap, 0 16px horizontal padding.
- **Card**: Padding 28px 16px, centered text, 13px 600, column flex with 10px gap.
- **Primary variant**: `--rust` bg, `--cream` text.
- **Secondary variant**: `--green` bg, `--cream` text (`.secondary`).
- **Icon**: 28x28 SVG, stroke currentColor, stroke-width 1.5.

### 4.16 Bottom Sheet

- **Overlay**: Absolute inset 0, `rgba(0,0,0,0.4)` bg.
- **Sheet**: Absolute bottom 0, left/right 0. `--cream` bg. No border-radius. Padding 12px 16px 24px. Max-height 70%.
- **Handle**: 40x4, `--cream-darker`, border-radius 2px, centered, margin-bottom 16px.
- **Title**: Josefin Sans 18px 600, `--text`, centered, margin-bottom 16px.
- **Section**: margin-bottom 20px. Title 11px 600 uppercase `--text-muted`.

### 4.17 Dialog

- **Overlay**: Absolute inset 0, `rgba(0,0,0,0.5)`, flex center, 24px padding.
- **Dialog box**: `--cream` bg, max-width 320px, 24px padding, no border-radius.
- **Title**: Josefin Sans 18px 600 `--text`.
- **Message**: 14px `--text-light`, line-height 1.5, margin-bottom 20px.
- **Actions**: Flex row, 12px gap, right-aligned.
- **Dialog buttons**: 10px 20px padding, 14px 500. Secondary = transparent `--text-light`. Primary = `--green` bg white text. Destructive = `--error` bg white text.

### 4.18 Toast

- **Position**: Absolute, bottom 90px, left/right 16px.
- **Styling**: `--green-dark` bg, `--cream` text, 14px 500. Flex center, 10px gap. Shadow 0 4px 12px rgba(0,0,0,0.2).
- **Icon**: 20x20 checkmark SVG.

### 4.19 Empty State

- **Container**: 60px 32px padding, centered text.
- **Icon area**: 120x120, centered, margin-bottom 20px.
- **Title**: Josefin Sans 20px 600, `--green-dark`, 1px letter-spacing, lowercase.
- **Description**: 14px `--text-light`, line-height 1.5, margin-bottom 24px.
- **CTA**: Full-width btn-primary or btn-secondary.

### 4.20 Error State

- **Container**: 48px 32px padding, centered text.
- **Icon area**: 100x100, centered, margin-bottom 20px.
- **Title**: Josefin Sans 18px 600, `--error`.
- **Description**: 14px `--text-light`, line-height 1.5, margin-bottom 24px.
- **Buttons**: Error filled + error outline, full-width stacked.

### 4.21 Loading State

- **Container**: 60px 32px padding, centered text.
- **Loader icon**: 80x140 container, 6-frame animated artskida pod (ping-pong animation, 3.1s cycle, steps(1) timing).
- **Text**: 14px `--text-light`.

### 4.22 Loading Overlay

- **Container**: Absolute inset 0, `rgba(248,244,232,0.9)` bg (cream 90%). Flex column, centered, 16px gap.
- **Loader**: Same 80x140 animated artskida pod.
- **Text**: 16px `--text`. Subtext: 13px `--text-muted`.

### 4.23 Input Field

- **Styling**: Full width, 14px 16px padding. White bg. 2px `--cream-dark` border, 3px `--green` bottom border. 14px `--text`. Placeholder `--text-muted`.

### 4.24 Form Input

- **Styling**: Full width, 12px 14px padding. White bg. 1px `--cream-darker` border. 15px `--text`. Focus: `--green` border. No border-radius.
- **Textarea variant**: min-height 100px, vertical resize.
- **Label**: 11px 600, 1px letter-spacing, uppercase, `--text-muted`, margin-bottom 8px.

### 4.25 Filter Toggle

- **Container**: Flex row, center, 8px gap. Padding 10px 14px. White bg, 1px `--cream-darker` border. 13px `--text`.
- **Active state**: `--green-pale` bg, `--green` border, `--green-dark` text.
- **Toggle indicator**: 18x18 square, 2px `--cream-darker` border. Active: `--green` bg + border, white checkmark 12px.
- **Setting variant** (`.filter-toggle--setting`): justify-content space-between, used in vertical toggle lists.

### 4.26 Portion Controls

- **Layout**: Flex row, center, 12px gap.
- **Buttons**: 36x36 square (40x40 in scaler), white bg, 2px `--green` border, 18px/20px 600 `--green` text. Hover: green bg, white text.
- **Value**: 20px/24px 700, `--green-dark` / `--text`, min-width 28px/40px, centered.

### 4.27 Ingredient Row (Display)

- **Layout**: Flex row, center, 12px gap. Padding 12px 0. 1px `--cream-dark` bottom border. 14px.
- **Amount**: 70px width, 600 weight, `--green-dark`.
- **Name**: flex 1, `--text`. Warning: `--error` color with warning emoji prefix.

### 4.28 Ingredient Editor Row

- **Container**: White bg, 1px `--cream-darker` border.
- **Row**: Flex, center, 8px gap. Padding 10px 12px. 1px `--cream-dark` bottom divider.
- **Drag handle**: 16x16 hamburger icon, `--text-muted`, cursor grab.
- **Input**: flex 1, no border, transparent bg, 14px `--text`.
- **Delete button**: 16x16 X icon, `--text-muted`, hover `--error`.
- **Add row**: 12px padding, `--green` text, 18px plus icon + "Lagg till ingrediens".

### 4.29 Instruction Step

- **Container**: Flex row, 12px gap. Padding 14px 16px. 1px `--cream-dark` bottom border.
- **Step number** (static): 28x28 square, `--green` bg, white 14px 600. No border-radius.
- **Step checkbox** (interactive): 28x28 square, 2px `--cream-darker` border. Checked: `--green` bg + border, white 16px checkmark (stroke-width 3). No border-radius.
- **Text**: 14px, line-height 1.5, `--text`. Completed: `--text-muted` + line-through.

### 4.30 Progress Stepper

- **Container**: 24px 16px padding.
- **Step**: Flex row, 14px gap, margin-bottom 20px.
- **Step icon**: 28x28 circle (border-radius 50% -- exception to square rule).
  - Done: `--green` bg, cream text, 16px checkmark (stroke-width 3).
  - Current: 3px `--green` border, `--green-pale` bg.
  - Pending: 2px `--cream-dark` border, white bg.
- **Title**: 14px 600 `--text`.
- **Description**: 12px `--text-light`.

### 4.31 Profile Header

- **Container**: `--green-dark` bg, 32px 16px padding, centered.
- **Avatar**: 100x100 circle (border-radius 50%), `--cream` bg, Josefin 36px 600 `--green-dark` initials.
- **Name**: Josefin Sans 24px 600 `--cream`.
- **Email**: 14px `--green-pale`.
- **Stats**: Flex row, 32px gap, centered. Value 24px 600 `--cream` / Label 11px uppercase 1px spacing `--green-pale`.

### 4.32 Settings List

- **Section**: 16px padding. Title 11px 600 uppercase 1px spacing `--text-muted`.
- **Item**: Flex row, space-between, center. Padding 14px 0. 1px `--cream-dark` bottom border (last: none).
- **Item icon**: 36x36 square, `--green-pale` bg, 20x20 `--green-dark` stroke icon.
- **Item text**: 15px `--text`. Description: 12px `--text-muted`.
- **Chevron**: 20x20, `--text-muted` stroke, stroke-width 2.

### 4.33 Image Upload

- **Empty state**: Full width, 180px height. `--cream-dark` bg. Centered column: 48x48 `--text-muted` image icon (stroke-width 1.5) + 14px `--text-light` text.
- **Preview**: 180px height, `--charcoal` bg. Image contained. Change button overlay bottom-right: `--cream` bg, 12px 500.

### 4.34 Toggle Switch

- **Track**: 44x24, `--cream-darker` bg, border-radius 12px. Active: `--green` bg.
- **Thumb**: 20x20 circle, white, positioned top 2px left 2px. Active: left 22px. Shadow 0 1px 3px rgba(0,0,0,0.2).
- **Label**: 13px `--text-light`.

### 4.35 Portion Scaler (Component)

- **Container**: `--green-pale` bg, 4px `--green` left border, 16px padding, 16px margin.
- **Header**: Flex, 8px gap, 12px 600 `--green-dark` uppercase 1px spacing. 16x16 people icon.
- **Controls**: Larger: 40x40 buttons, 24px value text.
- **Note**: 12px `--text-light`.
- **Unit toggle**: Separated by 1px `--cream-dark` top border, 12px margin/padding top.

### 4.36 List Selector Row (Shopping)

- **Container**: Flex row, 8px gap, 0 16px margin.
- **Selector**: Flex 1, space-between. 12px 16px padding, white bg, 2px `--cream-dark` border. 14px 500. Chevron-down icon 16x16 `--text-light`.
- **New list button**: 48x48 square, `--rust` bg, 20x20 cream plus icon.

### 4.37 FAB (Cart)

- **Position**: Absolute bottom 68px right 16px. z-index 10.
- **Styling**: 48x48 square, `--green` bg, shadow 0 4px 12px rgba(0,0,0,0.2). No border-radius.
- **Icon**: 22x22 cart SVG, white stroke, stroke-width 2.

---

## 5. Icon Inventory

All icons are inline SVGs. Stroke-based (stroke = currentColor or specified color, fill = none unless noted). Standard viewBox = "0 0 24 24".

### Navigation Icons

| Icon | SVG Description | Used In |
|---|---|---|
| **Grid (recept)** | 4 squares: rects at (3,3), (14,3), (3,14), (14,14) each 7x7 | Bottom nav |
| **Calendar (meny)** | Rect 3,4 18x16 rx2 + horizontal line y=10 | Bottom nav |
| **Cart (inkop)** | Two circles (9,21) (20,21) r=1 + cart path M1 1 h4 l2.68... | Bottom nav, FAB |
| **Plus (lagg till)** | Two lines: vertical (12,5)-(12,19) + horizontal (5,12)-(19,12) | Bottom nav, add ingredient, new list btn |

### Action Icons

| Icon | SVG Description | Used In |
|---|---|---|
| **Search** | Circle cx=11 cy=11 r=8 + line (21,21)-(16.65,16.65) | Search boxes |
| **Back/Chevron-left** | Polyline 15,18 9,12 15,6 | Headers, hero overlay |
| **Chevron-right** | Polyline 9,18 15,12 9,6 | Settings items |
| **Chevron-down** | Polyline 6,9 12,15 18,9 | Dropdowns, list selector |
| **Heart** | Path d="M20.84 4.61..." (heart shape) | Recipe detail hero |
| **Share** | 3 circles (18,5 r3)(6,12 r3)(18,19 r3) + 2 connecting lines | Recipe detail hero, header actions |
| **Checkmark** | Polyline 20,6 9,17 4,12 | Badges, checkboxes, toasts, step icons |
| **X / Close** | Two lines (18,6)-(6,18) + (6,6)-(18,18) | Delete buttons in ingredient editor |
| **Refresh** | Path "M21 2v6h-6" + arc path "M3 12a9 9 0 0 1 15-6.7L21 8" | Menu generate, change buttons |
| **Save/Document** | Path rect with folded corner + polyline for lines | Header actions |

### Content Icons

| Icon | SVG Description | Used In |
|---|---|---|
| **Clock** | Circle cx=12 cy=12 r=10 + polyline 12,6 12,12 16,14 | Recipe meta |
| **Person** | Path "M17 21v-2a4 4 0 0 0-4-4H5..." + circle cx=9 cy=7 r=4 | Recipe meta (portions) |
| **People** | Same as person + extra person path | Portion scaler header |
| **Link** | Two curved paths (chain link) | Import link option |
| **Image** | Rect 3,3 18x18 rx2 + circle 8.5,8.5 r1.5 + polyline mountain | Image upload, from-image option |
| **Camera** | Path trapezoid + circle cx=12 cy=13 r=3 | Scan recipe option, photo import |
| **Drag handle** | Two horizontal lines y=9 and y=15 | Ingredient editor |
| **Shield** | Path "M12 22s8-4 8-10V5l-8-3-8 3v7..." | Allergen settings |
| **Sun/rays** | 8 radiating lines from center (12,12) | Appearance settings |
| **Bell** | Path bell shape + path for clapper | Notification settings |
| **User** | Path + circle (person silhouette) | Profile settings |

### Badge/Status Icons

| Icon | SVG Description | Used In |
|---|---|---|
| **Checkmark (FREE badge)** | Polyline 20,6 9,17 4,12 | FREE allergy/dietary badges |
| **Triangle/Warning (CONTAINS)** | Path "M12 2L2 19h20L12 2z" (filled, no stroke) | CONTAINS badges |
| **Question circle (UNKNOWN)** | Circle r=10 + question mark path + dot at (12,17) | UNKNOWN badges |

### Illustration Assets (External PNGs)

| Asset | Used In |
|---|---|
| `broccoli.png` | Recipe card image, hero image, empty state (tom samling) |
| `morot.png` | Recipe card image, hero image (instructions), empty state (tom inkopslista) |
| `champinjon.png` | Recipe card image, empty state (inga traffar), foto import |
| `artskida.png` | Recipe card image, empty state (tom meny) |
| `rodlok.png` | Recently imported recipe card, error state (import fel) |
| `artskida0.png` - `artskida5.png` | 6-frame animation for loading spinner (ping-pong) |

---

## 6. Global Design Principles

1. **Square everywhere**: No border-radius on cards, buttons, badges, FABs, inputs, chips, checkboxes, nav items. The only exceptions are progress stepper step icons (circles), profile avatar (circle), and the sheet handle / toggle switch (which use minimal rounding for functional reasons).

2. **Dual-accent border pattern**: Many components use green (primary) + rust (accent) in combination: search box (green sides, rust bottom), page headers (green bg, rust bottom stripe), recipe cards (green left, rust-light bottom), section headers (rust left border).

3. **Text is lowercase**: All Josefin Sans headings use `text-transform: lowercase`. Labels and small caps use `text-transform: uppercase`.

4. **Flat/brutalist aesthetic**: No rounded corners, no gradients, strong borders, solid color blocks. Shadows are minimal and functional (phone frame, FAB, toast).

5. **Consistent spacing**: 16px horizontal page margin. 12px gaps between stacked cards. 8px gaps between inline elements.

6. **Color coding categories**: Shopping uses rust (meat), warning/gold (dairy), green (vegetables). Allergens use green (free/safe), red (contains/danger), gray (unknown).

7. **Status bar spacing**: Headers have 52px top padding to accommodate the phone status bar area.
