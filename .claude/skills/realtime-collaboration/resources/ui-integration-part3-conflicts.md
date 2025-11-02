# UI Integration - Part 3: Conflict Resolution & Best Practices

Guide to conflict resolution UI, performance optimization, and best practices for real-time collaboration.

**Part of**: [ui-integration](./ui-integration.md) (split for readability)
**See also**: [Part 1: StreamBuilder](./ui-integration-part1-streambuilder.md), [Part 2: Updates](./ui-integration-part2-updates.md)

## Conflict Resolution UI

### Conflict Dialog

```dart
Future<void> showConflictDialog(
  BuildContext context,
  RealtimeRecipe local,
  RealtimeRecipe server,
) async {
  final choice = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 8),
          Text('Konflikt upptäckt'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Receptet har ändrats av ${server.lastEditedByDisplayName} medan du redigerade.',
          ),
          SizedBox(height: 16),
          Text(
            'Välj vilken version du vill behålla:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          _buildVersionCard(
            'Min version',
            local.lastEditedTimeAgo,
            local.editCount,
            isLocal: true,
          ),
          SizedBox(height: 8),
          _buildVersionCard(
            '${server.lastEditedByDisplayName}s version',
            server.lastEditedTimeAgo,
            server.editCount,
            isLocal: false,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'local'),
          child: Text('Använd min version'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'server'),
          child: Text('Använd deras version'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, 'merge'),
          child: Text('Slå ihop båda'),
        ),
      ],
    ),
  );

  if (choice == null) return;

  final syncService = ServiceLocator.get<RealtimeSyncService>();

  switch (choice) {
    case 'local':
      await syncService.resolveConflict(
        local.id,
        localVersion: local,
        serverVersion: server,
      );
      break;
    case 'server':
      // Use server version (do nothing)
      break;
    case 'merge':
      await _mergeRecipes(local, server);
      break;
  }
}

Widget _buildVersionCard(
  String title,
  String timeAgo,
  int editCount,
  {required bool isLocal},
) {
  return Container(
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(
        color: isLocal ? Colors.blue : Colors.grey,
        width: 2,
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text('Senast ändrad: $timeAgo'),
        Text('$editCount ändringar totalt'),
      ],
    ),
  );
}
```

---

## Performance Optimization

### Debounced Text Input

```dart
class DebouncedTextField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;
  final Duration debounce;

  const DebouncedTextField({
    required this.initialValue,
    required this.onChanged,
    this.debounce = const Duration(milliseconds: 500),
  });

  @override
  _DebouncedTextFieldState createState() => _DebouncedTextFieldState();
}

class _DebouncedTextFieldState extends State<DebouncedTextField> {
  late TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(widget.debounce, () {
      widget.onChanged(value);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onTextChanged,
      decoration: InputDecoration(labelText: 'Titel'),
    );
  }
}
```

### Pagination for Large Lists

```dart
class PaginatedRecipeList extends StatefulWidget {
  @override
  _PaginatedRecipeListState createState() => _PaginatedRecipeListState();
}

class _PaginatedRecipeListState extends State<PaginatedRecipeList> {
  final ScrollController _scrollController = ScrollController();
  final List<RealtimeRecipe> _recipes = [];
  bool _isLoadingMore = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadRecipes() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    final service = ServiceLocator.get<RealtimeRecipeService>();
    final newRecipes = await service.getRecipesPage(
      page: _currentPage,
      pageSize: 20,
    );

    setState(() {
      _recipes.addAll(newRecipes);
      _currentPage++;
      _isLoadingMore = false;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadRecipes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _recipes.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _recipes.length) {
          return Center(child: CircularProgressIndicator());
        }

        return RecipeCard(recipe: _recipes[index]);
      },
    );
  }
}
```

---

## Best Practices

1. **Use StreamBuilder for real-time data**
   - Automatic updates from Firebase
   - Clean stream lifecycle management
   - Error handling built-in

2. **Implement optimistic updates**
   - Update UI immediately
   - Send to server in background
   - Rollback on error

3. **Show activity indicators**
   - Last editor, edit count, online status
   - Visual feedback for user actions
   - Pending operation indicators

4. **Notify users of conflicts**
   - Snackbar for other users' edits
   - Dialog for conflicts requiring resolution
   - Clear version comparison

5. **Optimize performance**
   - Debounce text inputs (500ms)
   - Paginate large lists
   - Cache UI state locally

6. **Handle edge cases**
   - No internet connection
   - Stale data
   - Rapid successive edits

---

## Related Resources

- [realtime-services.md](realtime-services.md) - Services providing streams
- [conflict-resolution.md](conflict-resolution.md) - Handling conflicts
- [presence-tracking.md](presence-tracking.md) - Online status and typing indicators
- [Part 1: StreamBuilder](./ui-integration-part1-streambuilder.md) - StreamBuilder patterns and indicators
- [Part 2: Updates](./ui-integration-part2-updates.md) - Optimistic updates and notifications

---

**Patterns**: Conflict resolution, debouncing, pagination
**Performance**: Optimized for real-time updates
**Status**: ✅ Production-ready
