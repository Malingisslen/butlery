// BUT-1275: widget gates for the multi-URL ("batch") path of ImportViaUrlView
// (BUT-947). A user can paste a list of recipe URLs; the view then renders one
// progress row per URL, a per-row retry on failures, and a "Importera N recept"
// CTA whose count reflects only the URLs that succeeded. These tests pin that
// user-visible contract against a fake ViewModel:
//   - one result row per urlResults entry, each showing the URL text;
//   - the per-row status icon distinguishes success / failure / loading;
//   - the retry button appears only on failed rows and calls retryUrl(index);
//   - the partial-success CTA shows successfulUrlCount, not the total;
//   - the CTA is absent until at least one URL succeeds.
//
// Asserts behaviour (row count, retry wiring, CTA count), not pixel layout, so
// it needs no human visual sign-off.

library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/url_import_viewmodel.dart';
import 'package:butlery/views/import_via_url_view.dart';

/// Self-contained ChangeNotifier fake exposing only the surface the view reads
/// for the multi-URL path, plus a retry recorder. The real VM drives a
/// WebScraper + AutoSaveManager; here we hand the view a fixed batch result so
/// the render + wiring are deterministic and platform-free.
class _FakeUrlImportViewModel extends ChangeNotifier
    implements UrlImportViewModel {
  _FakeUrlImportViewModel({
    required List<UrlImportResult> results,
    String batchText = '',
    bool isMultiUrl = true,
    String extractedText = '',
  })  : _results = results,
        _batchText = batchText,
        _isMultiUrl = isMultiUrl,
        _extractedText = extractedText;

  final List<UrlImportResult> _results;
  final String _batchText;
  final bool _isMultiUrl;
  final String _extractedText;

  bool loading = false;
  @override
  bool get isLoading => loading;

  int? retriedIndex;

  @override
  List<UrlImportResult> get urlResults => List.unmodifiable(_results);

  @override
  bool get hasAnyUrlSuccess => _results.any((r) => r.isSuccess);

  @override
  int get successfulUrlCount => _results.where((r) => r.isSuccess).length;

  @override
  bool get isMultiUrl => _isMultiUrl;

  @override
  Future<void> retryUrl(int index) async {
    retriedIndex = index;
  }

  // ---- inert surface the view's build() also reads ----
  @override
  bool get hasError => false;
  @override
  String? get error => null;
  @override
  bool get canFetch => true;
  @override
  bool get hasExtractedText => _extractedText.isNotEmpty;
  @override
  String get extractedText => _extractedText;
  @override
  String get sourceUrl => '';
  @override
  void updateUrl(String url) {}
  @override
  Future<void> fetchFromUrl() async {}
  @override
  Future<void> fetchMultipleUrls() async {}
  @override
  String get successfulBatchText => _batchText;

  // BUT-1273: the view's build reads these on the single-URL path; default to
  // "not an index page" so existing batch/single tests are unaffected.
  bool indexCandidate = false;
  @override
  bool get isIndexPageCandidate => indexCandidate;
  @override
  List<String> get indexPageLinks => _indexLinks;
  List<String> _indexLinks = const [];
  int expandCalls = 0;
  @override
  Future<void> expandIndexPage() async {
    expandCalls++;
  }

  // Spy on the probe so a test can prove _fetchPage only probes on a fetch miss.
  int detectCalls = 0;
  @override
  Future<void> detectIndexPage() async {
    detectCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records every route pushed past the home route so a test can assert the
/// batch CTA actually navigates (and with which arguments), not merely that it
/// renders the right label.
class _RouteRecorder extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}

Widget _wrap(Widget child, {List<NavigatorObserver> observers = const []}) =>
    MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      navigatorObservers: observers,
      // The batch CTA pushes '/franSocialaMedier'; give it a stub destination so
      // the push resolves instead of throwing "no route" mid-test.
      routes: {
        '/franSocialaMedier': (_) => const Scaffold(body: Text('paste-stub')),
      },
      home: child,
    );

void main() {
  late _FakeUrlImportViewModel fakeVm;

  void registerFake(_FakeUrlImportViewModel vm) {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<UrlImportViewModel>()) {
      getIt.unregister<UrlImportViewModel>();
    }
    getIt.registerFactory<UrlImportViewModel>(() => vm);
    app_provider.ServiceLocator.reset();
    app_provider.ServiceLocator.initialize(DIContainer());
  }

  setUp(() {
    // Empty prefs so the view's AutoSaveManager.load resolves (no draft).
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    app_provider.ServiceLocator.reset();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<UrlImportViewModel>()) {
      getIt.unregister<UrlImportViewModel>();
    }
  });

  Future<void> pumpView(
    WidgetTester tester, {
    bool settle = true,
    List<NavigatorObserver> observers = const [],
  }) async {
    await tester.pumpWidget(
      _wrap(const ImportViaUrlView(), observers: observers),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // A loading row holds an indefinitely-animating spinner, so pumpAndSettle
      // would never converge — two bounded pumps run the post-frame draft check
      // and flush the first build.
      await tester.pump();
      await tester.pump();
    }
  }

  const okUrl = 'https://ica.se/recept/ett';
  const failUrl = 'https://example.com/trasig';
  const loadingUrl = 'https://koket.se/laddar';

  testWidgets('renders one progress row per URL in the batch', (tester) async {
    fakeVm = _FakeUrlImportViewModel(results: const [
      UrlImportResult(url: okUrl, status: UrlFetchStatus.success),
      UrlImportResult(url: failUrl, status: UrlFetchStatus.failure),
    ]);
    registerFake(fakeVm);
    await pumpView(tester);

    // Each pasted URL gets its own row showing the URL string.
    expect(find.text(okUrl), findsOneWidget);
    expect(find.text(failUrl), findsOneWidget);
  });

  testWidgets('a failed row shows the retry button; a successful row does not',
      (tester) async {
    fakeVm = _FakeUrlImportViewModel(results: const [
      UrlImportResult(url: okUrl, status: UrlFetchStatus.success),
      UrlImportResult(url: failUrl, status: UrlFetchStatus.failure),
    ]);
    registerFake(fakeVm);
    await pumpView(tester);

    // One failure ⇒ exactly one "Försök igen" retry affordance.
    expect(find.text('Försök igen'), findsOneWidget);
  });

  testWidgets('tapping retry calls retryUrl with the failed row index',
      (tester) async {
    fakeVm = _FakeUrlImportViewModel(results: const [
      UrlImportResult(url: okUrl, status: UrlFetchStatus.success),
      UrlImportResult(url: failUrl, status: UrlFetchStatus.failure),
    ]);
    registerFake(fakeVm);
    await pumpView(tester);

    // The failure is row index 1; its retry must target exactly that row.
    await tester.tap(find.text('Försök igen'));
    await tester.pump();

    expect(fakeVm.retriedIndex, 1);
  });

  testWidgets('per-row status icons distinguish success / failure / loading',
      (tester) async {
    fakeVm = _FakeUrlImportViewModel(results: const [
      UrlImportResult(url: okUrl, status: UrlFetchStatus.success),
      UrlImportResult(url: failUrl, status: UrlFetchStatus.failure),
      UrlImportResult(url: loadingUrl, status: UrlFetchStatus.loading),
    ]);
    registerFake(fakeVm);
    await pumpView(tester, settle: false);

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);
    // A loading row shows a spinner instead of an icon.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('the import CTA counts only the URLs that succeeded',
      (tester) async {
    fakeVm = _FakeUrlImportViewModel(results: const [
      UrlImportResult(url: okUrl, status: UrlFetchStatus.success),
      UrlImportResult(
          url: 'https://arla.se/recept/tva', status: UrlFetchStatus.success),
      UrlImportResult(url: failUrl, status: UrlFetchStatus.failure),
    ]);
    registerFake(fakeVm);
    await pumpView(tester);

    // 2 of 3 succeeded → "Importera 2 recept", never the total of 3.
    expect(find.text('Importera 2 recept'), findsOneWidget);
    expect(find.text('Importera 3 recept'), findsNothing);
  });

  testWidgets('no import CTA until at least one URL succeeds', (tester) async {
    fakeVm = _FakeUrlImportViewModel(results: const [
      UrlImportResult(url: failUrl, status: UrlFetchStatus.failure),
      UrlImportResult(
          url: 'https://example.com/ocksa-trasig',
          status: UrlFetchStatus.failure),
    ]);
    registerFake(fakeVm);
    await pumpView(tester);

    // All failed ⇒ the partial-success CTA is absent (nothing to import).
    expect(find.textContaining('Importera'), findsNothing);
  });

  // Gap (BUT-1275 review): the original suite proved the CTA's *label* count but
  // never that the CTA actually *does* anything. A user who taps "Importera N
  // recept" must reach the paste step carrying the combined batch text; if the
  // wiring (or successfulBatchText) silently produced nothing, the label would
  // still read correctly while the button did nothing. This pins the dispatch.
  testWidgets('tapping the batch CTA navigates to paste with the combined text',
      (tester) async {
    final recorder = _RouteRecorder();
    fakeVm = _FakeUrlImportViewModel(
      results: const [
        UrlImportResult(url: okUrl, status: UrlFetchStatus.success),
        UrlImportResult(
            url: 'https://arla.se/recept/tva', status: UrlFetchStatus.success),
      ],
      batchText: 'RECEPT ETT\n\nRECEPT TVA',
    );
    registerFake(fakeVm);
    await pumpView(tester, observers: [recorder]);

    await tester.tap(find.text('Importera 2 recept'));
    await tester.pumpAndSettle();

    final pushedSettings =
        recorder.pushed.map((r) => r.settings).toList(growable: false);
    final batchRoute = pushedSettings
        .where((s) => s.name == '/franSocialaMedier')
        .toList(growable: false);
    expect(batchRoute, hasLength(1),
        reason: 'the CTA must push the paste route exactly once');
    expect(
      (batchRoute.single.arguments as Map)['text'],
      'RECEPT ETT\n\nRECEPT TVA',
      reason: 'the combined batch text must reach the paste step verbatim',
    );
  });

  // Gap (BUT-1275 review): the "{success} av {total} hämtade" progress summary
  // is the user's at-a-glance partial-success readout and is a separate
  // aggregation from the CTA count (it shows the TOTAL, the CTA shows only the
  // successes). A regression collapsing the two would be invisible to the
  // existing CTA-only assertions.
  testWidgets(
      'the batch summary shows successes over total, not just successes',
      (tester) async {
    fakeVm = _FakeUrlImportViewModel(results: const [
      UrlImportResult(url: okUrl, status: UrlFetchStatus.success),
      UrlImportResult(
          url: 'https://arla.se/recept/tva', status: UrlFetchStatus.success),
      UrlImportResult(url: failUrl, status: UrlFetchStatus.failure),
    ]);
    registerFake(fakeVm);
    await pumpView(tester);

    // 2 succeeded out of 3 pasted → "2 av 3 hämtade" (Swedish copy).
    expect(find.text('2 av 3 hämtade'), findsOneWidget);
  });

  // Gap (BUT-1293): every test above exercises the multi-URL batch path. None
  // proved the *legacy* single-URL path is untouched by BUT-947 — that a single
  // pasted URL still renders the editable-extracted-text editor and "Gå vidare
  // till klistra-in" CTA, and crucially does NOT render the per-URL progress row
  // list or the "Importera N recept" batch CTA. The view branches the batch UI on
  // `urlResults.isNotEmpty` and the editor on `urlResults.isEmpty &&
  // hasExtractedText`; this pins that a single-URL VM (isMultiUrl == false, no
  // urlResults, with extracted text) stays on the legacy branch.
  testWidgets(
      'single-URL input renders the legacy editor, not the multi-URL row list',
      (tester) async {
    fakeVm = _FakeUrlImportViewModel(
      results: const [],
      isMultiUrl: false,
      extractedText: 'Pannkakor\n\n3 ägg\n5 dl mjölk',
    );
    registerFake(fakeVm);
    await pumpView(tester);

    // Legacy single-URL UI is present: the extracted-text header and the
    // "proceed to paste" CTA only render on the `urlResults.isEmpty &&
    // hasExtractedText` branch, so their presence proves we're on the legacy
    // editor path. (The editor seeds its text via a notifyListeners-driven
    // listener, not on first build, so we assert the branch markers rather than
    // the controller contents — which would be a flaky implementation detail.)
    expect(find.text('Extraherad text:'), findsOneWidget);
    expect(find.text('Gå vidare till klistra-in'), findsOneWidget);

    // The multi-URL batch surface is entirely absent: no per-URL progress row
    // (no URL text, no status icons, no retry), no "{n} av {m} hämtade" summary,
    // and no "Importera N recept" batch CTA.
    expect(find.text(okUrl), findsNothing);
    expect(find.text('Försök igen'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.textContaining('hämtade'), findsNothing);
    expect(find.textContaining('Importera'), findsNothing);
  });

  // BUT-1273: the opt-in recipe-index banner. Intent: when a single-URL fetch
  // detected a listing page, the view offers an "import all N" action and tapping
  // it delegates to expandIndexPage — nothing fans out without the user's tap.
  testWidgets('shows the index-page banner and expands on tap', (tester) async {
    fakeVm = _FakeUrlImportViewModel(results: const [])
      ..indexCandidate = true
      .._indexLinks = const [
        'https://ica.se/recept/ett-med-namn',
        'https://ica.se/recept/tva-med-namn',
        'https://ica.se/recept/tre-med-namn',
      ];
    registerFake(fakeVm);
    await pumpView(tester);

    // Banner + count-bearing CTA are present (count reflects harvested links).
    expect(find.text('Det här ser ut som en receptsamling.'), findsOneWidget);
    final cta = find.text('Importera alla 3 recept');
    expect(cta, findsOneWidget);

    await tester.tap(cta);
    await tester.pump();

    expect(fakeVm.expandCalls, 1,
        reason: 'tapping the banner CTA must delegate to expandIndexPage');
  });

  testWidgets('no index banner when the page is not a listing', (tester) async {
    fakeVm = _FakeUrlImportViewModel(
      results: const [],
      extractedText: 'a single extracted recipe body',
    )..indexCandidate = false;
    registerFake(fakeVm);
    await pumpView(tester);

    expect(find.text('Det här ser ut som en receptsamling.'), findsNothing);
  });

  // BUT-1273 cost guard: a single URL that already yielded a recipe must NOT
  // trigger the index probe (no spurious second network round-trip / banner).
  testWidgets('successful single fetch does not probe for an index page',
      (tester) async {
    fakeVm = _FakeUrlImportViewModel(
      results: const [],
      isMultiUrl: false,
      extractedText: 'a recipe body that means the fetch hit',
    );
    registerFake(fakeVm);
    await pumpView(tester);

    await tester.tap(find.text('Hämta text'));
    await tester.pumpAndSettle();

    expect(fakeVm.detectCalls, 0,
        reason: 'fetch hit ⇒ no index probe (the !hasExtractedText guard)');
  });

  testWidgets('a single fetch that yields no recipe probes for an index page',
      (tester) async {
    fakeVm = _FakeUrlImportViewModel(
      results: const [],
      isMultiUrl: false,
      extractedText: '', // miss → hasExtractedText false → probe
    );
    registerFake(fakeVm);
    await pumpView(tester);

    await tester.tap(find.text('Hämta text'));
    await tester.pumpAndSettle();

    expect(fakeVm.detectCalls, 1,
        reason: 'fetch miss ⇒ probe once for a listing page');
  });

  testWidgets('index CTA is disabled while loading (no double-expand)',
      (tester) async {
    fakeVm = _FakeUrlImportViewModel(results: const [])
      ..indexCandidate = true
      ..loading = true
      .._indexLinks = const ['https://ica.se/recept/ett-med-namn'];
    registerFake(fakeVm);
    // Loading holds an animating spinner, so use bounded pumps not settle.
    await pumpView(tester, settle: false);

    await tester.tap(find.text('Importera alla 1 recept'));
    await tester.pump();

    expect(fakeVm.expandCalls, 0,
        reason: 'a loading CTA is onPressed:null — taps must not expand');
  });
}
