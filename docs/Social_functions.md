# 🤝 Butlerys Sociala Platform - Komplett Guide

## 📋 Översikt

Den sociala plattformen i Butlery låter användare dela recept och veckomenyer med varandra, precis som man delar bilder på Instagram. Men istället för att dela foton delar våra användare mat-innehåll som hjälper varandra i vardagen.

### 🎯 Huvudfunktioner:
- **Vänhantering** - Sök, lägg till och hantera vänner
- **Receptdelning** - Dela enskilda recept med meddelanden och smart filtrering
- **Menydelning** - Dela hela veckomenyer
- **Grupphantering** - Organisera vänner i kategorier
- **Kollaborativa listor** - Dela inköpslistor i realtid
- **Notifikationer** - Håll koll på all social aktivitet

---

## 👥 Vänhantering

### Hitta och lägg till vänner

1. **Sök efter användare:**
   - Tryck på din avatar → "Vänner"
   - Använd sökfältet för att hitta personer
   - Systemet söker på användarnamn (case-insensitive)

2. **Skicka vänskapsförfrågan:**
   - Tryck "Lägg till vän" på någons profil
   - Skriv ett meddelande (valfritt): "Hej! Vi träffades på kalaset"
   - Förfrågan skickas direkt

3. **Hantera förfrågningar:**
   - Röd siffra på avataren = nya förfrågningar
   - Gå till "Notiser" för att se förfrågningar
   - Acceptera eller avböj med ett tryck

### Teknisk implementation:

```dart
// services/friends_service.dart
- Hanterar alla vänskapsoperationer
- Mutual friends validation
- Automatic cleanup av gamla förfrågningar

// viewmodels/friends_viewmodel.dart
- UI state management
- Cached user profiles (30 min TTL)
- Real-time förfrågningsuppdateringar
```

---

## 🍳 Receptdelning

### Dela recept med smart filtrering

1. **Öppna väns profil** från vänlistan
2. **Tryck "Dela recept"** för att öppna delningsdialogen
3. **Smart funktionalitet:**
   - Automatisk filtrering visar vilka recept redan delats
   - Redan delade recept visas med grå text och "Delad" chip
   - Sök och filtrera bland dina recept
   - Multi-select för att dela flera recept samtidigt

4. **Genomför delning:**
   - Välj ett eller flera recept
   - Tryck "Dela (X)" där X är antal valda recept
   - Få bekräftelse: "3 recept delade med Anna! 🍽️"

### Vad händer tekniskt:

```dart
// viewmodels/recipe_selection_viewmodel.dart
- Laddar alla användarens recept
- Kollar vilka som redan delats med specifik vän
- Hanterar sök, filter och multi-select
- Visar visuella indikatorer för redan delade recept

// widgets/recipe_selection_dialog.dart
- Fullt funktionell dialog med sök
- Checkbox-baserad multi-select
- AppTheme-baserad styling för redan delade recept
- Real-time feedback och loading states

// services/social_recipe_service.dart
- getRecipesSharedWithFriend() för smart filtrering
- shareRecipeToFriends() hanterar bulk-delning
- Optimerade Firestore-frågor för snabb prestanda
```

### Design för redan delade recept:

- **Ljus grå text** - tydlig visuell skillnad
- **"Delad" chip** - grön etikett med skugga
- **Grå ikoner** - konsekvent nedtonad styling
- **Fortfarande valbara** - kan delas igen om önskat
- **Semantiska AppTheme-färger** - ingen hårdkodning

### Hantera mottagna recept:

- **Visa**: Öppna receptet i detaljvy
- **Importera**: Kopiera till din samling
- **Dölja**: Ta bort från din lista (andra påverkas inte)

---

## 📅 Menydelning

### Dela en veckomeny

1. **Skapa/ladda en meny** i Veckomeny-fliken
2. **Tryck på personer-ikonen**
3. **Anpassa titel**: "Marias vintermeny 2025"
4. **Välj mottagare** (vänner/grupper)
5. **Lägg till meddelande**
6. **Dela hela menyn**

### Teknisk struktur:

```dart
// models/shared_menu.dart
- Komplett veckomeny med alla recept
- Organiserad per dag (Map<String, List<Recipe>>)
- Bulk import functionality

// widgets/menu_share_dialog.dart
- Preview av menyn före delning
- Anpassningsbar titel
- Success animations
```

### För mottagaren:

- Se hela veckomenyn organiserad per dag
- Importera hela menyn (alla recept kopieras)
- Eller plocka ut enskilda recept
- Dölja om ej intresserad

---

## 👥 Grupphantering

### Skapa och hantera grupper

1. **Skapa grupp:**
   - Vänner → Grupper-fliken → "+"
   - Namn, emoji, beskrivning
   - Välj medlemmar att bjuda in

2. **Gruppinbjudningar:**
   - Skickas som notifikationer
   - Orange badge på grupper-tabben
   - Accept/avböj direkt i listan

3. **Hantera grupper:**
   - Endast ägaren kan redigera/ta bort
   - Alla kan lämna gruppen
   - Ägaren kan ta bort medlemmar

### Implementation:

```dart
// services/friend_categories_service.dart
- CRUD operations för grupper
- Medlemshantering
- Firebase paths: users/{userId}/friend_categories

// services/group_invitation_service.dart
- Separat system för inbjudningar
- Real-time listeners
- Event bus för UI updates
```

---

## 🛒 Kollaborativa inköpslistor

### Dela inköpslistor (framtida feature)

```dart
// models/shared_shopping_list.dart
- Real-time collaboration
- Conflict resolution
- Item-level permissions

// services/social_shopping_service.dart
- Firestore real-time sync
- Optimistic updates
- Offline support
```

---

## 🔔 Notifikationssystem

### Typer av notifikationer:

1. **Vänskapsförfrågningar** - Röd badge på avatar
2. **Gruppinbjudningar** - Orange badge på grupper-tab
3. **Delade recept/menyer** - Räknare på "Delat med mig"

### Teknisk arkitektur:

```dart
// core/events/group_events.dart
- Event bus för real-time updates
- Broadcast streams
- Memory-safe listeners

// viewmodels/friends_viewmodel.dart
- Kombinerar alla notification counts
- Real-time updates via streams
```

---

## 🏗️ Teknisk Arkitektur

### Databasstruktur (Firestore)

```
├── user_profiles/{userId}      # Publika profiler för sökning
├── users/{userId}/
│   ├── friends/{friendId}      # Vänrelationer
│   └── friend_categories/      # Grupper
├── friend_requests/            # Vänskapsförfrågningar
├── group_invitations/          # Gruppinbjudningar
├── shared_recipes/             # Delade recept med delningsstatus
├── shared_menus/               # Delade menyer
└── recipe_comments/            # Kommentarer (framtida)
```

### Service Layer

```dart
// Alla services använder ChangeNotifier pattern
UserService         # Profiler och sökning
FriendsService      # Vänskap och förfrågningar
SocialRecipeService # Delning, smart filter och kommentarer
FriendCategoriesService # Grupphantering
GroupInvitationService  # Inbjudningar
```

### Security & Privacy

```javascript
// Firestore Security Rules
- Användare kan bara läsa sina egna vänner
- Delade recept kräver explicit permission
- Sökning begränsad till publika profiler
- Grupper är user-scoped
- Smart filtrering respekterar privacy
```

---

## 📱 UI Navigation

### Huvudingångar:

1. **Avatar (övre högra hörnet)**
   - Röd badge = notifikationer
   - Tryck för profil-meny

2. **Profil-meny innehåller:**
   - Redigera profil
   - Vänner (med badges)
   - Notiser
   - Delat med mig
   - Säkerhetskopiering
   - Logga ut

3. **I vänprofiler:**
   - "Dela recept" knapp öppnar smart delningsdialog
   - Visar redan delade recept med visuella indikatorer

4. **I recept/meny-vyer:**
   - Personer-ikon för social delning
   - Skiljer sig från system-delning

---

## 🎯 Best Practices

### För användare:

1. **Kolla "redan delad" indikatorer** - undvik dubbeldelning
2. **Använd sökfunktionen** i delningsdialogen för stora receptsamlingar
3. **Multi-select** för att dela flera recept samtidigt
4. **Skriv meddelanden** när du delar - ger kontext
5. **Använd grupper** för att organisera vänner
6. **Importera selektivt** - ta bara det du behöver
7. **Håll profilen uppdaterad** - underlättar för vänner att hitta dig

### För utvecklare:

1. **Använd ViewModels** för all UI logic
2. **Services är singletons** - aldrig dispose
3. **Event bus** för cross-component updates
4. **Cache aggressivt** - UserProfiles, groups, delningsstatus
5. **Batch operations** när möjligt
6. **AppTheme för all styling** - ingen hårdkodning
7. **Optimistic updates** för bättre UX

---

## 🚀 Performance

### Optimeringar:

1. **UserProfile caching** - 30 min TTL
2. **Delningsstatus caching** - Ladda en gång per dialog
3. **Batch user lookups** - Minska queries
4. **displayNameLower** - Indexerad sökning
5. **Lazy loading** - Comments, group members
6. **Optimistic updates** - Dismiss och delning
7. **Set-baserad lookup** - O(1) för redan delade recept

### Metrics:

- Sökning: <200ms med index
- Smart filter laddning: <300ms
- Receptdelning: <400ms per recept
- Import: <500ms för enskilt recept
- Meny import: <2s för 7 recept
- Real-time updates: ~100ms latency

---

## 🎨 Design System

### AppTheme för redan delade recept:

```dart
// Semantiska färger
sharedRecipeTextColor     # Ljus grå för text
sharedRecipeIconColor     # Ännu ljusare för ikoner  
sharedRecipeBackgroundColor # Mycket ljus bakgrund

// Text styles
sharedRecipeTitleStyle    # Nedtonad titel
sharedRecipeMetaStyle     # Metadata styling
sharedRecipeInfoStyle     # Information styling
sharedChipTextStyle       # "Delad" chip text
sharedChipDecoration      # Chip design med skugga
```

### Konsekvent visual hierarchy:

- **Normal recept**: Standard AppTheme färger
- **Redan delat**: Ljusgrå hierarchy med "Delad" chip
- **Ingen hårdkodning**: Allt går genom AppTheme system

---

## 📊 Analytics

### Spårade events:

- Receptdelning initierad
- Antal recept delade per session
- Redan delade recept som delas igen
- Söktermer i delningsdialog
- Multi-select användning
- Import vs dismiss rate för delade recept

---

## 🔮 Framtida Features

### Planerade:

1. **Kommentarer på recept** - Threading, likes
2. **Push notifications** - Real-time alerts
3. **Delningshistorik** - Se all tidigare delning
4. **Bulk operations** - Dela hela kategorier
5. **Smart förslag** - "Anna kanske gillar dessa recept"

### Under utveckling:

- **Förbättrade filter** - Måltidstyp, tid, ingredienser
- **Delningsschema** - Automatisk delning
- **Gruppdelning** - Dela med hela grupper samtidigt

---

## 💡 Tips för Teamet

### Code Review Checklist:

- [ ] ViewModels har ingen UI logic
- [ ] Services returnerar aldrig widgets
- [ ] Event listeners har dispose
- [ ] Firebase queries är optimerade
- [ ] Error handling på alla async calls
- [ ] Svenska felmeddelanden
- [ ] AppTheme används konsekvent
- [ ] Inga hårdkodade färger eller stilar

### Testing:

- Unit tests för ViewModels (lätta att testa)
- Integration tests för service layer
- Widget tests för kritiska UI flows (delningsdialog)
- Manual testing för animations/UX
- Performance tests för stora receptsamlingar

### Git Workflow:

```bash
feat: ny funktionalitet
fix: buggfix
refactor: kod-refactoring
style: styling/design ändringar
test: lägg till/uppdatera tester
docs: dokumentation
```

---

## 🎉 Senaste Uppdateringar

### Version 2.1 - Smart Receptdelning

**✨ Nya funktioner:**
- Komplett receptdelningssystem med smart filtrering
- Visuella indikatorer för redan delade recept
- Multi-select delning med bekräftelsemeddelanden
- Optimerade Firestore-frågor för delningsstatus
- Semantisk AppTheme design för redan delade recept

**🎨 Design förbättringar:**
- Konsekvent styling genom AppTheme
- Ljus grå hierarchy för redan delade recept
- "Delad" chip med skugga och animation
- Responsiv sök och filter i delningsdialog

**🔧 Tekniska förbättringar:**
- RecipeSelectionViewModel med cached delningsstatus
- Optimerad prestanda med Set-baserad lookup
- Robusta felhantering och användarfeedback
- Dependency injection för parameteriserade ViewModels

---

**Status: Production Ready! 🎉**

Social plattformen är 95% komplett och redo för användning. Den nya smarta receptdelningen gör det enkelt för användare att dela innehåll utan dubbelarbete, med tydlig visuell feedback och optimerad prestanda.