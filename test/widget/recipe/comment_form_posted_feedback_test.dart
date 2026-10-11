/// BUT-2363: after a successful post the comment form must not claim
/// "posted" while offline (the write is only queued), and screen-reader users
/// must hear the outcome. The announcement is captured on the real
/// `flutter/accessibility` channel.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/recipe/comment_form_widget.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/announce_channel.dart';
import '../../test_support/base_unit_test.dart';

class _FakeSocialRecipeViewModel extends Mock
    implements SocialRecipeViewModel {}

class _OfflineStub extends ChangeNotifier implements OfflineService {
  @override
  bool get isOnline => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeSocialRecipeViewModel vm;
  late List<(String, bool)> shown;
  final sv = AppLocalizationsSv();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());

    shown = [];
    vm = _FakeSocialRecipeViewModel();
    when(() => vm.isReplying).thenReturn(false);
    when(() => vm.isPostingComment).thenReturn(false);
    when(() => vm.newCommentText).thenReturn('Gott!');
    when(() => vm.currentUser).thenReturn(null);
    when(() => vm.updateNewCommentText(any())).thenReturn(null);
  });

  tearDown(() async {
    TestServiceLocator.unregister<OfflineService>();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<AnnounceChannel> postComment(
    WidgetTester tester, {
    String? text,
  }) async {
    final announces = AnnounceChannel.arm(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: Scaffold(
          body: CommentFormWidget(
            socialViewModel: vm,
            recipeId: 'r1',
            onShowMessage: (message, {bool isError = false}) =>
                shown.add((message, isError)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (text != null) {
      await tester.enterText(find.byType(TextField), text);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byIcon(ButleryIcons.send));
    await tester.pumpAndSettle();
    return announces;
  }

  testWidgets('online: shows and announces that the comment was posted', (
    tester,
  ) async {
    when(
      () => vm.postComment('r1', imageUrls: any(named: 'imageUrls')),
    ).thenAnswer((_) async {});

    final announces = await postComment(tester);

    expect(shown, [(sv.commentPosted, false)]);
    expect(announces.messages, [sv.a11yCommentPosted]);
  });

  testWidgets('offline: shows and announces the queued state, not "posted"', (
    tester,
  ) async {
    TestServiceLocator.registerMock<OfflineService>(_OfflineStub());
    when(
      () => vm.postComment('r1', imageUrls: any(named: 'imageUrls')),
    ).thenAnswer((_) async {});

    final announces = await postComment(tester);

    expect(shown, [(sv.pendingSyncOffline, false)]);
    expect(announces.messages, [sv.pendingSyncOffline]);
  });

  testWidgets('failed post: error message only, nothing announced', (
    tester,
  ) async {
    when(
      () => vm.postComment('r1', imageUrls: any(named: 'imageUrls')),
    ).thenThrow(Exception('network down'));

    final announces = await postComment(tester);

    expect(shown, [(sv.commentCouldNotPost, true)]);
    expect(announces.count, 0);
  });

  testWidgets(
    'awaiting send: waiting notice, no announcement, typed text is kept',
    (tester) async {
      when(
        () => vm.postComment('r1', imageUrls: any(named: 'imageUrls')),
      ).thenThrow(const CommentAwaitingSendException());

      final announces = await postComment(tester, text: 'Gott!');

      expect(shown, [(sv.commentWaitingForNetwork, false)]);
      expect(announces.count, 0);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'Gott!',
      );
    },
  );
}
