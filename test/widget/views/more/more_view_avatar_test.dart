// The Mer tab with its REAL avatar, as the app's shell builds it: no
// Provider<UserService> (or any social view model) sits above the tab. The
// sibling more_view_test.dart swaps the avatar out, which is how a
// Consumer3 that needed three providers shipped and covered the page with
// an error box in release.

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/more/more_view.dart';
import 'package:butlery/widgets/common/social_components/recipe_list_avatar_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../sync/fake_sync_queue_source.dart';

class _MockUserService extends Mock implements UserService {}

void main() {
  late _MockUserService userService;

  setUp(() {
    SyncQueueSource.debugOverride = FakeSyncQueueSource();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<UserService>()) getIt.unregister<UserService>();
    production.ServiceLocator.initialize(DIContainer());
    userService = _MockUserService();
    when(() => userService.currentUserProfile).thenReturn(null);
    when(() => userService.currentDisplayName).thenReturn('Malin');
    getIt.registerSingleton<UserService>(userService);
  });

  tearDown(() {
    SyncQueueSource.debugOverride = null;
    final getIt = GetIt.instance;
    if (getIt.isRegistered<UserService>()) getIt.unregister<UserService>();
    production.ServiceLocator.reset();
  });

  testWidgets('the Mer tab builds its avatar with no providers above it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme,
        home: const MoreView(),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(RecipeListAvatarBadge), findsOneWidget);
  });
}
