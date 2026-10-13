import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';

void main() {
  Color? circleColor(WidgetTester tester) {
    final box = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(AvatarCircle),
            matching: find.byType(Container),
          ),
        )
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .first;
    return box.color;
  }

  Future<void> pump(WidgetTester tester, AvatarCircleTone tone) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: AvatarCircle(displayName: 'Anna', tone: tone),
        ),
      ),
    );
  }

  final cs = AppTheme.lightTheme.colorScheme;

  testWidgets('ink tone is the ink circle', (tester) async {
    await pump(tester, AvatarCircleTone.ink);
    expect(circleColor(tester), cs.primary);
  });

  testWidgets('paper tone is the paper circle', (tester) async {
    await pump(tester, AvatarCircleTone.paper);
    expect(circleColor(tester), cs.surface);
  });

  testWidgets('sizes follow the steps', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Column(
            children: [
              AvatarCircle(displayName: 'A', size: AvatarCircleSize.inline),
              AvatarCircle(displayName: 'B'),
              AvatarCircle(displayName: 'C', size: AvatarCircleSize.header),
            ],
          ),
        ),
      ),
    );
    final sizes = tester
        .widgetList<AvatarCircle>(find.byType(AvatarCircle))
        .map((a) => tester.getSize(find.byWidget(a)).width)
        .toList();
    expect(sizes, [26, 32, 56]);
  });
}
