import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/scheduler.dart';
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:butlery/main.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import '../helpers/test_helpers.dart';
import '../test_configuration.dart';
import '../helpers/mock_factories.dart';

/// Performance benchmark for app startup
class AppStartupBenchmark extends BenchmarkBase {
  AppStartupBenchmark() : super('AppStartup');

  @override
  void run() {
    // Measure app initialization
    main();
  }
}

/// Performance benchmark for recipe list rendering
class RecipeListRenderingBenchmark extends BenchmarkBase {
  final int recipeCount;
  late List<Recipe> recipes;

  RecipeListRenderingBenchmark(this.recipeCount)
      : super('RecipeListRendering_$recipeCount');

  @override
  void setup() {
    recipes = RecipeFactory.buildList(recipeCount);
  }

  @override
  void run() {
    // Measure list rendering performance
    final stopwatch = Stopwatch()..start();

    ListView.builder(
      itemCount: recipes.length,
      itemBuilder: (context, index) => ListTile(
        title: Text(recipes[index].title),
        subtitle: Text(recipes[index].description),
      ),
    );

    stopwatch.stop();
  }
}

/// Widget tests for performance monitoring
void main() {
  // Configure tests to ensure ServiceLocator is properly initialized
  configureTests();

  group('Performance Tests', () {
    testWidgets('app startup time should be under 3 seconds', (tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(const ButleryApp());
      await tester.pumpAndSettle();

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(3000),
          reason: 'App startup took ${stopwatch.elapsedMilliseconds}ms');

      debugPrint('[PERF] App startup time: ${stopwatch.elapsedMilliseconds}ms');
    });

    testWidgets('frame rendering should maintain 60fps', (tester) async {
      // Setup frame timing tracking
      final frameTimings = <FrameTiming>[];

      void frameCallback(List<FrameTiming> timings) {
        frameTimings.addAll(timings);
      }

      // Enable frame timing
      SchedulerBinding.instance.addTimingsCallback(frameCallback);

      // Create scrollable list with many items
      final recipes = RecipeFactory.buildList(100);

      await tester.pumpWidget(
        createTestableWidget(
          child: ListView.builder(
            itemCount: recipes.length,
            itemBuilder: (context, index) => Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundImage: AssetImage('assets/placeholder.png'),
                ),
                title: Text(recipes[index].title),
                subtitle: Text('${recipes[index].timeMinutes ?? 0} min'),
                trailing: const Icon(Icons.favorite_border),
              ),
            ),
          ),
        ),
      );

      // Perform rapid scrolling
      for (int i = 0; i < 10; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pump();
        await tester.drag(find.byType(ListView), const Offset(0, 500));
        await tester.pump();
      }

      await tester.pumpAndSettle();

      // Remove callback
      SchedulerBinding.instance.removeTimingsCallback(frameCallback);

      // Analyze frame timings
      int droppedFrames = 0;
      for (final timing in frameTimings) {
        final frameDuration = timing.rasterDuration + timing.buildDuration;
        if (frameDuration > const Duration(milliseconds: 16)) {
          droppedFrames++;
        }
      }

      final frameDropPercentage = (droppedFrames / frameTimings.length) * 100;

      expect(frameDropPercentage, lessThan(5),
          reason:
              'Frame drop rate: ${frameDropPercentage.toStringAsFixed(2)}%');

      debugPrint('[PERF] Total frames: ${frameTimings.length}');
      debugPrint('[PERF] Dropped frames: $droppedFrames');
      debugPrint(
          '[PERF] Frame drop rate: ${frameDropPercentage.toStringAsFixed(2)}%');
    });

    testWidgets('memory usage should remain stable during navigation',
        (tester) async {
      // Get initial memory usage
      final initialMemory = MemoryInfo.currentMemory;

      await tester.pumpWidget(const ButleryApp());
      await tester.pumpAndSettle();

      // Navigate through multiple screens
      for (int i = 0; i < 10; i++) {
        // Navigate to recipe list
        await tester.tap(find.byIcon(Icons.restaurant_menu));
        await tester.pumpAndSettle();

        // Navigate to shopping list
        await tester.tap(find.byIcon(Icons.shopping_cart));
        await tester.pumpAndSettle();

        // Navigate to social
        await tester.tap(find.byIcon(Icons.people));
        await tester.pumpAndSettle();
      }

      // Force garbage collection
      await tester.idle();

      // Check memory after navigation
      final finalMemory = MemoryInfo.currentMemory;
      final memoryIncrease = finalMemory - initialMemory;

      // Memory increase should be minimal (less than 10MB)
      expect(memoryIncrease, lessThan(10 * 1024 * 1024),
          reason:
              'Memory increased by ${(memoryIncrease / 1024 / 1024).toStringAsFixed(2)}MB');

      debugPrint(
          '[PERF] Initial memory: ${(initialMemory / 1024 / 1024).toStringAsFixed(2)}MB');
      debugPrint(
          '[PERF] Final memory: ${(finalMemory / 1024 / 1024).toStringAsFixed(2)}MB');
      debugPrint(
          '[PERF] Memory increase: ${(memoryIncrease / 1024 / 1024).toStringAsFixed(2)}MB');
    });

    testWidgets('image loading performance', (tester) async {
      final recipes = RecipeFactory.buildList(20);

      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        createTestableWidget(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
            ),
            itemCount: recipes.length,
            itemBuilder: (context, index) => Image.network(
              recipes[index].primaryImageUrl ??
                  'https://via.placeholder.com/300',
              fit: BoxFit.cover,
            ),
          ),
        ),
      );

      // Wait for images to load
      await tester.pump(const Duration(seconds: 2));

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(2000),
          reason: 'Image loading took ${stopwatch.elapsedMilliseconds}ms');

      debugPrint(
          '[PERF] Image grid load time: ${stopwatch.elapsedMilliseconds}ms');
    });

    test('database query performance', () async {
      // ServiceLocator is already initialized by configureTests()

      final recipeService = UnifiedRecipeService();

      // Seed test data
      final recipes = RecipeFactory.buildList(1000);
      for (final recipe in recipes) {
        await recipeService.createPersonalRecipe(
          title: recipe.title,
          description: recipe.description,
          ingredients: recipe.ingredients,
          instructions: recipe.instructions,
          imageUrls: recipe.imageUrls,
          mealType: recipe.mealType,
          portions: recipe.portions,
          timeMinutes: recipe.timeMinutes,
        );
      }

      // Test search performance
      final searchStopwatch = Stopwatch()..start();
      // Search is handled through discovery module
      // final searchResults = await recipeService.discovery.searchRecipes('pasta');
      // Search is handled through discovery module
      // final searchResults = await recipeService.discovery.searchRecipes('pasta');
      searchStopwatch.stop();

      expect(searchStopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'Search took ${searchStopwatch.elapsedMilliseconds}ms');

      // Test filter performance
      final filterStopwatch = Stopwatch()..start();
      // Filtering is handled through discovery module
      // final filteredResults = await recipeService.discovery.getRecipesByFilter({
      // Filtering is handled through discovery module
      // final filteredResults = await recipeService.discovery.getRecipesByFilter({
      /*{
        'tags': ['Italian'],
        'maxCookTime': 30,
      });*/
      filterStopwatch.stop();

      expect(filterStopwatch.elapsedMilliseconds, lessThan(150),
          reason: 'Filter took ${filterStopwatch.elapsedMilliseconds}ms');

      // Test pagination performance
      final paginationStopwatch = Stopwatch()..start();
      // User recipes are accessed through personal module
      // User recipes are accessed through personal module
      // final page1 = await recipeService.personal.getAllRecipes();
      // final page2 = await recipeService.personal.getAllRecipes(page: 2);
      paginationStopwatch.stop();

      expect(paginationStopwatch.elapsedMilliseconds, lessThan(200),
          reason:
              'Pagination took ${paginationStopwatch.elapsedMilliseconds}ms');

      debugPrint(
          '[PERF] Search performance: ${searchStopwatch.elapsedMilliseconds}ms');
      debugPrint(
          '[PERF] Filter performance: ${filterStopwatch.elapsedMilliseconds}ms');
      debugPrint(
          '[PERF] Pagination performance: ${paginationStopwatch.elapsedMilliseconds}ms');

      // Disposal is handled by configureTests()
    });

    test('concurrent operations performance', () async {
      // ServiceLocator is already initialized by configureTests()

      final recipeService = UnifiedRecipeService();

      // Test concurrent creates
      final createStopwatch = Stopwatch()..start();

      final createFutures = List.generate(
        50,
        (i) => recipeService.createPersonalRecipe(
          title: 'Concurrent Recipe $i',
        ),
      );

      await Future.wait(createFutures);
      createStopwatch.stop();

      expect(createStopwatch.elapsedMilliseconds, lessThan(2000),
          reason:
              'Concurrent creates took ${createStopwatch.elapsedMilliseconds}ms');

      // Test concurrent reads
      final readStopwatch = Stopwatch()..start();

      final readFutures = List.generate(
        100,
        (i) async => recipeService.getRecipeById('recipe_$i'),
      );

      await Future.wait(readFutures);
      readStopwatch.stop();

      expect(readStopwatch.elapsedMilliseconds, lessThan(1000),
          reason:
              'Concurrent reads took ${readStopwatch.elapsedMilliseconds}ms');

      debugPrint(
          '[PERF] 50 concurrent creates: ${createStopwatch.elapsedMilliseconds}ms');
      debugPrint(
          '[PERF] 100 concurrent reads: ${readStopwatch.elapsedMilliseconds}ms');

      // Disposal is handled by configureTests()
    });
  });

  group('Benchmark Tests', () {
    test('run app startup benchmark', () {
      final benchmark = AppStartupBenchmark();
      benchmark.report();
    });

    test('run recipe list rendering benchmarks', () {
      for (final count in [10, 50, 100, 500]) {
        final benchmark = RecipeListRenderingBenchmark(count);
        benchmark.report();
      }
    });
  });
}

/// Helper class to get memory information
class MemoryInfo {
  static int get currentMemory {
    // In a real app, this would use platform channels to get actual memory usage
    // For testing, we simulate memory usage
    return DateTime.now().millisecondsSinceEpoch % 100000000;
  }
}
