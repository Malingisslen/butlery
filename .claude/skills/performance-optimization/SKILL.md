# Performance Optimization Skill

**Purpose**: Master performance optimization patterns in Butlery Flutter app

**Domain**: Widget optimization, caching, lazy loading, memory management

**Value**: LOW (well-documented best practices)

---

## Quick Reference

### Widget Optimization

```dart
// Use const constructors
const Text('Static text');
const Icon(Icons.home);
const SizedBox(height: 16);

// Extract static widgets
class _StaticHeader extends StatelessWidget {
  const _StaticHeader();

  @override
  Widget build(BuildContext context) {
    return const Text('Header');
  }
}

// Use keys for list items
ListView.builder(
  itemBuilder: (context, index) {
    return RecipeCard(
      key: ValueKey(recipes[index].id),
      recipe: recipes[index],
    );
  },
);
```

### Build Method Optimization

```dart
// Bad: Rebuilds entire widget
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ExpensiveWidget(),
        AnotherExpensiveWidget(),
      ],
    );
  }
}

// Good: Extract to const widgets
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _ExpensiveWidget(),
        _AnotherExpensiveWidget(),
      ],
    );
  }
}

class _ExpensiveWidget extends StatelessWidget {
  const _ExpensiveWidget();

  @override
  Widget build(BuildContext context) => Text('Expensive');
}
```

---

## List Performance

### ListView.builder (Lazy Loading)

```dart
// Good: Only builds visible items
ListView.builder(
  itemCount: recipes.length,
  itemBuilder: (context, index) {
    return RecipeCard(recipe: recipes[index]);
  },
);

// Bad: Builds all items at once
ListView(
  children: recipes.map((r) => RecipeCard(recipe: r)).toList(),
);
```

### Pagination

```dart
class PaginatedRecipeList extends StatefulWidget {
  @override
  _PaginatedRecipeListState createState() => _PaginatedRecipeListState();
}

class _PaginatedRecipeListState extends State<PaginatedRecipeList> {
  final ScrollController _scrollController = ScrollController();
  List<Recipe> _recipes = [];
  bool _isLoading = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _loadMore();
      }
    });
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final newRecipes = await _recipeService.getRecipesPage(
      page: _page,
      pageSize: 20,
    );

    setState(() {
      _recipes.addAll(newRecipes);
      _page++;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _recipes.length + (_isLoading ? 1 : 0),
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

## Image Optimization

### CachedNetworkImage

```dart
// Good: Uses cached_network_image package
CachedNetworkImage(
  imageUrl: recipe.imageUrl,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
  memCacheHeight: 400,  // Resize for memory efficiency
  memCacheWidth: 400,
);

// Bad: NetworkImage without caching
Image.network(recipe.imageUrl);
```

### Image Size Optimization

```dart
// Resize images before caching
class ImageOptimizer {
  static Widget optimizedImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      memCacheHeight: 400,
      memCacheWidth: 400,
      fit: BoxFit.cover,
      maxHeightDiskCache: 800,
      maxWidthDiskCache: 800,
    );
  }
}
```

---

## Caching Strategies

### IntelligentCacheManager

```dart
// Cache frequently accessed data
final cacheManager = ServiceLocator.get<IntelligentCacheManager>();

// Cache recipe with priority
await cacheManager.cacheRecipe(
  recipe,
  priority: CachePriority.high,
);

// Get from cache (fast)
final cached = await cacheManager.getCachedRecipe(recipeId);
if (cached != null) return cached;

// Prefetch user's favorites
await cacheManager.prefetchRecipes(favoriteIds);
```

### Compute for Heavy Operations

```dart
// Run heavy operations in isolate
Future<List<Recipe>> parseRecipes(String jsonString) async {
  return await compute(_parseRecipesIsolate, jsonString);
}

// Isolate function (top-level or static)
List<Recipe> _parseRecipesIsolate(String jsonString) {
  final json = jsonDecode(jsonString) as List;
  return json.map((e) => Recipe.fromJson(e)).toList();
}
```

---

## State Management Optimization

### Selective Rebuild with Consumer

```dart
// Bad: Entire widget rebuilds
Consumer<RecipeViewModel>(
  builder: (context, viewModel, child) {
    return Column(
      children: [
        Text(viewModel.title),
        ExpensiveWidget(),  // Rebuilds unnecessarily
      ],
    );
  },
);

// Good: Only necessary parts rebuild
Column(
  children: [
    Consumer<RecipeViewModel>(
      builder: (context, viewModel, child) {
        return Text(viewModel.title);
      },
    ),
    const ExpensiveWidget(),  // Doesn't rebuild
  ],
);
```

### Selector for Granular Updates

```dart
// Only rebuild when specific field changes
Selector<RecipeViewModel, String>(
  selector: (context, viewModel) => viewModel.title,
  builder: (context, title, child) {
    return Text(title);
  },
);
```

---

## Debouncing & Throttling

### Debounced Search

```dart
class SearchField extends StatefulWidget {
  final ValueChanged<String> onSearch;

  @override
  _SearchFieldState createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  Timer? _debounce;

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: 500), () {
      widget.onSearch(value);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: _onTextChanged,
      decoration: InputDecoration(hintText: 'Sök recept...'),
    );
  }
}
```

### Throttled Updates

```dart
class ThrottledButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Duration throttle;

  const ThrottledButton({
    required this.onPressed,
    this.throttle = const Duration(seconds: 1),
  });

  @override
  _ThrottledButtonState createState() => _ThrottledButtonState();
}

class _ThrottledButtonState extends State<ThrottledButton> {
  bool _isThrottled = false;

  void _handlePress() {
    if (_isThrottled) return;

    widget.onPressed();

    setState(() => _isThrottled = true);
    Future.delayed(widget.throttle, () {
      setState(() => _isThrottled = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isThrottled ? null : _handlePress,
      child: Text('Submit'),
    );
  }
}
```

---

## Memory Management

### Dispose Resources

```dart
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late TextEditingController _controller;
  late StreamSubscription _subscription;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _subscription = _stream.listen(_handleData);
    _timer = Timer.periodic(Duration(seconds: 1), _tick);
  }

  @override
  void dispose() {
    // Dispose all resources
    _controller.dispose();
    _subscription.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}
```

### AutomaticKeepAliveClientMixin

```dart
// Keep tab content alive (avoid rebuilding)
class RecipesTab extends StatefulWidget {
  @override
  _RecipesTabState createState() => _RecipesTabState();
}

class _RecipesTabState extends State<RecipesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);  // Must call super
    return RecipeList();
  }
}
```

---

## Performance Monitoring

### Performance Monitoring Service

```dart
class PerformanceMonitoringService {
  Future<void> measureOperation(
    String name,
    Future<void> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      await operation();
    } finally {
      stopwatch.stop();

      if (stopwatch.elapsedMilliseconds > 1000) {
        print('⚠️ Slow operation: $name took ${stopwatch.elapsedMilliseconds}ms');
      }
    }
  }

  void trackScreenLoad(String screenName) {
    FirebasePerformance.instance
        .newTrace('screen_$screenName')
        .start();
  }
}
```

### Timeline Monitoring

```dart
import 'dart:developer' as developer;

Future<void> expensiveOperation() async {
  developer.Timeline.startSync('expensiveOperation');

  try {
    // Do work
    await _processData();
  } finally {
    developer.Timeline.finishSync();
  }
}
```

---

## Build Optimization

### RepaintBoundary

```dart
// Isolate repaints to specific widgets
RepaintBoundary(
  child: AnimatedWidget(),
);

// Use for custom painters
RepaintBoundary(
  child: CustomPaint(
    painter: ExpensivePainter(),
  ),
);
```

### Avoid Rebuilding Entire Trees

```dart
// Bad: Entire Column rebuilds
class MyWidget extends StatelessWidget {
  final ValueNotifier<int> counter = ValueNotifier(0);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: counter,
          builder: (context, value, child) {
            return Column(  // Rebuilds unnecessarily
              children: [
                Text('$value'),
                ExpensiveWidget(),
              ],
            );
          },
        ),
      ],
    );
  }
}

// Good: Only Text rebuilds
class MyWidget extends StatelessWidget {
  final ValueNotifier<int> counter = ValueNotifier(0);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: counter,
          builder: (context, value, child) {
            return Text('$value');
          },
        ),
        const ExpensiveWidget(),
      ],
    );
  }
}
```

---

## Best Practices

1. **Use const constructors** - Prevents unnecessary rebuilds
2. **Extract static widgets** - Isolate rebuild boundaries
3. **ListView.builder for lists** - Lazy loading
4. **Cache images** - CachedNetworkImage package
5. **Debounce user input** - Reduce API calls
6. **Dispose resources** - Prevent memory leaks
7. **Use compute for CPU-intensive tasks** - Isolates
8. **Monitor performance** - Timeline, Firebase Performance

---

## Performance Checklist

- [ ] Use const constructors where possible
- [ ] Extract widgets that don't change
- [ ] ListView.builder for long lists
- [ ] Pagination for infinite lists
- [ ] CachedNetworkImage for network images
- [ ] Resize images (memCacheHeight, memCacheWidth)
- [ ] Debounce search inputs (500ms)
- [ ] Dispose controllers, subscriptions, timers
- [ ] Use RepaintBoundary for animations
- [ ] Monitor slow operations (>1s)

---

## Related Skills

- **caching-strategies** (offline-first-patterns) - IntelligentCacheManager
- **realtime-collaboration** - Stream optimization
- **dependency-injection-patterns** - Service lifecycle management

---

**Status**: ✅ Standard Flutter best practices
**Complexity**: LOW (well-documented framework features)
**Coverage**: Widgets, lists, images, caching, memory
