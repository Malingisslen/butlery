import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/social/groups/shared/group_dialog_components.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('DialogFooter lays out its filled button under the app theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: DialogFooter(
          primaryActionText: 'Spara',
          secondaryActionText: 'Avbryt',
          onPrimaryAction: () {},
          onSecondaryAction: () {},
          isLoading: false,
          primaryActionIcon: ButleryIcons.check,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
