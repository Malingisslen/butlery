// At 200 % text the initials are scaled down to the circle they sit in
// rather than clipped or overflowing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/user/user_avatar_widgets.dart';
import 'package:butlery/widgets/user/user_display_models.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/word_break_finder.dart';

void main() {
  testWidgets('initials stay inside a small avatar at 200 % text', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: Center(
              child: UserAvatarWidgets.avatar(
                displayName: 'Wilhelm Wallenberg',
                size: ImageSize.small,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(findMidWordBreaks(tester), isEmpty);
  });
}
