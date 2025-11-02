# Data Export - GDPR Article 15

Guide to implementing data portability using DataExportService for GDPR Article 15 compliance.

## Overview

**GDPR Article 15** gives users the right to access all their personal data:
- **Complete data export** - All user data in machine-readable format
- **Self-service** - Available from settings, no support needed
- **Immediate** - Export generated on demand
- **Portable format** - JSON for easy import elsewhere

**Implementation**: DataExportService with comprehensive data collection

## DataExportService

**Location**: `lib/services/account/data_export_service.dart`

### Key Methods

```dart
class DataExportService {
  // Export all user data as structured map
  Future<Map<String, dynamic>> exportUserData(String userId);

  // Export as JSON string
  Future<String> exportAsJson(String userId);

  // Export and save to file
  Future<File> exportAsFile(String userId, String filename);
}
```

### Export Data Structure

```json
{
  "exportDate": "2025-01-31T10:00:00Z",
  "user": {
    "id": "user-123",
    "email": "user@example.com",
    "displayName": "John Doe",
    "createdAt": "2024-01-01T00:00:00Z"
  },
  "recipes": [
    {
      "id": "recipe-1",
      "title": "Pasta Carbonara",
      "ingredients": ["pasta", "eggs", "bacon"],
      "instructions": ["Boil pasta", "Mix eggs"],
      "createdAt": "2024-06-15T12:00:00Z"
    }
  ],
  "menus": [...],
  "shoppingLists": [...],
  "preferences": {
    "darkMode": false,
    "language": "sv",
    "notifications": true
  },
  "social": {
    "friends": [...],
    "ratings": [...],
    "comments": [...]
  }
}
```

## Implementation

### exportUserData() Method

```dart
Future<Map<String, dynamic>> exportUserData(String userId) async {
  // Collect all user data from various services
  final user = await _userService.getUserProfile(userId);
  final recipes = await _recipeService.getUserRecipes(userId);
  final menus = await _menuService.getUserMenus(userId);
  final lists = await _shoppingService.getUserLists(userId);
  final preferences = await _userService.getUserPreferences(userId);
  final friends = await _friendsService.getUserFriends(userId);
  final ratings = await _ratingsService.getUserRatings(userId);
  final comments = await _commentsService.getUserComments(userId);

  return {
    'exportDate': DateTime.now().toIso8601String(),
    'user': user.toJson(),
    'recipes': recipes.map((r) => r.toJson()).toList(),
    'menus': menus.map((m) => m.toJson()).toList(),
    'shoppingLists': lists.map((l) => l.toJson()).toList(),
    'preferences': preferences,
    'social': {
      'friends': friends.map((f) => f.toJson()).toList(),
      'ratings': ratings.map((r) => r.toJson()).toList(),
      'comments': comments.map((c) => c.toJson()).toList(),
    },
  };
}
```

### exportAsJson() Method

```dart
Future<String> exportAsJson(String userId) async {
  final data = await exportUserData(userId);
  return jsonEncode(data);
}
```

### exportAsFile() Method

```dart
Future<File> exportAsFile(String userId, String filename) async {
  final jsonString = await exportAsJson(userId);

  // Get app documents directory
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$filename');

  // Write JSON to file
  await file.writeAsString(jsonString);

  return file;
}
```

## Usage Patterns

### Pattern 1: Self-Service Export from Settings

```dart
class DataExportView extends StatefulWidget {
  @override
  _DataExportViewState createState() => _DataExportViewState();
}

class _DataExportViewState extends State<DataExportView> {
  bool _isExporting = false;

  Future<void> _exportData() async {
    setState(() => _isExporting = true);

    try {
      final exportService = ServiceLocator.get<DataExportService>();
      final userId = authService.currentUserId;

      // Generate export file
      final file = await exportService.exportAsFile(
        userId,
        'my_butlery_data_${DateTime.now().millisecondsSinceEpoch}.json',
      );

      // Share/download file
      await Share.shareFiles([file.path], text: 'My Butlery Data Export');

      // Log audit event
      final auditRepo = ServiceLocator.get<FirebaseAuditRepository>();
      await auditRepo.logAuditEvent(AuditEvent(
        userId: userId,
        action: AuditAction.dataExport,
        resourceType: 'user_data',
        timestamp: DateTime.now(),
      ));

      showSnackbar('Data exported successfully');
    } catch (e) {
      showError('Failed to export data: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Export My Data')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download, size: 64),
            SizedBox(height: 16),
            Text('Download all your data'),
            SizedBox(height: 8),
            Text('Includes recipes, menus, lists, and preferences'),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportData,
              icon: _isExporting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.download),
              label: Text(_isExporting ? 'Exporting...' : 'Export My Data'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Pattern 2: Export with Progress Indicator

```dart
Future<void> _exportWithProgress() async {
  final exportService = ServiceLocator.get<DataExportService>();
  final userId = authService.currentUserId;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Preparing your data export...'),
        ],
      ),
    ),
  );

  try {
    final file = await exportService.exportAsFile(userId, 'my_data.json');
    Navigator.pop(context);  // Close progress dialog

    await Share.shareFiles([file.path]);
  } catch (e) {
    Navigator.pop(context);
    showError('Export failed: $e');
  }
}
```

## Testing Data Export

```dart
group('DataExportService', () {
  late DataExportService service;

  setUp() {
    // Setup mocks for all data sources
    TestServiceLocator.registerMock<UserService>(mockUserService);
    TestServiceLocator.registerMock<RecipeService>(mockRecipeService);
    TestServiceLocator.registerMock<MenuService>(mockMenuService);

    service = ServiceLocator.get<DataExportService>();
  });

  test('export includes all user data', () async {
    // Arrange: Mock data sources
    when(() => mockUserService.getUserProfile(any()))
        .thenAnswer((_) async => testUser);
    when(() => mockRecipeService.getUserRecipes(any()))
        .thenAnswer((_) async => [testRecipe1, testRecipe2]);
    when(() => mockMenuService.getUserMenus(any()))
        .thenAnswer((_) async => [testMenu]);

    // Act
    final exportData = await service.exportUserData('user-123');

    // Assert
    expect(exportData['user'], isNotNull);
    expect(exportData['recipes'], hasLength(2));
    expect(exportData['menus'], hasLength(1));
    expect(exportData['exportDate'], isNotNull);
  });

  test('exportAsJson generates valid JSON', () async {
    final jsonString = await service.exportAsJson('user-123');

    // Verify valid JSON
    expect(() => jsonDecode(jsonString), returnsNormally);

    final data = jsonDecode(jsonString);
    expect(data, isA<Map<String, dynamic>>());
  });
});
```

## Best Practices

1. **Include ALL user data** - Comprehensive export
2. **Machine-readable format** - JSON for portability
3. **Self-service** - No support tickets needed
4. **Immediate generation** - On-demand export
5. **Audit logging** - Log all export requests
6. **File cleanup** - Delete temp files after sharing

## Related Resources

- [consent-management.md](consent-management.md) - Article 7
- [account-deletion.md](account-deletion.md) - Article 17
- [audit-logging.md](audit-logging.md) - Article 30

---

**Impact**: GDPR Article 15 compliance
**Benefit**: User data portability
**Status**: ✅ Production-ready
