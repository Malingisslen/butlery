# Real-Time Models

Comprehensive guide to Butlery's real-time collaboration models: RealtimeResource, RealtimeRecipe, RealtimeMenu, and RealtimeMetadata.

## Overview

Butlery's real-time models provide:
- **Permission management** - Multi-level access control
- **Activity tracking** - Last edited, edit frequency, collaboration metrics
- **Conflict resolution** - editCount and timestamp tracking
- **Participant management** - Owner, admins, editors, viewers

**Model Hierarchy**:
```
RealtimeResource (base class)
  ├─ RealtimeRecipe
  └─ RealtimeMenu
```

---

## RealtimeResource (Base Class)

**Location**: `lib/models/realtime/realtime_resource.dart`

**Purpose**: Base class for all collaborative resources with permission management and activity tracking

### Core Fields

```dart
class RealtimeResource {
  // Identification
  final String id;
  final String type;  // 'recipe', 'menu', etc.

  // Ownership
  final String ownerId;
  final String ownerDisplayName;

  // Participants (userId -> PermissionLevel)
  final Map<String, String> participants;

  // Activity tracking
  final DateTime createdAt;
  final DateTime lastEditedAt;
  final String? lastEditedBy;
  final String? lastEditedByDisplayName;
  final int editCount;  // Incremented on each edit (conflict resolution key)

  // Status
  final bool isActive;

  // Additional data
  final Map<String, dynamic>? metadata;

  RealtimeResource({
    required this.id,
    required this.type,
    required this.ownerId,
    required this.ownerDisplayName,
    required this.participants,
    required this.createdAt,
    required this.lastEditedAt,
    this.lastEditedBy,
    this.lastEditedByDisplayName,
    required this.editCount,
    required this.isActive,
    this.metadata,
  });
}
```

### Permission Methods

```dart
// Check if user has specific permission
bool hasPermission(String userId, PermissionLevel requiredLevel) {
  final userPermission = participants[userId];
  if (userPermission == null) return false;

  final userLevel = _parsePermissionLevel(userPermission);
  return _isPermissionSufficient(userLevel, requiredLevel);
}

// Check if user can edit
bool canUserEdit(String userId) {
  return hasPermission(userId, PermissionLevel.editor);
}

// Check if user can delete
bool canUserDelete(String userId) {
  return isOwner(userId);  // Only owner can delete
}

// Check if user can manage permissions
bool canUserManagePermissions(String userId) {
  return hasPermission(userId, PermissionLevel.admin);
}

// Check if user can invite others
bool canUserInvite(String userId) {
  return hasPermission(userId, PermissionLevel.admin);
}

// Check if user can leave
bool canUserLeave(String userId) {
  return isParticipant(userId) && !isOwner(userId);
}

// Check if user is owner
bool isOwner(String userId) {
  return ownerId == userId;
}

// Check if user is participant
bool isParticipant(String userId) {
  return participants.containsKey(userId);
}
```

### Permission Levels

```dart
enum PermissionLevel {
  owner,   // Full control, cannot be removed
  admin,   // Can manage participants and edit content
  editor,  // Can edit content (write access)
  viewer,  // Can view only (read access)
}

// Permission hierarchy (for comparison)
bool _isPermissionSufficient(
  PermissionLevel userLevel,
  PermissionLevel requiredLevel,
) {
  const hierarchy = {
    PermissionLevel.viewer: 1,
    PermissionLevel.editor: 2,
    PermissionLevel.admin: 3,
    PermissionLevel.owner: 4,
  };

  return hierarchy[userLevel]! >= hierarchy[requiredLevel]!;
}
```

### Activity Tracking

```dart
// Time since last edit
Duration get timeSinceLastEdit {
  return DateTime.now().difference(lastEditedAt);
}

// Human-readable time ago
String get lastEditedTimeAgo {
  final duration = timeSinceLastEdit;

  if (duration.inMinutes < 1) return 'just nu';
  if (duration.inMinutes < 60) return '${duration.inMinutes} min sedan';
  if (duration.inHours < 24) return '${duration.inHours} timmar sedan';
  if (duration.inDays < 7) return '${duration.inDays} dagar sedan';
  if (duration.inDays < 30) return '${(duration.inDays / 7).floor()} veckor sedan';
  return '${(duration.inDays / 30).floor()} månader sedan';
}

// Check if recently active (within 7 days)
bool get hasRecentActivity {
  return timeSinceLastEdit.inDays < 7;
}

// Check if active this week
bool get hasWeeklyActivity {
  return timeSinceLastEdit.inDays < 7;
}

// Get activity summary
Map<String, dynamic> getChangesSummary() {
  return {
    'totalEdits': editCount,
    'lastEditedBy': lastEditedByDisplayName,
    'lastEditedAt': lastEditedAt,
    'timeSinceLastEdit': lastEditedTimeAgo,
    'uniqueEditors': participants.length,
  };
}

// Activity text for UI
String get activityText {
  if (timeSinceLastEdit.inMinutes < 5) return 'Aktiv nu';
  if (timeSinceLastEdit.inHours < 1) return 'Aktiv';
  return 'Inaktiv';
}
```

### Firestore Serialization

```dart
Map<String, dynamic> toFirestore() {
  return {
    'id': id,
    'type': type,
    'ownerId': ownerId,
    'ownerDisplayName': ownerDisplayName,
    'participants': participants,
    'createdAt': Timestamp.fromDate(createdAt),
    'lastEditedAt': Timestamp.fromDate(lastEditedAt),
    'lastEditedBy': lastEditedBy,
    'lastEditedByDisplayName': lastEditedByDisplayName,
    'editCount': editCount,
    'isActive': isActive,
    'metadata': metadata,
  };
}

factory RealtimeResource.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;

  return RealtimeResource(
    id: doc.id,
    type: data['type'] as String,
    ownerId: data['ownerId'] as String,
    ownerDisplayName: data['ownerDisplayName'] as String,
    participants: Map<String, String>.from(data['participants'] as Map),
    createdAt: (data['createdAt'] as Timestamp).toDate(),
    lastEditedAt: (data['lastEditedAt'] as Timestamp).toDate(),
    lastEditedBy: data['lastEditedBy'] as String?,
    lastEditedByDisplayName: data['lastEditedByDisplayName'] as String?,
    editCount: data['editCount'] as int,
    isActive: data['isActive'] as bool,
    metadata: data['metadata'] as Map<String, dynamic>?,
  );
}
```

---

## RealtimeRecipe

**Location**: `lib/models/realtime/realtime_recipe.dart`

**Purpose**: Collaborative recipe editing with multi-user support

### Additional Fields

```dart
class RealtimeRecipe extends RealtimeResource {
  final Recipe recipe;  // Contains title, ingredients, instructions, etc.

  RealtimeRecipe({
    required String id,
    required String ownerId,
    required String ownerDisplayName,
    required Map<String, String> participants,
    required this.recipe,
    required DateTime createdAt,
    required DateTime lastEditedAt,
    String? lastEditedBy,
    String? lastEditedByDisplayName,
    required int editCount,
    required bool isActive,
    Map<String, dynamic>? metadata,
  }) : super(
          id: id,
          type: 'recipe',
          ownerId: ownerId,
          ownerDisplayName: ownerDisplayName,
          participants: participants,
          createdAt: createdAt,
          lastEditedAt: lastEditedAt,
          lastEditedBy: lastEditedBy,
          lastEditedByDisplayName: lastEditedByDisplayName,
          editCount: editCount,
          isActive: isActive,
          metadata: metadata,
        );
}
```

### Recipe Model

```dart
class Recipe {
  final String? id;
  final String title;
  final String? description;
  final List<Ingredient> ingredients;
  final List<String> instructions;
  final List<String> imageUrls;
  final MealType? mealType;
  final int? portions;
  final int? timeMinutes;
  final double? rating;
  final List<String> tags;

  Recipe({
    this.id,
    required this.title,
    this.description,
    required this.ingredients,
    required this.instructions,
    required this.imageUrls,
    this.mealType,
    this.portions,
    this.timeMinutes,
    this.rating,
    required this.tags,
  });
}
```

### Delegate Operations

RealtimeRecipe delegates operations to focused modules:

```dart
// Content operations (via RecipeOperations module)
void addIngredient(Ingredient ingredient) {
  recipe.ingredients.add(ingredient);
}

void removeIngredient(String ingredientId) {
  recipe.ingredients.removeWhere((i) => i.id == ingredientId);
}

void addInstruction(String instruction) {
  recipe.instructions.add(instruction);
}

// Participant management (via RecipeParticipants module)
void addParticipant(String userId, PermissionLevel permission) {
  participants[userId] = permission.toString();
}

void removeParticipant(String userId) {
  if (!isOwner(userId)) {
    participants.remove(userId);
  }
}
```

### Usage Example

```dart
final realtimeRecipe = RealtimeRecipe(
  id: 'recipe-123',
  ownerId: 'user-123',
  ownerDisplayName: 'John Doe',
  participants: {
    'user-123': 'owner',
    'user-456': 'editor',
    'user-789': 'viewer',
  },
  recipe: Recipe(
    title: 'Pasta Carbonara',
    description: 'Classic Italian pasta dish',
    ingredients: [
      Ingredient(name: 'Pasta', amount: 400, unit: 'g'),
      Ingredient(name: 'Eggs', amount: 4, unit: 'st'),
      Ingredient(name: 'Bacon', amount: 200, unit: 'g'),
    ],
    instructions: [
      'Boil pasta according to package',
      'Fry bacon until crispy',
      'Mix eggs with pasta and bacon',
    ],
    imageUrls: ['https://example.com/image.jpg'],
    mealType: MealType.dinner,
    portions: 4,
    timeMinutes: 30,
    tags: ['Italian', 'Pasta', 'Quick'],
  ),
  createdAt: DateTime.now().subtract(Duration(days: 7)),
  lastEditedAt: DateTime.now().subtract(Duration(hours: 2)),
  lastEditedBy: 'user-456',
  lastEditedByDisplayName: 'Jane Smith',
  editCount: 15,
  isActive: true,
);

// Check permissions
if (realtimeRecipe.canUserEdit('user-456')) {
  print('User can edit');
}

// Activity tracking
print('Last edited: ${realtimeRecipe.lastEditedTimeAgo}');
print('Active: ${realtimeRecipe.hasRecentActivity}');
```

---

## RealtimeMenu

**Location**: `lib/models/realtime/realtime_menu.dart`

**Purpose**: Category-based collaborative menu planning

### Additional Fields

```dart
class RealtimeMenu extends RealtimeResource {
  final RealtimeMenuData data;

  RealtimeMenu({
    required String id,
    required String ownerId,
    required String ownerDisplayName,
    required Map<String, String> participants,
    required this.data,
    required DateTime createdAt,
    required DateTime lastEditedAt,
    String? lastEditedBy,
    String? lastEditedByDisplayName,
    required int editCount,
    required bool isActive,
    Map<String, dynamic>? metadata,
  }) : super(
          id: id,
          type: 'menu',
          ownerId: ownerId,
          ownerDisplayName: ownerDisplayName,
          participants: participants,
          createdAt: createdAt,
          lastEditedAt: lastEditedAt,
          lastEditedBy: lastEditedBy,
          lastEditedByDisplayName: lastEditedByDisplayName,
          editCount: editCount,
          isActive: isActive,
          metadata: metadata,
        );

  // Convenience getters
  Map<String, List<Recipe>> get categories => data.categories;
  String get title => data.title ?? 'Veckomeny';
  String? get menuNotes => data.menuNotes;
  List<String> get favoriteRecipeIds => data.favoriteRecipeIds;
  String? get originalPrompt => data.originalPrompt;
  DateTime? get createdForDate => data.createdForDate;
}
```

### RealtimeMenuData

```dart
class RealtimeMenuData {
  final Map<String, List<Recipe>> categories;  // 'Måndag' -> [Recipe, Recipe]
  final String? title;
  final String? menuNotes;
  final List<String> favoriteRecipeIds;
  final String? originalPrompt;
  final DateTime? createdForDate;

  RealtimeMenuData({
    required this.categories,
    this.title,
    this.menuNotes,
    required this.favoriteRecipeIds,
    this.originalPrompt,
    this.createdForDate,
  });
}
```

### Category Operations

```dart
// Add recipe to category
void addRecipeToCategory(String categoryName, Recipe recipe) {
  categories[categoryName] ??= [];
  categories[categoryName]!.add(recipe);
}

// Remove recipe from category
void removeRecipeFromCategory(String categoryName, String recipeId) {
  categories[categoryName]?.removeWhere((r) => r.id == recipeId);
}

// Move recipe between categories
void moveRecipe(String recipeId, String fromCategory, String toCategory) {
  final recipe = categories[fromCategory]
      ?.firstWhere((r) => r.id == recipeId);

  if (recipe != null) {
    removeRecipeFromCategory(fromCategory, recipeId);
    addRecipeToCategory(toCategory, recipe);
  }
}

// Get total recipe count
int get totalRecipes {
  return categories.values.fold(0, (sum, list) => sum + list.length);
}

// Get all recipes (flat list)
List<Recipe> get allRecipes {
  return categories.values.expand((list) => list).toList();
}
```

### Usage Example

```dart
final realtimeMenu = RealtimeMenu(
  id: 'menu-123',
  ownerId: 'user-123',
  ownerDisplayName: 'John Doe',
  participants: {
    'user-123': 'owner',
    'user-456': 'editor',
  },
  data: RealtimeMenuData(
    title: 'Veckomeny - Vecka 5',
    menuNotes: 'Vegetariska rätter',
    categories: {
      'Måndag': [Recipe(title: 'Pasta'), Recipe(title: 'Sallad')],
      'Tisdag': [Recipe(title: 'Pizza')],
      'Onsdag': [Recipe(title: 'Tacos'), Recipe(title: 'Guacamole')],
    },
    favoriteRecipeIds: ['recipe-1', 'recipe-3'],
    originalPrompt: 'En vecka med vegetariska rätter',
    createdForDate: DateTime(2025, 2, 3),
  ),
  createdAt: DateTime.now().subtract(Duration(days: 14)),
  lastEditedAt: DateTime.now().subtract(Duration(hours: 5)),
  lastEditedBy: 'user-456',
  lastEditedByDisplayName: 'Jane Smith',
  editCount: 8,
  isActive: true,
);

// Category operations
print('Total recipes: ${realtimeMenu.totalRecipes}');  // 5
print('Categories: ${realtimeMenu.categories.keys.join(', ')}');  // Måndag, Tisdag, Onsdag

// Add recipe
realtimeMenu.addRecipeToCategory('Torsdag', Recipe(title: 'Soppa'));
```

---

## RealtimeMetadata

**Location**: `lib/models/realtime/realtime_metadata.dart`

**Purpose**: Extended metadata for activity tracking and collaboration metrics

### Key Methods

```dart
class RealtimeMetadata {
  // Create edit tracking metadata
  static Map<String, dynamic> createEditTracking({
    required String userId,
    required String displayName,
    required int editCount,
  }) {
    return {
      'lastEditedBy': userId,
      'lastEditedByDisplayName': displayName,
      'lastEditedAt': FieldValue.serverTimestamp(),
      'editCount': editCount,
    };
  }

  // Calculate edit frequency (edits per day)
  static double getEditFrequency(
    int editCount,
    DateTime createdAt,
  ) {
    final daysSinceCreation = DateTime.now().difference(createdAt).inDays;
    if (daysSinceCreation == 0) return editCount.toDouble();
    return editCount / daysSinceCreation;
  }

  // Determine if resource is active
  static bool calculateActiveStatus(DateTime lastEditedAt) {
    return DateTime.now().difference(lastEditedAt).inDays < 7;
  }

  // Check if resource is stale (no edits in 30 days)
  static bool isStaleResource(DateTime lastEditedAt) {
    return DateTime.now().difference(lastEditedAt).inDays > 30;
  }

  // Get activity level (1-5 scale)
  static int getActivityLevel(DateTime lastEditedAt, int editCount) {
    final daysSinceEdit = DateTime.now().difference(lastEditedAt).inDays;
    final editFrequency = editCount / max(daysSinceEdit, 1);

    if (daysSinceEdit <= 1) return 5;  // Very active
    if (daysSinceEdit <= 3) return 4;  // Active
    if (daysSinceEdit <= 7) return 3;  // Moderate
    if (daysSinceEdit <= 30) return 2;  // Low
    return 1;  // Inactive
  }

  // Calculate edit velocity (edits in last 7 days)
  static int calculateEditVelocity(List<DateTime> editTimestamps) {
    final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7));
    return editTimestamps.where((t) => t.isAfter(sevenDaysAgo)).length;
  }

  // Get collaboration score (0-100)
  static int getCollaborationScore(
    int participantCount,
    int editCount,
    DateTime createdAt,
  ) {
    final daysSinceCreation = DateTime.now().difference(createdAt).inDays;
    final editsPerDay = editCount / max(daysSinceCreation, 1);
    final participantScore = min(participantCount * 10, 50);
    final activityScore = min(editsPerDay * 10, 50);

    return (participantScore + activityScore).round();
  }

  // Generate edit summary
  static String generateEditSummary(
    int editCount,
    int participantCount,
    DateTime lastEditedAt,
  ) {
    final timeAgo = _formatTimeAgo(lastEditedAt);
    return '$editCount ändringar av $participantCount användare. Senast: $timeAgo';
  }
}
```

---

## Best Practices

1. **Always check permissions before edits**
   - Use `canUserEdit()`, `canUserDelete()`, etc.
   - Validate at service layer AND model layer

2. **Increment editCount on every change**
   - Critical for conflict resolution
   - Never skip incrementing

3. **Update activity tracking fields**
   - lastEditedAt, lastEditedBy, lastEditedByDisplayName
   - Use `RealtimeMetadata.createEditTracking()`

4. **Use permission hierarchy**
   - owner > admin > editor > viewer
   - Higher permissions include lower permissions

5. **Preserve owner field**
   - Owner cannot be changed
   - Owner cannot be removed from participants

6. **Monitor activity levels**
   - Use `hasRecentActivity`, `activityLevel`
   - Archive stale resources

---

## Related Resources

- [realtime-services.md](realtime-services.md) - Services using these models
- [conflict-resolution.md](conflict-resolution.md) - editCount usage
- [presence-tracking.md](presence-tracking.md) - User presence model

---

**Models**: RealtimeResource, RealtimeRecipe, RealtimeMenu
**Features**: Permission management, activity tracking, conflict resolution
**Status**: ✅ Production-ready
