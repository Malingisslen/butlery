// PQ-17: the Mer tab (Skarmar v12 del 2 #mer), and "Mer → Väntar på synk"
// (produktregler.md). The profile row leads to Profil, the sync band is
// there only while something waits, and every other row opens its own view,
// identified by route. The friend-request count on Vänner & grupper is
// pinned in friends_but2306_test.dart.

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/more/more_view.dart';
import 'package:butlery/widgets/common/sync/sync_queue_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../sync/fake_sync_queue_source.dart';

final _sv = AppLocalizationsSv();

class _Pushes extends NavigatorObserver {
  final List<RouteSettings> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route.settings);
  }
}

class _FakeUserService extends Fake implements UserService {
  _FakeUserService(this.name);

  String? name;
  final _listeners = <VoidCallback>[];

  void rename(String? next) {
    name = next;
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  @override
  String? get currentDisplayName => name;

  @override
  UserProfile? get currentUserProfile => null;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
}

Widget _app(ThemeData theme, _Pushes pushes) => MaterialApp(
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: theme,
  navigatorObservers: [pushes],
  onGenerateRoute: (settings) => MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => const Scaffold(body: Text('pushed')),
  ),
  home: const MoreView(),
);

/// The drawn rows top to bottom, with the sync band (up while a change is
/// draining) between the profile and the first section.
final _rows = <String, String>{
  Routes.profileEdit: _sv.moreProfileFallbackName,
  Routes.syncQueue: _sv.moreSyncBand(1),
  Routes.notifications: _sv.moreNotifications,
  Routes.messages: _sv.messagingTitle,
  Routes.friends: _sv.socialFriendsAndGroups,
  Routes.shared: _sv.profileSharedWithMe,
  Routes.settingsFamily: _sv.moreFamily,
  Routes.settingsAllergens: _sv.moreAllergens,
  Routes.settingsPersonalTags: _sv.morePersonalTags,
  Routes.collectionStats: _sv.moreCollectionStats,
  Routes.settingsTrash: _sv.trashTitle,
  Routes.settingsAccount: _sv.settingsAccountAreaTitle,
  Routes.settingsPrivacy: _sv.settingsPrivacyAreaTitle,
  Routes.settings: _sv.settingsAppTitle,
  Routes.settingsHelp: _sv.settingsHelpTitle,
};

QueuedChange _change({String id = 'a', bool needsUser = false}) => QueuedChange(
  kind: QueuedChangeKind.recipe,
  id: id,
  operation: QueuedOperation.update,
  queuedAt: DateTime(2026),
  needsUser: needsUser,
);

void main() {
  late FakeSyncQueueSource source;

  setUp(() {
    source = FakeSyncQueueSource();
    SyncQueueSource.debugOverride = source;
    // One change draining, so every drawn row, the band included, is up.
    source.set([_change(id: 'draining')]);
  });

  tearDown(() async {
    SyncQueueSource.debugOverride = null;
    production.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<void> tall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<_FakeUserService> signedIn(String? name) async {
    final users = _FakeUserService(name);
    production.ServiceLocator.initialize(DIContainer());
    GetIt.instance.registerSingleton<UserService>(users);
    return users;
  }

  for (final mode in {
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  }.entries) {
    testWidgets('${mode.key}: the drawn sections and rows, in order', (
      tester,
    ) async {
      await tall(tester);
      await tester.pumpWidget(_app(mode.value, _Pushes()));
      await tester.pump();
      final cs = Theme.of(tester.element(find.byType(MoreView))).colorScheme;

      expect(find.text(_sv.moreTitle), findsOneWidget);
      for (final heading in [
        _sv.moreSectionTogether,
        _sv.moreSectionHousehold,
        _sv.moreSectionKitchen,
        _sv.moreSectionAppAccount,
      ]) {
        final text = tester.widget<Text>(find.text(heading.toUpperCase()));
        expect(text.style!.color, cs.tertiary, reason: heading);
      }
      var lastY = -1.0;
      for (final entry in _rows.entries) {
        final row = find.byKey(MoreView.rowKey(entry.key));
        expect(row, findsOneWidget, reason: entry.key);
        expect(
          find.descendant(of: row, matching: find.text(entry.value)),
          findsOneWidget,
          reason: entry.key,
        );
        final y = tester.getTopLeft(row).dy;
        expect(y, greaterThan(lastY), reason: entry.key);
        lastY = y;
      }
    });
  }

  for (final entry in _rows.entries) {
    testWidgets('the row "${entry.value}" opens ${entry.key}', (tester) async {
      await tall(tester);
      final pushes = _Pushes();
      await tester.pumpWidget(_app(AppTheme.lightTheme, pushes));
      await tester.pump();
      pushes.pushed.clear();

      await tester.tap(find.byKey(MoreView.rowKey(entry.key)));
      await tester.pumpAndSettle();
      expect(pushes.pushed.map((s) => s.name), [entry.key]);
    });
  }

  testWidgets('the four rows of Konto & app say what is behind them', (
    tester,
  ) async {
    await tall(tester);
    await tester.pumpWidget(_app(AppTheme.lightTheme, _Pushes()));
    await tester.pump();

    final subtitles = {
      Routes.settingsAccount: _sv.settingsAccountAreaSubtitle,
      Routes.settingsPrivacy: _sv.settingsPrivacyAreaSubtitle,
      Routes.settings: _sv.settingsAppSubtitle,
      Routes.settingsHelp: _sv.settingsHelpSubtitle,
    };
    for (final entry in subtitles.entries) {
      expect(
        find.descendant(
          of: find.byKey(MoreView.rowKey(entry.key)),
          matching: find.text(entry.value),
        ),
        findsOneWidget,
        reason: entry.key,
      );
    }
  });

  group('the profile row', () {
    testWidgets('names the signed-in user and opens Profil', (tester) async {
      await tall(tester);
      await signedIn('Malin');
      final pushes = _Pushes();
      await tester.pumpWidget(_app(AppTheme.lightTheme, pushes));
      await tester.pump();

      final row = find.byKey(MoreView.rowKey(Routes.profileEdit));
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(of: row, matching: find.text('Malin')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.text(_sv.moreProfileFallbackName),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: row, matching: find.text(_sv.moreProfileSubtitle)),
        findsOneWidget,
      );

      pushes.pushed.clear();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(pushes.pushed.map((s) => s.name), [Routes.profileEdit]);
    });

    testWidgets('follows a name change in UserService', (tester) async {
      await tall(tester);
      final users = await signedIn('Malin');
      await tester.pumpWidget(_app(AppTheme.lightTheme, _Pushes()));
      await tester.pump();
      expect(find.text('Malin'), findsOneWidget);

      users.rename('Anna');
      await tester.pump();

      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Malin'), findsNothing);
    });

    testWidgets('falls back to a generic name while the user has none', (
      tester,
    ) async {
      await tall(tester);
      await signedIn('   ');
      await tester.pumpWidget(_app(AppTheme.lightTheme, _Pushes()));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(MoreView.rowKey(Routes.profileEdit)),
          matching: find.text(_sv.moreProfileFallbackName),
        ),
        findsOneWidget,
      );
    });

    testWidgets('is one button named by the user, no avatar read aloud', (
      tester,
    ) async {
      await tall(tester);
      await signedIn('Malin');
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(AppTheme.lightTheme, _Pushes()));
      await tester.pump();

      final data = tester
          .getSemantics(find.byKey(MoreView.rowKey(Routes.profileEdit)))
          .getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(
        'Malin'.allMatches(data.label).length,
        1,
        reason: 'the name is read once, not again for the avatar',
      );
      handle.dispose();
    });
  });

  group('the sync band', () {
    testWidgets('is told that Back leads to Mer', (tester) async {
      await tall(tester);
      final pushes = _Pushes();
      await tester.pumpWidget(_app(AppTheme.lightTheme, pushes));
      await tester.pump();
      pushes.pushed.clear();
      await tester.tap(find.byKey(MoreView.rowKey(Routes.syncQueue)));
      await tester.pumpAndSettle();
      expect(pushes.pushed.single.arguments, _sv.moreTitle);
    });

    testWidgets('is there only while something waits', (tester) async {
      await tall(tester);
      source.set(const []);
      await tester.pumpWidget(_app(AppTheme.lightTheme, _Pushes()));
      await tester.pump();
      expect(find.byKey(MoreView.rowKey(Routes.syncQueue)), findsNothing);
      expect(find.byKey(MoreView.rowKey(Routes.settings)), findsOneWidget);

      source.set([_change()]);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(MoreView.rowKey(Routes.syncQueue)), findsOneWidget);
    });

    testWidgets('counts only what needs the user, and says so', (
      tester,
    ) async {
      await tall(tester);
      final handle = tester.ensureSemantics();
      source.set([_change()]);
      await tester.pumpWidget(_app(AppTheme.lightTheme, _Pushes()));
      await tester.pump();
      // Only draining: nothing (PQ-04 = B).
      expect(find.byType(SaffronCount), findsNothing);
      expect(
        tester
            .getSemantics(find.byKey(MoreView.rowKey(Routes.syncQueue)))
            .getSemanticsData()
            .value,
        isEmpty,
      );

      source.set([
        _change(needsUser: true),
        _change(id: 'b', needsUser: true),
      ]);
      await tester.pump();
      await tester.pump();
      final band = find.byKey(MoreView.rowKey(Routes.syncQueue));
      final count = find.descendant(
        of: band,
        matching: find.byType(SaffronCount),
      );
      expect(count, findsOneWidget);
      expect(find.descendant(of: count, matching: find.text('2')), findsOne);
      expect(
        tester.getSemantics(band).getSemanticsData().value,
        _sv.syncQueueNeedsYouHeader(2),
      );
      handle.dispose();
    });
  });

  testWidgets('each heading is its own node and holds no row', (tester) async {
    await tall(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(AppTheme.lightTheme, _Pushes()));
    await tester.pump();

    final headings = find.semantics
        .byFlag(SemanticsFlag.isHeader)
        .evaluate()
        .toList();
    final labels = headings.map((n) => n.getSemanticsData().label).toList();
    expect(
      labels,
      unorderedEquals([
        _sv.moreTitle,
        _sv.moreSectionTogether.toUpperCase(),
        _sv.moreSectionHousehold.toUpperCase(),
        _sv.moreSectionKitchen.toUpperCase(),
        _sv.moreSectionAppAccount.toUpperCase(),
      ]),
    );
    for (final heading in headings) {
      expect(heading.childrenCount, 0, reason: heading.label);
    }
    handle.dispose();
  });
}
