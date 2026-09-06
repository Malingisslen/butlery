---
name: "source-command-responsive-layout-validator"
description: "Validates Center + ConstrainedBox responsive pattern with Breakpoints constants. Use when creating dialogs, forms, detail views, settings pages, or when hardcoded width values are present."
---

# source-command-responsive-layout-validator

Use this skill when the user asks to run the migrated source command `responsive-layout-validator`.

## Command Template

# Responsive Layout Validator

> Validate Center + ConstrainedBox pattern for dialogs/forms.

## Primärt Mönster

```dart
Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: Breakpoints.contentWidthMedium),
    child: SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.spacingM),
        child: content,
      ),
    ),
  ),
)
```

## Breakpoints

| Konstant | Värde | Användning |
|----------|-------|------------|
| `Breakpoints.contentWidthNarrow` | 500-600px | Smala formulär, dialoger |
| `Breakpoints.contentWidthMedium` | 700-800px | Standard content |
| `Breakpoints.contentWidthWide` | 900-1200px | Breda listor, dashboards |

## Kritiska Fel

### ❌ Hårdkodad bredd

```dart
Container(
  width: 600, // FEL - använd Breakpoints
  child: content,
)
```

### ✅ Breakpoint-konstant

```dart
ConstrainedBox(
  constraints: BoxConstraints(maxWidth: Breakpoints.contentWidthMedium),
  child: content,
)
```

---

### ❌ Saknar Center

```dart
// FEL - content hamnar till vänster på stora skärmar
ConstrainedBox(
  constraints: BoxConstraints(maxWidth: 800),
  child: content,
)
```

### ✅ Center + ConstrainedBox

```dart
// RÄTT - centrerat på alla skärmstorlekar
Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: Breakpoints.contentWidthMedium),
    child: content,
  ),
)
```

---

### ❌ Saknar scroll

```dart
// FEL - overflow på små skärmar
Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: 800),
    child: Column(children: [...]), // Kan överfylla
  ),
)
```

### ✅ Med SingleChildScrollView

```dart
Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: 800),
    child: SingleChildScrollView(
      child: Column(children: [...]),
    ),
  ),
)
```

## Dialog-mönster

```dart
showDialog(
  context: context,
  builder: (context) => Dialog(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: Breakpoints.contentWidthNarrow,
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: content,
    ),
  ),
);
```

## Form-mönster

```dart
Scaffold(
  body: Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: Breakpoints.contentWidthMedium),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppDimensions.spacingM),
        child: Form(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: formFields,
          ),
        ),
      ),
    ),
  ),
)
```

## Checklista för Views

- [ ] `Center` som yttre wrapper
- [ ] `ConstrainedBox` med Breakpoints-konstant
- [ ] `SingleChildScrollView` för scrollbart innehåll
- [ ] `Padding` med AppDimensions-konstant
- [ ] Ingen hårdkodad width
