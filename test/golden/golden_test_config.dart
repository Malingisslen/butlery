import 'package:flutter/material.dart';

/// Theme configurations for golden tests
class TestThemes {
  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );

  static final highContrastTheme = ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.highContrastLight(),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
    ),
  );
}

/// Custom golden test scenario wrapper (renamed to avoid conflict with Alchemist)
class CustomGoldenScenario extends StatelessWidget {
  final String name;
  final Widget child;
  final BoxConstraints? constraints;

  const CustomGoldenScenario({
    super.key,
    required this.name,
    required this.child,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );

    if (constraints != null) {
      return ConstrainedBox(
        constraints: constraints!,
        child: content,
      );
    }

    return content;
  }
}

/// Common test data for golden tests
class GoldenTestData {
  static const shortText = 'Lorem ipsum';
  static const mediumText =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit.';
  static const longText =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
      'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. '
      'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.';

  static const placeholderImageUrl = 'https://via.placeholder.com/300';

  static const testIngredients = [
    'Mjöl - 3 dl',
    'Socker - 2 dl',
    'Ägg - 3 st',
    'Smör - 100 g',
    'Vaniljsocker - 1 tsk',
  ];

  static const testInstructions = [
    'Sätt ugnen på 175 grader.',
    'Blanda mjöl och socker i en skål.',
    'Vispa äggen lätt och tillsätt.',
    'Smält smöret och rör ner i smeten.',
    'Grädda i 25-30 minuter.',
  ];
}

/// Device configurations for responsive testing
class DeviceConfigs {
  static const smallPhone = Size(320, 568); // iPhone SE size
  static const mediumPhone = Size(375, 812); // iPhone X size
  static const largePhone = Size(428, 926); // iPhone 14 Pro Max size
  static const tablet = Size(768, 1024); // iPad size
  static const desktop = Size(1920, 1080);
}
