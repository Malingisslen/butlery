/// Widget tests for AdaptiveActivityIndicator.
///
/// Platform branching: AdaptiveActivityIndicator reads `Platform.isIOS`
/// (dart:io) rather than `defaultTargetPlatform`, so
/// `debugDefaultTargetPlatformOverride` cannot flip the iOS branch in a
/// host-OS test run. We therefore assert the "non-iOS" branch directly
/// (host runs on Windows/Linux/macOS), and exercise all constructors + the
/// prop forwarding path that is platform-agnostic.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/indicators/adaptive_activity_indicator.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// True when the host running these tests will take the iOS branch.
bool get _hostIsIos => !kIsWeb && Platform.isIOS;

void main() {
  group('AdaptiveActivityIndicator — default constructor', () {
    testWidgets('non-iOS host → CircularProgressIndicator in a SizedBox',
        (tester) async {
      if (_hostIsIos) return;
      await tester.pumpWidget(_wrap(const AdaptiveActivityIndicator()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);

      // Default radius is 10 → SizedBox is 20x20.
      final box = tester.widget<SizedBox>(find.descendant(
        of: find.byType(AdaptiveActivityIndicator),
        matching: find.byType(SizedBox),
      ));
      expect(box.width, 20);
      expect(box.height, 20);
    });

    testWidgets('non-iOS host → default strokeWidth is 4', (tester) async {
      if (_hostIsIos) return;
      await tester.pumpWidget(_wrap(const AdaptiveActivityIndicator()));
      final progress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progress.strokeWidth, 4.0);
    });

    testWidgets('iOS host → CupertinoActivityIndicator with default radius=10',
        (tester) async {
      if (!_hostIsIos) return;
      await tester.pumpWidget(_wrap(const AdaptiveActivityIndicator()));
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final cup = tester.widget<CupertinoActivityIndicator>(
        find.byType(CupertinoActivityIndicator),
      );
      expect(cup.radius, 10.0);
    });
  });

  group('AdaptiveActivityIndicator — explicit props (non-iOS)', () {
    testWidgets('explicit radius sets SizedBox dimensions to radius*2',
        (tester) async {
      if (_hostIsIos) return;
      await tester.pumpWidget(_wrap(
        const AdaptiveActivityIndicator(radius: 25),
      ));
      final box = tester.widget<SizedBox>(find.descendant(
        of: find.byType(AdaptiveActivityIndicator),
        matching: find.byType(SizedBox),
      ));
      expect(box.width, 50);
      expect(box.height, 50);
    });

    testWidgets('explicit strokeWidth forwards to CircularProgressIndicator',
        (tester) async {
      if (_hostIsIos) return;
      await tester.pumpWidget(_wrap(
        const AdaptiveActivityIndicator(strokeWidth: 7.5),
      ));
      final progress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progress.strokeWidth, 7.5);
    });

    testWidgets('explicit color forwards to CircularProgressIndicator',
        (tester) async {
      if (_hostIsIos) return;
      await tester.pumpWidget(_wrap(
        const AdaptiveActivityIndicator(color: Colors.purple),
      ));
      final progress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progress.color, Colors.purple);
    });
  });

  group('AdaptiveActivityIndicator — named constructors (non-iOS sizes)', () {
    testWidgets('.small → radius 8, strokeWidth 2 → 16x16 box', (tester) async {
      if (_hostIsIos) return;
      await tester.pumpWidget(_wrap(const AdaptiveActivityIndicator.small()));
      final box = tester.widget<SizedBox>(find.descendant(
        of: find.byType(AdaptiveActivityIndicator),
        matching: find.byType(SizedBox),
      ));
      expect(box.width, 16);
      expect(box.height, 16);
      final progress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progress.strokeWidth, 2.0);
    });

    testWidgets('.medium → radius 12, strokeWidth 3 → 24x24 box',
        (tester) async {
      if (_hostIsIos) return;
      await tester.pumpWidget(_wrap(const AdaptiveActivityIndicator.medium()));
      final box = tester.widget<SizedBox>(find.descendant(
        of: find.byType(AdaptiveActivityIndicator),
        matching: find.byType(SizedBox),
      ));
      expect(box.width, 24);
      expect(box.height, 24);
      final progress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progress.strokeWidth, 3.0);
    });

    testWidgets('.large → radius 16, strokeWidth 4 → 32x32 box',
        (tester) async {
      if (_hostIsIos) return;
      await tester.pumpWidget(_wrap(const AdaptiveActivityIndicator.large()));
      final box = tester.widget<SizedBox>(find.descendant(
        of: find.byType(AdaptiveActivityIndicator),
        matching: find.byType(SizedBox),
      ));
      expect(box.width, 32);
      expect(box.height, 32);
      final progress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progress.strokeWidth, 4.0);
    });

    testWidgets('named constructors forward color', (tester) async {
      if (_hostIsIos) return;
      await tester.pumpWidget(_wrap(
        const AdaptiveActivityIndicator.small(color: Colors.red),
      ));
      final progress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progress.color, Colors.red);
    });
  });

  group('AdaptiveActivityIndicator — iOS-host paths', () {
    // These only run when CI happens to be on macOS+iOS sim; on Windows/Linux
    // they short-circuit. The non-iOS group above provides the primary
    // coverage.
    testWidgets('.small on iOS → CupertinoActivityIndicator(radius=8)',
        (tester) async {
      if (!_hostIsIos) return;
      await tester.pumpWidget(_wrap(const AdaptiveActivityIndicator.small()));
      final cup = tester.widget<CupertinoActivityIndicator>(
        find.byType(CupertinoActivityIndicator),
      );
      expect(cup.radius, 8.0);
    });

    testWidgets('color forwards on iOS', (tester) async {
      if (!_hostIsIos) return;
      await tester.pumpWidget(_wrap(
        const AdaptiveActivityIndicator(color: Colors.green),
      ));
      final cup = tester.widget<CupertinoActivityIndicator>(
        find.byType(CupertinoActivityIndicator),
      );
      expect(cup.color, Colors.green);
    });
  });
}
