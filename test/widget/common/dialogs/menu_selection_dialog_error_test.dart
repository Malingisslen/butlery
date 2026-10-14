// A failed menu load tells the user what to do, never the exception's text.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/widgets/common/dialogs/menu_selection_dialog.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockPermissionService extends Mock implements PermissionService {}

void main() {
  late MockUnifiedMenuService menus;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    menus = MockUnifiedMenuService();
    when(() => menus.isInitialized).thenReturn(false);
    when(
      () => menus.initialize(),
    ).thenAnswer((_) async => throw StateError('SECRET-DETAIL'));
    final permission = _MockPermissionService();
    when(() => permission.currentUserId).thenReturn('u1');
    when(() => permission.isAuthenticated).thenReturn(true);
    TestServiceLocator.registerMock<UnifiedMenuService>(menus);
    TestServiceLocator.registerMock<PermissionService>(permission);
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  testWidgets('a failed load says what to do and hides the exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const MenuSelectionDialog(groupName: 'Familjen'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Ett fel uppstod vid laddning. Försök igen eller gå tillbaka.'),
      findsOneWidget,
    );
    expect(find.textContaining('SECRET-DETAIL'), findsNothing);

    await tester.tap(find.text('Försök igen'));
    await tester.pump();
    await tester.pump();
    verify(() => menus.initialize()).called(2);
  });
}
