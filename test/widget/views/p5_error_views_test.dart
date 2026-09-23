// P5-U10 and P5-U12: account security and the recipe editor show a failed
// save as the three-part failure (content-style-guide.md:87-97): what did
// not happen and why, what was kept when typed content is at stake, and
// Försök igen or Stäng. Never OK.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/views/edit_recipe_view.dart';
import 'package:butlery/views/settings/account_security_view.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart' as mocks;
import '../../test_support/base_unit_test.dart';

void main() {
  final l10n = AppLocalizationsSv();
  late mocks.MockAuthService auth;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    auth = MockFactory.createAuthService(
      isAuthenticated: true,
      userId: 'test-user-123',
    );
    TestServiceLocator.registerMock<AuthService>(auth);
    TestServiceLocator.registerMock<PermissionService>(
      MockFactory.createPermissionService(currentUserId: 'test-user-123'),
    );
    TestServiceLocator.registerMock<SocialRecipeService>(
      MockFactory.createSocialRecipeService(),
    );
    TestServiceLocator.registerFactory<CollaborativeStatusViewModel>(
      () => CollaborativeStatusViewModel(),
    );
    TestServiceLocator.registerMock<ImageUploadService>(ImageUploadService());
    final tags = mocks.MockPersonalTagService();
    TestServiceLocator.registerMock<PersonalTagService>(tags);
    TestServiceLocator.registerMock<OfflineService>(
      OfflineService(
        firestoreRepository: TestServiceLocator.get<FirestoreRepository>(),
        authRepository: TestServiceLocator.get<AuthRepository>(),
      ),
    );
    TestServiceLocator.registerFactory<PersonalTagViewModel>(
      () => PersonalTagViewModel(service: tags),
    );
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  group('account security (P5-U10)', () {
    Future<void> pumpView(WidgetTester tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const AccountSecurityView(),
          wrapInScaffold: false,
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> fillPassword(WidgetTester tester) async {
      await tester.enterText(
        // The password section's field; the email section has one too.
        find
            .widgetWithText(TextField, l10n.accountSecurityCurrentPassword)
            .first,
        'current123',
      );
      await tester.enterText(
        find.widgetWithText(TextField, l10n.accountSecurityNewPassword),
        'newPassword123',
      );
      await tester.enterText(
        find.widgetWithText(TextField, l10n.accountSecurityConfirmPassword),
        'newPassword123',
      );
    }

    testWidgets('a server failure names the cause and offers Försök igen', (
      tester,
    ) async {
      auth.setAuthState(isAuthenticated: true, error: l10n.errorNetwork);
      when(
        () => auth.reauthenticateWithPassword(any()),
      ).thenAnswer((_) async => true);
      when(() => auth.changePassword(any())).thenAnswer((_) async => false);

      await pumpView(tester);
      await fillPassword(tester);
      await tester.ensureVisible(
        find.text(l10n.accountSecurityChangePassword).last,
      );
      await tester.tap(find.text(l10n.accountSecurityChangePassword).last);
      await tester.pumpAndSettle();

      expect(
        find.text(
          l10n.accountSecurityPasswordChangeFailedBecause(l10n.errorNetwork),
        ),
        findsOneWidget,
      );
      expect(find.text('OK'), findsNothing);

      await tester.tap(find.text(l10n.commonRetry));
      await tester.pumpAndSettle();
      verify(() => auth.changePassword('newPassword123')).called(2);
    });

    testWidgets('a form error gets Stäng, not Försök igen', (tester) async {
      await pumpView(tester);
      await tester.ensureVisible(
        find.text(l10n.accountSecurityChangePassword).last,
      );
      await tester.tap(find.text(l10n.accountSecurityChangePassword).last);
      await tester.pumpAndSettle();

      expect(find.text(l10n.validationPasswordRequired), findsWidgets);
      expect(find.text(l10n.commonClose), findsOneWidget);
      expect(find.text(l10n.commonRetry), findsNothing);
    });
  });

  group('recipe editor (P5-U12)', () {
    testWidgets('a failed save says the edits are kept and offers Försök '
        'igen, and the editor stays open', (tester) async {
      final Recipe recipe = RecipeFactory.build(
        id: 'recipe-p5-u12',
        title: 'Testrecept',
        description: 'Beskrivning',
        ingredients: const ['Mjöl', 'Socker'],
        instructions: const ['Blanda', 'Grädda'],
      );
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: EditRecipeView(recipe: recipe),
          wrapInScaffold: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Testrecept'),
        'Testrecept 2',
      );
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('edit-recipe-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      final failure = find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data ?? '').endsWith(l10n.errorPreservedRecipeEdits),
      );
      expect(failure, findsOneWidget);
      expect(find.byType(EditRecipeView), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Testrecept 2'),
        findsOneWidget,
        reason: 'the edits are still in the form',
      );
      expect(find.text('OK'), findsNothing);
      expect(
        find.text(l10n.commonRetry).evaluate().isNotEmpty ||
            find.text(l10n.commonClose).evaluate().isNotEmpty,
        isTrue,
      );
      final text = tester.widget<Text>(failure).data!;
      expect(
        text,
        anyOf(
          SnackBarUtils.failureMessage(
            l10n.recipeSaveFailed,
            l10n.errorPreservedRecipeEdits,
          ),
          SnackBarUtils.failureMessage(
            l10n.errorNoPermissionToSave,
            l10n.errorPreservedRecipeEdits,
          ),
        ),
      );
    });
  });
}
