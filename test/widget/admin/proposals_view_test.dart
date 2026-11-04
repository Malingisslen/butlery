import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/models/tagging/ingredient_column.dart';
import 'package:butlery/repositories/interfaces/ingredient_change_request_repository.dart';
import 'package:butlery/services/tagging/ingredient_change_pr_service.dart';
import 'package:butlery/viewmodels/admin/pending_proposals_viewmodel.dart';
import 'package:butlery/views/admin/proposals_view.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';
import '../../test_support/ingredient_review_fixtures.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  Future<FakeChangeRequestRepository> pump(
    WidgetTester tester, {
    IngredientChangePrService? prService,
  }) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeChangeRequestRepository();
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: ProposalsView(
          viewModel: PendingProposalsViewModel(
            repository: repo,
            prService: prService,
          ),
        ),
      ),
    );
    await tester.pump();
    return repo;
  }

  IngredientChangeRequest proposal({
    String id = 'r1',
    IngredientChangeStatus status = IngredientChangeStatus.pending,
    int? prNumber,
    String? reason,
    Map<String, Object?>? csvValue,
    List<String> oldProps = const ['dairy'],
    List<String> newProps = const ['dairy'],
  }) => IngredientChangeRequest(
    id: id,
    status: status,
    prNumber: prNumber,
    reason: reason,
    csvValue: csvValue,
    ingredientId: 'milk',
    note: 'rätta',
    createdAt: DateTime.utc(2026, 11, 1),
    changes: [
      IngredientFieldChange(
        column: IngredientColumn.status,
        oldValue: 'draft',
        newValue: 'verified',
      ),
      IngredientFieldChange(
        column: IngredientColumn.properties,
        oldValue: oldProps,
        newValue: newProps,
      ),
    ],
  );

  testWidgets('shows loading, then the empty state', (tester) async {
    final repo = await pump(tester);
    expect(find.textContaining('Laddar'), findsOneWidget);
    repo.pending.add([]);
    await tester.pumpAndSettle();
    expect(find.text('Inga väntande förslag'), findsOneWidget);
  });

  testWidgets('a stream error is an error state with retry, not empty', (
    tester,
  ) async {
    final repo = await pump(tester);
    repo.pending.addError(StateError('denied'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kunde inte ladda förslagen'), findsOneWidget);
    expect(find.text('Inga väntande förslag'), findsNothing);
  });

  testWidgets('shows old to new per field, note and no allergen mark', (
    tester,
  ) async {
    final repo = await pump(tester);
    repo.pending.add([proposal()]);
    await tester.pumpAndSettle();

    expect(find.text('Status: draft → verified'), findsOneWidget);
    expect(find.text('rätta'), findsOneWidget);
    expect(find.textContaining('Föreslaget 2026-11-01'), findsOneWidget);
    expect(find.byKey(const ValueKey('allergen-mark')), findsNothing);
  });

  testWidgets('a removed allergen property carries the allergen mark', (
    tester,
  ) async {
    final repo = await pump(tester);
    repo.pending.add([proposal(newProps: const [])]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('allergen-mark')), findsOneWidget);
  });

  testWidgets('withdraw calls the repository', (tester) async {
    final repo = await pump(tester);
    repo.pending.add([proposal()]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('withdraw')));
    await tester.pumpAndSettle();
    expect(repo.withdrawn, ['r1']);
  });

  testWidgets('a full page says more proposals are waiting', (tester) async {
    final repo = await pump(tester);
    repo.pending.add([proposal()]);
    await tester.pump();
    expect(find.byKey(const ValueKey('proposals-more-waiting')), findsNothing);

    repo.pending.add([
      for (var i = 0; i < IngredientChangeRequestRepository.maxPending; i++)
        proposal(id: 'r$i'),
    ]);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('proposals-more-waiting')),
      findsOneWidget,
    );
  });

  group('sections and review', () {
    testWidgets('each status lands in its own section', (tester) async {
      final repo = await pump(tester);
      repo.pending.add([
        proposal(id: 'p'),
        proposal(
          id: 'i',
          status: IngredientChangeStatus.inReview,
          prNumber: 42,
        ),
        proposal(
          id: 'c',
          status: IngredientChangeStatus.conflict,
          reason: 'csv-mismatch',
          csvValue: {'status': 'review'},
        ),
      ]);
      repo.decided.add([
        proposal(
          id: 'r',
          status: IngredientChangeStatus.rejected,
          reason: 'no-change',
        ),
        proposal(id: 'a', status: IngredientChangeStatus.applied),
      ]);
      await tester.pumpAndSettle();

      for (final title in [
        'Väntar',
        'I granskning',
        'Konflikt',
        'Avvisade',
        'Nyligen genomförda',
      ]) {
        expect(find.byKey(ValueKey('section-$title')), findsOneWidget);
      }
      expect(find.text('Granskning #42'), findsOneWidget);
      expect(find.byKey(const ValueKey('open-github')), findsOneWidget);
      expect(find.text('Värde i filen: review'), findsOneWidget);
      expect(find.text('Ditt gamla: draft'), findsOneWidget);
      expect(find.text('Ditt nya: verified'), findsOneWidget);
      expect(
        find.textContaining('Filen har redan det värdet'),
        findsOneWidget,
      );
      // Pending, in review and conflict can be withdrawn; decided cannot.
      expect(find.byKey(const ValueKey('withdraw')), findsNWidgets(3));
    });

    testWidgets('the button is disabled with nothing waiting', (tester) async {
      final repo = await pump(tester);
      repo.pending.add([
        proposal(id: 'c', status: IngredientChangeStatus.conflict),
      ]);
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('create-review'));
      expect(button, findsOneWidget);
      await tester.tap(button, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Skapa granskning?'), findsNothing);
    });

    testWidgets('confirm states the count, then shows the summary', (
      tester,
    ) async {
      final pr = _MockPrService();
      when(pr.createPr).thenAnswer(
        (_) async => const IngredientChangePrResult(
          prNumber: 9,
          prUrl: 'https://github.com/Malingisslen/butlery/pull/9',
          applied: 2,
          conflicts: 1,
          rejected: 0,
          reopened: 0,
          skipped: 0,
        ),
      );
      final repo = await pump(tester, prService: pr);
      repo.pending.add([
        proposal(id: 'p1'),
        proposal(id: 'p2'),
        proposal(id: 'i', status: IngredientChangeStatus.inReview),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('create-review')));
      await tester.pumpAndSettle();
      expect(find.text('Skapa granskning?'), findsOneWidget);
      expect(find.textContaining('3 förslag'), findsOneWidget);
      verifyNever(pr.createPr);

      await tester.tap(find.text('Skapa granskning').last);
      await tester.pumpAndSettle();
      verify(pr.createPr).called(1);
      expect(
        find.text('Granskning skapad: 2 ändringar, 1 konflikt'),
        findsOneWidget,
      );
      expect(find.text('Granskning #9'), findsOneWidget);
    });

    test('only https github.com links may be opened', () {
      expect(isTrustedGithubUrl('https://github.com/a/b/pull/1'), isTrue);
      expect(isTrustedGithubUrl('http://github.com/a/b/pull/1'), isFalse);
      expect(isTrustedGithubUrl('https://evil.example/pull/1'), isFalse);
      expect(isTrustedGithubUrl('https://github.com.evil.example/x'), isFalse);
      expect(isTrustedGithubUrl('javascript:alert(1)'), isFalse);
      expect(isTrustedGithubUrl(''), isFalse);
    });

    Future<List<String>> launchFrom(
      WidgetTester tester,
      String prUrl,
    ) async {
      final launcher = _RecordingUrlLauncher();
      final original = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = original);
      final pr = _MockPrService();
      when(pr.createPr).thenAnswer(
        (_) async => IngredientChangePrResult(
          prNumber: 9,
          prUrl: prUrl,
          applied: 1,
          conflicts: 0,
          rejected: 0,
          reopened: 0,
          skipped: 0,
        ),
      );
      final repo = await pump(tester, prService: pr);
      repo.pending.add([proposal()]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skapa granskning').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Granskning skapad: 1 ändring, 0 konflikter'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('open-github')));
      await tester.pumpAndSettle();
      return launcher.launched;
    }

    testWidgets('an untrusted result url opens the numbered link instead', (
      tester,
    ) async {
      final launched = await launchFrom(tester, 'javascript:alert(1)');
      expect(launched, ['${kButleryPullRequestBase}9']);
      expect(launched.any((u) => u.startsWith('javascript:')), isFalse);
    });

    testWidgets('a trusted result url is opened as given', (tester) async {
      const url = 'https://github.com/Malingisslen/butlery/pull/9';
      expect(await launchFrom(tester, url), [url]);
    });

    testWidgets('cancelling the confirmation creates nothing', (tester) async {
      final pr = _MockPrService();
      final repo = await pump(tester, prService: pr);
      repo.pending.add([proposal()]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create-review')));
      await tester.pumpAndSettle();
      expect(find.text('Skapa granskning?'), findsOneWidget);

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();
      expect(find.text('Skapa granskning?'), findsNothing);
      verifyNever(pr.createPr);
      expect(find.byKey(const ValueKey('review-created')), findsNothing);
      expect(find.byKey(const ValueKey('review-error')), findsNothing);
    });

    testWidgets('cards sit inside their own section', (tester) async {
      final repo = await pump(tester);
      repo.pending.add([
        proposal(id: 'p'),
        proposal(id: 'c', status: IngredientChangeStatus.conflict),
      ]);
      await tester.pumpAndSettle();
      Finder card(String section, String id) => find.descendant(
        of: find.byKey(ValueKey('section-$section')),
        matching: find.byKey(ValueKey(id)),
      );
      expect(card('Väntar', 'p'), findsOneWidget);
      expect(card('Väntar', 'c'), findsNothing);
      expect(card('Konflikt', 'c'), findsOneWidget);
      expect(card('Konflikt', 'p'), findsNothing);
    });

    testWidgets('a refusal shows its Swedish message', (tester) async {
      final pr = _MockPrService();
      when(pr.createPr).thenThrow(
        const IngredientChangePrException(IngredientChangePrFailure.locked),
      );
      final repo = await pump(tester, prService: pr);
      repo.pending.add([proposal()]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skapa granskning').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('review-error')), findsOneWidget);
      expect(find.textContaining('skapas just nu'), findsOneWidget);
    });
  });
}

class _MockPrService extends Mock implements IngredientChangePrService {}

class _RecordingUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}
