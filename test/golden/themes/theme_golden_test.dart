import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../golden_test_configuration.dart';

/// Golden tests for app theme variations
void main() {
  configureGoldenTests();
  group('Theme Golden Tests', () {
    testWidgets('Light theme components', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const _ThemeShowcase(),
        ),
      );

      await expectLater(
        find.byType(_ThemeShowcase),
        matchesGoldenFile('goldens/themes/light_theme_components.png'),
      );
    });

    testWidgets('Dark theme components', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const _ThemeShowcase(),
        ),
      );

      await expectLater(
        find.byType(_ThemeShowcase),
        matchesGoldenFile('goldens/themes/dark_theme_components.png'),
      );
    });

    testWidgets('Theme color palette', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              Expanded(
                child: Theme(
                  data: ThemeData.light(),
                  child: const _ColorPalette(title: 'Light Theme'),
                ),
              ),
              Expanded(
                child: Theme(
                  data: ThemeData.dark(),
                  child: const _ColorPalette(title: 'Dark Theme'),
                ),
              ),
            ],
          ),
        ),
      );

      await expectLater(
        find.byType(Row),
        matchesGoldenFile('goldens/themes/theme_color_palette.png'),
      );
    });
  });
}

/// Widget showcasing various themed components
class _ThemeShowcase extends StatelessWidget {
  const _ThemeShowcase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Components'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Buttons
            const Text('Buttons',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Elevated'),
                ),
                FilledButton(
                  onPressed: () {},
                  child: const Text('Filled'),
                ),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Outlined'),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Text'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Cards
            const Text('Cards', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: const Text('A'),
                ),
                title: const Text('Card Title'),
                subtitle: const Text('Card subtitle with description'),
                trailing: const Icon(Icons.arrow_forward),
              ),
            ),
            const SizedBox(height: 24),

            // Form Fields
            const Text('Form Fields',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Text Field',
                hintText: 'Enter text here',
                prefixIcon: Icon(Icons.edit),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Filled Text Field',
                hintText: 'Enter text here',
                filled: true,
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Widget displaying color palette
class _ColorPalette extends StatelessWidget {
  final String title;

  const _ColorPalette({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          _ColorRow('Primary', colorScheme.primary, colorScheme.onPrimary),
          _ColorRow(
              'Secondary', colorScheme.secondary, colorScheme.onSecondary),
          _ColorRow('Error', colorScheme.error, colorScheme.onError),
          _ColorRow('Surface', colorScheme.surface, colorScheme.onSurface),
        ],
      ),
    );
  }
}

/// Widget displaying a color with its name
class _ColorRow extends StatelessWidget {
  final String name;
  final Color color;
  final Color onColor;

  const _ColorRow(this.name, this.color, this.onColor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Text(
                'Aa',
                style: TextStyle(color: onColor, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name),
          ),
        ],
      ),
    );
  }
}
