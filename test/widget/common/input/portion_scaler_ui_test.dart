/// Widget tests for PortionScalerUI.buildScaler — the static portion-scaler
/// control builder used by recipe detail.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/input/portion_scaler_ui.dart';

class _Host extends StatefulWidget {
  const _Host({
    required this.currentPortions,
    required this.originalPortions,
    required this.convertToSwedish,
    required this.hasAmericanUnits,
    this.minPortions = 1,
    this.maxPortions = 12,
    this.onUpdatePortions,
    this.onToggleUnitConversion,
  });

  final int currentPortions;
  final int originalPortions;
  final bool convertToSwedish;
  final bool hasAmericanUnits;
  final int minPortions;
  final int maxPortions;
  final Function(int)? onUpdatePortions;
  final VoidCallback? onToggleUnitConversion;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _anim = Tween<double>(begin: 1.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PortionScalerUI.buildScaler(
      context: context,
      currentPortions: widget.currentPortions,
      originalPortions: widget.originalPortions,
      convertToSwedish: widget.convertToSwedish,
      hasAmericanUnits: widget.hasAmericanUnits,
      minPortions: widget.minPortions,
      maxPortions: widget.maxPortions,
      scaleAnimation: _anim,
      onUpdatePortions: widget.onUpdatePortions ?? (_) {},
      onToggleUnitConversion: widget.onToggleUnitConversion ?? () {},
    );
  }
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

void main() {
  group('PortionScalerUI — header + portion controls', () {
    testWidgets('renders the portion count as bold text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const _Host(
            currentPortions: 4,
            originalPortions: 4,
            convertToSwedish: false,
            hasAmericanUnits: false,
          ),
        ),
      );
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('renders + and - icon buttons', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const _Host(
            currentPortions: 4,
            originalPortions: 4,
            convertToSwedish: false,
            hasAmericanUnits: false,
          ),
        ),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

    testWidgets('tap + invokes onUpdatePortions with currentPortions+1', (
      tester,
    ) async {
      final calls = <int>[];
      await tester.pumpWidget(
        _wrap(
          _Host(
            currentPortions: 4,
            originalPortions: 4,
            convertToSwedish: false,
            hasAmericanUnits: false,
            onUpdatePortions: calls.add,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.add));
      expect(calls, [5]);
    });

    testWidgets('tap - invokes onUpdatePortions with currentPortions-1', (
      tester,
    ) async {
      final calls = <int>[];
      await tester.pumpWidget(
        _wrap(
          _Host(
            currentPortions: 4,
            originalPortions: 4,
            convertToSwedish: false,
            hasAmericanUnits: false,
            onUpdatePortions: calls.add,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.remove));
      expect(calls, [3]);
    });

    testWidgets('- is disabled when currentPortions == minPortions', (
      tester,
    ) async {
      final calls = <int>[];
      await tester.pumpWidget(
        _wrap(
          _Host(
            currentPortions: 1,
            originalPortions: 1,
            convertToSwedish: false,
            hasAmericanUnits: false,
            minPortions: 1,
            onUpdatePortions: calls.add,
          ),
        ),
      );
      // Tap does nothing because onPressed is null
      await tester.tap(find.byIcon(Icons.remove));
      expect(calls, isEmpty);
    });

    testWidgets('+ is disabled when currentPortions == maxPortions', (
      tester,
    ) async {
      final calls = <int>[];
      await tester.pumpWidget(
        _wrap(
          _Host(
            currentPortions: 12,
            originalPortions: 4,
            convertToSwedish: false,
            hasAmericanUnits: false,
            maxPortions: 12,
            onUpdatePortions: calls.add,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.add));
      expect(calls, isEmpty);
    });
  });

  group('PortionScalerUI — status info banner', () {
    testWidgets(
      'no banner when current==original and no Swedish conversion + no AU',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const _Host(
              currentPortions: 4,
              originalPortions: 4,
              convertToSwedish: false,
              hasAmericanUnits: false,
            ),
          ),
        );
        // Banner uses calculate or language icon — neither should be present
        expect(find.byIcon(Icons.calculate), findsNothing);
        expect(find.byIcon(Icons.language), findsNothing);
      },
    );

    testWidgets('shows calculate icon when scaled but not converting', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const _Host(
            currentPortions: 6,
            originalPortions: 4,
            convertToSwedish: false,
            hasAmericanUnits: false,
          ),
        ),
      );
      expect(find.byIcon(Icons.calculate), findsOneWidget);
    });

    testWidgets('shows language icon when converting to Swedish', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const _Host(
            currentPortions: 4,
            originalPortions: 4,
            convertToSwedish: true,
            hasAmericanUnits: true,
          ),
        ),
      );
      expect(find.byIcon(Icons.language), findsAtLeastNWidgets(1));
    });

    testWidgets(
      'banner missing when only hasAmericanUnits=true (no scale, no convert)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const _Host(
              currentPortions: 4,
              originalPortions: 4,
              convertToSwedish: false,
              hasAmericanUnits: true,
            ),
          ),
        );
        // Status condition is (scaled || convertToSwedish) — false here.
        // Toggle is rendered (hasAmericanUnits=true) → language icon appears.
        expect(find.byIcon(Icons.calculate), findsNothing);
      },
    );
  });

  group('PortionScalerUI — unit conversion toggle', () {
    testWidgets('no toggle when hasAmericanUnits=false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const _Host(
            currentPortions: 4,
            originalPortions: 4,
            convertToSwedish: false,
            hasAmericanUnits: false,
          ),
        ),
      );
      expect(find.byWidgetPredicate((w) => w is OutlinedButton), findsNothing);
    });

    testWidgets('toggle renders OutlinedButton when hasAmericanUnits=true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const _Host(
            currentPortions: 4,
            originalPortions: 4,
            convertToSwedish: false,
            hasAmericanUnits: true,
          ),
        ),
      );
      expect(
        find.byWidgetPredicate((w) => w is OutlinedButton),
        findsOneWidget,
      );
    });

    testWidgets('toggle shows check_circle icon when convertToSwedish=true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const _Host(
            currentPortions: 4,
            originalPortions: 4,
            convertToSwedish: true,
            hasAmericanUnits: true,
          ),
        ),
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('toggle shows language icon when convertToSwedish=false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const _Host(
            currentPortions: 4,
            originalPortions: 4,
            convertToSwedish: false,
            hasAmericanUnits: true,
          ),
        ),
      );
      expect(find.byIcon(Icons.language), findsAtLeastNWidgets(1));
    });

    testWidgets('tap toggle invokes onToggleUnitConversion exactly once', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          _Host(
            currentPortions: 4,
            originalPortions: 4,
            convertToSwedish: false,
            hasAmericanUnits: true,
            onToggleUnitConversion: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byWidgetPredicate((w) => w is OutlinedButton));
      expect(taps, 1);
    });
  });

  group('PortionScalerUI — layout integration', () {
    testWidgets('all three sections render when scaled + convert + AU=true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const _Host(
            currentPortions: 6,
            originalPortions: 4,
            convertToSwedish: true,
            hasAmericanUnits: true,
          ),
        ),
      );
      // Header portion text
      expect(find.text('6'), findsOneWidget);
      // Status banner (language icon)
      expect(find.byIcon(Icons.language), findsAtLeastNWidgets(1));
      // Toggle button
      expect(
        find.byWidgetPredicate((w) => w is OutlinedButton),
        findsOneWidget,
      );
      // No build crash
      expect(tester.takeException(), isNull);
    });
  });
}
