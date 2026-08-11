/// BUT-1819: what the two source-URL TAP HANDLERS do when a link will not open.
///
/// The plan named the first explicitly — "`handleSourceUrlClick` testas, inte
/// bara hjälparen" — because a unit test of `openExternalLink` proves nothing
/// about a wrapper that has to decide what to do with a `false`. `launchSourceUrl`
/// joined it after review: it is the row's own handler, and it used to swallow
/// every failure.
///
/// No test here opens a real browser. Three fixtures are refused before the
/// plugin is reached; two swap `UrlLauncherPlatform.instance` — one for a
/// launcher that answers false, which is how the OS-declines-a-valid-link case
/// is reached without a platform channel, and one that answers true, the
/// success control that keeps "always show an error" from surviving. The
/// message assertions are on WHICH string, so the refuse-the-scheme branch
/// stays distinguishable from the cannot-parse-it branch.
///
/// The overflow-menu entry is a third site and is NOT covered here — see the
/// note at the end of the file for why.
library;

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_actions.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../test_support/base_unit_test.dart';

/// A launcher that accepts everything, standing in for an OS that opens the
/// link. The success control's double.
class _AcceptingUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async => true;
}

/// A launcher that refuses everything, standing in for the OS declining to
/// open a link that is perfectly well-formed. Swapping
/// `UrlLauncherPlatform.instance` is the seam `linkified_text_test.dart`
/// already uses; it bypasses the platform channel, so the answer arrives on
/// the same microtask queue `pump` drains.
///
/// Only `launchUrl` is stubbed: `openExternalLink` has no `canLaunchUrl`
/// pre-check. That was dropped in review — the plugin documents `canLaunchUrl`
/// as answering a PERMISSION question, and `ios/Runner/Info.plist` declares no
/// `LSApplicationQueriesSchemes`, so on iOS it can refuse a link that would
/// have opened.
class _RefusingUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async => false;
}

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  /// Pumps a button that runs [onTap], so the handler gets a real mounted
  /// context with a `ScaffoldMessenger` above it.
  Future<void> pumpTapper(
    WidgetTester tester,
    Future<void> Function(BuildContext) onTap,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => onTap(context),
              child: const Text('tap'),
            ),
          ),
        ),
      ),
    );
  }

  group('handleSourceUrlClick', () {
    testWidgets('a javascript: source shows an error instead of opening', (
      tester,
    ) async {
      // The wrapper's whole job on a refusal. Before BUT-1819 it called
      // `launchUrl` directly with no scheme check at all.
      final actions = RecipeDetailActions();

      await pumpTapper(
        tester,
        (context) =>
            actions.handleSourceUrlClick(context, 'javascript:alert(1)'),
      );
      await tester.tap(find.text('tap'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      // The REFUSAL message, not the malformed-input one — the string parses
      // fine, it is the scheme that is rejected, and telling those apart is the
      // difference between the guard working and `Uri.parse` throwing.
      //
      // WHY THIS CAN FAIL AT ALL: no url_launcher channel is bound in unit
      // tests. With the guard present, `openExternalLink` returns false before
      // reaching the plugin. Remove it and `launchUrl` reaches the unstubbed
      // method channel and throws `MissingPluginException` — which is not a
      // `PlatformException`, so it escapes the helper's catch and the handler's
      // own catch turns it into the OTHER message — so the mutant dies on this line. A future shared `setUp`
      // that mocks the channel changes this, but only in one direction: a mock
      // answering FALSE blinds this assertion (both paths then produce
      // `errorCouldNotOpenLink`), while a permissive one reddens the
      // `findsOneWidget` above instead, because the mutant would open the URL
      // and show no snackbar at all.
      final l10n = await AppLocalizations.delegate.load(const Locale('sv'));
      expect(find.text(l10n.errorCouldNotOpenLink), findsOneWidget);
    });

    testWidgets('a provenance sentence shows the invalid-link message', (
      tester,
    ) async {
      // `Uri.parse` THROWS on this one — not because of the colon, but because
      // a SPACE precedes it, which is an illegal scheme character. A colon with
      // a legal prefix parses fine and dies on the scheme line instead. So
      // it takes the catch branch rather than the refusal branch. Both end in a
      // message; asserting which proves the two paths are still distinct.
      final actions = RecipeDetailActions();

      await pumpTapper(
        tester,
        (context) =>
            actions.handleSourceUrlClick(context, 'Kopierat från: Pannkakor'),
      );
      await tester.tap(find.text('tap'));
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('sv'));
      expect(find.text(l10n.errorInvalidLink), findsOneWidget);
    });
  });

  group('launchSourceUrl', () {
    testWidgets('a refused link says so instead of doing nothing', (
      tester,
    ) async {
      // The row's own tap handler. It used to swallow every failure, so a
      // value the row had DRAWN as tappable could be tapped forever with no
      // response — the same shape of lie the render guard removed from the row.
      //
      // The fixture is a REFUSED value: `openExternalLink` returns false at the
      // scheme line, before the plugin, which is the branch the fix added. The
      // OS-refuses-a-VALID-link case is pinned by the test below.
      await pumpTapper(
        tester,
        (context) => RecipeDetailSharedWidgets.launchSourceUrl(
          context,
          'javascript:alert(1)',
        ),
      );
      await tester.tap(find.text('tap'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      final l10n = await AppLocalizations.delegate.load(const Locale('sv'));
      expect(find.text(l10n.errorCouldNotOpenLink), findsOneWidget);
    });

    testWidgets('a valid link the OS refuses also says so', (tester) async {
      // The case that matters most in practice, and the one an earlier version
      // of this file wrote off as untestable: the row DREW this as a link
      // because `isSafeExternalUrl` accepts it, the user taps it, and the OS
      // declines. Before the fix that was silence. Reaching it needs a
      // launcher that answers false rather than one that is absent — the
      // platform-instance seam, not a channel mock.
      final original = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = _RefusingUrlLauncher();
      addTearDown(() => UrlLauncherPlatform.instance = original);

      await pumpTapper(
        tester,
        (context) => RecipeDetailSharedWidgets.launchSourceUrl(
          context,
          'https://ica.se/recept/pannkakor',
        ),
      );
      await tester.tap(find.text('tap'));
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('sv'));
      expect(find.text(l10n.errorCouldNotOpenLink), findsOneWidget);
    });
  });

  group('the success control', () {
    testWidgets('a link that DOES open says nothing', (tester) async {
      // Without this, every test in the file asserts that a message appears,
      // and the mutant "show `errorCouldNotOpenLink` unconditionally" survives
      // all of them. This is also the only test that proves `launchSourceUrl`
      // consults the launcher at all on the happy path rather than short-
      // circuiting to a message.
      final original = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = _AcceptingUrlLauncher();
      addTearDown(() => UrlLauncherPlatform.instance = original);

      await pumpTapper(
        tester,
        (context) => RecipeDetailSharedWidgets.launchSourceUrl(
          context,
          'https://ica.se/recept/pannkakor',
        ),
      );
      await tester.tap(find.text('tap'));
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });
  });

  // The overflow-menu entry is NOT pinned here, and deliberately not by a
  // duplicate. `recipe_detail_view.dart:690` gates its `PopupMenuItem` on the
  // same `isSafeExternalUrl`, but asserting the predicate again would only
  // restate `external_link_test.dart` under a name that promises a rendered
  // outcome. A real test of that entry costs the whole detail-view DI stack;
  // saying so is more honest than a green test that cannot observe the wiring.
}
