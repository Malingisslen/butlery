# Common Widgets Library

Guide to Butlery's reusable component library in `widgets/common/` - 100+ pre-built widgets organized by category for consistent UI across the app.

## Overview

The common widgets library provides:
- **100+ Components**: Pre-built, tested, reusable widgets
- **Organized by Category**: Clear structure for discovery
- **Consistent Design**: Same look/feel across app
- **Swedish Localization**: All text in Swedish
- **Well-Documented**: Clear usage examples

**Location**: `lib/widgets/common/`

## Library Structure

```
lib/widgets/common/
├── dialogs/           - Confirmation, selection, custom dialogs
├── buttons/           - Action buttons, FABs, icon buttons
├── indicators/        - Loading indicators, badges, avatars
├── layout/            - Cards, containers, headers, dividers
├── input/             - Text fields, checkboxes, pickers
├── social/            - Friend avatars, group widgets
├── search_filter/     - Search bars, filter chips
└── profile/           - Profile actions, settings widgets
```

## Dialogs

### Confirmation Dialogs

```dart
// lib/widgets/common/dialogs/confirmation_dialog.dart

// Basic confirmation
await showConfirmationDialog(
  context: context,
  title: 'Ta bort recept?',
  message: 'Detta går inte att ångra',
  confirmText: 'Ta bort',
  cancelText: 'Avbryt',
  onConfirm: () => deleteRecipe(),
);

// Destructive action
await showDestructiveDialog(
  context: context,
  title: 'Radera konto?',
  message: 'All data kommer att raderas permanent',
  onConfirm: () => deleteAccount(),
);
```

### Selection Dialogs

```dart
// Single selection
final selected = await showSelectionDialog<String>(
  context: context,
  title: 'Välj kategori',
  options: ['Frukost', 'Lunch', 'Middag', 'Efterrätt'],
);

// Multi-selection
final selectedIds = await showMultiSelectionDialog<String>(
  context: context,
  title: 'Välj vänner',
  options: friends,
  optionBuilder: (friend) => ListTile(
    title: Text(friend.displayName),
    leading: Avatar(friend.avatarUrl),
  ),
);
```

### Input Dialogs

```dart
// Text input
final text = await showTextInputDialog(
  context: context,
  title: 'Namnge meny',
  hint: 'Ange ett namn',
  initialValue: 'Veckomeny',
  maxLength: 50,
);

// Number input
final portions = await showNumberInputDialog(
  context: context,
  title: 'Antal portioner',
  initialValue: 4,
  min: 1,
  max: 100,
);
```

## Buttons

### Action Buttons

```dart
// lib/widgets/common/buttons/action_buttons.dart

// Primary action
PrimaryActionButton(
  label: 'Spara',
  onPressed: () => save(),
  icon: Icons.save,
)

// Secondary action
SecondaryActionButton(
  label: 'Avbryt',
  onPressed: () => cancel(),
)

// Destructive action
DestructiveActionButton(
  label: 'Ta bort',
  onPressed: () => delete(),
  icon: Icons.delete,
)

// Loading state
PrimaryActionButton(
  label: 'Sparar...',
  onPressed: null,  // Disabled
  isLoading: true,
)
```

### Floating Action Buttons

```dart
// Standard FAB
FloatingActionButton(
  onPressed: () => create(),
  child: Icon(Icons.add),
)

// Extended FAB
FloatingActionButton.extended(
  onPressed: () => create(),
  icon: Icon(Icons.add),
  label: Text('Lägg till recept'),
)

// Custom FAB from common library
CustomFAB(
  icon: Icons.add,
  label: 'Skapa',
  onPressed: () => create(),
  backgroundColor: Theme.of(context).primaryColor,
)
```

### Icon Buttons

```dart
// Standard icon button
IconButton(
  icon: Icon(Icons.share),
  onPressed: () => share(),
)

// With tooltip
IconButtonWithTooltip(
  icon: Icons.favorite_border,
  tooltip: 'Lägg till i favoriter',
  onPressed: () => toggleFavorite(),
)

// Loading icon button
IconButton(
  icon: isLoading
      ? SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Icon(Icons.sync),
  onPressed: isLoading ? null : () => sync(),
)
```

## Indicators

### Loading Indicators

```dart
// lib/widgets/common/indicators/loading_indicators.dart

// Centered loader
CenteredLoadingIndicator()

// Loading overlay
LoadingOverlay(
  isLoading: viewModel.isLoading,
  child: ContentWidget(),
)

// Inline loader
InlineLoadingIndicator(message: 'Laddar...')

// Shimmer effect
ShimmerLoading(
  width: 200,
  height: 100,
)
```

### Badges

```dart
// Notification badge
NotificationBadge(
  count: 5,
  child: Icon(Icons.notifications),
)

// Status badge
StatusBadge(
  label: 'Ny',
  color: Colors.green,
)

// Custom badge
CustomBadge(
  value: '10+',
  position: BadgePosition.topRight,
  child: Icon(Icons.message),
)
```

### Avatars

```dart
// User avatar
UserAvatar(
  imageUrl: user.avatarUrl,
  size: 48,
  onTap: () => viewProfile(user),
)

// Avatar with status indicator
UserAvatarWithStatus(
  imageUrl: user.avatarUrl,
  isOnline: true,
  size: 48,
)

// Avatar group (overlapping avatars)
AvatarGroup(
  users: friends,
  maxVisible: 3,
  size: 40,
)
```

## Layout

### Cards

```dart
// lib/widgets/common/layout/cards.dart

// Recipe card
RecipeCard(
  recipe: recipe,
  onTap: () => viewRecipe(recipe),
  showActions: true,
)

// Horizontal card
HorizontalCard(
  imageUrl: recipe.imageUrl,
  title: recipe.title,
  subtitle: '${recipe.portions} portioner',
  onTap: () => viewRecipe(recipe),
)

// Elevated card with shadow
ElevatedCard(
  child: ContentWidget(),
  elevation: 4,
  borderRadius: 12,
)
```

### Containers

```dart
// Rounded container
RoundedContainer(
  child: ContentWidget(),
  padding: EdgeInsets.all(16),
  backgroundColor: Colors.grey[100],
)

// Section container
SectionContainer(
  title: 'Ingredienser',
  child: IngredientsList(),
  actions: [
    IconButton(icon: Icon(Icons.add), onPressed: () => addIngredient()),
  ],
)
```

### Headers

```dart
// Section header
SectionHeader(
  title: 'Mina Recept',
  action: TextButton(
    child: Text('Visa alla'),
    onPressed: () => viewAll(),
  ),
)

// List header
ListHeader(
  title: 'Favoriter',
  count: favorites.length,
  icon: Icons.favorite,
)
```

### Dividers

```dart
// Standard divider
Divider()

// Thick divider
ThickDivider(
  thickness: 8,
  color: Colors.grey[200],
)

// Divider with text
DividerWithText(text: 'eller')
```

## Input Components

### Text Fields

```dart
// lib/widgets/common/input/text_fields.dart

// Standard text field
CustomTextField(
  label: 'Receptnamn',
  hint: 'Ange namn',
  controller: titleController,
  validator: (value) => value?.isEmpty == true ? 'Namn krävs' : null,
)

// Multiline text field
MultilineTextField(
  label: 'Beskrivning',
  hint: 'Beskriv receptet',
  controller: descriptionController,
  maxLines: 5,
)

// Number input field
NumberInputField(
  label: 'Portioner',
  controller: portionsController,
  min: 1,
  max: 100,
)

// Search field
SearchTextField(
  hint: 'Sök recept...',
  onChanged: (query) => search(query),
  onClear: () => clearSearch(),
)
```

### Checkboxes and Switches

```dart
// Checkbox with label
LabeledCheckbox(
  label: 'Acceptera villkor',
  value: accepted,
  onChanged: (value) => setState(() => accepted = value!),
)

// Switch with label
LabeledSwitch(
  label: 'Aktivera aviseringar',
  value: notificationsEnabled,
  onChanged: (value) => toggleNotifications(value),
)
```

### Pickers

```dart
// Date picker
await showDatePickerDialog(
  context: context,
  initialDate: DateTime.now(),
  firstDate: DateTime.now(),
  lastDate: DateTime.now().add(Duration(days: 365)),
);

// Time picker
await showTimePickerDialog(
  context: context,
  initialTime: TimeOfDay.now(),
);

// Image picker
final image = await showImagePickerDialog(
  context: context,
  source: ImageSource.gallery,
);
```

## Social Widgets

### Friend Widgets

```dart
// lib/widgets/common/social/friend_widgets.dart

// Friend list item
FriendListItem(
  friend: friend,
  onTap: () => viewProfile(friend),
  trailing: IconButton(
    icon: Icon(Icons.message),
    onPressed: () => sendMessage(friend),
  ),
)

// Friend request item
FriendRequestItem(
  request: request,
  onAccept: () => acceptRequest(request),
  onDecline: () => declineRequest(request),
)

// Friend avatar with name
FriendAvatarWithName(
  friend: friend,
  onTap: () => viewProfile(friend),
)
```

### Group Widgets

```dart
// Group card
GroupCard(
  group: group,
  onTap: () => viewGroup(group),
  memberCount: group.members.length,
)

// Group member list
GroupMemberList(
  members: group.members,
  onMemberTap: (member) => viewProfile(member),
  showRole: true,
)
```

## Search and Filter

### Search Bars

```dart
// lib/widgets/common/search_filter/search_bars.dart

// Standard search bar
StandardSearchBar(
  hint: 'Sök recept...',
  onChanged: (query) => search(query),
  onClear: () => clearSearch(),
)

// Persistent search bar
PersistentSearchBar(
  controller: searchController,
  focusNode: searchFocusNode,
  onChanged: (query) => search(query),
  suggestions: searchSuggestions,
  onSuggestionTap: (suggestion) => applySuggestion(suggestion),
)
```

### Filter Chips

```dart
// Filter chip row
FilterChipRow(
  filters: ['Alla', 'Favoriter', 'Senaste'],
  selectedFilter: selectedFilter,
  onFilterSelected: (filter) => applyFilter(filter),
)

// Custom filter chip
CustomFilterChip(
  label: 'Vegetariskt',
  icon: Icons.eco,
  selected: isVegetarianFilter,
  onSelected: (selected) => toggleVegetarian(selected),
)
```

## Profile Widgets

### Profile Actions

```dart
// lib/widgets/common/profile/profile_actions.dart

// Profile action button
ProfileActionButton(
  icon: Icons.settings,
  label: 'Inställningar',
  onTap: () => openSettings(),
)

// Profile menu item
ProfileMenuItem(
  icon: Icons.logout,
  label: 'Logga ut',
  onTap: () => logout(),
  destructive: true,
)
```

## Usage Examples

### Complete Recipe Card

```dart
RecipeCard(
  recipe: recipe,
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RecipeDetailView(recipeId: recipe.id),
    ),
  ),
  actions: [
    IconButton(
      icon: Icon(recipe.isFavorite ? Icons.favorite : Icons.favorite_border),
      onPressed: () => toggleFavorite(recipe),
    ),
    IconButton(
      icon: Icon(Icons.share),
      onPressed: () => shareRecipe(recipe),
    ),
  ],
)
```

### Search with Filters

```dart
Column(
  children: [
    StandardSearchBar(
      hint: 'Sök recept...',
      onChanged: (query) => viewModel.search(query),
    ),
    FilterChipRow(
      filters: ['Alla', 'Frukost', 'Lunch', 'Middag'],
      selectedFilter: viewModel.selectedCategory,
      onFilterSelected: (filter) => viewModel.filterByCategory(filter),
    ),
    Expanded(
      child: RecipeList(recipes: viewModel.filteredRecipes),
    ),
  ],
)
```

### Friend List with Actions

```dart
ListView.builder(
  itemCount: friends.length,
  itemBuilder: (context, index) {
    final friend = friends[index];
    return FriendListItem(
      friend: friend,
      onTap: () => viewProfile(friend),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButtonWithTooltip(
            icon: Icons.message,
            tooltip: 'Skicka meddelande',
            onPressed: () => sendMessage(friend),
          ),
          IconButtonWithTooltip(
            icon: Icons.more_vert,
            tooltip: 'Fler alternativ',
            onPressed: () => showOptions(friend),
          ),
        ],
      ),
    );
  },
)
```

## Creating Custom Common Widgets

### Steps to Add New Widget

1. **Choose Category**: Determine which subfolder (dialogs/, buttons/, etc.)
2. **Create File**: Name descriptively (`custom_button.dart`)
3. **Implement Widget**: Follow patterns from existing widgets
4. **Add Documentation**: Include usage examples
5. **Test**: Write widget tests
6. **Use**: Import and use across app

### Template for New Widget

```dart
// lib/widgets/common/buttons/custom_action_button.dart

import 'package:flutter/material.dart';

/// Custom action button with consistent styling.
///
/// Usage:
/// ```dart
/// CustomActionButton(
///   label: 'Save',
///   onPressed: () => save(),
///   icon: Icons.save,
/// )
/// ```
class CustomActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  const CustomActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : icon != null
              ? Icon(icon)
              : SizedBox.shrink(),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
```

## Best Practices

1. **Reuse First**: Check common/ before creating new widgets
2. **Consistent Naming**: Follow existing naming patterns
3. **Documentation**: Add usage examples in comments
4. **Swedish Text**: All labels in Swedish
5. **Test Coverage**: Write tests for custom widgets
6. **Theme Awareness**: Use Theme.of(context) for colors
7. **Accessibility**: Include semantic labels

## Common Imports

```dart
// Import specific widget
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

// Import category
import 'package:butlery/widgets/common/dialogs/confirmation_dialog.dart';
import 'package:butlery/widgets/common/indicators/loading_indicators.dart';
```

## Related Resources

- [LoadingStateBuilder](loading-state-builder.md) - Using with common widgets
- [StateWidget](state-widget.md) - State display components
- [Widget Composition](widget-composition.md) - Composing common widgets
- Flutter widget catalog - https://docs.flutter.dev/development/ui/widgets
