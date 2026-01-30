# Butlery App - Complete Views & States Inventory

> **Purpose**: Design mockup reference for all screens, states, components, and flows in the Butlery app.
> **Generated**: 2026-01-30

---

## Table of Contents

1. [Navigation Structure](#navigation-structure)
2. [Main Screens](#main-screens)
3. [Recipe Management Screens](#recipe-management-screens)
4. [Social Screens](#social-screens)
5. [Messaging Screens](#messaging-screens)
6. [Settings Screens](#settings-screens)
7. [Global Components](#global-components)
8. [User Flows](#user-flows)

---

## Navigation Structure

### Bottom Navigation (5 Tabs)

| Tab | Swedish Label | Icon (Inactive) | Icon (Active) | Route |
|-----|---------------|-----------------|---------------|-------|
| 1 | Mina recept | bookOutlined | book | `/` |
| 2 | Lägg till | addOutlined | add | `/laggTill` |
| 3 | Veckomeny | calendarOutlined | calendar | `/veckomeny` |
| 4 | Inköpslista | cartOutlined | cart | `/inkopslista` |
| 5 | Upptäck | exploreOutlined | explore | `/discovery` |

### Responsive Navigation

- **Mobile** (< 600px): BottomNavigationBar
- **Tablet** (600-1024px): NavigationRail (compact, icons only)
- **Desktop** (≥ 1024px): NavigationRail (extended with labels)

---

## Main Screens

### 1. Mina Recept (My Recipes)

**Route:** `/` (home)
**Tab:** Mina recept

#### States

| State | What's Displayed |
|-------|------------------|
| **Loading** | Skeleton recipe list (5 placeholder cards with shimmer animation) |
| **Empty - No recipes** | Illustration + "Du har inga recept ännu" + "Lägg till ditt första recept" button |
| **Empty - No search results** | "Inga resultat" + suggestion to try different search terms |
| **Error** | Error icon + error message + "Försök igen" (Try again) button |
| **Normal** | Responsive grid/list of recipe cards |

#### Components

- **Header (AppBar)**:
  - App logo/title: "Mina recept"
  - Search icon (opens search field)
  - Filter icon (opens filter bottom sheet)
  - Sort menu (dropdown: Senaste, Namn A-Ö, Betyg)
  - Error indicator icon (appears when sync error)
  - Offline indicator badge

- **Body**:
  - Search field (when active)
  - Filter chips row (active filters)
  - Recipe card grid/list (responsive)
  - Pull-to-refresh enabled
  - Personal tags filter chips

- **Actions**:
  - FAB hidden (use bottom nav "Lägg till" instead)

#### Interactions

- **Tap recipe card** → Navigate to Recipe Detail
- **Long-press recipe card** → Context menu (Edit, Delete, Share, Fork)
- **Tap search icon** → Expand search field
- **Tap filter icon** → Open filter bottom sheet
- **Pull down** → Refresh recipe list
- **Scroll** → Infinite scroll (lazy loading)

#### Modals/Sheets

- **Filter Bottom Sheet**: Allergens, dietary prefs, tags, rating, time
- **Sort Dropdown Menu**: Senaste, Namn, Betyg
- **Delete Confirmation Dialog**: "Är du säker på att du vill ta bort receptet?"

---

### 2. Lägg Till (Add Recipe)

**Route:** `/laggTill`
**Tab:** Lägg till

#### States

| State | What's Displayed |
|-------|------------------|
| **Normal** | Grid of 6 import method buttons + archive button |

*No loading, empty, or error states - this is a static navigation menu.*

#### Components

- **Header (AppBar)**:
  - Title: "Lägg till recept"
  - Back button (if navigated from elsewhere)

- **Body**:
  - 2x3 grid of import method cards:
    1. **YOUTUBE** - Play icon, "Från YouTube"
    2. **FOTO** - Camera icon, "Från foto"
    3. **LÄNK** - Link icon, "Från länk"
    4. **INSTAGRAM** - Instagram icon, "Från Instagram"
    5. **TIKTOK** - TikTok icon, "Från TikTok"
    6. **SKRIV SJÄLV** - Pencil icon, "Skriv själv"
  - Full-width archive button: "Importera från arkiv"

#### Interactions

- **Tap method card** → Navigate to respective import flow
- **Tap archive button** → Navigate to file import

---

### 3. Veckomeny (Weekly Menu)

**Route:** `/veckomeny`
**Tab:** Veckomeny

#### States

| State | What's Displayed |
|-------|------------------|
| **Loading** | Semi-transparent overlay with centered spinner + "Genererar meny..." |
| **Empty** | Input field prominent + "Ange vad du vill äta..." placeholder |
| **Error** | Error icon in AppBar (tap for details) + snackbar notification |
| **Normal** | Generated menu organized by day/meal type |

#### Components

- **Header (AppBar)**:
  - Title: "Veckomeny"
  - Actions row:
    - Load saved menu (folder icon)
    - Save menu (save icon)
    - Share menu (people icon)
    - Clear menu (X icon)
    - Error indicator (if error state)

- **Body - Empty/Input State**:
  - Text input field: "Beskriv din meny..."
  - Example prompts: "5 italienska middagar", "Snabba luncher under 30 min"
  - "Generera meny" (Generate menu) button

- **Body - Generated State**:
  - Day sections (Måndag → Söndag)
  - Each day shows: Day name header + recipe cards for meals
  - Recipe cards: Compact style with image, title, time
  - "Till inköpslista" (To shopping list) button at bottom

#### Interactions

- **Tap "Generera meny"** → AI generates 7-day menu
- **Tap recipe in menu** → Navigate to Recipe Detail
- **Tap save icon** → Save menu dialog (name + share options)
- **Tap share icon** → Share with friends/groups dialog
- **Tap folder icon** → Load saved menu bottom sheet
- **Tap "Till inköpslista"** → Add all ingredients to shopping list
- **Tap refresh icon on category** → Regenerate that category only

#### Modals/Sheets

- **Save Menu Dialog**: Name input + friend/group selector
- **Share Menu Dialog**: Friend/group multi-select
- **Load Menu Sheet**: List of saved menus
- **Shopping List Selector**: Choose which list to add ingredients to

---

### 4. Inköpslista (Shopping List)

**Route:** `/inkopslista`
**Tab:** Inköpslista

#### States

| State | What's Displayed |
|-------|------------------|
| **Loading** | Centered circular progress indicator |
| **Empty - No lists** | "Ingen inköpslista" + "Skapa din första lista" button |
| **Empty - List empty** | "Listan är tom" + "Lägg till varor" prompt |
| **Error** | Error message + "Försök igen" button |
| **Normal** | Categorized item list with checkboxes |

#### Components

- **Header (AppBar)**:
  - Title: "Inköpslista"
  - List selector dropdown (if multiple lists)
  - Offline indicator
  - Share icon (if personal list)
  - More menu (⋮): Clear completed, Rename, Delete list

- **Sub-header**:
  - Statistics: "X av Y varor" (X of Y items)
  - Progress indicator bar

- **Body**:
  - Category sections (expandable):
    - Grönsaker (Vegetables)
    - Frukt (Fruit)
    - Mejeri (Dairy)
    - Kött & Fisk (Meat & Fish)
    - Torrvaror (Dry goods)
    - Fryst (Frozen)
    - Övrigt (Other)
  - Each item row:
    - Checkbox (checked = strikethrough)
    - Item name
    - Quantity + unit
    - Edit icon (pencil)
    - Delete icon (trash)
  - Completed items section (collapsed, expandable)

- **FAB**: "+" Add item

#### Interactions

- **Tap checkbox** → Toggle item completion (strikethrough animation)
- **Tap item row** → Expand item details
- **Tap edit icon** → Edit item dialog
- **Tap delete icon** → Delete confirmation
- **Tap FAB** → Add item dialog
- **Tap list dropdown** → Switch between lists
- **Long-press item** → Context menu (edit, delete, move to other list)

#### Modals/Sheets

- **Add Item Dialog**: Name, category dropdown, quantity, unit, note, priority
- **Edit Item Dialog**: Same fields as add
- **Delete Confirmation**: "Ta bort X?"
- **Share List Dialog**: Friend/group selector
- **List Operations Menu**: Rename, Clear completed, Delete list

---

### 5. Upptäck (Discovery)

**Route:** `/discovery`
**Tab:** Upptäck

#### States

| State | What's Displayed |
|-------|------------------|
| **Loading** | Spinner + "Laddar upptäcktsinnehåll..." |
| **Empty - No search results** | "Inga resultat för sökningen" |
| **Error** | Error message + "Uppdatera" button |
| **Normal** | Tab-based content sections |

#### Components

- **Header (AppBar)**:
  - Title: "Upptäck"
  - Search icon → Expandable search field
  - Profile icon → Navigate to profile
  - Messages icon → Navigate to messages (with badge count)

- **Tab Bar** (3 tabs):
  1. **Upptäck** - Trending content
  2. **Aktivitet** - Friend activity
  3. **Rekommenderat** - Personalized recommendations

- **Body - Upptäck Tab**:
  - Trending recipes section (horizontal scroll)
  - Popular categories section
  - Featured collections

- **Body - Aktivitet Tab**:
  - Friend activity feed (who shared what)
  - Activity cards with timestamps

- **Body - Rekommenderat Tab**:
  - "Baserat på dina preferenser"
  - Personalized recipe suggestions

#### Interactions

- **Tap tab** → Switch content view
- **Tap recipe card** → Navigate to Recipe Detail
- **Tap friend activity** → Navigate to shared content
- **Tap search** → Search users and recipes
- **Scroll to bottom** → Infinite scroll loads more content
- **Pull down** → Refresh content

#### Modals/Sheets

- **Search Results**: User profiles + recipes
- **Filter Options**: Content type, time range

---

## Recipe Management Screens

### 6. Receptdetalj (Recipe Detail)

**Route:** `/receptDetalj`
**Tab:** None (accessed from any recipe list)

#### States

| State | What's Displayed |
|-------|------------------|
| **Loading (deletion)** | Full-screen spinner during delete operation |
| **Image loading** | Placeholder icon while image loads |
| **Image error** | Restaurant icon fallback |
| **Normal** | Full recipe display with all sections |

#### Components

- **Header (SliverAppBar)**:
  - Hero image (or placeholder if no image)
  - Collapsed: Recipe title
  - Actions:
    - Back button
    - Edit icon (pencil)
    - Share icon
    - More menu (⋮): Delete, Fork, Add to menu

- **Body - CustomScrollView**:

  **Metadata Section**:
  - Title (large)
  - Source URL (if external recipe)
  - Rating stars (interactive)
  - Time badge: "X min"
  - Portions badge: "X portioner"
  - Allergen badges row
  - Dietary badges row
  - Personal tags chips
  - Collaborative status banner (if shared)

  **Portion Scaler Section**:
  - "Portioner" header
  - Minus/Plus buttons with current count
  - "Skalat från X till Y portioner" indicator
  - Unit conversion toggle: "Konvertera amerikanska enheter"

  **Ingredients Section**:
  - "Ingredienser för X portioner:"
  - Bullet list of ingredients (scaled)
  - Changed ingredients highlighted (bold)
  - "Lägg till i inköpslista" button

  **Instructions Section**:
  - "Instruktioner"
  - Numbered steps
  - Step checkboxes (optional completion tracking)

  **Comments Section** (if social):
  - Comment count header
  - Comment list
  - Add comment input field

#### Interactions

- **Tap edit icon** → Navigate to Edit Recipe
- **Tap share icon** → Share options sheet
- **Tap rating stars** → Update rating
- **Tap +/- buttons** → Scale portions
- **Tap unit toggle** → Convert US → Swedish units
- **Tap "Till inköpslista"** → Shopping list selector
- **Tap personal tag** → Filter by tag
- **Tap image** → Fullscreen image viewer
- **Swipe images** → Carousel navigation
- **Tap step checkbox** → Mark step complete

#### Modals/Sheets

- **Share Options Sheet**: Share with friends, groups, or external
- **Shopping List Selector**: Choose destination list
- **Delete Confirmation**: "Ta bort receptet permanent?"
- **Fullscreen Image Viewer**: Pinch-zoom, swipe carousel

---

### 7. Skriv Själv (Manual Recipe Creation)

**Route:** `/skrivSjalv`
**Tab:** None

#### States

| State | What's Displayed |
|-------|------------------|
| **Loading (save)** | Overlay with spinner during save |
| **Draft recovered** | Snackbar: "Utkast återställt" |
| **Validation error** | Field-level error messages |
| **Normal** | Empty form or pre-filled template |

#### Components

- **Header (AppBar)**:
  - Title: "Nytt recept" or "Redigera recept"
  - Back button (with unsaved changes warning)
  - Save icon

- **Body - Form (SingleChildScrollView)**:

  **Image Section**:
  - Image preview (if selected)
  - "Lägg till bild" button → Image picker
  - Upload progress indicator

  **Basic Info Section**:
  - Title field (required) *
  - Description field (multiline)
  - Source URL field

  **Metadata Section**:
  - Portions: Number input with +/- steppers
  - Time: Number input (minutes)
  - Rating: 5-star selector

  **Ingredients Section**:
  - "Ingredienser" header
  - Dynamic list builder:
    - Each row: Text input + delete button
    - Last row auto-adds new when typing
    - "Lägg till ingrediens" button

  **Instructions Section**:
  - "Instruktioner" header
  - Multiline text area
  - Or numbered step list (toggle)

  **Tags Section**:
  - "Personliga taggar" header
  - Tag selector chips
  - "Lägg till tagg" button

- **Bottom Actions**:
  - "Spara recept" primary button (full width)

#### Interactions

- **Tap image area** → Image picker sheet
- **Tap +/- steppers** → Adjust portions/time
- **Tap stars** → Set rating
- **Type in last ingredient row** → Auto-add new row
- **Tap delete on ingredient** → Remove row
- **Tap tag chip** → Toggle tag selection
- **Tap "Spara"** → Validate and save
- **Back gesture with unsaved changes** → Warning dialog

#### Modals/Sheets

- **Image Picker Sheet**: "Ta ett foto" / "Välj från galleri"
- **Tag Selector Dialog**: All available personal tags
- **Unsaved Changes Dialog**: "Spara" / "Kasta" / "Avbryt"
- **Validation Errors**: Inline under fields

---

### 8. Smart Import

**Route:** `/smartImport`
**Tab:** None

#### States

| State | What's Displayed |
|-------|------------------|
| **Input** | Text field + paste button |
| **Detecting** | "Identifierar plattform..." + spinner |
| **Fetching** | "Hämtar recept..." + progress |
| **Analyzing** | "Analyserar innehåll..." + progress |
| **Error** | Error message + "Försök manuellt" button |
| **Rate limited** | Rate limit dialog with countdown |
| **Success** | Auto-navigates to recipe editor |

#### Components

- **Header (AppBar)**:
  - Title: "Smart Import"
  - Back button

- **Body**:

  **Input Section**:
  - Large text input field
  - Placeholder: "Klistra in länk eller text..."
  - "Klistra in" (Paste) button

  **Detection Indicator**:
  - Platform badge: YouTube / Instagram / TikTok / Webbsida / Text
  - Icon + platform name

  **Progress Section**:
  - Step indicator: 1. Hämtar → 2. Analyserar → 3. Skapar
  - Progress bar
  - Current step description

  **Error Section** (if error):
  - Error icon + message
  - "Försök igen" button
  - "Manuell import" fallback button

#### Interactions

- **Paste content** → Auto-detect platform
- **Tap "Klistra in"** → Paste from clipboard
- **Tap "Manuell import"** → Opens assisted import dialog
- **Auto-navigate on success** → To recipe editor with pre-filled data

#### Modals/Sheets

- **Assisted Import Dialog**: Step-by-step guided form
- **Rate Limit Dialog**: "Vänta X sekunder..." countdown
- **Platform Detection Badge**: Visual feedback

---

### 9. Photo Import

**Route:** `/photoImport`
**Tab:** None

#### States

| State | What's Displayed |
|-------|------------------|
| **Initial** | Camera/gallery selection prompt |
| **Capturing** | Camera UI |
| **Processing** | "Extraherar text..." + OCR progress |
| **Error** | "Kunde inte läsa texten" + retry options |
| **Success** | Auto-navigates to text import |

#### Components

- **Header (AppBar)**:
  - Title: "Importera från foto"
  - Back button

- **Body**:

  **Selection Buttons**:
  - Large button: "Ta ett foto" with camera icon
  - Large button: "Välj från galleri" with gallery icon

  **Preview Section** (after capture):
  - Image preview
  - "Använd denna bild" button
  - "Ta ny bild" button

  **Processing Section**:
  - Image thumbnail
  - "Extraherar text med OCR..."
  - Progress indicator

#### Interactions

- **Tap "Ta ett foto"** → Opens camera
- **Tap "Välj från galleri"** → Opens photo picker
- **Capture photo** → Shows preview
- **Tap "Använd"** → Start OCR processing
- **OCR complete** → Navigate to text import with extracted text

---

### 10. Edit Recipe

**Route:** `/redigeraRecept`
**Tab:** None

*Same layout as "Skriv Själv" but with pre-filled data*

#### Additional Components

- **Collaborative Banner** (if shared):
  - Blue background
  - "Delad med X personer" info
  - Permission level indicator

#### Additional Interactions

- **If read-only** → Form fields disabled
- **Save changes** → Returns to Recipe Detail

---

## Social Screens

### 11. Vänner & Grupper (Friends & Groups)

**Route:** `/friends`
**Tab:** None (accessed from Upptäck)

#### States (per tab)

| Tab | Empty State | Loading | Normal |
|-----|-------------|---------|--------|
| **Vänner** | "Inga vänner ännu" + "Sök efter vänner" | Spinner | Friend list |
| **Förfrågningar** | "Inga väntande förfrågningar" | Spinner | Request cards |
| **Grupper** | "Inga grupper" + "Skapa grupp" | Spinner | Group cards |

#### Components

- **Header (AppBar)**:
  - Title: "Vänner & Grupper"
  - Back button

- **Tab Bar**:
  - "Vänner" (badge: friend count)
  - "Förfrågningar" (badge: pending count)
  - "Grupper" (badge: group count)

- **Vänner Tab**:
  - Friend list with avatars
  - Each row: Avatar, Name, Status
  - Tap → Friend profile

- **Förfrågningar Tab**:
  - Incoming requests section:
    - Request card: Avatar, Name, Date
    - Accept (✓) / Reject (✗) buttons
  - Sent requests section:
    - Pending request card
    - "Avbryt" cancel button

- **Grupper Tab**:
  - Group cards: Icon, Name, Member count
  - FAB: "+" Create group

#### Interactions

- **Tap friend** → Navigate to Friend Profile
- **Tap accept** → Accept friend request
- **Tap reject** → Reject friend request
- **Tap group** → Navigate to Group Detail
- **Tap FAB (groups)** → Create group dialog
- **Pull down** → Refresh list

---

### 12. Gruppdetalj (Group Detail)

**Route:** Direct navigation (not named route)
**Tab:** None

#### Components

- **Header (SliverAppBar)**:
  - Group icon/image
  - Group name
  - Settings icon (if owner)

- **Stats Section**:
  - Member count
  - Shared recipes count
  - Created date

- **Members Section**:
  - Member list with roles (Ägare, Medlem)
  - Add member button (if owner)

- **Actions Section** (if owner):
  - "Redigera grupp"
  - "Lägg till medlemmar"
  - "Ta bort grupp"

- **Actions Section** (if member):
  - "Lämna grupp"

#### Interactions

- **Tap member** → View member profile
- **Tap "Lägg till"** → Add members sheet
- **Tap "Lämna grupp"** → Confirmation dialog
- **Tap "Ta bort grupp"** → Destructive confirmation

---

### 13. Delat med mig (Shared With Me)

**Route:** `/shared`
**Tab:** None

#### Tab Structure

- **Recept** - Shared recipes
- **Menyer** - Shared menus
- **Inköpslistor** - Shared shopping lists

#### Components

- **AppBar**:
  - Title: "Delat med mig"
  - Search icon

- **Body (per tab)**:
  - Content cards with sharer info
  - Sharing date
  - Permission badge (View/Edit)

---

### 14. Vänprofil (Friend Profile)

**Route:** `/friend-profile`
**Tab:** None

#### Components

- **Header**:
  - Large avatar
  - Display name
  - Friend since date

- **Stats Section**:
  - Recipe count
  - Shared with you count

- **Actions**:
  - "Skicka meddelande" (Message)
  - "Dela recept" (Share recipe)
  - "Ta bort vän" (Unfriend)

---

### 15. Profilredigering (Profile Edit)

**Route:** `/profile/edit`
**Tab:** None

#### Components

- **Avatar Section**:
  - Large avatar image
  - "Ändra bild" overlay button
  - Upload progress indicator

- **Form Fields**:
  - Display name (with availability check)
  - Bio/description (optional)
  - Language selector: Svenska / English
  - Theme: Ljust / Mörkt / System

- **Save Button**:
  - "Spara ändringar"

---

## Messaging Screens

### 16. Meddelanden (Conversations List)

**Route:** `/messages`
**Tab:** None

#### States

| State | What's Displayed |
|-------|------------------|
| **Loading** | Full-screen loading overlay |
| **Empty** | "Inga konversationer" + "Starta en chatt" button |
| **No search results** | "Inga resultat" |
| **Normal** | Conversation list |

#### Components

- **AppBar**:
  - Title: "Meddelanden"
  - Search icon
  - New conversation icon (+)

- **Search Field** (when active):
  - Filter conversations by name

- **Conversation List**:
  - Each row:
    - Avatar (user or group icon)
    - Name
    - Last message preview (truncated)
    - Timestamp
    - Unread badge (if unread)

#### Interactions

- **Tap conversation** → Navigate to Chat
- **Tap new (+)** → Create conversation sheet
- **Long-press** → Context menu (Mute, Delete)
- **Pull down** → Refresh

---

### 17. Chatt (Chat View)

**Route:** `/chat`
**Tab:** None

#### Components

- **AppBar**:
  - Back button
  - Avatar + Name
  - Info icon (→ conversation details)

- **Message List**:
  - Messages grouped by date
  - User messages (right, primary color)
  - Other messages (left, gray)
  - Timestamps
  - Read receipts
  - Shared content previews (recipes, menus)

- **Input Section**:
  - Text field
  - Send button
  - Attachment button (share recipe/menu)

#### Interactions

- **Type message** → Send button activates
- **Tap send** → Send message
- **Tap attachment** → Share content sheet
- **Tap shared recipe** → Navigate to Recipe Detail
- **Scroll up** → Load older messages

---

## Settings Screens

### 18. Allergenpreferenser (Allergen Preferences)

**Route:** `/settings/allergens`
**Tab:** None

#### Components

- **AppBar**:
  - Title: "Allergener & Kost"
  - Back button

- **Allergens Section**:
  - "Mina allergener"
  - Toggle list for each allergen:
    - Gluten
    - Laktos
    - Nötter
    - Ägg
    - Soja
    - Fisk
    - Skaldjur

- **Dietary Section**:
  - "Kostpreferenser"
  - Toggle list:
    - Vegetarisk
    - Vegansk
    - Pescetarian
    - Halal
    - Kosher

- **Info Text**:
  - "Recept med dessa markeras automatiskt"

---

### 19. Personliga Taggar (Personal Tags)

**Route:** `/settings/personal-tags`
**Tab:** None

#### States

| State | What's Displayed |
|-------|------------------|
| **Loading** | Skeleton list |
| **Empty** | "Inga taggar" + "Skapa din första tagg" |
| **Normal** | Tag list with groups |

#### Components

- **AppBar**:
  - Title: "Personliga taggar"
  - Sort menu (Namn, Användning, Skapad)
  - Add tag (+)

- **Tag Groups** (expandable sections):
  - Group name header
  - Tags in group

- **Ungrouped Tags**:
  - Individual tag cards

- **Tag Card**:
  - Tag name
  - Usage count badge
  - Color indicator
  - Edit icon

- **FAB**: "+" Create tag

#### Interactions

- **Tap tag** → Tag detail view
- **Long-press tag** → Context menu (Edit, Delete)
- **Tap group header** → Expand/collapse
- **Tap FAB** → Create tag dialog
- **Pull down** → Refresh

---

### 20. Taggdetalj (Tag Detail)

**Route:** Direct navigation
**Tab:** None

#### Components

- **Header**:
  - Tag name
  - Color picker
  - Usage statistics

- **Automation Rules**:
  - "Automatiskt tagga recept som..."
  - Rule conditions (keywords, ingredients)

- **Recipes with Tag**:
  - List of tagged recipes

---

## Global Components

### Recipe Card

**3 Style Variants**:

1. **Detailed** (default list view):
   - Image (80x80px) on left
   - Title (2 lines max)
   - Description (2 lines, truncated)
   - Metadata row: Meal type, Portions, Time, Rating
   - Allergen badges (max 4)
   - Dietary badges (max 2)
   - Personal tags (with +N overflow)

2. **Compact** (horizontal lists):
   - Smaller image (60x60px)
   - Single-line title
   - Compact metadata

3. **Grid** (grid layouts):
   - Full-width image (150px height)
   - Title below
   - Compact metadata row

### Allergen Badge (Tri-state)

| State | Color | Shape | Icon | Label Example |
|-------|-------|-------|------|---------------|
| **FREE** | Green (#10B981) | Circle | ✓ check | "Fri från gluten" |
| **CONTAINS** | Red (#EF4444) | Triangle | ⚠ warning | "Innehåller gluten" |
| **UNKNOWN** | Gray (#6B7280) | Circle | ? help | "Gluten okänd" |

**Sizes**: Standard (for detail views) and Compact (for cards)

### Dietary Badge

Same tri-state pattern as allergen, but uses leaf icon (🌿) for FREE state.

### Shopping List Item

- Checkbox (circular)
- Item name (strikethrough when checked)
- Quantity + unit
- Category color indicator
- Edit/Delete icons

### Menu Day Card

- Day name header (Måndag, Tisdag, etc.)
- Meal type sections (Frukost, Lunch, Middag)
- Compact recipe cards
- Section refresh button

### Portion Scaler

- Container with primary accent
- "Portioner" header with restaurant icon
- Minus / Current Count / Plus buttons
- Status banner: "Skalat från X till Y portioner"
- Unit conversion toggle

### Empty State Widget

- Large icon (64px, semi-transparent)
- Title text
- Description text
- Primary action button (optional)

### Error State Widget

- Error icon (64px, red)
- Error message
- "Försök igen" retry button

### Loading States

1. **Skeleton Loader**: Shimmer animation placeholders
2. **Spinner**: Circular progress with message
3. **Overlay**: Semi-transparent dark background + centered spinner
4. **Button Loading**: Disabled button with spinner

### Dialog Types

1. **Confirmation Dialog**: Icon, title, message, Cancel/Confirm
2. **Destructive Dialog**: Warning styling, red confirm button
3. **Form Dialog**: Title, form fields, Cancel/Submit
4. **Loading Dialog**: Spinner + message (non-dismissible)

### Bottom Sheets

- Draggable with handle
- Rounded top corners (12px)
- Initial height: 70%, Max: 90%, Min: 50%

### Snackbar Variants

| Type | Color | Icon |
|------|-------|------|
| **Success** | Green (#10B981) | ✓ check_circle |
| **Error** | Red (#EF4444) | ✕ error |
| **Warning** | Amber (#F59E0B) | ⚠ warning |
| **Info** | Blue (#3B82F6) | ℹ info |

---

## User Flows

### Add Recipe Flow

```
[Lägg till tab]
    ↓
[Choose import method]
    ├─ YouTube/Instagram/TikTok/Länk → [Smart Import] → [Parse] → [Recipe Editor]
    ├─ Foto → [Camera/Gallery] → [OCR] → [Text Import] → [Recipe Editor]
    ├─ Skriv själv → [Recipe Editor]
    └─ Arkiv → [File Import] → [Recipe Editor]
    ↓
[Edit/Review recipe form]
    ↓
[Save] → [Mina Recept with new recipe]
```

### Generate Menu Flow

```
[Veckomeny tab]
    ↓
[Enter prompt: "5 italienska middagar"]
    ↓
[Generate] → Loading overlay
    ↓
[View generated menu by day]
    ↓
├─ [Save menu] → Save dialog → Saved
├─ [Share menu] → Friend selector → Shared
├─ [To shopping list] → List selector → Items added
└─ [Edit recipes] → Tap recipe → Recipe Detail
```

### Share Recipe Flow

```
[Recipe Detail]
    ↓
[Tap share icon]
    ↓
[Share sheet]
    ├─ [Share with friends] → Friend multi-select → Permission level → Share
    ├─ [Share with group] → Group selector → Share
    └─ [External share] → OS share sheet
```

### Shopping Flow

```
[Inköpslista tab]
    ↓
├─ [No list] → [Create list dialog]
└─ [Has list] → [View items by category]
    ↓
├─ [Add item] → FAB → [Add item dialog] → Item added
├─ [Check item] → Tap checkbox → Strikethrough
├─ [Edit item] → Tap edit → [Edit dialog] → Updated
├─ [Delete item] → Tap delete → Confirmation → Deleted
└─ [Share list] → Share icon → Friend selector → Shared
```

### Refresh/Scroll Behaviors

| View | Pull-to-Refresh | Infinite Scroll |
|------|-----------------|-----------------|
| Mina Recept | ✅ Yes | ✅ Yes |
| Veckomeny | ❌ No | ❌ No |
| Inköpslista | ✅ Yes | ❌ No |
| Upptäck | ✅ Yes | ✅ Yes |
| Vänner | ✅ Yes | ❌ No |
| Meddelanden | ✅ Yes | ❌ No |
| Chatt | ❌ No | ✅ Yes (older messages) |

---

## Color Palette Reference

### Primary Brand

- Primary Blue: #4E6F8B
- Dark Navy: #2C3E50
- Background Beige: #EFE9E3
- White: #FFFFFF

### Semantic Colors

- Success: #10B981 (green)
- Warning: #F59E0B (amber)
- Error: #EF4444 (red)
- Info: #3B82F6 (blue)

### Text Colors

- Dark: #2C3E50
- Medium: #6B7280
- Light: #9CA3AF

---

## Spacing Scale

- Xs: 4px
- Sm: 8px
- Md: 16px
- Lg: 24px
- Xl: 32px
- Xxl: 48px

## Border Radius

- Small: 4px
- Medium: 8px
- Large: 12px
- Round: 50px (pills/circles)

---

## Summary Statistics

- **Total Named Routes**: 30
- **Main Navigation Tabs**: 5
- **Main Views**: 18
- **Component View Files**: 67+
- **Deferred Loading Modules**: 3 (Extraction, Social, Messaging)
