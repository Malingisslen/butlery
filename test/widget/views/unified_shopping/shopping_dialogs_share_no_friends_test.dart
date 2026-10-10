// BUT-2261: sharing a list with no friends explains why and offers the friends
// page, the same dialog "Gör samarbetslista" shows.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_dialogs.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockViewModel extends Mock implements UnifiedShoppingViewModel {}

class _MockFriendsService extends Mock implements UnifiedFriendsService {}

void main() {
  late _MockViewModel viewModel;
  late _MockFriendsService friends;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() {
    viewModel = _MockViewModel();
    friends = _MockFriendsService();
    when(() => friends.initialize()).thenAnswer((_) async {});
    when(() => friends.friends).thenReturn([]);
    if (GetIt.instance.isRegistered<UnifiedFriendsService>()) {
      GetIt.instance.unregister<UnifiedFriendsService>();
    }
    GetIt.instance.registerSingleton<UnifiedFriendsService>(friends);
  });

  tearDown(() {
    if (GetIt.instance.isRegistered<UnifiedFriendsService>()) {
      GetIt.instance.unregister<UnifiedFriendsService>();
    }
  });

  String? pushed;

  Future<void> openShare(WidgetTester tester) async {
    pushed = null;
    await tester.pumpWidget(
      createLocalizedTestApp(
        onGenerateRoute: (settings) {
          pushed = settings.name;
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('friends page')),
          );
        },
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                ShoppingDialogs.showShareDialog(context, viewModel),
            child: const Text('share'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('share'));
    await tester.pumpAndSettle();
  }

  testWidgets('with an active list and no friends, the no-friends dialog '
      'opens and leads to the friends page', (tester) async {
    when(() => viewModel.activeList).thenReturn(
      UnifiedShoppingList(
        name: 'Veckan',
        ownerId: 'owner-uid',
        ownerDisplayName: 'Malin',
      ),
    );

    await openShare(tester);

    expect(find.text('Inga vänner'), findsOneWidget);
    expect(find.text('Lägg till vänner'), findsOneWidget);
    // No error snackbar: having no friends is not a failure.
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.text('Lägg till vänner'));
    await tester.pumpAndSettle();
    expect(find.text('friends page'), findsOneWidget);
    expect(pushed, Routes.friends);
  });

  testWidgets('without an active list nothing opens and friends are not '
      'even loaded', (tester) async {
    when(() => viewModel.activeList).thenReturn(null);

    await openShare(tester);

    expect(find.byType(AlertDialog), findsNothing);
    verifyNever(() => friends.initialize());
  });
}
