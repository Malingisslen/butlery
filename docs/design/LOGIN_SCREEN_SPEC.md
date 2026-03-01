# Butlery Login Screen — Specifikation för Implementation

## Översikt
Uppdatera login-skärmen med ny visuell design. Byt ut generisk bestick-ikon mot Butlerys nya broccoli-logotyp.

## Visuell referens
Se `butlery-login-mockup.html` i samma mapp för exakt utseende.

---

## Struktur (uppifrån och ner)

### 1. Grön header
- **Bakgrund:** `#3D6849` (green-dark)
- **Padding:** 48px top, 32px horizontal, 40px bottom
- **Innehåll centrerat**

#### 1a. Logo (horisontell layout)
- Broccoli-bild (60px hög) + "butlery" text
- **Font:** Josefin Sans, 38px, weight 400
- **Färg:** `#F8F4E8` (cream)
- **Letter-spacing:** 1px
- **Gap mellan bild och text:** 12px
- **Vertikal justering:** text sänkt ~10px för att matcha broccolins visuella centrum

#### 1b. Tagline
- **Text:** "Dina recept. Resten löser sig."
- **Font:** Space Grotesk, 14px
- **Färg:** `rgba(255, 255, 255, 0.7)`
- **Margin-top:** 12px

### 2. Rust accent-linje
- **Höjd:** 4px
- **Färg:** `#8B5A3C` (rust)
- **Full bredd**

### 3. Content area
- **Bakgrund:** `#F8F4E8` (cream)
- **Padding:** 32px horizontal, 24px top

### 4. Login card
- **Bakgrund:** `#FFFFFF`
- **Padding:** 32px horizontal, 28px vertical
- **Inga rounded corners** (sharp corners genomgående)
- **Ingen shadow**

#### 4a. Titel
- **Text:** "Logga in"
- **Font:** Josefin Sans, 24px, weight 500
- **Färg:** `#2D2D2D`
- **Margin-bottom:** 28px

#### 4b. Input fields
- **Labels ovanför** (inte ikoner inuti)
- **Label font:** Space Grotesk, 13px, färg `#6B6B6B`
- **Input bakgrund:** `#F8F4E8` (cream)
- **Input border:** 1px solid `#E8E2D6`
- **Input padding:** 14px 16px
- **Inga rounded corners**

#### 4c. Glömt lösenord-länk
- **Högerställd**
- **Font:** 13px
- **Färg:** `#3D6849`

#### 4d. Logga in-knapp
- **Bakgrund:** `#3D6849`
- **Text:** vit, Space Grotesk, 15px, weight 500
- **Padding:** 16px
- **Full bredd**
- **Inga rounded corners**

#### 4e. Divider
- **Text:** "eller"
- **Linjer på varje sida:** 1px `#E8E2D6`

#### 4f. Skapa konto-knapp
- **Bakgrund:** transparent
- **Border:** 1px solid `#3D6849`
- **Text:** `#3D6849`, Space Grotesk, 15px, weight 500
- **Padding:** 16px
- **Full bredd**
- **Inga rounded corners**

### 5. Footer
- **Text:** "Villkor · Integritetspolicy"
- **Font:** 12px
- **Färg:** `#6B6B6B`
- **Centrerad**
- **Längst ner på skärmen**

---

## Assets som behövs
- `broccoli-icon.png` — transparent bakgrund, används i header

---

## Färgpalett (referens)
```dart
static const greenDark = Color(0xFF3D6849);
static const green = Color(0xFF4A7C59);
static const rust = Color(0xFF8B5A3C);
static const cream = Color(0xFFF8F4E8);
static const creamDark = Color(0xFFE8E2D6);
static const textDark = Color(0xFF2D2D2D);
static const textMuted = Color(0xFF6B6B6B);
```

---

## Viktiga designprinciper
1. **Inga rounded corners** — skarpa hörn genomgående
2. **Labels ovanför input fields** — inte ikoner inuti
3. **Tagline är mission statement** — "Dina recept. Resten löser sig."
4. **Rust-linjen är accent** — ger värme och särskiljning
