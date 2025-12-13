# Phase 5: User-Assisted Import

## Overview

When automated extraction (rule-based + LLM) fails to fully extract a recipe, the system falls back to user-assisted import. This allows users to manually select ingredients and instructions from extracted text.

## Architecture

### Flow Diagram

```
Import Attempt
    │
    ├─► ImportSuccess ──► Save Recipe
    │
    ├─► ImportPartial ──► LLM Enhancement ──► ImportSuccess/Failure
    │
    └─► ImportNeedsAssistance ──► User-Assisted Dialog
                                        │
                                        ├─► User selects lines
                                        ├─► User edits fields
                                        └─► Save Recipe
```

### Key Components

1. **AssistedImportDialog** - Main dialog for user-assisted import
2. **TextLineSelector** - Multi-select widget for text lines
3. **AssistedImportViewModel** - State management for the dialog
4. **ImportResultV2 integration** - Handle ImportNeedsAssistance results

## Implementation Plan

### Step 1: TextLineSelector Widget

Location: `lib/widgets/import/text_line_selector.dart`

A scrollable list where users can tap lines to select them as ingredients or instructions.

```dart
class TextLineSelector extends StatelessWidget {
  final List<String> lines;
  final Set<int> selectedIndices;
  final Set<int> highlightedIndices; // Pre-detected likely ingredients
  final ValueChanged<Set<int>> onSelectionChanged;
  final String selectionType; // 'ingredients' or 'instructions'
}
```

Features:
- Tap to toggle selection
- Long-press to start range selection
- Visual distinction for pre-detected lines (likelyIngredientLines)
- Color coding: green for ingredients, blue for instructions

### Step 2: AssistedImportViewModel

Location: `lib/viewmodels/assisted_import_viewmodel.dart`

```dart
class AssistedImportViewModel extends ChangeNotifier {
  // Source data from ImportNeedsAssistance
  final ImportNeedsAssistance sourceData;

  // User selections
  Set<int> selectedIngredientLines = {};
  Set<int> selectedInstructionLines = {};

  // Editable fields
  String title = '';
  String description = '';
  int portions = 4;
  int timeMinutes = 0;
  String mealType = 'dinner';

  // Derived data
  List<String> get ingredients;
  List<String> get instructions;

  // Actions
  void toggleIngredientLine(int index);
  void toggleInstructionLine(int index);
  Future<Recipe> buildRecipe();
}
```

### Step 3: AssistedImportDialog

Location: `lib/widgets/import/assisted_import_dialog.dart`

A multi-step dialog using BaseFormDialog pattern:

**Step 1: Select Ingredients**
- Show extracted text with line selection
- Pre-highlight likely ingredient lines
- "Select All Highlighted" button

**Step 2: Select Instructions**
- Show remaining text (excluding selected ingredients)
- Allow multi-line selection for steps

**Step 3: Review & Edit**
- Title (pre-filled from suggestedTitle)
- Portions, time, meal type
- Editable ingredient list
- Editable instruction list
- Preview thumbnail if available

### Step 4: Integration Points

#### 4.1 ImportManager Changes

Update `_importWithStrategy` to handle ImportNeedsAssistance:

```dart
// In import_manager.dart
if (importResult.needsAssistance) {
  return ImportManagerResult.needsAssistance(
    extractedText: importResult.extractedText,
    partialData: importResult.partialData,
    thumbnailUrl: importResult.thumbnailUrl,
    suggestedTitle: importResult.suggestedTitle,
    likelyIngredientLines: importResult.likelyIngredientLines,
  );
}
```

#### 4.2 URL Import Strategy

Update to return ImportNeedsAssistance when LLM fails:

```dart
// In url_import_strategy.dart, after LLM fallback fails
if (htmlResult != null) {
  final plainText = _stripHtmlTags(htmlResult);
  return ImportResult.needsAssistance(
    extractedText: plainText,
    message: 'Could not automatically extract recipe. Please select the ingredients and instructions.',
    likelyIngredientLines: _detectIngredientLines(plainText),
  );
}
```

#### 4.3 View Integration

In the import view (wherever import is triggered):

```dart
final result = await importManager.autoImport(input);

if (result.needsAssistance) {
  final recipe = await showDialog<Recipe>(
    context: context,
    builder: (_) => AssistedImportDialog(
      extractedText: result.extractedText,
      suggestedTitle: result.suggestedTitle,
      thumbnailUrl: result.thumbnailUrl,
      likelyIngredientLines: result.likelyIngredientLines,
    ),
  );

  if (recipe != null) {
    await importManager.saveImportedRecipe(recipe);
  }
}
```

## File Structure

```
lib/
├── widgets/
│   └── import/
│       ├── assisted_import_dialog.dart    # Main dialog
│       ├── text_line_selector.dart        # Line selection widget
│       └── ingredient_line_detector.dart  # Heuristic detection
├── viewmodels/
│   └── assisted_import_viewmodel.dart     # State management
└── services/
    └── import/
        └── models/
            └── import_manager_result.dart # Updated result type
```

## UI Design

### Color Scheme
- **Ingredient lines**: Green highlight (#E8F5E9)
- **Instruction lines**: Blue highlight (#E3F2FD)
- **Pre-detected lines**: Dashed border
- **Selected lines**: Solid border + filled background

### Accessibility
- Minimum tap target: 48px
- Clear visual feedback on selection
- Screen reader labels for selection state

## Swedish Localization

```dart
// Strings to add
'assisted_import_title': 'Manuell import',
'select_ingredients': 'Välj ingredienser',
'select_instructions': 'Välj instruktioner',
'review_recipe': 'Granska recept',
'tap_to_select': 'Tryck för att välja',
'likely_ingredient': 'Trolig ingrediens',
'selected_count': '{count} valda',
```

## Testing Strategy

1. **Unit tests**: ViewModel logic, line detection heuristics
2. **Widget tests**: TextLineSelector selection behavior
3. **Integration tests**: Full import flow with user assistance

## Success Metrics

- User can complete assisted import in < 60 seconds
- Pre-detection accuracy > 70% for ingredient lines
- Zero data loss during selection process
