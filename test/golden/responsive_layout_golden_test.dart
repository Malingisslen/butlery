import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';
import '../helpers/mock_factories.dart';

/// Golden tests for responsive layouts across different screen sizes
/// Ensures UI adapts correctly to various device dimensions
void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  group('Responsive Layout Golden Tests', () {
    // Define common device sizes
    final devices = [
      const Device(
        name: 'phone_portrait',
        size: Size(375, 812), // iPhone X
        textScale: 1.0,
      ),
      const Device(
        name: 'phone_landscape',
        size: Size(812, 375), // iPhone X landscape
        textScale: 1.0,
      ),
      const Device(
        name: 'tablet_portrait',
        size: Size(768, 1024), // iPad
        textScale: 1.0,
      ),
      const Device(
        name: 'tablet_landscape',
        size: Size(1024, 768), // iPad landscape
        textScale: 1.0,
      ),
      const Device(
        name: 'desktop',
        size: Size(1920, 1080), // Full HD desktop
        textScale: 1.0,
      ),
      const Device(
        name: 'phone_small',
        size: Size(320, 568), // iPhone SE
        textScale: 0.85,
      ),
      const Device(
        name: 'foldable_unfolded',
        size: Size(840, 1260), // Galaxy Fold unfolded
        textScale: 1.0,
      ),
    ];

    testGoldens('Recipe Grid Layout - adapts to screen sizes', (tester) async {
      // Given - Recipe data
      final recipes = RecipeFactory.buildList(12);

      await tester.pumpWidgetBuilder(
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => RecipeCard(
                    recipe: recipes[index],
                    onTap: (_) {},
                  ),
                  childCount: recipes.length,
                ),
              ),
            ),
          ],
        ),
        wrapper: materialAppWrapper(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          ),
        ),
      );

      await multiScreenGolden(
        tester,
        'recipe_grid_responsive',
        devices: devices,
      );
    });

    testGoldens('Recipe Form Layout - responsive form fields', (tester) async {
      await tester.pumpWidgetBuilder(
        const _ResponsiveFormExample(),
        wrapper: materialAppWrapper(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          ),
        ),
      );

      await multiScreenGolden(
        tester,
        'recipe_form_responsive',
        devices: devices,
      );
    });

    testGoldens('Navigation Layout - adaptive navigation patterns',
        (tester) async {
      await tester.pumpWidgetBuilder(
        const _AdaptiveNavigationExample(),
        wrapper: materialAppWrapper(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          ),
        ),
      );

      await multiScreenGolden(
        tester,
        'navigation_responsive',
        devices: devices,
      );
    });

    testGoldens('Discovery Dashboard - responsive card layout', (tester) async {
      await tester.pumpWidgetBuilder(
        const _DiscoveryDashboardExample(),
        wrapper: materialAppWrapper(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          ),
        ),
      );

      await multiScreenGolden(
        tester,
        'discovery_dashboard_responsive',
        devices: devices,
      );
    });

    testGoldens('Shopping List - responsive list layout', (tester) async {
      await tester.pumpWidgetBuilder(
        const _ShoppingListExample(),
        wrapper: materialAppWrapper(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          ),
        ),
      );

      await multiScreenGolden(
        tester,
        'shopping_list_responsive',
        devices: devices,
      );
    });

    testGoldens('Text Scaling - handles different text scales', (tester) async {
      final textScaleDevices = [
        const Device(
          name: 'normal_text',
          size: Size(375, 812),
          textScale: 1.0,
        ),
        const Device(
          name: 'large_text',
          size: Size(375, 812),
          textScale: 1.3,
        ),
        const Device(
          name: 'huge_text',
          size: Size(375, 812),
          textScale: 2.0,
        ),
        const Device(
          name: 'small_text',
          size: Size(375, 812),
          textScale: 0.85,
        ),
      ];

      await tester.pumpWidgetBuilder(
        const _TextScalingExample(),
        wrapper: materialAppWrapper(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          ),
        ),
      );

      await multiScreenGolden(
        tester,
        'text_scaling_responsive',
        devices: textScaleDevices,
      );
    });

    testGoldens('Responsive Dialog - adapts to screen constraints',
        (tester) async {
      await tester.pumpWidgetBuilder(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const _ResponsiveDialog(),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
        wrapper: materialAppWrapper(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          ),
        ),
      );

      // Tap button to show dialog
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      await multiScreenGolden(
        tester,
        'responsive_dialog',
        devices: devices,
      );
    });

    testGoldens('Responsive Bottom Sheet - adapts height and layout',
        (tester) async {
      await tester.pumpWidgetBuilder(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const _ResponsiveBottomSheet(),
                  );
                },
                child: const Text('Show Bottom Sheet'),
              ),
            ),
          ),
        ),
        wrapper: materialAppWrapper(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          ),
        ),
      );

      // Tap button to show bottom sheet
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      await multiScreenGolden(
        tester,
        'responsive_bottom_sheet',
        devices: devices,
      );
    });

    testGoldens('Orientation Changes - portrait to landscape transition',
        (tester) async {
      // Test how layouts adapt when orientation changes
      final orientationDevices = [
        const Device(
          name: 'portrait_before',
          size: Size(375, 812),
          textScale: 1.0,
        ),
        const Device(
          name: 'landscape_after',
          size: Size(812, 375),
          textScale: 1.0,
        ),
      ];

      await tester.pumpWidgetBuilder(
        const _OrientationAwareWidget(),
        wrapper: materialAppWrapper(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          ),
        ),
      );

      await multiScreenGolden(
        tester,
        'orientation_transition',
        devices: orientationDevices,
      );
    });
  });
}

// Example widgets for testing

class _ResponsiveFormExample extends StatelessWidget {
  const _ResponsiveFormExample();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Recipe')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? constraints.maxWidth * 0.2 : 16,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Recipe Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (isWide)
                  const Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Prep Time',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Cook Time',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  )
                else ...[
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'Prep Time',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'Cook Time',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const TextField(
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdaptiveNavigationExample extends StatefulWidget {
  const _AdaptiveNavigationExample();

  @override
  State<_AdaptiveNavigationExample> createState() =>
      _AdaptiveNavigationExampleState();
}

class _AdaptiveNavigationExampleState
    extends State<_AdaptiveNavigationExample> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;

        if (isWide) {
          // Desktop layout with navigation rail
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  extended: constraints.maxWidth > 900,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.restaurant_menu),
                      label: Text('Recipes'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.shopping_cart),
                      label: Text('Shopping'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person),
                      label: Text('Profile'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Center(
                    child: Text('Page $_selectedIndex'),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Mobile layout with bottom navigation
          return Scaffold(
            body: Center(
              child: Text('Page $_selectedIndex'),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.restaurant_menu),
                  label: 'Recipes',
                ),
                NavigationDestination(
                  icon: Icon(Icons.shopping_cart),
                  label: 'Shopping',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          );
        }
      },
    );
  }
}

class _DiscoveryDashboardExample extends StatelessWidget {
  const _DiscoveryDashboardExample();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discovery')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 1200
              ? 4
              : constraints.maxWidth > 800
                  ? 3
                  : constraints.maxWidth > 600
                      ? 2
                      : 1;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: 8,
            itemBuilder: (context, index) {
              final categories = [
                'Trending Now',
                'Quick & Easy',
                'Healthy',
                'Desserts',
                'Vegetarian',
                'Family Meals',
                'Budget Friendly',
                'International',
              ];

              return Card(
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Colors
                          .primaries[index % Colors.primaries.length].shade100,
                      child: Icon(
                        Icons.restaurant_menu,
                        size: 48,
                        color:
                            Colors.primaries[index % Colors.primaries.length],
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          categories[index],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ShoppingListExample extends StatelessWidget {
  const _ShoppingListExample();

  @override
  Widget build(BuildContext context) {
    final items = List.generate(
      20,
      (index) => ShoppingItem(
        name: 'Item ${index + 1}',
        quantity: index % 3 + 1,
        unit: ['kg', 'l', 'pcs'][index % 3],
        checked: index % 4 == 0,
        category: ['Produce', 'Dairy', 'Bakery', 'Meat'][index % 4],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Shopping List')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600) {
            // Wide layout - group by category
            final grouped = <String, List<ShoppingItem>>{};
            for (final item in items) {
              grouped.putIfAbsent(item.category, () => []).add(item);
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: grouped.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Card(
                      child: Column(
                        children: entry.value.map((item) {
                          return CheckboxListTile(
                            value: item.checked,
                            onChanged: (_) {},
                            title: Text(item.name),
                            subtitle: Text('${item.quantity} ${item.unit}'),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              }).toList(),
            );
          } else {
            // Narrow layout - simple list
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: CheckboxListTile(
                    value: item.checked,
                    onChanged: (_) {},
                    title: Text(item.name),
                    subtitle: Text('${item.quantity} ${item.unit}'),
                    secondary: Chip(
                      label: Text(item.category),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}

class _TextScalingExample extends StatelessWidget {
  const _TextScalingExample();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Text Scaling Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Display Large',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Headline Medium with a longer text that might wrap to multiple lines',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Body Large - Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
              'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Action Button'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Secondary'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Input Field',
                helperText: 'Helper text scales with accessibility settings',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsiveDialog extends StatelessWidget {
  const _ResponsiveDialog();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth > 600 ? 600.0 : constraints.maxWidth * 0.9;

        return Dialog(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: constraints.maxHeight * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: const Text('Recipe Details'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: ColoredBox(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.image, size: 64),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Delicious Recipe Title',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This is a detailed description of the recipe that explains '
                          'what makes it special and why you should try it.',
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _InfoChip(icon: Icons.timer, label: '30 min'),
                            _InfoChip(icon: Icons.people, label: '4 portions'),
                            _InfoChip(
                                icon: Icons.local_fire_department,
                                label: '350 cal'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Start Cooking'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ResponsiveBottomSheet extends StatelessWidget {
  const _ResponsiveBottomSheet();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
            maxWidth: isWide ? 600 : double.infinity,
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Add Ingredients',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: Checkbox(
                        value: index % 3 == 0,
                        onChanged: (_) {},
                      ),
                      title: Text('Ingredient ${index + 1}'),
                      subtitle: Text(
                          '${index + 1} ${['cups', 'tbsp', 'tsp'][index % 3]}'),
                    );
                  },
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const Text('Add Selected'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrientationAwareWidget extends StatelessWidget {
  const _OrientationAwareWidget();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orientation Aware')),
      body: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.portrait) {
            return Column(
              children: [
                Expanded(
                  flex: 2,
                  child: ColoredBox(
                    color: Colors.blue.shade100,
                    child: const Center(
                      child: Icon(Icons.image, size: 100),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Portrait Layout',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Content stacks vertically in portrait mode. '
                          'The image takes up less space to show more content below.',
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {},
                            child: const Text('Action'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Row(
              children: [
                Expanded(
                  child: ColoredBox(
                    color: Colors.blue.shade100,
                    child: const Center(
                      child: Icon(Icons.image, size: 100),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Landscape Layout',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        const Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              'Content appears side-by-side in landscape mode. '
                              'This makes better use of horizontal space and allows '
                              'users to see the image while reading content.',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {},
                            child: const Text('Action'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class ShoppingItem {
  final String name;
  final int quantity;
  final String unit;
  final bool checked;
  final String category;

  const ShoppingItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.checked,
    required this.category,
  });
}
