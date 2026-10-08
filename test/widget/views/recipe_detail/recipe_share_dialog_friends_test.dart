/// A share dialog opened before the friends list has loaded must wait for it,
/// or it says "Inga vänner att dela med" to someone who has friends.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_social_handler.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/user_profile_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/widget_mocks.dart';

class _MockShareViewModel extends Mock
    implements UniversalShareDialogViewModel {}

void main() {
  late MockUnifiedFriendsService friends;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();

    final shareVm = _MockShareViewModel();
    when(() => shareVm.isSharing).thenReturn(false);
    when(() => shareVm.hasError).thenReturn(false);
    TestServiceLocator.registerMock<UniversalShareDialogViewModel>(shareVm);

    friends = MockUnifiedFriendsService();
    TestServiceLocator.registerMock<UnifiedFriendsService>(friends);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  Future<void> pumpHost(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv', 'SE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ChangeNotifierProvider<RecipeDetailViewModel>.value(
          value: MockRecipeDetailViewModel(),
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    RecipeSocialHandler.showSocialShareDialog(context),
                child: const Text('dela'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a friends list still loading is waited for', (tester) async {
    friends.setFriendsState(isInitialized: false);
    final load = Completer<void>();
    when(friends.initialize).thenAnswer((_) => load.future);

    await pumpHost(tester);
    await tester.tap(find.text('dela'));
    await tester.pump();
    friends.setFriendsState(
      friends: [UserProfileFactory.build(uid: 'f1', displayName: 'Erik')],
      isInitialized: true,
    );
    load.complete();
    await tester.pumpAndSettle();

    verify(friends.initialize).called(1);
    expect(find.textContaining('Erik'), findsWidgets);
    expect(find.text('Inga vänner att dela med'), findsNothing);
  });

  testWidgets('a loaded friends list is not loaded again', (tester) async {
    friends.setFriendsState(
      friends: [UserProfileFactory.build(uid: 'f1', displayName: 'Erik')],
      isInitialized: true,
    );

    await pumpHost(tester);
    await tester.tap(find.text('dela'));
    await tester.pumpAndSettle();

    verifyNever(friends.initialize);
    expect(find.textContaining('Erik'), findsWidgets);
    // BUT-2250: recipe share opens the bottom sheet, not a dialog.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });
}
