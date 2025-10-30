# Firebase Performance Monitoring Integration Guide

## Overview

This guide explains how to use Firebase Performance Monitoring in the Butlery application to track and optimize app performance.

## What is Firebase Performance?

Firebase Performance Monitoring is an automatic and manual performance tracking service that helps:
- Identify performance bottlenecks
- Monitor app startup time
- Track network request performance
- Measure custom code execution time
- Detect slow rendering

## Setup Status

✅ **Firebase Performance is fully integrated** (Phase 4.7 - Jan 2025)

- Package: `firebase_performance: ^0.10.0` added to pubspec.yaml
- Service: `FirebasePerformanceService` created
- Initialization: Automatic via `PerformanceModule`
- Status: Ready to use in production

## Usage Patterns

### 1. Basic Trace Usage

```dart
import 'package:butlery/services/performance/firebase_performance_service.dart';

// Start a trace
final trace = await FirebasePerformanceService.startTrace('load_recipes');

try {
  // Your operation
  final recipes = await _repository.getAllRecipes();

  // Add metadata
  trace.putAttribute('recipe_count', recipes.length.toString());
  trace.putAttribute('source', 'firebase');

  // Stop trace
  await trace.stop();
} catch (e) {
  trace.putAttribute('error', e.toString());
  await trace.stop();
  rethrow;
}
```

### 2. Automatic Trace Wrapper

```dart
// Using traceOperation for automatic trace management
final recipes = await FirebasePerformanceService.traceOperation(
  'load_recipes',
  (trace) async {
    final recipes = await _repository.getAllRecipes();
    trace.putAttribute('count', recipes.length.toString());
    return recipes;
  },
  attributes: {
    'source': 'firebase',
    'userId': userId,
  },
);
```

### 3. Predefined Trace Methods

#### Recipe Loading
```dart
final recipe = await FirebasePerformanceService.traceRecipeLoad(
  (trace) async {
    final recipe = await _repository.getRecipe(recipeId);
    trace.putAttribute('has_images', recipe.imageUrls.isNotEmpty.toString());
    return recipe;
  },
  recipeId: recipeId,
  source: 'firestore',
);
```

#### Search Operations
```dart
final results = await FirebasePerformanceService.traceSearch(
  (trace) async {
    final results = await _searchRecipes(query);
    trace.setMetric('result_count', results.length);
    return results;
  },
  searchType: 'text_search',
  resultCount: results.length,
);
```

#### Firebase Queries
```dart
final recipes = await FirebasePerformanceService.traceFirebaseQuery(
  (trace) async {
    final snapshot = await _collection.where('userId', isEqualTo: userId).get();
    final recipes = snapshot.docs.map((doc) => Recipe.fromFirestore(doc)).toList();
    return recipes;
  },
  collection: 'recipes',
  resultCount: recipes.length,
);
```

#### Screen Loading
```dart
await FirebasePerformanceService.traceScreenLoad(
  'recipe_detail',
  (trace) async {
    await _loadRecipeData();
    await _loadComments();
    trace.putAttribute('comments_loaded', 'true');
  },
);
```

#### Image Uploads
```dart
final imageUrl = await FirebasePerformanceService.traceImageUpload(
  (trace) async {
    final compressed = await compressImage(imageFile);
    trace.setMetric('original_size', imageFile.lengthSync());
    trace.setMetric('compressed_size', compressed.lengthSync());

    final url = await _uploadToStorage(compressed);
    return url;
  },
  imageSize: imageFile.lengthSync(),
  imageFormat: 'jpg',
);
```

#### Social Interactions
```dart
await FirebasePerformanceService.traceSocialInteraction(
  'share_recipe',
  (trace) async {
    await _shareRepository.shareRecipe(recipeId, friendIds);
    trace.setMetric('friend_count', friendIds.length);
  },
  targetType: 'recipe',
);
```

### 4. HTTP Metric Monitoring

```dart
// Automatic HTTP request monitoring
final data = await FirebasePerformanceService.traceHttpRequest(
  'https://api.example.com/recipes',
  HttpMethod.Get,
  (metric) async {
    final response = await http.get(Uri.parse(url));

    // Set response metrics
    metric.httpResponseCode = response.statusCode;
    metric.responsePayloadSize = response.bodyBytes.length;
    metric.responseContentType = response.headers['content-type'];

    return jsonDecode(response.body);
  },
  contentType: 'application/json',
);
```

## Integration Recommendations

### Priority 1: Critical User Flows
These operations should **always** be traced:

1. **App Startup**
   - `trace_app_startup`
   - Track from main() to first screen render

2. **Recipe Loading**
   - `recipe_load` for individual recipes
   - `recipes_list_load` for recipe lists

3. **Search Operations**
   - `search_recipes`
   - `search_friends`

4. **Image Operations**
   - `image_upload`
   - `image_compression`

5. **Social Features**
   - `share_recipe`
   - `send_message`
   - `load_activity_feed`

### Priority 2: Database Operations

Wrap all Firebase queries with traces:

```dart
// Example in repository
Future<List<Recipe>> getUserRecipes(String userId) async {
  return await FirebasePerformanceService.traceFirebaseQuery(
    (trace) async {
      final snapshot = await _collection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final recipes = snapshot.docs
          .map((doc) => Recipe.fromFirestore(doc))
          .toList();

      trace.setMetric('result_count', recipes.length);
      trace.putAttribute('has_filter', 'true');

      return recipes;
    },
    collection: 'recipes',
    resultCount: recipes.length,
  );
}
```

### Priority 3: Complex Computations

```dart
Future<Menu> generateWeekMenu() async {
  final trace = await FirebasePerformanceService.startTrace('generate_week_menu');

  try {
    // Track sub-operations
    trace.incrementMetric('recipes_analyzed', recipes.length);

    final menu = await _menuGenerator.generate(preferences);

    trace.putAttribute('menu_days', menu.days.length.toString());
    trace.setMetric('total_recipes', menu.totalRecipes);

    await trace.stop();
    return menu;
  } catch (e) {
    trace.putAttribute('error', e.toString());
    await trace.stop();
    rethrow;
  }
}
```

## Best Practices

### 1. Trace Naming
- Use lowercase with underscores: `load_recipe`, not `LoadRecipe`
- Be specific: `load_recipe_detail` instead of `load_data`
- Max length: 100 characters
- Only letters, numbers, and underscores

### 2. Attributes
- Max 5 attributes per trace
- Attribute names: Max 40 characters
- Attribute values: Max 100 characters
- Use for categorization: `recipe_type`, `user_tier`, `source`

### 3. Metrics
- Use for counts and sizes: `recipe_count`, `file_size_bytes`
- Always use integers
- Track both success and error metrics

### 4. Error Handling
Always stop traces, even on error:

```dart
final trace = await FirebasePerformanceService.startTrace('operation');

try {
  // operation
  await trace.stop();
} catch (e) {
  trace.putAttribute('error', e.runtimeType.toString());
  await trace.stop();
  rethrow;
}
```

## Performance Impact

Firebase Performance Monitoring is designed for production:
- **Overhead**: < 1ms per trace
- **Network**: Batched uploads, minimal data usage
- **Battery**: Negligible impact
- **Size**: ~200KB to app size

## Viewing Results

### Firebase Console
1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to: **Performance** section
4. View:
   - App startup time
   - Network requests
   - Custom traces
   - Screen rendering

### Metrics Available
- **Duration**: P50, P90, P99 percentiles
- **Success rate**: % of successful operations
- **Affected users**: How many users experienced the trace
- **Trends**: Performance over time

## Automatic Monitoring

Firebase Performance automatically tracks:
- ✅ App startup time
- ✅ HTTP/HTTPS requests (via `firebase_performance`)
- ✅ Screen rendering (via FrameTiming)

## Disabling in Development

```dart
// Disable for specific scenarios
await FirebasePerformanceService.setPerformanceCollectionEnabled(false);

// Re-enable
await FirebasePerformanceService.setPerformanceCollectionEnabled(true);
```

## Integration with Existing PerformanceMonitoringService

Both services work together:
- **PerformanceMonitoringService**: Real-time local metrics, immediate feedback
- **FirebasePerformanceService**: Production monitoring, historical data, Firebase Console

Example combining both:

```dart
// Start both traces
final firebaseTrace = await FirebasePerformanceService.startTrace('load_recipes');
performanceMonitoring.startTimer('load_recipes');

try {
  final recipes = await _repository.getAllRecipes();

  // Stop both
  performanceMonitoring.stopTimer('load_recipes', type: MetricType.custom);
  await firebaseTrace.stop();

  return recipes;
} catch (e) {
  performanceMonitoring.stopTimer('load_recipes',
    type: MetricType.custom,
    metadata: {'error': e.toString()}
  );
  firebaseTrace.putAttribute('error', e.toString());
  await firebaseTrace.stop();
  rethrow;
}
```

## Troubleshooting

### Traces Not Appearing
- Wait 12-24 hours for first data
- Check Firebase Console → Performance
- Verify `firebase_performance` package installed
- Ensure app is running in release mode for full metrics

### High Trace Volume
- Limit traces to critical paths only
- Use sampling for high-frequency operations
- Max 500 unique trace names per app

### Performance Degradation
- Check trace overhead in profiler
- Reduce attribute count
- Avoid tracing very frequent operations (> 100/sec)

## Next Steps

1. Add traces to critical user flows
2. Monitor Firebase Console for insights
3. Set performance budgets
4. Create alerts for slow operations
5. Iterate on optimizations

## Related Documentation

- `/docs/performance/SETSTATE_REFACTORING_GUIDE.md` - UI performance
- `/docs/firebase/FIRESTORE_INDICES_DEPLOYMENT.md` - Query optimization
- `lib/core/mixins/performance_monitoring_mixin.dart` - Local monitoring

---

**Last Updated**: January 2025 - Phase 4.7 Performance Optimization
**Status**: ✅ Ready for production use
**Package Version**: firebase_performance ^0.10.0
