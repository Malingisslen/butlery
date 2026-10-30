import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/image/avatar_image_widget.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  group('AvatarImageWidget.readonly', () {
    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
    });

    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    testWidgets('shows the initials when there is no picture', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: AvatarImageWidget.readonly(displayName: 'Anna Andersson'),
        ),
      );

      expect(find.text('AA'), findsOneWidget);
    });

    testWidgets('a tap reaches onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: AvatarImageWidget.readonly(
            displayName: 'Anna Andersson',
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text('AA'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
