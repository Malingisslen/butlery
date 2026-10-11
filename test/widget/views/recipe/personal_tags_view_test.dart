/// REC-14 — behaviour tests for [PersonalTagsView], the personal-tags hub.
///
/// The view resolves its [PersonalTagViewModel] through the production
/// [ServiceLocator] (GetIt) and branches its body on four VM states:
///   loading → error → empty → tag list.
/// We register a thin fake VM (a real [ChangeNotifier] so the view's Consumer
/// rebuilds on state changes) over the GetIt bridge — the same seam the real
/// app uses — and assert the user-visible Swedish state for each branch.
///
/// [LayoutComponents.offlineIndicator] resolves [OfflineService] in initState,
/// so an online mock is registered too.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/views/personal_tags_view.dart';
import 'package:butlery/views/tag_detail_view.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/state_widget.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../../infrastructure/mocks/production_mocks.dart';
import 'fake_personal_tag_viewmodel.dart';

void main() {
  late _RecordingTagVm fakeVm;
  late MockOfflineService offlineService;

  setUp(() {
    final getIt = GetIt.instance;

    fakeVm = _RecordingTagVm();
    if (getIt.isRegistered<PersonalTagViewModel>()) {
      getIt.unregister<PersonalTagViewModel>();
    }
    getIt.registerFactory<PersonalTagViewModel>(() => fakeVm);

    offlineService = MockOfflineService();
    when(() => offlineService.isOnline).thenReturn(true);
    when(() => offlineService.addListener(any())).thenReturn(null);
    when(() => offlineService.removeListener(any())).thenReturn(null);
    if (getIt.isRegistered<OfflineService>()) {
      getIt.unregister<OfflineService>();
    }
    getIt.registerSingleton<OfflineService>(offlineService);

    production.ServiceLocator.reset();
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() {
    production.ServiceLocator.reset();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PersonalTagViewModel>()) {
      getIt.unregister<PersonalTagViewModel>();
    }
    if (getIt.isRegistered<OfflineService>()) {
      getIt.unregister<OfflineService>();
    }
  });

  Widget testApp({String? backTo}) {
    return MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: PersonalTagsView(backTo: backTo),
    );
  }

  Future<void> pumpView(WidgetTester tester, {String? backTo}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(testApp(backTo: backTo));
    await tester.pump(); // settle the post-frame statistics callback
  }

  testWidgets('renders the app-bar title', (tester) async {
    // Proves: the hub identifies itself with the localized title regardless of
    // state — a baseline that fails if the title key is swapped/removed.
    fakeVm.setState(tags: const [], isLoading: false);
    await pumpView(tester);

    expect(find.text('Egna taggar'), findsOneWidget);
  });

  testWidgets('empty state shows the localized empty title and create CTA', (
    tester,
  ) async {
    // Proves: with no tags the user sees the empty-state guidance, not a blank
    // screen or an error — the !hasTags branch.
    fakeVm.setState(tags: const [], isLoading: false);
    await pumpView(tester);

    expect(find.text('Inga egna taggar'), findsOneWidget);
    expect(
      find.text('Skapa taggar för att organisera dina recept'),
      findsOneWidget,
    );
  });

  testWidgets('error state shows the VM error message with a retry action', (
    tester,
  ) async {
    // Proves: when the VM reports hasError the error message surfaces with a
    // retry CTA (StateWidget.error wired to viewModel.initialize).
    fakeVm.setState(tags: const [], isLoading: false, error: 'Något gick fel');
    await pumpView(tester);

    expect(find.text('Något gick fel'), findsOneWidget);
    expect(find.text('Försök igen'), findsOneWidget); // commonRetry
  });

  testWidgets('loading state (no tags yet) shows the loading widget, not empty', (
    tester,
  ) async {
    // Proves: the isLoading && !hasTags branch renders the branded loading
    // state — the empty/error copy must NOT appear while first load is pending.
    fakeVm.setState(tags: const [], isLoading: true);
    await pumpView(tester);

    expect(find.byType(StateWidget), findsOneWidget);
    expect(find.text('Inga egna taggar'), findsNothing);
    expect(find.text('Något gick fel'), findsNothing);
  });

  testWidgets(
    'with tags the list renders the tag and the Tags section header',
    (tester) async {
      // Proves: the happy path — a tag the user created appears under the
      // "Taggar" section header, not the empty state.
      final tag = PersonalTag.create(name: 'Vegetariskt');
      fakeVm.setState(
        tags: [tag],
        groups: const <PersonalTagGroup>[],
        isLoading: false,
        usageCounts: {'Vegetariskt': 4},
      );
      await pumpView(tester);

      // The section overline is upper-cased by ButleryListSection.
      expect(find.text('TAGGAR'), findsOneWidget); // personalTagSectionTags
      expect(find.text('Vegetariskt'), findsWidgets);
      expect(find.text('Inga egna taggar'), findsNothing);
    },
  );

  // Negative control: proves the empty and list branches are genuinely
  // distinguished by hasTags. A list render must NOT also surface the
  // empty-state guidance copy — otherwise the empty-state positive test above
  // would be meaningless.
  testWidgets('tag-list state does not render the empty-state guidance copy', (
    tester,
  ) async {
    final tag = PersonalTag.create(name: 'Snabbt');
    fakeVm.setState(
      tags: [tag],
      isLoading: false,
      usageCounts: {'Snabbt': 1},
    );
    await pumpView(tester);

    expect(find.text('Inga egna taggar'), findsNothing);
    expect(
      find.text('Skapa taggar för att organisera dina recept'),
      findsNothing,
    );
    expect(find.text('Snabbt'), findsWidgets);
  });

  // P5-U31: "Välj" in the view's own bar from two tags (B-46;
  // produktregler.md:870-876); the bar keeps its height in selection mode.
  group('Välj (P5-U31)', () {
    final enter = find.byKey(const ValueKey('personal-tags-select-enter'));

    testWidgets('one tag shows no Välj', (tester) async {
      fakeVm.setState(
        tags: [PersonalTag.create(name: 'Snabbt')],
        isLoading: false,
      );
      await pumpView(tester);

      expect(enter, findsNothing);
    });

    testWidgets('two tags show Välj; it opens selection at zero with the '
        'counter, Avbryt and the same bar height', (tester) async {
      fakeVm.setState(
        tags: [
          PersonalTag.create(name: 'Snabbt'),
          PersonalTag.create(name: 'Vardag'),
        ],
        isLoading: false,
      );
      await pumpView(tester);
      final bar = find.byType(ButleryTopBar);
      final before = tester.getSize(bar).height;
      expect(find.bySemanticsLabel('Välj taggar'), findsOneWidget);

      await tester.tap(enter);
      await tester.pump();

      expect(find.text('0 valda'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('personal-tags-selection-cancel')),
        findsOneWidget,
      );
      expect(tester.getSize(bar).height, before);
      final delete = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, ButleryIcons.trash2),
      );
      expect(delete.onPressed, isNull);
    });
  });

  group('Mer, omtänkt', () {
    testWidgets('the bar names the row that opens it, and Back is named '
        'after where the caller says it leads', (tester) async {
      fakeVm.setState(tags: [PersonalTag.create(name: 'Snabbt')]);
      await pumpView(tester, backTo: 'Mer');

      final bar = tester.widget<ButleryTopBar>(find.byType(ButleryTopBar));
      expect(bar.title, 'Egna taggar');
      expect(bar.backTo, 'Mer');
    });

    testWidgets('opened from elsewhere, Back names no destination', (
      tester,
    ) async {
      fakeVm.setState(tags: [PersonalTag.create(name: 'Snabbt')]);
      await pumpView(tester);

      final bar = tester.widget<ButleryTopBar>(find.byType(ButleryTopBar));
      expect(bar.backTo, isNull);
    });

    testWidgets('groups, ungrouped and unused tags are separate sections, '
        'and the unused one ends with the danger row', (tester) async {
      final group = PersonalTagGroup.create(name: 'Kvällsmat');
      fakeVm.setState(
        tags: [
          PersonalTag.create(name: 'Pasta').copyWith(groupId: group.id),
          PersonalTag.create(name: 'Fika'),
          PersonalTag.create(name: 'Glömd'),
        ],
        groups: [group],
        usageCounts: {'Pasta': 34, 'Fika': 2},
      );
      await pumpView(tester);

      expect(find.text('KVÄLLSMAT'), findsOneWidget);
      expect(find.text('UTAN GRUPP'), findsOneWidget);
      expect(find.text('OANVÄNDA · 1'), findsOneWidget);
      expect(find.text('34 recept'), findsOneWidget);
      expect(find.text('Radera oanvända taggar'), findsOneWidget);
      // An unused tag is listed once, in its own section.
      expect(find.text('Glömd'), findsOneWidget);
    });

    testWidgets('the plus in the bar opens a Skapa sheet with both rows', (
      tester,
    ) async {
      fakeVm.setState(tags: [PersonalTag.create(name: 'Snabbt')]);
      await pumpView(tester);

      await tester.tap(find.byKey(const ValueKey('personal-tags-create')));
      await tester.pumpAndSettle();

      expect(find.text('Ny tagg'), findsOneWidget);
      expect(find.text('Ny grupp'), findsOneWidget);

      await tester.tap(find.text('Ny grupp'));
      await tester.pumpAndSettle();
      expect(find.text('Skapa grupp'), findsOneWidget); // the existing dialog
    });

    testWidgets('a group ends with a row whose sheet renames or deletes it', (
      tester,
    ) async {
      final group = PersonalTagGroup.create(name: 'Kvällsmat');
      fakeVm.setState(
        tags: [PersonalTag.create(name: 'Pasta').copyWith(groupId: group.id)],
        groups: [group],
        usageCounts: {'Pasta': 3},
      );
      await pumpView(tester);

      await tester.tap(find.text('Hantera gruppen'));
      await tester.pumpAndSettle();

      expect(find.text('Byt namn'), findsOneWidget);
      expect(find.text('Radera gruppen'), findsOneWidget);

      await tester.tap(find.text('Radera gruppen'));
      await tester.pumpAndSettle();
      expect(find.text('Radera gruppen?'), findsOneWidget);
      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hantera gruppen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Byt namn'));
      await tester.pumpAndSettle();
      expect(find.text('Byt namn på grupp'), findsOneWidget);
    });

    testWidgets('Radera oanvända taggar asks first and deletes on confirm', (
      tester,
    ) async {
      fakeVm.setState(
        tags: [
          PersonalTag.create(name: 'Fika'),
          PersonalTag.create(name: 'Glömd'),
        ],
        usageCounts: {'Fika': 2},
      );
      await pumpView(tester);

      await tester.tap(find.text('Radera oanvända taggar'));
      await tester.pumpAndSettle();
      expect(find.text('Radera oanvända taggar?'), findsOneWidget);
      expect(fakeVm.deleteUnusedCalls, 0);

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();
      expect(fakeVm.deleteUnusedCalls, 0);

      await tester.tap(find.text('Radera oanvända taggar'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text('Radera oanvända taggar'),
          matching: find.bySubtype<FilledButton>(),
        ),
      );
      await tester.pumpAndSettle();
      expect(fakeVm.deleteUnusedCalls, 1);
    });

    testWidgets('a tap on a tag opens that tag\'s page', (tester) async {
      final tag = PersonalTag.create(name: 'Snabbt');
      fakeVm.setState(tags: [tag], usageCounts: {'Snabbt': 1});
      await pumpView(tester);

      await tester.tap(find.widgetWithText(ButleryListRow, 'Snabbt'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TagDetailView>(find.byType(TagDetailView)).tagId,
        tag.id,
      );
    });

    testWidgets('long press on a tag still enters selection', (tester) async {
      fakeVm.setState(
        tags: [
          PersonalTag.create(name: 'Snabbt'),
          PersonalTag.create(name: 'Vardag'),
        ],
        usageCounts: {'Snabbt': 1, 'Vardag': 1},
      );
      await pumpView(tester);

      await tester.longPress(find.widgetWithText(ButleryListRow, 'Snabbt'));
      await tester.pump();

      expect(find.text('1 valda'), findsOneWidget);
    });

    testWidgets('the sort button opens a choice sheet', (tester) async {
      fakeVm.setState(tags: [PersonalTag.create(name: 'Snabbt')]);
      await pumpView(tester);

      await tester.tap(find.byTooltip('Sortera'));
      await tester.pumpAndSettle();

      expect(find.text('Namn'), findsWidgets);
    });

    testWidgets('picking Namn in the sort sheet orders the tags by name', (
      tester,
    ) async {
      fakeVm.setState(
        tags: [
          PersonalTag.create(name: 'Apelsin'),
          PersonalTag.create(name: 'Zucchini'),
        ],
        usageCounts: {'Apelsin': 1, 'Zucchini': 5},
      );
      await pumpView(tester);
      double y(String name) => tester.getTopLeft(find.text(name)).dy;
      // The default order is by use, so the more used tag comes first.
      expect(y('Zucchini'), lessThan(y('Apelsin')));

      await tester.tap(find.byTooltip('Sortera'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Namn').last);
      await tester.pumpAndSettle();

      expect(y('Apelsin'), lessThan(y('Zucchini')));
    });
  });
}

class _RecordingTagVm extends FakePersonalTagViewModel {
  int deleteUnusedCalls = 0;

  @override
  Future<int> deleteUnusedTags() async {
    deleteUnusedCalls++;
    return unusedTags.length;
  }
}
