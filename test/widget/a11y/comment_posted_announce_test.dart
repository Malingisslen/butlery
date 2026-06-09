// test/widget/a11y/comment_posted_announce_test.dart
//
// BUT-1212: announce-channel coverage for the comment-posted site
// (`RecipeSocialHandler.postComment` → `a11yCommentPosted`, BUT-905).
//
// The handler is a static that resolves AuthService/UserService from the
// ServiceLocator and the SocialRecipeViewModel from Provider — so the "seam"
// is a minimal host widget over registered mocks, not a view refactor. The
// REAL handler runs end to end (guards, profile fetch, post, snackbar) and the
// announce is asserted on the REAL flutter/accessibility channel.

library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_social_handler.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/user_profile_factory.dart';
import '../../infrastructure/helpers/announce_channel.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/widget_mocks.dart';

void main() {
  late MockAuthService authService;
  late MockUserService userService;
  late MockSocialRecipeViewModel socialVm;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();

    // MockAuthService implements currentUserId as a REAL state-backed getter
    // (currentUser?.uid) — drive it via setAuthState, not mocktail when().
    authService = MockAuthService();
    authService.setAuthState(
      currentUser: FakeUser(uid: 'test-user-123'),
      isAuthenticated: true,
    );
    TestServiceLocator.registerMock<AuthService>(authService);

    userService = MockUserService();
    when(() => userService.getUserProfile('test-user-123')).thenAnswer(
        (_) async => UserProfileFactory.build(uid: 'test-user-123'));
    TestServiceLocator.registerMock<UserService>(userService);

    socialVm = MockSocialRecipeViewModel();
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  /// Pumps a minimal host whose button invokes the REAL static handler with
  /// the Provider + Scaffold context it needs.
  Future<void> pumpHost(WidgetTester tester, {required String commentText}) {
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
        home: ChangeNotifierProvider<SocialRecipeViewModel>.value(
          value: socialVm,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => RecipeSocialHandler.postComment(
                  context,
                  commentText: commentText,
                  recipeId: 'recipe-1',
                ),
                child: const Text('post'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.text('post')));

  testWidgets('a successfully posted comment announces a11yCommentPosted',
      (tester) async {
    when(() => socialVm.postComment('recipe-1')).thenAnswer((_) async {});

    final announces = AnnounceChannel.arm(tester);
    await pumpHost(tester, commentText: 'Riktigt gott!');
    await tester.tap(find.text('post'));
    await tester.pumpAndSettle();

    expect(announces.messages, [l10nOf(tester).a11yCommentPosted]);
  });

  testWidgets('a failed post announces nothing (error snackbar only)',
      (tester) async {
    when(() => socialVm.postComment('recipe-1'))
        .thenThrow(Exception('network down'));

    final announces = AnnounceChannel.arm(tester);
    await pumpHost(tester, commentText: 'Riktigt gott!');
    await tester.tap(find.text('post'));
    await tester.pumpAndSettle();

    expect(announces.count, 0,
        reason: 'the failure path must not claim the comment was posted');
    expect(find.text(l10nOf(tester).socialCouldNotPostComment), findsOneWidget);
  });

  testWidgets('an empty comment is guarded before any service call',
      (tester) async {
    final announces = AnnounceChannel.arm(tester);
    await pumpHost(tester, commentText: '   ');
    await tester.tap(find.text('post'));
    await tester.pumpAndSettle();

    expect(announces.count, 0);
    verifyNever(() => socialVm.postComment(any()));
  });
}
