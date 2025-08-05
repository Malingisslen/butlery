import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import '../golden_test_configuration.dart';

/// Golden tests for platform-specific rendering
/// Ensures UI components render correctly on iOS vs Android vs Web
void main() {
  configureGoldenTests();

  group('Platform-Specific Rendering Golden Tests', () {
    // Test iOS-style (Cupertino) widgets
    group('iOS/Cupertino Rendering', () {
      testGoldens('CupertinoNavigationBar variations', (tester) async {
        await tester.pumpWidgetBuilder(
          CupertinoApp(
            home: Column(
              children: [
                // Standard navigation bar
                const CupertinoNavigationBar(
                  middle: Text('Standard Nav Bar'),
                ),
                const SizedBox(height: 20),
                // With leading and trailing
                CupertinoNavigationBar(
                  leading: CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.back),
                    onPressed: () {},
                  ),
                  middle: const Text('With Actions'),
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.add),
                    onPressed: () {},
                  ),
                ),
                const SizedBox(height: 20),
                // Large title style
                const CupertinoNavigationBar(
                  middle: Text('Large Title Style'),
                  backgroundColor: CupertinoColors.systemGrey6,
                ),
              ],
            ),
          ),
        );

        await screenMatchesGolden(tester, 'ios_navigation_bars');
      });

      testGoldens('CupertinoButtons and controls', (tester) async {
        await tester.pumpWidgetBuilder(
          CupertinoApp(
            home: CupertinoPageScaffold(
              navigationBar: const CupertinoNavigationBar(
                middle: Text('iOS Controls'),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 100),
                    // Buttons
                    CupertinoButton(
                      color: CupertinoColors.activeBlue,
                      onPressed: () {},
                      child: const Text('Filled Button'),
                    ),
                    const SizedBox(height: 16),
                    CupertinoButton(
                      onPressed: () {},
                      child: const Text('Text Button'),
                    ),
                    const SizedBox(height: 16),
                    // Segmented Control
                    CupertinoSegmentedControl<int>(
                      children: const {
                        0: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text('One'),
                        ),
                        1: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text('Two'),
                        ),
                        2: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text('Three'),
                        ),
                      },
                      groupValue: 1,
                      onValueChanged: (_) {},
                    ),
                    const SizedBox(height: 16),
                    // Switch
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Enable Feature'),
                        CupertinoSwitch(
                          value: true,
                          onChanged: (_) {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Slider
                    CupertinoSlider(
                      value: 0.6,
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 16),
                    // Text Field
                    const CupertinoTextField(
                      placeholder: 'iOS Text Field',
                      padding: EdgeInsets.all(12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'ios_controls');
      });

      testGoldens('CupertinoActionSheet', (tester) async {
        await tester.pumpWidgetBuilder(
          CupertinoApp(
            home: Builder(
              builder: (context) => CupertinoPageScaffold(
                child: Center(
                  child: CupertinoButton(
                    onPressed: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (_) => CupertinoActionSheet(
                          title: const Text('Select Option'),
                          message: const Text(
                              'Choose an action from the options below'),
                          actions: [
                            CupertinoActionSheetAction(
                              onPressed: () {},
                              child: const Text('Share Recipe'),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () {},
                              child: const Text('Add to Favorites'),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () {},
                              child: const Text('Edit Recipe'),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () {},
                              isDestructiveAction: true,
                              child: const Text('Delete Recipe'),
                            ),
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            onPressed: () {},
                            child: const Text('Cancel'),
                          ),
                        ),
                      );
                    },
                    child: const Text('Show Action Sheet'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Tap to show action sheet
        await tester.tap(find.text('Show Action Sheet'));
        await tester.pumpAndSettle();

        await screenMatchesGolden(tester, 'ios_action_sheet');
      });

      testGoldens('CupertinoPicker', (tester) async {
        await tester.pumpWidgetBuilder(
          CupertinoApp(
            home: CupertinoPageScaffold(
              navigationBar: const CupertinoNavigationBar(
                middle: Text('iOS Picker'),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  SizedBox(
                    height: 200,
                    child: CupertinoPicker(
                      itemExtent: 32,
                      onSelectedItemChanged: (_) {},
                      children: List.generate(
                        10,
                        (index) => Center(
                          child: Text('Item ${index + 1}'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Scroll to select'),
                ],
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'ios_picker');
      });
    });

    // Test Android-style (Material) widgets
    group('Android/Material Rendering', () {
      testGoldens('Material AppBar variations', (tester) async {
        await tester.pumpWidgetBuilder(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
              useMaterial3: true,
            ),
            home: Scaffold(
              body: Column(
                children: [
                  // Standard app bar
                  AppBar(
                    title: const Text('Standard App Bar'),
                  ),
                  const SizedBox(height: 20),
                  // With actions
                  AppBar(
                    leading: IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () {},
                    ),
                    title: const Text('With Actions'),
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
                  const SizedBox(height: 20),
                  // Colored app bar
                  AppBar(
                    title: const Text('Custom Colors'),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'android_app_bars');
      });

      testGoldens('Material buttons and controls', (tester) async {
        await tester.pumpWidgetBuilder(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
              useMaterial3: true,
            ),
            home: Scaffold(
              appBar: AppBar(title: const Text('Material Controls')),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Buttons
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('Elevated Button'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Filled Button'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Outlined Button'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Text Button'),
                    ),
                    const SizedBox(height: 16),
                    // FAB variations
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        FloatingActionButton.small(
                          onPressed: () {},
                          child: const Icon(Icons.add),
                        ),
                        FloatingActionButton(
                          onPressed: () {},
                          child: const Icon(Icons.add),
                        ),
                        FloatingActionButton.extended(
                          onPressed: () {},
                          label: const Text('Add Recipe'),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Switch
                    SwitchListTile(
                      title: const Text('Enable Feature'),
                      value: true,
                      onChanged: (_) {},
                    ),
                    // Slider
                    Slider(
                      value: 0.6,
                      onChanged: (_) {},
                    ),
                    // Text Field
                    const TextField(
                      decoration: InputDecoration(
                        labelText: 'Material Text Field',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'android_controls');
      });

      testGoldens('Material BottomSheet', (tester) async {
        await tester.pumpWidgetBuilder(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
              useMaterial3: true,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (_) => Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.share),
                                title: const Text('Share Recipe'),
                                onTap: () {},
                              ),
                              ListTile(
                                leading: const Icon(Icons.favorite_border),
                                title: const Text('Add to Favorites'),
                                onTap: () {},
                              ),
                              ListTile(
                                leading: const Icon(Icons.edit),
                                title: const Text('Edit Recipe'),
                                onTap: () {},
                              ),
                              ListTile(
                                leading:
                                    const Icon(Icons.delete, color: Colors.red),
                                title: const Text(
                                  'Delete Recipe',
                                  style: TextStyle(color: Colors.red),
                                ),
                                onTap: () {},
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: const Text('Show Bottom Sheet'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Tap to show bottom sheet
        await tester.tap(find.text('Show Bottom Sheet'));
        await tester.pumpAndSettle();

        await screenMatchesGolden(tester, 'android_bottom_sheet');
      });

      testGoldens('Material Dialog', (tester) async {
        await tester.pumpWidgetBuilder(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
              useMaterial3: true,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Recipe?'),
                          content: const Text(
                            'This action cannot be undone. '
                            'Are you sure you want to delete this recipe?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {},
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Show Dialog'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Tap to show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        await screenMatchesGolden(tester, 'android_dialog');
      });
    });

    // Test platform-adaptive widgets
    group('Platform Adaptive Widgets', () {
      testGoldens('Adaptive navigation - iOS style', (tester) async {
        await tester.pumpWidgetBuilder(
          const _AdaptiveNavigationExample(
            platform: TargetPlatform.iOS,
          ),
        );

        await screenMatchesGolden(tester, 'adaptive_navigation_ios');
      });

      testGoldens('Adaptive navigation - Android style', (tester) async {
        await tester.pumpWidgetBuilder(
          const _AdaptiveNavigationExample(
            platform: TargetPlatform.android,
          ),
        );

        await screenMatchesGolden(tester, 'adaptive_navigation_android');
      });

      testGoldens('Adaptive buttons comparison', (tester) async {
        await tester.pumpWidgetBuilder(
          Row(
            children: [
              Expanded(
                child: Theme(
                  data: ThemeData(platform: TargetPlatform.iOS),
                  child: const _AdaptiveButtonExample(title: 'iOS'),
                ),
              ),
              const VerticalDivider(),
              Expanded(
                child: Theme(
                  data: ThemeData(platform: TargetPlatform.android),
                  child: const _AdaptiveButtonExample(title: 'Android'),
                ),
              ),
            ],
          ),
          wrapper: materialAppWrapper(),
        );

        await screenMatchesGolden(tester, 'adaptive_buttons_comparison');
      });

      testGoldens('Adaptive date picker - iOS', (tester) async {
        await tester.pumpWidgetBuilder(
          CupertinoApp(
            home: CupertinoPageScaffold(
              navigationBar: const CupertinoNavigationBar(
                middle: Text('iOS Date Picker'),
              ),
              child: Center(
                child: SizedBox(
                  height: 200,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: DateTime(2024, 1, 15),
                    onDateTimeChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );

        await screenMatchesGolden(tester, 'adaptive_date_picker_ios');
      });

      testGoldens('Adaptive progress indicators', (tester) async {
        await tester.pumpWidgetBuilder(
          Column(
            children: [
              // iOS style
              Container(
                padding: const EdgeInsets.all(32),
                color: CupertinoColors.systemGrey6,
                child: const Column(
                  children: [
                    Text(
                      'iOS Style',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        CupertinoActivityIndicator(),
                        CupertinoActivityIndicator(radius: 20),
                        CupertinoActivityIndicator(
                          radius: 30,
                          color: CupertinoColors.activeBlue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Android style
              Container(
                padding: const EdgeInsets.all(32),
                child: const Column(
                  children: [
                    Text(
                      'Android Style',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            strokeWidth: 5,
                            valueColor: AlwaysStoppedAnimation(Colors.green),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    LinearProgressIndicator(),
                  ],
                ),
              ),
            ],
          ),
          wrapper: materialAppWrapper(),
        );

        await screenMatchesGolden(tester, 'adaptive_progress_indicators');
      });
    });

    // Test web-specific rendering
    group('Web-Specific Rendering', () {
      testGoldens('Web hover states', (tester) async {
        await tester.pumpWidgetBuilder(
          const _WebHoverExample(),
          wrapper: materialAppWrapper(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
              useMaterial3: true,
            ),
          ),
        );

        await screenMatchesGolden(tester, 'web_hover_states');
      });

      testGoldens('Web selection controls', (tester) async {
        await tester.pumpWidgetBuilder(
          const _WebSelectionExample(),
          wrapper: materialAppWrapper(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
              useMaterial3: true,
            ),
          ),
        );

        await screenMatchesGolden(tester, 'web_selection_controls');
      });
    });

    // Test theme variations
    group('Theme Variations', () {
      testGoldens('Light vs Dark theme comparison', (tester) async {
        final widget = Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Theme Test')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Card Title',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text('Card content with regular text'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Primary Action'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Secondary Action'),
                  ),
                  const SizedBox(height: 16),
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'Input Field',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(value: true, onChanged: (_) {}),
                      const Text('Checkbox'),
                      const SizedBox(width: 16),
                      Radio(value: true, groupValue: true, onChanged: (_) {}),
                      const Text('Radio'),
                      const Spacer(),
                      Switch(value: true, onChanged: (_) {}),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpWidgetBuilder(
          Row(
            children: [
              Expanded(
                child: Theme(
                  data: ThemeData.light(useMaterial3: true),
                  child: widget,
                ),
              ),
              Expanded(
                child: Theme(
                  data: ThemeData.dark(useMaterial3: true),
                  child: widget,
                ),
              ),
            ],
          ),
          wrapper: materialAppWrapper(),
        );

        await screenMatchesGolden(tester, 'theme_light_vs_dark');
      });
    });
  });
}

// Helper widgets for testing

class _AdaptiveNavigationExample extends StatelessWidget {
  final TargetPlatform platform;

  const _AdaptiveNavigationExample({
    required this.platform,
  });

  @override
  Widget build(BuildContext context) {
    if (platform == TargetPlatform.iOS) {
      return CupertinoApp(
        home: CupertinoTabScaffold(
          tabBar: CupertinoTabBar(
            items: const [
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.search),
                label: 'Search',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.heart),
                label: 'Favorites',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.person),
                label: 'Profile',
              ),
            ],
          ),
          tabBuilder: (context, index) {
            return CupertinoTabView(
              builder: (_) => Center(
                child: Text('Tab $index'),
              ),
            );
          },
        ),
      );
    } else {
      return MaterialApp(
        home: Scaffold(
          body: const Center(child: Text('Content')),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_outline),
                selectedIcon: Icon(Icons.favorite),
                label: 'Favorites',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      );
    }
  }
}

class _AdaptiveButtonExample extends StatelessWidget {
  final String title;

  const _AdaptiveButtonExample({required this.title});

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (isIOS) ...[
            CupertinoButton(
              color: CupertinoColors.activeBlue,
              onPressed: () {},
              child: const Text('Primary'),
            ),
            const SizedBox(height: 8),
            CupertinoButton(
              onPressed: () {},
              child: const Text('Secondary'),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () {},
              child: const Text('Primary'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Secondary'),
            ),
          ],
        ],
      ),
    );
  }
}

class _WebHoverExample extends StatefulWidget {
  const _WebHoverExample();

  @override
  State<_WebHoverExample> createState() => _WebHoverExampleState();
}

class _WebHoverExampleState extends State<_WebHoverExample> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Web Hover States')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            MouseRegion(
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      _isHovered ? Colors.blue.shade50 : Colors.grey.shade100,
                  border: Border.all(
                    color: _isHovered ? Colors.blue : Colors.grey.shade300,
                    width: _isHovered ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      color: _isHovered ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Interactive Recipe Card',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _isHovered ? Colors.blue.shade700 : null,
                            ),
                          ),
                          const Text('Hover to see interactive effects'),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: _isHovered ? Colors.blue : Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Wrap(
              spacing: 8,
              children: [
                _HoverChip(label: 'Vegetarian'),
                _HoverChip(label: 'Quick'),
                _HoverChip(label: 'Healthy'),
                _HoverChip(label: 'Budget'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HoverChip extends StatefulWidget {
  final String label;

  const _HoverChip({required this.label});

  @override
  State<_HoverChip> createState() => _HoverChipState();
}

class _HoverChipState extends State<_HoverChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _isHovered ? Colors.green : Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered ? Colors.green.shade700 : Colors.green.shade200,
          ),
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            color: _isHovered ? Colors.white : Colors.green.shade700,
            fontWeight: _isHovered ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _WebSelectionExample extends StatelessWidget {
  const _WebSelectionExample();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Web Selection Controls')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SelectableText(
              'This text can be selected and copied. Try selecting it with your mouse!',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            SelectableText.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Recipe ingredients: '),
                  TextSpan(
                    text: '2 cups flour',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const TextSpan(text: ', '),
                  TextSpan(
                    text: '1 cup sugar',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const TextSpan(text: ', '),
                  TextSpan(
                    text: '3 eggs',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SelectableText(
                'Instructions:\n'
                '1. Preheat oven to 350°F\n'
                '2. Mix dry ingredients\n'
                '3. Beat eggs and add to mixture\n'
                '4. Bake for 25-30 minutes',
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
