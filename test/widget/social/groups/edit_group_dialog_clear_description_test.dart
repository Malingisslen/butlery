// A group whose description is emptied saves it as empty. A null would mean
// "leave it as it was", so the old text came back after every save (A14).

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/social/groups/edit_group_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/field_finder.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

class _MockFriends extends Mock implements UnifiedFriendsService {}

class _MockCategories extends Mock implements FriendsCategoriesOperations {}

void main() {
  late _MockFriends friends;
  late _MockCategories categories;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    friends = _MockFriends();
    categories = _MockCategories();
    when(() => friends.categories).thenReturn(categories);
    when(() => friends.getCategoryById(any())).thenReturn(null);
    when(
      () => categories.updateCategory(
        categoryId: any(named: 'categoryId'),
        name: any(named: 'name'),
        description: any(named: 'description'),
        icon: any(named: 'icon'),
      ),
    ).thenAnswer((_) async => true);
    TestServiceLocator.registerMock<UnifiedFriendsService>(friends);
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  testWidgets('an emptied description is sent as an empty string', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: EditGroupDialog(
          group: FriendCategory(
            id: 'g1',
            ownerId: 'u1',
            name: 'Middagsgänget',
            description: 'Gammal text',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(fieldLabelled('Beskrivning (valfritt)'), '');
    await tester.ensureVisible(find.text('Spara ändringar'));
    await tester.tap(find.text('Spara ändringar'));
    await tester.pumpAndSettle();

    verify(
      () => categories.updateCategory(
        categoryId: 'g1',
        name: 'Middagsgänget',
        description: '',
        icon: any(named: 'icon'),
      ),
    ).called(1);
  });
}
