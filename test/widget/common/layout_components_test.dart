/// Widget tests for the LayoutComponents facade.
///
/// Covers the parts of the facade that can be exercised without standing up
/// the production ServiceLocator (offline service, menu viewmodels, profile
/// service stack). Heavy-dependency entry points are documented with
/// `// SKIP:` markers below.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/core/responsive/responsive_builder.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/responsive/responsive_grid.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';

/// Plain MaterialApp wrapper for widgets that don't touch `context.l10n`.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// MaterialApp wrapper with Swedish localization for widgets that call
/// `context.l10n.<key>` (ButleryHeader, navigation landmark, etc).
Widget _wrapWithL10n(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: child,
);

/// Pump at a specific logical width so the Breakpoints helpers resolve to a
/// known device category. Height is generous to avoid clipping.
Future<void> _pumpAtWidth(
  WidgetTester tester,
  double width,
  Widget child, {
  bool withL10n = false,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 2000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(withL10n ? _wrapWithL10n(child) : _wrap(child));
}

/// Helper that captures the BuildContext at render time so we can invoke the
/// facade's `static T fn(BuildContext context, ...)` helpers from a test.
class _ContextCapture extends StatelessWidget {
  const _ContextCapture(this.onContext);
  final void Function(BuildContext context) onContext;

  @override
  Widget build(BuildContext context) {
    onContext(context);
    return const SizedBox.shrink();
  }
}

void main() {
  // ---------------------------------------------------------------------
  // Breakpoint helpers — isMobile / isTablet / isDesktop / valueFor
  // ---------------------------------------------------------------------
  group('LayoutComponents.isMobile / isTablet / isDesktop', () {
    testWidgets('400px → isMobile=true, others=false', (tester) async {
      late BuildContext captured;
      await _pumpAtWidth(
        tester,
        400,
        _ContextCapture((ctx) => captured = ctx),
      );
      expect(LayoutComponents.isMobile(captured), isTrue);
      expect(LayoutComponents.isTablet(captured), isFalse);
      expect(LayoutComponents.isDesktop(captured), isFalse);
    });

    testWidgets('800px → isTablet=true, others=false', (tester) async {
      late BuildContext captured;
      await _pumpAtWidth(
        tester,
        800,
        _ContextCapture((ctx) => captured = ctx),
      );
      expect(LayoutComponents.isMobile(captured), isFalse);
      expect(LayoutComponents.isTablet(captured), isTrue);
      expect(LayoutComponents.isDesktop(captured), isFalse);
    });

    testWidgets('1400px → isDesktop=true, others=false', (tester) async {
      late BuildContext captured;
      await _pumpAtWidth(
        tester,
        1400,
        _ContextCapture((ctx) => captured = ctx),
      );
      expect(LayoutComponents.isMobile(captured), isFalse);
      expect(LayoutComponents.isTablet(captured), isFalse);
      expect(LayoutComponents.isDesktop(captured), isTrue);
    });
  });

  group('LayoutComponents.valueFor', () {
    testWidgets('returns mobile value on phone widths', (tester) async {
      late BuildContext captured;
      await _pumpAtWidth(
        tester,
        400,
        _ContextCapture((ctx) => captured = ctx),
      );
      final value = LayoutComponents.valueFor<int>(
        context: captured,
        mobile: 1,
        tablet: 2,
        desktop: 3,
      );
      expect(value, 1);
    });

    testWidgets('returns tablet value on 800px', (tester) async {
      late BuildContext captured;
      await _pumpAtWidth(
        tester,
        800,
        _ContextCapture((ctx) => captured = ctx),
      );
      final value = LayoutComponents.valueFor<int>(
        context: captured,
        mobile: 1,
        tablet: 2,
        desktop: 3,
      );
      expect(value, 2);
    });

    testWidgets('returns desktop value on 1400px', (tester) async {
      late BuildContext captured;
      await _pumpAtWidth(
        tester,
        1400,
        _ContextCapture((ctx) => captured = ctx),
      );
      final value = LayoutComponents.valueFor<int>(
        context: captured,
        mobile: 1,
        tablet: 2,
        desktop: 3,
      );
      expect(value, 3);
    });

    testWidgets(
      'falls back to mobile when tablet/desktop omitted at large widths',
      (tester) async {
        late BuildContext captured;
        await _pumpAtWidth(
          tester,
          1400,
          _ContextCapture((ctx) => captured = ctx),
        );
        final value = LayoutComponents.valueFor<String>(
          context: captured,
          mobile: 'mobile-only',
        );
        expect(value, 'mobile-only');
      },
    );
  });

  // ---------------------------------------------------------------------
  // responsiveBuilder — selects the right child for the screen size.
  // ---------------------------------------------------------------------
  group('LayoutComponents.responsiveBuilder', () {
    testWidgets('renders mobile child at 400px', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        LayoutComponents.responsiveBuilder(
          mobile: (_) => const Text('mobile-child'),
          tablet: (_) => const Text('tablet-child'),
          desktop: (_) => const Text('desktop-child'),
        ),
      );
      expect(find.text('mobile-child'), findsOneWidget);
      expect(find.text('tablet-child'), findsNothing);
      expect(find.text('desktop-child'), findsNothing);
    });

    testWidgets('renders tablet child at 800px', (tester) async {
      await _pumpAtWidth(
        tester,
        800,
        LayoutComponents.responsiveBuilder(
          mobile: (_) => const Text('mobile-child'),
          tablet: (_) => const Text('tablet-child'),
          desktop: (_) => const Text('desktop-child'),
        ),
      );
      expect(find.text('tablet-child'), findsOneWidget);
    });

    testWidgets('renders desktop child at 1400px', (tester) async {
      await _pumpAtWidth(
        tester,
        1400,
        LayoutComponents.responsiveBuilder(
          mobile: (_) => const Text('mobile-child'),
          tablet: (_) => const Text('tablet-child'),
          desktop: (_) => const Text('desktop-child'),
        ),
      );
      expect(find.text('desktop-child'), findsOneWidget);
    });

    testWidgets('returns a ResponsiveBuilder instance', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        LayoutComponents.responsiveBuilder(
          mobile: (_) => const SizedBox.shrink(),
        ),
      );
      expect(find.byType(ResponsiveBuilder), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------
  // responsiveGrid — facade for ResponsiveGrid.
  // ---------------------------------------------------------------------
  group('LayoutComponents.responsiveGrid', () {
    testWidgets('builds a ResponsiveGrid containing the supplied children', (
      tester,
    ) async {
      await _pumpAtWidth(
        tester,
        400,
        LayoutComponents.responsiveGrid(
          children: const [
            Text('grid-item-a'),
            Text('grid-item-b'),
          ],
        ),
      );
      expect(find.byType(ResponsiveGrid), findsOneWidget);
      expect(find.text('grid-item-a'), findsOneWidget);
    });

    testWidgets('mobileColumns override applied at mobile width', (
      tester,
    ) async {
      await _pumpAtWidth(
        tester,
        400,
        LayoutComponents.responsiveGrid(
          children: const [Text('a'), Text('b'), Text('c')],
          mobileColumns: 3,
        ),
      );
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
    });

    testWidgets('spacing override applied to grid delegate', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        LayoutComponents.responsiveGrid(
          children: const [Text('a')],
          spacing: 42,
        ),
      );
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.mainAxisSpacing, 42);
      expect(delegate.crossAxisSpacing, 42);
    });

    testWidgets('childAspectRatio forwarded to delegate', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        LayoutComponents.responsiveGrid(
          children: const [Text('a')],
          childAspectRatio: 2.5,
        ),
      );
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.childAspectRatio, 2.5);
    });

    testWidgets('shrinkWrap + physics forwarded', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        LayoutComponents.responsiveGrid(
          children: const [Text('a')],
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
        ),
      );
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(grid.shrinkWrap, isTrue);
      expect(grid.physics, isA<NeverScrollableScrollPhysics>());
    });

    testWidgets('padding override applied to GridView', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        LayoutComponents.responsiveGrid(
          children: const [Text('a')],
          padding: const EdgeInsets.all(7),
        ),
      );
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(grid.padding, const EdgeInsets.all(7));
    });
  });

  // ---------------------------------------------------------------------
  // responsiveListGrid — list on mobile, grid on tablet/desktop.
  // ---------------------------------------------------------------------
  group('LayoutComponents.responsiveListGrid', () {
    testWidgets('renders ListView at mobile width', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        LayoutComponents.responsiveListGrid<String>(
          items: const ['x', 'y'],
          itemBuilder: (context, item) => Text('item-$item'),
        ),
      );
      // Mobile path uses a ListView (separated).
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('item-x'), findsOneWidget);
      expect(find.text('item-y'), findsOneWidget);
    });

    testWidgets('renders GridView at tablet width', (tester) async {
      await _pumpAtWidth(
        tester,
        800,
        LayoutComponents.responsiveListGrid<String>(
          items: const ['x', 'y'],
          itemBuilder: (context, item) => Text('item-$item'),
        ),
      );
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('item-x'), findsOneWidget);
    });

    testWidgets('forwards tabletColumns override at tablet width', (
      tester,
    ) async {
      await _pumpAtWidth(
        tester,
        800,
        LayoutComponents.responsiveListGrid<int>(
          items: const [1, 2, 3, 4],
          itemBuilder: (context, item) => Text('n=$item'),
          tabletColumns: 4,
        ),
      );
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 4);
    });

    testWidgets('itemBuilder is invoked for each item on mobile', (
      tester,
    ) async {
      final builtFor = <String>[];
      await _pumpAtWidth(
        tester,
        400,
        LayoutComponents.responsiveListGrid<String>(
          items: const ['alpha', 'beta'],
          itemBuilder: (context, item) {
            builtFor.add(item);
            return Text('row-$item');
          },
        ),
      );
      expect(builtFor, containsAll(['alpha', 'beta']));
    });
  });

  // ---------------------------------------------------------------------
  // AdaptiveNavigationScaffold — the shell's scaffold (the LayoutComponents
  // wrappers had no app callers and were removed in package 7).
  // ---------------------------------------------------------------------
  group('AdaptiveNavigationScaffold', () {
    final navItems = [
      const AdaptiveNavigationItem(
        label: 'Home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        route: '/',
      ),
      const AdaptiveNavigationItem(
        label: 'Profile',
        icon: ButleryIcons.user,
        activeIcon: ButleryIcons.user,
        route: '/profile',
      ),
    ];

    testWidgets('renders the scaffold with body content', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        AdaptiveNavigationScaffold(
          currentIndex: 0,
          items: navItems,
          body: const Text('body-content'),
        ),
        withL10n: true,
      );
      expect(find.byType(AdaptiveNavigationScaffold), findsOneWidget);
      expect(find.text('body-content'), findsOneWidget);
    });

    testWidgets('mobile width renders BottomNavigation', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        AdaptiveNavigationScaffold(
          currentIndex: 0,
          items: navItems,
          body: const SizedBox.shrink(),
        ),
        withL10n: true,
      );
      expect(find.byType(ButleryBottomNavigation), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('tablet width renders our rail (produktregler.md:1054)', (
      tester,
    ) async {
      await _pumpAtWidth(
        tester,
        800,
        AdaptiveNavigationScaffold(
          currentIndex: 0,
          items: navItems,
          body: const SizedBox.shrink(),
        ),
        withL10n: true,
      );
      expect(find.byType(ButleryNavigationRail), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(ButleryBottomNavigation), findsNothing);
    });

    testWidgets('onNavigationChanged is wired through bottom nav tap', (
      tester,
    ) async {
      int? tapped;
      await _pumpAtWidth(
        tester,
        400,
        AdaptiveNavigationScaffold(
          currentIndex: 0,
          items: navItems,
          body: const SizedBox.shrink(),
          onNavigationChanged: (i) => tapped = i,
        ),
        withL10n: true,
      );
      // Tap the second nav destination — the inner InkWell is keyed by route.
      await tester.tap(find.byKey(const ValueKey('test-nav-/profile')));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('floatingActionButton is forwarded to the Scaffold', (
      tester,
    ) async {
      const fabKey = Key('layout-fab');
      await _pumpAtWidth(
        tester,
        400,
        AdaptiveNavigationScaffold(
          currentIndex: 0,
          items: navItems,
          body: const SizedBox.shrink(),
          floatingActionButton: FloatingActionButton(
            key: fabKey,
            onPressed: () {},
            child: const ButleryIcon(ButleryIcons.plus),
          ),
        ),
        withL10n: true,
      );
      expect(find.byKey(fabKey), findsOneWidget);
    });

    testWidgets('no appBar draws no bar (the bare title AppBar is gone)', (
      tester,
    ) async {
      await _pumpAtWidth(
        tester,
        400,
        AdaptiveNavigationScaffold(
          currentIndex: 0,
          items: navItems,
          body: const SizedBox.shrink(),
        ),
        withL10n: true,
      );
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('a custom appBar is drawn', (tester) async {
      const customKey = Key('custom-appbar');
      await _pumpAtWidth(
        tester,
        400,
        AdaptiveNavigationScaffold(
          currentIndex: 0,
          items: navItems,
          body: const SizedBox.shrink(),
          appBar: AppBar(
            key: customKey,
            title: const Text('custom-title'),
          ),
        ),
        withL10n: true,
      );
      expect(find.byKey(customKey), findsOneWidget);
      expect(find.text('custom-title'), findsOneWidget);
    });

    testWidgets('desktop width keeps the same rail (produktregler.md:1054)', (
      tester,
    ) async {
      await _pumpAtWidth(
        tester,
        1400,
        AdaptiveNavigationScaffold(
          currentIndex: 0,
          items: navItems,
          body: const SizedBox.shrink(),
        ),
        withL10n: true,
      );
      expect(find.byType(ButleryNavigationRail), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });
  });

  // ---------------------------------------------------------------------
  // ButleryAdaptiveNavigation — the predefined nav items.
  // ---------------------------------------------------------------------
  group('ButleryAdaptiveNavigation', () {
    testWidgets('renders the ButleryAdaptiveNavigation widget', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        ButleryAdaptiveNavigation(
          currentIndex: 0,
          body: const Text('butlery-body'),
        ),
        withL10n: true,
      );
      expect(find.byType(ButleryAdaptiveNavigation), findsOneWidget);
      expect(find.text('butlery-body'), findsOneWidget);
    });

    testWidgets('exposes the 4 predefined Butlery nav destinations', (
      tester,
    ) async {
      await _pumpAtWidth(
        tester,
        400,
        ButleryAdaptiveNavigation(
          currentIndex: 0,
          body: const SizedBox.shrink(),
        ),
        withL10n: true,
      );
      // 4 bottom nav items (Hem · Meny · Inköp · Mer), each with a `test-nav-<route>` ValueKey on the
      // inner InkWell (mobile path).
      expect(find.byKey(const ValueKey('test-nav-/')), findsOneWidget);
      expect(find.byKey(const ValueKey('test-nav-/veckomeny')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('test-nav-/inkopslista')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('test-nav-/mer')), findsOneWidget);
      // PQ-17: "Lägg till" is no longer a destination.
      expect(find.byKey(const ValueKey('test-nav-/laggTill')), findsNothing);
    });
  });

  // ---------------------------------------------------------------------
  // recipeUploadButtonGrid — 6 main buttons + 1 archive (2-2-2-1 layout).
  // ---------------------------------------------------------------------
  group('LayoutComponents.recipeUploadButtonGrid', () {
    List<Map<String, dynamic>> makeButtons(
      int n, {
      VoidCallback? onPressedAt0,
    }) {
      return List.generate(n, (i) {
        return {
          'label': 'btn-$i',
          'icon': ButleryIcons.plus,
          'onPressed': (i == 0 && onPressedAt0 != null) ? onPressedAt0 : () {},
        };
      });
    }

    Map<String, dynamic> archive({VoidCallback? onPressed}) {
      return {
        'label': 'arkiv',
        'icon': ButleryIcons.archive,
        'onPressed': onPressed ?? () {},
      };
    }

    testWidgets('renders all 6 button labels + archive label', (tester) async {
      late BuildContext captured;
      await _pumpAtWidth(
        tester,
        400,
        _ContextCapture((ctx) => captured = ctx),
        withL10n: true,
      );
      await tester.pumpWidget(
        _wrapWithL10n(
          Column(
            children: [
              LayoutComponents.recipeUploadButtonGrid(
                captured,
                buttons: makeButtons(6),
                archiveButton: archive(),
              ),
            ],
          ),
        ),
      );

      for (var i = 0; i < 6; i++) {
        expect(find.text('btn-$i'), findsOneWidget);
      }
      expect(find.text('arkiv'), findsOneWidget);
    });

    testWidgets('throws ArgumentError when fewer than 6 buttons are supplied', (
      tester,
    ) async {
      late BuildContext captured;
      await _pumpAtWidth(
        tester,
        400,
        _ContextCapture((ctx) => captured = ctx),
        withL10n: true,
      );
      expect(
        () => LayoutComponents.recipeUploadButtonGrid(
          captured,
          buttons: makeButtons(5),
          archiveButton: archive(),
        ),
        throwsArgumentError,
      );
    });

    testWidgets('throws ArgumentError when more than 6 buttons are supplied', (
      tester,
    ) async {
      late BuildContext captured;
      await _pumpAtWidth(
        tester,
        400,
        _ContextCapture((ctx) => captured = ctx),
        withL10n: true,
      );
      expect(
        () => LayoutComponents.recipeUploadButtonGrid(
          captured,
          buttons: makeButtons(7),
          archiveButton: archive(),
        ),
        throwsArgumentError,
      );
    });

    testWidgets('tapping the first button invokes its onPressed', (
      tester,
    ) async {
      late BuildContext captured;
      await _pumpAtWidth(
        tester,
        400,
        _ContextCapture((ctx) => captured = ctx),
        withL10n: true,
      );
      var fired = 0;
      await tester.pumpWidget(
        _wrapWithL10n(
          Column(
            children: [
              LayoutComponents.recipeUploadButtonGrid(
                captured,
                buttons: makeButtons(6, onPressedAt0: () => fired++),
                archiveButton: archive(),
              ),
            ],
          ),
        ),
      );

      // Tapping by visible label is more stable than reaching into the inner
      // square button structure (UtilityComponents may add Semantics/InkWell
      // wrappers we don't want to depend on).
      await tester.tap(find.text('btn-0'), warnIfMissed: false);
      await tester.pump();
      expect(fired, 1);
    });

    testWidgets('tapping the archive button invokes its onPressed', (
      tester,
    ) async {
      late BuildContext captured;
      await _pumpAtWidth(
        tester,
        400,
        _ContextCapture((ctx) => captured = ctx),
        withL10n: true,
      );
      var fired = 0;
      await tester.pumpWidget(
        _wrapWithL10n(
          Column(
            children: [
              LayoutComponents.recipeUploadButtonGrid(
                captured,
                buttons: makeButtons(6),
                archiveButton: archive(onPressed: () => fired++),
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('arkiv'), warnIfMissed: false);
      await tester.pump();
      expect(fired, 1);
    });

    testWidgets('wraps its contents in an Expanded for parent Column/Row use', (
      tester,
    ) async {
      late BuildContext captured;
      await _pumpAtWidth(
        tester,
        400,
        _ContextCapture((ctx) => captured = ctx),
        withL10n: true,
      );
      await tester.pumpWidget(
        _wrapWithL10n(
          Column(
            children: [
              LayoutComponents.recipeUploadButtonGrid(
                captured,
                buttons: makeButtons(6),
                archiveButton: archive(),
              ),
            ],
          ),
        ),
      );
      // The facade returns `Expanded(child: LayoutBuilder(...))`. At least one
      // Expanded should be present at the top of the subtree.
      expect(find.byType(Expanded), findsWidgets);
      expect(find.byType(LayoutBuilder), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------
  // SKIPPED — entry points that require production ServiceLocator wiring.
  //
  // The following facade methods are NOT covered here because they require
  // standing up production services (OfflineService, MenuViewModel,
  // ProfileViewModel, FriendsService, AppRouter, etc.) which is heavier than
  // a per-widget unit test should pull in. They are exercised by integration
  // tests / view-level smoke tests instead:
  //
  // SKIP: LayoutComponents.mainMenu        — pulls AdaptiveNavigationScaffold
  //                                          with the live tab modules.
  // SKIP: LayoutComponents.simpleLayout    — ButleryHeader needs l10n + theme.
  // SKIP: LayoutComponents.profileMenu     — depends on FriendsViewModel,
  //                                          MessagingService, RecipeService,
  //                                          MenuService via ServiceLocator.
  // SKIP: LayoutComponents.showProfileMenu — same dependency chain via bottom
  //                                          sheet route.
  // SKIP: LayoutComponents.offlineIndicator/offlineStatusIcon — need
  //                                          OfflineService registered in
  //                                          ServiceLocator.
  // SKIP: LayoutComponents.showSaveMenuDialog / showLoadMenuDialog — need a
  //       real MenuViewModel (full service stack).
  // ---------------------------------------------------------------------
  group('Heavy-dependency facade methods', () {
    testWidgets('mainMenu — covered by integration tests', (tester) async {
      // SKIP: requires live tab views (MinaReceptView etc) and ServiceLocator.
    }, skip: true);

    testWidgets('simpleLayout — covered by view-level tests', (tester) async {
      // SKIP: requires localizations and ServiceLocator-backed services.
    }, skip: true);

    testWidgets('profileMenu — covered by profile widget tests', (
      tester,
    ) async {
      // SKIP: requires FriendsViewModel/MessagingService/RecipeService/
      // MenuService in ServiceLocator.
    }, skip: true);

    testWidgets('showProfileMenu — covered by profile widget tests', (
      tester,
    ) async {
      // SKIP: opens the modal route that hits the same dependency chain as
      // profileMenu.
    }, skip: true);

    testWidgets('offlineIndicator — covered by status indicator tests', (
      tester,
    ) async {
      // SKIP: needs OfflineService registered in ServiceLocator. The banner
      // (anatomy, pendingCount, onTap, announcements) is covered in
      // test/widget/common/layout/status_indicators_simplified_test.dart.
    }, skip: true);

    testWidgets('offlineStatusIcon — covered by status indicator tests', (
      tester,
    ) async {
      // SKIP: needs OfflineService registered in ServiceLocator.
    }, skip: true);

    testWidgets('showSaveMenuDialog — covered by menu dialog tests', (
      tester,
    ) async {
      // SKIP: requires a fully wired MenuViewModel.
    }, skip: true);

    testWidgets('showLoadMenuDialog — covered by menu dialog tests', (
      tester,
    ) async {
      // SKIP: requires a fully wired MenuViewModel.
    }, skip: true);
  });
}
