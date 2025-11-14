# Firebase Performance Monitoring Guide

**Status**: ✅ Production Ready
**Last Updated**: November 13, 2025
**Coverage**: Automatic screen tracking, app startup, business logic (recipes, images, search)

---

## Table of Contents

1. [Overview](#overview)
2. [What Gets Tracked](#what-gets-tracked)
3. [Viewing Performance Data](#viewing-performance-data)
4. [Understanding Traces](#understanding-traces)
5. [Adding Custom Traces](#adding-custom-traces)
6. [Performance Thresholds](#performance-thresholds)
7. [Troubleshooting](#troubleshooting)

---

## Overview

Firebase Performance Monitoring automatically tracks app performance in production without requiring code changes for each screen. The system measures:

- **Screen rendering time** - How long it takes to display each screen
- **App startup time** - Cold/warm/hot start performance
- **Business operations** - Recipe CRUD, image uploads, search operations
- **Network requests** - API call performance (automatic via Firebase)

**Key Benefits**:
- 📊 **Automatic tracking** - No manual instrumentation needed for screens
- 🎯 **Real user data** - Production performance from actual users
- 📈 **Percentile metrics** - See p50, p90, p99 for each operation
- 🔍 **Performance regression detection** - Identify slow screens and operations

---

## What Gets Tracked

### 1. Automatic Screen Tracking

**Implementation**: [PerformanceNavigatorObserver](../../lib/core/observers/performance_navigator_observer.dart:74)

Every screen transition is automatically tracked with:
- **Trace Name**: `screen_{route_name}`
- **Attributes**: `previous_screen`, `replaced_screen`, `has_arguments`
- **Metrics**: Screen rendering duration (automatic)

**Example Traces**:
- `screen_recipe_detail` - Recipe detail view
- `screen_shopping_list` - Shopping list view
- `screen_menu_planning` - Menu planning view
- `screen_settings` - Settings view

**Requirements**:
- Routes must have meaningful names via `RouteSettings(name: 'route_name')`
- ✅ Good: `settings: RouteSettings(name: 'recipe_detail')`
- ❌ Bad: `settings: RouteSettings(name: null)` → tracked as `unknown_screen`

### 2. App Startup Trace

**Implementation**: [main.dart:175-195](../../lib/main.dart:175)

Measures full application initialization time:
- **Trace Name**: `app_startup`
- **Measures**: `ApplicationBootstrap.initialize()` duration
- **Includes**: DI module loading, Firebase init, service registration

**Startup Stages Measured**:
1. Firebase SDK initialization
2. 7 DI modules (Core, Content, Social, Messaging, Collaboration, Performance, UI)
3. 5 bootstrap stages (Platform, Core, Content, Social, UI)
4. ServiceLocator setup

### 3. Recipe Operations

**Implementation**: [firebase_recipe_repository.dart:166-315](../../lib/repositories/firebase/firebase_recipe_repository.dart:166)

#### Create Recipe
- **Trace Name**: `recipe_create`
- **Metrics**: `ingredient_count`
- **Attributes**: `has_image`, `is_collaborative`

#### Update Recipe
- **Trace Name**: `recipe_update`
- **Metrics**: `ingredient_count`
- **Attributes**: `has_image`, `is_collaborative`, `ingredients_normalized`

#### Delete Recipe
- **Trace Name**: `recipe_delete`
- **Attributes**: `is_legacy`, `is_collaborative`, `had_image`

#### Search Recipes
- **Trace Name**: `search` (via FirebasePerformanceService.traceSearch)
- **Metrics**: `result_count`
- **Attributes**: `query_length`, `user_id`, `search_type: recipe_title`

### 4. Image Upload

**Implementation**: [firebase_storage_repository.dart:254](../../lib/repositories/firebase/firebase_storage_repository.dart:254)

- **Trace Name**: `image_upload`
- **Metrics**: `size_bytes`
- **Attributes**: `user_id`, `success`, `error` (on failure)

---

## Viewing Performance Data

### Firebase Console

1. **Navigate to Performance Monitoring**:
   - Open [Firebase Console](https://console.firebase.google.com)
   - Select your project (Butlery)
   - Click "Performance" in left sidebar

2. **View Custom Traces** (Screen & Business Logic):
   - Click "Custom traces" tab
   - Filter by prefix:
     - `screen_*` - All screen traces
     - `recipe_*` - Recipe operations
     - `app_startup` - Startup performance
     - `image_upload` - Image uploads
     - `search` - Search operations

3. **Key Metrics to Monitor**:
   - **p50 (median)** - Typical user experience
   - **p90** - Slower users (9 out of 10 users faster)
   - **p99** - Worst case (99 out of 100 users faster)
   - **Session count** - How many times the operation was performed

4. **Data Availability**:
   - ⏱️ **24-hour delay** - Data appears ~24 hours after collection
   - 📅 **Retention** - 90 days by default
   - 🔄 **Refresh** - Updates hourly in console

### Debug Mode (Local Testing)

Enable debug mode to see traces in logcat/console immediately:

```bash
# Android
adb shell setprop debug.firebase.perf.enable true

# iOS (via Xcode Instruments)
# Use Firebase Performance dashboard during development
```

**Note**: Debug mode data does NOT appear in Firebase Console.

---

## Understanding Traces

### Trace Lifecycle

```dart
// 1. Start trace
final trace = FirebasePerformance.instance.newTrace('my_operation');
await trace.start();

// 2. Perform operation
await doSomethingExpensive();

// 3. Add attributes/metrics (optional)
trace.putAttribute('user_type', 'premium');
trace.setMetric('items_processed', 42);

// 4. Stop trace
await trace.stop();
```

### Attributes vs Metrics

**Attributes** (String key-value pairs):
- Categorical data for filtering/grouping
- Examples: `has_image: true`, `user_id: abc123`
- Max 5 attributes per trace
- Max 40 chars for key, 100 chars for value

**Metrics** (Integer counts):
- Numerical measurements
- Examples: `ingredient_count: 12`, `size_bytes: 524288`
- Used for aggregation and statistics
- Max 32 metrics per trace

### Performance Characteristics

**Fast Operations** (< 100ms):
- `screen_settings` - Simple settings view
- `recipe_delete` - Delete operation (mostly validation)

**Medium Operations** (100ms - 500ms):
- `screen_recipe_detail` - Recipe detail with images
- `recipe_create` - Create with validation
- `recipe_update` - Update with normalization

**Slow Operations** (> 500ms):
- `app_startup` - Full initialization (expected)
- `image_upload` - Network-dependent
- `search` - Large dataset queries

---

## Adding Custom Traces

### For New Screens

Screens are automatically tracked if routes have names. To ensure tracking:

```dart
// ✅ Good - Automatic tracking
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => MyNewView(),
    settings: RouteSettings(name: 'my_new_view'),
  ),
);

// ❌ Bad - No tracking
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => MyNewView()),
);
```

### For Business Operations

Use `FirebasePerformanceService.traceOperation()`:

```dart
import 'package:butlery/services/performance/firebase_performance_service.dart';

Future<void> myExpensiveOperation() async {
  return await FirebasePerformanceService.traceOperation(
    'my_operation',
    (trace) async {
      // Perform operation
      final result = await doWork();

      // Add metrics/attributes
      trace.setMetric('items_count', result.length);
      trace.putAttribute('cache_hit', result.fromCache ? 'true' : 'false');

      return result;
    },
  );
}
```

### For Search Operations

Use `FirebasePerformanceService.traceSearch()`:

```dart
Future<List<Item>> searchItems(String query) async {
  return await FirebasePerformanceService.traceSearch(
    (trace) async {
      final results = await performSearch(query);

      // Automatically adds query-related attributes
      trace.putAttribute('query_length', query.length.toString());
      trace.setMetric('result_count', results.length);

      return results;
    },
    searchType: 'item_search', // Identifies the search type
  );
}
```

### For Image Operations

Use `FirebasePerformanceService.traceImageUpload()`:

```dart
Future<String?> uploadImage(File file) async {
  return await FirebasePerformanceService.traceImageUpload(
    (trace) async {
      final url = await uploadToStorage(file);

      // Automatically adds image-related metrics
      trace.setMetric('size_bytes', file.lengthSync());
      trace.putAttribute('format', 'jpeg');

      return url;
    },
    imageSize: file.lengthSync(),
    imageFormat: 'jpeg',
  );
}
```

---

## Performance Thresholds

### Recommended Targets

**Screen Rendering** (p90):
- ✅ **Excellent**: < 100ms
- ⚠️ **Acceptable**: 100-300ms
- ❌ **Needs optimization**: > 300ms

**App Startup** (p90):
- ✅ **Excellent**: < 2s
- ⚠️ **Acceptable**: 2-4s
- ❌ **Needs optimization**: > 4s

**Recipe CRUD** (p90):
- ✅ **Excellent**: < 500ms
- ⚠️ **Acceptable**: 500-1000ms
- ❌ **Needs optimization**: > 1000ms

**Image Upload** (p90):
- ✅ **Excellent**: < 2s (for compressed images)
- ⚠️ **Acceptable**: 2-5s
- ❌ **Needs optimization**: > 5s (check network/compression)

**Search Operations** (p90):
- ✅ **Excellent**: < 200ms
- ⚠️ **Acceptable**: 200-500ms
- ❌ **Needs optimization**: > 500ms (consider indexing)

### Performance Alerts

Set up alerts in Firebase Console for regressions:

1. Go to Performance → Custom traces
2. Click on a trace (e.g., `screen_recipe_detail`)
3. Click "Create alert"
4. Set threshold (e.g., p90 > 500ms)
5. Configure email notifications

---

## Troubleshooting

### "Traces not appearing in Firebase Console"

**Causes**:
1. ⏱️ **24-hour delay** - Data takes ~24 hours to appear
2. 📱 **Debug mode** - Debug traces don't appear in console
3. 🔧 **Local development** - Only production data is uploaded
4. 🚫 **Firebase disabled** - Check `firebase_performance.dart` initialization

**Solutions**:
- Wait 24 hours after first trace
- Use production/TestFlight builds for testing
- Verify Firebase Performance is enabled in Firebase Console

### "Screen traces showing as unknown_screen"

**Cause**: Routes lack `RouteSettings(name: ...)`.

**Solution**: Add route names to all navigation:

```dart
// Before
Navigator.push(context, MaterialPageRoute(builder: (_) => MyView()));

// After
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => MyView(),
    settings: RouteSettings(name: 'my_view'),
  ),
);
```

### "Slow screen performance (> 500ms)"

**Common Causes**:
1. 🖼️ **Large images** - Not compressed or optimized
2. 🔄 **Heavy build() methods** - Too much computation in build
3. 📊 **Excessive data loading** - Loading all data upfront
4. 🎨 **Complex layouts** - Deeply nested widgets

**Solutions**:
1. Use image compression (already implemented in [firebase_storage_repository.dart](../../lib/repositories/firebase/firebase_storage_repository.dart:419))
2. Extract expensive computations outside build()
3. Use pagination/lazy loading for large lists
4. Simplify widget trees, use const widgets where possible

### "High startup time (> 3s)"

**Common Causes**:
1. 🔌 **Too many DI registrations** - Eager singletons
2. 🌐 **Network calls on startup** - Loading data before UI ready
3. 📦 **Heavy initialization** - Large file reads or computations

**Solutions**:
1. Use `registerLazySingleton` instead of `registerSingleton`
2. Defer non-critical network calls until after UI renders
3. Move heavy initialization to background isolates

### "Firebase Performance not collecting data"

**Verification Steps**:

1. Check if FirebasePerformance is initialized in `main.dart`:
   ```dart
   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
   ```

2. Verify `firebase_performance` dependency in `pubspec.yaml`:
   ```yaml
   firebase_performance: ^0.11.0
   ```

3. Check Firebase Console → Performance → Settings:
   - Performance Monitoring should be **enabled**
   - Data collection should be **on**

4. Review logs for initialization errors:
   ```bash
   # Look for Firebase Performance errors
   flutter logs | grep -i "performance\|firebase"
   ```

---

## Best Practices

### DO ✅

- ✅ Use meaningful route names for automatic screen tracking
- ✅ Add custom traces for expensive operations (> 100ms)
- ✅ Include attributes for filtering (e.g., `user_type`, `has_premium`)
- ✅ Monitor p90 percentiles for realistic user experience
- ✅ Set up alerts for performance regressions
- ✅ Use production builds for realistic measurements

### DON'T ❌

- ❌ Add traces for trivial operations (< 10ms)
- ❌ Exceed 5 attributes or 32 metrics per trace
- ❌ Use PII (personally identifiable information) in attributes
- ❌ Expect instant data (24-hour delay is normal)
- ❌ Test with debug builds (different performance characteristics)
- ❌ Forget to stop traces (memory leaks)

---

## Related Documentation

- [Firebase Performance Service](../../lib/services/performance/firebase_performance_service.dart) - Core service implementation
- [Performance Navigator Observer](../../lib/core/observers/performance_navigator_observer.dart) - Automatic screen tracking
- [Firebase Recipe Repository](../../lib/repositories/firebase/firebase_recipe_repository.dart) - Business logic tracing examples
- [Firebase Console](https://console.firebase.google.com) - View production metrics

---

**Questions or Issues?**

- Check Firebase Console → Performance → Troubleshooting
- Review [Firebase Performance Monitoring docs](https://firebase.google.com/docs/perf-mon)
- Search existing traces for patterns: `screen_*`, `recipe_*`
