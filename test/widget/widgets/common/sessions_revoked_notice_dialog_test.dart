// BUT-2481: the notice after "logga ut från alla enheter" shows once, reads the
// profile at most once per sign-in, and a failed read tries again next start.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/auth/sessions_revoked_notice.dart';
import 'package:butlery/widgets/common/sessions_revoked_notice_dialog.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockUser extends Mock implements User {}

void main() {
  final sv = AppLocalizationsSv();
  late _MockUserRepository users;
  final signInMs = DateTime(2026, 11, 7, 12).millisecondsSinceEpoch;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    ServiceLocator.reset();

    final user = _MockUser();
    when(() => user.uid).thenReturn('anna');
    when(() => user.metadata).thenReturn(
      UserMetadata(signInMs - 1000000, signInMs),
    );
    final auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(user);
    users = _MockUserRepository();

    final container = DIContainer();
    container.container.registerSingleton<AuthRepository>(auth);
    container.container.registerSingleton<UserRepository>(users);
    ServiceLocator.initialize(container);
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<BuildContext> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(child: const SizedBox.shrink()),
    );
    return tester.element(find.byType(SizedBox).first);
  }

  testWidgets('a recent stamp shows the notice once per sign-in', (
    tester,
  ) async {
    when(
      () => users.fetchSessionsRevokedAt('anna'),
    ).thenAnswer((_) async => DateTime.now().subtract(const Duration(days: 1)));
    final context = await pump(tester);

    unawaited(showSessionsRevokedNoticeIfDue(context));
    await tester.pumpAndSettle();
    expect(find.text(sv.settingsSignOutEverywhereTitle), findsOneWidget);

    await tester.tap(find.text(sv.commonClose));
    await tester.pumpAndSettle();

    await showSessionsRevokedNoticeIfDue(context);
    await tester.pumpAndSettle();
    expect(find.text(sv.settingsSignOutEverywhereTitle), findsNothing);
    verify(() => users.fetchSessionsRevokedAt('anna')).called(1);
  });

  testWidgets('no stamp: no dialog, and no second read in the same sign-in', (
    tester,
  ) async {
    when(
      () => users.fetchSessionsRevokedAt('anna'),
    ).thenAnswer((_) async => null);
    final context = await pump(tester);

    await showSessionsRevokedNoticeIfDue(context);
    await showSessionsRevokedNoticeIfDue(context);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    verify(() => users.fetchSessionsRevokedAt('anna')).called(1);
  });

  testWidgets('a failed read is not marked as checked, so it is retried', (
    tester,
  ) async {
    when(
      () => users.fetchSessionsRevokedAt('anna'),
    ).thenThrow(Exception('offline'));
    final context = await pump(tester);

    await showSessionsRevokedNoticeIfDue(context);
    expect(find.byType(AlertDialog), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(SessionsRevokedNotice.checkedSignInKey), isNull);

    when(
      () => users.fetchSessionsRevokedAt('anna'),
    ).thenAnswer((_) async => null);
    await showSessionsRevokedNoticeIfDue(context);
    verify(() => users.fetchSessionsRevokedAt('anna')).called(2);
  });
}
