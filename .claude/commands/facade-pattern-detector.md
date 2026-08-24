---
description: >
  Recommends facade pattern for files approaching 500 lines. Use when a file
  exceeds 400 lines, adding functionality to large files, seeing section dividers,
  or refactoring complex views/viewmodels/services.
---

# Facade Pattern Detector

> Recommend facade pattern for files approaching 500 lines.

## Regel

**Max 500 rader per fil** (från CLAUDE.md)

| Radantal | Åtgärd |
|----------|--------|
| < 400 | OK |
| 400-500 | Överväg refaktorering |
| > 500 | Kräver facade eller dokumenterat undantag |

## Undantag

Se `/docs/architecture/ACCEPTED_LARGE_FILES.md` för 33 filer som medvetet överskrider gränsen.

## Facade-mönster

### Före (1,648 rader)

```dart
class ChatView extends StatefulWidget {
  // 1,648 rader med allt blandat
  // - App bar logic
  // - Message stream
  // - Input handling
  // - Typing indicators
  // - File uploads
  // ...
}
```

### Efter (116 rader + komponenter)

```dart
// chat_view_facade.dart (116 rader)
class ChatViewFacade extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ChatAppBar(...),
      body: Column(children: [
        Expanded(child: ChatMessageStream(...)),
        if (hasTyping) TypingIndicator(...),
        ChatInputSection(...),
      ]),
    );
  }
}

// Separata filer:
// - chat_app_bar.dart
// - chat_message_stream.dart
// - chat_input_section.dart
// - typing_indicator.dart
```

## ViewModel Facade

### Före (>500 rader)

```dart
class RecipeFormViewModel extends ChangeNotifier {
  // Allt i en fil:
  // - State management
  // - Validation
  // - Image handling
  // - Persistence
  // - Collaboration
}
```

### Efter (managers)

```dart
class RecipeFormViewModel extends ChangeNotifier {
  late final RecipeFormState _state;
  late final RecipeValidationManager _validation;
  late final RecipeImageManager _images;
  late final RecipePersistenceManager _persistence;
  late final RecipeCollaborativeManager _collab;

  // Koordinerar managers, ~200 rader
}
```

## Service Facade

### Före (>500 rader)

```dart
class UnifiedRecipeService {
  // Allt: personal, social, realtime, caching...
}
```

### Efter (modules)

```dart
class UnifiedRecipeService {
  late final PersonalRecipeModule _personal;
  late final SocialRecipeModule _social;
  late final RealtimeRecipeModule _realtime;
  late final RecipeCacheModule _cache;

  PersonalRecipeModule get personal => _personal;
  SocialRecipeModule get social => _social;
  // etc.
}
```

## Extraktions-checklista

1. **Identifiera ansvarsområden** - Vilka distinkta uppgifter har filen?
2. **Skapa komponenter/managers** - En per ansvarsområde
3. **Facade koordinerar** - Huvudfilen delegerar, koordinerar
4. **Exponera via getters** - `get personal`, `get social`, etc.

## Varningssignaler

| Tecken | Åtgärd |
|--------|--------|
| Fil > 400 rader | Överväg uppdelning |
| Många `#region` / section comments | Naturliga brytpunkter |
| Lång constructor | Extrahera till builders |
| Många private methods | Gruppera i managers |

## Kontrollera Filstorlek

```bash
wc -l lib/path/to/file.dart
```

