// Konto & säkerhet under Mer: the sign-in rows lead to Kontosäkerhet, the
// sign-out row asks before it signs out, and the delete-account row is the
// destructive last row that opens the deletion dialog.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/auth/sign_out_guard.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/more/account_area_view.dart';
import 'package:butlery/widgets/common/profile/handlers/auth_action_handler.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockUserService extends Mock implements UserService {}

class _MockReportService extends Mock implements ReportService {}

class _FakeAuthService extends Fake implements AuthService {
  @override
  String? get currentUserId => 'anna';
}

class _EmptyQueue implements PendingChangesSource {
  @override
  Future<PendingChanges> read(String userId) async => PendingChanges.none;

  @override
  Future<void> discard(String userId) async {}
}

void main() {
  final sv = AppLocalizationsSv();
  late SignOutGuard Function() originalFactory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    ServiceLocator.reset();

    final users = _MockUserService();
    when(() => users.currentUserProfile).thenReturn(
      UserProfile(
        uid: 'anna',
        displayName: 'Anna',
        email: 'anna@example.com',
        joinedAt: DateTime(2024, 1, 1),
        lastActiveAt: DateTime(2024, 1, 1),
      ),
    );
    final reports = _MockReportService();
    when(
      () => reports.ownReportStatus(),
    ).thenAnswer((_) async => OwnReportStatus.none);

    final container = DIContainer();
    container.container.registerSingleton<UserService>(users);
    container.container.registerSingleton<ReportService>(reports);
    ServiceLocator.initialize(container);

    originalFactory = AuthActionHandler.guardFactory;
    AuthActionHandler.guardFactory = () =>
        SignOutGuard(authService: _FakeAuthService(), source: _EmptyQueue());
  });

  tearDown(() async {
    AuthActionHandler.guardFactory = originalFactory;
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<List<String?>> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pushed = <String?>[];
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const AccountAreaView(),
        onGenerateRoute: (settings) {
          pushed.add(settings.name);
          return MaterialPageRoute<void>(
            builder: (_) => const SizedBox.shrink(),
            settings: settings,
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    return pushed;
  }

  testWidgets('shows the account email on its row', (tester) async {
    await pump(tester);

    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text(sv.settingsAccountEmail),
          matching: find.byType(InkWell),
        ),
        matching: find.text('anna@example.com'),
      ),
      findsOneWidget,
    );
  });

  for (final label in [
    sv.settingsAccountEmail,
    sv.settingsAccountPassword,
    sv.settingsAccountTwoStep,
  ]) {
    testWidgets('the "$label" row opens Kontosäkerhet', (tester) async {
      final pushed = await pump(tester);

      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(pushed, [Routes.settingsAccountSecurity]);
    });
  }

  testWidgets('the sign-out row asks first and cancelling stays on the page', (
    tester,
  ) async {
    final pushed = await pump(tester);

    await tester.tap(find.text(sv.profileLogout));
    await tester.pumpAndSettle();
    expect(find.text(sv.profileLogoutConfirm), findsOneWidget);

    await tester.tap(find.text(sv.commonCancel));
    await tester.pumpAndSettle();

    expect(find.text(sv.profileLogoutConfirm), findsNothing);
    expect(find.byType(AccountAreaView), findsOneWidget);
    expect(pushed, isEmpty);
  });

  testWidgets('the delete-account row is drawn in the theme error colour '
      'and opens the deletion dialog', (tester) async {
    late ColorScheme cs;
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Builder(
          builder: (context) {
            cs = Theme.of(context).colorScheme;
            return const AccountAreaView();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.text(sv.profileDeleteAccount);
    expect(tester.widget<Text>(row).style?.color, cs.error);
    // The sign-out row beside it is not flagged.
    expect(
      tester.widget<Text>(find.text(sv.profileLogout)).style?.color,
      isNot(cs.error),
    );

    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.text(sv.profileDeleteWarningTitle), findsOneWidget);
  });
}
