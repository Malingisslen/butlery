// Megagenomgång A44: the error route scaled in even when the user had asked
// for less motion; every other route type already honours it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/router/app_router.dart';

void main() {
  Widget transition({required bool reducedMotion}) {
    final route = AppRouter.errorRoute() as PageRouteBuilder<dynamic>;
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Builder(
        builder: (context) => route.transitionsBuilder(
          context,
          const AlwaysStoppedAnimation<double>(0.5),
          const AlwaysStoppedAnimation<double>(0),
          const SizedBox(key: ValueKey('page')),
        ),
      ),
    );
  }

  testWidgets('scales in by default', (tester) async {
    await tester.pumpWidget(transition(reducedMotion: false));
    expect(find.byType(ScaleTransition), findsOneWidget);
  });

  testWidgets('shows the page at once when reduced motion is on', (
    tester,
  ) async {
    await tester.pumpWidget(transition(reducedMotion: true));
    expect(find.byType(ScaleTransition), findsNothing);
    expect(find.byKey(const ValueKey('page')), findsOneWidget);
  });
}
