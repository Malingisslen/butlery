# 🤖 Claude Development Guide - Butlery Coding Standards

> **VIKTIG**: Detta dokument MÅSTE läsas och följas av alla Claude-instanser som arbetar med Butlery-projektet. Det definierar arkitektur, kodstandards och arbetssätt som är kritiska för projektets framgång.

## 📋 Innehållsförteckning

1. [Projektöversikt](#projektöversikt)
2. [Arkitektur & Patterns](#arkitektur--patterns)  
3. [Single Responsibility Principle](#single-responsibility-principle)
4. [Fil- och mappstruktur](#fil--och-mappstruktur)
5. [Kodstandarder](#kodstandarder)
6. [UI & Theming](#ui--theming)
7. [Kommunikationsstil](#kommunikationsstil)
8. [Felsökning & Bästa praxis](#felsökning--bästa-praxis)
9. [Checklista för nya features](#checklista-för-nya-features)

---

## 🎯 Projektöversikt

### Teknisk Stack
- **Frontend**: Flutter/Dart (Android först, iOS-kompatibel)
- **Backend**: Firebase (Auth, Firestore, Storage)
- **Offline**: Hive (lokal cache och sync-kö)
- **State Management**: Provider + ChangeNotifier
- **DI**: GetIt
- **Arkitektur**: MVVM + Repository Pattern
- **Kodstandard**: Dart Style Guide + Flutter linter

### Appens Syfte
Smart app som automatiserar receptflödet - från import/skapande av recept till veckomeny-generering och automatisk inköpslista. Löser vardagsproblem med måltidsplanering flexibelt.

---

## 🏗️ Arkitektur & Patterns

### MVVM + Repository Pattern

```
lib/
├── models/           # 📊 Data classes + business logic
├── viewmodels/       # 🧠 Presentation logic + state management
├── views/           # 📱 UI screens + navigation
├── services/        # 🔧 Business services + API calls
├── repositories/    # 🗄️ Data access layer
├── theme/          # 🎨 Design tokens + styling
└── widgets/        # 🧩 Reusable UI components
```

### Dependency Flow
```
Views → ViewModels → Services → Repositories → Models
  ↓         ↓           ↓           ↓         ↓
Widgets ← Theme ← AppTheme ← Firebase ← Data Classes
```

---

## ⚡ Single Responsibility Principle

**KRITISKT**: Varje fil får bara ha ETT ansvar. Detta är ICKE-FÖRHANDLINGSBART.

### ✅ KORREKT struktur:

#### **Models** (BARA data + business logic)
```dart
// lib/models/recipe.dart
class Recipe {
  final String title;
  final List<String> ingredients;
  
  // ✅ Business logic getters
  bool get isComplete => title.isNotEmpty && ingredients.isNotEmpty;
  
  // ✅ Data transformations  
  Map<String, dynamic> toFirestore() { ... }
  
  // ❌ ALDRIG UI-kod här
  // ❌ ALDRIG AppTheme imports
  // ❌ ALDRIG Widget builders
}
```

#### **Theme** (BARA styling)
```dart
// lib/theme/recipe_theme.dart  
class RecipeTheme {
  // ✅ Colors, TextStyles, Decorations
  static Color getTitleColor() => AppTheme.textPrimary;
  static TextStyle getTitleStyle() => AppTheme.cardTitleStyle;
  
  // ❌ ALDRIG Widget builders
  // ❌ ALDRIG Business logic
}
```

#### **Widgets** (BARA UI komponenter)
```dart
// lib/widgets/recipe/recipe_display_widgets.dart
class RecipeDisplayWidgets {
  // ✅ Widget builders med funktional cohesion
  static Widget buildCard(Recipe recipe) { ... }
  static Widget buildListTile(Recipe recipe) { ... }
  
  // ❌ ALDRIG Styling logic
  // ❌ ALDRIG Business logic
}
```

### 🗂️ Widget Gruppering (Industry Best Practice)

**GRUPPERA relaterade widgets baserat på functional cohesion:**

```
lib/widgets/recipe/
├── recipe_display_widgets.dart    # Card, ListTile, Badge
├── recipe_input_widgets.dart      # Forms, Search, Selection  
├── recipe_state_widgets.dart      # Empty, Loading, Error
└── recipe_layout_widgets.dart     # Grid, List, Collections
```

**VARJE fil ska innehålla 3-8 relaterade widgets med samma ansvar.**

---

## 📁 Fil- och Mappstruktur

### Obligatorisk Struktur

```
lib/
├── main.dart
├── injection.dart                 # GetIt DI setup
├── models/
│   ├── [feature]/
│   │   ├── [model_name].dart     # Data class
│   │   └── [related_model].dart
│   └── permissions/
│       └── resource_permission.dart
├── services/
│   ├── [feature]_service.dart    # Business logic
│   └── firebase/
│       ├── auth_service.dart
│       └── firestore_service.dart
├── viewmodels/
│   ├── [feature]_viewmodel.dart  # State management
│   └── base_viewmodel.dart
├── views/
│   ├── [feature]/
│   │   ├── [feature]_view.dart   # Main screen
│   │   └── widgets/              # Screen-specific widgets
│   └── shared/
│       └── base_view.dart
├── widgets/
│   ├── [feature]/
│   │   ├── [feature]_display_widgets.dart
│   │   ├── [feature]_input_widgets.dart
│   │   ├── [feature]_state_widgets.dart
│   │   └── [feature]_layout_widgets.dart
│   └── common/
│       ├── buttons.dart
│       └── dialogs.dart
├── theme/
│   ├── app_theme.dart            # Master theme
│   ├── [feature]_theme.dart      # Feature-specific styling
│   └── themes.dart               # Theme exports
└── utils/
    ├── constants.dart
    ├── helpers.dart
    └── extensions.dart
```

### Namnkonventioner

- **Filer**: `snake_case.dart`
- **Klasser**: `PascalCase`
- **Variabler**: `camelCase`
- **Konstanter**: `SCREAMING_SNAKE_CASE`
- **Private members**: `_leadingUnderscore`

---

## 📝 Kodstandarder

### AI Info Block (OBLIGATORISKT)

**VARJE fil MÅSTE börja med denna block:**

```dart
/// 🔍 AI INFO BLOCK:
/// Component: [Kort beskrivning av komponenten]
/// File: [relativ sökväg från lib/]
/// Quick Guide: [En mening om vad filen gör]
/// Dependencies IN: [Vad filen importerar/använder]
/// Dependencies OUT: [Vad som använder denna fil]
/// Data flow: [Hur data flödar genom komponenten]
/// State management: [Hur state hanteras]
/// Purpose: [Varför denna fil existerar]
/// Common issues: [Vanliga problem och lösningar]
/// Test coverage: [Testnivå och typ]
/// Performance: [Prestandakarakteristik]
/// Analytics: [Vad som loggas/trackas]
/// Code smells: [Kvalitetsstatus och förbättringar]
/// Connected to: [Relaterade filer och komponenter]
/// Used in phases: [Vilken fas av utveckling]
```

### Imports Organisation

```dart
// 1. Dart core imports
import 'dart:async';
import 'dart:convert';

// 2. Flutter imports  
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 3. Package imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

// 4. Internal imports (relativt)
import '../models/recipe.dart';
import '../theme/app_theme.dart';
import 'widgets/recipe_card.dart';
```

### Kommentarer

```dart
// ===== SECTION HEADERS =====
/// Documentation comments för public APIs
// Förklarande kommentarer på svenska för complex logic
// TODO: Specifika todo items med ägare
// FIXME: Kända buggar som behöver fixas
// HACK: Temporära lösningar som behöver refaktoreras
```

---

## 🎨 UI & Theming

### AppTheme Supremacy

**ABSOLUT REGEL**: All styling MÅSTE komma från AppTheme. INGA hårdkodade värden.

#### ✅ KORREKT:
```dart
Container(
  padding: AppTheme.cardPadding,
  decoration: AppTheme.cardDecoration,
  child: Text(
    'Hello',
    style: AppTheme.cardTitleStyle,
  ),
)
```

#### ❌ FÖRBJUDET:
```dart
Container(
  padding: EdgeInsets.all(16), // ❌ Hårdkodat
  decoration: BoxDecoration(
    color: Color(0xFFFFFFFF), // ❌ Hårdkodat
  ),
  child: Text(
    'Hello',
    style: TextStyle(fontSize: 18), // ❌ Hårdkodat
  ),
)
```

### Theme Hierarki

```
AppTheme (master)
├── Colors (primärfärger, semantiska färger)
├── TextStyles (semantiska text styles)
├── Spacing (standardiserade spacing)
├── Decorations (kort, knappar, etc.)
└── Components (kompletta komponenter)
    ↓
[Feature]Theme (feature-specifik styling)
├── Feature colors
├── Feature text styles  
├── Feature decorations
└── Feature constants
    ↓
[Feature]Widgets (widget builders)
├── UI komponenter
├── State widgets
└── Layout widgets
```

### Responsive Design

```dart
// Använd MediaQuery för responsivitet
final screenWidth = MediaQuery.of(context).size.width;
final isTablet = screenWidth > 768;

// Använd AppTheme för adaptive spacing
final padding = isTablet 
    ? AppTheme.spacingXl 
    : AppTheme.spacingMd;
```

---

## 💬 Kommunikationsstil

### Språk & Förklaringar

- **Primärspråk**: Svenska (enligt user preferences)
- **Nybörjarvänligt**: ALLTID steg-för-steg instruktioner
- **Tekniska termer**: ALLTID förklara enkelt och pedagogiskt
- **Alternativ**: ALLTID ge robust + skalbart alternativ
- **Djupförklaring**: ALLTID fråga: "Vill du att jag förklarar [term] mer?"

### Exempel på Kommunikation

```
"Nu ska vi skapa en service för att hantera recept. En service är som en 
hjälpare som sköter all kommunikation med databasen åt oss.

Vill du att jag förklarar mer om vad en service är och varför vi använder det?"
```

### Före Kodändringar

1. **BE** om aktuell fil - hitta ALDRIG på kod
2. **UTGÅ** från att kod finns, annars informerar användaren
3. **FRÅGA**: "Kan du visa mig din nuvarande [filnamn]?"

### Efter Kodändringar

1. **Testa**: "Testa nu genom att köra appen med `flutter run`"
2. **Git commit**: `git commit -m "feat: lägg till receptservice"`
3. **Lista ändringar**: "Vi har nu lagt till: 1) ... 2) ... 3) ..."
4. **Dependencies**: "Kör `flutter pub get` om du får fel"

---

## 🔧 Felsökning & Bästa Praxis

### Error Handling Pattern

```dart
try {
  final result = await service.getData();
  return Success(result);
} on FirebaseException catch (e) {
  return Failure('Firebase error: ${e.message}');
} on NetworkException catch (e) {
  return Failure('Network error: ${e.message}');
} catch (e) {
  return Failure('Unexpected error: $e');
}
```

### Async/Await Pattern

```dart
// ✅ KORREKT
Future<void> loadData() async {
  setState(() => isLoading = true);
  
  try {
    final data = await repository.fetchData();
    setState(() {
      this.data = data;
      isLoading = false;
    });
  } catch (e) {
    setState(() {
      error = e.toString();
      isLoading = false;
    });
  }
}

// ❌ UNDVIK
loadData().then((data) => {
  // Callback hell
});
```

### Memory Management

```dart
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late TextEditingController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }
  
  @override
  void dispose() {
    _controller.dispose(); // ✅ KRITISKT - undvik memory leaks
    super.dispose();
  }
}
```

---

## ✅ Checklista för Nya Features

### Innan Du Börjar Koda

- [ ] **Projektplan**: Diskutera approach med användaren
- [ ] **Mappstruktur**: Bekräfta var filer ska placeras
- [ ] **Dependencies**: Kontrollera vad som behöver importeras
- [ ] **Git status**: `git status` för att se current state

### Under Utveckling

- [ ] **AI Info Block**: Lägg till i toppen av varje ny fil
- [ ] **Single Responsibility**: En fil = ett ansvar
- [ ] **AppTheme**: All styling från theme, inga hårdkodade värden
- [ ] **Error Handling**: Proper try/catch och user feedback
- [ ] **Documentation**: Svenska kommentarer för complex logic

### Efter Implementation  

- [ ] **Testing**: `flutter run` och testa funktionalitet
- [ ] **Git Commit**: Meaningful commit message
- [ ] **Dependencies**: `flutter pub get` om nya packages
- [ ] **Documentation**: Uppdatera README om behövs
- [ ] **User Guide**: Förklara vad som gjordes och varför

### Kod Review Checklist

- [ ] **Imports**: Organiserade korrekt (core, flutter, packages, internal)
- [ ] **Naming**: Konsekvent med projekt conventions
- [ ] **Performance**: Inga onödiga rebuilds eller minneslästor
- [ ] **Accessibility**: Text scaling, focus handling
- [ ] **Error States**: Hantering av loading, error, empty states

---

## 🚨 Kritiska Förbud

### ALDRIG gör detta:

1. **❌ Hårdkodade UI-värden**
   ```dart
   padding: EdgeInsets.all(16), // FÖRBJUDET
   ```

2. **❌ Business logic i Widgets**
   ```dart
   class MyWidget extends StatelessWidget {
     Widget build(context) {
       final user = FirebaseAuth.instance.currentUser; // FÖRBJUDET
     }
   }
   ```

3. **❌ Direct Firebase calls i Widgets**
   ```dart
   FirebaseFirestore.instance.collection('users') // FÖRBJUDET
   ```

4. **❌ Blandade ansvar i samma fil**
   ```dart
   // recipe_widgets.dart
   class RecipeCard {} // Display
   class RecipeForm {} // Input  
   class RecipeError {} // State
   // FÖRBJUDET - olika ansvar
   ```

5. **❌ Imports utan organisation**
   ```dart
   import '../theme/app_theme.dart';
   import 'package:flutter/material.dart'; // FÖRBJUDET - fel ordning
   ```

---

## 🎯 Success Metrics

### Kod Kvalitet

- **File Size**: Max 400 linjer per fil
- **Cyclomatic Complexity**: Max 10 per method
- **Single Responsibility**: 1 ansvar per fil
- **Test Coverage**: >80% för business logic
- **Performance**: <16ms per frame, <100ms cold start

### User Experience

- **Accessibility**: WCAG 2.1 AA compliance
- **Performance**: <2s initial load
- **Offline**: Grundfunktioner fungerar offline
- **Error Handling**: Graceful degradation
- **Responsive**: Fungerar på 5"-12" skärmar

---

## 📚 Referenser

### Viktiga Dokument

- [Flutter Style Guide](https://dart.dev/guides/language/effective-dart/style)
- [Material Design 3](https://m3.material.io/)
- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

### Intern Dokumentation

- `project_plan.md` - Utvecklingsplan och faser
- `ai_code_index.md` - AI-genererad kod registry
- `README.md` - Projektöversikt och setup

---

## 🔄 Uppdateringar

Detta dokument är **levande** och ska uppdateras när:

- Nya patterns introduceras
- Arkitekturen förändras  
- Bästa praxis utvecklas
- Nya team members tillkommer

**Senast uppdaterad**: 2025-01-03
**Version**: 1.0
**Nästa review**: 2025-02-01

---

**🎉 Framgång!** Följ denna guide för att säkerställa konsistent, skalbar och underhållbar kod i Butlery-projektet.