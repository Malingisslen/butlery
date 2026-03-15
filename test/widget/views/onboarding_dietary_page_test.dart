import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/views/onboarding/onboarding_dietary_page.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

Widget _testApp({required OnboardingViewModel viewModel}) {
  return ChangeNotifierProvider<OnboardingViewModel>.value(
    value: viewModel,
    child: createLocalizedTestApp(
      child: const OnboardingDietaryPage(),
    ),
  );
}

void main() {
  group('OnboardingDietaryPage', () {
    late OnboardingViewModel viewModel;

    setUp(() {
      viewModel = OnboardingViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    testWidgets('renders 3 dietary cards', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // 3 dietary options: vegetarisk, vegansk, pescetarian
      expect(find.byType(GestureDetector), findsNWidgets(3));
    });

    testWidgets('initially no check_circle icons', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('tapping shows check_circle icon', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Tap the first dietary card (Vegetarisk)
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(viewModel.isDietaryPrefSelected('vegetarisk'), isTrue);
    });

    testWidgets('each card shows label and description', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Cards have both a title (label) and description subtitle
      // Each GestureDetector card contains a Column with label + description
      // Verify we have at least the 3 label texts via the GestureDetectors
      final cards = tester.widgetList<GestureDetector>(
        find.byType(GestureDetector),
      );
      expect(cards.length, 3);

      // Check that descriptions exist (body text below each label)
      // The descriptions are separate Text widgets
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      // Title + description + page title + page description = at least 3*2 + 2 = 8
      expect(textWidgets.length, greaterThanOrEqualTo(8));
    });

    testWidgets('can select multiple simultaneously', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Select first (vegetarisk)
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      // Select second (vegansk)
      await tester.tap(find.byType(GestureDetector).at(1));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
      expect(viewModel.isDietaryPrefSelected('vegetarisk'), isTrue);
      expect(viewModel.isDietaryPrefSelected('vegansk'), isTrue);
    });
  });
}
